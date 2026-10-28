# Budgetism dev.13 Windows test

Use [successful dev.13 run 40781260879](https://github.com/TechSavage1989/budgetism/actions/runs/40781260879), application commit 6f6e33c58c297fc55dde40ce74aae9a64f2acc7a. Download artifact 12856818776, Budgetism-Windows-x64-development; exact package hashes and scan evidence are in VALIDATION.md. Export an encrypted backup from working dev.12, retain its password and close all Budgetism windows. Do not select source or updater-only artifacts. Extract the outer artifact and inner Budgetism-Windows-x64.zip into a separate folder. Keep Budgetism.exe, all DLLs and data together. Open the existing workspace under the same Windows account. Do not replace or recreate its database.

## Test category history and undo only

1. Confirm 0.1.0-dev.13. Open User options > Manage categories > Categorization rules > History. Reuse the fictional Rule test batch created earlier; no new account or expense is needed.
2. Open that batch. Check its payee, original Other spending category, applied Groceries category and 12.34 amount. History from dev.11/dev.12 should be visible. Opening it must not change finances.
3. Only when the complete batch contains your fictional test data, enter a reason, check the full-batch review confirmation and select Undo this batch. Its category returns to Other spending. Account balance, amount and stored transaction count must not change. Budget/report category totals recalculate.
4. Close/reopen dev.13. The batch should be marked Undone, its reason retained, and a second undo unavailable. The original saved rule must still exist unchanged, as must prior statements, imports, schedule links and your optional-password preference.
5. No schema-upgrade prompt is expected. A batch containing an edited, voided or reconciled transaction should be blocked completely, not partially restored. Do not reopen a real statement just to force this test. A later explicit rule preview may suggest recategorizing the test entry again, but nothing runs automatically.

Keep independent encrypted backups. This preview supports undo of rule-applied category batches, not all transaction edits or deletion recovery. Inspect the exact build's Defender evidence; a clean scan is not publisher signing or universal browser reputation.
