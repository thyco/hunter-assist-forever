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
            spell.slot, spell.bank = entry.slot, entry.bank
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
    self.checks = {}
    self.evidence = {}
    self.unit = addon.Client.RangeUnit()
    self.hasTarget = self.unit ~= nil
end

function Range:Sample(id)
    local value = self.samples[id]
    if value == nil then
        local spell = self.spells[id]
        local source, bookStatus, idStatus
        value, source, bookStatus, idStatus = addon.Client.InRange(id, spell.slot, spell.bank, self.unit)
        self.checks[id] = { source = source, book = bookStatus, spellID = idStatus }
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
                self.evidence[spell.id] = probe.id
                break
            end
        end
    end

    self.results[spell.id] = close
    return close
end

-- Describe the last refresh without making extra API calls or printing raw values.
function Range:DescribeChecks()
    if not self.hasTarget then
        return { "No eligible unit: use a living attackable target, or mouseover with no target selected." }
    end

    local lines, ids = {}, {}
    for id in pairs(self.checks or {}) do
        ids[#ids + 1] = id
    end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local spell, check = self.spells[id], self.checks[id]
        local text = spell.name .. " (" .. id .. ", " .. spell.minRange .. "-" .. spell.maxRange
            .. " yd): spellbook=" .. check.book .. "; spell ID=" .. check.spellID
            .. "; used=" .. check.source
        local evidence = self.evidence[id]
        if evidence then
            text = text .. "; too close confirmed by " .. self.spells[evidence].name .. " (" .. evidence .. ")"
        end
        lines[#lines + 1] = text
    end

    if #lines == 0 then
        lines[1] = "No eligible ranged spell was checked on a visible default button."
    end
    table.insert(lines, 1, "Checking: " .. self.unit .. " (living, attackable)")
    lines[#lines + 1] = "Only checks needed for this refresh are listed; unneeded probes are skipped."

    return lines
end
