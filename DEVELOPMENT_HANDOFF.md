# Budgetism development handoff

**Development version:** 0.1.0-dev.14, saved encrypted CSV import profiles.
**Application commit:** b6d515686ba8344d957fe5ec3dd692c283141691, tree 53d01b4f44cd5360bc6b7c70c42296af3d43dc72.
**Successful build:** [run 40801825492](https://github.com/TechSavage1989/budgetism/actions/runs/40801825492), all five jobs passed including native profile restart checks and exact-package scanning.
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

All five hosted jobs passed, including analysis, 219 unit/widget tests on the web runner, the complete Windows suite, all retained/new native process checks, Windows/web compilation, package verification and the exact ZIP/extracted Defender scans. One initial UI test exposed a parent loading indicator remaining active during a profile dialog; the app was corrected and all tests retained and rerun. Local source-layout/package negative controls, Go race tests/vet, exact source-tree comparisons and downloaded-package updater verify-only checks also passed. No local Flutter/Dart/.NET or Windows GUI was available; hosted execution is not manual desktop confirmation. See docs/VALIDATION.md for exact evidence.

Keep generated files outside tracked root. Recheck main/branch/PR heads before normal expected-head fast-forward, and preserve historical branches. Current data remains separate from the extracted app. Once schema 7 is saved, older apps cannot reopen it; retain the pre-upgrade encrypted backup.

## Delivered package and continuity

Use Windows artifact 12866993294 from run 40801825492. Outer SHA-256 fcfa9748a2f224d9887ec1a229e50c62283764b04d975c788a52537682823e9c; inner Budgetism-Windows-x64.zip SHA-256 d161ebdc5fd89a8d3a9ff1a796d28a33ca1f099cfd346af85b92a093a4129456, 16,297,677 bytes. Security artifact 12867316574 reports no threats for that exact archive and extracted files. Both executables remain unsigned. Source archive, complete Git tree, app identity/version, runtime dependencies, hashes and actual updater verify-only acceptance were independently checked.

The final follow-up changes only documentation and preserves the tested application. Publish with normal expected-head fast-forwards, retaining historical branches. No tags, releases, provider/server setup or updater installation. Dev.14 manual profile testing is the next user gate.

## Next desktop check

The existing fictional CSV is enough. Save its mapping with Groceries as the expense default, restart, apply that profile to the example, and preview without importing. Profile and categories must persist, selected account must not change, and transaction counts/balances must remain unchanged. No more budgeting or prior-feature setup tests are needed. See docs/WINDOWS_TESTING.md.
