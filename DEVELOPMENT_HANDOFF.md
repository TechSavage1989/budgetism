# Budgetism development handoff

**Date:** October 27, 2026
**App:** Budgetism
**Version:** 0.1.0-dev.1
**State:** Public source committed and validated by GitHub Actions at code commit `743daffff7bf985245f3fb20c26d5c3e7e207a29`. An unsigned Windows portable build exists as a temporary CI artifact, but native installation and GUI operation are unverified. No application release.

## Repository inspection performed first

- URL: https://github.com/TechSavage1989/budgetism
- Visibility: **public**, user has push/admin access; source publication explicitly authorized October 27, 2026.
- Initial placeholder commit: `ded152921fec3f8b141e94f10bba39dc55012e56`.
- Published source baseline commit: `e9c1b6ca82b5b030cc949ed23e87ec120c6f49d3`.
- Latest verified code commit: `743daffff7bf985245f3fb20c26d5c3e7e207a29` (Flutter CI fixes; 44 source files). Subsequent documentation-only commits do not alter the validated application code.
- Before publication, the repo had only an 11-byte README; the source commit added the complete reviewed 43-file baseline.
- Active PRs at publication: none. Branches listed: main only. Releases: none. The public release feed exists but has no release entries.
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
- Source was published by a normal commit on top of the initial README placeholder with no force-push or history rewrite.
- The tested code tree contains 44 files, including a real Budgetism widget smoke test; no committed binaries or credentials. No GitHub release or tag is authorized.
- Initial CI run: https://github.com/TechSavage1989/budgetism/actions/runs/40570606567. Flutter web analysis failed due to a generated `MyApp` test and informational lints; backend, updater, layout and Windows packaging passed.
- Corrected CI run: https://github.com/TechSavage1989/budgetism/actions/runs/40571846774 (commit `743daff`). **All five jobs passed**: Flutter web analysis/tests/build; Windows Flutter analysis/tests/portable packaging; .NET build/ledger contract; Go updater security; source layout. CI produced `Budgetism-Windows-x64-development` and `Budgetism-updater-test-binary` as temporary workflow artifacts, not releases.
- Windows executable GUI startup, actual update/restart behavior, and rollback have not been validated on a real Windows machine.
- Source is not production-safe for real financial data.

## Validation performed in this environment

- Source root guard and negative control: PASS (after documents created).
- Go updater archive unit tests, including good archive, wrong hash, wrong version, traversal, executable injection, wrong PE architecture and custom filename validation: PASS.
- Go Windows x64 PE updater helper cross-compilation: PASS on Linux with Go 1.23.2. This is not a Windows run test.
- Source ZIP integrity, extracted no-.git guard test and Markdown link scan: performed at packaging time.
- Flutter SDK / .NET 10 SDK / Docker: unavailable locally. Corrected GitHub Actions run `40571846774` passed web and Windows Flutter builds/tests, .NET backend build/ledger contract, Go updater tests and source layout. This validates compilation/CI checks, **not** GUI startup on a user machine, live database operation, native updater install/restart/rollback, encrypted storage or production financial safety.

## Known blockers and next actions

1. Run the packaged Windows application on an actual Windows desktop, verify startup, sample-data workflows, window behavior, per-user storage and shutdown; repeat on subsequent builds.
2. Test the native Windows updater with two genuine signed/not-signed test builds (including rollback, rename/custom executable, current window health, offline/focus/resume, cleanup and preservation of settings). Do **not** enable Install and restart until these tests pass.
3. Add persistent encrypted native data, synchronized outbox and conflict resolution, versioned backend migrations and verified backup/restore before accepting real financial data.
4. Add budgeting, recurring bills, forecasting, reporting and transaction reconciliation without breaking existing ledger invariants.
5. Check GitHub HEAD, active branches/PRs, read-first docs and source package consistency before further source changes. Source publication was authorized; tag/build/release publication remains separately authorized.

## Never claim

Do not call this a production-ready finance application, tested native updater, successfully running Windows Flutter executable, deployed server, or published application release. Public source publication is not an application release. Hosted GitHub Actions produced a Windows portable CI package, but it remains a development artifact and has not been validated by launching the app on Windows.
