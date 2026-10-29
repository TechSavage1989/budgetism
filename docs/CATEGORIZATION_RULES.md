# Reviewed local categorization rules

Dev.11 adds reusable rules under **User options > Manage categories > Categorization rules**. This implements a bounded portion of FR-04: saved conditions, ordering, enable/disable, preview and explicit historical application. No rule runs automatically on import, startup, refresh, synchronization or a timer.

## Definition and precedence

A rule has a unique name and priority from 1 to 9999, enabled flag, Income or Expense type, and required payee text. Text matching is case-insensitive Contains, Exact match or Starts with; it does not execute regular expressions or inspect notes. Optional conditions restrict account, existing category and inclusive positive USD amount limits. Amounts remain exact integer cents.

Source can be all recorded entries, statement-linked entries, or entries without a statement link. Statement-linked means an import receipt exists, including manual transactions explicitly matched to a CSV row. It does not necessarily mean a bank created the transaction or that it has been reconciled.

Lower priority numbers run first. The first enabled rule whose conditions match wins, even when it proposes the existing category. Later rules do not override that no-op. Rules evaluate the original transaction, not the results of another rule. Priorities and names remain unique even when disabled. Up to 100 rules; disable or edit an existing rule rather than deleting history.

## Review and apply

Choose inclusive From/Through dates, then Generate preview. The preview reads only the current snapshot and shows each account, payee, amount, date, original category, proposed category and winning rule. Nothing is selected by default. Rows appear in stable date/identifier order, 100 at a time with Show 100 more. Select up to 500 rows and confirm their category and budget/report effects before Apply selected.

Changing a date resets the preview, selection and review. Changing or saving a rule clears previous suggestions. Stale workspace, transaction or rule revisions are refused; refresh and review again. A failed save retains entered selections and an unchanged retry uses the same operation identity. Inputs and closing controls are disabled during a save.

Reconciled, split (including an explicit one-line split), voided and transfer transactions are always excluded. A forged selected entry cannot bypass these rules. Manual correction of a reconciled transaction still requires explicit statement reopening. Dev.13 History can undo a complete applied category batch when every affected transaction is still unchanged and unreconciled. It requires review and a reason, preserves the original audit and does not remove the rule. See [history and undo](CATEGORY_HISTORY.md). Ordinary non-reconciled transaction editing also remains available for corrections.

## Suggestions before CSV import

Dev.15 also offers Review category suggestions for unsaved new CSV rows. It uses the same first-match rules after an explicit request, protects manual choices, and changes only selected preview categories. The final CSV import remains a separate confirmation. Existing transactions and category-undo history are untouched. See [CSV rule suggestions](CSV_RULE_SUGGESTIONS.md).

## Financial invariants

Application is one atomic ledger mutation. It changes category, category postings and transaction version, retains before/after audit, and preserves every account posting, monetary amount, date, payee, note, identifier, import receipt and reciprocal schedule link. The number of transactions and every account balance remain unchanged. Budgets and category reports recalculate from the new category, including dependent rollover. No money is transferred or spent again.

Selected rows are re-derived from the saved rules on commit. Duplicates, stale versions, invalid categories, changed conditions, protected entries and out-of-range selections reject the whole batch. Identical operation replay does not apply a second time. Applying the same rule to an already-correct transaction produces no change; another rule may match in a later, separately requested preview after a category condition has changed.

## Migration, privacy and preservation

For financial schemas 1 through 5, the first rule save, not opening or previewing, upgrades to schema 6 after explicit backup/upgrade consent. Higher schemas are retained unchanged. All schema 1 through 5 collections are retained. Existing budgets, imports, matching, reconciliation and subsequent operations continue without downgrading or reinitializing rules. Older apps cannot open the upgraded payload. Keep an encrypted pre-upgrade backup.

Rules contain potentially sensitive payee text and are stored inside the existing encrypted payload, not unencrypted preferences. OS keys, optional password, storage path, SQLite container and independently encrypted backups remain unchanged. Backups include rules. No network, bank connection or server setup is used. All automated fixtures are fictional.

## Limits and future scope

Category action only; no payee rewriting, tags, split templates, hierarchical categories, general financial undo, auto-application during import, or synchronization. Desktop Windows is the validated distribution target. Actual validation status is recorded separately in VALIDATION.md.
