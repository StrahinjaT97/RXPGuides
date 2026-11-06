local addonName, addon = ...
local L = addon.locale.Get

if not (addon.game == "CLASSIC" or addon.game == "TBC" or addon.game == "FOREVER") then return end

addon.professions = addon.professions or {}
addon.professions.gui = {}

-- Localize globlas
local _G = _G
local len, fmt, lower, find, match, gmatch = string.len, string.format, string.lower, string.find, string.match, string.gmatch
local tcount, tinsert, twipe, tsort, tremove, tconcat = table.count, table.insert, table.wipe, table.sort, table.remove, table.concat
local pairs, ipairs, next, type, tostring, tonumber, error, unpack = pairs, ipairs, next, type, tostring, tonumber, error, unpack
local max, min, abs, floor, ceil, huge, log = math.max, math.min, math.abs, math.floor, math.ceil, math.huge, math.log

local CreateFrame, UIParent = CreateFrame, UIParent
local AceGUI = LibStub("AceGUI-3.0")

addon.professions.gui.session = {
    isInitialized = false,
    isGuiCreated = false,
    isAhOpen = false,

    guiFrame = {}
}

function addon.professions.gui:Setup()
    if addon.game ~= "CLASSIC" and addon.game ~= "TBC" and addon.game ~= "FOREVER" then return end
    if self.session.isInitialized then return end


    self.session.isInitialized = true
end


function addon.professions.gui:Reset()
    self.session.isAhOpen = false
    self.session.isGuiCreated = false
end

local function createAuctionHousePanelButton(parent, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(80, 22)
    button:SetText(text)

    local divider = button:CreateTexture(nil, "BORDER")
    divider:SetSize(13, 25)
    divider:SetPoint("TOPRIGHT", button, "TOPLEFT", 5, 1)
    divider:SetTexture("Interface\\FrameGeneral\\UI-Frame")
    divider:SetTexCoord(0.0078125, 0.109375, 0.7578125, 0.953125)

    return button
end

local function createAuctionHouseCheckButton(parent, text)
    local radioButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    radioButton:SetSize(20, 20)
    local textFrame = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textFrame:SetText(text)

    textFrame:SetPoint("RIGHT", radioButton, "LEFT", -10, 0)

    return radioButton, textFrame
end

function addon.professions.gui:RegisterProfessionsAuctionHouse()
    local Type, Version = "RXPProfessionsAuctionHouse", 1
    if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

    local methods = {
        ["OnAcquire"] = function(this)
            this.frame:Show()
        end,

        ["OnRelease"] = function(this)
            if self.auctionHouse == this then self.auctionHouse = nil end
            this.frame:Hide()
        end,
    }
    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)

        local title = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
        title:SetPoint("TOP", 0, -18)
        title:SetText(_G.MINIMAP_TRACKING_ACUTIONEER)
        frame.Title = title

        local closeButton = createAuctionHousePanelButton(frame, _G.CLOSE)
        closeButton:SetPoint("BOTTOMRIGHT", -6, 14)
        closeButton:SetScript("OnClick", function(this) HideUIPanel(this:GetParent():GetParent()) end)

        local exportButton = createAuctionHousePanelButton(frame, _G.EXPORT or "Export")
        exportButton:SetPoint("RIGHT", closeButton, "LEFT")

        exportButton:SetScript("OnClick", function ()
            addon.professions.AH:exportInfo()
        end)

        local scanButton = createAuctionHousePanelButton(frame, _G.SCAN or "Scan")
        scanButton:SetPoint("RIGHT", exportButton, "LEFT")

        local professionButton1,  professionButton2, professionText2
        if RXPCData.professions.profession1 and RXPCData.professions.profession1.skillLineId ~= 0 then
            professionButton1, _ = createAuctionHouseCheckButton(frame, RXPCData.professions.profession1.name)
            professionButton1:SetPoint("RIGHT", scanButton, "LEFT", -10, 0)
        end
        if RXPCData.professions.profession1 and RXPCData.professions.profession2 and
           RXPCData.professions.profession1.skillLineId ~= 0 and RXPCData.professions.profession2.skillLineId ~= 0 then
            professionButton2, professionText2 = createAuctionHouseCheckButton(frame, RXPCData.professions.profession2.name)
            professionButton2:SetPoint("RIGHT", scanButton, "LEFT", -10, 0)
            professionButton1:SetPoint("RIGHT", professionText2, "LEFT", -10, 0)
        end

        scanButton:SetScript("OnClick", function (this)
            local flags = (professionButton1 and professionButton2 and professionButton1:GetChecked()
                        and professionButton2:GetChecked() and 3) or
                        (professionButton1 and professionButton1:GetChecked() and 1) or
                        (professionButton2 and professionButton2:GetChecked() and 2) or
                        0
            addon.professions.AH:fullScan(flags)
        end)

        frame.closeButton = closeButton
        frame.exportButton = exportButton
        frame.scanButton = scanButton
        frame.professionButton1 = professionButton1
        frame.professionButton2 = professionButton2

        local widget = {frame = frame, content = frame, type = Type}

        for method, func in pairs(methods) do widget[method] = func end

        return AceGUI:RegisterAsContainer(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

function addon.professions.gui:CreateEmbeddedGui()
    if self.session.isGuiCreated then return end

    local attachment = _G.AuctionFrame
    if not attachment then return end


    self:RegisterProfessionsAuctionHouse()

    if not self.auctionHouse then
        self.auctionHouse = AceGUI:Create("RXPProfessionsAuctionHouse")
        self.auctionHouse.frame:Hide()
    end

    self.auctionHouse.frame:SetParent(attachment)
    self.auctionHouse.frame:SetPoint("TOPLEFT", attachment, "TOPLEFT")
    self.auctionHouse.frame:SetPoint("BOTTOMRIGHT", attachment, "BOTTOMRIGHT")

    self.auctionHouse.frame.Title:SetText("Hello")

    local index = attachment.numTabs + 1
    local tabButton = CreateFrame("Button", "AuctionFrameTab" .. index, attachment, "AuctionTabTemplate")

    tabButton:SetText("RXP Professions")
    tabButton:SetID(index)
    tabButton:SetPoint("TOPLEFT", "AuctionFrameTab" .. (index - 1), "TOPRIGHT", -8, 0)
    tabButton:HookScript("OnHide", function() self.auctionHouse.frame:Hide() end)

    tabButton.Selected = function (this)
        PanelTemplates_SetTab(attachment, this)

        self.auctionHouse.frame:Show()

        PanelTemplates_SelectTab(this)
    end

    tabButton.Deselected = function (this)
        PanelTemplates_DeselectTab(this)
        self.auctionHouse.frame:Hide()
    end

    PanelTemplates_TabResize(tabButton, 0, nil, 72)
    PanelTemplates_SetNumTabs(attachment, index)
    PanelTemplates_EnableTab(attachment, index)

    self.session.isGuiCreated = true
end