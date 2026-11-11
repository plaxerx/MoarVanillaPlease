-- Steady Frames: keeps Lua's garbage collector ahead of the game, so the frame rate holds
-- over a long session instead of sliding until a trip to the main menu resets it.
--
-- WHY THE GAME SLOWS DOWN
-- Game:update calls nuGC(nil, nil, true) every frame (game.lua:2584). nuGC
-- (misc_functions.lua:705) steps the collector for a FIXED 0.3 ms, stops automatic
-- collection for the rest of the frame, and does a full collect whenever the heap passes
-- 300 MB. When the game, and mods such as Amulet's big numbers, make garbage faster than
-- 0.3 ms a frame clears, the heap creeps up all run. Every step then walks a bigger heap,
-- and once the live data sits near 300 MB the safety net fires full collects over and over,
-- each a visible stall.
--
-- WHAT THIS CHANGES
--   1. The step budget scales with how far the heap has grown past what was live after the
--      last full collect: vanilla's 0.3 ms when there is little garbage, up to MAX_BUDGET.
--   2. A full collect runs at moments where a short pause can't be felt - arriving at the
--      shop or the Blind select - once the heap has grown QUIET_GROWTH past that baseline.
--   3. The safety-net ceiling follows the live data instead of sitting at a flat 300 MB, so a
--      big modded run can't land in a full collect every frame.
-- nuGC itself still runs; only its arguments change.

SteadyFrames = SteadyFrames or {}

local VANILLA_BUDGET = 3e-4     -- seconds per frame, nuGC's own default
local MAX_BUDGET     = 2e-3     -- the most a frame ever spends collecting
local SCALE          = 4        -- budget multiplier per baseline's worth of garbage
local QUIET_GROWTH   = 48       -- MB of growth before a quiet-moment full collect
local CEILING_FLOOR  = 300      -- MB, vanilla's ceiling
local CEILING_ROOM   = 256      -- MB of headroom over the live data

local stats = { budget = VANILLA_BUDGET, full = 0, last_ms = 0, baseline = nil }
SteadyFrames.stats = stats

local function mem_mb() return collectgarbage('count') / 1024 end

local function full_collect()
    local t0 = love.timer.getTime()
    collectgarbage('collect')
    stats.last_ms = (love.timer.getTime() - t0) * 1000
    stats.full = stats.full + 1
    stats.baseline = mem_mb()
    collectgarbage('stop')      -- nuGC's contract: no automatic collection between frames
end

local sf_nuGC = nuGC
function nuGC(time_budget, memory_ceiling, disable_otherwise)
    local mem = mem_mb()
    stats.baseline = stats.baseline or mem
    local base = stats.baseline
    local garbage = math.max(0, mem - base)
    stats.budget = math.min(MAX_BUDGET,
        (time_budget or VANILLA_BUDGET) * (1 + SCALE * garbage / math.max(base, 1)))
    local ceiling = math.max(memory_ceiling or CEILING_FLOOR, base + CEILING_ROOM)
    return sf_nuGC(stats.budget, ceiling, disable_otherwise)
end

-- Arriving at the shop or the Blind select: the screen is moving anyway.
local STATES = (G and G.STATES) or {}
local QUIET = { [STATES.SHOP or 5] = true, [STATES.BLIND_SELECT or 7] = true }
local last_state
local sf_update = Game.update
function Game:update(dt)
    sf_update(self, dt)
    local state = self.STATE
    if state ~= last_state then
        last_state = state
        if QUIET[state] and stats.baseline and mem_mb() - stats.baseline >= QUIET_GROWTH then
            full_collect()
        end
    end
end

-- Leaving a run frees a whole run's worth of objects; start the next one from a clean heap.
local sf_delete_run = Game.delete_run
function Game:delete_run(...)
    local r = sf_delete_run(self, ...)
    full_collect()
    return r
end
