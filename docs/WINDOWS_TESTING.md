# Budgetism dev.8 Windows test

Download only the verified successful dev.8 application artifact recorded in the handoff, not an updater-only or source ZIP. Export an encrypted backup from the working dev.7 app and retain its separate password. Close all Budgetism windows, extract the complete new portable package into its own folder, and run Budgetism.exe under the same Windows account. Keep all DLLs/data files together; do not replace or recreate the per-user workspace.

## Test matching, not previous milestones again

1. Confirm version 0.1.0-dev.8 and open the saved local workspace. Existing records and optional-password preference should remain.
2. Use a fictional imported expense already in Transactions, or enter a fictional expense once. Note its account, category, amount and actual date.
3. Create a monthly expense schedule with the same account/amount and that date as the first due date. Use an end date equal to the first date to keep this test to one occurrence. Creating this plan must not post the expense again.
4. Note the current account balance, budget spending and transaction count. In Scheduled > Upcoming, choose Match existing for that occurrence. Do not choose Record transaction.
5. Select the existing actual. Review its amount/date/categories, tick the confirmation and choose Link without new transaction. There should be no new transaction and no change to account balance or actual budget spending.
6. History should show Matched. The occurrence should no longer be due, and Calendar/Forecasts should not add its planned amount again.
7. Close and reopen dev.8. Confirm the same single transaction and matched history remain. An imported transaction's import history should still be present.

Use Include different amounts only for a deliberate variable-bill test. The actual amount/categories/date stay unchanged. Suggestions default to seven days around the due date; 30/90-day ranges are available. Only unlinked, non-voided transactions of the same type/account qualify; transfer direction must match. This preview has no unlink action, so review carefully.

Matching introduces no new financial-format upgrade on an existing recurring/import workspace. No server setup or previous budgeting/forecasting setup test is required. Inspect the same run's Defender security-evidence artifact. Any new download detection still requires its exact name/file; a clean build-time scan is not universal reputation or publisher signing.
