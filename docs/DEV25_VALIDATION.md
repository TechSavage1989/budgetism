# Dev.25 report and forecast verification

Application: `dba09b0a5ad39cc0dfed5e9bf74e5ad7fd2236c2`.
Tree: `627c0a24cdbdc962b9433692c0f945e2ea2cd61f`.
Branch: `development/report-forecast-dev25`, based on verified dev.24 branch head
`15cc77a8171bea3fd70048f267d19b05c0bc76fa`, not older main.

[Build run 41060657452](https://github.com/TechSavage1989/budgetism/actions/runs/41060657452)
completed all six jobs successfully. The independent
[source run 41060657492](https://github.com/TechSavage1989/budgetism/actions/runs/41060657492)
also passed. No failed candidate or rerun was needed.

## Scope and test evidence

This is a client-only presentation/read-model increment. Report graphs expose
income/expenses, net income or recorded net balance, line/bar style, month
inspection and exact values. Forecast controls expose 1–365 days and explicit
schedule inclusion/exclusion, Apply/Cancel/Reset and normal-baseline versus
what-if comparison. Configuration is session-only; no financial schema or
installed API/database change is required. See [scope](REPORT_FORECAST_DEV25.md)
and [the longer replacement roadmap](REPLACEMENT_ROADMAP.md).

Hosted strict analysis reported no issues. All **372** unit/widget/storage tests
passed on Linux and Windows, followed by web and Windows release compilation.
All **34** existing native Windows commands were retained and passed. The report
and planning native commands were extended with new graph/scenario flows and
unchanged encrypted SQLite bytes/revisions. New engine/widget cases exercise
signed refunds/debt, zero activity, exact large amounts, narrow/wide controls,
account cancellation, date selection, future actuals, linked schedules, transfer
netting, overdue disclosure, custom one-day horizon and deterministic reset.

Static peer review corrected grouped bars clipping at first/last month and made
today-inclusive schedule wording explicit before the tested commit. The new
native screenshots in artifact **12981561405** were downloaded, hash/CRC checked
and visually inspected. Report metric/bar/exact values and forecast baseline/
scenario/recorded distinctions are readable. These are fictional test data, not
authenticated live-server acceptance evidence.

Backend contracts, updater security, source layout and server package/Defender
jobs passed unchanged hosted gates. No server artifact was installed. Local
source-layout and package negative controls passed. Local Flutter bootstrap was
stopped by automatic review for an unexpected instance-metadata request; no
workaround or retry was used, and no local Flutter pass is claimed. Native
PowerShell and a Go compiler were unavailable locally; hosted checks supplied
that evidence. No security permissions were weakened.

## Package and scan evidence

Client artifact **12981736554** was downloaded. Its inner
`Budgetism-Windows-x64.zip` contains **16,601,349 bytes**, SHA-256:

```text
085daa0027bf42a537661996597f50ee621be6a15b6c54d3e0d26a4ceeb18d90
```

Independent package validation confirmed identity/version `0.1.0-dev.25`, native
runtime dependencies, manifest/checksums, safe archive membership and CRCs.
Security artifact **12981986443** matched this exact archive hash. Defender
scanned both the ZIP and extracted files at **2026-10-30T13:31:49.6998901Z**;
both returned zero/no threats with engine **1.1.26100.4**, signatures
**1.463.36.0**. This is build-time scan evidence, not publisher signing or
clearance by every browser/antivirus. Executables remain unsigned.

Source artifact **12979265665** passed outer/inner checksums and CRCs; all **268**
source file bytes matched the application commit. Inner source ZIP SHA-256:
`6e70988758312478c6a275551f4b0485c21f565f213e36dcae03673f0fff13f8`.

The unchanged client ZIP is delivered as
`Budgetism-Dev25-Windows-x64-Verified.zip`. Program extraction must be separate
from the prior client folder, preserving all bundled files. Existing local
workspaces and optional-password choices remain; no new migration is introduced.
For server sessions, use the existing explicit server connection/sign-in flow.
Do not rerun server installation or planning-schema upgrade for this client.

No release, tag, main-branch promotion, real bank link, provider retrieval,
credential change, private installation or network change was performed.
User acceptance of dev.25 remains unconfirmed. The installed dev.24 program,
protected recovery keys and previous rollback files were left untouched.
