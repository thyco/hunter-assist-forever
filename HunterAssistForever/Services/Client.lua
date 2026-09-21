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

function Client.CanAttack(unit)
    return Client.Boolean(UnitExists(unit)) == true
        and Client.Boolean(UnitCanAttack("player", unit)) == true
        and Client.Boolean(UnitIsDeadOrGhost(unit)) == false
end

function Client.RangeUnit()
    local hasTarget = Client.Boolean(UnitExists("target"))
    if hasTarget == true then
        if Client.CanAttack("target") then
            return "target"
        end
    elseif hasTarget == false and Client.CanAttack("mouseover") then
        return "mouseover"
    end
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

    local name = "spell " .. id
    if Client.Readable(info.name) and type(info.name) == "string" then
        name = info.name:gsub("|", "||"):gsub("[\r\n]", " ")
    end

    return { id = id, name = name, minRange = info.minRange, maxRange = info.maxRange }
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

local function rangeCheck(api, ...)
    if type(api) ~= "function" then
        return nil, "missing API"
    end

    local ok, value = pcall(api, ...)
    if not ok then
        return nil, "error"
    elseif not Client.Readable(value) then
        return nil, "restricted"
    end

    local result = Client.Boolean(value)
    if result == nil then
        return nil, "unavailable"
    end

    return result, result and "in range" or "out of range"
end

function Client.InRange(id, slot, bank, unit)
    local result, bookStatus
    if Client.Number(slot) and Client.Number(bank) then
        result, bookStatus = rangeCheck(C_SpellBook and C_SpellBook.IsSpellBookItemInRange,
            slot, bank, unit)
    else
        bookStatus = "no spellbook slot"
    end

    if result ~= nil then
        return result, "spellbook", bookStatus, "not checked"
    end

    local idStatus
    result, idStatus = rangeCheck(C_Spell and C_Spell.IsSpellInRange, id, unit)

    return result, result ~= nil and "spell ID" or "none", bookStatus, idStatus
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
