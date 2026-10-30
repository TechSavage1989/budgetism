# Private-server planning suite

The user authorized implementation of the remaining feature roadmap after dev.23.
Dev.24 brings budgets, recurring schedules, calendar, cash-flow forecasts, reports,
account trends, custom categories, labels and saved activity searches to private
server sessions. It preserves separate local workspaces, fictional bank scope,
owner authentication and existing network/publication restrictions.

## Data and commands

Existing server databases require an explicit additive planning-schema upgrade
after protected recovery verification. Three tables bring the total from 14 to
17: schema marker, owner workspace document, and append-only application audit.
Startup never migrates an existing database. The prior API program remains
compatible with the unchanged financial tables; do not reinstall the database.

Planning documents and audit details use AES-256-GCM with a separate random
server key in a protected file. Associated data binds owner/workspace version or
complete event identity. Keys are never stored in the database, source or package.
Back up the protected key separately with every database recovery set. Losing it
makes planning documents unreadable. This does not change the existing server
ledger storage or add end-to-end device synchronization. Metadata such as owner,
event type, version and timestamp remains visible in the database.

Commands require explicit confirmation, operation ID, current owner planning
version and financial cursor. One owner lock, transaction, typed receipt and audit
commit preserve atomicity. Exact replay returns the original result; changed reuse
or stale state fails. The client retains the original envelope/ID after uncertain
completion, including budget dialogs that generate a fresh button-attempt ID.
GET reads never create a workspace/occurrence, fetch provider credentials or
contact Plaid. Local records are never uploaded.

## Planning behavior

Budgets retain no/positive/all rollover, allocation removal, copy previous month,
exact category progress and expense drilldown. Spending covers the complete
selected month, including future-dated recorded expenses; Home remains through
today. Allocations do not create postings or transfer money.

Schedules support bills, income and transfers; weekly/fortnightly/monthly/yearly
anchors; editing templates; pause/resume; explicit record, match, postpone and
skip; and history. Short months and leap years preserve the original anchor.
Recurrence dates are immutable after creation. Stable schedule/index identity
cannot be resolved twice. Postponing/skipping never moves money. Only explicit
Record transaction creates balanced journal postings, financial change, resolved
occurrence, planning audit and receipt in one commit.

Server Match existing validates kind, account/transfer direction, currency,
transaction version and a 90-day maximum date gap. It preserves journal identity,
money, notes and financial change stream. Its authoritative relationship lives
in the planning document; the read projection supplies reciprocal display links.
It does not rewrite the immutable server journal merely to add relationship
metadata. One actual entry cannot settle two occurrences. This differs from the
local payload's versioned transaction-link representation; both retain the same
no-repost outcome. Settled/skipped occurrences are not regenerated.

Calendar and forecasts reuse read-only date/recurrence calculations. Signed
recorded postings through today form the starting balance. Future actuals enter
on their effective dates, unresolved plans enter once, and overdue unresolved
items are disclosed instead of assigned invented payment dates. Linked actuals
replace their plan. No timer posts or retrieves bank activity.

## Reports and activity

Historical report ranges/account filters, category drilldown, monthly comparisons,
recorded account trends/balances and explicit CSV export use a detached server
projection. Signed opening entries affect balances on their actual dates, never
income/spending. Refunds reduce expenses; transfers/card payments are excluded
from income/spending. These are recorded balances, not market valuations.
The local report engine's added dated-opening read case does not change local
financial formats or mutation behavior. Export remains explicit, unencrypted,
desktop-only, formula-safe and separate from backups.

Server activity combines payee/notes/account search, account, type, label and
inclusive calendar dates. Invalid ranges fail visibly. Search stays in memory
until Save this search. Saved searches and labels use encrypted server documents,
not device appearance preferences. At most 50 saved views, 100 labels and 20 labels
per entry are supported. Applying/removing a label or saved view never edits money.
Custom income/expense categories can be created, renamed, archived and restored.
Archiving preserves history and prevents new use until restored.

## Boundaries and limits

The server adapter has no vault/storage reference. Its synthetic display snapshot
reuses calculation/widget interfaces; it is not a local format-8 conversion.
Original local imports, profiles, rules/history, splits/edits/voids and statement
reconciliation remain available locally. This milestone does not silently port
those mutation contracts into server journals or merge a local workspace.
Real banks, paid services, public/LAN exposure, automatic refresh/posting,
investments, multi-currency and local/server synchronization remain outside the
current authorized integration boundary.

USD only. Read inventories are complete or fail visibly above 2,000 combined
ledger accounts/categories or 10,000 journals; no partial financial totals are
shown. Documents are limited to 2 MiB, commands to 256 KiB and replies to 16 MiB.
Up to 5,000 budget rows, 500 schedules and 10,000 occurrence records are supported.
Exact integer limits, trusted HTTPS, rejected redirects, bounded responses,
stale-session checks and sanitized failures remain mandatory.
