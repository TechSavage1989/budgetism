<h1 align="center">Budgetism</h1>
<p align="center">Personal money tracking with private local storage and a self-hosted, cross-device roadmap.</p>
<p align="center"><a href="#download">Download</a> | <a href="#getting-started">Get started</a> | <a href="#features">Features</a> | <a href="#updates-and-settings">Updates</a> | <a href="#development">Development</a></p>

**0.1.0-dev.3 development preview. Use test data, not your only copy of real financial information.** The user confirmed dev.2 launches and retains local records after restarting. This version makes local password protection optional; it is not a production release.

## Features

Budgetism is a Windows-first personal finance app. The current native client offers an encrypted, device-local workspace without requiring a server. Private cross-device synchronization remains planned, not implemented.

- Create and reopen a saved local workspace, with optional password protection and encrypted accounts, categories, transactions, and audit history.
- Record income, expenses, transfers, and credit-card payments using exact USD cents and balanced postings.
- Edit accounts and transactions; split income or expenses across categories; void a transaction without erasing its audit history.
- Search payees, notes, accounts, and categories; filter the register by account.
- Add or rename categories, export encrypted backups, and restore a complete workspace.
- Preserve the existing dashboard, sample-data demo, existing-server client, light/dark appearance, and release checking. Theme preference now survives restarts.

Not yet implemented: cross-device synchronization of local data, budgets, scheduled bills, forecasting, bank feeds, multi-currency local accounts, reconciliation, password recovery, idle auto-lock, and validated update installation. The local audit is retained in storage; there is no audit-browser screen yet.

## Download

There is no published application release. Preview Windows packages are temporary artifacts under [GitHub Actions](https://github.com/TechSavage1989/budgetism/actions), not releases. Only use a package from a successful run for the intended source commit. Artifact downloads may require GitHub sign-in.

The [releases index](https://github.com/TechSavage1989/budgetism/releases) remains the future public update feed. Do not use a latest-release shortcut while there are no stable releases. Source and build instructions are available in this repository.

## Requirements

- Windows 64-bit is the primary portable target. Keep the entire extracted application folder together, including its DLLs and data directory.
- A writable per-user application-data directory is required for local workspaces. Password-free mode also requires working OS-protected key storage. A server, financial-provider account, and administrator privileges are not required for this mode.
- Browser builds retain sample mode and the existing server client. Browser local financial persistence is deliberately disabled.
- Android, iOS, macOS, and Linux remain planned targets; they are not validated distributions in this preview.
- Building requires Flutter with Dart compatible with the dependencies in apps/client/pubspec.yaml, and native Windows build tools. The existing backend source requires .NET 10 to build; no server deployment is added here.

## Getting started

1. Download the Windows development artifact from the relevant successful Actions run. Extract the artifact, then extract Budgetism-Windows-x64.zip if it is nested inside.
2. Open the extracted Budgetism folder and run **Budgetism.exe**. Do not run from inside the ZIP or move the executable away from its supporting files.
3. Select **Open local workspace** to create saved test data. **Require a password to open this workspace** is off by default for a new workspace. Turn it on and choose a password of at least 14 characters when desired.
4. Create an account, then add a transaction. Close and reopen Budgetism and select **Open local workspace**. Password-free workspaces open without a password prompt; protected workspaces ask for their password.
5. Use the top-right **User options** menu for **Workspace security**, **Manage categories**, **Backups and storage**, and **Close workspace** or **Lock workspace**.

Existing dev.2 workspaces remain password-protected until you change them. Open yours once with its current password, choose **User options > Workspace security**, turn off **Require a password to open this workspace**, confirm your current password, and select **Save**. Accounts and transactions are preserved. Turn the setting back on to choose a new password.

There is no password recovery. Device-unlocked data depends on the original OS user/key store. Anyone using that OS account can open it. New backup exports use a separate password chosen during export; old backups still use their original workspace password. Keep backup passwords separately.

To explore without saving financial records, select **Explore with sample data**. Demo records remain temporary and are not copied into your local workspace.

## How to use

**Accounts:** Add a checking, savings, cash, credit-card, loan, asset, or liability account. Opening debt is a negative balance. In local mode, select an account to edit it. Changing the opening balance adjusts the starting position; it is not income or spending.

**Transactions:** Add an expense, income, or transfer. Credit-card payments are transfers, not another expense. Select a local transaction to edit its account, amount, category, date, payee, or notes. Enable **Split across categories** and allocate the exact total. **Void transaction** removes its effect from balances while retaining the previous record in the local audit.

**Categories:** Use the profile menu to add income/expense categories or rename them. Referenced categories are not deleted. Category names do not change existing transaction amounts.

**Backups:** Export an encrypted .budgetism file to a location you choose. Restore replaces the entire local workspace after confirmation and validates the backup before committing it. The current workspace security setting remains unchanged. New exports ask for a backup-only password, even when local password protection is off. Export a separate backup before restoring; the app does not provide an undo-restore screen.

**Budgets and forecasts:** These screens remain clearly labelled placeholders. Local entries are recorded transactions, not scheduled forecasts.

**Existing server:** The prior server client is preserved for an already configured private system. Local records are not uploaded to it. Do not assume opening the server client transfers or synchronizes your local workspace.

## Updates and settings

Release checks retain startup, five-minute active, and focus-return behavior with ETags, single-flight protection, cooldowns, and backoff. Failed checks do not claim the app is up to date. Download is manual and requires an expected SHA-256 digest. A matching digest is not publisher signing.

**Install and restart remains disabled.** Native Windows install, visible-window health detection, rollback, and settings preservation still require complete end-to-end validation. No release or tag is created by the build workflow.

- Stable launch filename: Budgetism.exe.
- Windows local workspace: %LOCALAPPDATA%\Budgetism\finance\workspace.sqlite3.
- Local financial payload: AES-256-GCM encryption with either password-derived keys or random OS-protected device keys. Database headers and revision metadata are not encrypted. See [local storage design](docs/LOCAL_STORAGE.md).
- Theme and public release cache: per-user SharedPreferences storage, not beside the executable.
- Update downloads: per-user application-support updates/staging. Updater logs: %LOCALAPPDATA%\Budgetism\logs\updater.log.
- Workspace passwords and private-server login tokens are not saved. Device mode saves only a random encryption key in OS-protected storage, not in preferences. Password mode asks again after closing or locking.

Keep the older executable in a separate folder when testing this preview. Dev.2 cannot read format-2 workspaces after a security-mode change. Keep a separate encrypted backup rather than trying to downgrade the database. Do not delete application-data files to troubleshoot a failed unlock.

## Troubleshooting

**Local changes missing:** Confirm you opened the saved local workspace rather than the temporary demo, under the same Windows user account.

**Wrong password or damaged workspace:** Nothing is reset automatically. Recheck the password and preserve the database. There is no password-reset mechanism that can decrypt it.

**Device unlock unavailable:** Preserve the database. Use the original OS user profile/key store, or restore a separately exported backup in a new workspace on another profile/device. There is no plaintext fallback or automatic reset.

**Changed in another window:** Refresh and reopen the edit. After a security-mode change in another window, close and reopen the workspace. The app refuses stale writes rather than silently overwriting another window's changes.

**Save fails:** Local transaction and account editors stay open with their values. Correct the problem and retry; do not assume the displayed edit was committed.

**No release found / install disabled:** Expected until release publication and native updater validation are separately completed.

## Development

Read [AGENTS.md](AGENTS.md), [DEVELOPMENT_HANDOFF.md](DEVELOPMENT_HANDOFF.md), and [implementation status](docs/IMPLEMENTATION_STATUS.md) first.

The Flutter client and tests are in apps/client. Local ledger, encryption, SQLite adapter, and dialogs are under apps/client/lib/local. Existing .NET source is under services/api; the Go updater is under tools/updater. Scripts and CI never publish releases automatically.

From apps/client on a Flutter-capable Windows machine:

```powershell
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.3
```

From the source root:

```powershell
python scripts/check_layout.py --self-test
python scripts/check_layout.py
cd tools/updater
go test ./...
cd ../..
dotnet build services/api/Budgetism.Api.csproj --configuration Release
dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release
```

The CI workflow builds the Go helper and runs scripts/package_windows.ps1. Source archive checks must also pass without .git. The source-archive workflow also retains the exact source and SHA-256 as a temporary artifact. Native security tests launch two Windows app processes to test key-store persistence. Current exact validation and untested native behavior belong in the handoff, not inferred from these commands. Read [update requirements](docs/UPDATES.md) before enabling installation and [development notes](docs/releases/0.1.0-dev.3.md) for this change.
