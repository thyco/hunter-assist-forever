local _, addon = ...
local kinds = { "mongoose", "counterattack" }
local Feature = {
    eventDriven = true,
    owners = { mongoose = "mongoose-ready", counterattack = "counterattack-ready" },
    buttons = {},
    ready = {},
}
addon.ReactiveGlow = Feature
addon:RegisterFeature(Feature)

function Feature:Prepare()
    if not InCombatLockdown() then
        for _, button in ipairs(addon.Buttons.All()) do
            addon.Glow.Prepare(button)
        end

        if addon.Config.Get("counterattackOverlayEnabled") then
            addon.CounterattackOverlay:Prepare(addon.Buttons.Selected(
                addon.Config.Get("counterattackBar"), addon.Config.Get("counterattackButton")))
        end
    end
end

function Feature:Initialize()
    self:Prepare()
    addon.ReactiveSpells:Rebuild()
    local frame = CreateFrame("Frame")
    self.frame = frame
    local elapsed = 0
    self.update = function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            self:Refresh(false, "poll")
        end
    end

    for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN",
        "UNIT_SPELLCAST_SUCCEEDED", "SPELLS_CHANGED",
        "PLAYER_TALENT_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_PAGE_CHANGED", "SPELL_DATA_LOAD_RESULT" }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
        if event == "PLAYER_LEAVING_WORLD" then
            self.loading = true
            self:Stop()
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            self.loading = false
        elseif event == "UNIT_SPELLCAST_SUCCEEDED"
            and not addon.ReactiveSpells:ReactiveCast(unit, spellID) then
            return
        end

        if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
            or event == "PLAYER_ENTERING_WORLD" or event == "SPELL_DATA_LOAD_RESULT" then
            addon.ReactiveSpells:Rebuild()
        end
        self:Refresh(event == "SPELL_UPDATE_COOLDOWN", event)
    end)
end

function Feature:Refresh(cooldownEvent, source)
    self:Prepare()
    if self.loading then
        self:Stop()
        return
    end

    local combat = UnitAffectingCombat and addon.Client.Boolean(UnitAffectingCombat("player")) == true
    local polling = false
    for _, kind in ipairs(kinds) do
        local owner = self.owners[kind]
        local button
        if addon.Config.Get(kind .. "GlowEnabled")
            or (kind == "counterattack" and addon.Config.Get("counterattackOverlayEnabled")) then
            button = addon.Buttons.Selected(addon.Config.Get(kind .. "Bar"), addon.Config.Get(kind .. "Button"))
        end

        if self.buttons[kind] and self.buttons[kind] ~= button then
            addon.Glow.Set(self.buttons[kind], owner, false)
        end
        self.buttons[kind] = button

        if combat and button then
            polling = true
            self.ready[kind] = addon.ReactiveSpells:Ready(kind, cooldownEvent, source)
            local visible = button:IsVisible() and self.ready[kind]
            addon.Glow.Set(button, owner, visible and addon.Config.Get(kind .. "GlowEnabled"))
            if kind == "counterattack" then
                addon.CounterattackOverlay:Set(button,
                    visible and addon.Config.Get("counterattackOverlayEnabled"))
            end
        else
            self.ready[kind] = false
            addon.Glow.ClearOwner(owner)
            if kind == "counterattack" then
                addon.CounterattackOverlay:Stop()
            end
        end
    end

    self.frame:SetScript("OnUpdate", polling and self.update or nil)
end

function Feature:ApplySettings()
    for _, kind in ipairs(kinds) do
        local color
        if not addon.Config.Get(kind .. "NativeColor") then
            local red, green, blue = addon.Config.GetColor(kind .. "GlowColor")
            color = { red, green, blue, 1 }
        end

        addon.Glow.ConfigureOwner(self.owners[kind], { color = color })
    end

    self:Refresh()
end

function Feature:Stop()
    self.ready = {}
    self.buttons = {}
    addon.ReactiveSpells.gcdOnly = {}
    addon.ReactiveSpells.procUsable = {}
    addon.ReactiveSpells.consumed = {}
    for _, kind in ipairs(kinds) do
        addon.Glow.ClearOwner(self.owners[kind])
    end
    addon.CounterattackOverlay:Stop()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
end
