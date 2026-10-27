# Current implementation state

Budgetism 0.1.0-dev.1, October 27, 2026. **Source development, not a tested finance release.**

| Area | Current status |
| --- | --- |
| Repository | Source publication authorized for public Budgetism repository; no application release published |
| Flutter shell | Source has desktop/web/mobile responsive dashboard, accounts, transactions and initial connection screen; uncompiled |
| Demo | Added ephemeral sample data with in-memory account and transaction changes; uncompiled |
| Ledger | Prior exact-integer double-entry API source and C# fixture tests; uncompiled |
| Updates discovery | Added cached ETag, 5-minute active checks, startup and focus, manual cooldown and backoff; tests authored but Dart SDK unavailable |
| Update download | Windows-only HTTPS allowlist + expected GitHub digest and staging; untested at runtime |
| Windows helper | Go unit tests pass and PE32+ Windows x64 helper builds; installer not integrated or Windows-tested |
| Windows package | PowerShell packaging plus CI definition; no actual Flutter app executable built |
| Offline sync | Not implemented; demo mode is memory-only, not durable offline finance storage |
| Budgeting and forecasts | UI placeholders, no engines |
| Production data safety | Not established; migrations, local encryption and restore tests outstanding |
| Publishing | Source publication authorized; do not create tags/releases or change visibility |

Read DEVELOPMENT_HANDOFF.md for exact commands and limitations. In this work, no server deployment or API-account setup has been added.
