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
    frame:SetSize(380, 500)
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
    CreateTab(frame, "Glow", 3)

    -- Tab content containers
    tabContents["Tracker"] = CreateTabContent(frame)
    tabContents["Note"] = CreateTabContent(frame)
    tabContents["Glow"] = CreateTabContent(frame)

    -- Build each tab's content
    self:BuildTrackerTab(tabContents["Tracker"])
    self:BuildNoteTab(tabContents["Note"])
    self:BuildGlowTab(tabContents["Glow"])

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
    readBtn:SetText("Read & Parse")
    readBtn:SetScript("OnClick", function()
        PC:ReadAndParseNote()
        PC:RefreshNoteDisplay()
    end)

    local noteStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteStatus:SetPoint("LEFT", readBtn, "RIGHT", 8, 0)
    noteStatus:SetText("")
    self.noteStatus = noteStatus

    local threshLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    threshLabel:SetPoint("TOPLEFT", 0, -28)
    threshLabel:SetText("Threshold:")

    local threshBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    threshBox:SetSize(30, 18)
    threshBox:SetPoint("LEFT", threshLabel, "RIGHT", 4, 0)
    threshBox:SetAutoFocus(false)
    threshBox:SetNumeric(true)
    threshBox:SetMaxLetters(2)
    threshBox:SetText(tostring(PC.auraThreshold))
    threshBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 then
            PC.auraThreshold = val
        end
        self:ClearFocus()
    end)
    threshBox:SetScript("OnEditFocusLost", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 then
            PC.auraThreshold = val
        else
            self:SetText(tostring(PC.auraThreshold))
        end
    end)

    local dispelStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dispelStatus:SetPoint("LEFT", threshBox, "RIGHT", 10, 0)
    dispelStatus:SetText("")
    self.dispelStatus = dispelStatus

    -- Left column: Parsed note list
    local parsedHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    parsedHeader:SetPoint("TOPLEFT", 0, -44)
    parsedHeader:SetText("Note List:")

    local parsedScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    parsedScroll:SetPoint("TOPLEFT", 0, -60)
    parsedScroll:SetSize(150, 185)

    local parsedChild = CreateFrame("Frame")
    parsedChild:SetSize(135, 1)
    parsedScroll:SetScrollChild(parsedChild)
    self.parsedChild = parsedChild

    -- Right column: Raid roster
    local rosterHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rosterHeader:SetPoint("TOPLEFT", 165, -44)
    rosterHeader:SetText("Raid Roster:")

    self.rosterCountText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.rosterCountText:SetPoint("LEFT", rosterHeader, "RIGHT", 4, 0)
    self.rosterCountText:SetText("")

    local rosterScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    rosterScroll:SetPoint("TOPLEFT", 165, -60)
    rosterScroll:SetSize(150, 185)

    local rosterChild = CreateFrame("Frame")
    rosterChild:SetSize(135, 1)
    rosterScroll:SetScrollChild(rosterChild)
    self.rosterChild = rosterChild

    -- Raw note area (bottom)
    local rawHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rawHeader:SetPoint("TOPLEFT", 0, -250)
    rawHeader:SetText("Raw Note:")

    local rawScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    rawScroll:SetPoint("TOPLEFT", 0, -266)
    rawScroll:SetPoint("BOTTOMRIGHT", -18, 0)

    local editBox = CreateFrame("EditBox", nil, rawScroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(280)
    editBox:SetText("")
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    rawScroll:SetScrollChild(editBox)
    self.noteEditBox = editBox

    rawScroll:SetScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(w)
    end)
end

local NOTE_ROW_HEIGHT = 18

local function SpeakDispel(name)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0
        C_VoiceChat.SpeakText(0, "dispel " .. name, rate, 100, true)
    end
end

local function GetOrCreateNoteRow(parent, index)
    parent.rows = parent.rows or {}
    if parent.rows[index] then
        return parent.rows[index]
    end

    local parentWidth = parent:GetWidth() or 135
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parentWidth, NOTE_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * NOTE_ROW_HEIGHT))

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 18, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWidth(parentWidth - 40)

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(12, 12)
    row.icon:SetPoint("LEFT", 2, 0)

    row.ttsBtn = CreateFrame("Button", nil, row)
    row.ttsBtn:SetSize(14, 14)
    row.ttsBtn:SetPoint("RIGHT", -2, 0)
    row.ttsBtn.icon = row.ttsBtn:CreateTexture(nil, "ARTWORK")
    row.ttsBtn.icon:SetAllPoints()
    row.ttsBtn.icon:SetAtlas("chatframe-button-icon-voicechat")
    row.ttsBtn.icon:SetAlpha(0.5)
    row.ttsBtn:SetScript("OnClick", function()
        if row.playerName then
            SpeakDispel(row.playerName)
        end
    end)
    row.ttsBtn:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1)
    end)
    row.ttsBtn:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(0.5)
    end)
    row.ttsBtn:Hide()

    parent.rows[index] = row
    return row
end

local function HideAllRows(container)
    if container.rows then
        for _, row in pairs(container.rows) do
            row:Hide()
        end
    end
end

function PC:RefreshNoteDisplay()
    local parsedChild = self.parsedChild
    local rosterChild = self.rosterChild
    if not parsedChild or not rosterChild then return end

    HideAllRows(parsedChild)
    HideAllRows(rosterChild)

    -- Always refresh raid roster
    self:RefreshRosterList()

    -- Status
    if not self:HasMRT() then
        self.noteStatus:SetText("|cffff4444MRT not found|r")
        self.noteEditBox:SetText("MRT (Method Raid Tools) is not loaded.\nInstall MRT to use this feature.")
        return
    end

    -- Raw note display
    if self.lastNoteText and self.lastNoteText ~= "" then
        self.noteEditBox:SetText(self.lastNoteText)
    else
        self.noteEditBox:SetText("(Note is empty)")
    end

    -- Show errors if any
    if #self.parseErrors > 0 and not self.parsedSpellId and #self.parsedPlayers == 0 then
        self.noteStatus:SetText("|cffff4444Parse failed|r")
        local row = GetOrCreateNoteRow(parsedChild, 1)
        row.text:SetText("|cffff4444" .. self.parseErrors[1] .. "|r")
        row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        row.icon:Show()
        row:Show()
        parsedChild:SetHeight(NOTE_ROW_HEIGHT)
        return
    end

    -- Spell ID row
    local rowIdx = 1
    local spellRow = GetOrCreateNoteRow(parsedChild, rowIdx)
    if self.parsedSpellId then
        local spellName = C_Spell.GetSpellName(self.parsedSpellId)
        local label = spellName and (spellName .. " (" .. self.parsedSpellId .. ")") or tostring(self.parsedSpellId)
        spellRow.text:SetText("|cffffcc00" .. label .. "|r")
        spellRow.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    else
        spellRow.text:SetText("|cff888888No spell ID|r")
        spellRow.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    end
    spellRow.icon:Show()
    spellRow:Show()

    -- Player rows
    local warnings = 0
    for i, entry in ipairs(self.parsedPlayers) do
        rowIdx = rowIdx + 1
        local row = GetOrCreateNoteRow(parsedChild, rowIdx)
        row.text:SetText(i .. ". " .. entry.name)
        if entry.found then
            row.text:SetTextColor(0.3, 1, 0.3)
            row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        else
            row.text:SetTextColor(1, 0.2, 0.2)
            row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
            warnings = warnings + 1
        end
        row.icon:Show()
        row:Show()
    end

    -- Error rows (non-player errors only)
    for _, err in ipairs(self.parseErrors) do
        if not err:match("^Player not found") then
            rowIdx = rowIdx + 1
            local row = GetOrCreateNoteRow(parsedChild, rowIdx)
            row.text:SetText("|cffff4444" .. err .. "|r")
            row.text:SetTextColor(1, 1, 1)
            row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
            row.icon:Show()
            row:Show()
        end
    end

    parsedChild:SetHeight(rowIdx * NOTE_ROW_HEIGHT)

    -- Update status
    if warnings > 0 then
        self.noteStatus:SetText("|cffffaa00Parsed with " .. warnings .. " warning(s)|r")
    elseif #self.parsedPlayers > 0 then
        self.noteStatus:SetText("|cff44ff44Parsed OK - " .. #self.parsedPlayers .. " players|r")
    else
        self.noteStatus:SetText("|cffaaaaaaNo data parsed|r")
    end

    self:RefreshDispelStatus()
end

----------------------------------------
-- Raid Roster List
----------------------------------------

function PC:RefreshRosterList()
    local rosterChild = self.rosterChild
    if not rosterChild then return end

    HideAllRows(rosterChild)

    -- Build alphabetically sorted name list
    local names = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    names[#names + 1] = name
                end
            end
        end
    else
        if UnitExists("player") then
            local name = UnitName("player")
            if name then
                names[#names + 1] = name
            end
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    names[#names + 1] = name
                end
            end
        end
    end

    table.sort(names)

    -- Count warning
    local count = #names
    if count == 20 then
        self.rosterCountText:SetText("|cff44ff44(" .. count .. ")|r")
    else
        self.rosterCountText:SetText("|cffff4444(" .. count .. "/20)|r")
    end

    -- Display rows
    for i, name in ipairs(names) do
        local row = GetOrCreateNoteRow(rosterChild, i)
        row.text:SetText(name)
        row.text:SetTextColor(0.8, 0.8, 0.8)
        row.icon:Hide()
        row.playerName = name
        row.ttsBtn:Show()
        row:Show()
    end

    rosterChild:SetHeight(count * NOTE_ROW_HEIGHT)
end

----------------------------------------
-- Dispel Status
----------------------------------------

function PC:RefreshDispelStatus()
    if not self.dispelStatus then return end

    if self.myHealerIndex then
        self.dispelStatus:SetText("|cff44ff44You are healer #" .. self.myHealerIndex .. "|r - dispels active")
    elseif self.parsedSpellId and #self.parsedPlayers > 0 then
        self.dispelStatus:SetText("|cffffaa00You are not in the healer list|r")
    else
        self.dispelStatus:SetText("")
    end
end

----------------------------------------
-- Glow Tab
----------------------------------------

function PC:BuildGlowTab(parent)
    local nameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 0, 0)
    nameLabel:SetText("Player Name:")

    local nameBox = CreateFrame("EditBox", "PcRaidToolsGlowInput", parent, "InputBoxTemplate")
    nameBox:SetSize(120, 20)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(24)

    local glowBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    glowBtn:SetSize(60, 22)
    glowBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    glowBtn:SetText("Glow")

    local glowStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    glowStatus:SetPoint("TOPLEFT", 0, -28)
    glowStatus:SetText("")
    self.glowStatus = glowStatus

    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 22)
    clearBtn:SetPoint("TOPLEFT", 0, -48)
    clearBtn:SetText("Clear")

    local clearAllBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearAllBtn:SetSize(80, 22)
    clearAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
    clearAllBtn:SetText("Clear All")

    glowBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():trim()
        local success, msg = PC:GlowPlayer(name)
        if success then
            glowStatus:SetText("|cff44ff44" .. msg .. "|r")
        else
            glowStatus:SetText("|cffff4444" .. msg .. "|r")
        end
        nameBox:ClearFocus()
    end)

    nameBox:SetScript("OnEnterPressed", function()
        glowBtn:Click()
    end)

    clearBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():trim()
        if name ~= "" then
            PC:ClearGlowByName(name)
            glowStatus:SetText("|cffaaaaaaCleared glow on " .. name .. "|r")
        end
    end)

    clearAllBtn:SetScript("OnClick", function()
        PC:ClearAllGlows()
        glowStatus:SetText("|cffaaaaaaAll glows cleared|r")
    end)
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
