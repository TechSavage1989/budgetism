using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public sealed record PlanningCommand(Guid OperationId, int ExpectedVersion, long ExpectedLedgerCursor,
    string Action, JsonElement Data, bool Confirmed);
public sealed record PlanningResult(int Version, Guid? TransactionId);

public sealed class ServerPlanning(FinanceDb db, Func<byte[]>? keyFactory = null)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private static void Require(bool valid, string code = "invalid_planning_input", int status = 400)
    { if (!valid) throw new BankRuleException(code, status); }
    private static string Text(JsonObject d, string key, int max = 100, bool optional = false)
    {
        if (optional && d[key] is null) return "";
        Require(d[key] is JsonValue v && v.TryGetValue<string>(out _));
        var s = d[key]!.GetValue<string>().Trim(); Require((optional || s.Length > 0) && s.Length <= max); return s;
    }
    private static long Number(JsonObject d, string key, long min = 0, long max = 100_000_000_000_000)
    {
        long n;
        if (d[key] is JsonValue v && v.TryGetValue<long>(out var value)) n = value;
        else if (d[key] is JsonValue i && i.TryGetValue<int>(out var small)) n = small;
        else throw new BankRuleException("invalid_planning_input", 400);
        Require(n >= min && n <= max); return n;
    }
    private static Guid Id(JsonObject d, string key) { Require(Guid.TryParse(Text(d, key), out var id) && id != Guid.Empty); return id; }
    private static DateOnly Day(string text) { Require(DateOnly.TryParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day) && day.Year >= 1900); return day; }
    private static string Month(JsonObject d) { var m = Text(d, "month", 7); Require(m.Length == 7); Day(m + "-01"); return m; }
    private static string Hash(string s) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(s)));
    private static string Canonical(JsonNode? node) => node switch {
        JsonObject o => "{" + string.Join(',', o.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => JsonSerializer.Serialize(p.Key) + ":" + Canonical(p.Value))) + "}",
        JsonArray a => "[" + string.Join(',', a.Select(Canonical)) + "]", _ => node?.ToJsonString() ?? "null" };
    private static JsonObject Root(string? json)
    {
        var root = JsonNode.Parse(json ?? "{}")!.AsObject();
        foreach (var key in new[] { "budgets", "schedules", "occurrences", "labels", "views", "annotations" }) root[key] ??= new JsonArray();
        return root;
    }
    public static DateOnly At(DateOnly start, string frequency, int index)
    {
        Require(index is >= 0 and <= 500000 && new[] { "weekly", "fortnightly", "monthly", "yearly" }.Contains(frequency));
        if (frequency is "weekly" or "fortnightly") return start.AddDays(checked(index * (frequency == "weekly" ? 7 : 14)));
        var month = checked(start.Year * 12 + start.Month - 1 + index * (frequency == "yearly" ? 12 : 1));
        var y = month / 12; var m = month % 12 + 1; Require(y <= 9999);
        return new(y, m, Math.Min(start.Day, DateTime.DaysInMonth(y, m)));
    }
    private async Task<long> Cursor(Guid owner, CancellationToken token) =>
        await db.ChangeRecords.Where(x => x.OwnerId == owner).MaxAsync(x => (long?)x.Sequence, token) ?? 0;

    public async Task<object> StateAsync(Guid owner, CancellationToken token)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead, token);
        var saved = await db.PlanningWorkspaces.AsNoTracking().SingleOrDefaultAsync(x => x.OwnerId == owner, token);
        var key = (keyFactory ?? PlanningProtection.ReadKey)();
        var root = Root(saved is null ? null : PlanningProtection.Open(saved.PayloadJson, key, owner, "workspace:" + saved.Version));
        var accounts = await db.LedgerAccounts.AsNoTracking().Where(x => x.OwnerId == owner).OrderBy(x => x.Id).Take(2001).ToListAsync(token);
        Require(accounts.Count <= 2000, "planning_inventory_limit");
        var journals = await db.JournalEntries.AsNoTracking().Where(x => x.OwnerId == owner).Include(x => x.Postings)
            .OrderBy(x => x.EffectiveDate).ThenBy(x => x.Id).Take(10001).ToListAsync(token);
        Require(journals.Count <= 10000, "planning_inventory_limit");
        var financial = accounts.Where(a => !a.IsSystem && a.LedgerKind is "Asset" or "Liability").ToList();
        var ids = financial.Select(a => a.Id).ToHashSet();
        var categoryIds = accounts.Where(a => a.LedgerKind is "Expense" or "Income").Select(a => a.Id).ToHashSet();
        var occurrences = root["occurrences"]!.AsArray().Select(x => x!.AsObject()).ToList();
        var entries = journals.Select(e => {
            var linked = occurrences.SingleOrDefault(o => o["transactionId"]?.GetValue<string>() == e.Id.ToString());
            return new { id = e.Id, e.OperationId, e.Kind, accountId = e.PrimaryAccountId, counterpartyAccountId = e.CounterpartyAccountId,
                e.AmountMinor, e.Currency, effectiveDate = e.EffectiveDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), e.Payee, e.Notes, e.Version,
                voided = false, scheduleId = linked?["scheduleId"]?.GetValue<string>(), occurrenceIndex = linked?["index"]?.GetValue<int>(),
                postings = e.Postings.Select(p => new { ledgerId = categoryIds.Contains(p.LedgerAccountId) ? "category:" + p.LedgerAccountId : p.LedgerAccountId.ToString(),
                    amountMinor = Dashboard.Exact(p.AmountMinor) }).ToList() };
        }).ToList();
        var cursor = await Cursor(owner, token);
        await tx.CommitAsync(token);
        return new { version = saved?.Version ?? 0, ledgerCursor = cursor,
            snapshot = new { schema = 8, cursor = saved?.Version ?? 0,
                accounts = financial.Select(a => new { id = a.Id, a.Name, a.Type, a.Currency, a.Archived, openingBalanceMinor = 0 }),
                categories = accounts.Where(a => categoryIds.Contains(a.Id)).Select(a => new { id = a.Id, a.Name, kind = a.LedgerKind, a.Currency, a.Archived }),
                transactions = entries, datedOpenings = true, budgets = root["budgets"], schedules = root["schedules"], occurrences = root["occurrences"],
                labels = root["labels"], savedViews = root["views"], annotations = root["annotations"],
                statements = Array.Empty<object>(), audit = occurrences.Where(o => o["matched"]?.GetValue<bool>() == true).Select(o => new { action = "schedule-match", objectId = o["id"]!.GetValue<string>() }) } };
    }

    public async Task<PlanningResult> ApplyAsync(Guid owner, PlanningCommand command, CancellationToken token)
    {
        Require(command.Confirmed && command.OperationId != Guid.Empty && command.Data.ValueKind == JsonValueKind.Object && command.Data.GetRawText().Length <= 262144);
        var data = JsonNode.Parse(command.Data.GetRawText())!.AsObject();
        var fields = command.Action switch {
            "budget" or "budget-remove" => "month categoryId expectedVersion amountMinor rollover confirmSchemaUpgrade",
            "budget-copy" => "month expectedRevision replaceExisting confirmSchemaUpgrade",
            "schedule" => "id expectedVersion name kind accountId counterpartyAccountId currency amountMinor payee notes startDate endDate frequency confirmScheduleUpgrade",
            "schedule-state" => "id expectedVersion paused",
            "schedule-confirm" => "scheduleId index expectedScheduleVersion expectedOccurrenceVersion amountMinor effectiveDate notes",
            "schedule-postpone" => "scheduleId index expectedScheduleVersion expectedOccurrenceVersion dueDate",
            "schedule-skip" => "scheduleId index expectedScheduleVersion expectedOccurrenceVersion",
            "schedule-match" => "scheduleId index expectedScheduleVersion expectedOccurrenceVersion transactionId expectedTransactionVersion expectedRevision confirmMatch",
            "label" => "id expectedVersion name", "view" => "id expectedVersion name query accountId kind labelId from through",
            "view-remove" => "id expectedVersion", "annotate" => "transactionId expectedRevision labelIds",
            "category" => "id expectedRevision name kind archived",
            _ => throw new BankRuleException("unsupported_planning_action", 400) };
        var allowed = fields.Split(' ').ToHashSet(StringComparer.Ordinal);
        Require(data.All(p => allowed.Contains(p.Key)));
        var hash = Hash(Canonical(JsonSerializer.SerializeToNode(command, Json)));
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, token);
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT 1 FROM \"Owners\" WHERE \"Id\"={owner} FOR UPDATE", token);
        Require(await db.Owners.AnyAsync(x => x.Id == owner, token), "owner_missing", 403);
        var old = await db.OperationRecords.AsNoTracking().SingleOrDefaultAsync(x => x.OwnerId == owner && x.OperationId == command.OperationId, token);
        if (old is not null) { Require(old.OperationType == "planning-command" && old.RequestHash == hash, "operation_reused", 409); return JsonSerializer.Deserialize<PlanningResult>(old.ResponseJson, Json)!; }
        var workspace = await db.PlanningWorkspaces.SingleOrDefaultAsync(x => x.OwnerId == owner, token);
        Require(command.ExpectedVersion == (workspace?.Version ?? 0) && command.ExpectedLedgerCursor == await Cursor(owner, token), "planning_changed", 409);
        var key = (keyFactory ?? PlanningProtection.ReadKey)();
        var root = Root(workspace is null ? null : PlanningProtection.Open(workspace.PayloadJson, key, owner, "workspace:" + workspace.Version)); var action = command.Action; var objectId = ""; Guid? transactionId = null;
        var accounts = await db.LedgerAccounts.AsNoTracking().Where(x => x.OwnerId == owner).ToListAsync(token);
        LedgerAccount Account(Guid id, string? kind = null, bool allowArchived = false) {
            var a = accounts.SingleOrDefault(a => a.Id == id);
            Require(a is not null && (allowArchived || !a.Archived) && a.Currency == "USD" && (kind == null ? !a.IsSystem && a.LedgerKind is "Asset" or "Liability" : a.LedgerKind == kind), "planning_account_invalid"); return a!;
        }
        if (action is "budget" or "budget-remove" or "budget-copy")
        {
            var month = Month(data); var budgets = root["budgets"]!.AsArray();
            void SaveBudget(JsonObject input, bool remove) {
                var category = Id(input, "categoryId"); Account(category, "Expense", remove);
                var before = budgets.Select(x => x!.AsObject()).SingleOrDefault(x => x["month"]!.GetValue<string>() == month && x["categoryId"]!.GetValue<string>() == category.ToString());
                Require(Number(input, "expectedVersion", max: int.MaxValue) == (before?["version"]?.GetValue<int>() ?? 0), "planning_changed", 409);
                var rollover = remove ? "none" : Text(input, "rollover"); Require(new[] { "none", "positive", "all" }.Contains(rollover));
                var after = new JsonObject { ["id"] = before?["id"]?.GetValue<string>() ?? Guid.NewGuid().ToString(), ["month"] = month, ["categoryId"] = category.ToString(),
                    ["amountMinor"] = remove ? 0 : Number(input, "amountMinor"), ["rollover"] = rollover, ["removed"] = remove, ["version"] = (before?["version"]?.GetValue<int>() ?? 0) + 1 };
                if (before is not null) budgets.Remove(before); budgets.Add(after); objectId = after["id"]!.GetValue<string>();
            }
            if (action == "budget-copy") {
                Require(Number(data, "expectedRevision", max: int.MaxValue) == command.ExpectedVersion, "planning_changed", 409);
                var previous = Day(month + "-01").AddMonths(-1).ToString("yyyy-MM", CultureInfo.InvariantCulture);
                foreach (var item in budgets.Select(x => x!.AsObject()).Where(x => x["month"]!.GetValue<string>() == previous && x["removed"]?.GetValue<bool>() != true).ToList()) {
                    var category = item["categoryId"]!.GetValue<string>(); var target = budgets.Select(x => x!.AsObject()).SingleOrDefault(x => x["month"]!.GetValue<string>() == month && x["categoryId"]!.GetValue<string>() == category);
                    if (target is not null && data["replaceExisting"]?.GetValue<bool>() != true) continue;
                    var copy = item.DeepClone().AsObject(); copy["expectedVersion"] = target?["version"]?.GetValue<int>() ?? 0; SaveBudget(copy, false);
                }
                objectId = month;
            } else SaveBudget(data, action == "budget-remove");
            Require(budgets.Count <= 5000, "planning_limit");
        }
        else if (action is "schedule" or "schedule-state")
        {
            var schedules = root["schedules"]!.AsArray(); var id = data["id"] is null ? Guid.NewGuid() : Id(data, "id");
            var before = schedules.Select(x => x!.AsObject()).SingleOrDefault(x => x["id"]!.GetValue<string>() == id.ToString());
            Require(Number(data, "expectedVersion", max: int.MaxValue) == (before?["version"]?.GetValue<int>() ?? 0), "planning_changed", 409);
            JsonObject after;
            if (action == "schedule-state") { Require(before is not null && data["paused"] is JsonValue); after = before!.DeepClone().AsObject(); after["paused"] = data["paused"]!.GetValue<bool>(); }
            else {
                var kind = Text(data, "kind"); Require(new[] { "expense", "income", "transfer" }.Contains(kind));
                var account = Id(data, "accountId"); var other = Id(data, "counterpartyAccountId"); Require(account != other); Account(account); Account(other, kind == "transfer" ? null : kind == "expense" ? "Expense" : "Income");
                Require(Text(data, "currency") == "USD"); var start = Day(Text(data, "startDate")); var frequency = Text(data, "frequency"); At(start, frequency, 0);
                var end = data["endDate"] is null ? null : Text(data, "endDate"); Require(end is null || Day(end) >= start);
                if (before is not null) Require(before["startDate"]!.GetValue<string>() == start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) && before["frequency"]!.GetValue<string>() == frequency && before["endDate"]?.GetValue<string>() == end, "recurrence_locked");
                after = new JsonObject { ["id"] = id.ToString(), ["name"] = Text(data, "name"), ["kind"] = kind, ["accountId"] = account.ToString(), ["counterpartyAccountId"] = other.ToString(),
                    ["currency"] = "USD", ["amountMinor"] = Number(data, "amountMinor", 1), ["payee"] = Text(data, "payee", 150, true), ["notes"] = Text(data, "notes", 500, true),
                    ["startDate"] = start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), ["frequency"] = frequency, ["endDate"] = end, ["paused"] = before?["paused"]?.GetValue<bool>() ?? false };
            }
            after["version"] = (before?["version"]?.GetValue<int>() ?? 0) + 1;
            if (before is not null) schedules.Remove(before); schedules.Add(after); Require(schedules.Count <= 500, "planning_limit"); objectId = id.ToString();
        }
        else if (action is "schedule-confirm" or "schedule-match" or "schedule-postpone" or "schedule-skip")
        {
            var id = Id(data, "scheduleId").ToString(); var index = (int)Number(data, "index", 0, 500000);
            var schedule = root["schedules"]!.AsArray().Select(x => x!.AsObject()).SingleOrDefault(x => x["id"]!.GetValue<string>() == id);
            Require(schedule is not null && schedule["paused"]?.GetValue<bool>() != true, "schedule_unavailable");
            Require(Number(data, "expectedScheduleVersion", max: int.MaxValue) == schedule!["version"]!.GetValue<int>(), "planning_changed", 409);
            var original = At(Day(Text(schedule, "startDate")), Text(schedule, "frequency"), index);
            Require(schedule["endDate"] is null || original <= Day(Text(schedule, "endDate")));
            var occurrences = root["occurrences"]!.AsArray(); var before = occurrences.Select(x => x!.AsObject()).SingleOrDefault(x => x["scheduleId"]!.GetValue<string>() == id && x["index"]!.GetValue<int>() == index);
            Require(before is null || before["status"]!.GetValue<string>() == "postponed", "occurrence_settled", 409);
            Require(Number(data, "expectedOccurrenceVersion", max: int.MaxValue) == (before?["version"]?.GetValue<int>() ?? 0), "planning_changed", 409);
            var due = before?["dueDate"]?.GetValue<string>() ?? original.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var after = new JsonObject { ["id"] = before?["id"]?.GetValue<string>() ?? Guid.NewGuid().ToString(), ["scheduleId"] = id, ["index"] = index,
                ["originalDueDate"] = original.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), ["dueDate"] = due, ["version"] = (before?["version"]?.GetValue<int>() ?? 0) + 1,
                ["scheduleVersion"] = schedule["version"]!.GetValue<int>(), ["plannedAmountMinor"] = schedule["amountMinor"]!.GetValue<long>(), ["transactionId"] = null,
                ["resolvedAtUtc"] = action == "schedule-postpone" ? null : DateTimeOffset.UtcNow.ToString("o") };
            if (action == "schedule-postpone") { var day = Day(Text(data, "dueDate")); Require(day > Day(due)); after["dueDate"] = day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture); after["status"] = "postponed"; }
            else if (action == "schedule-skip") after["status"] = "skipped";
            else {
                var account = Id(schedule, "accountId"); var other = Id(schedule, "counterpartyAccountId"); var kind = Text(schedule, "kind");
                Account(account); Account(other, kind == "transfer" ? null : kind == "expense" ? "Expense" : "Income");
                JournalEntry entry;
                if (action == "schedule-confirm") {
                    var date = Day(Text(data, "effectiveDate")); Require(date <= DateOnly.FromDateTime(DateTime.UtcNow.AddYears(20)));
                    entry = LedgerRules.Create(owner, command.OperationId, date, kind, account, other, Number(data, "amountMinor", 1), "USD", Text(schedule, "payee", 150, true), Text(data, "notes", 500, true));
                    db.JournalEntries.Add(entry);
                    var response = new TransactionResponse(entry.Id, entry.OperationId, entry.Kind, entry.PrimaryAccountId, entry.CounterpartyAccountId, entry.AmountMinor, entry.Currency, entry.EffectiveDate, entry.Payee, entry.Notes, entry.Version, entry.CreatedUtc);
                    db.ChangeRecords.Add(new() { OwnerId = owner, EntityType = "transaction", EntityId = entry.Id, Version = 1, PayloadJson = JsonSerializer.Serialize(response, Json) });
                } else {
                    Require(data["confirmMatch"]?.GetValue<bool>() == true, "match_confirmation_required");
                    var target = Id(data, "transactionId");
                    entry = (await db.JournalEntries.AsNoTracking().SingleOrDefaultAsync(x => x.OwnerId == owner && x.Id == target, token))!;
                    Require(entry is not null && entry.Version == Number(data, "expectedTransactionVersion", 1, int.MaxValue), "planning_changed", 409);
                    Require(entry!.Kind == kind && entry.PrimaryAccountId == account && entry.AmountMinor > 0 && (kind != "transfer" || entry.CounterpartyAccountId == other) && Math.Abs(entry.EffectiveDate.DayNumber - Day(due).DayNumber) <= 90, "match_ineligible");
                    Require(!occurrences.Any(x => x?["transactionId"]?.GetValue<string>() == entry.Id.ToString()), "already_matched", 409);
                    after["matched"] = true;
                }
                transactionId = entry.Id; after["transactionId"] = entry.Id.ToString(); after["status"] = "confirmed";
            }
            if (before is not null) occurrences.Remove(before); occurrences.Add(after); Require(occurrences.Count <= 10000, "planning_limit"); objectId = after["id"]!.GetValue<string>();
        }
        else if (action == "category")
        {
            Require(Number(data, "expectedRevision", max: int.MaxValue) == command.ExpectedVersion, "planning_changed", 409);
            var id = data["id"] is null ? Guid.NewGuid() : Id(data, "id");
            var name = Text(data, "name"); var kind = Text(data, "kind"); Require(kind is "Expense" or "Income");
            var before = await db.LedgerAccounts.SingleOrDefaultAsync(x => x.OwnerId == owner && x.Id == id, token);
            Require(data["id"] is null || before is not null && before.LedgerKind == kind, "planning_account_invalid");
            Require(!accounts.Any(a => a.Id != id && a.LedgerKind == kind && string.Equals(a.Name, name, StringComparison.OrdinalIgnoreCase)), "category_name_exists");
            if (before is null) { before = new() { Id = id, OwnerId = owner, LedgerKind = kind, Type = kind == "Expense" ? "expense_category" : "income_category", IsSystem = true }; db.LedgerAccounts.Add(before); }
            before.Name = name; before.Archived = data["archived"]?.GetValue<bool>() ?? false;
            var value = new CategoryResponse(id, name, kind, "USD");
            db.ChangeRecords.Add(new() { OwnerId = owner, EntityType = "category", EntityId = id, Version = (workspace?.Version ?? 0) + 1, PayloadJson = JsonSerializer.Serialize(value, Json) });
            objectId = id.ToString();
        }
        else if (action is "label" or "view" or "view-remove" or "annotate")
        {
            if (action == "annotate") {
                var id = Id(data, "transactionId"); Require(await db.JournalEntries.AnyAsync(x => x.OwnerId == owner && x.Id == id, token), "entry_missing");
                Require(Number(data, "expectedRevision", max: int.MaxValue) == command.ExpectedVersion, "planning_changed", 409);
                Require(data["labelIds"] is JsonArray);
                var labels = data["labelIds"]!.AsArray();
                Require(labels.Count <= 20 && labels.All(x => x is JsonValue v && v.TryGetValue<string>(out _)));
                Require(labels.Select(x => x!.GetValue<string>()).Distinct().Count() == labels.Count);
                var known = root["labels"]!.AsArray().Select(x => x!["id"]!.GetValue<string>()).ToHashSet(); Require(labels.All(x => known.Contains(x!.GetValue<string>())));
                var rows = root["annotations"]!.AsArray(); var before = rows.FirstOrDefault(x => x!["transactionId"]!.GetValue<string>() == id.ToString()); if (before is not null) rows.Remove(before);
                rows.Add(new JsonObject { ["transactionId"] = id.ToString(), ["labelIds"] = labels.DeepClone() }); Require(rows.Count <= 10000, "planning_limit"); objectId = id.ToString();
            } else {
                var collection = action == "label" ? "labels" : "views"; var rows = root[collection]!.AsArray(); var id = data["id"] is null ? Guid.NewGuid() : Id(data, "id");
                var before = rows.FirstOrDefault(x => x!["id"]!.GetValue<string>() == id.ToString());
                Require(Number(data, "expectedVersion", max: int.MaxValue) == (before?["version"]?.GetValue<int>() ?? 0), "planning_changed", 409);
                if (action == "view-remove") Require(before is not null);
                JsonObject? after = null;
                if (action != "view-remove") {
                    after = new JsonObject { ["id"] = id.ToString(), ["name"] = Text(data, "name"), ["version"] = (before?["version"]?.GetValue<int>() ?? 0) + 1 };
                    if (action == "view") {
                        after["query"] = Text(data, "query", 200, true); var account = data["accountId"] is null ? null : Text(data, "accountId"); if (account is not null) Account(Guid.Parse(account), null, true); after["accountId"] = account;
                        foreach (var field in new[] { "from", "through" }) { var value = Text(data, field, 10, true); if (value != "") Day(value); after[field] = value; }
                        Require(after["from"]!.GetValue<string>() == "" || after["through"]!.GetValue<string>() == "" || string.CompareOrdinal(after["from"]!.GetValue<string>(), after["through"]!.GetValue<string>()) <= 0);
                        var kind = Text(data, "kind", 20, true); Require(new[] { "", "income", "expense", "transfer", "opening" }.Contains(kind)); after["kind"] = kind;
                        var label = Text(data, "labelId", 100, true); Require(label == "" || root["labels"]!.AsArray().Any(x => x!["id"]!.GetValue<string>() == label)); after["labelId"] = label;
                    }
                }
                if (before is not null) rows.Remove(before); if (after is not null) rows.Add(after); Require(rows.Count <= (collection == "labels" ? 100 : 50), "planning_limit"); objectId = id.ToString();
            }
        }
        else throw new BankRuleException("unsupported_planning_action", 400);
        var payload = root.ToJsonString(); Require(Encoding.UTF8.GetByteCount(payload) <= 2 * 1024 * 1024, "planning_limit");
        if (workspace is null) { workspace = new() { OwnerId = owner }; db.PlanningWorkspaces.Add(workspace); }
        workspace.Version = checked(workspace.Version + 1);
        workspace.PayloadJson = PlanningProtection.Seal(payload, key, owner, "workspace:" + workspace.Version);
        var result = new PlanningResult(workspace.Version, transactionId);
        db.PlanningEvents.Add(new() { OwnerId = owner, OperationId = command.OperationId, Action = action, ObjectId = objectId, Version = workspace.Version,
            DetailsJson = PlanningProtection.Seal(data.ToJsonString(), key, owner, $"event:{command.OperationId}:{action}:{objectId}:{workspace.Version}") });
        db.OperationRecords.Add(new() { OwnerId = owner, OperationId = command.OperationId, OperationType = "planning-command", RequestHash = hash, ResponseJson = JsonSerializer.Serialize(result, Json) });
        await db.SaveChangesAsync(token); await tx.CommitAsync(token); return result;
    }
}

public static class PlanningEndpoints
{
    public static void MapPlanning(this WebApplication app)
    {
        app.MapGet("/api/planning/state", (HttpContext ctx, FinanceDb db) => Run(ctx, db, token => new ServerPlanning(db).StateAsync((Guid)ctx.Items["ownerId"]!, token)));
        app.MapPost("/api/planning/command", (HttpContext ctx, FinanceDb db, PlanningCommand input) => Run(ctx, db, async token => (object)await new ServerPlanning(db).ApplyAsync((Guid)ctx.Items["ownerId"]!, input, token)));
    }
    private static async Task<IResult> Run(HttpContext ctx, FinanceDb db, Func<CancellationToken, Task<object>> action)
    {
        ctx.Response.Headers.CacheControl = "no-store";
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ctx.RequestAborted); timeout.CancelAfter(TimeSpan.FromSeconds(25));
        try {
            if (!await PlanningSchema.ReadyAsync(db, timeout.Token)) return Results.Json(new { error = "planning_upgrade_required" }, statusCode: 503);
            return Results.Ok(await action(timeout.Token));
        }
        catch (BankRuleException e) { return Results.Json(new { error = e.Code }, statusCode: e.Status); }
        catch (ArgumentException) { return Results.BadRequest(new { error = "invalid_planning_input" }); }
        catch (InvalidOperationException) { return Results.BadRequest(new { error = "invalid_planning_input" }); }
        catch (Exception) { return Results.Json(new { error = "planning_operation_unconfirmed" }, statusCode: 503); }
    }
}
