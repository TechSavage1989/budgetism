# Validation: Budgetism 0.1.0-dev.7

## Starting baseline

Dev.6 application commit 37917d27a40d68cb6fbb83b61b192c9984a2b7ea on development/planning-dev6, Git tree 5abda49bb36a77e4b0e3bf7701b7f205f85df47a, successful run 40699293089. The user confirmed dev.6 works. Main was still the older dev.5 documentation commit and was not used as the code baseline.

The retrieved source artifact 12820253508 from run 40699292893 matched outer SHA-256 5cd2ea7115d61d712cdf42fed919312823c41f1473972167d2a52522af15e69c. Its inner source ZIP matched ea2cd4cfc224503a671f6bbf21e4a2ee3840b57659c88e52a1d4bcc7ab07ee42 and recorded commit. The full extracted Git tree was independently recomputed and matched.

## Local checks

Root-layout guard and deliberate-clutter negative control passed. Portable-package verifier negative controls passed. Compare preserved modules and run Go tests before packaging. Local Flutter/Dart/.NET SDKs and Windows GUI are unavailable. Never present source review as passing Flutter/native tests.

## New validation coverage

CSV quoting/CRLF/BOM/multiline, delimiters, malformed/oversized input, literal formula text, exact cents, rejected ambiguous formats, explicit dates, invalid rows and column mapping. Engine tests cover preview read-only behavior, schema consent, exact actual effects, batch replay, repeated source rows, references, duplicates after voids, legitimate identical rows, matching without reposting, both transfer directions, stale/invalid batch rejection, receipt corruption and subsequent schedules. Storage tests cover failed commits, real SQLite reopening, stale windows and independent encrypted backup restoration. Widget tests exercise the narrow-screen fictional-example flow, review consent, failed saves and retry. Native Windows tests write and reopen the import in two separate application processes and reject duplicate reimport.

## Delivery gate

Run the complete existing/new Flutter suite, all retained native integration tests, the new import restart pair, Windows/web builds, backend and updater checks, package verifier and Defender archive/extracted-content scan. Inspect exact run and artifact hashes before delivery. No disabled tests, suppressed analyzer warnings, antivirus exclusions, release publication or automatic installation.

Manual dev.7 GUI/file-picker interaction on the user's PC, non-Windows native distributions, live server integration and full updater installation remain unverified. A clean Defender scan is not publisher signing or an independent security audit.
