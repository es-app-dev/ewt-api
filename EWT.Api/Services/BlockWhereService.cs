using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// The WHERE clauses the legacy Forms blocks apply to every query of a block, held on the
/// server under a name.
///
/// A Forms data block carries a WHERE clause that decides which rows the screen shows at all.
/// Most translate to $filter. About twenty do not: they use subqueries, PL/SQL functions,
/// correlated EXISTS, CONNECT BY or a database link. Dropping them would show rows the legacy
/// never shows, so the text is kept here and named, and a request asks for it by name.
///
/// The text never comes from the client. A request carries a name; an unknown name is a 400.
/// Values the screen supplies arrive as separate bind parameters and are bound by Oracle, never
/// concatenated into SQL. So this is no more open to a caller than a view is.
///
/// The file is reviewed and placed by hand, like relationships.json. Nothing writes it at runtime.
/// </summary>
public class BlockWhereService
{
    private readonly ILogger<BlockWhereService> _logger;
    private readonly string _filePath;
    private Dictionary<string, BlockWhere> _byName = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Wire name to Oracle placeholder: ":MATL.CNTNR_SEQ_ID" is not a legal bind name.</summary>
    private static string PlaceholderFor(string bindName) => bindName.Replace('.', '_');

    public BlockWhereService(ILogger<BlockWhereService> logger)
    {
        _logger = logger;
        _filePath = Path.Combine(AppContext.BaseDirectory, "block-wheres.json");
        LoadFromFile();
    }

    public IReadOnlyCollection<BlockWhere> All => _byName.Values;

    public int Count => _byName.Count;

    /// <summary>The names registered for one entity set, for an error message that helps.</summary>
    public List<string> NamesFor(string entitySet) =>
        _byName.Values
            .Where(w => w.EntitySet.Equals(entitySet, StringComparison.OrdinalIgnoreCase))
            .Select(w => w.Name)
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase)
            .ToList();

    /// <summary>
    /// Looks a name up, checks it belongs to this entity set, and binds the supplied values.
    /// Throws <see cref="BlockWhereException"/> with a code the controller turns into a 400.
    /// </summary>
    public ResolvedBlockWhere Resolve(
        string entitySet, string name, IReadOnlyDictionary<string, string?> suppliedBinds)
    {
        if (!_byName.TryGetValue(name, out var entry))
        {
            throw new BlockWhereException(
                "UnknownBlockWhere",
                $"No block WHERE is registered under the name '{name}'.",
                NamesFor(entitySet));
        }

        if (!entry.EntitySet.Equals(entitySet, StringComparison.OrdinalIgnoreCase))
        {
            throw new BlockWhereException(
                "BlockWhereEntitySetMismatch",
                $"'{name}' is registered for {entry.EntitySet}, not {entitySet}. A block WHERE is "
                + "written against one block's table and is not valid against another.",
                NamesFor(entitySet));
        }

        var declared = entry.Binds.Select(b => b.Name).ToHashSet(StringComparer.OrdinalIgnoreCase);

        var unexpected = suppliedBinds.Keys
            .Where(k => !declared.Contains(k))
            .OrderBy(k => k, StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (unexpected.Count > 0)
        {
            throw new BlockWhereException(
                "UnexpectedBlockWhereBind",
                $"'{name}' does not take the bind(s) {string.Join(", ", unexpected)}.",
                declared.OrderBy(d => d, StringComparer.OrdinalIgnoreCase).ToList());
        }

        var values = new List<BoundValue>();
        var missing = new List<string>();

        foreach (var bind in entry.Binds)
        {
            if (!suppliedBinds.TryGetValue(bind.Name, out var raw) || raw is null)
            {
                missing.Add(bind.Name);
                continue;
            }

            values.Add(new BoundValue(PlaceholderFor(bind.Name), Convert(name, bind, raw)));
        }

        if (missing.Count > 0)
        {
            throw new BlockWhereException(
                "MissingBlockWhereBind",
                $"'{name}' needs the bind(s) {string.Join(", ", missing)}. Send each one as a query "
                + $"parameter, for example &bind.{missing[0]}=<value>.",
                declared.OrderBy(d => d, StringComparer.OrdinalIgnoreCase).ToList());
        }

        return new ResolvedBlockWhere(entry.Name, entry.EntitySet, entry.Sql, values);
    }

    /// <summary>
    /// Turns the query string's bind.* parameters into a plain dictionary keyed by the wire
    /// name, so "bind.MATL.CNTNR_SEQ_ID=4211" arrives as "MATL.CNTNR_SEQ_ID".
    /// </summary>
    public static Dictionary<string, string?> ReadBindsFromQuery(IQueryCollection query)
    {
        var binds = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in query)
        {
            if (pair.Key.StartsWith("bind.", StringComparison.OrdinalIgnoreCase) && pair.Key.Length > 5)
            {
                binds[pair.Key[5..]] = pair.Value.ToString();
            }
        }
        return binds;
    }

    private static object Convert(string whereName, BlockWhereBind bind, string raw)
    {
        switch (bind.Type.ToLowerInvariant())
        {
            case "number":
                if (!decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out var number))
                {
                    throw new BlockWhereException(
                        "BadBlockWhereBind",
                        $"Bind {bind.Name} of '{whereName}' is a number; '{raw}' is not one.",
                        new List<string>());
                }
                return number;

            case "date":
                if (!DateTime.TryParse(raw, CultureInfo.InvariantCulture,
                        DateTimeStyles.None, out var date))
                {
                    throw new BlockWhereException(
                        "BadBlockWhereBind",
                        $"Bind {bind.Name} of '{whereName}' is a date; '{raw}' is not one. "
                        + "Write it as 2026-01-31 or 2026-01-31T14:00:00.",
                        new List<string>());
                }
                return date;

            default:
                return raw;
        }
    }

    private void LoadFromFile()
    {
        if (!File.Exists(_filePath))
        {
            _logger.LogInformation(
                "No block-wheres.json at {Path}; no named block WHERE clauses are registered.", _filePath);
            return;
        }

        try
        {
            var json = File.ReadAllText(_filePath);
            var file = JsonSerializer.Deserialize<BlockWhereFile>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                ReadCommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true
            });

            var loaded = new Dictionary<string, BlockWhere>(StringComparer.OrdinalIgnoreCase);
            var rejected = new List<string>();

            foreach (var entry in file?.BlockWheres ?? new List<BlockWhere>())
            {
                if (Validate(entry, loaded, out var reason))
                {
                    // Validate has already rejected a null or blank name.
                    loaded[entry.Name!] = entry;
                }
                else
                {
                    rejected.Add($"{entry.Name ?? "(unnamed)"}: {reason}");
                }
            }

            _byName = loaded;

            if (rejected.Count > 0)
            {
                // Loud, because a rejected entry means a screen silently shows rows the legacy
                // does not. Better to see it at startup than to find it in the data.
                _logger.LogError("Rejected {Count} block WHERE entries: {Reasons}",
                    rejected.Count, string.Join(" | ", rejected));
            }

            _logger.LogInformation("Loaded {Count} named block WHERE clause(s) from {Path}",
                _byName.Count, _filePath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not read {Path}; no block WHERE clauses are registered.", _filePath);
            _byName = new Dictionary<string, BlockWhere>(StringComparer.OrdinalIgnoreCase);
        }
    }

    /// <summary>
    /// Checks one entry at load. The text is ours, not a caller's, so this is not a defence
    /// against an attacker: it catches a registry entry that would break a query or hide
    /// something from review.
    /// </summary>
    private static bool Validate(
        BlockWhere entry, Dictionary<string, BlockWhere> alreadyLoaded, out string reason)
    {
        reason = "";

        if (string.IsNullOrWhiteSpace(entry.Name)) { reason = "no name"; return false; }
        if (string.IsNullOrWhiteSpace(entry.EntitySet)) { reason = "no entitySet"; return false; }
        if (string.IsNullOrWhiteSpace(entry.Sql)) { reason = "no sql"; return false; }

        if (alreadyLoaded.ContainsKey(entry.Name))
        {
            reason = "duplicate name";
            return false;
        }

        var sql = entry.Sql;

        if (sql.Contains(';'))
        {
            reason = "the sql contains a semicolon";
            return false;
        }

        if (sql.Contains("--") || sql.Contains("/*"))
        {
            reason = "the sql contains a comment, which would hide text from review";
            return false;
        }

        var depth = 0;
        foreach (var c in sql)
        {
            if (c == '(') depth++;
            else if (c == ')' && --depth < 0) break;
        }
        if (depth != 0)
        {
            reason = "unbalanced parentheses in the sql";
            return false;
        }

        // It is a predicate, appended after WHERE. A leading statement keyword means someone
        // pasted a whole query in by mistake.
        if (Regex.IsMatch(sql.TrimStart(),
                @"^\s*(SELECT|INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|CREATE|TRUNCATE|GRANT|BEGIN)\b",
                RegexOptions.IgnoreCase))
        {
            reason = "the sql starts with a statement keyword; it must be a WHERE predicate only";
            return false;
        }

        foreach (var bind in entry.Binds)
        {
            if (string.IsNullOrWhiteSpace(bind.Name))
            {
                reason = "a bind has no name";
                return false;
            }

            if (!Regex.IsMatch(bind.Name, @"^[A-Za-z][A-Za-z0-9_$]*(\.[A-Za-z][A-Za-z0-9_$]*)*$"))
            {
                reason = $"bind name '{bind.Name}' is not a Forms-style name";
                return false;
            }

            if (!Regex.IsMatch(bind.Type, @"^(number|string|date)$", RegexOptions.IgnoreCase))
            {
                reason = $"bind {bind.Name} has type '{bind.Type}'; use number, string or date";
                return false;
            }

            if (!Regex.IsMatch(sql, $@":{Regex.Escape(PlaceholderFor(bind.Name))}\b", RegexOptions.IgnoreCase))
            {
                reason = $"bind {bind.Name} is declared but :{PlaceholderFor(bind.Name)} is not in the sql";
                return false;
            }
        }

        var declared = entry.Binds
            .Select(b => PlaceholderFor(b.Name))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        foreach (Match used in Regex.Matches(sql, @":([A-Za-z][A-Za-z0-9_$]*)"))
        {
            if (!declared.Contains(used.Groups[1].Value))
            {
                reason = $"the sql uses :{used.Groups[1].Value}, which is not declared in binds";
                return false;
            }
        }

        return true;
    }
}

/// <summary>The shape of block-wheres.json.</summary>
public class BlockWhereFile
{
    public List<BlockWhere> BlockWheres { get; set; } = new();
}

/// <summary>One named block WHERE clause.</summary>
public class BlockWhere
{
    /// <summary>Form and block, for example AT5521.OUTSHIPMT. This is what a request names.</summary>
    public string Name { get; set; } = "";

    /// <summary>The table the block queries. The name is only valid against this entity set.</summary>
    public string EntitySet { get; set; } = "";

    /// <summary>The predicate, as the form wrote it, with :PLACEHOLDERS for any binds.</summary>
    public string Sql { get; set; } = "";

    /// <summary>Values the screen supplies. Empty for a WHERE that reads nothing from the form.</summary>
    public List<BlockWhereBind> Binds { get; set; } = new();

    /// <summary>Free text: where it came from and anything a reviewer should know.</summary>
    public string? Note { get; set; }
}

/// <summary>One value a block WHERE reads from the screen.</summary>
public class BlockWhereBind
{
    /// <summary>The Forms name, for example MATL.CNTNR_SEQ_ID. Sent as bind.MATL.CNTNR_SEQ_ID.</summary>
    public string Name { get; set; } = "";

    /// <summary>number, string or date.</summary>
    public string Type { get; set; } = "string";
}

/// <summary>A block WHERE with its values bound, ready to append to a query.</summary>
public sealed class ResolvedBlockWhere
{
    public string Name { get; }
    public string EntitySet { get; }
    public string Sql { get; }
    private readonly IReadOnlyList<BoundValue> _values;

    public ResolvedBlockWhere(string name, string entitySet, string sql, IReadOnlyList<BoundValue> values)
    {
        Name = name;
        EntitySet = entitySet;
        Sql = sql;
        _values = values;
    }

    /// <summary>
    /// Fresh parameters each call. One row query and its $count are two commands, and ODP.NET
    /// will not let the same OracleParameter belong to both.
    /// </summary>
    public List<OracleParameter> CreateParameters() =>
        _values.Select(v => new OracleParameter(v.Placeholder, v.Value)).ToList();
}

/// <summary>A placeholder and the value bound to it.</summary>
public readonly record struct BoundValue(string Placeholder, object Value);

/// <summary>A caller's mistake naming or binding a block WHERE. The controller returns 400.</summary>
public class BlockWhereException : Exception
{
    public string Code { get; }
    public List<string> Known { get; }

    public BlockWhereException(string code, string message, List<string> known) : base(message)
    {
        Code = code;
        Known = known;
    }
}
