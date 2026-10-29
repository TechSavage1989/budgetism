# Current implementation state

Dev.13 category history/undo and all earlier milestones are user-confirmed. Dev.14 adds saved CSV import profiles. Hosted validation and exact-package scanning are required before Windows delivery.

| Area | State |
| --- | --- |
| Existing finances | All prior accounts, transactions, budgets, schedules, rules, history, reports, statements and register retained |
| Import profiles | Named separator/date/amount/header settings and optional default categories |
| Reuse | Explicit apply to selected file, header-name resolution, reordered/extra columns supported |
| Safety | Missing or ambiguous mapped headers block application; destination account never switched |
| Management | Save new, update selected, rename, archive and restore with version/revision protection |
| Privacy | Encrypted definitions and audit, no statement rows/paths/duplicate decisions saved in profiles |
| Migration | Schema 7 only on first explicit profile save after backup/consent |
| Import review | Existing preview, duplicate review and confirmed transaction mutation remain unchanged |
| Validation | New unit/storage/widget/native tests authored; hosted gate pending |
| Distribution | Development artifacts only, unsigned, no server setup, tags/releases or automatic installation |

USD decimal-point UTF-8 CSV limits remain. No automatic import, locale guessing, bank feeds, cross-device synchronization or new external service. See IMPORT_PROFILES.md and VALIDATION.md.
