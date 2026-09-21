local _, addon = ...
local Spells = { ids = {}, gcdOnly = {} }
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

function Spells:Rebuild()
    self.ids, self.gcdOnly = {}, {}
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
        return false
    end

    if addon.Client.Boolean(info.isEnabled) == false then
        return false
    elseif addon.Client.Boolean(info.isActive) == false or self.gcdOnly[id] then
        return true
    end

    local start, duration = info.startTime, info.duration
    if not number(start) or not number(duration) then
        return false
    end
    if start == 0 or duration == 0 then
        return true
    end

    local gcd = read(C_Spell and C_Spell.GetSpellCooldown, 61304)
    if type(gcd) == "table" and number(gcd.startTime) and number(gcd.duration)
        and gcd.duration > 0 and start == gcd.startTime and duration == gcd.duration then
        return true
    end

    local now = read(GetTime)
    return number(now) and now >= start + duration
end

function Spells:AnyReady(cooldownEvent)
    local ready = false
    for _, id in ipairs(self.ids) do
        local cooldownReady = self:CooldownReady(id, cooldownEvent)
        local usable = read(C_Spell and C_Spell.IsSpellUsable, id)
        if cooldownReady and addon.Client.Boolean(usable) == true then
            ready = true
        end
    end

    return ready
end
