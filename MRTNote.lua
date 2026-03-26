local addonName, PC = ...

----------------------------------------
-- MRT Note Reader
----------------------------------------

PC.lastNoteText = nil
PC.parsedSpellId = nil
PC.parsedPlayers = {}   -- ordered list of { name, found }
PC.parseErrors = {}

function PC:ReadMRTNote()
    if not VMRT or not VMRT.Note or not VMRT.Note.Text1 then
        self.lastNoteText = nil
        return nil
    end
    self.lastNoteText = VMRT.Note.Text1
    return self.lastNoteText
end

function PC:HasMRT()
    return VMRT and VMRT.Note and true or false
end

----------------------------------------
-- Note Parsing
----------------------------------------

function PC:ParseNote(text)
    self.parsedSpellId = nil
    wipe(self.parsedPlayers)
    wipe(self.parseErrors)

    if not text or text == "" then
        self.parseErrors[#self.parseErrors + 1] = "Note is empty."
        return false
    end

    -- Split into lines
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            lines[#lines + 1] = trimmed
        end
    end

    if #lines == 0 then
        self.parseErrors[#self.parseErrors + 1] = "Note is empty."
        return false
    end

    -- Line 1: Spell ID
    local spellId = tonumber(lines[1])
    if not spellId then
        self.parseErrors[#self.parseErrors + 1] = "First line is not a valid spell ID: \"" .. lines[1] .. "\""
        return false
    end
    self.parsedSpellId = spellId

    -- Find PCSTART and PCEND
    local startIdx = nil
    local endIdx = nil
    for i, line in ipairs(lines) do
        if line:upper() == "PCSTART" then
            startIdx = i
        elseif line:upper() == "PCEND" then
            endIdx = i
            break
        end
    end

    if not startIdx then
        self.parseErrors[#self.parseErrors + 1] = "Missing PCSTART tag."
        return false
    end
    if not endIdx then
        self.parseErrors[#self.parseErrors + 1] = "Missing PCEND tag."
        return false
    end
    if endIdx <= startIdx + 1 then
        self.parseErrors[#self.parseErrors + 1] = "No player names between PCSTART and PCEND."
        return false
    end

    -- Extract player names
    for i = startIdx + 1, endIdx - 1 do
        local name = lines[i]
        local unit = self:GetUnitForName(name)
        self.parsedPlayers[#self.parsedPlayers + 1] = {
            name = name,
            found = unit ~= nil,
        }
        if not unit then
            self.parseErrors[#self.parseErrors + 1] = "Player not found in group: \"" .. name .. "\""
        end
    end

    return true
end

-- Convenience: read + parse in one call
function PC:ReadAndParseNote()
    local text = self:ReadMRTNote()
    if not text then
        wipe(self.parsedPlayers)
        wipe(self.parseErrors)
        self.parsedSpellId = nil
        self.parseErrors[#self.parseErrors + 1] = "Could not read MRT note."
        return false
    end
    return self:ParseNote(text)
end
