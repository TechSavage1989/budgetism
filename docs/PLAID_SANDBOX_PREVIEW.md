# Authenticated Sandbox preview

The development API has a detached `POST /api/bank/sandbox/preview` endpoint.
It requires the existing owner bearer session and is disabled by default.
It does not enroll a bank, initialize an owner, change the database schema,
write a ledger transaction, save a provider cursor, or synchronize a local workspace.
The installed service must be upgraded from a verified package before this endpoint exists there.

An administrator may explicitly enable it with service-specific environment
`PLAID_SANDBOX_PREVIEW_ENABLED=true` and three separately protected files:
`PLAID_SANDBOX_CLIENT_ID_FILE`, `PLAID_SANDBOX_SECRET_FILE`, and
`PLAID_SANDBOX_ACCESS_TOKEN_FILE`. The API identity must be able to read them;
other service identities and ordinary users must not. Never put their contents
in registry values, process arguments, source, logs, screenshots or financial backups.
There is no credential-entry or token-creation endpoint. The access token must
belong to a separately created fictional Sandbox Item and start with `access-sandbox-`.
An Item removed by the standalone smoke test cannot be reused.

The server contacts only `https://sandbox.plaid.com/transactions/sync`, uses
normal certificate validation, rejects redirects, bounds each response to 4 MiB,
each batch to 50,000 changes/100 pages, and each request to 90 seconds overall.
One preview runs at a time. The existing authentication rate limiter also applies.
Provider response bodies and transport exception messages never enter error responses.
No production endpoint or real-account linkage is implemented.

Every preview begins at the empty cursor and collects a complete detached batch.
A pagination mutation discards partial results and restarts at the original cursor,
with at most three attempts. An empty initial cursor is reported as `ready=false`,
not a completed retrieval. No cursor is persisted or returned to the client.
This endpoint is a diagnostic preview, not an incremental refresh service.

Rows preserve account/transaction identities, added/modified/removed kind,
pending state and explicit pending predecessor identity. USD numbers convert
directly from JSON decimal values to exact signed integer cents; positive Plaid
outflows become negative account effects. Fractional cents, invalid dates,
unsupported currencies and out-of-range values fail the whole batch.
Removal tombstones contain identity only; missing rows never imply removal.
No provider revision, transfer relationship, category decision or opening balance
is manufactured. The response has `Cache-Control: no-store`.

Fictional transport/normalization contracts:

```powershell
dotnet run --project tests/plaid-contract/plaid-contract.csproj --configuration Release
```

The packaged server smoke test checks unauthenticated `401` and authenticated,
disabled `503`. Full client mapping, durable source versions/checkpoints,
protected token lifecycle, explicit review and ledger integration remain unfinished.
Do not enable real financial use on the basis of a successful preview.

Provider references:
[Sandbox API](https://plaid.com/docs/api/sandbox/) and
[Transactions Sync](https://plaid.com/docs/api/products/transactions/).
