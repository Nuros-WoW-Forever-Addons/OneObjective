# Changelog — OneObjective

## [0.1.5] - 2026-11-21
### Fixed
- **MapCanvas `SetPassThroughButtons` Taint**: Removed `POIButtonTemplate` instantiation from `Tracker.lua` (which tainted `Blizzard_POIButton` / `QuestDataProvider` map pins on `MapCanvas:AcquirePin`) and switched to a taint-free plain `Frame` using Blizzard's POI atlases directly (`UI-QuestPoi-QuestNumber`, `UI-QuestPoi-QuestNumber-SuperTracked`, `Quest-In-Progress-Icon-small`, `UI-QuestIcon-TurnIn-Normal`).

## [0.1.4] - 2026-11-20
### Fixed
- **Quest Item Button Clicks**: Updated `SecureActionButtonTemplate` quest item buttons to `RegisterForClicks("AnyUp", "AnyDown")` so clicks trigger properly when `ActionButtonUseKeyDown` is enabled.
- **Combat Lockdown Protected Call Errors**: Reparented `OneObjectiveItemButton*` frames from `OneObjectiveFrame` to `UIParent` (so `OneObjectiveFrame` never inherits combat-protected status) and guarded `SetScale` / `SetWidth` / `SetHeight` with `InCombatLockdown()`.

## [0.1.3] - 2026-11-20
### Fixed
- **Blizzard Tracker Flash on Quest Update**: Added `SetAlpha(0)` suppression and `hooksecurefunc(ObjectiveTrackerFrame, "SetShown", ...)` alongside the `Show` hook in `Core.lua` so Blizzard's default tracker never flashes visible when quest objectives update.

## [0.1.2] - 2026-11-20
### Added
- **Collapsible `Quests` Section Header**: Added a top-level `Quests` header above all Zone headers. Collapsing `Quests` hides all zone headers and quests while keeping tracked `Professions` recipes visible below.
- **Proportional Text Size Option**: Added a **Text Size** slider (`80%`–`160%`) in `/oo` Options (`OneObjectiveDB.fontScale`) that scales section headers (`15pt`), zone headers (`13.5pt`), quest titles (`12.5pt`), and objective lines (`11.5pt`) proportionately.

## [0.1.1] - 2026-11-20
### Changed
- **Blizzard Objective Tracker Styling**: Restyled `OneObjective` to match Blizzard's native `ObjectiveTrackerFrame` aesthetic:
  - Frameless transparent background by default (`bgAlpha = 0.0`).
  - Top `All Objectives` header bar with subtle gold underline, Blizzard-style minimize button, and hover-only `Opt` / `Lock` utility buttons (plus Right-Click for Options).
  - Zone headers use Blizzard's dark horizontal gradient bar, thin gold bottom line, gold title, and `-` / `+` minimize button.
  - Added circular quest POI / super-track badges (`?` / `•••` with glowing gold highlight when super-tracked) on the left of each quest row.
- **Professions Tracking**: Added collapsible `Professions` section below Zone groups for tracked crafting/recrafting recipes (`C_TradeSkillUI.GetRecipesTracked`).

## [0.1.0] - 2026-11-20
### Added
- **Zone-Grouped Quest Tracking**: Groups tracked (or all) quests by their Quest Log zone header, with optional current-zone-first sorting.
- **Collapsible Zone Headers**: Click any zone header (`[-]` / `[+]`) to collapse or expand its quests; collapse state persists per zone in `OneObjectiveDB.collapsedZones`.
- **Configurable Quest Item Button Side**: Option to place clickable quest item buttons on the **Right Side** (default) or **Left Side** of the tracker so they never clip off-screen.
- **Taint-Safe Secure Quest Item Buttons**: Uses `SecureActionButtonTemplate` with `InCombatLockdown()` queuing, cooldown swipes, charge counters, and item tooltips.
- **Blizzard Tracker Suppression**: Cleanly hides Blizzard's default `ObjectiveTrackerFrame` (toggleable in Options or `/oo blizz`).
- **Options UI & Slash Commands**: Standalone `/oo` (`/oneobjective`) configuration window and Blizzard Settings entry.
- **OneSuite Integration**: Routes addon messages to the shared `"OneAddon"` chat tab.
