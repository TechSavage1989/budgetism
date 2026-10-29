# Current implementation state

Dev.17 source adds a cohesive everyday-use update on the tested dev.16 calendar build. Application dd70d39df255a6484179e6df20ee0a63997915ef passed all five jobs in run 40822480327; the downloaded package matches its no-threats scan and identity/runtime/checksum validation. Dev.15 remains explicitly user-confirmed; do not treat continued development as a manual dev.16 test report.

| Area | Current source behavior |
| --- | --- |
| Home | Historical through-today totals, future-actual disclosure and direct actions |
| Settings | Direct local tools, security, backups, theme and update checks |
| Navigation | Scrollable wide rail; four primary narrow destinations plus full More drawer |
| Entry | Searchable account/category/split selectors and local-only payee suggestions |
| Multiple entries | Explicit Save and add another with safe resets and separate operation identities |
| Data | No new schema; existing finance/storage/key/backup logic retained |
| Tests | 270 unit/interface tests and all retained/new Windows native checks passed |
| Bank/device sync | Not enabled; next stage is a fictional provider-independent feed |
| Distribution | Verified Windows development artifact; unsigned; no releases/tags |

See DAILY_USE.md, DATE_CONTROLS.md, BANK_CONNECTION_PLAN.md and VALIDATION.md. No credentials, paid plan or external provider has been configured.
