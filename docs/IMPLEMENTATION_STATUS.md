# Current implementation state

Budgetism 0.1.0-dev.2 development preview. No application release or tag.

| Area | Status |
| --- | --- |
| Prior Windows baseline | User confirmed dev.1 launches and sample mode works |
| Local storage | Encrypted financial snapshot in native SQLite; requires passphrase each open |
| Transactions | Local create/edit/void; exact cents, balanced postings and audit; split income/expenses |
| Accounts/categories | Local create/edit account, create/rename category |
| Backups | Encrypted export and full-workspace restore; no passphrase recovery |
| Search/settings | Payee/notes/category/account search, account filter, saved theme |
| Demo | Existing temporary sample workspace retained separately |
| Web | Existing demo/server interface; local persistence disabled |
| Sync | Not implemented for local workspace; no outbox or merge UI |
| Budgets/forecasts | Placeholders; engines not implemented |
| Updates | Existing checks/downloads retained; install disabled pending native validation |
| Validation | New tests defined; see DEVELOPMENT_HANDOFF.md for exact performed results |
| Production data | Not approved; use test records and keep independent backups |

No server/provider-account/payment setup or release publication is included.
