using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public sealed class BankSchemaVersion
{
    [Key] public int Id { get; set; } = 1;
    public int Version { get; set; } = 1;
}
public sealed class BankConnection
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    [MaxLength(30)] public string Provider { get; set; } = "plaid-sandbox";
    [MaxLength(64)] public string CredentialFingerprint { get; set; } = "";
    public bool Active { get; set; } = true;
    public int Version { get; set; }
    [MaxLength(4096)] public string Cursor { get; set; } = "";
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? LastAttemptUtc { get; set; }
    public DateTimeOffset? LastSuccessUtc { get; set; }
    [MaxLength(50)] public string? LastErrorCode { get; set; }
}
public sealed class BankAccount
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    public Guid ConnectionId { get; set; }
    [MaxLength(256)] public string ProviderAccountId { get; set; } = "";
    [MaxLength(100)] public string Name { get; set; } = "";
    [MaxLength(16)] public string? Mask { get; set; }
    [MaxLength(30)] public string Type { get; set; } = "";
    [MaxLength(3)] public string Currency { get; set; } = "USD";
    public bool Supported { get; set; }
    public bool Available { get; set; } = true;
    public Guid? LedgerAccountId { get; set; }
    public long? ReportedBalanceMinor { get; set; }
    public long? AvailableBalanceMinor { get; set; }
    public bool BalanceIssue { get; set; }
    public DateTimeOffset ObservedUtc { get; set; }
}
public sealed class BankSource
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    public Guid BankAccountId { get; set; }
    [MaxLength(256)] public string ProviderSourceId { get; set; } = "";
    public int Version { get; set; }
    [MaxLength(64)] public string ContentHash { get; set; } = "";
    [MaxLength(10)] public string Status { get; set; } = "";
    public long? AmountMinor { get; set; }
    public DateOnly? EffectiveDate { get; set; }
    [MaxLength(500)] public string? Description { get; set; }
    [MaxLength(256)] public string? PendingSourceId { get; set; }
    public int? ReviewedVersion { get; set; }
    [MaxLength(20)] public string? Decision { get; set; }
    public Guid? LinkedJournalEntryId { get; set; }
    public Guid? LinkedLedgerAccountId { get; set; }
    public int? LinkedJournalVersion { get; set; }
}
public sealed class BankSourceRevision
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid SourceId { get; set; }
    public int Version { get; set; }
    public string ContentJson { get; set; } = "";
    public DateTimeOffset ObservedUtc { get; set; } = DateTimeOffset.UtcNow;
}
public sealed class BankBatch
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ConnectionId { get; set; }
    public Guid OperationId { get; set; }
    [MaxLength(64)] public string OriginalCursorHash { get; set; } = "";
    [MaxLength(64)] public string FinalCursorHash { get; set; } = "";
    [MaxLength(64)] public string ContentHash { get; set; } = "";
    public int SourceChanges { get; set; }
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}
public sealed class BankEvent
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ConnectionId { get; set; }
    public Guid OperationId { get; set; }
    public Guid? SourceId { get; set; }
    [MaxLength(30)] public string Action { get; set; } = "";
    public string DetailsJson { get; set; } = "";
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}

public static class BankModel
{
    public static void Configure(ModelBuilder m)
    {
        m.Entity<BankConnection>().HasIndex(x => x.OwnerId).IsUnique();
        m.Entity<BankConnection>().HasAlternateKey(x => new { x.Id, x.OwnerId });
        m.Entity<BankConnection>().HasOne<Owner>().WithMany().HasForeignKey(x => x.OwnerId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankAccount>().HasAlternateKey(x => new { x.Id, x.OwnerId });
        m.Entity<BankAccount>().HasIndex(x => new { x.ConnectionId, x.ProviderAccountId }).IsUnique();
        m.Entity<BankAccount>().HasIndex(x => new { x.OwnerId, x.LedgerAccountId }).IsUnique().HasFilter("\"LedgerAccountId\" IS NOT NULL");
        m.Entity<BankAccount>().HasOne<BankConnection>().WithMany().HasForeignKey(x => new { x.ConnectionId, x.OwnerId })
            .HasPrincipalKey(x => new { x.Id, x.OwnerId }).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankAccount>().HasOne<LedgerAccount>().WithMany().HasForeignKey(x => x.LedgerAccountId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankSource>().HasIndex(x => new { x.BankAccountId, x.ProviderSourceId }).IsUnique();
        m.Entity<BankSource>().HasIndex(x => new { x.OwnerId, x.LinkedJournalEntryId, x.LinkedLedgerAccountId })
            .IsUnique().HasFilter("\"LinkedJournalEntryId\" IS NOT NULL");
        m.Entity<BankSource>().HasOne<BankAccount>().WithMany().HasForeignKey(x => new { x.BankAccountId, x.OwnerId })
            .HasPrincipalKey(x => new { x.Id, x.OwnerId }).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankSource>().HasOne<JournalEntry>().WithMany().HasForeignKey(x => x.LinkedJournalEntryId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankSource>().HasOne<LedgerAccount>().WithMany().HasForeignKey(x => x.LinkedLedgerAccountId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankSourceRevision>().HasIndex(x => new { x.SourceId, x.Version }).IsUnique();
        m.Entity<BankSourceRevision>().HasOne<BankSource>().WithMany().HasForeignKey(x => x.SourceId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankBatch>().HasIndex(x => new { x.ConnectionId, x.OperationId }).IsUnique();
        m.Entity<BankBatch>().HasOne<BankConnection>().WithMany().HasForeignKey(x => x.ConnectionId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankEvent>().HasIndex(x => new { x.ConnectionId, x.CreatedUtc });
        m.Entity<BankEvent>().HasOne<BankConnection>().WithMany().HasForeignKey(x => x.ConnectionId).OnDelete(DeleteBehavior.Restrict);
        m.Entity<BankEvent>().HasOne<BankSource>().WithMany().HasForeignKey(x => x.SourceId).OnDelete(DeleteBehavior.Restrict);
    }
}
