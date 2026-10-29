# Private-server fictional source review

Dev.20 adds durable Sandbox sources and explicit review to the authenticated
server client. The user confirmed seeing the earlier dev.19 preview after local
sign-in. Server records remain separate from the encrypted local workspace.

Connections retains detached previews. **Open durable Sandbox review** and
Needs Review read saved database state. Navigation, ordinary snapshots, timers
and reloads never call Plaid. **Discover fictional fixture** explicitly discovers
the server's retained Sandbox accounts. Mapping creates a dedicated `Sandbox `
account after fictional-account and zero-baseline consent. It creates no opening
journal entry. Reported balances are separate cached reference values observed
at retrieval time. Only USD checking, savings and credit cards can map. Credit
debt is negative; available credit is not asset cash. See
[Plaid account semantics](https://plaid.com/docs/api/accounts/).

**Refresh fictional sources** collects complete bounded pages from the saved
cursor, restarting that cursor on pagination mutation. Sources, observed content
revisions, account metadata, audit, operation receipt and final cursor commit
atomically. Failure retains the checkpoint and earlier success time. Missing
rows are not removals. Source versions describe locally observed content changes,
not fabricated provider revisions. No automatic refresh or paid balance/refresh
endpoint is used. An uncertain client mutation retains its original operation ID
and unchanged request for retry; conflicting reuse is rejected.

Explicit review supports recording expense/income/refund, matching an existing
entry, pairing transfer sides, ignoring with a reason, and keeping a linked entry
unchanged with a reason. Pending and superseded sources never post. Duplicate and
transfer review plus final confirmation are required for posting/linkage.
Matching preserves metadata. Pairing records one transfer and two source links.
Refunds use balanced contra-expense postings and reduce spending. Owner,
connection/source versions, ownership, exact amount/date and journal-side
uniqueness are rechecked under the same owner lock as other ledger mutations.

Changed or removed linked sources remain visible without silently changing or
voiding recorded finances. This server ledger is immutable: server correction,
void and reconciliation tools remain future work. Keep unchanged records an
explicit reason. Disconnect preserves all history. Resume cannot silently replace
the retained fixture. Pages load 100 sources; transfer candidates are limited to
loaded pages, as disclosed in the UI. Storage is bounded at 100,000 sources.

## Upgrade and recovery

`PLAID_SANDBOX_REVIEW_ENABLED=true` is a separate, disabled-by-default switch.
Protected Sandbox credential files are reused; credentials and raw cursors never
reach clients. New routes require owner bearer authentication and a separate
request limit. Errors are sanitized. The client requires normal HTTPS trust,
refuses redirects, bounds responses and discards changed sessions.

New empty databases create the complete model and bank schema marker version 1.
Existing databases never upgrade automatically. After a protected backup and
independent isolated restore, the schema owner can explicitly run the
[additive SQL](../scripts/upgrade_bank_sources_v1.sql), packaged as
`Upgrade-BudgetismBankSources.sql`. It adds seven tables without changing existing
ledger tables/rows. It is repeatable at version 1 and refuses missing baseline
tables, partial bank schemas and unknown versions. Review refuses unavailable
schema markers/tables. Preserve the old API program for rollback; never reinstall
over existing data. Recovery must include all 14 tables, including operations,
revisions, audit, source links and checkpoints.

The disposable Windows runner exercises the seven-table upgrade with existing
fictional ledger data, repeat/future/partial guards, exact financial review,
idempotency, failure rollback, concurrency, disconnect and independent full
dump/restore across database restart. It never contacts Plaid or an existing DB:

```powershell
./scripts/test_server_bank.ps1 -DotnetPath (Get-Command dotnet).Source -PostgresDirectory <verified-postgresql-directory>
```

The candidate must pass the retained suite, native Windows isolation/screenshots,
package verification and exact ZIP/extracted Defender scans before delivery.
Development publication is not a release. No real bank linkage, public listener,
local-workspace upload, background provider job or installed-ledger test posting
is enabled. Host details and private installation evidence stay outside source.
