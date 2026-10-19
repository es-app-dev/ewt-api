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