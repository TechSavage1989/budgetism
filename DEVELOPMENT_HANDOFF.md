# Budgetism development handoff

Development: 0.1.0-dev.18, provider-independent fictional bank synchronization and unified Needs Review.

## Baseline and scope

The user explicitly confirmed dev.17 works. Development starts at main b222b62a2293c6092fba3ab92e327b46a7802356, whose application is the verified dev.17 baseline. Live branches, PRs, releases and workflows were checked before editing; there were no PRs, releases or tags. Work is on development/bank-foundation-dev18.

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/BANK_SYNC.md and docs/BANK_CONNECTION_PLAN.md before changes. Public source/development workflows and verified development artifacts are authorized. No releases/tags, credentials, live bank/provider enrollment, paid subscriptions, server setup, unattended workers or access changes.

## Implementation

Financial schema 8 adds encrypted bankConnections, bankAccounts, bankSources and bankBatches only after explicit fictional-account/baseline and backup/upgrade consent. Prior schemas/collections remain readable and intact. No changes to encryption, OS key storage, optional local password, SQLite container, backup envelope or dependencies.

BankProvider and BankRefreshService collect complete bounded, consistent pages before a single atomic source/balance/checkpoint save. Only SimulatedBankProvider is enabled. Stable source/account/batch identities, revisions, canonical replay digests, stale-write guards, explicit removal tombstones and pending predecessor relationships protect retries and partial failures. Pending records never enter the ledger.

Connections offers account mapping, distinct recorded/reported/available balances, attempt/success/data timestamps, manual refresh, repeat/interruption tests and disconnect/reconnect. Home and Settings expose Connections and Needs Review. One inbox derives categories, duplicates, pending ambiguity, transfers, schedule matches, source corrections/removals and reconciliation conflicts from current data.

Review explicitly records, matches, pairs transfers/card payments, keeps/ignores, corrects, voids or links schedules. Preserve categories, notes, user payees, split decisions, receipts and occurrence links. A reconciled correction remains blocked until all applicable statements are reopened. No automatic posting, categorization or refresh.

## Validation gate

Local analysis and new bank tests pass; full-suite and hosted verification evidence is recorded in docs/VALIDATION.md. A retained Settings test was updated for the intentional fictional-connection message and checks that both new tools remain disabled outside local workspaces. No existing financial assertion or native gate was removed.

All original 24 native commands remain; the bank_sync_restart_test.dart write/read pair is added with BANK_TEST_PHASE and BANK_TEST_DIRECTORY. This exercises actual mapping/review UI, Windows secure keys/SQLite, interrupted fetch, idempotent replay, pending replacements, paired transfers, reconciliation conflict and independent encrypted backup recovery across processes. Full CI, Windows/web builds, package identity/checksum/runtime verification and exact ZIP/extracted Defender scanning are required before delivery. Never mark an unscanned candidate verified.

## User check and next work

Use docs/WINDOWS_TESTING.md for concise fictional-only tests. Opening an existing workspace does not upgrade it; first mapping explicitly does. Keep a pre-upgrade backup because dev.17 cannot read schema 8. Program files remain separate from per-user data.

After this foundation, refine bank-style daily presentation and review throughput. Live bank support still requires institution/country/account types, researched compatibility and separate provider authorization. Device synchronization, server deployment, remembered window geometry and updater installation remain later work.