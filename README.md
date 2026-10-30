<h1 align="center">Budgetism</h1>
<p align="center">Your finances. Your control.</p>
<p align="center"><a href="#download">Download</a> | <a href="#getting-started">Get started</a> | <a href="#features">Features</a> | <a href="#updates-and-settings">Updates</a> | <a href="#development">Development</a></p>

A Windows-first personal-finance app for private, deliberate budgeting and planning.
**Development preview, not a production release.** Dev.26 is the verified client
package, including category scopes and historical period comparisons.

## Features

- Accounts, transactions, budgets, recurring bills and a financial calendar.
- Configurable historical report graphs, category scopes and period comparisons,
  with exact values and explicit CSV export.
- Read-only cash-flow forecasts with a custom 1–365-day horizon and schedule-based
  what-if comparisons. Report/scenario configuration is currently session-only.
- Encrypted local workspaces, optional password prompting and independent encrypted backups.
- Themes, quick entry, search, import review, reconciliation and categorization tools.
- Existing private-server dashboard, planning and fictional bank-source review;
  local workspaces remain separate and are never silently uploaded.

**Not enabled:** real bank feeds, local/server synchronization, multi-currency,
automatic posting or in-app installation. Advanced local tools are not all
available on the server. See the [feature guide](docs/FEATURE_GUIDE.md) and
[replacement roadmap](docs/REPLACEMENT_ROADMAP.md); no MoneyWiz/PocketSmith parity is claimed.

## Download

**No GitHub release is published.** Verified development downloads are retained as
[GitHub Actions artifacts](https://github.com/TechSavage1989/budgetism/actions/workflows/build-checks.yml).
Use only the successful, exact run identified in the [current handoff](DEVELOPMENT_HANDOFF.md),
and choose **Budgetism-Windows-x64-development**, not the source or updater-only artifact.
Artifact downloads may require GitHub sign-in and expire. The separately delivered
verified client ZIP is an alternative.

[Release index](https://github.com/TechSavage1989/budgetism/releases) is the intended
release/update destination, currently empty. Development artifacts are not stable
releases. Packages are unsigned. Exact-package Defender scans do not establish
publisher identity or guarantee every antivirus/browser will accept a download.
Never bypass a malware detection.

## Requirements

- Windows x64 for the validated portable distribution; other native targets are unvalidated.
- All files from the application ZIP, including DLLs and the data folder.
- No developer tools, bank account connection or server for a local workspace.
- The same Windows account/protected key store for existing device-unlocked data.
- Existing private HTTPS server access only if using an already configured server session.

Web compilation is tested; browser-local financial storage is not implemented.
No server setup is part of the current work.

## Getting started

1. Before replacing a working client, export an encrypted backup and retain its
   separate password. Close Budgetism; do not delete or recreate its workspace.
2. Download the verified development artifact. Extract the outer ZIP, then the
   inner **Budgetism-Windows-x64.zip**, into a separate program folder.
3. Keep every bundled file together and run **Budgetism.exe**. Confirm the version
   against the [handoff](DEVELOPMENT_HANDOFF.md).
4. Choose **Open local workspace** for saved records. **Explore with sample data**
   is fictional, temporary and separate.
5. For an existing server session, use its existing explicit HTTPS connection and
   sign-in flow. Do not rerun server installation or a database upgrade for a client-only update.

## How to use

- **Home** shows recorded balances through today. Future actuals, schedules and
  projections are distinct; they are not bank-reported available balances.
- **Transactions** records actual money movement. Budget allocations and plans do
  not move money. Use **Match existing** instead of posting a scheduled payment twice.
- **Reports > Graphs** selects a measure and line/bar view. Use the dates/accounts
  controls and exact-value table to inspect the same underlying recorded totals.
- **Forecast > Configure forecast** chooses a horizon and included schedules.
  **Apply** changes only the what-if view; **Cancel** discards edits and **Reset baseline**
  restores all schedules and 30 days. No setting here posts a transaction.
- **Settings** opens themes, categories, imports, security and backups. Narrow
  windows provide additional destinations through **More**.

CSV reports are **unencrypted and not backups**. Export requires explicit consent
and a chosen destination. Reconciled records require explicit reopening before
protected changes. See [detailed workflows](docs/FEATURE_GUIDE.md),
[report semantics](docs/REPORTS.md) and [forecast controls](docs/REPORT_FORECAST_DEV25.md).

## Updates and settings

The implemented public release checker runs asynchronously at startup, every five
minutes while active, and on focus return after at least two minutes. **Check for
updates** is also available on the connection screen/user controls. Requests are
single-flight with caching/ETags, cooldowns and throttling; failures do not mean
“up to date.” No release is currently available.

Downloading is explicit when a verified eligible release exists. **Install and
restart is disabled** pending full previous-release-to-new-release native testing.
Do not assume timer logic or helper unit tests prove installation/rollback/relaunch.
See the [update release gate](docs/UPDATES.md).

Stable names are **Budgetism.exe** and **Budgetism-Windows-x64.zip**. Data and
settings are per-user, not beside the executable. The Windows local workspace is
`%LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3`; copying it alone is not a
portable backup. Keep independent encrypted backups and their passwords.

## Troubleshooting

- Missing DLLs: re-extract the complete verified ZIP rather than copying only the EXE.
- Antivirus warning: retain the exact detection name and affected file; do not disable protection.
- Stale-window error: close and reopen the workspace before retrying.
- Wrong schema/older build: use the pre-upgrade encrypted backup; do not delete data.
- Lost device key or backup password: there is no bypass recovery without a usable backup.
- Connection failure: use the existing trusted HTTPS address; never disable certificate validation.

## Development

Read [AGENTS.md](AGENTS.md) and [DEVELOPMENT_HANDOFF.md](DEVELOPMENT_HANDOFF.md) first.
The current source is on the development branch identified there; **main is an
older checkpoint**, not the latest implementation.

[Build/test commands and code map](docs/DEVELOPMENT.md) cover Flutter, the retained
.NET API and Go updater helper. [Dev.26 validation](docs/DEV26_VALIDATION.md) records
the verified package; [development history](docs/releases/development-history-through-dev25.md)
preserves earlier milestones. No license is asserted solely from public visibility.

The current scope excludes server setup, Codex CLI automation, unattended workers,
payment/API-account setup, real bank linkage, release/tag publication and access
changes. Existing authorized development-branch source/workflow sync is separate
from release permission.
