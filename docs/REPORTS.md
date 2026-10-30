# Financial reports

Dev.26 candidate adds [category scopes and historical comparisons](REPORT_CONTROLS_DEV26.md). These are session-only read controls; category filters affect income/spending contributions, never whole selected-account balances. CSV carries category/balance scope metadata and remains current-period-only. Final validation is pending.

Dev.10 adds a read-only Reports destination in the saved local workspace. No financial schema, encryption, SQLite, security preference or dependency change is introduced. Reporting does not create transactions, mark items cleared, change reconciliation locks, post schedules or synchronize records.

## Scope and dates

Select all accounts or a chosen set. Presets are This month (through today), Last month, Year to date and Last 12 months (current partial month plus the previous eleven). Custom dates are inclusive, must end today or earlier, and are limited to 3,660 days. USD only. Refresh uses the existing workspace refresh operation; a report reflects the loaded snapshot, not an independently refreshed bank balance.

Only non-voided recorded income and expense transactions whose effective dates fall in the selected range enter income/spending totals. Future-dated recorded entries are excluded until their date is within the historical range. Scheduled plans, budget allocations, reconciliation history and opening balances are not income or spending. Card purchases count as expenses on the purchase account; transfers and card payments are excluded from income/spending and counted separately.

## Views

- Overview: income, expenses, net income, selected recorded net balance, income/expense transaction count and transfer count.
- Categories: expense or income totals, visual proportions and transaction counts. Select a category for its read-only contributions. Repeated split lines for one category aggregate once per transaction; the whole amount is labelled separately and is not summed again.
- Monthly: income, expenses, net income and closing recorded net balance for every month in range, including zero-activity months. First/last months can be partial. Bars use relative visual widths; all displayed amounts are exact integer-cent results.
- Balances: selected accounts immediately before the range and at its end, plus change. Transfers affect the appropriate account sides. A transfer outside the selected set can make account-balance change differ from net income.

Recorded balances use the saved undated account opening balance plus recorded postings through the relevant date. Account opening dates and market valuations are not tracked. These values are not independently verified historical net worth. Signed debt is negative; the displayed net balance is the sum of selected signed account balances. No account or transaction is silently truncated. Unsupported exact-total ranges fail visibly instead of rounding.

## CSV export

Desktop only, using the existing native file selector. Choose summary, category totals, monthly trends, account balances, or income/expense detail, then explicitly confirm export and choose a .csv destination. Cancellation or failure never changes the workspace. While saving, a second export is disabled. The exported report is the snapshot reviewed when export was requested.

Files use UTF-8 with BOM, quoted text and CRLF lines. Amounts are decimal USD with exact cents. Income/expense detail has one row per transaction/category contribution, not duplicated full transaction amounts; transfers are not in this expense/income export. Every data row includes the selected date range and currency. Text control characters are replaced with spaces. Formula-like leading text is given a visible Text: prefix rather than being emitted as an executable spreadsheet formula. Quoting preserves commas and embedded quotes. This is a display-oriented export, not a lossless round-trip format.

CSV is UNENCRYPTED and may contain account names, payees, category names and transaction identifiers. It is not a workspace backup and does not contain keys, passwords or the full audit/import history. The app sends no export to a service, writes no financial content to logs and opens no exported spreadsheet automatically. Store exports privately. Spreadsheet behavior after manual edits or transformations is outside this application.

## Validation targets

Tests cover totals, account filters, both transfer sides, split contribution aggregation, prior/future/voided activity, date/month/leap boundaries, zero months, exact-number bounds, all supported schema reads, preserved reconciliation locks and CSV encoding. Widget tests cover narrow/wide layouts, category detail, account and date filters, export consent, cancellation, errors, retry and single-flight behavior. Native Windows validation compares encrypted payload and revision before/after reports and actual CSV writes, then reopens SQLite and checks results and statement locks. This additional native test is same-process close/reopen; retained existing security/reconciliation tests still use separate processes.

Primary implementation references: Flutter file_selector 1.1.0 getSaveLocation and XFile.saveTo documentation; OWASP CSV Injection guidance. No claim is made that arbitrary downstream CSV editing is universally safe.
