local _, addon = ...
local Overlay = { entries = {} }
addon.CounterattackOverlay = Overlay

local function spellTexture()
    if not C_Spell then
        return nil
    end

    if type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, 19306)
        if ok and addon.Client.Readable(texture) and texture then
            return texture
        end
    end

    if type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, 19306)
        if ok and addon.Client.Readable(info) and type(info) == "table"
            and addon.Client.Readable(info.iconID) then
            return info.iconID
        end
    end
end

local function overlayLevel(button)
    local level = button:GetFrameLevel() + 5

    for _, key in ipairs({ "cooldown", "chargeCooldown", "lossOfControlCooldown" }) do
        local cooldown = button[key]
        if cooldown and type(cooldown.GetFrameLevel) == "function" then
            local ok, cooldownLevel = pcall(cooldown.GetFrameLevel, cooldown)
            if ok and addon.Client.Number(cooldownLevel) then
                level = math.max(level, cooldownLevel + 2)
            end
        end
    end

    return level
end

function Overlay:Prepare(button)
    if not button or self.entries[button] or self.unavailable or InCombatLockdown() then
        return
    end

    local texture = spellTexture()
    if not texture then
        return
    end

    local frame
    local ok, entry = pcall(function()
        frame = CreateFrame("Frame", nil, button)
        frame:Hide()
        frame:SetAllPoints(button.icon or button)
        frame:SetFrameLevel(overlayLevel(button))
        frame:EnableMouse(false)

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(frame)
        icon:SetTexture(texture)

        local cooldown = CreateFrame("Cooldown", nil, frame)
        cooldown:SetAllPoints(frame)
        cooldown:EnableMouse(false)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetHideCountdownNumbers(true)

        return { frame = frame, texture = icon, cooldown = cooldown }
    end)

    if ok then
        self.entries[button] = entry

        local glow = addon.Glow.Prepare(button)
        if glow then
            pcall(glow.frame.SetFrameLevel, glow.frame, entry.frame:GetFrameLevel() + 2)
        end
    else
        if frame then
            frame:Hide()
        end
        self.unavailable = true
    end
end

local function updateGCD(cooldown)
    if C_Spell and type(C_Spell.GetSpellCooldownDuration) == "function"
        and type(cooldown.SetCooldownFromDurationObject) == "function" then
        local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, addon.gcdSpellID)
        if ok and duration and pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration) then
            return
        end
    end

    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, info = pcall(C_Spell.GetSpellCooldown, addon.gcdSpellID)
        if ok and type(info) == "table" and addon.Client.Number(info.startTime)
            and addon.Client.Number(info.duration) and info.duration > 0 then
            if pcall(cooldown.SetCooldown, cooldown, info.startTime, info.duration) then
                return
            end
        end
    end

    pcall(cooldown.Clear, cooldown)
end

local function hide(entry)
    if entry then
        pcall(entry.frame.Hide, entry.frame)
    end
end

function Overlay:Set(button, active)
    if self.button and self.button ~= button then
        hide(self.entries[self.button])
    end

    self.button = button
    if not active or not button then
        hide(button and self.entries[button])
        return
    end

    self:Prepare(button)
    local entry = self.entries[button]
    if not entry or self.unavailable then
        return
    end

    self.frame, self.texture, self.cooldown = entry.frame, entry.texture, entry.cooldown
    updateGCD(entry.cooldown)
    if not pcall(entry.frame.Show, entry.frame) then
        self.unavailable = true
        hide(entry)
    end
end

function Overlay:Stop()
    self:Set(nil, false)
end
