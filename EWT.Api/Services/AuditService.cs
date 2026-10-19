using System.Text.Json;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// Application-level audit trail. Records the real Entra user behind every
/// create/update/delete performed through the API (which connects as the shared
/// ENVR account). Additive and best-effort: it never blocks a data change, and
/// it does not touch any legacy table, trigger, or the EC_APP_AUDIT package.
/// </summary>
public interface IAuditService
{
    /// <summary>True when auditing is switched on (Audit:Enabled).</summary>
    bool Enabled { get; }

    /// <summary>When true, writes lacking an owner should be rejected by callers.</summary>
    bool RequireOwner { get; }

    /// <summary>
    /// Ensures the audit table/sequence exist in every configured instance
    /// (auto-creates in Dev/Test). Best-effort.
    /// </summary>
    Task EnsureSchemaAsync();

    /// <summary>
    /// Writes one audit row for a CRUD event, into the instance where the change
    /// was made. Best-effort — swallows failures.
    /// </summary>
    Task WriteAsync(
        string instance,
        string entityName,
        string operation,
        IReadOnlyDictionary<string, object?> pk,
        IReadOnlyDictionary<string, object?>? values,
        string? ownerUser,
        string? ownerDisplay);
}

public class AuditService : IAuditService
{
    private const string TableName = "EWT_API_AUDIT";
    private const string SeqName = "EWT_API_AUDIT_SEQ";
    private const int CommandTimeoutSeconds = 15;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented = false
    };

    private readonly OracleConnectionService _connectionService;
    private readonly ILogger<AuditService> _logger;
    private readonly bool _autoCreate;

    // Populated at startup by EnsureSchemaAsync, one entry per instance. An instance
    // absent or false here makes WriteAsync a no-op for that instance.
    private readonly Dictionary<string, bool> _available = new(StringComparer.OrdinalIgnoreCase);

    public bool Enabled { get; }
    public bool RequireOwner { get; }

    public AuditService(
        OracleConnectionService connectionService,
        IConfiguration configuration,
        ILogger<AuditService> logger)
    {
        _connectionService = connectionService;
        _logger = logger;
        Enabled = configuration.GetValue("Audit:Enabled", true);
        _autoCreate = configuration.GetValue("Audit:AutoCreate", false);
        RequireOwner = configuration.GetValue("Audit:RequireOwner", false);
    }

    public async Task EnsureSchemaAsync()
    {
        if (!Enabled)
        {
            _logger.LogInformation("Audit trail disabled (Audit:Enabled=false).");
            return;
        }

        // Every instance shares one Oracle account, so a credential failure on the first
        // is a credential failure on all of them. Stop immediately rather than spending
        // one failed login per instance and risking a FAILED_LOGIN_ATTEMPTS lockout.
        foreach (var instance in _connectionService.InstanceNames)
        {
            if (!await EnsureSchemaForInstanceAsync(instance))
            {
                _logger.LogError(
                    "Aborting audit schema checks after an authentication failure on {Instance}. " +
                    "The remaining instances were not contacted, to avoid locking the shared account. " +
                    "Fix the Oracle password and restart.", instance);
                return;
            }
        }

        var ready = _available.Count(kv => kv.Value);
        _logger.LogInformation(
            "Audit trail ready on {Ready} of {Total} instances.", ready, _available.Count);
    }

    /// <summary>
    /// Returns false only for an authentication failure, which means every other
    /// instance would fail the same way. Any other error is per-instance and returns true.
    /// </summary>
    private async Task<bool> EnsureSchemaForInstanceAsync(string instance)
    {
        try
        {
            await using var con = new OracleConnection(_connectionService.GetConnectionString(instance));
            await con.OpenAsync();

            bool exists;
            await using (var check = new OracleCommand(
                "SELECT COUNT(*) FROM user_tables WHERE table_name = :t", con))
            {
                check.Parameters.Add(new OracleParameter("t", TableName));
                exists = Convert.ToInt32(await check.ExecuteScalarAsync()) > 0;
            }

            if (exists)
            {
                _available[instance] = true;
                _logger.LogInformation(
                    "Audit trail ready on {Instance} ({Table} present).", instance, TableName);
                return true;
            }

            if (!_autoCreate)
            {
                _available[instance] = false;
                _logger.LogWarning(
                    "Audit table {Table} is missing on instance {Instance} and Audit:AutoCreate=false. Auditing is disabled there until the table is created (run docs/db/EWT_API_AUDIT.sql).",
                    TableName, instance);
                return true;
            }

            await ExecuteDdlAsync(con, $"CREATE SEQUENCE {SeqName} START WITH 1 INCREMENT BY 1 NOCACHE");
            await ExecuteDdlAsync(con,
                $@"CREATE TABLE {TableName} (
                    AUDIT_ID       NUMBER          NOT NULL,
                    ENTITY_NAME    VARCHAR2(128)   NOT NULL,
                    OPERATION      VARCHAR2(10)    NOT NULL,
                    OWNER_USER     VARCHAR2(256),
                    OWNER_DISPLAY  VARCHAR2(256),
                    DB_USER        VARCHAR2(128),
                    AUDIT_TS_UTC   TIMESTAMP       NOT NULL,
                    EVENT_JSON     CLOB,
                    CONSTRAINT EWT_API_AUDIT_PK PRIMARY KEY (AUDIT_ID)
                )");
            await ExecuteDdlAsync(con, $"CREATE INDEX EWT_API_AUDIT_IX1 ON {TableName} (ENTITY_NAME, AUDIT_TS_UTC)");
            await ExecuteDdlAsync(con, $"CREATE INDEX EWT_API_AUDIT_IX2 ON {TableName} (OWNER_USER, AUDIT_TS_UTC)");

            // Say on the table itself what it does and does not cover. The legacy Forms
            // application writes the same tables concurrently and leaves nothing here, so an
            // absent row means "not changed through the API", never "not changed". Issued
            // only on first creation, so this adds no DDL to a database that already has it.
            await ExecuteDdlAsync(con,
                $"COMMENT ON TABLE {TableName} IS 'API writes only. The legacy Forms "
                + "application writes these tables concurrently and is NOT represented here, "
                + "so this is not a complete change history.'");

            _available[instance] = true;
            _logger.LogInformation(
                "Auto-created audit table {Table} and sequence {Seq} on instance {Instance}.",
                TableName, SeqName, instance);
            return true;
        }
        catch (OracleException ex) when (ex.Number is 1017 or 28000)
        {
            // ORA-01017 invalid credentials / ORA-28000 account locked.
            _available[instance] = false;
            _logger.LogError(ex,
                "Authentication failed on instance {Instance} (ORA-{Code:00000}).", instance, ex.Number);
            return false;
        }
        catch (Exception ex)
        {
            _available[instance] = false;
            _logger.LogWarning(ex,
                "Could not ensure audit schema on instance {Instance}; auditing disabled there for this run (data operations are unaffected).",
                instance);
        }

        return true;
    }

    public async Task WriteAsync(
        string instance,
        string entityName,
        string operation,
        IReadOnlyDictionary<string, object?> pk,
        IReadOnlyDictionary<string, object?>? values,
        string? ownerUser,
        string? ownerDisplay)
    {
        if (!_available.TryGetValue(instance, out var ready) || !ready) return;

        try
        {
            var evt = new Dictionary<string, object?>
            {
                ["entity"] = entityName,
                ["operation"] = operation,
                ["pk"] = pk
            };
            if (values != null && values.Count > 0)
            {
                evt["values"] = values;
            }

            var json = JsonSerializer.Serialize(evt, JsonOpts);

            await using var con = new OracleConnection(_connectionService.GetConnectionString(instance));
            await con.OpenAsync();

            await using var cmd = new OracleCommand(
                $@"INSERT INTO {TableName}
                       (AUDIT_ID, ENTITY_NAME, OPERATION, OWNER_USER, OWNER_DISPLAY, DB_USER, AUDIT_TS_UTC, EVENT_JSON)
                   VALUES
                       ({SeqName}.NEXTVAL, :entity, :op, :owner, :display, USER, SYS_EXTRACT_UTC(SYSTIMESTAMP), :json)",
                con)
            { CommandTimeout = CommandTimeoutSeconds, BindByName = true };

            cmd.Parameters.Add(new OracleParameter("entity", entityName));
            cmd.Parameters.Add(new OracleParameter("op", operation));
            cmd.Parameters.Add(new OracleParameter("owner", (object?)ownerUser ?? DBNull.Value));
            cmd.Parameters.Add(new OracleParameter("display", (object?)ownerDisplay ?? DBNull.Value));
            cmd.Parameters.Add(new OracleParameter("json", OracleDbType.Clob) { Value = json });

            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            // Best-effort: the data change already succeeded; never surface an audit failure.
            _logger.LogWarning(ex, "Audit write failed for {Entity} {Op} on instance {Instance} (best-effort; data change preserved).", entityName, operation, instance);
        }
    }

    private async Task ExecuteDdlAsync(OracleConnection con, string ddl)
    {
        try
        {
            await using var cmd = new OracleCommand(ddl, con) { CommandTimeout = CommandTimeoutSeconds };
            await cmd.ExecuteNonQueryAsync();
        }
        catch (OracleException ex) when (ex.Number == 955) // ORA-00955: name already used by an existing object
        {
            _logger.LogDebug("Audit object already exists (ORA-00955); continuing.");
        }
    }
}
