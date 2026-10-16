local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

local function setting(key, label)
    local default = addon.Config.GetDefault(key)
    -- Numeric cutoffs reset together, since intermediate defaults may violate
    -- their ordering. Only independent booleans use native proxy settings.
    local proxyNumber = key == "mongooseBar" or key == "mongooseButton"
        or key == "counterattackBar" or key == "counterattackButton"
        or key == "petHealthThreshold" or key == "petFlashIntensity"
    if type(default) == "number" and not proxyNumber then
        return {
            GetValue = function() return addon.Config.Get(key) end,
            SetValue = function(_, value) addon.Config.Set(key, value) end,
        }
    end

    local valueType = type(default) == "boolean" and Settings.VarType.Boolean
        or (type(default) == "string" and Settings.VarType.String or Settings.VarType.Number)
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

local function color(section, key, label, y, tooltip)
    panel.controls[key] = addon.SettingsWidgets.Color(section, label, y, setting(key, label), tooltip)
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
    content:SetSize(580, 1660)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)

    widgets.Text(content, "Hunter Assist Forever", 8, -8, "GameFontNormalLarge")
    local ammo = widgets.Section(content, "Ammo check", "Equipped ammunition · local low-ammo warning", -48, 380)
    local mongoose = widgets.Section(content, "Mongoose Bite glow",
        "Combat only · dodge opportunity and own cooldown ready", -444, 210)
    local counterattack = widgets.Section(content, "Counterattack glow",
        "Combat only · parry opportunity and own cooldown ready", -670, 210)
    local pet = widgets.Section(content, "Pet settings", "Pet health and happiness alerts", -896, 544)
    local aspect = widgets.Section(content, "Aspect reminder", "Combat only · Cheetah or Pack active", -1456, 170)
    self.sections = { ammo, mongoose, counterattack, pet, aspect }

    checkbox(aspect, "aspectCheckEnabled", "Show active Cheetah / Pack icon", -62,
        "Show a larger icon during combat while Aspect of the Cheetah or Aspect of the Pack is active.")
    checkbox(aspect, "aspectGlowEnabled", "Glow around aspect icon", -96,
        "Use Blizzard's native proc glow around the aspect icon.")
    local moveAspect = CreateFrame("Button", nil, aspect, "UIPanelButtonTemplate")
    moveAspect:SetPoint("TOPLEFT", aspect, "TOPLEFT", 20, -128)
    moveAspect:SetSize(140, 28)
    moveAspect:SetText("Move icon")
    moveAspect:SetScript("OnClick", function()
        addon.AspectIcon:SetPreview(true)
    end)
    widgets.Tooltip(moveAspect, "Show the aspect icon and drag it. Close settings to save the position.")
    self.moveAspectButton = moveAspect

    checkbox(pet, "petHealthEnabled", "Enable low pet health icon", -62,
        "Show a red icon at or below the threshold, including out of combat. The warning and chime occur in combat only.")
    checkbox(pet, "petShowPercent", "Show health percentage", -96,
        "Display the pet's current health percentage on the red icon.")
    checkbox(pet, "petFlashEnabled", "Flash screen at low pet health", -130,
        "Pulse the screen edges in combat while your pet is at or below the health threshold.")
    color(pet, "petFlashColor", "Flash color", -168,
        "Choose the color of the low-health screen flash. Amber is the default.")
    local testFlash = CreateFrame("Button", nil, pet, "UIPanelButtonTemplate")
    testFlash:SetPoint("TOPLEFT", pet, "TOPLEFT", 420, -166)
    testFlash:SetSize(120, 28)
    testFlash:SetText("Test pulse")
    testFlash:SetScript("OnClick", function(self)
        local preview = addon.PetWarning.SetPreview(not addon.PetWarning.preview)
        self:SetText(preview and "Stop pulse" or "Test pulse")
    end)
    widgets.Tooltip(testFlash, "Preview the screen-edge pulse even with a healthy pet or outside combat. Click again to stop.")
    self.testFlashButton = testFlash

    widgets.Text(pet, "Happiness", 20, -348, "GameFontNormal")
    checkbox(pet, "petHappinessEnabled", "Enable pet happiness icon", -380,
        "Show yellow when content and red when unhappy, with one local warning and gentle chime. Hidden when happy.")
    local moveHappiness = CreateFrame("Button", nil, pet, "UIPanelButtonTemplate")
    moveHappiness:SetPoint("TOPLEFT", pet, "TOPLEFT", 20, -424)
    moveHappiness:SetSize(180, 28)
    moveHappiness:SetText("Move happiness icon")
    moveHappiness:SetScript("OnClick", function()
        addon.PetHappinessIcon:SetPreview(true)
    end)
    widgets.Tooltip(moveHappiness, "Show the happiness icon and drag it. Close settings to save the position.")
    self.moveHappinessButton = moveHappiness

    local petFeedback = widgets.Text(pet, "", 20, -490)
    petFeedback:SetTextColor(1, 0.4, 0.3)
    self.controls.petFlashIntensity = widgets.Number(pet, "Pulse intensity (%)", -214,
        setting("petFlashIntensity", "Pet pulse intensity"), function(value)
            return addon.Config.CanSet("petFlashIntensity", value)
        end, petFeedback, "Use a whole percentage from 10 to 300.")
    self.controls.petHealthThreshold = widgets.Number(pet, "Health threshold (%)", -252,
        setting("petHealthThreshold", "Pet health threshold"), function(value)
            return addon.Config.CanSet("petHealthThreshold", value)
        end, petFeedback, "Use a whole percentage between 1 and 100.")
    local movePet = CreateFrame("Button", nil, pet, "UIPanelButtonTemplate")
    movePet:SetPoint("TOPLEFT", pet, "TOPLEFT", 20, -300)
    movePet:SetSize(140, 28)
    movePet:SetText("Move icon")
    movePet:SetScript("OnClick", function()
        addon.PetHealthIcon:SetPreview(true)
    end)
    widgets.Tooltip(movePet, "Show a red preview and drag it. Close settings to finish; position is saved.")
    self.movePetButton = movePet

    checkbox(mongoose, "mongooseGlowEnabled", "Enable Mongoose Bite glow", -62,
        "Use Blizzard's native glow when Mongoose Bite is usable and off its own cooldown.")
    checkbox(counterattack, "counterattackGlowEnabled", "Enable Counterattack glow", -62,
        "Use Blizzard's native glow when Counterattack is learned, usable and off its own cooldown.")
    local bars = { { value = 0, label = "Not selected" } }
    for index, label in ipairs(addon.Buttons.Bars()) do
        bars[#bars + 1] = { value = index, label = label }
    end
    local buttons = {}
    for index = 1, 12 do
        buttons[#buttons + 1] = { value = index, label = "Button " .. index }
    end
    self.controls.mongooseBar = widgets.Dropdown(mongoose, "Action bar", -100,
        setting("mongooseBar", "Mongoose Bite action bar"), bars,
        "Choose a default action bar. No glow appears until a bar is selected.")
    self.controls.mongooseButton = widgets.Dropdown(mongoose, "Button", -136,
        setting("mongooseButton", "Mongoose Bite button"), buttons,
        "Uses a fixed button position, including when the bar changes pages. Choose the button containing your spell or macro.")
    self.controls.counterattackBar = widgets.Dropdown(counterattack, "Action bar", -100,
        setting("counterattackBar", "Counterattack action bar"), bars,
        "Choose a default action bar. No glow appears until a bar is selected.")
    self.controls.counterattackButton = widgets.Dropdown(counterattack, "Button", -136,
        setting("counterattackButton", "Counterattack button"), buttons,
        "Uses a fixed button position, including when the bar changes pages. Choose the button containing your spell or macro.")

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
        testFlash:SetText(addon.PetWarning.preview and "Stop pulse" or "Test pulse")
        self:Refresh()
    end)
    canvas:SetScript("OnHide", function()
        addon.PetWarning.SetPreview(false)
        testFlash:SetText("Test pulse")
        addon.AmmoIcon:SetPreview(false)
        addon.PetHealthIcon:SetPreview(false)
        addon.PetHappinessIcon:SetPreview(false)
        addon.AspectIcon:SetPreview(false)
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
