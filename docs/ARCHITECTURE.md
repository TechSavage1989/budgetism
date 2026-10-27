# Technical Architecture and Self-Hosted Operations

> **Design reference only.** This document is historical v0.2 product scope, not a description of implemented Budgetism features. No server setup, deployment, unattended workers, payment integration, or external API-account setup is included in the current 0.1.0-dev.1 development scope.

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
