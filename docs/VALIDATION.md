# Validation: Budgetism 0.1.0-dev.14

## Verified application

Application b6d515686ba8344d957fe5ec3dd692c283141691, tree 53d01b4f44cd5360bc6b7c70c42296af3d43dc72, passed all five jobs in [run 40801825492](https://github.com/TechSavage1989/budgetism/actions/runs/40801825492). This includes Windows/web compilation, all retained and new unit/widget tests, every prior native process/preservation test, the new import-profile write/read pair, packaging and exact-package Defender scans. Documentation-only follow-ups do not change this tested application/version.

The user confirmed dev.13 category history/undo and all earlier milestones. Starting main a5b89e75b9f704b96c5f307f25b7647351a58f87 was the documentation-only follow-up to application 6f6e33c58c297fc55dde40ce74aae9a64f2acc7a, successful run 40781260879. No earlier setup exercise needs repeating.

## Correction and full rerun

Initial application 39b03949cbcdc34a86400ef745539fb085ef1a45 in run 40801071667 failed a profile-save interface test. The parent import screen displayed an indeterminate progress indicator while waiting for the profile dialog, so the interface test could not settle. The corrected app keeps the parent controls disabled but hides that loading indicator while the profile dialog is open. A regression assertion checks both conditions. No test was skipped, removed or suppressed, and the financial/import mutation logic was not changed by the fix. The complete suite and native build pipeline were rerun on the corrected commit above.

## Passed hosted checks

- Flutter analysis, all 219 unit/widget tests on the Ubuntu web runner, the complete Windows unit/widget suite, and web compilation.
- Financial schemas 1 through 6 migrate only after explicit profile-save consent; earlier collections, category-undo history and reconciliation protections remain intact.
- Exact header-name binding with reordered/extra columns; missing/ambiguous mapped headers rejected without positional fallback; separators, date formats, signed and separate debit/credit amounts, optional columns and defaults validated.
- Profile name uniqueness, version/revision checks, archive/restore, bounded count and malformed/corrupt records; statement rows and duplicate decisions never saved in profile settings.
- Failed profile/storage writes remain atomic, unchanged retries save once, stale writers fail, SQLite reopening and independent encrypted backup restoration preserve profiles and optional-password behavior.
- Interface checks at narrow/wide widths, destination-account preservation, explicit profile application, missing-header recovery, separate profile-save/import confirmation, archive confirmation and single-flight saves.
- All retained Windows OS-key/schedule/import/matching/reconciliation/rules/category-undo write/read pairs in separate application processes, plus read-only planning/report/register preservation tests.
- New real Windows OS-key/SQLite profile write/read pair: profile survives a separate app process; a reordered CSV is resolved by name; its duplicate bank reference is rejected without another transaction; exact balance, transaction/receipt counts and password-free mode remain correct.
- Windows compilation/portable packaging from an archive without Git metadata, package identity/runtime checks, source-layout/package negative controls, backend build/accounting contracts and Go updater tests.
- Microsoft Defender scans of the exact Windows ZIP and its extracted files before upload.

## Source and local verification

The starting dev.13 source artifact matched outer SHA-256 8329f87c8683fefacf69081d73c29aa0c71e541a756e1747935a6224f090773c and inner SHA-256 074e1a9757508bbb0c0cb3ef3167f74cf28a0870dddcb5db9069036cee4b2bcd. Its reconstructed tree was 6106ec95fb78ab89aff027bd0296d4741a7a8692 before editing.

Corrected dev.14 source artifact 12866471294 from source run 40801825829 matched outer SHA-256 163ffe788903e70fb39ab1d7746892c50f8f130abb6391cb13dd6246ab9d3e0c and inner SHA-256 8d5d527ba185cac8820c067a61860e84b1b3310c94a366b9a3e2756443566e4c. Its commit marker matches the tested application. Independent reconstruction of all 156 files produced tree 53d01b4f44cd5360bc6b7c70c42296af3d43dc72. All 118 application/workflow/source files matched the intended implementation byte for byte.

Local source-layout/deliberate-clutter checks, package-verifier negative controls, unchanged Go race tests and go vet, diff whitespace, 56 local Markdown targets and the README single centered H1/navigation passed. Forty-one existing local-finance/backend/updater files remain byte-identical to dev.13, including the CSV parser, import/duplicate engine, financial calculations, category history, register, encryption, SQLite and OS keys. Only the existing import screen, ledger routing/schema/snapshot and local API were changed in those areas, with new profile files added. No new package dependency, encryption format or backup envelope.

No local Flutter/Dart/.NET SDK or Windows GUI was available. Compilation and native execution above are hosted evidence. No manual desktop interaction or full updater installation is claimed.

## Exact delivered package

Windows artifact 12866993294 belongs to the successful application run/commit above. Outer SHA-256 fcfa9748a2f224d9887ec1a229e50c62283764b04d975c788a52537682823e9c. Inner Budgetism-Windows-x64.zip: 16,297,677 bytes, 18 entries, SHA-256 d161ebdc5fd89a8d3a9ff1a796d28a33ca1f099cfd346af85b92a093a4129456. It matches checksums.sha256 and the exact Defender report.

Application identity TechSavage1989.Budgetism, version 0.1.0-dev.14, platform windows-x64, stable Budgetism.exe name, required x64 PE/runtime files, CRC/path/size checks and absence of packaged financial databases/private keys passed. The actual unchanged Go updater accepted the downloaded archive in verify-only mode. No installation was attempted. The chat download is a byte-for-byte copy of that inner archive.

## Defender evidence

Security artifact 12867316574 matched outer SHA-256 ddbf83eef0ebb6cb5c425c9542654432b7c0c1675b0ad98e8beb0c1ecf0f5ae2. At 2026-10-29T01:59:06.8832898Z, engine 1.1.26100.4 with signatures 1.463.16.0 reported no threats in both the ZIP and extracted files, exit code 0 for each. Signature update: 2026-10-28T20:03:00.0000000Z. The scan report identifies the exact inner archive hash above.

Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signatures. This one build-time scan is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No exclusions, protection disabling, skipped tests or analyzer/scan suppression were added.

## Remaining gates

Dev.13 remains the user-confirmed baseline. Dev.14 profile interaction on the user's PC, non-Windows native distributions, synchronization and full updater install/relaunch/rollback remain unverified. No release/tag or production approval. First profile save requires explicit backup/consent for schema 7; dev.13 and older cannot open the upgraded workspace. Loading profiles and previewing CSV files do not save transactions or migrate data. See [Windows testing](WINDOWS_TESTING.md).
