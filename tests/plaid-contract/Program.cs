using System.Net;
using System.Text;
using System.Text.Json;
using Budgetism.Api;

void Check(bool condition, string name)
{
    if (!condition) throw new Exception("FAIL: " + name);
    Console.WriteLine("PASS: " + name);
}
JsonElement Row(string amount = "12.34", string currency = "USD", string date = "2026-10-29") =>
    JsonDocument.Parse("""
    {"account_id":"fictional-account","transaction_id":"fictional-transaction",
    "name":"Fictional cafe","pending":false,"pending_transaction_id":"fictional-pending",
    "amount":AMOUNT,"iso_currency_code":"CURRENCY","date":"DATE"}
    """.Replace("AMOUNT", amount).Replace("CURRENCY", currency).Replace("DATE", date)).RootElement.Clone();
void Reject(Action action, string name)
{
    try { action(); } catch (PlaidPreviewException) { Check(true, name); return; }
    throw new Exception("FAIL: " + name);
}
string Page(string next, bool more, bool row = false) => JsonSerializer.Serialize(new
{
    next_cursor = next, has_more = more,
    added = row ? new[] { Row() } : Array.Empty<JsonElement>(),
    modified = Array.Empty<object>(), removed = Array.Empty<object>()
});
var purchase = PlaidSandbox.Normalize("added", Row());
Check(purchase.AmountMinor == -1234 && purchase.PendingSourceId == "fictional-pending", "Exact cents, outflow sign and pending predecessor preserved");
Check(PlaidSandbox.Normalize("modified", Row("-0.29")).AmountMinor == 29, "Refund has exact positive ledger effect");
Check(PlaidSandbox.Normalize("added", Row("1e2")).AmountMinor == -10000, "Exact JSON decimal exponent handled");
Reject(() => PlaidSandbox.Normalize("added", Row("1.001")), "Fractional cents rejected");
Reject(() => PlaidSandbox.Normalize("added", Row("1e-29")), "Sub-decimal-precision nonzero amount cannot round to zero");
Reject(() => PlaidSandbox.Normalize("added", Row("1.00000000000000000000000000001")), "High-precision fraction cannot silently round to whole cents");
Reject(() => PlaidSandbox.Normalize("added", Row("1000000000000")), "Amount range enforced");
Reject(() => PlaidSandbox.Normalize("added", Row("79228162514264337593543950335")), "Decimal maximum rejected without overflow");
Reject(() => PlaidSandbox.Normalize("added", Row(currency: "EUR")), "Unsupported currency rejected");
Reject(() => PlaidSandbox.Normalize("added", Row(date: "2026-02-30")), "Invalid calendar date rejected");
Check(PlaidSandbox.Normalize("removed", JsonDocument.Parse("""{"account_id":"a","transaction_id":"t"}""").RootElement).AmountMinor is null,
    "Removal preserves identity without fabricated amount or date");

async Task<PlaidPreview> Preview(Func<HttpRequestMessage, int, Task<HttpResponseMessage>> respond)
{
    using var http = new HttpClient(new FakeHandler(respond));
    return await new PlaidSandbox(http).PreviewAsync("fictional-client", "fictional-secret", "access-sandbox-fictional", CancellationToken.None);
}
HttpResponseMessage Json(string body, HttpStatusCode code = HttpStatusCode.OK) =>
    new(code) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
var cursors = new List<string>();
var batch = await Preview(async (request, call) =>
{
    Check(request.RequestUri!.AbsoluteUri == "https://sandbox.plaid.com/transactions/sync", "Transport pinned to Sandbox origin and path");
    var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
    cursors.Add(body.RootElement.GetProperty("cursor").GetString()!);
    return Json(Page(call == 0 ? "page2" : "final", call == 0, row: call == 1));
});
Check(batch.Ready && batch.Fictional && batch.Changes.Count == 1 && cursors.SequenceEqual(new[] { "", "page2" }), "Complete pages returned as one detached preview");
Check(!(await Preview((_, _) => Task.FromResult(Json(Page("", false))))).Ready, "Empty initial cursor remains not ready");
cursors.Clear();
var retried = await Preview(async (request, call) =>
{
    var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
    cursors.Add(body.RootElement.GetProperty("cursor").GetString()!);
    return call switch
    {
        0 => Json(Page("partial", true, true)),
        1 => Json("""{"error_code":"TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION"}""", HttpStatusCode.BadRequest),
        _ => Json(Page("complete", false, true))
    };
});
Check(retried.Changes.Count == 1 && cursors.SequenceEqual(new[] { "", "partial", "" }), "Pagination mutation discards partial rows and restarts original cursor");
async Task RejectAsync(Func<Task> action, string code, string name)
{
    try { await action(); } catch (PlaidPreviewException e) when (e.Code == code) { Check(true, name); return; }
    throw new Exception("FAIL: " + name);
}
await RejectAsync(async () => await Preview((_, _) => Task.FromResult(Json(Page("same", true)))), "cursor_cycle", "Cyclic cursor rejected");
await RejectAsync(async () => await Preview((_, _) => Task.FromResult(Json(Page("", false, true)))), "invalid_cursor", "Nonempty batch with empty cursor rejected");
await RejectAsync(async () => await Preview((_, _) => Task.FromResult(Json("{\"error_code\":\"fictional-secret\"}", HttpStatusCode.BadRequest))), "provider_request_failed", "Provider error body excluded from sanitized exception");
await RejectAsync(async () => await Preview((_, _) => Task.FromResult(Json(new string('x', 4 * 1024 * 1024 + 1)))), "response_limit", "Response byte limit enforced");
using (var http = new HttpClient(new FakeHandler((_, _) => throw new Exception("Network must not run"))))
    await RejectAsync(async () => await new PlaidSandbox(http).PreviewAsync("id", "secret", "access-production-fictional", CancellationToken.None),
        "sandbox_credentials_required", "Production token rejected before network access");
using (var http = new HttpClient(new FakeHandler(async (request, call) =>
{
    var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync());
    cursors.Add(body.RootElement.GetProperty("cursor").GetString()!);
    return call switch { 0 => Json(Page("partial", true)),
        1 => Json("""{"error_code":"TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION"}""", HttpStatusCode.BadRequest),
        _ => Json(Page("committed", false)) };
})))
{
    cursors.Clear();
    var delta = await new PlaidSandbox(http).GetDeltaAsync(new("id", "secret", "access-sandbox-fictional"), "stored-checkpoint", default);
    Check(delta.Cursor == "committed" && cursors.SequenceEqual(new[] { "stored-checkpoint", "partial", "stored-checkpoint" }),
        "Durable refresh restarts the last committed cursor on pagination mutation");
}
string Account(string id, string type, string subtype, string current, string available = "null", string currency = "USD") =>
    """{"account_id":"ID","name":"Fictional account","mask":"0000","type":"TYPE","subtype":"SUBTYPE","balances":{"current":CURRENT,"available":AVAILABLE,"iso_currency_code":"CURRENCY"}}"""
        .Replace("ID", id).Replace("SUBTYPE", subtype).Replace("TYPE", type).Replace("CURRENT", current).Replace("AVAILABLE", available).Replace("CURRENCY", currency);
async Task<IReadOnlyList<PlaidBankAccount>> Accounts(string rows)
{
    using var http = new HttpClient(new FakeHandler((request, _) => {
        Check(request.RequestUri!.AbsoluteUri == "https://sandbox.plaid.com/accounts/get", "Discovery uses cached Sandbox accounts endpoint only");
        return Task.FromResult(Json("{\"accounts\":[" + rows + "]}"));
    }));
    return await new PlaidSandbox(http).GetAccountsAsync(new("id", "secret", "access-sandbox-fictional"), default);
}
var discovered = await Accounts(string.Join(',', Account("checking", "depository", "checking", "100.29", "90.01"),
    Account("card", "credit", "credit card", "12.34", "987.66"), Account("fraction", "depository", "savings", "1.001"),
    Account("eur", "depository", "checking", "20", currency: "EUR")));
Check(discovered[0].ReportedBalanceMinor == 10029 && discovered[0].AvailableBalanceMinor == 9001, "Discovery preserves exact cached asset balances");
Check(discovered[1].ReportedBalanceMinor == -1234 && discovered[1].AvailableBalanceMinor is null, "Card debt has negative account effect; available credit is not spendable asset cash");
Check(discovered[2].BalanceIssue && discovered[2].ReportedBalanceMinor is null && !discovered[3].Supported && discovered[3].Currency == "EUR",
    "Fractional balances are unavailable; unsupported currency is never relabeled USD");
await RejectAsync(async () => await Accounts(Account("duplicate", "depository", "checking", "1") + "," + Account("duplicate", "depository", "checking", "1")),
    "invalid_accounts", "Duplicate discovery identities rejected");
Console.WriteLine("All fictional Plaid backend contract tests passed.");

sealed class FakeHandler(Func<HttpRequestMessage, int, Task<HttpResponseMessage>> respond) : HttpMessageHandler
{
    private int count;
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token) => respond(request, count++);
}
