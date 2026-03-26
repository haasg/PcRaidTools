local addonName, PC = ...

----------------------------------------
-- Main Window
----------------------------------------

function PC:CreateMainWindow()
    local frame = CreateFrame("Frame", "PcRaidToolsMain", UIParent, "BackdropTemplate")
    frame:SetSize(300, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    -- Backdrop
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

    -- Make draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff00ccffPcRaidTools|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Escape to close
    tinsert(UISpecialFrames, "PcRaidToolsMain")

    ----------------------------------------
    -- Spell ID Input
    ----------------------------------------

    -- Buff / Debuff toggle
    local filterBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    filterBtn:SetSize(70, 22)
    filterBtn:SetPoint("TOPLEFT", 12, -38)
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

    -- Spell ID input
    local inputLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("LEFT", filterBtn, "RIGHT", 8, 0)
    inputLabel:SetText("Spell ID:")

    local inputBox = CreateFrame("EditBox", "PcRaidToolsSpellInput", frame, "InputBoxTemplate")
    inputBox:SetSize(80, 20)
    inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 6, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetNumeric(true)
    inputBox:SetMaxLetters(10)

    local trackBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
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

    -- Tracking status line
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 12, -65)
    statusText:SetText("|cff888888No aura tracked|r")
    self.statusText = statusText

    ----------------------------------------
    -- Roster Scroll Area
    ----------------------------------------

    local rosterHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rosterHeader:SetPoint("TOPLEFT", 12, -85)
    rosterHeader:SetText("Raid/Party Members:")

    -- Scroll frame for the roster list
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -102)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(240, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollChild = scrollChild
    self.rosterRows = {}

    -- Start hidden
    frame:Hide()

    self.mainWindow = frame
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
    row:SetSize(240, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(180)

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

    -- Hide all existing rows
    if scrollChild.rows then
        for _, row in pairs(scrollChild.rows) do
            row:Hide()
        end
    end

    -- Build sorted unit list
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

    -- Update status text
    if self.trackedSpellId then
        local spellName = C_Spell.GetSpellName(self.trackedSpellId)
        local label = spellName or ("ID: " .. self.trackedSpellId)
        local filterLabel = self.auraFilter == "HARMFUL" and "Debuff" or "Buff"
        self.statusText:SetText("Tracking " .. filterLabel .. ": |cffffcc00" .. label .. "|r")
    else
        self.statusText:SetText("|cff888888No aura tracked|r")
    end

    -- Populate rows
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

    -- Update scroll child height
    scrollChild:SetHeight(#units * ROW_HEIGHT)
end

-- Refresh the display whenever the window is shown
function PC:HookMainWindowShow()
    self.mainWindow:HookScript("OnShow", function()
        PC:ScanAuras()
    end)
end

function PC:ToggleMainWindow()
    if self.mainWindow:IsShown() then
        self.mainWindow:Hide()
    else
        self.mainWindow:Show()
    end
end
