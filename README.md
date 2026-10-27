<h1 align="center">Budgetism</h1>
<p align="center">Personal budgeting and money tracking, designed for private financial data and cross-device access.</p>

<p align="center">
<a href="#download">Download</a> | <a href="#getting-started">Get started</a> | <a href="#features">Features</a> | <a href="#updates-and-settings">Updates</a> | <a href="#development">Development</a>
</p>

**Development source baseline 0.1.0-dev.1. Not a verified app release. Do not enter real financial information.**

## Features

Budgetism is a Windows-first, cross-platform personal finance app. The application is designed for private self-hosted synchronization without a mandatory external finance service.

Implemented in the current source:

- Responsive Flutter client with light/dark appearance, financial dashboard, accounts, and a transaction register.
- **Explore with sample data** mode. It requires no server, displays fictitious transactions, and allows temporary edits without persistent storage.
- Create accounts and record income, expenses, and transfers in the demo, or through the separate ASP.NET Core API when a private backend already exists.
- Exact-integer USD-cent accounting and double-entry journal entries in the backend source.
- Public GitHub release checks on startup, every five minutes while active, and after focus returns when at least two minutes have passed.
- Update availability banner, brief release notes, manual check, cached ETags, rate-limit backoff, and Windows ZIP download with SHA-256 comparison when the release supplies a GitHub digest.

Not implemented: persistent offline changes, personal-data-safe production migration/backup, budgeting, recurring bills, forecasting, signed builds, fully validated Windows installation, and real bank synchronization.

## Download

There is **no published Budgetism application release**. The public [releases index](https://github.com/TechSavage1989/budgetism/releases) contains no verified application package at the time of this handoff.

The source is maintained in the public [Budgetism repository](https://github.com/TechSavage1989/budgetism). To try the demo, build the Flutter client using the instructions below. No installable application release has been published.

A standalone Windows updater helper can be built separately, but it is not the Budgetism application.

## Requirements

- Windows first, with Flutter projects planned for web, Android, iOS, macOS, and Linux. These targets have **not all been built or verified**.
- For local Flutter builds: a compatible current Flutter SDK, Dart SDK, and native target build tools.
- For backend builds: .NET 10 SDK and compatible PostgreSQL environment, if already provisioned. This source package deliberately **does not include server setup or deployment instructions**.
- No administrator rights or payment account are required to explore the in-memory demo after compilation.

## Getting started

1. Extract the source ZIP into a working folder.
2. Install Flutter and Windows desktop build requirements using Flutter's official instructions.
3. Open a shell in the `apps/client` directory.
4. Generate the Flutter Windows runner and resolve dependencies:

   ```powershell
   flutter create --platforms=windows,web --project-name budgetism --no-pub .
   flutter pub get
   ```

5. Run the app and open its self-contained demo:

   ```powershell
   flutter run -d windows --dart-define=APP_VERSION=0.1.0-dev.1
   ```

6. Select **Explore with sample data**. You can review the dashboard, create test accounts, and add sample transactions. Changes disappear when the app closes.

Do not supply actual bank logins, real private financial records, or real account information to this development version.

## How to use

- **Dashboard:** View fictitious cash, net worth, current-month spending, and recent transactions.
- **Accounts:** Select **Add account**, choose an account type, and specify a name and opening balance.
- **Transactions:** Select **Add transaction**, then choose expense, income, or transfer. A credit-card payment is a transfer rather than another expense.
- **Budgets / Forecasts:** Placeholder screens. The financial engines are not implemented yet.
- **Check for updates:** From the welcome screen or the profile menu in the main UI.
- **Connect to server:** The existing API client remains available for previously configured private systems, but no server is provided or configured by this source package.

Demo entries are memory-only. No demo records are saved to disk, transmitted to GitHub, or sent to a financial institution.

## Updates and settings

The update checker reads releases from the public `TechSavage1989/budgetism` repository. It uses conditional ETag requests, a startup check, five-minute active polling, focus-return checks after two minutes, and single-flight request protection. Manual checks are subject to a 20-second cooldown. Network failures or GitHub throttling are reported as unavailable rather than incorrectly claiming that the app is current.

A newer published version appears in a compact banner with the installed/latest versions and up to three release-note items. A **Download** action is offered on Windows only if GitHub release metadata contains an SHA-256 digest for `Budgetism-Windows-x64.zip`. Downloads are saved in the user's application-support storage and verified before being retained. This comparison **does not prove publisher signing**.

**Install and restart remains disabled in this development baseline.** The companion Go helper validates package identity, Windows PE architecture, archive paths, hashes, and rollback mechanics, but no real Windows update/restart/visible-window path has been tested. It must not be turned on before those tests pass.

- Windows portable executable target: **Budgetism.exe** with no version in the filename. Companion DLLs/assets must remain together in the extracted app directory.
- Native user settings/cache: Flutter's platform-specific per-user application-support and preferences storage, not beside the executable.
- Download staging: under the per-user application-support directory, `updates/staging`.
- Updater logs: per-user `LOCALAPPDATA/Budgetism/logs/updater.log` on Windows.
- Theme selection and login tokens are currently session-only and not persisted. Native encrypted finance storage is not implemented.
- Source packaging does not create or publish a GitHub release.

## Troubleshooting

- **No app release found:** This is expected until an authorized Budgetism release has been published.
- **Unable to check updates:** Verify network access and respect any retry/backoff time. Offline results do not mean no update exists.
- **Private server unavailable:** Use the sample demo instead. Do not expose a financial backend over untrusted plaintext HTTP.
- **Changes disappear after restart:** Demo records are intentionally not persisted.
- **Windows build missing:** Confirm Flutter is installed, the Windows runner has been generated, and native Windows build prerequisites are available.
- **Update install disabled:** Windows live validation, signing decisions, and full rollback testing are still required.

## Development

Read [AGENTS.md](AGENTS.md), [DEVELOPMENT_HANDOFF.md](DEVELOPMENT_HANDOFF.md), and [implementation status](docs/IMPLEMENTATION_STATUS.md) before changing code.

Source map:

- `apps/client`: Flutter UI, sample-data demo, update checker, verified release downloads, and Dart tests.
- `services/api`: .NET 10 backend ledger and API source. Deployment is intentionally out of scope.
- `tools/updater`: Go-based Windows package validator and installer helper, plus security unit tests.
- `scripts`: root cleanliness guard and Windows packaging script.
- `tests`: backend accounting fixtures and integration test definitions.
- `docs`: product design, API outline, security/update scope, and release notes.
- `.github/workflows`: CI source/build checks that upload validation artifacts but never create a release.

On a machine with the relevant SDKs:

```powershell
python scripts/check_layout.py --self-test
cd tools/updater
go test ./...
cd ../..
dotnet build services/api/Budgetism.Api.csproj --configuration Release
dotnet run --project tests/ledger-contract/ledger-contract.csproj --configuration Release
cd apps/client
flutter create --platforms=windows,web --project-name budgetism --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define=APP_VERSION=0.1.0-dev.1
```

GitHub Actions includes Windows portable packaging checks using `scripts/package_windows.ps1`. Hosted results must be verified for the specific commit before relying on those artifacts. Local Go tests and Go Windows cross-compilation are verified; .NET/Flutter compilation and native Windows lifecycle tests remain unverified.

Read [docs/UPDATES.md](docs/UPDATES.md) before enabling automatic installation or publishing the first release. Source publication is authorized for the existing public repository. Publishing source does not authorize application release publication, changing repository visibility, or enabling the untested installer.
