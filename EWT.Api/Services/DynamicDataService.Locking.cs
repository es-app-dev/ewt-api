using Oracle.ManagedDataAccess.Client;

namespace EWT.Api.Services;

/// <summary>
/// Row locking, so meeting a legacy Forms session fails fast instead of hanging.
///
/// The legacy application has not gone anywhere: it writes these same tables at the same
/// time, and it uses pessimistic locking. Forms takes SELECT ... FOR UPDATE NOWAIT the
/// moment a user modifies a row and holds it until they commit, raising FRM-40501,
/// "Unable to reserve record for update", against anyone who gets there second.
///
/// That protects Forms from us. Nothing protected us from Forms. An API write to a row a
/// Forms user is holding blocked in Oracle indefinitely, and the caller eventually saw a
/// client-side command timeout: no error code, a connection tied up for 30 seconds, and a
/// failure that looks like the API is down rather than like somebody else has the record.
///
/// So a write now tries to take the lock first, with a bounded wait, and turns ORA-00054
/// into its own error the UI can show in the legacy wording. This is the same defence
/// Forms already has, not a better one. It adds nothing to the database: FOR UPDATE is a
/// statement option, and the lock lives only for the transaction that takes it.
///
/// The probe deliberately omits any If-Match predicate. Locked and changed are different
/// answers to the user, and Forms distinguishes them too: FRM-40501 for a held record,
/// FRM-40654 for one that moved underneath. Lock first, then check for change.
/// </summary>
public partial class DynamicDataService
{
    /// <summary>
    /// Takes a row lock before a write, or fails with something the caller can act on.
    ///
    /// Anything other than ORA-00054 is logged and allowed through rather than failing the
    /// write. A view that is not key-preserved cannot be locked, for instance, and refusing
    /// on that basis would break writes that work today. The write itself then surfaces
    /// whatever the real problem is.
    /// </summary>
    private async Task AcquireRowLockAsync(
        OracleConnection connection,
        OracleTransaction? transaction,
        EntityMetadata metadata,
        string whereClause,
        List<OracleParameter> parameters)
    {
        var waitSeconds = _connectionService.LockWaitSeconds;
        if (waitSeconds < 0)
        {
            return;     // explicitly disabled, back to blocking
        }

        var wait = waitSeconds == 0 ? "NOWAIT" : $"WAIT {waitSeconds}";
        var sql = $"SELECT NULL FROM {metadata.SqlName} "
                  + $"WHERE {whereClause} FOR UPDATE {wait}";

        try
        {
            await using var command = new OracleCommand(sql, connection)
            {
                CommandTimeout = WriteCommandTimeoutSeconds
            };
            if (transaction is not null)
            {
                command.Transaction = transaction;
            }
            foreach (var parameter in parameters)
            {
                command.Parameters.Add(parameter);
            }

            await command.ExecuteNonQueryAsync();
        }
        catch (OracleException ex) when (ex.Number == 54)
        {
            _logger.LogInformation(
                "{Table}: row held by another session, write refused after {Wait}s",
                metadata.TableName, waitSeconds);
            throw new RowLockedException(metadata.TableName, waitSeconds);
        }
        catch (OracleException ex)
        {
            _logger.LogWarning(
                "{Table}: could not take a row lock ({Error}); continuing without one",
                metadata.TableName, $"ORA-{ex.Number:00000}");
        }
    }
}

/// <summary>
/// The row is locked by another session, almost always a legacy Forms user with the record
/// open. Nothing was written. This is the API's equivalent of FRM-40501, and the message is
/// deliberately close to the wording operators already know.
/// </summary>
public class RowLockedException : Exception
{
    public string TableName { get; }
    public int WaitedSeconds { get; }

    public RowLockedException(string tableName, int waitedSeconds)
        : base("This record is locked by another user. Please wait and try again later.")
    {
        TableName = tableName;
        WaitedSeconds = waitedSeconds;
    }
}
