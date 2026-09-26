local _, addon = ...
local Pet = { settingKey = "petHealthEnabled", eventDriven = true, worldReady = false }
addon.PetHealth = Pet
addon:RegisterFeature(Pet)

local function read(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

local function positive(value)
    return addon.Client.Number(value) and value == value and value > 0 and value < math.huge
end

function Pet:Initialize()
    addon.PetHealthIcon:Initialize()
    local frame = CreateFrame("Frame")
    self.frame = frame
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS", "UNIT_PET",
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
        elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" then
            if not addon.Client.Readable(unit) or unit ~= "pet" then
                return
            end
        end

        self:Refresh()
    end)
end

function Pet:Refresh()
    if not self.worldReady or not addon.Config.Get(self.settingKey) then
        self:Stop()
        return
    end

    self.sample = nil
    self.status = "no living pet or health unavailable"
    local alpha, alphaAvailable
    local exists = addon.Client.Boolean(read(UnitExists, "pet"))
    local dead = exists == true and addon.Client.Boolean(read(UnitIsDeadOrGhost, "pet"))
    if exists == true and dead == false then
        local health = read(UnitHealth, "pet")
        local maximum = read(UnitHealthMax, "pet")
        if positive(health) and positive(maximum) and health <= maximum then
            self.sample = { health = health, maximum = maximum, percent = (health / maximum) * 100 }
            self.status = "pet health"
        else
            alpha, alphaAvailable = addon.PetHealthIcon:RestrictedAlpha()
            if alphaAvailable then
                self.status = "pet health visual only (restricted value)"
            end
        end
    elseif exists == false or dead == true then
        self.warned = false
    end

    addon.PetHealthIcon:Set(self.sample, true, alpha, alphaAvailable)
    if self.sample then
        local low = self.sample.health * 100 <= self.sample.maximum * addon.Config.Get("petHealthThreshold")
        if low and not self.warned then
            addon.PetWarning.Show("Pet health low!")
            self.warned = true
        elseif not low then
            self.warned = false
        end
    end
end

function Pet:ApplySettings()
    addon.PetHealthIcon:ApplySettings()
    self:Refresh()
end

function Pet:Stop()
    self.sample = nil
    self.status = "disabled or loading"
    addon.PetHealthIcon:Set(nil, false)
end
