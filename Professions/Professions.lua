local _, addon = ...

if not (addon.game == "CLASSIC" or addon.game == "TBC" or addon.game == "FOREVER") then return end

addon.professions = addon.professions or {}
addon.professions.locale = addon.professions.locale or {}

-- Localize globals
local _G = _G
local lower, find, match = string.lower, string.find, string.match
local pairs, ipairs, tonumber = pairs, ipairs, tonumber


addon.professions = addon:NewModule("ProfessionsGuide", "AceEvent-3.0")

--Session
local EVENTS_TO_REGISTER = {
    --Universal
    universal = {
        "CHAT_MSG_SKILL",
    },
    --Classic
    classic = {
    },
    --Forever
    forever = {

    },
}

addon.professions.session = {
    isInitialized = false,
    isClassic = false,
}


--Updates skill level
--TODO: localize
function addon.professions:CHAT_MSG_SKILL(_, text)
    if RXPCData.professions == nil or RXPCData.professions.profession1 == nil or RXPCData.professions.profession1.name == nil
        or RXPCData.professions.profession2 == nil or RXPCData.professions.profession2.name == nil then
        return
    end

    local newSkillLevel = tonumber(match(text, "%d+"))
    local prof1Name, prof2Name = RXPCData.professions.profession1.name, RXPCData.professions.profession2.name
    if prof1Name ~= "" and find(lower(text), prof1Name, 1, true) then
        RXPCData.professions.profession1.skillLevel = newSkillLevel
    elseif prof2Name ~= "" and find(lower(text), prof2Name, 1 , true) then
        RXPCData.professions.profession2.skillLevel = newSkillLevel
    end
end

--Resets RXPCData related to professions
function addon.professions.ResetRXPCData()
    RXPCData.professions.profession1 = {}
    RXPCData.professions.profession2 = {}
    RXPCData.professions.foundItems = {}
    RXPCData.professions.knownRecipes = {}
    RXPCData.professions.money = 0
    RXPCData.professions.overtimeLevel = 0
    RXPCData.professions.scannedAt = ""
    RXPCData.professions.isInitialScanned = false
end

--Helper function to set up RXPCData
local function setUpRXPCData()
    RXPCData.professions = RXPCData.professions or {}
    RXPCData.professions.faction = RXPCData.professions.faction or ""
    RXPCData.professions.money = RXPCData.money or 0
    RXPCData.professions.scannedAt = RXPCData.professions.scannedAt or ""
    RXPCData.professions.foundItems = RXPCData.professions.foundItems or {}
    RXPCData.professions.knownRecipes = RXPCData.professions.knownRecipes or {}

    RXPCData.professions.profession1 = RXPCData.professions.profession1 or {}
    RXPCData.professions.profession1.skillLineId = RXPCData.professions.profession1.skillLineId or 0
    RXPCData.professions.profession1.name = RXPCData.professions.profession1.name or ""
    RXPCData.professions.profession1.skillLevel = RXPCData.professions.profession1.skillLevel or 0
    RXPCData.professions.profession1.skillMaxLevel = RXPCData.professions.profession1.skillMaxLevel or 0

    RXPCData.professions.profession2 = RXPCData.professions.profession2 or {}
    RXPCData.professions.profession2.skillLineId = RXPCData.professions.profession2.skillLineId or 0
    RXPCData.professions.profession2.name = RXPCData.professions.profession2.name or ""
    RXPCData.professions.profession2.skillLevel = RXPCData.professions.profession2.skillLevel or 0
    RXPCData.professions.profession2.skillMaxLevel = RXPCData.professions.profession2.skillMaxLevel or 0
end

--Setup
function addon.professions:Setup()

    if addon.game ~= "CLASSIC" and addon.game ~= "TBC" and addon.game ~= "FOREVER" then return end
    if self.session.isInitialized == true then return end

    if addon.game ~= "FOREVER" then
        self.session.isClassic = true
    end

    for version, events in pairs(EVENTS_TO_REGISTER) do
        if version == "universal" or (version == "classic" and addon.professions.session.isClassic) or (version == "forever" and not addon.professions.session.isClassic) then
            for _, event in ipairs(events) do
                self:RegisterEvent(event)
            end
        end
    end
    RXPCData.professions.isInitialScanned = RXPCData.professions.isInitialScanned or false
    setUpRXPCData()
    self.AH:Setup()
    self.session.isInitialized = true
end