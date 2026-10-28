# Budgetism dev.9 Windows test

Download only the compiled Windows artifact from the verified run recorded after validation. Export an encrypted backup from working dev.8 and keep its password. Close every Budgetism window. Extract the complete portable package in its own folder; keep Budgetism.exe, DLLs and data directory together, using the same Windows account. Do not replace or recreate the stored workspace.

Open version 0.1.0-dev.9 and your existing workspace. Previous budgeting, forecasting, importing and matching already worked; no repeated setup exercise is needed.

## Test reconciliation only

Use a fictional account with a known opening balance and recorded entries. For example, an opening balance of 1000 plus recorded income 500 minus recorded expense 200 has a balance of 1300.

1. Open Accounts > Reconcile statements (also available in User options). Select the test account and Start reconciliation.
2. Enter the statement ending date, covering those entries, and closing balance 1300.00. Review statement must not alter actual balances.
3. Check the two cleared entries. Selected cleared balance should be 1300.00 and difference 0.00. An omitted or extra entry must prevent completion if the difference is nonzero.
4. After exporting a backup, confirm the format upgrade and statement review. Finish reconciliation must leave the account at 1300 with the same number of transactions.
5. Close and reopen dev.9. Completed history and balance should remain. Trying to edit an included transaction should explain that its statement must first be reopened.
6. Optionally reopen the latest statement with a reason. History remains, balances do not change, and those entries become outstanding for that account again.

Credit-card/loan money owed uses a negative statement balance. A transfer reconciles each side independently and stays edit-protected while included in any active statement. Later statements start at the previous closing balance and can include older outstanding transactions.

The first completed reconciliation upgrades to schema 5. Do not open the upgraded workspace with dev.8 or older. Retain the pre-upgrade backup. Viewing alone does not upgrade. Inspect the exact build's security-evidence artifact; a clean build-time scan is not signing or universal browser reputation.
