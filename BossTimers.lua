local addonName, PC = ...

----------------------------------------
-- Boss Mechanic Timer System
-- Uses Blizzard's Encounter Timeline API
----------------------------------------

-- Timer rules: keyed by "Boss.Mechanic"
PC.bossTimerRules = {
    ["Cosmos.Explosion"] = {
        enabled = true,
        triggers = {
            {
                type = "text",
                label = "Bait",
                duration = 6,
                startAt = 3, -- start when timeline has 3s remaining
            },
            {
                type = "bar",
                label = "Explosion",
                duration = 14,
                startAt = -3, -- start 3s after timeline ends (when bait finishes)
            },
        },
        spellId = 1255368,
        matchDurations = {12, 60, 39, 11.5, 14, 16, 20},
    },
}

-- Active timeline events being tracked: eventId -> {rule, startTime, timelineDuration, triggersStarted = {}}
local activeEvents = {}

-- Active display timers: {trigger, startTime, duration, displayFrame}
local activeDisplays = {}

----------------------------------------
-- On-Screen Display Frames
----------------------------------------

-- Text display (e.g., "Bait (5.2)")
local function CreateTextDisplay()
    local frame = CreateFrame("Frame", "PcRTTextTimer", UIParent, "BackdropTemplate")
    frame:SetSize(200, 40)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.text:SetTextColor(1, 0.8, 0)

    return frame
end

-- Bar display (e.g., "Explosion [========  ] 12.3")
local function CreateBarDisplay()
    local frame = CreateFrame("Frame", "PcRTBarTimer", UIParent, "BackdropTemplate")
    frame:SetSize(250, 22)
    frame:SetPoint("CENTER", 0, 80)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    frame:Hide()

    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetPoint("TOPLEFT", 4, -4)
    frame.bar:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar:SetStatusBarColor(0.9, 0.4, 0.1)
    frame.bar:SetMinMaxValues(0, 1)

    frame.bar.bg = frame.bar:CreateTexture(nil, "BACKGROUND")
    frame.bar.bg:SetAllPoints()
    frame.bar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar.bg:SetVertexColor(0.2, 0.1, 0.05, 0.5)

    frame.label = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    frame.label:SetPoint("LEFT", 4, 0)
    frame.label:SetTextColor(1, 1, 1)

    frame.time = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.time:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    frame.time:SetPoint("RIGHT", -4, 0)
    frame.time:SetTextColor(1, 1, 1)

    return frame
end

-- Anchor frames for repositioning
local function MakeMovable(frame, dbKey)
    frame:SetMovable(true)
    frame:EnableMouse(false) -- only enable mouse when unlocked
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PcRaidToolsDB[dbKey] = { point = point, relPoint = relPoint, x = x, y = y }
    end)
end

local function RestorePosition(frame, dbKey)
    local saved = PcRaidToolsDB and PcRaidToolsDB[dbKey]
    if saved then
        frame:ClearAllPoints()
        frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    end
end

local textDisplay, barDisplay

function PC:InitBossTimerDisplays()
    if textDisplay then return end

    textDisplay = CreateTextDisplay()
    barDisplay = CreateBarDisplay()

    MakeMovable(textDisplay, "textTimerAnchor")
    MakeMovable(barDisplay, "barTimerAnchor")

    RestorePosition(textDisplay, "textTimerAnchor")
    RestorePosition(barDisplay, "barTimerAnchor")
end

----------------------------------------
-- Timer Display Control
----------------------------------------

local function ShowTextTimer(trigger)
    if not textDisplay then return end
    local display = {
        trigger = trigger,
        startTime = GetTime(),
        duration = trigger.duration,
        frame = textDisplay,
    }
    textDisplay.text:SetText(trigger.label .. " (" .. string.format("%.1f", trigger.duration) .. ")")
    textDisplay:Show()
    activeDisplays[#activeDisplays + 1] = display
end

local function ShowBarTimer(trigger)
    if not barDisplay then return end
    local display = {
        trigger = trigger,
        startTime = GetTime(),
        duration = trigger.duration,
        frame = barDisplay,
    }
    barDisplay.label:SetText(trigger.label)
    barDisplay.time:SetText(string.format("%.1f", trigger.duration))
    barDisplay.bar:SetValue(1)
    barDisplay:Show()
    activeDisplays[#activeDisplays + 1] = display
end

----------------------------------------
-- OnUpdate Tick
----------------------------------------

local tickFrame = CreateFrame("Frame")
tickFrame:Hide()
tickFrame:SetScript("OnUpdate", function(self, dt)
    local now = GetTime()

    -- Check active timeline events for trigger starts
    for eventId, ev in pairs(activeEvents) do
        local elapsed = now - ev.startTime
        local timelineRemaining = ev.timelineDuration - elapsed

        for i, trigger in ipairs(ev.rule.triggers) do
            if not ev.triggersStarted[i] and timelineRemaining <= trigger.startAt then
                ev.triggersStarted[i] = true
                if trigger.type == "text" then
                    ShowTextTimer(trigger)
                elseif trigger.type == "bar" then
                    ShowBarTimer(trigger)
                end
            end
        end

        -- Clean up expired timeline tracking (generous buffer)
        if timelineRemaining < -60 then
            activeEvents[eventId] = nil
        end
    end

    -- Update active displays
    for i = #activeDisplays, 1, -1 do
        local d = activeDisplays[i]
        local remaining = d.duration - (now - d.startTime)

        if remaining <= 0 then
            d.frame:Hide()
            table.remove(activeDisplays, i)
        else
            if d.trigger.type == "text" then
                d.frame.text:SetText(d.trigger.label .. " (" .. string.format("%.1f", remaining) .. ")")
            elseif d.trigger.type == "bar" then
                d.frame.bar:SetValue(remaining / d.duration)
                d.frame.time:SetText(string.format("%.1f", remaining))
            end
        end
    end

    -- Stop ticking if nothing active
    if not next(activeEvents) and #activeDisplays == 0 then
        self:Hide()
    end
end)

local function StartTicking()
    tickFrame:Show()
end

----------------------------------------
-- Timeline Event Matching
----------------------------------------

local function RoundDuration(duration)
    return math.floor(duration + 0.5)
end

local function MatchTimelineEvent(eventInfo)
    local durationRounded = RoundDuration(eventInfo.duration)

    for ruleKey, rule in pairs(PC.bossTimerRules) do
        if rule.enabled then
            for _, matchDur in ipairs(rule.matchDurations) do
                if math.abs(durationRounded - matchDur) <= 1 then
                    return ruleKey, rule
                end
            end
        end
    end
    return nil, nil
end

----------------------------------------
-- Event Handlers
----------------------------------------

local function OnTimelineEventAdded(_, eventInfo)
    local ruleKey, rule = MatchTimelineEvent(eventInfo)
    if not ruleKey then return end

    activeEvents[eventInfo.id] = {
        rule = rule,
        startTime = GetTime(),
        timelineDuration = eventInfo.duration,
        triggersStarted = {},
    }
    StartTicking()

    if PC.debugMode then
        print("|cff00ccff[PC Timer]|r Matched " .. ruleKey .. " - timeline " .. string.format("%.1f", eventInfo.duration) .. "s (id=" .. eventInfo.id .. ")")
    end
end

local function OnTimelineStateChanged(_, eventID)
    local ev = activeEvents[eventID]
    if not ev then return end

    local state = C_EncounterTimeline and C_EncounterTimeline.GetEventState(eventID)
    if state == 3 then -- Canceled
        activeEvents[eventID] = nil
        if PC.debugMode then
            print("|cffff9900[PC Timer]|r Timeline canceled (id=" .. eventID .. ")")
        end
    end
end

local function OnTimelineEventRemoved(_, eventID)
    activeEvents[eventID] = nil
end

local function ClearAllTimers()
    activeEvents = {}
    for i = #activeDisplays, 1, -1 do
        activeDisplays[i].frame:Hide()
        table.remove(activeDisplays, i)
    end
    tickFrame:Hide()
end

local function OnEncounterEnd()
    ClearAllTimers()
    if PC.debugMode then
        print("|cff00ccff[PC Timer]|r Encounter ended, timers cleared")
    end
end

----------------------------------------
-- Event Frame
----------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        OnTimelineEventAdded(event, ...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        OnTimelineStateChanged(event, ...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        OnTimelineEventRemoved(event, ...)
    elseif event == "ENCOUNTER_END" then
        OnEncounterEnd()
    end
end)

----------------------------------------
-- Anchor Lock/Unlock
----------------------------------------

PC.timersUnlocked = false

function PC:ToggleTimerAnchors()
    self:InitBossTimerDisplays()
    self.timersUnlocked = not self.timersUnlocked

    if self.timersUnlocked then
        -- Show placeholder displays for dragging
        textDisplay:EnableMouse(true)
        textDisplay.text:SetText("Bait (5.2)")
        textDisplay:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        textDisplay:SetBackdropColor(0, 0, 0, 0.5)
        textDisplay:SetBackdropBorderColor(1, 0.8, 0, 0.8)
        textDisplay:Show()

        barDisplay:EnableMouse(true)
        barDisplay.label:SetText("Explosion")
        barDisplay.time:SetText("14.0")
        barDisplay.bar:SetValue(0.7)
        barDisplay:Show()

        print("|cff00ccff[PcRaidTools]|r Timer anchors UNLOCKED - drag to reposition, run again to lock")
    else
        textDisplay:EnableMouse(false)
        textDisplay:SetBackdrop(nil)
        textDisplay:Hide()

        barDisplay:EnableMouse(false)
        barDisplay:Hide()

        print("|cff00ccff[PcRaidTools]|r Timer anchors LOCKED")
    end
end

----------------------------------------
-- Test Function (for UI panel)
----------------------------------------

function PC:TestBossTimer(ruleKey)
    self:InitBossTimerDisplays()
    local rule = self.bossTimerRules[ruleKey]
    if not rule then return end

    -- Simulate a timeline event that's about to finish
    -- Find the max startAt among triggers to set a reasonable test duration
    local maxStartAt = 0
    for _, trigger in ipairs(rule.triggers) do
        if trigger.startAt > maxStartAt then
            maxStartAt = trigger.startAt
        end
    end

    local testDuration = maxStartAt + 2 -- give 2 seconds before first trigger fires
    local fakeEventId = -1

    activeEvents[fakeEventId] = {
        rule = rule,
        startTime = GetTime(),
        timelineDuration = testDuration,
        triggersStarted = {},
    }
    StartTicking()
    print("|cff00ccff[PC Timer]|r Test started for " .. ruleKey .. " (" .. testDuration .. "s simulated timeline)")
end

function PC:ClearBossTimers()
    ClearAllTimers()
end
