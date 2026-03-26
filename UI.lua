local addonName, PC = ...

local TAB_HEIGHT = 24
local CONTENT_TOP = -60

----------------------------------------
-- Tab System
----------------------------------------

local tabs = {}
local tabContents = {}
local activeTab = nil

local function CreateTab(parent, name, index)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(80, TAB_HEIGHT)
    tab:SetPoint("TOPLEFT", 8 + (index - 1) * 84, -32)

    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(name)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()
    tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    tab:SetScript("OnClick", function()
        PC:SelectTab(name)
    end)

    tabs[name] = tab
    return tab
end

local function CreateTabContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT", 12, CONTENT_TOP)
    content:SetPoint("BOTTOMRIGHT", -12, 12)
    content:Hide()
    return content
end

function PC:SelectTab(name)
    for tabName, content in pairs(tabContents) do
        content:Hide()
        tabs[tabName].bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        tabs[tabName].text:SetTextColor(0.6, 0.6, 0.6)
    end
    tabContents[name]:Show()
    tabs[name].bg:SetColorTexture(0.3, 0.3, 0.5, 0.9)
    tabs[name].text:SetTextColor(1, 1, 1)
    activeTab = name

    if name == "Note" then
        PC:RefreshNoteDisplay()
    elseif name == "Tracker" then
        PC:ScanAuras()
    end
end

----------------------------------------
-- Main Window
----------------------------------------

function PC:CreateMainWindow()
    local frame = CreateFrame("Frame", "PcRaidToolsMain", UIParent, "BackdropTemplate")
    frame:SetSize(350, 450)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff00ccffPcRaidTools|r")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    tinsert(UISpecialFrames, "PcRaidToolsMain")

    -- Tabs
    CreateTab(frame, "Tracker", 1)
    CreateTab(frame, "Note", 2)

    -- Tab content containers
    tabContents["Tracker"] = CreateTabContent(frame)
    tabContents["Note"] = CreateTabContent(frame)

    -- Build each tab's content
    self:BuildTrackerTab(tabContents["Tracker"])
    self:BuildNoteTab(tabContents["Note"])

    frame:Hide()
    self.mainWindow = frame

    -- Default to Tracker tab
    self:SelectTab("Tracker")
end

----------------------------------------
-- Tracker Tab
----------------------------------------

function PC:BuildTrackerTab(parent)
    -- Buff / Debuff toggle
    local filterBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    filterBtn:SetSize(70, 22)
    filterBtn:SetPoint("TOPLEFT", 0, 0)
    filterBtn:SetText("Debuff")

    local function UpdateFilterButton()
        if PC.auraFilter == "HARMFUL" then
            filterBtn:SetText("Debuff")
        else
            filterBtn:SetText("Buff")
        end
    end

    filterBtn:SetScript("OnClick", function()
        if PC.auraFilter == "HARMFUL" then
            PC:SetAuraFilter("HELPFUL")
        else
            PC:SetAuraFilter("HARMFUL")
        end
        UpdateFilterButton()
    end)

    local inputLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("LEFT", filterBtn, "RIGHT", 8, 0)
    inputLabel:SetText("Spell ID:")

    local inputBox = CreateFrame("EditBox", "PcRaidToolsSpellInput", parent, "InputBoxTemplate")
    inputBox:SetSize(80, 20)
    inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 6, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetNumeric(true)
    inputBox:SetMaxLetters(10)

    local trackBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    trackBtn:SetSize(60, 22)
    trackBtn:SetPoint("LEFT", inputBox, "RIGHT", 6, 0)
    trackBtn:SetText("Track")
    trackBtn:SetScript("OnClick", function()
        local text = inputBox:GetText()
        local spellId = tonumber(text)
        if spellId and spellId > 0 then
            PC:SetTrackedSpellId(spellId)
            inputBox:ClearFocus()
        end
    end)

    inputBox:SetScript("OnEnterPressed", function(self)
        trackBtn:Click()
    end)

    local statusText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 0, -28)
    statusText:SetText("|cff888888No aura tracked|r")
    self.statusText = statusText

    -- Roster header
    local rosterHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rosterHeader:SetPoint("TOPLEFT", 0, -46)
    rosterHeader:SetText("Raid/Party Members:")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -62)
    scrollFrame:SetPoint("BOTTOMRIGHT", -18, 0)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(280, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollChild = scrollChild
end

----------------------------------------
-- Note Tab
----------------------------------------

function PC:BuildNoteTab(parent)
    local readBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    readBtn:SetSize(120, 22)
    readBtn:SetPoint("TOPLEFT", 0, 0)
    readBtn:SetText("Read MRT Note")
    readBtn:SetScript("OnClick", function()
        PC:ReadMRTNote()
        PC:RefreshNoteDisplay()
    end)

    local noteStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteStatus:SetPoint("LEFT", readBtn, "RIGHT", 8, 0)
    noteStatus:SetText("")
    self.noteStatus = noteStatus

    -- Scrollable text area to display the note
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -18, 0)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() or 280)
    editBox:SetText("")
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    scrollFrame:SetScrollChild(editBox)
    self.noteEditBox = editBox

    -- Update width when parent resizes
    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(w)
    end)
end

function PC:RefreshNoteDisplay()
    if not self.noteEditBox then return end

    if not self:HasMRT() then
        self.noteEditBox:SetText("MRT (Method Raid Tools) is not loaded.\nInstall MRT to use this feature.")
        self.noteStatus:SetText("|cffff4444MRT not found|r")
        return
    end

    local note = self:ReadMRTNote()
    if note and note ~= "" then
        self.noteEditBox:SetText(note)
        self.noteStatus:SetText("|cff44ff44Note loaded (" .. #note .. " chars)|r")
    else
        self.noteEditBox:SetText("(Note is empty)")
        self.noteStatus:SetText("|cffaaaaaaEmpty note|r")
    end
end

----------------------------------------
-- Roster Display
----------------------------------------

local ROW_HEIGHT = 20
local HAS_COLOR = { r = 0.3, g = 1, b = 0.3 }
local MISSING_COLOR = { r = 1, g = 0.2, b = 0.2 }
local NO_TRACK_COLOR = { r = 0.6, g = 0.6, b = 0.6 }

local function GetOrCreateRow(parent, index)
    if parent.rows and parent.rows[index] then
        return parent.rows[index]
    end

    parent.rows = parent.rows or {}

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(220)

    row.indicator = row:CreateTexture(nil, "OVERLAY")
    row.indicator:SetSize(12, 12)
    row.indicator:SetPoint("RIGHT", -4, 0)
    row.indicator:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")

    parent.rows[index] = row
    return row
end

function PC:UpdateRosterDisplay()
    if not self.mainWindow or not self.mainWindow:IsShown() then return end

    local scrollChild = self.scrollChild

    if scrollChild.rows then
        for _, row in pairs(scrollChild.rows) do
            row:Hide()
        end
    end

    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                units[#units + 1] = unit
            end
        end
    else
        if UnitExists("player") then
            units[#units + 1] = "player"
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                units[#units + 1] = unit
            end
        end
    end

    if self.trackedSpellId then
        local spellName = C_Spell.GetSpellName(self.trackedSpellId)
        local label = spellName or ("ID: " .. self.trackedSpellId)
        local filterLabel = self.auraFilter == "HARMFUL" and "Debuff" or "Buff"
        self.statusText:SetText("Tracking " .. filterLabel .. ": |cffffcc00" .. label .. "|r")
    else
        self.statusText:SetText("|cff888888No aura tracked|r")
    end

    for i, unit in ipairs(units) do
        local row = GetOrCreateRow(scrollChild, i)
        local name = UnitName(unit) or "Unknown"
        row.name:SetText(name)

        if not self.trackedSpellId then
            row.name:SetTextColor(NO_TRACK_COLOR.r, NO_TRACK_COLOR.g, NO_TRACK_COLOR.b)
            row.indicator:Hide()
        elseif self.auraStatus[unit] then
            row.name:SetTextColor(HAS_COLOR.r, HAS_COLOR.g, HAS_COLOR.b)
            row.indicator:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
            row.indicator:Show()
        else
            row.name:SetTextColor(MISSING_COLOR.r, MISSING_COLOR.g, MISSING_COLOR.b)
            row.indicator:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
            row.indicator:Show()
        end

        row:Show()
    end

    scrollChild:SetHeight(#units * ROW_HEIGHT)
end

-- Refresh the display whenever the window is shown
function PC:HookMainWindowShow()
    self.mainWindow:HookScript("OnShow", function()
        if activeTab == "Tracker" then
            PC:ScanAuras()
        elseif activeTab == "Note" then
            PC:RefreshNoteDisplay()
        end
    end)
end

function PC:ToggleMainWindow()
    if self.mainWindow:IsShown() then
        self.mainWindow:Hide()
    else
        self.mainWindow:Show()
    end
end
