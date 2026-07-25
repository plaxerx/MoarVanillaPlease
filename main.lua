-- Moar Vanilla Please - entry point
--
-- Registers the shared atlas and helpers, then loads each content file. This was
-- jokers.lua until the Jokers were dropped; the helpers below are what the surviving
-- content (decks, stakes, challenges) still depends on, so they live here rather than
-- inside any one of them.

--============================================================
-- Atlas
--============================================================
-- Named for the Jokers it originally held. The Jokers are gone, but the sheet still
-- carries the Prismatic deck back at (0,2) and the file is still eeng_jokers.png, so
-- the key stays as-is: renaming it would mean renaming the art for no gain.
SMODS.Atlas{
    key = 'eeng_jokers',
    path = 'eeng_jokers.png',
    px = 71,
    py = 95,
}

--============================================================
-- Shared helpers
--============================================================
EEng = EEng or {}

-- CRITICAL (Talisman): a "number" may be a plain Lua number OR a Talisman big number,
-- which is a TABLE ({sign=, array=, scale=}). is_number() is true for BOTH, so it must be
-- tested before any type(v)=='table' branch - otherwise a big number looks like a plain
-- container and gets walked into as if its internal sign/scale fields were data.
function EEng.isnum(v)
    if is_number then return is_number(v) end
    return type(v) == 'number'
end

-- Collapse a value (plain or Talisman big) to a plain Lua number, or nil if it isn't one.
-- Lua 5.1 raises "attempt to compare table with number" on a big-vs-plain comparison with
-- no chance for a metamethod, so anything doing arithmetic on a game value goes through here.
function EEng.plain(v)
    if type(v) == 'number' then return v end
    if to_number then
        local n = to_number(v)
        if type(n) == 'number' then return n end
    end
    return nil
end

--============================================================
-- Content
--============================================================
assert(SMODS.load_file('decks.lua'))()
assert(SMODS.load_file('stakes.lua'))()
assert(SMODS.load_file('challenges.lua'))()
assert(SMODS.load_file('erratic.lua'))()
assert(SMODS.load_file('peek.lua'))()

--============================================================
-- Config tab (SMODS mod menu)
--============================================================
-- SMODS loads config.lua as defaults, overlays the saved config, and saves on menu exit.
-- config_tab returns the UI for the mod's config page. EEng.CFG mirrors the live config
-- so the rest of the code reads one place.
EEng.mod = SMODS.current_mod
-- config.lua provides the defaults; SMODS overlays the saved config. Fallback in case a
-- SMODS build hasn't populated it yet, so peek.lua never indexes nil.
EEng.CFG = SMODS.current_mod.config or { peek_mode = 2, peek_depth = 5 }
SMODS.current_mod.config = EEng.CFG

local PEEK_MODE_OPTS = { 'Off', 'Endless & Seeded', 'Always (debug)' }

SMODS.current_mod.config_tab = function()
    local cfg = EEng.CFG
    return { n = G.UIT.ROOT, config = { align = 'cm', minh = 4, minw = 8, padding = 0.1, r = 0.1, colour = G.C.CLEAR }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Peek Store', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            create_option_cycle({
                label = 'When available',
                options = PEEK_MODE_OPTS,
                current_option = math.min(3, math.max(1, cfg.peek_mode or 2)),
                w = 4.5, scale = 0.9, text_scale = 0.4,
                ref_table = cfg, ref_value = 'peek_mode',
                opt_callback = 'eeng_config_saved',
            }),
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            create_option_cycle({
                label = 'Rerolls to look ahead',
                options = { '3', '5', '8' },
                current_option = ({ [3] = 1, [5] = 2, [8] = 3 })[cfg.peek_depth or 5] or 2,
                w = 4.5, scale = 0.9, text_scale = 0.4,
                ref_table = cfg, ref_value = 'peek_depth_idx',
                opt_callback = 'eeng_peek_depth_saved',
            }),
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.08, maxw = 7 }, nodes = {
            { n = G.UIT.T, config = { text = 'Shows upcoming shop cards in future rerolls, with the cost to reach them.',
                                      scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
        }},
    }}
end

-- create_option_cycle does NOT auto-write ref_table[ref_value]; it calls the callback with
-- the new option index in `to_key`. So the callbacks write the config themselves.
G.FUNCS.eeng_config_saved = function(e)
    EEng.CFG.peek_mode = (e and e.to_key) or EEng.CFG.peek_mode
    if SMODS.save_mod_config then SMODS.save_mod_config(EEng.mod) end
end

G.FUNCS.eeng_peek_depth_saved = function(e)
    EEng.CFG.peek_depth = ({ 3, 5, 8 })[(e and e.to_key) or 2] or 5
    if SMODS.save_mod_config then SMODS.save_mod_config(EEng.mod) end
end
