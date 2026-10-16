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
    world.env.C_Spell.IsSpellUsable = function(id)
        return world.usable[id], world.noMana and world.noMana[id]
    end
    world.env.C_Spell.GetSpellCooldown = function(id) return world.cooldowns[id] end
    world.env.C_Spell.GetSpellTexture = function(id) return id == 19306 and 132269 or nil end
    world.env.C_Spell.GetSpellCooldownDuration = function(id)
        return id == 29515 and world.gcdDurationObject or nil
    end
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

local function glowColor(world, button)
    for frame, active in pairs(world.glowActive) do
        if frame.parent == button and active then
            return world.glowOptionsByFrame[frame].color
        end
    end
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
    local world = setup(function(w)
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world.learned[#world.learned + 1] = 19306

    world:fire('SPELLS_CHANGED')

    equal(glowing(world, world.main), true)
    equal(glowing(world, world.side), false)
end)

test('Mongoose Bite and Counterattack glow on their own selected buttons', function()
    local world = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[1495] = true
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
    equal(glowing(world, world.main), true)

    world.usable[1495] = false
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
    equal(glowing(world, world.main), true)
end)

test('Counterattack proc shows its icon and the GCD swipe over the selected button', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.gcdDurationObject = { marker = 'GCD' }
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    local overlay = addon.CounterattackOverlay
    equal(overlay.frame.parent, world.main)
    equal(overlay.frame.shown, true)
    equal(overlay.frame.mouseEnabled, false)
    equal(overlay.cooldown.mouseEnabled, false)
    equal(overlay.texture.texture, 132269)
    equal(overlay.cooldown.cooldownDuration, world.gcdDurationObject)
    equal(overlay.cooldown.drawSwipe, true)
    equal(glowing(world, world.main), true)
    equal(world.main.icon.texture, nil)
end)

test('Counterattack overlay uses the Forever GCD when duration objects are unavailable', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(addon.CounterattackOverlay.frame.shown, true)
    equal(addon.CounterattackOverlay.cooldown.cooldownStart, 100)
    equal(addon.CounterattackOverlay.cooldown.cooldownLength, 1.5)
end)

test('Counterattack icon covers the underlying action cooldown and keeps proc glow above it', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1

        w.main.cooldown = w.env.CreateFrame('Cooldown', nil, w.main)
        w.main.cooldown:SetFrameLevel(12)
        w.main.chargeCooldown = w.env.CreateFrame('Cooldown', nil, w.main)
        w.main.chargeCooldown:SetFrameLevel(14)
    end)
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    local overlayLevel = addon.CounterattackOverlay.frame:GetFrameLevel()
    local glowLevel = addon.Glow.Prepare(world.main).frame:GetFrameLevel()
    equal(addon.CounterattackOverlay.frame.strata, 'DIALOG')
    equal(addon.Glow.Prepare(world.main).frame.strata, 'DIALOG')
    assert(overlayLevel > world.main.cooldown:GetFrameLevel())
    assert(overlayLevel > world.main.chargeCooldown:GetFrameLevel())
    assert(glowLevel > overlayLevel)
    equal(addon.CounterattackOverlay.cooldown.drawSwipe, true)
    equal(addon.CounterattackOverlay.cooldown.noCooldownCount, true)
end)

test('Counterattack icon disappears when proc ends or its own cooldown starts', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')
    equal(addon.CounterattackOverlay.frame.shown, true)

    world.usable[19306] = false
    world:fire('SPELL_UPDATE_USABLE')
    equal(addon.CounterattackOverlay.frame.shown, false)

    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')
    world.cooldowns[19306] = { startTime = 100, duration = 5, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')
    equal(addon.CounterattackOverlay.frame.shown, false)
end)

test('casting Counterattack clears its overlay immediately through the GCD', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')
    equal(addon.CounterattackOverlay.frame.shown, true)

    world.cooldowns[19306] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true }
    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 19306)

    equal(addon.CounterattackOverlay.frame.shown, false)
    equal(glowing(world, world.main), false)

    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(addon.CounterattackOverlay.frame.shown, false)
    equal(glowing(world, world.main), false)
end)

test('consumed Counterattack cannot reappear after GCD until opportunity ends', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')
    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 19306)

    world.now = 102
    world.usable[19306] = true
    world.cooldowns[19306] = { startTime = 0, duration = 0, isEnabled = true }
    world:fire('SPELL_DATA_LOAD_RESULT')
    world:tick(0.1)

    equal(addon.CounterattackOverlay.frame.shown, false)
    equal(glowing(world, world.main), false)

    world.usable[19306] = false
    world:fire('SPELL_UPDATE_USABLE')
    equal(addon.CounterattackOverlay.frame.shown, false)

    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    equal(addon.CounterattackOverlay.frame.shown, true)
end)

test('casting Mongoose Bite clears its glow immediately through the GCD', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.side), true)

    world.cooldowns[1495] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true }
    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1495)

    equal(glowing(world, world.side), false)

    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(glowing(world, world.side), false)
end)

test('consumed Mongoose Bite stays hidden until dodge opportunity ends', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')
    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1495)

    world.now = 102
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.side), false)

    world.usable[1495] = false
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.side), false)

    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.side), true)
end)

test('another player spell does not consume Counterattack opportunity', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1495)
    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'pet', 'cast-guid', 19306)

    equal(addon.CounterattackOverlay.frame.shown, true)
end)

test('casting a learned higher Counterattack rank clears its overlay', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 20910
        w.spells[20910] = { spellID = 20910, name = 'Counterattack', minRange = 0, maxRange = 5 }
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[20910] = true
    world.cooldowns[20910] = { startTime = 0, duration = 0, isEnabled = true }
    world:fire('SPELL_UPDATE_USABLE')
    equal(addon.CounterattackOverlay.frame.shown, true)

    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 20910)

    equal(addon.CounterattackOverlay.frame.shown, false)
end)

test('casting one Counterattack rank consumes the opportunity for all learned ranks', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.learned[#w.learned + 1] = 20910
        w.spells[20910] = { spellID = 20910, name = 'Counterattack', minRange = 0, maxRange = 5 }
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world.usable[20910] = true
    world.cooldowns[20910] = { startTime = 0, duration = 0, isEnabled = true }
    world:fire('SPELL_UPDATE_USABLE')
    equal(addon.CounterattackOverlay.frame.shown, true)

    world:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 20910)

    equal(addon.CounterattackOverlay.frame.shown, false)
end)

test('Counterattack icon overlay can be disabled without clearing the glow', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    addon.Config.Set('counterattackOverlayEnabled', false)

    assert(addon.SettingsPanel.controls.counterattackOverlayEnabled)
    equal(addon.CounterattackOverlay.frame.shown, false)
    equal(glowing(world, world.main), true)
end)

test('unavailable cooldown widget does not prevent either reactive glow from starting', function()
    local world = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1

        local createFrame = w.env.CreateFrame
        w.env.CreateFrame = function(kind, ...)
            if kind == 'Cooldown' then
                error('cooldown widget unavailable')
            end

            return createFrame(kind, ...)
        end
    end)
    world.usable[1495] = true
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
    equal(glowing(world, world.main), true)
end)

test('overlay display failure cannot interrupt either reactive glow', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    addon.CounterattackOverlay.entries[world.main].frame.Show = function()
        error('display blocked')
    end
    world.usable[1495] = true
    world.usable[19306] = true

    local ok = pcall(function() world:fire('SPELL_UPDATE_USABLE') end)

    equal(ok, true)
    equal(glowing(world, world.side), true)
    equal(glowing(world, world.main), true)
end)

test('restricted GCD setter cannot break Counterattack readiness', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    local overlay = addon.CounterattackOverlay
    overlay.entries[world.main].cooldown.SetCooldown = function() error('protected cooldown') end
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world.usable[19306] = true

    local ok = pcall(function() world:fire('SPELL_UPDATE_USABLE') end)

    equal(ok, true)
    equal(overlay.frame.shown, true)
    equal(glowing(world, world.main), true)
end)

test('GCD-only usable event does not briefly clear an active Mongoose Bite proc', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = 0, duration = 0, isEnabled = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
end)

test('each reactive glow exposes native color and custom color settings', function()
    local _, addon = setup()

    assert(addon.SettingsPanel.controls.mongooseNativeColor)
    assert(addon.SettingsPanel.controls.mongooseGlowColor)
    assert(addon.SettingsPanel.controls.counterattackNativeColor)
    assert(addon.SettingsPanel.controls.counterattackGlowColor)
    equal(addon.Config.Get('mongooseNativeColor'), true)
    equal(addon.Config.Get('counterattackNativeColor'), true)
end)

test('custom colors apply independently and native restores immediately', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[1495] = true
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowColor(world, world.side), nil)
    equal(glowColor(world, world.main), nil)

    addon.Config.Set('mongooseGlowColor', 'ff0000ff')
    addon.Config.Set('mongooseNativeColor', false)
    local mongooseColor = glowColor(world, world.side)
    equal(mongooseColor[1], 0)
    equal(mongooseColor[3], 1)
    equal(glowColor(world, world.main), nil)

    addon.Config.Set('counterattackGlowColor', 'ffff0000')
    addon.Config.Set('counterattackNativeColor', false)
    local counterattackColor = glowColor(world, world.main)
    equal(counterattackColor[1], 1)
    equal(counterattackColor[3], 0)
    equal(glowColor(world, world.side)[3], 1)

    addon.Config.Set('mongooseNativeColor', true)
    equal(glowColor(world, world.side), nil)
    equal(glowColor(world, world.main)[1], 1)
end)

test('Counterattack is unselected by default and does not light Mongoose Bite button', function()
    local world = setup(function(w) w.learned[#w.learned + 1] = 19306 end)
    world.usable[19306] = true

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
    equal(world.addon.Config.Get('counterattackBar'), 0)
end)

test('disabling one reactive glow keeps the other active', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[1495] = true
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    addon.Config.Set('mongooseGlowEnabled', false)

    equal(glowing(world, world.side), false)
    equal(glowing(world, world.main), true)
end)

test('Counterattack cooldown clears only its own glow', function()
    local world = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[1495] = true
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.cooldowns[19306] = { startTime = 100, duration = 5, isEnabled = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), true)
    equal(glowing(world, world.main), false)
end)

test('shared button keeps Counterattack glow when Mongoose Bite expires', function()
    local world = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 5
        w.env.HunterAssistForeverDB.counterattackButton = 7
    end)
    world.usable[1495] = true
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world:fire('SPELL_UPDATE_USABLE')

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
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), true)
end)

test('Mongoose Bite glow stays visible when usability briefly falls during GCD', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.side), true)

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = 100, duration = 1.5, isEnabled = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(glowing(world, world.side), true)

    world.now = 102
    world.cooldowns[1495] = { startTime = 0, duration = 0, isEnabled = true, isOnGCD = false }
    world.cooldowns[29515] = { startTime = 0, duration = 0, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
end)

test('GCD evidence and a zero own cooldown keep Mongoose Bite glowing despite timing differences', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = 100.02, duration = 1.48,
        isEnabled = true, isActive = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world.env.C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
        if id == 1495 and ignoreGCD then
            return {
                HasSecretValues = function() return false end,
                IsZero = function() return true end,
            }
        end
    end

    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(glowing(world, world.side), true)
end)

test('readable GCD timings tolerate small differences without an own duration object', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = 100.02, duration = 1.48,
        isEnabled = true, isActive = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5,
        isEnabled = true, isActive = true }

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
end)

test('GCD evidence and a zero own cooldown keep Counterattack overlay visible', function()
    local world, addon = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[19306] = false
    world.cooldowns[19306] = { startTime = 100.02, duration = 1.48,
        isEnabled = true, isActive = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world.env.C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
        if id == 19306 and ignoreGCD then
            return {
                HasSecretValues = function() return false end,
                IsZero = function() return true end,
            }
        end
    end

    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(glowing(world, world.main), true)
    equal(addon.CounterattackOverlay.frame.shown, true)
end)

test('event GCD evidence preserves the proc when combat cooldown timings are restricted', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true, isOnGCD = true }
    world:fire('SPELL_UPDATE_COOLDOWN')
    world.cooldowns[1495].isOnGCD = nil
    world:tick(0.1)

    equal(glowing(world, world.side), true)
end)

test('active GCD preserves Mongoose Bite before its cooldown event arrives', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true }
    world.cooldowns[29515] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true }

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
end)

test('second cooldown event without a GCD flag keeps Counterattack glowing', function()
    local world = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[19306] = false
    world.cooldowns[19306] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true, isOnGCD = true }
    world:fire('SPELL_UPDATE_COOLDOWN')
    world.cooldowns[19306].isOnGCD = false

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.main), true)
end)

test('event GCD evidence expires instead of keeping a stale proc glow', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true, isOnGCD = true }
    world:fire('SPELL_UPDATE_COOLDOWN')
    world.cooldowns[1495].isOnGCD = nil
    world.now = 102

    world:tick(0.1)

    equal(glowing(world, world.side), false)
end)

test('usability event before cooldown event does not erase a proc at GCD start', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true }
    world.cooldowns[29515] = { startTime = world.secret, duration = world.secret,
        isEnabled = true, isActive = true }
    world.env.C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
        if id == 1495 and ignoreGCD then
            return {
                HasSecretValues = function() return false end,
                IsZero = function() return true end,
            }
        end
    end

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)

    world.cooldowns[1495].isOnGCD = true
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), true)
end)

test('Counterattack glow stays visible when usability briefly falls during GCD', function()
    local world = setup(function(w)
        w.learned[#w.learned + 1] = 19306
        w.env.HunterAssistForeverDB.counterattackBar = 1
        w.env.HunterAssistForeverDB.counterattackButton = 1
    end)
    world.usable[19306] = true
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.main), true)

    world.usable[19306] = false
    world.cooldowns[19306] = { startTime = 100, duration = 1.5, isEnabled = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.main), true)
end)

test('insufficient resources do not clear a reactive glow during GCD', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.noMana = { [1495] = true }
    world.cooldowns[1495] = { startTime = 100, duration = 1.5, isEnabled = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), true)
end)

test('insufficient resources do not clear a reactive glow outside GCD', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.noMana = { [1495] = true }
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
end)

test('resource shortage can light a newly available reactive spell', function()
    local world = setup()
    world.usable[1495] = false
    world.noMana = { [1495] = true }

    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), true)
end)

test('expired reactive opportunity clears glow after resource shortage', function()
    local world = setup()
    world.usable[1495] = false
    world.noMana = { [1495] = true }
    world:fire('SPELL_UPDATE_USABLE')
    equal(glowing(world, world.side), true)

    world.noMana[1495] = false
    world:fire('SPELL_UPDATE_USABLE')

    equal(glowing(world, world.side), false)
end)

test('a real cooldown clears a previously active reactive glow', function()
    local world = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    world.usable[1495] = false
    world.cooldowns[1495] = { startTime = 100, duration = 5, isEnabled = true, isOnGCD = false }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
end)

test('GCD flag does not override a longer own cooldown', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { startTime = 100, duration = 6, isEnabled = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
end)

test('a readable own cooldown blocks glow even when event also reports GCD', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { startTime = 100, duration = 1.5,
        isEnabled = true, isActive = true, isOnGCD = true }
    world.cooldowns[29515] = { startTime = 100, duration = 1.5, isEnabled = true }
    world.env.C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
        if id == 1495 and ignoreGCD then
            return {
                HasSecretValues = function() return false end,
                IsZero = function() return false end,
                HasExpired = function() return false end,
            }
        end
    end

    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), false)
end)

test('changing selected button clears the previous glow', function()
    local world, addon = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    addon.Config.Set('mongooseButton', 1)
    addon.Config.Set('mongooseBar', 1)

    equal(glowing(world, world.side), false)
    equal(glowing(world, world.main), true)
end)

test('disabling clears glow and stops reactive polling', function()
    local world, addon = setup()
    world.usable[1495] = true
    world:fire('SPELL_UPDATE_USABLE')

    addon.Config.Set('mongooseGlowEnabled', false)

    equal(glowing(world, world.side), false)
    equal(addon.ReactiveGlow.frame.scripts.OnUpdate, nil)
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

test('restricted GCD flag retains bounded evidence from prior cooldown event', function()
    local world = setup()
    world.usable[1495] = true
    world.cooldowns[1495] = { isOnGCD = true, startTime = world.secret, duration = world.secret }
    world:fire('SPELL_UPDATE_COOLDOWN')
    equal(glowing(world, world.side), true)

    world.cooldowns[1495] = { isOnGCD = world.secret, startTime = world.secret, duration = world.secret }
    world:fire('SPELL_UPDATE_COOLDOWN')

    equal(glowing(world, world.side), true)

    world.now = 102
    world:tick(0.1)

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
