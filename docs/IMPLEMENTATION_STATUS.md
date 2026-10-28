# Current implementation state

Dev.8 is user-confirmed functional. Dev.9 adds statement reconciliation; hosted validation and the exact package scan must be inspected before delivery.

| Area | State |
| --- | --- |
| Existing finances | Accounts, budgets, schedules, matching, imports and calendar/forecast retained |
| Statement review | Account, ending date, signed balance and outstanding transaction selection |
| Completion | Requires exact zero and explicit review; never posts an adjustment |
| History | Completed/reopened statements with selected transaction snapshots |
| Protection | Included entries cannot be edited/voided until applicable statements are reopened |
| Recovery | Latest active statement per account can be reopened with a reason |
| Migration | First completion explicitly upgrades to financial schema 5; all previous collections preserved |
| Security | Existing encrypted storage, optional password and independent backups retained |
| Distribution | Development artifacts only; Windows scan required; no release or updater installation |

Read docs/RECONCILIATION.md and docs/VALIDATION.md for exact semantics and performed checks. Cross-device synchronization and production approval remain outside this milestone.
