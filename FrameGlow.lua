local addonName, PC = ...

----------------------------------------
-- Frame Glow System
----------------------------------------

PC.activeGlows = {}  -- [playerName] = { frame, overlay }
PC.glowColor = { r = 1, g = 0, b = 1 }
PC.glowSize = 2
PC.glowStyle = "thick"  -- "solid", "pulse", "thick"

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

-- Create or get the glow container on a frame
-- Parented to UIParent and anchored via SetPoint — works on secure frames in combat
local function GetOrCreateGlow(frame)
    if frame.pcRaidToolsGlow then
        return frame.pcRaidToolsGlow
    end

    local glow = CreateFrame("Frame", nil, UIParent)
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    glow:SetFrameStrata(frame:GetFrameStrata())
    glow:SetFrameLevel(frame:GetFrameLevel() + 15)

    -- Main border layer
    glow.border = CreateFrame("Frame", nil, glow, "BackdropTemplate")

    -- Extra layers for "thick" style
    glow.layers = {}
    for i = 1, 3 do
        local layer = CreateFrame("Frame", nil, glow, "BackdropTemplate")
        layer:Hide()
        glow.layers[i] = layer
    end

    -- Pulse animation state
    glow.elapsed = 0
    glow.direction = 1

    glow:SetScript("OnUpdate", function(self, dt)
        -- Hide if owner frame is gone
        if not self.ownerFrame or not self.ownerFrame:IsVisible() then
            self:Hide()
            return
        end
        if self.style ~= "pulse" then return end
        self.elapsed = self.elapsed + dt
        local speed = 1.2
        local progress = self.elapsed / speed
        if progress >= 1 then
            self.direction = -self.direction
            self.elapsed = 0
            progress = 0
        end
        local t = progress * progress * (3 - 2 * progress)
        local alpha
        if self.direction == 1 then
            alpha = 0.4 + 0.6 * t
        else
            alpha = 1.0 - 0.6 * t
        end
        self.border:SetAlpha(alpha)
    end)

    -- Hide glow when owner frame hides
    glow.ownerFrame = frame
    frame:HookScript("OnHide", function()
        if frame.pcRaidToolsGlow then
            frame.pcRaidToolsGlow:Hide()
        end
    end)

    glow:Hide()
    frame.pcRaidToolsGlow = glow
    return glow
end

-- Apply glow settings to a glow container
local function ApplyGlowStyle(glow, r, g, b, size, style)
    local edgeSize = math.max(1, size)

    -- Configure main border
    glow.border:ClearAllPoints()
    glow.border:SetPoint("TOPLEFT", glow, "TOPLEFT", -size, size)
    glow.border:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", size, -size)
    glow.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = edgeSize })
    glow.border:SetBackdropBorderColor(r, g, b, 1)
    glow.border:SetAlpha(1)
    glow.border:Show()

    glow.style = style
    glow.elapsed = 0
    glow.direction = 1

    -- Hide extra layers by default
    for _, layer in ipairs(glow.layers) do
        layer:Hide()
    end

    if style == "thick" then
        -- Multi-layer glow: each layer expands outward with decreasing alpha
        for i, layer in ipairs(glow.layers) do
            local offset = size + i * 2
            local layerAlpha = math.max(0, 1.0 - i * 0.3)
            layer:ClearAllPoints()
            layer:SetPoint("TOPLEFT", glow, "TOPLEFT", -offset, offset)
            layer:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", offset, -offset)
            layer:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = edgeSize })
            layer:SetBackdropBorderColor(r, g, b, layerAlpha)
            layer:Show()
        end
    end
end

-- Glow a specific frame using config settings
function PC:GlowFrame(frame)
    if not frame then return end
    local r = self.glowColor.r
    local g = self.glowColor.g
    local b = self.glowColor.b
    local glow = GetOrCreateGlow(frame)
    ApplyGlowStyle(glow, r, g, b, self.glowSize, self.glowStyle)
    glow:Show()
end

-- Clear glow on a specific frame
function PC:ClearGlow(frame)
    if not frame then return end
    if frame.pcRaidToolsGlow then
        frame.pcRaidToolsGlow:Hide()
    end
end

-- Glow a player by name
function PC:GlowPlayer(name)
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

    self:GlowFrame(frame)
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
