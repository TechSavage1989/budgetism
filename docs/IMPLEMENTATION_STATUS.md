# Current implementation state

Private-server follow-up: permanent services, loopback HTTPS, owner setup and a
protected database backup/isolated restore were verified in the private session.
LAN access remains disabled at the user's request. A separate Sandbox API smoke
test retrieved 316 fictional changes and removed its Item, without ledger writes.
An authenticated, disabled-by-default [Sandbox preview API](PLAID_SANDBOX_PREVIEW.md)
passed all six build/security jobs at source bd101dee3871d691e2065b6c98c9ff2498153460
and its scanned API package was installed privately with rollback retained.
Protected Sandbox credentials are configured and an owner-authenticated preview
passed with four controlled fictional changes and zero ledger entries.
The endpoint is not wired into the client; durable bank-source
integration and real bank linkage remain unavailable. Older
milestone descriptions below describe the prior checkpoint.

Dev.18 adds fictional bank synchronization and a unified Needs Review inbox on user-confirmed dev.17 (main b222b62a2293c6092fba3ab92e327b46a7802356). Exact validation and delivery evidence belongs in [VALIDATION.md](VALIDATION.md).

Dev.19 work in progress: detached fictional Plaid pagination tests and an isolated Windows server test kit. The user authorized private Windows Server setup. The backend can run under Windows Service hosting and accepts a separate database port; the test kit exercises temporary loopback processes only. See [WINDOWS_SERVER_SETUP.md](WINDOWS_SERVER_SETUP.md). No permanent service, LAN endpoint, live bank adapter or dev.19 desktop package is delivered yet.

| Area | Current source behavior |
| --- | --- |
| Connections | Explicit fictional-account mapping, status, timestamps and manual refresh |
| Source model | Durable account/transaction IDs, pending/posted/removed states and separate reported/available balances |
| Atomic refresh | Complete pages before source/balance/checkpoint commit; stable repeat/reorder handling and failure retention |
| Pending changes | Explicit pending-to-posted relationships; ambiguous replacements require review |
| Needs Review | Categories, duplicates, transfers, card payments, schedule matches, corrections/removals and connection issues |
| User edits | Refresh never changes ledger records; reviewed corrections preserve categories, notes, payee and occurrence links |
| Reconciliation | Conflicts stay visible; changes require all applicable statements to be reopened |
| Compatibility | Read schemas 1–8; first fictional mapping requires format-8 consent; preserve prior collections |
| Security | Optional password, encrypted payloads, OS keys and independent backups unchanged |
| Retained features | Home, date pickers, quick entry, imports, rules/history, budgets, schedules, matching and reports |
| Distribution | Verified Windows dev.18 artifact; five build jobs, 306 tests, 26 native commands and exact ZIP/extracted Defender scans passed; see validation evidence |
| Live bank/device sync | Not enabled; no provider credentials, enrollment, server setup or background workers |

See [BANK_SYNC.md](BANK_SYNC.md) for current behavior and [BANK_CONNECTION_PLAN.md](BANK_CONNECTION_PLAN.md) for later provider work.
