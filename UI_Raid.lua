local addonName, PC = ...

----------------------------------------
-- Shared UI Helpers
----------------------------------------

PC.ttsEnabled = true

local function CreateSlider(parent, label, min, max, step, initial, x, y, onChange)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetSize(120, 16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initial)
    slider.Low:SetText(min)
    slider.High:SetText(max)
    slider.Text:SetText(label .. ": " .. initial)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.Text:SetText(label .. ": " .. string.format("%.2f", value))
        onChange(value)
    end)
    return slider
end

local function CreateColorSwatch(parent, label, initialColor, x, y, onChange)
    local colorLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", x, y)
    colorLabel:SetText(label .. ":")

    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 6, 0)

    swatch.tex = swatch:CreateTexture(nil, "ARTWORK")
    swatch.tex:SetAllPoints()
    swatch.tex:SetColorTexture(initialColor.r, initialColor.g, initialColor.b)

    swatch.border = swatch:CreateTexture(nil, "OVERLAY")
    swatch.border:SetPoint("TOPLEFT", -1, 1)
    swatch.border:SetPoint("BOTTOMRIGHT", 1, -1)
    swatch.border:SetColorTexture(0.5, 0.5, 0.5, 1)
    swatch.tex:SetDrawLayer("OVERLAY", 1)

    swatch:SetScript("OnClick", function()
        local prev = { r = initialColor.r, g = initialColor.g, b = initialColor.b }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = initialColor.r,
            g = initialColor.g,
            b = initialColor.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                initialColor.r = r
                initialColor.g = g
                initialColor.b = b
                swatch.tex:SetColorTexture(r, g, b)
                onChange(initialColor)
            end,
            cancelFunc = function()
                initialColor.r = prev.r
                initialColor.g = prev.g
                initialColor.b = prev.b
                swatch.tex:SetColorTexture(prev.r, prev.g, prev.b)
                onChange(initialColor)
            end,
        })
    end)

    return swatch
end

-- Store helpers on PC so other files can use them
PC.CreateSlider = CreateSlider
PC.CreateColorSwatch = CreateColorSwatch

----------------------------------------
-- Dispel Settings Panel
----------------------------------------

function PC:BuildDispelSettingsPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Dispel Settings")
    y = y - 28

    -- TTS checkbox
    local ttsCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    ttsCheck:SetPoint("TOPLEFT", 0, y)
    ttsCheck:SetChecked(PC.ttsEnabled)
    ttsCheck:SetScript("OnClick", function(self)
        PC.ttsEnabled = self:GetChecked()
    end)
    local ttsLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("LEFT", ttsCheck, "RIGHT", 4, 0)
    ttsLabel:SetText("TTS announce on dispel glow")
    y = y - 30

    -- Glow Style
    local styleLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 0, y)
    styleLabel:SetText("Glow Style:")
    y = y - 18

    local styles = { "solid", "pulse", "thick" }
    local styleButtons = {}
    for i, style in ipairs(styles) do
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(70, 20)
        btn:SetPoint("TOPLEFT", (i - 1) * 74, y)
        btn:SetText(style:sub(1,1):upper() .. style:sub(2))
        btn:SetScript("OnClick", function()
            PC.glowStyle = style
            for _, b in ipairs(styleButtons) do
                b:SetAlpha(0.5)
            end
            btn:SetAlpha(1)
        end)
        btn:SetAlpha(style == PC.glowStyle and 1 or 0.5)
        styleButtons[i] = btn
    end
    y = y - 28

    -- Glow Size
    CreateSlider(parent, "Size", 1, 8, 1, PC.glowSize, 0, y, function(val)
        PC.glowSize = val
    end)
    y = y - 38

    -- Glow Color
    CreateColorSwatch(parent, "Glow Color", PC.glowColor, 0, y, function(c)
        PC.glowColor = c
    end)
    y = y - 32

    -- Test glow buttons
    local testStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    testStatus:SetPoint("TOPLEFT", 0, y)
    testStatus:SetText("")
    y = y - 16

    local testOnBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testOnBtn:SetSize(70, 22)
    testOnBtn:SetPoint("TOPLEFT", 0, y)
    testOnBtn:SetText("Test On")
    testOnBtn:SetScript("OnClick", function()
        local myName = UnitName("player")
        PC:ClearAllGlows()
        local success, msg = PC:GlowPlayer(myName)
        if success then
            testStatus:SetText("|cff44ff44Glow ON on " .. myName .. "|r")
        else
            testStatus:SetText("|cffff4444" .. msg .. "|r")
        end
    end)

    local testOffBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testOffBtn:SetSize(70, 22)
    testOffBtn:SetPoint("LEFT", testOnBtn, "RIGHT", 6, 0)
    testOffBtn:SetText("Test Off")
    testOffBtn:SetScript("OnClick", function()
        PC:ClearAllGlows()
        testStatus:SetText("|cffaaaaaaGlow cleared|r")
    end)
end

----------------------------------------
-- Placeholder Panel
----------------------------------------

function PC:BuildPlaceholderPanel(parent, mechName)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(mechName .. " Settings")

    local placeholder = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    placeholder:SetPoint("TOPLEFT", 0, -30)
    placeholder:SetText("|cff888888Coming soon.|r")
end

----------------------------------------
-- Explosion Panel (Cosmos)
----------------------------------------

function PC:BuildExplosionPanel(parent)
    self:BuildMechanicPanel(parent, "Cosmos.Explosion", "Void Expulsion Timers")
end

-- Generic mechanic panel (enable/disable + trigger info + test)
function PC:BuildMechanicPanel(parent, ruleKey, title)
    local rule = self.bossTimerRules[ruleKey]
    if not rule then return end
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText(title)
    y = y - 28

    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 0, y)
    enableCheck:SetChecked(rule.enabled)
    enableCheck:SetScript("OnClick", function(self)
        rule.enabled = self:GetChecked()
    end)
    local enableLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableLabel:SetText("Enabled")
    y = y - 30

    -- Trigger info
    for _, trigger in ipairs(rule.triggers) do
        local info = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        info:SetPoint("TOPLEFT", 0, y)
        if trigger.startAt > 0 then
            info:SetText("|cffffcc00" .. trigger.type:upper() .. "|r  \"" .. trigger.label .. "\"  " .. trigger.duration .. "s, starts at " .. trigger.startAt .. "s remaining")
        elseif trigger.startAt < 0 then
            info:SetText("|cffffcc00" .. trigger.type:upper() .. "|r  \"" .. trigger.label .. "\"  " .. trigger.duration .. "s, starts " .. math.abs(trigger.startAt) .. "s after timeline ends")
        else
            info:SetText("|cffffcc00" .. trigger.type:upper() .. "|r  \"" .. trigger.label .. "\"  " .. trigger.duration .. "s, starts when timeline ends")
        end
        y = y - 20
    end
    y = y - 8

    -- Test / Clear
    local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testBtn:SetSize(80, 22)
    testBtn:SetPoint("TOPLEFT", 0, y)
    testBtn:SetText("Test")
    testBtn:SetScript("OnClick", function()
        PC:TestBossTimer(ruleKey)
    end)

    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PC:ClearBossTimers()
    end)
end

----------------------------------------
-- Belo'ren Feather Panel
----------------------------------------

function PC:BuildFeatherPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Feather Indicator")
    y = y - 28

    -- Enable checkbox
    PcRaidToolsDB = PcRaidToolsDB or {}
    if PcRaidToolsDB.featherEnabled == nil then PcRaidToolsDB.featherEnabled = true end

    local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 0, y)
    enableCheck:SetChecked(PcRaidToolsDB.featherEnabled)
    enableCheck:SetScript("OnClick", function(self)
        PcRaidToolsDB.featherEnabled = self:GetChecked()
    end)
    local enableLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableLabel:SetText("Enabled")
    y = y - 30

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 0, y)
    desc:SetText("Shows Light Feather or Void Feather debuff icon on your screen.")
    y = y - 30

    -- Icon Size slider
    local sizeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 0, y)
    sizeLabel:SetText("Icon Size")

    local sizeValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeValue:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
    sizeValue:SetText(tostring(PC:GetFeatherIconSize()))
    y = y - 22

    local sizeSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 0, y)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(20, 80)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetValue(PC:GetFeatherIconSize())
    sizeSlider.Low:SetText("20")
    sizeSlider.High:SetText("80")
    sizeSlider.Text:SetText("")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        PC:SetFeatherIconSize(value)
        sizeValue:SetText(tostring(value))
    end)
    y = y - 36

    -- Unlock / Lock position button
    local unlockBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    unlockBtn:SetSize(120, 22)
    unlockBtn:SetPoint("TOPLEFT", 0, y)
    unlockBtn:SetText("Unlock Position")
    unlockBtn:SetScript("OnClick", function(self)
        local newState = not PC:IsFeatherUnlocked()
        PC:SetFeatherUnlocked(newState)
        self:SetText(newState and "Lock Position" or "Unlock Position")
    end)

    local unlockDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockDesc:SetPoint("LEFT", unlockBtn, "RIGHT", 8, 0)
    unlockDesc:SetText("|cffaaaaaaUnlock to drag the icon to a new position.|r")
end
