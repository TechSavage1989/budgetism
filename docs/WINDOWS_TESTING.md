# Budgetism dev.16 Windows test

Use [successful dev.16 run 40816063799](https://github.com/TechSavage1989/budgetism/actions/runs/40816063799), application ef07b3438605a3de215c4cf1f75bccf015f519fc, Windows artifact 12873575129. Exact package hashes and scanning evidence are recorded in VALIDATION.md. Export an encrypted backup from dev.15, retain its password and close Budgetism. Extract the development artifact and its inner Budgetism-Windows-x64.zip into a separate folder, keep all supporting files together, confirm 0.1.0-dev.16 and open the existing workspace under the same Windows account. No new workspace-format upgrade is expected.

## Test usability without adding financial records

1. Open Scheduled > Add schedule. Beside First due date, select the calendar-month icon, choose a day and Use date. The date field should fill automatically. Try Last scheduled date and Clear, then cancel the schedule without saving.
2. In Accounts > Reconcile statements > Start reconciliation, try the statement ending date calendar. Cancel without completing a statement. This must not change balances, transaction count or statement history.
3. In Transactions > Filters, choose Last 7 days, then All dates. Dates should change together; search/account/category filters should be retained. Open Choose date range and cancel. No saved transaction changes.
4. In Budgets, select the displayed month, click the year to choose a year visually, select a month and Go to month. No year typing is required. This month returns the selector to the current month.

The Today icon is a shortcut; the calendar-month icon opens the calendar. Typing YYYY-MM-DD remains available. Existing saved schedules keep their recurrence dates locked. The transaction editor also provides Today and Yesterday; those remain unsaved until Save transaction. No earlier import, budget-calculation or rule exercises need repetition.
