local addonName, PC = ...

----------------------------------------
-- Lura Matrix Kick Notification
--
-- Watches raid chat for the player's name.
-- When someone says your name, triggers a
-- kick notification (sound, flash, TTS).
----------------------------------------

local LURA_ENCOUNTER_ID = 3183

-- Defaults (overridden by SavedVariables)
local defaults = {
    enabled = true,
    soundEnabled = true,
    soundId = 8959,  -- RAID_WARNING sound
    ttsEnabled = true,
    ttsMessage = "Kick now",
    flashEnabled = true,
    onlyDuringEncounter = false,
}

local function GetSettings()
    PcRaidToolsDB = PcRaidToolsDB or {}
    if not PcRaidToolsDB.luraMatrix then
        PcRaidToolsDB.luraMatrix = CopyTable(defaults)
    end
    return PcRaidToolsDB.luraMatrix
end

local inLuraFight = false

----------------------------------------
-- Notification Display
----------------------------------------

-- Full-screen flash
local flashFrame = CreateFrame("Frame", "PcRTMatrixFlash", UIParent)
flashFrame:SetAllPoints()
flashFrame:SetFrameStrata("FULLSCREEN_DIALOG")
flashFrame:Hide()

flashFrame.tex = flashFrame:CreateTexture(nil, "BACKGROUND")
flashFrame.tex:SetAllPoints()
flashFrame.tex:SetColorTexture(1, 0.2, 0, 0.4)

local flashElapsed = 0
local FLASH_DURATION = 0.8
flashFrame:SetScript("OnUpdate", function(self, elapsed)
    flashElapsed = flashElapsed + elapsed
    if flashElapsed >= FLASH_DURATION then
        self:Hide()
        return
    end
    local alpha = 0.4 * (1 - flashElapsed / FLASH_DURATION)
    self.tex:SetAlpha(alpha)
end)

local function ShowFlash()
    flashElapsed = 0
    flashFrame.tex:SetAlpha(0.4)
    flashFrame:Show()
end

-- Center screen text alert
local alertFrame = CreateFrame("Frame", "PcRTMatrixAlert", UIParent)
alertFrame:SetSize(400, 60)
alertFrame:SetPoint("CENTER", 0, 200)
alertFrame:SetFrameStrata("FULLSCREEN_DIALOG")
alertFrame:Hide()

alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY")
alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
alertFrame.text:SetPoint("CENTER")
alertFrame.text:SetTextColor(1, 0.3, 0)
alertFrame.text:SetText("KICK NOW!")

local alertElapsed = 0
local ALERT_DURATION = 3
alertFrame:SetScript("OnUpdate", function(self, elapsed)
    alertElapsed = alertElapsed + elapsed
    if alertElapsed >= ALERT_DURATION then
        self:Hide()
        return
    end
    if alertElapsed > ALERT_DURATION - 1 then
        local fade = 1 - (alertElapsed - (ALERT_DURATION - 1))
        self.text:SetAlpha(fade)
    end
end)

local function ShowAlert()
    alertElapsed = 0
    alertFrame.text:SetAlpha(1)
    alertFrame:Show()
end

----------------------------------------
-- Trigger Notification
----------------------------------------

function PC:TriggerMatrixKick()
    local s = GetSettings()

    if s.flashEnabled then
        ShowFlash()
    end

    ShowAlert()

    if s.soundEnabled then
        PlaySound(s.soundId, "Master")
    end

    if s.ttsEnabled and C_VoiceChat and C_VoiceChat.SpeakText then
        local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0
        C_VoiceChat.SpeakText(0, s.ttsMessage or "Kick now", rate, 100, true)
    end
end

----------------------------------------
-- Chat Listener
----------------------------------------

local function ContainsPlayerName(msg)
    local myName = UnitName("player")
    if not myName then return false end
    -- Case-insensitive search for our name
    return msg:lower():find(myName:lower(), 1, true) ~= nil
end

local chatFrame = CreateFrame("Frame")
chatFrame:RegisterEvent("CHAT_MSG_RAID")
chatFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
chatFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
chatFrame:RegisterEvent("ENCOUNTER_START")
chatFrame:RegisterEvent("ENCOUNTER_END")
chatFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        inLuraFight = (encounterID == LURA_ENCOUNTER_ID)
        return
    elseif event == "ENCOUNTER_END" then
        inLuraFight = false
        return
    end

    local s = GetSettings()
    if not s.enabled then return end
    if s.onlyDuringEncounter and not inLuraFight then return end

    local msg, sender = ...
    -- Don't trigger on our own messages
    local myName = UnitName("player")
    local senderName = Ambiguate(sender, "short")
    if senderName == myName then return end

    if ContainsPlayerName(msg) then
        PC:TriggerMatrixKick()
    end
end)
