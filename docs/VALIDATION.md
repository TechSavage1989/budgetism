# Validation: Budgetism 0.1.0-dev.8

## Starting baseline

User-confirmed dev.7 application 0dec77e3372a7ceb5745e29a54301a6622de414b passed run 40708091217. Current starting main b6057f6fbee794b86d8a8fe1bb23e0ce88318ee8 is its documentation-only follow-up. Source artifact envelope SHA-256 6724f37b910ab187ef1326e7fad42fa4eb4594d57162c6912c6dabc713a8490f, inner SHA-256 97ef40f5f26bf259f5c9c3be5848439087d62a9c8897563a079db4ea5bcb4605, and recomputed complete Git tree d97461e0c2945f39ba2d9f20fa97ef163a9b419b were verified before editing. New changes are applied above current main, not an older branch.

## Local checks

Source-layout guard and deliberate-clutter negative control passed. Native package-verifier negative controls passed. Git diff whitespace checks passed. Run unchanged Go tests and preserved-file comparisons before publishing. No local Flutter/Dart/.NET SDK or Windows GUI exists; no local compilation/test pass is implied.

## New regression coverage

Read-only candidates, preserved financial fields/schema, imported receipts and reimport rejection, variable amounts/dates/splits, income/transfer links, invalid account/type/currency/direction and voided exclusions, date-window endpoints/DST, review requirements, idempotency, repeated-link rejection, all stale revisions, paused/skipped/postponed cases, forecast/calendar deduplication, edit/void link preservation and corrupt relationships. Storage tests cover atomic failed commits, exact retries, real SQLite reopen/stale windows and encrypted backup restore. Widget tests cover explicit review, failed-save retry retention, single-flight behavior, variable amounts, search reset and a 430-pixel viewport. Native Windows matching uses actual secure storage and SQLite across separate write/read processes.

## Delivery gate

All existing/new Flutter tests, retained native tests plus matching process pair, Windows/web compilation, backend contracts, updater/security/root checks, package verification and Defender scan must pass for the exact application commit. Download exact source/application/security artifacts; confirm provenance and hashes and verify contents. No test/analyzer suppression or antivirus bypass. Record actual run and scan results here after completion.

Manual dev.8 GUI interaction, non-Windows native distributions, live backend integration, independent security review and full updater installation remain separate gates. No release/tag, signing or production approval. Dev.7 stays the user-confirmed baseline until new manual confirmation.
