# Budgetism development handoff

**Development version:** 0.1.0-dev.11, reviewed local categorization rules.
**Starting main:** 17a5a04b3e8ca1688afce38f4d60859d9ac8c522, documentation follow-up to application 63b5b6cef441ca1889117d6a3b43ec05f5e5aa34, tree 5f2d6f429fdbfc83a373608227de4d609d562c59.
**User-confirmed baseline:** dev.10 reports and CSV export worked. Earlier reconciliation, matching, imports, budgets, schedules, forecasts, persistence and optional-password behavior are confirmed. Do not repeat their setup exercises.
**Starting successful run:** 40737797353. GitHub Actions artifacts are the preferred delivery route.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/CATEGORIZATION_RULES.md and docs/LOCAL_STORAGE.md. Inspect live branches, PRs, releases and workflows before editing. Public source and non-release development workflows are authorized. No releases/tags, credential/visibility changes, server/provider/payment setup, unattended workers or Codex CLI automation. Never force-push, overwrite concurrent work, or commit real financial records. The default branch at the start includes all dev.10 code; do not revert to older milestone branches.

## This iteration

Rules are available through User options > Manage categories > Categorization rules, leaving the existing navigation shell unchanged. Rule editor supports payee Contains/Exact/Starts with, account, type, source, existing category, amount bounds, priority and enable/disable. Saving does not edit history. Dated preview requires selected rows and explicit review before an atomic category-only batch.

Schema 6 is opt-in on first rule save and preserves all earlier collections. Exclude reconciled, split, voided and transfer entries. Account postings, amounts, transaction identity/count, import receipts and schedule links remain unchanged. Budgets and reports recalculate category effects. No automatic application or transmission. Rule text remains encrypted, included in backups, and unaffected by ordinary app updates.

## Source map

- apps/client/lib/local/category_rules.dart: ledger part for definitions, validation, read-only suggestions, precedence and audited atomic category application.
- category_rule_widgets.dart: management/editor, date preview, explicit selection/review, failure retention and single-flight controls.
- ledger.dart / local_api.dart: schema and mutation integration; no encryption or storage changes.
- workspace_dialogs.dart: one category-management entrypoint; existing workspace/backup behavior retained.
- test/category_rules_test.dart, category_rules_storage_test.dart, category_rule_widgets_test.dart: financial/validation/storage/widget regression coverage.
- integration_test/category_rules_restart_test.dart: actual Windows OS-key/SQLite rules and applied-category persistence in separate write/read app processes.

Existing main shell, budget/report/planning engines, imports, reconciliation, matching, recurrence, transaction editor, encryption, SQLite, OS keys, backend and updater remain preserved. No new package dependency. Stable Budgetism.exe and Budgetism-Windows-x64.zip; workspace path remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same OS account.

## Validation and delivery gate

Flutter remains pinned to 3.47.8. Retain all analysis, unit/widget, native process pairs, planning/report preservation tests, web/Windows builds, package-verifier negative controls and Defender scan of the exact ZIP/extracted files. Add the new rules pair with RULE_TEST_PHASE=write/read and a shared isolated RULE_TEST_DIRECTORY. Build/package as 0.1.0-dev.11. No analyzer suppression, skipped tests, scanner bypass or updater installation.

Local source-layout and package negative controls and unchanged Go tests passed. There is no local Flutter/Dart/.NET SDK or Windows GUI. Hosted tests/builds and exact-package scan must be inspected before delivery; no passing compilation is implied by authored tests. Record exact run, commit, artifact hashes and performed checks in docs/VALIDATION.md after completion.

Root allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. Support documents stay in docs; generated output belongs under ignored build. No binaries, databases, private keys or temporary logs in tracked source. New saved rules require a pre-upgrade encrypted backup; older apps cannot read schema 6.

## Next desktop check

Use one new fictional non-reconciled expense with payee Rule test store, amount 12.34 and category Other spending. Note its balance/count after recording it once. Add a rule containing Rule test, restricted to Other spending, targeting Groceries. After backing up, approve first-rule upgrade. Generate preview for its date, select that entry, review and apply. Category changes to Groceries with unchanged amount/balance/count. Restart: rule and category remain. The same preview proposes no further change for that transaction. Do not reopen schema 6 using dev.10 or older. No earlier feature setup exercises or server installation are required.
