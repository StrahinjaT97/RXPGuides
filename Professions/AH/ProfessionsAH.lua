local _, addon = ...

if not (addon.game == "CLASSIC" or addon.game == "TBC" or addon.game == "FOREVER") then return end

addon.professions = addon.professions or {}
addon.professions.materialIds = addon.professions.materialIds or {}
addon.professions.recipeIds = addon.professions.recipeIds or {}
addon.professions.PROFESSIONS = addon.professions.PROFESSIONS or {}
addon.professions.locale = addon.professions.locale or {}
addon.professions.export = addon.professions.export or {}

addon.itemUpgrades = addon.itemUpgrades or {}

-- Localize globals
local _G = _G
local pairs, ipairs = pairs, ipairs
local lower, split, trim = string.lower, string.split, string.trim
local band = bit.band
local CanSendAuctionQuery, QueryAuctionItems = _G.CanSendAuctionQuery, _G.QueryAuctionItems
local GetNumAuctionItems, GetAuctionItemLink, GetAuctionItemInfo = _G.GetNumAuctionItems, _G.GetAuctionItemLink, _G.GetAuctionItemInfo
local GetContainerNumSlots, GetContainerItemInfo = _G.C_Container.GetContainerNumSlots, _G.C_Container.GetContainerItemInfo
local GetNumItemSearchResults, GetItemSearchResultInfo =
    (_G.C_AuctionHouse and _G.C_AuctionHouse.GetNumItemSearchResults) or nil,
    (_G.C_AuctionHouse and _G.C_AuctionHouse.GetItemSearchResultInfo) or nil
local GetNumCommoditySearchResults, GetCommoditySearchResultInfo =
    (_G.C_AuctionHouse and _G.C_AuctionHouse.GetNumCommoditySearchResults) or nil,
    (_G.C_AuctionHouse and _G.C_AuctionHouse.GetCommoditySearchResultInfo) or nil
local SendSearchQuery = (_G.C_AuctionHouse and _G.C_AuctionHouse.SendSearchQuery) or nil
local IsThrottledMessageSystemReady = (_G.C_AuctionHouse and _G.C_AuctionHouse.IsThrottledMessageSystemReady) or nil
local MakeItemKey = (_G.C_AuctionHouse and _G.C_AuctionHouse.MakeItemKey) or nil
local GetNumSkillLines, GetSkillLineInfo = _G.GetNumSkillLines, _G.GetSkillLineInfo
local GetNumFactions, GetFactionInfo = _G.GetNumFactions, _G.GetFactionInfo
local GetMoney = _G.GetMoney
local GetActiveConfigID = _G.C_ClassTalents and _G.C_ClassTalents.GetActiveConfigID
local GetConfigIDBySystemID, GetNodeInfo, ConfigHasStagedChanges, GetStagedChanges, GetTreeNodes, GetConfigInfo =
    (_G.C_Traits and _G.C_Traits.GetConfigIDBySystemID),
    (_G.C_Traits and _G.C_Traits.GetNodeInfo),
    (_G.C_Traits and _G.C_Traits.ConfigHasStagedChanges),
    (_G.C_Traits and _G.C_Traits.GetStagedChanges),
    (_G.C_Traits and _G.C_Traits.GetTreeNodes),
    (_G.C_Traits and _G.C_Traits.GetConfigInfo)

-- Local renaming
local RECIPES = addon.professions.recipeIds
local MATERIALS = addon.professions.materialIds
local PROFESSION_NAMES = addon.professions.locale.PROFESSION_NAMES

-- Local enums
local EVENTS_TO_REGISTER_AH = {
    --Universal
    universal = {
        "AUCTION_HOUSE_SHOW",
        "AUCTION_HOUSE_CLOSED",
        "AUCTION_HOUSE_DISABLED",
        "GET_ITEM_INFO_RECEIVED",
    },
    --Classic
    classic = {
        "AUCTION_ITEM_LIST_UPDATE",
    },
    --Forever
    forever = {
        "ITEM_SEARCH_RESULTS_UPDATED",
        "COMMODITY_SEARCH_RESULTS_UPDATED",
    },
}

local SKILL_LINE_IDS = {
    alchemy = 171,
    blacksmithing = 164,
    enchanting = 333,
    engineering = 202,
    herbalism = 182,
    leatherworking = 165,
    mining = 186,
    skinning = 393,
    tailoring = 197,
    cooking = 185,
    firstaid = 129,
    fishing = 356,
}

local OVERTIME_IDS = {
    LEGACY_SYSTEM_ID = 45,
    OVERTIME_NODE_ID = 110290,
    OVERTIME_SPELL_ID = 1225451,
}

addon.professions.AH = addon:NewModule("ProfessionsAH", "AceEvent-3.0")


addon.professions.AH.session = {
    isInitialized = false,
    auctionFilterButtons = {"Trade Goods"},
    foundItems = {},
    materialsToScan = {},
    materialIndex = 1,
    currentPage = 0,
    currentItemName = "",
    ahIsShowing = false,
    sentQuery = false,
    isScanning = false,
}

--Setup
function addon.professions.AH:Setup()
    if addon.game ~= "CLASSIC" and addon.game ~= "TBC" and addon.game ~= "FOREVER" then return end
    if self.session.isInitialized then return end

    --Set the flag to check the players inventory for lingering items
    RXPCData.professions.isInitialScanned = false

    --Register events
    for version, events in pairs(EVENTS_TO_REGISTER_AH) do
        if version == "universal" or (version == "classic" and addon.professions.session.isClassic) or (version == "forever" and not addon.professions.session.isClassic) then
            for _, event in ipairs(events) do
                self:RegisterEvent(event)
            end
        end
    end

    self.session.isInitialized = true
end

function addon.professions.AH.session:Reset()
    self.foundItems = {}
    self.materialIndex = 1
    self.materialsToScan = {}
    self.currentPage = 0
    self.currentItemName = ""
    self.sentQuery = false
    self.isScanning = false
end


--Local functions

--Helper function to determine if itemID is part of a profession
local function isRecipeOrMaterial(itemID, professionName)
    if not professionName then return end
    if not type(itemID) == "number" then return end
    if addon.professions.session.isClassic then
        if not RECIPES.classic[professionName] and not MATERIALS.classic[professionName] then return end
        return RECIPES.classic[professionName][itemID] or MATERIALS.classic[professionName][itemID]
    else
        if not RECIPES.forever[professionName] and not MATERIALS.forever[professionName] then return end
        return RECIPES.forever[professionName][itemID] or MATERIALS.forever[professionName][itemID]
    end
end

--Scans backpacks for items created by recipes in backpacks for
--given profession names and updates the RXPCData accordingly
--Because of problems stated in: https://warcraft.wiki.gg/wiki/API_GetContainerNumSlots
--we call this function when AH is opened for the first time, per player character
local function initialScanInventoryForCraftedItems(prof1Name, prof2Name)
    --Reset RXPCData.craftedItems so the new scan will not be added to old scan
    RXPCData.craftedItems = {}
    local numberOfSlots, itemName, itemID, itemCount
    for bagID = 0, NUM_BAG_SLOTS do
        numberOfSlots = GetContainerNumSlots(bagID)
        if numberOfSlots == 0 then
            break
        end
        for slot = 1, numberOfSlots do
            local containerInfo = GetContainerItemInfo(bagID, slot)
            if containerInfo and (isRecipeOrMaterial(containerInfo.itemID, prof1Name) or isRecipeOrMaterial(containerInfo.itemID, prof2Name)) then
                itemID = containerInfo.itemID
                itemCount = containerInfo.stackCount
                RXPCData.craftedItems[itemID] = (RXPCData.craftedItems[itemID] or 0) + itemCount
            end
        end
    end
end


function addon.professions.AH:gatherMaterialsToScan(professionName)
    if addon.professions.session.isClassic then
        if not MATERIALS.classic[professionName] then return end
        for materialId, _ in pairs(MATERIALS.classic[professionName]) do
            tinsert(self.session.materialsToScan, materialId)
        end
    else
        if not MATERIALS.forever[professionName] then return end
        for materialId, _ in pairs(MATERIALS.forever[professionName]) do
            tinsert(self.session.materialsToScan, materialId)
        end
    end
end

-- Player info gathering functions

local function gatherPlayerProfessionInfo()
    if not RXPCData.professions.profession1 then RXPCData.professions.profession1 = {} end
    if not RXPCData.professions.profession2 then RXPCData.professions.profession2 = {} end

    if addon.professions.session.isClassic then
        --skillName, header, isExpanded, skillRank, numTempPoints, skillModifier,
        --skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType,
        --skillDescription = GetSkillLineInfo(index)
        local skillName, isHeader, skillRank, skillMaxRank
        local foundFirst = false
        for i = 1, GetNumSkillLines() do
            skillName, isHeader, _, skillRank, _, _, skillMaxRank, _, _, _, _, _, _ = GetSkillLineInfo(i)
            if skillName and not isHeader and addon.professions.locale.PROFESSION_NAMES[skillName] then
                if not foundFirst then
                    RXPCData.professions.profession1 = {
                        name = lower(PROFESSION_NAMES[skillName]),
                        skillLineId = SKILL_LINE_IDS[lower(PROFESSION_NAMES[skillName])],
                        skillLevel = skillRank,
                        skillMaxLevel = skillMaxRank,
                    }
                    foundFirst = true
                else
                    RXPCData.professions.profession2 = {
                        name = lower(PROFESSION_NAMES[skillName]),
                        skillLineId = SKILL_LINE_IDS[lower(PROFESSION_NAMES[skillName])],
                        skillLevel = skillRank,
                        skillMaxLevel = skillMaxRank,
                    }
                end
            end
        end
    else
        local prof1Index, prof2Index, archaeology, fishing, cooking = GetProfessions()
        local name, skillLevel, maxSkillLevel, skillLine, specializationIndex, specializationOffset, skillLineName
        if prof1Index then
            name, _, skillLevel, maxSkillLevel,
            _, _, skillLine,
            _, specializationIndex,
            specializationOffset, skillLineName = GetProfessionInfo(prof1Index)
            RXPCData.professions.profession1 = {
                name = name,
                skillLineId = skillLine,
                skillLevel = skillLevel,
                skillMaxLevel = maxSkillLevel
            }
        end
        if prof2Index then
            name, _, skillLevel, maxSkillLevel,
            _, _, skillLine,
            _, specializationIndex,
            specializationOffset, skillLineName = GetProfessionInfo(prof2Index)
            RXPCData.professions.profession2 = {
                name = name,
                skillLineId = skillLine,
                skillLevel = skillLevel,
                skillMaxLevel = maxSkillLevel
            }
        end
    end
end


local function gatherPlayerFactionInfo()
    if not RXPCData.professions then RXPCData.professions = {} end

    local name
    for i = 1, GetNumFactions() do
        name = GetFactionInfo(i)
        if name and addon.professions.locale.FACTION_NAMES[name] then
            RXPCData.professions.faction = addon.professions.locale.FACTION_NAMES[name]
            break
        end
    end
end


local function gatherPlayerMoneyInfo()
    if not RXPCData.professions then RXPCData.professions = {} end
    RXPCData.professions.money = GetMoney()
end


--Checks if player has Working Overtime talent points
local function gatherPlayerWorkingOvertimeTalent()
    if addon.professions.session.isClassic then
        RXPCData.professions.overtimeLevel = 0
        return
    end

    --Get all config IDs
    local configIDs = {}
    if GetActiveConfigID then
        local id = GetActiveConfigID()
        if id and id ~= 0 then
            configIDs[#configIDs + 1] = id
        end
    end
    if GetConfigIDBySystemID then
        local id = GetConfigIDBySystemID(OVERTIME_IDS.LEGACY_SYSTEM_ID)
        if id and id ~= 0 then
            configIDs[#configIDs + 1] = id
        end
    end

    --Sarch for overtime node
    local config, node
    for _, configID in ipairs(configIDs) do
        config = GetConfigInfo(configID)
        for _, treeID in ipairs(config and config.treeIDs or {}) do
            for _, nodeID in ipairs(GetTreeNodes(treeID) or {}) do
                node = GetNodeInfo(configID, nodeID)
                if node and node.ID ~= 0 and node.ID == OVERTIME_IDS.OVERTIME_NODE_ID and node.maxRanks and node.maxRanks > 0 then
                    if node.activeRank then
                        --Check if rank is commited or not
                        local hasStaged = ConfigHasStagedChanges(configID)
                        if hasStaged then
                            local isNodeStaged = false
                            for _, list in ipairs({GetStagedChanges(configID)}) do
                                for _, id in ipairs(type(list) == "table" and list or {}) do
                                    if id == OVERTIME_IDS.OVERTIME_NODE_ID then
                                        isNodeStaged = true
                                        break
                                    end
                                end
                            end
                            hasStaged = isNodeStaged
                        end
                        if not hasStaged then
                            RXPCData.professions.overtimeLevel = node.activeRank or 0
                        else
                            RXPCData.professions.overtimeLevel = RXPCData.professions.overtimeLevel or 0
                        end
                        return
                    end
                end
            end
        end
    end
    RXPCData.professions.overtimeLevel = 0
end

local function gatherPlayerKnownRecipes()
    RXPCData.professions.knownRecipes = {}
    local professionsFound = 0
    local lookup = (addon.professions.session.isClassic and RECIPES.classic) or RECIPES.forever
    for key, recipeIds in pairs(lookup or {}) do
        if professionsFound == 2 then
            break
        end
        if (RXPCData.professions.profession1 and RXPCData.professions.profession1.name == key) or
           (RXPCData.professions.profession2 and RXPCData.professions.profession2.name == key) then
            professionsFound = professionsFound + 1
            for recipeId, _ in pairs(recipeIds) do
                if addon.IsPlayerSpell(recipeId) then
                    RXPCData.professions.knownRecipes[#RXPCData.professions.knownRecipes+1] = recipeId
                end
            end
        end
    end
end


--Scan functions

--Scan for classic versions
local function classicScan(itemID)
    if not addon.professions.session.isClassic then return end

    if addon.professions.AH.session.sentQuery then return end
    if not CanSendAuctionQuery() then
        C_Timer.After(0.35, function ()
           classicScan(itemID)
        end)
        return
    end

    local item = Item:CreateFromItemID(itemID)
    local itemName
    item:ContinueOnItemLoad(function ()
        itemName = item:GetItemName()
        addon.professions.AH.session.sentQuery = true
        -- text, minLevel, maxLevel, page, usable, rarity, getAll, exactMatch, filterData
        QueryAuctionItems(itemName, nil, nil, addon.professions.AH.session.currentPage, false, nil, false, true, nil)
    end)
end


--Scan for forever version
local function foreverScan(itemID)
    if addon.professions.session.isClassic then return end

    if addon.professions.AH.session.sentQuery then return end

    if not IsThrottledMessageSystemReady() then
        C_Timer.After(0.35, function ()
            foreverScan(itemID)
        end)
        return
    end

    local item = Item:CreateFromItemID(itemID)
    local itemKey
    item:ContinueOnItemLoad(function ()
        itemKey = MakeItemKey(item:GetItemID())
        addon.professions.AH.session.sentQuery = true
        SendSearchQuery(itemKey, {}, false)
    end)

end

--Main scan function
function addon.professions.AH:Scan()
    if not self.session.ahIsShowing then return end
    if self.session.isScanning then return end

    self.session.isScanning = true
    self.session.materialIndex = 1
    if addon.professions.session.isClassic then
        classicScan(self.session.materialsToScan[self.session.materialIndex])
    else
        foreverScan(self.session.materialsToScan[self.session.materialIndex])
    end
end

--Events
function addon.professions.AH:AUCTION_HOUSE_SHOW()
    if self.session.isInitialized then
        self.session.ahIsShowing = true
    end
    if not RXPCData.professions.isInitialScanned then
        initialScanInventoryForCraftedItems(RXPCData.professions.profession1.name, RXPCData.professions.profession2.name)
        gatherPlayerFactionInfo()
        RXPCData.professions.isInitialScanned = true
    end
    gatherPlayerProfessionInfo()
end


function addon.professions.AH:AUCTION_HOUSE_CLOSED()
    self.session.ahIsShowing = false
end


function addon.professions.AH:AUCTION_HOUSE_DISABLED()
    self.session.ahIsShowing = false
end


--Classic events
function addon.professions.AH:GET_ITEM_INFO_RECEIVED(_, itemID, success)
end


function addon.professions.AH:AUCTION_ITEM_LIST_UPDATE()
    if not self.session.sentQuery then return end

    local resultCount, totalAuctions = GetNumAuctionItems("list")
    if resultCount == 0 or totalAuctions == 0 then
        self.session.sentQuery = false
        self.session.currentPage = 0
        self.session.materialIndex = self.session.materialIndex + 1

        --Updated title
        local percentage = addon.Round(self.session.materialIndex / #self.session.materialsToScan, 2) * 100
        percentage = math.floor(math.min(percentage, 100) + 0.5)
        addon.itemUpgrades.title.Title:SetText(string.format("%s / %s items scanned (%d%%)", self.session.materialIndex,
                                                #self.session.materialsToScan, percentage))
        if (self.session.materialIndex == #self.session.materialsToScan) then
            addon.itemUpgrades.title.Title:SetText("Done scanning")
        end

        if self.session.materialIndex <= #self.session.materialsToScan then
            classicScan(self.session.materialsToScan[self.session.materialIndex])
        end
        return
    end

    local name, count, buyoutPrice, owner, itemID, hasAllInfo, itemLink
    local pricePerItem
    for i = 1, resultCount do
        itemLink = GetAuctionItemLink("list", i)
        -- name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo(type, index)
        name, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, owner, _, _, itemID, hasAllInfo = GetAuctionItemInfo("list", i)

        self.session.foundItems[itemID] = self.session.foundItems[itemID] or {}
        if buyoutPrice > 0 then
            pricePerItem = ceil(buyoutPrice / count)
            self.session.foundItems[itemID][pricePerItem] = (self.session.foundItems[itemID][pricePerItem] or 0) + count
        end
    end

    self.session.sentQuery = false
    self.session.currentPage = self.session.currentPage + 1

    classicScan(self.session.materialsToScan[self.session.materialIndex])
end


--Forever events
function addon.professions.AH:ITEM_SEARCH_RESULTS_UPDATED(_, itemKey, _)
    if not self.session.sentQuery then return end

    local resultCount = GetNumItemSearchResults(itemKey)
    local result, itemID, price, count
    local totalCount = 0
    for i = 1, resultCount do
		result = GetItemSearchResultInfo(itemKey, i)
        if result and result.buyoutAmount then
            itemID = result.itemKey.itemID
            price = result.buyoutAmount
            count = result.quantity
            self.session.foundItems[itemID] = self.session.foundItems[itemID] or {}
            self.session.foundItems[itemID][price] = count
            totalCount = totalCount + count
        end
	end

    self.session.sentQuery = false
    self.session.materialIndex = self.session.materialIndex + 1
    if self.session.materialIndex <= #self.session.materialsToScan then
        foreverScan(self.session.materialsToScan[self.session.materialIndex])
    end
end


function addon.professions.AH:COMMODITY_SEARCH_RESULTS_UPDATED(_, itemID)
    if not self.session.sentQuery then return end

    local resultCount = GetNumCommoditySearchResults(itemID)
    local result,price, count
    local totalCount = 0
    for i = 1, resultCount do
		result = GetCommoditySearchResultInfo(itemID, i)
        if result then
            price = result.unitPrice
            count = result.quantity
            self.session.foundItems[itemID] = self.session.foundItems[itemID] or {}
            self.session.foundItems[itemID][price] = count
            totalCount = totalCount + count
        end
	end

    self.session.sentQuery = false
    self.session.materialIndex = self.session.materialIndex + 1
    if self.session.materialIndex <= #self.session.materialsToScan then
        foreverScan(self.session.materialsToScan[self.session.materialIndex])
    end
end

--[[
Scan flags:
0 (0x0): Scan NONE
1 (0x1): Scan the first profession
2 (0x2): Scan the second profession
]]
function addon.professions.AH:fullScan(flags)
    flags = flags or 0
    if flags == 0 then return end

    if not RXPCData.professions.profession1.name then
        return
    end
    self.session:Reset()
    self.session.scannedAt = time()
    if band(flags, 0x1) ~= 0 then
        addon.professions.AH:gatherMaterialsToScan(RXPCData.professions.profession1.name)
    end
    if RXPCData.professions.profession2.name then
        if band(flags, 0x2) ~= 0 then
            addon.professions.AH:gatherMaterialsToScan(RXPCData.professions.profession2.name)
        end
    end

    addon.professions.AH.session.materialIndex = 1
    addon.professions.AH:Scan()
end


function addon.professions.AH:exportInfo()
    gatherPlayerProfessionInfo()
    gatherPlayerMoneyInfo()
    gatherPlayerWorkingOvertimeTalent()
    gatherPlayerKnownRecipes()
    RXPCData.professions.foundItems = self.session.foundItems
    RXPCData.professions.scannedAt = self.session.scannedAt

    addon.professions.export.ShowWindow()
end