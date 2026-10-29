# Calendar date controls and shortcuts

Dev.16 is a presentation-only usability update. It does not change the financial schema, encryption, security preference, saved profiles or rules. Every ledger mutation still needs its existing explicit save and validation.

## Where calendars are available

- Scheduled: first due date, optional last scheduled date, recorded date and postponed due date.
- Reconciliation: statement ending date before the statement review is generated.
- Categorization rules: From and Through, plus a combined range picker.
- Transactions: existing transaction calendar with Today/Yesterday shortcuts; register From/Through and combined ranges.
- Budgets: a 12-month grid and visual year picker, previous/next year and This month.

Reports, the financial calendar and the sample/server transaction screen already used calendar pickers and are preserved. CSV date-format mapping is deliberately not a date picker: it describes how dates already present in a statement are parsed.

## Interaction and semantics

The calendar-month icon opens a month grid at the current valid date. Select a day and Use date. Month arrows and the year header allow navigation without typing. The Today icon sets the current local calendar day. Optional fields have Clear; the schedule end date stays empty for an unlimited schedule. Text entry remains available in YYYY-MM-DD form.

The picker opens in calendar mode, with Flutter's optional keyboard-entry switch. Cancelling, closing or pressing Escape does not replace the original field, even when its text is invalid. A date is represented by its year/month/day and stored as the same YYYY-MM-DD text. It is never converted between local and UTC instants. Invalid typed dates are not silently normalized.

Register and category-rule ranges offer Today, Last 7 days, Last 30 days, Month to date, Last month and Year to date. Ranges include both endpoints; Last 7 days includes today plus the preceding six days. Month/year to date end today; Last month covers the complete previous calendar month. Register also offers All dates, which clears only its two date fields. Other account/category/search/status/amount filters remain unchanged. A range update is one callback, not two partial filter changes. Range pickers are constrained on wider desktops and remain full-screen on narrow displays.

## Existing protections remain

Saved schedule anchors are still read-only; the calendar cannot bypass that restriction. New schedule end dates can be selected on or after their first due date. Postponement selection must be later than the current due date. A later statement date must follow the latest active statement. At the maximum supported date with no later date available, the calendar action is disabled rather than crashing. Existing validation still rejects invalid manual values.

Statement date controls lock while reviewing selected transactions. Use Change statement details before changing the date. Changing rule dates or choosing a preset invalidates previous suggestions, selection and review. Picking a date does not submit a schedule, record a payment, finish reconciliation or apply a rule.

The shared field prevents overlapping picker launches and disables its shortcuts while one is open. It rechecks enabled/read-only state and bounds on return. A controller changed elsewhere while the picker is open is not overwritten. Picker values, ranges and shortcuts are not stored in preferences or sent to a service.

## Validation

Tests cover exact dates, leap years, daylight-saving boundaries, supported limits, inclusive presets, cancellation, invalid text, locked/disabled fields, stale changes, callbacks, narrow/wide layouts, visual year/month choice and the actual financial forms. A native Windows UI test checks unchanged encrypted data before explicit save and exact date persistence afterward. See VALIDATION.md for the actual performed results.

Implementation references: Flutter showDatePicker and showDateRangePicker API documentation at https://api.flutter.dev/flutter/material/showDatePicker.html and https://api.flutter.dev/flutter/material/showDateRangePicker.html. The pinned CI SDK is unchanged.
