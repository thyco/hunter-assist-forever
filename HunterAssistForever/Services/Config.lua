local _, addon = ...
local Config = {}
addon.Config = Config
local defaults = {
    deadzoneSaturation = true,
    ammoCheckEnabled = true,
    ammoShowCount = false,
    ammoHideAbove = 800,
    ammoYellowAt = 600,
    ammoRedAt = 400,
    ammoWarnBelow = 200,
    ammoX = 0,
    ammoY = -180,
}
local thresholds = { "ammoHideAbove", "ammoYellowAt", "ammoRedAt", "ammoWarnBelow" }

local function valid(key, value)
    if type(value) ~= type(defaults[key]) then
        return false
    end

    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return false
        end
        if key == "ammoX" or key == "ammoY" then
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
