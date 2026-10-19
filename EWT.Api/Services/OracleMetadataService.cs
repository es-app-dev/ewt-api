using System.Text.RegularExpressions;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// Discovers table and column metadata from Oracle data dictionary.
/// </summary>
public class OracleMetadataService
{
    private readonly OracleConnectionService _connectionService;
    private readonly ILogger<OracleMetadataService> _logger;

    public OracleMetadataService(OracleConnectionService connectionService, ILogger<OracleMetadataService> logger)
    {
        _connectionService = connectionService;
        _logger = logger;
    }

    /// <summary>
    /// Gets all tables and views accessible to the current user.
    /// </summary>
    public async Task<List<TableMetadata>> GetTablesAsync(string instance, string? schemaFilter = null)
    {
        var tables = new List<TableMetadata>();

        // ALL_TAB_COLUMNS already includes view columns, and SELECT works the same
        // against either object type, so we treat views as read-only "tables" here.
        var sql = @"
            SELECT OWNER, TABLE_NAME, OBJECT_TYPE FROM (
                SELECT OWNER, TABLE_NAME, 'TABLE' AS OBJECT_TYPE
                FROM ALL_TABLES
                WHERE OWNER = NVL(:schemaFilter, USER)
                UNION ALL
                SELECT OWNER, VIEW_NAME AS TABLE_NAME, 'VIEW' AS OBJECT_TYPE
                FROM ALL_VIEWS
                WHERE OWNER = NVL(:schemaFilter, USER)
            )
            WHERE TABLE_NAME <> 'EWT_API_AUDIT'
            ORDER BY TABLE_NAME";

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        await using var command = new OracleCommand(sql, connection);
        command.BindByName = true;
        command.Parameters.Add(new OracleParameter("schemaFilter", schemaFilter ?? (object)DBNull.Value));

        var tableCount = 0;
        var viewCount = 0;
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var objectType = reader.GetString(2);
            tables.Add(new TableMetadata
            {
                Owner = reader.GetString(0),
                TableName = reader.GetString(1),
                ObjectType = objectType
            });
            if (objectType == "VIEW") viewCount++; else tableCount++;
        }

        _logger.LogInformation(
            "Discovered {TableCount} tables and {ViewCount} views in schema {Schema} on instance {Instance}",
            tableCount, viewCount, schemaFilter ?? "USER", instance);
        return tables;
    }

    /// <summary>
    /// Gets column metadata for a specific table.
    /// </summary>
    /// <summary>
    /// What Oracle will actually let us do to each view, per operation.
    ///
    /// The legacy forms insert and update through several views with no ON-INSERT trigger
    /// of their own, so Forms is issuing ordinary DML and it works in production. We cannot
    /// tell from a form dump what makes that legal, so we ask the database rather than keep
    /// an allowlist by hand.
    ///
    /// Insert, update and delete are asked separately because they genuinely differ: a
    /// join view is commonly updatable through its key-preserved table while refusing
    /// inserts. Treating them as one flag would block screens that only edit.
    ///
    /// An INSTEAD OF trigger overrides all of it, since the trigger body decides.
    /// </summary>
    public async Task<Dictionary<string, ViewCapability>> GetViewCapabilitiesAsync(
        string instance, string? schemaFilter = null)
    {
        var capabilities = new Dictionary<string, ViewCapability>(StringComparer.OrdinalIgnoreCase);

        const string sql = @"
            SELECT u.TABLE_NAME,
                   MAX(CASE WHEN u.INSERTABLE = 'YES' THEN 1 ELSE 0 END) AS CAN_INSERT,
                   MAX(CASE WHEN u.UPDATABLE  = 'YES' THEN 1 ELSE 0 END) AS CAN_UPDATE,
                   MAX(CASE WHEN u.DELETABLE  = 'YES' THEN 1 ELSE 0 END) AS CAN_DELETE
            FROM ALL_UPDATABLE_COLUMNS u
            JOIN ALL_VIEWS v ON v.OWNER = u.OWNER AND v.VIEW_NAME = u.TABLE_NAME
            WHERE u.OWNER = NVL(:schemaFilter, USER)
            GROUP BY u.TABLE_NAME";

        const string triggerSql = @"
            SELECT DISTINCT t.TABLE_NAME, t.TRIGGERING_EVENT
            FROM ALL_TRIGGERS t
            JOIN ALL_VIEWS v ON v.OWNER = t.TABLE_OWNER AND v.VIEW_NAME = t.TABLE_NAME
            WHERE t.TABLE_OWNER = NVL(:schemaFilter, USER)
              AND t.TRIGGER_TYPE LIKE 'INSTEAD OF%'
              AND t.STATUS = 'ENABLED'";

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        await using (var command = new OracleCommand(sql, connection) { BindByName = true })
        {
            command.Parameters.Add(new OracleParameter("schemaFilter", (object?)schemaFilter ?? DBNull.Value));
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                capabilities[reader.GetString(0)] = new ViewCapability
                {
                    CanInsert = reader.GetInt32(1) == 1,
                    CanUpdate = reader.GetInt32(2) == 1,
                    CanDelete = reader.GetInt32(3) == 1
                };
            }
        }

        await using (var command = new OracleCommand(triggerSql, connection) { BindByName = true })
        {
            command.Parameters.Add(new OracleParameter("schemaFilter", (object?)schemaFilter ?? DBNull.Value));
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var view = reader.GetString(0);
                // TRIGGERING_EVENT is like "INSERT OR UPDATE OR DELETE".
                var events = reader.IsDBNull(1) ? "" : reader.GetString(1).ToUpperInvariant();

                if (!capabilities.TryGetValue(view, out var capability))
                {
                    capability = new ViewCapability();
                    capabilities[view] = capability;
                }

                capability.HasInsteadOfTrigger = true;
                if (events.Contains("INSERT")) capability.CanInsert = true;
                if (events.Contains("UPDATE")) capability.CanUpdate = true;
                if (events.Contains("DELETE")) capability.CanDelete = true;
            }
        }

        return capabilities;
    }

    public async Task<List<ColumnMetadata>> GetColumnsAsync(string instance, string tableName, string? owner = null)
    {
        var columns = new List<ColumnMetadata>();

        var sql = @"
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                DATA_LENGTH,
                DATA_PRECISION,
                DATA_SCALE,
                NULLABLE,
                COLUMN_ID
            FROM ALL_TAB_COLUMNS
            WHERE TABLE_NAME = :tableName
              AND OWNER = NVL(:owner, USER)
            ORDER BY COLUMN_ID";

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        await using var command = new OracleCommand(sql, connection);
        command.Parameters.Add(new OracleParameter("tableName", tableName.ToUpperInvariant()));
        command.Parameters.Add(new OracleParameter("owner", owner ?? (object)DBNull.Value));

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            columns.Add(new ColumnMetadata
            {
                ColumnName = reader.GetString(0),
                DataType = reader.GetString(1),
                DataLength = reader.IsDBNull(2) ? null : reader.GetInt32(2),
                DataPrecision = reader.IsDBNull(3) ? null : reader.GetInt32(3),
                DataScale = reader.IsDBNull(4) ? null : reader.GetInt32(4),
                IsNullable = reader.GetString(5) == "Y",
                ColumnId = reader.GetInt32(6)
            });
        }

        _logger.LogDebug("Discovered {Count} columns for table {Table}", columns.Count, tableName);
        return columns;
    }

    /// <summary>
    /// Gets primary key columns for a table.
    /// </summary>
    public async Task<List<string>> GetPrimaryKeyColumnsAsync(string instance, string tableName, string? owner = null)
    {
        var pkColumns = new List<string>();

        var sql = @"
            SELECT cc.COLUMN_NAME
            FROM ALL_CONSTRAINTS c
            JOIN ALL_CONS_COLUMNS cc ON c.CONSTRAINT_NAME = cc.CONSTRAINT_NAME 
                AND c.OWNER = cc.OWNER
            WHERE c.TABLE_NAME = :tableName
              AND c.OWNER = NVL(:owner, USER)
              AND c.CONSTRAINT_TYPE = 'P'
            ORDER BY cc.POSITION";

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        await using var command = new OracleCommand(sql, connection);
        command.Parameters.Add(new OracleParameter("tableName", tableName.ToUpperInvariant()));
        command.Parameters.Add(new OracleParameter("owner", owner ?? (object)DBNull.Value));

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            pkColumns.Add(reader.GetString(0));
        }

        return pkColumns;
    }

    /// <summary>
    /// Gets complete metadata for all tables and views including columns and primary keys.
    /// Views are read-only and have no primary key.
    /// </summary>
    /// <summary>
    /// Unique constraints and unique indexes for one table, best first.
    ///
    /// These are how a row is addressed on the 27 bound tables that declare no primary key:
    /// this schema often enforces uniqueness with an index and never declares the key. The
    /// shipped cache files carry them because the Python generator reads them out of the
    /// research dump, but a refresh from Oracle has to read them too. Without this, running
    /// /admin/refresh-cache silently drops every unique key for that instance and the
    /// no-primary-key error stops telling callers which columns to filter on.
    ///
    /// A constraint and its enforcing index usually share a name, so index entries whose
    /// column set a constraint already covers are skipped.
    /// </summary>
    public async Task<List<UniqueKeyMetadata>> GetUniqueKeysAsync(
        string instance, string tableName, string? owner = null)
    {
        var keys = new List<UniqueKeyMetadata>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        const string constraintSql = @"
            SELECT c.CONSTRAINT_NAME, cc.COLUMN_NAME
            FROM ALL_CONSTRAINTS c
            JOIN ALL_CONS_COLUMNS cc ON c.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
                AND c.OWNER = cc.OWNER
            WHERE c.TABLE_NAME = :tableName
              AND c.OWNER = NVL(:owner, USER)
              AND c.CONSTRAINT_TYPE = 'U'
              AND c.STATUS = 'ENABLED'
            ORDER BY c.CONSTRAINT_NAME, cc.POSITION";

        const string indexSql = @"
            SELECT i.INDEX_NAME, ic.COLUMN_NAME
            FROM ALL_INDEXES i
            JOIN ALL_IND_COLUMNS ic ON i.INDEX_NAME = ic.INDEX_NAME
                AND i.OWNER = ic.INDEX_OWNER
            WHERE i.TABLE_NAME = :tableName
              AND i.OWNER = NVL(:owner, USER)
              AND i.UNIQUENESS = 'UNIQUE'
            ORDER BY i.INDEX_NAME, ic.COLUMN_POSITION";

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        foreach (var (sql, source) in new[] { (constraintSql, "constraint"), (indexSql, "index") })
        {
            var grouped = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            var order = new List<string>();

            await using var command = new OracleCommand(sql, connection);
            command.Parameters.Add(new OracleParameter("tableName", tableName.ToUpperInvariant()));
            command.Parameters.Add(new OracleParameter("owner", owner ?? (object)DBNull.Value));

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var name = reader.GetString(0);
                if (!grouped.TryGetValue(name, out var columns))
                {
                    grouped[name] = columns = new List<string>();
                    order.Add(name);
                }
                columns.Add(reader.GetString(1));
            }

            foreach (var name in order)
            {
                var columns = grouped[name];
                var signature = string.Join(",", columns).ToUpperInvariant();
                if (!seen.Add(signature))
                {
                    continue;   // a constraint already covers these columns
                }

                keys.Add(new UniqueKeyMetadata
                {
                    Name = name,
                    Columns = columns,
                    Source = source
                });
            }
        }

        return keys;
    }

    /// <summary>
    /// Entities a daughter reaches through a synonym over a database link.
    ///
    /// The catalogue asks ALL_TABLES and ALL_VIEWS. A synonym is neither, so an object the
    /// application reaches perfectly well by name was invisible, and the table looked
    /// CORP-only when it is not. That produced a real defect: a screen signed in to BCTN was
    /// told AT_AGT_MEDIA_CATEGORIES lived only on CORP, so it wrote there, and the legacy
    /// screen on BCTN never showed the row.
    ///
    /// 145 such synonyms exist on each daughter and none on CORP, which is the shape to
    /// expect: CORP owns this master data and the daughters reach it by link.
    ///
    /// Local synonyms are deliberately excluded. 1,215 of them point at procedures,
    /// functions, sequences and packages rather than tables, and the two that alias a local
    /// table are already catalogued under the table's own name.
    ///
    /// Column and key metadata is read from the dictionary ON THE OTHER SIDE of the link,
    /// batched to one pair of queries per link, because that is the definition a caller will
    /// actually be querying.
    /// </summary>
    public async Task<Dictionary<string, EntityMetadata>> GetLinkedSynonymsAsync(
        string instance, string? schemaFilter = null)
    {
        var result = new Dictionary<string, EntityMetadata>(StringComparer.OrdinalIgnoreCase);

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        const string discoverSql = @"
            SELECT s.SYNONYM_NAME, s.TABLE_OWNER, s.TABLE_NAME, s.DB_LINK
            FROM ALL_SYNONYMS s
            WHERE s.OWNER IN ('PUBLIC', USER)
              AND NVL(s.TABLE_OWNER, NVL(:schemaFilter, USER)) = NVL(:schemaFilter, USER)
              AND s.DB_LINK IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM ALL_TABLES t
                               WHERE t.OWNER = USER AND t.TABLE_NAME = s.SYNONYM_NAME)
              AND NOT EXISTS (SELECT 1 FROM ALL_VIEWS v
                               WHERE v.OWNER = USER AND v.VIEW_NAME = s.SYNONYM_NAME)
            ORDER BY s.SYNONYM_NAME";

        var synonyms = new List<LinkedSynonym>();
        await using (var command = new OracleCommand(discoverSql, connection) { BindByName = true })
        {
            command.Parameters.Add(new OracleParameter("schemaFilter", (object?)schemaFilter ?? DBNull.Value));
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                // TABLE_OWNER can be null: AT_CONTRACT_SHIPPING_LOCS is defined without one.
                // It still resolves, because an unqualified target lands in whatever schema
                // the link connects as, which here is the same schema. Treat it as that.
                synonyms.Add(new LinkedSynonym(
                    reader.GetString(0),
                    reader.IsDBNull(1) ? (schemaFilter ?? "ACCUTRACK") : reader.GetString(1),
                    reader.GetString(2),
                    reader.GetString(3)));
            }
        }

        if (synonyms.Count == 0)
        {
            return result;
        }

        foreach (var group in synonyms.GroupBy(x => x.Link, StringComparer.OrdinalIgnoreCase))
        {
            // The link name comes from the data dictionary, never from a request, but it is
            // interpolated into SQL so it is validated anyway.
            if (!Regex.IsMatch(group.Key, @"^[A-Za-z][A-Za-z0-9_$#.]{0,127}$"))
            {
                _logger.LogWarning(
                    "{Instance}: skipping synonyms over link '{Link}': not a plain identifier",
                    instance, group.Key);
                continue;
            }

            try
            {
                await LoadOverLinkAsync(connection, instance, group.Key, group.ToList(), result);
            }
            catch (OracleException ex)
            {
                _logger.LogWarning(
                    "{Instance}: could not read the dictionary over link {Link} (ORA-{Number:00000}); "
                    + "{Count} synonym(s) left out of the catalogue",
                    instance, group.Key, ex.Number, group.Count());
            }
        }

        return result;
    }

    private async Task LoadOverLinkAsync(
        OracleConnection connection,
        string instance,
        string link,
        List<LinkedSynonym> synonyms,
        Dictionary<string, EntityMetadata> into)
    {
        var owner = synonyms[0].TargetOwner;
        var wanted = synonyms.Select(s => s.TargetTable)
            .Distinct(StringComparer.OrdinalIgnoreCase).ToList();

        var columns = new Dictionary<string, List<ColumnMetadata>>(StringComparer.OrdinalIgnoreCase);
        var keys = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);

        foreach (var chunk in wanted.Chunk(900))
        {
            var binds = string.Join(", ", chunk.Select((_, i) => $":t{i}"));

            var columnSql = $@"
                SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, DATA_PRECISION,
                       DATA_SCALE, NULLABLE, COLUMN_ID
                FROM ALL_TAB_COLUMNS@{link}
                WHERE OWNER = :owner AND TABLE_NAME IN ({binds})
                ORDER BY TABLE_NAME, COLUMN_ID";

            await using (var command = new OracleCommand(columnSql, connection) { BindByName = true })
            {
                command.Parameters.Add(new OracleParameter("owner", owner));
                for (var i = 0; i < chunk.Length; i++)
                {
                    command.Parameters.Add(new OracleParameter($"t{i}", chunk[i]));
                }

                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    var table = reader.GetString(0);
                    if (!columns.TryGetValue(table, out var list))
                    {
                        columns[table] = list = new List<ColumnMetadata>();
                    }
                    list.Add(new ColumnMetadata
                    {
                        ColumnName = reader.GetString(1),
                        DataType = reader.GetString(2),
                        DataLength = reader.IsDBNull(3) ? null : Convert.ToInt32(reader.GetValue(3)),
                        DataPrecision = reader.IsDBNull(4) ? null : Convert.ToInt32(reader.GetValue(4)),
                        DataScale = reader.IsDBNull(5) ? null : Convert.ToInt32(reader.GetValue(5)),
                        IsNullable = reader.GetString(6) == "Y",
                        ColumnId = reader.IsDBNull(7) ? 0 : Convert.ToInt32(reader.GetValue(7))
                    });
                }
            }

            var keySql = $@"
                SELECT cc.TABLE_NAME, cc.COLUMN_NAME
                FROM ALL_CONSTRAINTS@{link} c
                JOIN ALL_CONS_COLUMNS@{link} cc
                     ON c.CONSTRAINT_NAME = cc.CONSTRAINT_NAME AND c.OWNER = cc.OWNER
                WHERE c.OWNER = :owner AND c.CONSTRAINT_TYPE = 'P'
                  AND cc.TABLE_NAME IN ({binds})
                ORDER BY cc.TABLE_NAME, cc.POSITION";

            await using (var command = new OracleCommand(keySql, connection) { BindByName = true })
            {
                command.Parameters.Add(new OracleParameter("owner", owner));
                for (var i = 0; i < chunk.Length; i++)
                {
                    command.Parameters.Add(new OracleParameter($"t{i}", chunk[i]));
                }

                await using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    var table = reader.GetString(0);
                    if (!keys.TryGetValue(table, out var list))
                    {
                        keys[table] = list = new List<string>();
                    }
                    list.Add(reader.GetString(1));
                }
            }
        }

        var loaded = 0;
        foreach (var synonym in synonyms)
        {
            if (!columns.TryGetValue(synonym.TargetTable, out var cols) || cols.Count == 0)
            {
                continue;   // nothing readable on the other side
            }

            into[synonym.Name] = new EntityMetadata
            {
                TableName = synonym.Name,
                Owner = synonym.TargetOwner,
                Columns = cols,
                PrimaryKeyColumns = keys.TryGetValue(synonym.TargetTable, out var pk)
                    ? pk
                    : new List<string>(),
                IsView = false,
                ResolvesVia = "synonym",
                ResolvesTo = $"{synonym.TargetOwner}.{synonym.TargetTable}@{synonym.Link}"
            };
            loaded++;
        }

        _logger.LogInformation(
            "{Instance}: {Loaded} of {Total} entities reached through synonyms over {Link}",
            instance, loaded, synonyms.Count, link);
    }

    public async Task<Dictionary<string, EntityMetadata>> GetFullMetadataAsync(string instance, string? schemaFilter = null)
    {
        var result = new Dictionary<string, EntityMetadata>(StringComparer.OrdinalIgnoreCase);

        var tables = await GetTablesAsync(instance, schemaFilter);
        
        foreach (var table in tables)
        {
            var columns = await GetColumnsAsync(instance, table.TableName, table.Owner);
            var isView = string.Equals(table.ObjectType, "VIEW", StringComparison.OrdinalIgnoreCase);
            var pkColumns = isView
                ? new List<string>()
                : await GetPrimaryKeyColumnsAsync(instance, table.TableName, table.Owner);

            result[table.TableName] = new EntityMetadata
            {
                TableName = table.TableName,
                Owner = table.Owner,
                Columns = columns,
                PrimaryKeyColumns = pkColumns,
                // A view has no unique keys to speak of, and asking for 400 of them per
                // instance would triple the cost of a refresh for nothing.
                UniqueKeys = isView
                    ? new List<UniqueKeyMetadata>()
                    : await GetUniqueKeysAsync(instance, table.TableName, table.Owner),
                IsView = isView
            };
        }

        return result;
    }
}

/// <summary>A synonym that resolves over a database link to a table in another database.</summary>
public record LinkedSynonym(string Name, string TargetOwner, string TargetTable, string Link);

public class TableMetadata
{
    public required string Owner { get; set; }
    public required string TableName { get; set; }
    public string ObjectType { get; set; } = "TABLE";
}

public class ColumnMetadata
{
    public required string ColumnName { get; set; }
    public required string DataType { get; set; }
    public int? DataLength { get; set; }
    public int? DataPrecision { get; set; }
    public int? DataScale { get; set; }
    public bool IsNullable { get; set; }
    public int ColumnId { get; set; }
}

public class EntityMetadata
{
    public required string TableName { get; set; }
    public required string Owner { get; set; }
    public List<ColumnMetadata> Columns { get; set; } = new();
    public List<string> PrimaryKeyColumns { get; set; } = new();

    /// <summary>
    /// Unique constraints and unique indexes, best first.
    ///
    /// A schema this old often enforces uniqueness with an index and never declares the
    /// primary key. 27 of the 277 tables the UI binds are in that position, and for the 8
    /// that have one of these, it is the column set to address the row with. The other 19
    /// have nothing, which is why filter-addressed writes accept any columns rather than
    /// only a declared key.
    /// </summary>
    public List<UniqueKeyMetadata> UniqueKeys { get; set; } = new();

    /// <summary>
    /// True if this entity is backed by a view (no primary key).
    /// </summary>
    public bool IsView { get; set; }

    /// <summary>
    /// How this entity is reached: null when we own it, "synonym" when the name resolves
    /// through a synonym. A synonym-backed entity must be addressed by its bare name,
    /// because the owner-qualified form does not exist on this database.
    /// </summary>
    public string? ResolvesVia { get; set; }

    /// <summary>What the synonym points at, for reporting: OWNER.TABLE@LINK.</summary>
    public string? ResolvesTo { get; set; }

    /// <summary>True when SQL must use the bare name rather than OWNER.NAME.</summary>
    public bool UseBareName => ResolvesVia is not null;

    /// <summary>
    /// How this entity must be written in SQL on its own instance.
    ///
    /// An owned object is qualified with its schema. A synonym is NOT: on a daughter,
    /// ACCUTRACK.AT_CUSTOMERS does not exist, only the bare name does, and letting Oracle
    /// resolve it on the signed-in connection is the whole point. That is what a Forms
    /// session does, and it inherits the site's own view of where the data lives instead of
    /// the API forming a second opinion about it.
    /// </summary>
    public string SqlName => UseBareName
        ? $"\"{TableName}\""
        : $"\"{Owner}\".\"{TableName}\"";

    /// <summary>
    /// What Oracle will accept against this view, asked of the database at startup rather
    /// than kept in a list by hand. Null for a table, and null for every view when the
    /// check could not run, in which case the view stays read-only.
    /// </summary>
    public ViewCapability? ViewCapability { get; set; }

    /// <summary>True when this view accepts at least one kind of write.</summary>
    public bool IsWritableView => ViewCapability?.Any == true;
}

/// <summary>What Oracle will let us do to one view.</summary>
public class ViewCapability
{
    public bool CanInsert { get; set; }
    public bool CanUpdate { get; set; }
    public bool CanDelete { get; set; }

    /// <summary>An INSTEAD OF trigger decides, rather than key preservation.</summary>
    public bool HasInsteadOfTrigger { get; set; }

    public bool Any => CanInsert || CanUpdate || CanDelete;
}

/// <summary>A unique constraint or unique index, as a candidate row address.</summary>
public class UniqueKeyMetadata
{
    public required string Name { get; set; }
    public List<string> Columns { get; set; } = new();

    /// <summary>"constraint" when declared, "index" when only the index enforces it.</summary>
    public string Source { get; set; } = "constraint";
}
