local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

function panel:Refresh()
    for _, control in pairs(self.controls) do
        control.refresh()
    end
end

function panel:Initialize()
    if self.category then
        return
    end

    local widgets = addon.SettingsWidgets
    local canvas = CreateFrame("Frame")
    self.canvas = canvas
    canvas:Hide()
    self.category = Settings.RegisterCanvasLayoutCategory(canvas, "Hunter Assist Forever")

    widgets.Text(canvas, "Hunter Assist Forever", 8, -8, "GameFontNormalLarge")
    local section = widgets.Section(canvas, "Range checks", "Ranged abilities on all default action bars", -48, 112)
    self.sections = { section }

    local setting = Settings.RegisterProxySetting(
        self.category, "HunterAssistForever_DeadzoneSaturation", Settings.VarType.Boolean,
        "Deadzone saturation", addon.Config.GetDefault("deadzoneSaturation"),
        function()
            return addon.Config.Get("deadzoneSaturation")
        end,
        function(value)
            addon.Config.Set("deadzoneSaturation", value)
        end
    )
    self.controls.deadzoneSaturation = widgets.Checkbox(section, "Deadzone saturation", -62, setting,
        "Tint ranged ability icons desaturated red when your living attackable target is confirmed too close. With no target selected, checks your mouseover. Applies to hunters only.")

    canvas:SetScript("OnShow", function()
        self:Refresh()
    end)
    addon.Config.Subscribe(function()
        self:Refresh()
    end)
    self:Refresh()
    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
