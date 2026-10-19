using System.Text.Json;

namespace EWT.Api.Services;

/// <summary>
/// Manages table relationships for $expand support.
/// Relationships are persisted to relationships.json.
/// </summary>
public class RelationshipService
{
    private readonly string _filePath;
    private readonly ILogger<RelationshipService> _logger;
    private Dictionary<string, List<Relationship>> _relationshipsByTable = new(StringComparer.OrdinalIgnoreCase);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public RelationshipService(ILogger<RelationshipService> logger)
    {
        _logger = logger;
        _filePath = Path.Combine(AppContext.BaseDirectory, "relationships.json");
        LoadFromFile();
    }

    /// <summary>
    /// Gets all relationships for a specific table.
    /// </summary>
    public List<Relationship> GetRelationshipsForTable(string tableName)
    {
        return _relationshipsByTable.TryGetValue(tableName.ToUpperInvariant(), out var relationships)
            ? relationships
            : new List<Relationship>();
    }

    /// <summary>
    /// Gets a specific relationship by table and name.
    /// </summary>
    public Relationship? GetRelationship(string tableName, string relationshipName)
    {
        var relationships = GetRelationshipsForTable(tableName);
        return relationships.FirstOrDefault(r => 
            r.Name.Equals(relationshipName, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>
    /// Gets all configured relationships.
    /// </summary>
    public List<Relationship> GetAllRelationships()
    {
        return _relationshipsByTable.Values.SelectMany(r => r).ToList();
    }

    /// <summary>
    /// Gets expand options available for each table.
    /// </summary>
    public Dictionary<string, List<string>> GetExpandOptionsPerTable()
    {
        return _relationshipsByTable.ToDictionary(
            kvp => kvp.Key,
            kvp => kvp.Value.Select(r => r.Name).ToList(),
            StringComparer.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Adds a new relationship.
    /// </summary>
    public Relationship AddRelationship(Relationship relationship)
    {
        // Normalize table names to uppercase
        relationship.FromTable = relationship.FromTable.ToUpperInvariant();
        relationship.ToTable = relationship.ToTable.ToUpperInvariant();
        relationship.FromColumn = relationship.FromColumn.ToUpperInvariant();
        relationship.ToColumn = relationship.ToColumn.ToUpperInvariant();

        if (!_relationshipsByTable.ContainsKey(relationship.FromTable))
        {
            _relationshipsByTable[relationship.FromTable] = new List<Relationship>();
        }

        // Check for duplicate
        var existing = _relationshipsByTable[relationship.FromTable]
            .FirstOrDefault(r => r.Name.Equals(relationship.Name, StringComparison.OrdinalIgnoreCase));
        
        if (existing != null)
        {
            // Update existing
            _relationshipsByTable[relationship.FromTable].Remove(existing);
        }

        _relationshipsByTable[relationship.FromTable].Add(relationship);
        SaveToFile();

        _logger.LogInformation("Added relationship: {FromTable}.{Name} -> {ToTable}", 
            relationship.FromTable, relationship.Name, relationship.ToTable);

        return relationship;
    }

    /// <summary>
    /// Removes a relationship.
    /// </summary>
    public bool RemoveRelationship(string tableName, string relationshipName)
    {
        var tableKey = tableName.ToUpperInvariant();
        if (!_relationshipsByTable.TryGetValue(tableKey, out var relationships))
        {
            return false;
        }

        var toRemove = relationships.FirstOrDefault(r => 
            r.Name.Equals(relationshipName, StringComparison.OrdinalIgnoreCase));

        if (toRemove == null)
        {
            return false;
        }

        relationships.Remove(toRemove);
        if (relationships.Count == 0)
        {
            _relationshipsByTable.Remove(tableKey);
        }

        SaveToFile();
        _logger.LogInformation("Removed relationship: {Table}.{Name}", tableName, relationshipName);

        return true;
    }

    /// <summary>
    /// Loads relationships from the JSON file.
    /// </summary>
    private void LoadFromFile()
    {
        try
        {
            if (!File.Exists(_filePath))
            {
                _logger.LogInformation("No relationships.json found, starting with empty relationships");
                return;
            }

            var json = File.ReadAllText(_filePath);
            List<Relationship>? list = null;

            // Accept either { "relationships": [...] } or a root array [...]
            using (var doc = JsonDocument.Parse(json))
            {
                var root = doc.RootElement;
                if (root.ValueKind == JsonValueKind.Array)
                {
                    list = JsonSerializer.Deserialize<List<Relationship>>(json, JsonOptions);
                }
                else if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty("relationships", out var rels))
                {
                    list = JsonSerializer.Deserialize<List<Relationship>>(rels.GetRawText(), JsonOptions);
                }
                else
                {
                    var data = JsonSerializer.Deserialize<RelationshipData>(json, JsonOptions);
                    list = data?.Relationships;
                }
            }

            if (list != null && list.Count > 0)
            {
                _relationshipsByTable.Clear();
                foreach (var rel in list)
                {
                    var tableKey = rel.FromTable.ToUpperInvariant();
                    if (!_relationshipsByTable.ContainsKey(tableKey))
                    {
                        _relationshipsByTable[tableKey] = new List<Relationship>();
                    }
                    _relationshipsByTable[tableKey].Add(rel);
                }

                _logger.LogInformation("Loaded {Count} relationships from {File}", 
                    list.Count, _filePath);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to load relationships.json");
        }
    }

    /// <summary>
    /// Saves relationships to the JSON file.
    /// </summary>
    private void SaveToFile()
    {
        try
        {
            var data = new RelationshipData
            {
                LastModified = DateTime.UtcNow,
                Relationships = GetAllRelationships()
            };

            var json = JsonSerializer.Serialize(data, JsonOptions);
            File.WriteAllText(_filePath, json);

            _logger.LogDebug("Saved relationships to {File}", _filePath);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to save relationships.json");
        }
    }

    /// <summary>
    /// Gets the path to the relationships file.
    /// </summary>
    public string FilePath => _filePath;
}

/// <summary>
/// A relationship between two tables.
/// </summary>
public class Relationship
{
    /// <summary>Name of the relationship (used in $expand)</summary>
    public string Name { get; set; } = "";

    /// <summary>Source table</summary>
    public string FromTable { get; set; } = "";

    /// <summary>Column in source table</summary>
    public string FromColumn { get; set; } = "";

    /// <summary>Target table</summary>
    public string ToTable { get; set; } = "";

    /// <summary>Column in target table</summary>
    public string ToColumn { get; set; } = "";

    /// <summary>Type: "many-to-one" (single object) or "one-to-many" (array)</summary>
    public string Type { get; set; } = "many-to-one";
}

/// <summary>
/// Container for serializing relationships.
/// </summary>
public class RelationshipData
{
    public DateTime LastModified { get; set; }
    public List<Relationship> Relationships { get; set; } = new();
}
