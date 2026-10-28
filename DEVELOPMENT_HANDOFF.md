# Budgetism development handoff

**Version:** 0.1.0-dev.3 development preview
**Verified application commit:** f376eb8b08bca041e30aee795d16b5a7883578cb
**Successful CI:** [run 40604743739](https://github.com/TechSavage1989/budgetism/actions/runs/40604743739), all five jobs passed.
**User-confirmed baseline:** dev.2 launches on Windows and retains local records across restart. Dev.3 has passed hosted Windows native security tests, but its complete user-facing workflow has not yet been confirmed on the user's PC.

## Read first and authorization

Read AGENTS.md, this file, docs/IMPLEMENTATION_STATUS.md and docs/LOCAL_STORAGE.md. Inspect the current default branch, branches, open PRs, releases and CI before editing. Never replace newer confirmed work with an old ZIP.

Repository: https://github.com/TechSavage1989/budgetism, public. Public source and non-publishing development workflows are authorized. Releases, tags, visibility changes and credentials are not authorized. Exclusions remain: server setup, Codex CLI automation, unattended workers, payment setup and API-account setup.

The current follow-up changes documentation only. It does not change the tested application code or version, rerun builds for publication, or create a release. Use the application commit above to identify the compiled artifact, not a later documentation-only HEAD.

## Source lineage and build correction

- Dev.2 code: 9bbe21f73bbc79dc1bb42c7c655180113458cbc0; successful run 40580132124; user confirmed restart persistence.
- Dev.3 security implementation: 33cea10232107cf6ee79f717c7d918b7a951203e. Run 40597079736 failed Flutter analysis at main.dart:468 because the backup-menu context lacked a mounted guard. Tests and Windows packaging were not reached. This is the negative control.
- Corrected code: f376eb8b08bca041e30aee795d16b5a7883578cb. Only the missing mounted guard was added. The published main.dart blob matched the locally prepared one-line patch exactly. Run 40604743739 passed analysis, all unit/widget tests, both native Windows process tests, web/Windows builds, backend/ledger tests, updater tests and source-layout checks.
- The source-archive workflow retains exact source snapshots and provenance without publishing releases. The corrected local source tree matched Git tree 0446c12e0f0bb3f64bb29e3abe34a1dd72beff2f before this documentation follow-up.

## Delivered development artifact

GitHub Actions is the primary delivery route because chat downloads did not work for the user. Use [the successful build page](https://github.com/TechSavage1989/budgetism/actions/runs/40604743739), artifact **Budgetism-Windows-x64-development**, ID 12779758618. Extract its outer ZIP, then Budgetism-Windows-x64.zip, and launch Budgetism/Budgetism.exe.

- Artifact envelope SHA-256: 583388f59c4982423a78400d7be6365f5e3de6931b09e2099646e6a7b104f3f0.
- Portable ZIP SHA-256: 6f4f8c94cbd2fb5234562ff4755364381dc9053ea7aa1674150cc8cb00d7fc26.
- Portable ZIP size: 15,833,965 bytes; 18 entries.
- Verified appId TechSavage1989.Budgetism, version 0.1.0-dev.3, platform windows-x64 and launch filename Budgetism.exe.
- Both executables have Windows x64 PE headers. SQLite and flutter_secure_storage Windows plugin DLLs are included. Archive path/CRC checks, both digest layers, and the actual Go updater's verify-only validation passed. This is not publisher signing or an updater installation test.

No GitHub release or tag exists. The public release feed remains empty; in-app installation remains disabled.

## Security behavior and data preservation

New workspace setup defaults to no Budgetism password, using a random key in OS-protected storage. Existing dev.2 workspaces stay protected until the user explicitly changes the setting. Open with the current password, choose User options > Workspace security, turn off Require a password to open this workspace, confirm the current password once and Save.

Both modes retain encrypted financial payloads. Mode conversion rotates keys and preserves accounts, categories, transactions and history. Enabling protection again asks for a new password. Missing keys and failed writes never reset data or fall back to plaintext. Stale windows must reopen after a security change.

Export in dev.3 asks for a separate backup password and does not enable a local password. Old backups remain readable with their original password. Restore replaces the entire workspace only after confirmation and preserves the destination access mode.

**Back up before changing security.** Dev.2 cannot read format 2 after conversion. Keep a pre-change backup for recovery; do not use the older executable against the converted database or delete application-data files to troubleshoot. Device-unlocked data depends on the same OS user/key store. Copying only the database is not a portable backup.

## Code map and stable paths

- apps/client/lib/main.dart: existing shell, release lifecycle, local menus and the corrected context guard.
- apps/client/lib/local/vault.dart: encryption, format compatibility, mode conversion, backup/restore and commit validation.
- apps/client/lib/local/device_keys.dart: OS-protected random-key adapter; passwords are not stored.
- apps/client/lib/local/security_dialogs.dart and workspace_dialogs.dart: optional setup/security/backup controls.
- apps/client/test/local_security_test.dart: compatibility, negative/failure, mode, backup and widget cases.
- apps/client/test/fixtures/legacy_password_v1.json: independent fictional format-1 fixture, not a credential.
- apps/client/integration_test/device_restart_test.dart: real Windows SQLite/key-store write/read in two separate app processes, then both mode conversions.
- services/api and tools/updater: existing backend and updater, unchanged by this fix.
- scripts: layout guard and portable packaging. .github/workflows: non-publishing checks and source snapshots.

Root allowlist remains README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and .gitignore. There are no new root exceptions or moved implementation paths. Supporting documents belong in docs/ and historical notes in docs/releases/. Build output belongs under ignored build/. Never commit generated runners, databases, keys, binaries or temporary reports.

Launch: Budgetism.exe. Portable ZIP: Budgetism-Windows-x64.zip. Windows database: %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3. Secure keys are namespaced by random vault salt in OS-protected plugin storage. Theme/public update metadata remain per-user. Keep the same Windows profile when replacing only the program folder.

## Verified commands

From apps/client with Flutter 3.47.8 and the Windows toolchain:

~~~powershell
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter test integration_test/device_restart_test.dart -d windows
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.3
flutter build web --release --dart-define=APP_VERSION=0.1.0-dev.3
~~~

CI invokes the native test twice, using SECURITY_TEST_PHASE=write/read with the same isolated SECURITY_TEST_DIRECTORY. Both passed. The standalone command above performs same-process close/reopen; it is not equivalent to the two-process CI test. The Windows job builds from a clean source archive without .git.

From the source root, run python scripts/check_layout.py --self-test and python scripts/check_layout.py. From tools/updater, run go test -race ./... and go vet ./... on a suitable host; the Windows workflow uses go test ./.... Backend checks are dotnet build services/api/Budgetism.Api.csproj --configuration Release and dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release. Build the Go helper into build/tools/Budgetism-Updater.exe, then run scripts/package_windows.ps1 -Version '0.1.0-dev.3'.

## Remaining checks and next work

See [validation evidence](docs/VALIDATION.md) and [Windows user testing](docs/WINDOWS_TESTING.md). Manual dev.3 dialogs, file pickers and a complete end-user workflow still need confirmation on the user's Windows PC. Hosted native key-store tests are not a full GUI or independent security audit. Mobile/macOS/Linux distributions, live PostgreSQL operation and the full updater install/relaunch/rollback path remain unverified. Local SDKs and a Windows GUI were unavailable; hosted checks supplied compilation and native testing.

Deliver the verified artifact and test existing-data conversion off, restart without a prompt, and unchanged balances. After the user confirms that baseline, proceed to monthly category budgets with actual spending, remaining balances and optional rollover. Cross-device synchronization, recurring bills and forecasts remain later milestones. Do not enable updater installation or claim production financial safety.
