local addonName, PC = ...

----------------------------------------
-- Belo'ren Feather Debuff Indicator
--
-- Shows all harmful auras on the player as icons.
-- Uses the secret-safe chain:
-- secret spellId -> C_Spell.GetSpellTexture -> SetTexture
----------------------------------------

local LIGHT_FEATHER = 1241162
local DEFAULT_ICON_SIZE = 48
local MAX_ICONS = 6
local ICON_SPACING = 4

local featherDebug = false
local isUnlocked = false

-- Tracked debuffs: [auraInstanceID] = iconIndex
local activeDebuffs = {}
local activeCount = 0

local function SafeStr(val)
    if val == nil then return "nil" end
    if issecretvalue and issecretvalue(val) then return "SECRET" end
    local ok, str = pcall(tostring, val)
    return ok and str or "error"
end

local function DebugPrint(...)
    if not featherDebug then return end
    print("|cff00ccff[Feather]|r", ...)
end

----------------------------------------
-- Display Frames
----------------------------------------

local anchorFrame = CreateFrame("Frame", "PcRTFeatherIndicator", UIParent)
anchorFrame:SetSize(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE)
anchorFrame:SetPoint("CENTER")
anchorFrame:SetClampedToScreen(true)
anchorFrame:Hide()

local iconFrames = {}

local function CreateIconFrame(index)
    local f = CreateFrame("Frame", nil, anchorFrame)
    f:SetSize(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -2, 2)
    f.border:SetPoint("BOTTOMRIGHT", 2, -2)
    f.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    f.border:SetBackdropBorderColor(0, 0, 0, 0.9)

    f:Hide()
    return f
end

for i = 1, MAX_ICONS do
    iconFrames[i] = CreateIconFrame(i)
end

local currentIconSize = DEFAULT_ICON_SIZE

local function LayoutIcons()
    local size = currentIconSize
    for i, f in ipairs(iconFrames) do
        f:SetSize(size, size)
        f:ClearAllPoints()
        f:SetPoint("LEFT", anchorFrame, "LEFT", (i - 1) * (size + ICON_SPACING), 0)
    end
    -- Resize anchor to fit all visible icons
    local shown = math.max(activeCount, 1)
    anchorFrame:SetSize(shown * size + (shown - 1) * ICON_SPACING, size)
end

local function ChangeIconSize(value)
    currentIconSize = value
    LayoutIcons()
end

local function ShowExample()
    local tex = C_Spell.GetSpellTexture(LIGHT_FEATHER)
    iconFrames[1].icon:SetTexture(tex or 135994)
    iconFrames[1]:Show()
    for i = 2, MAX_ICONS do
        iconFrames[i]:Hide()
    end
    activeCount = 1
    LayoutIcons()
    anchorFrame:Show()
end

local function IsUnlocked()
    return isUnlocked
end

local function IsEnabled()
    return PcRaidToolsDB and PcRaidToolsDB.featherEnabled ~= false
end

----------------------------------------
-- Aura Tracking
----------------------------------------

local function RefreshDisplay()
    local idx = 0
    for instanceID, _ in pairs(activeDebuffs) do
        idx = idx + 1
        if idx > MAX_ICONS then break end
        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID)
        if auraData and auraData.spellId then
            local tex = C_Spell.GetSpellTexture(auraData.spellId)
            if tex then
                iconFrames[idx].icon:SetTexture(tex)
            end
            iconFrames[idx]:Show()
        end
    end
    for i = idx + 1, MAX_ICONS do
        iconFrames[i]:Hide()
    end
    activeCount = idx
    LayoutIcons()
    if idx > 0 then
        anchorFrame:Show()
    else
        if not IsUnlocked() then
            anchorFrame:Hide()
        end
    end
end

local function HideAll()
    if IsUnlocked() then return end
    wipe(activeDebuffs)
    activeCount = 0
    for i = 1, MAX_ICONS do
        iconFrames[i]:Hide()
    end
    anchorFrame:Hide()
end

local function HandleFullUpdate()
    if IsUnlocked() then return end

    wipe(activeDebuffs)

    local instanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL")
    if not instanceIDs then
        HideAll()
        return
    end

    DebugPrint("FullUpdate: " .. #instanceIDs .. " harmful auras")
    for _, auraInstanceID in ipairs(instanceIDs) do
        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID)
        if auraData then
            DebugPrint("  id=" .. SafeStr(auraInstanceID)
                .. " duration=" .. SafeStr(auraData.duration)
                .. " spell=" .. SafeStr(auraData.spellId)
                .. " name=" .. SafeStr(auraData.name)
                .. " icon=" .. SafeStr(auraData.icon))
        end
        if auraData and auraData.spellId then
            local IsFiltered = C_UnitAuras.IsAuraFilteredOutByInstanceID
            local passPlayer = not IsFiltered("player", auraInstanceID, "HARMFUL|PLAYER")
            if not passPlayer and auraData.expirationTime and issecretvalue and issecretvalue(auraData.expirationTime) then
                activeDebuffs[auraInstanceID] = true
            end
        end
    end

    RefreshDisplay()
end

local function HandleAddedAuras(addedAuras)
    if IsUnlocked() then return end

    local changed = false
    for _, auraData in ipairs(addedAuras) do
        local isDebuff = not C_UnitAuras.IsAuraFilteredOutByInstanceID("player", auraData.auraInstanceID, "HARMFUL")
        if not isDebuff then
            -- skip buffs
        elseif auraData.spellId then
            local id = auraData.auraInstanceID
            local IsFiltered = C_UnitAuras.IsAuraFilteredOutByInstanceID
            local passRaid = not IsFiltered("player", id, "HARMFUL|RAID")
            local passCC = AuraUtil and AuraUtil.AuraFilters and AuraUtil.AuraFilters.CrowdControl
                and not IsFiltered("player", id, "HARMFUL|" .. AuraUtil.AuraFilters.CrowdControl) or false
            local passDisp = not IsFiltered("player", id, "HARMFUL|RAID_PLAYER_DISPELLABLE")

            local passPlayer = not IsFiltered("player", id, "HARMFUL|PLAYER")
            local passNotCancel = not IsFiltered("player", id, "HARMFUL|NOT_CANCELABLE")

            DebugPrint("Added debuff: id=" .. SafeStr(id)
                .. " spell=" .. SafeStr(auraData.spellId)
                .. " name=" .. SafeStr(auraData.name)
                .. " icon=" .. SafeStr(auraData.icon)
                .. " duration=" .. SafeStr(auraData.duration)
                .. " expTime=" .. SafeStr(auraData.expirationTime)
                .. " dispel=" .. SafeStr(auraData.dispelName)
                .. " source=" .. SafeStr(auraData.sourceUnit)
                .. " fromPlayer=" .. SafeStr(auraData.isFromPlayerOrPlayerPet)
                .. " stealable=" .. SafeStr(auraData.isStealable)
                .. " charges=" .. SafeStr(auraData.charges)
                .. " maxCharges=" .. SafeStr(auraData.maxCharges)
                .. " canApply=" .. SafeStr(auraData.canApplyAura)
                .. " isBossAura=" .. SafeStr(auraData.isBossAura)
                .. " isNameplate=" .. SafeStr(auraData.nameplateShowAll)
                .. " |cffffcc00RAID=" .. tostring(passRaid)
                .. " CC=" .. tostring(passCC)
                .. " DISP=" .. tostring(passDisp)
                .. " PLAYER=" .. tostring(passPlayer)
                .. " NOT_CANCEL=" .. tostring(passNotCancel) .. "|r")

            if passPlayer then
                DebugPrint("  SKIPPED (PLAYER=true, player-cast)")
            elseif not (auraData.expirationTime and issecretvalue and issecretvalue(auraData.expirationTime)) then
                DebugPrint("  SKIPPED (expirationTime not secret)")
            else
                activeDebuffs[id] = true
                changed = true
            end
        end
    end
    if changed then
        RefreshDisplay()
    end
end

local function HandleRemovedAuras(removedIDs)
    if IsUnlocked() then return end

    local changed = false
    for _, auraInstanceID in ipairs(removedIDs) do
        if activeDebuffs[auraInstanceID] then
            activeDebuffs[auraInstanceID] = nil
            changed = true
            DebugPrint("Removed debuff: id=" .. SafeStr(auraInstanceID))
        end
    end
    if changed then
        RefreshDisplay()
    end
end

----------------------------------------
-- Events
----------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_END" or event == "PLAYER_DEAD" then
        HideAll()
        return
    elseif event == "UNIT_AURA" then
        if not IsEnabled() then return end
        local unit, updateInfo = ...
        if unit ~= "player" or not updateInfo then return end

        if updateInfo.isFullUpdate then
            HandleFullUpdate()
        else
            if updateInfo.addedAuras then
                HandleAddedAuras(updateInfo.addedAuras)
            end
            if updateInfo.removedAuraInstanceIDs then
                HandleRemovedAuras(updateInfo.removedAuraInstanceIDs)
            end
        end
    end
end)

----------------------------------------
-- Position / Size Management
----------------------------------------

local function SavePosition()
    local point, _, _, x, y = anchorFrame:GetPoint(1)
    PcRaidToolsDB.feather = PcRaidToolsDB.feather or {}
    PcRaidToolsDB.feather.point = point
    PcRaidToolsDB.feather.x = x
    PcRaidToolsDB.feather.y = y
end

local function LoadPosition()
    PcRaidToolsDB = PcRaidToolsDB or {}
    PcRaidToolsDB.feather = PcRaidToolsDB.feather or {}
    local data = PcRaidToolsDB.feather
    local point = data.point or "CENTER"
    local x = data.x or 0
    local y = data.y or 200
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint(point, UIParent, point, x, y)
    ChangeIconSize(data.iconSize or DEFAULT_ICON_SIZE)
end

anchorFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    LoadPosition()
    PC.featherFrame = anchorFrame
end)

----------------------------------------
-- Config helpers (called from UI.lua)
----------------------------------------

function PC:SetFeatherUnlocked(unlock)
    isUnlocked = unlock
    if unlock then
        anchorFrame:SetMovable(true)
        anchorFrame:RegisterForDrag("LeftButton")
        anchorFrame:EnableMouse(true)
        anchorFrame:SetScript("OnDragStart", function(self)
            if not InCombatLockdown() then
                self:StartMoving()
            end
        end)
        ShowExample()
    else
        anchorFrame:SetMovable(false)
        anchorFrame:RegisterForDrag()
        anchorFrame:EnableMouse(false)
        anchorFrame:SetScript("OnDragStart", nil)
        if next(activeDebuffs) == nil then
            for i = 1, MAX_ICONS do
                iconFrames[i]:Hide()
            end
            activeCount = 0
            anchorFrame:Hide()
        end
    end
end

function PC:IsFeatherUnlocked()
    return isUnlocked
end

function PC:SetFeatherIconSize(value)
    PcRaidToolsDB = PcRaidToolsDB or {}
    PcRaidToolsDB.feather = PcRaidToolsDB.feather or {}
    PcRaidToolsDB.feather.iconSize = value
    ChangeIconSize(value)
end

function PC:GetFeatherIconSize()
    PcRaidToolsDB = PcRaidToolsDB or {}
    PcRaidToolsDB.feather = PcRaidToolsDB.feather or {}
    return PcRaidToolsDB.feather.iconSize or DEFAULT_ICON_SIZE
end

function PC:ToggleFeatherDebug()
    featherDebug = not featherDebug
    print("|cff00ccff[PcRaidTools]|r Feather debug " .. (featherDebug and "ON" or "OFF"))
end

function PC:ShowFeatherPreview()
    ShowExample()
end

function PC:HideFeatherPreview()
    if next(activeDebuffs) == nil and not IsUnlocked() then
        for i = 1, MAX_ICONS do
            iconFrames[i]:Hide()
        end
        activeCount = 0
        anchorFrame:Hide()
    end
end
