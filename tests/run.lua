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

test('spellbook check supplies proximity when spell-ID result is unavailable', function()
    local world, addon = setup()
    world.ranges[20] = nil
    world.env.C_SpellBook.IsSpellBookItemInRange = function(slot, bank, unit)
        equal(bank, 0)
        equal(unit, 'target')
        if slot == 1 then return false end
        if slot == 2 then return true end
    end

    equal(addon.Range:IsTooClose(10), true)
end)

test('explicit spellbook false is authoritative over spell-ID true', function()
    local world, addon = setup()
    world.env.C_SpellBook.IsSpellBookItemInRange = function() return false end

    equal(addon.Range:IsTooClose(10), false)
end)

test('restricted spellbook answer safely falls back to readable spell-ID answer', function()
    local world, addon = setup()
    world.env.C_SpellBook.IsSpellBookItemInRange = function() return world.secret end

    equal(addon.Range:IsTooClose(10), true)
    local details = table.concat(addon.Range:DescribeChecks(), '\n')
    assert(details:find('restricted', 1, true))
    assert(details:find('spell ID', 1, true))
end)

test('spellbook API error falls back without exposing the error payload', function()
    local world, addon = setup()
    world.env.C_SpellBook.IsSpellBookItemInRange = function() error('raw error payload') end

    equal(addon.Range:IsTooClose(10), true)
    local details = table.concat(addon.Range:DescribeChecks(), '\n')
    assert(details:find('error', 1, true))
    assert(not details:find('raw error payload', 1, true))
end)

test('diagnostics identify the spell confirming proximity', function()
    local _, addon = setup()
    equal(addon.Range:IsTooClose(10), true)

    local details = table.concat(addon.Range:DescribeChecks(), '\n')

    assert(details:find('Ranged shot', 1, true))
    assert(details:find('Close probe', 1, true))
    assert(details:find('confirmed by', 1, true))
end)

test('diagnostics distinguish unknown range from out of range', function()
    local world, addon = setup()
    world.ranges[20] = nil
    equal(addon.Range:IsTooClose(10), false)

    local details = table.concat(addon.Range:DescribeChecks(), '\n')

    assert(details:find('unavailable', 1, true))
    assert(details:find('out of range', 1, true))
    assert(not details:find('confirmed by', 1, true))
end)

test('restricted spell names are never stringified in diagnostics', function()
    local world, addon = setup()
    world.spells[20].name = world.secret
    addon.Range:Rebuild()
    addon.Range:BeginUpdate()
    equal(addon.Range:IsTooClose(10), true)

    local details = table.concat(addon.Range:DescribeChecks(), '\n')

    assert(details:find('spell 20', 1, true))
end)

test('duplicate buttons share the spellbook check and skip the ID API when readable', function()
    local world, addon = setup()
    local calls = {}
    world.env.C_SpellBook.IsSpellBookItemInRange = function(slot)
        calls[slot] = (calls[slot] or 0) + 1
        return slot == 2
    end

    for _ = 1, 96 do equal(addon.Range:IsTooClose(10), true) end

    equal(calls[1], 1)
    equal(calls[2], 1)
    equal(next(world.queries), nil)
end)

local function interactionSetup(result)
    local world, addon = setup()
    world.ranges[20] = false
    world.ranges[40] = false
    world.interactionCalls = 0
    world.env.CheckInteractDistance = function(unit, index)
        equal(index, 3)
        world.interactionUnit = unit
        world.interactionCalls = world.interactionCalls + 1
        return result
    end

    return world, addon
end

test('interaction confirms close humanoid when creature-restricted spell cannot', function()
    local world, addon = interactionSetup(true)
    world.combat = true

    equal(addon.Range:IsTooClose(10), true)
    equal(world.interactionUnit, 'target')
    assert(table.concat(addon.Range:DescribeChecks(), '\n'):find('CheckInteractDistance', 1, true))
end)

test('interaction false cannot confuse far away with too close', function()
    local _, addon = interactionSetup(false)

    equal(addon.Range:IsTooClose(10), false)
end)

test('positive interaction does not color a shot in normal shooting range', function()
    local world, addon = interactionSetup(true)
    world.ranges[10] = true

    equal(addon.Range:IsTooClose(10), false)
    equal(world.interactionCalls, 0)
end)

test('positive interaction cannot replace unknown shot range', function()
    local world, addon = interactionSetup(true)
    world.ranges[10] = nil

    equal(addon.Range:IsTooClose(10), false)
    equal(world.interactionCalls, 0)
end)

test('unknown interaction leaves the icon native', function()
    local _, addon = interactionSetup(nil)

    equal(addon.Range:IsTooClose(10), false)
    assert(table.concat(addon.Range:DescribeChecks(), '\n'):find('interaction=unavailable', 1, true))
end)

test('restricted interaction is ignored without exposing its value', function()
    local world, addon = interactionSetup(nil)
    world.env.CheckInteractDistance = function() return world.secret end

    equal(addon.Range:IsTooClose(10), false)
    assert(table.concat(addon.Range:DescribeChecks(), '\n'):find('interaction=restricted', 1, true))
end)

test('interaction API errors leave the icon native', function()
    local world, addon = interactionSetup(nil)
    world.env.CheckInteractDistance = function() error('private payload') end

    equal(addon.Range:IsTooClose(10), false)
    local details = table.concat(addon.Range:DescribeChecks(), '\n')
    assert(details:find('interaction=error', 1, true))
    assert(not details:find('private payload', 1, true))
end)

test('interaction bound cannot prove proximity for shorter maximum range spells', function()
    local world, addon = interactionSetup(true)
    world.spells[10].maxRange = 9
    addon.Range:Rebuild()

    equal(addon.Range:IsTooClose(10), false)
    equal(world.interactionCalls, 0)
end)

test('interaction result is shared across shots and cleared for next refresh', function()
    local world, addon = interactionSetup(true)
    world.spells[30].minRange = 8
    world.ranges[30] = false
    addon.Range:Rebuild()

    equal(addon.Range:IsTooClose(10), true)
    equal(addon.Range:IsTooClose(30), true)
    equal(world.interactionCalls, 1)

    addon.Range:BeginUpdate()
    equal(addon.Range:IsTooClose(10), true)
    equal(world.interactionCalls, 2)
end)

test('interaction fallback uses mouseover only without a selected target', function()
    local world, addon = interactionSetup(true)
    world.exists = false
    world.mouseover = { exists = true, attackable = true, dead = false,
        ranges = { [10] = false, [20] = false, [40] = false } }
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), true)
    equal(world.interactionUnit, 'mouseover')
end)

test('friendly selected target blocks interaction fallback to mouseover', function()
    local world, addon = interactionSetup(true)
    world.attackable = false
    world.mouseover.exists = true
    world.mouseover.attackable = true
    addon.Range:BeginUpdate()

    equal(addon.Range:IsTooClose(10), false)
    equal(world.interactionCalls, 0)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
