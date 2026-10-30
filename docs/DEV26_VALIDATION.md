# Dev.26 report scope and comparison verification

Application `b8d21ed69fd1cc137461919ae3b2e0c3d8a37020`, tree
`0f55b35a4ba46c2d2bea1f0f6b0cc70225ac0820`, branch
`development/report-controls-dev26`, continuing verified dev.25 rather than old main.

[Build 41071151884](https://github.com/TechSavage1989/budgetism/actions/runs/41071151884)
passed all six jobs. Strict analysis, **381** tests on both Linux and Windows,
web/Windows release builds and all **34** retained/extended native Windows
commands passed. [Source run 41071151863](https://github.com/TechSavage1989/budgetism/actions/runs/41071151863)
also passed; all **278** tracked files matched the tested commit byte-for-byte.

## Scope and corrections

Category scopes use exact split contributions, including archived history and
signed refunds. Whole-account balances remain explicitly unfiltered. Historical
comparison uses the same snapshot/account/category filters for both periods,
exact deltas, inclusive date counts, leap-day clamping and honest zero/negative
base percentage disclosure. Apply/Cancel/Reset and narrow/wide widgets preserve
data. Native report tests confirm unchanged encrypted bytes and revision.
Configuration remains session-only. No financial schema or installed API change.

Two earlier candidates failed before packaging: run 41066511281 exposed a narrow
widget test attempting to locate an unmounted lazy-list checkbox; scoped scrolling
fixed the test. Run 41067852218 exposed a native fixture assertion expecting one
income total where income and net income correctly coincide; exact two-occurrence,
zero-expense and three zero-comparison assertions replaced it. No financial
calculation was changed to satisfy these tests. Final run above passed all gates.

Native screenshots from artifact **12986158677** passed hash/CRC checks and visual
inspection: period dates, scope, exact values, signed bars and whole-account
balance wording are readable. These use fictional data, not live user acceptance.
README HTML and hierarchy/navigation/link negative controls passed; local Chromium
visual rendering was blocked by sandbox socket restrictions. Local Flutter
remains unrun after the earlier metadata-access denial, with no indirect retry.
Hosted validation supplied runtime evidence; no security permissions changed.

## Exact package provenance

Client artifact **12985329455**, inner `Budgetism-Windows-x64.zip`, **16,612,545 bytes**:

```text
b8204a6e55a7ed9cd952e3eb7b6afc9fa155b00660f890c47eb4d8f2915e6bd4
```

Independent validation passed version `0.1.0-dev.26`, required native dependencies,
manifest/checksums, safe archive membership, CRCs and verifier negative controls.
Outer artifact SHA-256: `46f0b5c45eab01334c78b4147f97574defaa9e0efc86e09d63c424c4db1879f3`.
Security artifact **12985619228** matches the exact inner hash. Defender scanned
the ZIP and extracted files with both exit codes zero/no threats at
**2026-10-30T14:50:14.3933494Z**, engine **1.1.26100.4**, signatures **1.463.39.0**.
This is build-time evidence, not publisher signing or universal antivirus clearance.

Source artifact **12984204203**, inner source ZIP SHA-256
`0b5296e0f340662b04d07289e6b6c53e19bb6e3a17ca2283205279a022f353f6`.
Outer source SHA-256: `76d22ce14b625021211f3dd5f071036ee48e89ddada9aa34664014a50b7b7870`.

The unchanged client archive is `Budgetism-Dev26-Windows-x64-Verified.zip`.
Extract separately from the prior program and keep all bundled files. Existing
local workspace/settings and optional-password choices remain. For server use,
retain the existing explicit connection/sign-in flow; do not reinstall or upgrade
the server for this client. User acceptance remains unconfirmed.

No release/tag, main promotion, live bank retrieval/linkage, credential/access
change, server deployment, paid service or unattended worker was performed.
Install-and-restart and complete native updater timer/focus acceptance remain
unverified/disabled as documented in [updates](UPDATES.md).
