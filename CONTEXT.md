# AI Context & Living Specification — OneObjective

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneObjective
- **Current Version**: 0.2.5
- **Suite**: Part of the **OneSuite** family
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneObjective
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>` or `dev`)
- **Live Sync Path**: `/Applications/World of Warcraft/_forever_/Interface/AddOns/OneObjective/`
- **Rollback Target**: Last working `main` branch commit
- **Target WoW Runtime**: WoW Forever (v1.60.1 / Interface 16001)
- **Primary Goal**: Replace Blizzard's default `ObjectiveTrackerFrame` with a clean, movable, zone-grouped objective tracker featuring collapsible zone headers and configurable Left/Right placement for quest item buttons.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneObjective.toc`: Addon manifest (`## Interface: 16001`), load order, and `OneObjectiveDB` SavedVariables declaration.
- `Core.lua`: SavedVariables initialization (`ADDON_LOADED`), event dispatch table, `ObjectiveTrackerFrame` suppression via `hooksecurefunc`, `"OneAddon"` chat tab routing, and `/oo` / `/oneobjective` slash commands.
- `Data.lua`: `C_QuestLog` and `C_SuperTrack` scanner, zone header grouping, current-zone-first sorting, objective parsing, and `GetQuestLogSpecialItemInfo` extraction.
- `Tracker.lua`: Movable/scalable `OneObjectiveFrame`, scrollable quest list, pooled collapsible zone headers, quest blocks (super-tracking, untracking, Quest Log opening), and `SecureActionButtonTemplate` quest item button pool anchored outside the `ScrollFrame` on either the `LEFT` or `RIGHT` side with `InCombatLockdown()` queuing.
- `OptionsUI.lua`: Standalone draggable `OneObjectiveOptionsFrame` and Blizzard Settings category registration.

### Global State & Database Schema (`OneObjectiveDB`)
```lua
OneObjectiveDB = {
    enabled = true,
    hideBlizzardTracker = true,
    locked = false,
    scale = 1.0,
    fontScale = 1.0,
    width = 250,
    maxHeight = 460,
    bgAlpha = 0.0,
    questItemSide = "RIGHT",       -- "LEFT" or "RIGHT"
    showOnlyWatched = true,
    showQuestLevels = true,
    sortCurrentZoneFirst = true,
    allCollapsed = false,
    routeToOneAddonTab = true,
    collapsedZones = {},           -- [zoneName] = boolean
    position = nil,                -- { point, relPoint, x, y }
    optionsPosition = nil,
}
```

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.2.5
- **Fixed Quest Log Taint**: Replaced `QuestMapFrame_OpenToQuestDetails` with `C_QuestLog.SetSelectedQuest` + `ToggleQuestLog` on Right-Click in `Tracker.lua` so `QuestMapFrame` is never tainted.

### Spin 0.2.4
- **Fixed Combat `SetPassThroughButtons()` Error**: Guarded `QuestMapFrame_OpenToQuestDetails`, `ToggleQuestLog`, and `C_SuperTrack.SetSuperTrackedQuestID` in `Tracker.lua` with `InCombatLockdown()` so clicking quest rows during combat never triggers protected `MapCanvas` pin updates.

### Spin 0.2.3
- **Fixed Combat `GetAuraDataByIndex()` Taint**: Switched `UpdateBlizzardTracker()` in `Core.lua` to `SetAlpha(0)` / `SetAlpha(1)` only (removing `SetParent`, `Hide`, `RegisterStateDriver`, and `hooksecurefunc`) so `ObjectiveTrackerFrame`'s `OnHide`/`EditMode` callbacks are never triggered from addon taint.

### Spin 0.2.2
- **Fixed Blizzard Tracker Flash on World Map Open/Close**: Reparented `ObjectiveTrackerFrame` to `OneObjectiveHiddenParent` (a hidden `UIParent` child) in `Core.lua` so `WorldMapFrame` open/close never flashes it and `IsVisible()` remains `false` in combat.

### Spin 0.2.1
- **Fixed Combat `GetAuraDataByIndex()` Taint**: Switched `ObjectiveTrackerFrame` suppression in `Core.lua` to `RegisterStateDriver(..., "visibility", "hide")` / `UnregisterStateDriver(...)` and removed `ObjectiveTrackerFrame` texture copying in `Tracker.lua`, preventing taint on `ScenarioObjectiveTracker` / `Blizzard_MawBuffs` in combat.

### Spin 0.2.0
- **Timed Quest Support (`TimerFrame.lua`, `Data.lua`, `Tracker.lua`)**:
  - Added `C_QuestLog.GetTimeAllowed(questID)` extraction in `Data.lua`.
  - Added inline countdown bar (`StatusBar` + `Time Remaining: MM:SS`) below timed quest objectives in `Tracker.lua`.
  - Added optional standalone movable `OneObjectiveTimerFrame` (`OneObjectiveDB.standaloneQuestTimer`) mirroring quest name, objectives, and live timer bar, with `/oo timer test` preview and `/oo timer reset`.

### Spin 0.1.5
- **Fixed `MapCanvas` `SetPassThroughButtons` Taint**: Removed `POIButtonTemplate` from `Tracker.lua` and rendered Blizzard's exact POI atlases (`UI-QuestPoi-QuestNumber`, `UI-QuestPoi-QuestNumber-SuperTracked`, `Quest-In-Progress-Icon-small`, `UI-QuestIcon-TurnIn-Normal`) on a plain `Frame` so `QuestDataProvider` map pins are never tainted.

### Spin 0.1.4
- **Fixed Quest Item Button Clicks & Combat Protected Call Errors**:
  - Updated `AcquireItemButton` in `Tracker.lua` to `RegisterForClicks("AnyUp", "AnyDown")` so quest items trigger when `ActionButtonUseKeyDown` is active.
  - Reparented `OneObjectiveItemButton*` to `UIParent` so `OneObjectiveFrame` does not become combat-protected, and guarded `SetScale`/`SetWidth`/`SetHeight` with `InCombatLockdown()`.

### Spin 0.1.3
- **Fixed Blizzard Tracker Flash**: Added `SetAlpha(0)` and `SetShown` hook to `UpdateBlizzardTracker()` in `Core.lua` so `ObjectiveTrackerFrame` never flashes visible on quest objective updates.

### Spin 0.1.0
- **Initial OneObjective Addon**:
  - Implemented zone-grouped quest tracking with clickable, persistent collapsible zone headers (`OneObjectiveDB.collapsedZones`).
  - Implemented `SecureActionButtonTemplate` quest item buttons with configurable `LEFT` or `RIGHT` placement (`OneObjectiveDB.questItemSide`, defaulting to `"RIGHT"`), combat lockdown queuing, cooldown swipes, and charge counts.
  - Added clean `ObjectiveTrackerFrame` suppression (`OneObjectiveDB.hideBlizzardTracker`).
  - Added draggable top-anchored tracker frame, scrollable quest list, super-tracking on Left-Click, untrack on Shift+Left-Click, Quest Log details on Right-Click.
  - Added standalone Options UI (`/oo`) and `"OneAddon"` chat tab routing.

---

## 📋 Living Roadmap & Upcoming Backlog

### High Priority
- Verify in-game on WoW Forever (v1.60.1 / Interface 16001) with active quests containing special quest items and multi-zone quest logs.

### Nice-to-Have / Future Enhancements
- Achievement tracking section (collapsible header below quests).
- Optional auto-collapse of non-current zones when entering a new zone.
- Custom font size selector in Options UI.
