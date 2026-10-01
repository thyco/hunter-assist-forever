local _, addon = ...
local Warning = {}
addon.PetWarning = Warning
local lastSoundAt

function Warning.Initialize()
    if Warning.visualFrame then
        return
    end

    local frame = CreateFrame("Frame", "HunterAssistForeverPetHealthWarning", UIParent)
    frame:SetSize(640, 50)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER", frame, "CENTER")
    text:SetText("Pet health low!")
    text:SetTextColor(1, 0.2, 0.2)
    text:SetJustifyH("CENTER")

    frame:Hide()
    Warning.visualFrame = frame
    Warning.visualText = text

    local flash = CreateFrame("Frame", "HunterAssistForeverPetHealthFlash", UIParent)
    flash:SetAllPoints(UIParent)
    flash:SetFrameStrata("MEDIUM")
    flash:EnableMouse(false)

    local pulse = CreateFrame("Frame", nil, flash)
    pulse:SetAllPoints(flash)
    pulse:EnableMouse(false)
    local tint = pulse:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(pulse)
    tint:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    tint:SetBlendMode("ADD")
    tint:SetDesaturated(true)

    local animation = pulse:CreateAnimationGroup()
    animation:SetLooping("REPEAT")
    local brighten = animation:CreateAnimation("Alpha")
    brighten:SetOrder(1)
    brighten:SetFromAlpha(0.1)
    brighten:SetToAlpha(1)
    brighten:SetDuration(0.45)
    local dim = animation:CreateAnimation("Alpha")
    dim:SetOrder(2)
    dim:SetFromAlpha(1)
    dim:SetToAlpha(0.1)
    dim:SetDuration(0.55)

    flash:Hide()
    Warning.flashFrame = flash
    Warning.flashTint = tint
    Warning.flashAnimation = animation
    Warning.ApplyFlashColor()
end

function Warning.ApplyFlashColor()
    if not Warning.flashTint then
        return
    end

    local color = addon.Config.Get("petFlashColor")
    if Warning.flashColor == color then
        return
    end

    local red, green, blue = addon.Config.GetColor("petFlashColor")
    Warning.flashTint:SetVertexColor(red, green, blue, 0.24)
    Warning.flashColor = color
end

function Warning.SetLowHealthVisual(alpha, available)
    local frame = Warning.visualFrame
    if not frame then
        return
    end

    if available then
        frame:Show()
        frame:SetAlpha(alpha)
    else
        frame:Hide()
        frame:SetAlpha(1)
    end
end

function Warning.SetLowHealthFlash(low, alpha, available)
    local frame = Warning.flashFrame
    if not frame then
        return
    end

    if not addon.Config.Get("petFlashEnabled") or (not low and not available) then
        if Warning.flashAnimation:IsPlaying() then
            Warning.flashAnimation:Stop()
        end
        frame:Hide()
        frame:SetAlpha(1)
        return
    end

    frame:SetAlpha(available and alpha or 1)
    frame:Show()
    if not Warning.flashAnimation:IsPlaying() then
        Warning.flashAnimation:Play()
    end
end

function Warning.Show(message)
    local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.2, b = 0.2 }
    local shown = false
    if RaidNotice_AddMessage and RaidWarningFrame then
        shown = pcall(RaidNotice_AddMessage, RaidWarningFrame, message, color)
    end
    if not shown then
        print("Hunter Assist Forever: " .. message)
    end

    local now
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)
        if ok and addon.Client.Number(value) then
            now = value
        end
    end
    if now and lastSoundAt and now - lastSoundAt < 1 then
        return
    end

    local sound = SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081
    if type(PlaySound) == "function" and addon.Client.Number(sound) then
        local ok = pcall(PlaySound, sound)
        if ok then
            lastSoundAt = now
        end
    end
end
