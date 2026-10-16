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

function Overlay:Prepare(button)
    if not button or self.entries[button] or InCombatLockdown() then
        return
    end

    local texture = spellTexture()
    if not texture then
        return
    end

    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button.icon or button)
    frame:SetFrameLevel(button:GetFrameLevel() + 5)
    frame:EnableMouse(false)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(texture)

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame)
    cooldown:EnableMouse(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetHideCountdownNumbers(true)
    frame:Hide()

    self.entries[button] = { frame = frame, texture = icon, cooldown = cooldown }
end

local function updateGCD(cooldown)
    if C_Spell and type(C_Spell.GetSpellCooldownDuration) == "function"
        and type(cooldown.SetCooldownFromDurationObject) == "function" then
        local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, 61304)
        if ok and duration and pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration) then
            return
        end
    end

    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, info = pcall(C_Spell.GetSpellCooldown, 61304)
        if ok and type(info) == "table" and addon.Client.Number(info.startTime)
            and addon.Client.Number(info.duration) and info.duration > 0 then
            if pcall(cooldown.SetCooldown, cooldown, info.startTime, info.duration) then
                return
            end
        end
    end

    pcall(cooldown.Clear, cooldown)
end

function Overlay:Set(button, active)
    if self.button and self.button ~= button then
        local previous = self.entries[self.button]
        if previous then
            previous.frame:Hide()
        end
    end

    self.button = button
    if not active or not button then
        if button and self.entries[button] then
            self.entries[button].frame:Hide()
        end
        return
    end

    self:Prepare(button)
    local entry = self.entries[button]
    if not entry then
        return
    end

    self.frame, self.texture, self.cooldown = entry.frame, entry.texture, entry.cooldown
    updateGCD(entry.cooldown)
    entry.frame:Show()
end

function Overlay:Stop()
    self:Set(nil, false)
end
