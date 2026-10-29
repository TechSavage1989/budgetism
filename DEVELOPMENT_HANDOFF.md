# Budgetism development handoff

**Development version:** 0.1.0-dev.16, calendar date selection and usability shortcuts.
**User-confirmed baseline:** dev.15 CSV category suggestions and all earlier milestones work. Do not repeat the earlier setup exercises.
**Starting main:** 57c958720a87dbe16ae2aa17e1e8e2061a71b2e9, tree 937edf4032ce2b715f69a9c5990284c4986a2403. This documentation-only follow-up preserves application b32e53e1a37a08ca4dd0a4dcb2830ce1b096d153, successful build 40809471115.

## Scope and continuity

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/DATE_CONTROLS.md and docs/USABILITY_ROADMAP.md. The user explicitly requested ease-of-use work, especially calendar date selection instead of typing. Public source and development artifacts remain authorized. No releases/tags, visibility or credential changes, server/provider/payment setup, unattended workers or Codex CLI automation. Recheck live refs and PRs before normal expected-head writes; never force-push or discard concurrent work.

Preserve the optional password, encrypted local workspace, independently encrypted backups, every financial collection and all prior features. No new financial schema or migration, package dependency, encryption format or local data path. Do not copy databases into packages. Stable filenames remain Budgetism.exe and Budgetism-Windows-x64.zip.

## Implementation

New apps/client/lib/date_controls.dart contains strict date-only conversion, a shared calendar picker, date fields with calendar/Today/optional-clear actions, inclusive date-range presets and a visual month/year dialog. Calendar UI starts in calendar mode; manual entry remains optional. Invalid input only influences the temporary picker seed and is not changed on cancel. Date choice updates a controller and callback, never a ledger. Picker controls respect disabled/read-only states, bounds and in-flight selection. A controller changed while the picker is open is not overwritten on return.

Schedule start/end, recorded/postponed occurrence dates, statement ending dates and rule date ranges use the shared controls. Existing schedule anchors remain locked. Postponement and later statement calendars honor their existing lower bounds. Register fields use the shared control and add atomic date-range shortcuts while preserving all other filters. Rule range changes clear old preview/selection/confirmation. Budgets use a month grid and visual year selector, with This month. Transaction editing adds Today/Yesterday and expands calendar selection to the existing ledger-supported years rather than stopping at 2100. Reports, financial calendar and the sample/server form already have calendar controls and remain unchanged.

## Source and tests

Only presentation files, version/workflow references, new tests and documentation change. Ledger, financial engines, rules/imports/profiles/history, encryption/SQLite/OS-key code, API and updater implementation are preserved.

- test/date_controls_test.dart: exact parsing, leap/DST/year bounds, presets, calendar confirmation/cancel, optional clear, disabled/locked states, stale controller handling, narrow/wide range layouts and visual month/year selection.
- test/date_workflows_test.dart: real schedule/occurrence/statement/register/rule/transaction screens, unchanged finance data, frozen review dates and old/future date editing.
- integration_test/date_picker_native_test.dart: real Windows calendar interaction tied to an isolated encrypted SQLite workspace; selection alone leaves ciphertext untouched; explicit transaction save changes only the date and survives reopening.

Retain Flutter 3.47.8 and the complete existing unit/widget/native suite. Add the new native date-picker test after the existing CSV-rule restart pair. Build/package 0.1.0-dev.16, inspect Windows/web compilation, source/package negative controls, backend and updater checks, and exact ZIP/extracted Defender scanning. Do not suppress failures. No local Flutter/Dart/.NET SDK or Windows GUI is available; hosted tests are required and manual user interaction is a separate gate.

## Delivery gate

Source edits and tests are prepared. Local source-layout and package negative controls passed. No hosted passing build or scanner clearance for dev.16 has been claimed yet. Record exact commit/run/artifact hashes and performed checks in docs/VALIDATION.md before delivery. No app installation or release publication is authorized by this milestone.

## Next desktop check

Back up dev.15 and open the new package in a separate program folder using the existing workspace. Try selecting dates in a new schedule and a statement review, then cancel without saving. Use register Last 7 days and All dates, and select a budget month/year visually. Existing balances and transactions should not change. Earlier import/budget/rule test exercises do not need repetition. See docs/WINDOWS_TESTING.md. Next usability priorities are documented separately, not claimed as implemented.
