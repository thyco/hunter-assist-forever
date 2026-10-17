local _, addon = ...
local Spells = { ids = { mongoose = {}, counterattack = {} }, gcdOnly = {},
    procUsable = {}, consumed = {}, diagnostics = { enabled = false, entries = {}, last = {} } }
addon.ReactiveSpells = Spells
local seeds = { mongoose = 1495, counterattack = 19306 } -- Rank one.
local gcdEvidenceSeconds = 1.6

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

local function durationBoolean(duration, methodName)
    local ok, method = pcall(function() return duration[methodName] end)
    if not ok or not addon.Client.Readable(method) or type(method) ~= "function" then
        return nil
    end

    return addon.Client.Boolean(read(method, duration))
end

local function gcdTiming(now)
    local info = read(C_Spell and C_Spell.GetSpellCooldown, addon.gcdSpellID)
    if type(info) ~= "table" then
        return nil, nil, false
    end

    local active = addon.Client.Boolean(info.isActive) == true
    if not number(info.startTime) or not number(info.duration) or not number(now) then
        return nil, nil, active
    end

    if info.duration == 0 or now >= info.startTime + info.duration then
        return nil, nil, false
    end

    return info.startTime, info.duration, true
end

local function traceValue(value)
    if not addon.Client.Readable(value) then
        return "secret"
    end

    if value == nil then
        return "nil"
    end

    if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
        return tostring(value)
    end

    return type(value)
end

local function traceCooldown(id)
    local info = read(C_Spell and C_Spell.GetSpellCooldown, id)
    local ownDuration = read(C_Spell and C_Spell.GetSpellCooldownDuration, id, true)
    if type(info) ~= "table" then
        return "api=" .. traceValue(info)
    end

    local details = "raw(active=" .. traceValue(info.isActive)
        .. ",gcd=" .. traceValue(info.isOnGCD)
        .. ",start=" .. traceValue(info.startTime)
        .. ",duration=" .. traceValue(info.duration) .. ")"
    if ownDuration then
        details = details .. " durationObject(secret=" .. traceValue(durationBoolean(ownDuration, "HasSecretValues"))
            .. ",zero=" .. traceValue(durationBoolean(ownDuration, "IsZero"))
            .. ",expired=" .. traceValue(durationBoolean(ownDuration, "HasExpired")) .. ")"
    else
        details = details .. " durationObject=nil"
    end

    return details
end

function Spells:SetDiagnostics(enabled)
    self.diagnostics = { enabled = enabled == true, entries = {}, last = {} }
end

function Spells:DiagnosticLines(kind)
    local entries = self.diagnostics.entries[kind] or {}
    local lines = {}
    for index, entry in ipairs(entries) do
        lines[index] = entry
    end

    return lines
end

function Spells:RecordDiagnostic(kind, source, state)
    local diagnostics = self.diagnostics
    if not diagnostics.enabled or diagnostics.last[kind] == state then
        return
    end

    diagnostics.last[kind] = state
    local entries = diagnostics.entries[kind] or {}
    diagnostics.entries[kind] = entries
    entries[#entries + 1] = "t=" .. traceValue(read(GetTime)) .. " " .. (source or "refresh") .. " " .. state
    if #entries > 40 then
        table.remove(entries, 1)
    end
end

function Spells:Rebuild()
    self.ids, self.gcdOnly, self.procUsable = { mongoose = {}, counterattack = {} }, {}, {}
    local names, seen = {}, {}
    for kind, id in pairs(seeds) do
        local info = read(C_Spell and C_Spell.GetSpellInfo, id)
        if type(info) == "table" and addon.Client.Readable(info.name) and type(info.name) == "string" then
            names[info.name] = kind
        end
    end

    -- Match localized names against learned spellbook entries to use their rank.
    for _, entry in ipairs(addon.Client.PlayerSpells()) do
        local info = read(C_Spell and C_Spell.GetSpellInfo, entry.id)
        if type(info) == "table" and addon.Client.Readable(info.name)
            and type(info.name) == "string" and names[info.name] and not seen[entry.id] then
            local kind = names[info.name]
            self.ids[kind][#self.ids[kind] + 1] = entry.id
            seen[entry.id] = true
        end
    end
end

function Spells:ReactiveCast(unit, spellID)
    if not addon.Client.Readable(unit) or unit ~= "player"
        or not addon.Client.Number(spellID) then
        return false
    end

    for kind, ranks in pairs(self.ids) do
        for _, id in ipairs(ranks) do
            if id == spellID then
                local now = read(GetTime)

                for _, rankID in ipairs(ranks) do
                    self.procUsable[rankID] = nil
                    self.gcdOnly[rankID] = nil
                end

                self.consumed[kind] = {
                    spellID = id,
                    deadline = number(now) and now + gcdEvidenceSeconds or nil,
                    ownCooldownSeen = false,
                }

                self:RecordDiagnostic(kind, "cast", "spell=" .. id .. " consumed=true")

                return true
            end
        end
    end

    return false
end

function Spells:CooldownReady(id, cooldownEvent)
    local info = read(C_Spell and C_Spell.GetSpellCooldown, id)
    local now = read(GetTime)

    if cooldownEvent and type(info) == "table"
        and addon.Client.Boolean(info.isOnGCD) == true then
        self.gcdOnly[id] = number(now) and now + gcdEvidenceSeconds or nil
    end
    if type(info) ~= "table" then
        return false, false
    end

    if addon.Client.Boolean(info.isEnabled) == false then
        self.gcdOnly[id] = nil
        return false, false
    end

    local gcdStart, gcdDuration, gcdActive = gcdTiming(now)
    local gcdEvidence = number(now) and number(self.gcdOnly[id]) and now < self.gcdOnly[id]
    if not gcdEvidence then
        self.gcdOnly[id] = nil
    end
    local gcdOnly = gcdEvidence or gcdActive

    if addon.Client.Boolean(info.isActive) == false then
        return true, gcdOnly, "ready"
    end

    local ownDuration = read(C_Spell and C_Spell.GetSpellCooldownDuration, id, true)
    if ownDuration and durationBoolean(ownDuration, "HasSecretValues") == false then
        local zero = durationBoolean(ownDuration, "IsZero")
        local expired = durationBoolean(ownDuration, "HasExpired")
        if zero == true or expired == true then
            return true, gcdOnly, "ready"
        elseif zero == false and expired == false then
            self.gcdOnly[id] = nil
            return false, false, "active"
        end
    end

    local start, duration = info.startTime, info.duration
    if not number(start) or not number(duration) then
        return gcdOnly == true, gcdOnly == true, gcdOnly and nil or "active"
    end
    if start == 0 or duration == 0 then
        return true, gcdOnly, "ready"
    end

    if not number(now) then
        return false, false
    end

    if gcdStart and duration > gcdDuration + 0.1
        and start + duration > gcdStart + gcdDuration + 0.1 then
        self.gcdOnly[id] = nil
        return false, false, "active"
    end

    if gcdEvidence or (gcdStart and duration <= gcdDuration + 0.1
        and math.abs(start + duration - gcdStart - gcdDuration) <= 0.1) then
        return true, true
    end

    if now >= start + duration then
        self.gcdOnly[id] = nil
        return true, false, "ready"
    end

    return false, false, "active"
end

function Spells:Ready(kind, cooldownEvent, source)
    local ready = false
    local consumed = self.consumed[kind]
    local allInactive = consumed ~= nil and #(self.ids[kind] or {}) > 0
    local castCooldownReady = false
    local diagnostic = self.diagnostics.enabled and {} or nil

    for _, id in ipairs(self.ids[kind] or {}) do
        local cooldownReady, gcdOnly, ownCooldownState = self:CooldownReady(id, cooldownEvent)
        local usable, noMana = spellUsability(id)
        if consumed then
            self.procUsable[id] = nil

            if usable ~= false or noMana == true or gcdOnly then
                allInactive = false
            end

            if id == consumed.spellID then
                local now = read(GetTime)
                if number(now) and number(consumed.deadline) and now >= consumed.deadline then
                    if ownCooldownState == "active" and not gcdOnly then
                        consumed.ownCooldownSeen = true
                    elseif ownCooldownState == "ready" then
                        castCooldownReady = true
                    end
                end
            end
        else
            -- Resource shortage also reports a usable reactive opportunity; a known GCD preserves it.
            if not cooldownReady or usable == nil or (usable == false and noMana ~= true and not gcdOnly) then
                self.procUsable[id] = nil
            elseif usable == true or noMana == true then
                self.procUsable[id] = true
            end
        end

        if not consumed and cooldownReady and self.procUsable[id] then
            ready = true
        end

        if diagnostic then
            diagnostic[#diagnostic + 1] = "id=" .. id
                .. " usable=" .. traceValue(usable)
                .. " noMana=" .. traceValue(noMana)
                .. " cdReady=" .. traceValue(cooldownReady)
                .. " gcdOnly=" .. traceValue(gcdOnly)
                .. " own=" .. traceValue(ownCooldownState)
                .. " procCached=" .. traceValue(self.procUsable[id] == true)
                .. " " .. traceCooldown(id)
        end
    end

    local now = read(GetTime)
    if diagnostic then
        local deadlinePassed = consumed and number(now) and number(consumed.deadline)
            and now >= consumed.deadline
        local state = "consumed=" .. traceValue(consumed ~= nil)
            .. " deadlinePassed=" .. traceValue(deadlinePassed)
            .. " ownSeen=" .. traceValue(consumed and consumed.ownCooldownSeen)
            .. " allInactive=" .. traceValue(allInactive)
            .. " castReady=" .. traceValue(castCooldownReady)
            .. " ready=" .. traceValue(ready)
            .. " " .. table.concat(diagnostic, " | ")
        self:RecordDiagnostic(kind, source, state)
    end

    if consumed and number(now) and number(consumed.deadline) and now >= consumed.deadline
        and ((consumed.ownCooldownSeen and castCooldownReady)
            or (not consumed.ownCooldownSeen and allInactive)) then
        self.consumed[kind] = nil

        return self:Ready(kind, false, "rearmed")
    end

    return ready
end
