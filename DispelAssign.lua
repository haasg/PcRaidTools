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

PC.triggerCooldown = 16  -- default, overridden by note
local lastTriggerTime = 0

-- Compute my dispel target with self-dispel priority
function PC:ComputeMyTarget(affected)
    if not self.myHealerIndex then return nil end

    local myName = UnitName("player")

    -- Build set of debuffed names
    local debuffedSet = {}
    for _, name in ipairs(affected) do
        debuffedSet[name:lower()] = true
    end

    -- First pass: find healers who are debuffed (self-assign)
    local selfAssigned = {}  -- set of healer names who self-dispel
    for _, entry in ipairs(self.parsedPlayers) do
        if debuffedSet[entry.name:lower()] then
            selfAssigned[entry.name:lower()] = true
        end
    end

    -- Am I self-assigned?
    if selfAssigned[myName:lower()] then
        return myName
    end

    -- Second pass: remaining debuffed (alphabetical), assigned to remaining healers (in list order)
    local remainingDebuffed = {}
    for _, name in ipairs(affected) do
        if not selfAssigned[name:lower()] then
            remainingDebuffed[#remainingDebuffed + 1] = name
        end
    end

    -- Build remaining healer order (preserving list order, skipping self-assigned)
    local remainingIdx = 0
    for _, entry in ipairs(self.parsedPlayers) do
        if not selfAssigned[entry.name:lower()] then
            remainingIdx = remainingIdx + 1
            if entry.name:lower() == myName:lower() then
                -- I'm the Nth remaining healer, I get the Nth remaining debuffed player
                return remainingDebuffed[remainingIdx]
            end
        end
    end

    return nil
end

-- Main evaluation - called on every aura change
local lastDebugTime = 0
function PC:EvaluateAssignments()
    if not self.myHealerIndex then return end

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

    -- If we have an active glow, only clear it when that player's debuff is gone
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
        else
            -- Target still has debuff, keep glowing, don't reassign
            return
        end
    end

    -- No active glow — check if we should assign a new one
    if #affected < self.auraThreshold then
        return
    end

    -- Compute my assignment with self-dispel priority
    local myTarget = self:ComputeMyTarget(affected)
    if not myTarget then return end

    -- New target (cooldown only applies to new glows)
    if myTarget ~= self.currentGlowTarget then
        local now = GetTime()
        if now - lastTriggerTime < self.triggerCooldown then
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
                C_VoiceChat.SpeakText(0, myTarget, rate, 100, true)
            end
        else
            self.currentGlowTarget = nil
        end
    end
end
