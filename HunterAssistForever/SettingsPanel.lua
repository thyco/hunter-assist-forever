local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

local function setting(key, label)
    local default = addon.Config.GetDefault(key)
    -- Numeric cutoffs reset together, since intermediate defaults may violate
    -- their ordering. Only independent booleans use native proxy settings.
    if type(default) == "number" and key ~= "reactiveBar" and key ~= "reactiveButton" then
        return {
            GetValue = function() return addon.Config.Get(key) end,
            SetValue = function(_, value) addon.Config.Set(key, value) end,
        }
    end

    local valueType = type(default) == "boolean" and Settings.VarType.Boolean or Settings.VarType.Number
    return Settings.RegisterProxySetting(panel.category, "HunterAssistForever_" .. key, valueType,
        label, default, function()
            return addon.Config.Get(key)
        end, function(value)
            addon.Config.Set(key, value)
        end)
end

local function checkbox(section, key, label, y, tooltip)
    panel.controls[key] = addon.SettingsWidgets.Checkbox(section, label, y, setting(key, label), tooltip)
end

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
    canvas.OnDefault = function()
        addon.Config.ResetAmmoThresholds()
    end
    canvas:Hide()
    self.category = Settings.RegisterCanvasLayoutCategory(canvas, "Hunter Assist Forever")

    local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(580, 804)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)

    widgets.Text(content, "Hunter Assist Forever", 8, -8, "GameFontNormalLarge")
    local range = widgets.Section(content, "Range checks", "Ranged abilities on all default action bars", -48, 112)
    local ammo = widgets.Section(content, "Ammo check", "Equipped ammunition · local low-ammo warning", -176, 380)
    local reactive = widgets.Section(content, "Mongoose Bite / Counterattack",
        "Combat only · either learned spell usable and off cooldown", -572, 210)
    self.sections = { range, ammo, reactive }

    checkbox(reactive, "reactiveGlowEnabled", "Enable reactive ability glow", -62,
        "Use Blizzard's native glow when Mongoose Bite or Counterattack is usable and off its own cooldown.")
    local bars = { { value = 0, label = "Not selected" } }
    for index, label in ipairs(addon.Buttons.Bars()) do
        bars[#bars + 1] = { value = index, label = label }
    end
    local buttons = {}
    for index = 1, 12 do
        buttons[#buttons + 1] = { value = index, label = "Button " .. index }
    end
    self.controls.reactiveBar = widgets.Dropdown(reactive, "Action bar", -100,
        setting("reactiveBar", "Reactive ability action bar"), bars,
        "Choose a default action bar. No glow appears until a bar is selected.")
    self.controls.reactiveButton = widgets.Dropdown(reactive, "Button", -136,
        setting("reactiveButton", "Reactive ability button"), buttons,
        "Uses a fixed button position, including when the bar changes pages. Choose the button containing your spell or macro.")

    checkbox(range, "deadzoneSaturation", "Deadzone saturation", -62,
        "Tint ranged ability icons when your living attackable target is confirmed too close. With no target selected, checks your mouseover.")
    checkbox(ammo, "ammoCheckEnabled", "Enable ammo check", -62,
        "Show equipped ammo status and warn below the configured threshold. Applies to hunters only.")
    checkbox(ammo, "ammoShowCount", "Show count", -96,
        "Show the equipped ammunition count on the icon. Hidden by default.")

    local feedback = widgets.Text(ammo, "", 20, -350)
    feedback:SetPoint("TOPRIGHT", ammo, "TOPRIGHT", -16, -350)
    feedback:SetTextColor(1, 0.4, 0.3)
    for _, field in ipairs({
        { "ammoHideAbove", "Hide above", -142 },
        { "ammoYellowAt", "Yellow at or below", -180 },
        { "ammoRedAt", "Red at or below", -218 },
        { "ammoWarnBelow", "Warn below", -256 },
    }) do
        local key, label, y = field[1], field[2], field[3]
        self.controls[key] = widgets.Number(ammo, label, y, setting(key, label), function(value)
            return addon.Config.CanSet(key, value)
        end, feedback)
    end

    local move = CreateFrame("Button", nil, ammo, "UIPanelButtonTemplate")
    move:SetPoint("TOPLEFT", ammo, "TOPLEFT", 20, -306)
    move:SetSize(140, 28)
    move:SetText("Move icon")
    move:SetScript("OnClick", function()
        addon.AmmoIcon:SetPreview(true)
    end)
    widgets.Tooltip(move, "Show the icon even above the cutoff, then drag it. Close settings to finish; position is saved.")
    self.moveAmmoButton = move

    canvas:SetScript("OnShow", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        self:Refresh()
    end)
    canvas:SetScript("OnHide", function()
        addon.AmmoIcon:SetPreview(false)
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
