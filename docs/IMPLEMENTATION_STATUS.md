# Current implementation state

Budgetism 0.1.0-dev.3 development preview. No application release or tag.

| Area | Status |
| --- | --- |
| User-confirmed baseline | Dev.2 launches on Windows and retains local data through restart |
| Local security | Optional password or OS-protected device key; new setup defaults to no password |
| Existing records | Format-1 password workspaces retained; explicit conversion preserves accounts and transactions |
| Local storage | Encrypted snapshot in native SQLite; atomic writes and revision checking |
| Transactions | Exact cents, balanced postings, create/edit/void, splits and retained audit |
| Accounts/categories | Create/edit accounts; add/rename categories |
| Backups | Independent backup password; verified full-workspace restore preserves destination access mode |
| Interface | Workspace security setting, saved theme, search, sample mode kept separate |
| Native tests | Added real Windows secure-storage write/read process test; see validation for performed status |
| Web | Demo/existing-server interface; no local persistence |
| Sync/budgets/forecasts | Still not implemented |
| Updates | Discovery/download retained; installation remains disabled |
| Production data | Not approved; keep independent backups and test with fictional records |

No server/provider-account/payment setup or release publication is included.
