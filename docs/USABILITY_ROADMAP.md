# Usability priorities

The user confirmed dev.15 and requested a shift toward ease of use rather than another narrow import feature. This roadmap is a proposal; only the date-control milestone is implemented in the dev.16 source.

## Current milestone: dates

Calendar selection for remaining typed date fields, quick inclusive date ranges, Today/Yesterday for transactions and visual budget month/year selection. Preserve manual entry, cancellation, financial protections and all saved data. No financial migration.

## Next: faster everyday transaction entry

Add local payee autocomplete from existing history, a clear quick-add workflow and an explicit Save and add another option. Make last-used account/category defaults predictable and optional; never reuse a transfer direction or split silently. Validate decimal cents, show remaining split allocation and leave protected records untouched. Remember personal finance defaults only inside an approved encrypted model, not plaintext preferences. Keyboard shortcuts must not accidentally submit while a calendar or confirmation dialog is open.

## Then: easier navigation and desktop behavior

Reduce nested menus for rules, import profiles, reconciliation and backups. Provide useful empty states and visible next actions. Preserve the current navigation until changes are tested across small and large windows. Add remembered window size/position, sensible minimum sizes, consistent keyboard focus, clearer disabled-control explanations and searchable account/category selectors. Desktop geometry is a nonfinancial per-device preference; personal search text remains session-only.

## Delivery usability

A tested in-app update workflow would remove repeated ZIP handling. It still requires native install/relaunch/rollback tests and explicit authorization for any release/tag publication. Do not enable it or publish releases as a side effect of date controls.

## Larger product goals

Self-hosted cross-device synchronization and mobile access remain part of the product direction, but are not implemented or enabled by this milestone. Server/provider setup stays outside the currently authorized implementation scope. Do not ask the user to repeat setup exercises for features already confirmed working.
