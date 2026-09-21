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

local function setup()
    local world = H.new()
    local addon = world:load('Services/Client', 'Services/Range')
    assert(addon.Range, 'range evidence service is not implemented')
    addon.Range:Rebuild()
    addon.Range:BeginUpdate()
    return world, addon
end

test('close evidence colors a shot even in the gap beyond melee reach', function()
    local world, addon = setup()

    equal(addon.Range:IsTooClose(10), true)
    equal(world.ranges[40], false)
end)

test('in-range shot remains native even with a nearby probe', function()
    local world, addon = setup()
    world.ranges[10] = true

    equal(addon.Range:IsTooClose(10), false)
end)

test('too far is not mistaken for too close by a longer-range probe', function()
    local world, addon = setup()
    world.ranges[20] = false
    world.ranges[40] = false

    equal(addon.Range:IsTooClose(10), false)
end)

test('melee distance can confirm too close', function()
    local world, addon = setup()
    world.ranges[20] = nil
    world.ranges[40] = true

    equal(addon.Range:IsTooClose(10), true)
end)

test('melee and zero-minimum abilities are never tinted', function()
    local _, addon = setup()

    equal(addon.Range:IsTooClose(40), false)
    equal(addon.Range:IsTooClose(20), false)
end)

test('unknown shot range is not evidence', function()
    local world, addon = setup()
    world.ranges[10] = nil

    equal(addon.Range:IsTooClose(10), false)
end)

test('restricted shot range stays unchanged without branching on it', function()
    local world, addon = setup()
    world.ranges[10] = world.secret

    equal(addon.Range:IsTooClose(10), false)
end)

test('restricted probe is ignored and cannot prove proximity', function()
    local world, addon = setup()
    world.ranges[20] = world.secret

    equal(addon.Range:IsTooClose(10), false)
end)

test('one restricted probe does not suppress another readable close probe', function()
    local world, addon = setup()
    world.ranges[20] = world.secret
    world.ranges[40] = true

    equal(addon.Range:IsTooClose(10), true)
end)

test('invalid target prevents all range calls', function()
    local world, addon = setup()
    world.exists = false
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
    equal(next(world.queries), nil)
end)

test('friendly target prevents coloring', function()
    local world, addon = setup()
    world.attackable = false
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
    equal(next(world.queries), nil)
end)

test('dead target prevents coloring', function()
    local world, addon = setup()
    world.dead = true
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
end)

test('restricted target flags prevent coloring', function()
    local world, addon = setup()
    world.attackable = world.secret
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
end)

test('duplicate buttons reuse each spell range query per refresh', function()
    local world, addon = setup()

    for _ = 1, 96 do equal(addon.Range:IsTooClose(10), true) end

    equal(world.queries[10], 1)
    equal(world.queries[20], 1)
    equal(world.bookReads, 1)
end)

test('new target update discards previous proximity evidence', function()
    local world, addon = setup()
    equal(addon.Range:IsTooClose(10), true)
    world.ranges[20] = false
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
    equal(world.queries[20], 2)
end)

test('unlearned spell never colors despite available metadata', function()
    local world, addon = setup()
    world.learned = { 20, 30, 40 }
    addon.Range:Rebuild()
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
end)

test('a helpful spell is not a proximity probe for a hostile target', function()
    local world, addon = setup()
    world.helpful = { [20] = true }
    addon.Range:Rebuild()
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
end)

test('restricted range metadata is discarded safely', function()
    local world, addon = setup()
    world.spells[10].minRange = world.secret
    addon.Range:Rebuild()
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
end)

test('missing range API leaves native appearance', function()
    local world, addon = setup()
    world.env.C_Spell.IsSpellInRange = nil

    equal(addon.Range:IsTooClose(10), false)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
