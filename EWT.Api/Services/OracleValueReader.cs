using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

namespace EWT.Api.Services;

/// <summary>
/// Reads one column from an Oracle reader, tolerating NUMBER values that cannot be
/// materialized as a .NET <see cref="decimal"/>.
///
/// Oracle NUMBER declared without precision or scale holds up to 38 significant digits; a .NET
/// decimal holds 28 to 29. For such a value ODP.NET's <c>GetValue</c> calls <c>GetDecimal</c>
/// and throws <see cref="InvalidCastException"/> ("Specified cast is not valid."), which fails
/// the whole request over one column of one row.
///
/// This lives on its own because both readers need it: the $expand and $filter query path in
/// <see cref="DynamicDataService"/>, and the REF CURSOR a stored procedure hands back in
/// <see cref="OracleProcedureService"/>. The cursor path went without it until the generated
/// query blocks arrived, and six of them failed on columns the ordinary query path had been
/// reading correctly for months.
/// </summary>
public static class OracleValueReader
{
    public static object? Read(OracleDataReader reader, int ordinal)
    {
        if (reader.IsDBNull(ordinal))
        {
            return null;
        }

        try
        {
            return reader.GetValue(ordinal);
        }
        catch (Exception ex) when (ex is InvalidCastException or OverflowException)
        {
            var oracleDecimal = reader.GetOracleDecimal(ordinal);
            if (oracleDecimal.IsNull)
            {
                return null;
            }

            // Clamp to decimal's 28 significant digits, which resolves the common case: a
            // value with more digits than decimal holds but well inside its range.
            var clamped = OracleDecimal.SetPrecision(oracleDecimal, 28);
            try
            {
                return clamped.Value;
            }
            catch (Exception inner) when (inner is InvalidCastException or OverflowException)
            {
                // Magnitude outside decimal's range. Oracle NUMBER fits comfortably in a
                // double, so the request still succeeds rather than failing on one column.
                return (double)clamped;
            }
        }
    }
}
