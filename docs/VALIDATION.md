# Validation log: Budgetism 0.1.0-dev.1

Local validations were performed in a Linux development container on October 27, 2026. Additional hosted checks passed on GitHub Actions at code commit `743daffff7bf985245f3fb20c26d5c3e7e207a29`. Neither is a substitute for native GUI/update testing.

## Passed locally

- Repository root guard; no-.git fallback; clean and intentionally cluttered negative-control fixtures.
- Go updater security tests via `go test -race ./...` and `go vet ./...`.
- Archive accepts correctly identified Windows x64 fixture; rejects incorrect SHA-256, version mismatch, traversal path, additional executable, wrong PE architecture, and unsafe custom executable names.
- Go 1.23.2 cross-compilation to Windows x64 GUI executable.
- README heading structure/navigation and local documentation target checks.
- Source package ZIP manifest check, CRC validation and extracted archive root guard (final package verification).

## Passed in hosted GitHub Actions

- [Corrected CI run 40571846774](https://github.com/TechSavage1989/budgetism/actions/runs/40571846774): all five jobs successful.
- Flutter web analysis, tests and release build.
- Windows Flutter analysis, tests, release build and portable ZIP packaging.
- .NET 10 API build and accounting contract tests.
- Go updater security tests and Windows x64 helper cross-compilation.
- Source layout guard and negative control.

## Not run / unsupported here

- Actual Windows GUI launch, manual feature exercise, or automated native UI tests.
- Real GitHub update polling, focus transition timers, rate-limit behaviors, download redirect handling or platform per-user directory checks.
- Live ASP.NET Core API tests against a PostgreSQL database.
- PostgreSQL integration tests, schema migration and encrypted backup/restore.
- Windows native install/relaunch/visibility/rollback lifecycle, including testing from an older Budgetism.exe.
- Independent Windows native verification of the CI-produced portable package and shortcut/update lifecycle.
- GitHub Release updater asset checks (no application release exists).

## Release gate

Do not install untrusted updates or use real finances until Flutter and backend tests, security review, migrations, backup/restore and a genuine Windows previous-to-new test pass. The UI intentionally disables Install and restart.
