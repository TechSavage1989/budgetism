# Usability priorities

The user confirmed dev.15, requested calendar date selection and clarified that the end goal is a real-bank-connected, intuitive personal finance app. This updates the delivery priorities, not the implemented feature list. Only the date-control milestone is implemented in the dev.16 application.

## Current milestone: dates

Calendar selection for remaining typed date fields, inclusive date ranges, Today/Yesterday for transactions and visual budget month/year selection. Preserve manual entry, cancellation, financial protections and all saved data. No financial migration. See DATE_CONTROLS.md and the exact validation results before installing.

## Next: everyday use and clear navigation

Bring Add transaction, Accounts, Budgets, Scheduled, Reports and Settings into predictable locations. Surface rules, import profiles, reconciliation and backups without unnecessary nested dialogs. Design a simple Home view around balances, bills due soon, remaining budgets and items needing attention, with plain labels that distinguish recorded, bank-reported and projected values.

Add local payee autocomplete from existing history, searchable account/category selectors, a focused quick-add workflow and explicit Save and add another. Make last-used defaults predictable and optional; never reuse transfer directions or splits silently. Personal finance defaults belong in an approved encrypted model, not plaintext preferences. Search stays session-only. Test keyboard focus and shortcuts so a calendar or confirmation dialog cannot accidentally submit the underlying form.

Prefer one meaningful review for routine actions and undo where safe. Keep confirmations for destructive actions, migrations, connection authorization, reconciliation changes and genuine ambiguity. Error messages should say what happened, what was preserved and what the user can do next. Add remembered desktop window size/position as nonfinancial per-device preferences with sensible off-screen recovery.

## Bank connectivity is a primary goal

Do not continue adding isolated import subfeatures indefinitely. Use the established exact ledger, duplicate receipts, category rules and schedule matching as a foundation for a provider-independent bank-data pipeline. Design Connect bank, account mapping, sync status and one Needs review inbox while improving the daily interface.

Implement and test a simulated feed before real connections, including pending-to-posted replacement, provider corrections, transfer matching, interrupted refreshes and user-edit preservation. Select a provider only after verifying the user's institution, country, account types, costs, privacy terms and access requirements. Read-only access is the initial scope; no payments or transfers initiated through the bank. See BANK_CONNECTION_PLAN.md for acceptance criteria and researched provider candidates.

## Cross-device ownership and delivery

Keep the self-hosted Flutter/.NET/PostgreSQL direction, encrypted native data, optional local password and independent backups. Bank synchronization and device synchronization are separate systems and must not be advertised as interchangeable. Private-server setup, external API enrollment, paid subscriptions and real-bank authorization are separate future actions, not side effects of QoL work.

A tested in-app update workflow should remove repeated ZIP handling, but still requires native install/relaunch/rollback tests and authorization for release/tag publication. Do not enable untested installation or delete rollback safeguards. Non-Windows native distributions and synchronization remain unfinished.

Do not ask the user to repeat setup exercises for features already confirmed. Each delivery should provide a small end-to-end check of the new experience, not another round of historical feature tests.
