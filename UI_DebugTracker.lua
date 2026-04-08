local addonName, PC = ...

----------------------------------------
-- Tracker Panel
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
    scrollChild:SetSize(440, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollChild = scrollChild
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
    row:SetSize(440, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(380)

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
