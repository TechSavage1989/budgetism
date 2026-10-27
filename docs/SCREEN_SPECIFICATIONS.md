# Screen Specifications and Navigation

> **Design reference only.** This document is historical v0.2 product scope, not a description of implemented Budgetism features. No server setup, deployment, unattended workers, payment integration, or external API-account setup is included in the current 0.1.0-dev.1 development scope.

Version: 0.2 draft

## Global adaptive shell
Desktop/web wide: left collapsible sidebar; top toolbar with workspace, date range, global search, add-transaction button, sync status, settings; main content; optional right detail pane. Split panes and columns are resizable where supported.
Tablet: compact sidebar and sheet-style details.
Phone: bottom navigation Home, Activity, Add, Budget, More; drilldown pages; sticky primary action where useful.
Breakpoints must be decided based on tested usability, not platform names alone.

Primary navigation: Dashboard, Accounts, Transactions, Budgets, Calendar, Forecast, Bills, Goals, Reports, Settings. The first baseline may show disabled or hidden navigation entries for unimplemented modules, not nonfunctional controls pretending to work.
Global search available from toolbar and a keyboard shortcut. A sync status control opens a panel with queued change count, last success, current server connection, and conflict list. Financial figures may be masked by privacy mode across all screens.

## Screen S01 - Dashboard
Header: current period selector, account scope filter, privacy toggle, Customize action.
Four recommended KPIs: available cash, expenses this period, unallocated budget funds, upcoming bills (next 30 days). Net worth shown separately from spendable cash.
Body: cashflow actual/projected chart, budget summary by category, recent activity, upcoming commitments, actionable warnings.
Actions: click any figure to reveal underlying account/transaction scope; reorder/hide widgets, restore default; adjust period without losing other settings; navigate to source records. Negative projected balances include date and contributing items.
Empty state: explain how to add an account/import transactions. Offline state: show local values with pending-sync badge, not a misleading 'fully synced' label.

## Screen S02 - Accounts and account register
Left account navigator: expandable institution groups, account type icons, displayed balances and optional hide/archived filter.
Header: account name, currency, posted/cleared/pending summary, reconciliation status, buttons Add, Transfer, Import, Reconcile.
Main register columns: date, payee, memo, category, amount, running balance, status. Optional columns: tags, source, attachment, cleared date, imported external ID. Column widths saved by device; sort and filter persistent per account.
Right details pane: editable transaction fields, posting breakdown, source/import metadata, history, attachment list. Expand to a standalone detail page on small devices.
Transactions never disappear because an account is archived. An account balance always shows timestamp, status basis, and included transaction types.

## Screen S03 - Transaction editor
Transaction type switcher: Expense, Income, Transfer, Refund, Adjustment.
Controls: account, date, payee, amount, currency, category, tags, note, cleared/pending status, and attachment. Transfer type replaces category with destination account and records linked balanced postings. Split mode adds rows and shows residual amount; save disabled until balanced. Duplicate warning appears before importing or saving if warranted.
Save / Save & Next / Cancel. On desktop, shortcut to create transaction and edit selected record. After save, focus returns to prior register position.
Editing a reconciled item requires special confirmation and can instead use an adjusting entry. Unsaved draft confirmation on navigation.

## Screen S04 - Budgets
Top: budget period selector, method indicator, projected income, available-to-assign, spending totals, rollover summary.
Category table: category, allocated, spent, planned, remaining, carryover, status; sections can collapse. Click a category for its transactions, rules, and previous periods.
Interactions: edit allocation inline, move funds between categories, toggle rollover according to rules, copy prior month's plan with preview, compare months. Clearly explain when current account balance differs from budget availability.
On mobile, each category becomes a compact card with remaining funds and drilldown controls.

## Screen S05 - Calendar
Top: month/week/agenda switch, previous/next/today, account filter, actual+projected balance toggle.
Date cell: day, net flow, closing projected balance, scheduled event count, warning indicator; click opens a daily timeline panel.
Day panel: opening balance; confirmed payments and deposits; future scheduled/estimated items; projected closing balance. Distinguish confirmed vs estimated with labels and icons.
Actions: add one-time scheduled item, edit recurring occurrence/series, mark paid, postpone, skip, inspect source transactions, navigate to forecast chart.

## Screen S06 - Forecast
Header: horizon presets (30/60/90 days), account selection, scenario selector, toggle uncertain estimates.
Main chart: verified historical balance as solid line; future projected balance as visually distinct dotted line; highlighted minimum balance dates; optional lower/upper sensitivity bands only when justified by explicit assumptions.
Below: projection table grouped by date with opening amount, income, expense, transfers, closing amount; drilldowns reveal included postings and schedules.
Scenario editor (advanced): copy baseline, adjust income, spending, dates, or one-time events, compare scenarios; never modifies actual transactions without explicit confirmation.

## Screen S07 - Bills and subscriptions
List/calendar with payee, due date, expected amount, recurrence, linked account, next occurrence, last matched payment, and status. Filters for due soon, overdue, recurring, subscriptions, variable amount.
Actions: add, confirm, edit series vs occurrence, skip, postpone, stop recurring, link actual payment, show forecast consequences.

## Screen S08 - Reports
Report picker; period and account/category filters; charts plus accessible tables; clear total calculations and source drilldown. Export after validated rendering, with consistent printed headers and complete tables.

## Screen S09 - Settings and server management
Sections: Profile & Security; Devices; Server Connection; Backup & Restore; Accounts & Categories; Rules; Appearance; Import Templates; About & Updates; Diagnostics.
Display current client/server version, last backup verification, migration status, connection diagnostics, and device revocation. Warn before deleting workspaces, overwriting restores, and applying irreversible schema changes.

## Screen S10 - First-run and reconnect
Choose Connect to self-hosted server or Create local-only workspace (native clients). For self-hosted connection: enter HTTPS URL, test certificate and connection, enroll device, authenticate, choose workspace, initial sync progress. Never accept an invalid TLS certificate without a clearly segregated development-only path.
Reconnect UI must preserve offline work, show pending count, retry safely, and request intervention when two devices changed the same financial aggregate.

## Design system rules
- Theme: light and dark, configurable accent and density, accessible contrast.
- Desktop keyboard focus, logical tab order, large-table virtualization, screen reader semantics.
- Selection and scrolling state preserved when returning from detail panes.
- Use text labels for warning/success states, not color alone.
- All examples in mockups are fictitious and must be marked sample data.
