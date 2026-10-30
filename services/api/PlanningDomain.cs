using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public sealed class PlanningSchemaVersion
{
    [Key] public int Id { get; set; } = 1;
    public int Version { get; set; } = 1;
}
public sealed class PlanningWorkspace
{
    [Key] public Guid OwnerId { get; set; }
    public int Version { get; set; }
    public string PayloadJson { get; set; } = "{}";
}
public sealed class PlanningEvent
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    public Guid OperationId { get; set; }
    [MaxLength(40)] public string Action { get; set; } = "";
    [MaxLength(150)] public string ObjectId { get; set; } = "";
    public int Version { get; set; }
    public string DetailsJson { get; set; } = "{}";
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}
public static class PlanningSchema
{
    public static async Task<bool> ReadyAsync(FinanceDb db, CancellationToken token = default)
    {
        var connection = db.Database.GetDbConnection();
        var opened = connection.State != System.Data.ConnectionState.Open;
        if (opened) await connection.OpenAsync(token);
        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT to_regclass('public.\"PlanningSchemaVersions\"')::text";
            if (await command.ExecuteScalarAsync(token) is null or DBNull) return false;
            command.CommandText = "SELECT \"Version\" FROM \"PlanningSchemaVersions\" WHERE \"Id\"=1";
            if (await command.ExecuteScalarAsync(token) is not int v || v != 1) return false;
            command.CommandText = "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('PlanningSchemaVersions','PlanningWorkspaces','PlanningEvents')";
            return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 3;
        }
        finally { if (opened) await connection.CloseAsync(); }
    }
}
