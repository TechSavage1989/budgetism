# Local transaction register

Dev.12 improves the saved local Transactions screen. It is a read-only derived view of existing recorded entries, not a new financial collection. It does not add cross-device sync or browser-local storage. Demo/server screens remain unchanged.

## Search and filters

Search is case-insensitive across payee, notes, account names (both transfer sides) and actual category names, including splits. Multiple words use AND; each term can match a different field. Quoted phrases must match within a field. Prefix a term or quoted phrase with a minus sign to exclude it. Regular expressions and OR/group syntax are not supported. Invalid quotes, empty phrases, over 32 terms or over 500 characters show an error rather than silently broadening search.

Filters combine with AND: account, category, transaction type, record/reconciliation status, statement link, From/Through dates, and minimum/maximum amount. Dates and amounts are inclusive and may be left blank. Amounts are nonnegative full transaction values, not signed account movement or a split share. Exact cents and conventional comma grouping are accepted; fractional cents, exponent notation, negatives and malformed grouping are rejected.

A transfer matches either its source or destination account. A category filter matches the actual split lines, aggregating repeated uses of the same category; it never uses an inactive placeholder category on a split. Transfers have no category. Active records are the default. All or Voided only can expose retained voided history, but voided entries never affect summaries and cannot be edited.

With an account selected, reconciliation and statement-link filters refer to that side. Without an account filter, they match either account. Reopened statements no longer count as active reconciliation. A statement-linked entry has a CSV receipt, which includes entries created from imports and existing manual entries matched to a CSV row. Absence of a receipt is not proof of manual creation.

## Amounts, sorting and totals

Sort by newest/oldest date, largest/smallest whole amount, or payee A-Z. Ties use date then stable transaction ID so pagination does not reshuffle records. All matching rows are counted and summarized even when only the first 100 are displayed. Show 100 more expands the list without changing filters or records.

Matched income and expenses sum whole amounts unless a category is selected, in which case only that category's contribution is summed. Row amounts remain the full transaction, with the selected split contribution separately labeled. Transfers/card payments are a separate whole-amount total, not income, spending or a net account movement. All-account transfer totals count each record once, not once per posting. Voided rows are excluded from every monetary total.

The register may include future-dated recorded entries within the filter range. It never creates or displays unresolved scheduled plans as transactions. Opening balances and budget allocations are not transaction income. Historical Reports retain their own time basis. Aggregates beyond the supported exact amount range fail before rendering and can be recovered by narrowing filters.

## Details and edit protection

Selecting a result opens Transaction details without writing anything. Show its whole amount, date, source/destination accounts, category contributions, notes, CSV receipt references, linked schedule and active reconciliation statements. Record IDs, versions and timestamps are in a secondary information section.

Edit transaction is offered only for active, globally unprotected entries. A transfer can appear Unreconciled for the selected account but remain protected by the other account's active statement. This is explained in details. The record/protection state is checked again before handoff to the existing editor, whose revision/storage checks still apply. The register never directly changes or voids a transaction. Refresh the workspace to obtain changes made by another app window.

## Preservation and limits

There is no financial-format migration or new dependency. Ledger, budgets, rules, receipts, schedules, statement locks, encryption, OS-key store, optional password and backups are unchanged. Search/filter state is only in the open workspace session, retained across navigation but not an application restart. It is not written to preferences/logs or transmitted over the network. Refresh/reset/filter/sort/details are read-only.

Saved searches, tags, pending/cleared bank status, cross-entity global search, bulk editing and register-specific export are not part of this milestone. Existing report CSV export and transaction editing remain available. See VALIDATION.md for actual test/build status.
