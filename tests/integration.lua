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
    world.main = world:button('ActionButton1', 1)
    world.side = world:button('MultiBarLeftButton7', 67)
    world.actions = { [1] = { 'spell', 10 }, [67] = { 'spell', 10 } }
    if configure then configure(world) end

    local manifest = io.open('HunterAssistForever/HunterAssistForever.toc')
    assert(manifest, 'addon manifest is not implemented')
    for line in manifest:lines() do
        if line:match('%.lua$') then
            local chunk = assert(loadfile('HunterAssistForever/' .. line, 't', world.env))
            chunk('HunterAssistForever', world.addon)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')
    return world, world.addon
end

local function tinted(button)
    equal(button.icon.desaturation, 1, 'icon must be desaturated')
    equal(button.icon.color[1], 1, 'red component')
    equal(button.icon.color[2], 0.25, 'green component')
    equal(button.icon.color[3], 0.25, 'blue component')
end

local function native(button)
    equal(button.icon.desaturation, 0, 'icon saturation restored')
    equal(button.icon.color[1], 1)
    equal(button.icon.color[2], 1)
    equal(button.icon.color[3], 1)
end

test('login colors a shot on both main and side bars', function()
    local world = setup()

    tinted(world.main)
    tinted(world.side)
    equal(world.queries[10], 1, 'duplicate abilities share queries')
end)

test('all eight default bar prefixes participate', function()
    local prefixes = { 'ActionButton', 'MultiBarBottomLeftButton', 'MultiBarBottomRightButton',
        'MultiBarRightButton', 'MultiBarLeftButton', 'MultiBar5Button', 'MultiBar6Button', 'MultiBar7Button' }
    local world = setup(function(w)
        for index, prefix in ipairs(prefixes) do
            w:button(prefix .. '12', index + 100)
            w.actions[index + 100] = { 'spell', 10 }
        end
    end)

    for _, prefix in ipairs(prefixes) do tinted(world.env[prefix .. '12']) end
end)

test('custom bars are left untouched', function()
    local world = setup(function(w)
        w.custom = w:button('BT4Button1', 1)
    end)

    native(world.custom)
end)

test('far target restores all tracked icons', function()
    local world = setup()
    world.ranges[20] = false

    world:tick(0.1)

    native(world.main)
    native(world.side)
end)

test('new target clears prior evidence immediately', function()
    local world = setup()
    world.exists = false

    world:fire('PLAYER_TARGET_CHANGED')

    native(world.main)
    native(world.side)
end)

test('paged main slot becomes melee without tinting the melee action', function()
    local world = setup()
    world.actions[13] = { 'spell', 40 }
    world.main.action = 13

    world:fire('ACTIONBAR_PAGE_CHANGED')
    world:tick(0.1)

    native(world.main)
    tinted(world.side)
end)

test('replacing spell in the same slot removes tint', function()
    local world = setup()
    world.actions[67] = { 'item', 10 }

    world:fire('ACTIONBAR_SLOT_CHANGED', 67)
    world:tick(0.1)

    native(world.side)
end)

test('macro follows the client-reported displayed spell', function()
    local world = setup(function(w)
        w.actions[67] = { 'macro', 10, 'spell' }
    end)
    tinted(world.side)
    world.actions[67] = { 'macro', 40, 'spell' }

    world:tick(0.1)

    native(world.side)
end)

test('unknown macro payload is not confused with a spell ID', function()
    local world = setup(function(w)
        w.actions[67] = { 'macro', 10 }
    end)

    native(world.side)
end)

test('restricted action identifiers clear previous tint', function()
    local world = setup()
    world.actions[67] = { 'spell', world.secret }

    world:tick(0.1)

    native(world.side)
end)

test('hidden button releases its tint', function()
    local world = setup()
    world.side:Hide()

    world:tick(0.1)

    native(world.side)
end)

test('native color updates retain red but restore the latest mana color', function()
    local world, addon = setup()
    world.side.icon:SetVertexColor(0.5, 0.5, 1, 0.8)
    tinted(world.side)

    addon.Config.Set('deadzoneSaturation', false)

    equal(world.side.icon.color[1], 0.5)
    equal(world.side.icon.color[2], 0.5)
    equal(world.side.icon.color[3], 1)
    equal(world.side.icon.color[4], 0.8)
    equal(world.side.icon.desaturation, 0)
end)

test('native desaturation refresh does not erase an active tint', function()
    local world = setup()

    world.side.icon:SetDesaturated(false)

    tinted(world.side)
end)

test('partial native desaturation is restored on disable', function()
    local world, addon = setup()
    world.side.icon:SetDesaturation(0.4)

    addon.Config.Set('deadzoneSaturation', false)

    equal(world.side.icon.desaturation, 0.4)
end)

test('unchanged range polls do not rewrite icon textures', function()
    local world = setup()
    local writes = world.side.icon.writes

    for _ = 1, 20 do world:tick(0.1) end

    equal(world.side.icon.writes, writes)
    equal(world.bookReads, 1, 'spellbook is not rescanned by polling')
end)

test('updates are throttled rather than running on every frame', function()
    local world = setup()
    local queries = world.queries[10]

    world:tick(0.02)
    world:tick(0.02)
    world:tick(0.02)

    equal(world.queries[10], queries)
    world:tick(0.05)
    equal(world.queries[10], queries + 1)
end)

test('checkbox defaults on and switches coloring immediately', function()
    local world, addon = setup()
    local check = addon.SettingsPanel.controls.deadzoneSaturation
    equal(check:GetChecked(), true)
    check:SetChecked(false)

    check.scripts.OnClick(check)

    native(world.main)
    native(world.side)
    equal(world.env.HunterAssistForeverDB.deadzoneSaturation, false)
    check:SetChecked(true)
    check.scripts.OnClick(check)
    tinted(world.side)
end)

test('disabled checkbox stops range polling', function()
    local world, addon = setup()
    addon.Config.Set('deadzoneSaturation', false)
    local queries = world.queries[10]

    for _ = 1, 100 do world:tick(0.1) end

    equal(world.queries[10], queries)
    native(world.side)
end)

test('saved disabled preference survives initialization and reenable discovers bars', function()
    local world, addon = setup(function(w)
        w.env.HunterAssistForeverDB = { deadzoneSaturation = false }
    end)
    native(world.main)
    equal(next(world.queries), nil)
    equal(addon.SettingsPanel.controls.deadzoneSaturation:GetChecked(), false)

    addon.Config.Set('deadzoneSaturation', true)

    tinted(world.side)
end)

test('invalid saved setting gets the enabled default', function()
    local world, addon = setup(function(w)
        w.env.HunterAssistForeverDB = { deadzoneSaturation = 'false' }
    end)

    equal(addon.Config.Get('deadzoneSaturation'), true)
    tinted(world.side)
end)

test('settings contain one checkbox inside Range checks', function()
    local _, addon = setup()
    local panel = addon.SettingsPanel
    local count = 0
    for _ in pairs(panel.controls) do count = count + 1 end

    equal(count, 1)
    equal(#panel.sections, 1)
    equal(panel.controls.deadzoneSaturation.Text.text, 'Deadzone saturation')
    equal(panel.controls.deadzoneSaturation.parent, panel.sections[1])
    equal(panel.sections[1].children[1].text, 'Range checks')
end)

test('slash config command opens registered native category', function()
    local world = setup()

    world.env.SlashCmdList.HUNTERASSISTFOREVER(' config ')

    equal(world.openCategory, 123)
end)

test('non-hunter gets settings but no feature updates', function()
    local world, addon = setup(function(w) w.class = 'PALADIN' end)

    world:tick(1)
    addon.Config.Set('deadzoneSaturation', false)
    addon.Config.Set('deadzoneSaturation', true)

    native(world.main)
    equal(next(world.queries), nil)
    equal(world.bookReads, 0)
    assert(addon.SettingsPanel.category)
end)

test('late-created button waits for combat to end before preparing hooks', function()
    local world = setup()
    world.combat = true
    local late = world:button('MultiBar7Button8', 88)
    world.actions[88] = { 'spell', 10 }
    world:tick(0.5)
    native(late)
    world.combat = false

    world:fire('PLAYER_REGEN_ENABLED')

    tinted(late)
end)

test('prepared buttons continue updating in combat', function()
    local world = setup()
    world.combat = true
    world.ranges[10] = true
    world:tick(0.1)
    native(world.side)
    world.ranges[10] = false

    world:tick(0.1)

    tinted(world.side)
end)

test('newly learned probe is picked up after spellbook event', function()
    local world = setup(function(w) w.learned = { 10, 30 } end)
    native(world.side)
    world.learned = { 10, 20, 30 }

    world:fire('SPELLS_CHANGED')
    world:tick(0.1)

    tinted(world.side)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
