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

local function setup(health, configure)
    local world = H.new()
    world.petHealth, world.petMax, world.petExists, world.petDead = health, 1000, true, false
    world.petReads = 0
    world.happiness, world.happinessReads = 3, 0
    world.petWarnings, world.petSounds, world.now = {}, {}, 100
    world.env.UnitExists = function(unit) equal(unit, 'pet'); return world.petExists end
    world.env.UnitIsDeadOrGhost = function(unit) equal(unit, 'pet'); return world.petDead end
    world.env.UnitHealth = function(unit)
        equal(unit, 'pet')
        world.petReads = world.petReads + 1
        return world.petHealth
    end
    world.env.UnitHealthMax = function(unit) equal(unit, 'pet'); return world.petMax end
    world.env.C_PetInfo = {
        GetPetHappiness = function()
            world.happinessReads = world.happinessReads + 1
            return world.happiness
        end,
    }
    world.env.RaidWarningFrame = {}
    world.env.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.2, b = 0.2 } }
    world.env.SOUNDKIT = { TELL_MESSAGE = 3081, RAID_WARNING = 8959 }
    world.env.GetTime = function() return world.now end
    world.env.RaidNotice_AddMessage = function(frame, message)
        equal(frame, world.env.RaidWarningFrame)
        world.petWarnings[#world.petWarnings + 1] = message
    end
    world.env.PlaySound = function(sound)
        world.petSounds[#world.petSounds + 1] = sound
    end
    world.env.SendChatMessage = function() error('pet warnings must be local') end
    if configure then configure(world) end

    for line in io.lines('HunterAssistForever/HunterAssistForever.toc') do
        if line:match('%.lua$') then
            assert(loadfile('HunterAssistForever/' .. line, 't', world.env))('HunterAssistForever', world.addon)
        end
    end
    world:fire('PLAYER_LOGIN')
    world:fire('PLAYER_ENTERING_WORLD')

    assert(world.addon.PetHealthIcon, 'pet health feature missing')
    return world, world.addon
end

test('fresh setup uses a 35 percent pet health threshold', function()
    local _, addon = setup(350)

    equal(addon.Config.Get('petHealthThreshold'), 35)
    equal(addon.PetHealthIcon.frame.shown, true)
end)

test('saved pet health threshold survives a default change', function()
    local _, addon = setup(300, function(world)
        world.env.HunterAssistForeverDB = { petHealthThreshold = 25 }
    end)

    equal(addon.Config.Get('petHealthThreshold'), 25)
    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('healthy pet icon is hidden', function()
    local _, addon = setup(351)

    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('exact threshold shows red and one local warning', function()
    local world, addon = setup(350)

    equal(addon.PetHealthIcon.frame.shown, true)
    equal(addon.PetHealthIcon.texture.color[1], 1)
    equal(addon.PetHealthIcon.texture.color[2], 0.2)
    equal(addon.PetHealthIcon.countText.shown, false)
    equal(#world.petWarnings, 1)
    equal(#world.petSounds, 1)
end)

test('healing above threshold hides the icon', function()
    local world, addon = setup(200)
    world.petHealth = 500

    world:fire('UNIT_HEALTH', 'pet')

    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('max health changes update the threshold calculation', function()
    local world, addon = setup(400)
    world.petMax = 2000

    world:fire('UNIT_MAXHEALTH', 'pet')

    equal(addon.PetHealthIcon.frame.shown, true)
end)

test('missing pet and dead pet hide the icon', function()
    local world, addon = setup(200)
    world.petExists = false
    world:fire('UNIT_PET', 'player')
    equal(addon.PetHealthIcon.frame.shown, false)

    world.petExists, world.petDead = true, true
    world:fire('UNIT_FLAGS', 'pet')

    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('restricted health hides without arithmetic on the value', function()
    local world, addon = setup(200)
    world.petHealth = world.secret

    world:fire('UNIT_HEALTH', 'pet')

    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('restricted pet health still drives low-health icon through a client curve', function()
    local world, addon = setup(1000, function(w)
        w.petHealth = w.secret
        w.petFraction = 0.2
        w.env.Enum.LuaCurveType = { Step = 1 }
        w.env.C_CurveUtil = { CreateCurve = function()
            local curve = { points = {} }
            function curve:SetType(kind) equal(kind, 1) end
            function curve:AddPoint(input, output)
                self.points[#self.points + 1] = { input, output }
            end
            return curve
        end }
        w.env.UnitHealthPercent = function(unit, predicted, curve)
            equal(unit, 'pet')
            equal(predicted, true)
            local alpha = 0
            for _, point in ipairs(curve.points) do
                if w.petFraction >= point[1] then alpha = point[2] end
            end
            return alpha
        end
    end)

    equal(addon.PetHealthIcon.frame.shown, true)
    equal(addon.PetHealthIcon.frame.alpha, 1)
    equal(addon.PetHealthIcon.countText.shown, false)
    equal(#world.petWarnings, 0)

    world.petFraction = 0.35
    world:fire('UNIT_HEALTH', 'pet')
    equal(addon.PetHealthIcon.frame.alpha, 1)

    world.petFraction = 0.36
    world:fire('UNIT_HEALTH', 'pet')
    equal(addon.PetHealthIcon.frame.alpha, 0)

    world.petFraction = 0.8
    world:fire('UNIT_HEALTH', 'pet')
    equal(addon.PetHealthIcon.frame.alpha, 0)

    addon.Config.Set('petHealthThreshold', 90)
    equal(addon.PetHealthIcon.frame.alpha, 1)
end)

test('secret health-curve alpha reaches the icon without Lua comparison', function()
    local world, addon = setup(1000, function(w)
        w.petHealth = w.secret
        w.env.Enum.LuaCurveType = { Step = 1 }
        w.env.C_CurveUtil = { CreateCurve = function()
            return { SetType = function() end, AddPoint = function() end }
        end }
        w.env.UnitHealthPercent = function() return w.secret end
    end)

    equal(addon.PetHealthIcon.frame.shown, true)
    equal(rawequal(addon.PetHealthIcon.frame.alpha, world.secret), true)
    equal(#world.petWarnings, 0)
end)

test('threshold and percentage settings apply immediately', function()
    local _, addon = setup(400)

    addon.Config.Set('petHealthThreshold', 50)
    addon.Config.Set('petShowPercent', true)

    equal(addon.PetHealthIcon.frame.shown, true)
    equal(addon.PetHealthIcon.countText.text, '40%')
    equal(addon.Config.CanSet('petHealthThreshold', 101), false)
    equal(addon.Config.CanSet('petHealthThreshold', 0), false)
end)

test('disable hides the pet indicator', function()
    local _, addon = setup(100)

    addon.Config.Set('petHealthEnabled', false)

    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('loading hides the indicator until world entry', function()
    local world, addon = setup(100)
    world:fire('PLAYER_LEAVING_WORLD')
    equal(addon.PetHealthIcon.frame.shown, false)

    world:fire('UNIT_HEALTH', 'pet')
    equal(addon.PetHealthIcon.frame.shown, false)
    world:fire('PLAYER_ENTERING_WORLD')
    equal(addon.PetHealthIcon.frame.shown, true)
end)

test('unrelated unit events and idle frames do not query pet health', function()
    local world = setup(500)
    local reads = world.petReads

    world:fire('UNIT_HEALTH', 'target')
    world:fire('UNIT_PET', 'party1')
    world:tick(1)

    equal(world.petReads, reads)
end)

test('pet preview is movable and closes with settings', function()
    local _, addon = setup(1000)
    addon.SettingsPanel.movePetButton.scripts.OnClick()
    local frame = addon.PetHealthIcon.frame
    equal(frame.shown, true)
    frame.centerX, frame.centerY = 700, 400

    frame.scripts.OnDragStop(frame)
    addon.SettingsPanel.canvas:Hide()

    equal(addon.Config.Get('petX'), 200)
    equal(addon.Config.Get('petY'), -100)
    equal(frame.shown, false)
    equal(frame.mouseEnabled, false)
end)

test('zero maximum health hides the indicator', function()
    local world, addon = setup(100)
    world.petMax = 0

    world:fire('UNIT_MAXHEALTH', 'pet')

    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('non-hunters do not create or read pet health indicator', function()
    local world, addon = setup(100, function(w) w.class = 'PALADIN' end)

    equal(addon.PetHealthIcon.frame, nil)
    equal(addon.PetHappinessIcon.frame, nil)
    equal(world.petReads, 0)
    equal(world.happinessReads, 0)
end)

test('combat pet health updates show and hide the icon', function()
    local world, addon = setup(500)
    world.combat = true
    world.petHealth = 200

    world:fire('UNIT_HEALTH', 'pet')
    equal(addon.PetHealthIcon.frame.shown, true)
    world.petHealth = 800
    world:fire('UNIT_HEALTH', 'pet')
    equal(addon.PetHealthIcon.frame.shown, false)
end)

test('exact custom threshold is not hidden by percentage rounding', function()
    local _, addon = setup(280)

    addon.Config.Set('petHealthThreshold', 28)

    equal(addon.PetHealthIcon.frame.shown, true)
end)

test('happy pet has no happiness icon', function()
    local _, addon = setup(1000)

    equal(addon.PetHappinessIcon.frame.shown, false)
end)

test('Forever namespaced happiness API shows the content icon without the legacy global', function()
    local _, addon = setup(1000, function(world)
        world.happiness = 2
        world.env.GetPetHappiness = false
    end)

    equal(addon.PetHappinessIcon.frame.shown, true)
    equal(addon.PetHappinessIcon.texture.color[2], 0.85)
end)

test('content pet displays a yellow happiness icon', function()
    local world, addon = setup(1000)
    world.happiness = 2

    world:fire('UNIT_HAPPINESS', 'pet')

    equal(addon.PetHappinessIcon.frame.shown, true)
    equal(addon.PetHappinessIcon.texture.color[1], 1)
    equal(addon.PetHappinessIcon.texture.color[2], 0.85)
    equal(#world.messages, 0)
end)

test('unhappy pet displays a red happiness icon', function()
    local world, addon = setup(1000)
    world.happiness = 1

    world:fire('UNIT_HAPPINESS', 'pet')

    equal(addon.PetHappinessIcon.frame.shown, true)
    equal(addon.PetHappinessIcon.texture.color[1], 1)
    equal(addon.PetHappinessIcon.texture.color[2], 0.2)
    equal(#world.messages, 0)
end)

test('feeding back to happy hides the happiness icon', function()
    local world, addon = setup(1000)
    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')
    world.happiness = 3

    world:fire('UNIT_HAPPINESS', 'pet')

    equal(addon.PetHappinessIcon.frame.shown, false)
end)

test('unavailable or restricted happiness hides without comparing it', function()
    local world, addon = setup(1000)
    world.happiness = world.secret
    world:fire('UNIT_HAPPINESS', 'pet')
    equal(addon.PetHappinessIcon.frame.shown, false)

    world.happiness = nil
    world:fire('UNIT_HAPPINESS', 'pet')
    equal(addon.PetHappinessIcon.frame.shown, false)
end)

test('missing or dead pets hide the happiness icon', function()
    local world, addon = setup(1000)
    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')
    world.petExists = false

    world:fire('UNIT_PET', 'player')

    equal(addon.PetHappinessIcon.frame.shown, false)
    world.petExists, world.petDead = true, true
    world:fire('UNIT_FLAGS', 'pet')
    equal(addon.PetHappinessIcon.frame.shown, false)
end)

test('happiness setting disables the icon without changing health alert', function()
    local world, addon = setup(200)
    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')

    addon.Config.Set('petHappinessEnabled', false)

    equal(addon.PetHappinessIcon.frame.shown, false)
    equal(addon.PetHealthIcon.frame.shown, true)
end)

test('happiness icon can be moved independently', function()
    local _, addon = setup(1000)
    addon.SettingsPanel.moveHappinessButton.scripts.OnClick()
    local frame = addon.PetHappinessIcon.frame
    equal(frame.shown, true)
    frame.centerX, frame.centerY = 750, 390

    frame.scripts.OnDragStop(frame)
    addon.SettingsPanel.canvas:Hide()

    equal(addon.Config.Get('petHappinessX'), 250)
    equal(addon.Config.Get('petHappinessY'), -110)
    equal(frame.shown, false)
end)

test('happiness updates remain event driven', function()
    local world = setup(1000)
    local reads = world.happinessReads

    world:tick(1)
    world:fire('UNIT_PET', 'party1')

    equal(world.happinessReads, reads)
end)

test('happiness API failure hides the icon without an error', function()
    local world, addon = setup(1000)
    world.happiness = 2
    world:fire('UNIT_HAPPINESS', 'pet')
    world.env.C_PetInfo.GetPetHappiness = function() error('unavailable') end

    world:fire('UNIT_HAPPINESS', 'pet')

    equal(addon.PetHappinessIcon.frame.shown, false)
end)

test('loading hides the happiness icon and restores its current state', function()
    local world, addon = setup(1000)
    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')
    world:fire('PLAYER_LEAVING_WORLD')
    equal(addon.PetHappinessIcon.frame.shown, false)

    world:fire('PLAYER_ENTERING_WORLD')

    equal(addon.PetHappinessIcon.frame.shown, true)
end)

test('low pet health warns once and rearms after recovery', function()
    local world = setup(600)
    equal(#world.petWarnings, 0)

    world.petHealth = 250
    world:fire('UNIT_HEALTH', 'pet')
    world:fire('UNIT_HEALTH', 'pet')
    equal(#world.petWarnings, 1)
    assert(world.petWarnings[1]:find('Pet health low', 1, true))
    equal(world.petSounds[1], 3081)

    world.petHealth = 700
    world:fire('UNIT_HEALTH', 'pet')
    world.petHealth = 200
    world.now = 102
    world:fire('UNIT_HEALTH', 'pet')

    equal(#world.petWarnings, 2)
    equal(#world.petSounds, 2)
end)

test('content stays visual only; unhappy warns once per episode', function()
    local world = setup(1000)
    world.happiness = 2
    world:fire('UNIT_HAPPINESS', 'pet')
    equal(#world.petWarnings, 0)
    equal(#world.petSounds, 0)

    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')
    world:fire('UNIT_HAPPINESS', 'pet')
    equal(#world.petWarnings, 1)
    assert(world.petWarnings[1]:find('Pet unhappy', 1, true))
    equal(world.petSounds[1], 3081)

    world.happiness = 2
    world:fire('UNIT_HAPPINESS', 'pet')
    world.happiness = 1
    world.now = 102
    world:fire('UNIT_HAPPINESS', 'pet')

    equal(#world.petWarnings, 2)
    equal(#world.petSounds, 2)
end)

test('simultaneous pet alerts show both texts with one gentle chime', function()
    local world = setup(1000, function(w) w.happiness = 1 end)
    world.petHealth = 200

    world:fire('UNIT_HEALTH', 'pet')

    equal(#world.petWarnings, 2)
    equal(#world.petSounds, 1)
    equal(world.petSounds[1], 3081)
end)

test('restricted pet data cannot invent or rearm a warning', function()
    local world = setup(1000)
    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')
    equal(#world.petWarnings, 1)

    world.happiness = world.secret
    world:fire('UNIT_HAPPINESS', 'pet')
    world.happiness = 1
    world:fire('UNIT_HAPPINESS', 'pet')

    equal(#world.petWarnings, 1)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
