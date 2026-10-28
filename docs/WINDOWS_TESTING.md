# Budgetism dev.11 Windows test

Use only the completed and verified Windows build recorded after validation. Export an encrypted backup from working dev.10 and retain its separate password. Close all Budgetism windows. Download Budgetism-Windows-x64-development, not the source or updater-only artifact. Extract the outer ZIP, then its inner Budgetism-Windows-x64.zip into a separate folder. Keep Budgetism.exe, DLLs and data together. Use the same Windows account and existing workspace; do not replace its database.

## Test categorization rules only

Earlier feature setup tests are already confirmed and should not be repeated.

1. Confirm 0.1.0-dev.11. In an existing fictional account, record one new expense of 12.34 with payee Rule test store and category Other spending. Use today's date. Do not reconcile this new entry. Note its account balance and transaction count after this one expense is recorded.
2. Open User options > Manage categories > Categorization rules > Add rule. Name it Rule test. Use Expense, Contains, payee text Rule test, priority 10 (or another unused priority), and leave account/source/amount limits at their defaults. Set Only when current category is to Other spending and Set category to Groceries.
3. After exporting the backup, approve the saved-rules format upgrade and Save rule. The expense category must still be Other spending; saving the definition alone changes no transaction.
4. Generate preview for a range covering the expense date. Select its proposed category change, confirm the review checkbox and Apply selected. The category becomes Groceries. Amount, transaction count and account balance remain unchanged. Budget/report category totals reflect the new category.
5. Close and reopen dev.11. The rule and changed category remain. Generate the same preview: that entry should no longer require a change. Existing optional-password preference, prior statements, imports and schedule links remain intact.

Only the first rule save upgrades the financial payload to schema 6. Older builds cannot open that workspace afterward. Viewing alone does not upgrade. Keep the pre-upgrade backup. Split, reconciled, transfer and voided entries are excluded. Rules never run automatically, and the preview has no batch undo action. No server setup is needed.

Inspect the exact build's Defender security evidence. A no-threats result is not publisher signing or a guarantee of browser reputation.
