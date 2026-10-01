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
