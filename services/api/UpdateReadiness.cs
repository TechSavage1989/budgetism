using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

/// API-only update contract. It never creates or migrates storage.
public static class UpdateReadiness
{
    public static string Version => typeof(UpdateReadiness).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion.Split('+')[0];
    public static string SourceCommit => typeof(UpdateReadiness).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion.Split('+').Skip(1).FirstOrDefault() ?? "";
    public const int Contract = 1;
    public static object Identity => new { appId = "budgetism-api", version = Version, sourceCommit = SourceCommit,
        apiMajor = 1, clientApiContract = 1, minimumClientApiMajor = 1, maximumClientApiMajor = 1,
        bankSchema = 1, planningSchema = 1, updateContract = Contract };
    public static readonly string[] Tables = ["Owners", "Sessions", "LedgerAccounts", "JournalEntries",
        "LedgerPostings", "OperationRecords", "ChangeRecords", "BankConnections", "BankAccounts",
        "BankSources", "BankSourceRevisions", "BankBatches", "BankEvents", "BankSchemaVersions",
        "PlanningSchemaVersions", "PlanningWorkspaces", "PlanningEvents"];
    // Manifest and maintenance marker are deployment control files, not user data.
    public static string InstallRoot => Directory.GetParent(AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar))!.FullName;
    public static string MaintenancePath => Path.Combine(InstallRoot, "update-maintenance.json");
    public static bool Maintenance => File.Exists(MaintenancePath) || Directory.Exists(MaintenancePath);
    public static bool UpdateMode => File.Exists(Path.Combine(AppContext.BaseDirectory, "api-update-contract.json")) || Maintenance;
    public static bool IsLoopback(IPAddress? address) => address is not null && IPAddress.IsLoopback(address);

    public static async Task<bool> ReadyAsync(FinanceDb db, CancellationToken token = default)
    {
        // Exact inventory plus explicit bank/planning marker versions. Schema
        // fingerprints are additionally compared by the external coordinator.
        if (!await db.Database.CanConnectAsync(token)) return false;
        var connection = db.Database.GetDbConnection();
        var opened = connection.State != System.Data.ConnectionState.Open;
        if (opened) await connection.OpenAsync(token);
        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name";
            var found = new List<string>();
            await using (var reader = await command.ExecuteReaderAsync(token))
                while (await reader.ReadAsync(token)) found.Add(reader.GetString(0));
            if (!found.Order(StringComparer.Ordinal).SequenceEqual(Tables.Order(StringComparer.Ordinal))) return false;
        }
        finally { if (opened) await connection.CloseAsync(); }
        if (!await BankSchema.ReadyAsync(db, token) || !await PlanningSchema.ReadyAsync(db, token)) return false;
        var key = PlanningProtection.ReadKey();
        CryptographicOperations.ZeroMemory(key);
        return true;
    }
}
