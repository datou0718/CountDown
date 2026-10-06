# Changelog

## 1.6.2 — 2026-10-06

- Make abbreviation searches exact: PST returns only PST, while city searches can offer PST and PDT separately.
- Save the selected abbreviation with its fixed offset so explicit choices stay unchanged across seasons and after reopening.
- Preserve existing and imported city-zone behavior until an explicit choice is made.

## 1.6.1 — 2026-10-06

- Show one picker entry per named time zone, with its cities linked as search aliases.
- Search by city, zone name, seasonal abbreviation, or UTC offset while preserving city identifiers and daylight-saving rules.

## 1.6.0 — 2026-10-06

- Added explicit due dates, due times, and searchable time zones. Changing zones preserves the entered local date and time.
- Hide expired events across the dashboard, menu bar, and widgets. Expired pins fall back to the next upcoming event; all-day events expire at the end of the selected day in their zone.
- Align app countdown updates to the clock and match the live widget timer's whole-second display. Widget timers stop at zero while waiting for macOS to switch entries.
- Preserve existing saved deadlines and support daylight-saving boundaries.
- Document source installation, updates, widgets, backups, and distribution requirements.
- Add a clean-checkout GitHub build workflow, package verification, and an empty-state preview.
- License the project under PolyForm Noncommercial 1.0.0.
