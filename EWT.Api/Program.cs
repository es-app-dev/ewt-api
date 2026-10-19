using EWT.Api.Configuration;
using EWT.Api.Services;
using EWT.Services.Utilites;
using Microsoft.Extensions.Options;
using Serilog;

namespace EWT.Api
{
    public class Program
    {
        public static async Task Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);
            var configuration = builder.Configuration;

            // EWT connection strings use TNS aliases (Data Source=EWT_CORP_DEV), which the
            // Oracle driver resolves through tnsnames.ora. EWIS cleared TNS_ADMIN because it
            // used inline connect descriptors; doing that here would break every connection.
            // Set Oracle:TnsAdmin to point at the directory holding tnsnames.ora, or leave it
            // unset to use the machine's existing TNS_ADMIN / Oracle client configuration.
            var tnsAdmin = configuration["Oracle:TnsAdmin"];
            if (!string.IsNullOrWhiteSpace(tnsAdmin))
            {
                Environment.SetEnvironmentVariable("TNS_ADMIN", tnsAdmin);
            }

            // Configure Serilog from appsettings
            Log.Logger = new LoggerConfiguration()
                .ReadFrom.Configuration(builder.Configuration)
                .WriteTo.Console()
                .WriteTo.File("logs/ih_logs.txt", rollingInterval: RollingInterval.Day)
                .CreateLogger();
            builder.Host.UseSerilog();

            // Bind Oracle configuration (CORP + the daughter instances).
            builder.Services.Configure<OracleOptions>(configuration.GetSection(OracleOptions.SectionName));
            var oracleOptions = configuration.GetSection(OracleOptions.SectionName).Get<OracleOptions>()
                ?? throw new InvalidOperationException(
                    "Missing 'Oracle' configuration section. It must define Instances for CORP and each daughter database.");

            // Create Oracle services manually to avoid BuildServiceProvider warning
            var loggerFactory = LoggerFactory.Create(logging => logging.AddConsole());
            var connectionService = new OracleConnectionService(Options.Create(oracleOptions), loggerFactory.CreateLogger<OracleConnectionService>());
            var metadataService = new OracleMetadataService(connectionService, loggerFactory.CreateLogger<OracleMetadataService>());
            var edmModelBuilder = new DynamicEdmModelBuilder(metadataService, connectionService, loggerFactory.CreateLogger<DynamicEdmModelBuilder>());
            var relationshipService = new RelationshipService(loggerFactory.CreateLogger<RelationshipService>());
            var sequenceService = new SequenceService(loggerFactory.CreateLogger<SequenceService>());
            var blockWhereService = new BlockWhereService(loggerFactory.CreateLogger<BlockWhereService>());

            // Register Oracle OData services as singletons
            builder.Services.AddSingleton(connectionService);
            builder.Services.AddSingleton(metadataService);
            builder.Services.AddSingleton(edmModelBuilder);
            builder.Services.AddSingleton(relationshipService);
            builder.Services.AddSingleton(sequenceService);
            builder.Services.AddSingleton(blockWhereService);
            builder.Services.AddScoped<DynamicDataService>();
            builder.Services.AddScoped<OracleProcedureService>();
            builder.Services.AddSingleton<IAuditService, AuditService>();
            builder.Services.AddSingleton<IGraphRoleService, GraphRoleService>();
            builder.Services.AddSingleton<PackageService>();

            builder.Services.AddControllers();
            builder.Services.AddDependencyConfiguration();
            builder.Services.AddAuthenticationConfiguration(configuration);
            builder.Services.AddHttpContextAccessor();

            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(options =>
            {
                options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
                {
                    Title = "EWT API",
                    Version = "v1",
                    Description = """
                        Dynamic OData over the seven EWT Oracle databases: CORP and its six daughter sites.

                        **Choosing a database.** Every call takes `?db=`, for example
                        `/odata/AT_CUSTOMERS?db=CORP`. Omit it and the configured default is used.
                        `GET /odata/instances` lists the valid names.

                        **The seven schemas are not identical.** They share column structure but not
                        which tables exist: 75 of the tables the UI binds are on CORP only. Asking a
                        daughter for one of those returns 404 naming where it does live, never an
                        empty result, because an empty result cannot be told apart from "no rows".

                        **The legacy Oracle Forms application still runs against these same
                        databases.** A write can meet a Forms user holding a row. This API
                        reproduces legacy behaviour rather than improving on it.

                        **Query options:** `$select`, `$filter`, `$orderby`, `$expand`, `$top`,
                        `$skip`, `$count`, `$apply`.
                        """
                });

                // Pull the XML doc comments off the controllers so each operation shows its
                // own summary, remarks and worked examples instead of a bare method name.
                var xml = Path.Combine(AppContext.BaseDirectory,
                    $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml");
                if (File.Exists(xml))
                {
                    options.IncludeXmlComments(xml, includeControllerXmlComments: true);
                }

                options.OrderActionsBy(apiDesc => apiDesc.RelativePath);
            });

            // Build Oracle metadata at startup
            var schemaFilter = configuration["Oracle:SchemaFilter"];
            try
            {
                await edmModelBuilder.LoadAllAsync(schemaFilter);
                Log.Information(
                    "Metadata loaded per instance. The seven schemas are NOT identical, so each " +
                    "instance has its own model: {Detail}",
                    string.Join(", ", edmModelBuilder.LoadedInstances
                        .OrderBy(kv => kv.Key).Select(kv => $"{kv.Key}={kv.Value}")));
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Could not load Oracle metadata at startup. OData endpoints may not work until Oracle is available.");
            }

            var app = builder.Build();

            var httpContextAccessor = app.Services.GetRequiredService<IHttpContextAccessor>();
            UserContextHelper.Configure(httpContextAccessor);

            // Ensure the application audit trail exists (auto-creates in Dev/Test; best-effort).
            await app.Services.GetRequiredService<IAuditService>().EnsureSchemaAsync();

            // Check our own PL/SQL packages are present, valid and identical on every
            // instance. Reports only unless Packages:AutoDeploy is set: the legacy Forms
            // application is live on these databases and CREATE OR REPLACE is a real change.
            await app.Services.GetRequiredService<PackageService>().VerifyAsync();

            app.UseCors(builder =>
                    builder.AllowAnyOrigin()
                           .AllowAnyMethod()
                           .AllowAnyHeader());

            app.Use(async (context, next) =>
            {
                try
                {
                    await next(context);
                }
                catch (Exception ex)
                {
                    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
                    logger.LogError(ex, "Unhandled error");
                    context.Response.StatusCode = 500;
                    await context.Response.WriteAsync("error");
                }
            });

            // Enable Swagger in all environments (internal API)
            app.UseSwagger();
            app.UseSwaggerUI(options =>
            {
                // Hide the "Schemas" section at the bottom of the page.
                options.DefaultModelsExpandDepth(-1);
            });
            
            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseHttpsRedirection();

            app.UseAuthentication();

            app.UseAuthorization();

            app.MapControllers();

            // Oracle reports dataLength for every type, but it is only a usable maxLength
            // for character and raw columns; a NUMBER always reports 22 (its storage size).
            static bool IsCharacterType(string? t) => (t ?? "").ToUpperInvariant() is
                "VARCHAR2" or "VARCHAR" or "CHAR" or "NVARCHAR2" or "NCHAR" or "RAW";

            // Resolves ?db= for the minimal endpoints, mirroring the controller's behaviour.
            static bool TryResolveDb(OracleConnectionService connections, string? db,
                                     out string instance, out IResult? error)
            {
                try
                {
                    instance = connections.ResolveInstanceName(db);
                    error = null;
                    return true;
                }
                catch (UnknownInstanceException ex)
                {
                    instance = string.Empty;
                    error = Results.NotFound(new
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

            // Lists the configured databases. A literal path segment, so it takes
            // precedence over the /odata/{entitySet} parameterised route (an Oracle
            // table actually named INSTANCES would be shadowed by it).
            app.MapGet("/odata/instances", (OracleConnectionService connections) =>
            {
                return Results.Ok(new
                {
                    count = connections.InstanceNames.Count,
                    defaultInstance = connections.DefaultInstance,
                    modelSourceInstance = connections.ModelSourceInstance,
                    // Corporate first, then daughters alphabetically — config binding
                    // does not preserve the order they were declared in.
                    instances = connections.Instances
                        .OrderByDescending(kv => kv.Value.IsCorporate)
                        .ThenBy(kv => kv.Key, StringComparer.OrdinalIgnoreCase)
                        .Select(kv => new
                    {
                        name = kv.Key,
                        displayName = kv.Value.DisplayName ?? kv.Key,
                        isCorporate = kv.Value.IsCorporate,
                        legacyKey = kv.Value.LegacyKey,
                        tnsAlias = kv.Value.TnsAlias
                    })
                });
            })
            .WithSummary("List the databases this API can reach.")
            .WithDescription("The seven EWT Oracle databases: CORP and its six daughter sites. Returns each name, its display name, whether it is the corporate instance, and its TNS alias. The name is what you pass as ?db= on every other call. An unknown ?db= returns 404 listing these, so a typo never reads the wrong database.");

            // Admin endpoints for cache management
            // TODO: Re-enable .RequireAuthorization() after debugging
            app.MapPost("/admin/refresh-cache", async (DynamicEdmModelBuilder modelBuilder,
                                                       OracleConnectionService connections,
                                                       IConfiguration config, string? db) =>
            {
                if (!TryResolveDb(connections, db, out var instance, out var dbError)) return dbError!;
                var schema = config["Oracle:SchemaFilter"];
                await modelBuilder.RefreshFromOracleAsync(instance, schema);
                var metadata = modelBuilder.GetEntityMetadata(instance);
                return Results.Ok(new { message = $"Cache refreshed from Oracle for {instance}",
                                        instance, tableCount = metadata.Count });
            })
            .WithSummary("Re-read one database's schema from Oracle.")
            .WithDescription("Drops the cached metadata for a database, reads the data dictionary again and rebuilds that instance's model. Use it after a schema change. Metadata normally comes from the shipped cache files, so this is not needed in normal running.");

            // Admin endpoint to get table schema
            app.MapGet("/admin/schema/{tableName}", (DynamicEdmModelBuilder modelBuilder,
                                                     OracleConnectionService connections,
                                                     RelationshipService relService,
                                                     SequenceService sequences,
                                                     string tableName, string? db) =>
            {
                if (!TryResolveDb(connections, db, out var instance, out var dbError)) return dbError!;
                var metadata = modelBuilder.GetEntityMetadata(instance);
                if (!metadata.TryGetValue(tableName.ToUpperInvariant(), out var table))
                {
                    // Say where it does exist. 75 of the tables the UI binds are CORP-only,
                    // and an empty result set would look identical to "no rows".
                    var elsewhere = modelBuilder.InstancesWith(tableName.ToUpperInvariant());
                    return Results.NotFound(new
                    {
                        error = elsewhere.Count > 0
                            ? $"Table '{tableName}' does not exist on '{instance}'."
                            : $"Table '{tableName}' does not exist on any configured database.",
                        requestedDatabase = instance,
                        availableOn = elsewhere
                    });
                }

                var relationships = relService.GetRelationshipsForTable(table.TableName);
                var pk = new HashSet<string>(table.PrimaryKeyColumns, StringComparer.OrdinalIgnoreCase);
                var assignment = sequences.For(table.TableName);

                return Results.Ok(new
                {
                    instance,
                    tableName = table.TableName,
                    owner = table.Owner,
                    kind = table.IsView ? "view" : "table",
                    readOnly = table.IsView && !table.IsWritableView,

                    // A view Oracle will accept writes to, because it has an INSTEAD OF
                    // trigger or is key-preserving. Several legacy forms insert through
                    // views, so this is asked of the database rather than assumed.
                    // Null for a table. For a view, what Oracle actually permits, asked of
                    // the database rather than assumed, and per operation because a join
                    // view is often updatable while refusing inserts.
                    viewWrites = !table.IsView ? null : new
                    {
                        insert = table.ViewCapability?.CanInsert ?? false,
                        update = table.ViewCapability?.CanUpdate ?? false,
                        delete = table.ViewCapability?.CanDelete ?? false,
                        viaInsteadOfTrigger = table.ViewCapability?.HasInsteadOfTrigger ?? false
                    },

                    columnCount = table.Columns.Count,
                    primaryKey = table.PrimaryKeyColumns,

                    // Every database this entity is reachable on, whether we own it there or
                    // reach it through a synonym. Reachable, not owned: the daughters reach
                    // CORP master data by synonym and it is served from the site session.
                    availableOn = modelBuilder.InstancesWith(table.TableName),

                    // How this name resolves here. Null means we own it. "synonym" means
                    // Oracle resolves it on the signed-in connection, which for these tables
                    // is a link to CORP, and is exactly what a Forms session does. Routing
                    // should not need this; it is here so a surprise is explainable.
                    resolvesVia = table.ResolvesVia,
                    resolvesTo = table.ResolvesTo,

                    // How to address a row for PATCH and DELETE.
                    //   "key"    - the primary key, in the body or the url
                    //   "filter" - no primary key declared, so use $filter and match one row
                    //   "none"   - a view: read only
                    addressing = table.IsView && !table.IsWritableView ? "none"
                        : table.PrimaryKeyColumns.Count > 0 ? "key" : "filter",

                    // Optimistic concurrency. When a column is named here, send its value
                    // as If-Match on PATCH and DELETE and a losing race is refused with 412
                    // rather than silently overwriting. When null there is nothing to check
                    // against and writes to this table are unguarded.
                    concurrency = DynamicDataService.ConcurrencyColumnOf(table) is not {} c ? null : new
                    {
                        column = c,
                        fallbackColumn = DynamicDataService.ConcurrencyFallbackOf(table),
                        note = "Send this column's value as If-Match on PATCH and DELETE. It is "
                               + "null until a row is first edited, so send the fallback column's "
                               + "value when it is."
                    },

                    // Unique constraints and unique indexes. For a table with no primary key
                    // these are the column sets that will identify exactly one row.
                    uniqueKeys = table.UniqueKeys.Select(u => new
                    {
                        name = u.Name,
                        columns = u.Columns,
                        source = u.Source
                    }).ToList(),

                    // When present, POST may omit this column and the server allocates it.
                    generatedKey = assignment is null ? null : new
                    {
                        column = assignment.Column,
                        sequence = assignment.Sequence,
                        note = "Omit this column on POST and the server fills it from the "
                               + "sequence, returning the created entity with the key."
                    },
                    columns = table.Columns
                        .OrderBy(c => c.ColumnId)
                        .Select(c => new
                        {
                            name = c.ColumnName,
                            position = c.ColumnId,
                            // Oracle's own spelling, e.g. VARCHAR2(50) or NUMBER(10,2)
                            type = DynamicEdmModelBuilder.DescribeOracleType(c),
                            oracleType = c.DataType,
                            // what the JSON value will actually be, so the UI can pick a control
                            jsonType = DynamicEdmModelBuilder
                                .MapOracleTypeToEdm(c.DataType, c.DataPrecision, c.DataScale)
                                .ToString(),
                            // maxLength is only meaningful for character and raw types;
                            // for NUMBER, dataLength is Oracle's internal 22-byte storage.
                            maxLength = IsCharacterType(c.DataType) ? c.DataLength : null,
                            length = c.DataLength,
                            precision = c.DataPrecision,
                            scale = c.DataScale,
                            nullable = c.IsNullable,
                            // A server-allocated key is not required from the client even
                            // though the column itself is NOT NULL.
                            required = !c.IsNullable && !table.IsView
                                       && !c.ColumnName.Equals(assignment?.Column, StringComparison.OrdinalIgnoreCase),
                            isPrimaryKey = pk.Contains(c.ColumnName),
                            isServerAssigned = c.ColumnName.Equals(assignment?.Column, StringComparison.OrdinalIgnoreCase)
                        }),
                    expandOptions = relationships.Select(r => new
                    {
                        name = r.Name,
                        fromColumn = r.FromColumn,
                        toTable = r.ToTable,
                        toColumn = r.ToColumn,
                        type = r.Type
                    }).ToList()
                });
            })
            .WithSummary("Describe one table or view: columns, keys, and how to write to it.")
            .WithDescription("The reference a client builds a screen from.\n\nPer column: Oracle's own type spelling such as VARCHAR2(30), the JSON type the value arrives as, maxLength for character columns, precision and scale, nullability, whether it is part of the primary key, and whether the server allocates it.\n\nPer table: availableOn lists every database holding this entity, so cross-database routing can be driven from the API rather than a static map. addressing is key, filter or none and says how PATCH and DELETE reach a row. uniqueKeys gives the column sets that identify one row where there is no primary key. generatedKey names the sequence when POST may omit the key. viewWrites reports what Oracle actually permits on a view, asked of the dictionary rather than assumed. concurrency names the column to send as If-Match.\n\nA table absent from this database returns 404 naming where it does exist.");

            // Every table whose primary key the server allocates on POST. One call, so the
            // UI does not have to probe /admin/schema for all 91 of them.
            app.MapGet("/admin/sequences", (SequenceService sequences,
                                            DynamicEdmModelBuilder modelBuilder) =>
            {
                var rows = sequences.Assignments.Values
                    .OrderBy(a => a.Table, StringComparer.OrdinalIgnoreCase)
                    .Select(a => new
                    {
                        table = a.Table,
                        column = a.Column,
                        sequence = a.Sequence,
                        availableOn = modelBuilder.InstancesWith(a.Table)
                    })
                    .ToList();

                return Results.Ok(new
                {
                    count = rows.Count,
                    note = "POST to one of these entity sets without the listed column and the "
                           + "server allocates it from the sequence, returning the created entity "
                           + "with its key. Send the column explicitly and it is used as given.",
                    value = rows
                });
            })
            .WithSummary("Every table whose primary key the server allocates on POST.")
            .WithDescription("One call instead of probing the schema endpoint for each table. For each: the table, the column the server fills, the sequence it comes from, and which databases hold that table.\n\nPOST to one of these without the listed column and the server allocates it, returning the created entity with its key. Send the column explicitly and it is used as given.");

            // ---- The EWT_UI package, at runtime ------------------------------------------
            // Three operations: get what a database holds, update the source this server
            // ships, deploy it. Off unless Packages:AllowRuntimeDeploy is true, which it is
            // only in Dev, because deploying compiles PL/SQL into the database.

            const string UiPackage = "EWT_UI";

            static IResult? RuntimeDeployGate(PackageService packages)
            {
                if (packages.AllowRuntimeDeploy) return null;
                return Results.Json(new
                {
                    error = new
                    {
                        code = "RuntimeDeployDisabled",
                        message = "Changing the EWT_UI package at runtime is off on this server.",
                        hint = "Set Packages:AllowRuntimeDeploy to true. It is meant for Dev only: "
                               + "it compiles PL/SQL into the database."
                    }
                }, statusCode: 403);
            }

            app.MapGet("/admin/ui-package", async (PackageService packages, OracleConnectionService connections,
                                                   string? db, bool? runnable) =>
            {
                // No database named: report where the package stands on every instance.
                if (string.IsNullOrWhiteSpace(db))
                {
                    var status = await packages.DescribeLiveAsync(UiPackage, connections.InstanceNames);
                    return Results.Ok(new
                    {
                        package = UiPackage,
                        runtimeDeploy = packages.AllowRuntimeDeploy,
                        instances = status.Count,
                        valid = status.Count(s => !s.Missing && !s.Invalid && s.Unreachable is null),
                        matchingFile = status.Count(s => s.MatchesFile),
                        status
                    });
                }

                if (!TryResolveDb(connections, db, out var instance, out var dbError)) return dbError!;

                var deployed = await packages.GetDeployedAsync(instance, UiPackage);
                if (deployed is null)
                {
                    return Results.NotFound(new
                    {
                        error = new { code = "PackageNotDeployed",
                                      message = $"{UiPackage} is not on {instance}." }
                    });
                }

                // runnable=true gives plain text you can edit and send straight back.
                if (runnable == true)
                {
                    return Results.Text(deployed.Runnable, "text/plain");
                }

                return Results.Ok(new
                {
                    package = deployed.Package,
                    instance = deployed.Instance,
                    invalid = deployed.Invalid,
                    matchesFile = deployed.MatchesFile,
                    databaseFingerprint = deployed.DatabaseFingerprint,
                    fileFingerprint = deployed.FileFingerprint,
                    units = deployed.Units.Select(u => new { type = u.Type, lines = u.Text.Split('\n').Length, text = u.Text }),
                    runnable = deployed.Runnable
                });
            })
            .WithName("GetUiPackage")
            .WithSummary("Get the EWT_UI package.")
            .WithDescription("With no ?db=, reports where EWT_UI stands on all seven instances: present, valid, how many procedures, and whether it matches the .sql file this server ships.\n\nWith ?db=BCTN, returns the package as that instance holds it, read from USER_SOURCE, which is the deployed text rather than the file. Add &runnable=true for plain text with CREATE OR REPLACE and the slash lines put back, ready to edit and send to DeployUiPackage.");

            app.MapPut("/admin/ui-package", async (PackageService packages, HttpRequest request) =>
            {
                if (RuntimeDeployGate(packages) is { } off) return off;

                using var reader = new StreamReader(request.Body);
                var sql = await reader.ReadToEndAsync();
                if (string.IsNullOrWhiteSpace(sql))
                {
                    return Results.BadRequest(new
                    {
                        error = new { code = "EmptyBody",
                                      message = "Send the package source as the request body, content-type text/plain." }
                    });
                }

                var update = await packages.WriteSourceFileAsync(UiPackage, sql);
                if (!update.Ok)
                {
                    return Results.BadRequest(new
                    {
                        error = new { code = "SourceRejected", message = update.Refusal }
                    });
                }

                return Results.Ok(new
                {
                    package = UiPackage,
                    file = update.FileName,
                    previousBytes = update.PreviousBytes,
                    newBytes = update.NewBytes,
                    statements = update.Statements,
                    fingerprint = update.Fingerprint,
                    previousKeptAs = update.BackupFileName,
                    note = "The file this server ships is updated. Nothing is on a database yet: "
                           + "call DeployUiPackage to compile it."
                });
            })
            .WithName("UpdateUiPackage")
            .WithSummary("Update the EWT_UI source this server ships.")
            .WithDescription("Replaces the single .sql file a package is built from, with the request body, content-type text/plain.\n\nThis is refused for EWT_UI, because EWT_UI is assembled from one file per form in OurPackages/ewt_ui: there is no single file to replace, and overwriting the whole package in one call would make one person's edit silently discard everyone else's. Use PutUiPackageForm for the form you changed.\n\nFor any other package:\n\nThis changes what the server believes the package should be: it is what matchesFile is measured against, what AutoDeploy restores at startup, and it survives a restart. It does not touch any database on its own. The previous file is kept beside it with a timestamp, because it is checked in, so copy the new version back into the repo once you are happy with it.");

            app.MapPost("/admin/ui-package/deploy", async (PackageService packages, OracleConnectionService connections,
                                                           HttpRequest request, string? db) =>
            {
                if (RuntimeDeployGate(packages) is { } off) return off;

                if (string.IsNullOrWhiteSpace(db))
                {
                    return Results.BadRequest(new
                    {
                        error = new
                        {
                            code = "InstanceRequired",
                            message = "Name the database outright: ?db=BCTN, or ?db=all for every instance.",
                            hint = "There is no default here on purpose.",
                            instances = connections.InstanceNames
                        }
                    });
                }

                var targets = db.Equals("all", StringComparison.OrdinalIgnoreCase)
                    ? connections.InstanceNames.ToList()
                    : new List<string> { connections.ResolveInstanceName(db) };

                // A body deploys that text; no body deploys the file this server ships.
                using var reader = new StreamReader(request.Body);
                var sql = await reader.ReadToEndAsync();
                var fromFile = string.IsNullOrWhiteSpace(sql);

                var results = new List<PackageDeployResult>();
                foreach (var instance in targets)
                {
                    results.Add(fromFile
                        ? await packages.RedeployFromFileAsync(instance, UiPackage)
                        : await packages.DeployTextAsync(instance, UiPackage, sql));
                }

                var allOk = results.All(r => r.Ok);
                return Results.Json(new
                {
                    package = UiPackage,
                    source = fromFile
                        ? (packages.UsesFragments
                            ? $"OurPackages/ewt_ui on the server ({packages.FragmentOrder().Count} fragments)"
                            : "the .sql file on the server")
                        : "the request body",
                    ok = allOk,
                    instances = targets.Count,
                    compiled = results.Count(r => r.Ok),
                    results = results.Select(r => new
                    {
                        instance = r.Instance,
                        ok = r.Ok,
                        summary = r.Summary,
                        statementsRun = r.StatementsRun,
                        statementsTotal = r.StatementsTotal,
                        invalid = r.Invalid,
                        missing = r.Missing,
                        matchesFile = r.MatchesFile,
                        oracleError = r.OracleError,
                        refusal = r.Refusal,
                        errors = r.Errors
                    })
                }, statusCode: allOk ? 200 : 400);
            })
            .WithName("DeployUiPackage")
            .WithSummary("Deploy the EWT_UI package to one database or to all seven.")
            .WithDescription("Compiles EWT_UI and reports what Oracle made of it. ?db= is required and may be an instance name or 'all'.\n\nSend the source as the request body, content-type text/plain, to deploy that text. Send no body to deploy what the server holds, which for EWT_UI means the fragments in OurPackages/ewt_ui assembled in manifest order. That is how you put the shipped version back after trying something.\n\nWhen it does not compile the reply carries USER_ERRORS per instance, with type, line and position, so the reason does not have to be chased through the server log. A deploy from a body does not change the file: restart, or deploy with no body, and the shipped version returns. Use UpdateUiPackage to make a change stick.");

            // ---- One form at a time -------------------------------------------------------
            // EWT_UI is assembled from OurPackages/ewt_ui/<FORM>.sql. These let the UI side
            // work on one form without touching the other fifty-nine.

            static IResult? FragmentsGate(PackageService packages)
            {
                if (packages.UsesFragments) return null;
                return Results.Json(new
                {
                    error = new
                    {
                        code = "FragmentsNotInUse",
                        message = "This server builds EWT_UI from a single .sql file, not from "
                                  + "per-form fragments.",
                        hint = "OurPackages/ewt_ui/ with a _frame.sql is what switches it over. "
                               + "scripts/split-ewt-ui.py produced it from the original single-file package."
                    }
                }, statusCode: 409);
            }

            app.MapGet("/admin/ui-package/forms", (PackageService packages) =>
            {
                if (FragmentsGate(packages) is { } no) return no;

                var all = packages.DescribeFragments();
                return Results.Ok(new
                {
                    package = "EWT_UI",
                    count = all.Count,
                    declarations = all.Sum(f => f.Declarations),
                    definitions = all.Sum(f => f.Definitions),
                    note = "Assembly order is this order. _COMMON is first because the helpers "
                           + "there are called from other fragments and PL/SQL needs a private "
                           + "procedure defined before its caller.",
                    forms = all
                });
            })
            .WithName("ListUiPackageForms")
            .WithSummary("List the forms EWT_UI is assembled from.")
            .WithDescription("One entry per OurPackages/ewt_ui/<FORM>.sql, in assembly order, with how many procedures each declares and defines and how many of those are body-private. The totals across all forms are the package's own totals.");

            app.MapGet("/admin/ui-package/forms/{form}", (PackageService packages, string form) =>
            {
                if (FragmentsGate(packages) is { } no) return no;

                var text = packages.ReadFragment(form);
                if (text is null)
                {
                    return Results.NotFound(new
                    {
                        error = new
                        {
                            code = "NoSuchForm",
                            message = $"There is no fragment for {form.ToUpperInvariant()}.",
                            known = packages.DescribeFragments().Select(f => f.Form)
                        }
                    });
                }

                return Results.Text(text, "text/plain");
            })
            .WithName("GetUiPackageForm")
            .WithSummary("Get one form's SQL.")
            .WithDescription("Returns OurPackages/ewt_ui/{FORM}.sql as plain text: a --#SPEC section holding that form's declarations and a --#BODY section holding its definitions. Edit it and send it back with PutUiPackageForm.");

            app.MapPut("/admin/ui-package/forms/{form}", async (PackageService packages,
                                                                HttpRequest request, string form) =>
            {
                if (RuntimeDeployGate(packages) is { } off) return off;
                if (FragmentsGate(packages) is { } no) return no;

                using var reader = new StreamReader(request.Body);
                var text = await reader.ReadToEndAsync();
                if (string.IsNullOrWhiteSpace(text))
                {
                    return Results.BadRequest(new
                    {
                        error = new { code = "EmptyBody",
                                      message = "Send the fragment as the request body, content-type text/plain." }
                    });
                }

                var result = packages.WriteFragment(form, text);
                if (!result.Ok)
                {
                    return Results.BadRequest(new
                    {
                        error = new { code = "FragmentRejected", message = result.Refusal }
                    });
                }

                return Results.Ok(new
                {
                    form = result.Form,
                    file = result.FileName,
                    created = !result.Existed,
                    previousBytes = result.PreviousBytes,
                    newBytes = result.NewBytes,
                    declarations = result.Declarations,
                    definitions = result.Definitions,
                    previousKeptAs = result.BackupFileName,
                    note = "The fragment is saved. Nothing is on a database yet: call "
                           + "DeployUiPackage, which reassembles all the forms and compiles them."
                });
            })
            .WithName("PutUiPackageForm")
            .WithSummary("Replace one form's SQL.")
            .WithDescription("Writes OurPackages/ewt_ui/{FORM}.sql from the request body, content-type text/plain. Creates the form if it does not exist yet.\n\nRefused unless every procedure in it is named {form}_<something>, lower case, which is how a form owns its procedures and how two forms are kept from claiming the same one. _COMMON is the one exemption. Also refused if the body declares something under --#SPEC that it does not define under --#BODY, which Oracle would otherwise report as PLS-00323 against the whole package, and if it contains CREATE OR REPLACE or a slash line, which belong to the frame.\n\nThis saves the file. It does not touch a database: deploy separately.");

            app.MapDelete("/admin/ui-package/forms/{form}", (PackageService packages, string form) =>
            {
                if (RuntimeDeployGate(packages) is { } off) return off;
                if (FragmentsGate(packages) is { } no) return no;

                var result = packages.DeleteFragment(form);
                if (!result.Ok)
                {
                    return Results.BadRequest(new
                    {
                        error = new { code = "FragmentNotRemoved", message = result.Refusal }
                    });
                }

                return Results.Ok(new
                {
                    form = result.Form,
                    removedBytes = result.PreviousBytes,
                    keptAs = result.BackupFileName,
                    note = "The file is gone and the next deploy will not include it. The "
                           + "procedures stay on the databases until something replaces the "
                           + "package, and Oracle drops them when it does."
                });
            })
            .WithName("DeleteUiPackageForm")
            .WithSummary("Remove one form from the package.")
            .WithDescription("Deletes OurPackages/ewt_ui/{FORM}.sql, keeping a timestamped copy beside it. The next deploy assembles without it, which is what actually removes its procedures from the databases. _COMMON cannot be removed: other fragments call into it.");

            app.MapGet("/admin/ui-package/assembled", (PackageService packages) =>
            {
                if (FragmentsGate(packages) is { } no) return no;
                return Results.Text(packages.AssembleFromFragments(), "text/plain");
            })
            .WithName("GetUiPackageAssembled")
            .WithSummary("The whole package as the fragments currently assemble it.")
            .WithDescription("The exact text a deploy would compile: the frame plus every form in assembly order. Useful for reading a diff before deploying, and for checking what a fragment change did to the whole.");

            // The named block WHERE clauses. Read-only: the registry is reviewed and placed on
            // the server like relationships.json, never written through the API.
            app.MapGet("/admin/block-wheres", (BlockWhereService blockWheres) =>
            {
                var all = blockWheres.All
                    .OrderBy(w => w.EntitySet, StringComparer.OrdinalIgnoreCase)
                    .ThenBy(w => w.Name, StringComparer.OrdinalIgnoreCase)
                    .Select(w => new
                    {
                        name = w.Name,
                        entitySet = w.EntitySet,
                        sql = w.Sql,
                        binds = w.Binds.Select(b => new { name = b.Name, type = b.Type }),
                        note = w.Note
                    })
                    .ToList();

                return Results.Ok(new
                {
                    count = all.Count,
                    byEntitySet = all.GroupBy(w => w.entitySet, StringComparer.OrdinalIgnoreCase)
                        .ToDictionary(g => g.Key, g => g.Select(w => w.name).ToList()),
                    blockWheres = all
                });
            })
            .WithSummary("List the named block WHERE clauses a query can ask for.")
            .WithDescription("The WHERE clauses the legacy Forms blocks applied to every query, for the blocks whose clause $filter cannot express. Each entry gives the name a request passes as where=, the entity set it is valid against, the SQL text, and the binds it needs. Pass a name as GET /odata/{entitySet}?where={name} and any binds as bind.{name}=value.");

            // Relationship management endpoints
            app.MapGet("/admin/relationships", (RelationshipService relService) =>
            {
                var relationships = relService.GetAllRelationships();
                var byTable = relService.GetExpandOptionsPerTable();
                
                return Results.Ok(new 
                { 
                    count = relationships.Count,
                    file = relService.FilePath,
                    byTable = byTable,
                    relationships = relationships
                });
            })
            .WithSummary("List the $expand relationships available on each table.")
            .WithDescription("The navigation properties $expand understands, generated from the real Oracle foreign keys: 1,477 of them, single-column and enabled only. Grouped by table, plus the flat list with the from and to columns of each.");

            app.MapPost("/admin/relationships", (RelationshipService relService, Relationship relationship) =>
            {
                // Validate required fields
                if (string.IsNullOrWhiteSpace(relationship.Name) ||
                    string.IsNullOrWhiteSpace(relationship.FromTable) ||
                    string.IsNullOrWhiteSpace(relationship.FromColumn) ||
                    string.IsNullOrWhiteSpace(relationship.ToTable) ||
                    string.IsNullOrWhiteSpace(relationship.ToColumn))
                {
                    return Results.BadRequest(new 
                    { 
                        error = "All fields are required: name, fromTable, fromColumn, toTable, toColumn",
                        example = new 
                        {
                            name = "CurrentStatus",
                            fromTable = "PICKLIST",
                            fromColumn = "CURRENT_STATUS_ID",
                            toTable = "CURRENT_STATUS",
                            toColumn = "CURRENT_STATUS_ID",
                            type = "many-to-one"
                        }
                    });
                }

                var added = relService.AddRelationship(relationship);
                return Results.Created($"/admin/relationships/{added.FromTable}/{added.Name}", added);
            })
            .WithSummary("Add or replace one $expand relationship.")
            .WithDescription("For a join the foreign keys do not express, such as a relationship enforced only in application code. Takes name, fromTable, fromColumn, toTable, toColumn and type. Saved to relationships.json and live immediately. The generated ones are rewritten by scripts/convert-schema-metadata.py, so prefer fixing the source data where the foreign key exists.");

            app.MapDelete("/admin/relationships/{tableName}/{relationshipName}", 
                (RelationshipService relService, string tableName, string relationshipName) =>
            {
                var removed = relService.RemoveRelationship(tableName, relationshipName);
                if (!removed)
                {
                    return Results.NotFound(new { error = $"Relationship '{relationshipName}' not found on table '{tableName}'" });
                }
                return Results.Ok(new { message = $"Relationship '{relationshipName}' removed from '{tableName}'" });
            })
            .WithSummary("Remove one $expand relationship.")
            .WithDescription("Deletes a navigation property from relationships.json by table and relationship name. Only affects what $expand offers; nothing in the database changes.");

            // Stored procedure endpoints
            app.MapGet("/odata/proc", async (OracleProcedureService procService, OracleConnectionService connections, string? db) =>
            {
                if (!TryResolveDb(connections, db, out var instance, out var dbError)) return dbError!;
                try
                {
                    var procedures = await procService.GetProceduresAsync(instance);
                    return Results.Ok(new { count = procedures.Count, procedures });
                }
                catch (Exception ex)
                {
                    return Results.Json(new { error = ex.Message }, statusCode: 500);
                }
            })
            .WithSummary("List the stored procedures and functions on a database.")
            .WithDescription("Name, package, type, whether it is a function, and current status, read from the Oracle data dictionary. Use /odata/proc/{procedureName}/params for the signature before calling one.");

            app.MapGet("/odata/proc/{procedureName}/params", async (OracleProcedureService procService, OracleConnectionService connections, string procedureName, string? db) =>
            {
                if (!TryResolveDb(connections, db, out var instance, out var dbError)) return dbError!;
                try
                {
                    var parameters = await procService.GetProcedureParametersAsync(instance, procedureName);
                    if (parameters.Count == 0)
                    {
                        return Results.NotFound(new { error = $"Procedure '{procedureName}' not found or has no parameters" });
                    }
                    return Results.Ok(new { procedureName, parameters });
                }
                catch (Exception ex)
                {
                    return Results.Json(new { error = ex.Message }, statusCode: 500);
                }
            })
            .WithSummary("Describe one procedure's parameters.")
            .WithDescription("Each parameter in position order: name, direction, data type, whether it has a default, and whether you must supply it. A function's return value appears at position 0 with no name.");

            app.MapPost("/odata/proc/{procedureName}", async (OracleProcedureService procService, OracleConnectionService connections, string procedureName, string? db, Dictionary<string, object?>? parameters) =>
            {
                if (!TryResolveDb(connections, db, out var instance, out var dbError)) return dbError!;
                try
                {
                    var result = await procService.ExecuteAsync(instance, procedureName, parameters);
                    
                    if (!result.Success)
                    {
                        return Results.Json(new { success = false, error = result.Error }, statusCode: 400);
                    }

                    // Build response based on what the procedure returned
                    var response = new Dictionary<string, object?>
                    {
                        ["success"] = true
                    };

                    if (result.OutParameters.Count > 0)
                    {
                        response["outParameters"] = result.OutParameters;
                    }

                    if (result.ResultSets.Count > 0)
                    {
                        // If single result set, return as "data"; if multiple, return all by name
                        if (result.ResultSets.Count == 1)
                        {
                            var single = result.ResultSets.First();
                            response["data"] = single.Value;
                            response["count"] = single.Value.Count;
                        }
                        else
                        {
                            response["resultSets"] = result.ResultSets;
                        }
                    }

                    return Results.Ok(response);
                }
                catch (Exception ex)
                {
                    // Log it. A 500 carrying only ex.Message told us a procedure had failed but
                    // not where, which cost an afternoon on the generated query blocks.
                    app.Logger.LogError(ex, "Unhandled error executing procedure {Procedure} on {Instance}",
                        procedureName, instance);
                    return Results.Json(new { success = false, error = ex.Message }, statusCode: 500);
                }
            })
            .WithSummary("Execute a stored procedure or function.")
            .WithDescription("Send input parameters as a JSON object of name to value; names are case-insensitive. OUT and IN OUT parameters come back in the response, and a REF CURSOR is returned as rows.\n\n    POST /odata/proc/AT_SOME_PROC?db=CORP\n    { \"P_CUST_SEQ_ID\": 4211, \"P_STATUS\": \"A\" }\n\nCheck the signature with /odata/proc/{procedureName}/params first. This runs whatever the procedure does, including writes.");

            await app.RunAsync();
        }
    }
}
