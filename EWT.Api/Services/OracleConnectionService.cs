using System.Text;
using Microsoft.Extensions.Options;

namespace EWT.Api.Services;

/// <summary>
/// Configuration for a single EWT Oracle instance (CORP or one of the daughters).
/// </summary>
public class OracleInstanceOptions
{
    /// <summary>Human-readable name, surfaced by the /odata/instances endpoint.</summary>
    public string? DisplayName { get; set; }

    /// <summary>True for the top-level corporate instance.</summary>
    public bool IsCorporate { get; set; }

    /// <summary>
    /// Suffix from the legacy Web.config connection name
    /// (EWTOracleConnectionString_1064 -> "1064"). Kept so callers migrating from the
    /// old app can map their existing site identifiers onto instance names.
    /// </summary>
    public string? LegacyKey { get; set; }

    /// <summary>
    /// The tnsnames.ora entry this instance's connect descriptor was taken from
    /// (e.g. EWT_CORP_DEV). Documentation only — the descriptor is inlined in
    /// <see cref="ConnectionString"/> so no tnsnames.ora deployment is needed.
    /// </summary>
    public string? TnsAlias { get; set; }

    /// <summary>
    /// Connection string. May contain a {PASSWORD} token, substituted from
    /// <see cref="Password"/> or <see cref="PasswordBase64"/> at startup.
    /// </summary>
    public string ConnectionString { get; set; } = string.Empty;

    /// <summary>
    /// Password for this instance. Supply via user-secrets or environment,
    /// never via a checked-in appsettings file.
    /// </summary>
    public string? Password { get; set; }

    /// <summary>
    /// Base64-encoded password, carried over from EWIS for compatibility.
    /// Base64 is encoding, not encryption — prefer <see cref="Password"/> in user-secrets.
    /// </summary>
    public string? PasswordBase64 { get; set; }
}

/// <summary>
/// Root Oracle configuration bound from the "Oracle" section.
/// </summary>
public class OracleOptions
{
    public const string SectionName = "Oracle";

    public string? SchemaFilter { get; set; }

    /// <summary>
    /// How long a write waits for a row lock before giving up, in seconds.
    ///
    /// The legacy Forms application is still running against these databases and takes
    /// SELECT ... FOR UPDATE NOWAIT the moment a user edits a row, holding it until they
    /// commit. Without this, an API write to that row blocks in Oracle until the person
    /// comes back from lunch, and the caller sees a connection timeout rather than
    /// "somebody else has this record". With it, the write gives up promptly and says so.
    ///
    /// 0 means NOWAIT, fail immediately. A negative value disables the check entirely and
    /// restores the old blocking behaviour.
    /// </summary>
    public int LockWaitSeconds { get; set; } = 3;

    /// <summary>
    /// Directory containing tnsnames.ora. Applied to TNS_ADMIN at startup when set;
    /// leave null to use the machine's existing Oracle client configuration.
    /// </summary>
    public string? TnsAdmin { get; set; }

    /// <summary>
    /// Instance whose schema is read to build the EDM model. The daughters share an
    /// identical schema, so the model is built once here and reused for every instance.
    /// </summary>
    public string ModelSourceInstance { get; set; } = "CORP";

    /// <summary>
    /// Instance used when a request omits the instance segment.
    /// Null means every request must name an instance explicitly.
    /// </summary>
    public string? DefaultInstance { get; set; }

    /// <summary>
    /// Password used by any instance that does not define its own. Every EWT instance
    /// connects as the same account, so this is normally the only secret you set:
    ///   dotnet user-secrets set "Oracle:DefaultPassword" "&lt;password&gt;"
    /// </summary>
    public string? DefaultPassword { get; set; }

    /// <summary>
    /// Base64-encoded shared password — the EWIS convention, carried forward. Used when
    /// no plain <see cref="DefaultPassword"/> and no per-instance password is set.
    /// Base64 is encoding, not encryption: anyone with the file can decode it, so keep
    /// it out of anything committed to git.
    /// </summary>
    public string? DefaultPasswordBase64 { get; set; }

    public Dictionary<string, OracleInstanceOptions> Instances { get; set; } =
        new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>
/// Thrown when a request names an instance that is not configured.
/// </summary>
public class UnknownInstanceException : Exception
{
    public UnknownInstanceException(string requested, IReadOnlyCollection<string> known)
        : base($"Unknown database instance '{requested}'.")
    {
        RequestedInstance = requested;
        KnownInstances = known;
    }

    public string RequestedInstance { get; }
    public IReadOnlyCollection<string> KnownInstances { get; }
}

/// <summary>
/// Resolves Oracle connection strings for the CORP instance and its daughter databases.
/// Connection strings are resolved once at startup; callers select an instance by name
/// on every request.
/// </summary>
public class OracleConnectionService
{
    /// <summary>
    /// Seconds a write waits for a row lock before refusing. See OracleOptions.
    /// </summary>
    public int LockWaitSeconds { get; private set; } = 3;

    private readonly Dictionary<string, string> _connectionStrings =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, OracleInstanceOptions> _instances;
    private readonly ILogger<OracleConnectionService> _logger;

    public OracleConnectionService(IOptions<OracleOptions> options, ILogger<OracleConnectionService> logger)
    {
        _logger = logger;
        var opts = options.Value;
        LockWaitSeconds = opts.LockWaitSeconds;

        _instances = new Dictionary<string, OracleInstanceOptions>(opts.Instances, StringComparer.OrdinalIgnoreCase);

        if (_instances.Count == 0)
        {
            throw new InvalidOperationException(
                "No Oracle instances configured. Populate Oracle:Instances with CORP and the daughter databases.");
        }

        foreach (var (name, instance) in _instances)
        {
            if (string.IsNullOrWhiteSpace(instance.ConnectionString))
            {
                throw new InvalidOperationException(
                    $"Oracle instance '{name}' has no ConnectionString configured.");
            }

            _connectionStrings[name] = ResolvePassword(name, instance, opts);
        }

        ModelSourceInstance = opts.ModelSourceInstance;
        if (!_connectionStrings.ContainsKey(ModelSourceInstance))
        {
            throw new InvalidOperationException(
                $"Oracle:ModelSourceInstance is '{ModelSourceInstance}', which is not one of the configured " +
                $"instances ({string.Join(", ", _connectionStrings.Keys)}).");
        }

        DefaultInstance = opts.DefaultInstance;
        if (DefaultInstance is not null && !_connectionStrings.ContainsKey(DefaultInstance))
        {
            throw new InvalidOperationException(
                $"Oracle:DefaultInstance is '{DefaultInstance}', which is not one of the configured " +
                $"instances ({string.Join(", ", _connectionStrings.Keys)}).");
        }

        _logger.LogInformation(
            "Configured {Count} Oracle instances: {Instances}. Model source: {ModelSource}. Default: {Default}",
            _connectionStrings.Count,
            string.Join(", ", _connectionStrings.Keys),
            ModelSourceInstance,
            DefaultInstance ?? "(none - instance required on every request)");
    }

    /// <summary>Instance whose schema backs the shared EDM model.</summary>
    public string ModelSourceInstance { get; }

    /// <summary>Instance used when a request omits one, or null if it is always required.</summary>
    public string? DefaultInstance { get; }

    /// <summary>All configured instance names.</summary>
    public IReadOnlyCollection<string> InstanceNames => _connectionStrings.Keys;

    /// <summary>Configuration for every instance, for the discovery endpoint.</summary>
    public IReadOnlyDictionary<string, OracleInstanceOptions> Instances => _instances;

    /// <summary>
    /// Gets the connection string for a named instance.
    /// </summary>
    /// <exception cref="UnknownInstanceException">The instance is not configured.</exception>
    public string GetConnectionString(string instance)
    {
        if (string.IsNullOrWhiteSpace(instance))
        {
            throw new UnknownInstanceException(instance ?? "(null)", InstanceNames);
        }

        if (!_connectionStrings.TryGetValue(instance, out var connectionString))
        {
            throw new UnknownInstanceException(instance, InstanceNames);
        }

        return connectionString;
    }

    /// <summary>
    /// Resolves the instance a request should use: the one it named, or the configured
    /// default when it named none.
    /// </summary>
    /// <exception cref="UnknownInstanceException">
    /// No instance was named and no default is configured, or the named instance is unknown.
    /// </exception>
    public string ResolveInstanceName(string? requested)
    {
        if (string.IsNullOrWhiteSpace(requested))
        {
            if (DefaultInstance is null)
            {
                throw new UnknownInstanceException("(none supplied)", InstanceNames);
            }
            return DefaultInstance;
        }

        if (!_connectionStrings.TryGetValue(requested, out _))
        {
            throw new UnknownInstanceException(requested, InstanceNames);
        }

        // Return the canonical casing from configuration, not whatever the caller typed.
        return _connectionStrings.Keys.First(k => string.Equals(k, requested, StringComparison.OrdinalIgnoreCase));
    }

    public bool IsKnownInstance(string? instance) =>
        !string.IsNullOrWhiteSpace(instance) && _connectionStrings.ContainsKey(instance);

    private string ResolvePassword(string name, OracleInstanceOptions instance, OracleOptions opts)
    {
        var template = instance.ConnectionString;

        if (!template.Contains("{PASSWORD}", StringComparison.Ordinal))
        {
            // Password already embedded, or the instance uses external/OS authentication.
            return template;
        }

        // Most specific wins: per-instance before shared, plain before base64.
        if (!string.IsNullOrEmpty(instance.Password))
        {
            return template.Replace("{PASSWORD}", instance.Password);
        }

        if (!string.IsNullOrEmpty(instance.PasswordBase64))
        {
            return template.Replace(
                "{PASSWORD}", Decode(instance.PasswordBase64, $"Oracle:Instances:{name}:PasswordBase64"));
        }

        if (!string.IsNullOrEmpty(opts.DefaultPassword))
        {
            return template.Replace("{PASSWORD}", opts.DefaultPassword);
        }

        if (!string.IsNullOrEmpty(opts.DefaultPasswordBase64))
        {
            return template.Replace(
                "{PASSWORD}", Decode(opts.DefaultPasswordBase64, "Oracle:DefaultPasswordBase64"));
        }

        _logger.LogError(
            "Instance {Instance} has a {{PASSWORD}} token but no password configured. " +
            "All EWT instances share one account, so normally you set just " +
            "Oracle:DefaultPassword or Oracle:DefaultPasswordBase64.", name);

        throw new InvalidOperationException(
            $"Oracle instance '{name}' has a {{PASSWORD}} token in its connection string but no password " +
            $"configured. Set Oracle:DefaultPassword / Oracle:DefaultPasswordBase64 (shared), or " +
            $"Oracle:Instances:{name}:Password / :PasswordBase64 (per-instance override).");
    }
    private bool _base64Warned;

    private string Decode(string encoded, string configKey)
    {
        if (!_base64Warned)
        {
            _base64Warned = true;
            _logger.LogWarning(
                "Oracle password supplied as base64 ({ConfigKey}). Base64 is encoding, not encryption — " +
                "anyone with the file can decode it, so keep it out of git.", configKey);
        }

        try
        {
            return Encoding.UTF8.GetString(Convert.FromBase64String(encoded));
        }
        catch (FormatException ex)
        {
            throw new InvalidOperationException($"{configKey} is not valid base64.", ex);
        }
    }


}
