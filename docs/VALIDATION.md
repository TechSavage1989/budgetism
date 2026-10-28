# Validation: Budgetism 0.1.0-dev.12

## Verified application

Application 605ffe4334f20a94197f923fff12562e9de8737d, tree 507235f9a15065c51b0251cbd0083ef90ecf4263, passed all five jobs in [run 40772902439](https://github.com/TechSavage1989/budgetism/actions/runs/40772902439). This includes Windows/web compilation, the full retained/new unit and widget suites, every retained native process pair, the new register preservation test, packaging and Defender scanning. The first application run passed without code fixes or suppressed checks. Documentation-only follow-ups do not change this tested application or version.

The user confirmed dev.11 rules and all earlier finance features. Starting application 6296272ca9d6635379928fd783f17be57e5d4a83 on development/rules-dev11 has successful run 40746717030. Main was still the dev.10 documentation follow-up 17a5a04b3e8ca1688afce38f4d60859d9ac8c522; dev.12 preserves the full newer dev.11 ancestry rather than reverting it.

## Passed hosted checks

- Flutter analysis, all 179 unit/widget tests on the Ubuntu web runner, the complete Windows unit/widget suite, and web compilation.
- Read-only snapshots, future recorded entries vs plans, complete-match totals, exact split contributions vs whole-amount filtering, inclusive date/amount validation and aggregate limits.
- Query words, quoted phrases, exclusions, malformed query rejection, source/reconciliation state for each transfer side, global edit protection, voided history and deterministic sorting.
- Results beyond 100 visible rows, unavailable selections without scope broadening, detached immutable values, schema 1-6 reads and saved rules/schedule/import preservation.
- Narrow/wide register and details layouts, reset/error handling, explicit editor handoff, protection changes before editing, 101-row expansion and real-shell navigation retaining session filters.
- All retained Windows OS-key/schedule/import/matching/reconciliation/rules write/read pairs in separate app processes, plus the planning/report preservation tests.
- New native register test using real Windows SQLite and OS keys: unchanged encrypted payload/revision/financial JSON during filtering, reproducible details after close/reopen, saved rules and optional-password retention, and rejected protected edits. This new test is same-process close/reopen, not another separate-process pair.
- Windows compilation/portable packaging from a source archive without Git metadata, package identity/runtime checks and negative controls, backend/accounting contracts, updater tests and source-layout guards.
- Microsoft Defender scans of the exact Windows ZIP and extracted runtime before upload.

## Source and local verification

The starting dev.11 source outer SHA-256 was 5c00a452b17ab93555390d920d38b234353da3aa3a214536c378cbcbb0cb4949; inner source ZIP 9820412aa2e2b52ef875c0a5e0de76be310dee9333b871ac8ebd997777636280. Source commit and independently recomputed tree matched 07731ab027b035b331f39f23117700e57018d479 before editing.

Dev.12 source artifact 12851604858 from run 40772902155 matched outer SHA-256 29f1d769b602096a9d860a9404f40c60a6ea0e024bbc6bd8070e2826dd6719f7 and inner SHA-256 6bc8ffebc3b573adbf737e40d58173da33e7e4ce5793a45f37471d0cea08b057. Every one of its 137 files matched the intended source. Independently reconstructing the entire archive tree produced 507235f9a15065c51b0251cbd0083ef90ecf4263.

Local source-layout/deliberate-clutter checks, package-verifier negative controls, Go race tests and go vet, diff whitespace, 44 local documentation links and the README single centered H1 passed. Forty existing local-finance/backend/updater files are byte-identical to dev.11. Only nine app/workflow paths changed, plus documentation; ledger mutations, encryption, SQLite, OS keys, budgets, scheduling, matching, imports, reconciliation, reports and the existing transaction editor remain unchanged.

No local Flutter/Dart/.NET SDK or Windows GUI was available. Compilation/native execution above is hosted evidence. No manual desktop test or full native updater installation is claimed.

## Exact delivered package

Windows artifact 12855070182 belongs to the successful application run/commit above. Outer SHA-256: 47851f9ebf0aaea4e1c6ddeab3bd41150a579c25a2c761376c189127f960faf5. Inner Budgetism-Windows-x64.zip: 16,253,564 bytes, 18 entries, SHA-256 50373bec6edd60017d1066199112277cd4d89d0695e9e99b00a1dba704fa1624. The inner hash matches checksums.sha256 and the Defender report.

Application identity TechSavage1989.Budgetism, version 0.1.0-dev.12, platform windows-x64, stable Budgetism.exe name, required x64 PE/runtime files, CRC/path/size guards and absence of packaged financial databases/private keys passed. The actual unchanged Go updater accepted the downloaded archive in verify-only mode with its supported archive/sha256/version flags. No installation was attempted.

## Defender evidence

Security artifact 12853913856 matched outer SHA-256 75a84112472adf8cdc83f2e9e4e8a4c2b05a6f27b96bd5c05d477aa806d2f7f2. At 2026-10-28T21:50:01.4883131Z, engine 1.1.26100.4 with signatures 1.463.16.0 reported no threats in both the ZIP and extracted files, exit code 0 for each. Signature update: 2026-10-28T20:03:00.0000000Z. The report identifies the exact inner hash above.

Budgetism.exe and Budgetism-Updater.exe have no embedded Authenticode signatures. This one scanner result is not publisher signing, an independent audit, universal browser reputation or an explanation of the earlier dev.5 warning. No exclusions, protection disabling, skipped tests or analyzer/scan suppression were added.

## Remaining gates

Dev.11 remains the user-confirmed baseline. Manual dev.12 register interaction on the user's PC, non-Windows native distributions, synchronization and full updater install/relaunch/rollback remain unverified. No release/tag or production approval. The register requires no financial migration. Filters are session-only and clear when the workspace closes; saved rules/records/security remain persistent. See [Windows testing](WINDOWS_TESTING.md).
