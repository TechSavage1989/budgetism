# Budgetism development handoff

**Development version:** 0.1.0-dev.13, categorization history and reviewed batch undo.
**User-confirmed baseline:** dev.12 transaction register and all earlier finance features work. Do not repeat the previous setup exercises.
**Starting main:** 11b8edec71d97f111a16a44c02ac46fbf119633b, documentation follow-up to tested application 605ffe4334f20a94197f923fff12562e9de8737d, tree 507235f9a15065c51b0251cbd0083ef90ecf4263.
**Starting successful build:** run 40772902439. GitHub Actions is the preferred Windows download route.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/CATEGORY_HISTORY.md, docs/CATEGORIZATION_RULES.md and docs/LOCAL_STORAGE.md. Inspect live refs, PRs, releases and workflows before changing or publishing anything. Public source and development-workflow artifacts are authorized. Releases/tags, credentials/visibility changes, server/provider/payment setup, unattended workers and Codex CLI automation remain outside scope. Never force-push or discard concurrent work. All fixtures are fictional.

## This iteration

History is accessible beside Add rule inside Categorization rules. It reads the existing encrypted categorization audit, including batches created in dev.11/dev.12. Details show original/applied/current categories and the original rule version. Undo needs explicit full-batch review and a reason; original events stay intact and a new inverse event is appended.

Undo restores categories only when every transaction exactly matches its post-batch record and is not reconciled or voided. Incomplete/duplicated evidence, stale revisions/fingerprints and repeat undo are rejected. No partial application, automatic rule execution or database rollback. Saved rule definitions, financial values, account postings, transaction count, import receipts and schedule links remain unchanged. Budgets/reports recalculate category effects. No new financial migration or dependency.

## Source map

- apps/client/lib/local/category_history.dart: audit read model, complete-batch validation, review fingerprint and atomic category-only inverse.
- apps/client/lib/local/category_history_widgets.dart: history list, read-only batch details, reason/review and failure-safe undo controls.
- ledger.dart/local_api.dart: one new mutation route, with existing persistence and idempotency.
- category_rule_widgets.dart: History entrypoint and stale-preview invalidation on return.
- test/category_history_test.dart, category_history_storage_test.dart and category_history_widgets_test.dart: financial, audit, storage and interface regression coverage.
- integration_test/category_undo_restart_test.dart: real OS-key/SQLite undo persistence across separate write/read Windows app processes.

Main shell, register, rules engine, budgeting, recurrence, matching, imports, reconciliation, reports, planning, transaction editor, encryption, SQLite, OS keys, updater and backend remain preserved. Data stays at %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Stable names Budgetism.exe and Budgetism-Windows-x64.zip.

## Validation and delivery gate

Retain Flutter 3.47.8, all analysis/tests, every existing native process pair and planning/report/register preservation check. Add the undo write/read pair using UNDO_TEST_PHASE and an isolated UNDO_TEST_DIRECTORY. Build and package 0.1.0-dev.13, verify exact package identity/runtime/hashes, and require Defender scans of that ZIP and its extracted contents before delivery. Do not suppress analysis/tests/scanners or enable in-app installation.

Local source-layout/package negative controls and unchanged Go tests/vet passed. Flutter/Dart/.NET SDKs and a Windows GUI are not available locally; no compilation or desktop success is implied by authored tests. Record actual hosted evidence, run/commit/artifact hashes and remaining limitations in docs/VALIDATION.md before offering the download.

No binaries, databases, credentials or temporary logs in tracked source. Root allowlist unchanged. Use an expected-head normal fast-forward after checking concurrent edits; preserve historical milestone branches. No release/tag or production approval.

## Next desktop check

Back up dev.12. Open dev.13 and use the existing fictional Rule test batch in Categorization rules > History. Inspect its original category, record count and amount. Enter a reason and explicitly undo the complete batch only when it contains your fictional test entry. Its category should return to Other spending, with the same amount, account balance and transaction count. Restart: history should say Undone, with its reason, and the saved rule should remain. No new sample entries or schema-upgrade prompt are required. Edited/reconciled test batches should be blocked instead of forcing undo.
