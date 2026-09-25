local _, addon = ...
local Warning = {}
addon.PetWarning = Warning
local lastSoundAt

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
