# Reviewed category suggestions during CSV import

Dev.15 connects the existing saved categorization rules to the CSV review screen. This is an explicit, bounded extension of FR-04 and FR-10, not automatic importing or historical recategorization.

## Workflow

Choose a CSV, destination account, mapping/profile and default categories as before. Preview transactions, then choose **Review category suggestions**. Enabled rules suggest categories for eligible rows currently marked **Import a new transaction**. Nothing is selected by default. Review the current/proposed categories and winning rule, select suggestions, confirm review, then choose **Use selected suggestions**.

Accepted suggestions only update this unsaved preview. The ordinary final CSV review and **Import selected rows** confirmation remain required. Closing the import without committing discards these choices. No rule, profile, transaction or receipt is saved by opening, reviewing, accepting or cancelling suggestions.

## Precedence and exclusions

Rules use their existing priority, enabled state, payee Contains/Exact/Starts with, account, direction, positive absolute USD amount bounds and current-category condition. CSV rows are prospective statement-sourced entries: All and Statement-linked rules can match; manual-only rules cannot. Lowest priority number wins. A first match proposing the current category suppresses later rules, and a row is not processed by a chain of rules.

Skipped, invalid, already-handled and match-existing rows are excluded. Transfers and payment/transfer-hinted descriptions are excluded even when their current type is expense or income; confirm their type manually. Suggestions never change type, amount, account, date, notes, reference, matching decision or duplicate approval. A possible duplicate explicitly marked Create still requires its independent duplicate approval at import time.

Manually chosen row categories and already-accepted suggestions are protected from replacement for that preview. A manual category override removes the suggestion label. Rebuilding the CSV preview resets these session-only choices, as does changing the mapping/file/account. Saved profiles continue to supply defaults without forcing any categorization rule to run.

## Staleness and financial safety

A review is bound to the workspace revision, selected account, exact file identity, parsed rows, rule/category definitions, import receipts, row choices and protected rows. Acceptance rechecks current data; changed rules, another writer or edited review inputs require a fresh CSV preview instead of silently accepting different suggestions. No ledger write occurs during that check.

The existing atomic import mutation is unchanged. Final imports retain original duplicate, reconciliation, posting and revision protections. New transactions are created directly in their reviewed category; no extra categorization batch, category-undo event or second transaction is generated. Existing matched transactions remain untouched. Existing category-history undo does not undo imports; normal editing remains available for eligible imported transactions.

## Limits and continuity

At most 500 suggestions can be accepted in one review; the existing 500-row import and 1000-row CSV limits remain. Suggestions display in groups of 100 with explicit expansion. Only selected rows change, including rows beyond the first CSV review page. Suggestion state stays in memory and is not written to preferences, logs, backups or network services. Saved rules/profiles and actual imported records retain their existing encrypted persistence and backup behavior.

No new financial schema, storage/encryption format, package dependency, server connection or automatic application is added. Dev.14 remains the user-confirmed baseline until desktop confirmation. See VALIDATION.md for performed checks.
