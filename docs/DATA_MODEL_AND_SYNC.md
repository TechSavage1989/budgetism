# Financial Data Model and Synchronization Specification

> **Design reference only.** This document is historical v0.2 product scope, not a description of implemented Budgetism features. No server setup, deployment, unattended workers, payment integration, or external API-account setup is included in the current 0.1.0-dev.1 development scope.

Version: 0.2 draft

## 1. Accounting invariants
1. Posted ledger transaction contains at least two journal postings. Journal debits and credits balance within each accounted currency; cross-currency movement uses explicit FX bridge/valuation entries.
2. Owning-account transfer never creates income or spending, except separately recorded fees or FX adjustments.
3. Credit card purchase is expense when recognized; payment reduces checking and card liability, not expense again.
4. Split category allocations must equal the source transaction expense/income amount, accounting for any separate transfer postings.
5. Opening balances are explicit historical postings, not invisible UI offsets.
6. Posted, pending, cleared, reconciled, scheduled, and forecast-only are distinct concepts; a forecast event is not a posting.
7. Financial calculations use exact decimal or currency-specific minor-unit storage, never binary floating point. Precision must accommodate zero/three-decimal currencies and future non-fiat extensions.
8. Reconciliation produces a statement record with closing amount and period; changing a reconciled posting requires tracked correction or explicit authorized unlock.
9. Imported duplicates and repeated network requests never silently create additional posted entries.
10. Every edit has a stable operation ID and an auditable version. Aggregate writes are atomic.

## 2. Entities
Identity and access: User, Device, Session, Workspace, WorkspaceMember (future), WorkspaceSettings.
Financial: Institution, Account, LedgerTransaction, LedgerPosting, Payee, Category, Tag, TransactionTag, ReconciliationStatement, ExchangeRate, Attachment.
Planning: Budget, BudgetPeriod, BudgetAllocation, BudgetTransfer, RecurringSeries, RecurringOccurrence, ForecastScenario, ScenarioAdjustment, SavingsGoal.
Automation/import: Rule, RuleCondition, RuleAction, ImportBatch, ImportMapping, ImportedSourceRecord, ExternalBankLink (future).
Operations: SyncOperation, ChangeLog, DeviceCursor, ConflictRecord, AuditRecord, BackupRecord, SchemaMigration.

## 3. Critical fields
Account: id, workspace_id, name, type, currency_code, opening_date, status, include_in_net_worth, include_in_budget, updated_version.
LedgerTransaction: id, workspace_id, transaction_type, effective_date, posted_date, status, payee_id, memo, imported_source_id, origin_device_id, updated_version, created_at, updated_at.
LedgerPosting: id, ledger_transaction_id, account_or_internal_ledger_id, currency_code, debit, credit, reconciled_statement_id, optional category attribution.
BudgetAllocation: id, budget_period_id, category_id, assigned_amount, carryover_policy, updated_version.
RecurringOccurrence: id, series_id, local_due_date, expected_amount, status, matched_transaction_id, estimated_flag.
SyncOperation: idempotency_key, workspace_id, device_id, aggregate_type, aggregate_id, expected_version, payload, server_sequence, status, received_at.

## 4. Calendar, timezone and schedule semantics
Money posting effective date is a local calendar date with a specified workspace time zone, not a timestamp guessed from UTC. Audit times use UTC timestamps. Monthly recurrences must specify explicit end-of-month behavior for dates such as the 29th, 30th, and 31st. Recurrence and bill-matching routines are deterministic and tested across DST and leap years.

## 5. Native offline synchronization protocol
1. Device enrolls using an authenticated TLS connection and downloads a workspace snapshot with a server cursor.
2. UI reads and writes local SQLite. A transaction edit and its outbox operation commit atomically locally.
3. Each queued mutation carries a unique idempotency key, target aggregate, and expected server version.
4. Server validates authentication, permissions, ledger invariants, schema compatibility, aggregate version, and operation uniqueness.
5. Server commits all postings/related changes and change-log record in one database transaction; assigns strictly increasing workspace change sequence.
6. Client advances its cursor only after all received change records are durably written locally.
7. Retry of the same operation returns the original result instead of applying twice.
8. Client pulls remote changes since cursor; tombstones preserve deletions until devices can safely reconcile.
9. Independent edits on different aggregates can both succeed; simultaneous edits to the same financial aggregate never silently use last-write-wins.
10. Conflicting operation goes to a conflict inbox with original, local, and server values plus user-controlled resolution. Financial transactions are treated as cohesive aggregates, not field-level auto-merges.
11. A full resync reconstructs data from server after queued local changes are exported or safely reconciled. 'Reset local cache' must not silently discard unsent work.

## 6. Import deduplication
Store file checksum and imported record identity when available. Use normalized fingerprint (date, amount, currency, account, payee/reference, available bank-provided ID), with user review for ambiguous matches. Store import batch provenance and undo records. Unique source IDs prevent duplicate imports; fuzzy matching must not automatically suppress legitimate repeat purchases.

## 7. Derived balance and forecast contract
- Posted balance: sum of ledger postings counted as actual under the account's accounting sign convention.
- Cleared/reconciled balance: subset certified by clearing/reconciliation rules.
- Available-to-budget: explicitly defined available funding less assigned funds and applicable carryovers, never conflated with net worth or credit limit.
- Forecast: start with an as-of date and specified posted/pending inclusion policy, apply unmatched scheduled occurrences chronologically, and optionally apply a separately identified estimated-spend model.
- Actual and forecast should reconcile on their shared boundary date; calculations show currency, account filter, inclusion policy, and projection assumptions.
