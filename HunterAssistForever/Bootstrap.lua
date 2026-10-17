local _, addon = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    addon.Config.Initialize()
    addon.SettingsPanel:Initialize()
    addon:Start()
    self:UnregisterAllEvents()
end)

SLASH_HUNTERASSISTFOREVER1 = "/haf"
SlashCmdList.HUNTERASSISTFOREVER = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "config" then
        addon.SettingsPanel:Open()
        return
    end

    if command == "reactive-debug" then
        local enabled = not addon.ReactiveSpells.diagnostics.enabled
        addon.ReactiveSpells:SetDiagnostics(enabled)
        print("Reactive diagnostics " .. (enabled and "on" or "off")
            .. ". Use /haf reactive-log mongoose or /haf reactive-log counterattack after the issue occurs.")
        return
    end

    local diagnosticKind = command:match("^reactive%-log%s+(%S+)$")
    if diagnosticKind == "mongoose" or diagnosticKind == "counterattack" then
        local lines = addon.ReactiveSpells:DiagnosticLines(diagnosticKind)
        print("Reactive diagnostics: " .. diagnosticKind .. " (" .. #lines .. " changes)")
        for _, line in ipairs(lines) do
            print(line)
        end
        return
    end

    local version, build, _, interface = GetBuildInfo()
    print("Hunter Assist Forever " .. addon.version .. " | client " .. version
        .. " (" .. build .. ") | interface " .. interface)
    if not addon.started then
        print("Hunter helpers are inactive on this character. /haf config to configure.")
        return
    end

    addon.ReactiveGlow:Refresh()
    for _, spell in ipairs({ { "mongoose", "Mongoose Bite" }, { "counterattack", "Counterattack" } }) do
        local kind, label = spell[1], spell[2]
        print(label .. " glow: " .. (addon.Config.Get(kind .. "GlowEnabled") and "enabled" or "disabled")
            .. " | bar " .. addon.Config.Get(kind .. "Bar") .. ", button " .. addon.Config.Get(kind .. "Button")
            .. " | learned spells: " .. #addon.ReactiveSpells.ids[kind]
            .. " | ready: " .. tostring(addon.ReactiveGlow.ready[kind] == true))
    end
    addon.Ammo:Refresh()
    print("Ammo: " .. (addon.Ammo.sample and tostring(addon.Ammo.sample.count) or "unavailable")
        .. " | " .. (addon.Ammo.status or "not checked"))
    addon.PetHealth:Refresh()
    print("Pet health: " .. (addon.PetHealth.sample
        and (math.floor(addon.PetHealth.sample.percent + 0.5) .. "%") or "unavailable")
        .. " | " .. (addon.PetHealth.status or "not checked"))
    addon.PetHappiness:Refresh()
    print("Pet happiness: " .. (addon.PetHappiness.status or "not checked"))
    addon.AspectWarning:Refresh()
    local aspect = addon.AspectWarning.spellID == 5118 and "Cheetah"
        or (addon.AspectWarning.spellID == 13159 and "Pack" or "none")
    print("Aspect reminder: " .. (addon.Config.Get("aspectCheckEnabled") and "enabled" or "disabled")
        .. " | in combat: " .. tostring(addon.AspectWarning.inCombat == true)
        .. " | active: " .. aspect)
    print("/haf config to configure ammo, pet, reactive glow and aspect settings.")
end
