# Saved CSV import profiles

Dev.14 implements the saved CSV-mapping part of FR-10. Profiles live in the encrypted local workspace and are included in independent encrypted backups. They do not connect to a bank, schedule imports or send files to a server.

## Settings and reuse

A named profile stores separator (comma, semicolon or tab), date format (YYYY-MM-DD, MM/DD/YYYY or DD/MM/YYYY), signed-amount versus separate debit/credit mode, optional sign reversal, mapped headers and optional default income/expense categories. Mapped fields include date, description, amount or debit/credit, optional bank transaction ID and notes. Separate debit/credit mode never reverses signs.

Profiles store header names, not their column positions. Matching trims surrounding whitespace and is case-insensitive. Reordered columns and extra unused columns are supported. Every mapped header must occur exactly once. Missing or ambiguous mapped headers stop profile application, clear the previous preview and require a different profile or explicit manual mapping. There is no positional fallback or guessed optional-column substitution. Duplicate unmapped headers do not affect a profile.

The destination account is deliberately not saved or switched by a profile. Choose it for every import. Source file contents, filenames/paths, selected rows, transaction matching and duplicate approvals are not stored in a profile. The existing import receipts continue to retain their established source identity after an explicit import.

## Workflow

Open Transactions > Import CSV (or User options > Import CSV statement). Choose a CSV or the fictional example, review mapping/default categories, and choose Save as new profile. Name it and confirm the first-save format upgrade after exporting a backup. Saving a profile does not import any rows.

For later files, choose a Saved profile and Apply selected profile. Selecting the name alone does not apply it and disables preview until application or explicit manual mapping. Apply reparses the selected file with the saved separator, resolves unique headers and fills the visible controls. Review those controls and the destination account, then Preview transactions. The existing review checkbox and selected-row import remain mandatory. Header compatibility does not prove the bank kept the same sign or date conventions; review each file.

Update selected profile explicitly replaces the selected active definition with the currently reviewed mapping. Save as new profile does not overwrite a same-name definition. Profile names are unique case-insensitively, including archived profiles. Manage profiles supports rename, archive and restore; archive hides a profile without deleting its configuration, audit, receipts or any financial records. Up to 100 profiles including archived definitions are supported. No automatic deletion or application occurs.

## Persistence and safety

The first profile save, not screen opening, profile selection or CSV preview, upgrades the financial payload to schema 7 after backup/upgrade consent. Schemas 1 through 6 remain readable. All prior collections, rule history, protections and optional-password behavior remain intact; subsequent budget/schedule/import/rule/reconciliation operations must not downgrade or reinitialize profiles. Dev.13 and older cannot read schema 7. Keep the pre-upgrade backup.

Profile edits/archive/restore use expected workspace and profile versions, idempotent operation IDs, atomic encrypted commits and append-only audit. Failed saves retain entered values for retry. Stale writers fail rather than replace another window's changes. Loading and previewing profiles are read-only. Imports still use the existing receipt and transaction mutation; neither a saved profile nor reordered headers bypasses duplicate detection or review.

No storage/encryption/key/backup-envelope change or new dependency. USD decimal-point amounts and existing UTF-8/header/file-size/row limits remain unchanged. There is no new locale guessing, OFX/QFX/QIF, bank connection, cross-device synchronization or automatic import. Actual validation status is recorded in VALIDATION.md.
