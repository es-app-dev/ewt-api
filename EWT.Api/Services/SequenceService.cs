using System.Text.Json;
using System.Text.RegularExpressions;

namespace EWT.Api.Services;

/// <summary>
/// Server-side primary key allocation on POST.
///
/// The legacy Oracle Forms application allocates its own keys in PRE-INSERT
/// (:BLOCK.PK := SOME_SEQ.NEXTVAL). A REST client should not have to know that, so when
/// a table is in this map and the client omits the key column, the server fills it from
/// the sequence and returns the created entity including the key.
///
/// Only the safe shape is listed: the sequence feeds the table's SOLE primary key.
/// Compound keys, columns that are not the key (a child allocating its PARENT's key,
/// e.g. AT_CONTACTS.ADDR_SEQ_ID) and keyless tables are recorded in "excluded" in
/// sequences.json with the reason, and are never auto-assigned.
///
/// Regenerate with scripts/build-sequence-map.py.
///
/// STANDING CONSTRAINT, do not "fix" this:
///
/// The database does not change and the sequences stay exactly as they are. 34 of these
/// names resolve, through a PUBLIC synonym over a database link, to a sequence on CORP;
/// the other 51 resolve to a local sequence on whichever instance is being written to.
/// That split is deliberate and predates us by decades.
///
/// The consequence is that ids from the 51 are NOT unique across instances and already
/// collide today: AT_MATERIALS on BASC runs 645,601 to 696,062 while BCTN runs 15 to
/// 1,048,655, and every one of the 15 instance pairs overlaps. The legacy application has
/// always behaved this way and depends on those rows never being brought together.
///
/// Making them unique would be an improvement, and an improvement is a behavioural change
/// to a system with regulatory obligations and V and V'd behaviour. So: no uniqueness
/// guarantee is added here, none of the 51 is repointed at CORP, and the two groups are
/// not harmonised. Allocation is a plain SELECT seq.NEXTVAL FROM DUAL against the instance
/// named in ?db=, which is precisely what the Forms PRE-INSERT did, and Oracle resolves
/// the name the same way it always has. Whatever that yields is correct by definition.
///
/// Which group a given name falls into was established from ALL_SYNONYMS and ALL_SEQUENCES
/// on 2026-09-23 and is recorded here rather than queried at runtime, because nothing in the
/// server needs to know: the allocation is name resolution either way.
/// </summary>
public class SequenceService
{
    // A sequence name is interpolated into SQL, never bound, because NEXTVAL cannot be
    // a bind variable. It comes from a file we ship, not from the request, but validate
    // anyway so a bad edit to that file cannot become an injection.
    private static readonly Regex SafeIdentifier = new(@"^[A-Za-z][A-Za-z0-9_$#]{0,29}$",
        RegexOptions.Compiled);

    private readonly ILogger<SequenceService> _logger;
    private readonly Dictionary<string, SequenceAssignment> _assign =
        new(StringComparer.OrdinalIgnoreCase);

    public SequenceService(ILogger<SequenceService> logger)
    {
        _logger = logger;
        Load(Path.Combine(AppContext.BaseDirectory, "sequences.json"));
    }

    public int Count => _assign.Count;

    /// <summary>Every table the server will allocate a key for, for /admin reporting.</summary>
    public IReadOnlyDictionary<string, SequenceAssignment> Assignments => _assign;

    /// <summary>
    /// The key this table gets allocated on POST, or null when the client must supply it.
    /// </summary>
    public SequenceAssignment? For(string tableName) =>
        _assign.TryGetValue(tableName, out var a) ? a : null;

    private void Load(string path)
    {
        if (!File.Exists(path))
        {
            _logger.LogWarning(
                "No sequences.json at {Path}; POST will not assign primary keys and the "
                + "82 screens that create rows will need to send their own.", path);
            return;
        }

        try
        {
            using var stream = File.OpenRead(path);
            var doc = JsonSerializer.Deserialize<SequenceMapFile>(stream, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            foreach (var (table, entry) in doc?.Assign ?? new())
            {
                if (string.IsNullOrWhiteSpace(entry.Column) || string.IsNullOrWhiteSpace(entry.Sequence))
                {
                    continue;
                }

                if (!SafeIdentifier.IsMatch(entry.Sequence))
                {
                    _logger.LogError("Refusing sequence '{Sequence}' for {Table}: not a plain "
                                     + "Oracle identifier", entry.Sequence, table);
                    continue;
                }

                _assign[table] = new SequenceAssignment(
                    table, entry.Column.ToUpperInvariant(), entry.Sequence.ToUpperInvariant());
            }

            _logger.LogInformation("Key allocation enabled for {Count} tables ({Excluded} "
                                   + "deliberately excluded)", _assign.Count, doc?.Excluded?.Count ?? 0);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not read {Path}; POST will not assign primary keys", path);
        }
    }

    private class SequenceMapFile
    {
        public Dictionary<string, Entry> Assign { get; set; } = new();
        public List<object>? Excluded { get; set; }

        public class Entry
        {
            public string? Column { get; set; }
            public string? Sequence { get; set; }
        }
    }
}

/// <summary>One table's server-allocated key.</summary>
public record SequenceAssignment(string Table, string Column, string Sequence);
