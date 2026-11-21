--[[
    OneObjective - TimerFrame.lua
    Standalone movable Quest Timer frame (mirroring Quest Name, Objectives,
    and live countdown bar) plus shared live ticker for inline & standalone timers.
--]]

local addonName, ns = ...

ns.TimerFrame = {}
local TimerFrame = ns.TimerFrame

local timerFrame
local headerFrame
local headerTitle
local previewBadge
local blockPool = {}
local activeBlocks = {}
local activeTimedQuests = {}
local previewMode = false

local tickerFrame = CreateFrame("Frame")
local tickerAccum = 0
local tickerRunning = false

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
function TimerFrame:FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local hrs = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hrs > 0 then
        return string.format("%d:%02d:%02d", hrs, mins, secs)
    end
    return string.format("%d:%02d", mins, secs)
end

function TimerFrame:GetRemaining(timer)
    if not timer then return 0, 1 end
    local elapsed = (timer.elapsed or 0) + (GetTime() - (timer.fetchedAt or GetTime()))
    local remaining = math.max(0, (timer.total or 0) - elapsed)
    return remaining, math.max(1, timer.total or 1)
end

function TimerFrame:GetBarColor(remaining, total)
    local pct = (total > 0) and (remaining / total) or 0
    if remaining <= 60 or pct <= 0.15 then
        return 0.95, 0.22, 0.20
    elseif pct <= 0.35 then
        return 0.95, 0.65, 0.15
    end
    return 0.25, 0.80, 0.35
end

local function ApplyHorizontalGradient(tex, r1, g1, b1, a1, r2, g2, b2, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    else
        tex:SetColorTexture(r1, g1, b1, a1)
    end
end

local function GetQuestTitleColor(level, isComplete)
    if isComplete then
        return 0.25, 0.90, 0.25
    end
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if c then
            return c.r, c.g, c.b
        end
    end
    return 1.0, 0.82, 0.0
end

local function GetScaledSizes()
    local s = (OneObjectiveDB and OneObjectiveDB.fontScale) or 1.0
    local fontPath = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    return {
        fontPath = fontPath,
        sectionFont = math.floor(15 * s + 0.5),
        titleFont = math.floor(12.5 * s + 0.5),
        objFont = math.floor(11.5 * s + 0.5),
        headerHeight = math.max(24, math.floor(24 * s + 0.5)),
        barHeight = math.max(14, math.floor(14 * s + 0.5)),
    }
end

-------------------------------------------------------------------------------
-- Block Pool
-------------------------------------------------------------------------------
local function AcquireBlock(index)
    local b = blockPool[index]
    if b then
        b:Show()
        return b
    end

    b = CreateFrame("Frame", nil, timerFrame)
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -2)
    title:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -2)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    b.title = title

    b.objLines = {}

    local bar = CreateFrame("StatusBar", nil, b, "BackdropTemplate")
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bar:SetBackdropColor(0.05, 0.05, 0.07, 0.85)
    bar:SetBackdropBorderColor(0.45, 0.40, 0.25, 0.8)

    local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.text = barText
    b.bar = bar

    blockPool[index] = b
    return b
end

local function GetObjLine(block, idx)
    local fs = block.objLines[idx]
    if fs then
        fs:Show()
        return fs
    end
    fs = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    block.objLines[idx] = fs
    return fs
end

-------------------------------------------------------------------------------
-- Position & Live Ticker
-------------------------------------------------------------------------------
function TimerFrame:ApplyPosition()
    if not timerFrame then return end
    timerFrame:ClearAllPoints()
    local pos = OneObjectiveDB and OneObjectiveDB.timerPosition
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        timerFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        timerFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
end

function TimerFrame:SavePosition()
    if not timerFrame or not OneObjectiveDB then return end
    local point, _, relPoint, x, y = timerFrame:GetPoint()
    if point and relPoint and x and y then
        OneObjectiveDB.timerPosition = {
            point = point,
            relPoint = relPoint,
            x = x,
            y = y,
        }
    end
end

function TimerFrame:UpdateLiveTimers()
    for _, b in ipairs(activeBlocks) do
        if b.timerData and b.bar then
            local rem, total = self:GetRemaining(b.timerData)
            local r, g, bl = self:GetBarColor(rem, total)
            b.bar:SetMinMaxValues(0, total)
            b.bar:SetValue(rem)
            b.bar:SetStatusBarColor(r, g, bl)
            b.bar.text:SetText("Time Remaining: " .. self:FormatTime(rem))
        end
    end
    if ns.Tracker and ns.Tracker.UpdateInlineTimers then
        ns.Tracker:UpdateInlineTimers()
    end
end

local function SetTickerActive(active)
    if active and not tickerRunning then
        tickerRunning = true
        tickerAccum = 0
        tickerFrame:SetScript("OnUpdate", function(_, elapsed)
            tickerAccum = tickerAccum + elapsed
            if tickerAccum >= 0.25 then
                tickerAccum = 0
                TimerFrame:UpdateLiveTimers()
            end
        end)
    elseif not active and tickerRunning then
        tickerRunning = false
        tickerFrame:SetScript("OnUpdate", nil)
    end
end

function TimerFrame:TogglePreview()
    previewMode = not previewMode
    if previewMode and OneObjectiveDB and not OneObjectiveDB.standaloneQuestTimer then
        OneObjectiveDB.standaloneQuestTimer = true
        ns:Print("Enabled Standalone Quest Timer mode for preview.")
    end
    if ns.Tracker and ns.Tracker.Refresh then
        ns.Tracker:Refresh()
    end
    ns:Print("Standalone timer preview " .. (previewMode and "|cff66ff66shown|r (drag to move)." or "|cffff6666hidden|r."))
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
function TimerFrame:Refresh(timedQuests)
    activeTimedQuests = timedQuests or {}
    if not timerFrame then return end

    local db = OneObjectiveDB or ns.defaults
    local hasInline = (not db.standaloneQuestTimer) and (#activeTimedQuests > 0)
    local showStandalone = db.standaloneQuestTimer and (#activeTimedQuests > 0 or previewMode)

    SetTickerActive(hasInline or showStandalone)

    if not showStandalone then
        timerFrame:Hide()
        return
    end

    local sizes = GetScaledSizes()
    local width = db.width or 250
    timerFrame:SetScale(db.scale or 1.0)
    timerFrame:SetWidth(width)
    headerFrame:SetHeight(sizes.headerHeight)
    headerTitle:SetFont(sizes.fontPath, sizes.sectionFont, "")

    if previewMode and #activeTimedQuests == 0 then
        previewBadge:Show()
    else
        previewBadge:Hide()
    end

    local list = activeTimedQuests
    if #list == 0 and previewMode then
        list = {
            {
                title = "Timed Quest Preview",
                level = 20,
                isComplete = false,
                objectives = {
                    { text = "0/1 Urgent Objective", finished = false },
                },
                timer = { total = 900, elapsed = 30, fetchedAt = GetTime() },
            },
        }
    end

    for _, b in ipairs(activeBlocks) do
        b:Hide()
        for _, fs in ipairs(b.objLines) do
            fs:Hide()
        end
    end
    wipe(activeBlocks)

    local y = sizes.headerHeight + 4
    local contentWidth = width - 12

    for idx, q in ipairs(list) do
        local b = AcquireBlock(idx)
        table.insert(activeBlocks, b)

        b.timerData = q.timer
        b:SetWidth(contentWidth)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", timerFrame, "TOPLEFT", 6, -y)

        local titleStr = q.title
        if db.showQuestLevels and q.level and q.level > 0 then
            titleStr = string.format("[%d] %s", q.level, titleStr)
        end
        b.title:SetFont(sizes.fontPath, sizes.titleFont, "")
        b.title:SetWidth(contentWidth - 12)
        b.title:SetText(titleStr)
        local r, g, bl = GetQuestTitleColor(q.level, q.isComplete)
        b.title:SetTextColor(r, g, bl)

        local blockY = 2 + (b.title:GetStringHeight() or sizes.titleFont) + 3

        if q.objectives then
            for lineIdx, obj in ipairs(q.objectives) do
                if obj.text and obj.text ~= "" then
                    local fs = GetObjLine(b, lineIdx)
                    fs:SetFont(sizes.fontPath, sizes.objFont, "")
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -blockY)
                    fs:SetWidth(contentWidth - 18)
                    fs:SetText("- " .. obj.text)
                    if obj.finished then
                        fs:SetTextColor(0.55, 0.85, 0.55)
                    else
                        fs:SetTextColor(0.88, 0.88, 0.88)
                    end
                    blockY = blockY + (fs:GetStringHeight() or sizes.objFont) + 2
                end
            end
        end

        blockY = blockY + 2
        b.bar:ClearAllPoints()
        b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -blockY)
        b.bar:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -blockY)
        b.bar:SetHeight(sizes.barHeight)
        b.bar.text:SetFont(sizes.fontPath, math.max(10, sizes.objFont - 1), "OUTLINE")

        local blockH = blockY + sizes.barHeight + 6
        b:SetHeight(blockH)
        y = y + blockH + 4
    end

    timerFrame:SetHeight(y + 4)
    timerFrame:Show()
    self:UpdateLiveTimers()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
function TimerFrame:Init()
    if timerFrame then return end

    timerFrame = CreateFrame("Frame", "OneObjectiveTimerFrame", UIParent, "BackdropTemplate")
    timerFrame:SetSize(250, 100)
    timerFrame:SetClampedToScreen(true)
    timerFrame:SetMovable(true)
    timerFrame:EnableMouse(true)
    timerFrame:RegisterForDrag("LeftButton")
    timerFrame:SetFrameStrata("MEDIUM")

    timerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    timerFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.65)
    timerFrame:SetBackdropBorderColor(0.55, 0.45, 0.20, 0.75)

    timerFrame:SetScript("OnDragStart", function(self)
        if OneObjectiveDB and not OneObjectiveDB.locked then
            self:StartMoving()
        end
    end)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        TimerFrame:SavePosition()
    end)

    headerFrame = CreateFrame("Frame", nil, timerFrame)
    headerFrame:SetHeight(24)
    headerFrame:SetPoint("TOPLEFT", timerFrame, "TOPLEFT", 2, -2)
    headerFrame:SetPoint("TOPRIGHT", timerFrame, "TOPRIGHT", -2, -2)

    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    ApplyHorizontalGradient(headerBg, 0.06, 0.05, 0.03, 0.78, 0.0, 0.0, 0.0, 0.0)

    local headerLine = headerFrame:CreateTexture(nil, "BORDER")
    headerLine:SetHeight(1)
    headerLine:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
    ApplyHorizontalGradient(headerLine, 0.65, 0.50, 0.18, 0.85, 0.25, 0.18, 0.06, 0.0)

    headerTitle = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("LEFT", headerFrame, "LEFT", 6, 0)
    headerTitle:SetTextColor(1.0, 0.82, 0.0)
    headerTitle:SetText("Quest Timer")

    previewBadge = CreateFrame("Button", nil, headerFrame)
    previewBadge:SetSize(48, 16)
    previewBadge:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
    local pfs = previewBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pfs:SetPoint("CENTER")
    pfs:SetText("[Close]")
    pfs:SetTextColor(1.0, 0.55, 0.55)
    previewBadge:SetFontString(pfs)
    previewBadge:SetScript("OnClick", function()
        previewMode = false
        TimerFrame:Refresh(activeTimedQuests)
    end)
    previewBadge:Hide()

    self:ApplyPosition()
    timerFrame:Hide()
end
