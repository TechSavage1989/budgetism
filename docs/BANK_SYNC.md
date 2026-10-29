# Fictional bank synchronization and Needs Review

Dev.18 implements a provider-independent source pipeline with one local fictional adapter. No bank credentials, external API, enrollment, account subscription, server or timer is present. Bank retrieval and future cross-device synchronization remain separate systems.

## Start and map accounts

Open Connections from navigation, Home or Settings. Set up fictional connection presents three invented USD accounts: checking, savings and a credit card. Map each to a different existing fictional account of the same type/currency, or create a new account. Account names cannot duplicate existing names. Reconnect the existing simulation rather than creating another copy.

New account opening balances describe the baseline before the October 1, 2026 history window: checking 2,500.00, savings 1,000.00 and card -100.00. Mapping existing accounts preserves their opening balances and all transactions. The source baseline is informational for existing accounts; it never adjusts their ledger. Do not map invented data to real accounts. Mapping requires explicit fictional-account/baseline review and, on old schemas, backup/format-upgrade consent. It creates no transactions and retrieves nothing automatically.

Financial schema 8 adds encrypted bankConnections, bankAccounts, bankSources and bankBatches. Schemas 1–7 remain readable; opening a screen or preview never migrates them. The first confirmed mapping preserves every earlier collection and fills only missing empty collections. Older application builds cannot read format 8. Keep the pre-upgrade independent encrypted backup. SQLite container, encryption envelopes, key storage, optional password and portable backup format are unchanged.

## Refresh contract

BankProvider returns pages of provider-neutral source records and optional reported balances. Each record has connection/account/source identity, increasing source revision, signed integer cents, currency, calendar date, description, pending/posted/removed status and optional predecessor/transfer identities. Only the fictional provider ID may enroll in this build. Unsupported currencies, unknown accounts, records before the reviewed history window, invalid dates, conflicting revisions and oversized batches fail closed.

BankRefreshService permits one refresh at a time per local API. It holds pages in memory until the final page, checks consistent batch/checkpoint/timestamp metadata, rejects token cycles, and bounds pages/records. The ledger atomically commits the complete source batch, reported balances, encrypted audit and checkpoint. No partial page advances the cursor. A failed retrieval retains records and last-success timestamp; a sanitized connection error appears in Needs Review. If the storage write itself fails, the UI still reports it. An uncertain write is re-read without rolling back a possibly committed checkpoint. SQLite revision checks reject stale concurrent saves.

Stable batch identities plus canonical content digests make repeated/reordered retrieval a no-op. A reused batch or record revision with different content is rejected. Older record revisions cannot undo newer values. Source identity is scoped to connection and source account, never date/amount alone. Two legitimate identical purchases with different IDs remain separate. Durable links survive ordinary edits, voids, restarts and portable backups. A record missing from a partial or later response is never inferred to be deleted: removal requires an explicit tombstone. Source records and audit are retained.

Pending authorizations remain outside the ledger. An explicit pending predecessor ID marks the authorization replaced when its posted successor arrives, even when pages arrive out of order. The same source ID may also transition pending to posted. Without a reliable identity link, matching descriptions/dates produce an ambiguity for review, not an inferred deletion or merge. A posted source can be recorded only once; replaced authorizations cannot post separately.

## One review inbox

Needs Review derives one current list from persisted source decisions, relationships and connection status. Reasons include category needed, possible existing entry, uncertain pending replacement, transfer/card payment, scheduled match, correction/removal, voided record and reconciliation conflict. Home shows its count. Reading the list does not save data or apply rules.

Every source action rechecks the workspace/source revision and an explicit confirmation. An unchanged failed-save retry retains its operation ID; changed content under an existing ID fails. Available actions:

- Record a posted source with a selected category and optional user notes. Pending entries never record. Potential duplicates and ambiguous authorizations require their own review acknowledgement.
- Link an exact-date, exact-account-effect existing entry without changing its money, category, notes or identity. This works for manual or CSV-imported entries and the opposite side of an existing transfer. A transaction side cannot satisfy two distinct source IDs.
- Record one transfer or card payment using the opposite source side or an explicit other account. Both source sides then link to one balanced transfer. Neither side becomes spending or income. Opposite amount/date or transfer-key suggestions always require review. A transfer hint cannot become an ordinary income/expense without explicit acknowledgement.
- Apply a source correction to an unprotected linked entry. Only amount/date change; payee, categories, notes, splits, original identity and occurrence links survive. Changing an amount on a split transaction requires manually reviewing/reallocating splits first. Paired source sides must agree on transfer amount and direction before a paired correction.
- Void an explicitly removed linked entry, retaining its identity and relationships. Every linked transfer side must report removal before voiding the shared transaction. A separate posted refund is a separate reviewed actual, not an inferred reversal.
- Keep a linked entry unchanged or ignore an unlinked source revision with a reason. A later source revision can require review again. These decisions never delete source history.
- Match a recorded payment to a specific unresolved schedule occurrence. Exact-amount suggestions use a seven-day window and the existing schedule matching rules. Confirmation adds reciprocal links without reposting; schedules never auto-post. Dismiss schedule suggestions explicitly when inappropriate.

Reconciliation locks apply on every account side. A correction/removal affecting a reconciled entry becomes a conflict. Reopen all relevant statements through the existing Reconcile tool before changing it, or explicitly keep the recorded entry. A source refresh cannot rewrite a statement snapshot. Ordinary transaction editing remains protected and cannot orphan its source account link.

## Balances and connection state

Connections distinguishes recorded balances (all recorded dates), bank-reported balances and available balances with source timestamps. Available values already include pending activity in this simulator and are not added to pending amounts again. Card available balance is deliberately absent, displayed as Not supplied. Home retains its through-today scope. Since posted sources await review, recorded and reported balances may differ; no hidden balancing adjustment is made.

Refresh progress is session state. Last attempt, last successful refresh, data timestamp and sanitized errors are encrypted connection metadata. Disconnect stops retrieval and preserves account links, sources, checkpoints and all recorded history. Reconnect resumes that same identity. There is no background or automatic refresh.

## Fictional scenarios

Refresh 1 stages a 25.00 cafe authorization, 100.00 fuel authorization, bookshop purchase, cancellable order, rent, both savings-transfer/card-payment sides, card purchase, ambiguous market authorization/posting and two identical small purchases. Refresh 2 posts cafe at 28.00 and fuel at 54.32 using explicit predecessor IDs, corrects the bookshop description, removes the order and adds a card refund. Refresh 3 corrects the bookshop amount to 13.50 and removes the unresolved market authorization. Later refreshes are unchanged. Test refresh recovery offers Repeat last feed and Interrupt next refresh; neither generates extra transactions.

This milestone deliberately requires explicit review before posted sources affect the ledger. Live providers, automatic trusted categorization, background retrieval, arbitrary history-window selection, account relinking, multiple connections, bulk approval, online authentication and device synchronization are not enabled. The adapter and source/ledger boundary allow those to be developed separately.
