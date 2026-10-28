# Validation: Budgetism 0.1.0-dev.11

## Starting baseline

User-confirmed dev.10 application 63b5b6cef441ca1889117d6a3b43ec05f5e5aa34, successful run 40737797353. Starting main 17a5a04b3e8ca1688afce38f4d60859d9ac8c522 is its documentation-only follow-up. The source archive matched outer SHA-256 0514844ad3d66100d260a88fd896d368f0fe2c8d040ec5a67a0629765e75e7bc and inner 66f1ce0e50df25520a659dcca8f3422dbb8005e8e51ed000590a85b6e6800bc0. Its recorded commit and independently recomputed Git tree matched 5f2d6f429fdbfc83a373608227de4d609d562c59. Live comparison confirmed that main differs only in five documentation files.

## Local checks

Source-layout and deliberate-clutter checks, package-verifier negative controls, diff whitespace, unchanged Go race tests and go vet passed. New code was reviewed for atomic category-only changes, protected/split exclusions, stale revisions, explicit rule precedence and retained import/schedule links. No local Flutter/Dart/.NET SDK or Windows GUI exists. Authored tests are not passing runtime evidence.

## Added validation coverage

Rule migration only on explicit consent; older schemas and financial preservation; precedence including no-op and disabled rules; payee/source/account/category/amount/date conditions; protected/split/voided/transfer exclusions; exact category budget effects; stale/forged/duplicated batches and replay; corruption rejection; limits; preserved imports and matched schedules. Storage tests cover failed-save atomicity, encrypted SQLite reopening, stale windows and backup restoration. Widget tests cover migration/review consent, retained fields/selection on failure, retry, single-flight, date invalidation and narrow layouts. The native rules test runs write/read in separate Windows processes.

## Required hosted gate

Run the full retained/new Flutter suite, every native process pair, planning/report tests, Windows/web compilation, backend/updater checks, package identity/dependencies and exact ZIP/extracted Defender scans. Inspect and record the exact commit, run and artifact hashes before providing a Windows download. Do not bypass failures. No release/tag or production approval. A clean scan is limited to its scanner/signature/time and is not publisher signing or universal browser reputation.
