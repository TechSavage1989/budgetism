# Dev.22 themes and review verification

Application source: `147d1fb0af09713197786ac2964d6069567e6519`.
Exact tree: `f1fd33ec90b529250359ea99ad43ea29c2ed92c7`.
All six jobs in [run 40998255111](https://github.com/TechSavage1989/budgetism/actions/runs/40998255111)
and [source archive run 40998255147](https://github.com/TechSavage1989/budgetism/actions/runs/40998255147)
passed. Later documentation-only commits preserve the tested application.

## Behavior and checks

The user selected presets/custom accent and clearer review filters/batch controls.
See [themes and review](THEMES_AND_REVIEW.md) and the [reference roadmap](PRODUCT_REFERENCE_PLAN.md).
Strict analysis, **350** unit/widget tests, web release, backend builds/contracts,
updater security tests and layout/package negative controls passed. All **32**
native Windows commands passed, retaining every earlier command and adding
independent-process appearance write/read plus filter/batch/reopen UI checks.
Local native compilation was unavailable; hosted Windows supplies that evidence.

Appearance tests cover legacy/corrupt/future preferences, isolated metadata,
preview/cancel/apply, strict RGB values and generated text contrast across presets
and extreme seeds. Session-only filters clear selection when scope changes.
Batch tests cover stale/duplicate/missing/cross-owner selections, canonical retry,
changed request reuse, full validation before mutation, reason/audit receipts,
Ignore/Keep/Reopen and exact preservation of journals/postings/change records.
Disposable PostgreSQL recovery matched all 14 tables across restart/restore.

UI artifact **12953332030** contains six fictional screenshots. The new dark,
light-preview and selected-review images were inspected for readable controls,
selection state and pending-row separation. No private account data was used.

## Packages

Client artifact **12953052125** contains the **16,530,641-byte** inner ZIP:

```text
be98b3e00b838a4521a7159bbdd8e2a2717030e62fc5be0e137843da8d076a6e
```

Identity/version/dependencies, checksums, negative controls and CRCs passed
independent verification. Security artifact **12953475996** reports no threats
for the exact ZIP and extracted contents at **2026-10-30T04:02:13.8936723Z**.
Both scans returned zero, engine **1.1.26100.4**, signatures **1.463.31.0**.
These are build-time Defender results, not publisher signing or an independent audit.

Server artifact **12952138251**, scan artifact **12952078675**: inner ZIP SHA-256
`8d8572b6e75203ca07ef72ed0c1713c691064d3b43bdd0a58e43990877b1e3f4`.
All **1,932** manifested hashes, exact membership, safe paths and CRCs passed.
The exact ZIP and extracted scans both returned zero/no threats with the same
engine/signatures. No installer or schema upgrade is needed for dev.22.


## Private delivery

A fresh protected backup restored into an isolated database with all 14 tables
matching. Only the verified API program was upgraded, with its prior path retained
for rollback. Normal certificate-validated HTTPS health, owner preservation,
disabled enrollment, distinct automatic service identities and unauthenticated
batch rejection passed. No schema migration, provider refresh or review mutation
was performed. The database service/data, IIS and firewall were unchanged.

The verified `0.1.0-dev.22+22` client was extracted separately. Only the previously
owned private launcher was updated after checking its old target; the previous
executable hash was unchanged and the current window was left open. No client
was automatically launched or authenticated. User confirmation of the new themes
remains pending. Host paths, protected backups and credentials stay outside Git.
No release/tag, real-bank connection, local upload or LAN/public exposure occurred.

All 47 README local links/anchors passed after the evidence update.
