local addonName, PC = ...

----------------------------------------
-- Version Debug Panel
----------------------------------------

function PC:BuildVersionDebugPanel(parent)
    local y = 0

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText("Addon Versions")
    y = y - 28

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 0, y)
    desc:SetText("Query group members for their PcRaidTools version.")
    y = y - 28

    local scanBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    scanBtn:SetSize(100, 22)
    scanBtn:SetPoint("TOPLEFT", 0, y)
    scanBtn:SetText("Scan Group")
    scanBtn:SetScript("OnClick", function()
        PC:RequestVersions()
    end)

    local countText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", scanBtn, "RIGHT", 12, 0)
    countText:SetText("")
    self.versionCountText = countText
    y = y - 30

    -- Column headers
    local nameHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", 0, y)
    nameHeader:SetText("Player")

    local verHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    verHeader:SetPoint("TOPLEFT", 160, y)
    verHeader:SetText("Version")

    local statusHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", 280, y)
    statusHeader:SetText("Status")
    y = y - 18

    -- Scroll frame for the list
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, y)
    scrollFrame:SetPoint("BOTTOMRIGHT", -18, 0)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(440, 1)
    scrollFrame:SetScrollChild(scrollChild)
    self.versionScrollChild = scrollChild
    self.versionRows = {}
end

local ROW_HEIGHT = 20

local function GetOrCreateVersionRow(parent, rows, index)
    if rows[index] then return rows[index] end

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(440, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    row.version = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.version:SetPoint("LEFT", 160, 0)
    row.version:SetWidth(110)
    row.version:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("LEFT", 280, 0)
    row.status:SetWidth(150)
    row.status:SetJustifyH("LEFT")

    rows[index] = row
    return row
end

function PC:RefreshVersionPanel()
    if not self.versionScrollChild then return end
    local scrollChild = self.versionScrollChild
    local rows = self.versionRows

    -- Hide existing rows
    for _, row in pairs(rows) do
        row:Hide()
    end

    -- Find the newest version in the list
    local newest = self.VERSION
    for _, ver in pairs(self.knownVersions) do
        local parts = { strsplit(".", ver) }
        local nParts = { strsplit(".", newest) }
        local isNewer = false
        for i = 1, math.max(#parts, #nParts) do
            local a = tonumber(nParts[i]) or 0
            local b = tonumber(parts[i]) or 0
            if b > a then isNewer = true; break end
            if b < a then break end
        end
        if isNewer then newest = ver end
    end

    -- Sort names alphabetically
    local names = {}
    for name in pairs(self.knownVersions) do
        names[#names + 1] = name
    end
    table.sort(names)

    local myName = UnitName("player")
    for i, name in ipairs(names) do
        local row = GetOrCreateVersionRow(scrollChild, rows, i)
        local ver = self.knownVersions[name]

        row.name:SetText(name)
        row.version:SetText(ver)

        if ver == newest then
            row.name:SetTextColor(0.3, 1, 0.3)
            row.version:SetTextColor(0.3, 1, 0.3)
            row.status:SetText("|cff44ff44Current|r")
        else
            row.name:SetTextColor(1, 0.5, 0.2)
            row.version:SetTextColor(1, 0.5, 0.2)
            row.status:SetText("|cffff8800Out of Date|r")
        end

        if name == myName then
            row.name:SetText(name .. " |cff888888(you)|r")
        end

        row:Show()
    end

    scrollChild:SetHeight(math.max(1, #names * ROW_HEIGHT))

    if self.versionCountText then
        self.versionCountText:SetText("|cffaaaaaa" .. #names .. " player(s) with addon|r")
    end
end
