<h1 align="center">Budgetism</h1>
<p align="center">Your finances. Your control.</p>
<p align="center"><a href="#features">Features</a> | <a href="#download">Download</a> | <a href="#getting-started">Getting started</a> | <a href="#development">Development</a> | <a href="DEVELOPMENT_HANDOFF.md">Handoff</a></p>

**0.1.0-dev.17 development preview.** The user confirmed dev.15 CSV suggestions and all earlier finance workflows. Building on the validated dev.16 calendars, this iteration adds a clearer Home page, direct Settings tools, searchable entry selectors, local payee completion and Save and add another. No new financial-data migration is required. Check [validation](docs/VALIDATION.md) for the exact tested commit and package evidence. Keep independent encrypted backups. This is not a production release.

## Features

| Area | Implemented behavior |
| --- | --- |
| Everyday use | Through-today Home summaries and direct actions, Settings tools, searchable entry choices, local payee completion and explicit repeat entry |
| Local workspace | Encrypted SQLite data, optional password or protected device key, independent encrypted backup/restore |
| Accounts and transactions | USD checking/savings/cash/debt, exact cents, balanced postings, transfers, splits, edits, voids, audit and search |
| Budgets | Monthly allocations, actual spending, three rollover modes, copying and transaction drilldown |
| Scheduled | Bills, income and transfers; manual recording, postpone/skip, pause/resume and history |
| Matching | Explicit linking of an existing actual transaction to an unresolved occurrence without reposting |
| Calendar and forecasts | Read-only dated activity and scheduled daily cash flow, with overdue disclosure and device-only thresholds |
| Import profiles | Saved header/date/sign settings, default categories, explicit application, rename/archive/restore |
| Category history | Inspect prior rule-applied batches and explicitly undo eligible complete batches without moving money |
| CSV imports | Local mapping/review, signed amounts, transfers, existing matches, persistent duplicate receipts |
| Reports | Historical date/account filters, income/spending totals, category drilldown, monthly trends, recorded balances and explicit CSV export |
| Categorization rules | Ordered payee/account/amount/source conditions, preview and explicit selected category changes; protected entries excluded |
| Transaction register | Search words/phrases/exclusions, combined dates/accounts/categories/types/amount/source/status filters, sorting, whole and split totals, protected details |
| CSV category suggestions | Explicit preview and selected rule suggestions for new import rows; manual choices, transfers and duplicate decisions protected |
| Date controls | Calendar selection for schedule/occurrence/statement/rule/register dates, Today/Yesterday, quick ranges and visual budget month/year |
| Statement reconciliation | Selected cleared transactions, exact zero difference, retained history, protected records and explicit latest-statement reopening |

No local cross-device synchronization, bank feeds, multi-currency, automatic posting, reminders or in-app installation is enabled. The web build retains the sample/existing-server interface; it does not provide browser-local financial storage. No server setup is required or added in this milestone.

## Download

Use **Budgetism-Windows-x64-development** from the successful GitHub Actions run recorded in [the handoff](DEVELOPMENT_HANDOFF.md). Do not download the source snapshot or updater-only binary to run the application. Extract the outer artifact ZIP and then the inner **Budgetism-Windows-x64.zip**. Keep Budgetism.exe, every DLL and the data folder together.

Development artifacts are temporary test downloads, not GitHub releases. Before delivery, CI must build/test and scan both the exact Windows ZIP and extracted runtime files with Microsoft Defender. Scan evidence is retained separately. A clean scan is not signing, an independent audit or universal browser reputation. Do not bypass antivirus detections; retain the exact detection name and affected file for investigation.

## Requirements

Windows x64 for the validated portable distribution. No Flutter, developer tools, bank connection or server is required to run the saved local workspace. Other native targets remain unvalidated. Use the same Windows account and its protected key store when replacing only the program folder.

## Getting started

Export a backup before testing a newer build, retain its separate password, and close all Budgetism windows. Extract the new application into its own folder and launch Budgetism.exe. Choose **Open local workspace** for saved records; **Explore with sample data** is temporary and separate. Do not delete or recreate the saved workspace when updating.

Settings provides direct access to categories, categorization rules/history, saved import profiles, statements, workspace security and backups. The previous User options routes remain available. Narrow windows offer the full navigation through More. Local password prompting is optional; independently encrypted exports still require a backup password. There is no recovery of a forgotten backup password or lost device key without a usable backup.

## How to use

Home separates recorded balances through today from future-dated actuals, scheduled plans and forecasts. Its budget shortcut opens the current month. Accounts and Transactions continue to include all recorded dates. See [everyday use](docs/DAILY_USE.md).

Record actual income/expenses/transfers in Transactions. Budget allocations and schedules do not move money. Record a scheduled occurrence only when appropriate, or use Match existing when its actual transaction is already present. CSV preview is read-only until explicit import; review signs, dates, categories, transfer direction and duplicate decisions.

Accounts > Reconcile statements compares outstanding recorded entries with a signed statement closing balance. The first statement starts at the account opening balance; later statements start at the prior completed closing balance. Select only entries cleared on the statement. Finish requires exact zero difference and review confirmation. No balancing transactions are created. Reopen the latest statement with a reason before correcting a protected transaction. Transfers remain protected while reconciled on either side.

Reports reads existing records without a new format upgrade. Select dates/accounts and inspect Overview, Categories, Monthly or Balances. CSV exports are unencrypted, require explicit confirmation and are not backups. See [report semantics](docs/REPORTS.md), including the limits of undated opening balances.

The first reconciliation completion still requires backup/consent for financial schema 5. Viewing alone does not upgrade. Older builds cannot read the upgraded workspace. See [reconciliation semantics](docs/RECONCILIATION.md) and [the new-feature desktop test](docs/WINDOWS_TESTING.md). Earlier budgeting/import/forecast setup tests need not be repeated.

Categorization rules are opened from **User options > Manage categories > Categorization rules**. Add a rule, then generate a dated preview and select the entries to change. Saving a rule does not change transactions, and no rule runs automatically. Category changes can move spending between budgets, but account balances and transaction counts stay unchanged. Reconciled, split, transfer and voided entries are excluded. The first rule save needs backup/consent for financial schema 6; older builds cannot open it. See [categorization rules](docs/CATEGORIZATION_RULES.md).

The local Transactions screen now provides combined search and filters. Search words are ANDed; use quoted phrases or a minus-prefixed exclusion. Amount filters/sorting use the full unsigned transaction amount. A category filter uses that category's exact contribution in income/expense summaries. Transfers are listed separately, never as spending. Voided entries are hidden by default and excluded from totals when shown. Filters stay in this workspace session only. Select a row to inspect it, then explicitly choose Edit transaction when allowed. No format upgrade. See [register behavior](docs/TRANSACTION_REGISTER.md).

CSV import profiles save only mapping settings and defaults inside the encrypted workspace. Select a file and profile, choose Apply selected profile, review its mapping and destination account, then preview before importing. Missing or ambiguous mapped headers are rejected. First profile save requires backup/consent for schema 7, which older apps cannot open. See [saved import profiles](docs/IMPORT_PROFILES.md).

Categorization rules > History shows prior batches and supports reviewed, reasoned, category-only undo when every affected transaction remains unchanged and unprotected. See [category history](docs/CATEGORY_HISTORY.md).

During CSV review, **Review category suggestions** uses saved enabled rules for eligible new rows. Nothing is selected automatically. Acceptance only changes the unsaved preview; the final CSV review/import remains separate. Manual categories, matches, transfers, handled and skipped rows are protected. No new format upgrade. See [CSV rule suggestions](docs/CSV_RULE_SUGGESTIONS.md).

Date fields have a calendar-month icon; choose a day and Use date rather than typing. Optional end dates can be cleared. Register and rule ranges support calendar ranges and common shortcuts, preserving other filters. Budget month navigation now offers a month grid and year picker. Transaction entry has Today and Yesterday. Choosing or cancelling a date never saves a transaction by itself, and locked dates remain protected. See [date controls](docs/DATE_CONTROLS.md).

When adding local transactions, account/category fields are searchable and payees can be completed from existing local history. Save and add another explicitly commits one entry, then clears amount, payee, notes, splits and transfer destination. The ordinary category, account, type and date remain only for the open dialog. Closing does not undo entries already saved. No personal defaults or search terms are written to unencrypted preferences.

## Updates and settings

The public release checker uses caching, rate limits and verified downloads. No release feed exists yet and installation remains disabled pending native end-to-end update validation. Stable filenames are Budgetism.exe and Budgetism-Windows-x64.zip. Settings and data are per-user, not beside the executable.

Windows workspace: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Copying that database alone is not a portable backup. Read [local storage](docs/LOCAL_STORAGE.md) before changing recovery or security behavior.

## Troubleshooting

Keep all supporting files after extraction. An older executable must not open a newer financial schema; use the pre-upgrade exported backup for recovery rather than deleting application data. Stale-window errors require closing and reopening the workspace. A nonzero statement difference requires reviewing entries and balances, not forcing an adjustment. Report the exact message without posting private financial data.

## Development

Read AGENTS.md and DEVELOPMENT_HANDOFF.md before changes. Source is Flutter/Dart with a retained .NET API, PostgreSQL design, Go update helper and non-publishing GitHub Actions validation. Do not enable server deployment, integrations, releases, tags or automatic installation without the relevant authorization.

Flutter remains pinned to 3.47.8 in CI. Generate temporary runners, resolve packages, run analysis and all unit/widget tests, then the native security/schedule/import/matching/reconciliation/rules/undo/profiles/CSV-rules/quick-entry write/read process pairs and planning/report/register preservation tests plus native calendar UI/save/reopen checks. Build Windows/web with APP_VERSION=0.1.0-dev.17. Run the source-layout and package-verifier negative controls, backend ledger contracts, Go tests and the exact-package scan. Record any unperformed checks explicitly.

Supporting details: [everyday use](docs/DAILY_USE.md), [bank connection plan](docs/BANK_CONNECTION_PLAN.md), [date controls](docs/DATE_CONTROLS.md), [next usability priorities](docs/USABILITY_ROADMAP.md), [CSV rule suggestions](docs/CSV_RULE_SUGGESTIONS.md), [import profiles](docs/IMPORT_PROFILES.md), [category history](docs/CATEGORY_HISTORY.md), [register](docs/TRANSACTION_REGISTER.md), [categorization rules](docs/CATEGORIZATION_RULES.md), [status](docs/IMPLEMENTATION_STATUS.md), [recurring](docs/RECURRING.md), [matching](docs/MATCHING.md), [CSV](docs/CSV_IMPORT.md), [planning](docs/PLANNING.md), [reconciliation](docs/RECONCILIATION.md), [reports](docs/REPORTS.md), [validation](docs/VALIDATION.md), and [development notes](docs/releases/0.1.0-dev.17.md).
