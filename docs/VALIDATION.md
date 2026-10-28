# Validation: Budgetism 0.1.0-dev.5

## Verified application and negative controls

Application commit 39353fd46314aa22866ff85dcf0aad352fa39601, tree ff18ea3612a54a4a2f20e1afcdd5dc099f24fc8d. [Run 40616768105](https://github.com/TechSavage1989/budgetism/actions/runs/40616768105) passed all five jobs.

Initial run 40615851293 stopped on two multiline-if analyzer findings in schedule_rules.dart. After adding braces, run 40616113561 passed analysis but failed the narrow-screen widget test with a 192-pixel RenderFlex overflow. The final change added isExpanded and constrained item text to the Upcoming range dropdown. The same 430-pixel test, analyzer gates and full suite passed without disabled checks or relaxed viewport size. These actual failing runs are the negative controls.

## Passed in hosted CI for this exact application commit

- Flutter analysis and the full existing/new unit and widget suite on Ubuntu and Windows.
- Date anchors, leap years, month-end/DST boundaries, inclusive end dates and overdue ordering.
- Planned versus actual separation, exact-cent income/expense/transfer posting and actual-date budget effects.
- Duplicate confirmation rejection, idempotent retry, stale schedule/occurrence versions, failed-save atomicity and retained links after edits/voids.
- Explicit recurring schema migration, preserved legacy budget upgrade, validated encrypted backup/restore and actual SQLite reopen/stale-window checks.
- Form validation, migration consent, failed-save field retention, single-flight confirmation and narrow-screen layout.
- Existing real Windows OS-key/SQLite budget-security test in separate write/read processes.
- New real Windows recurring test in separate write/read processes: one confirmed transaction, postponed/skipped state, budget effect and duplicate rejection survive process exit.
- Windows release compilation and portable packaging from an extracted source archive without .git; package/native dependency verification.
- Flutter web compilation. This does not enable browser-local finance storage.
- .NET backend build/accounting contracts, Go updater tests, root guard and package-verifier negative controls.

## Passed locally

- Dev.4 source provenance/digests and independent Git-tree recomputation before editing. Existing user-confirmed baseline was c7de25eeff74651519407df666074262effc9176, not older main.
- Corrected whole source tree matches the exact application commit. Source artifact 12784884893 from run 40616767947: outer SHA-256 a21af4d581ecb212c2557a0a17b2438a2e653a216c950cf09223fc02c6e51161; inner source ZIP SHA-256 f9837b4b5b601a03d6dd6a1e2563eef82d777552b2b673865d8f193b53fd1fd1. Source commit and all 82 files matched.
- Root-layout guard and deliberate-clutter negative control, including clean no-Git source extraction. Unchanged Go tests/race detector and go vet passed.
- Existing encryption, device-key handling, SQLite, budget engine/UI, transaction editor, native security test, backend and updater compared byte-for-byte with dev.4.
- README Markdown-to-HTML conversion, one H1, navigation anchors and local documentation targets. A browser screenshot could not be produced because the local browser executable was unavailable.
- Windows artifact 12785682854 belongs to run 40616768105 and the tested commit. Outer SHA-256 21e086088c8715624cf836714625867f1967f5d155bae0bb92de4af118d3c400.
- Inner Budgetism-Windows-x64.zip matches checksums.sha256: d28557bb57c8a9d3bc4ef5318e9021f9f4a836ee050bb720f5910c2102cfee1e. Size 15,957,183 bytes; 18 entries.
- ZIP CRC/path/size/duplicate checks, app identity, 0.1.0-dev.5 version, windows-x64 platform and stable Budgetism.exe target.
- All EXE/DLL files have expected x64 PE headers; required Flutter, SQLite, secure-storage, file-selector and URL-launcher dependencies are present. No financial databases or private key files are packaged.
- Actual Go updater accepted the downloaded ZIP in verify-only mode. No installation or app-folder replacement was attempted.

## Remaining manual gates

No manual dev.5 GUI or backup-file-picker workflow on the user's PC, independent security review, live PostgreSQL integration, non-Windows native distributions, actual focus/update polling, or native updater install/relaunch/rollback is claimed. Local Flutter/.NET SDKs and Windows GUI were unavailable; their passes above are hosted evidence.

This is a development artifact, not a signed distribution, GitHub release or production approval. In-app installation stays disabled. Export an encrypted backup before the first schedule save; older builds cannot open the upgraded financial schema. Documentation-only follow-ups do not change the tested application or require a new version.
