local _, addon = ...
local Icon = { preview = false, enabled = false }
local glowOwner = "aspect-warning"
local cheetahSpellID = 5118
addon.AspectIcon = Icon

local function spellTexture(spellID)
    if not C_Spell then
        return nil
    end

    if type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and addon.Client.Readable(texture) and texture then
            return texture
        end
    end

    if type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and addon.Client.Readable(info) and type(info) == "table"
            and addon.Client.Readable(info.iconID) then
            return info.iconID
        end
    end
end

function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "HunterAssistForeverAspectIcon", UIParent)
    self.frame = frame
    frame:SetSize(64, 64)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    self.texture = frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(frame)
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
            addon.Config.Set("aspectX", x - centerX)
            addon.Config.Set("aspectY", y - centerY)
        end
    end)

    addon.Glow.Prepare(frame)
    self:ApplySettings()
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", addon.Config.Get("aspectX"), addon.Config.Get("aspectY"))
    addon.Glow.Prepare(self.frame)
    self:Render()
end

function Icon:Set(spellID, enabled)
    self.spellID, self.enabled = spellID, enabled
    self:Render()
end

function Icon:SetPreview(enabled)
    self.preview = enabled
    if not self.frame then
        return
    end

    if not enabled then
        self.frame:StopMovingOrSizing()
    end
    self.frame:SetFrameStrata(enabled and "TOOLTIP" or "MEDIUM")
    self.frame:EnableMouse(enabled)
    self:Render()
end

function Icon:Render()
    if not self.frame then
        return
    end

    local visible = self.preview or (self.enabled and self.spellID ~= nil)
    self.frame:SetShown(visible)
    if visible then
        self.texture:SetTexture(spellTexture(self.spellID or cheetahSpellID)
            or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    addon.Glow.Set(self.frame, glowOwner, visible and addon.Config.Get("aspectGlowEnabled"))
end
