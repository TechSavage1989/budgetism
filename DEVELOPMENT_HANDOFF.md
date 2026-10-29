# Budgetism development handoff

Development: 0.1.0-dev.17, daily-use Home, direct Settings tools and faster local transaction entry.

**Verified application:** dd70d39df255a6484179e6df20ee0a63997915ef, tree e21c739f544e4611505bc059a3f9730b44a627b5. **Successful build:** [run 40822480327](https://github.com/TechSavage1989/budgetism/actions/runs/40822480327), all five jobs passed. Documentation-only follow-ups preserve this tested code/version. Starting main 086fbd7b26bf420296103f47de7c7e5b4a8da1e7 (tree f5139c7de1710967bbcbb1e28e9d12367eda2a13) is the documentation follow-up to tested dev.16 application ef07b3438605a3de215c4cf1f75bccf015f519fc, successful run 40816063799. The user confirmed dev.15 and requested continued ease-of-use development; do not invent manual dev.16 confirmation.

## Scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/DAILY_USE.md, docs/DATE_CONTROLS.md and docs/BANK_CONNECTION_PLAN.md. Public source/development artifacts remain authorized. No releases/tags, credentials/visibility changes, bank/provider enrollment, paid subscriptions, server setup, unattended workers or Codex CLI automation. No real financial data or credentials in fixtures. Recheck refs/PRs before writes; never force-push or overwrite concurrent work.

## Implementation

Home uses the retained ReportEngine for exact balances through today and month-to-date spending. Future-dated actuals are disclosed separately. Existing monthly budget and upcoming schedule summaries remain available. Home links directly to add, scheduled activity, reports and tools; recent rows open protected transaction details before edits.

Settings exposes categories, rules/history, saved import profiles, CSV import, reconciliation, security, backups, appearance and update checks. Old user-menu routes are retained. Wide navigation is scrollable; narrow screens use four primary destinations plus More opening the full drawer. Bank/device-sync status remains explicitly not connected.

Local entry adds searchable account/category/split selectors and local history-only payee autocomplete. Selecting payee text never copies money/categories. Save and add another is new-entry-only, uses one operation per successful entry and preserves unchanged failed-save retries. It clears amount/payee/notes/splits/transfer destination and retains ordinary category, source account, type and date only for that open session. Closing does not undo saved entries. No new financial schema, encryption, backup, dependency or storage-path change.

FinanceShell moved from main.dart to finance_shell.dart as a part of the same library; existing public imports remain valid. New files local/entry_controls.dart and local/daily_workspace.dart contain presentation/read-model helpers. Transaction editor and shell are the only previous behavior changed; ledger/API mutation engines, keys, rules/imports/profiles/history processing and updater installation stay unchanged.

## Validation gate

New entry_qol_test.dart and daily_workspace_test.dart cover helpers, cancellation, protected records, Home totals, explicit selectors, autocomplete, repeat-save retry/single-flight, transfer/split clearing and narrow/wide layout. entry_qol_restart_test.dart exercises actual Windows quick-entry saving with real OS keys/SQLite in separate write/read processes. Keep all earlier tests including native date controls. Update the retained register-navigation test only for the intentionally renamed Home label.

All five hosted jobs passed: 270 unit/widget tests, full Windows suite, every retained native test and the new quick-entry process pair, Windows/web builds, backend/updater checks, package verification and exact ZIP/extracted Defender scans. Local source/package/Markdown guards and Go race/vet passed. The delivered ZIP hash matches the scan and updater verify-only validation. See docs/VALIDATION.md for exact evidence and the corrected Home shortcut/native CI target. No local Flutter/Dart/.NET SDK or Windows runtime exists here. Manual user interaction is a separate pending gate. Stable Budgetism.exe and Budgetism-Windows-x64.zip; user data remains per-user and outside the program folder.

Windows artifact 12875328581, outer SHA-256 fa7a6d96a61babf5e20a3fb7233443284621963a2fd9dd08d71a62f7eb9b46cf; inner SHA-256 258107629dd84d93b1f2835608a67218e7ae0a3e25c3ed3c34d10ad3fea9663e. Security artifact 12875842231 reports no threats for that exact inner archive and extracted runtime. Both executables remain unsigned. Do not substitute an earlier dev.17 run. No updater installation or release/tag publication.

## Next user check and product direction

Back up the existing workspace, open the verified new build in a separate program folder and try Home, Settings and a searchable selector without saving. A small optional fictional two-entry test confirms Save and add another clears details and persists only explicitly saved transactions. Do not repeat prior budget/import/rule exercises.

After this cohesive usability milestone, implement the provider-independent simulated bank feed from BANK_CONNECTION_PLAN.md: source identities, pending/posted changes, duplicate-safe retries, preserved user categories/notes and a clear review inbox. Real bank support needs institution/country/account types and separately approved provider authorization. No live connection or device synchronization exists yet. Window geometry and full updater installation remain later work, not claimed as completed here.

## CI continuity

The root guard now validates native target filenames and the exact declared restart phase/directory variables, with negative controls. Preserve all 22 original native commands plus the quick-entry pair. Keep the original category_undo_restart_test.dart and UNDO_TEST configuration. Never bypass failing gates.
