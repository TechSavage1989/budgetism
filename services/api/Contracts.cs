namespace Budgetism.Api;

public sealed record BootstrapRequest(string Username, string Password, string BootstrapToken);
public sealed record LoginRequest(string Username, string Password);
public sealed record CreateAccountRequest(
    Guid OperationId, string Name, string Type, string Currency, long OpeningBalanceMinor);
public sealed record CreateTransactionRequest(
    Guid OperationId, string Kind, Guid AccountId, Guid CounterpartyAccountId,
    long AmountMinor, string Currency, DateOnly EffectiveDate, string Payee, string? Notes);
public sealed record AccountResponse(
    Guid Id, string Name, string Type, string Currency, long BalanceMinor,
    bool Archived, DateTimeOffset CreatedUtc);
public sealed record CategoryResponse(Guid Id, string Name, string Kind, string Currency);
public sealed record TransactionResponse(
    Guid Id, Guid OperationId, string Kind, Guid AccountId, Guid CounterpartyAccountId,
    long AmountMinor, string Currency, DateOnly EffectiveDate, string Payee, string Notes,
    int Version, DateTimeOffset CreatedUtc);
public sealed record SyncChange(long Sequence, string EntityType, Guid EntityId,
    int Version, string PayloadJson, DateTimeOffset CreatedUtc);
