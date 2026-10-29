# Validation: Budgetism 0.1.0-dev.18

## Verified application

Application **bb67d575cc5b37de1452df6a95a855bde3162374**, tree **daa6efd94ff48a54c88063770044bbeb0099b9b9**, passed all five jobs in [build run 40896092713](https://github.com/TechSavage1989/budgetism/actions/runs/40896092713). The separate [source archive run 40896092824](https://github.com/TechSavage1989/budgetism/actions/runs/40896092824) also passed. The exact Windows development package was downloaded and independently verified locally. Documentation-only follow-ups retain the tested application and version. This is a development build, not a production release or a manual test of the user's real workspace.

The user confirmed dev.17 works. Dev.18 starts at b222b62a2293c6092fba3ab92e327b46a7802356. Live main, branches, PRs, releases and workflows were checked before implementation and publication. Historical dev.17 evidence is preserved in [VALIDATION_DEV17.md](VALIDATION_DEV17.md).

## Corrections and retained gates

Initial candidate a3e6eca9e9bda4658309ec1169253ee8e6f8c8a8 passed source/backend/updater checks but failed Flutter analysis in run 40894250188: CI-generated lint settings identified 41 missing-brace findings. These were corrected, and the shared Flutter lint configuration is now tracked so local and hosted analysis use the same rules. No lint was disabled. That failed candidate produced no delivery package. The complete pipeline passed on the corrected application above.

All **270 retained and 36 new unit/widget/storage tests (306 total)** pass locally, in the hosted web job and on Windows. A retained Settings assertion was updated for the intentional fictional-connection message and extended to check local-workspace gating. No existing financial assertion or native command was removed. The original **24 native Windows commands** are retained byte-for-byte; the bank write/read pair brings the total to **26**, all successful.

## Behavior verified

New tests cover old-schema read-only behavior and upgrade consent; mapping and duplicate-account protection; exact integer amounts; durable source and batch identities; repeated/reordered batches; pending replacement and ambiguity; explicit corrections/removals; stale/concurrent writes; failed and uncertain commits; both sides of transfers/card payments; preserved user metadata and populated legacy collections; CSV receipts and schedule relationships; reconciliation conflicts; encrypted backup/restore and optional-password changes; and validation of corrupted identities and checkpoints.

The native bank test saves through the actual mapping and review dialogs using Windows OS-protected keys and SQLite. It interrupts and retries a paged refresh, replaces pending records, pairs savings and card-payment sources, blocks a reconciled correction, repeats the same feed without changes and exports an independent encrypted backup. A second app process verifies schema 8, password-free mode, checkpoint 3, 17 sources and exactly five recorded transactions. Exact balances are 2,155.68 checking, 1,200.00 savings and -50.00 card; spending is 94.32. The protected bookshop entry retains its original 12.00 amount and user note. Backup restoration preserves bank collections, transactions, accounts and reconciliation evidence.

Retained native tests cover keys/security modes, schedules, calendar/forecasts, CSV imports, matching, reconciliation, reports/export, categorization rules, register/protected details, category undo, import profiles, CSV suggestions, date controls and quick entry. Hosted .NET backend/accounting contracts, Go race tests and Windows updater tests/cross-compilation, Flutter analysis, Windows/web builds, layout checks/negative controls and package verification all passed.

## Local and source verification

Flutter 3.47.8 was downloaded from the official SDK archive and its SHA-256 matched the official Windows manifest before execution. Strict analysis, all 306 tests and the release web build passed locally. Layout/native-target negative controls, package-verifier negative controls, whitespace checks and all 38 README local links/anchors passed. Native app execution and Defender scanning used the existing ephemeral GitHub Windows runner; the local machine additionally ran the packaged Windows updater in verify-only mode. No antivirus protection on the user's computer was changed.

Source artifact **12906383931** belongs to source run 40896092824 and the verified application commit. Outer SHA-256: a620333c948f4046e2e664d2a1d166bed4cdd1f933f0c3c50a57b7ec69feedb0. Inner source ZIP SHA-256: 33ba3c1c8b10bc34afd5c49fd951c1c9d7392e3777c97f2381a148122c147a39. The source-commit marker and all **193 file blobs** match the published Git commit exactly. The archive contains no Git metadata.

The vault, encryption, OS keys, SQLite storage, existing reconciliation/recurrence engines, backend and updater implementations are unchanged. No dependency was added or changed; pubspec changes only the development version. Schema 8 adds bank records after explicit mapping consent while retaining prior financial collections.

## Exact delivered package

Windows artifact **12907864433**, from the successful build run and application commit above, has outer SHA-256 8528d87f0161922785be2c36b4329389ba98166dc2c2e2bdf9bac488dab9fd11.

The inner **Budgetism-Windows-x64.zip** contains **18 entries**, is **16,450,362 bytes**, and has SHA-256:

d85e515c73e615b7b0be292db549e902d1e26828d763e1280942e217686ac71e

The delivered **Budgetism-Dev18-Windows-x64-Verified.zip** is an unchanged copy of that inner ZIP. Its hash matches checksums.sha256 and the Defender report. Independent verification confirms identity TechSavage1989.Budgetism, version 0.1.0-dev.18, windows-x64, stable Budgetism.exe, required native runtime files, PE architecture, safe archive paths, CRCs and absence of financial databases/private-key files. The packaged updater accepted this exact archive in Windows verify-only mode with exit code 0; no installation was attempted.

## Defender evidence

Security artifact **12909136485** has outer SHA-256 a9bfaf8151ec6d4b401495d30a99360a1af1ae28dd2fd335814ab0763ea52284. At **2026-10-29T15:18:28.7096917Z**, Microsoft Defender engine **1.1.26100.4**, signatures **1.463.24.0**, reported **no threats** in both the ZIP and extracted runtime files, exit code 0 for each. Signatures were updated at 2026-10-29T08:13:13.0000000Z. Both downloaded scan logs match the report, and its archive digest matches the delivered ZIP.

Budgetism.exe and Budgetism-Updater.exe have empty embedded PE certificate directories and remain unsigned. This build-time scan is not publisher signing or an independent security audit. Retained build notices include the Cupertino font-family and action-runtime deprecation notices; this is not a warning-free-build claim.

## User check and limits

Follow [WINDOWS_TESTING.md](WINDOWS_TESTING.md). Preserve a pre-upgrade encrypted backup: dev.17 cannot open format 8 after confirmed mapping. Opening dev.18 alone does not upgrade a workspace. Manual interaction on the user's computer remains for the user to confirm.

Only fictional fixtures are enabled. No live provider, credentials, real financial fixture, server setup, release/tag, updater installation, background worker or device synchronization was added. Multiple connections, account relinking, bulk approval and automatic posting remain outside this milestone.
