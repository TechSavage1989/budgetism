# Validation: Budgetism 0.1.0-dev.14

## Starting baseline

User-confirmed dev.13 application 6f6e33c58c297fc55dde40ce74aae9a64f2acc7a, successful run 40781260879. Starting main a5b89e75b9f704b96c5f307f25b7647351a58f87 is its documentation follow-up. The original application source artifact matched outer SHA-256 8329f87c8683fefacf69081d73c29aa0c71e541a756e1747935a6224f090773c and inner 074e1a9757508bbb0c0cb3ef3167f74cf28a0870dddcb5db9069036cee4b2bcd. Local Git reconstruction produced the recorded tree 6106ec95fb78ab89aff027bd0296d4741a7a8692 before changes.

## Local checks

Source-layout and deliberate-clutter checks, package-verifier negative controls, unchanged Go race tests and go vet passed. Source was reviewed for explicit opt-in migration, category type validation, unique header binding, unchanged destination selection, no saved statement rows, atomic versioned mutations and retained CSV duplicate checks. No local Flutter/Dart/.NET SDK or Windows GUI is available.

## Added coverage and hosted gate

New tests cover schema 1-6 migration only with consent; preservation of existing records/rule history and reconciliation; exact mapping/date/sign/amount behavior; reordered/extra/missing/duplicate headers; profile names, versions, archive/restore and limits; malformed/corrupt records; no raw rows in profiles; failed writes, stale writers, encrypted SQLite reopen and independent backup restoration. Interface tests cover explicit selection/application, narrow/wide layout, account preservation, invalid-header recovery, separate profile-save/import consent, archive confirmation and single-flight saves.

Native tests add a separate-process Windows write/read pair for profiles with unchanged optional-password behavior and rejection of a reordered duplicate CSV. Retain every existing test and compile web/Windows. Verify exact application identity/version/runtime dependencies, archive hashes and Defender scan evidence before providing a Windows download. No authored test is claimed passed until its actual result is inspected. No release/tag, updater installation or production approval.
