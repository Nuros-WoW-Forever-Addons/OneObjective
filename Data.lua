--[[
    OneObjective - Data.lua
    Quest Log & Quest Watch Scanner, Zone Grouping, Sorting,
    Objective Parsing, and Quest Special Item Extraction.
--]]

local addonName, ns = ...

ns.Data = {}
local Data = ns.Data

function Data:GetCurrentZoneName()
    local zone = GetRealZoneText and GetRealZoneText()
    if zone and zone ~= "" then
        return zone
    end
    zone = GetZoneText and GetZoneText()
    if zone and zone ~= "" then
        return zone
    end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo and mapInfo.name then
                return mapInfo.name
            end
        end
    end
    return ""
end

local function BuildWatchedSet()
    local watched = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex) then
        return watched
    end
    local numWatches = C_QuestLog.GetNumQuestWatches() or 0
    for i = 1, numWatches do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            watched[questID] = true
        end
    end
    return watched
end

local function ExtractSpecialItem(questLogIndex, isComplete)
    if not GetQuestLogSpecialItemInfo then
        return nil
    end
    local link, icon, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex)
    if not link then
        return nil
    end
    if isComplete and not showItemWhenComplete then
        return nil
    end
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    return {
        link = link,
        itemID = itemID,
        icon = icon,
        charges = charges or 0,
        questLogIndex = questLogIndex,
    }
end

function Data:GetGroupedQuests()
    local groups = {}
    local zonesByName = {}
    local db = OneObjectiveDB or ns.defaults
    local onlyWatched = db.showOnlyWatched ~= false
    local watched = onlyWatched and BuildWatchedSet() or nil

    local superTrackedID = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
        and C_SuperTrack.GetSuperTrackedQuestID() or nil

    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
        return groups, 0
    end

    local currentZoneHeader = "Other Quests"
    local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    local totalQuests = 0

    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                currentZoneHeader = info.title or "Other Quests"
            elseif not info.isHidden and info.questID then
                local questID = info.questID
                if (not onlyWatched) or (watched and watched[questID]) then
                    local isComplete = info.isComplete
                    if C_QuestLog.IsComplete then
                        local apiComplete = C_QuestLog.IsComplete(questID)
                        if apiComplete ~= nil then
                            isComplete = apiComplete
                        end
                    end

                    local objectives = (C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)) or {}
                    local specialItem = ExtractSpecialItem(i, isComplete)

                    local group = zonesByName[currentZoneHeader]
                    if not group then
                        group = {
                            zone = currentZoneHeader,
                            quests = {},
                        }
                        zonesByName[currentZoneHeader] = group
                        table.insert(groups, group)
                    end

                    table.insert(group.quests, {
                        questID = questID,
                        questLogIndex = i,
                        title = info.title or ("Quest " .. tostring(questID)),
                        level = info.level or 0,
                        isComplete = isComplete and true or false,
                        isSuperTracked = (superTrackedID == questID),
                        objectives = objectives,
                        specialItem = specialItem,
                    })
                    totalQuests = totalQuests + 1
                end
            end
        end
    end

    local currentZone = string.lower(self:GetCurrentZoneName() or "")
    local sortCurrentFirst = db.sortCurrentZoneFirst ~= false

    table.sort(groups, function(a, b)
        if sortCurrentFirst and currentZone ~= "" then
            local aIsCurrent = (string.lower(a.zone) == currentZone)
            local bIsCurrent = (string.lower(b.zone) == currentZone)
            if aIsCurrent ~= bIsCurrent then
                return aIsCurrent
            end
        end
        return a.zone < b.zone
    end)

    return groups, totalQuests
end

function Data:GetTrackedRecipes()
    local recipes = {}
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked) then
        return recipes
    end

    local function Collect(isRecraft)
        local trackedIDs = C_TradeSkillUI.GetRecipesTracked(isRecraft)
        if not trackedIDs then return end
        for _, recipeID in ipairs(trackedIDs) do
            local schematic = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
            if schematic and schematic.name then
                local reagents = {}
                if schematic.reagentSlotSchematics then
                    for _, slot in ipairs(schematic.reagentSlotSchematics) do
                        if slot.required and slot.reagents and slot.reagents[1] then
                            local r = slot.reagents[1]
                            local have = 0
                            local rName = "Reagent"
                            if r.itemID then
                                if C_Item and C_Item.GetItemCount then
                                    have = C_Item.GetItemCount(r.itemID, true) or 0
                                end
                                if C_Item and C_Item.GetItemNameByID then
                                    rName = C_Item.GetItemNameByID(r.itemID) or rName
                                end
                            end
                            local need = slot.quantityRequired or 1
                            table.insert(reagents, {
                                text = string.format("%d/%d %s", math.min(have, need), need, rName),
                                finished = (have >= need),
                            })
                        end
                    end
                end
                table.insert(recipes, {
                    recipeID = recipeID,
                    isRecraft = isRecraft,
                    name = schematic.name,
                    reagents = reagents,
                })
            end
        end
    end

    Collect(false)
    Collect(true)
    return recipes
end
