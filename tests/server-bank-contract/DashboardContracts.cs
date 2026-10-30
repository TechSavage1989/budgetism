using Budgetism.Api;
using Microsoft.EntityFrameworkCore;

internal static class DashboardContracts
{
    public static async Task RunAsync(Func<FinanceDb> create, Func<string, Task<string>> digests)
    {
        void Check(bool value, string label) { if (!value) throw new Exception("FAIL: " + label); Console.WriteLine("PASS: " + label); }
        var owner = new Owner { Username = "fictional-dashboard", PasswordHash = "fictional-no-login" };
        var empty = new Owner { Username = "fictional-empty-dashboard", PasswordHash = "fictional-no-login" };
        LedgerAccount Account(string name, string kind, string type, bool system = false) =>
            new() { OwnerId = owner.Id, Name = name, LedgerKind = kind, Type = type, IsSystem = system };
        var cash = Account("Fictional cash", "Asset", "checking");
        var debt = Account("Fictional card", "Liability", "credit_card"); debt.Archived = true;
        var equity = Account("Fictional opening", "Equity", "opening_equity", true);
        var expense = Account("Fictional food", "Expense", "expense_category");
        var income = Account("Fictional income", "Income", "income_category");
        await using (var db = create())
        {
            db.Owners.AddRange(owner, empty); db.LedgerAccounts.AddRange(cash, debt, equity, expense, income);
            db.JournalEntries.AddRange(
                LedgerRules.CreateOpening(owner.Id, Guid.NewGuid(), new(2026, 9, 1), cash.Id, equity.Id, 10000, "USD"),
                LedgerRules.CreateOpening(owner.Id, Guid.NewGuid(), new(2026, 9, 1), debt.Id, equity.Id, -5000, "USD"),
                LedgerRules.Create(owner.Id, Guid.NewGuid(), new(2026, 10, 1), "income", cash.Id, income.Id, 1000, "USD", "Fictional pay", ""),
                LedgerRules.Create(owner.Id, Guid.NewGuid(), new(2026, 10, 20), "expense", debt.Id, expense.Id, 200, "USD", "Fictional purchase", ""),
                LedgerRules.CreateRefund(owner.Id, Guid.NewGuid(), new(2026, 10, 21), debt.Id, expense.Id, 50, "Fictional refund", ""),
                LedgerRules.Create(owner.Id, Guid.NewGuid(), new(2026, 10, 22), "transfer", cash.Id, debt.Id, 500, "USD", "Fictional card payment", ""),
                LedgerRules.Create(owner.Id, Guid.NewGuid(), new(2026, 10, 31), "expense", cash.Id, expense.Id, 999, "USD", "Fictional future", ""));
            await db.SaveChangesAsync();
        }
        var before = await digests("postgres"); var feed = new FixtureFeed();
        async Task<DashboardView> Read(Guid id, DateOnly day, bool enabled)
        {
            await using var db = create();
            var bank = new ServerBank(db, feed, () => throw new Exception("Dashboard must not read credentials"));
            return await Dashboard.ReadAsync(db, bank, id, day, enabled, default);
        }
        var view = await Read(owner.Id, new(2026, 10, 30), true);
        Check(view.AssetsMinor == 10500 && view.NetBalanceMinor == 5850 && view.Accounts.Single(a => a.Id == debt.Id).BalanceMinor == -4650,
            "Dashboard uses historical signed postings, both transfer sides and archived accounts");
        Check(view.IncomeMinor == 1000 && view.ExpenseMinor == 150 && view.NetIncomeMinor == 850 &&
            view.SpendingCategories.Single().AmountMinor == 150 && view.SpendingCategories.Single().EntryCount == 2,
            "Dashboard excludes card payments/openings; refund reduces expense without becoming income");
        Check(view.RecordedCount == 6 && view.FutureCount == 1 && view.Recent.Count == 6 &&
            view.Recent.All(e => e.Date != "2026-10-31") && view.Bank.NeedsReviewCount == 0,
            "Dashboard recent/counts exclude future entries and disconnected owner data");
        var earlier = await Read(owner.Id, new(2026, 9, 30), false);
        Check(earlier.NetBalanceMinor == 5000 && earlier.ExpenseMinor == 0 && earlier.IncomeMinor == 0 &&
            earlier.Bank.Status == "disabled" && earlier.Bank.NeedsReviewCount is null, "Disabled review is unavailable rather than an invented zero");
        var blank = await Read(empty.Id, new(2026, 10, 30), true);
        Check(blank.Accounts.Count == 0 && blank.Recent.Count == 0 && blank.NetBalanceMinor == 0 && blank.RecordedCount == 0,
            "Empty and other-owner dashboards remain isolated");
        try { Dashboard.Exact(9_007_199_254_740_992m); throw new Exception("Unsafe total accepted"); }
        catch (InvalidOperationException) { }
        Check(feed.Discoveries == 0 && feed.Retrievals == 0 && await digests("postgres") == before,
            "Dashboard reads preserve every table digest and never access provider credentials/feed");
    }
}
