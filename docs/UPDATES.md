# Budgetism update architecture and release gate

Current release state: no GitHub Releases published. Verified compiled Windows development artifacts exist (see the current handoff), but native in-app installation remains disabled. Full previous-release download/install/relaunch and real native timer/focus acceptance have not been established.

## Update discovery

- Source: public GitHub REST API, `TechSavage1989/budgetism` releases. No bank or finance data is transmitted.
- Startup: asynchronous check; does not block app initialization.
- Active: five-minute polling, no duplicate in-flight requests.
- Focus return: check after at least two minutes since previous check.
- Manual: twenty-second cooldown. ETag and cached release JSON used for 304 responses.
- HTTP 403/429: follow Retry-After / GitHub reset time and display throttling. No claims of 'up to date' while offline or limited.
- Release selection: stable builds only stable releases, development versions may see prereleases. Semantic version numeric suffixes used.
- Download: only Windows x64 release asset named Budgetism-Windows-x64.zip, with GitHub-provided SHA-256 digest. GitHub asset URL and redirect host allowlist required.

## Windows portable package contract

Single ZIP with `Budgetism/` as root folder, executable `Budgetism/Budgetism.exe`, accompanying Flutter DLL/data files, `Budgetism/Budgetism-Updater.exe`, and the internal manifest `Budgetism/app-release.json` identifying TechSavage1989.Budgetism, release version, windows-x64 and Budgetism.exe. Version is not part of executable filename. A `checksums.sha256` file is generated beside the ZIP for release metadata.

`tools/updater` verifies archive digest, anti-traversal rules, sizes/compression, manifest version/identity/platform and Windows x64 PE. It supports preserving a custom launch filename and retains one persistent previous-install folder. The helper must be staged outside the install directory, wait for the old process to exit, launch the new program and verify that a visible window appeared, or restore the old folder.

Important: package hash is not a publisher signature. Signer verification, native restart testing and installer integration are still required. No self-updater may run during active financial operations.

## Native gate before enabling installation

1. Generate two genuine Flutter Windows builds, inspect ZIP layout, and record hashes.
2. Negative-control a deliberately corrupted ZIP and wrong-version ZIP; ensure rejection before touching current install.
3. From previous-version app, test user-click Download, checksum validation, staging, user-click Install and restart, old process exit, new visible window, shortcut persistence, settings persistence and one retained rollback folder.
4. Test a failed new window launch and confirm the prior folder is restored and relaunches.
5. Test custom executable filenames, cross-volume downloads, app-owned staging cleanup, antivirus interference and pause/active-work conditions.
6. Verify installed app only presents an update when feed contains a newer eligible version; verify startup, real timers, focus return, offline, 304, 403/429 Retry-After and throttling.
7. Verify release commit/tag, downloadable ZIP, checksum, manifest, no secrets, CI checks and source-to-release provenance before publication.

No CI job currently publishes a GitHub Release; building the Windows artifact is not permission to publish it.
