-- Exercise the real bundled renderer and adapter. Only WoW UI/pool APIs are
-- simulated; this cannot verify actual texture rendering in the game client.
_G.strmatch = string.match
_G.WOW_PROJECT_ID = 1
_G.WOW_PROJECT_MAINLINE = 1
local inCombat = false
_G.InCombatLockdown = function() return inCombat end

local Object = {}
Object.__index = Object
local function object(parent)
    return setmetatable({ parent = parent, scripts = {}, shown = false, level = 1, width = 36, height = 36 }, Object)
end

function Object:SetPoint() end
function Object:ClearAllPoints() end
function Object:SetAllPoints() end
function Object:EnableMouse() end
function Object:SetBlendMode() end
function Object:SetAlpha() end
function Object:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Object:SetDesaturated(value) self.desaturated = value end
function Object:SetAtlas(atlas) self.atlas = atlas end
function Object:SetSize(width, height) self.width, self.height = width, height end
function Object:GetSize() return self.width, self.height end
function Object:SetFrameLevel(level) self.level = level end
function Object:GetFrameLevel() return self.level end
function Object:SetParent(parent) self.parent = parent end
function Object:GetParent() return self.parent end
function Object:SetScript(event, callback) self.scripts[event] = callback end
function Object:Show()
    if self.shown then return end

    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Object:Hide()
    if not self.shown then return end

    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Object:SetShown(shown)
    if shown then self:Show() else self:Hide() end
end
function Object:CreateTexture() return object(self) end

local Animation = {}
Animation.__index = Animation
function Animation:SetChildKey() end
function Animation:SetFromAlpha() end
function Animation:SetToAlpha() end
function Animation:SetDuration() end
function Animation:SetOrder() end
function Animation:SetFlipBookRows() end
function Animation:SetFlipBookColumns() end
function Animation:SetFlipBookFrames() end
function Animation:SetFlipBookFrameWidth() end
function Animation:SetFlipBookFrameHeight() end

function Object:CreateAnimationGroup()
    local group = object(self)
    function group:SetLooping() end
    function group:SetToFinalAlpha() end
    function group:CreateAnimation() return setmetatable({}, Animation) end
    function group:Play() self.playing = true; self.plays = (self.plays or 0) + 1 end
    function group:Stop() self.playing = false end
    function group:IsPlaying() return self.playing == true end

    return group
end

_G.UIParent = object()
_G.CreateFrame = function(_, _, parent) return object(parent) end
_G.CreateTexturePool = function() return {} end
_G.CreateFramePool = function(_, parent, _, resetter)
    local pool = { active = {}, free = {} }
    function pool:Acquire()
        local frame = table.remove(self.free)
        local fresh = frame == nil
        frame = frame or object(parent)
        self.active[frame] = true

        return frame, fresh
    end
    function pool:Release(frame)
        assert(self.active[frame], 'releasing a frame not owned by this pool')
        resetter(self, frame)
        self.active[frame] = nil
        self.free[#self.free + 1] = frame
    end

    return pool
end

-- Load libraries in their actual manifest order, then the real glow adapter.
local addon = {}
for line in io.lines('HunterAssistForever/HunterAssistForever.toc') do
    if line:match('^Libs/.*%.lua$') or line == 'Services/Glow.lua' then
        assert(loadfile('HunterAssistForever/' .. line))('HunterAssistForever', addon)
    end
end
local library, minor = LibStub('LibCustomGlow-1.0')
assert(minor == 25)
local target = object(UIParent)
local entry = addon.Glow.Prepare(target)
assert(not entry.frame.shown)

inCombat = true
addon.Glow.Set(target, 'first', true)
local proc = entry.frame._ProcGlowHunterAssistForever
assert(proc and proc.ProcStartAnim:IsPlaying(), 'real proc start animation must run')
assert(proc.ProcStart.atlas == 'UI-HUD-ActionBar-Proc-Start-Flipbook')
assert(proc.ProcLoop.atlas == 'UI-HUD-ActionBar-Proc-Loop-Flipbook')
assert(entry.frame.shown)
print('PASS bundled renderer starts native proc animation on addon overlay')

addon.Glow.Set(target, 'first', true)
addon.Glow.Set(target, 'second', true)
addon.Glow.Set(target, 'first', false)
assert(proc.ProcStartAnim.plays == 1, 'updates must not restart the animation')
assert(library.ProcGlowPool.active[proc])
print('PASS polling and shared ownership retain the same running effect')

addon.Glow.Configure({ color = { 1, 0, 0, 1 } })
assert(entry.frame._ProcGlowHunterAssistForever == proc)
assert(proc.ProcStart.color[1] == 1 and proc.ProcStart.color[2] == 0)
assert(proc.ProcLoop.color[1] == 1 and proc.ProcLoop.color[3] == 0)
assert(proc.ProcStart.desaturated == 1 and proc.ProcLoop.desaturated == 1)
assert(proc.ProcStartAnim.plays == 1, 'recoloring must not replay the start flash')
print('PASS active custom color updates actual library textures without restarting')

addon.Glow.Configure({})
assert(proc.ProcStart.desaturated == nil and proc.ProcLoop.desaturated == nil)
assert(proc.ProcStart.color[1] == 1 and proc.ProcStart.color[2] == 1 and proc.ProcStart.color[3] == 1)
assert(proc.ProcStartAnim.plays == 1)
print('PASS native mode restores original artwork without restarting')

addon.Glow.ConfigureOwner('seal', { color = { 1, 0, 0, 1 }, priority = 10 })
addon.Glow.Set(target, 'seal', true)
assert(entry.frame._ProcGlowHunterAssistForever == proc)
assert(proc.ProcLoop.color[1] == 1 and proc.ProcLoop.color[2] == 0)
assert(proc.ProcStartAnim.plays == 1)
addon.Glow.Configure({ color = { 0, 0, 1, 1 } })
assert(proc.ProcLoop.color[1] == 1 and proc.ProcLoop.color[3] == 0)
addon.Glow.ClearOwner('seal')
assert(proc.ProcLoop.color[1] == 0 and proc.ProcLoop.color[3] == 1)
assert(proc.ProcStartAnim.plays == 1)
addon.Glow.Configure({})
assert(proc.ProcLoop.desaturated == nil)
print('PASS owner priority changes tint and restores remaining owner without replay')

proc.ProcStartAnim:Stop()
proc.ProcStartAnim.scripts.OnFinished(proc.ProcStartAnim)
assert(proc.ProcLoopAnim:IsPlaying())
addon.Glow.ClearOwner('second')
assert(not entry.frame.shown)
assert(not proc.ProcLoopAnim:IsPlaying())
assert(entry.frame._ProcGlowHunterAssistForever == nil)
assert(not library.ProcGlowPool.active[proc])
print('PASS clearing last owner stops looping animation and releases library frame')

addon.Glow.Set(target, 'first', true)
assert(entry.frame._ProcGlowHunterAssistForever == proc)
assert(proc.ProcStartAnim:IsPlaying())
addon.Glow.ClearOwner('first')
print('PASS subsequent activation reuses the library pool safely')

-- Loop-only requests must skip the actual library startup animation.
local flashes = proc.ProcStartAnim.plays
addon.Glow.Set(target, 'seal', true, { startAnim = false })
assert(proc.ProcStartAnim.plays == flashes)
assert(not proc.ProcStartAnim:IsPlaying())
assert(proc.ProcLoopAnim:IsPlaying())
local loops = proc.ProcLoopAnim.plays
addon.Glow.Set(target, 'seal', true, { startAnim = false })
assert(proc.ProcLoopAnim.plays == loops)
addon.Glow.Set(target, 'seal', true, { startAnim = true })
assert(proc.ProcStartAnim.plays == flashes, 'entering combat must not reflash an existing glow')
assert(proc.ProcLoopAnim:IsPlaying())
addon.Glow.ClearOwner('seal')
print('PASS loop-only activation skips flash and combat entry preserves loop')

addon.Glow.Set(target, 'seal', true, { startAnim = true })
assert(proc.ProcStartAnim:IsPlaying())
flashes = proc.ProcStartAnim.plays
addon.Glow.Set(target, 'seal', true, { startAnim = false })
assert(not proc.ProcStartAnim:IsPlaying(), 'combat exit must cancel an in-flight flash')
assert(proc.ProcStartAnim.plays == flashes)
assert(proc.ProcLoopAnim:IsPlaying())
assert(not proc.ProcStart.shown and proc.ProcLoop.shown)
addon.Glow.ClearOwner('seal')
print('PASS disabling flash cancels startup and immediately starts the loop')

-- Loading our bundled copies after another copy must preserve the live library.
assert(loadfile('HunterAssistForever/Libs/LibStub/LibStub.lua'))()
assert(loadfile('HunterAssistForever/Libs/LibCustomGlow-1.0/LibCustomGlow-1.0.lua'))()
assert(LibStub('LibCustomGlow-1.0') == library)
print('PASS duplicate library loading preserves the registered library')
print('\n10 integration checks passed')
