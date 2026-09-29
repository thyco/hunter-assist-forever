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

local function setup(configure)
    local world = H.new()
    world.auras = {}
    world.auraReads = 0
    world.env.UnitAffectingCombat = function(unit)
        equal(unit, 'player')
        return world.combat
    end
    world.env.C_UnitAuras = {
        GetPlayerAuraBySpellID = function(spellID)
            world.auraReads = world.auraReads + 1
            return world.auras[spellID]
        end,
    }
    world.env.C_Spell.GetSpellTexture = function(spellID)
        return ({ [5118] = 511801, [13159] = 1315901 })[spellID]
    end

    if configure then
        configure(world)
    end

    for line in io.lines('HunterAssistForever/HunterAssistForever.toc') do
        if line:match('%.lua$') then
            assert(loadfile('HunterAssistForever/' .. line, 't', world.env))('HunterAssistForever', world.addon)
        end
    end
    world:fire('PLAYER_LOGIN')
    world:fire('PLAYER_ENTERING_WORLD')

    assert(world.addon.AspectIcon, 'aspect icon missing')
    return world, world.addon
end

local function glowing(world, icon)
    for frame, active in pairs(world.glowActive) do
        if frame.parent == icon and active then
            return true
        end
    end

    return false
end

test('active Cheetah stays hidden out of combat', function()
    local world, addon = setup(function(w)
        w.auras[5118] = { spellId = 5118 }
    end)

    equal(addon.AspectIcon.frame.shown, false)
    equal(glowing(world, addon.AspectIcon.frame), false)
    equal(addon.Config.Get('aspectCheckEnabled'), true)
    equal(addon.Config.Get('aspectGlowEnabled'), true)
end)

test('Cheetah in combat shows its larger icon with native glow', function()
    local world, addon = setup(function(w)
        w.auras[5118] = { spellId = 5118 }
    end)
    world.combat = true

    world:fire('PLAYER_REGEN_DISABLED')

    equal(addon.AspectIcon.frame.shown, true)
    equal(addon.AspectIcon.frame.width, 64)
    equal(addon.AspectIcon.frame.height, 64)
    equal(addon.AspectIcon.texture.texture, 511801)
    equal(glowing(world, addon.AspectIcon.frame), true)
    equal(world.glowOptions.color, nil)
end)

test('Pack appears when gained during combat and hides when removed', function()
    local world, addon = setup()
    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')
    equal(addon.AspectIcon.frame.shown, false)

    world.auras[13159] = { spellId = 13159 }
    world:fire('UNIT_AURA', 'player')
    equal(addon.AspectIcon.frame.shown, true)
    equal(addon.AspectIcon.texture.texture, 1315901)

    world.auras[13159] = nil
    world:fire('UNIT_AURA', 'player')
    equal(addon.AspectIcon.frame.shown, false)
    equal(glowing(world, addon.AspectIcon.frame), false)
end)

test('unrelated aura events do not query player aspects', function()
    local world = setup()
    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')
    local reads = world.auraReads

    world:fire('UNIT_AURA', 'target')
    world:tick(1)

    equal(world.auraReads, reads)
end)

test('glow setting acts independently and updates immediately', function()
    local world, addon = setup(function(w)
        w.auras[5118] = { spellId = 5118 }
    end)
    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')

    local glowSetting = addon.SettingsPanel.controls.aspectGlowEnabled
    glowSetting:SetChecked(false)
    glowSetting.scripts.OnClick(glowSetting)
    equal(addon.Config.Get('aspectGlowEnabled'), false)
    equal(addon.AspectIcon.frame.shown, true)
    equal(glowing(world, addon.AspectIcon.frame), false)

    glowSetting:SetChecked(true)
    glowSetting.scripts.OnClick(glowSetting)
    equal(glowing(world, addon.AspectIcon.frame), true)

    local iconSetting = addon.SettingsPanel.controls.aspectCheckEnabled
    iconSetting:SetChecked(false)
    iconSetting.scripts.OnClick(iconSetting)
    equal(addon.Config.Get('aspectCheckEnabled'), false)
    equal(addon.AspectIcon.frame.shown, false)
    equal(glowing(world, addon.AspectIcon.frame), false)
end)

test('leaving combat or the world clears the icon and glow', function()
    local world, addon = setup(function(w)
        w.auras[5118] = { spellId = 5118 }
    end)
    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')
    equal(addon.AspectIcon.frame.shown, false)
    equal(glowing(world, addon.AspectIcon.frame), false)

    world.combat = true
    world:fire('PLAYER_ENTERING_WORLD')
    equal(addon.AspectIcon.frame.shown, true)
    world:fire('PLAYER_LEAVING_WORLD')
    equal(addon.AspectIcon.frame.shown, false)
    equal(glowing(world, addon.AspectIcon.frame), false)
end)

test('restricted aura data never causes an icon or error', function()
    local world, addon = setup(function(w)
        w.auras[5118] = w.secret
    end)
    world.combat = true

    world:fire('PLAYER_REGEN_DISABLED')

    equal(addon.AspectIcon.frame.shown, false)
    equal(glowing(world, addon.AspectIcon.frame), false)
end)

test('non-hunters never create or query the aspect reminder', function()
    local world, addon = setup(function(w)
        w.class = 'MAGE'
        w.auras[5118] = { spellId = 5118 }
    end)
    world.combat = true

    world:fire('PLAYER_REGEN_DISABLED')

    equal(addon.AspectIcon.frame, nil)
    equal(world.auraReads, 0)
end)

test('preview can be moved and closes with settings', function()
    local _, addon = setup()
    addon.SettingsPanel.moveAspectButton.scripts.OnClick()
    local frame = addon.AspectIcon.frame
    equal(frame.shown, true)
    equal(frame.mouseEnabled, true)
    frame.centerX, frame.centerY = 690, 410

    frame.scripts.OnDragStop(frame)

    equal(addon.Config.Get('aspectX'), 190)
    equal(addon.Config.Get('aspectY'), -90)
    addon.SettingsPanel.canvas:Hide()
    equal(frame.shown, false)
end)

print(('Aspect tests: %d passed, %d failed'):format(passed, failed))
if failed > 0 then os.exit(1) end
