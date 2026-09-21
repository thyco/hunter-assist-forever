local _, addon = ...
local Icon = { preview = false, enabled = false }
addon.AmmoIcon = Icon
local colors = {
    green = { 0.2, 1, 0.2 },
    yellow = { 1, 0.85, 0.1 },
    red = { 1, 0.2, 0.2 },
}

function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "HunterAssistForeverAmmoIcon", UIParent)
    self.frame = frame
    frame:SetSize(40, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    self.texture = frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(frame)
    self.texture:SetDesaturated(true)
    self.countText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    self.countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    frame:SetScript("OnDragStart", function(self)
        if Icon.preview then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if addon.Client.Number(x) and addon.Client.Number(y)
            and addon.Client.Number(centerX) and addon.Client.Number(centerY) then
            addon.Config.Set("ammoX", x - centerX)
            addon.Config.Set("ammoY", y - centerY)
        end
    end)

    self:ApplySettings()
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", addon.Config.Get("ammoX"), addon.Config.Get("ammoY"))
    self:Render()
end

function Icon:Set(sample, level, enabled)
    self.sample, self.level, self.enabled = sample, level, enabled
    self:Render()
end

function Icon:SetPreview(enabled)
    self.preview = enabled
    if self.frame then
        if not enabled then
            self.frame:StopMovingOrSizing()
        end
        self.frame:SetFrameStrata(enabled and "TOOLTIP" or "MEDIUM")
        self.frame:EnableMouse(enabled)
        self:Render()
    end
end

function Icon:Render()
    if not self.frame then
        return
    end

    local visible = self.preview or (self.enabled and colors[self.level] ~= nil)
    self.frame:SetShown(visible)
    if not visible then
        return
    end

    local color = colors[self.level] or colors.green
    self.texture:SetTexture(self.sample and self.sample.texture or "Interface\\Icons\\INV_Ammo_Arrow_02")
    self.texture:SetVertexColor(color[1], color[2], color[3])
    local showCount = addon.Config.Get("ammoShowCount") and self.sample ~= nil
    self.countText:SetShown(showCount)
    if showCount then
        self.countText:SetText(tostring(self.sample.count))
    end
end
