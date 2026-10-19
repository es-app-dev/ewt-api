using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// Keeps our own PL/SQL packages present, valid and identical on all seven databases.
///
/// A package of ours is one of only two permitted additions to this schema, the other being
/// the audit table. Everything else in these databases belongs to the legacy application and
/// is not ours to touch.
///
/// Three things go wrong with a package spread across seven databases, and only the first is
/// obvious:
///
///   missing   it was deployed to some instances and not others, so a screen works at one
///             site and fails at another
///   invalid   it compiled against something that has since changed, so it exists but throws
///   drifted   it exists everywhere, is valid everywhere, and the bodies differ, which is the
///             worst of the three because nothing reports it
///
/// So existence is checked, status is checked, and the source on each database is fingerprinted
/// and compared both against the file on disk and across instances. The file in OurPackages is
/// the source of truth; a database that disagrees with it is reported as drifted.
///
/// Deployment is deliberately opt in. The legacy Forms application is running against these
/// same databases, and CREATE OR REPLACE PACKAGE is a real change to a live system, so the
/// default is to report and do nothing. Set Packages:AutoDeploy in an environment where that
/// is acceptable, which is the same shape as Audit:AutoCreate.
/// </summary>
public partial class PackageService
{
    /// <summary>Directory holding our package source, relative to the application root.</summary>
    private const string SourceDirectoryName = "OurPackages";

    private const int DdlTimeoutSeconds = 120;

    private readonly OracleConnectionService _connectionService;
    private readonly ILogger<PackageService> _logger;
    private readonly bool _verify;
    private readonly bool _autoDeploy;
    private readonly bool _allowRuntimeDeploy;
    private readonly string _directory;

    /// <summary>What we found, per instance, for reporting.</summary>
    private readonly List<PackageStatus> _status = new();

    public PackageService(
        OracleConnectionService connectionService,
        IConfiguration configuration,
        ILogger<PackageService> logger)
    {
        _connectionService = connectionService;
        _logger = logger;
        _verify = configuration.GetValue("Packages:Verify", true);
        _autoDeploy = configuration.GetValue("Packages:AutoDeploy", false);
        // Off unless asked for. It compiles PL/SQL into the database, so it is a Dev-only
        // convenience and must stay false anywhere the legacy application matters.
        _allowRuntimeDeploy = configuration.GetValue("Packages:AllowRuntimeDeploy", false);
        _directory = Path.Combine(AppContext.BaseDirectory, SourceDirectoryName);
    }

    public IReadOnlyList<PackageStatus> Status => _status;

    /// <summary>
    /// Checks every package on every instance at startup, and deploys where configured to.
    ///
    /// Never throws. A database we cannot reach, or a package we cannot compile, is a thing
    /// to report loudly and carry on from; it is not a reason to refuse to start an API whose
    /// other 1,500 entity sets are fine.
    /// </summary>
    public async Task VerifyAsync()
    {
        if (!_verify)
        {
            _logger.LogInformation("Package verification disabled (Packages:Verify=false).");
            return;
        }

        var sources = LoadSources();
        if (sources.Count == 0)
        {
            _logger.LogInformation(
                "No package source in {Directory}. Drop a .sql file there and it is checked on "
                + "every instance at startup.", _directory);
            return;
        }

        _logger.LogInformation("Checking {Count} package(s) from {Directory} on {Instances} instances",
            sources.Count, _directory, _connectionService.InstanceNames.Count);

        foreach (var instance in _connectionService.InstanceNames)
        {
            try
            {
                await VerifyInstanceAsync(instance, sources);
            }
            catch (OracleException ex) when (ex.Number is 1017 or 28000)
            {
                // Every instance shares one Oracle account, so this fails identically
                // everywhere. Stop rather than spending a failed login per instance and
                // risking a lockout on the shared account.
                _logger.LogError(ex,
                    "Authentication failed on {Instance}; abandoning package checks on the "
                    + "remaining instances to protect the shared account.", instance);
                return;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "{Instance}: package check failed", instance);
            }
        }

        ReportDrift(sources);
    }

    private async Task VerifyInstanceAsync(string instance, IReadOnlyList<PackageSource> sources)
    {
        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        // Two queries for the whole set, then compare in memory. Only packages that
        // actually need deploying cost anything further.
        var state = await DescribeAllAsync(connection, sources.Select(s => s.Name).ToList());
        var redeployed = false;

        foreach (var source in sources)
        {
            var found = state.TryGetValue(source.Name, out var f) ? f : new FoundPackage();

            if (_autoDeploy && (found.Missing || found.Fingerprint != source.Fingerprint))
            {
                await DeployAsync(connection, instance, source,
                    found.Missing ? "missing" : "different from the file on disk");
                redeployed = true;
            }
        }

        // Report on what is there NOW. Reading before the deploys and reporting afterwards
        // would say "MISSING" about a package that had just been created successfully.
        if (redeployed)
        {
            state = await DescribeAllAsync(connection, sources.Select(s => s.Name).ToList());
        }

        foreach (var source in sources)
        {
            var found = state.TryGetValue(source.Name, out var f) ? f : new FoundPackage();

            _status.Add(new PackageStatus(instance, source.Name, found.Missing, found.Invalid,
                found.Fingerprint, source.Fingerprint));

            if (found.Missing)
            {
                _logger.LogWarning(
                    "{Instance}: package {Package} is MISSING. {Action}",
                    instance, source.Name,
                    _autoDeploy
                        ? "Auto-deploy is on but it did not compile; see the error above."
                        : $"Packages:AutoDeploy is false, so run {source.FileName} there by hand.");
            }
            else if (found.Invalid)
            {
                _logger.LogWarning(
                    "{Instance}: package {Package} exists but is INVALID. It will throw when "
                    + "called. Recompile it, or fix what it depends on.", instance, source.Name);
            }
            else if (found.Fingerprint != source.Fingerprint)
            {
                _logger.LogWarning(
                    "{Instance}: package {Package} is VALID but does NOT match {File}. The "
                    + "database has a different version from the one in source control.",
                    instance, source.Name, source.FileName);
            }
            else
            {
                _logger.LogInformation("{Instance}: package {Package} present, valid and current",
                    instance, source.Name);
            }
        }
    }

    /// <summary>
    /// Compares each package across instances, which is the check that catches the quiet
    /// failure: present and valid everywhere, but not the same code everywhere.
    /// </summary>
    private void ReportDrift(IReadOnlyList<PackageSource> sources)
    {
        foreach (var source in sources)
        {
            var rows = _status.Where(s => s.Package == source.Name && !s.Missing).ToList();
            if (rows.Count == 0)
            {
                continue;
            }

            var versions = rows.GroupBy(r => r.DatabaseFingerprint).ToList();
            if (versions.Count > 1)
            {
                var detail = string.Join("; ", versions.Select(g =>
                    $"[{string.Join(", ", g.Select(r => r.Instance))}] = {g.Key[..8]}"));
                _logger.LogError(
                    "Package {Package} DIFFERS between instances: {Detail}. The same call will "
                    + "behave differently depending on ?db=.", source.Name, detail);
            }
        }

        var missing = _status.Count(s => s.Missing);
        var invalid = _status.Count(s => s.Invalid);
        var stale = _status.Count(s => !s.Missing && !s.Matches);

        _logger.LogInformation(
            "Packages: {Ok} of {Total} instance checks present, valid and current "
            + "({Missing} missing, {Invalid} invalid, {Stale} not matching source)",
            _status.Count - missing - invalid - stale, _status.Count, missing, invalid, stale);
    }

    private async Task<(bool Missing, bool Invalid, string Fingerprint)> DescribeAsync(
        OracleConnection connection, string packageName)
    {
        var invalid = false;
        var any = false;

        await using (var command = new OracleCommand(
            @"SELECT OBJECT_TYPE, STATUS FROM USER_OBJECTS
               WHERE OBJECT_NAME = :n AND OBJECT_TYPE IN ('PACKAGE','PACKAGE BODY')", connection))
        {
            command.Parameters.Add(new OracleParameter("n", packageName));
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                any = true;
                if (!string.Equals(reader.GetString(1), "VALID", StringComparison.OrdinalIgnoreCase))
                {
                    invalid = true;
                }
            }
        }

        if (!any)
        {
            return (true, false, "");
        }

        var text = new StringBuilder();
        await using (var command = new OracleCommand(
            @"SELECT TEXT FROM USER_SOURCE
               WHERE NAME = :n AND TYPE IN ('PACKAGE','PACKAGE BODY')
               ORDER BY TYPE, LINE", connection))
        {
            command.Parameters.Add(new OracleParameter("n", packageName));
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // One row per source line, and the line break is not part of TEXT, so it
                // has to be put back. Without it the lines glue together and the database
                // fingerprint can never equal the file's.
                text.Append(reader.IsDBNull(0) ? "" : reader.GetString(0)).Append('\n');
            }
        }

        return (false, invalid, Fingerprint(text.ToString()));
    }

    private async Task DeployAsync(
        OracleConnection connection, string instance, PackageSource source, string why)
    {
        _logger.LogWarning("{Instance}: deploying package {Package} ({Why}) from {File}",
            instance, source.Name, why, source.FileName);

        foreach (var statement in source.Statements)
        {
            try
            {
                await using var command = new OracleCommand(statement, connection)
                {
                    CommandTimeout = DdlTimeoutSeconds
                };
                await command.ExecuteNonQueryAsync();
            }
            catch (OracleException ex)
            {
                _logger.LogError(
                    "{Instance}: package {Package} failed on ORA-{Number:00000}: {Message}",
                    instance, source.Name, ex.Number, ex.Message);
                await ReportCompileErrorsAsync(connection, instance, source.Name);
                return;
            }
        }

        // Oracle creates a package that does not compile rather than refusing it, and the
        // driver may report that as success. So ask outright instead of assuming.
        await ReportCompileErrorsAsync(connection, instance, source.Name);
    }

    /// <summary>
    /// Reads the state of every package on one instance in two queries, not two per package.
    ///
    /// The per-package version cost about six seconds across seven instances for one
    /// package. The UI side expects roughly seventy, one per ported screen, which would
    /// have been seven minutes of startup and 980 round trips. Batching keeps it at two
    /// queries per instance however many packages there are.
    /// </summary>
    private async Task<Dictionary<string, FoundPackage>> DescribeAllAsync(
        OracleConnection connection, IReadOnlyCollection<string> names)
    {
        var found = new Dictionary<string, FoundPackage>(StringComparer.OrdinalIgnoreCase);
        if (names.Count == 0)
        {
            return found;
        }

        foreach (var chunk in names.Chunk(900))
        {
            var binds = string.Join(", ", chunk.Select((_, i) => $":n{i}"));

            await using (var command = new OracleCommand(
                $@"SELECT OBJECT_NAME, OBJECT_TYPE, STATUS FROM USER_OBJECTS
                    WHERE OBJECT_NAME IN ({binds})
                      AND OBJECT_TYPE IN ('PACKAGE','PACKAGE BODY')", connection))
            {
                for (var i = 0; i < chunk.Length; i++)
                {
                    command.Parameters.Add(new OracleParameter($"n{i}", chunk[i]));
                }

                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    var name = reader.GetString(0);
                    if (!found.TryGetValue(name, out var entry))
                    {
                        found[name] = entry = new FoundPackage();
                    }
                    entry.Exists = true;
                    if (!string.Equals(reader.GetString(2), "VALID", StringComparison.OrdinalIgnoreCase))
                    {
                        entry.Invalid = true;
                    }
                }
            }

            // Source for all of them at once, ordered so each package's lines stay together
            // and the spec precedes the body, matching how the file is assembled.
            await using (var command = new OracleCommand(
                $@"SELECT NAME, TEXT FROM USER_SOURCE
                    WHERE NAME IN ({binds}) AND TYPE IN ('PACKAGE','PACKAGE BODY')
                    ORDER BY NAME, TYPE, LINE", connection))
            {
                for (var i = 0; i < chunk.Length; i++)
                {
                    command.Parameters.Add(new OracleParameter($"n{i}", chunk[i]));
                }

                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    var name = reader.GetString(0);
                    if (!found.TryGetValue(name, out var entry))
                    {
                        found[name] = entry = new FoundPackage { Exists = true };
                    }
                    entry.Source.Append(reader.IsDBNull(1) ? "" : reader.GetString(1)).Append('\n');
                }
            }
        }

        foreach (var entry in found.Values)
        {
            entry.Fingerprint = Fingerprint(entry.Source.ToString());
        }

        return found;
    }

    /// <summary>One package as the database currently holds it.</summary>
    private sealed class FoundPackage
    {
        public bool Exists { get; set; }
        public bool Invalid { get; set; }
        public StringBuilder Source { get; } = new();
        public string Fingerprint { get; set; } = "";
        public bool Missing => !Exists;
    }

    /// <summary>
    /// Logs why a unit is invalid, line by line, from USER_ERRORS.
    ///
    /// Without this the log says ORA-24344, success with compilation error, and nothing
    /// more, so "why is it INVALID" needs a DBA and a SQL session. The answer is one query
    /// away and belongs in the startup log.
    /// </summary>
    private async Task ReportCompileErrorsAsync(
        OracleConnection connection, string instance, string packageName)
    {
        try
        {
            await using var command = new OracleCommand(
                @"SELECT type, line, position, text FROM user_errors
                   WHERE name = :n ORDER BY type, sequence", connection);
            command.Parameters.Add(new OracleParameter("n", packageName));

            var any = false;
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                any = true;
                _logger.LogError("{Instance}: {Package} {Type} line {Line}:{Position}  {Text}",
                    instance, packageName, reader.GetString(0),
                    Convert.ToInt32(reader.GetValue(1)), Convert.ToInt32(reader.GetValue(2)),
                    reader.GetString(3).TrimEnd());
            }

            if (!any)
            {
                _logger.LogInformation("{Instance}: {Package} compiled clean",
                    instance, packageName);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Instance}: could not read compile errors for {Package}",
                instance, packageName);
        }
    }

    /// <summary>
    /// Reads every .sql file in OurPackages. Each file is one package: its spec, its body, or
    /// both, separated the way SQL*Plus separates them, with a line containing only a slash.
    /// </summary>
    private List<PackageSource> LoadSources()
    {
        var sources = new List<PackageSource>();
        if (!Directory.Exists(_directory))
        {
            return sources;
        }

        // EWT_UI comes from OurPackages/ewt_ui when that directory is there: one file per
        // form, concatenated. The monolith on disk, if still present, is then ignored, so
        // there is never a question of which one the server deployed.
        if (UsesFragments)
        {
            try
            {
                var assembled = AssembleFromFragments();
                var statements = SplitStatements(assembled);
                var name = PackageNameOf(statements);
                if (name is not null && statements.Count > 0)
                {
                    sources.Add(new PackageSource(
                        name, $"{FragmentDirectoryName}/ ({FragmentOrder().Count} fragments)",
                        statements, FingerprintOfSource(statements)));
                }
                else
                {
                    _logger.LogError(
                        "Assembled {Count} fragments but found no package in the result; "
                        + "falling back to the .sql files in {Directory}.",
                        FragmentOrder().Count, _directory);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Could not assemble the EWT_UI fragments; falling back to the .sql files.");
            }
        }

        foreach (var path in Directory.GetFiles(_directory, "*.sql").OrderBy(p => p))
        {
            // Already covered by the fragments.
            if (sources.Any(s => s.Name.Equals(
                    Path.GetFileNameWithoutExtension(path), StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

            try
            {
                var text = File.ReadAllText(path);
                var statements = SplitStatements(text);
                if (statements.Count == 0)
                {
                    _logger.LogWarning("{File} contains no statements; ignoring", Path.GetFileName(path));
                    continue;
                }

                var name = PackageNameOf(statements) ?? Path.GetFileNameWithoutExtension(path).ToUpperInvariant();
                sources.Add(new PackageSource(
                    name, Path.GetFileName(path), statements, FingerprintOfSource(statements)));
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not read package source {File}", path);
            }
        }

        return sources;
    }

    /// <summary>Splits on a line containing only a slash, which is how PL/SQL blocks end.</summary>
    /// <summary>A PL/SQL unit, where the trailing semicolon is part of the code.</summary>
    private static readonly Regex PlSqlUnit = new(
        @"^\s*CREATE\b(?:\s+OR\s+REPLACE)?(?:\s+(?:EDITIONABLE|NONEDITIONABLE))?\s+"
        + @"(?:PACKAGE|PROCEDURE|FUNCTION|TRIGGER|TYPE)\b",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static List<string> SplitStatements(string text) =>
        Regex.Split(text, @"^\s*/\s*$", RegexOptions.Multiline)
            .Select(s => s.Trim())
            // Strip the trailing semicolon from plain SQL, where it is ORA-00911, and KEEP
            // it on a PL/SQL unit, where it terminates the block. Removing it turns
            // "END pkg;" into "END pkg", and Oracle then creates the package with
            // PLS-00103, end-of-file when expecting ";". That is what compiled
            // EWT_UI_AT5510 INVALID on all seven instances. The file itself was always
            // correct; it compiles by hand in SQL*Plus. Only this splitter broke it.
            .Select(s => PlSqlUnit.IsMatch(StripComments(s)) ? s : s.TrimEnd(';'))
            .Where(s => s.Length > 0 && !s.Split('\n').All(l => l.TrimStart().StartsWith("--")))
            .ToList();

    /// <summary>
    /// The package name, read from the CREATE statement rather than from the filename.
    ///
    /// Anchored on CREATE ... PACKAGE, with comments stripped first. Matching a bare
    /// "PACKAGE &lt;word&gt;" anywhere in the file reads prose as code: a header comment
    /// saying "this package that does X" yields a package named THAT.
    /// </summary>
    private static string? PackageNameOf(IEnumerable<string> statements)
    {
        foreach (var statement in statements)
        {
            var match = Regex.Match(StripComments(statement),
                @"\bCREATE\b(?:\s+OR\s+REPLACE)?(?:\s+(?:EDITIONABLE|NONEDITIONABLE))?"
                + @"\s+PACKAGE\s+(?:BODY\s+)?(?:""?\w+""?\s*\.\s*)?""?(\w+)""?",
                RegexOptions.IgnoreCase);
            if (match.Success)
            {
                return match.Groups[1].Value.ToUpperInvariant();
            }
        }
        return null;
    }

    /// <summary>Removes line and block comments, so prose cannot be mistaken for code.</summary>
    private static string StripComments(string sql)
    {
        sql = Regex.Replace(sql, @"/\*.*?\*/", " ", RegexOptions.Singleline);
        sql = Regex.Replace(sql, @"--[^\n]*", " ");
        return sql;
    }

    /// <summary>
    /// A fingerprint that ignores whitespace and case, so reformatting does not read as drift
    /// but a real change does. Oracle stores source with its own line breaks and folds
    /// unquoted identifiers, so comparing raw text would report differences that are not.
    /// </summary>
    private static string Fingerprint(string source)
    {
        var normalised = Regex.Replace(source, @"\s+", " ").Trim().ToUpperInvariant();
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalised)));
    }

    /// <summary>
    /// Fingerprints the file the way Oracle will store it, so the two can be compared.
    ///
    /// USER_SOURCE keeps each unit from the PACKAGE keyword onward. It does not keep the
    /// header comments, the CREATE OR REPLACE prefix, or the slash that ends the block.
    /// Hashing the raw file therefore never matches the database, however perfect the
    /// deploy: with AutoDeploy on that is a CREATE OR REPLACE on every restart, which hands
    /// ORA-04068 to every session that had called the package, and with it off it is a
    /// permanent "does not match" that hides real drift.
    /// </summary>
    private static string FingerprintOfSource(IEnumerable<string> statements) =>
        // Joined with a newline, not concatenated. USER_SOURCE stores one row per line and
        // each carries its line break, so the database's text has a separator between the
        // spec's "END pkg;" and the body's "PACKAGE BODY". Without one here, the two differ
        // by a single character at that junction and never match.
        Fingerprint(string.Join("\n", statements.Select(StoredForm)));

    /// <summary>
    /// The part of a statement Oracle retains: from PACKAGE, PROCEDURE, FUNCTION, TRIGGER
    /// or TYPE onward. Anything before that, comments included, is discarded on create.
    /// </summary>
    private static string StoredForm(string statement)
    {
        // Anchored on CREATE, with the object type in a lookahead so the match ends exactly
        // where Oracle starts storing. A bare \bPACKAGE\b is not enough: this file's own
        // header mentions "validate-package.cjs", and the "." after "package" is a word
        // boundary, so the cut landed in the middle of a comment. The header also contains
        // the words "CREATE OR REPLACE" in prose, which the lookahead rules out.
        var match = Regex.Match(statement,
            @"\bCREATE\b(?:\s+OR\s+REPLACE)?(?:\s+(?:EDITIONABLE|NONEDITIONABLE))?\s+"
            + @"(?=(?:PACKAGE|PROCEDURE|FUNCTION|TRIGGER|TYPE)\b)",
            RegexOptions.IgnoreCase);
        return match.Success ? statement[(match.Index + match.Length)..] : statement;
    }

    internal record PackageSource(string Name, string FileName, List<string> Statements, string Fingerprint);
}

/// <summary>One package on one instance, as found at startup.</summary>
public record PackageStatus(
    string Instance,
    string Package,
    bool Missing,
    bool Invalid,
    string DatabaseFingerprint,
    string FileFingerprint)
{
    /// <summary>True when the database holds exactly what the file on disk says.</summary>
    public bool Matches => !Missing && DatabaseFingerprint == FileFingerprint;
}
