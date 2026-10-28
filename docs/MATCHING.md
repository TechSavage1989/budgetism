# Match an existing payment to a schedule

## Workflow

Dev.8 adds Scheduled > Upcoming > Match existing. Use it only when the actual bill payment, income or transfer already exists in Transactions. Suggestions do not save data. Select one actual entry, review its amount, date and complete category/split details, explicitly confirm, then choose Link without new transaction. The occurrence is settled and appears as Matched in History. Its transaction opens normally from History.

The actual account balance, spending, categories, splits, date, payee, notes, postings, original operation ID, import receipts and schedule template remain unchanged. The transaction version increases and reciprocal schedule/index links are added. The existing occurrence uses confirmed status with its actual transaction ID. No financial-schema/encryption/SQLite migration or dependency is introduced. This is not bank-statement reconciliation or automatic matching.

## Eligibility and review

Candidates are non-voided, currently unlinked transactions with the same kind, primary account and currency as the schedule. Transfers must also have the exact same destination account, preserving direction. A transfer is not interchangeable with an expense or income entry. One whole transaction may satisfy only one occurrence, even when it has multiple category splits. Split transaction amounts cannot be matched individually to separate schedules.

The default is exact expected amount within seven calendar days before or after the current due date. Choose 30 or 90 days explicitly to widen the range. Include different amounts is initially off. Turn it on for variable bills; the actual amount is never replaced with the planned amount. Search filters payee, notes and date. Results sort exact amounts first, then nearest dates, then a stable identifier. Display is limited to 100 candidates with a visible count and instruction to narrow the search.

Categories and payees may differ and are displayed, not silently corrected. This allows a bank-imported actual to retain its recorded categories. Explicit review is required even for an exact amount/date. No candidate is selected automatically. Postponed occurrences use the postponed due date. The ledger rejects dates outside the maximum 90-day range even when called without the UI. Paused schedules must be resumed first.

## Integrity and recovery

Matching checks workspace revision, schedule version, occurrence version and actual-transaction version. A stale window or preview must reopen/refresh. Confirmed/skipped occurrences and already-linked transactions cannot be matched again. Replaying the exact same operation is idempotent; a changed request with that operation ID is rejected. Failed persistence changes neither link, audit nor visible ledger.

Transaction-link and occurrence changes are audited under the same operation and saved atomically by the existing encrypted store. Imports retain source identity through matching, editing, voiding and backup/restore. Reimport protections continue to apply. Editing or voiding a matched transaction retains its occurrence relationship and does not make the bill due again. Corrupt or orphaned reciprocal links fail existing restore validation.

The calendar/forecast now represents the occurrence through its linked actual only. A future-dated actual still enters on its effective date; an unresolved plan is not added again. Overdue disclosures update because the occurrence is no longer unresolved. No forecast/budget engine was changed.

There is no unlink/reopen action in this preview. Review carefully and export an independent encrypted backup before development testing. Restoring a backup replaces the complete workspace, not just one link. Do not void a legitimate actual as a way to undo a mistaken match. No change to security preference, device keys, backups, updater installation or server access.
