using System.Data;
using System.Text.RegularExpressions;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace EWT.Api.Services;

/// <summary>
/// Executes dynamic CRUD operations against Oracle.
/// </summary>
public partial class DynamicDataService
{
    private const int WriteCommandTimeoutSeconds = 30;

    private readonly OracleConnectionService _connectionService;
    private readonly DynamicEdmModelBuilder _modelBuilder;
    private readonly SequenceService _sequences;
    private readonly ILogger<DynamicDataService> _logger;

    public DynamicDataService(
        OracleConnectionService connectionService,
        DynamicEdmModelBuilder modelBuilder,
        SequenceService sequences,
        ILogger<DynamicDataService> logger)
    {
        _connectionService = connectionService;
        _modelBuilder = modelBuilder;
        _sequences = sequences;
        _logger = logger;
    }

    /// <summary>
    /// Opens a connection for a write, unless the caller already has one. A $batch change
    /// set passes its own scope so every write in the set shares one transaction.
    /// </summary>
    private async Task<(OracleConnection Connection, bool Owned)> AcquireAsync(
        string instance, DbScope? scope)
    {
        if (scope is not null)
        {
            return (scope.Connection, false);
        }

        var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();
        return (connection, true);
    }

    /// <summary>
    /// Gets all records from a table.
    /// </summary>
    public async Task<List<Dictionary<string, object?>>> GetAllAsync(string instance, string tableName)
    {
        return await GetWithQueryAsync(instance, tableName, new QueryOptions());
    }

    /// <summary>
    /// Gets records with a raw SQL WHERE clause (used internally for $expand).
    /// </summary>
    public async Task<List<Dictionary<string, object?>>> GetWithFilterAsync(string instance, string tableName, string whereClause)
    {
        return await GetWithFilterAndSelectAsync(instance, tableName, whereClause, null);
    }

    /// <summary>
    /// Gets records with a raw SQL WHERE clause and optional column selection (used for $expand with nested $select).
    /// </summary>
    public async Task<List<Dictionary<string, object?>>> GetWithFilterAndSelectAsync(
        string instance,
        string tableName, 
        string whereClause, 
        string? selectColumns)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        
        string columns;
        if (!string.IsNullOrWhiteSpace(selectColumns))
        {
            var requestedColumns = selectColumns
                .Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(c => c.Trim().ToUpperInvariant())
                .ToList();

            var validColumnNames = metadata.Columns.Select(c => c.ColumnName.ToUpperInvariant()).ToHashSet();
            
            var joinColumn = whereClause.Split(' ')[0].Trim('"').ToUpperInvariant();
            if (!requestedColumns.Contains(joinColumn))
            {
                requestedColumns.Insert(0, joinColumn);
            }

            var validColumns = requestedColumns
                .Where(c => validColumnNames.Contains(c))
                .Select(c => $"\"{c}\"")
                .ToList();

            columns = validColumns.Count > 0 
                ? string.Join(", ", validColumns)
                : string.Join(", ", metadata.Columns.Select(c => $"\"{c.ColumnName}\""));
        }
        else
        {
            columns = string.Join(", ", metadata.Columns.Select(c => $"\"{c.ColumnName}\""));
        }
        
        var sql = $"SELECT {columns} FROM {metadata.SqlName} WHERE {whereClause}";
        
        _logger.LogDebug("Expand query: {Sql}", sql);
        return await ExecuteQueryAsync(instance, sql, metadata);
    }

    /// <summary>
    /// Gets records with query options ($select, $filter, $orderby, $top, $skip).
    /// </summary>
    public async Task<List<Dictionary<string, object?>>> GetWithQueryAsync(string instance, string tableName, QueryOptions options)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        var parameters = new List<OracleParameter>();
        var validColumnNames = metadata.Columns.Select(c => c.ColumnName.ToUpperInvariant()).ToHashSet();

        // Build SELECT clause with validation
        string columns;
        if (!string.IsNullOrWhiteSpace(options.Select))
        {
            var requestedColumns = options.Select
                .Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(c => c.Trim().ToUpperInvariant())
                .ToList();

            var invalidColumns = requestedColumns.Where(c => !validColumnNames.Contains(c)).ToList();
            if (invalidColumns.Count > 0)
            {
                throw new QueryValidationException(
                    $"Invalid column(s) in $select: {string.Join(", ", invalidColumns)}",
                    "select",
                    invalidColumns,
                    validColumnNames.OrderBy(c => c).ToList());
            }

            columns = string.Join(", ", requestedColumns.Select(c => $"\"{c}\""));
        }
        else
        {
            columns = string.Join(", ", metadata.Columns.Select(c => $"\"{c.ColumnName}\""));
        }

        // Build WHERE clause from the named block WHERE and $filter. Forms ANDed the block's
        // clause onto every query of the block, so a $filter narrows within it and can never
        // widen past it.
        var predicates = new List<string>();

        if (options.BlockWhere is not null)
        {
            predicates.Add($"({options.BlockWhere.Sql})");
            parameters.AddRange(options.BlockWhere.CreateParameters());
        }

        if (!string.IsNullOrWhiteSpace(options.Filter))
        {
            predicates.Add($"({ParseFilter(options.Filter, metadata, parameters)})");
        }

        string whereClause = string.Join(" AND ", predicates);

        // Build ORDER BY clause.
        // Sentinel "$orderby=none" means: return rows in natural database order
        // (emit no ORDER BY at all). This lets callers reproduce the legacy Oracle
        // Forms behavior for blocks that had no OrderByClause. Any other value is
        // parsed/validated as normal; when nothing is supplied we keep the historical
        // "ORDER BY 1" default so existing consumers are unaffected.
        string orderByClause = "";
        bool naturalOrder = false;
        if (!string.IsNullOrWhiteSpace(options.OrderBy))
        {
            if (options.OrderBy.Trim().Equals("none", StringComparison.OrdinalIgnoreCase))
                naturalOrder = true;
            else
                orderByClause = ParseOrderBy(options.OrderBy, metadata);
        }

        // Build the query with Oracle paging
        var sql = $"SELECT {columns} FROM {metadata.SqlName}";
        
        if (!string.IsNullOrEmpty(whereClause))
            sql += $" WHERE {whereClause}";
        
        if (!string.IsNullOrEmpty(orderByClause))
            sql += $" ORDER BY {orderByClause}";
        else if (!naturalOrder)
            sql += $" ORDER BY 1";
        
        // Oracle 11g compatible paging using ROWNUM
        sql = $@"SELECT {columns} FROM (
            SELECT a.*, ROWNUM rnum FROM (
                {sql}
            ) a WHERE ROWNUM <= {options.Skip + options.Top}
        ) WHERE rnum > {options.Skip}";

        _logger.LogDebug("Executing query: {Sql}", sql);
        return await ExecuteQueryAsync(instance, sql, metadata, parameters);
    }

    /// <summary>
    /// Parses simple OData $filter expressions into Oracle WHERE clause.
    /// </summary>
    private string ParseFilter(string filter, EntityMetadata metadata, List<OracleParameter> parameters)
    {
        ValidateFilterSyntax(filter, metadata);
        
        var result = ConvertDateLiterals(filter);
        
        // Handle null comparisons FIRST
        result = Regex.Replace(result, @"(\w+)\s+eq\s+null\b", "\"$1\" IS NULL", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"(\w+)\s+ne\s+null\b", "\"$1\" IS NOT NULL", RegexOptions.IgnoreCase);
        
        // Replace OData operators with SQL
        result = Regex.Replace(result, @"\s+eq\s+", " = ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+ne\s+", " <> ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+gt\s+", " > ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+ge\s+", " >= ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+lt\s+", " < ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+le\s+", " <= ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+and\s+", " AND ", RegexOptions.IgnoreCase);
        result = Regex.Replace(result, @"\s+or\s+", " OR ", RegexOptions.IgnoreCase);
        
        // Handle LIKE operator — case-insensitive via UPPER() on both sides
        // Matches: COLUMN LIKE 'value' (with optional wildcards in the value)
        result = Regex.Replace(result,
            @"(\w+)\s+like\s+'([^']*)'",
            match =>
            {
                var column = match.Groups[1].Value.ToUpperInvariant();
                var value = match.Groups[2].Value.Replace("'", "''");
                return $"UPPER(\"{column}\") LIKE UPPER('{value}')";
            },
            RegexOptions.IgnoreCase);

        // Handle contains, startswith, endswith — also case-insensitive via UPPER()
        result = Regex.Replace(result, 
            @"contains\s*\(\s*(\w+)\s*,\s*'([^']+)'\s*\)", 
            match =>
            {
                var column = match.Groups[1].Value.ToUpperInvariant();
                var value = match.Groups[2].Value.Replace("'", "''");
                return $"UPPER(\"{column}\") LIKE UPPER('%{value}%')";
            }, 
            RegexOptions.IgnoreCase);

        result = Regex.Replace(result,
            @"startswith\s*\(\s*(\w+)\s*,\s*'([^']+)'\s*\)",
            match =>
            {
                var column = match.Groups[1].Value.ToUpperInvariant();
                var value = match.Groups[2].Value.Replace("'", "''");
                return $"UPPER(\"{column}\") LIKE UPPER('{value}%')";
            },
            RegexOptions.IgnoreCase);

        result = Regex.Replace(result,
            @"endswith\s*\(\s*(\w+)\s*,\s*'([^']+)'\s*\)",
            match =>
            {
                var column = match.Groups[1].Value.ToUpperInvariant();
                var value = match.Groups[2].Value.Replace("'", "''");
                return $"UPPER(\"{column}\") LIKE UPPER('%{value}')";
            },
            RegexOptions.IgnoreCase);

        // Extract string literals before column quoting to prevent
        // column names inside values from being double-quoted.
        // e.g. TYPE eq 'WASTETYPE' — WASTETYPE is a column AND a value.
        var literals = new List<string>();
        result = Regex.Replace(result, @"'([^']*)'", match =>
        {
            literals.Add(match.Value);
            return $"__LIT{literals.Count - 1}__";
        });

        // Quote column names (only matches outside string literals now)
        foreach (var column in metadata.Columns)
        {
            result = Regex.Replace(result, 
                $@"(?<!"")\b{Regex.Escape(column.ColumnName)}\b(?!"")", 
                $"\"{column.ColumnName}\"", 
                RegexOptions.IgnoreCase);
        }

        // Restore string literals
        for (int i = 0; i < literals.Count; i++)
        {
            result = result.Replace($"__LIT{i}__", literals[i]);
        }

        return result;
    }


    /// <summary>
    /// Rewrites ISO date literals into Oracle TO_DATE(...) calls so $filter can compare
    /// against DATE columns. Oracle will not implicitly convert '2024-09-16' to a DATE,
    /// and an unquoted 2024-09-16 is read as arithmetic, so both forms must be converted.
    /// Text inside single quotes is left alone: a genuine string value may look like a date.
    /// </summary>
    private static string ConvertDateLiterals(string input)
    {
        // datetime'...' is the OData v2 spelling; unwrap it to the bare form first.
        input = Regex.Replace(input, @"datetime'([^']+)'", "$1", RegexOptions.IgnoreCase);

        // Odd indices are quoted literals, which must pass through untouched.
        var parts = Regex.Split(input, @"('(?:[^']|'')*')");
        for (var i = 0; i < parts.Length; i++)
        {
            if (i % 2 == 1) continue;
            parts[i] = Regex.Replace(
                parts[i],
                @"\b(\d{4}-\d{2}-\d{2})(?:[T ](\d{2}:\d{2}(?::\d{2})?))?Z?\b",
                m =>
                {
                    var time = m.Groups[2].Success ? m.Groups[2].Value : "00:00:00";
                    if (time.Length == 5) time += ":00";
                    return $"TO_DATE('{m.Groups[1].Value} {time}','YYYY-MM-DD HH24:MI:SS')";
                });
        }
        return string.Concat(parts);
    }

    private void ValidateFilterSyntax(string filter, EntityMetadata metadata)
    {
        var errors = new List<string>();
        var suggestions = new List<string>();

        if (Regex.IsMatch(filter, @"\w+\s+(eq|ne|gt|ge|lt|le|like)\s+""[^""]*""", RegexOptions.IgnoreCase))
        {
            errors.Add("Use single quotes (') for string values, not double quotes (\")");
            suggestions.Add("Example: NAME like '%value%'");
        }

        if (Regex.IsMatch(filter, @"\w+\s*=\s*[^=]") && !filter.Contains(" eq "))
        {
            errors.Add("Use 'eq' for equality comparison, not '='");
            suggestions.Add("Example: STATUS eq 'ACTIVE'");
        }

        if (errors.Count > 0)
        {
            throw new FilterValidationException(filter, errors, suggestions);
        }
    }

    private string ParseOrderBy(string orderBy, EntityMetadata metadata)
    {
        var parts = orderBy.Split(',', StringSplitOptions.RemoveEmptyEntries);
        var orderClauses = new List<string>();

        foreach (var part in parts)
        {
            var trimmed = part.Trim();
            var tokens = trimmed.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var columnName = tokens[0].ToUpperInvariant();
            var direction = tokens.Length > 1 && tokens[1].Equals("desc", StringComparison.OrdinalIgnoreCase) ? "DESC" : "ASC";

            if (metadata.Columns.Any(c => c.ColumnName.Equals(columnName, StringComparison.OrdinalIgnoreCase)))
            {
                orderClauses.Add($"\"{columnName}\" {direction}");
            }
        }

        return orderClauses.Count > 0 ? string.Join(", ", orderClauses) : "";
    }

    /// <summary>
    /// Inserts a new record.
    /// </summary>
    public async Task<Dictionary<string, object?>> InsertAsync(
        string instance,
        string tableName,
        Dictionary<string, object?> values,
        DbScope? scope = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        EnsureWritable(metadata, WriteOperation.Insert);

        // Server-assigned key. The legacy forms did ":BLOCK.PK := SOME_SEQ.NEXTVAL" in
        // PRE-INSERT; a REST client should not have to. A key the client does send is left
        // alone, which keeps data migration and replayed rows working.
        //
        // The value is fetched with its own SELECT ... FROM DUAL rather than inlined into
        // the INSERT. Inlining is one fewer round trip and was the first implementation, but
        // 34 of these sequences are PUBLIC synonyms pointing over a database link to CORP,
        // and Oracle raises ORA-22816 for a RETURNING clause on an INSERT that draws from a
        // remote sequence. Fetching first works for local and remote alike, and since we
        // then know the value, that column needs no RETURNING at all.
        //
        // The map is the authority on what is safe to allocate, not a rule applied here.
        // Most entries are a sole primary key, but five are reviewed exceptions: four
        // tables that declare no primary key at all, and one component of a compound key.
        // Each was verified against every write in the 161 forms, and three lookalikes
        // were refused on measured evidence. See scripts/build-sequence-map.py.
        var assignment = _sequences.For(tableName);
        var assignedColumn = (string?)null;
        if (assignment is not null &&
            metadata.Columns.Any(c => c.ColumnName.Equals(assignment.Column, StringComparison.OrdinalIgnoreCase)) &&
            (!values.TryGetValue(assignment.Column, out var supplied) || supplied is null))
        {
            values.Remove(assignment.Column);   // drop an explicit null
            assignedColumn = assignment.Column;
        }

        var (connection, owned) = await AcquireAsync(instance, scope);
        try
        {
        if (assignedColumn is not null)
        {
            values[assignedColumn] = await NextSequenceValueAsync(
                connection, scope?.Transaction, assignment!.Sequence);
        }

        var columns = values.Keys.ToList();
        var columnList = string.Join(", ", columns.Select(c => $"\"{c}\""));
        var paramList = string.Join(", ", columns.Select((_, i) => $":p{i}"));

        var sql = $"INSERT INTO {metadata.SqlName} ({columnList}) VALUES ({paramList})";

        // Capture the primary key via RETURNING, so the caller gets the value the database
        // actually stored: the sequence above, a trigger, or what the client supplied.
        var pkColumns = metadata.PrimaryKeyColumns
            .Where(pk => metadata.Columns.Any(c => c.ColumnName.Equals(pk, StringComparison.OrdinalIgnoreCase)))
            .ToList();

        // A column we allocated ourselves is already known, so it must not be in RETURNING:
        // it is unnecessary, and on a remote sequence it is what triggers ORA-22816.
        if (assignedColumn is not null)
        {
            pkColumns.RemoveAll(c => c.Equals(assignedColumn, StringComparison.OrdinalIgnoreCase));
        }

        // RETURNING cannot be used when the target is remote. A synonym-backed entity lives
        // on the other side of a database link, so Oracle raises ORA-22816 for the whole
        // statement. We lose nothing that matters: a key we allocated ourselves is already
        // known, because NEXTVAL is fetched separately, and a key the client supplied is in
        // the request. Only a trigger-assigned value on a remote table is unrecoverable, and
        // none of these tables has one.
        var canUseReturning = !metadata.UseBareName;

        var returnParams = new List<(string Column, OracleParameter Param)>();
        if (pkColumns.Count > 0 && canUseReturning)
        {
            var retCols = string.Join(", ", pkColumns.Select(c => $"\"{c}\""));
            var retInto = string.Join(", ", pkColumns.Select((_, i) => $":ret{i}"));
            sql += $" RETURNING {retCols} INTO {retInto}";

            for (int i = 0; i < pkColumns.Count; i++)
            {
                var colMeta = metadata.Columns.First(c => c.ColumnName.Equals(pkColumns[i], StringComparison.OrdinalIgnoreCase));
                var odt = MapToOracleDbType(colMeta.DataType);
                var p = new OracleParameter($"ret{i}", odt) { Direction = ParameterDirection.Output };
                if (odt is OracleDbType.Varchar2 or OracleDbType.NVarchar2 or OracleDbType.Char or OracleDbType.NChar)
                {
                    p.Size = colMeta.DataLength ?? 4000;
                }
                returnParams.Add((pkColumns[i], p));
            }
        }

            await using var command = new OracleCommand(sql, connection) { CommandTimeout = WriteCommandTimeoutSeconds, BindByName = true };
            if (scope is not null)
            {
                command.Transaction = scope.Transaction;
            }

            for (int i = 0; i < columns.Count; i++)
            {
                command.Parameters.Add(new OracleParameter($"p{i}", values[columns[i]] ?? DBNull.Value));
            }
            foreach (var (_, p) in returnParams)
            {
                command.Parameters.Add(p);
            }

            var rowsAffected = await command.ExecuteNonQueryAsync();
            _logger.LogInformation("Inserted {Rows} row(s) into {Table}{Assigned}", rowsAffected, tableName,
                assignedColumn is null ? "" : $" ({assignedColumn} from {assignment!.Sequence})");

            // Merge any RETURNING'd key values into the result (also surfaces the new PK to the caller).
            var result = new Dictionary<string, object?>(values);
            foreach (var (column, p) in returnParams)
            {
                result[column] = NormalizeOracleValue(p.Value);
            }
            return result;
        }
        finally
        {
            if (owned)
            {
                await connection.DisposeAsync();
            }
        }
    }

    /// <summary>
    /// Allocates the next value from a sequence, on the caller's connection and inside the
    /// caller's transaction when there is one.
    ///
    /// The name is interpolated because NEXTVAL cannot take a bind variable. It comes from
    /// sequences.json, which SequenceService validates as a plain Oracle identifier on load,
    /// so nothing from a request reaches this string.
    ///
    /// 34 of these names are PUBLIC synonyms carrying a database link to CORP, which is how
    /// the legacy application keeps container and manifest ids unique across all seven
    /// databases. Oracle resolves that transparently, so this works unchanged whether the
    /// allocator is local or central. A sequence value consumed by a statement that later
    /// rolls back is simply skipped, which is normal and is what Forms did too.
    /// </summary>
    private static async Task<object?> NextSequenceValueAsync(
        OracleConnection connection,
        OracleTransaction? transaction,
        string sequenceName)
    {
        await using var command = new OracleCommand(
            $"SELECT {sequenceName}.NEXTVAL FROM DUAL", connection)
        {
            CommandTimeout = WriteCommandTimeoutSeconds
        };
        if (transaction is not null)
        {
            command.Transaction = transaction;
        }

        return NormalizeOracleValue(await command.ExecuteScalarAsync());
    }

    /// <summary>
    /// Converts an ODP.NET provider value (from an output parameter) into a plain CLR value.
    /// </summary>
    private static object? NormalizeOracleValue(object? v)
    {
        if (v == null || v == DBNull.Value) return null;
        switch (v)
        {
            case OracleDecimal d:
                if (d.IsNull) return null;
                var dec = d.Value;
                return dec == Math.Floor(dec) && dec >= long.MinValue && dec <= long.MaxValue
                    ? (object)(long)dec
                    : dec;
            case OracleString s: return s.IsNull ? null : s.Value;
            case OracleClob c: return c.IsNull ? null : c.Value;
            case OracleDate od: return od.IsNull ? null : od.Value;
            case OracleTimeStamp ts: return ts.IsNull ? null : ts.Value;
            default: return v;
        }
    }

    /// <summary>
    /// Updates an existing record.
    /// </summary>
    public async Task<int> UpdateAsync(string instance, string tableName, Dictionary<string, object> keyValues, Dictionary<string, object?> values, DbScope? scope = null, string? ifMatch = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        EnsureWritable(metadata, WriteOperation.Update);

        // Build column lookup for type information
        var columnTypes = metadata.Columns.ToDictionary(c => c.ColumnName, c => c.DataType, StringComparer.OrdinalIgnoreCase);
        
        var setClause = string.Join(", ", values.Keys.Select((k, i) => $"\"{k}\" = :set{i}"));
        var whereClause = BuildWhereClause(keyValues, out var whereParams, "key");

        // Same predicate, separate parameter objects: a lock probe runs as its own statement
        // and an OracleParameter belongs to one command. The probe omits any If-Match, so
        // "locked by someone" and "changed underneath you" stay distinguishable.
        var lockWhere = BuildWhereClause(keyValues, out var lockParams, "lk");

        if (!string.IsNullOrWhiteSpace(ifMatch))
        {
            whereClause = AppendConcurrencyPredicate(whereClause, metadata, ifMatch, whereParams);
        }

        var sql = $"UPDATE {metadata.SqlName} SET {setClause} WHERE {whereClause}";

        _logger.LogDebug("Update SQL: {Sql}", sql);
        _logger.LogDebug("Update values: {Values}", string.Join(", ", values.Select(kvp => $"{kvp.Key}={kvp.Value ?? "NULL"}")));

        var (connection, owned) = await AcquireAsync(instance, scope);
        OracleTransaction? localTransaction = null;
        try
        {
        // A lock only lasts as long as the transaction holding it, so a standalone write
        // needs one of its own for the probe to mean anything.
        if (owned)
        {
            localTransaction = connection.BeginTransaction();
        }
        var activeTransaction = scope?.Transaction ?? localTransaction;

        await AcquireRowLockAsync(connection, activeTransaction, metadata, lockWhere, lockParams);

        await using var command = new OracleCommand(sql, connection) { CommandTimeout = WriteCommandTimeoutSeconds };
        command.Transaction = activeTransaction;
        
        var keys = values.Keys.ToList();
        for (int i = 0; i < keys.Count; i++)
        {
            var columnName = keys[i];
            var value = values[columnName];
            var param = new OracleParameter($"set{i}", value ?? DBNull.Value);
            
            if (value == null && columnTypes.TryGetValue(columnName, out var dataType))
            {
                param.OracleDbType = MapToOracleDbType(dataType);
            }
            
            command.Parameters.Add(param);
        }
        
        foreach (var param in whereParams)
        {
            command.Parameters.Add(param);
        }

        var rowsAffected = await command.ExecuteNonQueryAsync();
        _logger.LogInformation("Updated {Rows} row(s) in {Table}", rowsAffected, tableName);

        // A guarded write that touched nothing either lost a race or addressed a row that
        // is gone. Read it back to say which, rather than reporting a bare 404.
        if (rowsAffected == 0 && !string.IsNullOrWhiteSpace(ifMatch))
        {
            localTransaction?.Rollback();
            var current = await FindByKeyAsync(instance, tableName, keyValues);
            if (current != null)
            {
                throw new RowChangedException(tableName, current);
            }
            return rowsAffected;
        }

        localTransaction?.Commit();
        return rowsAffected;
        }
        catch
        {
            try { localTransaction?.Rollback(); } catch { /* already gone */ }
            throw;
        }
        finally
        {
            localTransaction?.Dispose();
            if (owned)
            {
                await connection.DisposeAsync();
            }
        }
    }

    private static OracleDbType MapToOracleDbType(string dataType)
    {
        var upper = dataType.ToUpperInvariant();
        if (upper.StartsWith("TIMESTAMP")) return OracleDbType.TimeStamp;
        
        return upper switch
        {
            "VARCHAR2" => OracleDbType.Varchar2,
            "NVARCHAR2" => OracleDbType.NVarchar2,
            "CHAR" => OracleDbType.Char,
            "NCHAR" => OracleDbType.NChar,
            "NUMBER" => OracleDbType.Decimal,
            "INTEGER" => OracleDbType.Int32,
            "FLOAT" => OracleDbType.Double,
            "DATE" => OracleDbType.Date,
            "CLOB" => OracleDbType.Clob,
            "NCLOB" => OracleDbType.NClob,
            "BLOB" => OracleDbType.Blob,
            "RAW" => OracleDbType.Raw,
            "LONG" => OracleDbType.Long,
            _ => OracleDbType.Varchar2
        };
    }

    /// <summary>
    /// Deletes a record by primary key.
    /// </summary>
    public async Task<int> DeleteAsync(string instance, string tableName, Dictionary<string, object> keyValues, DbScope? scope = null, string? ifMatch = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        EnsureWritable(metadata, WriteOperation.Delete);

        var whereClause = BuildWhereClause(keyValues, out var parameters);
        var lockWhere = BuildWhereClause(keyValues, out var lockParams, "lk");

        if (!string.IsNullOrWhiteSpace(ifMatch))
        {
            whereClause = AppendConcurrencyPredicate(whereClause, metadata, ifMatch, parameters);
        }

        var sql = $"DELETE FROM {metadata.SqlName} WHERE {whereClause}";

        var (connection, owned) = await AcquireAsync(instance, scope);
        OracleTransaction? localTransaction = null;
        try
        {
            if (owned)
            {
                localTransaction = connection.BeginTransaction();
            }
            var activeTransaction = scope?.Transaction ?? localTransaction;

            await AcquireRowLockAsync(connection, activeTransaction, metadata, lockWhere, lockParams);

            await using var command = new OracleCommand(sql, connection) { CommandTimeout = WriteCommandTimeoutSeconds };
            command.Transaction = activeTransaction;

            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }

            var rowsAffected = await command.ExecuteNonQueryAsync();
            _logger.LogInformation("Deleted {Rows} row(s) from {Table}", rowsAffected, tableName);

            if (rowsAffected == 0 && !string.IsNullOrWhiteSpace(ifMatch))
            {
                localTransaction?.Rollback();
                var current = await FindByKeyAsync(instance, tableName, keyValues);
                if (current != null)
                {
                    throw new RowChangedException(tableName, current);
                }
                return rowsAffected;
            }

            localTransaction?.Commit();
            return rowsAffected;
        }
        catch
        {
            try { localTransaction?.Rollback(); } catch { /* already gone */ }
            throw;
        }
        finally
        {
            localTransaction?.Dispose();
            if (owned)
            {
                await connection.DisposeAsync();
            }
        }
    }

    /// <summary>
    /// Row count for $count=true. Same table and same $filter as the page query, so the
    /// count always describes the set the caller is paging through.
    /// </summary>
    public async Task<long> CountAsync(
        string instance, string tableName, string? filter, ResolvedBlockWhere? blockWhere = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        var parameters = new List<OracleParameter>();

        // Same two predicates as the row query, so $count sizes the set the caller is paging.
        var predicates = new List<string>();

        if (blockWhere is not null)
        {
            predicates.Add($"({blockWhere.Sql})");
            parameters.AddRange(blockWhere.CreateParameters());
        }

        if (!string.IsNullOrWhiteSpace(filter))
        {
            predicates.Add($"({ParseFilter(filter, metadata, parameters)})");
        }

        var sql = $"SELECT COUNT(*) FROM {metadata.SqlName}";
        if (predicates.Count > 0)
        {
            sql += $" WHERE {string.Join(" AND ", predicates)}";
        }

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();
        await using var command = new OracleCommand(sql, connection) { BindByName = true };
        foreach (var param in parameters)
        {
            command.Parameters.Add(param);
        }

        var scalar = await command.ExecuteScalarAsync();
        return Convert.ToInt64(NormalizeOracleValue(scalar) ?? 0L);
    }

    /// <summary>
    /// Updates the single row matching an OData $filter, for the 27 bound tables that
    /// declare no primary key and so cannot be addressed by key.
    ///
    /// The count and the write are the same statement: the UPDATE runs, and if it did not
    /// touch exactly one row the transaction is rolled back and nothing changed. That is
    /// why there is no separate SELECT COUNT(*) first, which would race.
    /// </summary>
    public async Task<int> UpdateWhereAsync(
        string instance,
        string tableName,
        string filter,
        Dictionary<string, object?> values,
        DbScope? scope = null,
        string? ifMatch = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        EnsureWritable(metadata, WriteOperation.Update);

        var columnTypes = metadata.Columns.ToDictionary(c => c.ColumnName, c => c.DataType, StringComparer.OrdinalIgnoreCase);
        var parameters = new List<OracleParameter>();
        var where = ParseFilter(filter, metadata, parameters);

        if (!string.IsNullOrWhiteSpace(ifMatch))
        {
            where = AppendConcurrencyPredicate(where, metadata, ifMatch, parameters);
        }

        var setClause = string.Join(", ", values.Keys.Select((k, i) => $"\"{k}\" = :set{i}"));
        var sql = $"UPDATE {metadata.SqlName} SET {setClause} WHERE {where}";

        var lockParams = new List<OracleParameter>();
        var lockWhere = ParseFilter(filter, metadata, lockParams);

        return await ExecuteExactlyOneAsync(instance, tableName, sql, scope, ifMatch, filter,
            metadata, lockWhere, lockParams, command =>
        {
            var keys = values.Keys.ToList();
            for (int i = 0; i < keys.Count; i++)
            {
                var value = values[keys[i]];
                var param = new OracleParameter($"set{i}", value ?? DBNull.Value);
                if (value == null && columnTypes.TryGetValue(keys[i], out var dataType))
                {
                    param.OracleDbType = MapToOracleDbType(dataType);
                }
                command.Parameters.Add(param);
            }
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
        });
    }

    /// <summary>Deletes the single row matching an OData $filter. See UpdateWhereAsync.</summary>
    public async Task<int> DeleteWhereAsync(
        string instance,
        string tableName,
        string filter,
        DbScope? scope = null,
        string? ifMatch = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        EnsureWritable(metadata, WriteOperation.Delete);

        var parameters = new List<OracleParameter>();
        var where = ParseFilter(filter, metadata, parameters);

        if (!string.IsNullOrWhiteSpace(ifMatch))
        {
            where = AppendConcurrencyPredicate(where, metadata, ifMatch, parameters);
        }

        var sql = $"DELETE FROM {metadata.SqlName} WHERE {where}";

        var lockParams = new List<OracleParameter>();
        var lockWhere = ParseFilter(filter, metadata, lockParams);

        return await ExecuteExactlyOneAsync(instance, tableName, sql, scope, ifMatch, filter,
            metadata, lockWhere, lockParams, command =>
        {
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
        });
    }

    /// <summary>
    /// Runs a write that must affect exactly one row, and undoes it when it does not.
    ///
    /// Standing alone it uses its own transaction. Inside a $batch change set it uses the
    /// caller's, and throws instead of rolling back, so the whole change set unwinds.
    /// </summary>
    private async Task<int> ExecuteExactlyOneAsync(
        string instance,
        string tableName,
        string sql,
        DbScope? scope,
        string? ifMatch,
        string? filter,
        EntityMetadata metadata,
        string lockWhere,
        List<OracleParameter> lockParams,
        Action<OracleCommand> bind)
    {
        var (connection, owned) = await AcquireAsync(instance, scope);
        OracleTransaction? localTransaction = null;
        try
        {
            if (owned)
            {
                localTransaction = connection.BeginTransaction();
            }
            var activeTransaction = scope?.Transaction ?? localTransaction;

            await AcquireRowLockAsync(connection, activeTransaction, metadata, lockWhere, lockParams);

            await using var command = new OracleCommand(sql, connection) { CommandTimeout = WriteCommandTimeoutSeconds };
            command.Transaction = activeTransaction;
            bind(command);

            var rowsAffected = await command.ExecuteNonQueryAsync();
            if (rowsAffected != 1)
            {
                localTransaction?.Rollback();

                // A guarded write that matched nothing may have lost a race rather than
                // addressed a missing row. The filter alone tells the two apart.
                if (rowsAffected == 0 && !string.IsNullOrWhiteSpace(ifMatch)
                    && !string.IsNullOrWhiteSpace(filter))
                {
                    var current = await FindByFilterAsync(instance, tableName, filter);
                    if (current != null)
                    {
                        throw new RowChangedException(tableName, current);
                    }
                }

                throw new AmbiguousRowException(tableName, rowsAffected);
            }

            localTransaction?.Commit();
            _logger.LogInformation("Filter-addressed write affected 1 row in {Table}", tableName);
            return rowsAffected;
        }
        catch
        {
            try { localTransaction?.Rollback(); } catch { /* already rolled back or gone */ }
            throw;
        }
        finally
        {
            localTransaction?.Dispose();
            if (owned)
            {
                await connection.DisposeAsync();
            }
        }
    }

    private EntityMetadata GetEntityMetadata(string instance, string tableName)
    {
        var allMetadata = _modelBuilder.GetEntityMetadata(instance);
        if (!allMetadata.TryGetValue(tableName, out var metadata))
        {
            var suggestions = FindSimilarTableNames(tableName, allMetadata.Keys.ToList(), maxSuggestions: 5);
            throw new TableNotFoundException(tableName, suggestions);
        }
        return metadata;
    }

    /// <summary>
    /// Views held read-only whatever Oracle would permit.
    ///
    /// CP is CustomerPortal, which owns the waste profiles. The legacy AT1330 form writes
    /// to these and probably should not; that is an ownership decision nobody has made yet,
    /// so until they do, the safe default is to refuse.
    /// </summary>
    private static readonly HashSet<string> AlwaysReadOnly = new(StringComparer.OrdinalIgnoreCase)
    {
        "AT_CP_PROF_TS_REVIEW",
        "AT_CP_PROF_EE_REVIEW",
        "AT_CP_PROF_EE_REVIEW_NON_RCRA",
        "AT_CP_PROF_EE_REVIEW_RCRA",
        "AT_CP_PROF_RSO_REVIEW",
        "AT_CP_PROF_IH_REVIEW",
        "AT_CP_PROF_OPS_REVIEW",
    };

    /// <summary>
    /// Refuses a write the database would refuse anyway, with a reason the caller can act
    /// on, rather than letting it surface as an Oracle error at commit time.
    ///
    /// Insert, update and delete are checked separately because a join view is commonly
    /// updatable through its key-preserved table while refusing inserts. A single flag
    /// would block screens that only edit.
    /// </summary>
    private static void EnsureWritable(EntityMetadata metadata, WriteOperation operation)
    {
        if (!metadata.IsView)
        {
            return;
        }

        if (AlwaysReadOnly.Contains(metadata.TableName))
        {
            throw new ReadOnlyEntityException(metadata.TableName,
                "CustomerPortal owns this data. Writing to it from EWT has not been agreed, "
                + "so it is held read-only deliberately rather than by accident.");
        }

        var capability = metadata.ViewCapability;
        if (capability is null)
        {
            throw new ReadOnlyEntityException(metadata.TableName,
                "This is a view and the server could not establish what Oracle permits on it, "
                + "so it is treated as read-only.");
        }

        var permitted = operation switch
        {
            WriteOperation.Insert => capability.CanInsert,
            WriteOperation.Update => capability.CanUpdate,
            WriteOperation.Delete => capability.CanDelete,
            _ => false
        };

        if (permitted)
        {
            return;
        }

        var allowed = new List<string>();
        if (capability.CanInsert) allowed.Add("insert");
        if (capability.CanUpdate) allowed.Add("update");
        if (capability.CanDelete) allowed.Add("delete");

        throw new ReadOnlyEntityException(metadata.TableName,
            $"Oracle does not permit {operation.ToString().ToLowerInvariant()} on this view. "
            + (allowed.Count > 0
                ? $"It does permit: {string.Join(", ", allowed)}."
                : "It permits no writes at all."));
    }

    private List<string> FindSimilarTableNames(string input, List<string> tableNames, int maxSuggestions)
    {
        var inputUpper = input.ToUpperInvariant();
        
        return tableNames
            .Select(name => new { Name = name, Score = CalculateSimilarityScore(inputUpper, name.ToUpperInvariant()) })
            .Where(x => x.Score > 0)
            .OrderByDescending(x => x.Score)
            .Take(maxSuggestions)
            .Select(x => x.Name)
            .ToList();
    }

    private int CalculateSimilarityScore(string input, string candidate)
    {
        int score = 0;
        if (candidate.StartsWith(input)) score += 100;
        else if (input.StartsWith(candidate)) score += 80;
        if (candidate.Contains(input)) score += 50;
        else if (input.Contains(candidate)) score += 40;
        return score;
    }

    private async Task<List<Dictionary<string, object?>>> ExecuteQueryAsync(
        string instance,
        string sql, 
        EntityMetadata metadata,
        List<OracleParameter>? parameters = null)
    {
        var results = new List<Dictionary<string, object?>>();

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        // BindByName because a block WHERE's binds are named and may appear in any order, and
        // the same bind may be used more than once in one clause.
        await using var command = new OracleCommand(sql, connection) { BindByName = true };
        if (parameters != null)
        {
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
        }

        await using var reader = await command.ExecuteReaderAsync();
        var oracleReader = (OracleDataReader)reader;
        while (await reader.ReadAsync())
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < reader.FieldCount; i++)
            {
                var columnName = reader.GetName(i);
                row[columnName] = ReadColumnValue(oracleReader, i);
            }
            results.Add(row);
        }

        return results;
    }

    /// <summary>
    /// Reads one column, tolerating NUMBER values too precise for a .NET decimal.
    /// Shared with the stored-procedure cursor reader; see <see cref="OracleValueReader"/>.
    /// </summary>
    private static object? ReadColumnValue(OracleDataReader reader, int ordinal) =>
        OracleValueReader.Read(reader, ordinal);

    private string BuildWhereClause(Dictionary<string, object> keyValues, out List<OracleParameter> parameters, string prefix = "p")
    {
        parameters = new List<OracleParameter>();
        var conditions = new List<string>();

        int i = 0;
        foreach (var (column, value) in keyValues)
        {
            var paramName = $"{prefix}{i}";
            conditions.Add($"\"{column}\" = :{paramName}");
            parameters.Add(new OracleParameter(paramName, value));
            i++;
        }

        return string.Join(" AND ", conditions);
    }
}

/// <summary>
/// Query options for OData queries.
/// </summary>
public class QueryOptions
{
    public string? Select { get; set; }
    public string? Filter { get; set; }
    public string? OrderBy { get; set; }
    public int Top { get; set; } = 100;
    public int Skip { get; set; } = 0;

    /// <summary>
    /// A named block WHERE from the registry, ANDed with $filter. Reproduces the clause a
    /// legacy Forms block applied to every one of its queries. Null when none was named.
    /// </summary>
    public ResolvedBlockWhere? BlockWhere { get; set; }
}

public class QueryValidationException : Exception
{
    public string ParameterName { get; }
    public List<string> InvalidValues { get; }
    public List<string> ValidValues { get; }

    public QueryValidationException(string message, string parameterName, List<string> invalidValues, List<string> validValues)
        : base(message)
    {
        ParameterName = parameterName;
        InvalidValues = invalidValues;
        ValidValues = validValues;
    }
}

public class TableNotFoundException : Exception
{
    public string RequestedTable { get; }
    public List<string> Suggestions { get; }

    public TableNotFoundException(string requestedTable, List<string> suggestions)
        : base(suggestions.Count > 0 
            ? $"Table '{requestedTable}' not found. Did you mean: {string.Join(", ", suggestions)}?"
            : $"Table '{requestedTable}' not found.")
    {
        RequestedTable = requestedTable;
        Suggestions = suggestions;
    }
}

public class ReadOnlyEntityException : Exception
{
    public string EntityName { get; }

    public ReadOnlyEntityException(string entityName, string? reason = null)
        : base(reason is null
            ? $"'{entityName}' is a view and is read-only. Only GET is supported."
            : $"'{entityName}' is read-only. {reason}")
    {
        EntityName = entityName;
    }
}

public class FilterValidationException : Exception
{
    public string Filter { get; }
    public List<string> Errors { get; }
    public List<string> Suggestions { get; }

    public FilterValidationException(string filter, List<string> errors, List<string> suggestions)
        : base($"Invalid $filter syntax: {string.Join("; ", errors)}")
    {
        Filter = filter;
        Errors = errors;
        Suggestions = suggestions;
    }
}

/// <summary>Which kind of write is being attempted, for the view capability check.</summary>
public enum WriteOperation
{
    Insert,
    Update,
    Delete
}

/// <summary>
/// A filter-addressed write matched something other than exactly one row, so it was undone.
/// Zero means the row is gone or the filter is wrong; more than one means the filter is not
/// selective enough and the caller has to narrow it.
/// </summary>
public class AmbiguousRowException : Exception
{
    public string TableName { get; }
    public int MatchedRows { get; }

    public AmbiguousRowException(string tableName, int matchedRows)
        : base(matchedRows == 0
            ? $"No row in '{tableName}' matches that $filter."
            : $"That $filter matches {matchedRows} rows in '{tableName}'. A filter-addressed "
              + "write must identify exactly one row; nothing was changed.")
    {
        TableName = tableName;
        MatchedRows = matchedRows;
    }
}

/// <summary>
/// A connection and transaction that outlive a single operation, so the writes in one
/// $batch change set commit or roll back together. A plain request passes null and each
/// write stands alone.
/// </summary>
public sealed class DbScope
{
    public OracleConnection Connection { get; }
    public OracleTransaction Transaction { get; }

    public DbScope(OracleConnection connection, OracleTransaction transaction)
    {
        Connection = connection;
        Transaction = transaction;
    }
}
