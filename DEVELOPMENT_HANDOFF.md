# Budgetism development handoff

**Development version:** 0.1.0-dev.10, read-only financial reports and explicit CSV export.
**Verified application:** 63b5b6cef441ca1889117d6a3b43ec05f5e5aa34, tree 5f2d6f429fdbfc83a373608227de4d609d562c59.
**Successful build:** [run 40737797353](https://github.com/TechSavage1989/budgetism/actions/runs/40737797353), all five jobs passed including native report/export preservation and Defender scans.
**User-confirmed baseline:** dev.9 statement reconciliation worked, with previous matching/imports/calendar/forecast/budgets/persistence and optional passwords confirmed. Do not repeat those setup exercises.
**Starting main:** 05933bd381a9ede2150fe0ed2021a1171664bc5e, documentation follow-up to tested dev.9 application 1ba16145c8e9cec3cf88b39eceadbbfd8cab6b06. Successful dev.9 run 40728930400. Original application tree 113f9f79d896a92b5bd74943c81867b7149da39c.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/REPORTS.md and docs/LOCAL_STORAGE.md. Inspect current refs, PRs, releases and workflows before changes. Public source and development workflows are authorized. Releases/tags, visibility or credential changes, server/provider/payment setup, unattended workers and Codex CLI automation are not. Preserve newer work and history; never force-push. All fixtures must remain fictional.

## This iteration

Reports is a new navigation destination for saved local workspaces. Date/account selection drives Overview, Categories with contribution drilldowns, Monthly trends and recorded Balances. Only non-voided, historical recorded activity enters income/expense totals. Plans, allocations, transfers and opening balances are not spending/income. Account movement still uses both transfer sides correctly. Undated opening balances limit the historical interpretation, which is disclosed on screen and in docs/REPORTS.md.

The screen receives a read-only snapshot callback, not the financial mutation API. No schema migration or library dependency is introduced. Core ledger, encryption, SQLite, device keys, budgeting, forecasting, importing, schedule matching, reconciliation, backend and updater implementations remain unchanged. CSV export requires explicit unencrypted-data consent and a destination; only .csv filenames are accepted. Failed/cancelled exports preserve all records and controls. Formula-like text uses a visible Text: prefix; exact trusted amounts remain numeric.

## Source map

- apps/client/lib/local/reports.dart: immutable report values, date/account calculations and display-oriented CSV serialization.
- apps/client/lib/local/report_widgets.dart: responsive views, filters, category detail, export consent and native save function.
- apps/client/lib/main.dart: Reports navigation/integration only.
- apps/client/test/reports_test.dart, reports_limits_test.dart and report_widgets_test.dart: calculation, CSV and widget tests.
- apps/client/integration_test/reports_native_test.dart: actual SQLite report/export preservation and close/reopen validation.
- .github/workflows/build-checks.yml: version and additional native reports test; all prior tests and exact-package Defender scan retained.

## Build and delivery gate

Flutter remains pinned to 3.47.8. Generate temporary runners, resolve packages, analyze and run all existing/new unit/widget tests. Retain all native security/schedule/import/matching/reconciliation write/read process pairs and the planning test. Add reports_native_test.dart on Windows. This new report test is same-process reopen, not a separate-process test; existing process pairs remain the separate-process evidence.

Build/package with APP_VERSION=0.1.0-dev.10. Stable names Budgetism.exe and Budgetism-Windows-x64.zip. Verify exact artifact identity, dependencies, CRC/digests and the same ZIP's Defender results before offering it. No test suppression, analyzer bypass, antivirus exclusions or positive-detection bypass. No release or updater installation is authorized.

Hosted analysis, the full unit/widget suite, all retained native process tests, the new native report/export test, Windows/web compilation and exact-package scans passed for the application commit above. Downloaded artifact digests, version, native libraries and actual updater verify-only acceptance were checked separately. Local Flutter/Dart/.NET SDK and Windows GUI remain unavailable; no local compilation or manual user GUI run is claimed. Exact evidence and remaining gates are in docs/VALIDATION.md. GitHub Actions is the preferred delivery route because chat links previously failed.

Root allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. No generated runners, binaries, keys, databases or temporary logs in source. Windows data remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same profile/key store. Independent encrypted backups and optional local password remain unchanged.

## Delivered artifact and continuity

Use the successful run above and Budgetism-Windows-x64-development, artifact 12837643904. Outer SHA-256 2e29524f65ed1a520aa0fb5be4aa0425fd9ffb395e03d30ab8a8d120c5c38270. Inner Budgetism-Windows-x64.zip is 16,189,811 bytes with SHA-256 f6ce8f3b1c3243969510a7fef947f140a478018c24f386203dcf75fe9fa7638b. Security artifact 12838707119 reports no threats in that exact ZIP and extracted runtime files. Both executables remain unsigned. The complete source snapshot matched all 124 files and the tested Git tree.

Initial analyzer findings were corrected without suppressing checks. An exact-byte CSV test correction and the final aggregate-movement range guard were proactive review improvements; the final full run passed. This follow-up changes documentation only, not the tested application/version. Recheck branch heads and open PRs before a normal fast-forward to main, preserve historical branches, and never force-push. No release/tag was created.

## Next desktop check

Back up the working dev.9 workspace. Open dev.10 under the same Windows account. Use Reports with a known fictional account and dates: recorded income 500 and expense 200 should show income 500, expenses 200 and net income 300. A 1000 opening balance gives a 1300 recorded closing balance if there is no other activity. Verify category contributions and the optional CSV export, then reopen and confirm statement history/security are unchanged. Viewing or exporting reports must not prompt for a workspace-format upgrade. No repeated budgeting/import setup is required.
