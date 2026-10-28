# Budgetism development handoff

**Development version:** 0.1.0-dev.6, calendar and scheduled cash flow.
**Starting repository HEAD:** 938768e556f89ecf6a3a91c080bf8a5da740c8d0 (dev.5 documentation follow-up).
**Starting tested application:** 39353fd46314aa22866ff85dcf0aad352fa39601, run 40616768105.
**User reports:** dev.5 runs and works; earlier budgeting/restart retention and optional-password operation were confirmed. The user reported a browser antivirus warning, then chose to run the app. Functionality does not establish antivirus clearance or a security audit.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/PLANNING.md and docs/LOCAL_STORAGE.md. Inspect current branches, PRs, workflows and releases before edits. Repository TechSavage1989/budgetism is public. Source and non-publishing development workflows remain authorized. No release/tag, visibility/credential changes, server setup, Codex CLI automation, unattended workers, bank-provider setup or payment setup is authorized. Never overwrite newer repository work with an older source archive. Never force-push.

## This iteration

Calendar and Forecasts use existing accounts, actual postings and unresolved schedules. No financial, encryption or SQLite migration. No new library dependency. New pure planning.dart enumerates ranges directly, discloses overdue separately, treats future-dated recorded entries on their effective dates and avoids counting confirmed occurrences twice. planning_widgets.dart adds account selection, monthly calendar/day detail, a line chart with daily exact values, and device-only threshold preferences. Read docs/PLANNING.md for precise semantics and limitations.

Existing main.dart is changed only to import/integrate the two navigation destinations. Financial ledger, recurrence, encrypted vault, SQLite, budgeting, transaction editor, device-key code, backend, updater and existing tests are preserved. In-app update installation remains disabled. No live financial data enters source, tests or build files.

## Tests and build security

New planning_test.dart and planning_widgets_test.dart cover the read-only engine and layouts. integration_test/planning_native_test.dart verifies encrypted bytes and financial revision stay unchanged, then closes and reopens actual native SQLite and checks reproducible results. This native test is same-process reopen; the retained dev.5 security and schedule tests still run write/read in separate native processes.

Windows CI runs scripts/scan_windows_package.ps1 after packaging and dependency verification. It updates Defender security intelligence, scans both exact ZIP and extracted contents with custom-scan remediation disabled for evidence preservation, records scanner/version/hash/output and refuses delivery on errors/detections/unavailable scan. No global protection settings or exclusions are altered. The security-evidence artifact is separate and retained even when a scan fails. A clean scan is not publisher signing, universal browser reputation, or independent review.

## Build commands and stable paths

Flutter 3.47.8 remains pinned in CI. Generate Windows/web runners as before, run flutter pub get, flutter analyze, flutter test, the existing native integration test pairs, and the new native planning test. Build using APP_VERSION=0.1.0-dev.6 and package with scripts/package_windows.ps1 -Version '0.1.0-dev.6'. Run the root-layout and package verifier negative controls. Keep all test/analyzer gates enabled.

Stable executable Budgetism.exe, ZIP Budgetism-Windows-x64.zip, Windows database %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Preserve the same Windows profile and OS key store. Thresholds are unencrypted per-device display preferences, not ledger data. Independent encrypted backups are unchanged. Root file allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. No binaries, databases, keys or temporary logs in tracked source.

## Current validation and delivery gate

Local SDKs/Windows GUI are unavailable. Do not infer compilation from source review. Local layout/package checks and preserved source comparison are recorded separately. Hosted dev.6 analysis/tests, native execution, Windows/web builds and Defender scan are pending until the exact run is inspected and recorded. Do not offer an old artifact as dev.6. Use GitHub Actions as primary delivery because chat downloads failed for this user. Deliver only the verified successful artifact and record checksums/run/commit in docs/VALIDATION.md.

The user does not need to retest budgeting. Next desktop test: existing records and optional-password setting remain, then 1000 starting balance plus 500 scheduled income tomorrow minus 200 the following day produces 1500 then 1300 with no immediate actual balance change. Recording an occurrence replaces its projection with one actual. No additional workspace-format upgrade should appear from viewing Calendar or Forecasts.
