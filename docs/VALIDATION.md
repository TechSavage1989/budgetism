# Validation: Budgetism 0.1.0-dev.17

## Verified application

Application dd70d39df255a6484179e6df20ee0a63997915ef, tree e21c739f544e4611505bc059a3f9730b44a627b5, passed all five jobs in [run 40822480327](https://github.com/TechSavage1989/budgetism/actions/runs/40822480327). The exact development package was then independently downloaded and verified. Documentation-only follow-ups retain the tested application/version. This is not a production release or a manual test on the user's PC.

Starting main 086fbd7b26bf420296103f47de7c7e5b4a8da1e7 is the documentation follow-up to dev.16 application ef07b3438605a3de215c4cf1f75bccf015f519fc, successful run 40816063799. Dev.15 is the most recent explicit user confirmation; continued development is not a claim that the user manually tested dev.16.

## Corrections and retained checks

Initial dev.17 application 7f51e1a4d8b350d98ecd327a3f556e13e0d8529c passed its 269-test unit/interface suite and web build. A review found that Home's current-month budget shortcut could reopen an earlier session month. Commit bae344b4845bacb8a3cf2f24b4f7c47aa41c6e69 corrected the shortcut and added a complete regression test; all 270 unit/interface tests passed on that candidate.

A subsequent workflow audit caught an incorrectly transcribed category-undo native test filename and phase variables. The superseded run 40821297031 stopped at that native test and did not build, scan or upload an application package. Final application dd70d39df255a6484179e6df20ee0a63997915ef restores the original category_undo_restart_test.dart write/read commands and UNDO_TEST settings. It also adds early source checks with negative controls for missing targets, incorrect phase variables and mismatched shared directories. All 22 original native commands remain byte-for-byte identical to dev.16; only the new quick-entry write/read pair is added. No assertion, analyzer rule, native test or scanner gate was disabled to obtain a passing result. Failed runs blocked later steps as intended. The entire pipeline was rerun on the final commit.

## Passed hosted behavior

Flutter analysis, all 270 unit/widget tests, the complete Windows unit/widget suite, and Windows/web compilation passed. The retained OS-key, schedule, import, matching, reconciliation, categorization-rule, category-undo, import-profile and CSV-rule write/read process pairs passed. Read-only planning, reports and register preservation checks and the actual native calendar UI/save/reopen check passed.

The new Windows quick-entry test saves fictional 1.25 and 2.75 expenses through the actual editor, verifies that Save and add another clears the amount, and opens the encrypted workspace in a separate process. It confirms exactly two transactions with separate operation identities, exact amounts, a 996.00 balance from 1,000.00, unchanged schema and password-free mode. Unit/interface checks cover failed-save retry identity, single-flight saves, split/transfer resets, payee text-only completion, selector cancellation, protected details, exact historical Home totals and 360/1100-pixel layouts. Home's budget shortcut selects the current month while ordinary navigation retains the selected session month.

Source-layout and package negative controls, backend/accounting contracts, Go race tests, Windows packaging and exact ZIP/extracted Defender scanning passed. Existing logs include the deliberate disabled-control hit-test warning, Cupertino font-family notice and action-runtime deprecation notice; this is not a warning-free-build claim. No updater installation, live bank connection or server deployment was performed.

## Source and local verification

Source artifact 12875261726 from run 40822480402 matches outer SHA-256 f4edbcd5ebf516dbf17931a99ccfa6811fd22aaca51fc9499ce78b6e37f3d27e and inner SHA-256 7316c3e69e6a3e919ed4c240f4b7a813d1b75b9b28dd4be4b67da550e9c6e54a. Its commit marker is dd70d39df255a6484179e6df20ee0a63997915ef. Rebuilding the Git tree from all 181 source files produced e21c739f544e4611505bc059a3f9730b44a627b5.

Local root-layout/native-target negative controls, package-verifier negative controls, Go race tests/go vet, diff whitespace and local Markdown target checks passed. A comparison against dev.16 found 112 unchanged existing application/backend/updater files. The only changed existing application files are the transaction editor, main shell extraction/integration, version references and one navigation-label test. All financial engines, ledger mutations, imports, rules/profiles/history processing, storage/encryption/OS keys, backend and updater behavior are retained. New Home and entry modules contain no network, filesystem or preference API calls. No local Flutter/Dart/.NET SDK or Windows runtime was available; native execution is hosted evidence.

## Exact delivered package

Windows artifact 12875328581 belongs to the successful run/commit above. Outer SHA-256 fa7a6d96a61babf5e20a3fb7233443284621963a2fd9dd08d71a62f7eb9b46cf. Inner Budgetism-Windows-x64.zip: 16,378,297 bytes, 18 entries, SHA-256 258107629dd84d93b1f2835608a67218e7ae0a3e25c3ed3c34d10ad3fea9663e. The inner hash matches checksums.sha256 and the Defender report.

Independent validation confirms TechSavage1989.Budgetism, version 0.1.0-dev.17, windows-x64, stable Budgetism.exe, required runtime files, archive CRC/path guards and package-verifier negative controls. The unchanged Go updater accepted the archive in verify-only mode. No installation was attempted. The chat download is an unchanged copy of the scanned inner ZIP. No financial database or bank credential is included.

## Defender evidence

Security artifact 12875842231 matches outer SHA-256 d4b1645d5069888c8ebc8b2b4b5bfc3a30ac2b49dcebd0f2739787fd833d5a66. At 2026-10-29T05:37:50.6305356Z, engine 1.1.26100.4 and signatures 1.463.16.0 reported no threats in both the ZIP and extracted runtime files, with exit code 0 for each. Signature update: 2026-10-28T20:03:00.0000000Z. The recorded archive hash matches the delivered ZIP.

Budgetism.exe and Budgetism-Updater.exe have empty embedded PE certificate directories and remain unsigned. This build-time scan is not publisher signing, an independent security audit, an explanation of the earlier download warning or a guarantee of every browser's acceptance. No antivirus exclusions or protection disabling were added.

## Remaining work

No new financial schema, migration, dependency or security-mode change. Manual dev.17 interaction on the user's computer is still pending. Window geometry, live bank connectivity, device synchronization, non-Windows native distribution and updater installation remain unfinished. Next is the provider-independent simulated bank feed and unified review inbox described in BANK_CONNECTION_PLAN.md, before separately authorized real-bank/provider setup. No release/tag or production approval.
