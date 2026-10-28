# Budgetism dev.10 Windows test

Download only the verified compiled Windows artifact from the exact successful run recorded after validation. Export an encrypted backup from working dev.9 and retain its password. Close all Budgetism windows; extract the complete portable package into its own folder, keeping Budgetism.exe, DLLs and data together. Use the same Windows account and existing local workspace. Do not copy, replace or recreate the database.

## Test the new Reports screen

Previous reconciliation, matching, importing, forecasting and budgeting are confirmed. Do not repeat those setup exercises.

1. Confirm version 0.1.0-dev.10. Open Reports and select a known fictional account through Report accounts. Choose a range covering its recorded activity.
2. For an account with opening balance 1000, recorded income 500 and recorded expense 200, expect Income 500, Expenses 200, Net income 300 and Closing recorded net balance 1300, provided it has no other activity. The account opening balance is not income. Transfers and card payments are not expenses.
3. Open Categories and select an expense category. A split transaction must show the category contribution separately from the whole transaction. Monthly shows exact totals for all months in range; Balances shows starting, change and closing values.
4. Optionally choose a CSV report and Export CSV. Confirm that this file is unencrypted and choose a private .csv destination. Check its date range and totals. Cancelled/failed exports must not affect workspace records.
5. Close/reopen. Existing account balances, transaction counts, statement history and optional-password setting must remain unchanged. The report can be regenerated from the same records. Viewing or exporting requires no new workspace-format upgrade.

Reports are recorded historical activity, not the scheduled forecast. Future-dated recorded entries are excluded until their dates fall within the selected historical range. Saved opening balances have no opening dates, so recorded balances are not independently verified historical valuations. CSV is not a backup; sensitive text may be visibly prefixed with Text: for spreadsheet safety.

Use the same build's Defender security-evidence artifact. A no-threats result is limited to that scanner/signature/time; the application remains unsigned and no universal browser-reputation claim is made.
