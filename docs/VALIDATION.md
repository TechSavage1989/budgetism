# Validation: Budgetism 0.1.0-dev.16

## Baseline and provenance

User-confirmed dev.15 application b32e53e1a37a08ca4dd0a4dcb2830ce1b096d153 passed run 40809471115. Starting main is 57c958720a87dbe16ae2aa17e1e8e2061a71b2e9, a documentation-only follow-up. The available source artifact matches outer SHA-256 09376f0660f374e64e427659ed81059aac806ce79c4da647e52dcccee8d5e459 and inner ce55b4d2b4f5380b870894d279d6b4de053265db3c8d8be1f79ab6b0637f8d82. Reconstructed Git tree f4cc9bfae3baeec0ffa09199dd5e20a3e83acb7a matches the application before editing. Final source writes use current main as parent/base and do not overwrite unchanged newer documentation.

## Local checks

Source-layout and deliberate-clutter checks, package-verifier negative controls and diff whitespace passed. There is no local Flutter/Dart/.NET SDK or Windows GUI. New tests are authored, not passing execution evidence. Ledger and financial engines, CSV/rules/profile/history data processing, encryption/storage/keys, backend and updater implementation remain unchanged.

## Added checks

Exact calendar parsing and format; leap/DST/year limits; inclusive presets; calendar selection, cancel and invalid-text recovery; optional Clear/Today; locked/disabled/bounded fields; stale-controller protection; small/large range layout; month/year selection. Screen tests cover schedule dates, postponement limits, frozen statement dates, register filtering, rule-preview invalidation and a saved transaction after year 2100. Native Windows interaction verifies unchanged ciphertext before Save transaction and the exact selected date, amount, account balance, schema and optional-password state after reopening.

## Required hosted gate

Retain full analysis, all old/new unit/widget tests, every existing native process pair/preservation check, the new native calendar UI test, Windows/web builds, backend/Go tests, package identity/dependencies and exact ZIP/extracted Defender scans. Record the actual commit, run, artifacts and hashes after success. No scanner bypass or skipped failures. No new download, native manual confirmation or updater installation is claimed before this gate.
