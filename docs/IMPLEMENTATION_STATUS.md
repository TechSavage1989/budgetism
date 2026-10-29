# Current implementation state

Dev.15 CSV suggestions and all earlier milestones are user-confirmed. Dev.16 implements calendar date controls and ease-of-use shortcuts. Hosted validation and exact package scanning must finish before delivery; see VALIDATION.md.

| Area | State |
| --- | --- |
| Calendar entry | Schedule, occurrence, statement, rule and register dates use shared calendar controls |
| Shortcuts | Today, transaction Yesterday, optional Clear, inclusive range presets |
| Budget navigation | Visual month grid, year selector and This month |
| Protection | Existing schedule anchors and reviewed statement dates stay locked |
| Financial data | No new schema or migration; all calculations and storage code retained |
| Existing calendars | Reports, planning and sample/server date pickers retained |
| Validation | New pure, interface and native UI tests added; hosted results pending |
| Distribution | Development artifacts only; no releases, server setup or updater installation |

Manual date entry remains optional. All new date/range interaction is presentation-only until existing explicit actions are confirmed. Next usability priorities are proposals in USABILITY_ROADMAP.md, not implemented features.
