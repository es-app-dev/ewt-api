using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.OData.Edm;

namespace EWT.Api.Services;

/// <summary>
/// Builds an OData EDM model per Oracle instance.
///
/// The seven EWT databases do NOT share one schema. 1,388 entities are common to all,
/// the union is 1,864, and CORP alone holds 187 that no other instance has. A single
/// model built from CORP therefore advertises entities that are absent elsewhere and
/// hides entities that exist elsewhere but not on CORP, so metadata is kept per instance.
///
/// Each instance caches to metadata/tables.{INSTANCE}.json. Generate those with
/// scripts/convert-schema-metadata.py, or let an instance fall back to reading Oracle.
/// </summary>
public class DynamicEdmModelBuilder
{
    private readonly OracleMetadataService _metadataService;
    private readonly OracleConnectionService _connectionService;
    private readonly ILogger<DynamicEdmModelBuilder> _logger;
    private readonly string _cacheDirectory;

    private readonly ConcurrentDictionary<string, Dictionary<string, EntityMetadata>> _metadata =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly ConcurrentDictionary<string, IEdmModel> _models =
        new(StringComparer.OrdinalIgnoreCase);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = false,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public DynamicEdmModelBuilder(
        OracleMetadataService metadataService,
        OracleConnectionService connectionService,
        ILogger<DynamicEdmModelBuilder> logger)
    {
        _metadataService = metadataService;
        _connectionService = connectionService;
        _logger = logger;
        _cacheDirectory = Path.Combine(AppContext.BaseDirectory, "metadata");
    }

    private string CacheFileFor(string instance) =>
        Path.Combine(_cacheDirectory, $"tables.{instance.ToUpperInvariant()}.json");

    /// <summary>Entity metadata for one instance. Empty if that instance has not loaded.</summary>
    public Dictionary<string, EntityMetadata> GetEntityMetadata(string instance) =>
        _metadata.TryGetValue(instance, out var m) ? m : new Dictionary<string, EntityMetadata>();

    /// <summary>True when this instance has usable metadata.</summary>
    public bool IsMetadataLoaded(string instance) =>
        _metadata.TryGetValue(instance, out var m) && m.Count > 0;

    /// <summary>True when at least one instance loaded, for coarse health reporting.</summary>
    public bool AnyMetadataLoaded => _metadata.Values.Any(m => m.Count > 0);

    /// <summary>Instances that currently have metadata, and how many entities each has.</summary>
    public IReadOnlyDictionary<string, int> LoadedInstances =>
        _metadata.ToDictionary(kv => kv.Key, kv => kv.Value.Count, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Which instances actually have this entity.
    ///
    /// The seven schemas share column structure but not table presence: 75 of the tables
    /// the UI binds live on CORP only. Without this, asking a daughter for AT_CUSTOMERS
    /// would come back as an empty result set, which is indistinguishable from "no rows"
    /// and is the worst failure mode available. The 404 says where to look instead.
    /// </summary>
    public IReadOnlyList<string> InstancesWith(string tableName) =>
        _metadata
            .Where(kv => kv.Value.ContainsKey(tableName))
            .Select(kv => kv.Key)
            .OrderBy(k => k, StringComparer.OrdinalIgnoreCase)
            .ToList();

    /// <summary>
    /// Loads every configured instance. Cache file first, Oracle only where a cache is
    /// missing. One instance failing does not stop the others.
    /// </summary>
    public async Task LoadAllAsync(string? schemaFilter = null)
    {
        foreach (var instance in _connectionService.InstanceNames)
        {
            try
            {
                await BuildModelAsync(instance, schemaFilter);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Could not load metadata for instance {Instance}; its OData endpoints " +
                    "will return 503 until it loads.", instance);
            }
        }

        var loaded = LoadedInstances;
        _logger.LogInformation(
            "Metadata ready for {Ready} of {Total} instances: {Detail}",
            loaded.Count(kv => kv.Value > 0), _connectionService.InstanceNames.Count,
            string.Join(", ", loaded.OrderBy(kv => kv.Key).Select(kv => $"{kv.Key}={kv.Value}")));
    }

    /// <summary>Builds (and caches) the EDM model for one instance.</summary>
    public async Task<IEdmModel> BuildModelAsync(string instance, string? schemaFilter = null)
    {
        if (_models.TryGetValue(instance, out var cached))
        {
            return cached;
        }

        if (TryLoadFromCache(instance, out var fromFile))
        {
            _metadata[instance] = fromFile!;
            _logger.LogInformation("{Instance}: loaded {Count} entities from {File}",
                instance, fromFile!.Count, CacheFileFor(instance));
        }
        else
        {
            _logger.LogInformation("{Instance}: no cache file, reading Oracle...", instance);
            var live = await _metadataService.GetFullMetadataAsync(instance, schemaFilter);
            _metadata[instance] = live;
            await SaveToCacheAsync(instance, live);
            _logger.LogInformation("{Instance}: read {Count} entities from Oracle and cached them",
                instance, live.Count);
        }

        await MergeLinkedSynonymsAsync(instance, schemaFilter);
        await AnnotateWritableViewsAsync(instance, schemaFilter);

        var model = BuildModel(instance, _metadata[instance]);
        _models[instance] = model;
        return model;
    }

    /// <summary>
    /// Adds entities the instance reaches through a synonym over a database link.
    ///
    /// The cache files hold tables and views, because that is what the catalogue query asks
    /// for. A synonym is neither, so 145 objects per daughter that the application reaches
    /// by name were missing, and those tables read as CORP-only when they are not. A screen
    /// signed in to BCTN was told AT_AGT_MEDIA_CATEGORIES lived only on CORP and wrote
    /// there; the legacy screen on BCTN never showed the row.
    ///
    /// An owned object always wins: a synonym is only added when nothing of that name is
    /// already catalogued.
    /// </summary>
    private async Task MergeLinkedSynonymsAsync(string instance, string? schemaFilter)
    {
        try
        {
            var synonyms = await _metadataService.GetLinkedSynonymsAsync(instance, schemaFilter);
            if (synonyms.Count == 0)
            {
                return;
            }

            var catalogue = _metadata[instance];
            var added = 0;
            foreach (var (name, entity) in synonyms)
            {
                if (catalogue.ContainsKey(name))
                {
                    continue;   // we own something of this name; that wins
                }
                catalogue[name] = entity;
                added++;
            }

            _logger.LogInformation(
                "{Instance}: {Added} entities added from synonyms over a database link "
                + "(catalogue now {Total})", instance, added, catalogue.Count);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{Instance}: could not read linked synonyms; entities reached only by synonym "
                + "will be missing from the catalogue", instance);
        }
    }

    /// <summary>
    /// Asks Oracle which views accept writes, and marks them.
    ///
    /// The cache files carry structure but cannot carry this: whether a view is writable
    /// depends on INSTEAD OF triggers and key preservation, which live in the data
    /// dictionary and can change without any column changing. Several legacy forms insert
    /// through views, so refusing all of them outright would block those screens, and
    /// allowing all of them would turn a clear 405 into an Oracle error at write time.
    ///
    /// Failure here is not fatal. Every view simply stays read-only, which is what the
    /// server did before this existed.
    /// </summary>
    private async Task AnnotateWritableViewsAsync(string instance, string? schemaFilter)
    {
        var tables = _metadata[instance];
        var views = tables.Values.Count(t => t.IsView);
        if (views == 0)
        {
            return;
        }

        try
        {
            var capabilities = await _metadataService.GetViewCapabilitiesAsync(instance, schemaFilter);
            int marked = 0, insertable = 0, insteadOf = 0;
            foreach (var table in tables.Values)
            {
                if (!table.IsView || !capabilities.TryGetValue(table.TableName, out var capability))
                {
                    continue;
                }

                table.ViewCapability = capability;
                if (capability.Any) marked++;
                if (capability.CanInsert) insertable++;
                if (capability.HasInsteadOfTrigger) insteadOf++;
            }

            _logger.LogInformation(
                "{Instance}: {Marked} of {Views} views accept a write ({Insertable} insertable, "
                + "{InsteadOf} via INSTEAD OF triggers)",
                instance, marked, views, insertable, insteadOf);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{Instance}: could not determine which views accept writes; all {Views} stay "
                + "read-only", instance, views);
        }
    }

    /// <summary>Re-reads one instance from Oracle, ignoring and then rewriting its cache.</summary>
    public async Task<IEdmModel> RefreshFromOracleAsync(string instance, string? schemaFilter = null)
    {
        _logger.LogInformation("{Instance}: forced refresh from Oracle", instance);
        _models.TryRemove(instance, out _);

        var live = await _metadataService.GetFullMetadataAsync(instance, schemaFilter);
        _metadata[instance] = live;
        await SaveToCacheAsync(instance, live);

        await AnnotateWritableViewsAsync(instance, schemaFilter);

        var model = BuildModel(instance, live);
        _models[instance] = model;
        _logger.LogInformation("{Instance}: refreshed, {Count} entities", instance, live.Count);
        return model;
    }

    private IEdmModel BuildModel(string instance, Dictionary<string, EntityMetadata> tables)
    {
        var builder = new EdmModel();
        var container = new EdmEntityContainer("EWT", "Container");
        builder.AddElement(container);

        foreach (var (tableName, metadata) in tables)
        {
            var entityType = BuildEntityType(builder, tableName, metadata);
            builder.AddElement(entityType);
            container.AddEntitySet(tableName, entityType);
        }

        _logger.LogDebug("{Instance}: built EDM model with {Count} entity types",
            instance, tables.Count);
        return builder;
    }

    private bool TryLoadFromCache(string instance, out Dictionary<string, EntityMetadata>? tables)
    {
        tables = null;
        var path = CacheFileFor(instance);
        try
        {
            if (!File.Exists(path))
            {
                return false;
            }

            using var stream = File.OpenRead(path);
            var cache = JsonSerializer.Deserialize<MetadataCache>(stream, JsonOptions);
            if (cache?.Tables == null || cache.Tables.Count == 0)
            {
                _logger.LogWarning("{Instance}: cache file {File} is empty or invalid",
                    instance, path);
                return false;
            }

            tables = cache.Tables;
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Instance}: could not read {File}, will try Oracle",
                instance, path);
            return false;
        }
    }

    private async Task SaveToCacheAsync(string instance, Dictionary<string, EntityMetadata> tables)
    {
        try
        {
            Directory.CreateDirectory(_cacheDirectory);
            var cache = new MetadataCache
            {
                GeneratedAt = DateTime.UtcNow,
                Instance = instance,
                Tables = tables
            };
            await using var stream = File.Create(CacheFileFor(instance));
            await JsonSerializer.SerializeAsync(stream, cache, JsonOptions);
            _logger.LogDebug("{Instance}: saved cache to {File}", instance, CacheFileFor(instance));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Instance}: failed to save cache (non-fatal)", instance);
        }
    }

    public string CacheDirectory => _cacheDirectory;

    private EdmEntityType BuildEntityType(EdmModel model, string tableName, EntityMetadata metadata)
    {
        var entityType = new EdmEntityType("EWT", tableName, null, false, true); // open type

        var keyProperties = new List<IEdmStructuralProperty>();
        foreach (var column in metadata.Columns)
        {
            var edmType = MapOracleTypeToEdm(column.DataType, column.DataPrecision, column.DataScale);
            var property = entityType.AddStructuralProperty(column.ColumnName, edmType, column.IsNullable);

            if (metadata.PrimaryKeyColumns.Contains(column.ColumnName, StringComparer.OrdinalIgnoreCase))
            {
                keyProperties.Add(property);
            }
        }

        if (keyProperties.Count > 0)
        {
            entityType.AddKeys(keyProperties.ToArray());
        }
        else
        {
            // OData requires a key. Views and keyless tables fall back to the first column;
            // reads work, writes are blocked elsewhere by EnsureWritable.
            var firstColumn = metadata.Columns.FirstOrDefault();
            if (firstColumn != null &&
                entityType.FindProperty(firstColumn.ColumnName) is IEdmStructuralProperty existing)
            {
                entityType.AddKeys(existing);
            }
        }

        return entityType;
    }

    public static EdmPrimitiveTypeKind MapOracleTypeToEdm(string oracleType, int? precision, int? scale)
    {
        return oracleType.ToUpperInvariant() switch
        {
            "VARCHAR2" or "VARCHAR" or "CHAR" or "NVARCHAR2" or "NCHAR" or "CLOB" or "NCLOB" or "LONG"
                => EdmPrimitiveTypeKind.String,

            "NUMBER" when scale == 0 && precision <= 10
                => EdmPrimitiveTypeKind.Int32,
            "NUMBER" when scale == 0 && precision <= 19
                => EdmPrimitiveTypeKind.Int64,
            "NUMBER"
                => EdmPrimitiveTypeKind.Decimal,

            "INTEGER" or "SMALLINT"
                => EdmPrimitiveTypeKind.Int32,

            "FLOAT" or "BINARY_FLOAT"
                => EdmPrimitiveTypeKind.Single,
            "BINARY_DOUBLE"
                => EdmPrimitiveTypeKind.Double,

            "DATE" or "TIMESTAMP" or "TIMESTAMP WITH TIME ZONE" or "TIMESTAMP WITH LOCAL TIME ZONE"
                => EdmPrimitiveTypeKind.DateTimeOffset,

            "BLOB" or "RAW" or "LONG RAW"
                => EdmPrimitiveTypeKind.Binary,

            "ROWID" or "UROWID"
                => EdmPrimitiveTypeKind.String,

            _ => EdmPrimitiveTypeKind.String
        };
    }

    /// <summary>
    /// Oracle's own spelling of a column type, e.g. VARCHAR2(50), NUMBER(10,2), DATE.
    /// What a developer would see in a DDL listing.
    /// </summary>
    public static string DescribeOracleType(ColumnMetadata c)
    {
        var t = (c.DataType ?? "").ToUpperInvariant();
        return t switch
        {
            "VARCHAR2" or "VARCHAR" or "CHAR" or "NVARCHAR2" or "NCHAR" or "RAW"
                => c.DataLength is > 0 ? $"{t}({c.DataLength})" : t,
            "NUMBER" when c.DataPrecision is > 0 && c.DataScale is > 0
                => $"NUMBER({c.DataPrecision},{c.DataScale})",
            "NUMBER" when c.DataPrecision is > 0
                => $"NUMBER({c.DataPrecision})",
            _ => t
        };
    }

    /// <summary>Drops cached metadata and models. One instance, or all when null.</summary>
    public void InvalidateCache(string? instance = null)
    {
        if (instance is null)
        {
            _metadata.Clear();
            _models.Clear();
            _logger.LogInformation("In-memory metadata cleared for all instances");
            return;
        }

        _metadata.TryRemove(instance, out _);
        _models.TryRemove(instance, out _);
        _logger.LogInformation("{Instance}: in-memory metadata cleared", instance);
    }
}

/// <summary>One instance's cached metadata.</summary>
public class MetadataCache
{
    public DateTime GeneratedAt { get; set; }
    public string? Instance { get; set; }
    public Dictionary<string, EntityMetadata> Tables { get; set; } = new();
}
