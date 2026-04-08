local addonName, PC = ...

----------------------------------------
-- Encounter Debug Panel
----------------------------------------

function PC:BuildEncounterDebugPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Encounter Monitor")
    y = y - 28

    -- Status
    local statusLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusLabel:SetPoint("TOPLEFT", 0, y)
    statusLabel:SetText("Status:")
    local statusValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusValue:SetPoint("LEFT", statusLabel, "RIGHT", 8, 0)
    statusValue:SetText("|cff888888Idle|r")
    y = y - 22

    -- Encounter ID
    local idLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", 0, y)
    idLabel:SetText("Encounter ID:")
    local idValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    idValue:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
    idValue:SetText("--")
    y = y - 22

    -- Encounter Name
    local nameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 0, y)
    nameLabel:SetText("Boss:")
    local nameValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameValue:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameValue:SetText("--")
    y = y - 22

    -- Difficulty / Group Size
    local diffLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("TOPLEFT", 0, y)
    diffLabel:SetText("Difficulty:")
    local diffValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    diffValue:SetPoint("LEFT", diffLabel, "RIGHT", 8, 0)
    diffValue:SetText("--")
    y = y - 22

    -- Combat Timer
    local timerLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timerLabel:SetPoint("TOPLEFT", 0, y)
    timerLabel:SetText("Combat Time:")
    local timerValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerValue:SetPoint("LEFT", timerLabel, "RIGHT", 8, 0)
    timerValue:SetText("0:00")
    y = y - 30

    -- Result
    local resultLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultLabel:SetPoint("TOPLEFT", 0, y)
    resultLabel:SetText("Last Result:")
    local resultValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultValue:SetPoint("LEFT", resultLabel, "RIGHT", 8, 0)
    resultValue:SetText("--")
    y = y - 36

    -- History
    local histHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    histHeader:SetPoint("TOPLEFT", 0, y)
    histHeader:SetText("History")
    y = y - 18

    local MAX_HISTORY = 10
    local historyLines = {}
    for i = 1, MAX_HISTORY do
        local line = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", 0, y - (i - 1) * 16)
        line:SetText("")
        historyLines[i] = line
    end

    -- State
    local startTime = nil
    local history = {}

    local function FormatTime(seconds)
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%d:%02d", m, s)
    end

    -- Ticker for updating the timer
    local tickFrame = CreateFrame("Frame", nil, parent)
    tickFrame:Hide()
    tickFrame:SetScript("OnUpdate", function(self, elapsed)
        if startTime then
            timerValue:SetText(FormatTime(GetTime() - startTime))
        end
    end)

    -- Event handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ENCOUNTER_START" then
            local encounterID, encounterName, difficultyID, groupSize = ...
            startTime = GetTime()
            statusValue:SetText("|cff00ff00In Combat|r")
            idValue:SetText(tostring(encounterID))
            nameValue:SetText(encounterName or "?")
            diffValue:SetText("ID " .. tostring(difficultyID) .. ", " .. tostring(groupSize) .. " players")
            timerValue:SetText("0:00")
            resultValue:SetText("--")
            tickFrame:Show()
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            local duration = startTime and (GetTime() - startTime) or 0
            tickFrame:Hide()
            startTime = nil

            if success == 1 then
                statusValue:SetText("|cff888888Idle|r")
                resultValue:SetText("|cff00ff00Kill|r  " .. FormatTime(duration))
            else
                statusValue:SetText("|cff888888Idle|r")
                resultValue:SetText("|cffff4444Wipe|r  " .. FormatTime(duration))
            end

            -- Add to history
            local entry = string.format("%s  %s  %s  %s",
                date("%H:%M:%S"),
                tostring(encounterID),
                encounterName or "?",
                (success == 1 and "|cff00ff00Kill|r" or "|cffff4444Wipe|r") .. " " .. FormatTime(duration))
            table.insert(history, 1, entry)
            if #history > MAX_HISTORY then
                table.remove(history)
            end
            for i = 1, MAX_HISTORY do
                historyLines[i]:SetText(history[i] or "")
            end
        end
    end)
end
