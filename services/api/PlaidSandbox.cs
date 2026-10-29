using System.Globalization;
using System.Net.Http.Json;
using System.Numerics;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Budgetism.Api;

// Deliberately limited to a detached, authenticated Sandbox preview. No ledger writes.
public sealed class PlaidPreviewException(string code) : Exception(code)
{
    public string Code { get; } = code;
}

public sealed record PlaidPreviewRow(string Kind, string AccountId, string SourceId,
    long? AmountMinor, string? Date, string? Description, bool? Pending, string? PendingSourceId);
public sealed record PlaidPreview(bool Fictional, bool Ready, IReadOnlyList<PlaidPreviewRow> Changes);

public sealed class PlaidSandbox(HttpClient http)
{
    private readonly SemaphoreSlim gate = new(1, 1);
    public static HttpClient CreateClient() => new(new SocketsHttpHandler
    {
        AllowAutoRedirect = false,
        UseCookies = false
    }) { Timeout = TimeSpan.FromSeconds(30) };

    public async Task<PlaidPreview> PreviewAsync(string clientId, string secret,
        string accessToken, CancellationToken cancellationToken)
    {
        if (!await gate.WaitAsync(0, cancellationToken)) throw new PlaidPreviewException("preview_busy");
        try
        {
        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(secret) ||
            !accessToken.StartsWith("access-sandbox-", StringComparison.Ordinal))
            throw new PlaidPreviewException("sandbox_credentials_required");
        // Restart the whole detached batch from its original cursor on pagination mutation.
        for (var retry = 0; retry < 3; retry++)
        {
            try { return await CollectAsync(clientId, secret, accessToken, cancellationToken); }
            catch (PlaidPreviewException e) when (e.Code == "pagination_mutation" && retry < 2) { }
        }
        throw new PlaidPreviewException("pagination_mutation");
        }
        finally { gate.Release(); }
    }

    private async Task<PlaidPreview> CollectAsync(string clientId, string secret,
        string accessToken, CancellationToken cancellationToken)
    {
        var cursor = "";
        var seen = new HashSet<string>(StringComparer.Ordinal) { cursor };
        var changes = new List<PlaidPreviewRow>();
        for (var page = 0; page < 100; page++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post,
                "https://sandbox.plaid.com/transactions/sync")
            {
                Content = JsonContent.Create(new { client_id = clientId, secret,
                    access_token = accessToken, cursor, count = 100 })
            };
            using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            // Read through a strict bound even if Content-Length is missing or misleading.
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var buffer = new MemoryStream();
            var bytes = new byte[8192];
            int length;
            while ((length = await stream.ReadAsync(bytes, cancellationToken)) > 0)
            {
                if (buffer.Length + length > 4 * 1024 * 1024)
                    throw new PlaidPreviewException("response_limit");
                buffer.Write(bytes, 0, length);
            }
            using var document = JsonDocument.Parse(buffer.ToArray(), new JsonDocumentOptions { MaxDepth = 32 });
            var root = document.RootElement;
            if (!response.IsSuccessStatusCode)
            {
                if (root.TryGetProperty("error_code", out var error) &&
                    error.GetString() == "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION")
                    throw new PlaidPreviewException("pagination_mutation");
                throw new PlaidPreviewException("provider_request_failed");
            }
            var next = Text(root, "next_cursor", 4096, allowEmpty: true);
            var more = root.GetProperty("has_more").GetBoolean();
            foreach (var kind in new[] { "added", "modified", "removed" })
            {
                var rows = root.GetProperty(kind);
                if (rows.ValueKind != JsonValueKind.Array) throw new PlaidPreviewException("invalid_page");
                foreach (var row in rows.EnumerateArray())
                {
                    changes.Add(Normalize(kind, row));
                    if (changes.Count > 50000) throw new PlaidPreviewException("batch_limit");
                }
            }
            if (next.Length == 0 && (cursor.Length > 0 || changes.Count > 0 || more))
                throw new PlaidPreviewException("invalid_cursor");
            if (!more) return new(true, next.Length > 0, changes.AsReadOnly());
            if (!seen.Add(next)) throw new PlaidPreviewException("cursor_cycle");
            cursor = next;
        }
        throw new PlaidPreviewException("page_limit");
    }

    public static PlaidPreviewRow Normalize(string kind, JsonElement row)
    {
        var account = Text(row, "account_id", 256);
        var source = Text(row, "transaction_id", 256);
        if (kind == "removed") return new(kind, account, source, null, null, null, null, null);
        if (kind is not ("added" or "modified")) throw new PlaidPreviewException("invalid_kind");
        if (Text(row, "iso_currency_code", 3) != "USD") throw new PlaidPreviewException("unsupported_currency");
        var amount = row.GetProperty("amount");
        var minor = ExactMinor(amount);
        var date = Text(row, "date", 10);
        if (!DateOnly.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out _)) throw new PlaidPreviewException("invalid_date");
        string? predecessor = null;
        if (row.TryGetProperty("pending_transaction_id", out var pending) && pending.ValueKind != JsonValueKind.Null)
            predecessor = Text(row, "pending_transaction_id", 256);
        return new(kind, account, source, minor, date, Text(row, "name", 500),
            row.GetProperty("pending").GetBoolean(), predecessor);
    }

    private static long ExactMinor(JsonElement amount)
    {
        if (amount.ValueKind != JsonValueKind.Number) throw new PlaidPreviewException("invalid_amount");
        var raw = amount.GetRawText();
        if (raw.Length > 256) throw new PlaidPreviewException("invalid_amount");
        var match = Regex.Match(raw, @"^(-?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$");
        var exponent = 0;
        if (!match.Success || (match.Groups[4].Success &&
            !int.TryParse(match.Groups[4].Value, NumberStyles.AllowLeadingSign,
                CultureInfo.InvariantCulture, out exponent)) || exponent is < -1000 or > 1000)
            throw new PlaidPreviewException("invalid_amount");
        var magnitude = BigInteger.Parse(match.Groups[2].Value + match.Groups[3].Value,
            CultureInfo.InvariantCulture);
        var shift = exponent - match.Groups[3].Value.Length + 2;
        if (shift < 0)
        {
            magnitude = BigInteger.DivRem(magnitude, BigInteger.Pow(10, -shift), out var remainder);
            if (remainder != 0) throw new PlaidPreviewException("invalid_amount");
        }
        else magnitude *= BigInteger.Pow(10, shift);
        if (magnitude > 99999999999999) throw new PlaidPreviewException("invalid_amount");
        var signed = match.Groups[1].Value == "-" ? -(long)magnitude : (long)magnitude;
        return -signed; // Plaid positive means money out; no floating-point or decimal rounding.
    }

    private static string Text(JsonElement row, string name, int max, bool allowEmpty = false)
    {
        var value = row.GetProperty(name).GetString();
        if (value is null || value.Length > max || (!allowEmpty && string.IsNullOrWhiteSpace(value)))
            throw new PlaidPreviewException("invalid_field");
        return value;
    }
}
