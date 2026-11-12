-- Moar Vanilla Please - entry point. Registers the shared atlas and helpers, then loads
-- each content file.
--
-- Prefix `mvp`, distinct from Endless Engines' `eeng`: the two mods are designed to run
-- side by side, so nothing here may re-declare content that lives over there.

--============================================================
-- Atlas
--============================================================
-- Holds the Prismatic deck back, the mod's only deck skin.
SMODS.Atlas{
    key = 'mvp_decks',
    path = 'mvp_decks.png',
    px = 71,
    py = 95,
}

--============================================================
-- Shared helpers
--============================================================
MVP = MVP or {}

-- True for a plain Lua number OR a Talisman big number (a table: {sign=, array=, scale=}).
-- Must be tested before any type(v)=='table' branch, or a big number is walked into as if
-- its internal fields were data.
function MVP.isnum(v)
    if is_number then return is_number(v) end
    return type(v) == 'number'
end

-- Collapse a value (plain or Talisman big) to a plain Lua number, or nil if it isn't one.
-- Lua 5.1 raises "attempt to compare table with number" on a big-vs-plain comparison, so
-- arithmetic on a game value goes through here.
function MVP.plain(v)
    if type(v) == 'number' then return v end
    if to_number then
        local n = to_number(v)
        if type(n) == 'number' then return n end
    end
    return nil
end

-- True when the run in progress started on `back_key`.
--
-- Reads the deck the run actually began with. CardSleeves' get_current_deck_key() is a MENU
-- query - it consults collection and hover state - so it is right inside loc_vars and wrong
-- inside apply. It is kept only as a fallback for the deck-select screen, before G.GAME
-- carries a deck. Sleeves apply from Back:apply_to_run (CardSleeves.lua:1971), which runs
-- after G.GAME.selected_back is assigned, so the primary path is always available there.
--
-- G.GAME.selected_back_key is NOT a key string despite the name: game.lua assigns it the
-- return of get_deck_from_name(), which hands back the CENTER TABLE (common_events.lua:2245
-- `if v.name == _name then return v end`). Comparing it directly to a string is always
-- false, which silently disabled the deck+sleeve combo. Both forms are handled here in case
-- a build or another mod stores the string instead.
function MVP.on_deck(back_key)
    local g = G.GAME
    if not g then return false end

    local b = g.selected_back
    local k = b and b.effect and b.effect.center and b.effect.center.key
    if k then return k == back_key end

    local sbk = g.selected_back_key
    if type(sbk) == 'table' then return sbk.key == back_key end
    if type(sbk) == 'string' then return sbk == back_key end

    if CardSleeves and CardSleeves.Sleeve and CardSleeves.Sleeve.get_current_deck_key then
        local ok, cur = pcall(CardSleeves.Sleeve.get_current_deck_key)
        if ok then return cur == back_key end
    end
    return false
end

--============================================================
-- Content
--============================================================
assert(SMODS.load_file('decks.lua'))()
assert(SMODS.load_file('stakes.lua'))()
assert(SMODS.load_file('challenges.lua'))()
assert(SMODS.load_file('sandbox.lua'))()
assert(SMODS.load_file('erratic.lua'))()
assert(SMODS.load_file('peek.lua'))()

--============================================================
-- Whole mods
--============================================================
-- Moar Themes, Moar Stats and Steady Frames run unchanged from their subfolders. Each sets
-- SMODS.current_mod.config_tab for its standalone menu; those become the bundle's extra
-- tabs, and the Peek Store tab below stays the bundle's main one.
assert(SMODS.load_file('themes/main.lua'))()
local themes_tab = SMODS.current_mod.config_tab
assert(SMODS.load_file('stats/main.lua'))()
local stats_tab = SMODS.current_mod.config_tab
assert(SMODS.load_file('steadyframes/main.lua'))()

SMODS.current_mod.extra_tabs = function()
    return {
        { label = 'Themes', tab_definition_function = themes_tab },
        { label = 'Stats', tab_definition_function = stats_tab },
    }
end

--============================================================
-- Config tab (SMODS mod menu)
--============================================================
-- SMODS loads config.lua as defaults, overlays the saved config, and saves on menu exit.
-- MVP.CFG mirrors the live config so the rest of the code reads one place.
MVP.mod = SMODS.current_mod
-- Fallback in case a SMODS build hasn't populated the config yet, so peek.lua never
-- indexes nil.
MVP.CFG = SMODS.current_mod.config or { peek_mode = 1, peek_depth = 5 }
SMODS.current_mod.config = MVP.CFG

local PEEK_MODE_OPTS = { 'Off', 'Endless & Seeded', 'Always (debug)' }

SMODS.current_mod.config_tab = function()
    local cfg = MVP.CFG
    return { n = G.UIT.ROOT, config = { align = 'cm', minh = 4, minw = 8, padding = 0.1, r = 0.1, colour = G.C.CLEAR }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Peek Store', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            create_option_cycle({
                label = 'When available',
                options = PEEK_MODE_OPTS,
                current_option = math.min(3, math.max(1, cfg.peek_mode or 1)),
                w = 4.5, scale = 0.9, text_scale = 0.4,
                ref_table = cfg, ref_value = 'peek_mode',
                opt_callback = 'mvp_config_saved',
            }),
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            create_option_cycle({
                label = 'Rerolls to look ahead',
                options = { '3', '5', '8' },
                current_option = ({ [3] = 1, [5] = 2, [8] = 3 })[cfg.peek_depth or 5] or 2,
                w = 4.5, scale = 0.9, text_scale = 0.4,
                ref_table = cfg, ref_value = 'peek_depth_idx',
                opt_callback = 'mvp_peek_depth_saved',
            }),
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.08, maxw = 7 }, nodes = {
            { n = G.UIT.T, config = { text = 'Shows upcoming shop cards in future rerolls with the costs to reach them.',
                                      scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
        }},
    }}
end

-- create_option_cycle does not auto-write ref_table[ref_value]; it calls the callback with
-- the new option index in `to_key`, so the callbacks write the config themselves.
G.FUNCS.mvp_config_saved = function(e)
    MVP.CFG.peek_mode = (e and e.to_key) or MVP.CFG.peek_mode
    if SMODS.save_mod_config then SMODS.save_mod_config(MVP.mod) end
end

G.FUNCS.mvp_peek_depth_saved = function(e)
    MVP.CFG.peek_depth = ({ 3, 5, 8 })[(e and e.to_key) or 2] or 5
    if SMODS.save_mod_config then SMODS.save_mod_config(MVP.mod) end
end
