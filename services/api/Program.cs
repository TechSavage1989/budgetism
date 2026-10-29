using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;
using Budgetism.Api;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddWindowsService(options => options.ServiceName = "BudgetismApi");
var databasePassword = ReadSecret("DB_PASSWORD_FILE");
var bootstrapToken = ReadSecret("BOOTSTRAP_TOKEN_FILE");
var connection = builder.Configuration.GetConnectionString("Finance");
if (string.IsNullOrWhiteSpace(connection))
{
    if (string.IsNullOrWhiteSpace(databasePassword))
        throw new InvalidOperationException("Configure DB_PASSWORD_FILE or ConnectionStrings__Finance.");
    var csb = new NpgsqlConnectionStringBuilder
    {
        Host = Environment.GetEnvironmentVariable("DB_HOST") ?? "db",
        Port = int.TryParse(Environment.GetEnvironmentVariable("DB_PORT"), out var dbPort) ? dbPort : 5432,
        Database = Environment.GetEnvironmentVariable("DB_NAME") ?? "budgetism",
        Username = Environment.GetEnvironmentVariable("DB_USER") ?? "finance_app",
        Password = databasePassword,
        Pooling = true
    };
    connection = csb.ConnectionString;
}

builder.Services.AddDbContext<FinanceDb>(options => options.UseNpgsql(connection));
builder.Services.Configure<PasswordHasherOptions>(options =>
{
    options.CompatibilityMode = PasswordHasherCompatibilityMode.IdentityV3;
    options.IterationCount = 600_000;
});
builder.Services.AddScoped<IPasswordHasher<Owner>, PasswordHasher<Owner>>();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("auth", rule =>
    {
        rule.PermitLimit = 8;
        rule.Window = TimeSpan.FromMinutes(5);
        rule.QueueLimit = 0;
        rule.AutoReplenishment = true;
    });
});

var app = builder.Build();
app.UseRouting();
app.UseRateLimiter();

// A very small bearer-token middleware. Token hashes, not raw bearer tokens, are stored.
// A session can be revoked by deletion. No client registration is implied yet.
app.Use(async (ctx, next) =>
{
    var path = ctx.Request.Path;
    if (!path.StartsWithSegments("/api") ||
        path == "/api/version" || path == "/api/setup/status" ||
        path == "/api/setup/owner" || path == "/api/auth/login")
    {
        await next();
        return;
    }

    var header = ctx.Request.Headers.Authorization.ToString();
    if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        ctx.Response.StatusCode = 401;
        await ctx.Response.WriteAsJsonAsync(new { error = "Authentication required." });
        return;
    }
    var token = header[7..].Trim();
    if (token.Length < 32 || token.Length > 256)
    {
        ctx.Response.StatusCode = 401;
        return;
    }
    var tokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    var db = ctx.RequestServices.GetRequiredService<FinanceDb>();
    var session = await db.Sessions.AsNoTracking().FirstOrDefaultAsync(
        s => s.TokenHash == tokenHash && s.ExpiresUtc > DateTimeOffset.UtcNow);
    if (session is null)
    {
        ctx.Response.StatusCode = 401;
        await ctx.Response.WriteAsJsonAsync(new { error = "Session expired or invalid." });
        return;
    }
    ctx.Items["ownerId"] = session.OwnerId;
    ctx.Items["sessionId"] = session.Id;
    await next();
});

app.MapGet("/health", () => Results.Ok(new { status = "ok", version = "0.1.0-dev.1" }));
app.MapGet("/api/version", () => Results.Ok(new { version = "0.1.0-dev.1", apiMajor = 1 }));
app.MapGet("/api/setup/status", async (FinanceDb db) =>
    Results.Ok(new { initialized = await db.Owners.AnyAsync() }));

app.MapPost("/api/setup/owner", async Task<IResult> (BootstrapRequest input, FinanceDb db,
    IPasswordHasher<Owner> hasher) =>
{
    if (string.IsNullOrWhiteSpace(bootstrapToken))
        return Results.Problem("Owner bootstrap is disabled until BOOTSTRAP_TOKEN_FILE is configured.", statusCode: 503);
    if (input.BootstrapToken is null || !SecretEquals(input.BootstrapToken, bootstrapToken))
        return Results.Unauthorized();
    var username = input.Username?.Trim() ?? "";
    if (username.Length is < 3 or > 60 || input.Password is null ||
        input.Password.Length < 14 || input.Password.Length > 512)
        return Results.BadRequest(new { error = "Username must be 3-60 characters; password at least 14 characters." });

    await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
    if (await db.Owners.AnyAsync()) return Results.Conflict(new { error = "Owner already initialized." });
    var owner = new Owner { Username = username };
    owner.PasswordHash = hasher.HashPassword(owner, input.Password);
    db.Owners.Add(owner);
    var defaults = new[]
    {
        new LedgerAccount { OwnerId = owner.Id, Name = "Opening balances", LedgerKind = "Equity", Type = "opening_equity", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Groceries", LedgerKind = "Expense", Type = "expense_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Housing", LedgerKind = "Expense", Type = "expense_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Utilities", LedgerKind = "Expense", Type = "expense_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Transportation", LedgerKind = "Expense", Type = "expense_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Dining", LedgerKind = "Expense", Type = "expense_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Other spending", LedgerKind = "Expense", Type = "expense_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Paycheck", LedgerKind = "Income", Type = "income_category", IsSystem = true },
        new LedgerAccount { OwnerId = owner.Id, Name = "Other income", LedgerKind = "Income", Type = "income_category", IsSystem = true }
    };
    db.LedgerAccounts.AddRange(defaults);
    await db.SaveChangesAsync();
    await tx.CommitAsync();
    return Results.Created("/api/setup/status", new { initialized = true });
}).RequireRateLimiting("auth");

app.MapPost("/api/auth/login", async Task<IResult> (LoginRequest input, FinanceDb db,
    IPasswordHasher<Owner> hasher) =>
{
    if (string.IsNullOrWhiteSpace(input.Username) || input.Password is null)
        return Results.Unauthorized();
    var owner = await db.Owners.FirstOrDefaultAsync(x => x.Username == input.Username);
    if (owner is null || hasher.VerifyHashedPassword(owner, owner.PasswordHash, input.Password)
            == PasswordVerificationResult.Failed)
        return Results.Unauthorized();
    var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
    var session = new Session
    {
        OwnerId = owner.Id,
        TokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))),
        ExpiresUtc = DateTimeOffset.UtcNow.AddHours(12)
    };
    db.Sessions.Add(session);
    await db.SaveChangesAsync();
    return Results.Ok(new { token, expiresUtc = session.ExpiresUtc, username = owner.Username });
}).RequireRateLimiting("auth");

app.MapPost("/api/auth/logout", async (HttpContext http, FinanceDb db) =>
{
    var sessionId = (Guid)http.Items["sessionId"]!;
    var session = await db.Sessions.FindAsync(sessionId);
    if (session is not null) { db.Sessions.Remove(session); await db.SaveChangesAsync(); }
    return Results.NoContent();
});

app.MapGet("/api/me", async (HttpContext http, FinanceDb db) =>
{
    var id = OwnerId(http);
    var owner = await db.Owners.AsNoTracking().FirstAsync(x => x.Id == id);
    return Results.Ok(new { owner.Id, owner.Username });
});

app.MapGet("/api/accounts", async (HttpContext http, FinanceDb db) =>
    Results.Ok(await LoadAccounts(db, OwnerId(http))));

app.MapGet("/api/categories", async (HttpContext http, FinanceDb db) =>
{
    var owner = OwnerId(http);
    var categories = await db.LedgerAccounts.AsNoTracking()
        .Where(x => x.OwnerId == owner && (x.LedgerKind == "Income" || x.LedgerKind == "Expense"))
        .OrderBy(x => x.LedgerKind).ThenBy(x => x.Name)
        .Select(x => new CategoryResponse(x.Id, x.Name, x.LedgerKind, x.Currency)).ToListAsync();
    return Results.Ok(categories);
});

app.MapPost("/api/accounts", async Task<IResult> (HttpContext http, FinanceDb db, CreateAccountRequest input) =>
{
    var owner = OwnerId(http);
    if (input.OperationId == Guid.Empty) return Results.BadRequest(new { error = "Operation ID required." });
    if (input.Name is null || input.Name.Trim().Length is < 1 or > 100) return Results.BadRequest(new { error = "Name must be 1-100 characters." });
    var kinds = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["checking"] = "Asset", ["savings"] = "Asset", ["cash"] = "Asset",
        ["asset"] = "Asset", ["credit_card"] = "Liability", ["loan"] = "Liability",
        ["liability"] = "Liability"
    };
    if (input.Type is null || !kinds.TryGetValue(input.Type, out var ledgerKind) || input.Currency != "USD" ||
        input.OpeningBalanceMinor is > 100_000_000_000_000L or < -100_000_000_000_000L)
        return Results.BadRequest(new { error = "Unsupported account type, currency, or opening amount." });

    const string operationType = "create_account";
    var requestHash = Convert.ToHexString(SHA256.HashData(
        Encoding.UTF8.GetBytes(JsonSerializer.Serialize(input, new JsonSerializerOptions(JsonSerializerDefaults.Web)))));
    await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);
    await LockOwnerForMutation(db, owner);
    var old = await db.OperationRecords.AsNoTracking().FirstOrDefaultAsync(
        x => x.OwnerId == owner && x.OperationId == input.OperationId);
    if (old is not null)
        return old.RequestHash == requestHash && old.OperationType == operationType
            ? Results.Content(old.ResponseJson, "application/json")
            : Results.Conflict(new { error = "Operation ID already used for different content." });

    var account = new LedgerAccount { OwnerId = owner, Name = input.Name.Trim(),
        Type = input.Type, LedgerKind = ledgerKind, Currency = input.Currency };
    db.LedgerAccounts.Add(account);
    if (input.OpeningBalanceMinor != 0)
    {
        var equity = await db.LedgerAccounts.SingleAsync(x =>
            x.OwnerId == owner && x.Type == "opening_equity");
        var opening = LedgerRules.CreateOpening(owner, input.OperationId,
            DateOnly.FromDateTime(DateTime.UtcNow), account.Id, equity.Id,
            input.OpeningBalanceMinor, input.Currency);
        db.JournalEntries.Add(opening);
        AddChange(db, owner, "transaction", opening.Id, 1, ToTransaction(opening));
    }
    var response = new AccountResponse(account.Id, account.Name, account.Type,
        account.Currency, input.OpeningBalanceMinor, false, account.CreatedUtc);
    AddChange(db, owner, "account", account.Id, 1, response);
    db.OperationRecords.Add(new OperationRecord { OwnerId = owner, OperationId = input.OperationId,
        ResponseJson = JsonSerializer.Serialize(response, new JsonSerializerOptions(JsonSerializerDefaults.Web)),
        OperationType = operationType, RequestHash = requestHash });
    await db.SaveChangesAsync();
    await tx.CommitAsync();
    return Results.Created($"/api/accounts/{account.Id}", response);
});

app.MapGet("/api/transactions", async (HttpContext http, FinanceDb db, int? limit) =>
{
    var owner = OwnerId(http);
    var max = Math.Clamp(limit ?? 200, 1, 500);
    var records = await db.JournalEntries.AsNoTracking().Where(x => x.OwnerId == owner)
        .OrderByDescending(x => x.EffectiveDate).ThenByDescending(x => x.CreatedUtc)
        .Take(max).ToListAsync();
    return Results.Ok(records.Select(ToTransaction).ToList());
});

app.MapPost("/api/transactions", async Task<IResult> (HttpContext http, FinanceDb db,
    CreateTransactionRequest input) =>
{
    var owner = OwnerId(http);
    if (input.OperationId == Guid.Empty || input.AccountId == Guid.Empty ||
        input.CounterpartyAccountId == Guid.Empty || input.AccountId == input.CounterpartyAccountId)
        return Results.BadRequest(new { error = "Valid, distinct account and operation IDs are required." });
    if (input.Kind is not ("expense" or "income" or "transfer") ||
        input.AmountMinor is <= 0 or > 100_000_000_000_000L || input.Currency != "USD" ||
        input.Payee is null || input.Payee.Trim().Length > 150 || (input.Notes?.Length ?? 0) > 500 ||
        input.EffectiveDate < new DateOnly(1900, 1, 1) ||
        input.EffectiveDate > DateOnly.FromDateTime(DateTime.UtcNow.AddYears(20)))
        return Results.BadRequest(new { error = "Invalid transaction values." });

    const string operationType = "create_transaction";
    var requestHash = Convert.ToHexString(SHA256.HashData(
        Encoding.UTF8.GetBytes(JsonSerializer.Serialize(input, new JsonSerializerOptions(JsonSerializerDefaults.Web)))));
    await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);
    await LockOwnerForMutation(db, owner);
    var old = await db.OperationRecords.AsNoTracking().FirstOrDefaultAsync(
        x => x.OwnerId == owner && x.OperationId == input.OperationId);
    if (old is not null)
        return old.RequestHash == requestHash && old.OperationType == operationType
            ? Results.Content(old.ResponseJson, "application/json")
            : Results.Conflict(new { error = "Operation ID already used for different content." });

    var accounts = await db.LedgerAccounts.Where(x => x.OwnerId == owner &&
        (x.Id == input.AccountId || x.Id == input.CounterpartyAccountId)).ToListAsync();
    var primary = accounts.SingleOrDefault(x => x.Id == input.AccountId);
    var other = accounts.SingleOrDefault(x => x.Id == input.CounterpartyAccountId);
    if (primary is null || other is null || primary.Archived || other.Archived ||
        primary.IsSystem || primary.LedgerKind is not ("Asset" or "Liability") ||
        primary.Currency != input.Currency || other.Currency != input.Currency)
        return Results.BadRequest(new { error = "Account not found or account/currency not supported." });
    if ((input.Kind == "transfer" && (other.IsSystem || other.LedgerKind is not ("Asset" or "Liability"))) ||
        (input.Kind == "expense" && other.LedgerKind != "Expense") ||
        (input.Kind == "income" && other.LedgerKind != "Income"))
        return Results.BadRequest(new { error = "Counterparty category/account is not valid for this transaction type." });

    var entry = LedgerRules.Create(owner, input.OperationId, input.EffectiveDate,
        input.Kind, primary.Id, other.Id, input.AmountMinor,
        input.Currency, input.Payee.Trim(), (input.Notes ?? "").Trim());
    db.JournalEntries.Add(entry);
    var response = ToTransaction(entry);
    AddChange(db, owner, "transaction", entry.Id, 1, response);
    db.OperationRecords.Add(new OperationRecord { OwnerId = owner, OperationId = input.OperationId,
        ResponseJson = JsonSerializer.Serialize(response, new JsonSerializerOptions(JsonSerializerDefaults.Web)),
        OperationType = operationType, RequestHash = requestHash });
    await db.SaveChangesAsync();
    await tx.CommitAsync();
    return Results.Created($"/api/transactions/{entry.Id}", response);
});

app.MapGet("/api/sync/snapshot", async (HttpContext http, FinanceDb db) =>
{
    var owner = OwnerId(http);
    await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead);
    var cursor = await db.ChangeRecords.Where(x => x.OwnerId == owner)
        .MaxAsync(x => (long?)x.Sequence) ?? 0;
    var accounts = await LoadAccounts(db, owner);
    var categories = await db.LedgerAccounts.AsNoTracking()
        .Where(x => x.OwnerId == owner && (x.LedgerKind == "Expense" || x.LedgerKind == "Income"))
        .OrderBy(x => x.Name).Select(x => new CategoryResponse(x.Id, x.Name, x.LedgerKind, x.Currency)).ToListAsync();
    var transactions = (await db.JournalEntries.AsNoTracking().Where(x => x.OwnerId == owner)
        .OrderBy(x => x.EffectiveDate).ToListAsync()).Select(ToTransaction).ToList();
    await tx.CommitAsync();
    return Results.Ok(new { cursor, accounts, categories, transactions });
});

app.MapGet("/api/sync/changes", async Task<IResult> (HttpContext http, FinanceDb db, long? after, int? limit) =>
{
    var owner = OwnerId(http);
    if (after.GetValueOrDefault() < 0) return Results.BadRequest(new { error = "Cursor must not be negative." });
    var count = Math.Clamp(limit ?? 200, 1, 500);
    var changes = await db.ChangeRecords.AsNoTracking().Where(x =>
            x.OwnerId == owner && x.Sequence > (after ?? 0))
        .OrderBy(x => x.Sequence).Take(count)
        .Select(x => new SyncChange(x.Sequence, x.EntityType, x.EntityId,
            x.Version, x.PayloadJson, x.CreatedUtc)).ToListAsync();
    return Results.Ok(new { changes,
        nextCursor = changes.Count == 0 ? after.GetValueOrDefault() : changes[^1].Sequence,
        hasMore = changes.Count == count });
});

// Dev baseline only: EnsureCreated is not a migration system. No production data until
// a verified forward-only schema migration and restore workflow exist.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<FinanceDb>();
    await db.Database.EnsureCreatedAsync();
}
await app.RunAsync();

static Guid OwnerId(HttpContext http) => (Guid)http.Items["ownerId"]!;

// PostgreSQL row locks serialize writes within the owner workspace. This matters for
// commit-ordered change-log cursors: a later sequence may not commit before an earlier
// one, or incremental clients could skip an eventually committed change.
static async Task LockOwnerForMutation(FinanceDb db, Guid owner)
{
    var updatedRows = await db.Database.ExecuteSqlInterpolatedAsync(
        $"SELECT 1 FROM \"Owners\" WHERE \"Id\" = {owner} FOR UPDATE");
    _ = updatedRows; // PostgreSQL reports -1 for a SELECT executed as a nonquery.
}

static string ReadSecret(string name)
{
    var path = Environment.GetEnvironmentVariable(name);
    if (string.IsNullOrWhiteSpace(path)) return "";
    if (!File.Exists(path)) throw new FileNotFoundException($"Required secret file for {name} not found.", path);
    return File.ReadAllText(path).Trim();
}

static bool SecretEquals(string a, string b) =>
    CryptographicOperations.FixedTimeEquals(
        SHA256.HashData(Encoding.UTF8.GetBytes(a)),
        SHA256.HashData(Encoding.UTF8.GetBytes(b)));

static TransactionResponse ToTransaction(JournalEntry e) =>
    new(e.Id, e.OperationId, e.Kind, e.PrimaryAccountId, e.CounterpartyAccountId,
        e.AmountMinor, e.Currency, e.EffectiveDate, e.Payee, e.Notes,
        e.Version, e.CreatedUtc);

static void AddChange(FinanceDb db, Guid owner, string type, Guid id, int version, object payload)
    => db.ChangeRecords.Add(new ChangeRecord
    {
        OwnerId = owner, EntityType = type, EntityId = id, Version = version,
        PayloadJson = JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web))
    });

static async Task<List<AccountResponse>> LoadAccounts(FinanceDb db, Guid owner)
{
    var balances = await db.LedgerPostings.AsNoTracking()
        .Where(x => x.OwnerId == owner).GroupBy(x => x.LedgerAccountId)
        .Select(x => new { AccountId = x.Key, Balance = x.Sum(y => y.AmountMinor) })
        .ToDictionaryAsync(x => x.AccountId, x => x.Balance);
    var accounts = await db.LedgerAccounts.AsNoTracking()
        .Where(x => x.OwnerId == owner && !x.IsSystem &&
            (x.LedgerKind == "Asset" || x.LedgerKind == "Liability"))
        .OrderBy(x => x.Name).ToListAsync();
    return accounts.Select(x => new AccountResponse(x.Id, x.Name, x.Type, x.Currency,
        balances.GetValueOrDefault(x.Id), x.Archived, x.CreatedUtc)).ToList();
}
