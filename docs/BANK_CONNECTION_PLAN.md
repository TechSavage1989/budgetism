# Bank-connected personal finance plan

Status: live-bank roadmap and acceptance criteria. Dev.18 implements the local fictional source pipeline, account mapping and unified review inbox described in [BANK_SYNC.md](BANK_SYNC.md). No live bank/provider enrollment or device synchronization is enabled. Updated October 29, 2026 following the user-confirmed dev.17 baseline and explicit authorization to implement the fictional milestone. The client remains local-only.

## Product outcome

Connect chosen accounts once, see trustworthy balances and upcoming commitments, review exceptions instead of manually processing every routine transaction, and use the same private workspace on desktop, web and mobile. Bank connectivity is a primary product goal, not an indefinite extension of CSV development. Local-only operation and CSV recovery remain available without a bank subscription.

Bank synchronization and device synchronization are separate responsibilities. Bank synchronization retrieves authorized external data. Device synchronization keeps the user's private Budgetism records consistent. Neither capability exists in the current local client. A bank connection must not silently transmit the user's existing workspace or merge fictional test accounts into real ones.

## Connection experience

1. Accounts offers a clear Connect bank action. Explain read-only access, provider identity, costs, data shared, refresh limitations and revocation before enrollment. No money-movement or payment-initiation permissions.
2. Open the provider/bank's supported authorization flow. Budgetism must never ask for or store the bank login password. Provider tokens are sensitive credentials, not financial records, and must never appear in source, logs, exports, screenshots or chat.
3. Select accounts and choose whether each corresponds to an existing Budgetism account or a new one. Review currency, account type and masked identifiers. Do not silently duplicate an existing account.
4. Choose the initial history window. Explain available history and establish a reviewed balance baseline; importing history must not count the same starting balance twice.
5. Preview the initial results and any ambiguous matches. Confirm the first synchronization explicitly. Thereafter, a separately enabled background-sync preference can retrieve routine activity without repeating onboarding. No unattended job is enabled in the present milestone.
6. Show last successful refresh, data timestamp and attention-needed state per connection. Provide Refresh, Reconnect and Disconnect actions. A failed refresh retains existing records and must not display a false success or current balance.

## Financial correctness

Keep provider source records separate from user-entered categories, notes, splits, tags and reconciliation evidence. Provider refreshes must not erase the user's edits. Link source records to ledger transactions with durable provider/connection/account/transaction identities, not date/amount alone.

Use an idempotent, atomic import pipeline. Persist the provider cursor or fetched-window checkpoint only after the complete batch is committed. Retry safely after interruptions, reordered pages or expired cursors. Treat unsupported currencies explicitly rather than silently labeling them USD.

Handle new, changed and removed records according to the chosen provider's contract. A missing row in a partial or failed response is not proof of deletion. Pending charges may change amount/date or disappear; when a pending charge becomes posted, preserve its relationship without counting both as spending. If there is no reliable identity link, flag ambiguity instead of deleting or merging by guesswork.

Show recorded/posted balance, bank-reported balance, available balance and projected balance as distinct values with their dates. Do not add pending activity to an available balance that already incorporates it. Scheduled plans remain separate from actual payments. Matching a scheduled payment must not create it twice. Transfers and card repayments must not become income or expenses on both sides.

A correction affecting reconciled records must become a visible conflict requiring review, not an automatic rewrite. Disconnect stops new retrieval but preserves ledger history; deleting historical records is a separate explicit action. Existing imports and manual entries need a reviewed linking path, not a destructive re-import.

## Intuitive review and automation

Use a single Needs review inbox for unknown payees, ambiguous duplicates, unmatched transfers, category uncertainty, source corrections and connection problems. Explain why each item needs attention. Let users approve a clear batch with a summary, rather than repeating several checkboxes for each ordinary row.

Trusted categorization rules can become opt-in automation only in a separately implemented and tested milestone. Provide a preview, clear scope, preserved manual overrides, source provenance and undo where financially safe. Reversible routine actions should prefer immediate feedback and undo. Reserve explicit confirmation for destructive changes, first connections, workspace upgrades, reconciliation changes and materially ambiguous financial actions.

Home should answer: what is available in the selected accounts, what is due soon, what budget remains, and what needs attention. Do not label a calculated amount Safe to spend unless its account scope, pending activity, scheduled commitments and exclusions are fully defined. Advanced forecasting and reconciliation controls remain accessible without dominating the daily screen.

## Architecture and security boundaries

Preserve Flutter for the shared client and the existing .NET/PostgreSQL self-hosted direction. Put provider-specific authentication and data conversion behind an adapter contract, not inside screens or directly inside ledger calculations. Develop and test with fictional provider fixtures before any real connection.

For the intended cross-device deployment, a self-hosted service should coordinate bank refreshes and device synchronization, with one authoritative sync cursor per connection. Native clients retain encrypted local working data and a durable offline outbox. Browser access remains online-first until explicitly implemented otherwise. A desktop-only prototype must not bake its provider credentials or scheduling assumptions into the permanent architecture.

Protect local tokens with platform secure storage and server credentials with a separately protected server secret mechanism. Financial backups must not accidentally export bank-access secrets. Local password-free access remains configurable; it does not remove server authentication or bank authorization. Make credential rotation, revocation, logout and recovery distinct actions.

Self-hosting Budgetism does not imply a third-party-free bank connection. A selected aggregator may process bank data and may involve another upstream provider. Explain that boundary accurately. Prefer supported bank authorization flows; do not screen-scrape banking portals or weaken certificate validation. Validate token-exchange and callback destinations and reject unsafe redirects or credential-bearing log output.

## Provider selection gate

No provider is selected, no API account or subscription is created, and no real data is requested. First obtain the institution name/country and desired account types, not credentials or account numbers. Verify current coverage, refresh reliability, history limits, user enrollment requirements, pricing, security/privacy disclosures and revocation behavior for that exact institution. A supported-bank listing alone does not establish a working connection.

SimpleFIN Bridge is a candidate for a personal read-only connection. Its developer documentation describes a one-time setup-token exchange, revocable access, daily-oriented refresh limits and institution-dependent history. Its current specification is labeled version 2.0.0-draft, so production response/version behavior must be explicitly verified rather than assumed. Its security policy identifies MX as an upstream service and discloses a May 28, 2026 account-mixing incident; that disclosure belongs in selection review, not a blanket safety claim.

Plaid is another candidate. Its supported Link flow handles account authorization, including institution OAuth where available. The transaction sync contract provides added/modified/removed records and pending-to-posted linkage. Production access, institution availability and pricing must be checked before selection; do not promise that a free test environment can access the user's real bank.

Provider research reviewed October 29, 2026:
- SimpleFIN protocol: https://www.simplefin.org/protocol.html
- Bridge developer guide: https://beta-bridge.simplefin.org/info/developers
- Bridge supported institutions: https://beta-bridge.simplefin.org/search-institutions
- Bridge security disclosure: https://beta-bridge.simplefin.org/info/security
- Plaid Link: https://plaid.com/docs/link/
- Plaid transaction states: https://plaid.com/docs/transactions/transactions-data/
- Plaid Transactions integration/pricing model: https://plaid.com/docs/transactions/

These references support the provider observations above. The proposed Budgetism architecture, UI and delivery order are design decisions, not claims about those providers.

## Delivery sequence and acceptance

1. Complete date-selection QoL and preserve the working baseline.
2. Improve daily navigation, quick-add/payee entry and the dashboard. Define the account-link and Needs review screens alongside those changes so CSV controls do not dictate the final experience.
3. Implement provider-independent source records, account linking and a simulated feed against fictional data. Cover pending/posted replacements, corrections, repeated retrieval, matching existing entries, transfers and interrupted saves before live use.
4. Validate the chosen bank/provider and implement its adapter. Separately approve provider enrollment, any paid plan and the private-server setup needed for the chosen deployment. Begin with an explicitly authorized read-only pilot and independent backup/recovery checks.
5. Add and validate cross-device sync, offline conflicts, secure remote access and mobile distribution. Enable background retrieval only through an explicit preference with accurate status and failure handling.

Usability acceptance: a calendar supplies dates without typing; cancelling never saves; the main daily actions are directly discoverable; routine review does not repeat onboarding; every failure identifies an actionable recovery step; small screens and keyboard navigation remain usable.

Finance acceptance: repeated refresh creates no duplicate; a pending replacement affects spending once; manual edits survive refresh; matched schedules and transfers are not double counted; a failed/partial sync does not consume its checkpoint or delete records; reconciliation locks survive; first-link history preserves an explainable balance; disconnect preserves prior records; no private data or tokens escape into logs or public artifacts.
