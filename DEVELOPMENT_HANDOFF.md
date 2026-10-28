# Budgetism development handoff

**Development version:** 0.1.0-dev.7, reviewed local CSV importing.
**Verified application commit:** 0dec77e3372a7ceb5745e29a54301a6622de414b, tree d97461e0c2945f39ba2d9f20fa97ef163a9b419b.
**Successful build:** [run 40708091217](https://github.com/TechSavage1989/budgetism/actions/runs/40708091217), all five jobs passed, including the native import process pair and Defender package scan.
**Starting tested application:** 37917d27a40d68cb6fbb83b61b192c9984a2b7ea, development/planning-dev6, run 40699293089.
**User-confirmed baseline:** dev.6 works. Accounts/persistence, optional password, monthly budgets, recurring activity and calendar/forecast tests were already reported working. Do not repeatedly ask the user to repeat budgeting tests.

## Read first and authorized scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/CSV_IMPORT.md and docs/LOCAL_STORAGE.md. Inspect current main, development branches, PRs, releases and CI before changes. Main was still the older dev.5 documentation commit 938768e556f89ecf6a3a91c080bf8a5da740c8d0 when this work began; do not revert dev.6 features by using it as code baseline.

Public source and non-publishing development workflows are authorized. Releases, tags, visibility changes, credential creation, server/provider/payment setup, Codex CLI automation and unattended workers are not. Use a normal descendant branch, never force-push or overwrite concurrent work. Financial data/files remain local; none is sent to a provider or repository. All examples/tests are fictional.

## Current implementation

CSV selection and mapping use the existing native file selector. Review validates explicit date/sign conventions and exact integer cents. Rows can be skipped, imported with a category, imported as a transfer, or linked to a same-date/signed-account-amount existing transaction without posting again. Possible duplicates and transfer/payment hints default to Skip. Confirm review before one atomic save. Up to 2 MiB, 1000 records, 40 columns and 500 selected rows; UTF-8/header/USD only.

Schema 4 adds validated import receipts; the first import requires explicit backup/upgrade consent. LocalLedger.schema remains the recurring baseline 3, with importSchema 4. Existing schema 1/2/3 stays unchanged until an import. Recurring code accepts schema 4 without reinitializing schedules; importing preserves all prior financial collections. No change to the encryption envelope, SQLite container, storage paths, keys, security preference or updater installation.

File-hash/record identity and optional unique bank IDs persist in encrypted receipts. Retrying an unchanged operation is idempotent. Renaming a file cannot import its rows twice. Edited/voided transactions retain receipts. A changed file without stable bank IDs only gets candidate warnings, not guaranteed matching. Match choices are explicit and do not modify an existing transaction. Unrecorded schedules must be recorded through Scheduled before matching their actual entries; auto schedule linking and reconciliation are not included.

## Source map

- apps/client/lib/local/csv_import.dart: bounded parser, mapping, exact amounts/dates and preview matching helpers.
- import_rules.dart: ledger part for atomic selected-row mutations and receipt validation.
- csv_import_widgets.dart: mapping/review, native file selection, fictional example, history and commit controls.
- ledger.dart: schema-4 extension and batch integration; prior operations retained.
- schedule_rules.dart/schedule_widgets.dart: accept newer financial schema without resetting recurring data.
- local_api.dart/main.dart: import action and entrypoints in Transactions and User options.
- apps/client/test/csv_import*.dart: parser/engine/storage/widget tests.
- apps/client/integration_test/import_restart_test.dart: actual native SQLite/OS-key write and read in separate processes.
- .github/workflows/build-checks.yml: dev.7 builds and new native import test pair; retained Defender scan gate.

Preserve every other working module. No new library dependencies. Root allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. Supporting material belongs under docs; generated output under ignored build. Never commit databases, keys, artifacts or temporary logs.

## Validation, build and delivery

The complete existing/new Flutter suite passed on Ubuntu and Windows. All retained native security/schedule/planning tests and the new separate-process import test pair passed. Windows/web compilation, backend contracts, updater tests, source/package checks and the exact-package Defender scan passed. Downloaded artifacts, hashes, native libraries and actual updater verify-only acceptance were independently checked. Exact evidence is in docs/VALIDATION.md. Local Flutter/Dart/.NET SDKs and Windows GUI are unavailable; those passes are hosted evidence, not a local GUI run.

Use the successful run above, artifact Budgetism-Windows-x64-development, ID 12825108489. Its outer digest is 3464286de7e7442f3fab52eb5c1c426e7c50bead41fd45305cf2ee02cb0183ef. Inner Budgetism-Windows-x64.zip is 16,092,508 bytes with SHA-256 da89f1bb0d3a1cfa4a884ca47eccbc1579072d7bd9e039328601f63a28faef3b. Security evidence artifact 12824553649 reports no threats in that exact archive and extracted files. Both executables remain unsigned. No new manual dev.7 GUI/file-picker check or production approval is claimed.

This documentation-only follow-up records completed checks without changing the tested application/version. A normal fast-forward can bring main through dev.6/dev.7 while preserving historical branches; recheck expected branch heads first. Do not identify a documentation-only HEAD as a different application build.

Flutter remains 3.47.8. Generate Windows/web runners, resolve packages, analyze and test, then run existing native security/schedule process pairs and read-only planning test. The new integration test uses IMPORT_TEST_PHASE=write/read with the same isolated IMPORT_TEST_DIRECTORY in two processes. Build with APP_VERSION=0.1.0-dev.7, package with scripts/package_windows.ps1 -Version '0.1.0-dev.7', verify the package and scan exact ZIP and extracted contents. No release or installer is authorized.

Stable names: Budgetism.exe and Budgetism-Windows-x64.zip. Windows data: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same OS profile/key store. The existing device-only forecast threshold preferences are retained. Delivery is primarily the successful GitHub Actions artifact because chat downloads repeatedly failed for this user. The browser alert reported for dev.5 remains unrelated to functional confirmation; preserve Defender results and do not claim universal clearance.

## Next user check

Back up dev.6 before the first import. Open dev.7 with the existing workspace, create a fictional CSV test account with 1000.00, select Use fictional example CSV, preview +500.00 and -200.00 with no balance change, confirm import and expect 1300.00. Reopen and repeat the exact same CSV: both rows must be already handled, with no new postings. Older builds cannot open the schema-4 workspace after import. Full steps: docs/WINDOWS_TESTING.md.
