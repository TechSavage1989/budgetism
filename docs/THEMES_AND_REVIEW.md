# Themes and server review controls

Dev.22 follows the user-selected [reference roadmap](PRODUCT_REFERENCE_PLAN.md).
Appearance is available at the welcome screen and in Settings for local, demo and
server sessions. Six presets and a six-digit custom accent generate adaptive
Material colors for Light, Dark or System mode. Higher contrast and compact
spacing are optional. The dialog previews choices; Cancel and Reset preview do
not write settings. Apply persists one versioned, device-only appearance record.
The existing light/dark preference remains readable; invalid/future appearance
records fall back safely. Other preferences, credentials and financial records
are untouched. Generated text contrast is tested for presets and extreme seeds.

Server source review combines text, account, review status, money-in/out, calendar
date range and newest/oldest/largest ordering. Money direction does not classify
income/expenses or transfers. Filters operate on loaded rows, not hidden pages;
loaded/filtered/server totals are stated. Search and filters are session-only.
Reset or any filter change clears selection, as does a saved-state reload.

Batch controls select at most 100 visible eligible rows. Pending and superseded
unlinked rows cannot be batch-ignored. Ignore accepts unlinked posted sources; Keep
accepts linked conflicts and displays their recorded entries. Mixed selections
cannot share a decision. A mandatory reason and explicit summary confirmation
precede the request. Cancel writes nothing. The owner-authenticated batch endpoint
rechecks every source/version and connection under one lock, then saves all
decisions, audit and one operation receipt atomically. Identical retry, including
reordered selection, returns the original result. Changed reuse is rejected.
The cursor, financial change stream, journals and postings do not change.
Reopen decisions returns previously ignored/kept sources to their unresolved
review state with a new reason/audit receipt. It never reverses a financial entry.

This adds a backward-compatible server capability flag and route, not a schema
change. New clients hide batch actions on older APIs. After a protected verified
backup, install only the scanned API program with rollback retained; never rerun
the installer or schema upgrade for this change. Existing clients retain single
review. No live data is batch-reviewed by deployment or tests.

Batch recording, category changes, transfers, corrections and voids remain outside
this batch endpoint. Their existing individual explicit review and ledger rules
still apply. These controls do not enable real-bank enrollment, automatic provider
retrieval, local/server data synchronization or public exposure.
