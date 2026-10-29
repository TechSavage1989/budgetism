# Budgetism dev.18 Windows check

Use only the development package identified in [VALIDATION.md](VALIDATION.md). Export an encrypted backup from dev.17 and keep its password. Close Budgetism, extract dev.18 into a separate program folder, keep all supporting files together and run Budgetism.exe under the same Windows account. Confirm 0.1.0-dev.18 and open the existing workspace without recreating its database.

1. Open Connections, then Cancel account setup. Existing balances, transactions, optional-password setting and saved tools should remain unchanged.
2. Set up fictional connection using the three new fictional accounts. Review their opening balances and confirm the fictional-account and backup/format-8 choices. This upgrade means dev.17 cannot open this workspace afterward. Existing real accounts must not be selected.
3. Choose Refresh fictional feed. Reported/available balances and source records appear, while recorded transaction counts remain unchanged. Open Needs Review and record the fictional bookshop purchase with a category and note. Pair the checking/card payment using the other reported side; it should create one transfer, not income or spending.
4. In Connections > Test refresh recovery, choose Repeat last feed. Counts must not change. Choose Interrupt next refresh: an error should appear, with prior data/last-success timestamp preserved. Refresh normally to retry.
5. Refresh 2 replaces the 25.00 cafe authorization with 28.00 posted and 100.00 fuel authorization with 54.32 posted. Pending rows remain visible as replaced and do not count in spending. Record only the posted cafe/fuel entries. Their combined spending is 82.32.
6. Refresh 3 changes the bookshop source amount to 13.50. Review the correction: your selected category and note must survive. If you reconciled the original bookshop entry in the fictional account first, it must instead remain a protected conflict until you reopen that statement or keep the recorded entry.
7. Close and reopen Budgetism. Verify the same source records, review decisions and transfers, then optionally export an independently password-protected backup. Disconnect/reconnect the simulation should retain its history.

These fixtures are dated October 2026; later Home month-to-date totals may differ from the October Transactions/Budget view. No real bank login is offered. Use fictional accounts only.