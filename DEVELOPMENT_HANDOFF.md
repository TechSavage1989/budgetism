# Budgetism development handoff

Development: 0.1.0-dev.18, provider-independent fictional bank synchronization and unified Needs Review.

Server preparation now includes Windows service hosting support, configurable PostgreSQL port, a self-contained Windows API/PostgreSQL test kit, five negative package guards, and an additional Windows CI job. User inventory confirms Windows Server 2025 x64, IIS on 80/443, only .NET 7/8 runtimes, and no detected PostgreSQL service. The test kit binds loopback only, initializes a new fictional database, checks auth/idempotency/exact balances/logout and stops both processes. It does not install a permanent service or enable Plaid. Local build and ledger contracts pass; the packaged server smoke test passes. Local Defender is inactive, so no local malware-clearance claim is made; hosted exact-package scanning is required before delivery. Full dev.19 remains unfinished and the desktop version stays dev.18.

October 29 server update: the user authorized private server setup and chose an existing Windows Server 2025 accessed through Remote Desktop. This supersedes earlier deployment-choice-pending and no-server language below. The server's RDP and management ports are reachable; current Windows credentials do not authenticate remote management. No server settings were changed. scripts/server_readiness.ps1 provides a read-only inventory of runtime versions, PostgreSQL services, relevant listening ports and disk space without collecting secrets. Server inventory, authenticated deployment, Plaid integration and verification remain outstanding. Keep the target address and credentials out of public source.

Dev.19 work is on development/plaid-dev19. The initial detached Plaid sync collector and exact-cents conversion have eight fictional tests; all 314 local tests and strict analysis pass. These local changes are not published or connected to the application UI. Credential/authorization and ledger integration await the user's deployment choice in the active chat. Full hosted/native/package/Defender verification has not been run for dev.19, and no dev.19 delivery is claimed.

Plaid Trial signup is now user-completed and dashboard-confirmed: 0/10 connections used. Bank Five - Personal resolves to the intended bankfive.com institution. Live integration, secure credential configuration and fictional API testing remain unimplemented; no secret was revealed or real account linked during the readiness check.

The user has now confirmed dev.18 works and requested the next milestone for BankFive and common United States banks. Provider research and the proposed dev.19 implementation boundary are in docs/DEV19_PROVIDER_DECISION.md. The user selected Plaid first. Trial requirements and adapter constraints are recorded in the provider decision; no new application build, enrollment, payment or server setup has occurred.

## Baseline and scope

The user explicitly confirmed dev.17 works. Development starts at main b222b62a2293c6092fba3ab92e327b46a7802356, whose application is the verified dev.17 baseline. Live branches, PRs, releases and workflows were checked before editing; there were no PRs, releases or tags. Work is on development/bank-foundation-dev18.

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/BANK_SYNC.md and docs/BANK_CONNECTION_PLAN.md before changes. Public source/development workflows and verified development artifacts are authorized. No releases/tags, credentials, live bank/provider enrollment, paid subscriptions, server setup, unattended workers or access changes.

## Implementation

Financial schema 8 adds encrypted bankConnections, bankAccounts, bankSources and bankBatches only after explicit fictional-account/baseline and backup/upgrade consent. Prior schemas/collections remain readable and intact. No changes to encryption, OS key storage, optional local password, SQLite container, backup envelope or dependencies.

BankProvider and BankRefreshService collect complete bounded, consistent pages before a single atomic source/balance/checkpoint save. Only SimulatedBankProvider is enabled. Stable source/account/batch identities, revisions, canonical replay digests, stale-write guards, explicit removal tombstones and pending predecessor relationships protect retries and partial failures. Pending records never enter the ledger.

Connections offers account mapping, distinct recorded/reported/available balances, attempt/success/data timestamps, manual refresh, repeat/interruption tests and disconnect/reconnect. Home and Settings expose Connections and Needs Review. One inbox derives categories, duplicates, pending ambiguity, transfers, schedule matches, source corrections/removals and reconciliation conflicts from current data.

Review explicitly records, matches, pairs transfers/card payments, keeps/ignores, corrects, voids or links schedules. Preserve categories, notes, user payees, split decisions, receipts and occurrence links. A reconciled correction remains blocked until all applicable statements are reopened. No automatic posting, categorization or refresh.

## Verified development package

Application bb67d575cc5b37de1452df6a95a855bde3162374 passed all five jobs in [run 40896092713](https://github.com/TechSavage1989/budgetism/actions/runs/40896092713), including strict analysis, 306 unit/widget/storage tests, all 26 native Windows commands, backend/updater tests, Windows/web compilation, package verification and exact ZIP/extracted Defender scans. The separate source archive run 40896092824 passed; all 193 source file blobs match that application commit. Full provenance, failed-candidate corrections and hashes are in [docs/VALIDATION.md](docs/VALIDATION.md). Documentation-only follow-ups preserve the tested application.

Download Budgetism-Windows-x64-development artifact 12907864433 from that run, then extract the inner Budgetism-Windows-x64.zip. The verified inner ZIP is 16,450,362 bytes, SHA-256 d85e515c73e615b7b0be292db549e902d1e26828d763e1280942e217686ac71e. Its unchanged local delivery copy is named Budgetism-Dev18-Windows-x64-Verified.zip. The packaged updater also passed native Windows verify-only mode locally. No installation was attempted. Defender evidence is artifact 12909136485; both scans reported no threats with signatures 1.463.24.0. Executables remain unsigned.

All original 24 native commands remain; the bank_sync_restart_test.dart write/read pair is added with BANK_TEST_PHASE and BANK_TEST_DIRECTORY. This exercises actual mapping/review UI, Windows secure keys/SQLite, interrupted fetch, idempotent replay, pending replacements, paired transfers, reconciliation conflict and independent encrypted backup recovery across processes. No existing financial assertion, analyzer rule or native gate was removed. The shared Flutter lint configuration is tracked after correcting the first candidate's missing-brace findings. Future delivery still requires full CI, package verification and exact archive/extracted Defender evidence.

## User check and next work

Use docs/WINDOWS_TESTING.md for concise fictional-only tests. Opening an existing workspace does not upgrade it; first mapping explicitly does. Keep a pre-upgrade backup because dev.17 cannot read schema 8. Program files remain separate from per-user data.

After this foundation, refine bank-style daily presentation and review throughput. Live bank support still requires institution/country/account types, researched compatibility and separate provider authorization. Device synchronization, server deployment, remembered window geometry and updater installation remain later work.
