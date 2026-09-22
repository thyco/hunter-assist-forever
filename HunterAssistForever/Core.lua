local addonName, addon = ...
addon.name = addonName
addon.version = "0.5.1"
addon.features = {}
addon.started = false
addon.running = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:Start()
    local _, class = UnitClass("player")
    if not self.Client.Readable(class) or class ~= "HUNTER" or self.started then
        return
    end

    self.started = true
    for _, feature in ipairs(self.features) do
        if feature.Initialize then
            feature:Initialize()
        end
    end

    self.Config.Subscribe(function()
        self:ApplySettings()
    end)
    self:ApplySettings()
end

function addon:IsFeatureEnabled(feature)
    return not feature.settingKey or self.Config.Get(feature.settingKey) == true
end

function addon:ApplySettings()
    local running = false
    for _, feature in ipairs(self.features) do
        if self:IsFeatureEnabled(feature) then
            running = true
            feature:ApplySettings()
        else
            feature:Stop()
        end
    end

    self.running = running
end
