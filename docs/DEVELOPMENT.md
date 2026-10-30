# Build, test and source map

Read [the current handoff](../DEVELOPMENT_HANDOFF.md) for the exact branch/version
and verified run. Do not use older main as a new development baseline. Windows
runtime/package validation takes place in the existing hosted workflow; local
commands below require the corresponding installed toolchains and do not imply
they ran on every executor.

## Source map

| Path | Responsibility |
| --- | --- |
| apps/client | Flutter client, colocated Dart unit/widget and native integration tests |
| services/api | Existing .NET API and PostgreSQL contracts; no deployment in current scope |
| tools/updater | Go verification/update helper; in-app installation remains disabled |
| tests | Backend, database and packaging contracts |
| scripts | Layout/package guards, build helpers and retained server scripts; do not run installers for client work |
| docs | Current feature contracts, validation and development guides |
| docs/releases | Historical development notes |
| .github/workflows | Non-publishing validation and exact-source artifacts |

Allowed tracked root files are README.md, AGENTS.md, DEVELOPMENT_HANDOFF.md and
.gitignore. CI checks this allowlist with deliberate-clutter negative controls.
Generated build output is ignored. No paths were moved beneath active code work.
No suitable existing branding asset is tracked, so README uses a text header.

## Client checks

CI pins Flutter **3.47.8**. Generate platform runner files only in a disposable
checkout/source extraction, then use the app version from pubspec.yaml and the
matching workflow. Example for the dev.26 candidate:

```sh
cd apps/client
flutter create --platforms=web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=APP_VERSION=0.1.0-dev.26
```

On Windows with the Flutter Windows toolchain:

```powershell
cd apps/client
flutter create --platforms=windows --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.26
```

Run every native integration command with the explicit phase/directory defines in
[build-checks.yml](../.github/workflows/build-checks.yml). Do not substitute a single
smoke test for the complete suite or reuse real financial data as a fixture.
The Windows job extracts a source archive without .git before building/testing.

## Shared gates

From the repository or clean extracted source root:

```sh
python scripts/check_layout.py --self-test
python scripts/check_layout.py
python scripts/check_readme.py --self-test
python scripts/verify_windows_package.py --self-test
dotnet build services/api/Budgetism.Api.csproj --configuration Release
dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release
dotnet run --project tests/plaid-contract/plaid-contract.csproj --configuration Release
```

The hosted backend uses .NET 10; the Windows package job pins 10.0.403. Go checks:

```sh
cd tools/updater
mkdir -p ../../build/tools
go test -race ./...
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags='-H windowsgui' -o ../../build/tools/Budgetism-Updater.exe .
```

Use the workflow's Windows packaging/Defender commands on an appropriate isolated
Windows runner, then independently compare the downloaded ZIP's checksums,
identity/version, native dependencies and CRCs. Scan evidence must match that
exact archive hash. Compiling is not permission to publish or install.

## Local validation limitation

In the October 30 cloud executor, local Flutter bootstrap was rejected because it
attempted a cloud metadata endpoint. It was not retried or bypassed. Existing
hosted Flutter/native validation is used instead; no local Flutter success is
claimed. This restriction must not be worked around with an indirect invocation.
