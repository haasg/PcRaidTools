local addonName, PC = ...

local COMM_PREFIX = "PcRT"

C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)

PC.knownVersions = {} -- [name] = version string

----------------------------------------
-- Sending
----------------------------------------

local function GetChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

function PC:BroadcastVersion()
    if InCombatLockdown() then return end
    local channel = GetChannel()
    if not channel then return end
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "V:" .. self.VERSION, channel)
end

function PC:RequestVersions()
    if InCombatLockdown() then return end
    local channel = GetChannel()
    if not channel then return end
    wipe(self.knownVersions)
    -- Add self
    self.knownVersions[UnitName("player")] = self.VERSION
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "VREQ", channel)
    if self.RefreshVersionPanel then
        self:RefreshVersionPanel()
    end
end

----------------------------------------
-- Receiving
----------------------------------------

local function CompareVersions(myVer, theirVer)
    -- Parse "X.Y.Z" into comparable numbers
    local my = { strsplit(".", myVer) }
    local their = { strsplit(".", theirVer) }
    for i = 1, math.max(#my, #their) do
        local a = tonumber(my[i]) or 0
        local b = tonumber(their[i]) or 0
        if b > a then return true end
        if b < a then return false end
    end
    return false
end

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
    if prefix ~= COMM_PREFIX then return end

    local senderName = Ambiguate(sender, "short")
    local myName = UnitName("player")
    local msgType, payload = strsplit(":", msg, 2)

    if msgType == "VREQ" then
        -- Someone requested versions, respond with ours
        if senderName ~= myName and not InCombatLockdown() then
            local ch = GetChannel()
            if ch then
                C_ChatInfo.SendAddonMessage(COMM_PREFIX, "V:" .. PC.VERSION, ch)
            end
        end
        return
    end

    if msgType == "V" and payload then
        -- Track this player's version
        if senderName ~= myName then
            PC.knownVersions[senderName] = payload
            if PC.RefreshVersionPanel then
                PC:RefreshVersionPanel()
            end
        end

        -- Out of date check
        if senderName ~= myName and CompareVersions(PC.VERSION, payload) then
            if not PC.newestVersion or CompareVersions(PC.newestVersion, payload) then
                PC.newestVersion = payload
            end
            PC.isOutOfDate = true
            PC:UpdateTitleText()
        end
    end
end)
