# Dev.26 report category scopes and comparisons

Client-only candidate following verified dev.25. No financial schema, stored
schedule, server deployment, account setup or new dependency is required.
Local/server reports continue to use their existing detached read snapshots.

## Category scope

Select all categories, a chosen subset or explicitly no categories. Archived
categories remain available for historical reporting. For split transactions,
only selected category contributions enter income, expenses, net income, category
and monthly totals. The full transaction is validated before narrowing, and its
whole amount remains explicitly distinguished from a category contribution.

Account balances, monthly recorded balance curves and transfer counts remain
whole selected-account measures. Filtering a grocery category must never pretend
the bank balance consists only of grocery activity. The UI and CSV disclose this
distinction. Invalid/stale category IDs fail visibly and can be reset.

## Historical comparison

Compare the selected historical dates with a previous equal-day period or the
same dates in the previous year. Actual inclusive dates/day counts are displayed.
February 29 clamps to the prior February's last day, so previous-year day counts
can differ. Underflow before 1900 fails visibly rather than showing stale values.
Both periods use the same loaded snapshot, selected accounts and category scope.

Income, expenses and net income show exact current/comparison values and signed
changes. Bar views compare aggregate period totals, not aligned daily events.
Percent change is display-only and is unavailable for zero/negative comparison
bases; exact deltas remain authoritative. Checked integer-cent arithmetic rejects
unsupported totals/deltas instead of rounding or silently overflowing.

## Controls, export and limits

Apply category changes explicitly; Cancel preserves the prior selection. Reset
restores all accounts/categories, this month and no comparison. Choices are
session-only, not saved or synchronized. Encrypted reusable presets remain a
separate contract-design task; no financial configuration goes into ordinary
device preferences.

CSV export remains explicit and unencrypted. It exports the current period only,
with category-scope and whole-account balance-scope metadata; comparison values
are not silently inserted into the existing exports. The export confirmation
explains this. Existing formula/control-character protections remain.

## Validation status

Hosted checks and exact package validation are pending. No local Flutter runtime
was retried after the existing security block. Local source-layout, package guard
negative controls, diff checks and README structural checks are available; they
are not substitutes for final native checks.

The supplied README/build standard is applied to continuation, not a new app.
Root README now has standard user-first sections/navigation; code/test paths and
root allowlist are unchanged. Prior detailed workflows and development history
remain linked under docs. README HTML generation and structural link/anchor checks
are performed locally; browser visual rendering could not run because the local
Chromium process was denied socket creation by the filesystem/process sandbox.
No sandbox permission was changed. Actual application visuals will be inspected
from hosted fictional native screenshots.

No server setup, Codex CLI automation, unattended worker, payment/API-account
setup, release/tag, access change or live-bank action is included. Dev.25 remains
the delivered package until this candidate is verified.
