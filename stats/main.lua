-- Moar Stats Please - entry point. Shared helpers, then the store, the schema, the trackers
-- and the UI surfaces.
--
-- Prefix `mstat`. `msp` belongs to Moar Stakes Please; the two ship together, so nothing
-- here may re-use that prefix.
--
-- The mod is read-only with respect to the run: it never spends money, moves a card or
-- consumes an RNG stream. Every hook wraps a vanilla function, records, and hands the
-- original result straight back.

MSP = MSP or {}

--============================================================
-- Number helpers
--============================================================
-- True for a plain Lua number OR a Talisman big number (a table: {sign=, array=, scale=}).
-- Must be tested before any type(v)=='table' branch, or a big number is walked into as if
-- its internal fields were data.
function MSP.isnum(v)
    if is_number then return is_number(v) end
    return type(v) == 'number'
end

-- Collapse a value (plain or Talisman big) to a plain Lua number, or nil if it isn't one.
-- Lua 5.1 raises "attempt to compare table with number" on a big-vs-plain comparison, so
-- arithmetic on a game value goes through here.
function MSP.plain(v)
    if type(v) == 'number' then return v end
    if to_number then
        local n = to_number(v)
        if type(n) == 'number' then return n end
    end
    return nil
end

-- Same, but never nil: unusable values read as 0 so a counter can always be added to.
function MSP.num(v, default)
    local n = MSP.plain(v)
    if n == nil or n ~= n then return default or 0 end   -- n ~= n catches NaN
    return n
end

--============================================================
-- Magnitudes
--============================================================
-- Balatro is LuaJIT, where math.log10 exists; 5.2 deprecated it and 5.4 removed it. The
-- fallback costs nothing and lets this file be exercised outside the game.
local LOG10 = math.log10 or function(x) return math.log(x) / math.log(10) end

-- A score record has to survive values past 1e308, where a plain double is +inf and every
-- later score compares equal to it. A magnitude keeps three fields:
--   num - the plain double when the value fits one, else nil
--   log - log10 of the value, which stays finite and ordered for any Talisman big
--   str - the display string, formatted once while the big number is still intact
-- Comparison is always on `log`; display is always `str`.
function MSP.mag(v)
    local m = { num = nil, log = -1e300, str = '0' }
    if v == nil then return m end

    local n = MSP.plain(v)
    if n and n == n and n ~= math.huge and n ~= -math.huge then
        m.num = n
        m.log = (n > 0) and LOG10(n) or ((n == 0) and -1e300 or -1e299)
    else
        -- Out of double range, so pull the exponent from Talisman's own representation.
        if type(v) == 'table' then
            local e = MSP.plain(v.array and v.array[1]) or nil
            local layer = MSP.plain(v.sign) and MSP.plain(v.array and v.array[2]) or nil
            -- array[1] is the log10 mantissa for a layer-1 big; deeper layers are already
            -- beyond anything a run reaches, so they sort above every layer-1 value.
            m.log = (layer and layer > 1) and 1e299 or (e or 1e299)
        else
            m.log = 1e299
        end
    end

    local ok, s = pcall(number_format, v)
    m.str = (ok and s) or tostring(m.num or '?')
    return m
end

-- True when `a` is the larger magnitude. Used for every record comparison.
function MSP.mag_gt(a, b)
    if not b then return true end
    if not a then return false end
    return (a.log or -1e300) > (b.log or -1e300)
end

--============================================================
-- Formatting
--============================================================
local function comma(n)
    local s = tostring(math.floor(n))
    local sign = ''
    if s:sub(1, 1) == '-' then sign, s = '-', s:sub(2) end
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    out = out:gsub('^,', '')
    return sign .. out
end

-- Renders one stat value for display. `fmt` comes from the schema entry.
function MSP.format(v, fmt)
    if fmt == 'score' then
        if type(v) == 'table' and v.str then return v.str end
        local ok, s = pcall(number_format, v)
        return (ok and s) or '0'
    end

    local n = MSP.num(v)
    if fmt == 'money' then
        return (n < 0 and '-$' or '$') .. comma(math.abs(n))
    elseif fmt == 'pct' then
        return string.format('%.1f%%', n)
    elseif fmt == 'x' then
        return string.format('%.2fx', n)
    elseif fmt == 'avg' then
        return string.format('%.2f', n)
    elseif fmt == 'time' then
        local t = math.floor(n)
        local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
        if h > 0 then return string.format('%dh %02dm', h, m) end
        if m > 0 then return string.format('%dm %02ds', m, s) end
        return s .. 's'
    end
    return comma(n)
end

-- Human date for a run record. os.date is available under LOVE.
function MSP.today()
    local ok, s = pcall(os.date, '%Y-%m-%d')
    return (ok and s) or '?'
end

--============================================================
-- Content
--============================================================
assert(SMODS.load_file('stats/schema.lua'))()
assert(SMODS.load_file('stats/store.lua'))()
assert(SMODS.load_file('stats/track.lua'))()
assert(SMODS.load_file('stats/ui.lua'))()
assert(SMODS.load_file('stats/grid.lua'))()   -- after ui.lua: uses MSP.scrolled and MSP.view

--============================================================
-- Config tab (SMODS mod menu)
--============================================================
-- SMODS loads config.lua as defaults, overlays the saved config, and saves on menu exit.
-- MSP.CFG mirrors the live config so the rest of the code reads one place.
MSP.mod = SMODS.current_mod

-- Must agree with config.lua, which is what SMODS actually loads as the defaults. This is
-- the safety net underneath it: SMODS overlays the SAVED config on top, and a config saved
-- by an earlier version has no key for an option added since. Filling in only the missing
-- keys means a new option starts at its default instead of reading nil and silently
-- disabling whatever it gates - the same additive rule the stat store follows.
local DEFAULTS = { run_tab = true, game_over_rows = true, run_log = true, run_log_max = 0 }

MSP.CFG = SMODS.current_mod.config or {}
for k, v in pairs(DEFAULTS) do
    if MSP.CFG[k] == nil then MSP.CFG[k] = v end
end
SMODS.current_mod.config = MSP.CFG

SMODS.current_mod.config_tab = function()
    local cfg = MSP.CFG
    local function toggle(label, ref)
        return { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            create_toggle({ label = label, ref_table = cfg, ref_value = ref, w = 0, scale = 0.9, text_scale = 0.4 }),
        }}
    end

    return { n = G.UIT.ROOT, config = { align = 'cm', minh = 4, minw = 8, padding = 0.1, r = 0.1, colour = G.C.CLEAR }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Moar Stats Please', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }},
        toggle('Stats tab in Run Info', 'run_tab'),
        toggle('Extra rows on the Game Over screen', 'game_over_rows'),
        toggle('Keep a history of finished runs', 'run_log'),
        { n = G.UIT.R, config = { align = 'cm', padding = 0.15 }, nodes = {
            UIBox_button({
                label = { 'Career Stats' },
                button = 'mstat_open_career',
                colour = G.C.GREEN, minw = 4, minh = 0.6, scale = 0.4,
            }),
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.08, maxw = 7 }, nodes = {
            { n = G.UIT.T, config = { text = 'Career stats are kept per profile, split across normal and seeded runs.',
                                      scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
        }},
    }}
end
