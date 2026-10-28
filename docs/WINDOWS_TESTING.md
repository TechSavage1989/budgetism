# Budgetism dev.7 Windows test

Download only the verified Windows artifact from the exact successful run recorded in the handoff. Export an encrypted backup from dev.6, retain its independent password, close every Budgetism window, and extract the entire new portable package in a separate testing folder. Keep Budgetism.exe, its DLLs and data directory together under the same Windows user account. Do not replace or recreate the per-user workspace.

## Test only the new import workflow

Budgeting and forecasting have already been user-confirmed; do not repeat those setup exercises.

1. Confirm version 0.1.0-dev.7 and open the existing local workspace. Verify the optional-password preference remains.
2. Create a fictional checking account named CSV test with a 1000.00 opening balance.
3. Open Transactions > Import CSV (also in User options). Choose CSV test as the destination and select Use fictional example CSV.
4. Leave the displayed YYYY-MM-DD and signed-amount mapping. Preview the two fictional rows: +500.00 income and -200.00 expense. Confirm the date, sign and visible categories. The actual balance must still be 1000.00 during preview.
5. After exporting the backup, accept the import-format upgrade and review checkbox. Import the two selected rows. The account should show 1300.00 and exactly two new transactions.
6. Close and reopen dev.7. Open the same example again on the same day with the same account and preview it. Both rows should be already handled, with zero selected and no additional balance change. Import history should list the two receipts.

The example generates today's date. For an exact-file repeat across different days, save and reuse the same fictional CSV rather than generating a new example with different dates. Renaming that same file must not bypass duplicate detection.

After the first import, older builds cannot open the upgraded workspace. Keep the pre-import backup for recovery. Existing transaction matching does not settle unrecorded schedules. Do not enter or import a real payment twice, and do not use this preview as your only record of finances.

The same build's security-evidence artifact contains Defender output for the exact package. A clean scan is limited to its engine/signatures/time and does not establish code signing or universal browser reputation.
