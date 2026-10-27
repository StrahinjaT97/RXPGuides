local _, addon = ...

if not (addon.game == "CLASSIC" or addon.game == "TBC" or addon.game == "FOREVER") then return end

addon.professions = addon.professions or {}
addon.professions.export = {}

-- Localize globals
local _G = _G
local pairs, ipairs, type, tostring, tsort, tconcat = pairs, ipairs, type, tostring, table.sort, table.concat
local fmt, byte, gsub, floor = string.format, string.byte, string.gsub, math.floor
local GetMoney, GetRealmName, GetCurrentRegion, time, date = _G.GetMoney, _G.GetRealmName, _G.GetCurrentRegion, _G.time, _G.date
local UnitName, UnitClass = _G.UnitName, _G.UnitClass


-- Local enums
local SCHEMA_VERSION = 2
local REGIONS = {
    [1] = "us",
    [2] = "kr",
    [3] = "eu",
    [4] = "tw",
    [5] = "cn",
}
local ESCAPES = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

-- We distinguish an array from a table in the JSON format
-- so we create a metatable of 'type' ARRAY here
local ARRAY = {}
local function array(t)
    return setmetatable(t or {}, ARRAY)
end


local function escapeString(s)
    s = gsub(s, '[%c"\\]', function(c)
        return ESCAPES[c] or fmt("\\u%04x", byte(c))
    end)
    return '"' .. s .. '"'
end

local function encodeNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then
        return "null"
    end
    if n == floor(n) and n > -2^53 and n < 2^53 then
        return fmt("%d", n)
    end
    return fmt("%.14g", n)
end


function addon.professions.export.encodeTable(t, out)
    if getmetatable(t) == ARRAY then
        out[#out + 1] = "["
        for i, v in ipairs(t) do
            if i > 1 then out[#out + 1] = "," end
            addon.professions.export.encodeValue(v, out)
        end
        out[#out + 1] = "]"
        return
    end

    -- Sorted keys keep two exports of the same state identical.
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = tostring(k)
    end
    tsort(keys)
    local byString = {}
    for k, v in pairs(t) do
        byString[tostring(k)] = v
    end

    out[#out + 1] = "{"
    for i, k in ipairs(keys) do
        if i > 1 then out[#out + 1] = "," end
        out[#out + 1] = escapeString(k)
        out[#out + 1] = ":"
        addon.professions.export.encodeValue(byString[k], out)
    end
    out[#out + 1] = "}"
end

--encodeValue = function(v, out)
function addon.professions.export.encodeValue(v, out)
    local kind = type(v)
    if kind == "table" then
        addon.professions.export.encodeTable(v, out)
    elseif kind == "string" then
        out[#out + 1] = escapeString(v)
    elseif kind == "number" then
        out[#out + 1] = encodeNumber(v)
    elseif kind == "boolean" then
        out[#out + 1] = v and "true" or "false"
    else
        out[#out + 1] = "null"
    end
end

function addon.professions.export.ToJSON(value)
    local out = {}
    addon.professions.export.encodeValue(value, out)
    return tconcat(out)
end

local function knownRecipes()
    local known = array()
    for _, recipeId in ipairs(RXPCData.professions.knownRecipes) do
        known[#known+1] = recipeId
    end
    return known
end

local function isoTime(t)
    return date("!%Y-%m-%dT%H:%M:%SZ", t)
end

local function professionsList()
    local list = array()
    local prof
    if RXPCData.professions.profession1 and (RXPCData.professions.profession1.skillLineId or 0) > 0 then
        prof = RXPCData.professions.profession1
        list[#list+1] = {
            skillLineId = prof.skillLineId,
            skill = prof.skillLevel,
            maxSkill = prof.skillMaxLevel
        }
    end
    if RXPCData.professions.profession2 and (RXPCData.professions.profession2.skillLineId or 0) > 0 then
        prof = RXPCData.professions.profession2
        list[#list+1] = {
            skillLineId = prof.skillLineId,
            skill = prof.skillLevel,
            maxSkill = prof.skillMaxLevel
        }
    end
    tsort(list, function(a, b) return a.skillLineId < b.skillLineId end)
    return list
end

local function auctionScan()
    local session = addon.professions.AH and addon.professions.AH.session
    local found, scannedAt = session and session.foundItems, session and session.scannedAt
    if not found or next(found) == nil then
        local data = RXPCData and RXPCData.professions or {}
        found, scannedAt = data.foundItems, data.scannedAt
    end
    if not found or next(found) == nil then return nil end

    local items, listings = array()
    for itemId, prices in pairs(found) do
        listings = array()
        for unitPrice, quantity in pairs(prices) do
            listings[#listings + 1] = { unitPriceCopper = unitPrice, quantity = quantity }
        end
        tsort(listings, function(a, b) return a.unitPriceCopper < b.unitPriceCopper end)
        items[#items + 1] = { itemId = itemId, listings = listings }
    end
    tsort(items, function(a, b) return a.itemId < b.itemId end)

    return { scannedAt = isoTime(scannedAt or time()), items = items }
end


function addon.professions.export.ExportJSONData()
    local useOverrides = false

    local faction = RXPCData.professions.faction
    local money = GetMoney()
    local overtimeLevel = RXPCData.professions.overtimeLevel or 0
    local now = time()

    local table = {
        schemaVersion = SCHEMA_VERSION,
        realm = GetRealmName(),
        region = REGIONS[GetCurrentRegion()] or tostring(GetCurrentRegion()),
        faction = faction,
        character = {
            name = UnitName("player"),
            class = select(2, UnitClass("player")),
            level = addon.player.level,
            moneyCopper = money,
            overtimeLevel = overtimeLevel,
        },
        professions = professionsList(),
        auctionScan = auctionScan(),

        game = addon.game,
        gameVersion = addon.gameVersion,
        season = addon.player.season,
        hardcore = addon.player.hardcore == true,
        capturedAt = isoTime(now),
        knownRecipes = knownRecipes(),
        bags = RXPCData.craftedItems,
        debugOverrides = useOverrides and true or false,
    }
    if table.game == "TBC" then table.game = "CLASSIC" end
    return addon.professions.export.ToJSON(table)
end

local exportWindow

function addon.professions.export.ShowWindow()
    local AceGUI = LibStub("AceGUI-3.0")
    local text = addon.professions.export.ExportJSONData()

    if exportWindow then
        exportWindow:Release()
    end
    local window = AceGUI:Create("Frame")
    exportWindow = window
    window:SetTitle("RXP Profession Export")
    window:SetStatusText(fmt("%d characters - press Ctrl+A, then Ctrl+C", #text))
    window:SetLayout("Fill")
    window:SetWidth(560)
    window:SetHeight(420)
    window:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        exportWindow = nil
    end)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel("Paste this into the Profession Route page")
    box:DisableButton(true)
    box:SetText(text)
    -- Typing into the box must not change what gets copied.
    box:SetCallback("OnTextChanged", function(widget)
        widget:SetText(text)
        widget:HighlightText()
    end)
    box:SetCallback("OnEditFocusGained", function(widget)
        widget:HighlightText()
    end)
    window:AddChild(box)
    box:SetFocus()
    box:HighlightText()
end
