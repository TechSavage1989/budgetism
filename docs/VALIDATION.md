# Validation log: Budgetism 0.1.0-dev.1

Performed in a Linux development container on October 27, 2026. Not a substitute for testing the Windows Flutter desktop application.

## Passed locally

- Repository root guard; no-.git fallback; clean and intentionally cluttered negative-control fixtures.
- Go updater security tests via `go test -race ./...` and `go vet ./...`.
- Archive accepts correctly identified Windows x64 fixture; rejects incorrect SHA-256, version mismatch, traversal path, additional executable, wrong PE architecture, and unsafe custom executable names.
- Go 1.23.2 cross-compilation to Windows x64 GUI executable.
- README heading structure/navigation and local documentation target checks.
- Source package ZIP manifest check, CRC validation and extracted archive root guard (final package verification).

## Not run / unsupported here

- Flutter SDK, Dart analyzer, Flutter widget tests and Windows native Flutter build.
- Real GitHub update polling, focus transition timers, rate-limit behaviors, download redirect handling or platform per-user directory checks.
- .NET 10 compile and ledger executable tests.
- PostgreSQL integration tests, schema migration and encrypted backup/restore.
- Windows native install/relaunch/visibility/rollback lifecycle, including testing from an older Budgetism.exe.
- Windows portable packaging PowerShell run (requires Flutter-built files and Windows).
- GitHub hosted CI (source not pushed), GitHub release asset checks (no release exists).

## Release gate

Do not install untrusted updates or use real finances until Flutter and backend tests, security review, migrations, backup/restore and a genuine Windows previous-to-new test pass. The UI intentionally disables Install and restart.
