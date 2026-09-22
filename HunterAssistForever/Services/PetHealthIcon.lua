local _, addon = ...
local Icon = { preview = false, enabled = false }
addon.PetHealthIcon = Icon
function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "HunterAssistForeverPetHealthIcon", UIParent)
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
            addon.Config.Set("petX", x - centerX)
            addon.Config.Set("petY", y - centerY)
        end
    end)

    self:ApplySettings()
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", addon.Config.Get("petX"), addon.Config.Get("petY"))
    self:Render()
end

function Icon:Set(sample, enabled)
    self.sample, self.enabled = sample, enabled
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

    local visible = self.preview or (self.enabled and self.sample and self.sample.health * 100 <= self.sample.maximum * addon.Config.Get("petHealthThreshold"))
    self.frame:SetShown(visible)
    if not visible then
        return
    end

    self.texture:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
    self.texture:SetVertexColor(1, 0.2, 0.2)
    local showCount = addon.Config.Get("petShowPercent") and self.sample ~= nil
    self.countText:SetShown(showCount)
    if showCount then
        self.countText:SetText(tostring(math.floor(self.sample.percent + 0.5)) .. "%")
    end
end
