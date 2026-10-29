# Budgetism development handoff

**Development version:** 0.1.0-dev.14, saved encrypted CSV import profiles.
**User-confirmed baseline:** dev.13 categorization history/undo and all previous features worked. Do not repeat their setup exercises.
**Starting main:** a5b89e75b9f704b96c5f307f25b7647351a58f87, tree 77dbba7b82555e84d71ca4c5830090dbdfc95906. Its application is 6f6e33c58c297fc55dde40ce74aae9a64f2acc7a, successful run 40781260879. Main's follow-up is documentation-only.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/IMPORT_PROFILES.md, docs/CSV_IMPORT.md and docs/LOCAL_STORAGE.md. Recheck live refs, PRs, releases and runs before writes. Public source and development artifacts are authorized; no tags/releases, visibility/credentials changes, provider/server/payment setup, unattended workers or Codex CLI automation. Never force-push or discard concurrent work. All fixtures are fictional.

## This iteration

The import screen saves, explicitly applies and updates named profiles; management renames, archives and restores them. Settings include delimiter, date format, amount mode/sign, mapped header names and default categories. Header resolution is unique, case-insensitive and whitespace-trimmed, with no positional fallback. Reordered/extra columns are supported; missing/ambiguous mapped headers clear preview and block import until explicit correction. Destination account, statement rows, filenames and duplicate decisions are never saved in a profile.

First profile save requires explicit backup/upgrade consent for financial schema 7. Earlier financial schemas remain readable without an automatic upgrade. Preserve all collections, rule/undo audit, statement protections and local security; profiles are included in encrypted backups. Existing CSV receipts and transaction commits remain unchanged. Loading/previewing is read-only and no rule/import runs automatically.

## Source map

- apps/client/lib/local/import_profiles.dart: ledger part for schema validation, names, settings, versioned saves/archive/restore and migration.
- csv_profiles.dart: convert reviewed indexes to unique names and bind profiles to a later CSV without guessing.
- import_profile_widgets.dart: save/update confirmation and profile management.
- csv_import_widgets.dart: selected-file workflow, visible profile settings, explicit application and preview invalidation; injectable file picker for tests.
- ledger.dart/local_api.dart: new schema/list and two explicit mutations; storage, encryption and key handling unchanged.
- test/import_profiles_test.dart, import_profiles_storage_test.dart, import_profile_widgets_test.dart: unit/storage/UI regression coverage.
- integration_test/import_profiles_restart_test.dart: real Windows OS-key/SQLite save/reopen in separate processes, reordered-file preview and duplicate rejection.

Keep all prior budgeting, schedule, forecast, import, matching, reconciliation, reporting, rules, register and history tests. No new dependency. Stable Budgetism.exe and Budgetism-Windows-x64.zip, per-user workspace location and optional password remain unchanged. No sync or updater installation enabled.

## Validation and delivery gate

Flutter remains pinned to 3.47.8. The full retained/new analysis/unit/widget/native suite, web/Windows compilation, source/package negative controls, backend ledger contracts, Go tests and exact ZIP/extracted Defender scan remain mandatory. Add PROFILE_TEST_PHASE=write/read with one isolated PROFILE_TEST_DIRECTORY. No suppression or skipped failures.

Local source-layout and package-verifier negative controls, unchanged Go race tests and go vet passed. No local Flutter/Dart/.NET or Windows runtime is available. Hosted checks and the exact Windows package have not yet been verified for this iteration. Authored tests are not passing runtime evidence. Update docs/VALIDATION.md with exact run/commit/artifact/hash and scan results before delivering.

Keep generated files outside tracked root. Recheck main/branch/PR heads before normal expected-head fast-forward, and preserve historical branches. Current data remains separate from the extracted app. Once schema 7 is saved, older apps cannot reopen it; retain the pre-upgrade encrypted backup.

## Next desktop check

The existing fictional CSV is enough. Save its mapping with Groceries as the expense default, restart, apply that profile to the example, and preview without importing. Profile and categories must persist, selected account must not change, and transaction counts/balances must remain unchanged. No more budgeting or prior-feature setup tests are needed. See docs/WINDOWS_TESTING.md.
