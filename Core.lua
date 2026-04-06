local addonName, PC = ...
_G[addonName] = PC

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
PC.VERSION = GetAddOnMetadata(addonName, "Version") or "Unknown"

----------------------------------------
-- Initialization
----------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    PcRaidToolsDB = PcRaidToolsDB or {}

    PC:InitBossTimerDisplays()
    PC:CreateMainWindow()
    PC:HookMainWindowShow()

    -- Periodically re-read note and refresh roster
    C_Timer.NewTicker(3, function()
        if PC:HasMRT() then
            PC:ReadAndParseNote()
        end
        if PC.mainWindow and PC.mainWindow:IsShown() then
            PC:RefreshNoteDisplay()
        end
    end)

    print("|cff00ccffPcRaidTools|r v" .. PC.VERSION .. " loaded. Type |cff00ccff/pc|r to open.")
end)

----------------------------------------
-- Slash Command
----------------------------------------

SLASH_PCRAIDTOOLS1 = "/pc"
SlashCmdList["PCRAIDTOOLS"] = function(msg)
    local cmd = msg and msg:trim():lower() or ""
    if cmd == "debugon" then
        PC.debugMode = true
        print("|cff00ccff[PcRaidTools]|r Debug ON - will log every 2s")
    elseif cmd == "debugoff" then
        PC.debugMode = false
        print("|cff00ccff[PcRaidTools]|r Debug OFF")
    elseif cmd == "debug" then
        PC:DebugBlizzFrames()
    elseif cmd == "diag" then
        print("|cff00ccff[PcRaidTools Diag]|r")
        print("  auraThreshold: " .. tostring(PC.auraThreshold))
        print("  myHealerIndex: " .. tostring(PC.myHealerIndex))
        print("  currentGlowTarget: " .. tostring(PC.currentGlowTarget))
        print("  ttsEnabled: " .. tostring(PC.ttsEnabled))
        print("  parsedPlayers: " .. #PC.parsedPlayers)
        if PC.myHealerIndex then
            local affected = PC:GetAffectedPlayersSorted()
            print("  affected count: " .. #affected)
            for i, name in ipairs(affected) do
                print("    " .. i .. ". " .. name)
            end
            print("  myTarget would be: " .. tostring(affected[PC.myHealerIndex]))
        end
    elseif cmd == "feather" then
        PC:ToggleFeatherDebug()
    elseif cmd == "timers" then
        PC:ToggleTimerAnchors()
    elseif cmd == "testcleu" then
        if PC.cleuTestFrame then
            -- Stop test
            PC.cleuTestFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            PC.cleuTestFrame = nil
            if PC.cleuHeartbeat then
                PC.cleuHeartbeat:Cancel()
                PC.cleuHeartbeat = nil
            end
            print("|cff00ccff[PcRaidTools]|r CLEU test OFF")
        else
            -- Start test
            local totalEvents = 0
            local auraEvents = 0
            local lastTotal = 0
            local lastAura = 0

            PC.cleuTestFrame = CreateFrame("Frame")
            PC.cleuTestFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            PC.cleuTestFrame:SetScript("OnEvent", function()
                totalEvents = totalEvents + 1
                local _, subevent, _, _, _, _, _, _, destName, _, _, spellId, spellName, _, auraType = CombatLogGetCurrentEventInfo()
                if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REMOVED" then
                    auraEvents = auraEvents + 1
                    local idSecret = issecretvalue and issecretvalue(spellId) and "SECRET" or "clean"
                    local nameSecret = issecretvalue and issecretvalue(spellName) and "SECRET" or "clean"
                    local destSecret = issecretvalue and issecretvalue(destName) and "SECRET" or "clean"
                    local typeSecret = issecretvalue and issecretvalue(auraType) and "SECRET" or "clean"
                    print("|cff00ccff[CLEU]|r " .. subevent .. " dest=" .. tostring(destName) .. "(" .. destSecret .. ") id=" .. tostring(spellId) .. "(" .. idSecret .. ") name=" .. tostring(spellName) .. "(" .. nameSecret .. ") type=" .. tostring(auraType) .. "(" .. typeSecret .. ")")
                end
            end)

            -- Heartbeat: print every 5 seconds
            PC.cleuHeartbeat = C_Timer.NewTicker(5, function()
                local deltaTotal = totalEvents - lastTotal
                local deltaAura = auraEvents - lastAura
                lastTotal = totalEvents
                lastAura = auraEvents
                if deltaTotal == 0 then
                    print("|cffff4444[CLEU HEARTBEAT]|r SILENT - 0 events in last 5s (total: " .. totalEvents .. ")")
                else
                    print("|cff44ff44[CLEU HEARTBEAT]|r " .. deltaTotal .. " events (" .. deltaAura .. " aura) in last 5s | total: " .. totalEvents .. " (" .. auraEvents .. " aura)")
                end
            end)

            print("|cff00ccff[PcRaidTools]|r CLEU test ON - heartbeat every 5s, aura events printed live")
        end
    else
        PC:ToggleMainWindow()
    end
end
