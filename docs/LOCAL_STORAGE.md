# Local workspace format 1

## Scope

This is a native, device-local development workspace. It is not a synchronization implementation and does not call the private API. USD minor-unit values only. The original demo remains memory-only. The .NET/PostgreSQL architecture and eventual self-hosted synchronization are unchanged.

## Storage and encryption

Windows path: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Other native targets use the platform application-support directory plus Budgetism/finance. Native targets other than Windows are not distribution-validated.

The initial SQLite adapter stores a versioned encrypted ledger snapshot. It uses package:sqlite3 3.8.0 and its bundled native assets, not obsolete sqlite3_flutter_libs. This first adapter does not yet use generated Drift tables. Moving to relational Drift tables requires a tested format migration; do not silently reinterpret or replace this snapshot format.

Financial payloads are AES-256-GCM ciphertext. Each save uses a fresh 96-bit nonce and a 128-bit authentication tag. A unique 128-bit random salt and PBKDF2-HMAC-SHA256 with 600,000 iterations derive a 256-bit key from the workspace passphrase. The KDF runs in a compute isolate. Parameters and envelope version are fixed and validated before decrypting; format/revision metadata is bound as authenticated additional data. The passphrase and derived key are never saved.

This is payload encryption, not full-database encryption. SQLite headers, schema, revision numbers, file sizes, and update timing are visible. Unlocked values exist in process memory. This does not protect against malware, screen capture, a compromised OS account while unlocked, or replacement with an older valid encrypted snapshot. It is not an independent security audit or a production-safety claim.

## Commit and conflict behavior

A mutation is validated on a detached ledger copy. Each transaction has balanced exact-integer postings. Opening balances have an offsetting conceptual equity posting; they are not income. Edits replace the active posting set and preserve before/after values in audit events. Voids retain the record and remove its financial effect.

A local operation identifier and canonical request hash enforce retry idempotency. Different payloads may not reuse an identifier. Each transaction/account edit checks its expected record version. A SQLite BEGIN IMMEDIATE transaction also checks the workspace revision, preventing two app windows from silently overwriting each other. Data is shown as committed only after the database commit succeeds.

SQLite synchronous=FULL and rollback journaling are configured. Each successful write retains one previous encrypted snapshot in the same file. This is crash/correction assistance, not an independent disaster-recovery backup. There is no previous-snapshot recovery UI yet. Corruption, unknown schemas, wrong credentials, or a failed write never trigger automatic reset.

## Backup and restore

Export returns an authenticated and schema-validated encrypted envelope. The file uses the workspace passphrase at export time. Restore verifies size, format, authentication, schema, identifiers, amounts, dates, category references, and balanced postings before committing. It replaces the complete workspace and increments the current revision. The restored data is re-encrypted with the current workspace key; the current passphrase stays the same. A restore event is retained in the recovered audit. Prior local data remains only in the previous encrypted snapshot and any separately exported backup.

The preview limits plaintext snapshot size to 16 MiB and imported envelope size to 24 MiB. It favors correctness and portability over large-ledger performance. Encryption and file operations still need profiling on actual Windows hardware. Auto-lock on idle, OS keychain unlock, password changes, audit browsing, incremental sync/outbox and migrations to future schemas are not implemented.

## Dependency references

- https://pub.dev/packages/sqlite3
- https://pub.dev/packages/cryptography
- https://pub.dev/packages/file_selector

Dependencies are pinned for the new persistence components. Existing inherited dependency ranges remain as previously published. CI must validate the exact resolution and artifacts; a complete dependency lockfile is still an additional reproducibility improvement.
