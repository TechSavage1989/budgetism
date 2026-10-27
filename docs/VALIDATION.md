# Validation: 0.1.0-dev.3

## Established baseline

The user confirmed dev.2 starts on Windows and retains local records after restarting. This is a user-observed workflow, not a full financial or security audit. Starting code commit: 9bbe21f73bbc79dc1bb42c7c655180113458cbc0. Prior successful build run: 40580132124.

## Performed locally

- Exact upstream source archive and SHA-256/provenance verification.
- Reviewed root guard, including deliberate-clutter negative control.
- Unchanged Go updater unit tests. These do not validate local encryption.
- Source/documentation inspection. Local environment has no Flutter/Dart SDK or Windows GUI.

## Authored gates, pending the change's hosted run

- Flutter analysis and complete existing/new unit/widget suite.
- Independent legacy format-1 compatibility fixture and wrong-password negative control.
- Password-free creation/reopen; password on/off; preserved financial records.
- Missing key, key-store write/readback failure, failed DB commit, stale window and metadata-tamper refusal.
- Independent password-encrypted backup/restore with unchanged destination mode.
- Actual Windows OS secure storage: first native process writes, second process reopens and tests both mode changes.
- Web/Windows compilation, extracted-source build without .git, .NET/ledger and Go regression checks.
- Exact Windows artifact, manifest identity/version, SHA-256 and native library inspection.

Manual Windows end-user dialogs, file pickers and native updater installation are separate remaining checks. Mobile/macOS/Linux distributions are not validated by Windows/web CI. No release, tag, deployment, signing or production approval is implied.
