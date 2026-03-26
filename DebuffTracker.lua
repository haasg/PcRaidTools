local addonName, PC = ...

----------------------------------------
-- Aura Tracker (Buffs & Debuffs)
----------------------------------------

PC.trackedSpellId = nil
PC.auraFilter = "HARMFUL"  -- "HARMFUL" or "HELPFUL"
PC.auraStatus = {}  -- [unit] = true/false

local function GetGroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[#units + 1] = "player"
        for i = 1, 4 do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

local function UnitHasAura(unit, spellId, filter)
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not auraData then break end
        if auraData.spellId == spellId then
            return true
        end
    end
    return false
end

function PC:ScanAuras()
    if not self.trackedSpellId then return end

    local units = GetGroupUnits()
    wipe(self.auraStatus)

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            self.auraStatus[unit] = UnitHasAura(unit, self.trackedSpellId, self.auraFilter)
        end
    end

    self:UpdateRosterDisplay()
end

function PC:SetTrackedSpellId(id)
    self.trackedSpellId = id
    self:ScanAuras()
end

function PC:SetAuraFilter(filter)
    self.auraFilter = filter
    self:ScanAuras()
end

----------------------------------------
-- Event Handling
----------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if PC.trackedSpellId and UnitExists(unit) then
            PC.auraStatus[unit] = UnitHasAura(unit, PC.trackedSpellId, PC.auraFilter)
            PC:UpdateRosterDisplay()
        end
        -- Queue dispel assignment eval (runs once per frame max)
        PC:QueueAssignmentEval()
    elseif event == "GROUP_ROSTER_UPDATE" then
        PC:ScanAuras()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
