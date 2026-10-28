# Current implementation state

Budgetism 0.1.0-dev.5 source iteration. User-confirmed Windows baseline is dev.4 for monthly budgeting and restart persistence; dev.3 optional-password behavior was confirmed. Hosted checks for this new iteration are pending until recorded in the handoff.

| Area | Status |
| --- | --- |
| Local accounts and transactions | Existing exact-cent ledger, splits, edit/void, audit and search retained |
| Monthly budgets | Existing allocations, rollover, copying and category drilldown retained |
| Recurring schedules | New local weekly/fortnightly/monthly/yearly bills, income and transfers |
| Upcoming and history | Overdue/upcoming list, pause/resume, postpone/skip, recorded transaction drilldown |
| Posting | Explicit manual confirmation only; atomic transaction and occurrence link, duplicate rejection |
| Financial schema | Existing 1/2 readable; first schedule save explicitly upgrades to 3; older builds then refused |
| Security/backups | Existing optional password/device key and separately password-encrypted backups retained |
| Native validation | Authored schedule tests include actual OS-key/SQLite persistence in two app processes; execution status in handoff |
| Web | Existing demo/server interface; no browser-local workspace or scheduled data |
| Sync/forecast/calendar | Not implemented in this milestone |
| Updates | Existing discovery/download; installation remains disabled |
| Production data | Not approved; use fictional records and keep independent backups |

No server setup, payment/bank account setup, release or tag is included.
