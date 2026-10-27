# Acceptance Tests and Definition of Done

> **Design reference only.** This document is historical v0.2 product scope, not a description of implemented Budgetism features. No server setup, deployment, unattended workers, payment integration, or external API-account setup is included in the current 0.1.0-dev.1 development scope.

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
