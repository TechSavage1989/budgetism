# Validation: Budgetism 0.1.0-dev.18

## Baseline

The user confirmed dev.17 works. Dev.18 starts at b222b62a2293c6092fba3ab92e327b46a7802356. Live main/branches/PRs/releases/workflows were checked before editing and must be rechecked before publication. Historical dev.17 evidence is preserved in [VALIDATION_DEV17.md](VALIDATION_DEV17.md).

## Local verification

Flutter 3.47.8 was downloaded from the official SDK archive and its SHA-256 checked against the official Windows manifest before execution. Flutter analysis and the new unit/widget/storage tests have passed locally. The complete retained suite is being run before publication. No assertions or native test commands were removed. The retained Settings message assertion was updated for the intentional fictional-connection status and extended to check gating of both new tools.

Tests cover old-schema read-only behavior/consent, account mapping/duplicate protection, exact amounts, pending replacement and ambiguous identity, posted corrections/removals, repeated/reordered batches, concurrent/stale writers, failed/uncertain commits, transfer/card-payment pairing, preserved user metadata and populated legacy collections, imported/scheduled relationships, reconciliation conflicts, encrypted backup/restore, optional password and tamper rejection.

The new native bank test exercises actual mapping/review UI plus real Windows OS keys/SQLite in separate write/read processes, interrupted refresh/retry, repeated feed, pending replacements, paired transfers, a locked correction and independent backup recovery. All original 24 native commands are retained; this pair is added.

## Delivery gate

Hosted source/backend/updater/Flutter-web/Windows jobs, every retained/new native test, Windows/web builds, package identity/checksum/runtime checks and exact ZIP/extracted Defender scans are required. Run, artifact IDs and delivered hashes will be recorded after successful verification. This source candidate must not yet be called a verified Windows package.

No live provider, credentials, real financial fixture, server setup, release/tag, updater installation or background worker is included. Native execution and Defender scanning use the existing ephemeral GitHub Windows runner; no antivirus protection on the user's computer is changed.