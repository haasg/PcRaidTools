local addonName, PC = ...

----------------------------------------
-- Lura Matrix Settings Panel
----------------------------------------

function PC:BuildMatrixPanel(parent)
    PcRaidToolsDB = PcRaidToolsDB or {}
    if not PcRaidToolsDB.luraMatrix then
        PcRaidToolsDB.luraMatrix = {
            enabled = true,
            soundEnabled = true,
            soundId = 8959,
            ttsEnabled = true,
            ttsMessage = "Kick now",
            flashEnabled = true,
            onlyDuringEncounter = false,
        }
    end
    local s = PcRaidToolsDB.luraMatrix
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Matrix Kick Alert")
    y = y - 28

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 0, y)
    desc:SetText("Alerts you when someone says your name in raid chat (kick rotation).")
    y = y - 24

    -- Enable
    local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 0, y)
    enableCheck:SetChecked(s.enabled)
    enableCheck:SetScript("OnClick", function(self)
        s.enabled = self:GetChecked()
    end)
    local enableLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableLabel:SetText("Enabled")
    y = y - 28

    -- Only during encounter
    local encounterCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    encounterCheck:SetPoint("TOPLEFT", 0, y)
    encounterCheck:SetChecked(s.onlyDuringEncounter)
    encounterCheck:SetScript("OnClick", function(self)
        s.onlyDuringEncounter = self:GetChecked()
    end)
    local encounterLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    encounterLabel:SetPoint("LEFT", encounterCheck, "RIGHT", 4, 0)
    encounterLabel:SetText("Only during Lura encounter")
    y = y - 32

    -- Sound
    local soundHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundHeader:SetPoint("TOPLEFT", 0, y)
    soundHeader:SetText("|cffffcc00Notification Options|r")
    y = y - 22

    local soundCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", 0, y)
    soundCheck:SetChecked(s.soundEnabled)
    soundCheck:SetScript("OnClick", function(self)
        s.soundEnabled = self:GetChecked()
    end)
    local soundLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soundLabel:SetPoint("LEFT", soundCheck, "RIGHT", 4, 0)
    soundLabel:SetText("Play sound")
    y = y - 28

    -- Flash
    local flashCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    flashCheck:SetPoint("TOPLEFT", 0, y)
    flashCheck:SetChecked(s.flashEnabled)
    flashCheck:SetScript("OnClick", function(self)
        s.flashEnabled = self:GetChecked()
    end)
    local flashLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    flashLabel:SetPoint("LEFT", flashCheck, "RIGHT", 4, 0)
    flashLabel:SetText("Screen flash")
    y = y - 28

    -- TTS
    local ttsCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    ttsCheck:SetPoint("TOPLEFT", 0, y)
    ttsCheck:SetChecked(s.ttsEnabled)
    ttsCheck:SetScript("OnClick", function(self)
        s.ttsEnabled = self:GetChecked()
    end)
    local ttsLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("LEFT", ttsCheck, "RIGHT", 4, 0)
    ttsLabel:SetText("Text-to-speech")
    y = y - 28

    -- TTS message
    local ttsMessageLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ttsMessageLabel:SetPoint("TOPLEFT", 20, y)
    ttsMessageLabel:SetText("TTS Message:")

    local ttsBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    ttsBox:SetSize(140, 20)
    ttsBox:SetPoint("LEFT", ttsMessageLabel, "RIGHT", 6, 0)
    ttsBox:SetAutoFocus(false)
    ttsBox:SetMaxLetters(40)
    ttsBox:SetText(s.ttsMessage or "Kick now")
    ttsBox:SetScript("OnEnterPressed", function(self)
        s.ttsMessage = self:GetText()
        self:ClearFocus()
    end)
    ttsBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    y = y - 36

    -- Test button
    local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testBtn:SetSize(80, 22)
    testBtn:SetPoint("TOPLEFT", 0, y)
    testBtn:SetText("Test")
    testBtn:SetScript("OnClick", function()
        PC:TriggerMatrixKick()
    end)

    local testDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    testDesc:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    testDesc:SetText("|cffaaaaaaTriggers the alert as if someone said your name.|r")
end
