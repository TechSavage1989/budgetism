using Budgetism.Api;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

internal static class Contracts
{
    private static void Check(bool value, string name)
    {
        if (!value) throw new Exception("FAIL: " + name);
        Console.WriteLine("PASS: " + name);
    }
    public static async Task RunAsync(string[] args)
    {
        if (args.Length != 2 || args[0] is not ("--disposable-cluster" or "--verify-disposable"))
            throw new Exception("Use the isolated PostgreSQL test runner; no default/live database is supported.");
        var directory = Path.GetFullPath(args[1]);
        if (!File.Exists(Path.Combine(directory, "budgetism-disposable-test"))) throw new Exception("Disposable marker missing.");
        var csb = new NpgsqlConnectionStringBuilder {
            Host = "127.0.0.1", Port = int.Parse(File.ReadAllText(Path.Combine(directory, "port"))),
            Database = "postgres", Username = "budgetism_bank_test", Pooling = false,
            Password = File.ReadAllText(Path.Combine(directory, "password")) };
        if (csb.Port is 55432 or 5432) throw new Exception("Refusing ordinary database ports.");
        var options = new DbContextOptionsBuilder<FinanceDb>().UseNpgsql(csb.ConnectionString).Options;
        FinanceDb Db() => new(options);
        async Task<string> Digests(string database)
        {
            var digestBuilder = new NpgsqlConnectionStringBuilder(csb.ConnectionString) { Database = database };
            await using var connection = new NpgsqlConnection(digestBuilder.ConnectionString); await connection.OpenAsync();
            var names = new List<string>();
            await using (var command = new NpgsqlCommand("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name", connection))
            await using (var reader = await command.ExecuteReaderAsync()) { while (await reader.ReadAsync()) names.Add(reader.GetString(0)); }
            var digests = new Dictionary<string, object>();
            foreach (var name in names)
            {
                var identifier = new NpgsqlCommandBuilder().QuoteIdentifier(name);
                await using var command = new NpgsqlCommand("SELECT row_to_json(t)::text FROM " + identifier + " t", connection);
                await using var reader = await command.ExecuteReaderAsync(); var rows = new List<string>();
                while (await reader.ReadAsync()) rows.Add(reader.GetString(0));
                rows.Sort(StringComparer.Ordinal);
                digests[name] = new { count = rows.Count, hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join('\n', rows)))) };
            }
            return JsonSerializer.Serialize(digests);
        }
        if (args[0] == "--verify-disposable")
        {
            Check(await Digests("bank_recovery") == await File.ReadAllTextAsync(Path.Combine(directory, "expected-digests.json")),
                "Independent dump/restore preserves every table, source revision, cursor and ledger link");
            return;
        }
        var sql = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "upgrade_bank_sources_v1.sql"));
        await using (var db = Db())
        {
            await db.Database.OpenConnectionAsync();
            await using var guard = db.Database.GetDbConnection().CreateCommand();
            guard.CommandText = "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'";
            Check(Convert.ToInt32(await guard.ExecuteScalarAsync()) == 0, "Disposable database starts empty");
            var legacy = db.Database.GenerateCreateScript().Split(';', StringSplitOptions.RemoveEmptyEntries)
                .Where(s => !s.TrimStart().StartsWith("CREATE TABLE \"Bank", StringComparison.Ordinal) && !s.Contains(" ON \"Bank", StringComparison.Ordinal));
            // Only EF-generated DDL is accepted here; no input is interpolated into identifiers.
#pragma warning disable EF1003
            await db.Database.ExecuteSqlRawAsync(string.Join(';', legacy) + ";");
#pragma warning restore EF1003
            Check(!await BankSchema.ReadyAsync(db), "Legacy database requires an explicit upgrade");
            var preservedOwner = new Owner { Username = "fictional-preserved-owner", PasswordHash = "fictional-not-a-password" };
            db.Owners.Add(preservedOwner);
            var oldAccount = new LedgerAccount { OwnerId = preservedOwner.Id, Name = "Preserved fictional account", LedgerKind = "Asset", Type = "checking" };
            var oldCategory = new LedgerAccount { OwnerId = preservedOwner.Id, Name = "Preserved fictional category", LedgerKind = "Expense", Type = "expense_category" };
            db.LedgerAccounts.AddRange(oldAccount, oldCategory);
            db.JournalEntries.Add(LedgerRules.Create(preservedOwner.Id, Guid.NewGuid(), new(2026, 10, 28), "expense", oldAccount.Id, oldCategory.Id, 25, "USD", "Preserved fictional payee", "Preserved fictional notes"));
            await db.SaveChangesAsync();
            var baselineDigests = await Digests("postgres");
            await db.Database.ExecuteSqlRawAsync("CREATE TABLE \"BankSources\" (\"Fixture\" integer)");
            try { await db.Database.ExecuteSqlRawAsync(sql); throw new Exception("Partial schema accepted"); }
            catch (PostgresException) { await db.Database.ExecuteSqlRawAsync("ROLLBACK"); }
            await db.Database.ExecuteSqlRawAsync("DROP TABLE \"BankSources\"");
            Check(!await BankSchema.ReadyAsync(db), "Partial schema is refused before upgrade");
            await db.Database.ExecuteSqlRawAsync(sql);
            await db.Database.ExecuteSqlRawAsync(sql);
            Check(await BankSchema.ReadyAsync(db) && await db.Owners.CountAsync() == 1 &&
                await db.JournalEntries.CountAsync() == 1, "Upgrade is additive and repeatable; existing owner and ledger preserved");
            using (var before = JsonDocument.Parse(baselineDigests))
            using (var after = JsonDocument.Parse(await Digests("postgres")))
                Check(before.RootElement.EnumerateObject().All(x => x.Value.GetRawText() == after.RootElement.GetProperty(x.Name).GetRawText()),
                    "All seven legacy table row counts and content digests are unchanged by upgrade");
            await db.Database.ExecuteSqlRawAsync("UPDATE \"BankSchemaVersions\" SET \"Version\"=2");
            Check(!await BankSchema.ReadyAsync(db), "Unknown future schema is unavailable");
            try { await db.Database.ExecuteSqlRawAsync(sql); throw new Exception("Future schema accepted"); }
            catch (PostgresException) { await db.Database.ExecuteSqlRawAsync("ROLLBACK"); }
            await db.Database.ExecuteSqlRawAsync("UPDATE \"BankSchemaVersions\" SET \"Version\"=1");
        }
        var owner = new Owner { Username = "fictional-review-owner", PasswordHash = "fictional-not-a-password" };
        var otherOwner = new Owner { Username = "fictional-other-owner", PasswordHash = "fictional-not-a-password" };
        var expense = new LedgerAccount { OwnerId = owner.Id, Name = "Fictional spending", LedgerKind = "Expense", Type = "expense_category", IsSystem = true };
        var income = new LedgerAccount { OwnerId = owner.Id, Name = "Fictional income", LedgerKind = "Income", Type = "income_category", IsSystem = true };
        var foreignCategory = new LedgerAccount { OwnerId = otherOwner.Id, Name = "Other owner's category", LedgerKind = "Expense", Type = "expense_category", IsSystem = true };
        await using (var db = Db()) { db.Owners.AddRange(owner, otherOwner); db.LedgerAccounts.AddRange(expense, income, foreignCategory); await db.SaveChangesAsync(); }
        var feed = new FixtureFeed();
        var credentials = new SandboxCredentials("fictional-client", "fictional-secret", "access-sandbox-fictional");
        async Task<T> Use<T>(Func<ServerBank, Task<T>> action)
        { await using var db = Db(); return await action(new ServerBank(db, feed, () => credentials)); }
        async Task Reject(Func<Task> action, string code)
        {
            try { await action(); } catch (BankRuleException ex) when (ex.Code == code) { Check(true, "Refused " + code); return; }
            throw new Exception("FAIL: expected " + code);
        }
        Task<BankState> State(Guid? who = null) => Use(b => b.StateAsync(who ?? owner.Id, 0, null, default));
        var connect = new BankConnectInput(Guid.NewGuid(), 0, true);
        var connected = await Use(b => b.ConnectAsync(owner.Id, connect, default));
        Check(connected.ConnectionVersion == 1 && await Use(b => b.ConnectAsync(owner.Id, connect, default)) == connected && feed.Discoveries == 1,
            "Connect retry returns stored response without provider retrieval");
        var state = await State();
        var a = state.Accounts.Single(x => x.Name == "Fictional checking");
        var z = state.Accounts.Single(x => x.Name == "Fictional savings");
        await Reject(async () => { await Use(b => b.MapAsync(owner.Id, new(Guid.NewGuid(), 1, a.Id, "Ordinary account", true, true), default)); }, "sandbox_account_name_required");
        var map = new BankMapInput(Guid.NewGuid(), 1, a.Id, "Sandbox checking", true, true);
        var mapped = await Use(b => b.MapAsync(owner.Id, map, default));
        Check(await Use(b => b.MapAsync(owner.Id, map, default)) == mapped, "Mapping retry creates one dedicated zero-baseline account");
        await Use(b => b.MapAsync(owner.Id, new(Guid.NewGuid(), 2, z.Id, "Sandbox savings", true, true), default));
        await using (var db = Db()) Check(await db.JournalEntries.CountAsync(x => x.OwnerId == owner.Id) == 0 && await db.LedgerPostings.CountAsync(x => x.OwnerId == owner.Id) == 0,
            "Mapping reported balances creates no opening entry or posting");
        PlaidPreviewRow Row(string id, long amount, bool pending = false, string account = "checking", string? predecessor = null, string kind = "added") =>
            new(kind, account, id, amount, "2026-10-29", "Fictional " + id, pending, predecessor);
        feed.Batch = new(true, "cursor-1", [Row("expense", -1234), Row("income", 10000), Row("refund", 29), Row("pending", -250, true),
            Row("transfer-out", -5000), Row("transfer-in", 5000, account: "savings"), Row("manual", -400), Row("duplicate-manual", -400)]);
        var refresh = new BankRefreshInput(Guid.NewGuid(), 3);
        var refreshed = await Use(b => b.RefreshAsync(owner.Id, refresh, default));
        Check(refreshed.SourceChanges == 8 && await Use(b => b.RefreshAsync(owner.Id, refresh, default)) == refreshed && feed.Retrievals == 1,
            "Complete source batch and cursor commit once; unchanged retry never fetches again");
        state = await State();
        Check(state.NeedsReviewCount == 7 && state.Sources.Count == 8, "Pending source is retained but not a posting candidate");
        async Task<BankSource> Source(string id)
        { await using var db = Db(); return await db.BankSources.AsNoTracking().SingleAsync(x => x.OwnerId == owner.Id && x.ProviderSourceId == id); }
        async Task<BankReviewInput> Review(string id, string action = "record", string? kind = "expense", Guid? category = null)
        {
            var s = await Source(id); var current = await State();
            return new(Guid.NewGuid(), current.Connection!.Version, s.Id, s.Version, action, kind, category ?? expense.Id,
                null, null, null, "User payee", "User notes", null, true, true, true);
        }
        await Reject(async () => { var request = await Review("pending"); await Use(b => b.ReviewAsync(owner.Id, request, default)); }, "posted_source_required");
        await Reject(async () => { var request = await Review("expense", category: foreignCategory.Id); await Use(b => b.ReviewAsync(owner.Id, request, default)); }, "category_required");
        await Reject(async () => { var request = await Review("expense"); await Use(b => b.ReviewAsync(owner.Id, request with { ReviewedDuplicates = false }, default)); }, "duplicate_transfer_review_required");
        var recordedRequest = await Review("expense");
        var recorded = await Use(b => b.ReviewAsync(owner.Id, recordedRequest, default));
        Check(await Use(b => b.ReviewAsync(owner.Id, recordedRequest, default)) == recorded, "Record reply survives a lost response without reposting");
        await Reject(async () => { await Use(b => b.ReviewAsync(owner.Id, recordedRequest with { Notes = "Different request" }, default)); }, "operation_reused");
        foreach (var (id, kind, category) in new[] { ("income", "income", income.Id), ("refund", "refund", expense.Id) })
        { var request = await Review(id, kind: kind, category: category); await Use(b => b.ReviewAsync(owner.Id, request, default)); }
        var pair = await Review("transfer-out", "pair", "transfer"); var other = await Source("transfer-in");
        await Use(b => b.ReviewAsync(owner.Id, pair with { OtherSourceId = other.Id, OtherSourceVersion = other.Version }, default));
        Guid manualId;
        await using (var db = Db())
        {
            var ledgerId = (await db.BankAccounts.SingleAsync(x => x.Id == a.Id)).LedgerAccountId!.Value;
            var manual = LedgerRules.Create(owner.Id, Guid.NewGuid(), new(2026, 10, 29), "expense", ledgerId, expense.Id, 400, "USD", "Existing user payee", "Preserve these notes");
            manualId = manual.Id; db.JournalEntries.Add(manual); await db.SaveChangesAsync();
        }
        var match = await Review("manual", "match");
        await Use(b => b.ReviewAsync(owner.Id, match with { ExistingJournalId = manualId }, default));
        await Reject(async () => { var req = await Review("duplicate-manual", "match"); await Use(b => b.ReviewAsync(owner.Id, req with { ExistingJournalId = manualId }, default)); }, "entry_side_already_linked");
        await using (var db = Db())
        {
            var entries = await db.JournalEntries.Include(x => x.Postings).Where(x => x.OwnerId == owner.Id).ToListAsync();
            foreach (var entry in entries) LedgerRules.AssertBalanced(entry);
            Check(entries.Count == 5 && entries.Single(x => x.Kind == "transfer").AmountMinor == 5000 &&
                entries.Where(x => x.Kind == "expense").Sum(x => x.AmountMinor) == 1605,
                "Expense, income, refund and paired transfer balance exactly; refund reduces spending");
            Check(entries.Single(x => x.Id == manualId).Notes == "Preserve these notes", "Matching preserves existing journal metadata and creates no entry");
        }
        state = await State();
        feed.Batch = new(true, "cursor-2", [Row("expense", -1500, kind: "modified"), Row("posted-pending", -250, predecessor: "pending"),
            new("removed", "checking", "income", null, null, null, null, null)]);
        await Use(b => b.RefreshAsync(owner.Id, new(Guid.NewGuid(), state.Connection!.Version), default));
        state = await State();
        var pending = await Source("pending");
        Check(state.Sources.Single(x => x.Id == pending.Id).Superseded && state.Sources.Count == 9,
            "Pending replacement is retained; missing rows are not removals");
        await using (var db = Db()) Check((await db.JournalEntries.SingleAsync(x => x.Id == recorded.JournalEntryId)).AmountMinor == 1234,
            "Changed and removed linked sources never silently change recorded finances");
        // Batch decisions are all-or-nothing, idempotent and never financial postings.
        var expenseSource = await Source("expense"); var incomeSource = await Source("income");
        var duplicateSource = await Source("duplicate-manual"); var postedSource = await Source("posted-pending");
        state = await State();
        var batchKeep = new BankReviewBatchInput(Guid.NewGuid(), state.Connection!.Version, "keep",
            [new(expenseSource.Id, expenseSource.Version), new(incomeSource.Id, incomeSource.Version)], "Keep the recorded fictional entries", true);
        var beforeBatch = await Digests("postgres");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Sources = [] }, default)); }, "invalid_batch_selection");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Sources = Enumerable.Range(0, 101).Select(_ => new BankBatchSource(Guid.NewGuid(), 1)).ToArray() }, default)); }, "invalid_batch_selection");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Reason = " " }, default)); }, "review_reason_required");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Action = "ignore", Sources = [new(pending.Id, pending.Version)] }, default)); }, "source_changed");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(otherOwner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), ExpectedConnectionVersion = 0 }, default)); }, "connect_first");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Sources = [new(expenseSource.Id, expenseSource.Version), new(incomeSource.Id, incomeSource.Version + 1)] }, default)); }, "source_changed");
        Check(await Digests("postgres") == beforeBatch, "Stale batch leaves every table unchanged; no partial review or receipt");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Action = "ignore", Sources = [new(duplicateSource.Id, duplicateSource.Version), new(incomeSource.Id, incomeSource.Version)] }, default)); }, "invalid_batch_selection");
        Check(await Digests("postgres") == beforeBatch, "Mixed invalid selection rolls back before any decision");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with { OperationId = Guid.NewGuid(), Action = "record" }, default)); }, "invalid_batch_action");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Sources = [new(expenseSource.Id, expenseSource.Version), new(expenseSource.Id, expenseSource.Version)] }, default)); }, "invalid_batch_selection");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with {
            OperationId = Guid.NewGuid(), Sources = [new(expenseSource.Id, expenseSource.Version), new(Guid.NewGuid(), 1)] }, default)); }, "source_changed");
        var kept = await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep, default));
        Check(kept.ReviewedSources == 2 && kept.ConnectionVersion == batchKeep.ExpectedConnectionVersion + 1,
            "Batch keeps two linked decisions with one connection version increment");
        var afterKept = await Digests("postgres");
        Check(await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with { Sources = batchKeep.Sources.Reverse().ToArray() }, default)) == kept &&
            await Digests("postgres") == afterKept, "Batch retry canonicalizes selection order and creates no repeated audit or writes");
        await Reject(async () => { await Use(b => b.ReviewBatchAsync(owner.Id, batchKeep with { Reason = "Different decision" }, default)); }, "operation_reused");
        state = await State();
        var ignoredBatch = new BankReviewBatchInput(Guid.NewGuid(), state.Connection!.Version, "ignore",
            [new(duplicateSource.Id, duplicateSource.Version), new(postedSource.Id, postedSource.Version)], "Ignore these fictional sources", true);
        await Use(b => b.ReviewBatchAsync(owner.Id, ignoredBatch, default));
        state = await State();
        var reopen = ignoredBatch with { OperationId = Guid.NewGuid(), ExpectedConnectionVersion = state.Connection!.Version,
            Action = "reopen", Reason = "Review these fictional sources again" };
        var reopened = await Use(b => b.ReviewBatchAsync(owner.Id, reopen, default));
        Check(reopened.ReviewedSources == 2 && (await Source("duplicate-manual")).Decision is null &&
            (await Source("posted-pending")).ReviewedVersion is null, "Explicit batch reopen restores review eligibility without touching recorded money");
        using (var before = JsonDocument.Parse(beforeBatch))
        using (var after = JsonDocument.Parse(await Digests("postgres")))
            Check(new[] { "JournalEntries", "LedgerPostings", "ChangeRecords" }.All(name =>
                before.RootElement.GetProperty(name).GetRawText() == after.RootElement.GetProperty(name).GetRawText()),
                "Batch keep/ignore preserves journal, postings and financial change stream exactly");
        var keep = await Review("expense", "keep");
        await Use(b => b.ReviewAsync(owner.Id, keep with { Reason = "Keep recorded value while investigating" }, default));
        var ignored = await Review("duplicate-manual", "ignore");
        await Use(b => b.ReviewAsync(owner.Id, ignored with { Reason = "Duplicate fictional fixture" }, default));
        state = await State();
        var beforeFailure = state; var failureInput = new BankRefreshInput(Guid.NewGuid(), state.Connection!.Version);
        feed.Batch = new(true, "must-not-commit", [Row("partial-good", -1), Row("invalid", -2, account: "unknown")]);
        await Reject(async () => { await Use(b => b.RefreshAsync(owner.Id, failureInput, default)); }, "unknown_source_account");
        state = await State();
        await using (var db = Db()) Check(state.TotalSources == beforeFailure.TotalSources &&
            (await db.BankConnections.SingleAsync(x => x.OwnerId == owner.Id)).Cursor == "cursor-2" &&
            !await db.BankSources.AnyAsync(x => x.ProviderSourceId == "partial-good"), "Partial failure rolls back sources, history and cursor together");
        feed.Batch = new(true, "cursor-3", []);
        await Use(b => b.RefreshAsync(owner.Id, failureInput, default));
        Check(feed.LastCursor == "cursor-2", "Failed refresh retries from last committed cursor");
        var stale = await Review("posted-pending");
        state = await State();
        await Use(b => b.ActiveAsync(owner.Id, new(Guid.NewGuid(), state.Connection!.Version, false), default));
        await Reject(async () => { await Use(b => b.ReviewAsync(owner.Id, stale, default)); }, "connection_changed");
        state = await State();
        await Reject(async () => { await Use(b => b.RefreshAsync(owner.Id, new(Guid.NewGuid(), state.Connection!.Version), default)); }, "connection_disconnected");
        Check(state.Sources.Count == 9 && (await State(otherOwner.Id)).Sources.Count == 0, "Disconnect retains history; other owners cannot see it");
        credentials = new("fictional-client", "fictional-secret", "access-sandbox-different");
        await Reject(async () => { await Use(b => b.ActiveAsync(owner.Id, new(Guid.NewGuid(), state.Connection!.Version, true), default)); }, "fixture_changed");
        credentials = new("fictional-client", "fictional-secret", "access-sandbox-fictional");
        await Use(b => b.ActiveAsync(owner.Id, new(Guid.NewGuid(), state.Connection!.Version, true), default));
        state = await State();
        var concurrentVersion = state.Connection!.Version;
        var operations = new[] { new BankActiveInput(Guid.NewGuid(), concurrentVersion, false), new BankActiveInput(Guid.NewGuid(), concurrentVersion, false) };
        var results = await Task.WhenAll(operations.Select(async request => {
            try { await Use(b => b.ActiveAsync(owner.Id, request, default)); return true; }
            catch (BankRuleException ex) when (ex.Code == "connection_changed") { return false; }
        }));
        Check(results.Count(x => x) == 1, "Concurrent mutations serialize; stale second request is rejected");
        Check((await State()).Sources.Count == 9, "New database contexts preserve durable source/review history");
        var dashboardBefore = await Digests("postgres");
        await using (var db = Db())
        {
            var overview = await Dashboard.ReadAsync(db, new ServerBank(db, feed, () => throw new Exception("No dashboard credentials")),
                owner.Id, new(2026, 10, 30), true, default);
            var expected = await State();
            Check(overview.Bank.NeedsReviewCount == expected.NeedsReviewCount && overview.Bank.TotalSources == expected.TotalSources &&
                overview.Bank.Connection!.Version == expected.Connection!.Version, "Dashboard review count shares full source review semantics");
        }
        Check(await Digests("postgres") == dashboardBefore, "Dashboard with saved source history preserves all table digests");
        await DashboardContracts.RunAsync(Db, Digests);
        await File.WriteAllTextAsync(Path.Combine(directory, "expected-digests.json"), await Digests("postgres"));
        Console.WriteLine("PASS: All server bank contracts used invented data in an isolated loopback cluster.");
    }
}

internal sealed class FixtureFeed : IPlaidSandboxFeed
{
    public int Discoveries { get; private set; }
    public int Retrievals { get; private set; }
    public string LastCursor { get; private set; } = "";
    public PlaidDeltaBatch Batch { get; set; } = new(true, "fictional", []);
    public Task<IReadOnlyList<PlaidBankAccount>> GetAccountsAsync(SandboxCredentials credentials, CancellationToken token)
    {
        Discoveries++;
        return Task.FromResult<IReadOnlyList<PlaidBankAccount>>([
            new("checking", "Fictional checking", "0001", "checking", "USD", true, 100000, 100000, false, DateTimeOffset.UtcNow),
            new("savings", "Fictional savings", "0002", "savings", "USD", true, 50000, 50000, false, DateTimeOffset.UtcNow)]);
    }
    public Task<PlaidDeltaBatch> GetDeltaAsync(SandboxCredentials credentials, string cursor, CancellationToken token)
    { Retrievals++; LastCursor = cursor; return Task.FromResult(Batch); }
}
