# Everyday usability in dev.17

## Home and navigation

The local Home page uses the existing historical report engine to show assets/cash, net recorded balance and month-to-date recorded expenses through today. These are not bank-reported balances, market valuations or forecasts. Undated opening balances remain the saved baseline. Future-dated actuals are excluded from those Home totals and recent activity, with a visible count; Accounts and Transactions continue to include all recorded dates. Monthly budget totals still cover the full month, which is stated beside the summary. Schedules remain plans, not actual payments.

Common actions are Add transaction, Bills and income, View reports and Settings and tools. Recent entries open the existing transaction-details review; protected or voided records cannot be edited. Current data is rechecked before handing off to the editor. Navigation and viewing never mutate finances.

Settings offers direct access to categories, categorization rules/history, saved import profiles, importing, reconciliation, optional-password security, encrypted backups, theme and update checks. Existing user-menu paths remain. The desktop rail scrolls at short heights. Narrow screens use Home, Accounts, Transactions, Budgets and More; More opens the full navigation drawer including Calendar, Forecasts, Reports and Settings. Local-only tools stay unavailable in demo/server mode.

## Searchable entry fields and payees

Account, destination, category and split-category buttons open a searchable list of saved names. Search is case-insensitive and session-only; Cancel preserves the selection. Selecting an ID changes the form only. No free-text label silently creates a new account or category. Missing IDs and unavailable selections do not silently become a different record.

Payee suggestions use non-voided saved transactions of the same income/expense type. Prefix matches appear before contains matches, with recent dates first and case-insensitive deduplication. Up to eight names are shown. Transfer descriptions are not suggested from spending payees. Choosing a suggestion changes only payee text; it cannot copy an amount, category, note, split or transfer destination. No network request or persistent search preference is used.

## Save and add another

Available only when adding new local transactions, not editing an existing one. Each click explicitly saves exactly one transaction through the original ledger API. A successful save keeps the editor open and displays its saved-entry count. Amount, payee, notes, split allocations and transfer destination clear. Source account, transaction type, date and an ordinary unsplit category remain for this open session. Split templates are not reused; transfers require a destination to be selected again. Closing the dialog does not undo saved entries, and an empty follow-up entry cannot be saved.

Each successfully saved entry has a fresh operation ID. An unchanged failed-save retry keeps its original ID and data. Changing entered data gives that request a new identity. Saving is single-flight; disabled controls and picker dialogs cannot accidentally submit a second transaction. No keyboard shortcut submits the underlying form while choosing a payee/date/category.

Calendar controls, exact cents, split balance validation, stale-version checks, import receipts, schedule links and reconciliation locks remain intact. All persisted financial changes still require the existing explicit Save or Void action. No default/search text is written to plaintext preferences.

## Continuity and limits

No new schema, package dependency, storage migration or security-mode change. Backups and all existing collections remain compatible with the existing dev.16 financial format. This milestone does not implement bank connectivity, cross-device sync, background posting, bank payments, window geometry, automatic categorization or update installation. Bank access remains the next major product direction, starting with simulated data rather than a live provider.

Validation is recorded separately in VALIDATION.md. A source implementation or authored test is not proof of a passing runtime check.
