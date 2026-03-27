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
    else
        PC:ToggleMainWindow()
    end
end
