--[[
    OneObjective - Core.lua
    Initialization, SavedVariables, Event Dispatch, Blizzard Tracker Suppression,
    Dedicated "OneAddon" Chat Tab Routing, and Slash Commands.
--]]

local addonName, ns = ...
_G.OneObjective = ns

ns.version = "0.1.0"

ns.defaults = {
    enabled = true,
    hideBlizzardTracker = true,
    locked = false,
    scale = 1.0,
    fontScale = 1.0,
    width = 250,
    maxHeight = 460,
    bgAlpha = 0.0,
    questItemSide = "RIGHT", -- "LEFT" or "RIGHT"
    showOnlyWatched = true,
    showQuestLevels = true,
    sortCurrentZoneFirst = true,
    allCollapsed = false,
    routeToOneAddonTab = true,
    collapsedZones = {},
    position = nil,
    optionsPosition = nil,
}

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-------------------------------------------------------------------------------
-- Message Routing & Dedicated Chat Tab ("OneAddon")
-------------------------------------------------------------------------------
local chatTabInitialized = false

function ns:EnsureChatTab()
    if not OneObjectiveDB or OneObjectiveDB.routeToOneAddonTab == false then
        return DEFAULT_CHAT_FRAME
    end

    local targetName = "OneAddon"

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = GetChatWindowInfo(i)
        if name == targetName then
            local cf = _G["ChatFrame" .. i]
            if cf then
                local tab = _G["ChatFrame" .. i .. "Tab"]
                if tab then
                    tab:Show()
                    if PanelTemplates_TabResize then
                        pcall(PanelTemplates_TabResize, tab, 0)
                    end
                end
                return cf
            end
        end
    end

    if FCF_OpenNewWindow then
        local frame = FCF_OpenNewWindow(targetName)
        if frame then
            if FCF_DockFrame and GENERAL_CHAT_DOCK then
                local docked = (FCFDock_GetChatFrames and FCFDock_GetChatFrames(GENERAL_CHAT_DOCK))
                    or (GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES)
                    or {}
                local nextIdx = #docked + 1
                pcall(FCF_DockFrame, frame, nextIdx, false)
            end
            if ChatFrame_RemoveAllMessageGroups then
                pcall(ChatFrame_RemoveAllMessageGroups, frame)
            end
            if ChatFrame_RemoveAllChannels then
                pcall(ChatFrame_RemoveAllChannels, frame)
            end
            if FCF_DockUpdate then
                pcall(FCF_DockUpdate)
            end
            local id = frame.GetID and frame:GetID()
            if id then
                local tab = _G["ChatFrame" .. id .. "Tab"]
                if tab then
                    tab:Show()
                    if PanelTemplates_TabResize then
                        pcall(PanelTemplates_TabResize, tab, 0)
                    end
                end
            end
            if FCF_SelectDockFrame and DEFAULT_CHAT_FRAME then
                pcall(FCF_SelectDockFrame, DEFAULT_CHAT_FRAME)
            end
            return frame
        end
    end

    return DEFAULT_CHAT_FRAME
end

function ns:Print(msg)
    local out = self:EnsureChatTab() or DEFAULT_CHAT_FRAME
    if out and out.AddMessage then
        out:AddMessage("|cff00ccff[OneObjective]|r " .. tostring(msg))
    end
end

-------------------------------------------------------------------------------
-- Blizzard ObjectiveTrackerFrame Suppression
-------------------------------------------------------------------------------
local blizzHooked = false
local pendingBlizzUpdate = false

function ns:UpdateBlizzardTracker()
    local blizz = _G.ObjectiveTrackerFrame
    if not blizz then return end

    local function Suppress(self)
        if OneObjectiveDB and OneObjectiveDB.hideBlizzardTracker then
            self:SetAlpha(0)
            if InCombatLockdown() then
                pendingBlizzUpdate = true
            else
                self:Hide()
            end
        end
    end

    if not blizzHooked then
        blizzHooked = true
        hooksecurefunc(blizz, "Show", Suppress)
        if blizz.SetShown then
            hooksecurefunc(blizz, "SetShown", function(self, shown)
                if shown then
                    Suppress(self)
                end
            end)
        end
    end

    if OneObjectiveDB and OneObjectiveDB.hideBlizzardTracker then
        blizz:SetAlpha(0)
        if InCombatLockdown() then
            pendingBlizzUpdate = true
        else
            blizz:Hide()
        end
    else
        blizz:SetAlpha(1)
        if InCombatLockdown() then
            pendingBlizzUpdate = true
        else
            blizz:Show()
        end
    end
end

-------------------------------------------------------------------------------
-- Debounced Tracker Refresh
-------------------------------------------------------------------------------
local updatePending = false

function ns:RequestTrackerUpdate()
    if updatePending then return end
    updatePending = true
    C_Timer.After(0.05, function()
        updatePending = false
        if ns.Tracker and ns.Tracker.Refresh then
            ns.Tracker:Refresh()
        end
    end)
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
local function HandleSlashCommand(msg)
    local cmd, arg = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    arg = string.lower(arg or "")

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "opt" then
        if ns.OptionsUI and ns.OptionsUI.Toggle then
            ns.OptionsUI:Toggle()
        end
    elseif cmd == "lock" then
        OneObjectiveDB.locked = not OneObjectiveDB.locked
        if ns.Tracker and ns.Tracker.UpdateLockState then
            ns.Tracker:UpdateLockState()
        end
        ns:Print("Tracker " .. (OneObjectiveDB.locked and "|cffff6666locked|r." or "|cff66ff66unlocked|r."))
    elseif cmd == "side" or cmd == "itemside" then
        if arg == "left" then
            OneObjectiveDB.questItemSide = "LEFT"
        elseif arg == "right" then
            OneObjectiveDB.questItemSide = "RIGHT"
        else
            OneObjectiveDB.questItemSide = (OneObjectiveDB.questItemSide == "RIGHT") and "LEFT" or "RIGHT"
        end
        ns:RequestTrackerUpdate()
        ns:Print("Quest item buttons moved to |cffffd200" .. OneObjectiveDB.questItemSide .. "|r side.")
    elseif cmd == "all" or cmd == "watched" then
        OneObjectiveDB.showOnlyWatched = not OneObjectiveDB.showOnlyWatched
        ns:RequestTrackerUpdate()
        ns:Print(OneObjectiveDB.showOnlyWatched and "Showing |cffffd200watched quests only|r." or "Showing |cffffd200all quests|r in Quest Log.")
    elseif cmd == "collapse" then
        if ns.Tracker and ns.Tracker.SetAllCollapsed then
            ns.Tracker:SetAllCollapsed(true)
        end
    elseif cmd == "expand" then
        if ns.Tracker and ns.Tracker.SetAllCollapsed then
            ns.Tracker:SetAllCollapsed(false)
        end
    elseif cmd == "blizz" then
        OneObjectiveDB.hideBlizzardTracker = not OneObjectiveDB.hideBlizzardTracker
        ns:UpdateBlizzardTracker()
        ns:Print("Blizzard default tracker " .. (OneObjectiveDB.hideBlizzardTracker and "|cffff6666hidden|r." or "|cff66ff66shown|r."))
    elseif cmd == "chat" or cmd == "tab" then
        OneObjectiveDB.routeToOneAddonTab = not (OneObjectiveDB.routeToOneAddonTab ~= false)
        local dest = OneObjectiveDB.routeToOneAddonTab and "'OneAddon' chat tab" or "General chat"
        ns:Print("Addon messages routed to |cffffd200" .. dest .. "|r.")
    elseif cmd == "reset" then
        OneObjectiveDB.position = nil
        if ns.Tracker and ns.Tracker.ApplyPosition then
            ns.Tracker:ApplyPosition()
        end
        ns:Print("Tracker position reset to default.")
    else
        ns:Print("Commands:")
        ns:Print("  |cffffd200/oo|r - Open Options window")
        ns:Print("  |cffffd200/oo lock|r - Toggle frame lock")
        ns:Print("  |cffffd200/oo side [left|right]|r - Toggle or set quest item button side")
        ns:Print("  |cffffd200/oo all|r - Toggle watched-only vs all quests")
        ns:Print("  |cffffd200/oo collapse|r / |cffffd200expand|r - Collapse or expand all zones")
        ns:Print("  |cffffd200/oo blizz|r - Toggle hiding Blizzard's default tracker")
        ns:Print("  |cffffd200/oo chat|r - Toggle 'OneAddon' chat tab routing")
        ns:Print("  |cffffd200/oo reset|r - Reset tracker position")
    end
end

SLASH_ONEOBJECTIVE1 = "/oo"
SLASH_ONEOBJECTIVE2 = "/oneobjective"
SlashCmdList["ONEOBJECTIVE"] = HandleSlashCommand

-------------------------------------------------------------------------------
-- Event Frame & Dispatch Table
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local events = {}

function events.ADDON_LOADED(loadedAddon)
    if loadedAddon ~= addonName then return end

    if type(_G.OneObjectiveDB) ~= "table" then
        _G.OneObjectiveDB = {}
    end
    ApplyDefaults(_G.OneObjectiveDB, ns.defaults)

    if ns.Tracker and ns.Tracker.Init then
        ns.Tracker:Init()
    end
    if ns.OptionsUI and ns.OptionsUI.Init then
        ns.OptionsUI:Init()
    end

    ns:UpdateBlizzardTracker()
    eventFrame:UnregisterEvent("ADDON_LOADED")
end

function events.PLAYER_ENTERING_WORLD()
    if not chatTabInitialized then
        chatTabInitialized = true
        C_Timer.After(0.3, function()
            ns:EnsureChatTab()
            ns:Print("Loaded v" .. ns.version .. ". Type |cffffd200/oo|r for options.")
        end)
    end
    ns:UpdateBlizzardTracker()
    ns:RequestTrackerUpdate()
end

function events.QUEST_LOG_UPDATE()
    ns:RequestTrackerUpdate()
end

function events.QUEST_WATCH_LIST_CHANGED()
    ns:RequestTrackerUpdate()
end

function events.QUEST_ACCEPTED()
    ns:RequestTrackerUpdate()
end

function events.QUEST_REMOVED()
    ns:RequestTrackerUpdate()
end

function events.SUPER_TRACKING_CHANGED()
    ns:RequestTrackerUpdate()
end

function events.ZONE_CHANGED_NEW_AREA()
    ns:RequestTrackerUpdate()
end

function events.ZONE_CHANGED()
    ns:RequestTrackerUpdate()
end

function events.ZONE_CHANGED_INDOORS()
    ns:RequestTrackerUpdate()
end

function events.TRACKED_RECIPE_UPDATE()
    ns:RequestTrackerUpdate()
end

function events.BAG_UPDATE()
    ns:RequestTrackerUpdate()
end

function events.BAG_UPDATE_COOLDOWN()
    if ns.Tracker and ns.Tracker.UpdateCooldowns then
        ns.Tracker:UpdateCooldowns()
    end
end

function events.PLAYER_REGEN_ENABLED()
    if pendingBlizzUpdate then
        pendingBlizzUpdate = false
        ns:UpdateBlizzardTracker()
    end
    if ns.Tracker and ns.Tracker.FlushCombatQueue then
        ns.Tracker:FlushCombatQueue()
    end
end

for eventName in pairs(events) do
    eventFrame:RegisterEvent(eventName)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = events[event]
    if handler then
        handler(...)
    end
end)
