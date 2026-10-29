# Dev.19 provider decision

## Selected: Plaid first

Development has started on development/plaid-dev19. The detached PlaidSyncCollector now assembles bounded complete delta pages, restarts from the original saved cursor on pagination mutation, rejects concurrent collection/cyclic cursors and returns a defensive copy of the complete batch. An exact USD decimal converter reverses Plaid's transaction sign without multiplying binary floating-point amounts. Eight fictional tests cover these behaviors. This component is not yet wired into the ledger or UI; it makes no network calls and stores no credentials. Credential configuration, Link authorization, normalization into source revisions, mapping and native delivery remain outstanding.

Deployment choice is resolved: the user authorized a private Budgetism service on an existing Windows Server 2025 accessed through Remote Desktop. This supersedes the earlier no-server-setup constraint referenced below. No shared Plaid developer secret may be bundled with the application. Server preparation begins with scripts/server_readiness.ps1, a read-only inventory. Do not present this initial component as a completed dev.19 integration or verified Windows build.

The user subsequently completed the free Trial signup. A read-only dashboard check confirmed Free trial, 0/10 connections used, and automatic bank access. The dashboard institution entry Bank Five - Personal (ins_109586) points to bankfive.com/Personal, confirming the intended bank identity. Account-specific health metrics were unavailable. No secret was revealed, no connection created, and no API call or bank authorization performed. This verifies trial readiness and institution identity, not an end-to-end Budgetism connection.

On October 29, 2026 the user selected Plaid for the first pilot. The SimpleFIN comparison below is retained as an alternative, not the current recommendation. No live Budgetism adapter or new Windows package is implemented yet.

Plaid's current Trial documentation offers eligible US/Canadian developers free production access for up to ten Items. Existing Production/Limited Production accounts are ineligible. Creation of duplicate Items consumes the limit, and removing an Item does not return its slot. Use fictional Sandbox testing first; prevent duplicate enrollment and use update mode for reconnection. A paid upgrade is one-way and is not authorized.

The Trial application requires the user to accept Plaid's Master Services Agreement and security attestations and may require identity verification. The user must complete that step directly in the Plaid Dashboard. Do not request API secrets or bank credentials in chat or store them in public source.

Source: https://support.plaid.com/hc/en-us/articles/39994173227159-What-is-the-Plaid-Trial-plan

The proposed adapter uses Transactions Sync: collect all added/modified/removed pages before one commit; save the final cursor with the batch. On TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION, discard the partial batch and restart from the original cursor. Handle the initial empty cursor/not-ready response without falsely advancing history. Retain provider pending predecessor IDs and explicit removals; do not infer transfers or erase user metadata. Map provider amount signs and exact decimal cents deliberately. Plaid developer secrets must never be embedded in a distributed desktop executable; the deployment/security boundary remains to be implemented under the existing no-server-setup constraint.

Sources: https://plaid.com/docs/transactions/sync-migration/ and https://plaid.com/docs/quickstart/

The user confirmed dev.18 works and requested continued development for BankFive and common United States banks. Dev.18 remains the working application baseline. Checking and savings are the proposed initial pilot scope; account types have not been explicitly confirmed. No enrollment, payment, credentials or server setup has been authorized.

## Coverage checked October 29, 2026

SimpleFIN Bridge's public institution search returned BankFive. Searches also returned Chase Bank, Bank of America, Wells Fargo and Capital One. These are directory results, not a completed authorization or a guarantee of every account type, history window or refresh reliability.

Source: https://beta-bridge.simplefin.org/search-institutions (submitted public search form with each institution name).

Plaid's public US coverage CSV, generated October 16, 2026, lists Bank Five - Personal (ins_109586) and Bank Five - Business (ins_118483), each with Balance and Transactions support. Do not confuse these with separately listed Bank Five Nine. Exact institution identity and live availability still need validation during the pilot. Plaid says its public coverage table is not updated in real time.

Sources: https://plaid.com/documents/us_institution_coverage.csv and https://plaid.com/docs/institutions/

## Alternative evaluated: SimpleFIN Bridge

The advertised price is $1.50 plus tax monthly or $15 plus tax yearly, covering up to 25 institutions and 25 apps. Its user-issued setup token and read-only access fit a personal desktop pilot without adding a hosted Budgetism service. This is an architectural assessment, not a compatibility guarantee. Provider selection remains pending the user's preference.

The developer guide describes daily-oriented retrieval with 24 requests or fewer per day. Initial history and account-specific behavior remain to be measured. The current protocol is labeled 2.0.0-draft; request an explicit version and validate actual response behavior. A missing source row must never be treated as a removal. The published transaction shape does not establish reliable predecessor IDs or deletion events, so unresolved pending replacements and removals must remain reviewable rather than fabricated.

Sources: https://beta-bridge.simplefin.org/ ; https://beta-bridge.simplefin.org/info/developers ; https://www.simplefin.org/protocol.html

SimpleFIN uses MX for institution access. Its security policy discloses a May 28, 2026 MX incident in which up to 39 users may have seen one another's balances, names and transaction data during a four-hour period. It states bank credentials were not exposed. This disclosure is relevant to choosing the provider and must not be omitted from onboarding information.

Source: https://beta-bridge.simplefin.org/info/security

## Implementation boundary after selection

1. Implement and test a detached response normalizer with fictional provider-shaped fixtures: exact decimal-to-integer cents, stable account/source identity, account-scoped errors, unsupported currency handling, pending ambiguity and changed records. Do not manufacture provider cursors, revision numbers, transfer relationships or deletion guarantees.
2. Define a durable adapter checkpoint for observed content and overlapping retrieval windows. Preserve the existing atomic source/receipt/checkpoint boundary and explicit review of ledger changes. Keep fictional and real connection identities separate; never convert the fictional connection into a live one.
3. Implement a narrowly bounded HTTPS transport with certificate validation, rejected redirects, request/response limits, sanitized failures and explicit rate limits. Validate token claim/access origins; never log token-bearing URLs or provider payloads.
4. Store access secrets separately using OS-protected storage, excluded from financial backups. Design failure recovery for one-use token exchange and failed secret/metadata commits. Disconnect stops retrieval; provider revocation is a distinct action. Restore must require reauthorization rather than restoring access secrets.
5. Add reviewed account discovery, account-type selection, opening-balance/history handling, existing-account mapping and first-refresh preview. Check duplicate manual/CSV entries before recording. Keep all reconciliation locks and user metadata.
6. Run the full retained CI and new unit/widget/native Windows tests, package verification and exact archive/extracted Defender scans before delivering a dev.19 candidate. Account enrollment and any subscription remain separate user actions after the implementation is concrete and reviewable.

No new application version or Windows package is claimed by this research note. The verified dev.18 package remains current.
