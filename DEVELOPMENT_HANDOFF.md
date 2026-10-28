# Budgetism development handoff

**Development version:** 0.1.0-dev.8, explicit matching of existing actual transactions to scheduled occurrences.
**User-confirmed baseline:** dev.7 CSV importing, persistence and repeat-import protection, with earlier calendar/forecast, budgets, schedules and optional password already reported working. Do not repeat previous feature setup exercises.
**Starting repository commit:** b6057f6fbee794b86d8a8fe1bb23e0ce88318ee8 on main; application source 0dec77e3372a7ceb5745e29a54301a6622de414b, Git tree d97461e0c2945f39ba2d9f20fa97ef163a9b419b, successful run 40708091217. The documentation-only follow-up does not alter application code.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/MATCHING.md, docs/RECURRING.md and docs/LOCAL_STORAGE.md. Inspect current branches, open PRs, releases and workflows before edits. Public source and development workflows remain authorized. No releases/tags, visibility or credential changes, server/provider/payment setup, unattended workers or Codex CLI automation. Do not force-push, overwrite newer work or expose financial data. All fixtures are fictional.

## This iteration

Scheduled > Upcoming > Match existing opens a read-only candidate review. It links one compatible imported/manual actual to one unresolved scheduled occurrence, without new postings, category changes or receipt loss. Eligible type, account, currency and transfer direction must match. Exact amounts within seven days are the default; the user can expand to 30/90 days and include different amounts. Explicit selection/review, stale workspace/schedule/occurrence/transaction checks and atomic dual-link auditing are required.

No new financial schema, encryption format, SQLite container or library dependency. Existing schemas 3/4 use the same confirmed occurrence and transaction links. Earlier data is still readable; prior explicit schedule/import migration gates are retained. Security mode, saved budgets, planning, imports and updater-install restrictions are unchanged. No automatic matching, unlink action, reconciliation or live-bank integration.

## Code map

- apps/client/lib/local/schedule_matching.dart: part of ledger.dart; candidate rules and metadata-only actual linking with audit.
- schedule_match_dialog.dart: responsive read-only suggestions, filters, explicit review and single-flight retry.
- ledger.dart / schedule_rules.dart / local_api.dart: one new operation using existing atomic store and occurrence guards.
- schedule_widgets.dart: Match existing entrypoint and Matched history label.
- apps/client/test/schedule_matching_test.dart, schedule_match_storage_test.dart and schedule_match_widgets_test.dart: new unit/storage/widget regression coverage.
- apps/client/integration_test/matching_restart_test.dart: actual Windows OS-key/SQLite match write and read in separate native app processes.
- .github/workflows/build-checks.yml: dev.8 build and additional native test pair; all previous tests and Defender gate retained.

Core encryption, SQLite, device keys, budget/planning engines, imports, transaction editor, backend and updater implementations are unchanged. Root file allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. Keep supporting documents in docs; generated files under ignored build. No credentials, financial files, binaries or temporary logs in tracked source.

## Build and validation

Flutter 3.47.8 remains pinned. Generate temporary Windows/web runners, resolve packages, analyze and test. Retain all security/schedule/import two-process native tests and the read-only planning native test. Add matching_restart_test.dart with MATCH_TEST_PHASE=write/read and shared isolated MATCH_TEST_DIRECTORY. Standalone invocation is only same-process reopen, not equivalent to the two CI processes. Build/package using 0.1.0-dev.8, verify native dependencies, then scan the exact ZIP and extracted files with the existing Defender gate. No suppression, test skipping, antivirus exclusion or protection bypass.

Source archive hashes and the entire dev.7 Git tree were checked before editing. Local SDKs and Windows GUI are unavailable. Source/root/package checks are not passing Flutter tests. Inspect the exact hosted run and downloaded artifacts, then record actual results in docs/VALIDATION.md. Do not call dev.8 compiled or scanned until those steps finish.

Stable executable Budgetism.exe and archive Budgetism-Windows-x64.zip. Data remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same OS profile/key store. Local passwords remain optional; backups remain independently password-protected. Delivery uses verified GitHub Actions artifacts because the user's chat downloads failed. No GitHub release/tag or production approval. Update installation remains disabled.

## Next desktop test

Back up the working dev.7 workspace. Use an existing fictional imported expense and a matching scheduled bill. Note its actual balance/spending, then Scheduled > Match existing > select/review > Link without new transaction. There must still be one actual transaction and no balance/spending change. History shows Matched, the occurrence is no longer due, and the link survives restart. No new workspace-format prompt should arise merely from matching on an existing recurring/import workspace. Full steps: docs/WINDOWS_TESTING.md.
