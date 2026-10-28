# Validation: Budgetism 0.1.0-dev.5

## Verified starting point

User confirmed dev.4 budgeting and restart persistence. The live branch development/monthly-budgets-dev4 points to c7de25eeff74651519407df666074262effc9176, tested in successful run 40610634360. The exact source artifact digest, inner checksum, commit provenance and recomputed Git tree were verified before editing. The older main branch was not used as the application baseline.

## Performed locally

- Verified baseline tree 0c818a54fcefa2c320dc051cb2d7f4e6d71f4c84.
- Repository layout guard and deliberate-clutter negative control without Git metadata.
- Portable-package verifier's missing-library, wrong-version and wrong-digest negative controls.
- Unchanged Go updater: go test -race ./... and go vet ./.... These do not validate recurring finance code.

## Authored tests awaiting hosted execution

- Calendar anchors: monthly day 31, annual February 29, weekly/fortnightly DST boundaries, end dates and upper date bounds.
- Separation of planned/actual, exact-cent income/expense/transfer posting, actual-date budget effects.
- Postponement without series drift, oldest-overdue ordering and capped lists, pause/resume, single-occurrence skipping.
- Idempotent retries, distinct-ID duplicate rejection, stale schedule/occurrence versions, immutable recurrence anchors.
- Edited/voided actual transactions retain their origin and never regenerate settled occurrences.
- Explicit financial schema 2 to 3 migration, legacy budget schema 1 to 2 path, preserved records and downgrade refusal.
- Failed storage writes commit neither side; SQLite stale-window rejection, encrypted backup restore and restart persistence.
- Form validation, explicit migration checkbox, failed-save field retention, single-flight confirmation and narrow layout.
- Real Windows SQLite/key-store write/read in separate native app processes; existing budget/security native test preserved.

No new Flutter analysis, unit/widget run, Windows native process test, web/Windows compilation, backend regression, packaged ZIP validation or hosted CI pass is claimed until the exact run is recorded below. Local SDKs and a Windows GUI are unavailable.

## Remaining manual gates

Complete Windows GUI/backup-file-picker workflow, visual review of all window sizes, independent security review, live PostgreSQL integration, non-Windows distributions and native updater install/relaunch/rollback remain unverified. Source publication and temporary CI artifacts are not a GitHub release or publisher signing. In-app installation stays disabled.
