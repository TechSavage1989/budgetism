# Budgetism dev.6 Windows testing

Use only the successful dev.6 Windows artifact linked after validation. Export an encrypted backup in the working application, close all Budgetism windows, and extract the complete portable folder into a new testing folder. Launch Budgetism.exe under the same Windows account. Do not delete, copy over or recreate the per-user workspace.

## Existing data

Open local workspace, confirm version 0.1.0-dev.6, verify existing accounts/transactions/schedules and password preference. Merely opening Calendar or Forecasts must not trigger migration or alter balances. Budgeting was already tested; this test focuses on planning.

## Forecast test

Use a fictional checking account with a 1000.00 opening balance. Create a monthly income schedule for 500.00 tomorrow and an expense schedule for 200.00 the following day, using existing fictional categories. Open Forecasts and select this test account. The starting balance should be 1000.00, tomorrow 1500.00, and the following day 1300.00. Actual account balances must not change merely from opening these screens.

Select the dates in Calendar and inspect the two events and per-account changes. Confirm one occurrence through Scheduled using its planned date and amount. It must appear as Recorded (or Recorded future), not a second scheduled item. The future projection must not double count it. Restore/reopen only using the existing supported controls; no new financial-format conversion is needed by this feature.

Set a low-balance minimum for the test account, close/reopen the app and confirm that device preference remains. It is not included in encrypted financial backups. Test an overdue item separately: it should be disclosed, not silently deducted on today's date. Do not manually enter the same payment and also record its schedule.

## Security evidence

Check the same build's Budgetism-Windows-security-evidence artifact for the exact archive hash and Defender output. A clean scan is limited to that engine/signature/time and does not guarantee every browser will trust an unsigned build. Do not disable antivirus or add exclusions if another alert occurs; record its detection name and affected file.
