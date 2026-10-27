# Budgetism - Comprehensive Design Specification

> **Design reference only.** This document is historical v0.2 product scope, not a description of implemented Budgetism features. No server setup, deployment, unattended workers, payment integration, or external API-account setup is included in the current 0.1.0-dev.1 development scope.

Version 0.2 | October 27, 2026
Status: requirements and architecture baseline, no implementation yet.


---

# README.md

# Budgetism: Historical Design Baseline v0.2

Status: Design-only baseline. No application code, hosted service, release, GitHub repository, or deployment has been created as part of this document set.
Date: October 27, 2026

## Product
A personal finance application designed for private self-hosting, with synchronized Windows, macOS, Linux, web, Android, and iOS clients. The initial target user is one owner, with extensible support for household workspaces in later releases.

## Documents
- docs/PRODUCT_REQUIREMENTS.md: Product scope, features, rules, and priorities.
- docs/SCREEN_SPECIFICATIONS.md: Detailed screen layouts, controls, and navigation.
- docs/ARCHITECTURE.md: Technology, deployment, privacy, security, and release model.
- docs/DATA_MODEL_AND_SYNC.md: Financial ledger, entities, and synchronization rules.
- docs/ACCEPTANCE_TESTS.md: Release-blocking functional and integration scenarios.
- DEVELOPMENT_HANDOFF.md: Decisions, unresolved matters, and next development actions.
- AGENTS.md: Development guardrails for future sessions.

## Proposed software structure (not yet created)
- apps/client: Flutter app for desktop, mobile, and browser.
- packages/domain: Client-side financial model and validated offline projections.
- packages/ui: Shared adaptive design system.
- services/api: ASP.NET Core backend.
- services/worker: Background jobs and scheduling.
- infrastructure/compose: Docker Compose and reverse proxy templates.
- tests: Cross-platform, ledger, sync, security, migration, import, and golden fixture tests.
- docs: Source-of-truth product and technical specifications.

## Target milestone
The first executable development milestone is v0.1.0-alpha.1, with an initialized server, one private owner account, accounts, manual transactions, a validated posting ledger, one Windows client, one web client, and offline change synchronization. Android and iOS application projects must be configured from the start; fully verified mobile distributions may follow once signing/build environments are available.

## Scope control
Do not treat this design specification as implemented functionality. No release should be described as complete before tests and working build artifacts exist. No repository visibility, hosting arrangement, or publication permission is presumed.


---

# docs/PRODUCT_REQUIREMENTS.md

# Product Requirements Specification
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


---

# docs/SCREEN_SPECIFICATIONS.md

# Screen Specifications and Navigation
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


---

# docs/ARCHITECTURE.md

# Technical Architecture and Self-Hosted Operations
Version: 0.2 draft

## 1. Stack
Flutter/Dart clients: Windows, macOS, Linux, Android, iOS, web. ASP.NET Core on .NET 10 LTS for HTTPS API and authentication. PostgreSQL for server data. Native desktop/mobile: SQLite accessed using a vetted cross-platform data layer such as Drift; evaluate SQLCipher integration for encrypted local storage. Flutter web initially uses authenticated server reads/writes, with no claim of guaranteed offline durability.

## 2. Client modules
- App shell and adaptive navigation.
- Domain models and money-safe arithmetic (no floating point for money).
- Repository interface with native local SQLite implementation and browser API implementation.
- Offline outbox and sync manager (native).
- Transaction editor, accounts, budget, schedule, calendar, forecast, reports.
- Secrets access through OS keystore/keychain/credential vault; no API tokens in plaintext preference files.

## 3. Backend modules
- Auth/owner/bootstrap and registered devices.
- Workspace authorization and scoped requests.
- Ledger posting and account balances.
- Categories, rules, budgets, schedules, forecast services.
- Import/export and deduplication.
- Incremental sync endpoint with version and idempotency handling.
- Audit and diagnostics.
- Background job worker; deploy as separate service later if beneficial.

## 4. Container deployment
Initial Compose distribution: API, web static server/reverse proxy, PostgreSQL, optional backup job. Use named/persisted volumes and secrets provisioned by the operator. DB must not be bound to public host interfaces. API only accessible through reverse proxy under HTTPS. Restrict server access through a private LAN/VPN; recommend WireGuard for remote private connectivity. A configured domain and certificate trust are prerequisites for reliable mobile/browser HTTPS use. Include healthchecks, startup validation, sample environment file without credentials, upgrade and recovery instructions.

## 5. Ownership, availability and offline behavior
Server stores the authoritative synchronized state; each enrolled native client stores a local working replica. Native clients can create/edit local entries offline and queue mutations for later sync. Cached authentication should allow device unlock while offline after successful enrollment, with configurable local timeout. Revocation cannot retroactively erase already copied offline data; that limitation must be disclosed. Web client requires active server connection in first release.

## 6. Security
- One-time initial owner bootstrap; no public registration.
- Passwords hashed using a modern adaptive hash, with MFA/passkey extension.
- TLS for all API/web connections including over VPN, and safe certificate validation on clients.
- Least-privilege DB/service permissions; server checks workspace authorization for every request.
- Encrypted local device storage where technically supported and tested; OS-protected data keys.
- Encrypt backup archives and off-host backups; do not include secrets in public logs.
- Session and device revoke management; short-lived access sessions and safely rotated refresh credentials where appropriate.
- Audit significant edits and privileged operations without logging bank credentials or raw full transaction payloads.
- Dependabot/dependency scanning, automated tests, threat model, and penetration/security review before broad release.

## 7. Backup and disaster recovery
Cover DB, attachments, workspace config, migration state, encryption-key recovery instructions, and operator-managed secrets. Define daily logical backups plus tested retention policy; exact policy and storage location are deployment configuration. Protect backups with authenticated encryption and separate key management. Verify backup creation, integrity, and ability to restore into an isolated instance. Before any migration, take a recoverable backup. Schema rollback may not be possible without restoring backup.

## 8. Distribution and updates
- Windows portable by default: stable executable name and a versioned release archive containing required Flutter DLLs/data. 'Portable' means no installer; it does not imply a lone standalone EXE. User data must live outside the replaceable application folder unless portable-data mode is explicitly selected.
- A signed/reliable update manifest, integrity checks, application stop-and-swap, and preserved stable shortcut target. Do not install browser extensions or alter unrelated browser profiles.
- Server upgrades managed by versioned container images, explicit migration checks, backups and compatibility matrix.
- Web frontend version tied to compatible API.
- Android APK build signed; iOS requires macOS/Xcode and provisioning for native distribution. No unsupported cross-platform release claim.
- During staged rollout, clients must recognize incompatible server schemas and show a safe update-required state; avoid deleting queued offline changes.

## 9. Quality attributes
- Reproducible source-controlled builds with pinned dependencies and CI checks.
- Responsive desktop transaction register with virtualization and stable selection for large datasets.
- Repeatable golden test vectors for server/client money calculations.
- Traceability from a user-facing amount to source transactions and filter settings.
- Local security, backup and restore tests, migration tests, real cross-device sync tests.
- No hidden internet dependency for ledger, budgeting, forecasting, or local device access.


---

# docs/DATA_MODEL_AND_SYNC.md

# Financial Data Model and Synchronization Specification
Version: 0.2 draft

## 1. Accounting invariants
1. Posted ledger transaction contains at least two journal postings. Journal debits and credits balance within each accounted currency; cross-currency movement uses explicit FX bridge/valuation entries.
2. Owning-account transfer never creates income or spending, except separately recorded fees or FX adjustments.
3. Credit card purchase is expense when recognized; payment reduces checking and card liability, not expense again.
4. Split category allocations must equal the source transaction expense/income amount, accounting for any separate transfer postings.
5. Opening balances are explicit historical postings, not invisible UI offsets.
6. Posted, pending, cleared, reconciled, scheduled, and forecast-only are distinct concepts; a forecast event is not a posting.
7. Financial calculations use exact decimal or currency-specific minor-unit storage, never binary floating point. Precision must accommodate zero/three-decimal currencies and future non-fiat extensions.
8. Reconciliation produces a statement record with closing amount and period; changing a reconciled posting requires tracked correction or explicit authorized unlock.
9. Imported duplicates and repeated network requests never silently create additional posted entries.
10. Every edit has a stable operation ID and an auditable version. Aggregate writes are atomic.

## 2. Entities
Identity and access: User, Device, Session, Workspace, WorkspaceMember (future), WorkspaceSettings.
Financial: Institution, Account, LedgerTransaction, LedgerPosting, Payee, Category, Tag, TransactionTag, ReconciliationStatement, ExchangeRate, Attachment.
Planning: Budget, BudgetPeriod, BudgetAllocation, BudgetTransfer, RecurringSeries, RecurringOccurrence, ForecastScenario, ScenarioAdjustment, SavingsGoal.
Automation/import: Rule, RuleCondition, RuleAction, ImportBatch, ImportMapping, ImportedSourceRecord, ExternalBankLink (future).
Operations: SyncOperation, ChangeLog, DeviceCursor, ConflictRecord, AuditRecord, BackupRecord, SchemaMigration.

## 3. Critical fields
Account: id, workspace_id, name, type, currency_code, opening_date, status, include_in_net_worth, include_in_budget, updated_version.
LedgerTransaction: id, workspace_id, transaction_type, effective_date, posted_date, status, payee_id, memo, imported_source_id, origin_device_id, updated_version, created_at, updated_at.
LedgerPosting: id, ledger_transaction_id, account_or_internal_ledger_id, currency_code, debit, credit, reconciled_statement_id, optional category attribution.
BudgetAllocation: id, budget_period_id, category_id, assigned_amount, carryover_policy, updated_version.
RecurringOccurrence: id, series_id, local_due_date, expected_amount, status, matched_transaction_id, estimated_flag.
SyncOperation: idempotency_key, workspace_id, device_id, aggregate_type, aggregate_id, expected_version, payload, server_sequence, status, received_at.

## 4. Calendar, timezone and schedule semantics
Money posting effective date is a local calendar date with a specified workspace time zone, not a timestamp guessed from UTC. Audit times use UTC timestamps. Monthly recurrences must specify explicit end-of-month behavior for dates such as the 29th, 30th, and 31st. Recurrence and bill-matching routines are deterministic and tested across DST and leap years.

## 5. Native offline synchronization protocol
1. Device enrolls using an authenticated TLS connection and downloads a workspace snapshot with a server cursor.
2. UI reads and writes local SQLite. A transaction edit and its outbox operation commit atomically locally.
3. Each queued mutation carries a unique idempotency key, target aggregate, and expected server version.
4. Server validates authentication, permissions, ledger invariants, schema compatibility, aggregate version, and operation uniqueness.
5. Server commits all postings/related changes and change-log record in one database transaction; assigns strictly increasing workspace change sequence.
6. Client advances its cursor only after all received change records are durably written locally.
7. Retry of the same operation returns the original result instead of applying twice.
8. Client pulls remote changes since cursor; tombstones preserve deletions until devices can safely reconcile.
9. Independent edits on different aggregates can both succeed; simultaneous edits to the same financial aggregate never silently use last-write-wins.
10. Conflicting operation goes to a conflict inbox with original, local, and server values plus user-controlled resolution. Financial transactions are treated as cohesive aggregates, not field-level auto-merges.
11. A full resync reconstructs data from server after queued local changes are exported or safely reconciled. 'Reset local cache' must not silently discard unsent work.

## 6. Import deduplication
Store file checksum and imported record identity when available. Use normalized fingerprint (date, amount, currency, account, payee/reference, available bank-provided ID), with user review for ambiguous matches. Store import batch provenance and undo records. Unique source IDs prevent duplicate imports; fuzzy matching must not automatically suppress legitimate repeat purchases.

## 7. Derived balance and forecast contract
- Posted balance: sum of ledger postings counted as actual under the account's accounting sign convention.
- Cleared/reconciled balance: subset certified by clearing/reconciliation rules.
- Available-to-budget: explicitly defined available funding less assigned funds and applicable carryovers, never conflated with net worth or credit limit.
- Forecast: start with an as-of date and specified posted/pending inclusion policy, apply unmatched scheduled occurrences chronologically, and optionally apply a separately identified estimated-spend model.
- Actual and forecast should reconcile on their shared boundary date; calculations show currency, account filter, inclusion policy, and projection assumptions.


---

# docs/ACCEPTANCE_TESTS.md

# Acceptance Tests and Definition of Done
Version: 0.2 draft

## Release-blocking behavior
AT-001: Create initial owner, enroll Windows device, load workspace from HTTPS server; unauthenticated access denied.
AT-002: Create checking account with opening balance 1000 USD, record expense 80; posted balance shows 920 and transaction register running balance matches.
AT-003: Transfer 200 from checking to savings; total assets remain unchanged and spending does not increase.
AT-004: Credit card purchase 125 increases expense and card liability; payment of 125 from checking reduces liability without increasing expense again.
AT-005: Split 100 expense 40/60 across two categories; cannot save split totaling 99.99 or 100.01 without explicit rounding rule.
AT-006: Import the same statement twice. Verified source duplicates are rejected; uncertain matches appear for review; repeated legitimate purchases preserved.
AT-007: Mark a bill expected on the 15th and import its matching posted payment; forecast includes exactly one outgoing payment, not two.
AT-008: Monthly recurrence starting on January 31 handles February/leap year consistently according to selected end-of-month policy.
AT-009: Change a transaction while offline, restart native client, and reconnect; outbox survives and change syncs exactly once.
AT-010: Two devices edit the same transaction offline; server records conflict and no value is silently overwritten.
AT-011: Duplicate API mutation submission with same idempotency key changes balance once.
AT-012: A device losing connection mid-pull does not advance cursor past non-persisted changes.
AT-013: Budget allocation change does not change any bank account balance.
AT-014: Rollover, category transfers, and negative remaining values have independently tested formula outcomes.
AT-015: Expense refund impacts budget spending according to configured refund policy and does not create phantom income when linked to original transaction.
AT-016: Dashboard actual/forecast end-of-day amounts match ledger/schedule drilldown.
AT-017: Network loss leaves desktop/mobile with available local records, offline edits, and visible sync status; web reports unavailable server without claiming offline persistence.
AT-018: Device revocation blocks new requests after reaching the server; previously offline cached data cannot be remotely erased until the device reconnects, per documented limitation.
AT-019: Restore encrypted backup to new test server recovers ledger, budgets, schedules, and attachments with matching reconciliation totals.
AT-020: Update client and server with compatible versions; no loss of user prefs, transaction data, queued offline changes or shortcuts.
AT-021: Reconciliation locks historical entries, and correction path is audited.
AT-022: Category global search and phrase search return results across appropriate screens with proper navigation and no cross-workspace disclosure.
AT-023: Financial columns are keyboard navigable, selection is retained after editing, and screen reader labels distinguish negative/positive values.

## First executable alpha exit criteria
- Bootstrap one private owner account from a clean Docker Compose deployment.
- Windows native client and browser client run against the same workspace.
- Account creation, opening balance, expense/income/transfer, and current account balance are functional.
- Native offline edits queue and synchronize when connection is restored.
- Transaction ledger tests AT-002 through AT-004 and synchronization tests AT-009 through AT-012 pass.
- CLI and UI display app and API versions, and failures are reported clearly.
- Documented clean install, backup, and recovery steps exist.
- No known data-loss, bypass authorization, silent balance mismatch, or destructive update defects.

## Performance targets to benchmark on documented reference hardware
- Transaction register virtualizes large lists rather than rendering every row.
- Dashboard and filtered register interactions remain responsive with 10,000 transactions in a test workspace.
- Import previews do not block the main UI for large files.
- 24-hour/7-day server outage simulation followed by reconnect completes without double posting or lost queued mutations.
Set numerical latency targets only after a repeatable performance test environment is established.


---

# DEVELOPMENT_HANDOFF.md

# Development Handoff
Status: Design baseline v0.2, not an executable application.
Last updated: October 27, 2026

## Confirmed user direction
- Private, self-hosted personal finance management system.
- Desktop, web, and mobile from the start in system design.
- Cross-device sync and native offline functionality.
- Emphasis on MoneyWiz-level account tracking and PocketSmith-style budgeting/forecasting.
- Windows portable app preferred as initial desktop distribution.

## Agreed / selected technical direction
- Flutter and Dart client, ASP.NET Core on .NET 10 LTS backend, PostgreSQL server, SQLite native local cache.
- Docker Compose deployment behind HTTPS reverse proxy; private LAN/VPN by default.
- One owner workspace first, extendable to shared household workspaces.
- Manual entries/imports before bank synchronization.
- Double-entry ledger, idempotent sync, explicit conflict review and backups.

## Design status
- Product and UI requirements drafted, not approved as fully exhaustive.
- Initial functional test matrix defined.
- Proposed repository layout documented; no working source tree exists in this package.
- No GitHub repository identity or visibility authorized or established.
- No application version, manifest, remote release, or deployment is live.

## Open decisions requiring eventual user or implementation choice
1. Final application name and icon/branding.
2. Hosting platform (Linux host, NAS, mini PC, VM), HTTPS domain/certificate mechanism, and VPN approach.
3. Whether native clients may start with a local-only workspace before first server enrollment.
4. Desired budgeting default (category-budget vs zero-based), and weekly/monthly date handling.
5. Household permissions scope and timetable.
6. iOS build/signing availability and distribution process.
7. Initial import files/formats the user needs.
8. Local encrypted SQLite driver availability across selected platforms and key-recovery policy.

## Next engineering actions
1. Decide app name/repository only when user elects to begin implementation.
2. Create monorepo with Flutter client, API, Docker Compose templates, tests, and baseline design docs.
3. Create first-run owner initialization and secure private API connection flow.
4. Implement ledger types/invariants and automated fixture tests before any dashboard.
5. Build minimal Windows/web accounts and transaction workflows.
6. Implement native offline outbox and server incremental sync with conflict and idempotency tests.
7. Package v0.1.0-alpha.1 after clean-install, backup, migration, sync, and accounting tests.

## Handoff rule
Before any future work, confirm current source and release baseline, inspect DEVELOPMENT_HANDOFF.md for changes since this design draft, and avoid assuming this version is a working build.


---

# AGENTS.md

# Development Agent Instructions

1. Read README.md and DEVELOPMENT_HANDOFF.md before editing code. Inspect docs/PRODUCT_REQUIREMENTS.md, docs/DATA_MODEL_AND_SYNC.md, docs/ARCHITECTURE.md, docs/ACCEPTANCE_TESTS.md for the work area.
2. Confirm actual repository, branch, tags, build artifacts, deployed server version and working app baseline before changing functionality. This pack is design-only; do not invent an existing code baseline.
3. Preserve working features and user preferences unless explicitly requested to change them. Treat financial balance accuracy and sync integrity as release-blocking invariants.
4. No currency arithmetic using binary floating-point. Ledger transactions must remain balanced and financial edits atomic.
5. New schema migrations must be tested against existing data and include backup/recovery guidance. Never rely on automatic downgrades of irreversible migrations.
6. Synchronization retries must be idempotent. Never silently overwrite concurrent financial edits or delete untransmitted offline data.
7. Do not expose PostgreSQL directly to public networks; do not embed credentials or tokens in source or release assets. Never record bank credentials in logs.
8. Apply changes in small reviewable commits. Add tests and update documentation and DEVELOPMENT_HANDOFF.md every release.
9. Do not create a public repository, change repository visibility, publish a release, expose a private service to the internet, or push code without explicit permission and known repository destination.
10. Before publishing a build, verify release assets, update manifest/feed, stable Windows launcher/executable name, app icon, clean migration, sample backup restoration, and live updater test where possible.
11. If unable to test a platform or deploy a service, state the limitation plainly; do not claim success.
12. Finish each development session with current versions, changes, validation results, unresolved issues, and clear next steps for the next session.
