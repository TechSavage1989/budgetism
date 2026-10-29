# Local storage and optional password protection

## Financial schema 7: saved CSV import profiles

Dev.14 stores mapping profiles inside the encrypted payload. The first profile save requires backup/upgrade consent; loading and previewing never write or upgrade data. Schemas 1 through 6 remain readable. Preserve all prior collections, category history and security settings; older apps cannot read schema 7. Encryption, SQLite, OS keys and portable backup envelopes are unchanged. See [import profiles](IMPORT_PROFILES.md).

## Financial schema 6: saved categorization rules

Dev.11 stores rule definitions inside the encrypted financial payload. Viewing or previewing does not upgrade schemas 1 through 5. The first rule save requires explicit backup/upgrade consent and preserves all prior collections. Rule application uses the existing atomic ledger commit and audit with no new postings to accounts. Older builds refuse schema 6. Encryption envelopes, SQLite container, OS keys, optional-password setting and independent backup format are unchanged. See [categorization rules](CATEGORIZATION_RULES.md).

## Financial schema 5: statement reconciliation

Dev.9 adds completed/reopened statement history inside the encrypted payload after explicit first-completion consent. Opening schemas 1 through 4 does not upgrade them. Completion preserves financial records and all prior collections, including CSV receipts. Import and recurring operations accept schema 5 without downgrading it. Active statements protect included transactions and opening-balance changes; explicit latest-statement reopening retains history. Encryption, keys, access mode, SQLite container and backup envelope remain unchanged. Older builds cannot open schema 5. See [statement reconciliation](RECONCILIATION.md).

## Financial schema 4: CSV imports

Dev.7 adds validated import receipts inside the encrypted payload, with explicit consent on the first import. Existing schema 1/2/3 remains unchanged on open. Transactions and receipts commit together, and the access mode and encryption/SQLite formats remain unchanged. Older builds cannot open schema 4. See [CSV importing](CSV_IMPORT.md).

## Financial schema 3: recurring schedules

Dev.5 keeps the SQLite container and encryption envelopes unchanged. The inner financial payload schema 3 adds schedules, occurrence resolution and linked-transaction validation. Existing schema 1/2 stays unchanged on open; the first saved schedule requires explicit backup/upgrade confirmation. Older apps cannot read schema 3. See [recurring behavior](RECURRING.md) for atomic posting, migration and recovery details.

## User behavior

New local workspaces default to password-free access. Setup and User options > Workspace security expose **Require a password to open this workspace**. Existing dev.2 workspaces keep their password until the owner explicitly disables it and confirms the current password once. Enabling protection again asks for a new password of at least 14 characters. No records are deleted or recreated by this setting.

Password-free mode means no Budgetism password prompt, not unencrypted financial data. Anyone using the same OS account can open that workspace. Closing is labelled Close workspace rather than implying a password lock. This setting does not weaken private-server authentication, change demo behavior, or enable synchronization.

## Stable location and formats

Windows database: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Other native targets use their application-support directory plus Budgetism/finance. Only Windows distributions have hosted build coverage. The executable and settings paths are unchanged.

The SQLite table/schema remain version 1. Its current and previous entries contain encrypted financial snapshots. The app reads original format-1 envelopes without modifying them on open. Format 2 is used for new workspaces and explicit access-mode changes. Both use AES-256-GCM, fresh nonces, exact integer ledger values and authenticated metadata. Format 2 authenticates mode, KDF, salt and revision. An older app must refuse this envelope, never reset it.

Password mode uses PBKDF2-HMAC-SHA256, 600,000 iterations, a fresh 16-byte salt and a 256-bit key. The password is not saved. Device mode uses a fresh random 256-bit key stored through flutter_secure_storage under a random per-vault identifier. Its presence is verified before writing the new encrypted workspace. No key or password is stored in preferences, the SQLite envelope or logs. The Windows implementation uses encrypted per-user storage and Windows Credential Manager. Other native OS integrations require their own packaging/entitlement validation.

SQLite headers, schema, revisions, file sizes and timing are visible. Unlocked records exist in memory. Encryption does not protect against a compromised OS account, malicious app replacement, screen capture, or rollback to an older valid database. There is no security audit or production-safety claim.

## Safe mode changes

Access-mode changes rotate the encryption key and salt, increment the workspace revision, and append a non-secret audit event. They preserve all accounts, transactions, categories and operation identifiers. Device keys are written and read back before the SQLite commit. A failed commit leaves the old workspace usable. Cleanup never deletes a key that the current saved envelope references.

After a successful change back to password mode, the obsolete device credential is deleted. A cleanup failure is reported as a warning after the successful mode change; the old key cannot open current data. Previously copied snapshots and external backups are not retroactively protected or erased. SQLite retains one previous encrypted snapshot for correction/crash assistance, not as independent disaster recovery.

Concurrent windows check key identity and revision. Once another window changes security, stale windows must close/reopen rather than silently rewriting under an old key. Corrupt envelopes, missing OS keys, unsupported formats and failed writes do not trigger reset or a plaintext fallback.

## Backups and recovery

The export UI always asks for a separate backup password. It does not turn on the workspace password. Export authenticates the saved data and re-encrypts it with an independently derived key and fresh salt in the portable format-1 password envelope. Device keys are never exported. Old backups remain readable with the original password used to create them.

Restore validates the password, size, schema, identifiers, postings and metadata before a single commit. It replaces the complete workspace only after explicit confirmation. The imported data is encrypted under the destination workspace's current key and mode. It does not import the source device's unlock setting. Export before restore; there is no undo-restore UI.

If the OS key store is lost, return to the original profile/key store or restore an independently exported backup into a new workspace on another profile/device. Copying just the SQLite database to another computer is not a portable backup. There is no password/key recovery, destructive reset helper or automatic downgrade.

## Validation and dependencies

- Unit tests include an independent fictional format-1 fixture, off/on conversion, lost keys, wrong passwords, failed OS writes, failed DB writes, stale windows, metadata tampering, cleanup warnings and portable backups.
- Widget tests cover the default optional setup and new-password confirmation.
- Windows integration tests use the real OS secure-storage plugin and SQLite, in separate write/read application processes, then exercise both access-mode conversions.
- Exact performed checks and remaining limitations are recorded in DEVELOPMENT_HANDOFF.md and docs/VALIDATION.md.

Primary dependency references:
- https://pub.dev/packages/flutter_secure_storage
- https://pub.dev/packages/flutter_secure_storage_windows
- https://pub.dev/packages/cryptography
- https://pub.dev/packages/sqlite3

New dependencies are pinned. Flutter and dependency resolutions used by a build must be verified from its own logs/artifacts. Mobile entitlements, macOS Keychain access, Linux keyrings and distribution remain unvalidated targets.
