# Budgetism development handoff

**Development version:** 0.1.0-dev.8, explicit matching of existing actual transactions to scheduled occurrences.
**Verified application:** 0e41cbf1a2127aedeaa1dae267f538b06ce19d1b, tree d7b80b45ffbb1cb6fc7a6889de621234ffe55827.
**Successful CI:** [run 40717507066](https://github.com/TechSavage1989/budgetism/actions/runs/40717507066), all five jobs passed including Windows matching write/read processes and Defender scans.
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

Source archive hashes and the entire dev.7 Git tree were checked before editing. The final source artifact matched all 108 local files and the verified Git tree. Hosted analysis/tests, native execution, Windows/web builds, packaging and Defender scans passed for the exact application commit above. Local artifact checks confirmed hashes, version, native libraries and updater verify-only acceptance. Local SDKs and Windows GUI remain unavailable; no local Flutter or manual GUI test is claimed. See docs/VALIDATION.md for exact evidence and remaining gates.

Stable executable Budgetism.exe and archive Budgetism-Windows-x64.zip. Data remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same OS profile/key store. Local passwords remain optional; backups remain independently password-protected. Delivery uses verified GitHub Actions artifacts because the user's chat downloads failed. No GitHub release/tag or production approval. Update installation remains disabled.

## Delivered artifact and build correction

Use the successful Actions run above and artifact Budgetism-Windows-x64-development, ID 12827924651. Outer SHA-256 a57facb7b915161125c9f8a11795494649ff90669e6f8a68e87716e66f1732ad. Inner Budgetism-Windows-x64.zip: 16,110,219 bytes, 18 entries, SHA-256 b03dc760226524056b44ddd8fc53a0a174bed856f7f578da9de7431426cf6700. Security artifact 12828829229 identifies that same hash and reports no threats in the ZIP and extracted files. Both executables remain unsigned. Downloaded package identity, native dependencies and actual updater verify-only checks passed.

Initial run 40716102610 failed twice before Windows compilation because Update-MpSignature returned RPC error 0x800706be. No threat detection occurred. The corrected commit retained the application code and exact scan gate, added bounded documented command-line signature initialization, and updated README/supporting docs. Do not suppress or remove the scan to work around future initialization faults.

This follow-up records completed verification in documentation only. It does not change the tested binary/version. Preserve historical branches; recheck refs before any normal fast-forward to main. No release/tag was created.

## Next desktop test

Back up the working dev.7 workspace. Use an existing fictional imported expense and a matching scheduled bill. Note its actual balance/spending, then Scheduled > Match existing > select/review > Link without new transaction. There must still be one actual transaction and no balance/spending change. History shows Matched, the occurrence is no longer due, and the link survives restart. No new workspace-format prompt should arise merely from matching on an existing recurring/import workspace. Full steps: docs/WINDOWS_TESTING.md.
