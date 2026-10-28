# Statement reconciliation

Dev.9 adds Accounts > Reconcile statements, also available in User options. This is a local statement check, not a bank connection or automated accounting adjustment.

Choose an account, ending date and signed closing balance. The first statement starts at the account opening balance; later statements start at the last active statement closing balance. Select the outstanding recorded transactions that actually cleared by that date. Older outstanding items remain eligible for later statements. Future-dated, voided and already reconciled entries cannot be selected. Each account reconciles its own transfer posting. Card/loan money owed uses negative balances.

Review is read-only and selections are not persisted as a draft. Nothing changes until Finish reconciliation. Difference must be exactly zero, with explicit review confirmation. An empty statement is allowed when the closing balance equals the starting balance. No balancing transaction is generated. Amounts use integer cents and checked exact aggregation. This preview allows at most 2,000 selected transactions per statement.

Financial schema 5 adds statement history only after explicit backup/upgrade consent on first completion. Existing schemas 1 through 4 remain readable and unchanged on open. Budgets, schedules, occurrences and import receipts are preserved; importing after reconciliation must not downgrade the schema or clear receipts. Encryption, SQLite container, OS keys, optional password and backup formats are unchanged. Older application builds cannot open schema 5.

A completed statement stores the account, ending date, starting/closing balance, immutable selected transaction effects and date snapshots, prior statement identity, creation operation and optional note. Completion, validation, revision and audit changes are one encrypted atomic commit. A stale review or failed write cannot partially mark entries. Exact operation replay cannot create a second statement.

Included transactions are protected against edit/void, including transfers reconciled on either side. The account opening balance and type cannot change while active statements exist; names can change. Metadata-only schedule matching and CSV receipt matching remain allowed because they do not change actual postings. Reopening the latest active statement for an account requires a reason and confirmation, preserves its history, and never deletes transactions or moves money. Reopen newer statements first. Transfers remain protected until all relevant account statements are reopened.

Statement locks describe included records, not an absolute date freeze: a late imported or manually entered older transaction remains outstanding until reviewed in a later statement. Reopening is auditable but not an independent anti-tamper guarantee. Restoring a whole-workspace backup follows the existing explicit replacement procedure.

Not included: standalone cleared flags, persisted drafts, automatic adjustments, statement-file parsing, bank feeds, batch reconciliation or cross-device synchronization.
