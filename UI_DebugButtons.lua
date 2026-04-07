local addonName, PC = ...

----------------------------------------
-- Buttons Debug Panel
----------------------------------------

function PC:BuildButtonsDebugPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Raid Buttons")
    y = y - 28

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 0, y)
    desc:SetText("5 on-screen buttons that send messages to raid chat.")
    y = y - 28

    -- Create the 5 secure buttons (parented to UIParent so they persist)
    -- Raid target icons: 1=star, 2=circle, 3=diamond, 4=triangle, 5=moon, 6=square, 7=cross(x), 8=skull
    local buttonDefs = {
        { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", message = "pc-circle",   color = {1.0, 0.5, 0.0} },
        { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", message = "pc-triangle", color = {0.0, 0.8, 0.0} },
        { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", message = "pc-diamond",  color = {0.6, 0.0, 0.8} },
        { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", message = "pc-x",        color = {0.9, 0.1, 0.1} },
        { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", message = "pc-t",        color = {0.2, 0.4, 1.0} },
    }

    local BUTTON_SIZE = 40
    local BUTTON_SPACING = 8
    local raidButtons = {}

    local buttonAnchor = CreateFrame("Frame", "PcRTRaidButtons", UIParent)
    buttonAnchor:SetSize(5 * BUTTON_SIZE + 4 * BUTTON_SPACING, BUTTON_SIZE)
    buttonAnchor:SetPoint("CENTER", 0, -200)
    buttonAnchor:SetClampedToScreen(true)
    buttonAnchor:Hide()

    for i = 1, 5 do
        local def = buttonDefs[i]
        local btn = CreateFrame("Button", "PcRTRaidButton" .. i, buttonAnchor, "SecureActionButtonTemplate")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn:SetPoint("LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_SPACING), 0)

        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/run SendChatMessage(\"" .. def.message .. "\", \"RAID\")")

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(def.color[1] * 0.2, def.color[2] * 0.2, def.color[3] * 0.2, 0.9)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 4, -4)
        btn.icon:SetPoint("BOTTOMRIGHT", -4, 4)
        btn.icon:SetTexture(def.icon)

        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        raidButtons[i] = btn
    end

    PC.raidButtonAnchor = buttonAnchor

    -- Show / Hide buttons in the panel
    local showBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    showBtn:SetSize(80, 22)
    showBtn:SetPoint("TOPLEFT", 0, y)
    showBtn:SetText("Show")
    showBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            buttonAnchor:Show()
        end
    end)

    local hideBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    hideBtn:SetSize(80, 22)
    hideBtn:SetPoint("LEFT", showBtn, "RIGHT", 8, 0)
    hideBtn:SetText("Hide")
    hideBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            buttonAnchor:Hide()
        end
    end)
end
