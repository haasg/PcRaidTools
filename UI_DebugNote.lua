local addonName, PC = ...

----------------------------------------
-- Note Panel
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

    local dispelStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dispelStatus:SetPoint("TOPLEFT", 0, -28)
    dispelStatus:SetText("")
    self.dispelStatus = dispelStatus

    -- Left column: Parsed note list
    local parsedHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    parsedHeader:SetPoint("TOPLEFT", 0, -44)
    parsedHeader:SetText("Note List:")

    local parsedScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    parsedScroll:SetPoint("TOPLEFT", 0, -60)
    parsedScroll:SetSize(200, 185)

    local parsedChild = CreateFrame("Frame")
    parsedChild:SetSize(185, 1)
    parsedScroll:SetScrollChild(parsedChild)
    self.parsedChild = parsedChild

    -- Right column: Raid roster
    local rosterHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rosterHeader:SetPoint("TOPLEFT", 220, -44)
    rosterHeader:SetText("Raid Roster:")

    self.rosterCountText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.rosterCountText:SetPoint("LEFT", rosterHeader, "RIGHT", 4, 0)
    self.rosterCountText:SetText("")

    local rosterScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    rosterScroll:SetPoint("TOPLEFT", 220, -60)
    rosterScroll:SetSize(200, 185)

    local rosterChild = CreateFrame("Frame")
    rosterChild:SetSize(185, 1)
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
    editBox:SetWidth(440)
    editBox:SetText("")
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    rawScroll:SetScrollChild(editBox)
    self.noteEditBox = editBox

    rawScroll:SetScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(w)
    end)
end

----------------------------------------
-- Note Row Helpers
----------------------------------------

local NOTE_ROW_HEIGHT = 18

local function SpeakDispel(name)
    if C_VoiceChat and C_VoiceChat.SpeakText then
        local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0
        C_VoiceChat.SpeakText(0, name, rate, 100, true)
    end
end

local function GetOrCreateNoteRow(parent, index)
    parent.rows = parent.rows or {}
    if parent.rows[index] then
        return parent.rows[index]
    end

    local parentWidth = parent:GetWidth() or 185
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
    if #self.parseErrors > 0 and #self.parsedPlayers == 0 then
        self.noteStatus:SetText("|cffff4444Parse failed|r")
        local row = GetOrCreateNoteRow(parsedChild, 1)
        row.text:SetText("|cffff4444" .. self.parseErrors[1] .. "|r")
        row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        row.icon:Show()
        row:Show()
        parsedChild:SetHeight(NOTE_ROW_HEIGHT)
        return
    end

    -- Config rows
    local rowIdx = 1
    local threshRow = GetOrCreateNoteRow(parsedChild, rowIdx)
    threshRow.text:SetText("Threshold: |cffffcc00" .. self.auraThreshold .. "|r  CD: |cffffcc00" .. self.triggerCooldown .. "s|r")
    threshRow.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    threshRow.icon:Show()
    threshRow:Show()

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
        self.dispelStatus:SetText("|cff44ff44Healer #" .. self.myHealerIndex .. "|r | Threshold: " .. self.auraThreshold)
    elseif #self.parsedPlayers > 0 then
        self.dispelStatus:SetText("|cffffaa00Not in healer list|r | Threshold: " .. self.auraThreshold)
    else
        self.dispelStatus:SetText("")
    end
end
