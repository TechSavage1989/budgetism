# Dev.20 fictional server review verification

Application source: `269a277497365914000835952bf041af4bb6d4b6`.
Exact source tree: `7a9c14af0eeae19aa5bb7b8d22428f1bec7b43e7`.
All six jobs in [run 40959797640](https://github.com/TechSavage1989/budgetism/actions/runs/40959797640)
and the [source archive run 40959797658](https://github.com/TechSavage1989/budgetism/actions/runs/40959797658)
passed. Later documentation-only commits retain these tested program files.

## Checks

Local strict Flutter analysis, all 335 unit/widget tests and the release web build
passed. Hosted CI repeated them and retained all 27 native Windows commands.
The extended server test verifies saved-state reads without provider retrieval,
explicit refresh, original-ID retry and isolation from a separate encrypted local
workspace. Both fictional native screenshots in artifact **12935959238** were
inspected for readable labels/amounts and clipping. Earlier preview tests remain.

Backend build completed without warnings. Ledger/Plaid contracts, pinned Sandbox
discovery/cursor-retry tests, layout/package negative controls, updater tests,
Windows cross-build/native checks and 43 README local links/anchors passed.
Local native builds were not used because Visual C++ was unavailable; hosted
native results supply that validation. No release or tag was published.

The isolated PostgreSQL runner verifies additive upgrade against the legacy
seven-table schema containing fictional journal data, unchanged legacy counts/
digests, repeat/future/partial guards, zero-baseline mapping, reviewed posting,
matching, refunds, transfer pairs, duplicate retries, ownership, stale versions,
partial-batch rollback, pending replacement, changed/removed linked sources,
disconnect and concurrency. Independent dump/restore across database restart
matched all 14 table counts/content digests, including history, cursor, operation
receipts and journal links. These contracts contact neither an existing DB nor
Plaid. Fresh-server smoke and permanent-service tests also passed.

## Packages and Defender

Client artifact **12936852510** contains a **16,487,455-byte** inner ZIP, SHA-256:

```text
4fb5ebf3878ea768fb8e25088ab432219f992f0380af8fe110db0048fcfc269b
```

Identity/version/dependencies, checksum, negative controls and CRCs were verified.
Security artifact **12936498716** reports no threats for the exact ZIP and extracted
files, scanned at **2026-10-29T22:05:14.0212952Z**.

Server artifact **12936745070** contains a **102,333,993-byte** inner ZIP, SHA-256:

```text
f51fd6f77d29b0c46d07a5f7c75bd4136bbe50a20b0491a6401f7fd2a38c9c42
```

All **1,932** manifest hashes, safe paths, archive membership and CRCs matched.
Security artifact **12935013574** reports no threats for its exact ZIP and extracted
files, scanned at **2026-10-29T21:45:24.6073714Z**. Both reports used engine
**1.1.26100.4**, signatures **1.463.30.0**, and both scans returned exit code 0.
This is build-time Defender evidence, not publisher signing or an independent audit.

## Private delivery

After a fresh protected backup/isolated restore, the explicit schema upgrade
preserved every legacy table digest and passed a full 14-table independent restore.
Only verified API program files were replaced; the old program remains for
rollback. Owner, disabled enrollment, distinct virtual service identities,
automatic startup, normal TLS validation, required authentication and loopback
listeners passed. Firewall and IIS were unchanged.

Fictional review is enabled privately; no fixture discovery, account mapping,
provider refresh or installed-ledger posting was performed. The separately
extracted client identifies as `0.1.0-dev.20+20` and opened at its welcome screen.
Local URL entry/sign-in and explicit review choices remain the user's actions.
Plaid credentials need no re-entry and never belong in the client. The earlier
dev.19 GUI preview was user-confirmed. The user subsequently confirmed dev.20
discovery/mapping/refresh; one mapped fictional account and four saved sources
passed independent recovery. Manual posting has not been user-confirmed. Desktop
data and prior programs were preserved. Server
corrections/voids, real banks, automatic provider retrieval, LAN/public exposure
and local-workspace synchronization remain unavailable. After recording refunds,
use the dev.20 client; the older preview client's refund display is unsupported.
