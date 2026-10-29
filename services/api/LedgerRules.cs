namespace Budgetism.Api;

// This pure domain function is used by both API mutations and ledger contract tests.
public static class LedgerRules
{
    public static JournalEntry Create(
        Guid ownerId, Guid operationId, DateOnly effectiveDate, string kind,
        Guid primaryId, Guid counterpartyId, long amountMinor, string currency,
        string payee, string notes)
    {
        if (primaryId == counterpartyId) throw new ArgumentException("Accounts must be different.");
        if (amountMinor <= 0 || amountMinor > 100_000_000_000_000L)
            throw new ArgumentOutOfRangeException(nameof(amountMinor), "Amount must be positive and within supported limits.");
        if (currency != "USD") throw new ArgumentException("Initial alpha supports USD only.");
        if (kind is not ("expense" or "income" or "transfer" or "opening"))
            throw new ArgumentException("Unsupported journal kind.");

        // For expense, transfer and opening balance, a negative primary posting is a credit;
        // income debits the primary account and credits the income category.
        // Opening balances are a special case: signed posting amount must match the requested opening balance.
        if (kind == "opening") throw new ArgumentException("Use CreateOpening for opening balances.");
        var primaryAmount = kind == "income" ? amountMinor : -amountMinor;
        var entry = NewEntry(ownerId, operationId, effectiveDate, kind, primaryId,
            counterpartyId, amountMinor, currency, payee, notes);
        entry.Postings.Add(Posting(entry, primaryId, primaryAmount));
        entry.Postings.Add(Posting(entry, counterpartyId, checked(-primaryAmount)));
        AssertBalanced(entry);
        return entry;
    }

    public static JournalEntry CreateOpening(
        Guid ownerId, Guid operationId, DateOnly date, Guid accountId,
        Guid openingEquityId, long signedBalanceMinor, string currency)
    {
        if (accountId == openingEquityId) throw new ArgumentException("Accounts must differ.");
        if (signedBalanceMinor == 0 || signedBalanceMinor is > 100_000_000_000_000L or < -100_000_000_000_000L)
            throw new ArgumentOutOfRangeException(nameof(signedBalanceMinor));
        if (currency != "USD") throw new ArgumentException("Initial alpha supports USD only.");
        var entry = NewEntry(ownerId, operationId, date, "opening", accountId,
            openingEquityId, Math.Abs(signedBalanceMinor), currency, "Opening balance", "");
        entry.Postings.Add(Posting(entry, accountId, signedBalanceMinor));
        entry.Postings.Add(Posting(entry, openingEquityId, checked(-signedBalanceMinor)));
        AssertBalanced(entry);
        return entry;
    }

    public static void AssertBalanced(JournalEntry entry)
    {
        if (entry.Postings.Count < 2) throw new InvalidOperationException("Every entry needs at least two postings.");
        long total = 0;
        foreach (var posting in entry.Postings)
        {
            if (posting.OwnerId != entry.OwnerId || posting.JournalEntryId != entry.Id)
                throw new InvalidOperationException("Posting identity mismatch.");
            total = checked(total + posting.AmountMinor);
        }
        if (total != 0) throw new InvalidOperationException("Unbalanced journal entry.");
    }

    // A refund is a contra-expense: it increases the account and reduces the
    // original expense category. It must never be classified as new income.
    public static JournalEntry CreateRefund(Guid ownerId, Guid operationId, DateOnly date,
        Guid accountId, Guid expenseCategoryId, long amountMinor, string payee, string notes)
    {
        if (accountId == expenseCategoryId || amountMinor <= 0 || amountMinor > 100_000_000_000_000L)
            throw new ArgumentOutOfRangeException(nameof(amountMinor));
        var entry = NewEntry(ownerId, operationId, date, "expense", accountId,
            expenseCategoryId, -amountMinor, "USD", payee, notes);
        entry.Postings.Add(Posting(entry, accountId, amountMinor));
        entry.Postings.Add(Posting(entry, expenseCategoryId, -amountMinor));
        AssertBalanced(entry);
        return entry;
    }

    private static JournalEntry NewEntry(Guid ownerId, Guid operationId, DateOnly date,
        string kind, Guid primaryId, Guid counterpartyId, long amount, string currency,
        string payee, string notes)
        => new()
        {
            OwnerId = ownerId, OperationId = operationId, EffectiveDate = date,
            Kind = kind, PrimaryAccountId = primaryId, CounterpartyAccountId = counterpartyId,
            AmountMinor = amount, Currency = currency, Payee = payee, Notes = notes
        };

    private static LedgerPosting Posting(JournalEntry entry, Guid accountId, long amount)
        => new() { JournalEntryId = entry.Id, LedgerAccountId = accountId,
            OwnerId = entry.OwnerId, AmountMinor = amount };
}
