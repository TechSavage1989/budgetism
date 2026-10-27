# Budgetism development handoff

**Date:** October 27, 2026
**App:** Budgetism
**Version:** 0.1.0-dev.1
**State:** Source baseline prepared for authorized publication to the existing public repository; no verified Windows Flutter app binary and no GitHub application release.

## Repository inspection performed first

- URL: https://github.com/TechSavage1989/budgetism
- Visibility: **public**, user has push/admin access; source publication explicitly authorized October 27, 2026.
- Default branch: `main`, HEAD commit `ded152921fec3f8b141e94f10bba39dc55012e56` (initial README placeholder).
- One root file `README.md` (11 bytes), no AGENTS.md or DEVELOPMENT_HANDOFF.md.
- Active PRs: none. Branches listed: main only. Releases: none. No published update feed.
- User authorized publishing source and development workflows to the public repository. This does not include release binaries, tags, access changes or repository visibility changes.

## Starting source and scope

Previous conversation artifact: `Private_Finance_v0.1.0-dev.1_Source.zip`, uncompiled and unpublished. Used as code lineage because it contains existing Flutter account screens and .NET double-entry accounting. New product name Budgetism; no working installed application was available for regression comparison.

**Exclusions requested:** no server setup, Codex CLI automation, unattended workers, payment setup, or API-account setup. Existing API *source* is retained. No Compose, Docker setup, credential bootstrap scripts or server deployment instructions were added to this Budgetism package.

## New/modified features

- Renamed Flutter package and UI to Budgetism. Backend namespaces now Budgetism.Api; .NET project renamed to Budgetism.Api.csproj. Test references and Windows target naming updated.
- Added a genuinely offline **ephemeral demo** provider with sample accounts/categories and in-memory, balanced income/expense/transfer behavior. Demo is explicitly labelled and does not save or send data; unsupported server capabilities remain separate.
- Added release checker against public `TechSavage1989/budgetism` releases with ETags, cached release responses, manual cooldown, five-minute active checks, startup checks, focus-return interval, single-flight operation, Retry-After and throttling errors.
- Added verified Windows ZIP downloader to application-support `updates/staging`, enforcing HTTPS redirects, allowed asset hosts, maximum bytes, streaming downloads and SHA-256 comparison with GitHub release asset metadata when available. Automatic downloads are never initiated.
- Added Go Windows update helper for SHA-256, archive path, file count/unpacked byte limits, archive identity/version/platform, PE x64 verification and staged replacement/previous version restoration. Helper only, **not connected to Install and restart UI**.
- Added non-publishing CI blueprint, Windows portable ZIP packaging with stable Budgetism.exe and app-release.json/checksums.sha256, root guard and negative controls.
- Updated README to user's standard and added update process documentation.

## Technical source map

- `apps/client/lib/main.dart`: app shell, demo launch, screen navigation, release UI/lifecycle checks.
- `apps/client/lib/demo_finance_api.dart`: fictional, memory-only account and transaction operations.
- `apps/client/lib/finance_api.dart`: existing private API HTTP client.
- `apps/client/lib/release_feed.dart`: Github public release discovery/state/ETag/backoff.
- `apps/client/lib/release_download*.dart`: platform-gated SHA-256 download and staging, no install.
- `apps/client/test/`: currency and release-feed tests, not yet run with Flutter SDK.
- `services/api/`: .NET 10 ledger/API code from prior uncompiled baseline. Uses development-only EnsureCreated, no safe migrations.
- `tools/updater/`: Go CLI helper, ZIP package validation and Windows update/rollback code, Go unit tests.
- `scripts/check_layout.py`: repo root allowlist and negative-control test, works without .git.
- `scripts/package_windows.ps1`: uses compiled Flutter Windows release + Go helper, creates stable-named ZIP and SHA-256.
- `.github/workflows/build-checks.yml`: source lint/build/test, and **workflow artifacts only**, no publish.
- `docs/`: product spec and further implementation details.

## Build/test commands

From source root:

```bash
python3 scripts/check_layout.py --self-test
go test ./...                  # from tools/updater
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags='-H windowsgui' -o Budgetism-Updater.exe .
```

From a .NET 10 host (not verified here):

```bash
dotnet build services/api/Budgetism.Api.csproj --configuration Release
dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release
```

From `apps/client` on a Flutter-capable Windows host (not verified here):

```powershell
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.1
```

Then build Go helper into `build/tools/Budgetism-Updater.exe` and run `scripts/package_windows.ps1 -Version '0.1.0-dev.1'` from source root on Windows. The resulting ZIP contains one Budgetism folder and a stable `Budgetism.exe` plus Flutter support files. No installation or publication occurs.

## Per-user storage and update contract

- Executable: `Budgetism.exe`. Package asset: `Budgetism-Windows-x64.zip`.
- Settings / GitHub release metadata: platform SharedPreferences per-user store, no real finance credentials in update cache.
- Downloads: Flutter application-support `updates/staging`, not application install folder.
- Updater logs: `%LOCALAPPDATA%/Budgetism/logs/updater.log` on Windows.
- Rollback after verified install: one hidden `.<install-folder>.previous` beside installed app. Only app-owned temporary folders may be cleaned.
- Public feed: GitHub releases API for `TechSavage1989/budgetism`, with digest required to enable download.
- No authenticated feed or separate public release repo is required because repository is currently public. If visibility later changes, the update strategy must be reconsidered before publishing.

## Publication notes

- Authorized destination: public `TechSavage1989/budgetism`, default branch `main`. Do not force push.
- Source publication should create one normal commit on top of the initial README placeholder and retain the original history.
- Check CI results, repo tree and feed after upload. No release/tag is authorized.
- Source is not production-safe for real financial data.

## Validation performed in this environment

- Source root guard and negative control: PASS (after documents created).
- Go updater archive unit tests, including good archive, wrong hash, wrong version, traversal, executable injection, wrong PE architecture and custom filename validation: PASS.
- Go Windows x64 PE updater helper cross-compilation: PASS on Linux with Go 1.23.2. This is not a Windows run test.
- Source ZIP integrity, extracted no-.git guard test and Markdown link scan: performed at packaging time.
- Flutter SDK / .NET 10 SDK / Docker: unavailable in this environment. Therefore **Flutter analyze, Flutter unit/widget tests, Windows runnable app build, backend compilation, live database tests, install/restart/rollback native tests and hosted GitHub CI are not validated**.

## Known blockers and next actions

1. Run real Flutter/.NET build and tests on CI/Windows; resolve any compile or UI issues before publishing a release.
2. Test the native Windows updater with two genuine signed/not-signed test builds (including rollback, rename/custom executable, current window health, offline/focus/resume, cleanup and preservation of settings). Do **not** enable Install and restart until these tests pass.
3. Add persistent encrypted native data, synchronized outbox and conflict resolution, versioned backend migrations and verified backup/restore before accepting real financial data.
4. Add budgeting, recurring bills, forecasting, reporting and transaction reconciliation without breaking existing ledger invariants.
5. Check GitHub HEAD, active branches/PRs, read-first docs and source package consistency before requesting explicit approval to push code to the public repo. Tag/build/release publication remains separately authorized.

## Never claim

Do not call this a production-ready finance application, tested native updater, successfully running Windows Flutter executable, deployed server, or GitHub-published release. The only compiled Windows artifact in this deliverable is the isolated updater helper, which is not the app.
