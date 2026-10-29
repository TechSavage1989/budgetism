using System.Data;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Budgetism.Api;

public sealed class BankRuleException(string code, int status = 409) : Exception(code)
{
    public string Code { get; } = code;
    public int Status { get; } = status;
}
public sealed record BankConnectInput(Guid OperationId, int ExpectedConnectionVersion, bool ConfirmFictional);
public sealed record BankMapInput(Guid OperationId, int ExpectedConnectionVersion, Guid BankAccountId,
    string Name, bool ConfirmFictional, bool ConfirmZeroBaseline);
public sealed record BankRefreshInput(Guid OperationId, int ExpectedConnectionVersion);
public sealed record BankActiveInput(Guid OperationId, int ExpectedConnectionVersion, bool Active);
public sealed record BankReviewInput(Guid OperationId, int ExpectedConnectionVersion, Guid SourceId,
    int ExpectedSourceVersion, string Action, string? Kind, Guid? CategoryId, Guid? ExistingJournalId,
    Guid? OtherSourceId, int? OtherSourceVersion, string? Payee, string? Notes, string? Reason,
    bool Confirmed, bool ReviewedDuplicates, bool ReviewedTransfers);
public sealed record BankMutation(int ConnectionVersion, int SourceChanges = 0, Guid? SourceId = null,
    Guid? JournalEntryId = null, Guid? LedgerAccountId = null, bool Ready = true);
public sealed record BankConnectionView(Guid Id, bool Active, int Version, DateTimeOffset? LastAttemptUtc,
    DateTimeOffset? LastSuccessUtc, string? LastErrorCode);
public sealed record BankAccountView(Guid Id, string Name, string? Mask, string Type, string Currency,
    bool Supported, bool Available, Guid? LedgerAccountId, long? ReportedBalanceMinor,
    long? AvailableBalanceMinor, bool BalanceIssue, DateTimeOffset ObservedUtc);
public sealed record BankSourceView(Guid Id, Guid BankAccountId, int Version, string Status,
    long? AmountMinor, string? Date, string? Description, string? PendingSourceId, bool Superseded,
    bool NeedsReview, string? Decision, int? ReviewedVersion, Guid? LinkedJournalEntryId);
public sealed record BankState(bool StorageReady, BankConnectionView? Connection,
    IReadOnlyList<BankAccountView> Accounts, IReadOnlyList<BankSourceView> Sources,
    int TotalSources, int NeedsReviewCount, bool HasMore, int NextOffset);

public sealed class ServerBank(FinanceDb db, IPlaidSandboxFeed feed, Func<SandboxCredentials> credentialsFactory)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private static string Encode(object value) => JsonSerializer.Serialize(value, Json);
    private static string Digest(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    private static void Require([DoesNotReturnIf(false)] bool condition, string code, int status = 409)
    { if (!condition) throw new BankRuleException(code, status); }
    private async Task<IDbContextTransaction> LockAsync(Guid owner, CancellationToken token)
    {
        var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, token);
        try
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"SELECT 1 FROM \"Owners\" WHERE \"Id\"={owner} FOR UPDATE", token);
            Require(await db.Owners.AnyAsync(x => x.Id == owner, token), "owner_missing", 403);
            return tx;
        }
        catch { await tx.DisposeAsync(); throw; }
    }
    private async Task<BankMutation?> CachedAsync(Guid owner, Guid operation, string type, object input, CancellationToken token)
    {
        Require(operation != Guid.Empty, "operation_required", 400);
        var old = await db.OperationRecords.AsNoTracking().SingleOrDefaultAsync(x => x.OwnerId == owner && x.OperationId == operation, token);
        if (old is null) return null;
        Require(old.OperationType == type && old.RequestHash == Digest(Encode(input)), "operation_reused");
        return JsonSerializer.Deserialize<BankMutation>(old.ResponseJson, Json)!;
    }
    private async Task<BankConnection> ConnectionAsync(Guid owner, int version, CancellationToken token)
    {
        var connection = await db.BankConnections.SingleOrDefaultAsync(x => x.OwnerId == owner, token);
        Require(connection is not null, "connect_first");
        Require(connection!.Provider == "plaid-sandbox", "sandbox_only", 403);
        Require(connection.Version == version, "connection_changed");
        return connection;
    }
    private void Event(BankConnection connection, Guid operation, string action, object details, Guid? source = null) =>
        db.BankEvents.Add(new() { ConnectionId = connection.Id, OperationId = operation,
            SourceId = source, Action = action, DetailsJson = Encode(details) });
    private async Task<BankMutation> SaveAsync(Guid owner, BankConnection connection, Guid operation,
        string type, object input, BankMutation result, CancellationToken token)
    {
        connection.Version = checked(connection.Version + 1);
        result = result with { ConnectionVersion = connection.Version };
        db.OperationRecords.Add(new() { OwnerId = owner, OperationId = operation, OperationType = type,
            RequestHash = Digest(Encode(input)), ResponseJson = Encode(result) });
        await db.SaveChangesAsync(token);
        return result;
    }
    private static BankAccountView AccountView(BankAccount a) => new(a.Id, a.Name, a.Mask, a.Type,
        a.Currency, a.Supported, a.Available, a.LedgerAccountId, a.ReportedBalanceMinor,
        a.AvailableBalanceMinor, a.BalanceIssue, a.ObservedUtc);
    private static HashSet<(Guid, string)> Replaced(IEnumerable<BankSource> sources) => sources
        .Where(x => x.PendingSourceId is not null).Select(x => (x.BankAccountId, x.PendingSourceId!)).ToHashSet();
    private static bool ReviewNeeded(BankSource s, bool mapped, bool replaced) => mapped &&
        (s.LinkedJournalEntryId is not null ? s.ReviewedVersion != s.Version || replaced && s.Decision != "kept" :
            s.Status == "posted" && !replaced && s.ReviewedVersion != s.Version);

    public async Task<BankState> StateAsync(Guid owner, int offset, int? expectedVersion, CancellationToken token)
    {
        Require(offset is >= 0 and <= 100000, "invalid_page", 400);
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead, token);
        var connection = await db.BankConnections.AsNoTracking().SingleOrDefaultAsync(x => x.OwnerId == owner, token);
        if (connection is null) return new(true, null, [], [], 0, 0, false, 0);
        Require(connection.Provider == "plaid-sandbox", "sandbox_only", 403);
        Require(expectedVersion is null || connection.Version == expectedVersion, "connection_changed");
        var accounts = await db.BankAccounts.AsNoTracking().Where(x => x.OwnerId == owner && x.ConnectionId == connection.Id).OrderBy(x => x.Name).ThenBy(x => x.Id).ToListAsync(token);
        var accountIds = accounts.Select(x => x.Id).ToArray();
        var all = await db.BankSources.AsNoTracking().Where(x => x.OwnerId == owner && accountIds.Contains(x.BankAccountId))
            .OrderBy(x => x.BankAccountId).ThenBy(x => x.ProviderSourceId).Take(100001).ToListAsync(token);
        Require(all.Count <= 100000, "source_limit");
        var replaced = Replaced(all);
        var mapped = accounts.Where(x => x.LedgerAccountId.HasValue).Select(x => x.Id).ToHashSet();
        bool Needs(BankSource s) => ReviewNeeded(s, mapped.Contains(s.BankAccountId), replaced.Contains((s.BankAccountId, s.ProviderSourceId)));
        var rows = all.Skip(offset).Take(100).Select(s => new BankSourceView(s.Id, s.BankAccountId, s.Version,
            s.Status, s.AmountMinor, s.EffectiveDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), s.Description,
            s.PendingSourceId, replaced.Contains((s.BankAccountId, s.ProviderSourceId)), Needs(s), s.Decision,
            s.ReviewedVersion, s.LinkedJournalEntryId)).ToList();
        return new(true, new(connection.Id, connection.Active, connection.Version, connection.LastAttemptUtc,
            connection.LastSuccessUtc, connection.LastErrorCode), accounts.Select(AccountView).ToList(), rows,
            all.Count, all.Count(Needs), offset + rows.Count < all.Count, offset + rows.Count);
    }

    public async Task<BankMutation> ConnectAsync(Guid owner, BankConnectInput input, CancellationToken token)
    {
        Require(input.ConfirmFictional, "fictional_confirmation_required", 400);
        await using (var initial = await LockAsync(owner, token))
        {
            var cached = await CachedAsync(owner, input.OperationId, "bank-connect", input, token);
            if (cached is not null) return cached;
            Require(!await db.BankConnections.AnyAsync(x => x.OwnerId == owner, token), "already_connected");
            Require(input.ExpectedConnectionVersion == 0, "connection_changed");
        }
        var credentials = credentialsFactory(); credentials.Validate();
        var accounts = await feed.GetAccountsAsync(credentials, token);
        Require(accounts.Count is > 0 and <= 50, "no_supported_accounts", 400);
        await using var tx = await LockAsync(owner, token);
        var retry = await CachedAsync(owner, input.OperationId, "bank-connect", input, token);
        if (retry is not null) return retry;
        Require(!await db.BankConnections.AnyAsync(x => x.OwnerId == owner, token), "already_connected");
        var connection = new BankConnection { OwnerId = owner, CredentialFingerprint = credentials.Fingerprint };
        db.BankConnections.Add(connection);
        ApplyAccounts(owner, connection, [], accounts);
        Event(connection, input.OperationId, "connect", new { fictional = true, accounts = accounts.Count });
        var result = await SaveAsync(owner, connection, input.OperationId, "bank-connect", input, new(0), token);
        await tx.CommitAsync(token); return result;
    }

    public async Task<BankMutation> MapAsync(Guid owner, BankMapInput input, CancellationToken token)
    {
        Require(input.ConfirmFictional && input.ConfirmZeroBaseline, "mapping_confirmation_required", 400);
        var name = input.Name?.Trim() ?? "";
        Require(name.StartsWith("Sandbox ", StringComparison.Ordinal) && name.Length is > 8 and <= 100, "sandbox_account_name_required", 400);
        await using var tx = await LockAsync(owner, token);
        var cached = await CachedAsync(owner, input.OperationId, "bank-map", input, token); if (cached is not null) return cached;
        var connection = await ConnectionAsync(owner, input.ExpectedConnectionVersion, token);
        var account = await db.BankAccounts.SingleOrDefaultAsync(x => x.OwnerId == owner && x.ConnectionId == connection.Id && x.Id == input.BankAccountId, token);
        Require(account is not null && account.Supported && account.Available && account.Currency == "USD", "account_unavailable", 400);
        Require(account!.LedgerAccountId is null, "mapping_exists");
        Require(!await db.LedgerAccounts.AnyAsync(x => x.OwnerId == owner && x.Name.ToLower() == name.ToLower(), token), "account_name_exists", 400);
        // Dedicated zero-baseline accounts prevent fictional sources mapping to an ordinary/real account.
        var ledger = new LedgerAccount { OwnerId = owner, Name = name, Type = account.Type,
            LedgerKind = account.Type == "credit_card" ? "Liability" : "Asset", Currency = "USD" };
        db.LedgerAccounts.Add(ledger); account.LedgerAccountId = ledger.Id;
        db.ChangeRecords.Add(new() { OwnerId = owner, EntityType = "account", EntityId = ledger.Id, Version = 1,
            PayloadJson = Encode(new AccountResponse(ledger.Id, ledger.Name, ledger.Type, "USD", 0, false, ledger.CreatedUtc)) });
        Event(connection, input.OperationId, "map", new { bankAccountId = account.Id, ledgerAccountId = ledger.Id, zeroBaseline = true });
        var result = await SaveAsync(owner, connection, input.OperationId, "bank-map", input, new(0, LedgerAccountId: ledger.Id), token);
        await tx.CommitAsync(token); return result;
    }

    private void ApplyAccounts(Guid owner, BankConnection connection, List<BankAccount> saved, IReadOnlyList<PlaidBankAccount> observed)
    {
        Require(observed.Count <= 50 && observed.Select(x => x.AccountId).Distinct(StringComparer.Ordinal).Count() == observed.Count, "invalid_accounts", 400);
        foreach (var account in saved) account.Available = false; // Missing accounts retain history and mapping.
        foreach (var item in observed)
        {
            Require(item.AccountId.Length is > 0 and <= 256 && item.Name.Length is > 0 and <= 100 &&
                (item.Mask?.Length ?? 0) <= 16 && item.Type.Length is > 0 and <= 30 && item.Currency.Length == 3,
                "invalid_accounts", 400);
            var account = saved.SingleOrDefault(x => x.ProviderAccountId == item.AccountId);
            if (account is null)
            {
                account = new() { OwnerId = owner, ConnectionId = connection.Id, ProviderAccountId = item.AccountId };
                saved.Add(account); db.BankAccounts.Add(account);
            }
            Require(account.LedgerAccountId is null || account.Type == item.Type && account.Currency == item.Currency && item.Supported, "mapped_account_changed");
            account.Name = item.Name; account.Mask = item.Mask; account.Type = item.Type; account.Currency = item.Currency;
            account.Supported = item.Supported; account.Available = true; account.ReportedBalanceMinor = item.ReportedBalanceMinor;
            account.AvailableBalanceMinor = item.AvailableBalanceMinor; account.BalanceIssue = item.BalanceIssue; account.ObservedUtc = item.ObservedUtc;
        }
    }

    public async Task<BankMutation> RefreshAsync(Guid owner, BankRefreshInput input, CancellationToken token)
    {
        string start, fingerprint;
        await using (var initial = await LockAsync(owner, token))
        {
            var cached = await CachedAsync(owner, input.OperationId, "bank-refresh", input, token); if (cached is not null) return cached;
            var connection = await ConnectionAsync(owner, input.ExpectedConnectionVersion, token);
            Require(connection.Active, "connection_disconnected");
            start = connection.Cursor; fingerprint = connection.CredentialFingerprint;
        }
        // Never hold a database transaction open while fetching external pages.
        db.ChangeTracker.Clear();
        var attempt = DateTimeOffset.UtcNow;
        try
        {
            var credentials = credentialsFactory(); credentials.Validate();
            Require(credentials.Fingerprint == fingerprint, "fixture_changed");
            var batch = await feed.GetDeltaAsync(credentials, start, token);
            if (!batch.Ready) { await FailedAttemptAsync(owner, input, attempt, "not_ready", token); return new(input.ExpectedConnectionVersion, Ready: false); }
            var accounts = await feed.GetAccountsAsync(credentials, token);
            await using var tx = await LockAsync(owner, token);
            var retry = await CachedAsync(owner, input.OperationId, "bank-refresh", input, token); if (retry is not null) return retry;
            var connection = await ConnectionAsync(owner, input.ExpectedConnectionVersion, token);
            Require(connection.Active && connection.Cursor == start && connection.CredentialFingerprint == fingerprint, "connection_changed");
            var savedAccounts = await db.BankAccounts.Where(x => x.OwnerId == owner && x.ConnectionId == connection.Id).ToListAsync(token);
            ApplyAccounts(owner, connection, savedAccounts, accounts);
            var accountIds = savedAccounts.Select(x => x.Id).ToArray();
            var sources = await db.BankSources.Where(x => x.OwnerId == owner && accountIds.Contains(x.BankAccountId)).Take(100001).ToListAsync(token);
            Require(sources.Count <= 100000, "source_limit");
            var lookup = sources.ToDictionary(x => (x.BankAccountId, x.ProviderSourceId));
            var changes = 0;
            Require(batch.Changes.Count <= 50000 && batch.Cursor.Length is > 0 and <= 4096, "invalid_batch", 400);
            foreach (var row in batch.Changes)
            {
                Require(row.SourceId.Length is > 0 and <= 256 && (row.PendingSourceId?.Length ?? 0) <= 256,
                    "invalid_source", 400);
                var account = savedAccounts.SingleOrDefault(x => x.ProviderAccountId == row.AccountId && (x.Available || row.Kind == "removed"));
                Require(account is not null && account.Supported && account.Currency == "USD", "unknown_source_account");
                var key = (account!.Id, row.SourceId);
                if (!lookup.TryGetValue(key, out var source))
                {
                    Require(lookup.Count < 100000, "source_limit");
                    source = new() { OwnerId = owner, BankAccountId = account.Id, ProviderSourceId = row.SourceId };
                    lookup.Add(key, source); db.BankSources.Add(source);
                }
                if (row.Kind == "removed") source.Status = "removed";
                else
                {
                    Require(row.Kind is "added" or "modified" && row.AmountMinor is >= -99999999999999 and <= 99999999999999 &&
                        row.Pending.HasValue && row.Description?.Length is > 0 and <= 500 && DateOnly.TryParseExact(row.Date, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _), "invalid_source", 400);
                    source.Status = row.Pending == true ? "pending" : "posted"; source.AmountMinor = row.AmountMinor;
                    source.EffectiveDate = DateOnly.ParseExact(row.Date!, "yyyy-MM-dd", CultureInfo.InvariantCulture);
                    source.Description = row.Description; source.PendingSourceId = row.PendingSourceId;
                }
                var content = Encode(new { source.ProviderSourceId, source.Status, source.AmountMinor,
                    source.EffectiveDate, source.Description, source.PendingSourceId });
                var hash = Digest(content);
                if (source.ContentHash == hash) continue;
                source.ContentHash = hash; source.Version = checked(source.Version + 1); changes++;
                db.BankSourceRevisions.Add(new() { SourceId = source.Id, Version = source.Version, ContentJson = content });
            }
            connection.Cursor = batch.Cursor; connection.LastAttemptUtc = attempt;
            connection.LastSuccessUtc = DateTimeOffset.UtcNow; connection.LastErrorCode = null;
            db.BankBatches.Add(new() { ConnectionId = connection.Id, OperationId = input.OperationId,
                OriginalCursorHash = Digest(start), FinalCursorHash = Digest(batch.Cursor),
                ContentHash = Digest(Encode(batch.Changes)), SourceChanges = changes });
            Event(connection, input.OperationId, "refresh", new { observed = batch.Changes.Count, changed = changes });
            var result = await SaveAsync(owner, connection, input.OperationId, "bank-refresh", input, new(0, changes), token);
            await tx.CommitAsync(token); return result;
        }
        catch
        {
            db.ChangeTracker.Clear();
            if (!token.IsCancellationRequested) await FailedAttemptAsync(owner, input, attempt, "refresh_failed", token);
            throw;
        }
    }

    private async Task FailedAttemptAsync(Guid owner, BankRefreshInput input, DateTimeOffset attempt, string code, CancellationToken token)
    {
        await using var tx = await LockAsync(owner, token);
        if (await db.OperationRecords.AnyAsync(x => x.OwnerId == owner && x.OperationId == input.OperationId, token)) return;
        var connection = await db.BankConnections.SingleOrDefaultAsync(x => x.OwnerId == owner, token);
        if (connection is null || connection.Version != input.ExpectedConnectionVersion) return;
        connection.LastAttemptUtc = attempt; connection.LastErrorCode = code;
        Event(connection, input.OperationId, "refresh-failed", new { code });
        await db.SaveChangesAsync(token); await tx.CommitAsync(token);
    }

    public async Task<BankMutation> ActiveAsync(Guid owner, BankActiveInput input, CancellationToken token)
    {
        await using var tx = await LockAsync(owner, token);
        var cached = await CachedAsync(owner, input.OperationId, "bank-active", input, token); if (cached is not null) return cached;
        var connection = await ConnectionAsync(owner, input.ExpectedConnectionVersion, token);
        if (input.Active) { var credentials = credentialsFactory(); credentials.Validate(); Require(credentials.Fingerprint == connection.CredentialFingerprint, "fixture_changed"); }
        connection.Active = input.Active;
        Event(connection, input.OperationId, "connection-state", new { active = input.Active });
        var result = await SaveAsync(owner, connection, input.OperationId, "bank-active", input, new(0), token);
        await tx.CommitAsync(token); return result;
    }

    public async Task<BankMutation> ReviewAsync(Guid owner, BankReviewInput input, CancellationToken token)
    {
        Require(input.Confirmed, "review_confirmation_required", 400);
        Require(input.Action is "record" or "match" or "pair" or "ignore" or "keep", "invalid_review_action", 400);
        Require((input.Payee?.Length ?? 0) <= 150 && (input.Notes?.Length ?? 0) <= 500 && (input.Reason?.Length ?? 0) <= 500, "invalid_review_text", 400);
        await using var tx = await LockAsync(owner, token);
        var cached = await CachedAsync(owner, input.OperationId, "bank-review", input, token); if (cached is not null) return cached;
        var connection = await ConnectionAsync(owner, input.ExpectedConnectionVersion, token);
        var accounts = await db.BankAccounts.Where(x => x.OwnerId == owner && x.ConnectionId == connection.Id).ToListAsync(token);
        var ids = accounts.Select(x => x.Id).ToArray();
        var sources = await db.BankSources.Where(x => x.OwnerId == owner && ids.Contains(x.BankAccountId)).ToListAsync(token);
        var source = sources.SingleOrDefault(x => x.Id == input.SourceId);
        Require(source is not null && source.Version == input.ExpectedSourceVersion, "source_changed");
        Guid? journalId = null;
        if (input.Action is "ignore" or "keep")
        {
            Require(!string.IsNullOrWhiteSpace(input.Reason), "review_reason_required", 400);
            Require(input.Action == "ignore" ? source!.LinkedJournalEntryId is null : source!.LinkedJournalEntryId is not null, "invalid_review_action");
            source.Decision = input.Action == "ignore" ? "ignored" : "kept";
            source.ReviewedVersion = source.Version; journalId = source.LinkedJournalEntryId;
        }
        else
        {
            Require(input.ReviewedDuplicates && input.ReviewedTransfers, "duplicate_transfer_review_required", 400);
            Require(source!.LinkedJournalEntryId is null, "source_already_linked");
            Require(source.Status == "posted" && source.AmountMinor is not null and not 0 && source.EffectiveDate is not null, "posted_source_required");
            var replaced = Replaced(sources);
            Require(!replaced.Contains((source.BankAccountId, source.ProviderSourceId)), "source_superseded");
            Require(source.PendingSourceId is null || !sources.Any(x => x.BankAccountId == source.BankAccountId && x.ProviderSourceId == source.PendingSourceId && x.LinkedJournalEntryId is not null), "pending_predecessor_linked");
            var account = accounts.Single(x => x.Id == source.BankAccountId);
            var ledger = await MappedLedgerAsync(owner, account, token);
            var amount = source.AmountMinor!.Value;
            if (input.Action == "match")
            {
                var entry = await db.JournalEntries.Include(x => x.Postings).SingleOrDefaultAsync(x => x.OwnerId == owner && x.Id == input.ExistingJournalId, token);
                Require(entry is not null && entry.Kind != "opening" && entry.Currency == "USD" && entry.EffectiveDate == source.EffectiveDate &&
                    entry.Postings.Where(x => x.LedgerAccountId == ledger.Id).Sum(x => x.AmountMinor) == amount, "matching_entry_required");
                Require(!sources.Any(x => x.LinkedJournalEntryId == entry!.Id && x.LinkedLedgerAccountId == ledger.Id), "entry_side_already_linked");
                Link(source, entry!, ledger.Id, "matched"); journalId = entry!.Id;
            }
            else if (input.Action == "pair")
            {
                var other = sources.SingleOrDefault(x => x.Id == input.OtherSourceId);
                Require(other is not null && other.Id != source.Id && other.Version == input.OtherSourceVersion &&
                    other.Status == "posted" && other.LinkedJournalEntryId is null && other.AmountMinor == -amount &&
                    other.EffectiveDate == source.EffectiveDate && !replaced.Contains((other.BankAccountId, other.ProviderSourceId)), "transfer_pair_required");
                Require(other!.PendingSourceId is null || !sources.Any(x => x.BankAccountId == other.BankAccountId && x.ProviderSourceId == other.PendingSourceId && x.LinkedJournalEntryId is not null), "pending_predecessor_linked");
                var otherLedger = await MappedLedgerAsync(owner, accounts.Single(x => x.Id == other.BankAccountId), token);
                Require(otherLedger.Id != ledger.Id, "transfer_pair_required");
                var from = amount < 0 ? ledger.Id : otherLedger.Id; var to = amount < 0 ? otherLedger.Id : ledger.Id;
                var entry = LedgerRules.Create(owner, input.OperationId, source.EffectiveDate.Value, "transfer", from, to, Math.Abs(amount), "USD", input.Payee?.Trim() ?? "Fictional transfer", input.Notes?.Trim() ?? "");
                db.JournalEntries.Add(entry); AddJournalChange(entry);
                Link(source, entry, ledger.Id, "paired"); Link(other, entry, otherLedger.Id, "paired");
                Event(connection, input.OperationId, "pair-side", new { other.Version, journalEntryId = entry.Id }, other.Id);
                journalId = entry.Id;
            }
            else
            {
                Require(input.Kind is "expense" or "income" or "refund", "record_kind_required", 400);
                Require(input.Kind == "expense" ? amount < 0 : amount > 0, "record_direction_mismatch", 400);
                var category = await db.LedgerAccounts.SingleOrDefaultAsync(x => x.OwnerId == owner && x.Id == input.CategoryId && !x.Archived && x.Currency == "USD", token);
                Require(category is not null && category.LedgerKind == (input.Kind == "income" ? "Income" : "Expense"), "category_required", 400);
                var description = source.Description ?? "Fictional transaction";
                var payee = input.Payee?.Trim() ?? description[..Math.Min(150, description.Length)];
                var entry = input.Kind == "refund" ? LedgerRules.CreateRefund(owner, input.OperationId, source.EffectiveDate.Value,
                    ledger.Id, category!.Id, amount, payee, input.Notes?.Trim() ?? "") :
                    LedgerRules.Create(owner, input.OperationId, source.EffectiveDate.Value, input.Kind!, ledger.Id, category!.Id, Math.Abs(amount), "USD", payee, input.Notes?.Trim() ?? "");
                db.JournalEntries.Add(entry); AddJournalChange(entry); Link(source, entry, ledger.Id, "recorded"); journalId = entry.Id;
            }
        }
        Event(connection, input.OperationId, input.Action, new { source!.Version, journalEntryId = journalId, input.Reason, input.Kind }, source.Id);
        var result = await SaveAsync(owner, connection, input.OperationId, "bank-review", input, new(0, SourceId: source.Id, JournalEntryId: journalId), token);
        await tx.CommitAsync(token); return result;
    }
    private async Task<LedgerAccount> MappedLedgerAsync(Guid owner, BankAccount account, CancellationToken token)
    {
        var ledger = await db.LedgerAccounts.SingleOrDefaultAsync(x => x.Id == account.LedgerAccountId && x.OwnerId == owner, token);
        Require(ledger is not null && !ledger.Archived && !ledger.IsSystem && ledger.Type == account.Type && ledger.Currency == "USD" &&
            ledger.LedgerKind is "Asset" or "Liability", "map_account_first");
        return ledger!;
    }
    private static void Link(BankSource source, JournalEntry journal, Guid account, string decision)
    {
        source.LinkedJournalEntryId = journal.Id; source.LinkedLedgerAccountId = account;
        source.LinkedJournalVersion = journal.Version; source.ReviewedVersion = source.Version; source.Decision = decision;
    }
    private void AddJournalChange(JournalEntry e) => db.ChangeRecords.Add(new() { OwnerId = e.OwnerId,
        EntityType = "transaction", EntityId = e.Id, Version = e.Version,
        PayloadJson = Encode(new TransactionResponse(e.Id, e.OperationId, e.Kind, e.PrimaryAccountId,
            e.CounterpartyAccountId, e.AmountMinor, e.Currency, e.EffectiveDate, e.Payee, e.Notes, e.Version, e.CreatedUtc)) });
}
