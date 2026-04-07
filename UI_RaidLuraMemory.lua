local addonName, PC = ...

----------------------------------------
-- Lura Memory Settings Panel
----------------------------------------

function PC:BuildMemoryPanel(parent)
    PcRaidToolsDB = PcRaidToolsDB or {}
    if not PcRaidToolsDB.luraMemory then
        PcRaidToolsDB.luraMemory = {
            buttonPresser = false,
            memoryMap = true,
            buttonPoint = "CENTER",
            buttonX = 0,
            buttonY = -200,
            displayPoint = "CENTER",
            displayX = 0,
            displayY = 150,
        }
    end
    local s = PcRaidToolsDB.luraMemory
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Memory Game")
    y = y - 28

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 0, y)
    desc:SetText("Communicate the 5-shape sequence via raid chat buttons and display.")
    y = y - 28

    ----------------------------------------
    -- Button Presser Section
    ----------------------------------------

    local bpHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bpHeader:SetPoint("TOPLEFT", 0, y)
    bpHeader:SetText("|cffffcc00Button Presser|r")
    y = y - 22

    local bpDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bpDesc:SetPoint("TOPLEFT", 0, y)
    bpDesc:SetText("|cffaaaaaaEnable if you are assigned to press rune buttons. Sends shapes to raid chat.|r")
    y = y - 20

    local bpCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    bpCheck:SetPoint("TOPLEFT", 0, y)
    bpCheck:SetChecked(s.buttonPresser)
    bpCheck:SetScript("OnClick", function(self)
        PC:SetMemoryButtonsEnabled(self:GetChecked())
    end)
    local bpLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bpLabel:SetPoint("LEFT", bpCheck, "RIGHT", 4, 0)
    bpLabel:SetText("Memory button presser")
    y = y - 28

    -- Unlock buttons position
    local bpUnlockBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    bpUnlockBtn:SetSize(140, 22)
    bpUnlockBtn:SetPoint("TOPLEFT", 20, y)
    bpUnlockBtn:SetText("Unlock Buttons")
    bpUnlockBtn:SetScript("OnClick", function(self)
        local newState = not PC:AreMemoryButtonsUnlocked()
        PC:SetMemoryButtonsUnlocked(newState)
        self:SetText(newState and "Lock Buttons" or "Unlock Buttons")
    end)

    local bpUnlockDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bpUnlockDesc:SetPoint("LEFT", bpUnlockBtn, "RIGHT", 8, 0)
    bpUnlockDesc:SetText("|cffaaaaaaDrag to reposition the buttons.|r")
    y = y - 36

    ----------------------------------------
    -- Memory Map Section
    ----------------------------------------

    local mmHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmHeader:SetPoint("TOPLEFT", 0, y)
    mmHeader:SetText("|cffffcc00Memory Game Map|r")
    y = y - 22

    local mmDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mmDesc:SetPoint("TOPLEFT", 0, y)
    mmDesc:SetText("|cffaaaaaaDisplays the shape sequence from raid chat. Auto-hides after 15 seconds.|r")
    y = y - 20

    local mmCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    mmCheck:SetPoint("TOPLEFT", 0, y)
    mmCheck:SetChecked(s.memoryMap)
    mmCheck:SetScript("OnClick", function(self)
        s.memoryMap = self:GetChecked()
    end)
    local mmLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mmLabel:SetPoint("LEFT", mmCheck, "RIGHT", 4, 0)
    mmLabel:SetText("Memory game map")
    y = y - 28

    -- Unlock display position
    local mmUnlockBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    mmUnlockBtn:SetSize(140, 22)
    mmUnlockBtn:SetPoint("TOPLEFT", 20, y)
    mmUnlockBtn:SetText("Unlock Display")
    mmUnlockBtn:SetScript("OnClick", function(self)
        local newState = not PC:IsMemoryDisplayUnlocked()
        PC:SetMemoryDisplayUnlocked(newState)
        self:SetText(newState and "Lock Display" or "Unlock Display")
    end)

    local mmUnlockDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mmUnlockDesc:SetPoint("LEFT", mmUnlockBtn, "RIGHT", 8, 0)
    mmUnlockDesc:SetText("|cffaaaaaaDrag to reposition the display.|r")
    y = y - 36

    ----------------------------------------
    -- Test / Clear
    ----------------------------------------

    local testHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", 0, y)
    testHeader:SetText("|cffffcc00Testing|r")
    y = y - 22

    local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testBtn:SetSize(80, 22)
    testBtn:SetPoint("TOPLEFT", 0, y)
    testBtn:SetText("Test")
    testBtn:SetScript("OnClick", function()
        PC:TestMemorySequence()
    end)

    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PC:ClearMemorySequence()
    end)

    local testDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    testDesc:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    testDesc:SetText("|cffaaaaaaSimulates a 5-shape sequence.|r")
end
