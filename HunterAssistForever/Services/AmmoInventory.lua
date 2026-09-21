local _, addon = ...
local Inventory = {}
addon.AmmoInventory = Inventory

local function read(api, ...)
    if type(api) ~= "function" then
        return false, nil
    end

    local ok, value = pcall(api, ...)
    if not ok or not addon.Client.Readable(value) then
        return false, nil
    end

    return true, value
end

function Inventory.Read()
    if C_PaperDollInfo and C_PaperDollInfo.AmmoNeeded then
        local ok, needed = read(C_PaperDollInfo.AmmoNeeded)
        if not ok or needed ~= true then
            return nil, "ammunition not required or unavailable"
        end
    end

    local getSlot = C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo or GetInventorySlotInfo
    local ok, slot = read(getSlot, "AmmoSlot")
    if not ok or not addon.Client.Number(slot) or slot < 0 then
        return nil, "ammo slot unavailable"
    end

    local textureOK, texture = read(GetInventoryItemTexture, "player", slot)
    if not textureOK then
        return nil, "equipped ammo unavailable"
    end

    -- Empty inventory slots can report a count of one. The native character
    -- panel checks the texture first; an empty ammo slot means no equipped ammo.
    if texture == nil then
        return { count = 0 }, "no ammo equipped"
    end

    local countOK, count = read(GetInventoryItemCount, "player", slot)
    if not countOK or not addon.Client.Number(count) or count ~= count
        or count < 0 or count == math.huge or count ~= math.floor(count) then
        return nil, "equipped ammo count unavailable"
    end

    return { count = count, texture = texture }, "equipped ammo slot"
end
