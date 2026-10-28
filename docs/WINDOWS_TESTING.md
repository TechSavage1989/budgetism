# Budgetism dev.12 Windows test

Application commit 605ffe4334f20a94197f923fff12562e9de8737d is being validated in [run 40772902439](https://github.com/TechSavage1989/budgetism/actions/runs/40772902439). Do not download until all jobs and the exact-package scan are confirmed successful in VALIDATION.md. Export an encrypted backup from working dev.11, retain its separate password and close all Budgetism windows. Download Budgetism-Windows-x64-development, not source/updater-only artifacts. Extract both the outer artifact ZIP and the inner Budgetism-Windows-x64.zip into a separate folder, keeping Budgetism.exe, DLLs and data together. Open the existing workspace under the same Windows account; do not replace its database.

## Test the register, not earlier milestones again

1. Confirm 0.1.0-dev.12. Open Transactions. Use the existing fictional Rule test store expense from dev.11. No new sample transactions are needed.
2. Search for "Rule test store" including quotes. Expand Filters and select its account, Groceries category, and minimum/maximum 12.34. Include its date when using From/Through. Expect the existing matching record, not a new transaction.
3. Select the result. Details should show the original 12.34 amount, Groceries category, notes and any import/schedule/statement metadata. Close details without editing. Account balance and transaction count must not change.
4. Reset search and filters. Use Reconciled status to inspect an existing completed-statement entry. Its active statement should be listed and Edit transaction unavailable. Transfers are protected while either account remains reconciled.
5. Optionally show Voided only, then reset. Voided rows must not contribute to the totals. Change sort order and navigate to another screen and back; filters should remain during this session. Closing the workspace clears the session filters. Financial records, rules and optional-password settings persist normally.

No migration prompt is expected. Search/filter/sort/details do not change or export finances. Whole-amount filters differ from category contribution totals on split entries. Future-dated recorded entries are included when in range; scheduled plans are not. Use Reports for historical summaries and existing CSV export. Keep the exact build's security evidence; a clean scan is not publisher signing or universal browser reputation.
