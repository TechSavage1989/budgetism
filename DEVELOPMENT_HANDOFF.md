# Budgetism development handoff

**Development version:** 0.1.0-dev.5, recurring bills/income/transfers.
**User-confirmed baseline:** dev.4 Windows monthly budgets work and retain data across restart. Dev.3 optional-password operation was also confirmed. These reports cover the exercised workflows, not a security audit.
**This source iteration:** prepared for hosted validation. Do not claim a dev.5 build or test pass before checking its exact run.

## Read first and approved scope

Read AGENTS.md, this file, docs/IMPLEMENTATION_STATUS.md, docs/LOCAL_STORAGE.md and docs/RECURRING.md. Inspect default branch, development branches, open PRs, releases and CI before editing. Never overwrite newer repository work with a conversation ZIP.

Repository: https://github.com/TechSavage1989/budgetism, public. Source and non-publishing development workflows are authorized. No releases, tags, visibility changes or credentials are authorized. Exclusions: server setup, Codex CLI automation, unattended workers, payment setup and API-account setup.

## Correct baseline

The verified and user-tested dev.4 code is c7de25eeff74651519407df666074262effc9176 on development/monthly-budgets-dev4, not the older main branch. Main was 7c367d725fd4d2e5d07f2fd7abfa4b92648c706b at inspection. There were no open PRs. Dev.4 run 40610634360 passed all five jobs and produced the user's Windows artifact.

This iteration started from source artifact 12782791554, run 40610634489, pinned to c7de25e. Its outer digest was 76cef1b61183ee430256e0e892990fb2b442162f448c6c9c51753075a6f6889a; inner source digest df04c73e5e2ece16e6721b598ebbbdfde95ef0af17a841518ce49eefd0e5fa46. The extracted tree was independently recomputed as 0c818a54fcefa2c320dc051cb2d7f4e6d71f4c84, matching GitHub. Dev.4's carried-forward documentation still described dev.3; this handoff corrects that stale status.

## Changes

- Add Scheduled navigation, upcoming/date-range view, schedule management, resolved history and a dashboard preview.
- Weekly, fortnightly, monthly and annual calendar anchors; optional inclusive end date; pause/resume; explicit amount/date/notes confirmation, postponement and skip.
- Stable schedule/index identity, version guards and atomic occurrence-plus-transaction save. Duplicate confirmation, stale writes and partial saves are rejected.
- Preserve origin links through actual transaction edits/voids; settled occurrences do not regenerate.
- Financial schema 3 with explicit first-schedule migration from schema 1/2; preserve existing records, budgets and optional security mode. SQLite/encryption formats and paths stay unchanged.
- Add unit, widget, SQLite/backup and real two-process Windows tests. Keep existing financial, budgeting, security and updater tests. Update only the two budget-migration test expectations to the explicit budgetSchema=2 constant.
- No dependency additions, server changes, bank integration, auto-posting, sync or updater installation.

## Code map

apps/client/lib/local/recurrence.dart is pure date arithmetic. schedules.dart derives upcoming occurrences. schedule_rules.dart is a part of ledger.dart and performs validated mutations in the same ledger commit as financial transactions. schedule_widgets.dart contains the dashboard, views and dialogs. local_api.dart exposes the actions. main.dart adds navigation without replacing the existing shell, budgets or security screens.

Tests: schedules_test.dart, schedule_storage_test.dart, schedule_widgets_test.dart and integration_test/schedule_restart_test.dart. Existing device_restart_test.dart remains intact. CI builds from a clean source archive without .git and executes both native tests in separate write/read app processes.

Root allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. No moved paths or new root exceptions. Supporting documents are in docs/ and history in docs/releases/. Never commit generated runners, keys, vaults, binaries or temporary logs.

## Build and validation commands

From apps/client on the configured Flutter 3.47.8 Windows toolchain:

~~~powershell
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter test integration_test/device_restart_test.dart -d windows
flutter test integration_test/schedule_restart_test.dart -d windows
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.5
flutter build web --release --dart-define=APP_VERSION=0.1.0-dev.5
~~~

CI uses SECURITY_TEST_PHASE=write/read with a shared isolated SECURITY_TEST_DIRECTORY, and SCHEDULE_TEST_PHASE=write/read with a different isolated SCHEDULE_TEST_DIRECTORY. A single invocation is only a same-process reopen test, not the separate-process test.

From source root: python scripts/check_layout.py --self-test; python scripts/verify_windows_package.py --self-test. From tools/updater: go test -race ./... and go vet ./... on a suitable host. Backend regression: dotnet build services/api/Budgetism.Api.csproj --configuration Release and dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release.

Build Go helper to build/tools/Budgetism-Updater.exe, then scripts/package_windows.ps1 -Version '0.1.0-dev.5'. Validate with python scripts/verify_windows_package.py build/packages/Budgetism-Windows-x64.zip --version 0.1.0-dev.5 --checksums build/packages/checksums.sha256.

## Storage, updates and delivery

Stable executable Budgetism.exe and package Budgetism-Windows-x64.zip. Database %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Keep the same Windows account and OS key store. Settings, logs and downloads stay per-user. Both password and device modes retain encrypted financial payloads. Backups use an independent password.

Export a backup before the first schedule save. Existing workspaces are not automatically migrated just by opening dev.5. After financial schema 3 is saved, older versions must not be used against it. Use exported backups for recovery, not database file copying or deletion.

GitHub Actions artifacts are the primary user delivery path because chat download links failed repeatedly. No public release/tag or in-app install is enabled. Verify the exact commit, all required jobs, artifact digest, inner checksum, identity/version, native DLLs and PE architecture before providing a download. CI is not a full manual Windows GUI or independent security audit.

## Current validation and next action

Local source-tree provenance, layout guard/negative control, package-verifier negative controls, unchanged Go race tests and go vet passed. No local Flutter/.NET SDK or Windows GUI is available. New Flutter/native tests await hosted CI. Update docs/VALIDATION.md and this handoff with exact code commit, run and artifact evidence after verification.

Deliver a compiled dev.5 test build only after its gates pass. Ask the user to back up, create a fictional schedule, check no balance change before confirmation, confirm once, restart and verify one retained transaction and unchanged future anchors. Next milestones are calendar/forecasting and later self-hosted synchronization; not part of this change.
