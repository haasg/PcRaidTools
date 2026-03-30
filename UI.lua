local addonName, PC = ...

local TAB_HEIGHT = 24
local CONTENT_TOP = -60

----------------------------------------
-- Tab System
----------------------------------------

local tabs = {}
local tabContents = {}
local activeTab = nil

-- Raid tab hierarchy: bosses with mechanics
local raidBossButtons = {}   -- bossKey -> button frame
local raidMechButtons = {}   -- "bossKey.mechKey" -> button frame
local raidPanels = {}        -- "bossKey.mechKey" -> detail panel frame
local activeRaidPanel = nil  -- "bossKey.mechKey"
local raidSidebarChild = nil -- scroll child for repositioning

local debugEntries = {}
local debugPanels = {}
local activeDebugPanel = nil

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

----------------------------------------
-- Sidebar Layout Builder (flat list, used by Debug tab)
----------------------------------------

local function CreateSidebarLayout(parent, entries, entryTable, panelTable, onSelect)
    local sidebar = CreateFrame("Frame", nil, parent)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(120)

    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(0.15, 0.15, 0.15, 0.5)

    local detail = CreateFrame("Frame", nil, parent)
    detail:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    detail:SetPoint("BOTTOMRIGHT", 0, 0)

    for i, name in ipairs(entries) do
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(110, 24)
        btn:SetPoint("TOPLEFT", 5, -((i - 1) * 28))

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 8, 0)
        btn.text:SetText(name)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)

        btn:SetScript("OnClick", function()
            onSelect(name)
        end)

        entryTable[name] = btn
    end

    for _, name in ipairs(entries) do
        local panel = CreateFrame("Frame", nil, detail)
        panel:SetAllPoints()
        panel:Hide()
        panelTable[name] = panel
    end
end

----------------------------------------
-- Boss Hierarchy Sidebar (used by Raid tab)
----------------------------------------

-- Boss/mechanic definition: { bossKey, bossLabel, mechanics = { {mechKey, mechLabel}, ... } }
local raidBossData = {
    {
        key = "Vanguard",
        label = "Vanguard",
        mechanics = {
            { key = "Dispel", label = "Dispel" },
        },
    },
    {
        key = "Cosmos",
        label = "Cosmos",
        mechanics = {
            { key = "Explosion", label = "Explosion" },
        },
    },
}

local function LayoutRaidSidebar()
    if not raidSidebarChild then return end
    local yOffset = 0
    for _, boss in ipairs(raidBossData) do
        local bossBtn = raidBossButtons[boss.key]
        if bossBtn then
            bossBtn:ClearAllPoints()
            bossBtn:SetPoint("TOPLEFT", 2, -yOffset)
            bossBtn:Show()
            yOffset = yOffset + 24
        end
        if boss.expanded then
            for _, mech in ipairs(boss.mechanics) do
                local fullKey = boss.key .. "." .. mech.key
                local mechBtn = raidMechButtons[fullKey]
                if mechBtn then
                    mechBtn:ClearAllPoints()
                    mechBtn:SetPoint("TOPLEFT", 12, -yOffset)
                    mechBtn:Show()
                    yOffset = yOffset + 22
                end
            end
        else
            for _, mech in ipairs(boss.mechanics) do
                local fullKey = boss.key .. "." .. mech.key
                local mechBtn = raidMechButtons[fullKey]
                if mechBtn then
                    mechBtn:Hide()
                end
            end
        end
        yOffset = yOffset + 2 -- small gap between bosses
    end
    raidSidebarChild:SetHeight(yOffset)
end

local function CreateRaidSidebarLayout(parent)
    -- Sidebar container
    local sidebar = CreateFrame("Frame", nil, parent)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(130)

    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(0.15, 0.15, 0.15, 0.5)

    raidSidebarChild = sidebar

    -- Detail area
    local detail = CreateFrame("Frame", nil, parent)
    detail:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    detail:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Create boss headers and mechanic buttons
    for _, boss in ipairs(raidBossData) do
        boss.expanded = true -- start expanded

        -- Boss header button
        local bossBtn = CreateFrame("Button", nil, sidebar)
        bossBtn:SetSize(116, 22)

        bossBtn.bg = bossBtn:CreateTexture(nil, "BACKGROUND")
        bossBtn.bg:SetAllPoints()
        bossBtn.bg:SetColorTexture(0.25, 0.2, 0.1, 0.8)

        bossBtn.arrow = bossBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bossBtn.arrow:SetPoint("LEFT", 4, 0)
        bossBtn.arrow:SetText("v")

        bossBtn.text = bossBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bossBtn.text:SetPoint("LEFT", 14, 0)
        bossBtn.text:SetText("|cffffcc00" .. boss.label .. "|r")

        bossBtn:SetScript("OnClick", function()
            boss.expanded = not boss.expanded
            bossBtn.arrow:SetText(boss.expanded and "v" or ">")
            LayoutRaidSidebar()
        end)

        raidBossButtons[boss.key] = bossBtn

        -- Mechanic buttons
        for _, mech in ipairs(boss.mechanics) do
            local fullKey = boss.key .. "." .. mech.key
            local mechBtn = CreateFrame("Button", nil, sidebar)
            mechBtn:SetSize(104, 20)

            mechBtn.bg = mechBtn:CreateTexture(nil, "BACKGROUND")
            mechBtn.bg:SetAllPoints()
            mechBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)

            mechBtn.text = mechBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            mechBtn.text:SetPoint("LEFT", 6, 0)
            mechBtn.text:SetText(mech.label)

            mechBtn:SetScript("OnClick", function()
                PC:SelectRaidPanel(fullKey)
            end)

            raidMechButtons[fullKey] = mechBtn

            -- Detail panel
            local panel = CreateFrame("Frame", nil, detail)
            panel:SetAllPoints()
            panel:Hide()
            raidPanels[fullKey] = panel
        end
    end

    LayoutRaidSidebar()
end

----------------------------------------
-- Sub-panel Selection
----------------------------------------

function PC:SelectRaidPanel(fullKey)
    for panelName, panel in pairs(raidPanels) do
        panel:Hide()
        if raidMechButtons[panelName] then
            raidMechButtons[panelName].bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
            raidMechButtons[panelName].text:SetTextColor(0.6, 0.6, 0.6)
        end
    end
    if raidPanels[fullKey] then
        raidPanels[fullKey]:Show()
    end
    if raidMechButtons[fullKey] then
        raidMechButtons[fullKey].bg:SetColorTexture(0.3, 0.3, 0.5, 0.9)
        raidMechButtons[fullKey].text:SetTextColor(1, 1, 1)
    end
    activeRaidPanel = fullKey
end

function PC:SelectDebugPanel(name)
    for panelName, panel in pairs(debugPanels) do
        panel:Hide()
        debugEntries[panelName].bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
        debugEntries[panelName].text:SetTextColor(0.6, 0.6, 0.6)
    end
    debugPanels[name]:Show()
    debugEntries[name].bg:SetColorTexture(0.3, 0.3, 0.5, 0.9)
    debugEntries[name].text:SetTextColor(1, 1, 1)
    activeDebugPanel = name

    if name == "Note" then
        PC:RefreshNoteDisplay()
    elseif name == "Tracker" then
        PC:ScanAuras()
    end
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

    if name == "Raid" then
        if activeRaidPanel then
            PC:SelectRaidPanel(activeRaidPanel)
        end
    elseif name == "Debug" then
        if activeDebugPanel then
            PC:SelectDebugPanel(activeDebugPanel)
        end
    end
end

----------------------------------------
-- Main Window
----------------------------------------

function PC:CreateMainWindow()
    local frame = CreateFrame("Frame", "PcRaidToolsMain", UIParent, "BackdropTemplate")
    frame:SetSize(620, 550)
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
    title:SetText("|cff00ccffPcRaidTools|r - v" .. PC.VERSION)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    tinsert(UISpecialFrames, "PcRaidToolsMain")

    -- Tabs
    CreateTab(frame, "Raid", 1)
    CreateTab(frame, "Debug", 2)

    -- Tab content containers
    tabContents["Raid"] = CreateTabContent(frame)
    tabContents["Debug"] = CreateTabContent(frame)

    -- Build Raid tab with boss hierarchy sidebar
    CreateRaidSidebarLayout(tabContents["Raid"])
    self:BuildDispelSettingsPanel(raidPanels["Vanguard.Dispel"])
    self:BuildExplosionPanel(raidPanels["Cosmos.Explosion"])

    -- Build Debug tab with sidebar
    CreateSidebarLayout(tabContents["Debug"], { "Tracker", "Note", "Glow" }, debugEntries, debugPanels, function(name)
        PC:SelectDebugPanel(name)
    end)
    self:BuildTrackerTab(debugPanels["Tracker"])
    self:BuildNoteTab(debugPanels["Note"])
    self:BuildGlowTab(debugPanels["Glow"])

    frame:Hide()
    self.mainWindow = frame

    -- Default selections
    self:SelectRaidPanel("Vanguard.Dispel")
    self:SelectDebugPanel("Tracker")
    self:SelectTab("Raid")
end

----------------------------------------
-- Dispel Settings Panel (formerly Config Tab)
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

function PC:BuildDispelSettingsPanel(parent)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText("Dispel Settings")

    -- TTS checkbox
    local ttsCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    ttsCheck:SetPoint("TOPLEFT", 0, -24)
    ttsCheck:SetChecked(PC.ttsEnabled)
    ttsCheck:SetScript("OnClick", function(self)
        PC.ttsEnabled = self:GetChecked()
    end)

    local ttsLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ttsLabel:SetPoint("LEFT", ttsCheck, "RIGHT", 4, 0)
    ttsLabel:SetText("TTS announce on dispel glow")

    -- Glow Style
    local styleLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 0, -58)
    styleLabel:SetText("Glow Style:")

    local styles = { "solid", "pulse", "thick" }
    local styleButtons = {}
    for i, style in ipairs(styles) do
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(70, 20)
        btn:SetPoint("TOPLEFT", (i - 1) * 74, -74)
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

    -- Glow Size
    CreateSlider(parent, "Size", 1, 8, 1, PC.glowSize, 0, -108, function(val)
        PC.glowSize = val
    end)

    -- Color preview swatch
    local colorLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", 0, -142)
    colorLabel:SetText("Glow Color:")

    local swatch = parent:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 6, 0)
    swatch:SetColorTexture(PC.glowColor.r, PC.glowColor.g, PC.glowColor.b)

    -- R slider
    local rSlider = CreateSlider(parent, "R", 0, 1, 0.05, PC.glowColor.r, 0, -170, function(val)
        PC.glowColor.r = val
        swatch:SetColorTexture(PC.glowColor.r, PC.glowColor.g, PC.glowColor.b)
    end)

    -- G slider
    local gSlider = CreateSlider(parent, "G", 0, 1, 0.05, PC.glowColor.g, 0, -206, function(val)
        PC.glowColor.g = val
        swatch:SetColorTexture(PC.glowColor.r, PC.glowColor.g, PC.glowColor.b)
    end)

    -- B slider
    local bSlider = CreateSlider(parent, "B", 0, 1, 0.05, PC.glowColor.b, 0, -242, function(val)
        PC.glowColor.b = val
        swatch:SetColorTexture(PC.glowColor.r, PC.glowColor.g, PC.glowColor.b)
    end)

    -- Test glow buttons
    local testStatus = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    testStatus:SetPoint("TOPLEFT", 0, -272)
    testStatus:SetText("")

    local testOnBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testOnBtn:SetSize(70, 22)
    testOnBtn:SetPoint("TOPLEFT", 0, -286)
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
-- Placeholder Panel (for mechanics not yet implemented)
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
    local rule = self.bossTimerRules["Cosmos.Explosion"]

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText("Void Expulsion Timers")

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 0, -22)
    desc:SetText("|cff888888Bait countdown + Explosion bar from Timeline API|r")

    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 0, -44)
    enableCheck:SetChecked(rule.enabled)
    enableCheck:SetScript("OnClick", function(self)
        rule.enabled = self:GetChecked()
    end)

    local enableLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableLabel:SetText("Enabled")

    -- Trigger info display
    local infoY = -80
    for i, trigger in ipairs(rule.triggers) do
        local info = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        info:SetPoint("TOPLEFT", 0, infoY)
        if trigger.startAt > 0 then
            info:SetText("|cffffcc00" .. trigger.type:upper() .. "|r  \"" .. trigger.label .. "\"  " .. trigger.duration .. "s, starts at " .. trigger.startAt .. "s remaining")
        elseif trigger.startAt < 0 then
            info:SetText("|cffffcc00" .. trigger.type:upper() .. "|r  \"" .. trigger.label .. "\"  " .. trigger.duration .. "s, starts " .. math.abs(trigger.startAt) .. "s after timeline ends")
        else
            info:SetText("|cffffcc00" .. trigger.type:upper() .. "|r  \"" .. trigger.label .. "\"  " .. trigger.duration .. "s, starts when timeline ends")
        end
        infoY = infoY - 18
    end

    -- Test button
    local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testBtn:SetSize(80, 22)
    testBtn:SetPoint("TOPLEFT", 0, infoY - 10)
    testBtn:SetText("Test")
    testBtn:SetScript("OnClick", function()
        PC:TestBossTimer("Cosmos.Explosion")
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PC:ClearBossTimers()
    end)

    -- Move anchors button
    local moveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    moveBtn:SetSize(120, 22)
    moveBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    moveBtn:SetText("Move Anchors")
    moveBtn:SetScript("OnClick", function()
        PC:ToggleTimerAnchors()
    end)

    local status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 0, infoY - 38)
    status:SetText("|cff888888Use Test to preview. Move Anchors to reposition on screen.|r")
end

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

-- Refresh the display whenever the window is shown
function PC:HookMainWindowShow()
    self.mainWindow:HookScript("OnShow", function()
        if activeTab == "Debug" then
            if activeDebugPanel == "Tracker" then
                PC:ScanAuras()
            elseif activeDebugPanel == "Note" then
                PC:RefreshNoteDisplay()
            end
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
