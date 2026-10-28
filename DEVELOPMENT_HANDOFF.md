# Budgetism development handoff

**Development version:** 0.1.0-dev.9, local statement reconciliation.
**User-confirmed baseline:** dev.8 matching worked. Prior imports, forecasts, budgets, schedules, persistence and optional passwords are confirmed; do not repeat those setup tests.
**Starting main:** 1de69f0f3598aa275e52b910714cb30e5fcdac14, documentation follow-up to tested application 0e41cbf1a2127aedeaa1dae267f538b06ce19d1b. Dev.8 successful run 40717507066.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/RECONCILIATION.md and docs/LOCAL_STORAGE.md. Check live refs, PRs, releases and workflows before edits. Public source and development workflows are authorized; releases/tags, visibility/credential changes, server/provider/payment setup, unattended workers and Codex CLI automation are not. Preserve history, never force-push and never publish personal financial data.

## This iteration

Statement review, selected cleared entries, exact difference checks, completed statement history and explicit latest-statement reopening. No automatic balancing entries. Financial schema 5 is consent-gated on first completion; opening alone does not migrate. Transactions and original account balances are unchanged by reconciliation. Active statements protect transaction editing/voiding and account opening/type changes. Transfers reconcile independently per account. Existing imports and schedule matches continue after upgrade without dropping receipts or schedules.

New files: local/reconciliation.dart (ledger part and derived helpers), local/reconciliation_widgets.dart (review/history/reopen UI), reconciliation unit/storage/widget tests, and integration_test/reconciliation_restart_test.dart. Small integrations in ledger.dart, local_api.dart and main.dart. Import schema checks now accept newer versions instead of reinitializing receipts. Existing encryption, SQLite, device keys, budgets, planning, recurrence, matching algorithms, backend and updater are retained.

## Validation and delivery

Local SDKs and Windows GUI are unavailable. Source/archive and layout checks are not compilation evidence. Inspect the exact hosted run before delivery. Retain all existing Flutter tests and native process pairs; add reconciliation write/read with RECONCILE_TEST_PHASE and an isolated RECONCILE_TEST_DIRECTORY. Keep Windows/web build gates and the exact ZIP/extracted Defender scan. Never suppress an analyzer/test failure or bypass a scan detection.

Stable names Budgetism.exe and Budgetism-Windows-x64.zip. User data remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same Windows profile/key store. Root allowlist is unchanged. No build outputs, keys, databases or logs in tracked source. GitHub Actions artifacts are the preferred user delivery route; no release or automatic installation is authorized.

## Next user test

Back up dev.8. In dev.9 open Accounts > Reconcile statements and select a fictional account with known opening balance and recorded transactions. Enter the statement ending date and balance; select only cleared entries. Confirm exact zero, review and the first-completion format upgrade. Finish must not change the actual balance or create transactions. Restart and verify the completed statement remains. Reopening must retain history and balance. Do not use dev.8 or older after upgrading to schema 5. See docs/WINDOWS_TESTING.md.
