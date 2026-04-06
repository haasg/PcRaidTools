local addonName, PC = ...

----------------------------------------
-- Belo'ren Feather Debuff Indicator
----------------------------------------

local LIGHT_FEATHER = 1241162
local VOID_FEATHER = 1241163

local DEFAULT_ICON_SIZE = 48

----------------------------------------
-- Display Frame
----------------------------------------

local featherFrame = CreateFrame("Frame", "PcRTFeatherIndicator", UIParent)
featherFrame:SetSize(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE)
featherFrame:SetPoint("CENTER")
featherFrame:SetClampedToScreen(true)

featherFrame.icon = featherFrame:CreateTexture(nil, "BACKGROUND")
featherFrame.icon:SetAllPoints()
featherFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

featherFrame.border = CreateFrame("Frame", nil, featherFrame, "BackdropTemplate")
featherFrame.border:SetPoint("TOPLEFT", -2, 2)
featherFrame.border:SetPoint("BOTTOMRIGHT", 2, -2)
featherFrame.border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
})
featherFrame.border:SetBackdropBorderColor(0, 0, 0, 0.9)

featherFrame:Hide()

local function ChangeIconSize(value)
    featherFrame:SetSize(value, value)
end

local function ShowExample()
    local info = C_Spell.GetSpellInfo(LIGHT_FEATHER)
    if info and info.iconID then
        featherFrame.icon:SetTexture(info.iconID)
    else
        featherFrame.icon:SetTexture(135994)
    end
    featherFrame:Show()
end

----------------------------------------
-- Aura Scanning
----------------------------------------

local activeSpellId = nil
local LEM_ref = nil -- set after PLAYER_LOGIN

local function IsInEditMode()
    return LEM_ref and LEM_ref:IsInEditMode()
end

local function CheckFeatherDebuff()
    if IsInEditMode() then return end

    for i = 1, 40 do
        local aura = C_UnitAuras.GetDebuffDataByIndex("player", i)
        if not aura then break end
        if not (issecretvalue and issecretvalue(aura.spellId)) and (aura.spellId == LIGHT_FEATHER or aura.spellId == VOID_FEATHER) then
            if activeSpellId ~= aura.spellId then
                activeSpellId = aura.spellId
                local info = C_Spell.GetSpellInfo(aura.spellId)
                if info and info.iconID then
                    featherFrame.icon:SetTexture(info.iconID)
                end
            end
            featherFrame:Show()
            return
        end
    end
    activeSpellId = nil
    featherFrame:Hide()
end

local function HideFeather()
    if IsInEditMode() then return end
    activeSpellId = nil
    featherFrame:Hide()
end

----------------------------------------
-- Events
----------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            CheckFeatherDebuff()
        end
    elseif event == "ENCOUNTER_END" or event == "PLAYER_DEAD" then
        HideFeather()
    end
end)

----------------------------------------
-- Edit Mode Integration (LibEditMode)
----------------------------------------

local editModeFrame = CreateFrame("Frame")
editModeFrame:RegisterEvent("PLAYER_LOGIN")
editModeFrame:SetScript("OnEvent", function()
    PcRaidToolsDB = PcRaidToolsDB or {}
    PcRaidToolsDB.feather = PcRaidToolsDB.feather or {}

    local defaultData = {
        point = "CENTER",
        x = 0,
        y = 200,
        iconSize = DEFAULT_ICON_SIZE,
    }

    local function displayPositionChanged(frame, layout, point, x, y)
        PcRaidToolsDB.feather[layout] = PcRaidToolsDB.feather[layout] or CopyTable(defaultData)
        PcRaidToolsDB.feather[layout].point = point
        PcRaidToolsDB.feather[layout].x = x
        PcRaidToolsDB.feather[layout].y = y
    end

    local LEM = LibStub("LibEditMode")
    LEM_ref = LEM

    LEM:RegisterCallback("enter", function()
        ShowExample()
    end)

    LEM:RegisterCallback("exit", function()
        if not activeSpellId then
            featherFrame:Hide()
        end
    end)

    LEM:RegisterCallback("layout", function(layout)
        if not PcRaidToolsDB.feather[layout] then
            PcRaidToolsDB.feather[layout] = CopyTable(defaultData)
        end
        local data = PcRaidToolsDB.feather[layout]
        featherFrame:ClearAllPoints()
        featherFrame:SetPoint(data.point, data.x, data.y)
        ChangeIconSize(data.iconSize)
    end)

    LEM:AddFrame(featherFrame, displayPositionChanged, defaultData)

    LEM:AddFrameSettings(featherFrame, {
        {
            name = "Icon Size",
            kind = LEM.SettingType.Slider,
            default = defaultData.iconSize,
            get = function(layout)
                return PcRaidToolsDB.feather[layout] and PcRaidToolsDB.feather[layout].iconSize or defaultData.iconSize
            end,
            set = function(layout, value)
                PcRaidToolsDB.feather[layout] = PcRaidToolsDB.feather[layout] or CopyTable(defaultData)
                PcRaidToolsDB.feather[layout].iconSize = value
                ChangeIconSize(value)
            end,
            minValue = 20,
            maxValue = 80,
            valueStep = 1,
        },
    })

    -- Store ref for UI config
    PC.featherFrame = featherFrame
end)

----------------------------------------
-- Config helpers (called from UI.lua)
----------------------------------------

function PC:TestFeatherIndicator()
    ShowExample()
    C_Timer.After(3, function()
        if not activeSpellId then
            featherFrame:Hide()
        end
    end)
end
