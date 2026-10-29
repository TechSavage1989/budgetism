# CSV statement importing

## Scope

Dev.7 adds local-only CSV import with explicit preview and confirmation. It does not connect a bank, upload files, execute cell formulas, reconcile a statement, or automatically settle a scheduled occurrence. USD, UTF-8 files with headers, comma/semicolon/tab separators, up to 2 MiB, 40 columns and 1000 records. Select up to 500 valid rows in one atomic save.

Use Transactions > Import CSV or User options > Import CSV statement. Choose the existing account, map date/description and either signed amount or separate debit/credit columns. Choose the date convention explicitly: YYYY-MM-DD, MM/DD/YYYY or DD/MM/YYYY. Amounts use a decimal point, at most two decimal places and optional correctly grouped commas. A visible switch reverses signed amounts for exports that use positive amounts for money out. Separate debit and credit values must be nonnegative and cannot both be nonzero. An optional unique bank ID must actually be unique per account; ordinary check numbers are unsuitable.

Dates and monetary signs are never guessed on import. Suggested column names still require a preview. Invalid rows remain visible with an error and cannot be saved. Fix the CSV externally and reopen it, or knowingly leave those rows excluded. Quoted delimiters, escaped quotes and embedded line breaks are handled as text. No new parser dependency was added; the bounded parser is covered by positive and malformed-input tests.

## Review and duplicate decisions

Rows can be skipped, imported with a category, recorded as a transfer with an explicit second account, or matched to an existing transaction with the same date and signed account effect. Default categories are visible before preview and editable per row. Possible duplicates and descriptions suggesting transfers/payments default to Skip. This is a prompt for review, not a reliable merchant-classification system.

A CSV row already handled under the same account, exact content digest and logical record number is blocked. A mapped unique bank ID is also blocked for that account across different files. These protections survive financial edits, voiding, encrypted backup/restore and application restarts. Renaming a file does not change its identity. A modified file without a unique ID is not provably the same transaction: date/amount candidates and previous import history require review. Separate legitimate identical transactions are allowed only after an explicit duplicate acknowledgement; they are not silently collapsed.

Matching an existing entry saves a receipt but does not create, change or clear that entry. A statement from the other side of a transfer can match the existing paired transfer instead of posting again. One selected existing transaction cannot satisfy two rows in the same account batch. Different bank accounts have separate source identities.

An unrecorded schedule remains a plan. After importing a payment, use Scheduled > Upcoming > Match existing to explicitly settle its occurrence using the imported transaction without reposting. Alternatively, record the occurrence through Scheduled first, then match that actual during CSV review. Never import and separately record the same payment. See [schedule matching](MATCHING.md). Automatic matching, pending-to-posted merging and OFX/QFX/QIF remain later work. Manual statement reconciliation is available separately; see [reconciliation](RECONCILIATION.md).

## Saved settings and category suggestions

Dev.14 [import profiles](IMPORT_PROFILES.md) save mapping settings without importing rows or changing the destination account. Dev.15 [category suggestions](CSV_RULE_SUGGESTIONS.md) explicitly reviews existing rules against eligible new rows. Suggestions leave manual categories, transfers, matches, skipped/handled rows and duplicate approvals alone. Accepting suggestions changes only the unsaved preview and clears the final review confirmation. Only the ordinary final import saves transactions.

## Atomic save and migration

Financial schema 4 adds validated import receipts. Opening the file or previewing does not migrate or write financial data. The first committed import explicitly requires backup/upgrade consent. It preserves existing accounts, transactions, budgets, schedules, occurrence links and security mode. Older builds cannot read schema 4. Keep the pre-upgrade encrypted backup. New workspaces start at schema 3. A later feature may upgrade them before importing; an import preserves any higher schema instead of downgrading it.

Selected rows, receipts, operation replay hash and audit event are committed together by the existing encrypted SQLite adapter. A failed validation or write commits none of them. Revision checking rejects a preview made before another financial/security change. Retry the unchanged request after a transient failure, or reopen/review against the latest workspace after a stale-state error. No import undo/delete-history action exists; use normal transaction edit/void for corrections. Voiding does not erase import identities.

Receipts record filename (not path), digest, source row number, optional bank ID, original date/amount/payee, account and linked transaction. They are inside the encrypted payload and portable backup. Raw file contents are held in memory for review, not stored in an unencrypted staging folder. A device with unlocked app memory can still access that data. No production-security approval is implied.

## Reference behavior

The CSV parser implements the quoting conventions described in RFC 4180, with explicit semicolon/tab alternatives and strict bounded parsing. UTF-8 decoding rejects malformed bytes rather than replacing descriptions silently. Native file selection uses the existing file_selector dependency. No change to encryption, OS keys, database path, updater installation, server authentication or cloud behavior is included.
