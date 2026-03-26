local addonName, PC = ...

----------------------------------------
-- Dispel Assignment System
----------------------------------------

PC.dispelActive = false
PC.myHealerIndex = nil
PC.currentGlowTarget = nil  -- name of player currently glowed

local DEBUFF_THRESHOLD = 6
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
    if not self.dispelActive then return end
    if not dirty then
        dirty = true
        throttleFrame:Show()
    end
end

-- Activate dispel mode using parsed note data
function PC:ActivateDispelMode()
    if not self.parsedSpellId then
        return false, "No spell ID parsed from note."
    end
    if #self.parsedPlayers == 0 then
        return false, "No healer list parsed from note."
    end

    -- Find my position in the healer list
    local myName = UnitName("player")
    self.myHealerIndex = nil
    for i, entry in ipairs(self.parsedPlayers) do
        if entry.name:lower() == myName:lower() then
            self.myHealerIndex = i
            break
        end
    end

    self.dispelActive = true
    self.currentGlowTarget = nil

    if self.myHealerIndex then
        return true, "Active - You are healer #" .. self.myHealerIndex
    else
        return true, "Active - You are NOT in the healer list (spectating)"
    end
end

-- Deactivate dispel mode
function PC:DeactivateDispelMode()
    self.dispelActive = false
    self.myHealerIndex = nil
    if self.currentGlowTarget then
        self:ClearGlowByName(self.currentGlowTarget)
        self.currentGlowTarget = nil
    end
end

-- Build alphabetically sorted list of raid member names who have the debuff
function PC:GetDebuffedPlayersSorted()
    local debuffed = {}
    local spellId = self.parsedSpellId

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                for j = 1, 40 do
                    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, j, "HARMFUL")
                    if not auraData then break end
                    if auraData.spellId == spellId then
                        local name = UnitName(unit)
                        if name then
                            debuffed[#debuffed + 1] = name
                        end
                        break
                    end
                end
            end
        end
    else
        local units = { "player" }
        for i = 1, 4 do
            units[#units + 1] = "party" .. i
        end
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                for j = 1, 40 do
                    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, j, "HARMFUL")
                    if not auraData then break end
                    if auraData.spellId == spellId then
                        local name = UnitName(unit)
                        if name then
                            debuffed[#debuffed + 1] = name
                        end
                        break
                    end
                end
            end
        end
    end

    table.sort(debuffed)
    return debuffed
end

-- Main evaluation - called on every aura change
function PC:EvaluateAssignments()
    if not self.dispelActive then return end
    if not self.myHealerIndex then return end
    if not self.parsedSpellId then return end

    local debuffed = self:GetDebuffedPlayersSorted()

    -- Below threshold: clear and bail
    if #debuffed < DEBUFF_THRESHOLD then
        if self.currentGlowTarget then
            self:ClearGlowByName(self.currentGlowTarget)
            self.currentGlowTarget = nil
        end
        return
    end

    -- My assignment: the player at my healer index in the sorted debuffed list
    local myTarget = debuffed[self.myHealerIndex]

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
        else
            self.currentGlowTarget = nil
        end
    end
end
