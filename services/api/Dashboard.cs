using System.Data;
using System.Globalization;
using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public sealed record DashboardAccount(Guid Id, string Name, string Type, bool Archived, long BalanceMinor);
public sealed record DashboardEntry(Guid Id, string Kind, Guid AccountId, string AccountName,
    Guid CounterpartyAccountId, string CounterpartyName, long AmountMinor, string Date, string Payee);
public sealed record DashboardCategory(Guid Id, string Name, long AmountMinor, int EntryCount);
public sealed record DashboardBank(string Status, BankConnectionView? Connection,
    IReadOnlyList<BankAccountView> Accounts, int? NeedsReviewCount, int? TotalSources);
public sealed record DashboardView(string Through, string Currency, long AssetsMinor, long NetBalanceMinor,
    long IncomeMinor, long ExpenseMinor, long NetIncomeMinor, int RecordedCount, int FutureCount,
    IReadOnlyList<DashboardAccount> Accounts, IReadOnlyList<DashboardEntry> Recent,
    IReadOnlyList<DashboardCategory> SpendingCategories, int SpendingCategoryCount, DashboardBank Bank);

public static class Dashboard
{
    // All values sent to Dart/web must remain exact integers.
    public static long Exact(decimal value)
    {
        if (value != decimal.Truncate(value) || Math.Abs(value) > 9_007_199_254_740_991m)
            throw new InvalidOperationException("Dashboard total outside exact range.");
        return (long)value;
    }

    public static async Task<DashboardView> ReadAsync(FinanceDb db, ServerBank bank, Guid owner,
        DateOnly through, bool reviewEnabled, CancellationToken token)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead, token);
        var accounts = await db.LedgerAccounts.AsNoTracking().Where(x => x.OwnerId == owner && !x.IsSystem &&
            (x.LedgerKind == "Asset" || x.LedgerKind == "Liability")).OrderBy(x => x.Name).ThenBy(x => x.Id)
            .Take(1001).ToListAsync(token);
        if (accounts.Count > 1000 || accounts.Any(a => a.Currency != "USD")) throw new InvalidOperationException();
        var balances = await db.LedgerPostings.AsNoTracking().Where(x => x.OwnerId == owner &&
            x.JournalEntry.OwnerId == owner && x.JournalEntry.EffectiveDate <= through)
            .GroupBy(x => x.LedgerAccountId).Select(g => new { Id = g.Key, Amount = g.Sum(x => (decimal)x.AmountMinor) })
            .ToDictionaryAsync(x => x.Id, x => x.Amount, token);
        var rows = accounts.Select(a => new DashboardAccount(a.Id, a.Name, a.Type, a.Archived,
            Exact(balances.GetValueOrDefault(a.Id)))).ToList();
        var names = accounts.ToDictionary(a => a.Id, a => a.Name);
        var entries = db.JournalEntries.AsNoTracking().Where(x => x.OwnerId == owner);
        var month = new DateOnly(through.Year, through.Month, 1);
        var monthEntries = entries.Where(x => x.EffectiveDate >= month && x.EffectiveDate <= through);
        var income = Exact(await monthEntries.Where(x => x.Kind == "income").SumAsync(x => (decimal)x.AmountMinor, token));
        var expense = Exact(await monthEntries.Where(x => x.Kind == "expense").SumAsync(x => (decimal)x.AmountMinor, token));
        var recent = await entries.Where(x => x.EffectiveDate <= through).OrderByDescending(x => x.EffectiveDate)
            .ThenBy(x => x.Id).Take(8).ToListAsync(token);
        var categories = await monthEntries.Where(x => x.Kind == "expense").GroupBy(x => x.CounterpartyAccountId)
            .Select(g => new { Id = g.Key, Amount = g.Sum(x => (decimal)x.AmountMinor), Count = g.Count() }).ToListAsync(token);
        var categoryNames = await db.LedgerAccounts.AsNoTracking().Where(x => x.OwnerId == owner && x.LedgerKind == "Expense")
            .ToDictionaryAsync(x => x.Id, x => x.Name, token);
        var categoryRows = categories.Select(c => new DashboardCategory(c.Id, categoryNames.GetValueOrDefault(c.Id, "Expense category"),
            Exact(c.Amount), c.Count)).OrderByDescending(c => c.AmountMinor).ThenBy(c => c.Id).Take(6).ToList();
        DashboardBank bankView = new("disabled", null, [], null, null);
        if (reviewEnabled)
        {
            bankView = new("storage-unavailable", null, [], null, null);
            if (await BankSchema.ReadyAsync(db, token))
            {
                var state = await bank.ReadStateAsync(owner, 0, null, token);
                bankView = new("ready", state.Connection, state.Accounts, state.NeedsReviewCount, state.TotalSources);
            }
        }
        var result = new DashboardView(through.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), "USD",
            Exact(rows.Where(a => !new[] { "credit_card", "loan", "liability" }.Contains(a.Type)).Sum(a => (decimal)a.BalanceMinor)),
            Exact(rows.Sum(a => (decimal)a.BalanceMinor)), income, expense, Exact((decimal)income - expense),
            await entries.CountAsync(x => x.EffectiveDate <= through, token),
            await entries.CountAsync(x => x.EffectiveDate > through, token), rows,
            recent.Select(e => new DashboardEntry(e.Id, e.Kind, e.PrimaryAccountId,
                names.GetValueOrDefault(e.PrimaryAccountId, "Account"), e.CounterpartyAccountId,
                names.GetValueOrDefault(e.CounterpartyAccountId, "Category"), Exact(e.AmountMinor),
                e.EffectiveDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), e.Payee)).ToList(),
            categoryRows, categories.Count, bankView);
        await tx.CommitAsync(token);
        return result;
    }

    public static void MapDashboard(this WebApplication app)
    {
        app.MapGet("/api/dashboard", async (HttpContext ctx, FinanceDb db, ServerBank bank, string? through) =>
        {
            ctx.Response.Headers.CacheControl = "no-store";
            if (!DateOnly.TryParseExact(through, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day))
                return Results.BadRequest(new { error = "A calendar date is required." });
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ctx.RequestAborted);
            timeout.CancelAfter(TimeSpan.FromSeconds(15));
            try { return Results.Ok(await ReadAsync(db, bank, (Guid)ctx.Items["ownerId"]!, day,
                Environment.GetEnvironmentVariable("PLAID_SANDBOX_REVIEW_ENABLED") == "true", timeout.Token)); }
            catch (Exception) { return Results.Json(new { error = "Dashboard unavailable. Saved records are unchanged." }, statusCode: 503); }
        });
    }
}
