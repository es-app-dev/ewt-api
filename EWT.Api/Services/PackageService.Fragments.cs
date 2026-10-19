using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace EWT.Api.Services;

/// <summary>
/// EWT_UI as one file per form, assembled into a single Oracle package.
///
/// The package is one package in the database and stays that way: a package per form was
/// considered and rejected, because the UI calls these as EWT_UI.&lt;proc&gt; and seven databases
/// times sixty packages is not a thing anyone wants to reason about. What changes is the
/// source. OurPackages/ewt_ui holds one .sql per form, the API concatenates them on load and
/// on a deploy, and the UI side edits one form without touching the other fifty-nine.
///
/// Each fragment carries two sections, and nothing else: the declarations that belong in the
/// package spec, and the definitions that belong in the body. No CREATE OR REPLACE, no slash
/// lines, no package header. _frame.sql supplies those.
///
///     -- EWT_UI fragment: AT5510
///     --#SPEC
///       PROCEDURE at5510_set_location(...);
///     --#BODY
///       PROCEDURE at5510_set_location(...) IS ... END;
///
/// Order comes from _manifest.json, with anything unlisted appended alphabetically. It is not
/// cosmetic: a package-body-private procedure must be defined before anything calls it, and
/// rule_error in _COMMON is called from four other fragments, so _COMMON goes first.
/// </summary>
public partial class PackageService
{
    /// <summary>The package assembled from fragments, if the directory is there.</summary>
    private const string FragmentDirectoryName = "ewt_ui";

    /// <summary>Procedures in a form's fragment must carry its prefix. _COMMON is exempt.</summary>
    public const string CommonFragment = "_COMMON";

    /// <summary>
    /// The only markers that open a section. Anything else beginning <c>--#</c> stays as
    /// content.
    ///
    /// This used to accept any <c>--#NAME</c>, which was a trap: a generator writing its own
    /// <c>--#GENERATED-LOV</c> region would open a third section, and every procedure after it
    /// would fall out of SPEC. The package still compiles, because a procedure defined in the
    /// body and absent from the spec is simply private, so the only symptom is that the
    /// procedure disappears from /odata/proc. Nothing errors.
    /// </summary>
    private static readonly HashSet<string> KnownSections = new(StringComparer.OrdinalIgnoreCase)
    {
        "SPEC", "BODY",
        "PREAMBLE", "SPEC-OPEN", "SPEC-HEAD", "SPEC-TAIL",
        "BODY-OPEN", "BODY-HEAD", "BODY-TAIL",
    };

    private static readonly Regex SectionMarker = new(@"(?m)^--#([A-Za-z-]+)[ \t]*\r?\n", RegexOptions.Compiled);

    private static readonly Regex TopLevelUnit = new(
        @"(?m)^  (?:PROCEDURE|FUNCTION)\s+([A-Za-z0-9_]+)", RegexOptions.Compiled);

    private string FragmentDirectory => Path.Combine(_directory, FragmentDirectoryName);

    /// <summary>True when EWT_UI is sourced from fragments rather than one .sql file.</summary>
    public bool UsesFragments =>
        Directory.Exists(FragmentDirectory)
        && File.Exists(Path.Combine(FragmentDirectory, "_frame.sql"));

    /// <summary>Splits a fragment or the frame on its --#MARKER lines.</summary>
    private static Dictionary<string, string> Sections(string text)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var marks = SectionMarker.Matches(text)
            .Where(m => KnownSections.Contains(m.Groups[1].Value))
            .ToList();

        for (var i = 0; i < marks.Count; i++)
        {
            var start = marks[i].Index + marks[i].Length;
            var end = i + 1 < marks.Count ? marks[i + 1].Index : text.Length;
            result[marks[i].Groups[1].Value] = text[start..end];
        }
        return result;
    }

    /// <summary>Any --#NAME line that is not a section, so a PUT can refuse it by name.</summary>
    private static List<string> UnknownMarkers(string text) =>
        SectionMarker.Matches(text)
            .Select(m => m.Groups[1].Value)
            .Where(n => !KnownSections.Contains(n))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

    /// <summary>Fragment names in assembly order: the manifest's, then anything else, sorted.</summary>
    public List<string> FragmentOrder()
    {
        if (!UsesFragments)
        {
            return new List<string>();
        }

        var present = Directory.GetFiles(FragmentDirectory, "*.sql")
            .Select(Path.GetFileNameWithoutExtension)
            .Where(n => n is not null && !n.Equals("_frame", StringComparison.OrdinalIgnoreCase))
            .Select(n => n!)
            .ToList();

        var listed = new List<string>();
        var manifestPath = Path.Combine(FragmentDirectory, "_manifest.json");
        if (File.Exists(manifestPath))
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(manifestPath));
                if (doc.RootElement.TryGetProperty("order", out var order))
                {
                    listed = order.EnumerateArray().Select(e => e.GetString() ?? "").ToList();
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not read {Path}; assembling alphabetically", manifestPath);
            }
        }

        var ordered = listed.Where(n => present.Contains(n, StringComparer.OrdinalIgnoreCase)).ToList();
        ordered.AddRange(present
            .Where(n => !listed.Contains(n, StringComparer.OrdinalIgnoreCase))
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase));
        return ordered;
    }

    /// <summary>Concatenates the frame and every fragment into one EWT_UI package.</summary>
    public string AssembleFromFragments()
    {
        var frame = Sections(File.ReadAllText(Path.Combine(FragmentDirectory, "_frame.sql")));
        var order = FragmentOrder();

        var specs = new StringBuilder();
        var bodies = new StringBuilder();
        foreach (var name in order)
        {
            var parts = Sections(File.ReadAllText(Path.Combine(FragmentDirectory, name + ".sql")));
            specs.Append(parts.GetValueOrDefault("SPEC", ""));
            bodies.Append(parts.GetValueOrDefault("BODY", ""));
        }

        return frame.GetValueOrDefault("PREAMBLE", "")
             + frame.GetValueOrDefault("SPEC-OPEN", "")
             + frame.GetValueOrDefault("SPEC-HEAD", "")
             + specs
             + frame.GetValueOrDefault("SPEC-TAIL", "")
             + frame.GetValueOrDefault("BODY-OPEN", "")
             + frame.GetValueOrDefault("BODY-HEAD", "")
             + bodies
             + frame.GetValueOrDefault("BODY-TAIL", "");
    }

    /// <summary>One form's source, exactly as the file holds it.</summary>
    public string? ReadFragment(string form)
    {
        var path = FragmentPath(form);
        return path is not null && File.Exists(path) ? File.ReadAllText(path) : null;
    }

    /// <summary>What a fragment contains, for a listing.</summary>
    public List<FragmentInfo> DescribeFragments()
    {
        var infos = new List<FragmentInfo>();
        foreach (var name in FragmentOrder())
        {
            var text = File.ReadAllText(Path.Combine(FragmentDirectory, name + ".sql"));
            var parts = Sections(text);
            var spec = TopLevelUnit.Matches(parts.GetValueOrDefault("SPEC", ""))
                .Select(m => m.Groups[1].Value).ToList();
            var body = TopLevelUnit.Matches(parts.GetValueOrDefault("BODY", ""))
                .Select(m => m.Groups[1].Value).ToList();

            infos.Add(new FragmentInfo(
                name,
                spec.Count,
                body.Count,
                body.Except(spec, StringComparer.OrdinalIgnoreCase).Count(),
                text.Length,
                spec.OrderBy(p => p, StringComparer.OrdinalIgnoreCase).ToList()));
        }
        return infos;
    }

    private string? FragmentPath(string form)
    {
        // The name becomes a filename, so it may not wander out of the directory.
        if (string.IsNullOrWhiteSpace(form) || !Regex.IsMatch(form, @"^[A-Za-z0-9_]{1,40}$"))
        {
            return null;
        }
        if (form.Equals("_frame", StringComparison.OrdinalIgnoreCase)
            || form.Equals("_manifest", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }
        return Path.Combine(FragmentDirectory, form.ToUpperInvariant() + ".sql");
    }

    /// <summary>
    /// Replaces one form's fragment.
    ///
    /// Every procedure in a form's fragment must begin with that form's name and an
    /// underscore. That rule is what makes the split hold: it is how the first split decided
    /// where each of the 168 procedures went, it is what stops two forms claiming the same
    /// procedure, and it is what makes "AT5510 is mine" true rather than a convention people
    /// remember. _COMMON is the one exemption, for the shared helpers that belong to no form.
    /// </summary>
    public FragmentWrite WriteFragment(string form, string text)
    {
        var path = FragmentPath(form);
        if (path is null)
        {
            return FragmentWrite.Refused($"'{form}' is not a usable fragment name.");
        }

        var name = form.ToUpperInvariant();
        var parts = Sections(text);

        var unknown = UnknownMarkers(text);
        if (unknown.Count > 0)
        {
            return FragmentWrite.Refused(
                "The --# prefix opens a section and is reserved for SPEC and BODY. This file "
                + "uses " + string.Join(", ", unknown.Select(u => "--#" + u))
                + ". Mark a generated region with something else, for example the "
                + "'-- >>> generated by ...' and '-- <<< end of ...' lines already in use; "
                + "anything not starting --# is kept verbatim.");
        }

        if (!parts.ContainsKey("SPEC") && !parts.ContainsKey("BODY"))
        {
            return FragmentWrite.Refused(
                "The fragment needs a --#SPEC line and a --#BODY line. Everything above the "
                + "first marker is a comment; declarations go under --#SPEC and definitions "
                + "under --#BODY.");
        }

        // Check the code, not the comments: every fragment's own header says the words
        // "No CREATE OR REPLACE here", and the ported trigger text quoted in several of
        // them contains all sorts of SQL.
        var code = StripComments(text);

        if (code.Contains("CREATE OR REPLACE", StringComparison.OrdinalIgnoreCase))
        {
            return FragmentWrite.Refused(
                "A fragment holds no CREATE OR REPLACE. It is concatenated inside the package "
                + "the frame opens.");
        }

        if (Regex.IsMatch(code, @"(?m)^\s*/\s*$"))
        {
            return FragmentWrite.Refused(
                "A fragment holds no slash lines. The frame supplies the two that terminate "
                + "the spec and the body.");
        }

        var spec = TopLevelUnit.Matches(parts.GetValueOrDefault("SPEC", ""))
            .Select(m => m.Groups[1].Value).ToList();
        var body = TopLevelUnit.Matches(parts.GetValueOrDefault("BODY", ""))
            .Select(m => m.Groups[1].Value).ToList();

        var wrongPrefix = new List<string>();
        if (!name.Equals(CommonFragment, StringComparison.OrdinalIgnoreCase))
        {
            var required = name.ToLowerInvariant() + "_";
            wrongPrefix = spec.Concat(body)
                .Where(p => !p.StartsWith(required, StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(p => p, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        if (wrongPrefix.Count > 0)
        {
            return FragmentWrite.Refused(
                $"Every procedure in {name} must be named {name.ToLowerInvariant()}_<something>. "
                + $"These are not: {string.Join(", ", wrongPrefix)}. A shared helper that belongs "
                + $"to no form goes in {CommonFragment} instead.");
        }

        // A declaration with no definition is PLS-00323 at compile time; catch it here where
        // the message can say which procedure, rather than at deploy where it cannot.
        var undefined = spec.Except(body, StringComparer.OrdinalIgnoreCase).ToList();
        if (undefined.Count > 0)
        {
            return FragmentWrite.Refused(
                "Declared under --#SPEC but not defined under --#BODY: "
                + string.Join(", ", undefined)
                + ". Oracle reports this as PLS-00323 against the whole package.");
        }

        var existed = File.Exists(path);
        var previousBytes = existed ? new FileInfo(path).Length : 0;
        string? backup = null;
        if (existed)
        {
            backup = path + "." + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".bak";
            File.Copy(path, backup, overwrite: true);
        }

        File.WriteAllText(path, text);

        _logger.LogWarning(
            "EWT_UI fragment {Form} {Action}: {Old} -> {New} bytes, {Spec} declarations, {Body} definitions",
            name, existed ? "replaced" : "created", previousBytes, text.Length, spec.Count, body.Count);

        return new FragmentWrite(true, name, Path.GetFileName(path),
            backup is null ? null : Path.GetFileName(backup),
            previousBytes, text.Length, spec.Count, body.Count, existed, null);
    }

    /// <summary>Removes a form's fragment. _COMMON cannot go: other fragments call into it.</summary>
    public FragmentWrite DeleteFragment(string form)
    {
        var path = FragmentPath(form);
        if (path is null)
        {
            return FragmentWrite.Refused($"'{form}' is not a usable fragment name.");
        }

        var name = form.ToUpperInvariant();
        if (name.Equals(CommonFragment, StringComparison.OrdinalIgnoreCase))
        {
            return FragmentWrite.Refused(
                $"{CommonFragment} holds the helpers other fragments call, so it cannot be removed.");
        }

        if (!File.Exists(path))
        {
            return FragmentWrite.Refused($"There is no fragment named {name}.");
        }

        var bytes = new FileInfo(path).Length;
        var backup = path + "." + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".bak";
        File.Copy(path, backup, overwrite: true);
        File.Delete(path);

        _logger.LogWarning("EWT_UI fragment {Form} deleted ({Bytes} bytes), kept at {Backup}",
            name, bytes, Path.GetFileName(backup));

        return new FragmentWrite(true, name, null, Path.GetFileName(backup),
            bytes, 0, 0, 0, true, null);
    }
}

/// <summary>What one form's fragment holds.</summary>
public record FragmentInfo(
    string Form,
    int Declarations,
    int Definitions,
    int PrivateHelpers,
    long Bytes,
    IReadOnlyList<string> Procedures);

/// <summary>The outcome of writing or deleting a fragment.</summary>
public record FragmentWrite(
    bool Ok,
    string? Form,
    string? FileName,
    string? BackupFileName,
    long PreviousBytes,
    long NewBytes,
    int Declarations,
    int Definitions,
    bool Existed,
    string? Refusal)
{
    public static FragmentWrite Refused(string why) =>
        new(false, null, null, null, 0, 0, 0, 0, false, why);
}
