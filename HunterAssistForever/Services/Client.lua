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

function Client.HasTarget()
    return Client.Boolean(UnitExists("target")) == true
        and Client.Boolean(UnitCanAttack("player", "target")) == true
        and Client.Boolean(UnitIsDeadOrGhost("target")) == false
end

function Client.SpellInfo(id)
    if not Client.Number(id) or not C_Spell or not C_Spell.GetSpellInfo
        or not C_Spell.IsSpellHarmful then
        return nil
    end

    local info = C_Spell.GetSpellInfo(id)
    if not info or not Client.Number(info.minRange) or not Client.Number(info.maxRange)
        or info.minRange < 0 or info.maxRange <= info.minRange
        or Client.Boolean(C_Spell.IsSpellHarmful(id)) ~= true then
        return nil
    end

    return { id = id, minRange = info.minRange, maxRange = info.maxRange }
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
                    spells[#spells + 1] = { id = item.spellID, baseID = item.actionID }
                end
            end
        end
    end

    return spells
end

function Client.InRange(id)
    if not C_Spell or not C_Spell.IsSpellInRange then
        return nil
    end

    -- API restrictions can vary by beta build. Unknown results never prove range.
    local ok, result = pcall(C_Spell.IsSpellInRange, id, "target")
    if ok then
        return Client.Boolean(result)
    end
end

function Client.ActionSpell(slot)
    if not Client.Number(slot) or slot < 1 or slot ~= math.floor(slot) or not GetActionInfo then
        return nil
    end

    local kind, id, subtype = GetActionInfo(slot)
    if not Client.Readable(kind) or not Client.Number(id) or not Client.Readable(subtype) then
        return nil
    end

    if kind == "spell" or (kind == "macro" and subtype == "spell") then
        return id
    end
end
