# Budgetism development handoff

## Current checkpoint

- **Current engineering candidate:** dev.27 coordinated desktop/backend update paths on `development/coordinated-updates-dev27`, continuing dev.26. Read [candidate safety contract](docs/COORDINATED_UPDATES_DEV27.md). Runtime/upgrade verification is pending; no installation or publication is claimed.

- **Verified delivered client:** dev.26, application `b8d21ed69fd1cc137461919ae3b2e0c3d8a37020`, branch `development/report-controls-dev26`. [Full provenance](docs/DEV26_VALIDATION.md). User acceptance remains unconfirmed; later update-engineering work does not replace this verified package.
- Prior verified dev.25 remains preserved on `development/report-forecast-dev25`, documentation closure `cc0e815e832cedeab2f5a5e584c7f3b597992750`.
- Repository is public: [TechSavage1989/budgetism](https://github.com/TechSavage1989/budgetism). Main `8bd6472bc0bd567f90b491b1767736e5a030521e` is an older dev.18 checkpoint. Do not overwrite newer development with main. No release or tag exists.
- Prior `development/plaid-dev19` head `15cc77a8171bea3fd70048f267d19b05c0bc76fa` contains the verified dev.24 server planning suite. The existing private API, database, protected keys, current window and rollback files remain untouched.

Read [AGENTS.md](AGENTS.md), [implementation status](docs/IMPLEMENTATION_STATUS.md),
[report semantics](docs/REPORTS.md), [dev.26 scope](docs/REPORT_CONTROLS_DEV26.md) and [the replacement roadmap](docs/REPLACEMENT_ROADMAP.md)
before changes. Older milestones are preserved in
[development history](docs/releases/development-history-through-dev25.md), not repeated here.

## Verified dev.26 package

[Build 41071151884](https://github.com/TechSavage1989/budgetism/actions/runs/41071151884)
passed all six jobs, 381 client tests on Linux/Windows and all 34 native Windows
commands. Source archive, Windows/web compilation, package validation and exact
ZIP/extracted Defender scans passed. Fictional native screenshots were inspected.
[Full provenance](docs/DEV26_VALIDATION.md) includes both earlier failed candidates,
corrections and final artifact hashes.

Use **Budgetism-Windows-x64-development**, artifact 12985329455, from that run.
Inner Budgetism-Windows-x64.zip is 16,612,545 bytes, SHA-256
`b8204a6e55a7ed9cd952e3eb7b6afc9fa155b00660f890c47eb4d8f2915e6bd4`.
The unchanged delivered copy is Budgetism-Dev26-Windows-x64-Verified.zip.
It is unsigned; a clean build-time scan is not publisher signing or universal
antivirus/browser clearance. User acceptance remains unconfirmed.

## Scope and safeguards

Dev.25 graph/forecast controls are session-only. Dev.26 builds on these read
models: filter exact category contributions and compare explicitly labelled
historical periods without changing money or whole-account balances. Saved
cross-session report/scenario presets remain a future encrypted-contract feature,
not plaintext device preferences. Existing local/server data remain separate.

The earlier standard prompt explicitly excluded **server setup, Codex CLI
automation, unattended workers, payment setup and API-account setup**. Do not
reapply earlier private deployment instructions. The later 17:06–17:08 request authorizes engineering automatic updates for both existing desktop and backend, but not inaccessible-host access, new privileges, release publication or migrations. No real bank linkage, credentials,
network/access changes, release/tag publication or automatic installation is in
this increment. Existing development-source/workflow sync authorization does not
authorize main promotion or a release. BankFive/United States and Plaid-first are
known; exact account types and migration needs can be clarified in their own phase.

## Source map, build and settings

[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) contains exact build/test commands,
toolchain versions, extracted-archive validation and folder responsibilities.
Source remains under apps/client, services/api and tools/updater; colocated Flutter
tests remain in the client. Supporting contracts are in tests, scripts, docs and
.github. Allowed tracked root files remain README.md, AGENTS.md,
DEVELOPMENT_HANDOFF.md and .gitignore. Add any genuinely required root file only
through explicit allowlist review and negative-control tests.

No implementation files were moved. README now uses the supplied navigation and
section standard with a clean text header because no authentic logo is tracked.
Detailed workflows moved to [the feature guide](docs/FEATURE_GUIDE.md); old handoff
history moved to docs/releases with updated relative links. Main integration is
intentionally deferred: main is stale and no promotion was authorized. Do not
force-push or reconstruct old root clutter when integrating another branch.

Stable launch/archive names: Budgetism.exe and Budgetism-Windows-x64.zip.
The local Windows workspace is
`%LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3`; settings, caches and backups
remain per-user. Program extraction is separate from financial data. Copying the
SQLite file alone is not independent recovery; retain encrypted backups and their
passwords. Never regenerate the private server planning key or rerun its upgrade
for a client-only update. See [storage](docs/LOCAL_STORAGE.md).

## Update and verification limitations

The public feed targets this repository's releases, currently empty. Startup,
five-minute active and two-minute focus-return check logic exists with single-flight,
ETags/caching and throttling. Download is explicit for eligible verified assets;
**Install and restart remains disabled**. Actual previous-release installation,
rollback/healthy relaunch and complete native timer/focus acceptance remain gates,
not completed promises. See [UPDATES.md](docs/UPDATES.md). No release was created
merely to make the README's download section look complete.

Local Flutter bootstrap in this executor was blocked for unexpected metadata
endpoint access. Do not retry indirectly or weaken security. Use existing
hosted checks, disclose local omissions and verify final exact package evidence.
Synthetic native data and screenshots do not establish live authenticated user
acceptance. Dev.26 runtime/package checks passed as recorded in its validation document.
README structure/rendered HTML passed; local browser pixel rendering was blocked
by sandbox socket restrictions. No blocked runtime was retried indirectly.
