# Validation: Budgetism 0.1.0-dev.8

## Verified application and build correction

Application commit 0e41cbf1a2127aedeaa1dae267f538b06ce19d1b, tree d7b80b45ffbb1cb6fc7a6889de621234ffe55827. [Run 40717507066](https://github.com/TechSavage1989/budgetism/actions/runs/40717507066) passed all five jobs, including native matching across separate Windows processes and the exact-package Defender scan. Documentation-only follow-ups do not alter this tested application or version.

User-confirmed baseline: dev.7 application 0dec77e3372a7ceb5745e29a54301a6622de414b, run 40708091217; starting main b6057f6fbee794b86d8a8fe1bb23e0ce88318ee8 is its documentation follow-up. Existing budgeting, forecasting and importing do not need repeated user setup exercises.

Initial dev.8 commit cc8721d8a507a7426c748a810c75c454374d7ae6 passed Flutter analysis/tests/web compilation, backend, updater and layout checks. Both Windows attempts in run 40716102610 stopped before compilation at Defender initialization: Update-MpSignature returned RPC error 0x800706be. This was not a threat detection. The next commit changed only build initialization and documentation, not the application logic. Initialization now uses documented MpCmdRun -SignatureUpdate with bounded retries, recorded output and current-signature/service checks. The final exact-package scan remains mandatory and unchanged. No antivirus exclusion, protection disabling, test skipping or analyzer suppression was added. The successful run initialized on its first update attempt.

## Passed in hosted CI for the exact verified commit

- Flutter analysis and full existing/new unit/widget suite on Ubuntu and Windows, plus web compilation.
- Read-only candidate suggestions, financial-field/schema preservation, import receipts and reimport rejection.
- Variable amounts/dates, split categories, income and transfer linking, and invalid account/type/currency/direction/voided exclusions.
- Date-window endpoints, date-only arithmetic, explicit review, unchanged-request replay and repeated-link rejection.
- Workspace/transaction/schedule/occurrence stale guards, paused/skipped/postponed cases and invalid relationship rejection.
- Forecast/calendar deduplication and link preservation through edits and voids.
- Failed-save atomicity, real SQLite reopen, stale writers and encrypted backup restoration with security mode preserved.
- Review dialog validation, failed-save retry retention, single-flight behavior, search reset and 430-pixel layout.
- Retained native Windows security, schedule and CSV-import write/read pairs plus the read-only planning test.
- New matching write/read pair in separate native app processes using actual SQLite and OS keys: link, import receipt, one actual transaction and duplicate rejection persist.
- Windows compilation/portable packaging, required native dependency verification and package-verifier negative controls.
- Backend accounting contracts, Go updater tests, root-layout guard and deliberate-clutter negative control.
- Microsoft Defender scanning of the exact ZIP and extracted contents, followed by application artifact upload.

## Local verification

Starting source provenance/digests and the complete Git tree were checked. The final source artifact 12828887615 from run 40717507364 matched outer SHA-256 7729c05100ebb69a8e4f98aae9ce4e03869f164e9a096ed242b7010a6e10c757 and inner source SHA-256 c0d401e62ac91c57e54eda2ca9e5545e3a511291393154d907454f0c700009a9. All 108 files matched the prepared source and independently recomputed Git tree d7b80b45ffbb1cb6fc7a6889de621234ffe55827.

Root-layout and deliberate-clutter checks, package-verifier negative controls, diff whitespace, Go tests with race checking and go vet passed. Core encryption/storage/device-key/import/budget/planning/recurrence/transaction-editor/backend/updater implementations were compared with the dev.7 baseline and preserved. README single-H1/navigation and local documentation targets were checked. No local Flutter/Dart/.NET SDK or Windows GUI exists; compilation/native passes above come from hosted CI.

Windows artifact 12827924651 belongs to the exact successful application commit/run. Its outer SHA-256 is a57facb7b915161125c9f8a11795494649ff90669e6f8a68e87716e66f1732ad. Inner Budgetism-Windows-x64.zip is 16,110,219 bytes, 18 entries, with SHA-256 b03dc760226524056b44ddd8fc53a0a174bed856f7f578da9de7431426cf6700. This matches checksums.sha256 and the Defender report. ZIP paths/CRC/limits, application identity, dev.8 version, Windows x64 PE headers, stable Budgetism.exe target and required native files passed. No financial database/private key files are packaged. The actual Go updater accepted this downloaded ZIP in verify-only mode; no installation was attempted.

## Defender evidence

Security artifact 12828829229 matched outer SHA-256 5ece49c77a7ed719e87f200f2e828d5f29d3f9beff182553c59a0e58d660edc7. At 2026-10-28T15:44:36.9024859Z, engine 1.1.26100.4 with signatures 1.463.10.0 reported no threats in both scans, exit code 0. Signature update time was 2026-10-28T10:14:03Z. The archive hash equals the delivered inner package hash above. Initialization evidence records ready-for-custom-scan and successful command-line signature update.

Both Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signature. This scan is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning.

## Remaining gates

Manual dev.8 GUI interaction on the user's PC, non-Windows native distributions, live backend/synchronization and full updater installation/relaunch/rollback remain unverified. Dev.7 is still the user-confirmed baseline. No GitHub release/tag or production approval. Matching adds no financial-schema migration to an existing recurring/import workspace. See [Windows testing](WINDOWS_TESTING.md).
