# Validation: Budgetism 0.1.0-dev.9

## Verified application and corrections

Application commit 1ba16145c8e9cec3cf88b39eceadbbfd8cab6b06, tree 113f9f79d896a92b5bd74943c81867b7149da39c. [Run 40728930400](https://github.com/TechSavage1989/budgetism/actions/runs/40728930400) passed all five jobs, including the new separate-process Windows reconciliation test and the exact-package Defender scan. Documentation-only follow-ups do not change this application or version.

The user-confirmed baseline is dev.8, application 0e41cbf1a2127aedeaa1dae267f538b06ce19d1b, successful run 40717507066. Starting main 1de69f0f3598aa275e52b910714cb30e5fcdac14 is its documentation follow-up. Earlier user-confirmed budgeting, forecasting, importing and matching do not need repeated setup exercises.

Initial dev.9 run 40727677184 stopped at Flutter analysis because FilledButton.icon used child instead of its required label argument. Commit 398baf82e3647089b835a3b8334dec3e795774b2 corrected that one application line. Run 40728274160 then passed analysis and 126 tests, with one widget-test failure: ensureVisible could not locate an off-screen lazily built transaction row. The final commit changed the test harness to scroll the explicit outer form until controls are built and visible. The viewport and all financial, review, failure and retry assertions were retained. The full suite then passed. No tests were skipped or analyzer/scan gates suppressed.

## Passed in hosted CI

- Flutter analysis and the full existing/new unit and widget suite on Ubuntu and Windows, plus web compilation.
- Read-only statement preview, explicit review/upgrade consent, exact-cent totals and zero-difference completion with no financial postings.
- Older outstanding items, consecutive statements, latest-only reopening, retained history, signed debt balances and independent transfer sides.
- Edit/void protection and account opening/type protection, with account renaming and appropriate metadata-only matches preserved.
- Stale revisions, duplicate selections/replay, future/voided/already-reconciled entries, corrupted history and exact-integer limits.
- Financial schemas 1 through 4 upgrading to 5 only on completion, with prior records preserved; subsequent imports and schedule matching remain valid.
- Failed-save atomicity for completion/reopening, actual SQLite reopen, stale writers and encrypted backup restore retaining statement locks and security mode.
- Widget validation, failed-save field retention and retry, narrow-window precision errors, and explicit reopening consent.
- Retained Windows security, schedules, imports and matching tests in separate write/read processes, plus the read-only planning test.
- New Windows reconciliation write/read pair using actual SQLite and OS keys: statement/receipt persistence, protected edits rejected without changing saved bytes, and reopening retained after another open.
- Windows compilation/portable packaging from a clean source archive without Git metadata; identity/native dependency verification and negative controls.
- Backend build/accounting contracts, Go updater tests, source-layout guard and deliberate-clutter checks.
- Microsoft Defender scans of the exact Windows ZIP and extracted files before application artifact upload.

## Local source and package verification

The dev.8 source artifact, commit and full Git tree were verified before editing. The final dev.9 source artifact 12834546247 from run 40728930430 matched outer SHA-256 e5074a972baadbcbe2cc65dd63e27780dec5e150391c9ff397e2c925bece8ea3 and inner source ZIP SHA-256 5c20d06f9855c9c57eea05c22fff3bfea25849266bc03e1cdf1c3446c28a5239. All 116 files matched the prepared source and independently recomputed tree 113f9f79d896a92b5bd74943c81867b7149da39c.

Local source-layout and package-verifier negative controls, diff whitespace, unchanged Go tests with race checking and go vet passed. Encryption, SQLite, device keys, budgets, planning, recurrence, matching helpers, transaction editor, backend and updater were compared byte-for-byte with the baseline. The README centered single H1 and local documentation targets were checked. No local Flutter/Dart/.NET SDK or Windows GUI was available; compilation and native execution above are hosted evidence.

Windows artifact 12834822871 belongs to the exact successful run and commit. Outer SHA-256: 009a8d8e527e3d3af68da6a189c8de47633f0c5216c8f0adfb2395a8d718180d. Inner Budgetism-Windows-x64.zip is 16,126,748 bytes with 18 entries, SHA-256 9c76464b6934d0f430cbb3b24efe7c9627627cd80e88a3c0c5fbd0e71f7a5e5c. It matches checksums.sha256 and the scan report. Application identity TechSavage1989.Budgetism, version 0.1.0-dev.9, platform windows-x64, stable Budgetism.exe target, archive CRC/paths/limits and required x64 PE/runtime files passed. No financial database or private key files are packaged. The actual Go updater accepted the downloaded archive in verify-only mode; no installation was attempted.

## Defender evidence

Security artifact 12834608380 matched outer SHA-256 a7e233b9727a18895a0968fa78681ea7d3cd5084898c5feffeefcf127326313e. At 2026-10-28T16:58:12.9462676Z, engine 1.1.26100.4 with signatures 1.463.10.0 reported no threats in both the ZIP and extracted contents, exit code 0 for each. Signature update time: 2026-10-28T10:14:03.0000000Z. The report identifies the exact inner package hash above.

Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signatures. This one build-time result is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No antivirus exclusions or protection disabling were added.

## Remaining gates

Manual dev.9 GUI interaction on the user's PC, non-Windows native distributions, live backend/synchronization and full updater installation/relaunch/rollback remain unverified. Dev.8 remains the user-confirmed baseline. No GitHub release/tag or production approval. Export a backup before the first completed reconciliation upgrades the financial payload to schema 5; older builds cannot read it. Viewing alone does not upgrade. See [Windows testing](WINDOWS_TESTING.md).
