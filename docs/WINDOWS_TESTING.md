# Budgetism dev.15 Windows test

Use only the completed verified Windows run recorded in VALIDATION.md. Export an encrypted backup from working dev.14, keep its password and close Budgetism. Download Budgetism-Windows-x64-development, not the source/updater-only artifact. Extract both ZIP layers into a separate folder, keep all files together, confirm 0.1.0-dev.15 and open the existing workspace under the same Windows account. Do not replace or recreate its database.

## Test rule-assisted import review

Use fictional data only. The existing Rule test rule can be reused if enabled, with payee Contains Rule test, current category Other spending and proposed category Groceries.

1. Open Transactions > Import CSV and select an existing fictional account. Load a fictional CSV with Date,Description,Amount headers and one row such as 2026-10-28,Rule test store import preview,-23.45. Keep Default expense category as Other spending.
2. Preview transactions. The row initially stays Other spending. It must be marked Import a new transaction to be eligible; do not override a genuine duplicate warning just to test this feature.
3. Choose Review category suggestions. Check the row, Other spending to Groceries and the matching rule. Select the suggestion and review confirmation, then choose Use selected suggestions.
4. The main preview should now show Groceries with the rule label. Account balances and stored transaction counts remain unchanged. The final CSV review checkbox must be unchecked again.
5. Close without importing. Reopening and previewing the CSV begins from the chosen defaults again; suggestions are not auto-applied. Saved rules/profiles/security and existing records remain intact. No schema-upgrade prompt is expected.

No earlier setup tests or new bank connection are required. The optional final import uses the existing confirmation and duplicate protections and creates one transaction with the reviewed category. Accepted suggestions do not create a historical category-undo batch. Manual category choices and existing matched transactions are not changed by rule suggestions. This remains a development preview.
