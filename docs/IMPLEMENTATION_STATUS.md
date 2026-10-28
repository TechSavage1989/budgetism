# Current implementation state

Dev.10 financial reports and CSV export are user-confirmed. Dev.11 adds reviewed local categorization rules; the exact hosted build and package scan remain required before delivery.

| Area | State |
| --- | --- |
| Existing finances | Accounts, budgets, schedules, imports, matching, forecasts, reports and reconciliation retained |
| Rules | Payee/account/type/source/current-category/amount conditions; ordering and enable/disable |
| Review | Inclusive dates, before/after category and winning rule; nothing selected automatically |
| Apply | Explicit selected batch, exact revision/version checks, atomic before/after audit and idempotent retry |
| Protection | Reconciled, split, transfer and voided entries excluded |
| Accounting | Account balances, transaction count, values, receipts and schedule links preserved; categories affect budgets/reports |
| Migration | First rule save requires backup/consent for schema 6; no change merely on open/preview |
| Privacy | Rule text remains encrypted, with existing optional password and independent backups |
| Validation | New unit/storage/widget tests and native two-process rules test authored; inspect hosted results |
| Distribution | Development artifacts only; unsigned; no release/tag, server setup or updater installation |

No rule runs automatically. Bank feeds, synchronization, advanced rule actions and batch undo remain unfinished. See CATEGORIZATION_RULES.md and VALIDATION.md.
