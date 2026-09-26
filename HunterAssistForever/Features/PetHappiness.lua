local _, addon = ...
local Happiness = { settingKey = "petHappinessEnabled", eventDriven = true, worldReady = false }
addon.PetHappiness = Happiness
addon:RegisterFeature(Happiness)

local function read(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

function Happiness:Initialize()
    addon.PetHappinessIcon:Initialize()
    local frame = CreateFrame("Frame")
    self.frame = frame
    for _, event in ipairs({ "UNIT_HAPPINESS", "UNIT_PET", "UNIT_FLAGS", "PET_UI_UPDATE",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_LEAVING_WORLD" then
            self.worldReady = false
            self:Stop()
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            self.worldReady = true
            self.warned = false
        elseif event == "UNIT_PET" then
            if not addon.Client.Readable(unit) or unit ~= "player" then
                return
            end
        elseif event == "UNIT_HAPPINESS" or event == "UNIT_FLAGS" then
            if not addon.Client.Readable(unit) or (unit ~= nil and unit ~= "pet") then
                return
            end
        end

        self:Refresh()
    end)
end

function Happiness:Refresh()
    if not self.worldReady or not addon.Config.Get(self.settingKey) then
        self:Stop()
        return
    end

    self.level = nil
    self.status = "no living pet or happiness unavailable"
    local exists = addon.Client.Boolean(read(UnitExists, "pet"))
    local dead = exists == true and addon.Client.Boolean(read(UnitIsDeadOrGhost, "pet"))
    if exists == true and dead == false then
        local level = read(C_PetInfo and C_PetInfo.GetPetHappiness)
        if addon.Client.Number(level) and (level == 1 or level == 2 or level == 3) then
            self.level = level
            self.status = level == 1 and "unhappy" or (level == 2 and "content" or "happy")
        end
    elseif exists == false or dead == true then
        self.warned = false
    end

    addon.PetHappinessIcon:Set(self.level, true)
    if self.level == 1 and not self.warned then
        addon.PetWarning.Show("Pet unhappy: feed your pet!")
        self.warned = true
    elseif self.level == 2 or self.level == 3 then
        self.warned = false
    end
end

function Happiness:ApplySettings()
    addon.PetHappinessIcon:ApplySettings()
    self:Refresh()
end

function Happiness:Stop()
    self.level = nil
    self.status = "disabled or loading"
    addon.PetHappinessIcon:Set(nil, false)
end
