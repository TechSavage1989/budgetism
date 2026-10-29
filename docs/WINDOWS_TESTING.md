# Budgetism dev.17 Windows check

Use only the final successful and independently verified dev.17 build recorded in VALIDATION.md. Export an encrypted backup, retain its password and close Budgetism. Extract the new Windows program into a separate folder, keep all supporting files together, confirm 0.1.0-dev.17 and open the existing workspace using the same Windows account. Do not recreate or replace the database. No new format upgrade is expected.

First inspect Home and Settings. Open Categorization rules or Saved import profiles directly, then close without saving. In a new transaction, search an existing account/category and type part of a known expense payee. Choose a suggestion, then Cancel. Only the form should have changed; balances, transaction count and saved rules/profiles remain unchanged.

Optional fictional quick-entry check: in a fictional account, enter a 1.25 expense and choose Save and add another. The amount/payee/notes should clear, and the dialog should report one saved entry. Enter 2.75 and choose Save transaction. Exactly two new transactions should exist and the account should be lower by 4.00. Reopen the application and verify those same two entries, with no third blank/duplicate entry. Do not use real data for development tests.

The existing calendar pickers remain available. Narrow windows show More for the full navigation drawer. Home totals exclude future-dated actuals, while Accounts and Transactions still include all dates; monthly budget totals retain their full-month scope. Saved transactions are not undone by closing the add-another dialog. Bank connections/device sync remain unavailable.
