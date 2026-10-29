# Budgetism development handoff

**Development version:** 0.1.0-dev.15, explicitly reviewed CSV category suggestions.
**User-confirmed baseline:** dev.14 saved import profiles and all earlier features work. Do not repeat the earlier setup exercises.
**Starting main:** 58ba75a92aa8e92454e43146e1c3849508e3fe69, tree 1b60a5ffeee92ee1a6da2b27ab488c21c48527ea.
**Starting application:** b6d515686ba8344d957fe5ec3dd692c283141691, tree 53d01b4f44cd5360bc6b7c70c42296af3d43dc72, successful run 40801825492. The main follow-up changes documentation only.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/CSV_RULE_SUGGESTIONS.md, docs/IMPORT_PROFILES.md and docs/CATEGORIZATION_RULES.md. Recheck live refs/PRs/releases before publication. Public source and development-workflow artifacts remain authorized, not releases/tags, credentials/visibility changes, server/provider/payment setup, unattended workers or Codex CLI automation. Never force-push or discard concurrent changes. Every fixture is fictional.

## This iteration

CSV review now offers Review category suggestions. Existing saved rules propose categories for new expense/income import choices. Select and confirm suggestions explicitly, then complete the original CSV review/import separately. No automatic rule execution or historical edits. A first enabled priority match wins, including a no-op. Manual-only rules, matches, handled/skipped/invalid rows, transfers and transfer-hinted descriptions are excluded. Manually chosen and previously accepted categories are protected within the preview. Duplicate decisions and every non-category field remain unchanged.

The rule dialog rechecks the current workspace plus file/review fingerprint before changing detached choices. A stale review fails visibly and preserves the user's selection. Accepted choices clear the final CSV-review checkbox; only the existing import mutation writes finance records. No new schema, dependency, migration, encryption or backup change. Keep existing saved profiles/rules, category undo, statements and optional-password setting intact.

## Source map

- apps/client/lib/local/csv_rule_suggestions.dart: immutable proposals, priority/eligibility, session fingerprint and selected detached category replacements.
- csv_rule_widgets.dart: responsive selected/reviewed suggestions dialog, cancellation, errors and single-flight acceptance.
- csv_import_widgets.dart: explicit entrypoint, manually reviewed category tracking, suggestion labels and final-review invalidation.
- test/csv_rule_suggestions_test.dart, csv_rule_storage_test.dart and csv_rule_widgets_test.dart: pure financial invariants, protected choices, staleness, import atomicity, backup/reopen and actual import-screen UI checks.
- integration_test/csv_rules_restart_test.dart: real Windows SQLite/OS keys, read-only acceptance, one explicit import and exact category/balance/duplicate behavior across separate write/read processes.

Ledger mutations, CSV parsing/import receipts, rules engine, profile persistence, category history, all financial calculations, register/editor, keys/storage, updater and backend are unchanged. Budgetism.exe and Budgetism-Windows-x64.zip remain stable. Keep per-user workspace at %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3.

## Validation and delivery gate

Retain Flutter 3.47.8 and every existing analysis/unit/widget/native check. Add CSV_RULE_TEST_PHASE=write/read with an isolated CSV_RULE_TEST_DIRECTORY. Build/package 0.1.0-dev.15, verify exact identity/runtime/hashes, and require Defender scans of both the delivered ZIP and extracted files. No suppression, skipped tests or scanner bypass.

Local checks and authored tests do not establish hosted compilation. Inspect the exact CI commit/run and downloaded artifacts before delivery; record performed checks, hashes, scanner evidence and any corrections in docs/VALIDATION.md. No local Flutter/Dart/.NET SDK or Windows GUI is available. Native execution is hosted evidence, not a manual desktop confirmation.

Keep generated output under ignored build, not tracked root. Recheck expected branch heads/open PRs before normal fast-forwards, and retain historical development branches. No release/tag or updater install.

## Next desktop check

Use an existing fictional account and a fictional CSV row whose description matches a saved rule. Preview first with Other spending, explicitly review/accept a Groceries suggestion, and confirm that the row category changes only in the preview. Account balances and stored transaction counts must stay unchanged. Close without importing for a no-new-transactions check. An optional final import creates the row once using its reviewed category. No schema-upgrade prompt is expected in the existing dev.14 workspace. Tests of earlier budgeting/profile/history features need not be repeated.
