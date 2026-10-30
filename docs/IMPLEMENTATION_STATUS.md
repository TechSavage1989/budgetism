# Current implementation state

Dev.22 candidate adds [themes and server review controls](THEMES_AND_REVIEW.md)
from the user's selected [reference roadmap](PRODUCT_REFERENCE_PLAN.md). It adds
device-only preset/custom-accent appearance, generated contrast/spacing and
session-only source filters/selection. Atomic reasoned batch Ignore/Keep changes
source decisions/audit only, preserving journals/postings/checkpoints. It requires
a verified API program update, not a database migration. Full candidate checks,
scanned delivery and private update remain pending. The dev.21 launcher works;
existing financial data and authorization boundaries remain unchanged.

The user confirmed dev.20 Sandbox discovery/mapping/refresh works; four saved
sources and a fresh complete 14-table restore were independently verified, with
no journal entries or pending postings. Dev.21 is a client-only
[optional HTTPS address continuity](SERVER_ADDRESS.md) candidate, with stale
response and credential-destination guards. All six jobs, 344 tests, 29 native
commands and package scans passed; see [DEV21_VALIDATION.md](DEV21_VALIDATION.md).
A separate verified client and named private launcher were delivered while the
current window remained open. The verified dev.20 API/database stay installed;
dev.21's optional Remember setting has not yet been user-confirmed.

Dev.20 candidate adds [durable server Sandbox source review](SERVER_SANDBOX_REVIEW.md),
with explicit zero-baseline mapping, atomic checkpoints/history, record/match/pair/
ignore/keep decisions and a disabled-by-default switch. Existing databases require
an explicit additive versioned upgrade. Disposable PostgreSQL upgrade/retry/
rollback/concurrency and 14-table independent restore tests passed locally.
All six CI jobs passed, including 335 client tests, 27 native commands and exact
package scans; see [DEV20_VALIDATION.md](DEV20_VALIDATION.md). The verified private
API/schema upgrade preserved legacy table digests, passed a 14-table restore and
enabled fictional review. No live sources/mappings or journal entries were created.
A separate verified dev.20 client was delivered and opened at its welcome screen;
owner sign-in is a local user action. Dev.19 owner sign-in and visible fictional
changes were previously confirmed by the user. No real banks,
automatic provider refresh or public/LAN listener is enabled.

Client candidate 0.1.0-dev.19 now wires the [private-server Sandbox panel](SERVER_SANDBOX_CLIENT.md)
into Connections for an authenticated server session. It is explicit and read-only,
keeps all preview rows in memory, and never imports a local workspace or writes a
ledger entry. HTTPS validation, refused redirects, response limits, strict amounts,
sanitized failures and stale-session guards are covered by new tests. All six
CI jobs passed, including 328 tests, 27 native Windows commands and package scans;
see [DEV19_CLIENT_VALIDATION.md](DEV19_CLIENT_VALIDATION.md). A verified package
was extracted separately for local owner sign-in. Dev.18 remains the earlier
user-confirmed baseline. No real bank enrollment or automatic retrieval is enabled.

Private-server follow-up: permanent services, loopback HTTPS, owner setup and a
protected database backup/isolated restore were verified in the private session.
LAN access remains disabled at the user's request. A separate Sandbox API smoke
test retrieved 316 fictional changes and removed its Item, without ledger writes.
An authenticated, disabled-by-default [Sandbox preview API](PLAID_SANDBOX_PREVIEW.md)
passed all six build/security jobs at source bd101dee3871d691e2065b6c98c9ff2498153460
and its scanned API package was installed privately with rollback retained.
Protected Sandbox credentials are configured and an owner-authenticated preview
passed with four controlled fictional changes and zero ledger entries.
The detached endpoint is wired into the verified dev.19 client. Durable review
is a separate dev.20 candidate; real bank linkage remains unavailable. Older
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
