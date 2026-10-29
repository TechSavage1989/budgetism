using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public static class BankSchema
{
    public static async Task<bool> ReadyAsync(FinanceDb db, CancellationToken token = default)
    {
        var connection = db.Database.GetDbConnection();
        var opened = connection.State != System.Data.ConnectionState.Open;
        if (opened) await connection.OpenAsync(token);
        try
        {
            await using var exists = connection.CreateCommand();
            exists.CommandText = "SELECT to_regclass('public.\"BankSchemaVersions\"')::text";
            var table = await exists.ExecuteScalarAsync(token);
            if (table is null or DBNull) return false;
            await using var version = connection.CreateCommand();
            version.CommandText = "SELECT \"Version\" FROM \"BankSchemaVersions\" WHERE \"Id\"=1";
            if (await version.ExecuteScalarAsync(token) is not int value || value != 1) return false;
            await using var tables = connection.CreateCommand();
            tables.CommandText = "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('BankConnections','BankAccounts','BankSources','BankSourceRevisions','BankBatches','BankEvents','BankSchemaVersions')";
            return Convert.ToInt32(await tables.ExecuteScalarAsync(token)) == 7;
        }
        finally { if (opened) await connection.CloseAsync(); }
    }
}
