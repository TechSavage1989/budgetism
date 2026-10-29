# Validation: Budgetism 0.1.0-dev.15

## Verified application

Application b32e53e1a37a08ca4dd0a4dcb2830ce1b096d153, tree f4cc9bfae3baeec0ffa09199dd5e20a3e83acb7a, passed all five jobs in [run 40809471115](https://github.com/TechSavage1989/budgetism/actions/runs/40809471115). This includes Windows/web compilation, the retained and new unit/widget suites, every native process/preservation test, the new CSV-rule write/read pair, packaging and exact-package Defender scans. Documentation-only follow-ups do not change this tested application/version.

## Starting baseline

The user confirmed dev.14 profiles. Starting main 58ba75a92aa8e92454e43146e1c3849508e3fe69 is the documentation-only follow-up to application b6d515686ba8344d957fe5ec3dd692c283141691, successful run 40801825492. The supplied source artifact's outer SHA-256 is 163ffe788903e70fb39ab1d7746892c50f8f130abb6391cb13dd6246ab9d3e0c; inner SHA-256 8d5d527ba185cac8820c067a61860e84b1b3310c94a366b9a3e2756443566e4c. Both were recomputed; rebuilding its complete Git tree produced 53d01b4f44cd5360bc6b7c70c42296af3d43dc72 before any edits.

## Validation corrections

Initial application e7ecd90cc86fff673ade85cd7c9de403b997c0c4 in run 40807341154 was stopped by two analyzer brace checks. Commit 1313eb99b6f40cec0ceec3e6396b1a4c1abf9374 adds those blocks without changing eligibility semantics. Run 40807768474 then passed analysis and 231 tests, with four new interface-test failures. Two tests interacted with disabled parent controls before a real-async dialog continuation completed in the simulated test loop; another located a Tooltip instead of its disabled IconButton. The test helper and locator were corrected without changing application behavior.

Run 40808398275 on da296854b5404c085bcdbe860e99a90e8f0e6498 passed 234 tests. Its one remaining test failed before the injected disk failure because the in-memory file fixture supplied only a name. The pinned cross_file 0.3.5+5 native implementation ignores that parameter and derives the name from the path. The final fixture supplies both, asserts the filename, observes the actual import operation, and checks unchanged retry requests. The real import filename validation remains unchanged. No test or assertion was removed, skipped or suppressed.

The complete pipeline was rerun on final application b32e53e1a37a08ca4dd0a4dcb2830ce1b096d153. Analysis, all 235 unit/widget tests on the Ubuntu runner, the complete Windows unit/widget suite and both platform builds passed. All Windows-native, package and scanner gates also passed.

## Passed behavior coverage

Read-only detached suggestions; first-match/no-op/disabled/manual-only rules; account/text/amount/current-category conditions; manual and accepted category protection; transfer/payment hints, skipped/matched/handled/invalid rows; stale workspace/rules/file/choices; selected limits and rows beyond the first page; unchanged fields/duplicate approval; exact final posting, profile/rule retention and repeat import refusal. Storage tests use failed writes, SQLite reopen and independent encrypted backups. UI tests cover narrow/wide layouts, cancellation, explicit acceptance/final review, overrides, failed-save retry, stale rules and single-flight controls. The native CSV rule write/read pair uses real Windows keys and SQLite across separate application processes.

## Passed hosted gates

All retained Windows OS-key, schedule, import, matching, reconciliation, rules, category-undo and import-profile write/read pairs passed across separate application processes. The read-only planning, reports and register preservation tests also passed. The new CSV-rule pair verifies that acceptance alone leaves encrypted data unchanged, one explicit import saves the reviewed category, and reopening in another native process retains the exact balance, category, receipt count and optional-password setting while refusing repeat import.

Windows compilation and portable packaging from an archive without Git metadata, package identity/runtime checks, source-layout/package negative controls, backend/accounting contracts and Go updater tests passed. Microsoft Defender scanned the exact ZIP and extracted runtime before upload. No local Flutter/Dart/.NET or Windows GUI was available; hosted execution is distinct from manual desktop confirmation. No updater install/relaunch/rollback was performed.

## Source and local verification

Source artifact 12869551998 from source run 40809470994 matched outer SHA-256 09376f0660f374e64e427659ed81059aac806ce79c4da647e52dcccee8d5e459 and inner SHA-256 ce55b4d2b4f5380b870894d279d6b4de053265db3c8d8be1f79ab6b0637f8d82. Its commit marker is b32e53e1a37a08ca4dd0a4dcb2830ce1b096d153. Independent reconstruction of all 164 source files produced Git tree f4cc9bfae3baeec0ffa09199dd5e20a3e83acb7a. All 125 non-document source/workflow files match the intended local source byte for byte.

Local source-layout/deliberate-clutter checks, package-verifier negative controls, unchanged Go race tests and go vet, diff whitespace, 66 local Markdown targets and the README single centered H1/navigation passed. Forty-six existing finance/backend/updater implementation files remain byte-identical to dev.14, including the ledger, CSV parser/importer, rules/profiles/history, all financial engines, storage, OS keys and updater. The existing import screen is the only prior financial UI file changed. No local Flutter/Dart/.NET SDK or Windows GUI exists.

## Exact delivered package

Windows artifact 12870570526 belongs to the successful run/commit above. Outer SHA-256 064e065975363314ba1f49b94918905ef9d314e6c07bbb27c4bd4c59f43b6f75. Inner Budgetism-Windows-x64.zip: 16,310,892 bytes, 18 entries, SHA-256 6bdc3420a6b6a4640bd890db2488fbbe42b0eb75554de58b7472194d92456d22. This matches checksums.sha256 and the exact Defender report.

Application identity TechSavage1989.Budgetism, version 0.1.0-dev.15, platform windows-x64, stable Budgetism.exe name, required x64 PE/runtime files, CRC/path/size guards and absence of packaged financial databases/private keys passed independent verification. The actual unchanged Go updater accepted the downloaded archive in verify-only mode. No installation was attempted. The chat download is a byte-for-byte copy of the inner archive.

## Defender evidence

Security artifact 12869983322 matched outer SHA-256 5b89dbcc07777ec83c0618a3110e8ec977181dda652c2525856f7a4df880b78f. At 2026-10-29T03:12:04.4177497Z, engine 1.1.26100.4 with signatures 1.463.16.0 reported no threats in both the ZIP and extracted files, exit code 0 for each. Signature update: 2026-10-28T20:03:00.0000000Z. Its archive hash matches the delivered inner ZIP.

Both Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signatures. This one build-time scan is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No exclusions, protection disabling, skipped tests or analyzer/scan suppression were added.

## Remaining gates

Dev.14 remains the user-confirmed baseline. Dev.15 manual desktop interaction, non-Windows native distributions, synchronization and full updater installation remain unverified. No release/tag or production approval. There is no new schema or migration. CSV suggestions are not imported transactions and do not create a category-history undo batch. See [Windows testing](WINDOWS_TESTING.md).
