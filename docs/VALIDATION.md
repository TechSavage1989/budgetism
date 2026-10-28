# Validation: Budgetism 0.1.0-dev.13

## Starting baseline

User-confirmed dev.12 application 605ffe4334f20a94197f923fff12562e9de8737d, tree 507235f9a15065c51b0251cbd0083ef90ecf4263, successful run 40772902439. Starting main 11b8edec71d97f111a16a44c02ac46fbf119633b is a documentation-only follow-up. Live comparison verified that app/workflow code is unchanged between them.

The starting source artifact outer SHA-256 is 29f1d769b602096a9d860a9404f40c60a6ea0e024bbc6bd8070e2826dd6719f7; inner source archive SHA-256 is 6bc8ffebc3b573adbf737e40d58173da33e7e4ce5793a45f37471d0cea08b057. Both were recomputed before editing.

## Local checks

Source-layout/deliberate-clutter checks, package-verifier negative controls, diff whitespace and unchanged Go race tests/vet passed. No Flutter/Dart/.NET SDK or Windows GUI is available locally. Authored tests are not evidence of successful compilation or execution.

## Added validation coverage

Prior batch reads without migration; detached previews and original rule version; exact category-only restoration; balanced postings and unchanged amounts/identities/collections; appended audit; duplicate/changed operation rejection; complete-batch stale/version/protection guards; disjoint and overlapping batches; original imports/schedule links; incomplete/duplicated/non-category evidence; legacy reads and exact monetary bounds. Storage tests cover failed-save atomicity, unchanged retry, stale windows, actual SQLite reopen and encrypted backup restore. Widgets cover narrow/wide views, reason/review, error retention, single-flight, stale review, protected/undone states, rules-page refresh and empty/corrupt history. Native undo write/read tests run in separate Windows app processes.

## Required hosted gate

Run the full retained/new Flutter unit/widget suite, every prior native process pair, planning/report/register tests, the new undo pair, Windows/web compilation, backend/updater/source-layout checks and exact-package identity/runtime/Defender scans. Inspect the actual run and downloaded package hashes before delivery. Record performed checks and all remaining limitations. No release/tag or production approval; no scanner or test bypass.
