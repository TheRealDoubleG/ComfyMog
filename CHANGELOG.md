# ComfyMog Changelog

## 0.6 Beta – 04.10.2026
- Added optional scanning of equipped items on inspected players and records them as seen when the client exposes their item links.
- Added a setting to enable or disable inspected-player scanning.

## 0.5 Beta – 04.10.2026
- Added an account-wide transmog explorer with Seen, Collected, Uncollected and Owned filters.
- Added character-aware ownership tracking for equipped items, bags and bank scans.
- Added search/category filtering and ownership summaries in the browser and item tooltips.
- Added automatic inventory scanning and persistent seen-item history.

## 0.4 Beta – 04.10.2026
- Added the first account-wide seen/owned database layer for playtesting.

## 0.3 Beta – 28.09.2026
- Registered ComfyMog in Blizzard's native AddOns settings list with a button to open the full Comfy settings window.

## 0.2 Beta – 27.09.2026
- Fixed Background opacity so 0% fully removes the Comfy window background while the border can remain.
- Aligned the shared Load / copy control with its profile dropdown.

## 0.1 Beta – 27.09.2026
- Initial WoW: Forever 1.60.1 foundation.
- Added collected/uncollected transmog status to item tooltips.
- Added optional source ID display.
- Uses guarded C_TransmogCollection calls.
- Uses TooltipDataProcessor on WoW Forever, with a guarded legacy fallback.
- Added Comfy Suite UI standard generation 2.
- Retail/Midnight/Classic are explicitly not compatibility targets.
