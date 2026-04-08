local addonName, PC = ...

----------------------------------------
-- Timeline Debug Panel
----------------------------------------

local TIMELINE_ROW_HEIGHT = 16

function PC:BuildTimelineDebugPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Timeline Log")
    y = y - 24

    -- Toggle logging
    local logCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    logCheck:SetPoint("TOPLEFT", 0, y)
    logCheck:SetChecked(PC.timelineLogging)
    logCheck:SetScript("OnClick", function(self)
        PC.timelineLogging = self:GetChecked()
        if PC.timelineLogging then
            print("|cff00ccff[PcRaidTools]|r Timeline logging ON")
        else
            print("|cff00ccff[PcRaidTools]|r Timeline logging OFF")
        end
    end)
    local logLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    logLabel:SetPoint("LEFT", logCheck, "RIGHT", 4, 0)
    logLabel:SetText("Record timeline events")

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("LEFT", logLabel, "RIGHT", 12, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PC.timelineLog = {}
        PC:RefreshTimelineLog()
    end)
    y = y - 28

    -- Filter checkbox
    local filterCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    filterCheck:SetPoint("TOPLEFT", 0, y)
    filterCheck:SetChecked(PC.timelineFilterAddedRemoved or false)
    filterCheck:SetScript("OnClick", function(self)
        PC.timelineFilterAddedRemoved = self:GetChecked()
        PC:RefreshTimelineLog()
    end)
    local filterLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    filterLabel:SetPoint("LEFT", filterCheck, "RIGHT", 4, 0)
    filterLabel:SetText("Show only ADDED / REMOVED")
    y = y - 28

    -- Count display
    local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOPLEFT", 0, y)
    countText:SetText("")
    self.timelineCountText = countText
    y = y - 16

    -- Scroll frame for log entries
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, y)
    scrollFrame:SetPoint("BOTTOMRIGHT", -18, 0)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(440, 1)
    scrollFrame:SetScrollChild(scrollChild)
    self.timelineScrollChild = scrollChild
    self.timelineRows = {}
end

local function GetOrCreateTimelineRow(parent, rows, index)
    if rows[index] then return rows[index] end

    local row = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetJustifyH("LEFT")
    row:SetWidth(440)
    row:SetWordWrap(false)
    rows[index] = row
    return row
end

function PC:RefreshTimelineLog()
    if not self.timelineScrollChild then return end
    local scrollChild = self.timelineScrollChild
    local rows = self.timelineRows

    -- Hide existing
    for _, row in pairs(rows) do
        row:SetText("")
    end

    local log = self.timelineLog
    if self.timelineCountText then
        self.timelineCountText:SetText("|cffaaaaaa" .. #log .. " events logged|r")
    end

    local filterAddedRemoved = self.timelineFilterAddedRemoved
    local startTime = log[1] and log[1].time or 0
    local rowIndex = 0
    for i, entry in ipairs(log) do
        if filterAddedRemoved and entry.type ~= "ADDED" and entry.type ~= "REMOVED" then
            -- skip filtered entries
        else
        rowIndex = rowIndex + 1
        local row = GetOrCreateTimelineRow(scrollChild, rows, rowIndex)
        row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * TIMELINE_ROW_HEIGHT))

        local t = string.format("%7.1f", entry.time - startTime)
        local line

        if entry.type == "ADDED" then
            local s = entry.secrets or {}
            local cReal, cSecret = "|cff44ff44", "|cffff4444"
            local function cv(val, isSecret, fmt)
                local str = val and (fmt and string.format(fmt, val) or tostring(val)) or "?"
                return (isSecret and cSecret or cReal) .. str .. "|r"
            end
            line = "|cff44ff44" .. t .. "s|r |cff00ccffADDED|r id=" .. cv(entry.id, s.id)
                .. " dur=" .. cv(entry.duration, s.duration, "%.1f") .. "s"
                .. " spell=" .. cv(entry.spellName, s.spellName) .. " (" .. cv(entry.spellID, s.spellID) .. ")"
                .. " src=" .. cv(entry.source, s.source)
        elseif entry.type == "MATCHED" then
            line = "|cff44ff44" .. t .. "s|r |cff44ff44MATCHED|r id=" .. tostring(entry.id) .. " -> |cffffcc00" .. tostring(entry.extra) .. "|r"
        elseif entry.type == "STATE" then
            line = "|cff44ff44" .. t .. "s|r |cffff9900STATE|r id=" .. tostring(entry.id) .. " -> " .. tostring(entry.extra)
        elseif entry.type == "REMOVED" then
            line = "|cff44ff44" .. t .. "s|r |cff666666REMOVED|r id=" .. tostring(entry.id)
        elseif entry.type == "ENCOUNTER_START" then
            line = "|cff44ff44" .. t .. "s|r |cff00ff00=== ENCOUNTER START ===|r " .. tostring(entry.extra)
        elseif entry.type == "ENCOUNTER_END" then
            line = "|cff44ff44" .. t .. "s|r |cffff4444=== ENCOUNTER END ===|r " .. tostring(entry.extra)
        elseif entry.type:find("^CAST_") then
            local castType = entry.type:gsub("CAST_", "")
            local color = castType == "START" and "|cffff66ff" or castType == "INTERRUPTED" and "|cff44ff44" or "|cff999999"
            local s = entry.secrets or {}
            local cReal, cSecret = "|cff44ff44", "|cffff4444"
            local function cv(val, isSecret, fmt)
                local str = val and (fmt and string.format(fmt, val) or tostring(val)) or "?"
                return (isSecret and cSecret or cReal) .. str .. "|r"
            end
            if entry.castUnit then
                line = "|cff44ff44" .. t .. "s|r " .. color .. "CAST " .. castType .. "|r "
                    .. tostring(entry.castUnit) .. " spell=" .. cv(entry.spellName, s.spellName)
                    .. " (" .. cv(entry.spellID, s.spellID) .. ")"
                    .. " dur=" .. cv(entry.duration, s.duration, "%.1f") .. "s"
                    .. " notInterrupt=" .. cv(entry.notInterruptible, s.notInterruptible)
            else
                -- Legacy format fallback
                line = "|cff44ff44" .. t .. "s|r " .. color .. "CAST " .. castType .. "|r " .. tostring(entry.extra)
            end
        else
            line = "|cff44ff44" .. t .. "s|r " .. tostring(entry.type) .. " id=" .. tostring(entry.id)
        end

        row:SetText(line)
        end -- end filter else
    end

    -- Clear any leftover rows from previous refresh
    for i = rowIndex + 1, #rows do
        if rows[i] then rows[i]:SetText("") end
    end

    scrollChild:SetHeight(math.max(1, rowIndex * TIMELINE_ROW_HEIGHT))
end
