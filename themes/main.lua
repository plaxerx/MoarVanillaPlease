-- Moar Themes Please - entry point. The palette, theme storage, then the menu.
--
-- Prefix `mtp`. Every color change is a write into the game's own G.C tables, so the mod
-- never touches a run: a seeded run plays identically with any theme.

MTP = MTP or {}
MTP.current = MTP.current or {}
MTP.current_name = MTP.current_name or 'Standard'

assert(SMODS.load_file('themes/palette.lua'))()
assert(SMODS.load_file('themes/themes.lua'))()
assert(SMODS.load_file('themes/stock.lua'))()
assert(SMODS.load_file('themes/ui.lua'))()

--============================================================
-- Config
--============================================================
MTP.mod = SMODS.current_mod

-- Must agree with config.lua. Fills keys a config saved by an earlier version lacks.
local DEFAULTS = { active = '', advanced = false }

MTP.CFG = SMODS.current_mod.config or {}
for k, v in pairs(DEFAULTS) do
    if MTP.CFG[k] == nil then MTP.CFG[k] = v end
end
SMODS.current_mod.config = MTP.CFG

--============================================================
-- Boot
--============================================================
-- The saved theme goes on once every mod has injected, so modded colors are found and
-- snapshotted at their Standard value first. Game:splash_screen is the first thing start_up
-- runs after initSteamodded (game.lua:212-217), and the splash itself is drawn in G.C.BLUE.
function MTP.boot()
    if MTP.booted then return end
    MTP.booted = true
    local overrides, name = MTP.decode(MTP.CFG.active)
    -- An unedited stock theme is re-read from the shipped version, so a mod update reaches it.
    local stock = MTP.stock(name)
    MTP.current = (not stock and overrides) or {}
    MTP.scan()
    if stock then
        MTP.apply(MTP.stock_overrides(stock), stock.name)
    else
        MTP.apply(overrides or {}, name or MTP.STANDARD)
    end
    MTP.dirty = false
    MTP.write_template()
end

local splash_screen_ref = Game.splash_screen
function Game:splash_screen(...)
    local ok, err = pcall(MTP.boot)
    if not ok then print('[MoarThemesPlease] boot failed: ' .. tostring(err)) end
    return splash_screen_ref(self, ...)
end

--============================================================
-- Config tab (SMODS mod menu)
--============================================================
SMODS.current_mod.config_tab = function()
    return { n = G.UIT.ROOT, config = { align = 'cm', minh = 3, minw = 8, padding = 0.1, r = 0.1, colour = G.C.CLEAR }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Moar Themes Please', scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = 'Theme: ' .. (MTP.current_name or 'Standard'), scale = 0.35, colour = G.C.UI.TEXT_LIGHT } },
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.15 }, nodes = {
            UIBox_button({ label = { 'Themes' }, button = 'mtp_open_from_mods', colour = G.C.PURPLE, minw = 4, minh = 0.6, scale = 0.4 }),
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.08, maxw = 7 }, nodes = {
            { n = G.UIT.T, config = { text = 'Also under Settings > Video > Themes.', scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
        }},
    }}
end
