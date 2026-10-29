# Budgetism development handoff

Development: 0.1.0-dev.17, daily-use Home, direct Settings tools and faster local transaction entry. Starting main 086fbd7b26bf420296103f47de7c7e5b4a8da1e7 (tree f5139c7de1710967bbcbb1e28e9d12367eda2a13) is the documentation follow-up to tested dev.16 application ef07b3438605a3de215c4cf1f75bccf015f519fc, successful run 40816063799. The user confirmed dev.15 and requested continued ease-of-use development; do not invent manual dev.16 confirmation.

## Scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/DAILY_USE.md, docs/DATE_CONTROLS.md and docs/BANK_CONNECTION_PLAN.md. Public source/development artifacts remain authorized. No releases/tags, credentials/visibility changes, bank/provider enrollment, paid subscriptions, server setup, unattended workers or Codex CLI automation. No real financial data or credentials in fixtures. Recheck refs/PRs before writes; never force-push or overwrite concurrent work.

## Implementation

Home uses the retained ReportEngine for exact balances through today and month-to-date spending. Future-dated actuals are disclosed separately. Existing monthly budget and upcoming schedule summaries remain available. Home links directly to add, scheduled activity, reports and tools; recent rows open protected transaction details before edits.

Settings exposes categories, rules/history, saved import profiles, CSV import, reconciliation, security, backups, appearance and update checks. Old user-menu routes are retained. Wide navigation is scrollable; narrow screens use four primary destinations plus More opening the full drawer. Bank/device-sync status remains explicitly not connected.

Local entry adds searchable account/category/split selectors and local history-only payee autocomplete. Selecting payee text never copies money/categories. Save and add another is new-entry-only, uses one operation per successful entry and preserves unchanged failed-save retries. It clears amount/payee/notes/splits/transfer destination and retains ordinary category, source account, type and date only for that open session. Closing does not undo saved entries. No new financial schema, encryption, backup, dependency or storage-path change.

FinanceShell moved from main.dart to finance_shell.dart as a part of the same library; existing public imports remain valid. New files local/entry_controls.dart and local/daily_workspace.dart contain presentation/read-model helpers. Transaction editor and shell are the only previous behavior changed; ledger/API mutation engines, keys, rules/imports/profiles/history processing and updater installation stay unchanged.

## Validation gate

New entry_qol_test.dart and daily_workspace_test.dart cover helpers, cancellation, protected records, Home totals, explicit selectors, autocomplete, repeat-save retry/single-flight, transfer/split clearing and narrow/wide layout. entry_qol_restart_test.dart exercises actual Windows quick-entry saving with real OS keys/SQLite in separate write/read processes. Keep all earlier tests including native date controls. Update the retained register-navigation test only for the intentionally renamed Home label.

The assembled source requires hosted analysis/test/build validation. No passing dev.17 compilation, native run, package scan or manual user test has been claimed. Record exact final commit/run/artifact hashes in docs/VALIDATION.md before delivering. No local Flutter/Dart/.NET SDK or Windows runtime exists here. Never suppress failures. Stable Budgetism.exe and Budgetism-Windows-x64.zip; user data remains per-user and outside the program folder.

## Next user check and product direction

Back up the existing workspace, open the verified new build in a separate program folder and try Home, Settings and a searchable selector without saving. A small optional fictional two-entry test confirms Save and add another clears details and persists only explicitly saved transactions. Do not repeat prior budget/import/rule exercises.

After this cohesive usability milestone, implement the provider-independent simulated bank feed from BANK_CONNECTION_PLAN.md: source identities, pending/posted changes, duplicate-safe retries, preserved user categories/notes and a clear review inbox. Real bank support needs institution/country/account types and separately approved provider authorization. No live connection or device synchronization exists yet. Window geometry and full updater installation remain later work, not claimed as completed here.
