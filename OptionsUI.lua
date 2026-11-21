--[[
    OneObjective - OptionsUI.lua
    Graphical Configuration Panel for OneObjective.
    Supports standalone draggable window and Blizzard Settings registration.
--]]

local addonName, ns = ...

ns.OptionsUI = {}
local OptionsUI = ns.OptionsUI

local standaloneWindow = nil

local function CreateCheckbox(parent, label, getVal, setVal)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    if not cb.text then
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    end
    cb.text:SetText(label)

    cb:SetScript("OnShow", function(self)
        self:SetChecked(getVal() and true or false)
    end)
    cb:SetScript("OnClick", function(self)
        setVal(self:GetChecked() and true or false)
    end)
    return cb
end

local function CreateButton(parent, label, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 140, height or 24)
    btn:SetText(label)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateSlider(parent, label, minVal, maxVal, step, isPercent, getVal, setVal)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetWidth(210)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local title = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    title:SetText(label)
    slider.title = title

    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valText:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    slider.valText = valText

    local function UpdateDisplay(val)
        if isPercent then
            valText:SetText(string.format("%.0f%%", val * 100))
        else
            valText:SetText(string.format("%d", val))
        end
    end

    slider:SetScript("OnShow", function(self)
        local val = getVal() or minVal
        self:SetValue(val)
        UpdateDisplay(val)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value / step) + 0.5) * step
        UpdateDisplay(rounded)
        setVal(rounded)
    end)

    return slider
end

function OptionsUI:CreateStandaloneWindow()
    if standaloneWindow then return standaloneWindow end

    local frame = CreateFrame("Frame", "OneObjectiveOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(370, 666)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        OneObjectiveDB = OneObjectiveDB or {}
        OneObjectiveDB.optionsPosition = {
            point = point,
            relPoint = relPoint,
            x = xOfs,
            y = yOfs,
        }
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.10, 0.96)

    if OneObjectiveDB and OneObjectiveDB.optionsPosition then
        local p = OneObjectiveDB.optionsPosition
        frame:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("OneObjective Options")
    title:SetTextColor(1.0, 0.82, 0.0)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local y = -50

    local function AddCheckbox(label, getVal, setVal)
        local cb = CreateCheckbox(frame, label, getVal, setVal)
        cb:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)
        y = y - 28
        return cb
    end

    AddCheckbox("Hide Blizzard Default Tracker",
        function() return OneObjectiveDB and OneObjectiveDB.hideBlizzardTracker end,
        function(val)
            OneObjectiveDB.hideBlizzardTracker = val
            ns:UpdateBlizzardTracker()
        end)

    AddCheckbox("Lock Tracker Position",
        function() return OneObjectiveDB and OneObjectiveDB.locked end,
        function(val)
            OneObjectiveDB.locked = val
            if ns.Tracker and ns.Tracker.UpdateLockState then
                ns.Tracker:UpdateLockState()
            end
        end)

    AddCheckbox("Show Only Watched Quests",
        function() return OneObjectiveDB and (OneObjectiveDB.showOnlyWatched ~= false) end,
        function(val)
            OneObjectiveDB.showOnlyWatched = val
            ns:RequestTrackerUpdate()
        end)

    AddCheckbox("Sort Current Zone First",
        function() return OneObjectiveDB and (OneObjectiveDB.sortCurrentZoneFirst ~= false) end,
        function(val)
            OneObjectiveDB.sortCurrentZoneFirst = val
            ns:RequestTrackerUpdate()
        end)

    AddCheckbox("Show Quest Levels",
        function() return OneObjectiveDB and (OneObjectiveDB.showQuestLevels ~= false) end,
        function(val)
            OneObjectiveDB.showQuestLevels = val
            ns:RequestTrackerUpdate()
        end)

    AddCheckbox("Standalone Quest Timer Frame",
        function() return OneObjectiveDB and OneObjectiveDB.standaloneQuestTimer end,
        function(val)
            OneObjectiveDB.standaloneQuestTimer = val
            ns:RequestTrackerUpdate()
        end)

    AddCheckbox("Route Messages to 'OneAddon' Chat Tab",
        function() return OneObjectiveDB and (OneObjectiveDB.routeToOneAddonTab ~= false) end,
        function(val)
            OneObjectiveDB.routeToOneAddonTab = val
        end)

    -- Quest Item Button Side Selector
    y = y - 8
    local sideLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sideLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, y)
    sideLabel:SetText("Quest Item Button Side:")
    y = y - 22

    local leftSideBtn, rightSideBtn
    local function RefreshSideButtons()
        local side = (OneObjectiveDB and OneObjectiveDB.questItemSide) or "RIGHT"
        if side == "LEFT" then
            leftSideBtn:Disable()
            rightSideBtn:Enable()
        else
            leftSideBtn:Enable()
            rightSideBtn:Disable()
        end
    end

    leftSideBtn = CreateButton(frame, "Left Side", 120, 24, function()
        OneObjectiveDB.questItemSide = "LEFT"
        RefreshSideButtons()
        ns:RequestTrackerUpdate()
    end)
    leftSideBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, y)

    rightSideBtn = CreateButton(frame, "Right Side", 120, 24, function()
        OneObjectiveDB.questItemSide = "RIGHT"
        RefreshSideButtons()
        ns:RequestTrackerUpdate()
    end)
    rightSideBtn:SetPoint("LEFT", leftSideBtn, "RIGHT", 12, 0)

    frame:HookScript("OnShow", RefreshSideButtons)
    y = y - 46

    -- Sliders
    local sScale = CreateSlider(frame, "Tracker Scale", 0.70, 1.50, 0.05, true,
        function() return OneObjectiveDB and OneObjectiveDB.scale or 1.0 end,
        function(val)
            OneObjectiveDB.scale = val
            if ns.Tracker and ns.Tracker.ApplyAppearance then
                ns.Tracker:ApplyAppearance()
            end
        end)
    sScale:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, y)
    y = y - 46

    local sFontScale = CreateSlider(frame, "Text Size", 0.80, 1.60, 0.05, true,
        function() return OneObjectiveDB and OneObjectiveDB.fontScale or 1.0 end,
        function(val)
            OneObjectiveDB.fontScale = val
            ns:RequestTrackerUpdate()
        end)
    sFontScale:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, y)
    y = y - 46

    local sWidth = CreateSlider(frame, "Tracker Width", 200, 400, 10, false,
        function() return OneObjectiveDB and OneObjectiveDB.width or 250 end,
        function(val)
            OneObjectiveDB.width = val
            ns:RequestTrackerUpdate()
        end)
    sWidth:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, y)
    y = y - 46

    local sHeight = CreateSlider(frame, "Max Height", 200, 800, 20, false,
        function() return OneObjectiveDB and OneObjectiveDB.maxHeight or 460 end,
        function(val)
            OneObjectiveDB.maxHeight = val
            ns:RequestTrackerUpdate()
        end)
    sHeight:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, y)
    y = y - 46

    local sAlpha = CreateSlider(frame, "Background Opacity", 0.0, 0.95, 0.05, true,
        function() return OneObjectiveDB and OneObjectiveDB.bgAlpha or 0.0 end,
        function(val)
            OneObjectiveDB.bgAlpha = val
            if ns.Tracker and ns.Tracker.ApplyAppearance then
                ns.Tracker:ApplyAppearance()
            end
        end)
    sAlpha:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, y)
    y = y - 40

    -- Action Buttons
    local collapseBtn = CreateButton(frame, "Collapse All", 100, 24, function()
        if ns.Tracker and ns.Tracker.SetAllCollapsed then
            ns.Tracker:SetAllCollapsed(true)
        end
    end)
    collapseBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, y)

    local expandBtn = CreateButton(frame, "Expand All", 100, 24, function()
        if ns.Tracker and ns.Tracker.SetAllCollapsed then
            ns.Tracker:SetAllCollapsed(false)
        end
    end)
    expandBtn:SetPoint("LEFT", collapseBtn, "RIGHT", 8, 0)

    local resetBtn = CreateButton(frame, "Reset Pos", 100, 24, function()
        OneObjectiveDB.position = nil
        if ns.Tracker and ns.Tracker.ApplyPosition then
            ns.Tracker:ApplyPosition()
        end
        ns:Print("Tracker position reset.")
    end)
    resetBtn:SetPoint("LEFT", expandBtn, "RIGHT", 8, 0)

    local previewTimerBtn = CreateButton(frame, "Preview Timer", 150, 24, function()
        if ns.TimerFrame and ns.TimerFrame.TogglePreview then
            ns.TimerFrame:TogglePreview()
        end
    end)
    previewTimerBtn:SetPoint("TOPLEFT", collapseBtn, "BOTTOMLEFT", 0, -8)

    local resetTimerBtn = CreateButton(frame, "Reset Timer Pos", 150, 24, function()
        OneObjectiveDB.timerPosition = nil
        if ns.TimerFrame and ns.TimerFrame.ApplyPosition then
            ns.TimerFrame:ApplyPosition()
        end
        ns:Print("Standalone timer position reset.")
    end)
    resetTimerBtn:SetPoint("LEFT", previewTimerBtn, "RIGHT", 10, 0)

    frame:Hide()
    standaloneWindow = frame
    return frame
end

function OptionsUI:Toggle()
    local win = self:CreateStandaloneWindow()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
    end
end

function OptionsUI:Init()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel = CreateFrame("Frame", "OneObjectiveSettingsPanel", UIParent)
        panel.name = "OneObjective"

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("OneObjective")

        local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        desc:SetText("Zone-grouped collapsible Objective Tracker with Left/Right Quest Item placement.")

        local openBtn = CreateButton(panel, "Open OneObjective Options", 200, 28, function()
            OptionsUI:Toggle()
        end)
        openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)

        local category = Settings.RegisterCanvasLayoutCategory(panel, "OneObjective")
        Settings.RegisterAddOnCategory(category)
    end
end
