# Dev.21 private server address verification

Application source: `dba4830610dc23c91c179c3cfee25f5f52c12d46`.
Exact tree: `8b8fc05e136dc159a8660e9bd1dd86a689065f4a`.
All six jobs in [run 40986681227](https://github.com/TechSavage1989/budgetism/actions/runs/40986681227)
and [source archive run 40986681222](https://github.com/TechSavage1989/budgetism/actions/runs/40986681222)
passed. Later documentation-only commits preserve these program files.

## Behavior and tests

The user confirmed dev.20 discovery/mapping/refresh. Independent private checks
found one mapped fictional account and four saved sources, without journal
entries or pending postings. A fresh full 14-table isolated restore passed with
that source history present. This is confirmation of source ingestion/recovery,
not manual posting. Financial review remains covered by the earlier contracts.

Dev.21 is client-only and adds the [optional remembered address](SERVER_ADDRESS.md).
Local strict analysis, all 344 unit/widget tests, web release, layout/native-target
negative controls and package-verifier negative controls passed. A temporary
native SQLite build-file lock arose when test commands overlapped; sequential
targeted and final full-suite reruns passed. No financial behavior changed.

Hosted CI repeated the full suite, backend/ledger/Plaid/database-recovery contracts,
updater security/cross-build tests and all earlier native commands. Two additional
native processes verify a fictional address survives restart and Forget removes
only the unique test preference, with no automatic handshake/sign-in. All **29**
native commands passed. No local native build was attempted because Visual C++
was unavailable; hosted native results supply that evidence.

The new tests cover opt-in and failure behavior, unsafe URL forms, preserved
unrelated preferences, late preference reads, stale destination responses, cleared
credentials, safe errors and disposed login callbacks. The earlier plaintext
rejection check remains, with scrolling before selecting an off-screen button.
All **45** README local links/anchors passed. The fictional welcome screenshot
in artifact **12948685223** was inspected: labels, privacy disclosure, controls
and footer are readable; long addresses use normal horizontal field scrolling.

## Exact package

Client artifact **12947344888** contains a **16,492,561-byte** inner ZIP, SHA-256:

```text
e9c1a25a4360f9b129d1e09df4584c87f21609353edbab0d9a19d67a73b8194b
```

Identity/version/dependencies, checksums, negative controls and ZIP CRCs passed
independent verification. Security artifact **12948311439** reports no threats
for this exact archive and its extracted files at **2026-10-30T01:59:29.8096485Z**,
engine **1.1.26100.4**, signatures **1.463.31.0**. Both scans returned exit code 0.
These are build-time Defender results, not publisher signing or an independent audit.

The verified `0.1.0-dev.21+21` program was extracted separately and a clearly named
private launcher was created. The previous program's hash was unchanged and the
user's current window was left open. The new client was not automatically launched
or configured; Remember remains an explicit user choice. Private paths and launch
instructions stay outside public source. No release or tag was published.

The working dev.20 API/source, schema, credentials, checkpoints, financial data,
IIS and firewall were unchanged by this delivery. No server artifact was installed
for this client-only change. Desktop financial data remains separate, normal HTTPS
validation remains required, and no real-bank linkage, LAN/public exposure or
automatic provider refresh was enabled.
