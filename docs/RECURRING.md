# Recurring bills, income and transfers

## Scope

Dev.5 adds native, local recurring planning. It does not add server deployment, synchronization, bank downloads, notifications, background workers, automatic payment execution or automatic transaction posting. Sample mode and the existing-server client remain separate. USD only.

## Dates and occurrence identity

A schedule contains a name, expense/income/transfer type, account, category or destination account, expected amount, payee, notes, first due date, recurrence and optional last scheduled date. Frequencies are weekly, every two weeks, monthly and yearly. Date-only arithmetic uses UTC calendar values, independent of daylight-saving time.

The original start date anchors every occurrence. A monthly January 31 schedule uses February 28 (29 in a leap year), then March 31. A February 29 annual schedule uses February 28 in non-leap years and returns to February 29 in leap years. The last date is inclusive for original due dates. A postponed occurrence may fall after it.

Identity is the schedule ID plus zero-based occurrence index, not the editable due date. Frequency/start/end dates are immutable after creation. Pause the existing schedule and create a new one for a different recurrence. Editing the financial template changes unconfirmed occurrences, including overdue ones, but never rewrites posted transactions or resolved history.

## Upcoming and history

Upcoming includes every unresolved overdue date plus the next 30, 60, 90 or 365 days. It never silently skips missed months. The initial list shows the earliest 200, expandable to 1,000, with an explicit truncation message. Postponed dates are sorted by their current due date, not the original index. The dashboard shows five items and a link to the full screen.

Pause hides upcoming dates but preserves the schedule, overrides and history. Resume restores unresolved dates, including overdue ones. No catch-up posting occurs. History retains confirmed/skipped occurrences. Selecting a recorded item opens its actual transaction unless that transaction was voided.

## Manual resolution

- Record transaction: explicitly confirm an actual amount, recorded date and notes. The current schedule account/category is shown in Upcoming; the recorded date defaults to today. The schedule template remains unchanged. The created transaction may subsequently be edited or split in Transactions.
- Postpone: choose a later date for this occurrence only. No amount moves and later anchors do not change.
- Skip: settle only this occurrence without a transaction. History is retained; this preview does not offer undo-skip or reopening a settled occurrence.

Each occurrence mutation checks the schedule version and occurrence version. A confirmed/skipped identity cannot be confirmed again under another operation ID, even after a restart, backup restoration, edit or void. Retrying the exact original operation is idempotent; changing its payload under the same ID is rejected.

Confirmation creates the actual double-entry transaction and settled occurrence in the same detached ledger mutation and atomic SQLite commit. A failed save changes neither. Stale windows fail revision checks. Income increases the receiving account; transfers/card payments change two accounts without budget spending; expenses affect budgets only in the actual recorded month. A schedule, postponement or skip never contributes to actual balances or spending.

## Financial format migration

Encryption envelope versions 1/2 and SQLite container schema 1 are unchanged. The financial payload schema advances to 3 and adds schedules/occurrences. Dev.5 reads financial schemas 1, 2 and 3. Ordinary edits do not migrate an old workspace. The first saved schedule requires confirmation after exporting a backup and preserves accounts, categories, transactions, budgets, history and the selected security mode. A legacy first-budget upgrade still advances financial schema 1 to 2, independently of schedules.

Dev.4 and earlier cannot read schema 3. Do not run them against converted data. Backups include schedules, resolved occurrences and linked transactions. Restore validates their identities, reference consistency and balanced postings before committing; the destination's password/device mode stays unchanged. Copying only the database is not a portable recovery method for device-key workspaces.

## Limits and validation

At most 500 schedules. Existing 16 MiB plaintext/24 MiB encrypted-envelope limits remain. Schedule templates use one category or destination account; split the actual transaction after recording when necessary. No holiday/business-day adjustment, variable-amount prediction, automatic matching to manual/imported transactions, reminders, automatic posting, or schedule deletion. Existing actual transactions cannot yet be matched to an occurrence; do not record the same real payment manually and again through Scheduled.

Unit tests cover anchors, overdue ordering, end dates, transfers, budgets, duplicate resolution, retries, stale versions, pause/resume, schema migration and broken links. Storage tests cover failed saves, SQLite reopening, stale writers and backup restore. Widget tests cover form validation, upgrade consent and single-flight confirmation. Native Windows write/read process tests use actual SQLite and OS-protected keys. See the handoff and validation log for which checks have actually run.
