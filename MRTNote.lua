local addonName, PC = ...

----------------------------------------
-- MRT Note Reader
----------------------------------------

PC.lastNoteText = nil

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
