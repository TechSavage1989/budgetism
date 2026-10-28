# Budgetism development handoff

**Development version:** 0.1.0-dev.9, local statement reconciliation.
**Verified application:** 1ba16145c8e9cec3cf88b39eceadbbfd8cab6b06, tree 113f9f79d896a92b5bd74943c81867b7149da39c.
**Successful CI:** [run 40728930400](https://github.com/TechSavage1989/budgetism/actions/runs/40728930400), all five jobs passed, including the native reconciliation process pair and exact-package Defender scan.
**User-confirmed baseline:** dev.8 matching worked. Prior imports, forecasts, budgets, schedules, persistence and optional passwords are confirmed; do not repeat those setup tests.
**Starting main:** 1de69f0f3598aa275e52b910714cb30e5fcdac14, documentation follow-up to tested application 0e41cbf1a2127aedeaa1dae267f538b06ce19d1b. Dev.8 successful run 40717507066.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/RECONCILIATION.md and docs/LOCAL_STORAGE.md. Check live refs, PRs, releases and workflows before edits. Public source and development workflows are authorized; releases/tags, visibility/credential changes, server/provider/payment setup, unattended workers and Codex CLI automation are not. Preserve history, never force-push and never publish personal financial data.

## This iteration

Statement review, selected cleared entries, exact difference checks, completed statement history and explicit latest-statement reopening. No automatic balancing entries. Financial schema 5 is consent-gated on first completion; opening alone does not migrate. Transactions and original account balances are unchanged by reconciliation. Active statements protect transaction editing/voiding and account opening/type changes. Transfers reconcile independently per account. Existing imports and schedule matches continue after upgrade without dropping receipts or schedules.

New files: local/reconciliation.dart (ledger part and derived helpers), local/reconciliation_widgets.dart (review/history/reopen UI), reconciliation unit/storage/widget tests, and integration_test/reconciliation_restart_test.dart. Small integrations in ledger.dart, local_api.dart and main.dart. Import schema checks now accept newer versions instead of reinitializing receipts. Existing encryption, SQLite, device keys, budgets, planning, recurrence, matching algorithms, backend and updater are retained.

## Validation and delivery

All existing/new Flutter tests and web/Windows compilation passed. Retained native test pairs and the new reconciliation write/read pair passed with actual Windows SQLite/OS keys. The exact ZIP and extracted contents passed the required Defender scan. Downloaded source/package provenance, hashes, native files and actual updater verify-only acceptance were independently checked. See docs/VALIDATION.md for exact evidence and corrected failures.

Use the successful run above, artifact Budgetism-Windows-x64-development, ID 12834822871. Outer SHA-256: 009a8d8e527e3d3af68da6a189c8de47633f0c5216c8f0adfb2395a8d718180d. Inner portable ZIP: 16,126,748 bytes, SHA-256 9c76464b6934d0f430cbb3b24efe7c9627627cd80e88a3c0c5fbd0e71f7a5e5c. Security artifact 12834608380 identifies this same hash and reports no threats in both scans. The executables remain unsigned, and the user's dev.9 GUI workflow is not yet confirmed.

No local Flutter/Dart/.NET SDK or Windows GUI was available; hosted execution is distinguished from local source/package checks. Reconciliation integration uses RECONCILE_TEST_PHASE=write/read and the same isolated RECONCILE_TEST_DIRECTORY in two separate native app processes. All prior gates remain enabled. Do not suppress failures or bypass scan detections.

This documentation-only follow-up changes no tested application code/version. Identify the binary by the application commit, not a later documentation-only HEAD. Recheck expected branch heads before normal fast-forward publication; preserve historical branches.

Stable names Budgetism.exe and Budgetism-Windows-x64.zip. User data remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same Windows profile/key store. Root allowlist is unchanged. No build outputs, keys, databases or logs in tracked source. GitHub Actions artifacts are the preferred user delivery route; no release or automatic installation is authorized.

## Next user test

Back up dev.8. In dev.9 open Accounts > Reconcile statements and select a fictional account with known opening balance and recorded transactions. Enter the statement ending date and balance; select only cleared entries. Confirm exact zero, review and the first-completion format upgrade. Finish must not change the actual balance or create transactions. Restart and verify the completed statement remains. Reopening must retain history and balance. Do not use dev.8 or older after upgrading to schema 5. See docs/WINDOWS_TESTING.md.
