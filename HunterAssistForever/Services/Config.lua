local _, addon = ...
local Config = {}
addon.Config = Config
local defaults = {
    ammoCheckEnabled = true,
    ammoShowCount = false,
    ammoHideAbove = 800,
    ammoYellowAt = 600,
    ammoRedAt = 400,
    ammoWarnBelow = 200,
    reactiveGlowEnabled = true,
    reactiveBar = 3,
    reactiveButton = 3,
    aspectCheckEnabled = true,
    aspectGlowEnabled = true,
    aspectX = 0,
    aspectY = -270,
    petHappinessEnabled = true,
    petHappinessX = 100,
    petHappinessY = -180,
    petHealthEnabled = true,
    petFlashEnabled = true,
    petFlashColor = "ffffa60d",
    petHealthThreshold = 35,
    petShowPercent = false,
    petX = 50,
    petY = -180,
    ammoX = 0,
    ammoY = -180,
}
local thresholds = { "ammoHideAbove", "ammoYellowAt", "ammoRedAt", "ammoWarnBelow" }

local function valid(key, value)
    if type(value) ~= type(defaults[key]) then
        return false
    end

    if key == "petFlashColor" then
        return #value == 8 and value:match("^%x+$") ~= nil
    end

    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return false
        end
        if key == "reactiveBar" then
            return value >= 0 and value <= 8 and value == math.floor(value)
        elseif key == "reactiveButton" then
            return value >= 1 and value <= 12 and value == math.floor(value)
        end
        if key == "petHealthThreshold" then
            return value >= 1 and value <= 100 and value == math.floor(value)
        end
        if key == "ammoX" or key == "ammoY" or key == "petX" or key == "petY" or key == "petHappinessX" or key == "petHappinessY" or key == "aspectX" or key == "aspectY" then
            return value >= -10000 and value <= 10000
        end
        return value >= 1 and value <= 999999 and value == math.floor(value)
    end

    return true
end

local function ordered(get)
    return get("ammoHideAbove") > get("ammoYellowAt")
        and get("ammoYellowAt") > get("ammoRedAt")
        and get("ammoRedAt") > get("ammoWarnBelow")
end
local values
local listeners = {}

function Config.Initialize()
    if type(HunterAssistForeverDB) ~= "table" then
        HunterAssistForeverDB = {}
    end

    values = HunterAssistForeverDB
    for key, default in pairs(defaults) do
        if not valid(key, values[key]) then
            values[key] = default
        elseif key == "petFlashColor" then
            values[key] = "ff" .. values[key]:sub(3):lower()
        end
    end

    if not ordered(function(key) return values[key] end) then
        for _, key in ipairs(thresholds) do
            values[key] = defaults[key]
        end
    end
end

function Config.GetDefault(key)
    return defaults[key]
end

function Config.Get(key)
    if values and values[key] ~= nil then
        return values[key]
    end

    return defaults[key]
end

function Config.GetColor(key)
    local hex = Config.Get(key)
    return tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        tonumber(hex:sub(7, 8), 16) / 255
end

function Config.CanSet(key, value)
    return defaults[key] ~= nil and valid(key, value) and ordered(function(candidate)
        if candidate == key then
            return value
        end
        return Config.Get(candidate)
    end)
end

function Config.Set(key, value)
    assert(defaults[key] ~= nil, "Unknown configuration key: " .. key)
    assert(Config.CanSet(key, value), "Invalid configuration value: " .. key)
    if not values then
        Config.Initialize()
    end

    if key == "petFlashColor" then
        value = "ff" .. value:sub(3):lower()
    end

    if values[key] == value then
        return
    end

    values[key] = value
    for _, listener in ipairs(listeners) do
        listener(key, value)
    end
end

function Config.ResetAmmoThresholds()
    for _, key in ipairs(thresholds) do
        values[key] = defaults[key]
    end

    for _, listener in ipairs(listeners) do
        listener()
    end
end

function Config.Subscribe(listener)
    listeners[#listeners + 1] = listener
end
