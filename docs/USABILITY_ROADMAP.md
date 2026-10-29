# Usability priorities

The user confirmed dev.15, requested calendar selection and clarified that the end goal is a real-bank-connected, intuitive personal finance app. Dev.16 implements calendars; dev.17 implements the everyday navigation and entry milestone. Check VALIDATION.md for the exact tested application; an implemented feature is not a claim of manual confirmation on the user's PC.

## Implemented: dates and everyday use

Calendar selection, inclusive date ranges, Today/Yesterday and visual budget month/year controls are retained. Home adds direct actions, recorded balances through today, monthly budget and scheduled-activity summaries, and protected recent-record details. Settings exposes categories, rules/history, profiles, statements, security and backups without the old nested route. Narrow screens have four primary destinations plus the complete More drawer; the desktop rail scrolls.

Local entry now has searchable account/category/split selectors, history-only payee text completion and explicit Save and add another. Each successful entry uses a fresh operation identity. Amount, payee, notes, splits and transfer destination clear, while ordinary category/account/type/date remain only in that open dialog. No new financial schema, migration, personal plaintext defaults or automatic posting. See DAILY_USE.md.

## Next: bank-data foundation and one review inbox

Do not continue adding isolated CSV subfeatures indefinitely. Build provider-independent source records and account links, a simulated read-only feed, and an intuitive review inbox using fictional data. Keep bank-reported, available, recorded and projected balances distinct, with visible timestamps and connection status.

Cover pending-to-posted replacement, corrections, removed-source events, duplicate-safe retries, interrupted/partial retrieval, existing/manual transaction matching, transfer direction and preserved user categories/notes. A failed batch must not consume the sync checkpoint or delete existing records. Reconciled corrections become visible conflicts, not silent rewrites. Design Connect bank, initial account mapping, Refresh, Reconnect and Disconnect around the same verified flow. See BANK_CONNECTION_PLAN.md.

Only after those tests pass, verify the user's institution/country/account types and select a suitable provider with current coverage, costs, privacy terms and access requirements. Read-only is the initial scope; no bank payments or transfers. Provider enrollment, paid plans and live-bank authorization remain separate approval steps.

## Further quality of life

Add remembered desktop window size/position with sensible off-screen recovery, more consistent focus/keyboard support, and a clearer first-run experience. Remember personal account/category defaults only through an approved encrypted model. Search stays session-only. Preserve dialogs so keyboard selection cannot submit the underlying financial form.

Prefer one meaningful review for routine actions and undo where safe. Keep confirmations for destructive actions, migrations, connection authorization, reconciliation changes and real ambiguity. Error messages should identify what happened, what was preserved and the next useful action. Do not claim an amount is Safe to spend until its account scope, pending activity, commitments and exclusions are fully defined.

## Cross-device ownership and delivery

Keep the self-hosted Flutter/.NET/PostgreSQL direction, encrypted native data, optional local password and independent backups. Bank synchronization and device synchronization are separate systems. Private-server setup, external API enrollment, subscriptions and real-bank authorization are not side effects of QoL work.

A tested in-app update workflow should remove repeated ZIP handling, but still requires native install/relaunch/rollback tests and authorization for release/tag publication. Do not enable untested installation or delete rollback safeguards. Non-Windows native distributions and synchronization remain unfinished.

Do not repeat setup exercises for confirmed features. Each delivery should offer a small end-to-end check of the new experience. No bank provider, credential, server deployment or new background task is configured by dev.17.
