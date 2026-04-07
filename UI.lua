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

local configEntries = {}
local configPanels = {}
local activeConfigPanel = nil

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
        key = "Beloren",
        label = "Belo'ren",
        mechanics = {
            { key = "Feather", label = "Feather" },
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
        local btn = raidMechButtons[panelName]
        if btn then
            btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
            btn.text:SetTextColor(0.6, 0.6, 0.6)
        end
    end
    raidPanels[fullKey]:Show()
    local btn = raidMechButtons[fullKey]
    if btn then
        btn.bg:SetColorTexture(0.3, 0.3, 0.5, 0.9)
        btn.text:SetTextColor(1, 1, 1)
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
end

function PC:SelectConfigPanel(name)
    for panelName, panel in pairs(configPanels) do
        panel:Hide()
        configEntries[panelName].bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
        configEntries[panelName].text:SetTextColor(0.6, 0.6, 0.6)
    end
    configPanels[name]:Show()
    configEntries[name].bg:SetColorTexture(0.3, 0.3, 0.5, 0.9)
    configEntries[name].text:SetTextColor(1, 1, 1)
    activeConfigPanel = name
end

function PC:SelectTab(name)
    for tabName, content in pairs(tabContents) do
        content:Hide()
        tabs[tabName].bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    end
    tabContents[name]:Show()
    tabs[name].bg:SetColorTexture(0.3, 0.3, 0.5, 0.9)
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
    frame:SetSize(620, 460)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    title:SetText("PcRaidTools  |cff888888v" .. version .. "|r")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Tabs
    CreateTab(frame, "Raid", 1)
    CreateTab(frame, "Debug", 2)

    tabContents["Raid"] = CreateTabContent(frame)
    tabContents["Debug"] = CreateTabContent(frame)

    -- Build Raid tab with boss hierarchy
    CreateRaidSidebarLayout(tabContents["Raid"])
    self:BuildDispelSettingsPanel(raidPanels["Vanguard.Dispel"])
    self:BuildFeatherPanel(raidPanels["Beloren.Feather"])

    -- Build Debug tab with sidebar
    CreateSidebarLayout(tabContents["Debug"], { "Tracker", "Note", "Glow", "Timeline", "Chat", "Encounter", "Buttons" }, debugEntries, debugPanels, function(name)
        PC:SelectDebugPanel(name)
    end)
    self:BuildTrackerTab(debugPanels["Tracker"])
    self:BuildNoteTab(debugPanels["Note"])
    self:BuildGlowTab(debugPanels["Glow"])
    self:BuildTimelineDebugPanel(debugPanels["Timeline"])
    self:BuildChatDebugPanel(debugPanels["Chat"])
    self:BuildEncounterDebugPanel(debugPanels["Encounter"])
    self:BuildButtonsDebugPanel(debugPanels["Buttons"])

    frame:Hide()
    self.mainWindow = frame

    -- Default selections
    self:SelectRaidPanel("Vanguard.Dispel")
    self:SelectDebugPanel("Tracker")
    self:SelectTab("Raid")
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
