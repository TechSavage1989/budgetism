<h1 align="center">Budgetism</h1>
<p align="center">Personal money tracking, budgets and cash-flow planning with private local storage.</p>
<p align="center"><a href="#download">Download</a> | <a href="#getting-started">Get started</a> | <a href="#features">Features</a> | <a href="#updates-and-settings">Updates</a> | <a href="#development">Development</a></p>

**0.1.0-dev.7 development preview. Use fictional records and keep independent backups.** The user confirmed dev.6 calendar/forecast behavior and the earlier budgeting, persistence, recurring and optional-password workflows. This iteration adds reviewed CSV importing; check the [handoff](DEVELOPMENT_HANDOFF.md) for the exact tested commit and build.

## Calendar and scheduled cash flow

Dev.6 adds a read-only monthly calendar and daily 30/60/90/365-day cash-flow forecasts. Select an individual account or all checking/savings/cash accounts, inspect daily activity, and set device-only low-balance minimums. Existing records and financial/security formats do not change when opening these screens.

Starting balances include recorded entries dated today or earlier. Future-dated recorded entries enter on their effective dates. Confirmed occurrences appear only through their actual transaction; unresolved overdue items are disclosed separately and are not silently treated as paid. Budget allocations and unscheduled spending are not forecast. See [planning rules](docs/PLANNING.md) and [Windows test](docs/WINDOWS_TESTING.md).

The build workflow now requires a Microsoft Defender scan of the exact Windows ZIP and its extracted contents before delivering the application artifact. Scan evidence is retained separately. A clean build-time scan is not code signing, an independent audit, or an explanation of an earlier browser alert. Inspect the exact run rather than assuming the scan passed.

## CSV statement import

Choose **Transactions > Import CSV** or **User options > Import CSV statement**. Map the date, description and signed amount (or separate debit/credit columns), preview every row, and decide whether to skip, import, transfer or match an existing transaction. CSV files stay on your device. Invalid rows and possible duplicates require review. New imports commit atomically and keep encrypted history so the same file cannot silently post twice.

Use **Use fictional example CSV** with a test account for the first check. Export a backup before the first saved import: financial schema 4 requires dev.7 or newer afterward. Existing accounts, budgets, schedules, forecasts and the optional-password setting are preserved. CSV is UTF-8 with headers and USD decimal-point values; automatic bank/schedule matching, reconciliation and other statement formats are not included. See [CSV import behavior](docs/CSV_IMPORT.md) and [Windows testing](docs/WINDOWS_TESTING.md).

## Features

Budgetism is a Windows-first personal finance app with an encrypted local workspace. A server and bank connection are not required for local use.

- Save accounts, categories, transactions and history. Choose an optional workspace password or device-unlocked access.
- Record exact-USD income, expenses, transfers and credit-card payments; edit, split or void actual transactions.
- Set monthly category budgets, review actual spending, copy allocations, and optionally roll over unused money or overspending.
- Plan weekly, every-two-weeks, monthly and yearly bills, paychecks and transfers. Review upcoming/overdue dates; record, postpone or skip an occurrence.
- Review a recorded occurrence's transaction, pause/resume schedules and retain resolved history.
- Export password-encrypted backups, restore a workspace, search transactions and retain light/dark appearance.
- View the financial calendar, scheduled cash-flow projections and device-only low-balance warnings.
- Import CSV statements through explicit mapping/review, match existing entries and retain encrypted import history.
- Keep the separate temporary sample-data mode and existing-server client.

Planned, not implemented: local cross-device synchronization, bank feeds, multi-currency local accounts, reconciliation, automatic transaction matching, reminders and validated update installation. Recurring schedules never execute payments or post automatically. Schedule templates use one category/destination; actual transactions can be split after recording.

## Download

No GitHub release has been published. Windows preview packages are temporary artifacts under [GitHub Actions](https://github.com/TechSavage1989/budgetism/actions). Select only the successful run for the exact version/commit recorded in the handoff. Artifact downloads may require GitHub sign-in. Development branches can be ahead of main; do not confuse a source snapshot with the compiled application.

The [releases index](https://github.com/TechSavage1989/budgetism/releases) is the future public updater feed, not the current CI download location. No stable latest-release shortcut applies yet.

## Requirements

Windows 64-bit is the primary portable target. Keep the complete extracted folder, including DLLs and data. A writable Windows user-profile application-data folder is required. Local mode needs no administrator permissions, server or provider account.

Browser builds retain sample mode and the existing-server interface, not a local financial workspace. Android, iOS, macOS and Linux distributions are not validated by this preview. Building requires the configured Flutter SDK and native Windows toolchain; the existing API source requires .NET 10. No server deployment is included.

## Getting started

1. Before upgrading, export an encrypted backup from your working version and keep its password. Close all Budgetism windows.
2. Download Budgetism-Windows-x64-development from the verified successful Actions run. Extract its outer ZIP, then extract Budgetism-Windows-x64.zip inside it into a separate testing folder.
3. Run **Budgetism.exe** with its support files under the same Windows account. Do not run inside the archive or move only the executable.
4. Select **Open local workspace**. Existing records and the security setting remain in your Windows profile. New workspaces offer password-free access by default, with optional password protection.
5. Create or open a test account. Use Transactions, Budgets and Scheduled for the workflows below. The profile menu contains Workspace security, Manage categories and Backups and storage.

Sample mode is temporary and never copies its invented records into your saved workspace. Device-unlocked mode depends on your Windows profile/OS key store. Anyone using that Windows account can open it. There is no password/key recovery. Export portable backups rather than copying only the database.

## How to use

**Accounts and transactions:** Add checking, savings, cash, credit-card, loan, asset or liability accounts. Opening debt is negative. Transfers/card payments are not additional spending. Edit a transaction to change its details or split its categories. Void removes its financial effect while keeping history.

**Budgets:** Select a month and edit an expense category's allocation. Review allocated, carried-in, spent and remaining values. Rollover can be off, unused money only, or unused money and overspending. Copy previous month copies allocations/rules, not spending. Allocating a budget never moves account money. Select a category to inspect contributing expenses.

**Scheduled:** Add a schedule, choose its account, category/destination, amount, first date and frequency. Upcoming includes all unresolved overdue dates plus the selected future range. Record transaction explicitly creates one actual entry with the confirmed amount/date; Postpone changes only this occurrence; Skip settles it without money movement. Neither planning nor postponing changes balances. Use History to open recorded transactions. Voiding one does not regenerate its occurrence.

Schedule financial edits affect unconfirmed dates. To change recurrence dates, pause the old schedule and create a new one. Short months use their last day, then return to the original anchor. Pausing hides unresolved dates until resumed; nothing catches up automatically. Do not record the same real payment manually and again through Scheduled: automatic schedule matching is not implemented. Record the schedule first, then match its actual transaction during CSV review.

**Workspace upgrade:** Export a backup before saving your first schedule in an existing workspace. The explicit confirmation upgrades the financial schema to 3 while preserving financial records, budgets and security mode. Older builds cannot open it afterward. Opening the app alone does not upgrade old data. See [Windows testing](docs/WINDOWS_TESTING.md).

**Security:** User options > Workspace security controls the password requirement. Existing protected data stays protected until you change it. Device-unlocked access uses an OS-protected random key; it does not store your password in preferences. Missing keys never trigger an automatic reset.

**Backups:** Export a .budgetism file with a separate password. Restore replaces the complete workspace only after confirmation, validates records before committing, and preserves the destination security mode. Back up current data first. Keep exported backups and their passwords separately; there is no undo-restore screen.

**Existing server:** The server client remains for an already configured private system. Local records are not uploaded or synchronized. Calendar and forecasts use saved local records only; they are not enabled for server workspaces.

## Updates and settings

Update discovery retains startup, five-minute active and focus-return checks, ETags, cooldowns and backoff. Offline/failed checks do not claim the app is up to date. Downloads are manual and require an expected SHA-256 digest, which is not publisher signing.

**Install and restart remains disabled** until native replacement/relaunch/rollback is validated. CI does not create releases or tags.

- Stable executable: Budgetism.exe; portable package: Budgetism-Windows-x64.zip.
- Windows data: %LOCALAPPDATA%\Budgetism\finance\workspace.sqlite3.
- Financial payloads remain encrypted in both local access modes; database headers/revisions are not. See [storage design](docs/LOCAL_STORAGE.md).
- Theme/update cache and downloads remain in per-user storage, not the executable folder. Updater logs use %LOCALAPPDATA%\Budgetism\logs\updater.log.

Do not delete application-data files to troubleshoot. Read [recurring behavior](docs/RECURRING.md) and [development notes](docs/releases/0.1.0-dev.7.md) for this iteration.

## Troubleshooting

**Data missing:** Open the local workspace, not sample mode, under the original Windows account.

**Password/key unavailable:** Preserve the database and original OS profile. Use a valid exported backup and its password for recovery. The app cannot reset encryption credentials to decrypt the old data.

**Changed in another window:** Refresh or reopen before retrying. Stale financial, budget and occurrence changes are rejected rather than silently overwriting records.

**Save fails:** Editors keep entered values. Correct the issue and retry. A failed confirmation must not be treated as a recorded transaction.

**An occurrence is already recorded/skipped:** Review History. It cannot be recorded twice under a different request, even after restart or transaction voiding.

**No release / install disabled:** Expected. Obtain development builds from the verified Actions run, not the empty release feed.

## Development

Read [AGENTS.md](AGENTS.md), [DEVELOPMENT_HANDOFF.md](DEVELOPMENT_HANDOFF.md) and [implementation status](docs/IMPLEMENTATION_STATUS.md) first. The client is in apps/client, API in services/api, updater in tools/updater, and build scripts in scripts. No new server setup is required or provided.

From apps/client on the configured Flutter Windows build host:

~~~powershell
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter test integration_test/device_restart_test.dart -d windows
flutter test integration_test/schedule_restart_test.dart -d windows
flutter test integration_test/planning_native_test.dart -d windows
flutter test integration_test/import_restart_test.dart -d windows
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.7
~~~

CI also runs the security, schedule and import tests in distinct write/read processes. The planning test is a same-process SQLite reopen check. CI builds from an extracted source archive without .git. The handoff records exact flags and evidence. Run python scripts/check_layout.py --self-test and python scripts/verify_windows_package.py --self-test from the source root. Build/package commands and remaining gates are in the handoff and [validation log](docs/VALIDATION.md). Do not infer a test pass merely from a listed command.
