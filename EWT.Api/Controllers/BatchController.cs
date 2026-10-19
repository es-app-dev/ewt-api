using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Oracle.ManagedDataAccess.Client;
using EWT.Api.Services;
using EWT.Services.Utilites;

namespace EWT.Api.Controllers;

/// <summary>
/// POST /odata/$batch: several writes, committed together.
///
/// Oracle Forms commits a whole master-detail hierarchy as one transaction. Saving an
/// AT3110 manifest writes the manifest, its materials, its containers and their waste
/// codes in one go, and there are 240 master-detail relations in the application. Split
/// across independent HTTP calls, a failure halfway leaves the row half saved.
///
/// This is the OData V4 JSON batch format. Requests carrying the same atomicityGroup run
/// on one Oracle connection inside one transaction: all of them commit, or none do.
/// Requests with no atomicityGroup run independently, exactly as if they had been sent
/// one at a time.
///
/// A request may use the key a previous one produced. Write $id.COLUMN as a value in a
/// later body and it is substituted with that value, which is how a child row picks up
/// the sequence-assigned key of the parent created earlier in the same change set.
///
/// The multipart/mixed batch format is deliberately not supported; the JSON format
/// carries the same semantics and both ends of this system speak JSON already.
/// </summary>
[ApiController]
[Route("odata")]
[Tags("OData")]
public class BatchController : ControllerBase
{
    /// <summary>Most operations one batch may carry. AT3110's worst save is well inside this.</summary>
    private const int MaxRequests = 500;

    private static readonly Regex ContentIdReference =
        new(@"^\$([A-Za-z0-9_-]+)\.([A-Za-z0-9_$#]+)$", RegexOptions.Compiled);

    private readonly DynamicDataService _dataService;
    private readonly OracleConnectionService _connectionService;
    private readonly DynamicEdmModelBuilder _modelBuilder;
    private readonly IAuditService _audit;
    private readonly ILogger<BatchController> _logger;

    public BatchController(
        DynamicDataService dataService,
        OracleConnectionService connectionService,
        DynamicEdmModelBuilder modelBuilder,
        IAuditService audit,
        ILogger<BatchController> logger)
    {
        _dataService = dataService;
        _connectionService = connectionService;
        _modelBuilder = modelBuilder;
        _audit = audit;
        _logger = logger;
    }

    /// <summary>
    /// Several writes in one request, committed together or not at all.
    /// </summary>
    /// <remarks>
    /// Oracle Forms saves a whole master-detail hierarchy as one transaction, and there are
    /// 240 master-detail relations in this application. Split across separate HTTP calls, a
    /// failure halfway leaves the row half saved. This is the OData V4 **JSON** batch format;
    /// multipart is not supported.
    ///
    /// **A manifest and its child rows, saved atomically**
    ///
    ///     POST /odata/$batch
    ///     { "requests": [
    ///         { "id": "1", "method": "POST", "atomicityGroup": "save",
    ///           "url": "/odata/AT_MANIFESTS?db=BCTN",
    ///           "body": { "MANIFEST_NBR": "X-1" } },
    ///         { "id": "2", "method": "POST", "atomicityGroup": "save",
    ///           "url": "/odata/AT_MANIFEST_MATERIALS?db=BCTN",
    ///           "body": { "MNFST_SEQ_ID": "$1.MNFST_SEQ_ID", "MATERIAL_CD": "SOIL" } }
    ///     ] }
    ///
    /// **`$1.COLUMN` is replaced by what request `1` returned.** That is how a child row picks
    /// up the key the server just allocated for its parent, which is the reason master-detail
    /// saves need a batch at all.
    ///
    /// **Requests sharing an `atomicityGroup` run in one transaction.** All commit or none do.
    /// Requests without one run independently, exactly as if sent separately.
    ///
    /// **The outer response is always 200.** Each entry carries its own status, per OData, so
    /// check the entries and not the envelope. When a change set fails you can see which
    /// request broke it:
    ///
    ///     id=1 status=424 ChangeSetRolledBack  succeeded, then rolled back
    ///     id=2 status=409 ORA-00904            "NO_SUCH_COLUMN": invalid identifier
    ///     id=3 status=424 ChangeSetRolledBack  not attempted
    ///
    /// **A change set cannot span databases.** One transaction is one Oracle connection, so
    /// requests in one group must share a `?db=`. For a screen spanning CORP and a site, use
    /// one change set per database and send the CORP half first: an orphaned master row is
    /// recoverable, a dangling reference is not.
    ///
    /// `PATCH` and `DELETE` inside a batch address the row with `$filter` in the request url,
    /// and take an optional `ifMatch` per request. Reads stay ordinary GET requests. At most
    /// 500 requests per batch. Audit rows are written after the commit, so a rolled-back
    /// write is never recorded as having happened.
    /// </remarks>
    /// <param name="batch">The batch envelope: a "requests" array.</param>
    /// <response code="200">The batch ran. Check each entry's own status.</response>
    /// <response code="400">Empty batch, more than 500 requests, or duplicate ids.</response>
    [HttpPost("$batch")]
    public async Task<IActionResult> Batch([FromBody] BatchRequest batch)
    {
        if (batch?.Requests == null || batch.Requests.Count == 0)
        {
            return BadRequest(new
            {
                error = new
                {
                    code = "EmptyBatch",
                    message = "A batch needs a 'requests' array.",
                    hint = "Each entry is { id, method, url, atomicityGroup, body }. Requests "
                           + "sharing an atomicityGroup commit or roll back together."
                }
            });
        }

        if (batch.Requests.Count > MaxRequests)
        {
            return BadRequest(new
            {
                error = new
                {
                    code = "BatchTooLarge",
                    message = $"A batch may carry at most {MaxRequests} requests; this one has "
                              + $"{batch.Requests.Count}."
                }
            });
        }

        var duplicateId = batch.Requests
            .Where(r => !string.IsNullOrWhiteSpace(r.Id))
            .GroupBy(r => r.Id!, StringComparer.Ordinal)
            .FirstOrDefault(g => g.Count() > 1);
        if (duplicateId != null)
        {
            return BadRequest(new
            {
                error = new
                {
                    code = "DuplicateContentId",
                    message = $"Two requests share id '{duplicateId.Key}'. Ids address results, "
                              + "so they have to be unique within a batch."
                }
            });
        }

        var (ownerUser, ownerDisplay) = ResolveOwner();
        if (_audit.RequireOwner && string.IsNullOrWhiteSpace(ownerUser))
        {
            return BadRequest(new { error = new { message = "Owner attribution required (X-EWT-On-Behalf-Of header or authenticated user)." } });
        }

        // Results of earlier requests, for $id.COLUMN references in later ones.
        var results = new Dictionary<string, Dictionary<string, object?>>(StringComparer.Ordinal);
        var responses = new List<BatchResponse>();

        // Preserve the order the caller sent, but run each atomicity group as one unit.
        foreach (var group in GroupInOrder(batch.Requests))
        {
            if (group.Key == null)
            {
                foreach (var request in group.Requests)
                {
                    responses.Add(await RunOneAsync(request, null, results, ownerUser, ownerDisplay));
                }
                continue;
            }

            responses.AddRange(
                await RunChangeSetAsync(group.Key, group.Requests, results, ownerUser, ownerDisplay));
        }

        // 200 always: the batch itself succeeded even when an operation inside it did not.
        // Per-request status is in each response, which is what OData specifies.
        return Ok(new { responses });
    }

    /// <summary>
    /// Runs one change set: one connection, one transaction, all or nothing.
    ///
    /// On the first failure the transaction rolls back and the remaining requests in the
    /// set are reported as 424 Failed Dependency rather than being attempted, so the caller
    /// can see which operation actually broke.
    /// </summary>
    private async Task<List<BatchResponse>> RunChangeSetAsync(
        string groupKey,
        List<BatchOperation> requests,
        Dictionary<string, Dictionary<string, object?>> results,
        string? ownerUser,
        string? ownerDisplay)
    {
        // Every write in one transaction must be on one connection, so one database.
        List<string> instances;
        try
        {
            instances = requests
                .Select(ResolveInstanceOf)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch (BatchUrlException ex)
        {
            return requests
                .Select(r => Failure(r, StatusCodes.Status400BadRequest, "BadBatchUrl", ex.Message))
                .ToList();
        }

        if (instances.Count > 1)
        {
            var message = $"Change set '{groupKey}' spans databases ({string.Join(", ", instances)}). "
                          + "One transaction is one database; split it into one change set per db, "
                          + "accepting that the two halves then commit separately.";
            _logger.LogWarning("{Message}", message);
            return requests
                .Select(r => Failure(r, StatusCodes.Status400BadRequest, "ChangeSetSpansDatabases", message))
                .ToList();
        }

        var instance = instances[0];
        var responses = new List<BatchResponse>();

        // Results produced inside this change set, discarded if it rolls back, so nothing
        // later can reference a key that was never committed.
        var pending = new Dictionary<string, Dictionary<string, object?>>(StringComparer.Ordinal);
        var auditQueue = new List<Func<Task>>();

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();
        var scope = new DbScope(connection, transaction);

        var failed = false;
        foreach (var request in requests)
        {
            if (failed)
            {
                responses.Add(Failure(request, StatusCodes.Status424FailedDependency,
                    "ChangeSetRolledBack",
                    $"Not attempted: an earlier request in change set '{groupKey}' failed and "
                    + "the whole set was rolled back."));
                continue;
            }

            var response = await RunOneAsync(request, scope, Merge(results, pending),
                ownerUser, ownerDisplay, auditQueue);
            responses.Add(response);

            if (response.Status >= 400)
            {
                failed = true;
            }
            else if (!string.IsNullOrWhiteSpace(request.Id) && response.Body is Dictionary<string, object?> created)
            {
                pending[request.Id!] = created;
            }
        }

        if (failed)
        {
            transaction.Rollback();
            _logger.LogWarning("Change set {Group} rolled back on {Instance}", groupKey, instance);

            // Anything that did succeed before the failure no longer happened, and the
            // caller has to be told that rather than reading a 201 for a row that is gone.
            for (var i = 0; i < responses.Count; i++)
            {
                if (responses[i].Status < 400)
                {
                    responses[i] = Failure(requests[i], StatusCodes.Status424FailedDependency,
                        "ChangeSetRolledBack",
                        "Succeeded, then rolled back because a later request in change set "
                        + $"'{groupKey}' failed.");
                }
            }
            return responses;
        }

        transaction.Commit();
        _logger.LogInformation("Change set {Group} committed {Count} write(s) on {Instance}",
            groupKey, requests.Count, instance);

        foreach (var (id, row) in pending)
        {
            results[id] = row;
        }

        // Audit only what committed. Writing it inside the transaction would roll the audit
        // back with the data; writing it before the commit would record writes that never landed.
        foreach (var write in auditQueue)
        {
            await write();
        }

        return responses;
    }

    /// <summary>Executes one operation, inside the change set's transaction when there is one.</summary>
    private async Task<BatchResponse> RunOneAsync(
        BatchOperation request,
        DbScope? scope,
        IReadOnlyDictionary<string, Dictionary<string, object?>> results,
        string? ownerUser,
        string? ownerDisplay,
        List<Func<Task>>? auditQueue = null)
    {
        string instance;
        string entitySet;
        string? filter;
        try
        {
            instance = ResolveInstanceOf(request);
            (entitySet, filter) = ParseUrl(request.Url);
        }
        catch (BatchUrlException ex)
        {
            return Failure(request, StatusCodes.Status400BadRequest, "BadBatchUrl", ex.Message);
        }

        if (!_modelBuilder.GetEntityMetadata(instance).ContainsKey(entitySet))
        {
            var elsewhere = _modelBuilder.InstancesWith(entitySet);
            return Failure(request, StatusCodes.Status404NotFound, "EntitySetNotOnInstance",
                elsewhere.Count > 0
                    ? $"'{entitySet}' does not exist on '{instance}'; it is on {string.Join(", ", elsewhere)}."
                    : $"'{entitySet}' does not exist on any configured database.");
        }

        var method = (request.Method ?? "").ToUpperInvariant();
        try
        {
            var body = Resolve(request.Body, results);

            switch (method)
            {
                case "POST":
                {
                    if (body.Count == 0)
                    {
                        return Failure(request, StatusCodes.Status400BadRequest, "EmptyBody",
                            "POST needs a body.");
                    }

                    var created = await _dataService.InsertAsync(instance, entitySet, body, scope);
                    Queue(auditQueue, () => _audit.WriteAsync(instance, entitySet, "INSERT",
                        KeyOf(instance, entitySet, created), body, ownerUser, ownerDisplay));
                    return new BatchResponse
                    {
                        Id = request.Id,
                        Status = StatusCodes.Status201Created,
                        Body = created
                    };
                }

                case "PATCH":
                {
                    if (body.Count == 0)
                    {
                        return Failure(request, StatusCodes.Status400BadRequest, "EmptyBody",
                            "PATCH needs a body.");
                    }

                    if (!string.IsNullOrWhiteSpace(filter))
                    {
                        await _dataService.UpdateWhereAsync(instance, entitySet, filter, body, scope, request.IfMatch);
                        Queue(auditQueue, () => _audit.WriteAsync(instance, entitySet, "UPDATE",
                            FilterKey(filter), body, ownerUser, ownerDisplay));
                        return new BatchResponse { Id = request.Id, Status = StatusCodes.Status204NoContent };
                    }

                    var metadata = _modelBuilder.GetEntityMetadata(instance)[entitySet];
                    if (metadata.PrimaryKeyColumns.Count == 0)
                    {
                        return Failure(request, StatusCodes.Status400BadRequest, "NoPrimaryKey",
                            $"'{entitySet}' declares no primary key. Address the row with "
                            + "$filter in the request url.");
                    }

                    var keyValues = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                    var missing = new List<string>();
                    foreach (var pk in metadata.PrimaryKeyColumns)
                    {
                        if (body.TryGetValue(pk, out var v) && v != null)
                        {
                            keyValues[pk] = v;
                        }
                        else
                        {
                            missing.Add(pk);
                        }
                    }

                    if (missing.Count > 0)
                    {
                        return Failure(request, StatusCodes.Status400BadRequest, "MissingKey",
                            $"PATCH needs the primary key in the body: {string.Join(", ", missing)}.");
                    }

                    var updates = body
                        .Where(kv => !metadata.PrimaryKeyColumns.Contains(kv.Key, StringComparer.OrdinalIgnoreCase))
                        .ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.OrdinalIgnoreCase);
                    if (updates.Count == 0)
                    {
                        return Failure(request, StatusCodes.Status400BadRequest, "NothingToUpdate",
                            "The body has only key columns, so there is nothing to change.");
                    }

                    var rows = await _dataService.UpdateAsync(instance, entitySet, keyValues, updates, scope, request.IfMatch);
                    if (rows == 0)
                    {
                        return Failure(request, StatusCodes.Status404NotFound, "NoMatchingRow",
                            "No row with that key.");
                    }

                    Queue(auditQueue, () => _audit.WriteAsync(instance, entitySet, "UPDATE",
                        keyValues.ToDictionary(k => k.Key, k => (object?)k.Value, StringComparer.OrdinalIgnoreCase),
                        updates, ownerUser, ownerDisplay));
                    return new BatchResponse { Id = request.Id, Status = StatusCodes.Status204NoContent };
                }

                case "DELETE":
                {
                    if (string.IsNullOrWhiteSpace(filter))
                    {
                        return Failure(request, StatusCodes.Status400BadRequest, "FilterRequired",
                            "DELETE in a batch addresses the row with $filter in the url.");
                    }

                    await _dataService.DeleteWhereAsync(instance, entitySet, filter, scope, request.IfMatch);
                    Queue(auditQueue, () => _audit.WriteAsync(instance, entitySet, "DELETE",
                        FilterKey(filter), null, ownerUser, ownerDisplay));
                    return new BatchResponse { Id = request.Id, Status = StatusCodes.Status204NoContent };
                }

                default:
                    return Failure(request, StatusCodes.Status405MethodNotAllowed, "MethodNotAllowed",
                        $"'{request.Method}' is not supported in a batch. Use POST, PATCH or DELETE; "
                        + "reads go through ordinary GET requests.");
            }
        }
        catch (BatchUrlException ex)
        {
            return Failure(request, StatusCodes.Status400BadRequest, "BadReference", ex.Message);
        }
        catch (RowLockedException ex)
        {
            return Failure(request, StatusCodes.Status409Conflict, "RowLockedByAnotherUser",
                ex.Message);
        }
        catch (RowChangedException ex)
        {
            return Failure(request, StatusCodes.Status412PreconditionFailed, "RowChangedByAnother",
                ex.Message);
        }
        catch (ConcurrencyNotSupportedException ex)
        {
            return Failure(request, StatusCodes.Status400BadRequest, "IfMatchNotSupported",
                ex.Message);
        }
        catch (AmbiguousRowException ex)
        {
            return Failure(request,
                ex.MatchedRows == 0 ? StatusCodes.Status404NotFound : StatusCodes.Status409Conflict,
                ex.MatchedRows == 0 ? "NoMatchingRow" : "FilterNotUnique", ex.Message);
        }
        catch (ReadOnlyEntityException ex)
        {
            return Failure(request, StatusCodes.Status405MethodNotAllowed, "ReadOnlyEntity", ex.Message);
        }
        catch (TableNotFoundException ex)
        {
            return Failure(request, StatusCodes.Status404NotFound, "TableNotFound", ex.Message);
        }
        catch (FilterValidationException ex)
        {
            return Failure(request, StatusCodes.Status400BadRequest, "BadFilter", ex.Message);
        }
        catch (QueryValidationException ex)
        {
            return Failure(request, StatusCodes.Status400BadRequest, "BadQuery", ex.Message);
        }
        catch (OracleException ex)
        {
            _logger.LogWarning(ex, "Oracle error on batch request {Id} ({Method} {Url})",
                request.Id, request.Method, request.Url);
            return Failure(request, StatusCodes.Status409Conflict, $"ORA-{ex.Number:00000}", ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Batch request {Id} ({Method} {Url}) failed",
                request.Id, request.Method, request.Url);
            return Failure(request, StatusCodes.Status500InternalServerError, "UnhandledError", ex.Message);
        }
    }

    /// <summary>
    /// Replaces $id.COLUMN references with the value an earlier request produced.
    ///
    /// This is what lets a child row use the key the server just allocated for its parent,
    /// which is the whole reason master-detail saves need a batch in the first place.
    /// </summary>
    private static Dictionary<string, object?> Resolve(
        Dictionary<string, JsonElement>? body,
        IReadOnlyDictionary<string, Dictionary<string, object?>> results)
    {
        var resolved = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        if (body == null)
        {
            return resolved;
        }

        foreach (var (key, element) in body)
        {
            var value = ConvertJsonElement(element);

            if (value is string text)
            {
                var match = ContentIdReference.Match(text);
                if (match.Success)
                {
                    var id = match.Groups[1].Value;
                    var column = match.Groups[2].Value;
                    if (!results.TryGetValue(id, out var earlier))
                    {
                        throw new BatchUrlException(
                            $"'{text}' refers to request '{id}', which has not run or produced nothing. "
                            + "A reference can only point at an earlier request in the same batch.");
                    }
                    if (!earlier.TryGetValue(column, out var referenced))
                    {
                        throw new BatchUrlException(
                            $"Request '{id}' returned no column '{column}'. It returned: "
                            + string.Join(", ", earlier.Keys) + ".");
                    }
                    value = referenced;
                }
            }

            resolved[key.ToUpperInvariant()] = value;
        }

        return resolved;
    }

    /// <summary>Splits a batch request url into its entity set and its $filter.</summary>
    private static (string EntitySet, string? Filter) ParseUrl(string? url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            throw new BatchUrlException("Each request needs a url, for example /odata/AT_ADDRESSES?db=CORP");
        }

        var questionMark = url.IndexOf('?');
        var path = (questionMark < 0 ? url : url[..questionMark]).Trim('/');
        var query = questionMark < 0 ? "" : url[(questionMark + 1)..];

        if (path.StartsWith("odata/", StringComparison.OrdinalIgnoreCase))
        {
            path = path["odata/".Length..];
        }

        if (string.IsNullOrWhiteSpace(path) || path.Contains('/'))
        {
            throw new BatchUrlException(
                $"'{url}' is not an entity set url. Expected /odata/ENTITY_SET?db=DB");
        }

        var parsed = QueryHelpers.ParseQuery(query);
        var filter = parsed.TryGetValue("$filter", out var f) ? f.FirstOrDefault() : null;
        return (path.ToUpperInvariant(), string.IsNullOrWhiteSpace(filter) ? null : filter);
    }

    /// <summary>The database a batch request targets, from ?db= in its url.</summary>
    private string ResolveInstanceOf(BatchOperation request)
    {
        string? db = null;
        var questionMark = request.Url?.IndexOf('?') ?? -1;
        if (questionMark >= 0)
        {
            var parsed = QueryHelpers.ParseQuery(request.Url![(questionMark + 1)..]);
            db = parsed.TryGetValue("db", out var v) ? v.FirstOrDefault() : null;
        }

        try
        {
            return _connectionService.ResolveInstanceName(db);
        }
        catch (UnknownInstanceException ex)
        {
            throw new BatchUrlException(
                $"Unknown database '{db}'. Known: {string.Join(", ", ex.KnownInstances)}.");
        }
    }

    /// <summary>Groups requests by atomicityGroup, keeping the order the caller sent.</summary>
    private static List<(string? Key, List<BatchOperation> Requests)> GroupInOrder(List<BatchOperation> requests)
    {
        var groups = new List<(string? Key, List<BatchOperation> Requests)>();
        var byKey = new Dictionary<string, int>(StringComparer.Ordinal);

        foreach (var request in requests)
        {
            var key = string.IsNullOrWhiteSpace(request.AtomicityGroup) ? null : request.AtomicityGroup;
            if (key == null)
            {
                groups.Add((null, new List<BatchOperation> { request }));
                continue;
            }

            if (byKey.TryGetValue(key, out var index))
            {
                groups[index].Requests.Add(request);
                continue;
            }

            byKey[key] = groups.Count;
            groups.Add((key, new List<BatchOperation> { request }));
        }

        return groups;
    }

    private Dictionary<string, object?> KeyOf(string instance, string entitySet, IReadOnlyDictionary<string, object?> row)
    {
        var key = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        if (_modelBuilder.GetEntityMetadata(instance).TryGetValue(entitySet, out var metadata))
        {
            foreach (var column in metadata.PrimaryKeyColumns)
            {
                if (row.TryGetValue(column, out var v))
                {
                    key[column] = v;
                }
            }
        }
        return key;
    }

    private static Dictionary<string, object?> FilterKey(string? filter) =>
        new(StringComparer.OrdinalIgnoreCase) { ["$filter"] = filter };

    /// <summary>Runs the audit write now, or defers it to the commit when in a change set.</summary>
    private static void Queue(List<Func<Task>>? auditQueue, Func<Task> write)
    {
        if (auditQueue != null)
        {
            auditQueue.Add(write);
            return;
        }

        // Outside a change set the write has already committed, so record it immediately.
        _ = write();
    }

    private static IReadOnlyDictionary<string, Dictionary<string, object?>> Merge(
        Dictionary<string, Dictionary<string, object?>> committed,
        Dictionary<string, Dictionary<string, object?>> pending)
    {
        if (pending.Count == 0)
        {
            return committed;
        }

        var merged = new Dictionary<string, Dictionary<string, object?>>(committed, StringComparer.Ordinal);
        foreach (var (k, v) in pending)
        {
            merged[k] = v;
        }
        return merged;
    }

    private static BatchResponse Failure(BatchOperation request, int status, string code, string message) =>
        new()
        {
            Id = request.Id,
            Status = status,
            Body = new Dictionary<string, object?>
            {
                ["error"] = new Dictionary<string, object?> { ["code"] = code, ["message"] = message }
            }
        };

    private (string? User, string? Display) ResolveOwner()
    {
        var oid = UserContextHelper.GetUserOid();
        if (!string.IsNullOrWhiteSpace(oid))
        {
            var name = UserContextHelper.GetUserName();
            return (oid, string.IsNullOrWhiteSpace(name) ? null : name);
        }

        var headerUser = Request.Headers["X-EWT-On-Behalf-Of"].FirstOrDefault();
        var headerName = Request.Headers["X-EWT-On-Behalf-Of-Name"].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(headerUser))
        {
            return (headerUser, string.IsNullOrWhiteSpace(headerName) ? null : headerName);
        }

        return (null, null);
    }

    private static object? ConvertJsonElement(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.String:
                return element.GetString();
            case JsonValueKind.Number:
                if (element.TryGetInt64(out var l)) return l;
                return element.GetDecimal();
            case JsonValueKind.True:
                return true;
            case JsonValueKind.False:
                return false;
            case JsonValueKind.Null:
            case JsonValueKind.Undefined:
                return null;
            default:
                return element.ToString();
        }
    }
}

/// <summary>A malformed batch request url, or a content-id reference that cannot be resolved.</summary>
public class BatchUrlException : Exception
{
    public BatchUrlException(string message) : base(message) { }
}

/// <summary>The OData V4 JSON batch envelope.</summary>
public class BatchRequest
{
    public List<BatchOperation> Requests { get; set; } = new();
}

/// <summary>One operation in a batch.</summary>
public class BatchOperation
{
    /// <summary>Caller's id for this request, used to reference its result from a later one.</summary>
    public string? Id { get; set; }

    /// <summary>POST, PATCH or DELETE. Reads are ordinary GET requests.</summary>
    public string? Method { get; set; }

    /// <summary>For example /odata/AT_ADDRESSES?db=CORP, optionally with $filter.</summary>
    public string? Url { get; set; }

    /// <summary>Requests sharing this value commit or roll back together.</summary>
    public string? AtomicityGroup { get; set; }

    /// <summary>
    /// The MODIFIED_DT this request read, for an optimistically guarded PATCH or DELETE.
    /// A losing race fails the request, which rolls back the whole change set.
    /// </summary>
    public string? IfMatch { get; set; }

    public Dictionary<string, JsonElement>? Body { get; set; }
}

/// <summary>One operation's outcome.</summary>
public class BatchResponse
{
    public string? Id { get; set; }
    public int Status { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public object? Body { get; set; }
}
