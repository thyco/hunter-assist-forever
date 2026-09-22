local _, addon = ...
local Client = {}
addon.Client = Client

function Client.Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Client.Number(value)
    return Client.Readable(value) and type(value) == "number"
end

function Client.Boolean(value)
    if not Client.Readable(value) then
        return nil
    end

    if value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
end

function Client.PlayerSpells()
    local spells = {}
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines
        or not C_SpellBook.GetSpellBookSkillLineInfo or not C_SpellBook.GetSpellBookItemInfo
        or not Enum or not Enum.SpellBookSpellBank or not Enum.SpellBookItemType then
        return spells
    end

    local bank = Enum.SpellBookSpellBank.Player
    local count = C_SpellBook.GetNumSpellBookSkillLines()
    if not Client.Number(count) then
        return spells
    end

    for lineIndex = 1, count do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        if line and Client.Number(line.itemIndexOffset) and Client.Number(line.numSpellBookItems) then
            for index = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if item and Client.Readable(item.itemType) and item.itemType == Enum.SpellBookItemType.Spell
                    and Client.Boolean(item.isPassive) == false and Client.Boolean(item.isOffSpec) == false
                    and Client.Number(item.spellID) then
                    spells[#spells + 1] = { id = item.spellID, baseID = item.actionID, slot = index, bank = bank }
                end
            end
        end
    end

    return spells
end
