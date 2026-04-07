local addonName, PC = ...

----------------------------------------
-- Glow Panel
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
