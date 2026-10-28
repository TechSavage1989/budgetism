# Budgetism dev.5 Windows test

Use [successful dev.5 build 40616768105](https://github.com/TechSavage1989/budgetism/actions/runs/40616768105), tested application commit 39353fd46314aa22866ff85dcf0aad352fa39601, not a source ZIP or an older run. Download Budgetism-Windows-x64-development, extract the artifact and its inner Budgetism-Windows-x64.zip, keep all supporting files, and launch Budgetism.exe under the same Windows account.

## Before opening the next build

In the working dev.4 app, choose User options > Backups and storage > Export encrypted backup. Keep the backup and its independent password separately. Close every Budgetism window. Extract dev.5 into its own testing folder. Do not copy, delete or replace the per-user database.

## Existing records

Confirm version 0.1.0-dev.5. Open the saved local workspace and verify accounts, transactions, budgets and the optional-password setting. Opening does not automatically convert an existing financial schema.

## Recurring test using fictional records

1. Record the balance of a test checking account and the current spending in a test expense category.
2. Open Scheduled > Add schedule. Name it Test bill, choose that account/category, expected amount 10.00, Monthly, and today's date as the first due date.
3. After exporting the backup, confirm the dev.5 format-upgrade notice and Save schedule. Existing records should stay intact. The account balance and actual budget spending should not change yet.
4. In Upcoming, choose Record transaction for that Test bill. Use actual amount 10.00 and today's recorded date, then confirm. The balance should fall by 10.00, expense spending should increase by 10.00, and History should contain the recorded occurrence with one linked transaction.
5. Close and reopen dev.5. Confirm the schedule, budget effect, transaction and security preference are retained. The same occurrence must not appear as due again.
6. For a later occurrence, choose Postpone and a later date. It should move only that occurrence, without another transaction or a change to subsequent original dates. Skip a different test occurrence and verify History and unchanged balances.

The first saved schedule upgrades the financial schema. Do not use dev.4 or earlier against it afterward. Keep the pre-upgrade backup for recovery. Recurring schedules do not match existing manual transactions yet: recording a real payment both manually and through Scheduled would double count it. Use fictional entries during this preview.

This does not configure a server, move real money, send reminders, or enable updater installation. Exported backups still require their own password even when local password prompting is off.
