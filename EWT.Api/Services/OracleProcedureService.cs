using System.Data;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace EWT.Api.Services;

/// <summary>
/// Executes Oracle stored procedures dynamically, handling IN/OUT parameters and REF CURSORs.
/// </summary>
public class OracleProcedureService
{
    private readonly OracleConnectionService _connectionService;
    private readonly string? _schemaFilter;
    private readonly ILogger<OracleProcedureService> _logger;
    private readonly Dictionary<string, List<ProcedureParameter>> _procedureCache = new(StringComparer.OrdinalIgnoreCase);

    public OracleProcedureService(
        OracleConnectionService connectionService,
        IConfiguration configuration,
        ILogger<OracleProcedureService> logger)
    {
        _connectionService = connectionService;
        _schemaFilter = configuration["Oracle:SchemaFilter"];
        _logger = logger;
    }

    /// <summary>
    /// Gets metadata for all procedures in the schema.
    /// </summary>
    public async Task<List<ProcedureInfo>> GetProceduresAsync(string instance)
    {
        var procedures = new List<ProcedureInfo>();

        // Use NVL to default to current user's schema when filter is null
        var sql = @"
            SELECT DISTINCT
                p.OWNER,
                p.OBJECT_NAME,
                p.PROCEDURE_NAME,
                p.OBJECT_TYPE,
                o.STATUS,
                o.CREATED,
                o.LAST_DDL_TIME,
                p.DETERMINISTIC,
                p.PIPELINED,
                p.AGGREGATE,
                p.AUTHID
            FROM ALL_PROCEDURES p
            JOIN ALL_OBJECTS o
              ON o.OWNER = p.OWNER
             AND o.OBJECT_NAME = p.OBJECT_NAME
             AND o.OBJECT_TYPE = p.OBJECT_TYPE
            WHERE p.OWNER = NVL(:schema, USER)
              AND p.OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION', 'PACKAGE')
              AND p.OBJECT_NAME NOT LIKE 'SYS%'
            ORDER BY p.OWNER, p.OBJECT_NAME, p.PROCEDURE_NAME";

        _logger.LogInformation("Querying procedures with schema filter: {SchemaFilter}", _schemaFilter ?? "(default to USER)");

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        await using var command = new OracleCommand(sql, connection);
        command.Parameters.Add(new OracleParameter("schema", (object?)_schemaFilter ?? DBNull.Value));

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var objectName = reader.GetString(1);
            var procedureName = reader.IsDBNull(2) ? null : reader.GetString(2);
            var objectType = reader.GetString(3);

            // For packages, include procedure name; for standalone, just object name
            var fullName = objectType == "PACKAGE" && procedureName != null
                ? $"{objectName}.{procedureName}"
                : objectName;

            static bool YesNo(object? v) =>
                string.Equals(v as string, "YES", StringComparison.OrdinalIgnoreCase);

            procedures.Add(new ProcedureInfo
            {
                Owner = reader.GetString(0),
                Name = fullName,
                ObjectType = objectType,
                PackageName = objectType == "PACKAGE" ? objectName : null,
                ProcedureName = procedureName,
                Status = reader.IsDBNull(4) ? null : reader.GetString(4),
                Created = reader.IsDBNull(5) ? null : reader.GetDateTime(5),
                LastDdlTime = reader.IsDBNull(6) ? null : reader.GetDateTime(6),
                Deterministic = !reader.IsDBNull(7) && YesNo(reader.GetValue(7)),
                Pipelined = !reader.IsDBNull(8) && YesNo(reader.GetValue(8)),
                Aggregate = !reader.IsDBNull(9) && YesNo(reader.GetValue(9)),
                AuthId = reader.IsDBNull(10) ? null : reader.GetString(10)
            });
        }

        _logger.LogInformation("Found {Count} procedures", procedures.Count);
        return procedures;
    }

    /// <summary>
    /// Gets parameter metadata for a procedure.
    /// </summary>
    public async Task<List<ProcedureParameter>> GetProcedureParametersAsync(string instance, string procedureName)
    {
        // Keyed by instance as well as name: the seven schemas are not identical, so the
        // same procedure name can have a different signature, or not exist, elsewhere.
        var cacheKey = $"{instance}:{procedureName}";
        if (_procedureCache.TryGetValue(cacheKey, out var cached))
            return cached;

        var parameters = new List<ProcedureParameter>();

        // Handle package.procedure syntax
        string objectName, subprogramName;
        bool isPackaged = procedureName.Contains('.');
        if (isPackaged)
        {
            var parts = procedureName.Split('.', 2);
            objectName = parts[0].ToUpperInvariant();
            subprogramName = parts[1].ToUpperInvariant();
        }
        else
        {
            objectName = procedureName.ToUpperInvariant();
            subprogramName = null!;
        }

        string sql;
        if (isPackaged)
        {
            // For packaged procedures, join with ALL_PROCEDURES to get SUBPROGRAM_ID
            sql = @"
                SELECT
                    a.ARGUMENT_NAME,
                    a.DATA_TYPE,
                    a.IN_OUT,
                    a.POSITION,
                    a.DATA_LENGTH,
                    a.DATA_PRECISION,
                    a.DATA_SCALE,
                    a.DEFAULTED,
                    a.CHAR_LENGTH,
                    a.PLS_TYPE,
                    a.TYPE_NAME,
                    a.DATA_LEVEL,
                    a.OVERLOAD
                FROM ALL_ARGUMENTS a
                JOIN ALL_PROCEDURES p ON a.OBJECT_ID = p.OBJECT_ID 
                    AND a.SUBPROGRAM_ID = p.SUBPROGRAM_ID
                WHERE a.OWNER = NVL(:schema, USER)
                  AND a.PACKAGE_NAME = :objectName
                  AND p.PROCEDURE_NAME = :subName
                  AND a.DATA_LEVEL = 0
                ORDER BY a.POSITION";
        }
        else
        {
            // For standalone procedures
            sql = @"
                SELECT
                    ARGUMENT_NAME,
                    DATA_TYPE,
                    IN_OUT,
                    POSITION,
                    DATA_LENGTH,
                    DATA_PRECISION,
                    DATA_SCALE,
                    DEFAULTED,
                    CHAR_LENGTH,
                    PLS_TYPE,
                    TYPE_NAME,
                    DATA_LEVEL,
                    OVERLOAD
                FROM ALL_ARGUMENTS 
                WHERE OWNER = NVL(:schema, USER)
                  AND OBJECT_NAME = :objectName
                  AND PACKAGE_NAME IS NULL
                  AND DATA_LEVEL = 0
                ORDER BY POSITION";
        }

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        await using var command = new OracleCommand(sql, connection);
        command.Parameters.Add(new OracleParameter("schema", (object?)_schemaFilter ?? DBNull.Value));
        command.Parameters.Add(new OracleParameter("objectName", objectName));
        if (isPackaged)
        {
            command.Parameters.Add(new OracleParameter("subName", subprogramName));
        }

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            parameters.Add(new ProcedureParameter
            {
                // null for a function's return value
                Name = reader.IsDBNull(0) ? null : reader.GetString(0),
                DataType = reader.IsDBNull(1) ? "" : reader.GetString(1),
                Direction = reader.IsDBNull(2) ? "IN" : reader.GetString(2),
                Position = reader.GetInt32(3),
                Length = reader.IsDBNull(4) ? null : reader.GetInt32(4),
                Precision = reader.IsDBNull(5) ? null : reader.GetInt32(5),
                Scale = reader.IsDBNull(6) ? null : reader.GetInt32(6),
                Defaulted = !reader.IsDBNull(7) &&
                            string.Equals(reader.GetString(7), "Y", StringComparison.OrdinalIgnoreCase),
                CharLength = reader.IsDBNull(8) ? null : reader.GetInt32(8),
                PlsType = reader.IsDBNull(9) ? null : reader.GetString(9),
                TypeName = reader.IsDBNull(10) ? null : reader.GetString(10),
                DataLevel = reader.IsDBNull(11) ? 0 : reader.GetInt32(11),
                Overload = reader.IsDBNull(12) ? null : int.TryParse(reader.GetString(12), out var ov) ? ov : null
            });
        }

        _procedureCache[cacheKey] = parameters;
        return parameters;
    }

    /// <summary>
    /// Executes a stored procedure with the given parameters.
    /// </summary>
    public async Task<ProcedureResult> ExecuteAsync(string instance, string procedureName, Dictionary<string, object?>? inputParams)
    {
        var paramMetadata = await GetProcedureParametersAsync(instance, procedureName);
        
        if (paramMetadata.Count == 0)
        {
            _logger.LogWarning("No parameter metadata found for procedure {Procedure}. It may not exist or have no parameters.", procedureName);
        }

        await using var connection = new OracleConnection(_connectionService.GetConnectionString(instance));
        await connection.OpenAsync();

        // Build the procedure call
        var procCall = procedureName.Contains('.') 
            ? procedureName 
            : procedureName.ToUpperInvariant();

        await using var command = new OracleCommand(procCall, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        var outParams = new Dictionary<string, OracleParameter>();
        var cursorParams = new List<OracleParameter>();

        // Add parameters based on metadata
        foreach (var param in paramMetadata)
        {
            // A function's return value is metadata, not a bindable parameter: it has no
            // name and sits at position 0. Including it would bind a nameless parameter.
            if (param.IsReturnValue)
            {
                continue;
            }

            var oracleParam = new OracleParameter
            {
                ParameterName = param.Name,
                Direction = GetParameterDirection(param.Direction)
            };

            // Set Oracle type
            oracleParam.OracleDbType = MapToOracleDbType(param.DataType);

            // Set value for IN parameters
            if (param.Direction == "IN" || param.Direction == "IN/OUT")
            {
                if (inputParams != null && param.Name != null && inputParams.TryGetValue(param.Name, out var value))
                {
                    oracleParam.Value = ConvertToOracleValue(value, param.DataType);
                }
                else
                {
                    oracleParam.Value = DBNull.Value;
                }
            }

            // For OUT and IN/OUT, set size for strings
            if ((param.Direction == "OUT" || param.Direction == "IN/OUT") && param.DataType == "VARCHAR2")
            {
                oracleParam.Size = param.Length ?? 4000;
            }

            command.Parameters.Add(oracleParam);

            if ((param.Direction == "OUT" || param.Direction == "IN/OUT") && param.Name != null)
            {
                outParams[param.Name] = oracleParam;
            }

            if (param.DataType == "REF CURSOR")
            {
                cursorParams.Add(oracleParam);
            }
        }

        _logger.LogInformation("Executing procedure {Procedure} with {ParamCount} parameters", procedureName, command.Parameters.Count);

        var result = new ProcedureResult();

        try
        {
            await command.ExecuteNonQueryAsync();

            // Collect OUT parameter values
            foreach (var (name, param) in outParams)
            {
                if (param.OracleDbType == OracleDbType.RefCursor)
                {
                    // Handle REF CURSOR - read the result set
                    if (param.Value is OracleRefCursor cursor)
                    {
                        var rows = new List<Dictionary<string, object?>>();
                        using var reader = cursor.GetDataReader();
                        while (reader.Read())
                        {
                            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
                            for (int i = 0; i < reader.FieldCount; i++)
                            {
                                row[reader.GetName(i)] = OracleValueReader.Read(reader, i);
                            }
                            rows.Add(row);
                        }
                        result.ResultSets[name] = rows;
                    }
                }
                else
                {
                    // Regular OUT parameter
                    var value = param.Value;
                    if (value is OracleString oracleString)
                        value = oracleString.IsNull ? null : oracleString.Value;
                    else if (value is OracleDecimal oracleDecimal)
                        value = oracleDecimal.IsNull ? null : oracleDecimal.Value;
                    else if (value is OracleDate oracleDate)
                        value = oracleDate.IsNull ? null : oracleDate.Value;
                    else if (value == DBNull.Value)
                        value = null;

                    result.OutParameters[name] = value;
                }
            }

            result.Success = true;
        }
        catch (OracleException ex)
        {
            _logger.LogError(ex, "Error executing procedure {Procedure}", procedureName);
            result.Success = false;
            result.Error = ex.Message;
        }

        return result;
    }

    private static ParameterDirection GetParameterDirection(string direction) => direction switch
    {
        "IN" => ParameterDirection.Input,
        "OUT" => ParameterDirection.Output,
        "IN/OUT" => ParameterDirection.InputOutput,
        _ => ParameterDirection.Input
    };

    private static OracleDbType MapToOracleDbType(string dataType) => dataType.ToUpperInvariant() switch
    {
        "VARCHAR2" => OracleDbType.Varchar2,
        "NVARCHAR2" => OracleDbType.NVarchar2,
        "CHAR" => OracleDbType.Char,
        "NCHAR" => OracleDbType.NChar,
        "NUMBER" => OracleDbType.Decimal,
        "INTEGER" => OracleDbType.Int32,
        "FLOAT" => OracleDbType.Double,
        "DATE" => OracleDbType.Date,
        "TIMESTAMP" => OracleDbType.TimeStamp,
        "CLOB" => OracleDbType.Clob,
        "NCLOB" => OracleDbType.NClob,
        "BLOB" => OracleDbType.Blob,
        "RAW" => OracleDbType.Raw,
        "REF CURSOR" => OracleDbType.RefCursor,
        "BOOLEAN" => OracleDbType.Boolean,
        _ => OracleDbType.Varchar2
    };

    private static object ConvertToOracleValue(object? value, string dataType)
    {
        if (value == null) return DBNull.Value;

        // Handle JsonElement - extract actual value first
        if (value is System.Text.Json.JsonElement jsonElement)
        {
            value = jsonElement.ValueKind switch
            {
                System.Text.Json.JsonValueKind.String => jsonElement.GetString(),
                System.Text.Json.JsonValueKind.Number => jsonElement.TryGetInt64(out var longVal) ? longVal : jsonElement.GetDecimal(),
                System.Text.Json.JsonValueKind.True => true,
                System.Text.Json.JsonValueKind.False => false,
                System.Text.Json.JsonValueKind.Null => null,
                _ => jsonElement.ToString()
            };
            
            if (value == null) return DBNull.Value;
        }

        return dataType.ToUpperInvariant() switch
        {
            "NUMBER" or "INTEGER" or "FLOAT" => Convert.ToDecimal(value),
            "DATE" or "TIMESTAMP" => value is DateTime dt ? dt : DateTime.Parse(value.ToString()!),
            _ => value
        };
    }
}

public class ProcedureInfo
{
    public string Owner { get; set; } = "";
    /// <summary>Callable name: PACKAGE.PROCEDURE for packaged routines, else the object name.</summary>
    public string Name { get; set; } = "";
    public string ObjectType { get; set; } = "";
    /// <summary>Package this lives in, or null for a standalone procedure or function.</summary>
    public string? PackageName { get; set; }
    /// <summary>Subprogram name inside the package, or null when standalone.</summary>
    public string? ProcedureName { get; set; }
    /// <summary>VALID or INVALID. An INVALID routine will fail when called.</summary>
    public string? Status { get; set; }
    public DateTime? Created { get; set; }
    public DateTime? LastDdlTime { get; set; }
    public bool Deterministic { get; set; }
    public bool Pipelined { get; set; }
    public bool Aggregate { get; set; }
    /// <summary>DEFINER or CURRENT_USER.</summary>
    public string? AuthId { get; set; }
}

public class ProcedureParameter
{
    /// <summary>Null for a function's return value, which sits at position 0.</summary>
    public string? Name { get; set; } = "";
    public string DataType { get; set; } = "";
    /// <summary>IN, OUT or IN/OUT.</summary>
    public string Direction { get; set; } = "IN";
    public int Position { get; set; }
    public int? Length { get; set; }
    public int? Precision { get; set; }
    public int? Scale { get; set; }
    /// <summary>True when the parameter has a default, so callers may omit it.</summary>
    public bool Defaulted { get; set; }
    public bool Required => !Defaulted && Direction.StartsWith("IN", StringComparison.OrdinalIgnoreCase);
    /// <summary>Declared character length, for VARCHAR2 and friends.</summary>
    public int? CharLength { get; set; }
    /// <summary>PL/SQL type name where it differs from DataType.</summary>
    public string? PlsType { get; set; }
    /// <summary>Object or collection type, for REF CURSOR, records and tables.</summary>
    public string? TypeName { get; set; }
    /// <summary>0 for a top-level parameter; deeper for members of a record or collection.</summary>
    public int DataLevel { get; set; }
    /// <summary>Overload number when the routine is overloaded, else null.</summary>
    public int? Overload { get; set; }
    /// <summary>True when this row is a function's return value rather than a parameter.</summary>
    public bool IsReturnValue => Position == 0 && string.IsNullOrEmpty(Name);
}

public class ProcedureResult
{
    public bool Success { get; set; }
    public string? Error { get; set; }
    public Dictionary<string, object?> OutParameters { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, List<Dictionary<string, object?>>> ResultSets { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
