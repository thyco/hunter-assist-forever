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
    world.now = 100
    world.usable = { [1495] = false, [19306] = false }
    world.cooldowns = { [1495] = { startTime = 0, duration = 0, isEnabled = true },
        [19306] = { startTime = 0, duration = 0, isEnabled = true } }
    world.spells[1495] = { spellID = 1495, name = 'Mongoose Bite', minRange = 0, maxRange = 5 }
    world.spells[19306] = { spellID = 19306, name = 'Counterattack', minRange = 0, maxRange = 5 }
    world.learned[#world.learned + 1] = 1495
    world.env.GetTime = function() return world.now end
    world.env.UnitAffectingCombat = function() return world.combat end
    world.env.C_Spell.IsSpellUsable = function(id) return world.usable[id] end
    world.env.C_Spell.GetSpellCooldown = function(id) return world.cooldowns[id] end
    world.main = world:button('ActionButton1', 1)
    world.side = world:button('MultiBarLeftButton7', 67)
    world.env.HunterAssistForeverDB = { reactiveGlowEnabled = true, reactiveBar = 5, reactiveButton = 7 }
    if configure then configure(world) end

    for line in io.lines('HunterAssistForever/HunterAssistForever.toc') do
        if line:match('%.lua$') then
            assert(loadfile('HunterAssistForever/' .. line, 't', world.env))('HunterAssistForever', world.addon)
        end
    end
    world:fire('PLAYER_LOGIN')
    assert(world.addon.ReactiveGlow, 'reactive feature missing')
    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')

    return world, world.addon
end

local function glowing(world, button)
    for frame, active in pairs(world.glowActive) do
        if frame.parent == button and active then return true end
    end
    return false
end

test('dodge usability lights only the selected button with native glow', function()
    local world = setup()
    equal(glowing(world, world.side), false)
    world.usable[1495] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
    equal(glowing(world, world.main), false)
    equal(world.glowOptions.color, nil)
end)

test('own cooldown prevents glow even when spell is usable', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { startTime = 95, duration = 10, isEnabled = true }

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
    world.now = 106
    world:tick(0.1)
    equal(glowing(world, world.side), true)
end)

test('expired dodge opportunity clears glow immediately', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
end)

test('unlearned Counterattack cannot trigger glow', function()
    local world = setup()
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
end)

test('learning Counterattack enables its parry usability check', function()
    local world = setup()
    world.usable[19306] = true
    world.learned[#world.learned + 1] = 19306

    world:fire('SPELLS_CHANGED')

    equal(glowing(world, world.side), true)
end)

test('localized higher rank is checked instead of seed rank', function()
    local world = setup(function(w)
        w.spells[1495].name = 'Morsure'
        w.spells[14269] = { spellID = 14269, name = 'Morsure', minRange = 0, maxRange = 5 }
        w.learned[#w.learned] = 14269
        w.cooldowns[14269] = { startTime = 0, duration = 0, isEnabled = true }
        w.usable[14269] = true
    end)

    equal(glowing(world, world.side), true)
end)

test('restricted usability never triggers glow', function()
    local world = setup()
    world.usable[1495] = world.secret

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
end)

test('restricted cooldown timing leaves readiness unknown', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { startTime = world.secret, duration = world.secret }

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
end)

test('global cooldown alone does not hide the reactive opportunity', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { startTime = 100, duration = 1.5, isEnabled = true }
    world.cooldowns[61304] = { startTime = 100, duration = 1.5, isEnabled = true }

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), true)
end)

test('changing selected button clears the previous glow', function()
    local world, addon = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    addon.Config.Set('reactiveButton', 1)
    addon.Config.Set('reactiveBar', 1)

    equal(glowing(world, world.side), false)
    equal(glowing(world, world.main), true)
end)

test('disabling clears glow and stops reactive polling', function()
    local world, addon = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    addon.Config.Set('reactiveGlowEnabled', false)

    equal(glowing(world, world.side), false)
end)

test('leaving combat clears glow', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(glowing(world, world.side), false)
end)

test('hidden selected button releases glow on refresh', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.side:Hide()
    world:tick(0.1)

    equal(glowing(world, world.side), false)
end)

test('no bar selection means no glow or polling', function()
    local world, addon = setup(function(w) w.env.HunterAssistForeverDB.reactiveBar = 0 end)
    world.usable[1495] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
    equal(addon.ReactiveGlow.frame.scripts.OnUpdate, nil)
end)

test('loading suppresses glow until world entry restores current readiness', function()
    local world, addon = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world:fire('PLAYER_LEAVING_WORLD')
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
    equal(addon.ReactiveGlow.frame.scripts.OnUpdate, nil)
    world:fire('PLAYER_ENTERING_WORLD')
    equal(glowing(world, world.side), true)
end)

test('restricted GCD flag cannot retain readiness from prior cooldown event', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { isOnGCD = true, startTime = world.secret, duration = world.secret }
    world:fire('SPELL_UPDATE_COOLDOWN')
    equal(glowing(world, world.side), true)

    world.cooldowns[1495] = { isOnGCD = world.secret, startTime = world.secret, duration = world.secret }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
end)

test('usability API failure clears an existing glow', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.env.C_Spell.IsSpellUsable = function() error('unavailable') end
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
