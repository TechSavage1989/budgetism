# Product Requirements Specification

> **Design reference only.** This document is historical v0.2 product scope, not a description of implemented Budgetism features. No server setup, deployment, unattended workers, payment integration, or external API-account setup is included in the current 0.1.0-dev.1 development scope.

Version: 0.2 draft | October 27, 2026

## 1. Purpose and target deployment
Build an original, user-controlled personal finance application inspired by the level of account detail in MoneyWiz and by PocketSmith's flexible budgeting and forecasting. The system will be private and self-hosted, with cross-device synchronization. Desktop and mobile must remain functional offline after initial enrollment. The browser interface may remain online-first in initial releases.

## 2. Decisions
- No mandatory third-party cloud service, advertising trackers, commercial subscription, or external analytics.
- Self-hosted server on user-selected hardware, initially distributed using Docker Compose for Linux/NAS.
- Private network/VPN access is the default; no direct internet exposure required.
- One owner and workspace in the initial milestone; account/workspace model supports future household roles.
- USD default; currency attributes exist in all relevant financial models from the beginning.
- Manual transactions and statement imports first; bank API integrations are optional later.
- A real financial ledger is mandatory. Budget allocations and forecasts are not ledger postings.
- Native offline-first for desktop/mobile, with server-authoritative confirmed synchronized state.

## 3. Personas and primary workflows
Owner: manage all financial records, server connections, categories, rules, backups, reports, and devices.
Future household member: selected accounts and shared budgets with explicit permissions (not in MVP).

First-run workflow: connect to an existing private server or create an isolated local workspace; if the user later joins a server, use an explicit migration/import process, never a silent data merge. For a new server, owner bootstrap must be one-time and disable public signup.
Daily workflow: open dashboard, review balances and due bills, record or import transactions, categorize, inspect budget availability, optionally review forecasts, and synchronize when connected.

## 4. Functional requirements, prioritized
Priority P0 = first working baseline; P1 = initial stable target; P2 = subsequent advanced release.

### FR-01 Dashboard (P1)
- Show selected accounts' cleared, posted, and available balances with clearly labeled meaning.
- Separate on-hand cash, credit available, debt, net worth, monthly income, monthly spending, and budget remaining.
- Show recent transactions, upcoming bills, flagged issues, and forecast warning cards.
- Allow periods (month, prior month, quarter, year, custom), saved workspace views, widgets and reorder/hide, and privacy concealment.
- Display local changes awaiting synchronization, last successful sync, and server health.

### FR-02 Accounts (P0)
- Types: checking, savings, cash, credit card, generic liability, loan, asset, and manual investment account; future specialized types may extend behavior.
- Store institution label, display name, currency, opening balance/date, optional credit limit, grouping, archived status, and include-in-budget/net-worth flags.
- Create, edit, archive, restore, reorder, and group accounts without deleting history.
- Show current posted balance, cleared balance, pending activity, optional bank-stated balance, and account register.
- Reconciled statements lock historical periods unless correction is explicitly authorized and audited (P1).

### FR-03 Transactions and register (P0 essentials; P1 full)
- Types: spending, income, transfer, refund, adjustment; support split transactions and attachments (P1).
- Fields: effective date, posted date, payee, ledger account, category, amount, currency, notes, tags, merchant alias, status, source, external/import ID, and timestamps.
- Support date and description filtering, account/category/tag/status filters, amount ranges, saved searches, cross-entity global search, sorting, selection, and bulk operations (P1).
- Double-entry postings preserve balanced books, including for transfers and credit card payments.
- Imported transaction matching is deterministic, explains each proposed match, and never silently overwrites a reconciled or manually edited entry.
- Undo available for reversible non-reconciled edits; record audit history for substantive edits.

### FR-04 Categorization and rules (P1)
- Hierarchical income and expense categories, active/archived status, reordering, and category aliases.
- Rules with conditions: account, payee/description, amount/date range, transaction direction, and tag; actions: rename payee, category, tags, review flag, optional split template.
- Ordering/priority, test-run preview, exceptions, enable/disable, and explicit scope for imported vs manually entered transactions.
- Rule changes must not retroactively edit history unless initiated with preview and confirmation.

### FR-05 Budgeting (P1)
- Monthly category budgets first, with custom period start and recurring budget templates.
- Available funds, allocated amounts, actual category spend, planned spend, and carryover must be separate quantities.
- Optional rollover, negative rollover, category transfers, multi-category views, and configurable treatment of refunds.
- Optional envelope and zero-based methods (P2), sharing same ledger but separate allocation model.
- No creation of cash transactions when reallocating budget money.

### FR-06 Bills and schedules (P1)
- Schedule income, expenses, transfers, and subscriptions with daily/weekly/biweekly/monthly/yearly/custom recurrence, end date, and exception dates.
- Amount may be fixed or estimated. An occurrence can be confirm, postpone, skip, change amount, or mark as paid.
- A matched posted transaction must suppress its duplicate planned instance in cashflow.
- Notifications can be local on native devices; remote push notification is opt-in and may require external platform services.

### FR-07 Financial calendar (P1)
- Month/week/agenda views with date cells showing projected closing balances, net flow, and count of upcoming items.
- Date details: beginning balance, inflows, outflows, transfers, scheduled items, confirmed activity, closing projected balance.
- Filter to one or more accounts, actual vs forecast, planned vs confirmed, and included/excluded transactions.
- Click an occurrence to confirm/edit/postpone; scenario edits never post actual transactions until explicitly committed.

### FR-08 Forecasting (P1 basic; P2 advanced)
- Begin with current verified ledger snapshot; project due income/expenses/transfers chronologically.
- Show separate actual, committed scheduled, and uncertain/estimated amounts; warn on predicted negative balances.
- Support 30/60/90 day and custom ranges; weekly/monthly aggregates and daily drilldown.
- Advanced what-if scenarios and income variability settings are P2. Never treat a scenario as financial history.

### FR-09 Reporting (P1)
- Income vs expenses, categorized spend, cashflow, net worth, account history, budget variance, and bill/subscription summaries.
- All reports use specified time basis, account scope, currency, pending policy, and transfer exclusion logic.
- Drill down from charts to source transactions. Export CSV/PDF later in P1 after validation.

### FR-10 Imports, exports, and backups (P1)
- CSV with saved per-bank mapping, date/decimal locale parsing, review preview, import summary, duplicate review; OFX/QFX/QIF when feasible.
- Export human-readable structured records plus secure portable backup. Restores must verify version/consistency and clearly explain replacement vs merge.
- Attachment storage backed up with financial database; verify automatic backups by test restore.

### FR-11 Goals, debt, investments (P2)
- Savings targets, sinking funds, contribution plans, loan amortization, payoff scenarios, investments/holdings and historical FX rates.
- Explicitly distinguish market value estimates and ledger balances.

### FR-12 Settings and privacy (P0 essentials; P1 full)
- Server connection diagnostics, owner/security, registered devices, backups, notification rules, locale, currency, timezone, first day of week, fiscal period, theme, display density, privacy mode, and keyboard bindings.
- Local preferences (window geometry) stay on device; financial workspace settings synchronize.
- Separate secure destructive action confirmations from routine edit confirmations.

## 5. Global search requirements
- Search across transaction payees, memos, categories, tags, account names, bills, goals, and attachment metadata (not file contents initially).
- Search syntax in P1: exact phrase, multiple terms (AND), exclusion terms, date range, amount range, account/category scope, and saved filters; advanced OR/grouped expressions in P2.
- Results grouped by entity type, with total counts, snippets, and navigation to the originating record and screen.
- Multi-selection operations only for compatible entity types and permissions; never perform silent bulk financial edits.

## 6. Out of scope for the first stable release
- Moving money between external financial institutions.
- Mandatory bank feed or third-party identity platform.
- Tax filing or investment execution.
- Shared household roles, public signup, multi-tenant hosted SaaS.
- Guaranteed rich offline behavior in web browsers.
- Automatic AI processing or sending transaction contents to external models.

## 7. UX rules
- Important calculations show their components or permit drilldown.
- Destructive or financially material operations show clear consequences.
- Application should default to useful information rather than dense graphs.
- Never use color alone to convey spend/income, deficit/surplus, reconciled/pending, or sync states.
- Native app must keep existing data visible and editable during server outage with offline queued changes.
