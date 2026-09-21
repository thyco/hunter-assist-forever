local _, addon = ...
local Range = { spells = {}, probes = {}, samples = {}, results = {} }
addon.Range = Range
local UNKNOWN = {}

function Range:Rebuild()
    self.spells = {}
    self.probes = {}
    local seen = {}

    for _, entry in ipairs(addon.Client.PlayerSpells()) do
        local spell = self.spells[entry.id] or addon.Client.SpellInfo(entry.id)
        if spell then
            self.spells[entry.id] = spell
            if addon.Client.Number(entry.baseID) then
                self.spells[entry.baseID] = spell
            end

            if spell.minRange == 0 and not seen[spell.id] then
                self.probes[#self.probes + 1] = spell
                seen[spell.id] = true
            end
        end
    end

    -- Shorter probes provide the strongest bound and often finish the search early.
    table.sort(self.probes, function(left, right)
        return left.maxRange < right.maxRange
    end)
end

function Range:BeginUpdate()
    self.samples = {}
    self.results = {}
    self.hasTarget = addon.Client.HasTarget()
end

function Range:Sample(id)
    local value = self.samples[id]
    if value == nil then
        value = addon.Client.InRange(id)
        if value == nil then
            value = UNKNOWN
        end
        self.samples[id] = value
    end

    if value ~= UNKNOWN then
        return value
    end
end

function Range:IsTooClose(id)
    if not self.hasTarget or not addon.Client.Number(id) then
        return false
    end

    local spell = self.spells[id]
    if not spell or spell.minRange <= 0 then
        return false
    end

    if self.results[spell.id] ~= nil then
        return self.results[spell.id]
    end

    local close = false
    if self:Sample(spell.id) == false then
        for _, probe in ipairs(self.probes) do
            -- A longer-range probe could still reach a target beyond the shot's
            -- maximum. Never use it to infer the minimum-range deadzone.
            if probe.maxRange <= spell.maxRange and self:Sample(probe.id) == true then
                close = true
                break
            end
        end
    end

    self.results[spell.id] = close
    return close
end
