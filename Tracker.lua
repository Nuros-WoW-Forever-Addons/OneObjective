--[[
    OneObjective - Tracker.lua
    Blizzard-styled, frameless, zone-grouped Objective Tracker with collapsible
    Quests, Zone, & Professions headers, proportional text scaling, circular POI
    super-track badges, and taint-safe SecureActionButtonTemplate quest item buttons.
--]]

local addonName, ns = ...

ns.Tracker = {}
local Tracker = ns.Tracker

local PAD_X = 6
local PAD_Y = 4
local QUEST_TITLE_GAP = 2
local OBJECTIVE_GAP = 2
local QUEST_BLOCK_GAP = 6
local ITEM_BTN_SIZE = 26

local mainFrame
local headerFrame
local headerTitle
local minimizeAllBtn
local lockBtn
local optBtn
local scrollFrame
local scrollContent
local emptyText

local zoneHeaderPool = {}
local questBlockPool = {}
local itemButtonPool = {}

local activeZoneHeaders = {}
local activeQuestBlocks = {}
local activeItemData = {}
local pendingCombatUpdate = false
local lastGroups = {}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function GetFontScale()
    local fs = OneObjectiveDB and OneObjectiveDB.fontScale
    return fs or 1.0
end

local function GetScaledSizes()
    local s = GetFontScale()
    local fontPath = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    return {
        fontPath = fontPath,
        sectionFont = math.floor(15 * s + 0.5),
        zoneFont = math.floor(13.5 * s + 0.5),
        titleFont = math.floor(12.5 * s + 0.5),
        objFont = math.floor(11.5 * s + 0.5),
        headerHeight = math.max(24, math.floor(24 * s + 0.5)),
        sectionHeight = math.max(22, math.floor(22 * s + 0.5)),
        zoneHeight = math.max(20, math.floor(20 * s + 0.5)),
        poiSize = math.max(22, math.floor(24 * s + 0.5)),
    }
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

local function UpdateItemButtonCooldown(btn)
    if not btn or not btn.cooldown or not btn.questLogIndex then return end
    if GetQuestLogSpecialItemCooldown then
        local start, duration, enable = GetQuestLogSpecialItemCooldown(btn.questLogIndex)
        if start and duration and duration > 0 and enable == 1 then
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown:Show()
            return
        end
    end
    btn.cooldown:Hide()
end

local function ApplyHorizontalGradient(tex, r1, g1, b1, a1, r2, g2, b2, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    else
        tex:SetColorTexture(r1, g1, b1, a1)
    end
end

local function CopyBlizzardMinimizeStyle(btn, blizzBtn)
    if not blizzBtn then return false end
    local norm = blizzBtn.GetNormalTexture and blizzBtn:GetNormalTexture()
    local push = blizzBtn.GetPushedTexture and blizzBtn:GetPushedTexture()
    local hl = blizzBtn.GetHighlightTexture and blizzBtn:GetHighlightTexture()

    local normAtlas = norm and norm.GetAtlas and norm:GetAtlas()
    if normAtlas and normAtlas ~= "" and btn.SetNormalAtlas then
        btn:SetNormalAtlas(normAtlas)
        local pushAtlas = push and push.GetAtlas and push:GetAtlas()
        if pushAtlas and pushAtlas ~= "" and btn.SetPushedAtlas then
            btn:SetPushedAtlas(pushAtlas)
        end
        local hlAtlas = hl and hl.GetAtlas and hl:GetAtlas()
        if hlAtlas and hlAtlas ~= "" and btn.SetHighlightAtlas then
            btn:SetHighlightAtlas(hlAtlas)
        end
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Pools
-------------------------------------------------------------------------------
local function AcquireHeader(index)
    local btn = zoneHeaderPool[index]
    if btn then
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, scrollContent)
    btn:RegisterForClicks("LeftButtonUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    btn.bg = bg

    local line = btn:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.line = line

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    ApplyHorizontalGradient(hl, 1.0, 0.82, 0.0, 0.10, 1.0, 0.82, 0.0, 0.0)

    local minText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    minText:SetPoint("RIGHT", btn, "RIGHT", -6, 1)
    minText:SetWidth(16)
    minText:SetJustifyH("CENTER")
    minText:SetTextColor(1.0, 0.82, 0.0)
    btn.minText = minText

    local titleText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", btn, "LEFT", 6, 0)
    titleText:SetPoint("RIGHT", minText, "LEFT", -4, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    btn.titleText = titleText

    btn:SetScript("OnClick", function(self)
        if not self.collapseKey or not OneObjectiveDB then return end
        local collapsed = OneObjectiveDB.collapsedZones
        collapsed[self.collapseKey] = not collapsed[self.collapseKey]
        Tracker:Refresh()
    end)

    zoneHeaderPool[index] = btn
    return btn
end

local function StyleHeader(btn, isSection, sizes)
    if isSection then
        btn:SetHeight(sizes.sectionHeight)
        ApplyHorizontalGradient(btn.bg, 0.06, 0.05, 0.03, 0.78, 0.0, 0.0, 0.0, 0.0)
        ApplyHorizontalGradient(btn.line, 0.65, 0.50, 0.18, 0.85, 0.25, 0.18, 0.06, 0.0)
        btn.titleText:SetFont(sizes.fontPath, sizes.sectionFont, "")
        btn.titleText:SetTextColor(1.0, 0.82, 0.0)
        btn.minText:SetFont(sizes.fontPath, sizes.sectionFont + 2, "")
    else
        btn:SetHeight(sizes.zoneHeight)
        ApplyHorizontalGradient(btn.bg, 0.08, 0.08, 0.10, 0.50, 0.0, 0.0, 0.0, 0.0)
        ApplyHorizontalGradient(btn.line, 0.45, 0.38, 0.22, 0.45, 0.15, 0.12, 0.06, 0.0)
        btn.titleText:SetFont(sizes.fontPath, sizes.zoneFont, "")
        btn.titleText:SetTextColor(0.95, 0.84, 0.45)
        btn.minText:SetFont(sizes.fontPath, sizes.zoneFont + 2, "")
    end
end

local function AcquireQuestBlock(index)
    local btn = questBlockPool[index]
    if btn then
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, scrollContent)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1.0, 1.0, 1.0, 0.05)

    local poi = CreateFrame("Frame", nil, btn)
    poi:SetSize(18, 18)
    poi:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -1)

    local poiGlow = poi:CreateTexture(nil, "BACKGROUND")
    poiGlow:SetPoint("CENTER")
    poiGlow:SetSize(26, 26)
    poiGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    poiGlow:SetBlendMode("ADD")
    poiGlow:SetVertexColor(1.0, 0.85, 0.2, 0.9)
    poiGlow:Hide()
    poi.glow = poiGlow

    local poiBg = poi:CreateTexture(nil, "ARTWORK")
    poiBg:SetPoint("CENTER", poi, "CENTER", 0, 0)
    poiBg:SetSize(24, 24)
    poi.bg = poiBg

    local poiIcon = poi:CreateTexture(nil, "OVERLAY")
    poiIcon:SetPoint("CENTER", poi, "CENTER", 0, 0)
    poiIcon:SetSize(12, 12)
    poi.icon = poiIcon

    local poiText = poi:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    poiText:SetPoint("CENTER", poi, "CENTER", 0, 0)
    poiText:SetJustifyH("CENTER")
    poi.text = poiText

    btn.poi = poi

    local title = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", btn, "TOPLEFT", 25, -1)
    title:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -1)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    btn.title = title

    btn.objLines = {}

    local timerBar = CreateFrame("StatusBar", nil, btn, "BackdropTemplate")
    timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timerBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    timerBar:SetBackdropColor(0.05, 0.05, 0.07, 0.85)
    timerBar:SetBackdropBorderColor(0.45, 0.40, 0.25, 0.8)
    local timerText = timerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("CENTER", timerBar, "CENTER", 0, 0)
    timerBar.text = timerText
    timerBar:Hide()
    btn.timerBar = timerBar

    btn:SetScript("OnClick", function(self, mouseBtn)
        if self.isProfession then
            if mouseBtn == "LeftButton" and IsShiftKeyDown() then
                if C_TradeSkillUI and C_TradeSkillUI.SetRecipeTracked and self.recipeID then
                    C_TradeSkillUI.SetRecipeTracked(self.recipeID, false, self.isRecraft or false)
                end
            elseif mouseBtn == "LeftButton" and C_TradeSkillUI and C_TradeSkillUI.OpenRecipe and self.recipeID then
                C_TradeSkillUI.OpenRecipe(self.recipeID)
            end
            return
        end

        local questID = self.questID
        if not questID then return end

        if mouseBtn == "LeftButton" then
            if IsShiftKeyDown() then
                if C_QuestLog and C_QuestLog.RemoveQuestWatch then
                    C_QuestLog.RemoveQuestWatch(questID)
                end
            else
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                    local current = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
                    if current == questID then
                        C_SuperTrack.SetSuperTrackedQuestID(0)
                    else
                        C_SuperTrack.SetSuperTrackedQuestID(questID)
                    end
                end
            end
        elseif mouseBtn == "RightButton" then
            if QuestMapFrame_OpenToQuestDetails then
                QuestMapFrame_OpenToQuestDetails(questID)
            elseif ToggleQuestLog then
                ToggleQuestLog()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if self.isProfession then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.profName or "Recipe", 1, 0.82, 0)
            GameTooltip:AddLine("Left-Click: Open Recipe", 0.5, 0.8, 1.0)
            GameTooltip:AddLine("Shift+Left-Click: Untrack Recipe", 0.5, 0.8, 1.0)
            GameTooltip:Show()
            return
        end

        if not self.questData then return end
        local q = self.questData
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        local r, g, b = GetQuestTitleColor(q.level, q.isComplete)
        GameTooltip:AddLine(q.title, r, g, b, true)
        if self.zoneName then
            GameTooltip:AddLine(self.zoneName, 0.7, 0.7, 0.7)
        end
        if q.objectives and #q.objectives > 0 then
            GameTooltip:AddLine(" ")
            for _, obj in ipairs(q.objectives) do
                if obj.text and obj.text ~= "" then
                    if obj.finished then
                        GameTooltip:AddLine("- " .. obj.text, 0.4, 0.9, 0.4, true)
                    else
                        GameTooltip:AddLine("- " .. obj.text, 0.9, 0.9, 0.9, true)
                    end
                end
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Super-track quest", 0.5, 0.8, 1.0)
        GameTooltip:AddLine("Shift+Left-Click: Untrack quest", 0.5, 0.8, 1.0)
        GameTooltip:AddLine("Right-Click: Open in Quest Log", 0.5, 0.8, 1.0)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    questBlockPool[index] = btn
    return btn
end

local function GetObjectiveLine(block, lineIdx)
    local fs = block.objLines[lineIdx]
    if fs then
        fs:Show()
        return fs
    end
    fs = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    block.objLines[lineIdx] = fs
    return fs
end

local function AcquireItemButton(index)
    local btn = itemButtonPool[index]
    if btn then
        return btn
    end

    btn = CreateFrame("Button", "OneObjectiveItemButton" .. index, UIParent, "SecureActionButtonTemplate,BackdropTemplate")
    btn:SetSize(ITEM_BTN_SIZE, ITEM_BTN_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:RegisterForClicks("AnyUp", "AnyDown")

    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0, 0, 0, 0.85)
    btn:SetBackdropBorderColor(0.65, 0.55, 0.25, 1)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    btn.cooldown = cooldown

    local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.count = count

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(icon)
    hl:SetColorTexture(1, 1, 1, 0.25)

    btn:SetScript("OnEnter", function(self)
        local side = (OneObjectiveDB and OneObjectiveDB.questItemSide) or "RIGHT"
        GameTooltip:SetOwner(self, (side == "RIGHT") and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
        if self.questLogIndex and GameTooltip.SetQuestLogSpecialItem then
            GameTooltip:SetQuestLogSpecialItem(self.questLogIndex)
        elseif self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    itemButtonPool[index] = btn
    return btn
end

-------------------------------------------------------------------------------
-- Position & Styling
-------------------------------------------------------------------------------
function Tracker:ApplyPosition()
    if not mainFrame then return end
    mainFrame:ClearAllPoints()
    local pos = OneObjectiveDB and OneObjectiveDB.position
    if pos and pos.point and pos.relPoint and pos.x and pos.y then
        mainFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -220)
    end
end

function Tracker:SavePosition()
    if not mainFrame or not OneObjectiveDB then return end
    local uiW = UIParent:GetWidth()
    local uiH = UIParent:GetHeight()
    local left = mainFrame:GetLeft()
    local right = mainFrame:GetRight()
    local top = mainFrame:GetTop()
    if not (left and right and top and uiW and uiH) then return end

    local centerX = (left + right) / 2
    if centerX >= (uiW / 2) then
        OneObjectiveDB.position = {
            point = "TOPRIGHT",
            relPoint = "TOPRIGHT",
            x = right - uiW,
            y = top - uiH,
        }
    else
        OneObjectiveDB.position = {
            point = "TOPLEFT",
            relPoint = "TOPLEFT",
            x = left,
            y = top - uiH,
        }
    end
    self:ApplyPosition()
end

function Tracker:UpdateLockState()
    if not mainFrame or not lockBtn then return end
    local locked = OneObjectiveDB and OneObjectiveDB.locked
    if locked then
        lockBtn:SetText("L")
        lockBtn:GetFontString():SetTextColor(1.0, 0.45, 0.45)
    else
        lockBtn:SetText("U")
        lockBtn:GetFontString():SetTextColor(0.45, 1.0, 0.45)
    end
end

function Tracker:ApplyAppearance()
    if not mainFrame then return end
    local db = OneObjectiveDB or ns.defaults
    if not InCombatLockdown() then
        mainFrame:SetScale(db.scale or 1.0)
        mainFrame:SetWidth(db.width or 250)
    else
        pendingCombatUpdate = true
    end

    local sizes = GetScaledSizes()
    headerFrame:SetHeight(sizes.headerHeight)
    headerTitle:SetFont(sizes.fontPath, sizes.sectionFont, "")

    local alpha = db.bgAlpha or 0.0
    if alpha <= 0.01 then
        mainFrame:SetBackdropColor(0, 0, 0, 0)
        mainFrame:SetBackdropBorderColor(0, 0, 0, 0)
    else
        mainFrame:SetBackdropColor(0.05, 0.05, 0.07, alpha)
        mainFrame:SetBackdropBorderColor(0.45, 0.40, 0.25, math.min(1.0, alpha + 0.2))
    end
end

-------------------------------------------------------------------------------
-- Item Button Positioning (Respects Combat Lockdown & Scroll Offset)
-------------------------------------------------------------------------------
function Tracker:UpdateItemButtonsLayout()
    if InCombatLockdown() then
        pendingCombatUpdate = true
        return
    end

    local db = OneObjectiveDB or ns.defaults
    if db.allCollapsed then
        for _, btn in ipairs(itemButtonPool) do
            btn:Hide()
        end
        return
    end

    local sizes = GetScaledSizes()
    local side = db.questItemSide or "RIGHT"
    local scrollOffset = scrollFrame and scrollFrame:GetVerticalScroll() or 0
    local viewHeight = scrollFrame and scrollFrame:GetHeight() or 0

    for _, btn in ipairs(itemButtonPool) do
        btn:Hide()
    end

    for _, entry in ipairs(activeItemData) do
        local btn = entry.btn
        local relY = entry.questTopInContent - scrollOffset
        if relY >= -4 and relY <= (viewHeight - 14) then
            btn:SetScale(db.scale or 1.0)
            btn:ClearAllPoints()
            local yOffset = -(sizes.headerHeight + PAD_Y + relY)
            if side == "RIGHT" then
                btn:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 6, yOffset)
            else
                btn:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", -6, yOffset)
            end
            btn:Show()
        else
            btn:Hide()
        end
    end
end

function Tracker:UpdateCooldowns()
    for _, entry in ipairs(activeItemData) do
        UpdateItemButtonCooldown(entry.btn)
    end
end

function Tracker:FlushCombatQueue()
    if pendingCombatUpdate then
        pendingCombatUpdate = false
        self:Refresh()
    end
end

function Tracker:UpdateInlineTimers()
    if not ns.TimerFrame then return end
    for _, qb in ipairs(activeQuestBlocks) do
        if qb.timerData and qb.timerBar and qb.timerBar:IsShown() then
            local rem, total = ns.TimerFrame:GetRemaining(qb.timerData)
            local r, g, b = ns.TimerFrame:GetBarColor(rem, total)
            qb.timerBar:SetMinMaxValues(0, total)
            qb.timerBar:SetValue(rem)
            qb.timerBar:SetStatusBarColor(r, g, b)
            qb.timerBar.text:SetText("Time Remaining: " .. ns.TimerFrame:FormatTime(rem))
        end
    end
end

-------------------------------------------------------------------------------
-- Collapse / Expand All
-------------------------------------------------------------------------------
function Tracker:SetAllCollapsed(collapsed)
    if not OneObjectiveDB then return end
    for _, group in ipairs(lastGroups) do
        OneObjectiveDB.collapsedZones[group.zone] = collapsed and true or false
    end
    OneObjectiveDB.collapsedZones["__QUESTS__"] = collapsed and true or false
    OneObjectiveDB.collapsedZones["__PROFESSIONS__"] = collapsed and true or false
    self:Refresh()
end

-------------------------------------------------------------------------------
-- Refresh Layout
-------------------------------------------------------------------------------
local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function ConfigurePOIBadge(qb, questID, isComplete, isSuperTracked, poiSize)
    local poi = qb.poi
    poi:SetSize(poiSize, poiSize)
    if poi.glow then
        poi.glow:SetSize(poiSize + 10, poiSize + 10)
    end
    if not poi.bg then return end

    local bgSize = math.floor(poiSize * 1.45 + 0.5)
    poi.bg:SetSize(bgSize, bgSize)
    poi.bg:SetTexCoord(0, 1, 0, 1)
    poi.bg:SetVertexColor(1, 1, 1, 1)

    if isSuperTracked then
        poi.glow:Show()
        if HasAtlas("UI-QuestPoi-QuestNumber-SuperTracked") then
            poi.bg:SetAtlas("UI-QuestPoi-QuestNumber-SuperTracked", false)
        elseif HasAtlas("UI-QuestPoi-QuestNumber") then
            poi.bg:SetAtlas("UI-QuestPoi-QuestNumber", false)
        else
            poi.bg:SetTexture("Interface\\Common\\Indicator-Yellow")
            poi.bg:SetTexCoord(0.18, 0.82, 0.18, 0.82)
            poi.bg:SetVertexColor(1.0, 0.85, 0.15, 1.0)
        end
    else
        poi.glow:Hide()
        if HasAtlas("UI-QuestPoi-QuestNumber") then
            poi.bg:SetAtlas("UI-QuestPoi-QuestNumber", false)
        else
            poi.bg:SetTexture("Interface\\Common\\Indicator-Red")
            poi.bg:SetTexCoord(0.18, 0.82, 0.18, 0.82)
            poi.bg:SetVertexColor(0.55, 0.14, 0.12, 0.95)
        end
    end

    if isComplete then
        local turnInSize = math.floor(poiSize * 1.15 + 0.5)
        if HasAtlas("UI-QuestIcon-TurnIn-Normal") then
            poi.icon:SetAtlas("UI-QuestIcon-TurnIn-Normal", false)
            poi.icon:SetSize(turnInSize, turnInSize)
            poi.icon:Show()
            poi.text:SetText("")
        elseif HasAtlas("QuestTurnin") then
            poi.icon:SetAtlas("QuestTurnin", false)
            poi.icon:SetSize(turnInSize, turnInSize)
            poi.icon:Show()
            poi.text:SetText("")
        else
            poi.icon:Hide()
            poi.text:SetTextColor(1.0, 0.85, 0.2)
            poi.text:SetText("?")
        end
    else
        if HasAtlas("Quest-In-Progress-Icon-small") then
            poi.icon:SetAtlas("Quest-In-Progress-Icon-small", false)
            poi.icon:SetSize(math.floor(poiSize * 0.65 + 0.5), math.floor(poiSize * 0.65 + 0.5))
            poi.icon:Show()
            poi.text:SetText("")
        else
            poi.icon:Hide()
            poi.text:SetTextColor(isSuperTracked and 0.2 or 1.0, isSuperTracked and 0.12 or 0.85, isSuperTracked and 0.02 or 0.35)
            poi.text:SetText("•••")
        end
    end
end

function Tracker:Refresh()
    if not mainFrame then return end

    local db = OneObjectiveDB or ns.defaults
    local sizes = GetScaledSizes()
    self:ApplyAppearance()
    self:UpdateLockState()

    if db.allCollapsed then
        if minimizeAllBtn.fallbackText then
            minimizeAllBtn.fallbackText:SetText("+")
        end
        scrollFrame:Hide()
        if not InCombatLockdown() then
            mainFrame:SetHeight(sizes.headerHeight + 4)
        else
            pendingCombatUpdate = true
        end
        self:UpdateItemButtonsLayout()
        return
    else
        if minimizeAllBtn.fallbackText then
            minimizeAllBtn.fallbackText:SetText("-")
        end
        scrollFrame:Show()
    end

    local groups, totalQuests, timedQuests = ns.Data:GetGroupedQuests()
    local recipes = ns.Data:GetTrackedRecipes()
    lastGroups = groups

    for _, h in ipairs(activeZoneHeaders) do
        h:Hide()
    end
    wipe(activeZoneHeaders)

    for _, qb in ipairs(activeQuestBlocks) do
        qb:Hide()
        qb.timerData = nil
        if qb.timerBar then qb.timerBar:Hide() end
        for _, fs in ipairs(qb.objLines) do
            fs:Hide()
        end
    end
    wipe(activeQuestBlocks)

    if not InCombatLockdown() then
        for _, btn in ipairs(itemButtonPool) do
            btn:Hide()
        end
    else
        pendingCombatUpdate = true
    end
    wipe(activeItemData)

    local trackerWidth = db.width or 250
    local contentWidth = trackerWidth - (PAD_X * 2)
    scrollContent:SetWidth(contentWidth)

    local headerIdx = 0
    local questIdx = 0
    local itemIdx = 0
    local y = 0

    -- Top-level "Quests" collapsible section header
    if #groups > 0 then
        headerIdx = headerIdx + 1
        local questsHeader = AcquireHeader(headerIdx)
        table.insert(activeZoneHeaders, questsHeader)
        StyleHeader(questsHeader, true, sizes)

        local questsCollapsed = db.collapsedZones["__QUESTS__"] and true or false
        questsHeader.collapseKey = "__QUESTS__"
        questsHeader:SetWidth(contentWidth)
        questsHeader:ClearAllPoints()
        questsHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -y)
        questsHeader.minText:SetText(questsCollapsed and "+" or "-")
        questsHeader.titleText:SetText("Quests")

        y = y + sizes.sectionHeight + 4

        if not questsCollapsed then
            for _, group in ipairs(groups) do
                headerIdx = headerIdx + 1
                local zHeader = AcquireHeader(headerIdx)
                table.insert(activeZoneHeaders, zHeader)
                StyleHeader(zHeader, false, sizes)

                local isCollapsed = db.collapsedZones[group.zone] and true or false
                zHeader.collapseKey = group.zone
                zHeader:SetWidth(contentWidth - 6)
                zHeader:ClearAllPoints()
                zHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 6, -y)

                zHeader.minText:SetText(isCollapsed and "+" or "-")
                zHeader.titleText:SetText(group.zone)

                y = y + sizes.zoneHeight + 4

                if not isCollapsed then
                    for _, q in ipairs(group.quests) do
                        questIdx = questIdx + 1
                        local qb = AcquireQuestBlock(questIdx)
                        table.insert(activeQuestBlocks, qb)

                        local questTopY = y
                        qb.isProfession = false
                        qb.questID = q.questID
                        qb.questData = q
                        qb.zoneName = group.zone
                        qb:SetWidth(contentWidth - 6)
                        qb:ClearAllPoints()
                        qb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 6, -y)

                        qb.poi:Show()
                        ConfigurePOIBadge(qb, q.questID, q.isComplete, q.isSuperTracked, sizes.poiSize)

                        local titleStr = q.title
                        if db.showQuestLevels and q.level and q.level > 0 then
                            titleStr = string.format("[%d] %s", q.level, titleStr)
                        end

                        local titleOffsetX = sizes.poiSize + 7
                        qb.title:SetFont(sizes.fontPath, sizes.titleFont, "")
                        qb.title:SetPoint("TOPLEFT", qb, "TOPLEFT", titleOffsetX, -1)
                        qb.title:SetWidth((contentWidth - 6) - titleOffsetX - 4)
                        qb.title:SetText(titleStr)
                        local r, g, b = GetQuestTitleColor(q.level, q.isComplete)
                        qb.title:SetTextColor(r, g, b)

                        local titleHeight = qb.title:GetStringHeight() or sizes.titleFont
                        local blockY = math.max(sizes.poiSize + 2, 1 + titleHeight + QUEST_TITLE_GAP)

                        local lineIdx = 0
                        if q.objectives and #q.objectives > 0 then
                            for _, obj in ipairs(q.objectives) do
                                if obj.text and obj.text ~= "" then
                                    lineIdx = lineIdx + 1
                                    local fs = GetObjectiveLine(qb, lineIdx)
                                    fs:SetFont(sizes.fontPath, sizes.objFont, "")
                                    fs:ClearAllPoints()
                                    fs:SetPoint("TOPLEFT", qb, "TOPLEFT", titleOffsetX + 2, -blockY)
                                    fs:SetWidth((contentWidth - 6) - titleOffsetX - 6)
                                    fs:SetText("- " .. obj.text)
                                    if obj.finished then
                                        fs:SetTextColor(0.55, 0.85, 0.55)
                                    else
                                        fs:SetTextColor(0.88, 0.88, 0.88)
                                    end
                                    local lh = fs:GetStringHeight() or sizes.objFont
                                    blockY = blockY + lh + OBJECTIVE_GAP
                                end
                            end
                        elseif q.isComplete then
                            lineIdx = lineIdx + 1
                            local fs = GetObjectiveLine(qb, lineIdx)
                            fs:SetFont(sizes.fontPath, sizes.objFont, "")
                            fs:ClearAllPoints()
                            fs:SetPoint("TOPLEFT", qb, "TOPLEFT", titleOffsetX + 2, -blockY)
                            fs:SetWidth((contentWidth - 6) - titleOffsetX - 6)
                            fs:SetText("- Ready to turn in")
                            fs:SetTextColor(0.45, 0.95, 0.45)
                            local lh = fs:GetStringHeight() or sizes.objFont
                            blockY = blockY + lh + OBJECTIVE_GAP
                        end

                        if q.timer and not db.standaloneQuestTimer then
                            local barH = math.max(13, math.floor(13 * GetFontScale() + 0.5))
                            qb.timerData = q.timer
                            qb.timerBar:ClearAllPoints()
                            qb.timerBar:SetPoint("TOPLEFT", qb, "TOPLEFT", titleOffsetX + 2, -(blockY + 2))
                            qb.timerBar:SetPoint("TOPRIGHT", qb, "TOPRIGHT", -6, -(blockY + 2))
                            qb.timerBar:SetHeight(barH)
                            qb.timerBar.text:SetFont(sizes.fontPath, math.max(9, sizes.objFont - 2), "OUTLINE")
                            qb.timerBar:Show()
                            blockY = blockY + barH + 5
                        else
                            qb.timerData = nil
                            if qb.timerBar then qb.timerBar:Hide() end
                        end

                        local blockHeight = math.max(sizes.poiSize + 2, blockY + 2)
                        qb:SetHeight(blockHeight)

                        if q.specialItem then
                            if InCombatLockdown() then
                                pendingCombatUpdate = true
                            else
                                itemIdx = itemIdx + 1
                                local itemBtn = AcquireItemButton(itemIdx)
                                itemBtn:SetAttribute("type", "item")
                                if q.specialItem.itemID then
                                    itemBtn:SetAttribute("item", "item:" .. q.specialItem.itemID)
                                else
                                    itemBtn:SetAttribute("item", q.specialItem.link)
                                end

                                itemBtn.questLogIndex = q.specialItem.questLogIndex
                                itemBtn.itemLink = q.specialItem.link
                                if q.specialItem.icon then
                                    itemBtn.icon:SetTexture(q.specialItem.icon)
                                end
                                if q.specialItem.charges and q.specialItem.charges > 1 then
                                    itemBtn.count:SetText(tostring(q.specialItem.charges))
                                    itemBtn.count:Show()
                                else
                                    itemBtn.count:Hide()
                                end
                                UpdateItemButtonCooldown(itemBtn)

                                table.insert(activeItemData, {
                                    btn = itemBtn,
                                    questTopInContent = questTopY,
                                })
                            end
                        end

                        y = y + blockHeight + QUEST_BLOCK_GAP
                    end
                end
            end
        end
    end

    -- Top-level "Professions" section (stays visible even when Quests is collapsed)
    if #recipes > 0 then
        headerIdx = headerIdx + 1
        local pHeader = AcquireHeader(headerIdx)
        table.insert(activeZoneHeaders, pHeader)
        StyleHeader(pHeader, true, sizes)

        local isCollapsed = db.collapsedZones["__PROFESSIONS__"] and true or false
        pHeader.collapseKey = "__PROFESSIONS__"
        pHeader:SetWidth(contentWidth)
        pHeader:ClearAllPoints()
        pHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -y)
        pHeader.minText:SetText(isCollapsed and "+" or "-")
        pHeader.titleText:SetText("Professions")

        y = y + sizes.sectionHeight + 4

        if not isCollapsed then
            for _, rec in ipairs(recipes) do
                questIdx = questIdx + 1
                local rb = AcquireQuestBlock(questIdx)
                table.insert(activeQuestBlocks, rb)

                rb.isProfession = true
                rb.recipeID = rec.recipeID
                rb.isRecraft = rec.isRecraft
                rb.profName = rec.name
                rb:SetWidth(contentWidth)
                rb:ClearAllPoints()
                rb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -y)

                rb.poi:Hide()
                rb.title:SetFont(sizes.fontPath, sizes.titleFont, "")
                rb.title:SetPoint("TOPLEFT", rb, "TOPLEFT", 8, -1)
                rb.title:SetWidth(contentWidth - 12)
                rb.title:SetText(rec.name)
                rb.title:SetTextColor(1.0, 0.82, 0.0)

                local titleHeight = rb.title:GetStringHeight() or sizes.titleFont
                local blockY = 1 + titleHeight + QUEST_TITLE_GAP

                for lineIdx, reag in ipairs(rec.reagents) do
                    local fs = GetObjectiveLine(rb, lineIdx)
                    fs:SetFont(sizes.fontPath, sizes.objFont, "")
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", rb, "TOPLEFT", 14, -blockY)
                    fs:SetWidth(contentWidth - 18)
                    fs:SetText("- " .. reag.text)
                    if reag.finished then
                        fs:SetTextColor(0.55, 0.85, 0.55)
                    else
                        fs:SetTextColor(0.88, 0.88, 0.88)
                    end
                    local lh = fs:GetStringHeight() or sizes.objFont
                    blockY = blockY + lh + OBJECTIVE_GAP
                end

                local blockHeight = math.max(18, blockY + 2)
                rb:SetHeight(blockHeight)
                y = y + blockHeight + QUEST_BLOCK_GAP
            end
        end
    end

    if totalQuests == 0 and #recipes == 0 then
        emptyText:Show()
        y = 28
    else
        emptyText:Hide()
    end

    local contentHeight = math.max(24, y)
    scrollContent:SetHeight(contentHeight)

    local maxHeight = db.maxHeight or 460
    local maxScrollHeight = math.max(60, maxHeight - sizes.headerHeight - (PAD_Y * 2))
    local visibleScrollHeight = math.min(contentHeight, maxScrollHeight)

    scrollFrame:SetHeight(visibleScrollHeight)
    if not InCombatLockdown() then
        mainFrame:SetHeight(sizes.headerHeight + (PAD_Y * 2) + visibleScrollHeight)
    else
        pendingCombatUpdate = true
    end

    local maxScroll = math.max(0, contentHeight - visibleScrollHeight)
    if scrollFrame:GetVerticalScroll() > maxScroll then
        scrollFrame:SetVerticalScroll(maxScroll)
    end

    self:UpdateItemButtonsLayout()
    self:UpdateInlineTimers()
    if ns.TimerFrame and ns.TimerFrame.Refresh then
        ns.TimerFrame:Refresh(timedQuests)
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
function Tracker:Init()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "OneObjectiveFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(250, 200)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetFrameStrata("MEDIUM")

    mainFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    mainFrame:SetScript("OnDragStart", function(self)
        if OneObjectiveDB and not OneObjectiveDB.locked then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Tracker:SavePosition()
    end)

    headerFrame = CreateFrame("Frame", nil, mainFrame)
    headerFrame:SetHeight(24)
    headerFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 2, -2)
    headerFrame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)
    headerFrame:EnableMouse(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnDragStart", function()
        if OneObjectiveDB and not OneObjectiveDB.locked then
            mainFrame:StartMoving()
        end
    end)
    headerFrame:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        Tracker:SavePosition()
    end)
    headerFrame:SetScript("OnMouseUp", function(_, mouseBtn)
        if mouseBtn == "RightButton" and ns.OptionsUI and ns.OptionsUI.Toggle then
            ns.OptionsUI:Toggle()
        end
    end)

    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    ApplyHorizontalGradient(headerBg, 0.05, 0.04, 0.02, 0.55, 0.0, 0.0, 0.0, 0.0)

    local headerLine = headerFrame:CreateTexture(nil, "BORDER")
    headerLine:SetHeight(1)
    headerLine:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", 0, 0)
    ApplyHorizontalGradient(headerLine, 0.65, 0.50, 0.18, 0.85, 0.35, 0.25, 0.08, 0.15)

    headerTitle = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("LEFT", headerFrame, "LEFT", 6, 0)
    headerTitle:SetTextColor(1.0, 0.82, 0.0)
    headerTitle:SetText("All Objectives")

    minimizeAllBtn = CreateFrame("Button", nil, headerFrame, "BackdropTemplate")
    minimizeAllBtn:SetSize(16, 16)
    minimizeAllBtn:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
    local blizzMin = _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Header and _G.ObjectiveTrackerFrame.Header.MinimizeButton
    if not CopyBlizzardMinimizeStyle(minimizeAllBtn, blizzMin) then
        minimizeAllBtn:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        minimizeAllBtn:SetBackdropColor(0.55, 0.12, 0.10, 0.95)
        minimizeAllBtn:SetBackdropBorderColor(0.85, 0.70, 0.25, 1.0)
        local fs = minimizeAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER", 0, 1)
        fs:SetTextColor(1.0, 0.85, 0.25)
        fs:SetText("-")
        minimizeAllBtn.fallbackText = fs
    end
    minimizeAllBtn:SetScript("OnClick", function()
        if OneObjectiveDB then
            OneObjectiveDB.allCollapsed = not OneObjectiveDB.allCollapsed
            Tracker:Refresh()
        end
    end)
    minimizeAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Collapse / Expand All Objectives", 1, 1, 1)
        GameTooltip:AddLine("Right-Click header for Options (/oo)", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimizeAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function CreateSubtleBtn(label, width, tooltipText, onClick)
        local b = CreateFrame("Button", nil, headerFrame)
        b:SetSize(width, 16)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetText(label)
        b:SetFontString(fs)
        b:SetAlpha(0.0)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            self:SetAlpha(1.0)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if not headerFrame:IsMouseOver() then
                optBtn:SetAlpha(0.0)
                lockBtn:SetAlpha(0.0)
            end
        end)
        return b
    end

    optBtn = CreateSubtleBtn("Opt", 24, "Open OneObjective Options (/oo)", function()
        if ns.OptionsUI and ns.OptionsUI.Toggle then
            ns.OptionsUI:Toggle()
        end
    end)
    optBtn:SetPoint("RIGHT", minimizeAllBtn, "LEFT", -4, 0)

    lockBtn = CreateSubtleBtn("U", 16, "Lock / Unlock Tracker Position", function()
        if OneObjectiveDB then
            OneObjectiveDB.locked = not OneObjectiveDB.locked
            Tracker:UpdateLockState()
        end
    end)
    lockBtn:SetPoint("RIGHT", optBtn, "LEFT", -2, 0)

    headerFrame:SetScript("OnEnter", function()
        optBtn:SetAlpha(0.85)
        lockBtn:SetAlpha(0.85)
    end)
    headerFrame:SetScript("OnLeave", function()
        if not optBtn:IsMouseOver() and not lockBtn:IsMouseOver() then
            optBtn:SetAlpha(0.0)
            lockBtn:SetAlpha(0.0)
        end
    end)

    scrollFrame = CreateFrame("ScrollFrame", "OneObjectiveScrollFrame", mainFrame)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", PAD_X - 2, -PAD_Y)
    scrollFrame:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", -(PAD_X - 2), -PAD_Y)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(230, 100)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(0, scrollContent:GetHeight() - self:GetHeight())
        local nextVal = math.max(0, math.min(maxScroll, current - (delta * 24)))
        self:SetVerticalScroll(nextVal)
        Tracker:UpdateItemButtonsLayout()
    end)

    emptyText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 6, -6)
    emptyText:SetText("No tracked objectives.")
    emptyText:Hide()

    self:ApplyPosition()
    self:Refresh()
end
