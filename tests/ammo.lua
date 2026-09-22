local H = dofile('tests/helpers.lua')
local equal = H.equal
local passed, failed = 0, 0

local function test(name, run)
    local ok, message = pcall(run)
    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(message))
    end
end

local function setup(count, configure)
    local world = H.new()
    world.ammoCount = count
    world.ammoTexture = 1234
    world.ammoReads = 0
    world.warnings = {}
    world.env.C_PaperDollInfo = {
        GetInventorySlotInfo = function(name) equal(name, 'AmmoSlot'); return 0 end,
        AmmoNeeded = function() return true end,
    }
    world.env.GetInventoryItemTexture = function(unit, slot)
        equal(unit, 'player'); equal(slot, 0)
        return world.ammoTexture
    end
    world.env.GetInventoryItemCount = function(unit, slot)
        equal(unit, 'player'); equal(slot, 0)
        world.ammoReads = world.ammoReads + 1
        return world.ammoCount
    end
    world.env.C_Item = { GetItemCount = function() error('must use equipped ammo slot, not inventory totals') end }
    world.env.RaidWarningFrame = {}
    world.env.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0, b = 0 } }
    world.env.RaidNotice_AddMessage = function(frame, message)
        equal(frame, world.env.RaidWarningFrame)
        world.warnings[#world.warnings + 1] = message
    end
    world.env.SendChatMessage = function() error('must not broadcast a raid message') end
    if configure then configure(world) end

    local manifest = assert(io.open('HunterAssistForever/HunterAssistForever.toc'))
    for line in manifest:lines() do
        if line:match('%.lua$') then
            assert(loadfile('HunterAssistForever/' .. line, 't', world.env))('HunterAssistForever', world.addon)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')
    assert(world.addon.Ammo, 'ammo feature not implemented')
    equal(#world.warnings, 0, 'wait for world entry before warning')
    world:fire('PLAYER_ENTERING_WORLD')

    return world, world.addon
end

local function visible(addon, r, g, b)
    equal(addon.AmmoIcon.frame.shown, true)
    equal(addon.AmmoIcon.texture.color[1], r)
    equal(addon.AmmoIcon.texture.color[2], g)
    equal(addon.AmmoIcon.texture.color[3], b)
end

test('above 800 ammo hides the icon', function()
    local _, addon = setup(801)

    equal(addon.AmmoIcon.frame.shown, false)
end)

test('800 ammo displays green with count hidden by default', function()
    local _, addon = setup(800)

    visible(addon, 0.2, 1, 0.2)
    equal(addon.AmmoIcon.countText.shown, false)
end)

test('600 ammo displays yellow', function()
    local _, addon = setup(600)

    visible(addon, 1, 0.85, 0.1)
end)

test('400 ammo displays red', function()
    local world, addon = setup(400)

    visible(addon, 1, 0.2, 0.2)
    equal(#world.warnings, 0)
end)

test('exactly 200 does not warn until count drops below it', function()
    local world, addon = setup(200)
    visible(addon, 1, 0.2, 0.2)
    equal(#world.warnings, 0)
    world.ammoCount = 199

    world:fire('BAG_UPDATE_DELAYED')

    equal(#world.warnings, 1)
    assert(world.warnings[1]:find('199', 1, true))
end)

test('low-ammo warning is local and does not repeat on bag events', function()
    local world = setup(100)

    for _ = 1, 10 do world:fire('BAG_UPDATE_DELAYED') end

    equal(#world.warnings, 1)
end)

test('restocking rearms warning for the next low-ammo crossing', function()
    local world = setup(100)
    world.ammoCount = 500
    world:fire('BAG_UPDATE_DELAYED')
    world.ammoCount = 100

    world:fire('BAG_UPDATE_DELAYED')

    equal(#world.warnings, 2)
end)

test('loading stops checks and world entry permits one new warning', function()
    local world, addon = setup(100)
    world:fire('PLAYER_LEAVING_WORLD')
    local reads = world.ammoReads
    world:fire('BAG_UPDATE_DELAYED')
    equal(world.ammoReads, reads)
    equal(addon.AmmoIcon.frame.shown, false)

    world:fire('PLAYER_ENTERING_WORLD')
    world:fire('BAG_UPDATE_DELAYED')

    equal(#world.warnings, 2)
end)

test('count checkbox toggles the displayed count immediately', function()
    local _, addon = setup(725)
    local check = addon.SettingsPanel.controls.ammoShowCount
    equal(check:GetChecked(), false)
    check:SetChecked(true)

    check.scripts.OnClick(check)

    equal(addon.AmmoIcon.countText.shown, true)
    equal(addon.AmmoIcon.countText.text, '725')
end)

test('larger configurable thresholds update colors immediately', function()
    local _, addon = setup(1000)
    addon.Config.Set('ammoHideAbove', 2000)
    addon.Config.Set('ammoYellowAt', 1500)
    addon.Config.Set('ammoRedAt', 1100)
    addon.Config.Set('ammoWarnBelow', 500)

    visible(addon, 1, 0.2, 0.2)
end)

test('threshold controls save numeric input and reject overlapping ranges', function()
    local _, addon = setup(900)
    local edit = addon.SettingsPanel.controls.ammoHideAbove
    edit:SetText('1200')
    edit.scripts.OnEnterPressed(edit)
    equal(addon.Config.Get('ammoHideAbove'), 1200)
    visible(addon, 0.2, 1, 0.2)
    edit:SetText('300')

    edit.scripts.OnEnterPressed(edit)

    equal(addon.Config.Get('ammoHideAbove'), 1200)
    equal(edit:GetText(), '1200')
end)

test('native defaults reset larger thresholds atomically', function()
    local _, addon = setup(1000)
    addon.Config.Set('ammoHideAbove', 2000)
    addon.Config.Set('ammoYellowAt', 1500)
    addon.Config.Set('ammoRedAt', 1100)
    addon.Config.Set('ammoWarnBelow', 500)

    addon.SettingsPanel.canvas:OnDefault()

    equal(addon.Config.Get('ammoHideAbove'), 800)
    equal(addon.Config.Get('ammoYellowAt'), 600)
    equal(addon.Config.Get('ammoRedAt'), 400)
    equal(addon.Config.Get('ammoWarnBelow'), 200)
    equal(addon.AmmoIcon.frame.shown, false)
end)

test('invalid saved thresholds recover to a consistent set' , function()
    local _, addon = setup(600, function(w)
        w.env.HunterAssistForeverDB = { ammoHideAbove = 100, ammoYellowAt = 600,
            ammoRedAt = 400, ammoWarnBelow = 200, ammoShowCount = true }
    end)

    visible(addon, 1, 0.85, 0.1)
    equal(addon.Config.Get('ammoHideAbove'), 800)
    equal(addon.Config.Get('ammoShowCount'), true)
end)

test('restricted combat count hides indicator and does not invent a low warning', function()
    local world, addon = setup(500)
    world.combat = true
    world.ammoCount = world.secret

    world:fire('UNIT_INVENTORY_CHANGED', 'player')

    equal(addon.AmmoIcon.frame.shown, false)
    equal(#world.warnings, 0)
    world.ammoCount = 150
    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')
    equal(#world.warnings, 1)
end)

test('missing equipped texture means zero ammo despite empty-slot count of one', function()
    local world, addon = setup(1, function(w) w.ammoTexture = nil end)

    visible(addon, 1, 0.2, 0.2)
    equal(addon.Ammo.sample.count, 0)
    equal(#world.warnings, 1)
end)

test('ammo checks use events without polling', function()
    local world, addon = setup(500)
    local reads = world.ammoReads

    for _ = 1, 20 do world:tick(0.5) end

    equal(world.ammoReads, reads)
    world.ammoCount = 300
    world:fire('BAG_UPDATE_DELAYED')
    visible(addon, 1, 0.2, 0.2)
end)

test('disabled ammo feature hides the icon and suppresses warnings', function()
    local world, addon = setup(500)
    addon.Config.Set('ammoCheckEnabled', false)
    world.ammoCount = 100

    world:fire('BAG_UPDATE_DELAYED')

    equal(addon.AmmoIcon.frame.shown, false)
    equal(#world.warnings, 0)
end)

test('move mode previews hidden icon and saves its position', function()
    local _, addon = setup(1000)
    addon.SettingsPanel.moveAmmoButton.scripts.OnClick()
    local frame = addon.AmmoIcon.frame
    equal(frame.shown, true)
    equal(frame.mouseEnabled, true)
    frame.centerX, frame.centerY = 650, 320

    frame.scripts.OnDragStart(frame)
    frame.scripts.OnDragStop(frame)
    addon.SettingsPanel.canvas:Hide()

    equal(addon.Config.Get('ammoX'), 150)
    equal(addon.Config.Get('ammoY'), -180)
    equal(frame.mouseEnabled, false)
    equal(frame.shown, false)
end)

test('non-hunters do not create or query the ammo indicator', function()
    local world, addon = setup(100, function(w) w.class = 'MAGE' end)

    equal(addon.AmmoIcon.frame, nil)
    equal(world.ammoReads, 0)
    equal(#world.warnings, 0)
end)

test('upgrade keeps ammo and reactive preferences but removes range checks', function()
    local world, addon = setup(500, function(w)
        w.env.HunterAssistForeverDB = { deadzoneSaturation = true, reactiveGlowEnabled = true,
            reactiveBar = 5, reactiveButton = 7, ammoShowCount = true, ammoX = 25, ammoY = -100 }
    end)

    equal(#addon.features, 2)
    equal(addon.Range, nil)
    assert(addon.ReactiveGlow)
    equal(addon.Config.Get('reactiveBar'), 5)
    equal(addon.Config.Get('reactiveButton'), 7)
    equal(addon.Config.Get('ammoShowCount'), true)
    equal(addon.Config.Get('ammoX'), 25)
    equal(addon.SettingsPanel.controls.deadzoneSaturation, nil)
    assert(addon.SettingsPanel.controls.reactiveGlowEnabled)
    equal(#addon.SettingsPanel.sections, 2)
    for _, frame in ipairs(world.frames) do
        equal(frame.scripts.OnUpdate, nil)
        equal(frame.events.PLAYER_TARGET_CHANGED, nil)
    end

    world.env.SlashCmdList.HUNTERASSISTFOREVER('')
    assert(table.concat(world.messages, '\n'):find('Ammo: 500', 1, true))
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
