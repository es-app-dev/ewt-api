using System.Data;
using System.Globalization;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// Optimistic concurrency, via an If-Match header carrying the row's MODIFIED_DT.
///
/// The legacy application held row locks: Forms reserved a row on the first keystroke and
/// the second user was refused immediately. A REST API holds nothing between requests, so
/// without a check two people editing one row is silent last-write-wins, and neither of
/// them is told. That is not a weaker version of the old behaviour, it is the opposite.
///
/// The check is one extra predicate on the UPDATE or DELETE:
///
///     WHERE &lt;key or filter&gt; AND NVL("MODIFIED_DT", "CREATED_DT") = :ifMatch
///
/// so the comparison and the write are the same statement and cannot race. The fallback to
/// CREATED_DT matters: a trigger fills MODIFIED_DT on update, so it is null until a row is
/// first edited, and without it the first edit of every new row would be unguardable. What
/// a client sends is therefore MODIFIED_DT, or CREATED_DT when MODIFIED_DT is null. When it matches
/// nothing, the row is read back to say which of the two things happened: somebody else
/// changed it (412, with the current row attached) or it is gone (404).
///
/// 143 of the 206 writable tables the UI binds carry MODIFIED_DT. The other 63, nearly all
/// CORP reference data, have no column to check and are written unguarded. An If-Match sent
/// to one of those is rejected rather than ignored, because silently not checking is how a
/// caller ends up believing it is protected when it is not.
/// </summary>
public partial class DynamicDataService
{
    /// <summary>The column this schema uses to record when a row last changed.</summary>
    private const string ConcurrencyColumnName = "MODIFIED_DT";

    /// <summary>
    /// Used when MODIFIED_DT is null, which is every row that has not been edited since it
    /// was created. A trigger fills MODIFIED_DT on update, so without this fallback the
    /// first edit of any new row could never be guarded. 751 of the 806 tables carrying
    /// MODIFIED_DT also carry this.
    /// </summary>
    private const string CreatedColumnName = "CREATED_DT";

    /// <summary>
    /// The concurrency column for this table, or null when it has none.
    /// </summary>
    public static string? ConcurrencyColumnOf(EntityMetadata metadata) =>
        metadata.Columns
            .FirstOrDefault(c => c.ColumnName.Equals(ConcurrencyColumnName, StringComparison.OrdinalIgnoreCase))
            ?.ColumnName;

    /// <summary>The column that stands in when the concurrency column is null, if any.</summary>
    public static string? ConcurrencyFallbackOf(EntityMetadata metadata) =>
        ConcurrencyColumnOf(metadata) is null
            ? null
            : metadata.Columns
                .FirstOrDefault(c => c.ColumnName.Equals(CreatedColumnName, StringComparison.OrdinalIgnoreCase))
                ?.ColumnName;

    /// <summary>
    /// Turns the If-Match header into the value to compare against.
    ///
    /// Accepts what a client naturally has: the MODIFIED_DT it read back from a GET, with
    /// or without the quotes and weak-ETag prefix that HTTP would put around an entity tag.
    /// </summary>
    private static DateTime ParseIfMatch(string ifMatch, string tableName)
    {
        var text = ifMatch.Trim();
        if (text.StartsWith("W/", StringComparison.OrdinalIgnoreCase))
        {
            text = text[2..].Trim();
        }
        if (text.Length >= 2 && text[0] == '"' && text[^1] == '"')
        {
            text = text[1..^1];
        }

        if (text == "*")
        {
            throw new ConcurrencyNotSupportedException(
                $"If-Match: * is not supported. Send the MODIFIED_DT value you read from "
                + $"'{tableName}', so the server can tell whether the row changed underneath you.");
        }

        if (!DateTime.TryParse(text, CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var parsed))
        {
            throw new ConcurrencyNotSupportedException(
                $"'{ifMatch}' is not a MODIFIED_DT value. Send the value exactly as the API "
                + "returned it, for example 2026-09-23T12:23:07.");
        }

        return parsed;
    }

    /// <summary>
    /// Adds the concurrency predicate to a WHERE clause, or explains why it cannot.
    /// </summary>
    private static string AppendConcurrencyPredicate(
        string whereClause,
        EntityMetadata metadata,
        string ifMatch,
        List<OracleParameter> parameters)
    {
        var column = ConcurrencyColumnOf(metadata);
        if (column is null)
        {
            throw new ConcurrencyNotSupportedException(
                $"'{metadata.TableName}' has no {ConcurrencyColumnName} column, so the server "
                + "cannot tell whether the row changed underneath you. Retry without If-Match, "
                + "knowing the write is unguarded.");
        }

        // "null" addresses a row that has never been edited, on the 55 tables that have no
        // CREATED_DT to fall back to.
        if (ifMatch.Trim().Trim('"').Equals("null", StringComparison.OrdinalIgnoreCase))
        {
            return $"({whereClause}) AND \"{column}\" IS NULL";
        }

        parameters.Add(new OracleParameter("ifmatch", OracleDbType.Date)
        {
            Value = ParseIfMatch(ifMatch, metadata.TableName)
        });

        // Oracle DATE has second resolution and no fractional part, so an equality test on
        // the value the caller read is exact.
        var created = metadata.Columns
            .FirstOrDefault(c => c.ColumnName.Equals(CreatedColumnName, StringComparison.OrdinalIgnoreCase))
            ?.ColumnName;

        var token = created is null
            ? $"\"{column}\""
            : $"NVL(\"{column}\", \"{created}\")";

        return $"({whereClause}) AND {token} = :ifmatch";
    }

    /// <summary>
    /// Reads one row by primary key, to say whether a failed guarded write missed because
    /// somebody else changed the row or because it no longer exists.
    /// </summary>
    public async Task<Dictionary<string, object?>?> FindByKeyAsync(
        string instance,
        string tableName,
        Dictionary<string, object> keyValues)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        var columns = string.Join(", ", metadata.Columns.Select(c => $"\"{c.ColumnName}\""));
        var where = BuildWhereClause(keyValues, out var parameters, "find");
        var sql = $"SELECT {columns} FROM {metadata.SqlName} "
                  + $"WHERE {where} AND ROWNUM = 1";

        var rows = await ExecuteQueryAsync(instance, sql, metadata, parameters);
        return rows.Count > 0 ? rows[0] : null;
    }

    /// <summary>
    /// Reads the single row matching a filter, for the same purpose on keyless tables.
    /// </summary>
    public async Task<Dictionary<string, object?>?> FindByFilterAsync(
        string instance,
        string tableName,
        string filter)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        var parameters = new List<OracleParameter>();
        var where = ParseFilter(filter, metadata, parameters);
        var columns = string.Join(", ", metadata.Columns.Select(c => $"\"{c.ColumnName}\""));
        var sql = $"SELECT {columns} FROM {metadata.SqlName} "
                  + $"WHERE {where} AND ROWNUM = 1";

        var rows = await ExecuteQueryAsync(instance, sql, metadata, parameters);
        return rows.Count > 0 ? rows[0] : null;
    }
}

/// <summary>
/// The row changed after the caller read it, so the write was refused and nothing was
/// written. Carries the current row where it could be read back, so the caller can show
/// what changed rather than making the user re-query.
/// </summary>
public class RowChangedException : Exception
{
    public string TableName { get; }
    public Dictionary<string, object?>? Current { get; }

    public RowChangedException(string tableName, Dictionary<string, object?>? current)
        : base($"Someone else changed this {tableName} row while you were editing it. "
               + "Nothing was saved.")
    {
        TableName = tableName;
        Current = current;
    }
}

/// <summary>
/// An If-Match was sent that this server cannot honour, either because the table has no
/// column to check or because the value is not one. Refused rather than ignored: a caller
/// that believes it is guarded when it is not is worse off than one that knows it is not.
/// </summary>
public class ConcurrencyNotSupportedException : Exception
{
    public ConcurrencyNotSupportedException(string message) : base(message) { }
}
