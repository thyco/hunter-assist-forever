local _, addon = ...
local Ammo = { settingKey = "ammoCheckEnabled", eventDriven = true, warned = false, worldReady = false }
addon.Ammo = Ammo

local function warn(count)
    local message = "Low ammo: " .. count .. " remaining!"
    if RaidNotice_AddMessage and RaidWarningFrame then
        local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.2, b = 0.2 }
        local ok = pcall(RaidNotice_AddMessage, RaidWarningFrame, message, color)
        if ok then
            return
        end
    end

    print("Hunter Assist Forever: " .. message)
end

function Ammo:Initialize()
    addon.AmmoIcon:Initialize()
    local frame = CreateFrame("Frame")
    self.frame = frame
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "BAG_UPDATE_DELAYED",
        "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_INVENTORY_CHANGED"
            and (not addon.Client.Readable(unit) or unit ~= "player") then
            return
        end

        if event == "PLAYER_LEAVING_WORLD" then
            self.worldReady = false
            self:Stop()
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            self.worldReady = true
            self.warned = false
        end

        self:Refresh()
    end)
end

function Ammo:Level(count)
    if count > addon.Config.Get("ammoHideAbove") then
        return "hidden"
    elseif count > addon.Config.Get("ammoYellowAt") then
        return "green"
    elseif count > addon.Config.Get("ammoRedAt") then
        return "yellow"
    end

    return "red"
end

function Ammo:Refresh()
    if not addon.Config.Get(self.settingKey) or not self.worldReady then
        self:Stop()
        return
    end

    self.sample, self.status = addon.AmmoInventory.Read()
    local level = self.sample and self:Level(self.sample.count) or nil
    addon.AmmoIcon:Set(self.sample, level, true)
    if not self.sample then
        return
    end

    if self.sample.count >= addon.Config.Get("ammoWarnBelow") then
        self.warned = false
    elseif not self.warned then
        warn(self.sample.count)
        self.warned = true
    end
end

function Ammo:ApplySettings()
    addon.AmmoIcon:ApplySettings()
    self:Refresh()
end

function Ammo:Stop()
    self.sample = nil
    self.status = "disabled or loading"
    addon.AmmoIcon:Set(nil, nil, false)
end

addon:RegisterFeature(Ammo)
