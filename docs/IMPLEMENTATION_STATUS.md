# Current implementation state

Budgetism 0.1.0-dev.7 source iteration. User confirmed dev.6 calendar/forecast behavior; earlier accounts, persistence, optional password, budgeting and recurring features remain the working baseline. Hosted validation must be verified before delivering dev.7.

| Area | State |
| --- | --- |
| Existing finances | Dev.6 accounts, budgets, schedules, calendar and forecasts retained |
| CSV import | Local UTF-8 header/column mapping, explicit date/sign convention and preview |
| Review | Per-row skip/import/transfer or exact-date/amount existing-transaction match |
| Duplicate protection | Source digest/row and optional unique bank IDs, plus reviewed possible matches |
| History | Encrypted receipts survive edits, voids, backups and restarts |
| Save/migration | Atomic batch and stale revision check; first import explicitly upgrades financial schema to 4 |
| Security | Existing optional password, device keys, encrypted backups and Defender delivery gate retained |
| Tests | New parser/ledger/storage/widget and native two-process tests added; inspect hosted results |
| Web | Existing demo/server only; no browser-local financial data |
| Not included | Schedule auto-matching, reconciliation, bank feeds, multi-currency, synchronization or updater installation |
| Distribution | Development artifacts only; no GitHub release/tag, signing or production approval |
