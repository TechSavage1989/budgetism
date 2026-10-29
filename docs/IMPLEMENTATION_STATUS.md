# Current implementation state

Dev.14 import profiles and all earlier milestones are user-confirmed. Dev.15 adds explicit category suggestions during CSV review. Hosted validation and exact-package scanning must complete before delivery.

| Area | State |
| --- | --- |
| Existing finances | All dev.14 financial records, saved rules/profiles, statements and history retained |
| Suggestions | Existing enabled rules, first priority match, visible original/proposed category and winning rule |
| Approval | Nothing selected by default; selected suggestions update only unsaved import choices |
| Protection | Manual/reviewed categories, matches, handled/skipped/invalid rows and transfers excluded |
| Duplicate handling | Existing import decisions and approvals unchanged; final import remains mandatory |
| Staleness | Current workspace and complete review fingerprint rechecked before acceptance |
| Privacy | In-memory suggestions only; no query/file transmission or preference storage |
| Persistence | Only final import saves records; no new financial schema or backup format |
| Validation | New unit/storage/widget/native tests authored; exact hosted results pending |
| Distribution | Development artifacts only, unsigned; no server setup, tags/releases or automatic installation |

No automatic categorization/import, retroactive changes, bank feeds, synchronization or new external service. See CSV_RULE_SUGGESTIONS.md and VALIDATION.md.
