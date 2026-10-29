# Budgetism development handoff

**Development version:** 0.1.0-dev.16, calendar date selection and usability shortcuts.
**Application commit:** ef07b3438605a3de215c4cf1f75bccf015f519fc, tree 79cb611fdc65bb2665776e41a0268610c1f4900b.
**Successful build:** [run 40816063799](https://github.com/TechSavage1989/budgetism/actions/runs/40816063799), all five jobs passed, including the real Windows calendar test and exact-package Defender scans.
**User-confirmed baseline:** dev.15 CSV category suggestions and all earlier milestones work. Do not repeat earlier setup exercises.
**Starting main:** 57c958720a87dbe16ae2aa17e1e8e2061a71b2e9, tree 937edf4032ce2b715f69a9c5990284c4986a2403. Its tested application is b32e53e1a37a08ca4dd0a4dcb2830ce1b096d153, run 40809471115.

## Scope and continuity

Read AGENTS.md, docs/IMPLEMENTATION_STATUS.md, docs/DATE_CONTROLS.md, docs/USABILITY_ROADMAP.md and docs/BANK_CONNECTION_PLAN.md. The user requested easier dates and explicitly clarified the end goal: a real-bank-connected, intuitive personal finance application. Treat bank connectivity as a primary upcoming product goal while preserving optional local-only operation.

Public source and development artifacts remain authorized. No releases/tags, visibility/credential changes, server/provider/payment setup, unattended workers or Codex CLI automation. Bank integration design is not permission to enroll with a provider, start a paid subscription or connect real accounts. Obtain institution/country/account-type information, never login credentials in chat. Recheck live refs/PRs/releases before expected-head writes; never force-push or overwrite concurrent work.

Keep optional local passwords, encrypted data, independent backups and all existing finance features. No financial schema or storage migration, new dependency or data-path change in dev.16. Stable filenames remain Budgetism.exe and Budgetism-Windows-x64.zip. Existing workspace remains %LOCALAPPDATA%/Budgetism/finance/workspace.sqlite3 under the same Windows account.

## Implementation

apps/client/lib/date_controls.dart provides strict date-only conversion, calendar date fields with Today/optional Clear, inclusive range presets and a visual month/year selector. Calendar confirmation updates form controls, not financial records. Cancellation preserves the original value, including invalid text. Read-only/disabled states, bounds, overlapping picker launches and stale controller changes are guarded.

Schedule start/end and occurrence dates, statement ending dates and rule/register ranges use the shared controls. Existing recurrence anchors and reviewed statement dates remain locked. Rule-range changes invalidate old preview/selection/review. Register presets change only date filters. Budgets use a month grid, visual year selection and This month. Transaction editing adds Today/Yesterday and supports the ledger's existing year bounds. Reports, planning and sample/server calendars are retained.

Only presentation files, version/workflow references, tests and documentation change. Ledger, financial engines, CSV/rules/profiles/history processing, encryption/SQLite/OS-key code, backend and updater implementation remain unchanged.

## Validation and package

Keep Flutter 3.47.8 and all existing gates. The successful run passed analysis, 255 unit/widget tests on Ubuntu, the complete Windows suite, all prior native process/preservation tests, new native date-picker interaction, Windows/web builds, backend/Go checks, packaging and exact ZIP/extracted scanning. No local Flutter/Dart/.NET or Windows GUI exists; hosted runtime tests are separate from user confirmation. See docs/VALIDATION.md for performed checks and log notices.

Source artifact 12872462349 was hash-checked and independently reconstructed to the exact application Git tree. Windows artifact 12873575129 has outer SHA-256 5961a7bd1d5f38088dcea71abddb3c5508a089629dcf23dc6eb2d734f5c1af2f. Its inner ZIP is 16,318,836 bytes with SHA-256 fedad80dd470614eea32a955caa175a9aac563faa19b02d03b9deccc6e76a5bc. Security artifact 12873012449 reports no threats for that exact ZIP and its extracted files. Version, identity, dependencies, CRC/hashes and actual updater verify-only acceptance passed. Both executables remain unsigned; no updater install/relaunch/rollback was attempted.

The follow-up commit changes documentation only. Retain historical branches and the tested application/version. No release/tag is created. Generated outputs must stay outside tracked root.

## Next desktop check

Export a backup, close the current application and extract the new program into a separate folder. Open the existing workspace, not a replacement database. Choose a date in Scheduled > Add schedule and cancel without saving. Try register Last 7 days/All dates and visual budget month/year selection. No new test transactions or earlier feature setup are required. Dev.16 manual confirmation remains pending.

## Next implementation direction

Prioritize one cohesive everyday-use milestone: clearer navigation/Home, fast transaction entry with payee autocomplete, searchable account/category choices, fewer redundant confirmations and predictable desktop behavior. Design Connect bank, account mapping, sync status and Needs review alongside this work.

Then build a provider-independent, fictional bank-feed test path covering pending/posted replacements, corrections, duplicate-safe retries, preserved user edits, transfer/schedule matching and account baselines. Select a real provider only after verifying the user's bank coverage, current costs, access requirements and privacy/security disclosures. Self-hosted cross-device sync remains the intended architecture, not an already-working feature. Detailed acceptance criteria and researched candidates are in BANK_CONNECTION_PLAN.md. No live service or bank authorization has been performed.
