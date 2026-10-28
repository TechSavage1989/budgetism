<h1 align="center">Budgetism</h1>
<p align="center">Your finances. Your control.</p>
<p align="center"><a href="#features">Features</a> | <a href="#download">Download</a> | <a href="#getting-started">Getting started</a> | <a href="#development">Development</a> | <a href="DEVELOPMENT_HANDOFF.md">Handoff</a></p>

**0.1.0-dev.9 development preview.** The user confirmed dev.8 matching and earlier finance workflows. This iteration adds statement reconciliation. Check [validation](docs/VALIDATION.md) for the exact tested commit and build before downloading. Use fictional records and keep independent encrypted backups. This is not a production release.

## Features

| Area | Implemented behavior |
| --- | --- |
| Local workspace | Encrypted SQLite data, optional password or protected device key, independent encrypted backup/restore |
| Accounts and transactions | USD checking/savings/cash/debt, exact cents, balanced postings, transfers, splits, edits, voids, audit and search |
| Budgets | Monthly allocations, actual spending, three rollover modes, copying and transaction drilldown |
| Scheduled | Bills, income and transfers; manual recording, postpone/skip, pause/resume and history |
| Matching | Explicit linking of an existing actual transaction to an unresolved occurrence without reposting |
| Calendar and forecasts | Read-only dated activity and scheduled daily cash flow, with overdue disclosure and device-only thresholds |
| CSV imports | Local mapping/review, signed amounts, transfers, existing matches, persistent duplicate receipts |
| Statement reconciliation | Selected cleared transactions, exact zero difference, retained history, protected records and explicit latest-statement reopening |

No local cross-device synchronization, bank feeds, multi-currency, automatic posting, reminders or in-app installation is enabled. The web build retains the sample/existing-server interface; it does not provide browser-local financial storage. No server setup is required or added in this milestone.

## Download

Use **Budgetism-Windows-x64-development** from the successful GitHub Actions run recorded in [the handoff](DEVELOPMENT_HANDOFF.md). Do not download the source snapshot or updater-only binary to run the application. Extract the outer artifact ZIP and then the inner **Budgetism-Windows-x64.zip**. Keep Budgetism.exe, every DLL and the data folder together.

Development artifacts are temporary test downloads, not GitHub releases. Before delivery, CI must build/test and scan both the exact Windows ZIP and extracted runtime files with Microsoft Defender. Scan evidence is retained separately. A clean scan is not signing, an independent audit or universal browser reputation. Do not bypass antivirus detections; retain the exact detection name and affected file for investigation.

## Requirements

Windows x64 for the validated portable distribution. No Flutter, developer tools, bank connection or server is required to run the saved local workspace. Other native targets remain unvalidated. Use the same Windows account and its protected key store when replacing only the program folder.

## Getting started

Export a backup before testing a newer build, retain its separate password, and close all Budgetism windows. Extract the new application into its own folder and launch Budgetism.exe. Choose **Open local workspace** for saved records; **Explore with sample data** is temporary and separate. Do not delete or recreate the saved workspace when updating.

User options contains Workspace security, Manage categories, Backups and storage, Import CSV statement, and Reconcile statements. Local password prompting is optional; independently encrypted exports still require a backup password. There is no recovery of a forgotten backup password or lost device key without a usable backup.

## How to use

Record actual income/expenses/transfers in Transactions. Budget allocations and schedules do not move money. Record a scheduled occurrence only when appropriate, or use Match existing when its actual transaction is already present. CSV preview is read-only until explicit import; review signs, dates, categories, transfer direction and duplicate decisions.

Accounts > Reconcile statements compares outstanding recorded entries with a signed statement closing balance. The first statement starts at the account opening balance; later statements start at the prior completed closing balance. Select only entries cleared on the statement. Finish requires exact zero difference and review confirmation. No balancing transactions are created. Reopen the latest statement with a reason before correcting a protected transaction. Transfers remain protected while reconciled on either side.

The first reconciliation completion requires backup/consent for financial schema 5. Viewing alone does not upgrade. Older builds cannot read the upgraded workspace. See [reconciliation semantics](docs/RECONCILIATION.md) and [the new-feature desktop test](docs/WINDOWS_TESTING.md). Earlier budgeting/import/forecast setup tests need not be repeated.

## Updates and settings

The public release checker uses caching, rate limits and verified downloads. No release feed exists yet and installation remains disabled pending native end-to-end update validation. Stable filenames are Budgetism.exe and Budgetism-Windows-x64.zip. Settings and data are per-user, not beside the executable.

Windows workspace: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Copying that database alone is not a portable backup. Read [local storage](docs/LOCAL_STORAGE.md) before changing recovery or security behavior.

## Troubleshooting

Keep all supporting files after extraction. An older executable must not open a newer financial schema; use the pre-upgrade exported backup for recovery rather than deleting application data. Stale-window errors require closing and reopening the workspace. A nonzero statement difference requires reviewing entries and balances, not forcing an adjustment. Report the exact message without posting private financial data.

## Development

Read AGENTS.md and DEVELOPMENT_HANDOFF.md before changes. Source is Flutter/Dart with a retained .NET API, PostgreSQL design, Go update helper and non-publishing GitHub Actions validation. Do not enable server deployment, integrations, releases, tags or automatic installation without the relevant authorization.

Flutter remains pinned to 3.47.8 in CI. Generate temporary runners, resolve packages, run analysis and all unit/widget tests, then the native security/schedule/import/matching/reconciliation write/read process pairs and planning test. Build Windows/web with APP_VERSION=0.1.0-dev.9. Run the source-layout and package-verifier negative controls, backend ledger contracts, Go tests and the exact-package scan. Record any unperformed checks explicitly.

Supporting details: [status](docs/IMPLEMENTATION_STATUS.md), [recurring](docs/RECURRING.md), [matching](docs/MATCHING.md), [CSV](docs/CSV_IMPORT.md), [planning](docs/PLANNING.md), [reconciliation](docs/RECONCILIATION.md), [validation](docs/VALIDATION.md), and [development notes](docs/releases/0.1.0-dev.9.md).
