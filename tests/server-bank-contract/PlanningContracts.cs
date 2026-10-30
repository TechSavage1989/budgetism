using Budgetism.Api;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;

internal static class PlanningContracts
{
    // Invented test key, never used by the installed private server.
    private static byte[] Key() => Enumerable.Repeat((byte)0x51, 32).ToArray();
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private static void Check(bool value, string label) { if (!value) throw new Exception("FAIL: " + label); Console.WriteLine("PASS: " + label); }
    public static async Task VerifyRestoreAsync(Func<FinanceDb> create)
    {
        await using var db = create();
        var owner = await db.Owners.SingleAsync(x => x.Username == "fictional-planning-owner");
        var state = JsonSerializer.SerializeToNode(await new ServerPlanning(db, Key).StateAsync(owner.Id, default), Json)!;
        Check(state["snapshot"]!["labels"]!.AsArray().Count == 1 && state["snapshot"]!["occurrences"]!.AsArray().Count == 4,
            "Restored planning ciphertext decrypts with its separate recovery key and preserves stable occurrences");
    }
    public static async Task RunAsync(Func<FinanceDb> create, Func<string, Task<string>> digests)
    {
        var before = await digests("postgres");
        await using (var db = create()) {
            Check(!await PlanningSchema.ReadyAsync(db), "Existing 14-table database requires explicit planning upgrade");
            var sql = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "upgrade_planning_v1.sql"));
            await db.Database.ExecuteSqlRawAsync("CREATE TABLE \"PlanningWorkspaces\" (\"Fixture\" integer)");
            try { await db.Database.ExecuteSqlRawAsync(sql); throw new Exception("Partial planning schema accepted"); }
            catch (PostgresException) { await db.Database.ExecuteSqlRawAsync("ROLLBACK"); }
            await db.Database.ExecuteSqlRawAsync("DROP TABLE \"PlanningWorkspaces\"");
            await db.Database.ExecuteSqlRawAsync(sql); await db.Database.ExecuteSqlRawAsync(sql);
            Check(await PlanningSchema.ReadyAsync(db), "Planning upgrade is additive and repeatable");
            await db.Database.ExecuteSqlRawAsync("UPDATE \"PlanningSchemaVersions\" SET \"Version\"=2");
            Check(!await PlanningSchema.ReadyAsync(db), "Unknown future planning schema is unavailable");
            try { await db.Database.ExecuteSqlRawAsync(sql); throw new Exception("Future planning schema accepted"); }
            catch (PostgresException) { await db.Database.ExecuteSqlRawAsync("ROLLBACK"); }
            await db.Database.ExecuteSqlRawAsync("UPDATE \"PlanningSchemaVersions\" SET \"Version\"=1");
        }
        using (var old = JsonDocument.Parse(before))
        using (var after = JsonDocument.Parse(await digests("postgres"))) {
            Check(after.RootElement.EnumerateObject().Count() == 17 && old.RootElement.EnumerateObject().All(p => p.Value.GetRawText() == after.RootElement.GetProperty(p.Name).GetRawText()),
                "Planning schema preserves every existing table digest and adds exactly three tables");
        }
        var owner = new Owner { Username = "fictional-planning-owner", PasswordHash = "fictional-no-login" };
        var other = new Owner { Username = "fictional-other-planning", PasswordHash = "fictional-no-login" };
        var account = new LedgerAccount { OwnerId = owner.Id, Name = "Fictional planning checking", Type = "checking", LedgerKind = "Asset" };
        var category = new LedgerAccount { OwnerId = owner.Id, Name = "Fictional plan expense", Type = "expense_category", LedgerKind = "Expense", IsSystem = true };
        var manual = LedgerRules.Create(owner.Id, Guid.NewGuid(), new(2026, 5, 31), "expense", account.Id, category.Id, 135, "USD", "Fictional paid bill", "Preserved notes");
        await using (var db = create()) { db.Owners.AddRange(owner, other); db.LedgerAccounts.AddRange(account, category); db.JournalEntries.Add(manual); await db.SaveChangesAsync(); }
        async Task<JsonObject> Read(Guid? id = null) { await using var db = create(); return JsonSerializer.SerializeToNode(await new ServerPlanning(db, Key).StateAsync(id ?? owner.Id, default), Json)!.AsObject(); }
        async Task<PlanningCommand> Request(string action, object data, Guid? id = null) {
            var state = await Read(id); return new(Guid.NewGuid(), state["version"]!.GetValue<int>(), state["ledgerCursor"]!.GetValue<long>(), action, JsonSerializer.SerializeToElement(data, Json), true);
        }
        async Task<PlanningResult> Apply(PlanningCommand c, Guid? id = null) { await using var db = create(); return await new ServerPlanning(db, Key).ApplyAsync(id ?? owner.Id, c, default); }
        async Task Reject(PlanningCommand c, string code, Guid? id = null) {
            var saved = await digests("postgres");
            try { await Apply(c, id); throw new Exception("Invalid command accepted"); }
            catch (BankRuleException e) { Check(e.Code == code, "Planning refuses " + code); }
            Check(await digests("postgres") == saved, "Rejected planning command preserves all table digests");
        }
        var initial = await Read(); Check(initial["version"]!.GetValue<int>() == 0 && initial["snapshot"]!["schedules"]!.AsArray().Count == 0, "Planning starts detached and empty");
        await Reject((await Request("budget", new { month = "2026-10", categoryId = category.Id, expectedVersion = 0, amountMinor = 500, rollover = "none" })) with { Confirmed = false }, "invalid_planning_input");
        await Reject(await Request("budget", new { month = "2026-13", categoryId = category.Id, expectedVersion = 0, amountMinor = 500, rollover = "none" }), "invalid_planning_input");
        await Reject(await Request("budget", new { month = "2026-10", categoryId = category.Id, expectedVersion = 0, amountMinor = -1, rollover = "none" }), "invalid_planning_input");
        await Reject(await Request("budget", new { month = "2026-10", categoryId = category.Id, expectedVersion = 0, amountMinor = 500, rollover = "none", ownerId = other.Id }), "invalid_planning_input");
        var budget = await Request("budget", new { month = "2026-10", categoryId = category.Id, expectedVersion = 0, amountMinor = 500, rollover = "all" });
        await Apply(budget); var stable = await digests("postgres"); await Apply(budget); Check(await digests("postgres") == stable, "Budget receipt retry creates no duplicate audit");
        await Reject(budget with { Action = "budget-remove" }, "operation_reused");
        await Reject((await Request("budget", new { month = "2026-10", categoryId = category.Id, expectedVersion = 0, amountMinor = 900, rollover = "all" })), "planning_changed");
        var state = await Read();
        await Apply(await Request("budget-copy", new { month = "2026-11", expectedRevision = state["version"]!.GetValue<int>(), replaceExisting = false }));
        var scheduleInput = new { name = "Fictional monthly bill", kind = "expense", accountId = account.Id, counterpartyAccountId = category.Id, currency = "USD", amountMinor = 120, payee = "Fictional bill", notes = "Fictional plan", startDate = "2026-01-31", endDate = "2027-01-31", frequency = "monthly", expectedVersion = 0 };
        await Apply(await Request("schedule", scheduleInput)); state = await Read(); var scheduleId = state["snapshot"]!["schedules"]![0]!["id"]!.GetValue<string>();
        Check(ServerPlanning.At(new(2026, 1, 31), "monthly", 1) == new DateOnly(2026, 2, 28) && ServerPlanning.At(new(2026, 1, 31), "monthly", 2) == new DateOnly(2026, 3, 31) &&
            ServerPlanning.At(new(2024, 2, 29), "yearly", 4) == new DateOnly(2028, 2, 29), "Server recurrence preserves short-month and leap-day anchors");
        var confirm = await Request("schedule-confirm", new { scheduleId, index = 1, expectedScheduleVersion = 1, expectedOccurrenceVersion = 0, amountMinor = 120, effectiveDate = "2026-02-28", notes = "Fictional actual" });
        var recorded = await Apply(confirm); Check(recorded.TransactionId is not null, "Explicit schedule confirmation creates one actual transaction");
        stable = await digests("postgres"); Check(await Apply(confirm) == recorded && await digests("postgres") == stable, "Schedule unchanged retry survives commit and creates no second posting");
        await Reject(confirm with { OperationId = Guid.NewGuid(), ExpectedVersion = recorded.Version, ExpectedLedgerCursor = (await Read())["ledgerCursor"]!.GetValue<long>() }, "occurrence_settled");
        await Apply(await Request("schedule-skip", new { scheduleId, index = 2, expectedScheduleVersion = 1, expectedOccurrenceVersion = 0 }));
        await Apply(await Request("schedule-postpone", new { scheduleId, index = 3, expectedScheduleVersion = 1, expectedOccurrenceVersion = 0, dueDate = "2026-05-01" }));
        var financialBeforeMatch = await digests("postgres");
        await Apply(await Request("schedule-match", new { scheduleId, index = 4, expectedScheduleVersion = 1, expectedOccurrenceVersion = 0, transactionId = manual.Id, expectedTransactionVersion = 1, confirmMatch = true }));
        using (var a = JsonDocument.Parse(financialBeforeMatch)) using (var b = JsonDocument.Parse(await digests("postgres")))
            Check(new[] { "JournalEntries", "LedgerPostings", "ChangeRecords" }.All(n => a.RootElement.GetProperty(n).GetRawText() == b.RootElement.GetProperty(n).GetRawText()), "Match existing links metadata without changing money, notes or financial stream");
        await Reject(await Request("schedule-match", new { scheduleId, index = 5, expectedScheduleVersion = 1, expectedOccurrenceVersion = 0, transactionId = manual.Id, expectedTransactionVersion = 1, confirmMatch = true }), "already_matched");
        await Apply(await Request("label", new { name = "Fictional saved label", expectedVersion = 0 })); state = await Read(); var label = state["snapshot"]!["labels"]![0]!["id"]!.GetValue<string>();
        await Apply(await Request("annotate", new { transactionId = manual.Id, expectedRevision = state["version"]!.GetValue<int>(), labelIds = new[] { label } }));
        await Apply(await Request("view", new { name = "Fictional saved search", expectedVersion = 0, query = "paid", accountId = account.Id, kind = "expense", labelId = label, from = "2026-01-01", through = "2026-12-31" }));
        await Reject(await Request("annotate", new { transactionId = manual.Id, expectedRevision = 0, labelIds = new[] { label } }, other.Id), "entry_missing", other.Id);
        state = await Read(other.Id); Check(state["snapshot"]!["labels"]!.AsArray().Count == 0 && state["snapshot"]!["transactions"]!.AsArray().Count == 0, "Planning and ledger projections are owner-isolated");
        await using (var db = create()) {
            var workspace = await db.PlanningWorkspaces.SingleAsync(x => x.OwnerId == owner.Id);
            Check(workspace.PayloadJson.StartsWith("v1:") && !workspace.PayloadJson.Contains("Fictional", StringComparison.Ordinal) &&
                (await db.PlanningEvents.Where(x => x.OwnerId == owner.Id).ToListAsync()).All(x => x.DetailsJson.StartsWith("v1:")), "Planning documents and audit details are encrypted at rest");
            foreach (var e in await db.PlanningEvents.Where(x => x.OwnerId == owner.Id).ToListAsync())
                Check(JsonNode.Parse(PlanningProtection.Open(e.DetailsJson, Key(), owner.Id, $"event:{e.OperationId}:{e.Action}:{e.ObjectId}:{e.Version}")) is JsonObject, "Encrypted audit authenticates event identity and metadata");
            foreach (var (key, id, purpose) in new[] { (new byte[32], owner.Id, "workspace:" + workspace.Version), (Key(), other.Id, "workspace:" + workspace.Version), (Key(), owner.Id, "workspace:0") }) {
                try { PlanningProtection.Open(workspace.PayloadJson, key, id, purpose); throw new Exception("Ciphertext substitution accepted"); } catch (CryptographicException) { }
            }
            Check(true, "Wrong keys, owners and versions cannot decrypt planning ciphertext");
        }
        var readOnly = await digests("postgres"); await Read(); Check(await digests("postgres") == readOnly, "Planning/report reads never mutate or create occurrences");
        state = await Read();
        await Apply(await Request("category", new { expectedRevision = state["version"]!.GetValue<int>(), name = "Fictional custom category", kind = "Expense", archived = false }));
        state = await Read(); Check(state["snapshot"]!["categories"]!.AsArray().Any(c => c!["name"]!.GetValue<string>() == "Fictional custom category"), "Custom server categories join budgets, reports and future entry choices");
        var simultaneous = await Request("budget", new { month = "2026-10", categoryId = category.Id, expectedVersion = 1, amountMinor = 600, rollover = "positive" });
        var results = await Task.WhenAll(new[] { simultaneous, simultaneous with { OperationId = Guid.NewGuid() } }.Select(async c => {
            try { await Apply(c); return true; } catch (BankRuleException e) when (e.Code == "planning_changed") { return false; }
        }));
        Check(results.Count(x => x) == 1, "Owner lock serializes concurrent planning writes and rejects stale second update");
    }
}
