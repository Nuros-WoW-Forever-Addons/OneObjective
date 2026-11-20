# AI Context & Living Specification — OneObjective

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneObjective
- **Current Version**: 0.1.2
- **Suite**: Part of the **OneSuite** family
- **GitHub Repository**:
  - Exists: FALSE
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
