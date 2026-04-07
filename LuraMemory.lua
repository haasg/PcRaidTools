local addonName, PC = ...

----------------------------------------
-- Lura Memory Game
--
-- Button presser: 5 secure buttons that
-- send pc-circle etc to raid chat.
-- Memory map: listens for those messages
-- and displays a sequence of 5 icons.
----------------------------------------

local SHAPE_DEFS = {
    { message = "pc-circle",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", color = {1.0, 0.5, 0.0} },
    { message = "pc-triangle", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", color = {0.0, 0.8, 0.0} },
    { message = "pc-diamond",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", color = {0.6, 0.0, 0.8} },
    { message = "pc-x",        icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", color = {0.9, 0.1, 0.1} },
    { message = "pc-t",        icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", color = {0.2, 0.4, 1.0} },
}

-- Lookup message -> shape def
local MESSAGE_TO_SHAPE = {}
for _, def in ipairs(SHAPE_DEFS) do
    MESSAGE_TO_SHAPE[def.message] = def
end

local ICON_SIZE = 48
local ICON_SPACING = 8
local DISPLAY_DURATION = 15
local MAX_SEQUENCE = 5
local BUTTON_SIZE = 40
local BUTTON_SPACING = 8

local buttonsUnlocked = false
local displayUnlocked = false

----------------------------------------
-- SavedVariables helpers
----------------------------------------

local function GetSettings()
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
    return PcRaidToolsDB.luraMemory
end

----------------------------------------
-- Memory Button Presser (5 buttons)
----------------------------------------

local buttonAnchor = CreateFrame("Frame", "PcRTMemoryButtons", UIParent)
buttonAnchor:SetSize(5 * BUTTON_SIZE + 4 * BUTTON_SPACING, BUTTON_SIZE)
buttonAnchor:SetPoint("CENTER", 0, -200)
buttonAnchor:SetClampedToScreen(true)
buttonAnchor:Hide()

local memoryButtons = {}

for i = 1, 5 do
    local def = SHAPE_DEFS[i]
    local btn = CreateFrame("Button", "PcRTMemoryBtn" .. i, buttonAnchor, "SecureActionButtonTemplate")
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

    memoryButtons[i] = btn
end

buttonAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s = GetSettings()
    local point, _, _, x, y = self:GetPoint(1)
    s.buttonPoint = point
    s.buttonX = x
    s.buttonY = y
end)

----------------------------------------
-- Memory Game Map (display)
----------------------------------------

local displayAnchor = CreateFrame("Frame", "PcRTMemoryDisplay", UIParent)
displayAnchor:SetSize(MAX_SEQUENCE * ICON_SIZE + (MAX_SEQUENCE - 1) * ICON_SPACING, ICON_SIZE + 20)
displayAnchor:SetPoint("CENTER", 0, 150)
displayAnchor:SetClampedToScreen(true)
displayAnchor:Hide()

-- Background
displayAnchor.bg = displayAnchor:CreateTexture(nil, "BACKGROUND")
displayAnchor.bg:SetAllPoints()
displayAnchor.bg:SetColorTexture(0, 0, 0, 0.5)

-- Sequence icon slots
local displaySlots = {}
for i = 1, MAX_SEQUENCE do
    local slot = CreateFrame("Frame", nil, displayAnchor)
    slot:SetSize(ICON_SIZE, ICON_SIZE)
    slot:SetPoint("LEFT", (i - 1) * (ICON_SIZE + ICON_SPACING), 6)

    slot.bg = slot:CreateTexture(nil, "BACKGROUND")
    slot.bg:SetAllPoints()
    slot.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 4, -4)
    slot.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    slot.icon:Hide()

    slot.number = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.number:SetPoint("BOTTOM", 0, -12)
    slot.number:SetText(tostring(i))
    slot.number:SetTextColor(0.6, 0.6, 0.6)

    displaySlots[i] = slot
end

-- Timer bar
local timerBar = CreateFrame("StatusBar", nil, displayAnchor)
timerBar:SetSize(displayAnchor:GetWidth(), 4)
timerBar:SetPoint("BOTTOM", displayAnchor, "BOTTOM", 0, 0)
timerBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
timerBar:SetStatusBarColor(1, 0.8, 0)
timerBar:SetMinMaxValues(0, DISPLAY_DURATION)
timerBar:Hide()

displayAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s = GetSettings()
    local point, _, _, x, y = self:GetPoint(1)
    s.displayPoint = point
    s.displayX = x
    s.displayY = y
end)

----------------------------------------
-- Sequence State
----------------------------------------

local sequence = {}  -- array of shape defs, up to 5
local displayTimer = nil
local displayStartTime = nil

local function ClearSequence()
    wipe(sequence)
    for i = 1, MAX_SEQUENCE do
        displaySlots[i].icon:Hide()
        displaySlots[i].bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    end
    timerBar:Hide()
    displayStartTime = nil
    if not displayUnlocked then
        displayAnchor:Hide()
    end
end

local function UpdateDisplay()
    local s = GetSettings()
    if not s.memoryMap then return end

    for i = 1, MAX_SEQUENCE do
        local shape = sequence[i]
        if shape then
            displaySlots[i].icon:SetTexture(shape.icon)
            displaySlots[i].icon:Show()
            displaySlots[i].bg:SetColorTexture(
                shape.color[1] * 0.15,
                shape.color[2] * 0.15,
                shape.color[3] * 0.15,
                0.9
            )
        else
            displaySlots[i].icon:Hide()
            displaySlots[i].bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        end
    end

    displayAnchor:Show()

    -- Start or restart the 15-second timer
    displayStartTime = GetTime()
    timerBar:SetValue(DISPLAY_DURATION)
    timerBar:Show()

    if displayTimer then
        displayTimer:Cancel()
    end
    displayTimer = C_Timer.NewTimer(DISPLAY_DURATION, function()
        ClearSequence()
    end)
end

-- Timer bar update
local tickFrame = CreateFrame("Frame", nil, displayAnchor)
tickFrame:SetScript("OnUpdate", function()
    if displayStartTime and timerBar:IsShown() then
        local remaining = DISPLAY_DURATION - (GetTime() - displayStartTime)
        if remaining < 0 then remaining = 0 end
        timerBar:SetValue(remaining)
    end
end)

local function AddShape(shapeDef)
    if #sequence >= MAX_SEQUENCE then return end
    sequence[#sequence + 1] = shapeDef
    UpdateDisplay()
end

----------------------------------------
-- Chat Listener
----------------------------------------

local chatFrame = CreateFrame("Frame")
chatFrame:RegisterEvent("CHAT_MSG_RAID")
chatFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
chatFrame:SetScript("OnEvent", function(self, event, msg, ...)
    local s = GetSettings()
    if not s.memoryMap then return end

    local trimmed = msg:trim()
    local shape = MESSAGE_TO_SHAPE[trimmed]
    if shape then
        AddShape(shape)
    end
end)

----------------------------------------
-- Position Loading
----------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    local s = GetSettings()

    -- Button position
    buttonAnchor:ClearAllPoints()
    buttonAnchor:SetPoint(s.buttonPoint or "CENTER", UIParent, s.buttonPoint or "CENTER", s.buttonX or 0, s.buttonY or -200)

    -- Display position
    displayAnchor:ClearAllPoints()
    displayAnchor:SetPoint(s.displayPoint or "CENTER", UIParent, s.displayPoint or "CENTER", s.displayX or 0, s.displayY or 150)
end)

----------------------------------------
-- API for UI panel
----------------------------------------

function PC:SetMemoryButtonsEnabled(enabled)
    local s = GetSettings()
    s.buttonPresser = enabled
    if enabled then
        if not InCombatLockdown() then
            buttonAnchor:Show()
        end
    else
        if not InCombatLockdown() then
            buttonAnchor:Hide()
        end
        -- Also lock if disabling
        if buttonsUnlocked then
            PC:SetMemoryButtonsUnlocked(false)
        end
    end
end

function PC:AreMemoryButtonsEnabled()
    return GetSettings().buttonPresser
end

function PC:SetMemoryButtonsUnlocked(unlock)
    buttonsUnlocked = unlock
    if unlock then
        buttonAnchor:SetMovable(true)
        buttonAnchor:RegisterForDrag("LeftButton")
        buttonAnchor:EnableMouse(true)
        buttonAnchor:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then
                self:StartMoving()
            end
        end)
        if not InCombatLockdown() then
            buttonAnchor:Show()
        end
    else
        buttonAnchor:StopMovingOrSizing()
        buttonAnchor:SetMovable(false)
        buttonAnchor:RegisterForDrag()
        buttonAnchor:EnableMouse(false)
        buttonAnchor:SetScript("OnDragStart", nil)
    end
end

function PC:AreMemoryButtonsUnlocked()
    return buttonsUnlocked
end

function PC:SetMemoryDisplayUnlocked(unlock)
    displayUnlocked = unlock
    if unlock then
        displayAnchor:SetMovable(true)
        displayAnchor:RegisterForDrag("LeftButton")
        displayAnchor:EnableMouse(true)
        displayAnchor:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then
                self:StartMoving()
            end
        end)
        -- Show with placeholder icons for positioning
        for i = 1, MAX_SEQUENCE do
            displaySlots[i].icon:SetTexture(SHAPE_DEFS[i].icon)
            displaySlots[i].icon:Show()
            displaySlots[i].bg:SetColorTexture(
                SHAPE_DEFS[i].color[1] * 0.15,
                SHAPE_DEFS[i].color[2] * 0.15,
                SHAPE_DEFS[i].color[3] * 0.15,
                0.9
            )
        end
        displayAnchor:Show()
    else
        displayAnchor:StopMovingOrSizing()
        displayAnchor:SetMovable(false)
        displayAnchor:RegisterForDrag()
        displayAnchor:EnableMouse(false)
        displayAnchor:SetScript("OnDragStart", nil)
        -- Hide if no active sequence
        if #sequence == 0 then
            for i = 1, MAX_SEQUENCE do
                displaySlots[i].icon:Hide()
                displaySlots[i].bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            end
            displayAnchor:Hide()
        end
    end
end

function PC:IsMemoryDisplayUnlocked()
    return displayUnlocked
end

function PC:TestMemorySequence()
    ClearSequence()
    -- Add all 5 shapes with a small stagger
    for i = 1, MAX_SEQUENCE do
        C_Timer.After((i - 1) * 0.3, function()
            AddShape(SHAPE_DEFS[i])
        end)
    end
end

function PC:ClearMemorySequence()
    ClearSequence()
end
