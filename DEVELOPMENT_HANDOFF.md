# Budgetism development handoff

**Version:** 0.1.0-dev.3 development preview
**User-confirmed working baseline:** dev.2 on Windows launches and retains local records across restart. The user requested configurable local password protection.

## Read first and source lineage

Read AGENTS.md, this file, docs/IMPLEMENTATION_STATUS.md and docs/LOCAL_STORAGE.md. Inspect the latest default branch, branches, PRs, releases and CI before editing. Do not replace newer confirmed source with old ZIPs.

Repository: https://github.com/TechSavage1989/budgetism, public. Source and non-publishing development workflows remain authorized. Releases, tags and visibility changes are not authorized. Exclusions: server setup, Codex CLI automation, unattended workers, payment setup, API-account setup and credentials.

Starting application source: 9bbe21f73bbc79dc1bb42c7c655180113458cbc0 (dev.2). Run 40580132124 passed its build checks. The previous handoff was stale; the repository already contained compiled local persistence despite describing dev.1. This handoff replaces that stale status, not the working implementation.

An additional source-archive workflow was committed at aa2a75de6b2b6e3091fa88f792d58c0fc6da97f2. It packages exact source and SHA-256 into a temporary artifact without publishing a release. Run 40594589441 produced the source snapshot used for this change; the archive digest and recorded commit were checked before extraction.

## Scope and behavior

- New native workspace setup defaults to no Budgetism password. A visible switch enables optional protection.
- Existing dev.2 password workspaces are not silently converted. Open with the current password, choose User options > Workspace security, turn the requirement off, confirm the current password once and Save.
- Device mode uses a random AES key in OS-protected storage. No plaintext financial records, passwords or keys in preferences. Both modes keep encrypted payloads.
- Enabling protection again asks for a new password, rotates keys and removes the old device credential after the DB commit. Failed cleanup produces a warning, not false failure or a lost commit.
- Conversion preserves all financial records. Format-1 is readable; format-2 binds mode/key metadata and rejects stale windows. SQLite schema and stable paths remain unchanged.
- Export now asks for a separate backup password, without changing local access. Old backups remain readable. Restore preserves the destination mode and requires explicit replacement confirmation.
- This work does not implement cross-device sync, budgets, forecasts, idle auto-lock, password recovery or updater installation.

## Code map

- apps/client/lib/local/vault.dart: encryption, format compatibility, access-mode conversion, backup/restore, commit handling.
- apps/client/lib/local/device_keys.dart: flutter_secure_storage adapter. Only random device keys are saved.
- apps/client/lib/local/security_dialogs.dart: security setting and backup-password dialog.
- apps/client/lib/local/workspace_dialogs.dart: optional setup, opening and existing backup/category UI.
- apps/client/lib/main.dart: preserved shell, Workspace security menu, accurate Close/Lock labels.
- apps/client/test/local_security_test.dart: compatibility, negative/failure, mode, backup and widget tests.
- apps/client/test/fixtures/legacy_password_v1.json: independently generated fictional format-1 test vector; its documented password is not a credential.
- apps/client/integration_test/device_restart_test.dart: actual Windows SQLite/key-store behavior across two native processes, then both mode conversions.
- .github/workflows/build-checks.yml: non-publishing analysis/tests/builds and Windows native security checks.
- .github/workflows/source-archive.yml: exact source snapshot and provenance as a temporary artifact.

Existing ledger/API/updater code and source layout remain otherwise unchanged. Root allowlist: README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md, .gitignore. No root exceptions. Build output belongs under ignored build/. Do not commit generated runners, databases, keys or artifacts.

## Commands

From apps/client with the configured Flutter SDK and Windows native toolchain:

~~~powershell
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter test integration_test/device_restart_test.dart -d windows
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.3
flutter build web --release --dart-define=APP_VERSION=0.1.0-dev.3
~~~

CI runs the native test twice with SECURITY_TEST_PHASE=write/read and the same isolated SECURITY_TEST_DIRECTORY. This validates a real process exit, not only an in-memory fake key store. The single local invocation performs a same-process close/reopen test. The plugin's Windows build needs C++ ATL; non-Windows entitlement/keyring packaging is not validated here.

From source root: python scripts/check_layout.py --self-test, then python scripts/check_layout.py. Run go test ./... from tools/updater. Backend regression commands: dotnet build services/api/Budgetism.Api.csproj --configuration Release and dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release. Build the Go helper into build/tools/Budgetism-Updater.exe, then run scripts/package_windows.ps1 -Version '0.1.0-dev.3'. Use extracted source without .git as CI does.

## Stable storage/update contracts

Launch: Budgetism.exe. ZIP: Budgetism-Windows-x64.zip. Windows database: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Secure keys are namespaced by random vault salt in OS-protected plugin storage. Keep the same Windows user profile. Moving only the program folder must not move the data or clear credentials.

Settings and public update metadata remain per-user. Workspace passwords are not saved. New backups use a separate password; losing OS credentials requires an exported backup or recovery of the original OS profile. Never automatically reset a missing-key workspace. Dev.2 cannot read format 2 after conversion; use backups rather than database downgrade.

Update feed remains the public GitHub releases API, currently empty. No automatic download/restart. Install remains disabled until native update installation/relaunch/rollback tests pass. CI artifacts are not releases or signed distributions.

## Validation status for this change

Local: upstream archive digest/provenance verified; source-layout negative control and clean guard pass; unchanged Go updater unit tests pass. New Flutter analysis, unit/widget tests, native Windows security process tests and packaging require the hosted run for the exact next commit. See docs/VALIDATION.md and inspect current CI before calling it passed.

No new manual Windows GUI validation has been reported yet. User confirmation covers dev.2 persistence only. Neither this implementation nor passing CI establishes production financial safety, independent security audit, mobile support or a validated updater.

## Next work

Verify hosted CI and the exact Windows artifact, then update this handoff with commit/run/results. Deliver the development artifact through GitHub Actions as the primary route because chat download links did not work for the user. Test existing-data conversion off/on and restart on their Windows desktop. After this baseline is confirmed, proceed to budgeting without replacing working persistence.
