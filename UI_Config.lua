local addonName, PC = ...

----------------------------------------
-- Font / Texture Pickers
----------------------------------------

local fontList = {
    { label = "Default",    path = "Fonts\\FRIZQT__.TTF" },
    { label = "Morpheus",   path = "Fonts\\MORPHEUS.TTF" },
    { label = "Arial",      path = "Fonts\\ARIALN.TTF" },
    { label = "Skurri",     path = "Fonts\\skurri.TTF" },
}

local function CreateFontPicker(parent, label, initialFont, x, y, onChange)
    local fontLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", x, y)
    fontLabel:SetText(label .. ":")

    local selected = initialFont

    local preview = parent:CreateFontString(nil, "OVERLAY")
    preview:SetPoint("TOPLEFT", x + 200, y)
    preview:SetFont(initialFont, 14, "OUTLINE")
    preview:SetText("AaBb123")

    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", fontLabel, "RIGHT", 2, -2)
    dropdown:SetWidth(130)

    dropdown:SetupMenu(function(_, rootDescription)
        for _, f in ipairs(fontList) do
            rootDescription:CreateRadio(f.label, function()
                return selected == f.path
            end, function()
                selected = f.path
                preview:SetFont(f.path, 14, "OUTLINE")
                onChange(f.path)
            end, f.path)
        end
    end)

    return dropdown
end

local barTextureList = {
    { label = "Default",    path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { label = "Smooth",     path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { label = "Flat",       path = "Interface\\Buttons\\WHITE8X8" },
    { label = "Blizzard",   path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

local function CreateTexturePicker(parent, label, initialTexture, x, y, onChange)
    local texLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    texLabel:SetPoint("TOPLEFT", x, y)
    texLabel:SetText(label .. ":")

    local selected = initialTexture

    local preview = CreateFrame("StatusBar", nil, parent)
    preview:SetSize(80, 14)
    preview:SetPoint("TOPLEFT", x + 200, y - 2)
    preview:SetStatusBarTexture(initialTexture)
    preview:SetStatusBarColor(0.9, 0.4, 0.1)
    preview:SetMinMaxValues(0, 1)
    preview:SetValue(0.7)

    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", texLabel, "RIGHT", 2, -2)
    dropdown:SetWidth(130)

    dropdown:SetupMenu(function(_, rootDescription)
        for _, t in ipairs(barTextureList) do
            rootDescription:CreateRadio(t.label, function()
                return selected == t.path
            end, function()
                selected = t.path
                preview:SetStatusBarTexture(t.path)
                onChange(t.path)
            end, t.path)
        end
    end)

    return dropdown
end

----------------------------------------
-- Timer Template Panels (Config tab)
----------------------------------------

function PC:BuildTextTemplatePanel(parent)
    local CreateSlider = PC.CreateSlider
    local CreateColorSwatch = PC.CreateColorSwatch
    local tmpl = self:GetTimerTemplate("text")
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Text Timer")

    local anchorBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    anchorBtn:SetSize(120, 20)
    anchorBtn:SetPoint("LEFT", header, "RIGHT", 12, 0)
    anchorBtn:SetText("Toggle Anchors")
    anchorBtn:SetScript("OnClick", function()
        PC:ToggleTimerAnchors()
    end)
    y = y - 32

    -- Font
    CreateFontPicker(parent, "Font", tmpl.font or "Fonts\\FRIZQT__.TTF", 0, y, function(path)
        PC:SaveTimerTemplateSetting("text", "font", path)
    end)
    y = y - 34

    -- Font Size
    CreateSlider(parent, "Font Size", 12, 48, 1, tmpl.fontSize, 0, y, function(val)
        PC:SaveTimerTemplateSetting("text", "fontSize", val)
    end)
    y = y - 40

    -- Font Color
    CreateColorSwatch(parent, "Font Color", tmpl.fontColor, 0, y, function(c)
        PC:SaveTimerTemplateSetting("text", "fontColor", c)
    end)
end

function PC:BuildBarTemplatePanel(parent)
    local CreateSlider = PC.CreateSlider
    local CreateColorSwatch = PC.CreateColorSwatch
    local tmpl = self:GetTimerTemplate("bar")
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Bar Timer")

    local anchorBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    anchorBtn:SetSize(120, 20)
    anchorBtn:SetPoint("LEFT", header, "RIGHT", 12, 0)
    anchorBtn:SetText("Toggle Anchors")
    anchorBtn:SetScript("OnClick", function()
        PC:ToggleTimerAnchors()
    end)
    y = y - 32

    -- Width
    CreateSlider(parent, "Width", 150, 400, 5, tmpl.width, 0, y, function(val)
        PC:SaveTimerTemplateSetting("bar", "width", val)
    end)
    y = y - 40

    -- Height
    CreateSlider(parent, "Height", 14, 40, 1, tmpl.height, 0, y, function(val)
        PC:SaveTimerTemplateSetting("bar", "height", val)
    end)
    y = y - 40

    -- Texture
    CreateTexturePicker(parent, "Texture", tmpl.barTexture or "Interface\\TargetingFrame\\UI-StatusBar", 0, y, function(path)
        PC:SaveTimerTemplateSetting("bar", "barTexture", path)
    end)
    y = y - 34

    -- Font
    CreateFontPicker(parent, "Font", tmpl.font or "Fonts\\FRIZQT__.TTF", 0, y, function(path)
        PC:SaveTimerTemplateSetting("bar", "font", path)
    end)
    y = y - 34

    -- Font Size
    CreateSlider(parent, "Font Size", 8, 24, 1, tmpl.fontSize, 0, y, function(val)
        PC:SaveTimerTemplateSetting("bar", "fontSize", val)
    end)
    y = y - 40

    -- Bar Color
    CreateColorSwatch(parent, "Bar Color", tmpl.barColor, 0, y, function(c)
        PC:SaveTimerTemplateSetting("bar", "barColor", c)
    end)
end
