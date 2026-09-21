local _, addon = ...
local feature = { settingKey = "deadzoneSaturation", buttons = {}, colored = 0 }
addon.Deadzone = feature

function feature:Refresh(discover, rebuild)
    if rebuild then
        addon.Range:Rebuild()
    end

    if discover then
        self.buttons = addon.Buttons.All()
        for _, button in ipairs(self.buttons) do
            addon.IconTint.Prepare(button)
        end
    end

    addon.Range:BeginUpdate()
    self.colored = 0
    for _, button in ipairs(self.buttons) do
        local close = false
        if addon.Range.hasTarget and addon.Client.Boolean(button:IsVisible()) == true then
            -- Live slots handle paging; displayed spell IDs handle macro changes.
            local id = addon.Client.ActionSpell(button.action)
            close = addon.Range:IsTooClose(id)
        end

        addon.IconTint.Set(button, close)
        if close then
            self.colored = self.colored + 1
        end
    end
end

function feature:Stop()
    addon.IconTint.Clear()
    self.colored = 0
end

addon:RegisterFeature(feature)
