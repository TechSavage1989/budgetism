# Product references and delivery priorities

The user requested PocketSmith and MoneyWiz as functional references, alongside
custom themes and review QoL. This is a capability roadmap for Budgetism, with
its own interface and financial contracts. It does not connect to those services,
copy their private data/assets or imply feature parity. The supplied PocketSmith
app URL presents sign-in; research used public official documentation instead.

## Reference workflows

PocketSmith's [transaction search](https://learn.pocketsmith.com/transactions/6a6X8SseDBKmmGjRfHeFaS/transaction-search-an-overview/6tsq7StBSiGUxYFD3bc7yn)
combines dates, account/category scope, merchant text and transaction distinctions.
Its [transaction editing guide](https://pocketsmith.helpkit.so/transactions/6a6X8SseDBKmmGjRfHeFaS/editing-transactions/6a6X8SseDBnVtx2QGWHVme)
uses visible selection, a bulk-action toolbar and explicit application. Its
[calendar/forecast guide](https://learn.pocketsmith.com/article/1246-using-the-calendar-and-forecast-graph)
separates actual history from budget-driven future balances. These inform
filtering, review summaries and the longer-term planning workflow.

MoneyWiz's current [feature overview](https://www.wiz.money/features) groups
accounts/net worth, flexible budgets, bills/forecasting, reports, bank connections
and device continuity around common tasks. The official
[legacy desktop guide](https://assets.wiz.money/MoneyWiz_Guide.pdf) also describes
selection/filter/bulk-edit workflows with type restrictions. That legacy guide is
a historical workflow reference, not a claim about current Windows availability.

## Budgetism mapping

| Capability | Existing position | Delivery direction |
| --- | --- | --- |
| Appearance | Device light/dark mode | Dev.22: six presets, custom accent, system/light/dark, contrast, compact spacing, preview/apply/cancel |
| Transaction search | Rich local register filters | Retain local filters; dev.22 adds combinable session-only filters to server source review |
| Bulk review | Explicit single-source decisions | Dev.22: select visible eligible sources, atomic Ignore/Keep/Reopen with a reason; no bulk financial posting |
| Budgets and reports | Implemented locally and on the private server | Verified dev.24: server budget progress, category drilldown, monthly comparisons and explicit CSV export |
| Calendar and cash flow | Local/server schedules and read-only forecast | Verified dev.24: server schedules/calendar/cash-flow with explicit recording and distinct actual/planned amounts |
| Accounts/net worth | Recorded balances and transfers | Dev.23 overview; verified dev.24 adds dated account balances and monthly recorded trends; investment complexity remains later |
| Labels/saved searches | Local search is session-only | Verified dev.24: opt-in encrypted server saved activity filters and labels; no financial text in device preferences |
| Cross-device use | Private server records separate from encrypted local workspace | Separate sync/conflict milestone; no silent local upload or merging |
| Live banks | Controlled fictional Sandbox only | Remains outside authorization; no real linkage, paid subscriptions or background refresh |

## Current scope and safeguards

The immediate priority is themes plus clearer server review filters and batch
controls, as selected by the user. Source filters never change balances. Selection
clears when filters or loaded state change, and applies only to explicitly loaded
rows. Batch decisions require a reason and summary, reject changed versions and
commit once under the owner lock. Ignore never unlinks a recorded entry; Keep
does not edit it. Financial recording/matching/transfer pairing remains individual
review, not inferred from selection or appearance. No auto-categorization,
silent posting, deletion, paid integration or source checkpoint advancement is
introduced by these controls. Existing local financial schema/security and
reconciliation protections remain in force.

References reviewed October 29, 2026. This mapping describes Budgetism design
decisions, not endorsement or an assertion that the products share an architecture.

The authorized planning suite was privately delivered after the complete native,
package, scan and recovery gates; see [dev.24 evidence](DEV24_VALIDATION.md).
This completes these roadmap items, not PocketSmith/MoneyWiz feature parity.
Local imports, profiles, rules/history, splits/edits/voids and statement
reconciliation retain their existing local contracts. Porting those mutations
to server journals, investment valuation, multi-currency, real bank linkage and
local/server synchronization are distinct future work.
