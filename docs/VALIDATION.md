# Validation: Budgetism 0.1.0-dev.7

## Verified application

Application commit 0dec77e3372a7ceb5745e29a54301a6622de414b, Git tree d97461e0c2945f39ba2d9f20fa97ef163a9b419b, on development/imports-dev7. [Run 40708091217](https://github.com/TechSavage1989/budgetism/actions/runs/40708091217) completed successfully with all five jobs passed. The first published dev.7 application run passed without suppressing analyzer checks or skipping regression tests. Documentation-only follow-ups do not alter this tested application or version.

Starting baseline: user-confirmed dev.6 application 37917d27a40d68cb6fbb83b61b192c9984a2b7ea, tree 5abda49bb36a77e4b0e3bf7701b7f205f85df47a, successful run 40699293089. Older main was not used as the code baseline.

## Passed in hosted CI

- Flutter analysis, the full existing/new unit and widget suite on Ubuntu and Windows, and web compilation.
- CSV quoting, escaped quotes, multiline/CRLF/BOM, separators, malformed/oversized input, literal formula text, exact cents, explicit dates/signs, invalid rows and column mapping.
- Read-only preview, explicit schema consent, exact actual and budget effects, unchanged-request replay, source-row/bank-ID duplicate blocking, receipts retained after voids, and legitimate identical rows after explicit review.
- Existing-transaction matching without reposting, both transfer directions, stale previews, whole-batch validation failure, duplicate match rejection, receipt corruption and schedules after importing.
- Failed-save atomicity, real SQLite reopening, stale-window rejection, encrypted backup restoration and the narrow-screen example/review/failed-save/retry workflow.
- Existing Windows security and recurring write/read test pairs in separate native processes, plus the read-only calendar/forecast native test.
- New Windows CSV import write/read in separate native processes: records and receipts persist, and repeat import is rejected without changing the encrypted saved data.
- Windows release compilation and packaging from a clean source archive without Git metadata, native dependency/identity validation and package-verifier negative controls.
- .NET backend build/accounting contracts, Go updater tests, source-layout guard and deliberate-clutter negative control.
- Microsoft Defender scan of the exact ZIP and extracted runtime files, followed by application artifact upload.

## Passed locally

The dev.6 source archive, digest, recorded commit and independently recomputed Git tree were verified before editing. Root guard and no-Git negative control, package-verifier negative controls, unchanged Go tests with race checking and go vet passed. Encryption, SQLite, device keys, budgeting, recurrence, planning and transaction editor modules were compared byte-for-byte with dev.6. README H1/navigation and local documentation links were checked. No local Flutter/Dart/.NET SDK or Windows GUI was available; their passes above are hosted evidence.

Source artifact 12824906155 from run 40708091219 matched outer SHA-256 6724f37b910ab187ef1326e7fad42fa4eb4594d57162c6912c6dabc713a8490f. Inner source ZIP SHA-256: 97ef40f5f26bf259f5c9c3be5848439087d62a9c8897563a079db4ea5bcb4605. Its recorded application commit and all 100 source files were verified against the application tree. Later documentation edits are separate from this source snapshot.

Windows artifact 12825108489 belongs to the exact successful run and application commit. Outer artifact SHA-256: 3464286de7e7442f3fab52eb5c1c426e7c50bead41fd45305cf2ee02cb0183ef. Inner Budgetism-Windows-x64.zip matches checksums.sha256 and the scan report: da89f1bb0d3a1cfa4a884ca47eccbc1579072d7bd9e039328601f63a28faef3b. Size: 16,092,508 bytes; 18 entries. Verified appId TechSavage1989.Budgetism, version 0.1.0-dev.7, platform windows-x64, stable executable Budgetism.exe, ZIP CRC/paths/limits, all EXE/DLL x64 PE headers and required native libraries. No financial database or private key files are packaged. The actual Go updater accepted the downloaded ZIP in verify-only mode; no installation was attempted.

## Defender evidence

Security artifact 12824553649 matched outer SHA-256 1f54238dc5b432780e062a8c96b429429c3ffac54b4d208b3ea6f25119bbe7b6. The report identifies the same inner package hash above. At 2026-10-28T14:51:18.2693602Z, engine 1.1.26100.4 with signatures 1.463.9.0 reported no threats in both the ZIP and extracted contents, with exit code 0 for both scans. Signature update time: 2026-10-28T08:41:13Z.

Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signature. This one build-time scan is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No antivirus exclusions or global protection disabling were added.

## Remaining gates

Manual dev.7 GUI/file-picker interaction on the user's PC, non-Windows native distributions, live server integration and full updater installation remain unverified. The user-confirmed working baseline is dev.6, not yet dev.7. No GitHub release/tag or production approval. The first committed import requires backup/upgrade consent; older builds cannot open schema 4. See [Windows testing](WINDOWS_TESTING.md).
