# Budgetism development handoff

**Version:** 0.1.0-dev.5 development preview.
**Verified application commit:** 39353fd46314aa22866ff85dcf0aad352fa39601.
**Successful CI:** [run 40616768105](https://github.com/TechSavage1989/budgetism/actions/runs/40616768105), all five jobs passed, including the existing and new Windows write/read process tests.
**User-confirmed baseline:** dev.4 monthly budgeting and restart persistence; dev.3 optional-password behavior. Dev.5 still needs the user's manual GUI confirmation.

## Read first and approved scope

Read AGENTS.md, this file, docs/IMPLEMENTATION_STATUS.md, docs/LOCAL_STORAGE.md and docs/RECURRING.md. Inspect current main, development branches, PRs, releases and CI before editing. Never overwrite newer confirmed repository work with a conversation ZIP.

Repository: https://github.com/TechSavage1989/budgetism, public. Source and non-publishing development workflows are authorized. Releases, tags, visibility changes and credentials are not authorized. Exclusions: server setup, Codex CLI automation, unattended workers, payment setup and API-account setup.

This follow-up updates documentation only. It does not change the tested application code, increment the version, or create a release. Identify the compiled artifact by the application commit above, not a later documentation-only HEAD. Preserve historical branches and never force-push.

## Source lineage and corrected failures

Dev.4 code c7de25eeff74651519407df666074262effc9176 on development/monthly-budgets-dev4 was the starting point, not the older main at 7c367d725fd4d2e5d07f2fd7abfa4b92648c706b. Dev.4 run 40610634360 passed and the user confirmed budgeting/persistence.

Dev.5 was developed on development/recurring-dev5. Initial commit 1cb323a773bb7fbb693f31407962f2046244346c failed analysis in run 40615851293 due to two unbraced multiline validation guards. Commit e1f6d8d153920747f5667e8dd23fd374de274a3d corrected them; run 40616113561 then caught a 192-pixel dropdown overflow in the 430-pixel widget test. Commit 39353fd46314aa22866ff85dcf0aad352fa39601 constrained that selector. The same analyzer and regression tests then passed without suppression, skipped tests or a widened test viewport.

The tested code tree is ff18ea3612a54a4a2f20e1afcdd5dc099f24fc8d. Local files matched the entire hosted source snapshot and this Git tree. See docs/VALIDATION.md for both source/artifact hashes and checks.

## Delivered Windows development artifact

Use [successful run 40616768105](https://github.com/TechSavage1989/budgetism/actions/runs/40616768105), artifact **Budgetism-Windows-x64-development**, ID 12785682854. GitHub Actions is the primary delivery route because chat downloads repeatedly failed for the user. Extract the outer ZIP, then Budgetism-Windows-x64.zip, and run Budgetism/Budgetism.exe with all support files.

- Artifact envelope SHA-256: 21e086088c8715624cf836714625867f1967f5d155bae0bb92de4af118d3c400.
- Portable ZIP SHA-256: d28557bb57c8a9d3bc4ef5318e9021f9f4a836ee050bb720f5910c2102cfee1e.
- Portable ZIP: 15,957,183 bytes, 18 entries.
- Verified identity TechSavage1989.Budgetism, version 0.1.0-dev.5, windows-x64, Budgetism.exe.
- CRC/path checks, both digest layers, all PE/native dependencies and the actual Go updater's verify-only validation passed. This is not publisher signing or an installation test.

No GitHub release/tag or in-app installation is enabled. CI artifacts are temporary development downloads, not stable releases.

## Behavior and preservation

Scheduled adds weekly, every-two-weeks, monthly and yearly bills, income and transfers, with optional end dates. Upcoming includes unresolved overdue dates; Schedules provides editing/pause/resume; History retains recorded/skipped occurrences. Postpone changes one due date without shifting the original series. Record transaction explicitly creates one actual entry with the confirmed amount/date/notes. No schedule, timer, refresh, skip or postponement posts money automatically.

Stable schedule/index identity, operation replay protection, version guards and atomic occurrence-plus-transaction saves prevent duplicate confirmation. Actual edits/voids retain the origin link and never regenerate settled occurrences. Existing budgets, security, SQLite, encrypted backups and ledger behavior remain intact. Encryption/storage/budget modules, existing native security test, backend and updater were byte-identical to dev.4, apart from intentional ledger/API integration and version changes.

Existing financial schemas 1/2 remain readable. The first schedule save requires explicit backup/upgrade confirmation to financial schema 3. It preserves accounts, categories, transactions, budgets and password/device mode. Opening alone does not migrate. Older apps cannot read schema 3 afterward. Keep the pre-upgrade exported backup, not a copied database. Encryption envelope and SQLite container formats are unchanged.

Templates use one category/destination. Split an actual transaction after recording when needed. Frequency/start/end are fixed after creation; pause and create a new schedule to change recurrence. No automatic matching to existing manual transactions, undo-skip, bank feeds, reminders, automatic posting, forecasts or synchronization is included.

## Code map and organization

- apps/client/lib/local/recurrence.dart: strict date-only anchors and frequency arithmetic.
- schedules.dart: derived upcoming/overdue occurrences; no writes.
- schedule_rules.dart: ledger part for validated schedule/occurrence mutations and relationship validation.
- schedule_widgets.dart: views, dashboard preview and dialogs.
- ledger.dart/local_api.dart/main.dart: atomic integration, migration and preserved navigation shell.
- apps/client/test/schedules_test.dart, schedule_storage_test.dart, schedule_widgets_test.dart: new regression tests.
- apps/client/integration_test/schedule_restart_test.dart: actual Windows OS keys/SQLite across two app processes. Existing device_restart_test.dart is retained.
- services/api and tools/updater: unchanged backend/updater. scripts and .github/workflows: non-publishing build/validation.

Root allowlist: README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. No moved paths or root exceptions. Supporting material stays in docs/ and docs/releases/. Do not commit generated runners, databases, keys, binaries, temporary logs or source ZIPs.

## Verified build and test commands

From apps/client with Flutter 3.47.8 and the Windows native toolchain:

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

CI runs the device test with SECURITY_TEST_PHASE=write/read and a shared isolated SECURITY_TEST_DIRECTORY. It runs the schedule test with SCHEDULE_TEST_PHASE=write/read and a separate isolated SCHEDULE_TEST_DIRECTORY. All four native invocations passed. A single invocation above is only same-process reopen, not equivalent to the two-process CI test. Windows builds/tests ran from a clean source archive without .git.

From root: python scripts/check_layout.py --self-test and python scripts/verify_windows_package.py --self-test. From tools/updater: go test -race ./... and go vet ./... on a suitable host; Windows CI uses go test ./.... Backend: dotnet build services/api/Budgetism.Api.csproj --configuration Release; dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release.

Build Go helper to build/tools/Budgetism-Updater.exe, then scripts/package_windows.ps1 -Version '0.1.0-dev.5'. Verify with python scripts/verify_windows_package.py build/packages/Budgetism-Windows-x64.zip --version 0.1.0-dev.5 --checksums build/packages/checksums.sha256.

## Storage, remaining checks and next work

Stable launch name Budgetism.exe; package Budgetism-Windows-x64.zip. Windows database %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Keep the same OS user/key store. Settings, logs and downloads remain per-user. Both access modes retain encrypted payloads. Backups use a separate password.

Local Flutter/.NET SDKs and a Windows GUI were unavailable; compilation/native test passes come from the hosted run. Local source/archive/digest/root guards and Go verification were performed separately. Markdown conversion, H1/anchors and file links were checked, but browser visual rendering was unavailable. No manual dev.5 GUI/file-picker test, independent security audit, live PostgreSQL integration, non-Windows distribution or native updater installation/relaunch/rollback is claimed.

Follow docs/WINDOWS_TESTING.md: back up dev.4, create a fictional schedule with no immediate balance change, record once, restart and verify one retained transaction and the same future anchors. After confirmation, the next milestone is the calendar and cash-flow forecast. Do not enable updater installation or claim production financial safety.
