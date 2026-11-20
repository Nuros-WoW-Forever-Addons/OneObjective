# OneObjective

A clean, movable, zone-grouped Objective Tracker for **WoW Forever (Interface 16001)** that replaces Blizzard's default objective tracker.

## Features

- **Zone-Grouped Quests**: Organizes quests under their zone headers, with an option to pin your current zone at the top.
- **Collapsible Zone Headers**: Click any zone header to collapse or expand that zone's quests (saved across reloads), plus a global Collapse/Expand All button (`-` / `+`).
- **Left or Right Quest Item Buttons**: Choose whether usable quest item buttons appear on the **Right Side** or **Left Side** of the tracker so they never go off-screen.
- **Interactive Quest Rows**:
  - **Left-Click**: Toggle super-tracking on the quest.
  - **Shift + Left-Click**: Untrack the quest.
  - **Right-Click**: Open the quest in the Quest Log.
- **Customizable Appearance**: Adjust scale, width, max height, background opacity, and frame lock via `/oo` or the `Opt` button.
- **Hide Default Tracker**: Automatically hides Blizzard's default `ObjectiveTrackerFrame` (can be toggled off in Options).

## Slash Commands

- `/oo` or `/oneobjective` — Open the Options window
- `/oo lock` — Lock or unlock the tracker position
- `/oo side [left|right]` — Toggle or set quest item button side
- `/oo all` — Toggle between watched quests only and all quests in your Quest Log
- `/oo collapse` / `/oo expand` — Collapse or expand all zone headers
- `/oo blizz` — Toggle hiding Blizzard's default objective tracker
- `/oo chat` — Toggle routing messages to the `'OneAddon'` chat tab
- `/oo reset` — Reset the tracker position to default
