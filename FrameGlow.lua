local addonName, PC = ...

----------------------------------------
-- Frame Glow System
----------------------------------------

PC.activeGlows = {}  -- [playerName] = { frame, overlay }

-- Find the unit token for a player name
function PC:GetUnitForName(name)
    if not name or name == "" then return nil end
    local lowerName = name:lower()

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                local unitName = UnitName(unit)
                if unitName and unitName:lower() == lowerName then
                    return unit
                end
            end
        end
    else
        if UnitExists("player") then
            local unitName = UnitName("player")
            if unitName and unitName:lower() == lowerName then
                return "player"
            end
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local unitName = UnitName(unit)
                if unitName and unitName:lower() == lowerName then
                    return unit
                end
            end
        end
    end

    return nil
end

-- Find the raid frame widget for a unit token
function PC:FindRaidFrameForUnit(unit)
    if not unit then return nil end

    -- Try DandersFrames first
    if DandersFrames_GetFrameForUnit then
        local frame = DandersFrames_GetFrameForUnit(unit)
        if frame then return frame end
    end

    -- Blizzard CompactPartyFrame members
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unit) then
            return frame
        end
    end

    -- Blizzard CompactRaidFrames (flat layout)
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unit) then
            return frame
        end
    end

    -- Blizzard CompactRaidGroup frames (grouped layout)
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame and frame.unit and UnitIsUnit(frame.unit, unit) then
                return frame
            end
        end
    end

    return nil
end

-- Debug: print what Blizzard frames exist (use /pc debug)
function PC:DebugBlizzFrames()
    print("|cff00ccff[PcRaidTools]|r Scanning Blizzard frames...")
    local found = 0
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            print("  CompactPartyFrameMember" .. i .. " unit=" .. tostring(frame.unit) .. " visible=" .. tostring(frame:IsVisible()))
            found = found + 1
        end
    end
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            print("  CompactRaidFrame" .. i .. " unit=" .. tostring(frame.unit) .. " visible=" .. tostring(frame:IsVisible()))
            found = found + 1
        end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then
                print("  CompactRaidGroup" .. group .. "Member" .. member .. " unit=" .. tostring(frame.unit) .. " visible=" .. tostring(frame:IsVisible()))
                found = found + 1
            end
        end
    end
    if found == 0 then
        print("  No Blizzard CompactRaidFrame/CompactPartyFrame globals found.")
    end
end

-- Create or get the glow overlay on a frame
local function GetOrCreateOverlay(frame)
    if frame.pcRaidToolsGlow then
        return frame.pcRaidToolsGlow
    end

    local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    overlay:SetPoint("TOPLEFT", -3, 3)
    overlay:SetPoint("BOTTOMRIGHT", 3, -3)
    overlay:SetFrameStrata("HIGH")
    overlay:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    overlay:Hide()

    frame.pcRaidToolsGlow = overlay
    return overlay
end

-- Glow a specific frame
function PC:GlowFrame(frame, r, g, b)
    if not frame then return end
    r = r or 0.3
    g = g or 1
    b = b or 0.3
    local overlay = GetOrCreateOverlay(frame)
    overlay:SetBackdropBorderColor(r, g, b, 1)
    overlay:Show()
end

-- Clear glow on a specific frame
function PC:ClearGlow(frame)
    if not frame then return end
    if frame.pcRaidToolsGlow then
        frame.pcRaidToolsGlow:Hide()
    end
end

-- Glow a player by name
function PC:GlowPlayer(name, r, g, b)
    if not name or name == "" then
        return false, "No name provided"
    end

    local unit = self:GetUnitForName(name)
    if not unit then
        return false, "Player not found in group"
    end

    local frame = self:FindRaidFrameForUnit(unit)
    if not frame then
        return false, "Raid frame not found"
    end

    -- Clear existing glow for this name if any
    self:ClearGlowByName(name)

    self:GlowFrame(frame, r, g, b)
    self.activeGlows[name:lower()] = { frame = frame, overlay = frame.pcRaidToolsGlow }

    return true, "Glowing " .. name
end

-- Clear glow by player name
function PC:ClearGlowByName(name)
    if not name or name == "" then return end
    local key = name:lower()
    local entry = self.activeGlows[key]
    if entry and entry.frame then
        self:ClearGlow(entry.frame)
    end
    self.activeGlows[key] = nil
end

-- Clear all active glows
function PC:ClearAllGlows()
    for name, entry in pairs(self.activeGlows) do
        if entry.frame then
            self:ClearGlow(entry.frame)
        end
    end
    wipe(self.activeGlows)
end
