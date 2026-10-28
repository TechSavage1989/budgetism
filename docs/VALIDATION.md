# Validation: Budgetism 0.1.0-dev.13

## Verified application

Application 6f6e33c58c297fc55dde40ce74aae9a64f2acc7a, tree 6106ec95fb78ab89aff027bd0296d4741a7a8692, passed all five jobs in [run 40781260879](https://github.com/TechSavage1989/budgetism/actions/runs/40781260879). This includes Windows/web compilation, all retained/new unit and widget tests, every prior native process/preservation test, the new undo write/read pair, packaging and exact-package Defender scans. The first application run passed without code fixes or suppressed checks. Documentation-only follow-ups do not change the tested application/version.

The user confirmed dev.12 application 605ffe4334f20a94197f923fff12562e9de8737d, tree 507235f9a15065c51b0251cbd0083ef90ecf4263, successful run 40772902439. Starting main 11b8edec71d97f111a16a44c02ac46fbf119633b is its documentation-only follow-up. Live comparison verified identical app/workflow code. Earlier setup tests do not need to be repeated by the user.

## Passed hosted checks

- Flutter analysis, all 200 unit/widget tests on the Ubuntu web runner, the complete Windows unit/widget suite and web compilation.
- Prior batch read-only and detached previews, original rule version, exact category-only restoration and preserved monetary values/identities/collections.
- Append-only audit, duplicate operation/repeat undo rejection, stale review fingerprints, whole-batch protection, disjoint and overlapping batch behavior, and preserved import/schedule links.
- Missing/duplicated/inconsistent history rejection, legacy empty history without migration and exact monetary bounds.
- Failed storage commit atomicity, stable retry, stale writers, actual SQLite reopening and independently encrypted backup restoration.
- Narrow/wide widgets, explicit reason/review, failed-save input retention, single-flight, stale/blocked/undone states and rules-page refresh.
- All prior Windows OS-key/schedule/import/matching/reconciliation/rules write/read pairs in separate app processes, plus planning/report/register preservation tests.
- New native undo pair using real Windows OS keys and SQLite across separate write/read app processes: restored categories, retained original history/reason, unchanged transaction/import/rule counts, exact balance, optional-password retention, unchanged retry and rejected second undo.
- Windows compilation/portable packaging from a source archive without Git metadata, package identity/runtime checks, source-layout/package negative controls, backend build/accounting contracts and Go updater checks.
- Microsoft Defender scans of the exact Windows ZIP and its extracted contents before upload.

## Source and local verification

Starting dev.12 source outer SHA-256 29f1d769b602096a9d860a9404f40c60a6ea0e024bbc6bd8070e2826dd6719f7; inner source SHA-256 6bc8ffebc3b573adbf737e40d58173da33e7e4ce5793a45f37471d0cea08b057. Both were recomputed before editing.

Dev.13 source artifact 12857217315 from source run 40781260989 matched outer SHA-256 8329f87c8683fefacf69081d73c29aa0c71e541a756e1747935a6224f090773c and inner SHA-256 074e1a9757508bbb0c0cb3ef3167f74cf28a0870dddcb5db9069036cee4b2bcd. Its commit marker matches the application above. Independent reconstruction of all 147 archive files produced Git tree 6106ec95fb78ab89aff027bd0296d4741a7a8692. All 111 application/workflow/source files matched the prepared implementation byte for byte; documentation follow-ups do not alter the tested code.

Local source-layout checks, package-verifier negative controls, diff whitespace, unchanged Go race tests/vet, 26 local documentation targets and README single centered H1/navigation passed. Thirty-nine existing local-finance/backend/updater files remain byte-identical to dev.12, including financial calculation engines, the register/editor, rules engine, recurrence, imports, matching, reconciliation, encryption, SQLite and OS keys. Ledger changes add only the history part and explicit undo mutation route. No new dependency or financial schema.

No local Flutter/Dart/.NET SDK or Windows GUI was available. Hosted compilation/native execution is distinct from a manual desktop test. No manual user-interface test or full updater installation is claimed.

## Exact delivered package

Windows artifact 12856818776 belongs to the successful application run/commit above. Outer SHA-256 6c6e140f25ec63f25aaca536b4b187774fcb280564772eaf3a7dc39af15d3f2c. Inner Budgetism-Windows-x64.zip: 16,268,757 bytes, 18 entries, SHA-256 2f9f48eba4416634855f8904f957dae69dfa0520e1daedd1d9d561893d3723e2. It matches checksums.sha256 and the exact Defender report.

Application identity TechSavage1989.Budgetism, version 0.1.0-dev.13, platform windows-x64, stable Budgetism.exe name, required x64 PE/runtime files, CRC/path/size guards and absence of packaged financial databases/private keys passed. The actual unchanged Go updater accepted the downloaded package in verify-only mode. No installation was attempted.

## Defender evidence

Security artifact 12858515182 matched outer SHA-256 b629fc1107d25c71277fc9a9b59925a335023c1c2c0300393fe69c7df22018e6. At 2026-10-28T22:53:38.8711185Z, engine 1.1.26100.4 with signatures 1.463.16.0 reported no threats in the ZIP and extracted contents, with exit code 0 for both scans. Signature update: 2026-10-28T20:03:00.0000000Z. Its archive hash matches the delivered inner ZIP.

Both Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signatures. This one build-time scan is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No exclusions, protection disabling, skipped tests or analyzer/scan suppression were added.

## Remaining gates

Dev.12 remains the user-confirmed baseline. Manual dev.13 history/undo interaction on the user's PC, non-Windows native distributions, synchronization and full updater install/relaunch/rollback remain unverified. No release/tag or production approval. No new financial migration; saved rules remain unchanged. This is categorization-batch undo, not general financial undo or database rollback. See [Windows testing](WINDOWS_TESTING.md).
