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

    local version, build, _, interface = GetBuildInfo()
    print("Hunter Assist Forever " .. addon.version .. " | client " .. version
        .. " (" .. build .. ") | interface " .. interface)
    if not addon.started then
        print("Hunter helpers are inactive on this character. /haf config to configure.")
        return
    end

    addon.ReactiveGlow:Refresh()
    print("Reactive glow: " .. (addon.Config.Get("reactiveGlowEnabled") and "enabled" or "disabled")
        .. " | bar " .. addon.Config.Get("reactiveBar") .. ", button " .. addon.Config.Get("reactiveButton")
        .. " | learned spells: " .. #addon.ReactiveSpells.ids
        .. " | ready: " .. tostring(addon.ReactiveGlow.ready == true))
    addon.Ammo:Refresh()
    print("Ammo: " .. (addon.Ammo.sample and tostring(addon.Ammo.sample.count) or "unavailable")
        .. " | " .. (addon.Ammo.status or "not checked"))
    addon.PetHealth:Refresh()
    print("Pet health: " .. (addon.PetHealth.sample
        and (math.floor(addon.PetHealth.sample.percent + 0.5) .. "%") or "unavailable")
        .. " | " .. (addon.PetHealth.status or "not checked"))
    print("/haf config to configure ammo, pet health and reactive glow settings.")
end
