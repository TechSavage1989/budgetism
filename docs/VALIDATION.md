# Validation: Budgetism 0.1.0-dev.10

## Verified application and corrections

Application commit 63b5b6cef441ca1889117d6a3b43ec05f5e5aa34, tree 5f2d6f429fdbfc83a373608227de4d609d562c59. [Run 40737797353](https://github.com/TechSavage1989/budgetism/actions/runs/40737797353) passed all five jobs, including the native report/export preservation test and exact-package Defender scans. Documentation-only follow-ups do not change the tested application or version.

Starting main 05933bd381a9ede2150fe0ed2021a1171664bc5e is the documentation follow-up to user-confirmed dev.9 application 1ba16145c8e9cec3cf88b39eceadbbfd8cab6b06, successful run 40728930400. Previous reconciliation, matching, imports, forecasting and budgeting do not require repeated user setup exercises.

The first dev.10 run 40736126439 stopped at analysis: an unnecessary import, nullable report argument in an export callback, and a multiple-underscore lint. Commit 16740aa43e6b6ace3347b360947fd6156dffb6b9 corrected those findings without suppression. A separate proactive test correction checks exact UTF-8 output bytes, including the BOM, rather than a decoder's normalized string. Final commit 63b5b6cef441ca1889117d6a3b43ec05f5e5aa34 adds an engine-side range guard and regression test for transfer-only aggregate movement whose difference exceeds the exact-total limit; this was found during source review, not reported as an observed user failure. All checks remain enabled.

## Passed in hosted CI for this exact commit

- Flutter analysis and the full existing/new unit and widget suite on Ubuntu and Windows, plus web compilation.
- Historical inclusive date/account filters, exact-cent totals, both transfer sides, card purchases versus payments, split contributions and category counts.
- Prior, future-dated and voided activity; empty months; leap/year/date bounds; edits; all supported financial schema reads without migration.
- Preserved actual totals and reconciliation locks, read-only snapshots, and recoverable exact-number boundary rejection before rendering.
- CSV sections, exact amounts, quoted text, formula-like text handling, control characters and split detail without duplicate whole amounts.
- Narrow/wide report views and category drilldowns, account/date filters, export consent, cancellation, failed-save retry, single-flight and empty states.
- Retained native security, schedules, imports, matching and reconciliation write/read pairs in separate Windows app processes, plus the planning preservation test.
- New native reports test: real SQLite, actual CSV file writes, unchanged encrypted payload/revision/financial JSON, close/reopen reproducibility, and rejected edits to reconciled transactions. This report test is same-process close/reopen, not a separate-process test.
- Windows compilation and portable packaging from a source archive without Git metadata; identity/native dependency checks and negative controls.
- Backend build/accounting contracts, Go updater tests, source-layout guard and deliberate-clutter checks.
- Microsoft Defender scans of the exact ZIP and extracted files before application artifact upload.

## Local source and package verification

The dev.9 source archive, digest, commit and independently recomputed application tree were verified before editing. Final dev.10 source artifact 12836804263 from run 40737796983 matched outer SHA-256 0514844ad3d66100d260a88fd896d368f0fe2c8d040ec5a67a0629765e75e7bc and inner source ZIP SHA-256 66f1ce0e50df25520a659dcca8f3422dbb8005e8e51ed000590a85b6e6800bc0. All 124 files matched the prepared source and independently recomputed Git tree 5f2d6f429fdbfc83a373608227de4d609d562c59.

Source-layout and package-verifier negative controls, diff whitespace, Go race tests and go vet passed. Thirty-six existing financial/storage/backend/updater source files remained byte-identical to dev.9, including encryption, SQLite, security, imports, matching, budgets, planning and reconciliation. README H1/navigation and 33 local documentation targets were checked. No local Flutter/Dart/.NET SDK or Windows GUI was available; compilation/native passes above are hosted evidence.

Windows artifact 12837643904 belongs to the exact successful run and commit. Outer SHA-256: 2e29524f65ed1a520aa0fb5be4aa0425fd9ffb395e03d30ab8a8d120c5c38270. Inner Budgetism-Windows-x64.zip: 16,189,811 bytes, 18 entries, SHA-256 f6ce8f3b1c3243969510a7fef947f140a478018c24f386203dcf75fe9fa7638b. It matches checksums.sha256 and the Defender report. Application identity TechSavage1989.Budgetism, version 0.1.0-dev.10, platform windows-x64, stable Budgetism.exe target, archive CRC/paths/limits and required x64 PE/runtime files passed. No financial database/private key files are packaged. The actual Go updater accepted the downloaded archive in verify-only mode; no installation was attempted.

## Defender evidence

Security artifact 12838707119 matched outer SHA-256 c60bbc103c990e3260a50ffc778422af0a3a01fc5e80d2ea5b0b9b748f000329. At 2026-10-28T17:53:51.2633305Z, engine 1.1.26100.4 with signatures 1.463.12.0 reported no threats in both the archive and extracted contents, with exit code 0 for each scan. Signature update time: 2026-10-28T13:15:20.0000000Z. Its archive hash matches the delivered inner ZIP above.

Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signature. This build-time scan is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No antivirus exclusions, global protection disabling, skipped tests or analyzer suppression were added.

## Remaining gates

Manual dev.10 GUI and native file-picker interaction on the user's PC, non-Windows native distributions, live synchronization and full updater installation/relaunch/rollback remain unverified. Dev.9 is the user-confirmed baseline. No release/tag or production approval. Reports add no financial-format upgrade. CSV exports are unencrypted and are not workspace backups. See [Windows testing](WINDOWS_TESTING.md).
