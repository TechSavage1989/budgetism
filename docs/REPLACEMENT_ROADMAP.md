# Budgetism replacement roadmap

The October 30 goal is an everyday replacement for MoneyWiz and PocketSmith, not
just a bank-import demonstration. This is a phased workflow roadmap, not a claim
of feature parity. The verified starting point is dev.24 on
`development/plaid-dev19`; main is an older local-only checkpoint.

## Priorities and completion criteria

| Phase | Scope | Completion evidence |
| --- | --- | --- |
| Dev.25 candidate | Configurable report graphs and session-only forecast controls | Exact chart/table agreement, signed values, chosen account/date scope, baseline/scenario distinction, no ledger writes, native UI checks |
| Reporting depth | Category and comparison-period controls, reusable encrypted report presets, richer export | Saved configuration restores faithfully; totals reconcile to source transactions; canceled edits do not persist |
| Forecasting depth | Reusable encrypted scenarios, explicit amount/date assumptions, broader horizon policy | Baseline remains deterministic; assumptions never post money; future actuals and transfers enter once; recovery preserves scenarios |
| Schedule depth | One-time/custom/finite recurrence, occurrence-specific changes versus future series, variable expected amounts | Stable identities, explicit change scope, no historical rewrites, exact retry/record/match behavior |
| Bank readiness | BankFive/United States and Plaid-first compatibility, supported account types and history, initial review and connection recovery | Verified institution/provider coverage and cost, separate live authorization, complete atomic imports, pending/posted corrections, no duplicates or silent reconciled edits |
| Replacement readiness | Migration rehearsal, daily-workflow acceptance, data recovery, local/server feature gaps | Explain unsupported imports/features; reconcile counts, balances, splits, categories and schedules; independently restore backups before retiring the previous app |

Existing dev.24 includes budgets, schedules/calendar, forecasts, historical reports,
account trends, categories, labels and saved searches on the private server.
Local imports, profiles, rules/history, splits/edits/voids and reconciliation remain
separate advanced local tools. Investments, multi-currency and local/server sync
need distinct designs rather than implied support.

## Official reference workflows

- [MoneyWiz reports](https://www.wiz.money/features/reports): account/date-scoped reports, saved reports and PDF/CSV export.
- [PocketSmith saved reports](https://pocketsmith.helpkit.so/reports/6a6X8SseDBrzYELeJ73BE2/income--expense-saved-reports/6a6X8SseDADKKXQDbcfwTC): reusable account/category/date controls.
- [PocketSmith calendar and graph](https://learn.pocketsmith.com/article/1246-using-the-calendar-and-forecast-graph): account/scenario/date scope and actual/forecast distinction.
- [PocketSmith scenarios](https://learn.pocketsmith.com/calendar--forecasting/6a6X8SseDAXwf8ZqYunJuU/scenarios-everything-you-need-to-know-about-scenarios-in-pocketsmith/6a6X8SseDAQ8gWy6LCbMW8): switchable what-if changes to a baseline.
- [MoneyWiz bills and forecasts](https://www.wiz.money/features/bills): planned income/expenses and scheduled cash-flow projections, not guarantees.
- [PocketSmith repeating budgets](https://pocketsmith.helpkit.so/budgets/6a6X8SseDBUaJ16SUBj86C/repeating-budgets-and-how-to-delete-or-make-changes-to-them/6a6X8SseDCjsgEcKi8N9HX): explicit occurrence/future-series change scope.
- [MoneyWiz bank sync](https://www.wiz.money/features/bank-sync): institution/account/provider-dependent coverage and freshness.

Official materials reviewed October 30, 2026. These inform acceptance criteria;
Budgetism does not copy private data or assets or connect to either competitor.

## Current boundaries

Dev.25 does not save report/scenario choices across sessions. Persisted financial
configuration must use deliberately designed encrypted local/server contracts,
not ordinary device preferences. It does not add hypothetical amount edits,
comparison periods, new recurrence semantics, live banks or migrations.
No release/tag, paid service, credential setup, real account linkage, unattended
refresh, public/LAN exposure or installed server change is included. The existing
server and protected recovery keys remain untouched. Bank account types and
migration-source/export details will be clarified when those phases begin.
