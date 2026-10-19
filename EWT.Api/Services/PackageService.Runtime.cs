using System.Text;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// The develop loop for our own PL/SQL: read what is deployed, push a new version, and see the
/// compile errors, without restarting the API.
///
/// Startup verification was enough while the package changed once a week. It is not enough now
/// that the UI side regenerates it several times a day: every iteration cost a full restart,
/// which reloads metadata for seven instances before it will answer anything.
///
/// This is off unless <c>Packages:AllowRuntimeDeploy</c> is true, and it is true only in Dev.
/// It compiles PL/SQL into the database, so treat it as what it is. Two limits hold regardless
/// of configuration:
///
///   - Only a package the server already manages can be pushed, meaning one with a .sql file in
///     OurPackages. Today that is EWT_UI alone. Nothing can reach a legacy ACCUTRACK package
///     through this route.
///   - The instance is always named outright. There is no default and no implicit "all", because
///     on this estate a request that guesses its database has already gone wrong once.
/// </summary>
public partial class PackageService
{
    /// <summary>True when the runtime endpoints are permitted to compile anything.</summary>
    public bool AllowRuntimeDeploy => _allowRuntimeDeploy;

    /// <summary>The packages this server manages: one per .sql file in OurPackages.</summary>
    public IReadOnlyList<string> ManagedPackageNames =>
        LoadSources().Select(s => s.Name).OrderBy(n => n, StringComparer.OrdinalIgnoreCase).ToList();

    /// <summary>
    /// True when <paramref name="packageName"/> is one we manage. Anything else is refused:
    /// this endpoint is for iterating on our package, not for writing PL/SQL at large.
    /// </summary>
    public bool IsManaged(string packageName) =>
        ManagedPackageNames.Any(n => n.Equals(packageName, StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// The package exactly as the named instance currently holds it, rebuilt from USER_SOURCE.
    ///
    /// This is the deployed text, not the file: that is the point of pulling it. Oracle stores
    /// each unit from "PACKAGE ..." onward, so what comes back has no CREATE OR REPLACE and no
    /// slash lines. <see cref="MakeRunnable"/> puts those back when you want to edit and push it.
    /// </summary>
    public async Task<DeployedPackage?> GetDeployedAsync(string instance, string packageName)
    {
        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        var units = new List<DeployedUnit>();

        await using (var command = new OracleCommand(
            @"SELECT TYPE, TEXT FROM USER_SOURCE
               WHERE NAME = :n AND TYPE IN ('PACKAGE','PACKAGE BODY')
               ORDER BY DECODE(TYPE,'PACKAGE',1,2), LINE", connection))
        {
            command.Parameters.Add(new OracleParameter("n", packageName.ToUpperInvariant()));
            await using var reader = await command.ExecuteReaderAsync();

            var currentType = "";
            var text = new StringBuilder();
            while (await reader.ReadAsync())
            {
                var type = reader.GetString(0);
                if (type != currentType)
                {
                    if (currentType.Length > 0)
                    {
                        units.Add(new DeployedUnit(currentType, text.ToString()));
                    }
                    currentType = type;
                    text.Clear();
                }
                // USER_SOURCE.TEXT usually carries its own trailing newline, but not always
                // on the last line of a unit. Append one only when it is missing, or every
                // line comes back followed by a blank one.
                var line = reader.IsDBNull(1) ? "" : reader.GetString(1);
                text.Append(line);
                if (!line.EndsWith("\n", StringComparison.Ordinal))
                {
                    text.Append('\n');
                }
            }
            if (currentType.Length > 0)
            {
                units.Add(new DeployedUnit(currentType, text.ToString()));
            }
        }

        if (units.Count == 0)
        {
            return null;
        }

        var (missing, invalid, fingerprint) = await DescribeAsync(connection, packageName.ToUpperInvariant());
        var fileFingerprint = LoadSources()
            .FirstOrDefault(s => s.Name.Equals(packageName, StringComparison.OrdinalIgnoreCase))
            ?.Fingerprint ?? "";

        return new DeployedPackage(
            packageName.ToUpperInvariant(), instance, units, invalid, fingerprint, fileFingerprint,
            MakeRunnable(units));
    }

    /// <summary>
    /// Turns what USER_SOURCE gave back into something you can edit and push again: each unit
    /// gets its CREATE OR REPLACE prefix and its terminating slash.
    /// </summary>
    private static string MakeRunnable(IReadOnlyList<DeployedUnit> units)
    {
        var sb = new StringBuilder();
        foreach (var unit in units)
        {
            sb.Append("CREATE OR REPLACE ").Append(unit.Text.TrimEnd());
            if (!sb.ToString().TrimEnd().EndsWith(";", StringComparison.Ordinal))
            {
                sb.Append(';');
            }
            sb.Append('\n').Append("/\n\n");
        }
        return sb.ToString();
    }

    /// <summary>
    /// Compiles <paramref name="sqlText"/> on one instance and reports what Oracle made of it.
    ///
    /// Split the same way the startup path splits a file, so what you push behaves exactly as
    /// the same text would if you had put it in OurPackages and restarted. The package name in
    /// the text must match <paramref name="packageName"/>: pushing EWT_UI source under another
    /// name, or the reverse, is a mistake worth catching before it reaches the database.
    /// </summary>
    public async Task<PackageDeployResult> DeployTextAsync(
        string instance, string packageName, string sqlText)
    {
        var statements = SplitStatements(sqlText);
        if (statements.Count == 0)
        {
            return PackageDeployResult.Refused(instance, packageName,
                "The body contained no statements. Separate the spec and body with a line holding only a slash.");
        }

        var nameInText = PackageNameOf(statements);
        if (nameInText is null)
        {
            return PackageDeployResult.Refused(instance, packageName,
                "Could not find a CREATE PACKAGE or CREATE PACKAGE BODY in the text.");
        }

        if (!nameInText.Equals(packageName, StringComparison.OrdinalIgnoreCase))
        {
            return PackageDeployResult.Refused(instance, packageName,
                $"The text declares package {nameInText}, but the URL names {packageName}.");
        }

        _logger.LogWarning(
            "{Instance}: runtime deploy of package {Package}, {Bytes} bytes in {Statements} statement(s)",
            instance, packageName, sqlText.Length, statements.Count);

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        OracleException? failure = null;
        var ran = 0;
        foreach (var statement in statements)
        {
            try
            {
                await using var command = new OracleCommand(statement, connection)
                {
                    CommandTimeout = DdlTimeoutSeconds
                };
                await command.ExecuteNonQueryAsync();
                ran++;
            }
            catch (OracleException ex)
            {
                failure = ex;
                break;
            }
        }

        // Oracle creates a package that does not compile rather than refusing it, so the only
        // honest answer comes from USER_ERRORS, whether or not the driver reported a problem.
        var errors = await ReadCompileErrorsAsync(connection, packageName.ToUpperInvariant());
        var (missing, invalid, fingerprint) = await DescribeAsync(connection, packageName.ToUpperInvariant());

        var fileFingerprint = LoadSources()
            .FirstOrDefault(s => s.Name.Equals(packageName, StringComparison.OrdinalIgnoreCase))
            ?.Fingerprint ?? "";

        var result = new PackageDeployResult(
            instance,
            packageName.ToUpperInvariant(),
            Ok: failure is null && errors.Count == 0 && !missing && !invalid,
            StatementsRun: ran,
            StatementsTotal: statements.Count,
            Missing: missing,
            Invalid: invalid,
            OracleError: failure is null ? null : $"ORA-{failure.Number:00000}: {failure.Message.Split('\n')[0]}",
            Errors: errors,
            DatabaseFingerprint: fingerprint,
            FileFingerprint: fileFingerprint,
            Refusal: null);

        if (result.Ok)
        {
            _logger.LogInformation("{Instance}: {Package} compiled clean (runtime deploy)",
                instance, packageName);
        }
        else
        {
            _logger.LogError("{Instance}: {Package} runtime deploy did not come out clean: {Summary}",
                instance, packageName, result.Summary);
        }

        return result;
    }

    /// <summary>
    /// Pushes what is on disk in OurPackages, for when the file has been edited and you want it
    /// live without a restart.
    /// </summary>
    public async Task<PackageDeployResult> RedeployFromFileAsync(string instance, string packageName)
    {
        // Assembled from fragments, there is no single file to read: build the text the
        // same way the startup path does.
        if (UsesFragments && packageName.Equals("EWT_UI", StringComparison.OrdinalIgnoreCase))
        {
            return await DeployTextAsync(instance, packageName.ToUpperInvariant(),
                AssembleFromFragments());
        }

        var source = LoadSources()
            .FirstOrDefault(s => s.Name.Equals(packageName, StringComparison.OrdinalIgnoreCase));

        if (source is null)
        {
            return PackageDeployResult.Refused(instance, packageName,
                $"No .sql file in OurPackages declares package {packageName}.");
        }

        var path = Path.Combine(_directory, source.FileName);
        if (!File.Exists(path))
        {
            return PackageDeployResult.Refused(instance, packageName,
                $"{source.FileName} is not a readable file on this server.");
        }

        return await DeployTextAsync(instance, source.Name, await File.ReadAllTextAsync(path));
    }

    /// <summary>
    /// Replaces the .sql file this server ships for a package, so a change outlives a restart.
    ///
    /// Deploying and updating are deliberately separate. A deploy puts PL/SQL on a database and
    /// is undone by the next restart; an update changes what this server believes the package
    /// should be, which is what <c>matchesFile</c> is measured against and what AutoDeploy will
    /// put back. Keeping them apart means you can try something on one instance without
    /// claiming it is the truth, and claim it separately once it works.
    ///
    /// The previous contents are kept beside the file with a timestamp, because this overwrites
    /// a file that is checked in.
    /// </summary>
    public async Task<SourceFileUpdate> WriteSourceFileAsync(string packageName, string sqlText)
    {
        var statements = SplitStatements(sqlText);
        if (statements.Count == 0)
        {
            return SourceFileUpdate.Refused(
                "The body contained no statements. Separate the spec and body with a line holding only a slash.");
        }

        var nameInText = PackageNameOf(statements);
        if (nameInText is null)
        {
            return SourceFileUpdate.Refused(
                "Could not find a CREATE PACKAGE or CREATE PACKAGE BODY in the text.");
        }

        if (!nameInText.Equals(packageName, StringComparison.OrdinalIgnoreCase))
        {
            return SourceFileUpdate.Refused(
                $"The text declares package {nameInText}, but the URL names {packageName}.");
        }

        if (UsesFragments && packageName.Equals("EWT_UI", StringComparison.OrdinalIgnoreCase))
        {
            return SourceFileUpdate.Refused(
                "EWT_UI is assembled from one file per form, so there is no single file to "
                + "replace. Put the form you changed to /admin/ui-package/forms/{FORM}. "
                + "Replacing the whole package in one call would make one person's edit "
                + "silently overwrite everyone else's, which is the thing the split removed.");
        }

        var existing = LoadSources()
            .FirstOrDefault(s => s.Name.Equals(packageName, StringComparison.OrdinalIgnoreCase));
        if (existing is null)
        {
            return SourceFileUpdate.Refused(
                $"No .sql file in OurPackages declares package {packageName}, so there is nothing to update.");
        }

        var path = Path.Combine(_directory, existing.FileName);
        var previousBytes = File.Exists(path) ? new FileInfo(path).Length : 0;

        string? backup = null;
        if (File.Exists(path))
        {
            backup = path + "." + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".bak";
            File.Copy(path, backup, overwrite: true);
        }

        await File.WriteAllTextAsync(path, sqlText);

        var updated = LoadSources()
            .FirstOrDefault(s => s.Name.Equals(packageName, StringComparison.OrdinalIgnoreCase));

        _logger.LogWarning(
            "Package source file {File} replaced: {Old} bytes -> {New} bytes. Previous kept at {Backup}",
            existing.FileName, previousBytes, sqlText.Length, backup ?? "(none)");

        return new SourceFileUpdate(
            true, existing.FileName, path, backup is null ? null : Path.GetFileName(backup),
            previousBytes, sqlText.Length, statements.Count,
            updated?.Fingerprint ?? "", null);
    }

    /// <summary>Live state of one package on each named instance, read now rather than at startup.</summary>
    public async Task<List<PackageLiveStatus>> DescribeLiveAsync(
        string packageName, IEnumerable<string> instances)
    {
        var fileFingerprint = LoadSources()
            .FirstOrDefault(s => s.Name.Equals(packageName, StringComparison.OrdinalIgnoreCase))
            ?.Fingerprint ?? "";

        var results = new List<PackageLiveStatus>();
        foreach (var instance in instances)
        {
            try
            {
                await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
                await connection.OpenAsync();

                var (missing, invalid, fingerprint) = await DescribeAsync(connection, packageName.ToUpperInvariant());
                var errors = (missing || !invalid)
                    ? new List<PackageCompileError>()
                    : await ReadCompileErrorsAsync(connection, packageName.ToUpperInvariant());

                var procedures = missing ? 0 : await CountProceduresAsync(connection, packageName.ToUpperInvariant());

                results.Add(new PackageLiveStatus(
                    instance, packageName.ToUpperInvariant(), missing, invalid,
                    fingerprint, fileFingerprint, procedures, errors, null));
            }
            catch (Exception ex)
            {
                results.Add(new PackageLiveStatus(
                    instance, packageName.ToUpperInvariant(), true, false, "", fileFingerprint, 0,
                    new List<PackageCompileError>(), ex.Message.Split('\n')[0]));
            }
        }

        return results;
    }

    private static async Task<int> CountProceduresAsync(OracleConnection connection, string packageName)
    {
        await using var command = new OracleCommand(
            @"SELECT COUNT(*) FROM user_procedures
               WHERE object_name = :n AND procedure_name IS NOT NULL", connection);
        command.Parameters.Add(new OracleParameter("n", packageName));
        return Convert.ToInt32(await command.ExecuteScalarAsync() ?? 0);
    }

    /// <summary>
    /// USER_ERRORS for one unit, returned rather than only logged, so a push can answer "why
    /// is it invalid" in its own response instead of sending someone to the server log.
    /// </summary>
    private static async Task<List<PackageCompileError>> ReadCompileErrorsAsync(
        OracleConnection connection, string packageName)
    {
        var errors = new List<PackageCompileError>();
        try
        {
            await using var command = new OracleCommand(
                @"SELECT type, line, position, text FROM user_errors
                   WHERE name = :n ORDER BY type, sequence", connection);
            command.Parameters.Add(new OracleParameter("n", packageName));

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                errors.Add(new PackageCompileError(
                    reader.GetString(0),
                    Convert.ToInt32(reader.GetValue(1)),
                    Convert.ToInt32(reader.GetValue(2)),
                    reader.GetString(3).TrimEnd()));
            }
        }
        catch
        {
            // Reading the reason must never be what fails the operation.
        }
        return errors;
    }
}

/// <summary>One compiled unit as the database holds it.</summary>
public record DeployedUnit(string Type, string Text);

/// <summary>The outcome of replacing a package's .sql file on the server.</summary>
public record SourceFileUpdate(
    bool Ok,
    string? FileName,
    string? Path,
    string? BackupFileName,
    long PreviousBytes,
    long NewBytes,
    int Statements,
    string Fingerprint,
    string? Refusal)
{
    public static SourceFileUpdate Refused(string why) =>
        new(false, null, null, null, 0, 0, 0, "", why);
}

/// <summary>A package pulled back off an instance.</summary>
public record DeployedPackage(
    string Package,
    string Instance,
    IReadOnlyList<DeployedUnit> Units,
    bool Invalid,
    string DatabaseFingerprint,
    string FileFingerprint,
    string Runnable)
{
    /// <summary>True when the instance holds exactly what OurPackages says it should.</summary>
    public bool MatchesFile => FileFingerprint.Length > 0 && DatabaseFingerprint == FileFingerprint;
}

/// <summary>A compile error, straight from USER_ERRORS.</summary>
public record PackageCompileError(string Type, int Line, int Position, string Text);

/// <summary>What one instance made of a pushed package.</summary>
public record PackageDeployResult(
    string Instance,
    string Package,
    bool Ok,
    int StatementsRun,
    int StatementsTotal,
    bool Missing,
    bool Invalid,
    string? OracleError,
    IReadOnlyList<PackageCompileError> Errors,
    string DatabaseFingerprint,
    string FileFingerprint,
    string? Refusal)
{
    public static PackageDeployResult Refused(string instance, string package, string why) =>
        new(instance, package, false, 0, 0, false, false, null,
            new List<PackageCompileError>(), "", "", why);

    /// <summary>True when the instance now holds exactly what OurPackages says.</summary>
    public bool MatchesFile => FileFingerprint.Length > 0 && DatabaseFingerprint == FileFingerprint;

    public string Summary =>
        Refusal
        ?? OracleError
        ?? (Errors.Count > 0
            ? $"{Errors.Count} compile error(s), first at {Errors[0].Type} line {Errors[0].Line}: {Errors[0].Text}"
            : Missing ? "the package is not there after the push"
            : Invalid ? "the package is INVALID"
            : "compiled clean");
}

/// <summary>Live state of one package on one instance.</summary>
public record PackageLiveStatus(
    string Instance,
    string Package,
    bool Missing,
    bool Invalid,
    string DatabaseFingerprint,
    string FileFingerprint,
    int Procedures,
    IReadOnlyList<PackageCompileError> Errors,
    string? Unreachable)
{
    public bool MatchesFile => FileFingerprint.Length > 0 && DatabaseFingerprint == FileFingerprint;
}
