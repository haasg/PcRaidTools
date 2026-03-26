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
    print("|cff00ccffPcRaidTools|r v" .. PC.VERSION .. " loaded. Type |cff00ccff/pc|r to open.")
end)

----------------------------------------
-- Slash Command
----------------------------------------

SLASH_PCRAIDTOOLS1 = "/pc"
SlashCmdList["PCRAIDTOOLS"] = function()
    PC:ToggleMainWindow()
end
