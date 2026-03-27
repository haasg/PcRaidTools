local addonName, PC = ...

----------------------------------------
-- Dispel Assignment System
----------------------------------------

PC.myHealerIndex = nil
PC.currentGlowTarget = nil  -- name of player currently glowed
PC.debugMode = false

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
    local oldIndex = self.myHealerIndex
    self.myHealerIndex = nil
    for i, entry in ipairs(self.parsedPlayers) do
        if entry.name:lower() == myName:lower() then
            self.myHealerIndex = i
            break
        end
    end

    -- Only clear glow if healer index actually changed (config changed)
    if oldIndex ~= self.myHealerIndex and self.currentGlowTarget then
        self:ClearGlowByName(self.currentGlowTarget)
        self.currentGlowTarget = nil
    end
end

-- Check if a unit has any dispellable debuff (magic/curse/poison/disease)
local function UnitHasDispellableDebuff(unit)
    local ok, count, slot1 = pcall(C_UnitAuras.GetAuraSlots, unit, "HARMFUL|RAID_PLAYER_DISPELLABLE", 1)
    if ok then
        if type(count) == "number" and count > 0 then return true end
        if slot1 then return true end
    end
    return false
end

-- Build alphabetically sorted list of raid member names who have a dispellable debuff
function PC:GetAffectedPlayersSorted()
    local affected = {}

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
        if UnitExists(unit) and UnitHasDispellableDebuff(unit) then
            local name = UnitName(unit)
            if name then
                affected[#affected + 1] = name
            end
        end
    end

    table.sort(affected)
    return affected
end

-- Cooldown: glow + TTS can only trigger once per 16 seconds
local TRIGGER_COOLDOWN = 16
local lastTriggerTime = 0

-- Main evaluation - called on every aura change
local lastDebugTime = 0
function PC:EvaluateAssignments()
    if not self.myHealerIndex then return end
    if not self.parsedSpellId then return end

    local affected = self:GetAffectedPlayersSorted()

    -- Debug logging (throttled to once per 2 seconds)
    if self.debugMode then
        local now = GetTime()
        if now - lastDebugTime >= 2 then
            lastDebugTime = now
            local names = table.concat(affected, ", ")
            print("|cff00ccff[PC Debug]|r affected=" .. #affected .. "/" .. self.auraThreshold .. " [" .. names .. "] myIdx=" .. tostring(self.myHealerIndex) .. " glow=" .. tostring(self.currentGlowTarget))
        end
    end

    -- Below threshold: clear and bail
    if #affected < self.auraThreshold then
        if self.currentGlowTarget then
            self:ClearGlowByName(self.currentGlowTarget)
            self.currentGlowTarget = nil
        end
        return
    end

    -- Check if current glow target still has the aura
    if self.currentGlowTarget then
        local stillAffected = false
        for _, name in ipairs(affected) do
            if name == self.currentGlowTarget then
                stillAffected = true
                break
            end
        end
        if not stillAffected then
            self:ClearGlowByName(self.currentGlowTarget)
            self.currentGlowTarget = nil
        end
    end

    -- My assignment: the player at my healer index in the sorted affected list
    local myTarget = affected[self.myHealerIndex]

    -- No target for my index
    if not myTarget then
        if self.currentGlowTarget then
            self:ClearGlowByName(self.currentGlowTarget)
            self.currentGlowTarget = nil
        end
        return
    end

    -- Target changed or new target (cooldown only applies to new glows)
    if myTarget ~= self.currentGlowTarget then
        local now = GetTime()
        if now - lastTriggerTime < TRIGGER_COOLDOWN then
            return
        end
        lastTriggerTime = now

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
