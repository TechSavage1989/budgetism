# Categorization history and reviewed undo

Dev.13 adds **History** beside Add rule under **User options > Manage categories > Categorization rules**. It covers applied rule batches, including the before/after audit already saved by dev.11 and dev.12. This is a bounded implementation of FR-03 reversible non-reconciled edits, not general financial undo or database rollback.

## History and review

History lists applied batches newest first in their stored order, with application time, original selection date range, transaction count and Applied/Undone status. Times use the current device's local timezone. Show 50 more batches expands the list; no entries are silently removed. Saving a rule without applying it is not a categorization batch.

Open a batch to inspect its original category, applied category, current category, date, amount, account, payee and original rule version. Account/category names use current labels. The rule name comes from the saved rule-version audit when available, not a later renamed rule. Opening history and details never writes, migrates, exports or sends data externally.

## Undo contract

Undo restores the original category for the complete selected batch. It requires a nonempty reason, explicit review confirmation, current workspace revision and the exact review fingerprint. No entries are selected implicitly for a partial undo: either every original change is still eligible or nothing changes.

A batch is blocked if any affected transaction is missing, voided, reconciled, split, or different from its full post-batch record, including version. A later note edit, schedule-link edit or recategorization is not overwritten. Reopening a statement can make an otherwise unchanged transaction eligible again. Undoing a newer batch does not reset transaction versions or automatically make an older overlapping batch eligible. Disjoint older batches may still be eligible.

Original audit evidence must be complete and unique. Each change must be category-only, have the correct identifier/version transition, and have valid balanced before/after postings. Incomplete or inconsistent history fails closed. Commit re-derives the preview rather than accepting caller-supplied categories. Any stale or protected record rejects the whole operation.

## Financial preservation

Undo changes only the category, its category postings and transaction version. It preserves every account posting, amount, date, payee, note, ID, transaction count, import receipt, reciprocal schedule link and all existing statements. Budgets, rollover and reports recalculate from the restored categories. It never recreates a transaction, transfers money, restores an old database snapshot, or changes opening balances.

Original history remains intact. A successful undo appends its reason, source batch identity and before/after events inside the existing encrypted audit. An identical operation replay is a no-op; a second fresh undo of the same source batch is rejected. Failed storage commits preserve categories and history together, and the UI retains reason/review for an unchanged retry.

Saved rules are neither removed nor disabled. A later, explicitly requested rule preview can suggest applying them again. That creates a different batch only after separate user review. There is no automatic redo, no partial undo, and no general transaction-delete/void restoration in this iteration.

## Storage and validation

No financial schema, SQLite container, encryption format, OS-key behavior, optional password, backup format, dependency or data location changes. History and reasons are in the existing encrypted payload and travel with encrypted backups. Legacy workspaces show empty history without migration. Existing schema-6 records remain readable; unsupported versions are never reset.

Tests cover older applied batches, exact monetary preservation, audit retention, stale/forged previews, all-or-nothing protection, missing/inconsistent history, failed saves, duplicate requests, backup restoration, separate Windows processes and responsive review controls. Consult VALIDATION.md for the actual performed checks and remaining gates.
