# Dev.23 private-server dashboard verification

Application source: `aaee33e9b711b3cc80e61811336dfce361c5ebf4`.
Exact tree: `b39aa642b342b0e92c4413d5159c640089559e5e`.
Build run: [41004399767](https://github.com/TechSavage1989/budgetism/actions/runs/41004399767).
Source archive run: [41004399698](https://github.com/TechSavage1989/budgetism/actions/runs/41004399698).
All six build jobs and the separate source archive run passed. Later documentation-only commits preserve the tested application.

## Scope and contracts

The user authorized the dashboard after the themes/review milestone. See
[the dashboard contract](SERVER_DASHBOARD.md) and [reference roadmap](PRODUCT_REFERENCE_PLAN.md).
It reads through-day signed ledger postings and month-to-date recorded income/
contra-expenses, separates cached fictional provider values, and shares complete
source-review rules. Local/demo storage and financial mutation paths are unchanged.

Local strict analysis, all 354 client tests, targeted final dashboard tests and
web release passed. The API built with zero warnings/errors. The packaged API
passed authentication, revoked-session rejection, invalid-date rejection, exact
dashboard totals, disabled-review availability and no-created-entry checks.
No local native build was attempted because Visual C++ was unavailable.

Disposable PostgreSQL contracts passed historical signed openings/debt, transfers/
card payments, refunds, future exclusion, archived accounts, empty/other owners,
full source-review semantics and exact-number limits. Full 14-table content digests
were identical before/after reads; no provider/credential factory was invoked.
The complete isolated dump/restore matched every table across process restart.

The source artifact 12954666999 was independently downloaded: checksums/CRCs and
all 249 file blobs match the application commit. Layout/native-target and package
negative controls passed. No earlier test or native command was removed.

## Server package

Server artifact **12955156769**, scan artifact **12954947413**: inner ZIP SHA-256
`c95840b0d638a26ba6b6c1e5a46c240b008a2661f706e4d6c323a76129cbdbe9`.
All 1,932 manifested hashes, exact membership, safe paths and ZIP CRCs passed
independent verification. The exact ZIP and extracted scans both returned zero/
no threats at 2026-10-30T04:47:08.3688015Z, engine 1.1.26100.4, signatures 1.463.33.0.
This is build-time Defender evidence, not publisher signing or independent audit.


## Native client and exact package

Hosted Windows repeated strict analysis, all **354** tests and **33** native
commands. Every prior native check remains, plus dashboard navigation, failure
clearing, retry, compact/wide layout and zero mutation/provider-operation calls.
UI artifact **12956250150** contains eight fictional screenshots; the two new
dashboard screenshots were inspected for readable values, scope labels and layout.
These fixtures are UI evidence, not a login to or capture of the private server.

Client artifact **12955628165** contains the **16,543,503-byte** inner ZIP:

```text
022c21ede52cc54fd7114d4542fe6af2d6527da155aaaa173d049f957edbd834
```

Identity/version/dependencies, checksums, negative controls and ZIP CRCs passed
independent verification. Security artifact **12955598408** reports no threats
for this exact ZIP and extracted files at **2026-10-30T05:11:02.3020213Z**.
Both scans returned zero, engine **1.1.26100.4**, signatures **1.463.33.0**.
Executables remain unsigned; scan evidence does not establish publisher identity.


## Private delivery

A fresh protected backup restored into an isolated database with all 14 tables
matching. Its temporary database was removed. Only the scanned API program was
upgraded, preserving the previous program path for rollback. Normal trusted HTTPS
health, owner preservation, disabled enrollment, distinct automatic service
identities, expected running executable and dashboard unauthenticated rejection
passed. No schema migration, financial mutation, review action or provider refresh
was performed. The database service/data, existing IIS sites and firewall remain
unchanged, with Budgetism listeners on loopback and LAN access disabled.

The verified `0.1.0-dev.23+23` client was extracted separately. The existing owned
private shortcut was updated only after checking its expected target. The prior
executable hash was unchanged; the current window was left open. No client was
automatically launched or authenticated, and user confirmation of the new Home
remains pending. Private paths, credentials and recovery files stay outside Git.
No release/tag, real-bank link or local-workspace upload was created.

All 49 README local links/anchors passed after the evidence update.
