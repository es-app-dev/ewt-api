using System.Text.RegularExpressions;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// $apply: aggregation and grouping.
///
/// The forms carry 953 distinct aggregate or DISTINCT statements. 498 of them are a single
/// aggregate, a DISTINCT, a GROUP BY with an aggregate, or several aggregates at once, and
/// all four shapes have a standard OData spelling. This translates that spelling into one
/// Oracle query rather than making the client fetch rows and add them up.
///
/// Supported, which is the subset those 498 need:
///
///   $apply=aggregate(WEIGHT with sum as total)
///   $apply=aggregate(nvl(WEIGHT,0) with sum as total)      126 sites need this one
///   $apply=aggregate(WEIGHT with sum as total, WEIGHT with average as mean)
///   $apply=aggregate($count as rows)
///   $apply=groupby((CUST_SEQ_ID))                          the DISTINCT case
///   $apply=groupby((CUST_SEQ_ID), aggregate(WEIGHT with sum as total))
///   $apply=filter(STATUS eq 'A')/groupby((CUST_SEQ_ID), aggregate($count as rows))
///
/// nvl(COLUMN, default) is the only function allowed inside an aggregate, because it is
/// the only one the forms actually need: 126 of their aggregate calls wrap the column in
/// NVL and none uses CASE WHEN. Genuine arithmetic inside an aggregate, SUM(a * b), is 15
/// sites app-wide and is left to the client to compute from two aggregates.
///
/// Not supported, and rejected with a message saying so rather than silently ignored:
/// compute, expand, concat, topcount and nested groupby. Correlated subqueries, the
/// remaining 154 statements, are not expressible here at all and need named server-side
/// queries instead.
/// </summary>
public partial class DynamicDataService
{
    /// <summary>Largest number of groups one $apply may return.</summary>
    private const int MaxGroups = 10000;

    private static readonly Regex AliasPattern = new(@"^[A-Za-z][A-Za-z0-9_]{0,29}$", RegexOptions.Compiled);

    /// <summary>
    /// Runs an $apply pipeline. <paramref name="filter"/> is the ordinary $filter query
    /// option, which is ANDed with any filter() inside the pipeline.
    /// </summary>
    public async Task<List<Dictionary<string, object?>>> ApplyAsync(
        string instance,
        string tableName,
        string apply,
        string? filter,
        string? orderBy,
        int top,
        ResolvedBlockWhere? blockWhere = null)
    {
        var metadata = GetEntityMetadata(instance, tableName);
        var validColumns = metadata.Columns
            .Select(c => c.ColumnName.ToUpperInvariant())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var plan = ParseApply(apply, validColumns);

        var parameters = new List<OracleParameter>();
        var whereParts = new List<string>();

        // The block's clause bounds what the screen can see, so an aggregate over the block
        // must be taken inside it or the totals describe rows the legacy never shows.
        if (blockWhere is not null)
        {
            whereParts.Add($"({blockWhere.Sql})");
            parameters.AddRange(blockWhere.CreateParameters());
        }

        if (!string.IsNullOrWhiteSpace(filter))
        {
            whereParts.Add($"({ParseFilter(filter, metadata, parameters)})");
        }
        foreach (var applyFilter in plan.Filters)
        {
            whereParts.Add($"({ParseFilter(applyFilter, metadata, parameters)})");
        }

        var projection = new List<string>();
        foreach (var column in plan.GroupBy)
        {
            projection.Add($"\"{column}\"");
        }
        foreach (var aggregate in plan.Aggregates)
        {
            projection.Add($"{aggregate.Expression} AS \"{aggregate.Alias}\"");
        }

        if (projection.Count == 0)
        {
            throw new ApplyValidationException(
                "$apply must produce something: give it aggregate(...) or groupby((...)).");
        }

        var sql = $"SELECT {string.Join(", ", projection)} FROM {metadata.SqlName}";
        if (whereParts.Count > 0)
        {
            sql += $" WHERE {string.Join(" AND ", whereParts)}";
        }
        if (plan.GroupBy.Count > 0)
        {
            sql += $" GROUP BY {string.Join(", ", plan.GroupBy.Select(c => $"\"{c}\""))}";
        }

        // Order by the grouping columns unless the caller said otherwise, so paging over
        // groups is stable. An $orderby naming an aggregate alias is allowed, because after
        // aggregation the alias is the only name that column has.
        var order = BuildApplyOrderBy(orderBy, plan);
        if (!string.IsNullOrEmpty(order))
        {
            sql += $" ORDER BY {order}";
        }

        // An aggregate with no grouping is one row and needs no cap. Grouped output does.
        if (plan.GroupBy.Count > 0)
        {
            var limit = Math.Clamp(top <= 0 ? MaxGroups : top, 1, MaxGroups);
            sql = $"SELECT * FROM ({sql}) WHERE ROWNUM <= {limit}";
        }

        _logger.LogDebug("Executing $apply: {Sql}", sql);
        return await ExecuteQueryAsync(instance, sql, metadata, parameters);
    }

    private static string BuildApplyOrderBy(string? orderBy, ApplyPlan plan)
    {
        if (string.IsNullOrWhiteSpace(orderBy))
        {
            return plan.GroupBy.Count > 0
                ? string.Join(", ", plan.GroupBy.Select(c => $"\"{c}\""))
                : "";
        }

        if (orderBy.Trim().Equals("none", StringComparison.OrdinalIgnoreCase))
        {
            return "";
        }

        var available = plan.GroupBy
            .Concat(plan.Aggregates.Select(a => a.Alias))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var terms = new List<string>();
        foreach (var raw in orderBy.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = raw.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var name = parts[0];
            if (!available.Contains(name))
            {
                throw new ApplyValidationException(
                    $"$orderby '{name}' is not in the $apply result. After aggregation the only "
                    + $"names available are: {string.Join(", ", available.OrderBy(a => a))}.");
            }

            var direction = parts.Length > 1 && parts[1].Equals("desc", StringComparison.OrdinalIgnoreCase)
                ? "DESC"
                : "ASC";
            terms.Add($"\"{name}\" {direction}");
        }

        return string.Join(", ", terms);
    }

    private static ApplyPlan ParseApply(string apply, HashSet<string> validColumns)
    {
        var plan = new ApplyPlan();

        foreach (var transformation in SplitTopLevel(apply, '/'))
        {
            var (name, inner) = SplitCall(transformation);
            switch (name.ToLowerInvariant())
            {
                case "filter":
                    plan.Filters.Add(inner);
                    break;

                case "aggregate":
                    if (plan.Aggregates.Count > 0)
                    {
                        throw new ApplyValidationException(
                            "Only one aggregate() is supported. Put several aggregations inside "
                            + "it, separated by commas.");
                    }
                    plan.Aggregates.AddRange(ParseAggregates(inner, validColumns));
                    break;

                case "groupby":
                    if (plan.GroupBy.Count > 0)
                    {
                        throw new ApplyValidationException("Only one groupby() is supported.");
                    }
                    ParseGroupBy(inner, validColumns, plan);
                    break;

                default:
                    throw new ApplyValidationException(
                        $"$apply transformation '{name}' is not supported. This server understands "
                        + "filter, aggregate and groupby.");
            }
        }

        return plan;
    }

    private static void ParseGroupBy(string inner, HashSet<string> validColumns, ApplyPlan plan)
    {
        var parts = SplitTopLevel(inner, ',');
        if (parts.Count == 0)
        {
            throw new ApplyValidationException("groupby() needs a column list, e.g. groupby((CUST_SEQ_ID)).");
        }

        var columnList = parts[0].Trim();
        if (!columnList.StartsWith('(') || !columnList.EndsWith(')'))
        {
            throw new ApplyValidationException(
                "The first argument of groupby() is a parenthesised column list, "
                + "e.g. groupby((CUST_SEQ_ID, STATUS)).");
        }

        foreach (var raw in SplitTopLevel(columnList[1..^1], ','))
        {
            var column = raw.Trim().ToUpperInvariant();
            if (column.Length == 0)
            {
                continue;
            }
            if (!validColumns.Contains(column))
            {
                throw new ApplyValidationException($"groupby() column '{column}' does not exist on this table.");
            }
            plan.GroupBy.Add(column);
        }

        if (plan.GroupBy.Count == 0)
        {
            throw new ApplyValidationException("groupby() needs at least one column.");
        }

        // The optional second argument is the aggregation applied within each group.
        for (var i = 1; i < parts.Count; i++)
        {
            var (name, nested) = SplitCall(parts[i]);
            if (!name.Equals("aggregate", StringComparison.OrdinalIgnoreCase))
            {
                throw new ApplyValidationException(
                    $"Inside groupby(), only aggregate() is supported, not '{name}'.");
            }
            plan.Aggregates.AddRange(ParseAggregates(nested, validColumns));
        }
    }

    private static List<AggregateTerm> ParseAggregates(string inner, HashSet<string> validColumns)
    {
        var terms = new List<AggregateTerm>();

        foreach (var raw in SplitTopLevel(inner, ','))
        {
            var text = raw.Trim();
            if (text.Length == 0)
            {
                continue;
            }

            // $count as alias
            var countMatch = Regex.Match(text, @"^\$count\s+as\s+(\S+)$", RegexOptions.IgnoreCase);
            if (countMatch.Success)
            {
                terms.Add(new AggregateTerm("COUNT(*)", ValidateAlias(countMatch.Groups[1].Value)));
                continue;
            }

            // COLUMN with METHOD as alias, where COLUMN may be nvl(COLUMN, default)
            var match = Regex.Match(text, @"^(.+?)\s+with\s+(\S+)\s+as\s+(\S+)$", RegexOptions.IgnoreCase);
            if (!match.Success)
            {
                throw new ApplyValidationException(
                    $"'{text}' is not an aggregation. Expected \"COLUMN with METHOD as alias\", "
                    + "\"nvl(COLUMN,default) with METHOD as alias\" or \"$count as alias\".");
            }

            var operand = ParseOperand(match.Groups[1].Value, validColumns);
            var method = match.Groups[2].Value.Trim().ToLowerInvariant();
            var alias = ValidateAlias(match.Groups[3].Value);

            var expression = method switch
            {
                "sum" => $"SUM({operand})",
                "average" or "avg" => $"AVG({operand})",
                "min" => $"MIN({operand})",
                "max" => $"MAX({operand})",
                "countdistinct" => $"COUNT(DISTINCT {operand})",
                _ => throw new ApplyValidationException(
                    $"Aggregation method '{method}' is not supported. Use sum, average, min, max "
                    + "or countdistinct, or $count for a row count.")
            };

            terms.Add(new AggregateTerm(expression, alias));
        }

        if (terms.Count == 0)
        {
            throw new ApplyValidationException("aggregate() needs at least one aggregation.");
        }

        var duplicate = terms.GroupBy(t => t.Alias, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(g => g.Count() > 1);
        if (duplicate != null)
        {
            throw new ApplyValidationException($"Two aggregations share the alias '{duplicate.Key}'.");
        }

        return terms;
    }

    /// <summary>
    /// What an aggregate is applied to: a column, or nvl(column, default).
    ///
    /// NVL is allowed because 126 of the aggregate calls in the forms need it and its
    /// semantics are unambiguous. The default is bound as a parameter would be if it could
    /// be, but NVL's second argument has to match the column type, so it is validated hard
    /// instead: a plain number, or a quoted string with its quotes doubled.
    /// </summary>
    private static string ParseOperand(string text, HashSet<string> validColumns)
    {
        text = text.Trim();

        var nvl = Regex.Match(text, @"^nvl\s*\(\s*([A-Za-z0-9_$#]+)\s*,\s*(.+?)\s*\)$",
            RegexOptions.IgnoreCase);
        if (nvl.Success)
        {
            var column = RequireColumn(nvl.Groups[1].Value, validColumns);
            var fallback = nvl.Groups[2].Value.Trim();

            if (Regex.IsMatch(fallback, @"^-?\d+(\.\d+)?$"))
            {
                return $"NVL(\"{column}\", {fallback})";
            }

            if (fallback.Length >= 2 && fallback[0] == '\'' && fallback[^1] == '\'')
            {
                var inner = fallback[1..^1];
                // Reject a literal that closes its own quote, which would end the string
                // early and let the rest be read as SQL.
                if (Regex.IsMatch(inner.Replace("''", ""), @"'"))
                {
                    throw new ApplyValidationException(
                        "The default in nvl() has an unbalanced quote.");
                }
                return $"NVL(\"{column}\", '{inner}')";
            }

            throw new ApplyValidationException(
                $"The default in nvl({column}, ...) must be a number or a quoted string, "
                + $"not '{fallback}'.");
        }

        // Anything that is not a plain column name by this point is an expression, and the
        // message should say so rather than claim the whole expression is a missing column.
        if (!Regex.IsMatch(text, @"^[A-Za-z][A-Za-z0-9_$#]*$"))
        {
            throw new ApplyValidationException(
                $"'{text}' is not something this server can aggregate. Only a column name, or "
                + "nvl(column, default), is supported. For arithmetic such as SUM(a * b), "
                + "aggregate the columns separately and combine them client-side.");
        }

        return $"\"{RequireColumn(text, validColumns)}\"";
    }

    private static string RequireColumn(string name, HashSet<string> validColumns)
    {
        var column = name.Trim().ToUpperInvariant();
        if (!validColumns.Contains(column))
        {
            throw new ApplyValidationException($"Column '{column}' does not exist on this table.");
        }
        return column;
    }

    /// <summary>
    /// An alias becomes a quoted SQL identifier, so it is checked rather than trusted.
    /// </summary>
    private static string ValidateAlias(string alias)
    {
        alias = alias.Trim();
        if (!AliasPattern.IsMatch(alias))
        {
            throw new ApplyValidationException(
                $"'{alias}' is not a usable alias. Use a letter followed by letters, digits or "
                + "underscores, at most 30 characters.");
        }
        return alias;
    }

    /// <summary>Splits "name(args)" into its parts, tolerating nested parentheses in args.</summary>
    private static (string Name, string Inner) SplitCall(string text)
    {
        text = text.Trim();
        var open = text.IndexOf('(');
        if (open < 0 || !text.EndsWith(')'))
        {
            throw new ApplyValidationException(
                $"'{text}' is not a transformation. Expected something like aggregate(...) or groupby((...)).");
        }
        return (text[..open].Trim(), text[(open + 1)..^1]);
    }

    /// <summary>
    /// Splits on a separator that is outside parentheses and outside quoted strings, so a
    /// filter like filter(NAME eq 'a,b') survives being split on commas.
    /// </summary>
    private static List<string> SplitTopLevel(string text, char separator)
    {
        var parts = new List<string>();
        var depth = 0;
        var inQuotes = false;
        var start = 0;

        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (c == '\'')
            {
                // '' inside a string literal is an escaped quote, not the end of one.
                if (inQuotes && i + 1 < text.Length && text[i + 1] == '\'')
                {
                    i++;
                    continue;
                }
                inQuotes = !inQuotes;
                continue;
            }
            if (inQuotes)
            {
                continue;
            }
            if (c == '(')
            {
                depth++;
            }
            else if (c == ')')
            {
                depth--;
                if (depth < 0)
                {
                    throw new ApplyValidationException("Unbalanced parentheses in $apply.");
                }
            }
            else if (c == separator && depth == 0)
            {
                parts.Add(text[start..i]);
                start = i + 1;
            }
        }

        if (depth != 0 || inQuotes)
        {
            throw new ApplyValidationException(
                inQuotes ? "Unterminated string literal in $apply." : "Unbalanced parentheses in $apply.");
        }

        var last = text[start..];
        if (last.Trim().Length > 0 || parts.Count > 0)
        {
            parts.Add(last);
        }

        return parts.Where(p => p.Trim().Length > 0).ToList();
    }

    private class ApplyPlan
    {
        public List<string> Filters { get; } = new();
        public List<string> GroupBy { get; } = new();
        public List<AggregateTerm> Aggregates { get; } = new();
    }

    private record AggregateTerm(string Expression, string Alias);
}

/// <summary>An $apply expression this server cannot translate.</summary>
public class ApplyValidationException : Exception
{
    public ApplyValidationException(string message) : base(message) { }
}
