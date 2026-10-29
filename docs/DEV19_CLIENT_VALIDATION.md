# Dev.19 Sandbox client verification

Application commit: `69b360fe99eef39f94976fa3c501f86a23ed9197`.
Source tree: `6759bd43e68760a16b6a5c4cf7f254308dcc4c9f`.
All six jobs in [run 40946563501](https://github.com/TechSavage1989/budgetism/actions/runs/40946563501)
passed. The separate [source archive run 40946563514](https://github.com/TechSavage1989/budgetism/actions/runs/40946563514)
also passed. Later documentation-only commits preserve these tested program files.

## Checks

Pinned Flutter 3.47.8/Dart 3.13.7 passed local strict analysis, all 328 unit/widget
tests and a release web build. Layout/native-target negative controls and all 40
README local links/anchors passed. Hosted CI repeated analysis/tests/web build,
backend/ledger/Plaid contracts, updater checks and all 27 native Windows commands.
The existing 26 native commands were retained. The additional server-preview test
verifies explicit retrieval, signed cents, pending/removal states, cleared failures,
no retrieval on navigation, no ledger writes and an unchanged separate temporary
encrypted local workspace. Its fictional screenshot, artifact **12930662418**,
was inspected for readable labels/amounts and clipping.

The pinned Dart runtime also validated the existing private server's HTTPS health
endpoint using default certificate trust. Earlier owner-authenticated server
preview returned four controlled fictional changes and zero ledger entries.
Manual sign-in with the newly packaged GUI remains a local user step.
Server program files/services/data were not changed for this client.

## Package and scan evidence

Client artifact **12932015171** contains `Budgetism-Windows-x64.zip` and checksums.
The inner ZIP is **16,463,794 bytes**, SHA-256:

`9e0e77a766e6b0ae9e4983cfb19e7af1d1b65fee94d7a1dcd625aa9746c865e1`

Security artifact **12930802705** reports no threats in both this exact archive and
its extracted files, exit code 0 for both. Defender engine **1.1.26100.4**,
signatures **1.463.30.0**, scan timestamp **2026-10-29T20:34:50.624177Z**.
The downloaded archive hash matches checksums.sha256 and the scan report.
Independent package verification/negative controls and ZIP CRC checks passed.
Identity is `TechSavage1989.Budgetism`, `0.1.0-dev.19`, `windows-x64`, with stable
`Budgetism.exe` and required native dependencies.

The unchanged ZIP was copied and extracted to a fresh private workspace delivery
folder. Existing desktop programs, shortcuts, local financial files, IIS, firewall
and server services were preserved. Host-specific paths remain in private notes.
The client was not automatically launched.

Local packaged-updater verify-only execution and system-drive staging were not
performed: automatic approval review rejected the combined command with
"blocked by policy". Safer workspace file-copy/extraction completed; no executable
was started by that command. Hosted native updater/package tests passed.
No updater installation, release or tag was published.

## Scope

See [SERVER_SANDBOX_CLIENT.md](SERVER_SANDBOX_CLIENT.md). This is a read-only
fictional preview, not durable ingestion, account mapping, ledger posting,
real bank linkage or device sync. The user-confirmed dev.18 baseline remains separate.
