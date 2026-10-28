# Calendar and scheduled cash-flow forecast

## Scope and data safety

Dev.6 adds a native-local read-only planning engine and Calendar/Forecasts screens. No new dependencies, server setup, payments, reminders, synchronization, budget-spending estimates, automatic transaction posting, or financial migration. The ledger, SQLite, encryption, device keys, existing budgets, and recurring mutation rules are unchanged.

## Calendar

Navigate by month or choose a date. Day badges show counts of recorded, scheduled, postponed, overdue, skipped and voided activity. Select a date, then an event to inspect its status and per-account changes. Actual transactions can be opened in the existing editor. Planned events link to Scheduled for explicit confirmation/postponement/skip; navigation alone never records money.

Confirmed occurrences appear only as their actual transaction on its actual effective date, not as another planned entry on the original due date. Void retains history without regenerating the plan. Skipped history has no balance effect. Unresolved paused schedules are hidden, but recorded/skipped history remains. Skipped account filtering references the current schedule template because older occurrence records do not store historical account snapshots.

## Forecast contract

Horizons are 30, 60, 90 or 365 days including today, based on date-only arithmetic and the existing recurrence anchors. Start = account opening value + all non-void recorded postings with effective dates through today. Today's recorded entries shown in details are already included. Add only still-unresolved schedules due today. On each later day, add that day's recorded postings and still-unresolved schedules exactly once.

This as-of starting balance can differ from the account register when that register includes future-dated recorded transactions. Those transactions enter the forecast on their effective dates, not again from the schedule they resolved. Editing/voiding linked actual entries uses the existing ledger rules. Changing actual dates/amounts changes projections from the updated source; no cached financial totals are persisted.

The solid line is recorded cash flow plus scheduled activity. The dashed line includes only existing recorded entries. The daily list and selected-day details expose exact USD minor-unit totals. Floating point is used only for drawing coordinates, never for financial addition. The engine rejects exact-range overflow or excessive range sizes rather than silently returning a partial result.

Incoming and outgoing account postings preserve transfers. Transfers cancel when both accounts are selected. The combined view includes checking/savings/cash only, not debts or other assets. Each account can be selected independently. Negative debt balances are not a measure of available credit.

Unresolved overdue occurrences are counted separately and excluded from projected balances. The banner counts account impacts, so a transfer touching two selected accounts contributes two impacts. Review these in Scheduled and explicitly record/postpone/skip. No date is invented for them. Future projection enumeration starts at the requested range rather than using the bounded Upcoming list, so years of overdue history cannot hide future entries. Postponed occurrences are included at their override date, including overrides beyond the template end date. No original-date duplicate is added.

## Warnings and preferences

Warnings apply to end-of-day projected balances, not intraday payment order. Cash accounts default to a zero minimum; debt/other asset accounts default off. Choose one account to enter a signed USD threshold or disable it. Strictly below the threshold triggers the first-day warning; equality does not.

Thresholds are display preferences stored with the existing per-user SharedPreferences mechanism under forecast.minimum.v1 plus an account ID. They are not encrypted or synchronized and are not included in financial backups. No financial transactions, passwords, keys or account names are stored there. Failure to save is reported inline and entered values remain available for retry.

## Limits and assumptions

Opening balances have no dates in the existing model. Historical calendar entries therefore show activity, not a claim to a historically reconciled balance. No prediction of unscheduled expenses, budget consumption, interest, fees, exchange rates, pending bank activity, available credit, or holiday adjustments. Schedule amounts remain estimates until recorded. Duplicate manual entries are still not matched automatically to schedules. At most 100,000 calendar events per request; excess produces an explicit error, never a truncated financial total.

## Validation

Tests cover date anchoring, mixed recorded/scheduled cash flow, moved/voided linked actuals, postponed original dates outside the range, paused/skipped activity, old overdue backlogs, transfer conservation, exact amounts, threshold boundaries, legacy read-only compatibility, desktop/narrow layouts, and native SQLite byte preservation/reopen. Check docs/VALIDATION.md for which exact commit and run were executed.
