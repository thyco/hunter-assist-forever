local addonName, addon = ...
addon.name = addonName
addon.version = "0.1.0"
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
        else
            feature:Stop()
        end
    end

    self.running = running
    self:SetPolling(running)
    self:Refresh(true, true)
end

function addon:Refresh(discover, rebuild)
    if not self.started or not self.running then
        return
    end

    for _, feature in ipairs(self.features) do
        if self:IsFeatureEnabled(feature) then
            feature:Refresh(discover, rebuild)
        end
    end
end
