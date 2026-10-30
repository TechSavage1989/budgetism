# Dev.25 report graphs and forecast controls

Verified client-only development package following dev.24. No new financial
schema, encryption, database/API deployment or dependency is required. It operates
on the same loaded local or server display snapshots; no provider is contacted.

## Configurable reports

The Graphs view reuses ReportEngine's exact monthly results for the selected
inclusive historical dates and accounts. Users select income/expenses, net income
or recorded balance; line/bar presentation; and a month to inspect. Exact values
remain available alongside the visual view. Signed values and zero activity must
remain visible, including refunds and negative balances. Partial-month and dated
opening semantics match the existing report engine. Existing category drilldown
and explicit unencrypted CSV exports remain separate and unchanged.

## Read-only forecast scenarios

Choose 1–365 days and explicitly select which scheduled templates participate.
Apply changes only the detached forecast; Cancel retains the current selection.
Reset restores the deterministic normal-schedule baseline. Recorded transactions,
future actuals, saved templates and occurrences are never edited by configuration.
Recorded-only, normal-schedule baseline and scenario amounts are distinguished;
excluded schedule assumptions and overdue limitations remain visible. Transfers
continue to net by the selected account sides, and already recorded occurrences
are not projected twice. A one-day horizon must remain valid and inspectable.

All configuration is session-only. No financial selections or assumptions are
saved to device preferences. There are no hypothetical cash amount changes in
this increment. Forecasts are plans, not predictions or bank-reported balances.

## Verification and delivery

[Final verification](DEV25_VALIDATION.md) records all six passing hosted jobs,
372 tests, all 34 retained/extended native Windows commands, inspected fictional
screenshots and independent package/hash/Defender checks. The exact verified
client ZIP is delivered separately. No private installation was attempted.
The installed dev.24 API, database, keys and client are preserved. Actual user
acceptance remains unconfirmed; synthetic tests are not authenticated live-user
validation.

Local source-layout and Windows-package negative controls passed. Local Flutter
validation was not run: SDK bootstrap was stopped by automatic review for an
unexpected instance-metadata request. No workaround or retry was used. Hosted
checks supplied Flutter/native evidence without changing security permissions.
