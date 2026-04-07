local addonName, PC = ...

----------------------------------------
-- Chat Debug Panel
----------------------------------------

local CHAT_ROW_HEIGHT = 16
PC.chatLog = {}
PC.chatLogging = false

function PC:BuildChatDebugPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Raid Chat Log")
    y = y - 24

    local logCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    logCheck:SetPoint("TOPLEFT", 0, y)
    logCheck:SetChecked(PC.chatLogging)
    logCheck:SetScript("OnClick", function(self)
        PC.chatLogging = self:GetChecked()
        if PC.chatLogging then
            print("|cff00ccff[PcRaidTools]|r Chat logging ON")
        else
            print("|cff00ccff[PcRaidTools]|r Chat logging OFF")
        end
    end)
    local logLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    logLabel:SetPoint("LEFT", logCheck, "RIGHT", 4, 0)
    logLabel:SetText("Record raid/party chat")

    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("LEFT", logLabel, "RIGHT", 12, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        wipe(PC.chatLog)
        PC:RefreshChatLog()
    end)
    y = y - 28

    local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOPLEFT", 0, y)
    countText:SetText("")
    self.chatCountText = countText
    y = y - 16

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, y)
    scrollFrame:SetPoint("BOTTOMRIGHT", -18, 0)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(440, 1)
    scrollFrame:SetScrollChild(scrollChild)
    self.chatScrollChild = scrollChild
    self.chatRows = {}
end

function PC:RefreshChatLog()
    if not self.chatScrollChild then return end
    local scrollChild = self.chatScrollChild
    local rows = self.chatRows

    for _, row in pairs(rows) do
        row:SetText("")
    end

    if self.chatCountText then
        self.chatCountText:SetText("|cffaaaaaa" .. #self.chatLog .. " messages|r")
    end

    for i, entry in ipairs(self.chatLog) do
        local row = rows[i]
        if not row then
            row = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row:SetJustifyH("LEFT")
            row:SetWidth(440)
            row:SetWordWrap(false)
            rows[i] = row
        end
        row:SetPoint("TOPLEFT", 0, -((i - 1) * CHAT_ROW_HEIGHT))

        local t = string.format("%7.1f", entry.time - (self.chatLog[1] and self.chatLog[1].time or 0))
        local color = entry.channel == "RAID_LEADER" and "|cffff6600" or
                      entry.channel == "RAID" and "|cffff8800" or
                      entry.channel == "RAID_WARNING" and "|cffff0000" or
                      entry.channel == "PARTY_LEADER" and "|cff00aaff" or
                      entry.channel == "PARTY" and "|cff44aaff" or "|cffaaaaaa"

        row:SetText("|cff44ff44" .. t .. "s|r " .. color .. "[" .. entry.channel .. "]|r "
            .. "|cffffcc00" .. entry.sender .. "|r: " .. entry.msg)
    end

    scrollChild:SetHeight(math.max(1, #self.chatLog * CHAT_ROW_HEIGHT))
end

-- Chat event frame
local chatEventFrame = CreateFrame("Frame")
chatEventFrame:RegisterEvent("CHAT_MSG_RAID")
chatEventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
chatEventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
chatEventFrame:RegisterEvent("CHAT_MSG_PARTY")
chatEventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
chatEventFrame:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not PC.chatLogging then return end
    local channel = event:gsub("CHAT_MSG_", "")
    PC.chatLog[#PC.chatLog + 1] = {
        time = GetTime(),
        channel = channel,
        sender = sender,
        msg = msg,
    }
    if PC.chatScrollChild then
        PC:RefreshChatLog()
    end
end)
