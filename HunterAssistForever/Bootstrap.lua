local _, addon = ...
local frame = CreateFrame("Frame")
local elapsedSinceUpdate, elapsedSinceDiscovery = 0, 0
local discoveryDirty, catalogDirty = false, false
local discoveryEvents = {
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_MACROS",
    "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID",
}

local function update(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    elapsedSinceDiscovery = elapsedSinceDiscovery + elapsed
    if elapsedSinceUpdate < 0.1 then
        return
    end

    local discover = discoveryDirty or elapsedSinceDiscovery >= 0.5
    elapsedSinceUpdate = 0
    if discover then
        elapsedSinceDiscovery = 0
    end

    addon:Refresh(discover, catalogDirty)
    discoveryDirty, catalogDirty = false, false
end

function addon:SetPolling(enabled)
    elapsedSinceUpdate, elapsedSinceDiscovery = 0, 0
    discoveryDirty, catalogDirty = false, false
    frame:SetScript("OnUpdate", enabled and update or nil)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        addon.Config.Initialize()
        addon.SettingsPanel:Initialize()
        addon:Start()
        if not addon.started then
            self:UnregisterAllEvents()
            return
        end

        for _, name in ipairs(discoveryEvents) do
            self:RegisterEvent(name)
        end
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_TALENT_UPDATE")
        return
    end

    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
        addon:Refresh(false, catalogDirty)
        catalogDirty = false
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        addon:Refresh(true, true)
        discoveryDirty, catalogDirty = false, false
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        catalogDirty = true
    else
        discoveryDirty = true
    end
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
        print("Hunter range checks are inactive on this character. /haf config to configure.")
        return
    end

    addon:Refresh(true, true)
    print("Deadzone saturation: " .. (addon.Config.Get("deadzoneSaturation") and "enabled" or "disabled")
        .. " | /haf config to configure")
    print("Close-range probes: " .. #addon.Range.probes .. " | default buttons: " .. #addon.Deadzone.buttons
        .. " | confirmed too-close buttons: " .. addon.Deadzone.colored)
    if addon.running then
        for _, line in ipairs(addon.Range:DescribeChecks()) do
            print(line)
        end
    end
    print("Only confirmed proximity is colored. Missing or restricted range evidence leaves icons unchanged.")
end
