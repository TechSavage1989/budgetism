# Private-server dashboard

Dev.23 adds a read-only Home view for authenticated server sessions. The user
authorized this next milestone after themes and review. It uses Budgetism's own
financial contracts and the [product reference roadmap](PRODUCT_REFERENCE_PLAN.md).
Local Home and the ephemeral demo remain separate; no local records are uploaded.

## Recorded money

`GET /api/dashboard?through=YYYY-MM-DD` uses one repeatable-read transaction.
The client sends its current local calendar day without timezone conversion.
Balances sum signed ledger postings whose journal effective date is through that
day, including signed opening entries, debt and both transfer sides. Archived
accounts are included and labelled. Net recorded balance is not market net worth.
Assets and cash excludes credit-card/loan/liability accounts. USD only.

Month-to-date income and spending include every recorded income/expense in the
inclusive month-start/day range. Refunds are contra-expenses; transfers and card
payments are not income/spending. Future-dated entries are counted/disclosed but
excluded from balances, spending and recent activity. Accounts and Transactions
retain their existing all-recorded-dates behavior. No historical value is inferred
from an unsigned opening-entry magnitude: balances use actual signed postings.

The dashboard lists up to eight recent entries in stable date/identity order and
up to six categories by net spending, with full counts and scope labels. Totals
include every applicable row. Account inventories above 1,000 and totals outside
JavaScript's exact integer range fail visibly, never silently truncate or round.
Recent opening values show magnitude; their sign is reflected in account balance.
This is an overview, not the planned full report or budget-parity milestone.

## Saved bank state

Needs Review and saved-source counts use the same complete source/replacement/
mapping rules as the review inbox, within the consistent dashboard read.
Disconnected history remains visible. Disabled or unavailable storage reports an
unavailable count, not zero. Provider balances are cached references with observed
timestamps, mapping and availability; they never enter recorded totals. A refresh
issue is disclosed without exposing provider errors or credentials.

Dashboard loads and refreshes read saved database state only. They never retrieve
Plaid credentials, contact a provider, consume a cursor, record entries, change
review decisions or write audit/operation receipts. The existing ordinary server
snapshot refresh can refresh the overview, but it is not background bank sync.

## Transport and delivery

The client requires normal HTTPS, authenticated GET, refused redirects, a bounded
1 MiB response, timeout, exact integer validation and matching requested date.
Late destination/session/generation results are discarded. Failure clears prior
totals and offers retry/navigation rather than displaying a false current value.
No dashboard data/search/credentials are persisted to preferences or logs.

This requires a verified scanned API program update and separate client delivery
after a fresh protected backup/isolated restore. No schema migration, installer,
firewall, IIS, certificate, provider provisioning or financial-data change is needed.
Keep prior program files for rollback and preserve current windows/desktop data.
