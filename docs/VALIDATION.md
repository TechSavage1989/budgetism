# Validation: Budgetism 0.1.0-dev.3

## Baselines and negative control

The user confirmed dev.2 Windows startup and local data retention after restart. That confirms the reported workflow, not a full audit. Dev.2 source: 9bbe21f73bbc79dc1bb42c7c655180113458cbc0; successful run 40580132124.

Dev.3 commit 33cea10232107cf6ee79f717c7d918b7a951203e failed in [run 40597079736](https://github.com/TechSavage1989/budgetism/actions/runs/40597079736). Flutter analysis reported use_build_context_synchronously at main.dart:468. Windows tests/build were skipped. This real failed run is the negative control.

Commit f376eb8b08bca041e30aee795d16b5a7883578cb adds only the missing mounted guard. [Run 40604743739](https://github.com/TechSavage1989/budgetism/actions/runs/40604743739) passed all five jobs with the same analyzer gate, without suppressing the lint or skipping tests.

## Passed in hosted CI for the exact corrected commit

- Flutter analysis and the complete existing/new unit/widget suite on Windows and Ubuntu.
- Independent format-1 legacy compatibility, wrong-password rejection, explicit off/on conversion and preserved financial records.
- Password-free creation/reopen and portable, independently password-encrypted backup/restore.
- Missing keys, failed OS writes/readback, failed DB commit, stale windows, metadata tampering and obsolete-key cleanup warnings.
- Real Windows OS secure storage and SQLite in two separate native app processes: first writes, second reopens and exercises both access-mode conversions.
- Flutter Windows release compilation and portable packaging from an extracted source archive with no .git.
- Flutter web compilation. This does not enable browser-local financial storage.
- .NET backend build and ledger contract tests; Go updater tests; source-layout guard including deliberate clutter.

## Passed locally

- Original source-archive outer/inner SHA-256 and commit provenance.
- Corrected source tree equals Git tree 0446c12e0f0bb3f64bb29e3abe34a1dd72beff2f. The modified main.dart blob is fa92797f95c933f6ae7646b6fff5992936ef25ac, matching the GitHub write result.
- Layout guard and negative control without Git metadata; Go test -race and go vet on Linux.
- README single H1, navigation anchors and local documentation targets. Hosted GitHub visual rendering was not inspected.
- Downloaded artifact ID 12779758618 belongs to run 40604743739 and the corrected commit. Artifact envelope SHA-256: 583388f59c4982423a78400d7be6365f5e3de6931b09e2099646e6a7b104f3f0.
- Inner Budgetism-Windows-x64.zip matches checksums.sha256: 6f4f8c94cbd2fb5234562ff4755364381dc9053ea7aa1674150cc8cb00d7fc26. Size: 15,833,965 bytes; 18 entries.
- ZIP paths, duplicate names, CRC, size limits, application identity/version/platform and both Windows x64 PE executables.
- Required Flutter, SQLite, file selector and secure-storage plugin DLLs are present; no database/vault files are included.
- The actual Go updater accepted the downloaded package using --verify-only. No installation or replacement was attempted.

## Not established by these tests

Manual dev.3 GUI operation on the user's PC, real backup file-picker interaction, native updater install/relaunch/rollback, actual focus/timer/update behavior, code-signing verification, independent security review, live PostgreSQL integration and non-Windows native distributions remain separate checks. Local Flutter/.NET SDKs and a Windows GUI were unavailable; their reported passes come from hosted CI.

This is a temporary development artifact, not a published GitHub release, signed distribution or production approval. In-app installation stays disabled. Export a backup before changing security; dev.2 cannot read a converted format-2 workspace.
