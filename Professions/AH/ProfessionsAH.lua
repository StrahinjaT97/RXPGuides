local _, addon = ...

if not (addon.game == "CLASSIC" or addon.game == "TBC" or addon.game == "FOREVER") then return end

addon.professions = addon.professions or {}
addon.professions.materialIds = addon.professions.materialIds or {}
addon.professions.recipeIds = addon.professions.recipeIds or {}
addon.professions.tradeableRecipeIds = addon.professions.tradeableRecipeIds or {}
addon.professions.PROFESSIONS = addon.professions.PROFESSIONS or {}
addon.professions.locale = addon.professions.locale or {}
addon.professions.export = addon.professions.export or {}
addon.professions.gui = addon.professions.gui or {}


-- Localize globals
local _G = _G
local pairs, ipairs = pairs, ipairs
local lower, split, trim, fmt, lower = string.lower, string.split, string.trim, string.format, string.lower
local min, floor = math.min, math.floor
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
local GetNumFactions, GetFactionInfo =
    (_G.C_Reputation and _G.C_Reputation.GetNumFactions or _G.GetNumFactions),
    (_G.C_CreatureInfo and C_CreatureInfo.GetFactionInfo or _G.GetFactionInfo)
local GetMoney = _G.GetMoney
local GetActiveConfigID = _G.C_ClassTalents and _G.C_ClassTalents.GetActiveConfigID
local GetConfigIDBySystemID, GetNodeInfo, ConfigHasStagedChanges, GetStagedChanges, GetTreeNodes, GetConfigInfo =
    (_G.C_Traits and _G.C_Traits.GetConfigIDBySystemID),
    (_G.C_Traits and _G.C_Traits.GetNodeInfo),
    (_G.C_Traits and _G.C_Traits.ConfigHasStagedChanges),
    (_G.C_Traits and _G.C_Traits.GetStagedChanges),
    (_G.C_Traits and _G.C_Traits.GetTreeNodes),
    (_G.C_Traits and _G.C_Traits.GetConfigInfo)
local ReplicateItems, GetNumReplicateItems, GetReplicateItemInfo =
    (_G.C_AuctionHouse and _G.C_AuctionHouse.ReplicateItems),
    (_G.C_AuctionHouse and _G.C_AuctionHouse.GetNumReplicateItems),
    (_G.C_AuctionHouse and _G.C_AuctionHouse.GetReplicateItemInfo)

-- Local renaming
local RECIPES = addon.professions.recipeIds
local MATERIALS = addon.professions.materialIds
local TRADEABLE_RECIPES = addon.professions.tradeableRecipeIds
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
        "REPLICATE_ITEM_LIST_UPDATE",
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
    ahIsShowing = false,
    sentQuery = false,
    isScanning = false,

    isInitialScan = true,
    isForeverFullScanSuccessful = false, --checks if forever full scan succeeded for error message to appear
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
    self.sentQuery = false
    self.isScanning = false
    self.isInitialScan = true
    self.isForeverFullScanSuccessful = false
end


--Local functions

--Helper function to determine if itemID is part of a profession
local function isRecipeOrMaterialOrTradeable(itemID, professionName)
    if not professionName then return end
    if not type(itemID) == "number" then return end
    if addon.professions.session.isClassic then
        if not RECIPES.classic[professionName] and not MATERIALS.classic[professionName] and not TRADEABLE_RECIPES.classic[professionName] then return end
        return RECIPES.classic[professionName][itemID] or MATERIALS.classic[professionName][itemID] or TRADEABLE_RECIPES.classic[professionName][itemID]
    else
        if not RECIPES.forever[professionName] and not MATERIALS.forever[professionName] and not TRADEABLE_RECIPES.forever[professionName] then return end
        return RECIPES.forever[professionName][itemID] or MATERIALS.forever[professionName][itemID] or TRADEABLE_RECIPES.forever[professionName][itemID]
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
            if containerInfo and (isRecipeOrMaterialOrTradeable(containerInfo.itemID, prof1Name) or isRecipeOrMaterialOrTradeable(containerInfo.itemID, prof2Name)) then
                itemID = containerInfo.itemID
                itemCount = containerInfo.stackCount
                RXPCData.craftedItems[itemID] = (RXPCData.craftedItems[itemID] or 0) + itemCount
            end
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
                        localeName = skillName,
                        skillLineId = SKILL_LINE_IDS[lower(PROFESSION_NAMES[skillName])],
                        skillLevel = skillRank,
                        skillMaxLevel = skillMaxRank,
                    }
                    foundFirst = true
                else
                    RXPCData.professions.profession2 = {
                        name = lower(PROFESSION_NAMES[skillName]),
                        localeName = skillName,
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
                name = lower(PROFESSION_NAMES[name]),
                localeName = name,
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
                name = lower(PROFESSION_NAMES[name]),
                localeName = name,
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
    local raceID = select(3, UnitRace("player"))
    for i = 1, GetNumFactions() do
        name = addon.professions.session.isClassic and GetFactionInfo(i) or GetFactionInfo(raceID)
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


local function showCannotSearchAllMessage()
    if addon.professions.gui.cannotSearchAllMsgFrame then
        addon.professions.gui.cannotSearchAllMsgFrame:Clear()
        addon.professions.gui.cannotSearchAllMsgFrame = nil
        addon.professions.gui.cannotSearchAllMsgFrame = addon.professions.gui:createMessageFrame("Cannot scan the entire Auction House at this moment", 2) --TODO: localizde this
    end
    addon.professions.gui.cannotSearchAllMsgFrame:Show()
end

--Scan the entire AH
local function scanEntireAH()
    if addon.professions.AH.session.isScanning then return end

    if addon.professions.session.isClassic then
        local _, canQueryAll = CanSendAuctionQuery()
        if not canQueryAll then
            showCannotSearchAllMessage()
            return
        end
        QueryAuctionItems("", nil, nil, 0, nil, nil, true, nil, nil)
        addon.professions.AH.session.sentQuery = true
    else
        ReplicateItems()
        addon.professions.AH.session.sentQuery = true
        addon.professions.AH.session.isForeverFullScanSuccessful = false
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
    if not addon.professions.gui.session.isGuiCreated then
        addon.professions.gui:CreateGui()
        addon.professions.gui.session.isGuiCreated = true
    end
end


function addon.professions.AH:AUCTION_HOUSE_CLOSED()
    self.session.ahIsShowing = false
    addon.professions.gui:Reset()
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

    addon.professions.gui.auctionHouse.frame.Title:SetText("Done scanning") --TODO: localize this
    self.session.isScanning = false
    self.session.sentQuery = false
end


--Forever events

-- Full forever scan

--Helper function
local function foreverProcessEntireAHScan(scanIndex, totalAuctions)
    if addon.professions.AH.session.isScanning then return end

    addon.professions.AH.session.isScanning = true

    local name, count, buyoutPrice, owner, itemID, hasAllInfo
    local pricePerItem
    while scanIndex < totalAuctions do
        --name, texture, count, qualityID, usable, level, levelType, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo = C_AuctionHouse.GetReplicateItemInfo(index) 
        name, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, owner, _, _, itemID, hasAllInfo = GetReplicateItemInfo(scanIndex)
        addon.professions.AH.session.foundItems[itemID] = addon.professions.AH.session.foundItems[itemID] or {}
        if buyoutPrice > 0 then
            pricePerItem = ceil(buyoutPrice / count)
            addon.professions.AH.session.foundItems[itemID][pricePerItem] = (addon.professions.AH.session.foundItems[itemID][pricePerItem] or 0) + count
        end
        scanIndex = scanIndex + 1
    end
    addon.professions.gui.session.title = "Done scanning" --TODO: localize this
    addon.professions.gui.auctionHouse.frame:GetParent():SetTitle(addon.professions.gui.session.title)
    --We need to keep these disabled. Once the scan is done it can only be attempted by opening the AH again
    --TODO: add a better update to these values with C_Time of 15 minutes!
    --addon.professions.AH.session.isScanning = false
    --addon.professions.AH.session.isInitialScan = true
end

--Triggers on entire ah scan for forever
function addon.professions.AH:REPLICATE_ITEM_LIST_UPDATE()
    if not self.session.isInitialScan then return end
    self.session.isForeverFullScanSuccessful = true

    if self.session.isInitialScan and addon.professions.gui.auctionHouse.frame:IsShown() then
        addon.professions.gui.session.title = "Scanning full Auction House ..." --TODO: localize this
        addon.professions.gui.auctionHouse.frame:GetParent():SetTitle(addon.professions.gui.session.title)
    end

    local totalAuctions = GetNumReplicateItems()
    self.session.isInitialScan = false
    if totalAuctions == 0 then
        showCannotSearchAllMessage()
        return
    end

    foreverProcessEntireAHScan(0, totalAuctions)
end

function addon.professions.AH:fullScan()
    if not RXPCData.professions.profession1.name then return end

    self.session:Reset()
    self.session.scannedAt = time()
    scanEntireAH()
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

