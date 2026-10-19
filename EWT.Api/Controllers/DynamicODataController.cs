using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Oracle.ManagedDataAccess.Client;
using EWT.Api.Services;
using EWT.Services.Utilites;
using System.Text.Json;

namespace EWT.Api.Controllers;

/// <summary>
/// Dynamic OData controller that handles all Oracle entities.
/// TODO: Re-enable [Authorize] after debugging
/// </summary>
// [Authorize]  // Disabled for debugging
[ApiController]
[Route("odata")]
[Tags("OData")]
public class DynamicODataController : ControllerBase
{
    /// <summary>Largest page a caller may request with $top.</summary>
    private const int MaxTop = 10000;

    /// <summary>Page size when $top is not supplied.</summary>
    private const int DefaultTop = 100;

    private readonly DynamicDataService _dataService;
    private readonly OracleConnectionService _connectionService;
    private readonly DynamicEdmModelBuilder _modelBuilder;
    private readonly RelationshipService _relationshipService;
    private readonly BlockWhereService _blockWheres;
    private readonly IAuditService _audit;
    private readonly ILogger<DynamicODataController> _logger;

    public DynamicODataController(
        DynamicDataService dataService,
        OracleConnectionService connectionService,
        DynamicEdmModelBuilder modelBuilder,
        RelationshipService relationshipService,
        BlockWhereService blockWheres,
        IAuditService audit,
        ILogger<DynamicODataController> logger)
    {
        _dataService = dataService;
        _connectionService = connectionService;
        _modelBuilder = modelBuilder;
        _relationshipService = relationshipService;
        _blockWheres = blockWheres;
        _audit = audit;
        _logger = logger;
    }

    /// <summary>
    /// Resolves the acting user for audit: JWT oid claim first, then the
    /// X-EWT-On-Behalf-Of header(s), else (null, null).
    /// </summary>
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

    /// <summary>Builds the primary-key sub-document for the audit event from resolved metadata.</summary>
    private Dictionary<string, object?> BuildAuditPk(string instance, string entitySet, IReadOnlyDictionary<string, object?> source)
    {
        var pk = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        var metadata = _modelBuilder.GetEntityMetadata(instance);
        if (metadata.TryGetValue(entitySet.ToUpperInvariant(), out var em))
        {
            foreach (var col in em.PrimaryKeyColumns)
            {
                if (source.TryGetValue(col, out var v)) pk[col] = v;
            }
        }
        return pk;
    }

    /// <summary>
    /// Resolves the database for this request from the ?db= parameter, falling back to
    /// the configured default when it is omitted. Rejects unknown names before any
    /// connection is attempted.
    /// </summary>
    private bool TryResolveInstance(string? db, out string instance, out IActionResult? error)
    {
        try
        {
            instance = _connectionService.ResolveInstanceName(db);
            error = null;
            return true;
        }
        catch (UnknownInstanceException ex)
        {
            _logger.LogWarning("Request for unknown database {Requested}", ex.RequestedInstance);
            instance = string.Empty;
            error = NotFound(new
            {
                error = new
                {
                    code = "UnknownInstance",
                    message = string.IsNullOrWhiteSpace(db)
                        ? "No database specified and no default is configured. Pass ?db=<name>."
                        : $"Unknown database '{db}'.",
                    parameter = "db",
                    availableDatabases = ex.KnownInstances.ToList()
                }
            });
            return false;
        }
    }

    /// <summary>
    /// True when this entity does not exist on this instance. The 404 it produces names
    /// the instances that do have it, so a caller never has to tell an absent table apart
    /// from an empty one.
    /// </summary>
    private bool MissingOnInstance(string instance, string entitySet, out IActionResult? error)
    {
        var metadata = _modelBuilder.GetEntityMetadata(instance);
        if (metadata.ContainsKey(entitySet.ToUpperInvariant()))
        {
            error = null;
            return false;
        }

        var elsewhere = _modelBuilder.InstancesWith(entitySet.ToUpperInvariant());
        error = NotFound(new
        {
            error = new
            {
                code = "EntitySetNotOnInstance",
                message = elsewhere.Count > 0
                    ? $"'{entitySet}' does not exist on database '{instance}'."
                    : $"'{entitySet}' does not exist on any configured database.",
                entitySet = entitySet.ToUpperInvariant(),
                requestedDatabase = instance,
                availableOn = elsewhere,
                // Deliberately NOT "retry with ?db=CORP". That advice caused a real defect:
                // a screen signed in to BCTN followed it, wrote to the API's own CORP
                // connection, and the legacy screen on BCTN never showed the row. Where a
                // site can reach central data it does so through its own synonym, on its own
                // connection, which is what the legacy does. Naming another instance here
                // invites a second opinion about where the data lives.
                hint = elsewhere.Count > 0
                    ? $"Not found on '{instance}'. It exists on {string.Join(", ", elsewhere)}, "
                      + "but only query another database if that is genuinely the one the "
                      + "screen means; a site session normally reaches central data through "
                      + "its own connection."
                    : "Check the spelling against GET /odata?db=" + instance + "."
            }
        });
        return true;
    }

    /// <summary>
    /// List every table and view available on a database.
    /// </summary>
    /// <remarks>
    /// The catalogue for one database, and it differs per database: the seven schemas share
    /// column structure but not which tables exist. Each entry says whether it is a table or
    /// a view, whether it is read-only, and what it can `$expand`.
    ///
    ///     GET /odata?db=CORP
    ///     { "tableCount": 1585, "value": [ { "name": "AT_CUSTOMERS", "kind": "table", ... } ] }
    ///
    /// Counts differ by design: CORP 1585, CLUT 1555, BCTN 1477, BRON 1425, BASC 1411,
    /// EWTN 1403, MEMTN 1401.
    /// </remarks>
    /// <param name="db">Database to list. Omit for the configured default.</param>
    /// <response code="200">The entity sets on that database.</response>
    /// <response code="404">Unknown database name; the body lists the valid ones.</response>
    /// <response code="503">Metadata for that database has not loaded.</response>
    [HttpGet]
    [AllowAnonymous]
    public IActionResult GetEntitySets([FromQuery(Name = "db")] string? db = null)
    {
        if (!TryResolveInstance(db, out var instance, out var instanceError))
        {
            return instanceError!;
        }

        if (!_modelBuilder.IsMetadataLoaded(instance))
        {
            return StatusCode(503, new 
            { 
                error = new 
                { 
                    message = $"No metadata loaded for database '{instance}'.",
                    hint = "Ensure Oracle:Instances is configured and each instance has a password "
                           + "(dotnet user-secrets set \"Oracle:Instances:CORP:Password\" \"<password>\")."
                }
            });
        }

        var metadata = _modelBuilder.GetEntityMetadata(instance);
        var expandOptions = _relationshipService.GetExpandOptionsPerTable();
        
        var entitySets = metadata.OrderBy(kvp => kvp.Key).Select(kvp => new 
        { 
            name = kvp.Key, 
            url = $"/odata/{kvp.Key}",
            kind = kvp.Value.IsView ? "view" : "table",
            readOnly = kvp.Value.IsView,

            // Null when this database owns the object. "synonym" when the name resolves
            // elsewhere, which for these is CORP over a database link. Both are queryable
            // here and both are listed, because a catalogue that hides something servable
            // is how the last defect happened. Marking them means a caller can see that
            // the same entity on two instances may be one shared table, not two copies.
            resolvesVia = kvp.Value.ResolvesVia,

            expandOptions = expandOptions.TryGetValue(kvp.Key, out var expands) ? expands : new List<string>()
        });
        
        return Ok(new 
        { 
            tableCount = metadata.Count,
            ownedCount = metadata.Count(kvp => kvp.Value.ResolvesVia is null),
            viaSynonymCount = metadata.Count(kvp => kvp.Value.ResolvesVia is not null),
            value = entitySets 
        });
    }

    /// <summary>
    /// Read rows from a table or view.
    /// </summary>
    /// <remarks>
    /// The main read endpoint. Every table and view on the chosen database is exposed by its
    /// Oracle name, so the entity set for AT_CUSTOMERS is literally `AT_CUSTOMERS`.
    ///
    /// **A plain read, first 100 rows**
    ///
    ///     GET /odata/AT_CUSTOMERS?db=CORP
    ///
    /// **Pick columns, filter, sort and page**
    ///
    ///     GET /odata/AT_CUSTOMERS?db=CORP
    ///         &amp;$select=CUST_SEQ_ID,CUSTOMER_NAME
    ///         &amp;$filter=CUSTOMER_CD eq 'C' and CUSTOMER_NAME like 'ACME%'
    ///         &amp;$orderby=CUSTOMER_NAME
    ///         &amp;$top=50&amp;$skip=100
    ///
    /// **Total matching rows for a pager**, counted over the filter and not the page:
    ///
    ///     GET /odata/AT_CUSTOMERS?db=CORP&amp;$top=25&amp;$count=true
    ///     { "@odata.count": 8001, "value": [ ... 25 rows ... ] }
    ///
    /// **Follow a foreign key** with $expand. `GET /admin/schema/{table}` lists what each
    /// table can expand:
    ///
    ///     GET /odata/AT_CONTACTS?db=CORP&amp;$expand=Addresses
    ///
    /// **Aggregate instead of returning rows** with $apply. Cannot be combined with $select
    /// or $expand, because it returns groups rather than entities:
    ///
    ///     $apply=aggregate($count as total)
    ///     $apply=aggregate(nvl(GROSS_WGT,0) with sum as weight)
    ///     $apply=groupby((CUSTOMER_CD))
    ///     $apply=groupby((CUSTOMER_CD),aggregate($count as n))
    ///     $apply=filter(STATUS eq 'A')/groupby((CUST_SEQ_ID),aggregate(GROSS_WGT with sum as w))
    ///
    /// Aggregation methods are sum, average, min, max, countdistinct, and `$count` for rows.
    /// Only `nvl(column, default)` may wrap a column; for `SUM(a * b)` aggregate the columns
    /// separately and combine client-side.
    ///
    /// **Dates** in `$filter` are written plainly and converted for Oracle:
    ///
    ///     $filter=CREATED_DT ge 2026-01-01 and CREATED_DT lt 2026-02-01
    ///
    /// **$orderby=none** returns rows in natural database order, reproducing a legacy Forms
    /// block that had no ORDER BY. Otherwise rows are ordered by the first column.
    ///
    /// **where=** names a block WHERE clause the server holds, for the Forms blocks whose
    /// clause $filter cannot say (subqueries, PL/SQL functions, correlated EXISTS, CONNECT BY).
    /// The text lives on the server and is reviewed; the request carries only the name, and an
    /// unknown name is a 400:
    ///
    ///     GET /odata/AT_OUTBOUND_SHIPMENTS?db=BCTN&amp;where=AT5521.OUTSHIPMT
    ///
    /// The clause is ANDed onto whatever $filter asks for, so a filter narrows within the block
    /// and cannot widen past it. $count, $top, $skip, $orderby, $select and $apply all apply to
    /// the rows the clause allows. Writes are unaffected.
    ///
    /// Where a clause reads a value from the screen, send it by name. /admin/block-wheres lists
    /// the binds each one takes, and a missing bind is a 400:
    ///
    ///     GET /odata/AT_BARCODES?db=BCTN&amp;where=AT3110.BARCODE&amp;bind.MATL.MATL_SEQ_ID=4211
    ///
    /// Values are bound by Oracle, never pasted into the SQL.
    /// </remarks>
    /// <param name="entitySet">Oracle table or view name, for example AT_CUSTOMERS.</param>
    /// <param name="db">Database to read: CORP, BCTN, CLUT, EWTN, BRON, BASC or MEMTN.</param>
    /// <param name="select">Comma-separated columns. Omit for all columns.</param>
    /// <param name="filter">OData filter: eq, ne, gt, ge, lt, le, and, or, like, null tests.</param>
    /// <param name="orderby">Column, optionally with desc. "none" means natural order.</param>
    /// <param name="expand">Navigation properties to include, from /admin/schema.</param>
    /// <param name="apply">Aggregation pipeline. See the examples above.</param>
    /// <param name="count">true adds @odata.count, the total matching the filter.</param>
    /// <param name="top">Page size. Default 100, maximum 10000.</param>
    /// <param name="skip">Rows to skip, for paging.</param>
    /// <param name="where">
    /// Name of a block WHERE clause held by the server, from /admin/block-wheres. The API ANDs
    /// its text onto the query, as the legacy form did. Values the screen supplies go in
    /// separate bind.* query parameters.
    /// </param>
    /// <response code="200">Rows, under "value".</response>
    /// <response code="400">Bad $filter, $select, $orderby or $apply. The body names the problem.</response>
    /// <response code="404">That entity set does not exist on that database; the body lists where it does.</response>
    /// <response code="503">Metadata for that database has not loaded.</response>
    [HttpGet("{entitySet}")]
    public async Task<IActionResult> Get(
        string entitySet, 
        [FromQuery(Name = "db")] string? db = null,
        [FromQuery(Name = "$select")] string? select = null,
        [FromQuery(Name = "$filter")] string? filter = null,
        [FromQuery(Name = "$orderby")] string? orderby = null,
        [FromQuery(Name = "$expand")] string? expand = null,
        [FromQuery(Name = "$apply")] string? apply = null,
        [FromQuery(Name = "$count")] bool? count = null,
        [FromQuery(Name = "$top")] int? top = 100, 
        [FromQuery(Name = "$skip")] int? skip = null,
        [FromQuery(Name = "where")] string? where = null)
    {
        if (!TryResolveInstance(db, out var instance, out var instanceError))
        {
            return instanceError!;
        }

        if (!_modelBuilder.IsMetadataLoaded(instance))
        {
            return StatusCode(503, new 
            { 
                error = new 
                { 
                    message = $"No metadata loaded for database '{instance}'.",
                    hint = "Ensure Oracle:Instances is configured and each instance has a password "
                           + "(dotnet user-secrets set \"Oracle:Instances:CORP:Password\" \"<password>\")."
                }
            });
        }

        if (MissingOnInstance(instance, entitySet, out var absentError))
        {
            return absentError!;
        }

        // A named block WHERE is resolved before anything runs: an unknown name or a missing
        // bind is the caller's mistake, and answering 400 is better than quietly returning
        // rows the legacy screen would not show.
        ResolvedBlockWhere? blockWhere = null;
        if (!string.IsNullOrWhiteSpace(where))
        {
            try
            {
                blockWhere = _blockWheres.Resolve(
                    entitySet, where, BlockWhereService.ReadBindsFromQuery(Request.Query));
            }
            catch (BlockWhereException ex)
            {
                _logger.LogWarning("Block WHERE '{Name}' rejected for {EntitySet}: {Message}",
                    where, entitySet, ex.Message);
                return BadRequest(new
                {
                    error = new { code = ex.Code, message = ex.Message, known = ex.Known }
                });
            }
        }

        try
        {
            _logger.LogInformation("GET request for entity set: {EntitySet}, $select={Select}, $filter={Filter}, $orderby={OrderBy}, $expand={Expand}, $top={Top}, $skip={Skip}", 
                entitySet, select, filter, orderby, expand, top, skip);

            // $apply replaces the row projection entirely: aggregation returns groups, not
            // entities, so $select and $expand do not apply to it and are rejected rather
            // than quietly dropped.
            if (!string.IsNullOrWhiteSpace(apply))
            {
                if (!string.IsNullOrWhiteSpace(select) || !string.IsNullOrWhiteSpace(expand))
                {
                    return BadRequest(new
                    {
                        error = new
                        {
                            code = "ApplyWithProjection",
                            message = "$apply cannot be combined with $select or $expand.",
                            hint = "Aggregation produces groups rather than rows of the entity, so "
                                   + "name the columns you want inside groupby() and aggregate()."
                        }
                    });
                }

                var aggregated = await _dataService.ApplyAsync(
                    instance, entitySet, apply, filter, orderby,
                    top.HasValue ? Math.Min(top.Value, MaxTop) : MaxTop,
                    blockWhere);

                return Ok(new ODataResponse { Value = aggregated });
            }

            var effectiveSelect = select;
            var fkColumnsToHide = new List<string>();
            
            if (!string.IsNullOrWhiteSpace(expand) && !string.IsNullOrWhiteSpace(select))
            {
                var expandParts = ParseExpandExpression(expand);
                var relationships = _relationshipService.GetRelationshipsForTable(entitySet);
                
                var selectColumns = select.Split(',', StringSplitOptions.RemoveEmptyEntries)
                    .Select(c => c.Trim().ToUpperInvariant())
                    .ToList();

                foreach (var expandOption in expandParts)
                {
                    var relationship = relationships.FirstOrDefault(r => 
                        r.Name.Equals(expandOption.Name, StringComparison.OrdinalIgnoreCase));
                    
                    if (relationship != null)
                    {
                        var fkColumn = relationship.FromColumn.ToUpperInvariant();
                        if (!selectColumns.Contains(fkColumn))
                        {
                            selectColumns.Add(fkColumn);
                            fkColumnsToHide.Add(fkColumn);
                        }
                    }
                }
                
                effectiveSelect = string.Join(",", selectColumns);
            }
            
            var queryOptions = new QueryOptions
            {
                Select = effectiveSelect,
                Filter = filter,
                OrderBy = orderby,
                Top = top.HasValue ? Math.Min(top.Value, MaxTop) : DefaultTop,
                Skip = skip ?? 0,
                BlockWhere = blockWhere
            };
            
            var data = await _dataService.GetWithQueryAsync(instance, entitySet, queryOptions);

            if (!string.IsNullOrWhiteSpace(expand))
            {
                await ExpandNavigationPropertiesAsync(instance, entitySet, data, expand);
                
                if (fkColumnsToHide.Count > 0)
                {
                    foreach (var record in data)
                    {
                        foreach (var fkCol in fkColumnsToHide)
                        {
                            record.Remove(fkCol);
                        }
                    }
                }
            }
            
            var response = new ODataResponse { Value = data };
            if (count == true)
            {
                // Counts the filtered set, not the page: what the caller needs to size a
                // pager. $top/$skip deliberately do not apply.
                response.Count = await _dataService.CountAsync(instance, entitySet, filter, blockWhere);
            }

            return Ok(response);
        }
        catch (ApplyValidationException ex)
        {
            _logger.LogWarning(ex, "$apply validation failed for {EntitySet}", entitySet);
            return BadRequest(new { error = new { code = "BadApply", message = ex.Message } });
        }
        catch (FilterValidationException ex)
        {
            _logger.LogWarning(ex, "Filter validation failed for {EntitySet}", entitySet);
            return BadRequest(new { error = new { message = ex.Message, errors = ex.Errors, suggestions = ex.Suggestions } });
        }
        catch (QueryValidationException ex)
        {
            _logger.LogWarning(ex, "Query validation failed for {EntitySet}", entitySet);
            return BadRequest(new { error = new { message = ex.Message, invalidValues = ex.InvalidValues, validColumns = ex.ValidValues } });
        }
        catch (TableNotFoundException ex)
        {
            _logger.LogWarning(ex, "Entity set not found: {EntitySet}", entitySet);
            return NotFound(new { error = new { message = ex.Message, suggestions = ex.Suggestions } });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving data from {EntitySet}", entitySet);
            return StatusCode(500, new { error = new { message = "An error occurred", details = ex.Message } });
        }
    }

    /// <summary>
    /// Create a row. The server allocates the primary key for 85 tables.
    /// </summary>
    /// <remarks>
    /// Send the columns you want set. Column names are case-insensitive.
    ///
    ///     POST /odata/AT_BARCODE_ROLL_LOG?db=BRON
    ///     { "BARCODE_ROLL_QTY": 1, "PROCESS_AREA_NAME": "Roll 12" }
    ///
    ///     201 Created
    ///     { "BARCODE_ROLL_QTY": 1, "PROCESS_AREA_NAME": "Roll 12",
    ///       "BARCODE_ROLL_SEQ_ID": 3100 }
    ///
    /// **Leave the key out and the server fills it.** The legacy forms allocated their own
    /// keys in PRE-INSERT; a client here does not have to. `GET /admin/sequences` lists every
    /// table this applies to, and `/admin/schema/{table}` reports it per table as
    /// `generatedKey`. The created entity always comes back with its key, which is what lets
    /// you build child rows in the same save.
    ///
    /// **Send the key explicitly and it is used as given**, which keeps migration and replay
    /// working. Tables not in the map need you to supply the key or have a trigger do it.
    ///
    /// **Some keys are deliberately never allocated.** A column that is really the parent's
    /// key, such as `AT_CONTACTS.ADDR_SEQ_ID`, would silently orphan the row if filled in
    /// blind. Create the parent first in a `$batch` change set and reference its key.
    ///
    /// **Attribution.** Pass `X-EWT-On-Behalf-Of` with the acting user so the audit trail
    /// records a person rather than the shared Oracle account.
    /// </remarks>
    /// <param name="entitySet">Oracle table name. Views are read-only unless Oracle permits writes.</param>
    /// <param name="db">Database to write to.</param>
    /// <param name="entity">Column name to value. Omit a server-allocated key.</param>
    /// <response code="201">Created. The body is the row including its key.</response>
    /// <response code="400">A constraint was violated, or the body names an unknown column. The body gives the ORA code and what it means.</response>
    /// <response code="404">That entity set does not exist on that database.</response>
    /// <response code="405">That entity is read-only.</response>
    /// <response code="409">A unique key already exists, or the row is locked by another session.</response>
    [HttpPost("{entitySet}")]
    public async Task<IActionResult> Post(string entitySet, [FromQuery(Name = "db")] string? db, [FromBody] Dictionary<string, object?> entity)
    {
        if (!TryResolveInstance(db, out var instance, out var instanceError))
        {
            return instanceError!;
        }

        if (MissingOnInstance(instance, entitySet, out var absentError))
        {
            return absentError!;
        }

        try
        {
            _logger.LogInformation("POST request for entity set: {EntitySet}", entitySet);

            if (entity == null || entity.Count == 0)
            {
                return BadRequest(new { error = new { message = "Request body is required" } });
            }

            var (ownerUser, ownerDisplay) = ResolveOwner();
            if (_audit.RequireOwner && string.IsNullOrWhiteSpace(ownerUser))
            {
                return BadRequest(new { error = new { message = "Owner attribution required (X-EWT-On-Behalf-Of header or authenticated user)." } });
            }

            // Convert JsonElements to proper .NET types
            var convertedEntity = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (var kvp in entity)
            {
                convertedEntity[kvp.Key.ToUpperInvariant()] = ConvertJsonElement(kvp.Value);
            }

            var result = await _dataService.InsertAsync(instance, entitySet, convertedEntity);

            await _audit.WriteAsync(
                instance,
                entitySet.ToUpperInvariant(), "INSERT",
                BuildAuditPk(instance, entitySet, result), convertedEntity, ownerUser, ownerDisplay);

            return Created($"odata/{entitySet}?db={instance}", result);
        }
        catch (TableNotFoundException ex)
        {
            return NotFound(new { error = new { message = ex.Message, suggestions = ex.Suggestions } });
        }
        catch (ReadOnlyEntityException ex)
        {
            return StatusCode(405, new { error = new { message = ex.Message } });
        }
        catch (OracleException ex) when (ex.Number == 54)
        {
            _logger.LogWarning(ex, "Row locked during POST to {EntitySet}", entitySet);
            return StatusCode(409, new { error = new { message = "Row is locked by another session. Try again later.", details = ex.Message } });
        }
        catch (Exception ex) when (ex is TimeoutException || ex.InnerException is TimeoutException)
        {
            _logger.LogWarning(ex, "Timeout during POST to {EntitySet} — possible row lock", entitySet);
            return StatusCode(409, new { error = new { message = "Operation timed out — the row may be locked by another session.", details = ex.Message } });
        }
        catch (OracleException ex)
        {
            return OracleFailure(ex, entitySet);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating entity in {EntitySet}", entitySet);
            return StatusCode(500, new { error = new { message = "An error occurred", details = ex.Message } });
        }
    }

    /// <summary>
    /// Update a row, addressed by its key or by a filter.
    /// </summary>
    /// <remarks>
    /// Only the columns you send are changed.
    ///
    /// **By primary key**, which goes in the body alongside the changes:
    ///
    ///     PATCH /odata/AT_BARCODE_ROLL_LOG?db=BRON
    ///     { "BARCODE_ROLL_SEQ_ID": 3100, "PROCESS_AREA_NAME": "Roll 12A" }
    ///
    /// **By filter**, which is how you reach the 27 bound tables that declare no primary key
    /// at all. It also works on keyed tables, so a client can use one code path:
    ///
    ///     PATCH /odata/AT_ESPROFILE_RAD?db=CORP
    ///           &amp;$filter=ES_PROF_SEQ_ID eq 4211 and TRKDITM_SEQ_ID eq 7
    ///     { "ACTIVITY_QTY": 12.5 }
    ///
    /// **A filter-addressed write must match exactly one row.** Match several and you get 409
    /// with the count, match none and you get 404, and in both cases nothing is written: the
    /// update and its row count are one statement inside a transaction, so a loose filter
    /// cannot quietly change the whole table. `/admin/schema/{table}` reports `addressing`
    /// as "key" or "filter", and lists `uniqueKeys` when the table has one worth using.
    ///
    /// **Optional concurrency check.** The legacy Forms application locks a row while a user
    /// edits it, and it is still running against these databases. Send the row's MODIFIED_DT
    /// as `If-Match` and a write that lost the race is refused with 412 rather than silently
    /// overwriting someone:
    ///
    ///     If-Match: 2026-09-23T13:33:10
    ///
    /// MODIFIED_DT is null until a row is first edited, so send CREATED_DT when it is, or
    /// `If-Match: null` on the few tables with no CREATED_DT. Omit the header entirely and
    /// the write is unguarded, which is the historical behaviour.
    /// </remarks>
    /// <param name="entitySet">Oracle table name.</param>
    /// <param name="db">Database to write to.</param>
    /// <param name="entity">Columns to change, plus the primary key when not using $filter.</param>
    /// <param name="filter">Addresses the row instead of the key. Must match exactly one row.</param>
    /// <response code="204">Updated.</response>
    /// <response code="400">No key, nothing to update, a bad filter, or a constraint violation.</response>
    /// <response code="404">No row matches.</response>
    /// <response code="405">That entity is read-only.</response>
    /// <response code="409">The filter matched several rows, or the row is locked by another session.</response>
    /// <response code="412">If-Match was sent and the row changed first. The body carries the current row.</response>
    [HttpPatch("{entitySet}")]
    public async Task<IActionResult> Patch(
        string entitySet,
        [FromQuery(Name = "db")] string? db,
        [FromBody] Dictionary<string, object?> entity,
        [FromQuery(Name = "$filter")] string? filter = null)
    {
        if (!TryResolveInstance(db, out var instance, out var instanceError))
        {
            return instanceError!;
        }

        if (MissingOnInstance(instance, entitySet, out var absentError))
        {
            return absentError!;
        }

        try
        {
            _logger.LogInformation("PATCH request for {EntitySet}", entitySet);

            if (entity == null || entity.Count == 0)
            {
                return BadRequest(new { error = new { message = "Request body is required" } });
            }

            var (ownerUser, ownerDisplay) = ResolveOwner();
            if (_audit.RequireOwner && string.IsNullOrWhiteSpace(ownerUser))
            {
                return BadRequest(new { error = new { message = "Owner attribution required (X-EWT-On-Behalf-Of header or authenticated user)." } });
            }

            var metadata = _modelBuilder.GetEntityMetadata(instance);
            if (!metadata.TryGetValue(entitySet.ToUpperInvariant(), out var entityMetadata))
            {
                throw new TableNotFoundException(entitySet, new List<string>());
            }

            var convertedEntity = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (var kvp in entity)
            {
                convertedEntity[kvp.Key.ToUpperInvariant()] = ConvertJsonElement(kvp.Value);
            }

            // Filter-addressed update. The only way to reach the tables that declare no
            // primary key, and allowed on keyed tables too so a caller does not need two
            // code paths. The write is rejected and rolled back unless it hits exactly one
            // row, so an under-selective filter cannot quietly update the whole table.
            if (!string.IsNullOrWhiteSpace(filter))
            {
                if (convertedEntity.Count == 0)
                {
                    return BadRequest(new { error = new { message = "No fields to update" } });
                }

                await _dataService.UpdateWhereAsync(instance, entitySet, filter, convertedEntity, null, IfMatch());

                await _audit.WriteAsync(
                    instance,
                    entitySet.ToUpperInvariant(), "UPDATE",
                    new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase) { ["$filter"] = filter },
                    convertedEntity, ownerUser, ownerDisplay);

                return NoContent();
            }

            var pkColumns = entityMetadata.PrimaryKeyColumns;
            if (pkColumns.Count == 0)
            {
                return BadRequest(new
                {
                    error = new
                    {
                        code = "NoPrimaryKey",
                        message = $"'{entitySet}' declares no primary key, so it cannot be addressed by key.",
                        hint = "Address the row with $filter instead: "
                               + $"PATCH /odata/{entitySet}?db={instance}&$filter=<expression>. "
                               + "The filter must match exactly one row.",
                        uniqueKeys = entityMetadata.UniqueKeys
                    }
                });
            }

            var keyValues = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            var missingKeys = new List<string>();

            foreach (var pkCol in pkColumns)
            {
                if (convertedEntity.TryGetValue(pkCol, out var value) && value != null)
                {
                    keyValues[pkCol] = value;
                }
                else
                {
                    missingKeys.Add(pkCol);
                }
            }

            if (missingKeys.Count > 0)
            {
                return BadRequest(new { error = new { message = "Primary key column(s) required", missingColumns = missingKeys } });
            }

            var updateValues = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (var kvp in convertedEntity)
            {
                if (!pkColumns.Contains(kvp.Key, StringComparer.OrdinalIgnoreCase))
                {
                    updateValues[kvp.Key] = kvp.Value;
                }
            }

            if (updateValues.Count == 0)
            {
                return BadRequest(new { error = new { message = "No fields to update" } });
            }

            var rowsAffected = await _dataService.UpdateAsync(instance, entitySet, keyValues, updateValues, null, IfMatch());

            if (rowsAffected == 0)
            {
                return NotFound(new { error = new { message = "Entity not found" } });
            }

            await _audit.WriteAsync(
                instance,
                entitySet.ToUpperInvariant(), "UPDATE",
                keyValues.ToDictionary(k => k.Key, k => (object?)k.Value, StringComparer.OrdinalIgnoreCase),
                updateValues, ownerUser, ownerDisplay);

            return NoContent();
        }
        catch (AmbiguousRowException ex)
        {
            return AmbiguousRow(ex);
        }
        catch (FilterValidationException ex)
        {
            return BadRequest(new { error = new { message = ex.Message, errors = ex.Errors, suggestions = ex.Suggestions } });
        }
        catch (TableNotFoundException ex)
        {
            return NotFound(new { error = new { message = ex.Message, suggestions = ex.Suggestions } });
        }
        catch (ReadOnlyEntityException ex)
        {
            return StatusCode(405, new { error = new { message = ex.Message } });
        }
        catch (Exception ex) when (ex is TimeoutException || ex.InnerException is TimeoutException)
        {
            _logger.LogWarning(ex, "Timeout during PATCH to {EntitySet} — possible row lock", entitySet);
            return StatusCode(409, new { error = new { message = "Operation timed out — the row may be locked by another session.", details = ex.Message } });
        }
        catch (RowLockedException ex)
        {
            return RowLocked(ex);
        }
        catch (RowChangedException ex)
        {
            return RowChanged(ex);
        }
        catch (ConcurrencyNotSupportedException ex)
        {
            return BadRequest(new { error = new { code = "IfMatchNotSupported", message = ex.Message } });
        }
        catch (OracleException ex)
        {
            return OracleFailure(ex, entitySet);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating entity in {EntitySet}", entitySet);
            return StatusCode(500, new { error = new { message = "An error occurred", details = ex.Message } });
        }
    }

    /// <summary>
    /// Delete the single row matching a filter.
    /// </summary>
    /// <remarks>
    /// The route for tables that declare no primary key, so have nothing to put in
    /// `DELETE /odata/{entitySet}(key)`. It works on keyed tables too.
    ///
    ///     DELETE /odata/AT_ESPROFILE_RAD?db=CORP
    ///            &amp;$filter=ES_PROF_SEQ_ID eq 4211 and TRKDITM_SEQ_ID eq 7
    ///
    /// **Refused unless it matches exactly one row**, and rolled back when it does not, so a
    /// loose filter cannot empty a table. Several matches gives 409 with the count; none
    /// gives 404. `If-Match` works here exactly as it does on PATCH.
    /// </remarks>
    /// <param name="entitySet">Oracle table name.</param>
    /// <param name="filter">Required. Must identify exactly one row.</param>
    /// <param name="db">Database to write to.</param>
    /// <response code="204">Deleted.</response>
    /// <response code="400">$filter missing or invalid.</response>
    /// <response code="404">No row matches.</response>
    /// <response code="405">That entity is read-only.</response>
    /// <response code="409">Several rows matched, child rows still reference it, or it is locked.</response>
    /// <response code="412">If-Match was sent and the row changed first.</response>
    [HttpDelete("{entitySet}")]
    public async Task<IActionResult> DeleteByFilter(
        string entitySet,
        [FromQuery(Name = "$filter")] string? filter,
        [FromQuery(Name = "db")] string? db = null)
    {
        if (!TryResolveInstance(db, out var instance, out var instanceError))
        {
            return instanceError!;
        }

        if (MissingOnInstance(instance, entitySet, out var absentError))
        {
            return absentError!;
        }

        if (string.IsNullOrWhiteSpace(filter))
        {
            return BadRequest(new
            {
                error = new
                {
                    code = "FilterRequired",
                    message = "DELETE without a key requires $filter.",
                    hint = $"DELETE /odata/{entitySet}?db={instance}&$filter=<expression> "
                           + "matching exactly one row."
                }
            });
        }

        try
        {
            var (ownerUser, ownerDisplay) = ResolveOwner();
            if (_audit.RequireOwner && string.IsNullOrWhiteSpace(ownerUser))
            {
                return BadRequest(new { error = new { message = "Owner attribution required (X-EWT-On-Behalf-Of header or authenticated user)." } });
            }

            await _dataService.DeleteWhereAsync(instance, entitySet, filter, null, IfMatch());

            await _audit.WriteAsync(
                instance,
                entitySet.ToUpperInvariant(), "DELETE",
                new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase) { ["$filter"] = filter },
                null, ownerUser, ownerDisplay);

            return NoContent();
        }
        catch (AmbiguousRowException ex)
        {
            return AmbiguousRow(ex);
        }
        catch (FilterValidationException ex)
        {
            return BadRequest(new { error = new { message = ex.Message, errors = ex.Errors, suggestions = ex.Suggestions } });
        }
        catch (TableNotFoundException ex)
        {
            return NotFound(new { error = new { message = ex.Message, suggestions = ex.Suggestions } });
        }
        catch (ReadOnlyEntityException ex)
        {
            return StatusCode(405, new { error = new { message = ex.Message } });
        }
        catch (RowLockedException ex)
        {
            return RowLocked(ex);
        }
        catch (RowChangedException ex)
        {
            return RowChanged(ex);
        }
        catch (ConcurrencyNotSupportedException ex)
        {
            return BadRequest(new { error = new { code = "IfMatchNotSupported", message = ex.Message } });
        }
        catch (OracleException ex)
        {
            return OracleFailure(ex, entitySet);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting from {EntitySet} by filter", entitySet);
            return StatusCode(500, new { error = new { message = "An error occurred", details = ex.Message } });
        }
    }

    /// <summary>
    /// The If-Match header, carrying the MODIFIED_DT the caller read. Absent means the
    /// write is unguarded, which is the old behaviour.
    /// </summary>
    private string? IfMatch() => Request.Headers.IfMatch.FirstOrDefault();

    /// <summary>
    /// The row is held by another session, almost always a legacy Forms user with the
    /// record open. 409 with its own code, worded as the legacy message operators know.
    /// </summary>
    private IActionResult RowLocked(RowLockedException ex)
    {
        return Conflict(new
        {
            error = new
            {
                code = "RowLockedByAnotherUser",
                message = ex.Message,
                entitySet = ex.TableName,
                waitedSeconds = ex.WaitedSeconds,
                hint = "Nothing was written. The legacy Forms application holds a row while a "
                       + "user edits it; try again once they save or cancel."
            }
        });
    }

    /// <summary>
    /// Somebody else changed the row first. 412 with its own code, worded the way the
    /// legacy reservation message was, and carrying the current row so the UI can show what
    /// changed instead of making the user re-query.
    /// </summary>
    private IActionResult RowChanged(RowChangedException ex)
    {
        _logger.LogInformation("Concurrent edit refused on {Table}", ex.TableName);
        return StatusCode(StatusCodes.Status412PreconditionFailed, new
        {
            error = new
            {
                code = "RowChangedByAnother",
                message = ex.Message,
                entitySet = ex.TableName,
                hint = "Nothing was saved. Compare against 'current', then retry with the "
                       + "MODIFIED_DT from it.",
                current = ex.Current
            }
        });
    }

    /// <summary>
    /// Turns an Oracle error into something a UI can act on. A constraint violation is the
    /// caller's problem, not a server fault, so it is a 4xx carrying the ORA code and the
    /// constraint name rather than an opaque 500.
    /// </summary>
    private IActionResult OracleFailure(OracleException ex, string entitySet)
    {
        var (status, code, message) = ex.Number switch
        {
            1     => (StatusCodes.Status409Conflict, "UniqueViolation",
                      "A row with those key values already exists."),
            1400 or 1407 => (StatusCodes.Status400BadRequest, "NotNullViolation",
                      "A column that cannot be null was left empty."),
            2291  => (StatusCodes.Status400BadRequest, "ParentNotFound",
                      "A referenced parent row does not exist."),
            2292  => (StatusCodes.Status409Conflict, "ChildRowsExist",
                      "Other rows still reference this one, so it cannot be removed."),
            2290  => (StatusCodes.Status400BadRequest, "CheckViolation",
                      "A value is outside what the table allows."),
            12899 => (StatusCodes.Status400BadRequest, "ValueTooLong",
                      "A value is longer than its column allows."),
            904   => (StatusCodes.Status400BadRequest, "UnknownColumn",
                      "The body names a column this table does not have."),
            _     => (StatusCodes.Status500InternalServerError, "OracleError",
                      "The database rejected the operation.")
        };

        if (status >= 500)
        {
            _logger.LogError(ex, "Oracle error {Number} on {EntitySet}", ex.Number, entitySet);
        }
        else
        {
            _logger.LogWarning("Oracle error {Number} on {EntitySet}: {Message}",
                ex.Number, entitySet, ex.Message);
        }

        return StatusCode(status, new
        {
            error = new
            {
                code,
                message,
                oracleCode = $"ORA-{ex.Number:00000}",
                details = ex.Message
            }
        });
    }

    /// <summary>
    /// A filter-addressed write matched zero rows (404) or several (409). Either way
    /// nothing was written.
    /// </summary>
    private IActionResult AmbiguousRow(AmbiguousRowException ex)
    {
        if (ex.MatchedRows == 0)
        {
            return NotFound(new { error = new { code = "NoMatchingRow", message = ex.Message } });
        }

        _logger.LogWarning("Filter matched {Rows} rows in {Table}; write rolled back",
            ex.MatchedRows, ex.TableName);
        return Conflict(new
        {
            error = new
            {
                code = "FilterNotUnique",
                message = ex.Message,
                matchedRows = ex.MatchedRows,
                hint = "Add columns to $filter until it identifies one row."
            }
        });
    }

    /// <summary>
    /// Delete a row by primary key.
    /// </summary>
    /// <remarks>
    ///     DELETE /odata/AT_BARCODE_ROLL_LOG(3100)?db=BRON
    ///
    /// A compound key is given in order, comma separated:
    ///
    ///     DELETE /odata/AT_INVOICE_LINE_ITEMS(4211,7)?db=BCTN
    ///
    /// For a table with no primary key use the `$filter` form instead. `If-Match` works here
    /// as it does on PATCH.
    /// </remarks>
    /// <param name="entitySet">Oracle table name.</param>
    /// <param name="key">Primary key value, or comma-separated values for a compound key.</param>
    /// <param name="db">Database to write to.</param>
    /// <response code="204">Deleted.</response>
    /// <response code="404">No row with that key.</response>
    /// <response code="405">That entity is read-only.</response>
    /// <response code="409">Child rows still reference it, or it is locked by another session.</response>
    /// <response code="412">If-Match was sent and the row changed first.</response>
    [HttpDelete("{entitySet}({key})")]
    public async Task<IActionResult> Delete(string entitySet, string key, [FromQuery(Name = "db")] string? db = null)
    {
        if (!TryResolveInstance(db, out var instance, out var instanceError))
        {
            return instanceError!;
        }

        if (MissingOnInstance(instance, entitySet, out var absentError))
        {
            return absentError!;
        }

        try
        {
            _logger.LogInformation("DELETE request for {EntitySet}({Key})", entitySet, key);

            var (ownerUser, ownerDisplay) = ResolveOwner();
            if (_audit.RequireOwner && string.IsNullOrWhiteSpace(ownerUser))
            {
                return BadRequest(new { error = new { message = "Owner attribution required (X-EWT-On-Behalf-Of header or authenticated user)." } });
            }

            var keyValues = ParseKey(instance, entitySet, key);
            var rowsAffected = await _dataService.DeleteAsync(instance, entitySet, keyValues, null, IfMatch());

            if (rowsAffected == 0)
            {
                return NotFound(new { error = new { message = "Entity not found" } });
            }

            await _audit.WriteAsync(
                instance,
                entitySet.ToUpperInvariant(), "DELETE",
                keyValues.ToDictionary(k => k.Key, k => (object?)k.Value, StringComparer.OrdinalIgnoreCase),
                null, ownerUser, ownerDisplay);

            return NoContent();
        }
        catch (TableNotFoundException ex)
        {
            return NotFound(new { error = new { message = ex.Message, suggestions = ex.Suggestions } });
        }
        catch (ReadOnlyEntityException ex)
        {
            return StatusCode(405, new { error = new { message = ex.Message } });
        }
        catch (Exception ex) when (ex is TimeoutException || ex.InnerException is TimeoutException)
        {
            _logger.LogWarning(ex, "Timeout deleting from {EntitySet}({Key}) — possible row lock", entitySet, key);
            return StatusCode(409, new { error = new { message = "Operation timed out — the row may be locked by another session.", details = ex.Message } });
        }
        catch (RowLockedException ex)
        {
            return RowLocked(ex);
        }
        catch (RowChangedException ex)
        {
            return RowChanged(ex);
        }
        catch (ConcurrencyNotSupportedException ex)
        {
            return BadRequest(new { error = new { code = "IfMatchNotSupported", message = ex.Message } });
        }
        catch (OracleException ex)
        {
            return OracleFailure(ex, entitySet);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting entity from {EntitySet}", entitySet);
            return StatusCode(500, new { error = new { message = "An error occurred", details = ex.Message } });
        }
    }

    private Dictionary<string, object> ParseKey(string instance, string entitySet, string key)
    {
        var metadata = _modelBuilder.GetEntityMetadata(instance);
        if (!metadata.TryGetValue(entitySet, out var entityMetadata))
        {
            throw new KeyNotFoundException($"Entity set '{entitySet}' not found");
        }

        var keyValues = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        key = key.Trim();
        
        if (key.Contains('='))
        {
            var parts = key.Split(',');
            foreach (var part in parts)
            {
                var kvp = part.Split('=', 2);
                if (kvp.Length == 2)
                {
                    var columnName = kvp[0].Trim();
                    var value = ParseKeyValue(kvp[1].Trim());
                    keyValues[columnName] = value;
                }
            }
        }
        else
        {
            var pkColumn = entityMetadata.PrimaryKeyColumns.FirstOrDefault() 
                ?? entityMetadata.Columns.FirstOrDefault()?.ColumnName
                ?? throw new InvalidOperationException($"No key column found for {entitySet}");
            
            keyValues[pkColumn] = ParseKeyValue(key);
        }

        return keyValues;
    }

    private static object ParseKeyValue(string value)
    {
        if ((value.StartsWith('\'') && value.EndsWith('\'')) ||
            (value.StartsWith('"') && value.EndsWith('"')))
        {
            return value[1..^1];
        }

        if (long.TryParse(value, out var longVal)) return longVal;
        if (decimal.TryParse(value, out var decVal)) return decVal;

        return value;
    }

    private async Task ExpandNavigationPropertiesAsync(string instance, string entitySet, List<Dictionary<string, object?>> data, string expand)
    {
        if (data.Count == 0) return;

        var relationships = _relationshipService.GetRelationshipsForTable(entitySet);
        var expandParts = ParseExpandExpression(expand);

        foreach (var expandOption in expandParts)
        {
            var relationship = relationships.FirstOrDefault(r => 
                r.Name.Equals(expandOption.Name, StringComparison.OrdinalIgnoreCase));

            if (relationship == null)
            {
                _logger.LogWarning("Unknown $expand: {ExpandName}", expandOption.Name);
                continue;
            }

            await ExpandRelationshipAsync(instance, data, relationship, expandOption);
        }
    }

    private List<ExpandOption> ParseExpandExpression(string expand)
    {
        var results = new List<ExpandOption>();
        var parts = SplitExpandParts(expand);

        foreach (var part in parts)
        {
            var parenIndex = part.IndexOf('(');
            if (parenIndex == -1)
            {
                // Simple expand: "Container"
                results.Add(new ExpandOption { Name = part.Trim() });
            }
            else
            {
                // Expand with options: "Container($select=ID;$expand=Type)"
                var name = part.Substring(0, parenIndex).Trim();
                var options = part.Substring(parenIndex + 1, part.Length - parenIndex - 2); // Remove outer parens
                
                var expandOption = new ExpandOption { Name = name };
                
                // Parse inner options ($select and $expand)
                var innerParts = SplitInnerOptions(options);
                foreach (var inner in innerParts)
                {
                    var trimmed = inner.Trim();
                    if (trimmed.StartsWith("$select=", StringComparison.OrdinalIgnoreCase))
                    {
                        expandOption.Select = trimmed.Substring(8).Trim();
                    }
                    else if (trimmed.StartsWith("$expand=", StringComparison.OrdinalIgnoreCase))
                    {
                        var nestedExpand = trimmed.Substring(8).Trim();
                        expandOption.NestedExpand = ParseExpandExpression(nestedExpand);
                    }
                }
                
                results.Add(expandOption);
            }
        }

        return results;
    }

    private List<string> SplitExpandParts(string expand)
    {
        var parts = new List<string>();
        var depth = 0;
        var current = "";
        
        foreach (var c in expand)
        {
            if (c == '(') depth++;
            else if (c == ')') depth--;
            else if (c == ',' && depth == 0)
            {
                if (!string.IsNullOrWhiteSpace(current)) parts.Add(current.Trim());
                current = "";
                continue;
            }
            current += c;
        }
        if (!string.IsNullOrWhiteSpace(current)) parts.Add(current.Trim());
        
        return parts;
    }

    private List<string> SplitInnerOptions(string options)
    {
        // Split on ; but respect nested parentheses
        var parts = new List<string>();
        var depth = 0;
        var current = "";
        
        foreach (var c in options)
        {
            if (c == '(') depth++;
            else if (c == ')') depth--;
            else if (c == ';' && depth == 0)
            {
                if (!string.IsNullOrWhiteSpace(current)) parts.Add(current.Trim());
                current = "";
                continue;
            }
            current += c;
        }
        if (!string.IsNullOrWhiteSpace(current)) parts.Add(current.Trim());
        
        return parts;
    }

    private async Task ExpandRelationshipAsync(string instance, List<Dictionary<string, object?>> data, Relationship relationship, ExpandOption expandOption)
    {
        var fkValues = data
            .Where(d => d.TryGetValue(relationship.FromColumn, out var v) && v != null)
            .Select(d => d[relationship.FromColumn]!)
            .Distinct()
            .ToList();

        if (fkValues.Count == 0)
        {
            foreach (var record in data)
            {
                record[relationship.Name] = relationship.Type == "one-to-many"
                    ? new List<Dictionary<string, object?>>() : null;
            }
            return;
        }

        var inClause = string.Join(",", fkValues.Select(v => v is string ? $"'{v}'" : v?.ToString() ?? "NULL"));
        var filter = $"{relationship.ToColumn} IN ({inClause})";

        try
        {
            var relatedData = await _dataService.GetWithFilterAndSelectAsync(instance, relationship.ToTable, filter, expandOption.Select);

            // Process nested expansions recursively
            if (expandOption.NestedExpand != null && expandOption.NestedExpand.Count > 0)
            {
                var nestedRelationships = _relationshipService.GetRelationshipsForTable(relationship.ToTable);
                foreach (var nestedOption in expandOption.NestedExpand)
                {
                    var nestedRel = nestedRelationships.FirstOrDefault(r => 
                        r.Name.Equals(nestedOption.Name, StringComparison.OrdinalIgnoreCase));
                    
                    if (nestedRel != null)
                    {
                        await ExpandRelationshipAsync(instance, relatedData, nestedRel, nestedOption);
                    }
                    else
                    {
                        _logger.LogWarning("Unknown nested $expand: {ExpandName} on {Table}", nestedOption.Name, relationship.ToTable);
                    }
                }
            }

            var relatedByKey = new Dictionary<string, List<Dictionary<string, object?>>>(StringComparer.OrdinalIgnoreCase);
            foreach (var related in relatedData)
            {
                if (related.TryGetValue(relationship.ToColumn, out var keyValue) && keyValue != null)
                {
                    var keyStr = keyValue.ToString() ?? "";
                    if (!relatedByKey.ContainsKey(keyStr))
                    {
                        relatedByKey[keyStr] = new List<Dictionary<string, object?>>();
                    }
                    relatedByKey[keyStr].Add(related);
                }
            }

            foreach (var record in data)
            {
                if (record.TryGetValue(relationship.FromColumn, out var fkValue) && fkValue != null)
                {
                    var fkStr = fkValue.ToString() ?? "";
                    if (relatedByKey.TryGetValue(fkStr, out var matches))
                    {
                        record[relationship.Name] = relationship.Type == "one-to-many" ? matches : matches.FirstOrDefault();
                    }
                    else
                    {
                        record[relationship.Name] = relationship.Type == "one-to-many" ? new List<Dictionary<string, object?>>() : null;
                    }
                }
                else
                {
                    record[relationship.Name] = relationship.Type == "one-to-many"
                        ? new List<Dictionary<string, object?>>() : null;
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to expand {Name}", relationship.Name);
            foreach (var record in data)
            {
                record[relationship.Name] = relationship.Type == "one-to-many" ? new List<Dictionary<string, object?>>() : null;
            }
        }
    }

    private class ExpandOption
    {
        public string Name { get; set; } = "";
        public string? Select { get; set; }
        public List<ExpandOption>? NestedExpand { get; set; }
    }

    private static object? ConvertJsonElement(object? value)
    {
        if (value is JsonElement jsonElement)
        {
            return jsonElement.ValueKind switch
            {
                JsonValueKind.String => ParseStringValue(jsonElement.GetString()),
                JsonValueKind.Number => jsonElement.TryGetInt64(out var longVal) ? longVal : jsonElement.GetDecimal(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Null => null,
                JsonValueKind.Undefined => null,
                _ => jsonElement.ToString()
            };
        }
        return value;
    }

    private static object? ParseStringValue(string? str)
    {
        if (str == null) return null;

        // Try to parse as DateTime (ISO 8601 format)
        if (DateTime.TryParse(str, null, System.Globalization.DateTimeStyles.RoundtripKind, out var dateTime))
        {
            // Check if it looks like a date/datetime (has dashes and colons or T separator)
            if (str.Contains('T') || (str.Contains('-') && str.Length >= 10))
            {
                return dateTime;
            }
        }

        return str;
    }
}

public class ODataResponse
{
    /// <summary>
    /// Total rows matching $filter, ignoring paging. Present only when $count=true was
    /// asked for, per OData: the annotation is absent rather than null otherwise.
    /// </summary>
    [System.Text.Json.Serialization.JsonPropertyName("@odata.count")]
    [System.Text.Json.Serialization.JsonIgnore(Condition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull)]
    public long? Count { get; set; }

    public List<Dictionary<string, object?>> Value { get; set; } = new();
}
