local addonName, PC = ...

----------------------------------------
-- Dispel Assignment System
----------------------------------------

PC.myHealerIndex = nil
PC.currentGlowTarget = nil  -- name of player currently glowed

PC.auraThreshold = 6
local dirty = false

-- Throttle frame: evaluates at most once per render frame
local throttleFrame = CreateFrame("Frame")
throttleFrame:Hide()
throttleFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    dirty = false
    PC:EvaluateAssignments()
end)

-- Called from UNIT_AURA — just marks dirty and lets OnUpdate do the work
function PC:QueueAssignmentEval()
    if not self.parsedSpellId then return end
    if not self.myHealerIndex then return end
    if not dirty then
        dirty = true
        throttleFrame:Show()
    end
end

-- Called after a successful parse to resolve healer index
function PC:ResolveHealerIndex()
    local myName = UnitName("player")
    self.myHealerIndex = nil
    for i, entry in ipairs(self.parsedPlayers) do
        if entry.name:lower() == myName:lower() then
            self.myHealerIndex = i
            break
        end
    end

    -- Clear any stale glow from a previous config
    if self.currentGlowTarget then
        self:ClearGlowByName(self.currentGlowTarget)
        self.currentGlowTarget = nil
    end
end

-- Check if a unit has an aura by spell ID, scanning both buffs and debuffs
local function UnitHasSpell(unit, spellId)
    for j = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, j, "HARMFUL")
        if not auraData then break end
        if auraData.spellId == spellId then return true end
    end
    for j = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, j, "HELPFUL")
        if not auraData then break end
        if auraData.spellId == spellId then return true end
    end
    return false
end

-- Build alphabetically sorted list of raid member names who have the aura
function PC:GetAffectedPlayersSorted()
    local affected = {}
    local spellId = self.parsedSpellId

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

    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitHasSpell(unit, spellId) then
            local name = UnitName(unit)
            if name then
                affected[#affected + 1] = name
            end
        end
    end

    table.sort(affected)
    return affected
end

-- Main evaluation - called on every aura change
function PC:EvaluateAssignments()
    if not self.myHealerIndex then return end
    if not self.parsedSpellId then return end

    local affected = self:GetAffectedPlayersSorted()

    -- Below threshold: clear and bail
    if #affected < self.auraThreshold then
        if self.currentGlowTarget then
            self:ClearGlowByName(self.currentGlowTarget)
            self.currentGlowTarget = nil
        end
        return
    end

    -- My assignment: the player at my healer index in the sorted affected list
    local myTarget = affected[self.myHealerIndex]

    -- No target for my index (more healers than debuffed, shouldn't happen at threshold but safe)
    if not myTarget then
        if self.currentGlowTarget then
            self:ClearGlowByName(self.currentGlowTarget)
            self.currentGlowTarget = nil
        end
        return
    end

    -- Target changed or new target
    if myTarget ~= self.currentGlowTarget then
        -- Clear old glow
        if self.currentGlowTarget then
            self:ClearGlowByName(self.currentGlowTarget)
        end
        -- Glow new target
        local success = self:GlowPlayer(myTarget)
        if success then
            self.currentGlowTarget = myTarget
            -- TTS announce
            if self.ttsEnabled and C_VoiceChat and C_VoiceChat.SpeakText then
                local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0
                C_VoiceChat.SpeakText(0, "dispel " .. myTarget, rate, 100, true)
            end
        else
            self.currentGlowTarget = nil
        end
    end
end
