local _, addon = ...
local Feature = { settingKey = "reactiveGlowEnabled", eventDriven = true, owner = "reactive-ready" }
addon.ReactiveGlow = Feature
addon:RegisterFeature(Feature)

function Feature:Prepare()
    if not InCombatLockdown() then
        for _, button in ipairs(addon.Buttons.All()) do
            addon.Glow.Prepare(button)
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
            self:Refresh()
        end
    end

    for _, event in ipairs({ "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED",
        "PLAYER_TALENT_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_PAGE_CHANGED", "SPELL_DATA_LOAD_RESULT" }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LEAVING_WORLD" then
            self.loading = true
            self:Stop()
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            self.loading = false
        end

        if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
            or event == "PLAYER_ENTERING_WORLD" or event == "SPELL_DATA_LOAD_RESULT" then
            addon.ReactiveSpells:Rebuild()
        end
        self:Refresh(event == "SPELL_UPDATE_COOLDOWN")
    end)
end

function Feature:Refresh(cooldownEvent)
    self:Prepare()
    if not addon.Config.Get(self.settingKey) or self.loading then
        self:Stop()
        return
    end

    local button = addon.Buttons.Selected(addon.Config.Get("reactiveBar"), addon.Config.Get("reactiveButton"))
    if self.button and self.button ~= button then
        addon.Glow.Set(self.button, self.owner, false)
    end
    self.button = button

    local combat = UnitAffectingCombat and addon.Client.Boolean(UnitAffectingCombat("player")) == true
    self.frame:SetScript("OnUpdate", combat and button and self.update or nil)
    if not combat or not button then
        self.ready = false
        addon.Glow.ClearOwner(self.owner)
        return
    end

    self.ready = addon.ReactiveSpells:AnyReady(cooldownEvent)
    addon.Glow.Set(button, self.owner, button:IsVisible() and self.ready)
end

function Feature:ApplySettings()
    self:Refresh(true)
end

function Feature:Stop()
    self.ready = false
    self.button = nil
    addon.ReactiveSpells.gcdOnly = {}
    addon.Glow.ClearOwner(self.owner)
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
end
