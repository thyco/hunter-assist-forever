local _, addon = ...
local Aspect = { settingKey = "aspectCheckEnabled", eventDriven = true, worldReady = false }
local cheetahSpellID = 5118
local packSpellID = 13159
addon.AspectWarning = Aspect
addon:RegisterFeature(Aspect)

local function read(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

function Aspect:Initialize()
    addon.AspectIcon:Initialize()

    local frame = CreateFrame("Frame")
    self.frame = frame
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "SPELL_TEXT_UPDATE" }) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_LEAVING_WORLD" then
            self.worldReady = false
            self:Stop()
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            self.worldReady = true
            self.inCombat = addon.Client.Boolean(read(UnitAffectingCombat, "player")) == true
        elseif event == "PLAYER_REGEN_DISABLED" then
            self.inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            self.inCombat = false
            addon.Glow.Prepare(addon.AspectIcon.frame)
        elseif event == "UNIT_AURA" then
            if not addon.Client.Readable(unit) or unit ~= "player" then
                return
            end
        end

        self:Refresh()
    end)
end

function Aspect:Refresh()
    if not self.worldReady or not self.inCombat or not addon.Config.Get(self.settingKey) then
        self:Stop()
        return
    end

    local getAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    local cheetah = read(getAura, cheetahSpellID)
    local pack = read(getAura, packSpellID)
    self.spellID = cheetah and cheetahSpellID or (pack and packSpellID or nil)
    addon.AspectIcon:Set(self.spellID, true)
end

function Aspect:ApplySettings()
    addon.AspectIcon:ApplySettings()
    self:Refresh()
end

function Aspect:Stop()
    self.spellID = nil
    addon.AspectIcon:Set(nil, false)
end
