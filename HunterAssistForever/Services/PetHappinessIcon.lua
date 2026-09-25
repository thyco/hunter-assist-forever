local _, addon = ...
local Icon = { preview = false, enabled = false }
addon.PetHappinessIcon = Icon
function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "HunterAssistForeverPetHappinessIcon", UIParent)
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
            addon.Config.Set("petHappinessX", x - centerX)
            addon.Config.Set("petHappinessY", y - centerY)
        end
    end)

    self:ApplySettings()
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", addon.Config.Get("petHappinessX"), addon.Config.Get("petHappinessY"))
    self:Render()
end

function Icon:Set(happiness, enabled)
    self.happiness, self.enabled = happiness, enabled
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

    local happiness = self.happiness
    local visible = self.preview or (self.enabled and (happiness == 1 or happiness == 2))
    self.frame:SetShown(visible)
    if not visible then
        return
    end

    self.texture:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
    if happiness == 2 then
        self.texture:SetTexCoord(0.1875, 0.375, 0, 0.359375)
        self.texture:SetVertexColor(1, 0.85, 0.1)
    else
        self.texture:SetTexCoord(0.375, 0.5625, 0, 0.359375)
        self.texture:SetVertexColor(1, 0.2, 0.2)
    end
end
