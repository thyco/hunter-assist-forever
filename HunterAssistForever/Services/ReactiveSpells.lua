local _, addon = ...
local Spells = { ids = {}, gcdOnly = {}, procUsable = {} }
addon.ReactiveSpells = Spells
local seeds = { 1495, 19306 } -- Mongoose Bite, Counterattack (rank one).

local function read(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

local function number(value)
    return addon.Client.Number(value) and value == value and value >= 0 and value < math.huge
end

local function spellUsability(id)
    if not C_Spell or type(C_Spell.IsSpellUsable) ~= "function" then
        return nil, nil
    end

    local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, id)
    if not ok or (noMana ~= nil and not addon.Client.Readable(noMana)) then
        return nil, nil
    end

    return addon.Client.Boolean(usable), addon.Client.Boolean(noMana)
end

function Spells:Rebuild()
    self.ids, self.gcdOnly, self.procUsable = {}, {}, {}
    local names, seen = {}, {}
    for _, id in ipairs(seeds) do
        local info = read(C_Spell and C_Spell.GetSpellInfo, id)
        if type(info) == "table" and addon.Client.Readable(info.name) and type(info.name) == "string" then
            names[info.name] = true
        end
    end

    -- Match localized names against learned spellbook entries to use their rank.
    for _, entry in ipairs(addon.Client.PlayerSpells()) do
        local info = read(C_Spell and C_Spell.GetSpellInfo, entry.id)
        if type(info) == "table" and addon.Client.Readable(info.name)
            and type(info.name) == "string" and names[info.name] and not seen[entry.id] then
            self.ids[#self.ids + 1] = entry.id
            seen[entry.id] = true
        end
    end
end

function Spells:CooldownReady(id, cooldownEvent)
    local info = read(C_Spell and C_Spell.GetSpellCooldown, id)
    if cooldownEvent then
        self.gcdOnly[id] = type(info) == "table" and addon.Client.Boolean(info.isOnGCD) == true or nil
    end
    if type(info) ~= "table" then
        return false, false
    end

    if addon.Client.Boolean(info.isEnabled) == false then
        return false, false
    elseif addon.Client.Boolean(info.isActive) == false then
        self.gcdOnly[id] = nil
        return true, false
    end

    local start, duration = info.startTime, info.duration
    local now = read(GetTime)
    if self.gcdOnly[id] then
        if not number(start) or not number(duration) or not number(now)
            or (start > 0 and duration > 0 and now < start + duration) then
            return true, true
        end

        self.gcdOnly[id] = nil
    end

    if not number(start) or not number(duration) then
        return false, false
    end
    if start == 0 or duration == 0 then
        return true, false
    end

    local gcd = read(C_Spell and C_Spell.GetSpellCooldown, 61304)
    if type(gcd) == "table" and number(gcd.startTime) and number(gcd.duration)
        and gcd.duration > 0 and start == gcd.startTime and duration == gcd.duration
        and number(now) and now < start + duration then
        return true, true
    end

    return number(now) and now >= start + duration, false
end

function Spells:AnyReady(cooldownEvent)
    local ready = false
    for _, id in ipairs(self.ids) do
        local cooldownReady, gcdOnly = self:CooldownReady(id, cooldownEvent)
        local usable, noMana = spellUsability(id)
        -- Resource shortage also reports a usable reactive opportunity; a known GCD preserves it.
        if not cooldownReady or usable == nil or (usable == false and noMana ~= true and not gcdOnly) then
            self.procUsable[id] = nil
        elseif usable == true or noMana == true then
            self.procUsable[id] = true
        end

        if cooldownReady and self.procUsable[id] then
            ready = true
        end
    end

    return ready
end
