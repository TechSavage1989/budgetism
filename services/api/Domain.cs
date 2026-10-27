using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public sealed class Owner
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    [MaxLength(100)] public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class Session
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    [MaxLength(64)] public string TokenHash { get; set; } = "";
    public DateTimeOffset ExpiresUtc { get; set; }
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}

// Asset/liability accounts and internal equity/income/expense ledger accounts.
public sealed class LedgerAccount
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    [MaxLength(100)] public string Name { get; set; } = "";
    [MaxLength(30)] public string Type { get; set; } = "";
    [MaxLength(10)] public string LedgerKind { get; set; } = "";
    [MaxLength(3)] public string Currency { get; set; } = "USD";
    public bool IsSystem { get; set; }
    public bool Archived { get; set; }
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class JournalEntry
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid OwnerId { get; set; }
    [MaxLength(20)] public string Kind { get; set; } = "";
    public DateOnly EffectiveDate { get; set; }
    [MaxLength(150)] public string Payee { get; set; } = "";
    [MaxLength(500)] public string Notes { get; set; } = "";
    public long AmountMinor { get; set; }
    [MaxLength(3)] public string Currency { get; set; } = "USD";
    public Guid PrimaryAccountId { get; set; }
    public Guid CounterpartyAccountId { get; set; }
    public Guid OperationId { get; set; }
    public int Version { get; set; } = 1;
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
    public List<LedgerPosting> Postings { get; set; } = [];
}

public sealed class LedgerPosting
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    public Guid JournalEntryId { get; set; }
    public JournalEntry JournalEntry { get; set; } = null!;
    public Guid LedgerAccountId { get; set; }
    public Guid OwnerId { get; set; }
    // Debit is positive; credit is negative. Sum per entry must be exactly zero.
    public long AmountMinor { get; set; }
}

public sealed class OperationRecord
{
    public Guid OwnerId { get; set; }
    public Guid OperationId { get; set; }
    [MaxLength(30)] public string OperationType { get; set; } = "";
    [MaxLength(64)] public string RequestHash { get; set; } = "";
    public string ResponseJson { get; set; } = "";
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class ChangeRecord
{
    [Key] public long Sequence { get; set; }
    public Guid OwnerId { get; set; }
    [MaxLength(30)] public string EntityType { get; set; } = "";
    public Guid EntityId { get; set; }
    public int Version { get; set; }
    public string PayloadJson { get; set; } = "";
    public DateTimeOffset CreatedUtc { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class FinanceDb(DbContextOptions<FinanceDb> options) : DbContext(options)
{
    public DbSet<Owner> Owners => Set<Owner>();
    public DbSet<Session> Sessions => Set<Session>();
    public DbSet<LedgerAccount> LedgerAccounts => Set<LedgerAccount>();
    public DbSet<JournalEntry> JournalEntries => Set<JournalEntry>();
    public DbSet<LedgerPosting> LedgerPostings => Set<LedgerPosting>();
    public DbSet<OperationRecord> OperationRecords => Set<OperationRecord>();
    public DbSet<ChangeRecord> ChangeRecords => Set<ChangeRecord>();

    protected override void OnModelCreating(ModelBuilder m)
    {
        m.Entity<Owner>().HasIndex(x => x.Username).IsUnique();
        m.Entity<Session>().HasIndex(x => x.TokenHash).IsUnique();
        m.Entity<LedgerAccount>().HasIndex(x => new { x.OwnerId, x.LedgerKind });
        m.Entity<JournalEntry>().HasIndex(x => new { x.OwnerId, x.EffectiveDate });
        m.Entity<JournalEntry>().HasIndex(x => new { x.OwnerId, x.OperationId }).IsUnique();
        m.Entity<LedgerPosting>().HasIndex(x => new { x.OwnerId, x.LedgerAccountId });
        m.Entity<LedgerPosting>().HasOne<LedgerAccount>()
            .WithMany().HasForeignKey(x => x.LedgerAccountId)
            .OnDelete(DeleteBehavior.Restrict);
        m.Entity<LedgerPosting>().HasOne(x => x.JournalEntry)
            .WithMany(x => x.Postings).HasForeignKey(x => x.JournalEntryId)
            .OnDelete(DeleteBehavior.Restrict);
        m.Entity<OperationRecord>().HasKey(x => new { x.OwnerId, x.OperationId });
        m.Entity<ChangeRecord>().Property(x => x.Sequence).ValueGeneratedOnAdd();
        m.Entity<ChangeRecord>().HasIndex(x => new { x.OwnerId, x.Sequence });
    }
}
