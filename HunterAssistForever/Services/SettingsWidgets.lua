local _, addon = ...
local Widgets = {}
addon.SettingsWidgets = Widgets

function Widgets.Text(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    return label
end

function Widgets.Tooltip(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Widgets.Section(parent, title, description, y, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    section:SetHeight(height)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    section:SetBackdropColor(0.035, 0.035, 0.045, 0.8)
    section:SetBackdropBorderColor(0.35, 0.31, 0.22, 1)

    Widgets.Text(section, title, 16, -14, "GameFontNormalLarge")
    local subtitle = Widgets.Text(section, description, 16, -38)
    subtitle:SetPoint("TOPRIGHT", section, "TOPRIGHT", -16, -38)
    subtitle:SetTextColor(0.7, 0.7, 0.7)

    return section
end

function Widgets.Checkbox(parent, label, y, setting, tooltip)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    check.Text:SetText(label)
    check.Text:SetFontObject("GameFontHighlight")
    check:SetScript("OnClick", function(self)
        setting:SetValue(not not self:GetChecked())
    end)
    check.refresh = function()
        check:SetChecked(setting:GetValue())
    end
    Widgets.Tooltip(check, tooltip)

    return check
end

function Widgets.Number(parent, label, y, setting, validate, feedback)
    Widgets.Text(parent, label, 20, y - 7, "GameFontHighlight")
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", 280, y)
    edit:SetSize(110, 28)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(6)
    edit.refresh = function()
        edit:SetText(tostring(setting:GetValue()))
    end

    local function commit(self)
        local value = tonumber(self:GetText())
        if value == setting:GetValue() then
            return
        end

        if validate(value) then
            setting:SetValue(value)
            feedback:SetText("")
        else
            feedback:SetText("Keep: hide > yellow > red > warning. Use positive whole numbers.")
        end
        self.refresh()
    end
    edit:SetScript("OnEnterPressed", function(self)
        commit(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", commit)
    edit:SetScript("OnEscapePressed", function(self)
        self.refresh()
        self:ClearFocus()
    end)

    return edit
end

local dropdownSerial = 0

function Widgets.Dropdown(parent, label, y, setting, options, tooltip)
    Widgets.Text(parent, label, 20, y - 7, "GameFontHighlight")
    dropdownSerial = dropdownSerial + 1
    local dropdown = CreateFrame("Frame", "HunterAssistForeverDropdown" .. dropdownSerial,
        parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, y)
    UIDropDownMenu_SetWidth(dropdown, 210)
    dropdown.options = options
    UIDropDownMenu_Initialize(dropdown, function()
        for _, option in ipairs(options) do
            local value, text = option.value, option.label
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.value = value
            info.checked = setting:GetValue() == value
            info.tooltipTitle = label
            info.tooltipText = tooltip
            info.tooltipOnButton = true
            info.func = function()
                setting:SetValue(value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    dropdown.refresh = function()
        local value = setting:GetValue()
        -- SetSelectedValue also refreshes the globally shared popup, which
        -- may contain another dropdown's options (e.g. seconds instead of bars).
        -- Store this frame's selection without touching that popup; its own
        -- initializer rebuilds checkmarks whenever the menu is opened.
        dropdown.selectedName = nil
        dropdown.selectedID = nil
        dropdown.selectedValue = value

        for _, option in ipairs(options) do
            if option.value == value then
                UIDropDownMenu_SetText(dropdown, option.label)
                break
            end
        end
    end
    return dropdown
end
