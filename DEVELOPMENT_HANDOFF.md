# Budgetism development handoff

**Development version:** 0.1.0-dev.12, read-only transaction register improvements.
**Application commit:** 605ffe4334f20a94197f923fff12562e9de8737d, tree 507235f9a15065c51b0251cbd0083ef90ecf4263.
**Build:** [run 40772902439](https://github.com/TechSavage1989/budgetism/actions/runs/40772902439). Web analysis, all 179 unit/widget tests and web compilation passed; Windows unit/widget tests passed. Native tests, final packaging and scanning are still pending.
**User-confirmed baseline:** dev.11 categorization rules worked. All earlier features were also confirmed; do not repeat their setup exercises.
**Starting application:** 6296272ca9d6635379928fd783f17be57e5d4a83 on development/rules-dev11, tree 07731ab027b035b331f39f23117700e57018d479. Successful run 40746717030.
**Starting main:** 17a5a04b3e8ca1688afce38f4d60859d9ac8c522, still dev.10. Start from the newer dev.11 branch, not main. The prior interrupted delivery did not merge dev.11 to main.

## Read first and scope

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/TRANSACTION_REGISTER.md and docs/LOCAL_STORAGE.md. Inspect live branches/PRs/releases/workflows before edits or publication. Public source and development-workflow artifacts are authorized, not releases/tags, visibility/credential changes, server/provider/payment setup, unattended workers or Codex CLI automation. Never force-push. Every test record is fictional.

## This iteration

The saved local Transactions destination now uses a derived register with combined words/phrases/exclusions, inclusive date/amount limits, account/category/type/source/reconciliation filters and stable sorting. Income/expense summaries use category contributions when scoped, while amount filters/sorts/row values use whole transactions. Transfers are separate; voided rows are inspectable but contribute nothing. Source and reconciliation filters are account-side aware. Details expose actual splits, import receipts, schedule links and active statement protection. Editing remains an explicit handoff to the existing editor and rechecks protection first.

No ledger schema, financial mutations, encryption, OS keys, database, dependencies or backup format changed. Filters remain only in the current workspace session, including navigation; they clear on closing the workspace. No query is saved to unencrypted preferences or sent externally. Dashboard/demo/server flows remain unchanged. No synchronization or updater installation enabled.

## Source map

- apps/client/lib/local/transaction_register.dart: filter/query parser, immutable derived results, exact split summaries, account-side metadata and sort logic.
- apps/client/lib/local/transaction_register_widgets.dart: responsive local register, controls, read-only detail dialog and explicit existing-editor handoff.
- apps/client/lib/main.dart: small integration plus session filter state; original demo/server register retained.
- test/transaction_register_test.dart and transaction_register_widgets_test.dart: engine and UI coverage, including real-shell navigation.
- integration_test/register_native_test.dart: actual Windows SQLite/OS-key preservation and same-process close/reopen; all previous separate-process tests retained.

## Validation and delivery

Flutter remains pinned to 3.47.8. Run all existing/new analysis, unit/widget and native tests, then web/Windows builds, package verification and Defender scans of the exact ZIP and extracted contents. Native register test is same-process close/reopen, not a new two-process test. Existing OS-key/schedule/import/matching/reconciliation/rules pairs still run separately. Build APP_VERSION 0.1.0-dev.12; keep Budgetism.exe and Budgetism-Windows-x64.zip stable.

Local layout/package-verifier negative controls, Go race tests/vet, source-tree verification and documentation checks passed. No local Flutter/Dart/.NET SDK or Windows GUI is available. The application commit above passed web/Windows analysis and unit/widget testing plus web compilation; native tests, Windows packaging and exact-package scanning remain pending. Do not suppress failures or scanners. Documentation-only commits do not change the application commit being tested.

Keep data at %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 and use the same OS account/key store. No keys, databases, binaries or temporary output in tracked source. Root allowlist unchanged. On final publication, preserve the full dev.11 ancestry and recheck main/branches/open PRs before a normal fast-forward. Do not publish tags/releases.

## Next desktop check

Back up dev.11 and open the compiled dev.12 package under the same Windows account. Use Transactions to search an existing fictional payee and combine account/category/date/amount filters. Open a result and inspect details, then reset filters. Counts and balances must remain unchanged. The existing Rule test store expense can be found by quoted phrase and exact 12.34 minimum/maximum; no additional sample entries needed. Verify a reconciled entry shows its statement and offers no edit. No migration prompt, rule change, reimport or repeated budget setup is required.
