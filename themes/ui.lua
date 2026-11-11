-- Moar Themes Please - the Themes menu.
--
--   Settings > Video > Themes opens it. Left: the palette as a grid of live swatches - the
--   nineteen Basic colors by default, every group one at a time in Advanced mode. Right: the
--   selected color, with RGBA sliders and hex copy / paste. Bottom: the theme itself - name,
--   save, load, share code, reset.
--
-- The menu's own buttons and text are drawn in Standard colors, never the live ones: a theme
-- that makes text unreadable must not also make the Reset button unreadable.

local COLS, ROWS = 4, 5
local PER_PAGE = COLS * ROWS

MTP.view = MTP.view or { group = 1, page = 1, key = nil, pick = 1, name = '', status = '', host = 'settings' }
MTP.edit = MTP.edit or { r = 0, g = 0, b = 0, a = 255, hex = '' }

--============================================================
-- Standard colors for the menu chrome
--============================================================
-- A fresh copy each call: some widgets ease or recolor the table they are handed, and the
-- snapshot must stay the Standard value.
local function std(key)
    local e = MTP.entries[key]
    local d = e and e.default or G.C.WHITE
    return { d[1], d[2], d[3], d[4] or 1 }
end

local function text_on(c)
    -- Perceived brightness decides light or dark lettering, so a label stays legible on
    -- whatever the swatch is currently painted.
    local lum = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    if (c[4] or 1) < 0.5 then lum = 1 - lum * 0.5 end
    return lum > 0.6 and std('UI.TEXT_DARK') or std('UI.TEXT_LIGHT')
end

local function label(text, scale, color)
    return { n = G.UIT.T, config = { text = text, scale = scale or 0.35, colour = color or std('UI.TEXT_LIGHT'), shadow = true } }
end

local function button(text, func, color, w, extra)
    local cfg = { align = 'cm', minw = w or 2, minh = 0.55, r = 0.1, padding = 0.06, hover = true, shadow = true,
                  colour = color or std('RED'), button = func }
    for k, v in pairs(extra or {}) do cfg[k] = v end
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
        { n = G.UIT.C, config = cfg, nodes = { label(text, 0.32) } },
    }}
end

--============================================================
-- Selection
--============================================================
local function advanced() return MTP.CFG.advanced == true end

local function groups() return MTP.menu_groups(advanced()) end

local function current_group()
    local gs = groups()
    MTP.view.group = math.max(1, math.min(MTP.view.group, #gs))
    return gs[MTP.view.group]
end

-- The selection, provided it is on show; switching modes can hide it.
local function selected()
    local g = current_group()
    if not g then return nil end
    for _, e in ipairs(g.entries) do
        if e.key == MTP.view.key then return e end
    end
    return g.entries[1]
end

-- Basic mode names colors by what they paint rather than by their vanilla name.
local function name_of(e)
    local g = current_group()
    return (g and g.labels and g.labels[e.key]) or e.label
end

-- Loads the slider state from the color itself.
local function load_edit(e)
    local t = e.t
    MTP.edit.r = math.floor(t[1] * 255 + 0.5)
    MTP.edit.g = math.floor(t[2] * 255 + 0.5)
    MTP.edit.b = math.floor(t[3] * 255 + 0.5)
    MTP.edit.a = math.floor((t[4] or 1) * 255 + 0.5)
    MTP.edit.hex = '#' .. MTP.to_hex(t)
    MTP.edit.key = e.key
end

--============================================================
-- Palette grid
--============================================================
local function swatch(e, chosen)
    local c = e.t
    local changed = MTP.current[e.key] ~= nil
    local inner = { n = G.UIT.C, config = { align = 'cm', minw = 2.1, maxw = 2.1, minh = 0.6, r = 0.08, padding = 0.05,
                                             colour = c, hover = true, shadow = true,
                                             button = 'mtp_select', mtp_key = e.key }, nodes = {
        { n = G.UIT.T, config = { text = (changed and '* ' or '') .. name_of(e), scale = 0.28, colour = text_on(c) } },
    }}
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.04, r = 0.1,
                                     colour = chosen and std('WHITE') or G.C.CLEAR }, nodes = { inner } }
end

local function grid(g)
    local pages = math.max(1, math.ceil(#g.entries / PER_PAGE))
    MTP.view.page = math.max(1, math.min(MTP.view.page, pages))
    local first = (MTP.view.page - 1) * PER_PAGE
    local sel = selected()

    local rows = {}
    for r = 0, ROWS - 1 do
        local cols = {}
        for c = 1, COLS do
            local e = g.entries[first + r * COLS + c]
            if e then
                cols[#cols + 1] = swatch(e, sel == e)
            else
                cols[#cols + 1] = { n = G.UIT.C, config = { minw = 2.18, minh = 0.68 } }
            end
        end
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm' }, nodes = cols }
    end

    local labels = {}
    for i, gg in ipairs(groups()) do labels[i] = gg.label end
    local page_opts = {}
    for i = 1, pages do page_opts[i] = 'Page ' .. i .. '/' .. pages end

    local header
    if advanced() then
        -- create_option_cycle returns an R (UI_definitions.lua:2322); it needs a C of its own
        -- to sit beside the button.
        header = { n = G.UIT.R, config = { align = 'cm' }, nodes = {
            { n = G.UIT.C, config = { align = 'cm' }, nodes = {
                create_option_cycle({ options = labels, current_option = MTP.view.group, opt_callback = 'mtp_group',
                                      w = 4.2, scale = 0.8, colour = std('RED'), no_pips = true }),
            }},
            button('Basic', 'mtp_toggle_mode', std('L_BLACK'), 1.5),
        }}
    else
        header = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', minw = 5.3 }, nodes = { label('Basic Colors', 0.45) } },
            button('Advanced', 'mtp_toggle_mode', std('L_BLACK'), 1.8),
        }}
    end

    return { n = G.UIT.C, config = { align = 'tm', padding = 0.08, r = 0.1, colour = { 0, 0, 0, 0.15 } }, nodes = {
        header,
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = rows },
        pages > 1 and { n = G.UIT.R, config = { align = 'cm' }, nodes = {
            create_option_cycle({ options = page_opts, current_option = MTP.view.page, opt_callback = 'mtp_page',
                                  w = 3, scale = 0.6, colour = std('L_BLACK'), no_pips = true }),
        }} or nil,
    }}
end

--============================================================
-- Color editor
--============================================================
local function slider(name, key, color)
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
        { n = G.UIT.C, config = { align = 'cm', minw = 0.4 }, nodes = { label(name, 0.35) } },
        create_slider({ ref_table = MTP.edit, ref_value = key, min = 0, max = 255, w = 3.2, h = 0.3,
                        colour = color, text_scale = 0.3 }),
    }}
end

local function editor(e)
    load_edit(e)
    local g = MTP.groups[e.group]
    local sub = (g and g.label or '') .. '  ' .. e.key
    if not advanced() and MTP.FOLLOWERS[e.key] then
        local names = {}
        for i, k in ipairs(MTP.FOLLOWERS[e.key]) do
            names[i] = MTP.entries[k] and MTP.entries[k].label or k
        end
        sub = 'Also sets ' .. table.concat(names, ' and ')
    end
    if e.key == 'MTP.MOD_BUTTON' and not MTP.current[e.key] then
        sub = 'Repaints every mod button once changed'
    end
    return { n = G.UIT.C, config = { align = 'tm', padding = 0.1, r = 0.1, minw = 5.2, colour = { 0, 0, 0, 0.15 },
                                     func = 'mtp_sync' }, nodes = {
        { n = G.UIT.R, config = { align = 'cm' }, nodes = { label(name_of(e), 0.5) } },
        { n = G.UIT.R, config = { align = 'cm' }, nodes = {
            label(sub, 0.25, std('UI.TEXT_INACTIVE')),
        }},
        -- The live color against both page tones, so a transparent or near-black value is
        -- judged against what it will actually sit on.
        { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.12, r = 0.1, colour = std('L_BLACK') }, nodes = {
                { n = G.UIT.C, config = { minw = 1.9, minh = 1.1, r = 0.1, colour = e.t, emboss = 0.05 } },
            }},
            { n = G.UIT.C, config = { align = 'cm', padding = 0.12, r = 0.1, colour = std('WHITE') }, nodes = {
                { n = G.UIT.C, config = { minw = 1.9, minh = 1.1, r = 0.1, colour = e.t, emboss = 0.05 } },
            }},
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
            { n = G.UIT.T, config = { ref_table = MTP.edit, ref_value = 'hex', scale = 0.45, colour = std('UI.TEXT_LIGHT'), shadow = true } },
            { n = G.UIT.C, config = { minw = 0.3 } },
            label('was #' .. e.default_hex, 0.28, std('UI.TEXT_INACTIVE')),
        }},
        slider('R', 'r', std('RED')),
        slider('G', 'g', std('GREEN')),
        slider('B', 'b', std('BLUE')),
        slider('A', 'a', std('GREY')),
        { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
            button('Copy Hex', 'mtp_copy_hex', std('L_BLACK'), 1.5),
            button('Paste Hex', 'mtp_paste_hex', std('L_BLACK'), 1.5),
            button('Reset', 'mtp_reset_color', std('ORANGE'), 1.4),
        }},
    }}
end

--============================================================
-- Theme bar
--============================================================
local function theme_bar()
    local names = MTP.list_themes()
    MTP.view.pick = math.max(1, math.min(MTP.view.pick, #names))
    MTP.view.names = names

    return { n = G.UIT.R, config = { align = 'cm', padding = 0.08, r = 0.1, colour = { 0, 0, 0, 0.15 } }, nodes = {
        { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                create_text_input({ ref_table = MTP.view, ref_value = 'name', id = 'mtp_name', w = 3.6, max_length = 16,
                                    extended_corpus = true, prompt_text = 'Theme name', mtp_text = true,
                                    colour = std('BLUE'), hooked_colour = darken(std('BLUE'), 0.3) }),
                button('Save', 'mtp_save', std('GREEN'), 1.3),
            }},
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                button('Copy Code', 'mtp_copy_code', std('L_BLACK'), 1.8),
                button('Paste Code', 'mtp_paste_code', std('L_BLACK'), 1.8),
                button('Folder', 'mtp_folder', std('L_BLACK'), 1.3),
            }},
        }},
        { n = G.UIT.C, config = { align = 'cm', minw = 0.2 } },
        { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                create_option_cycle({ options = names, current_option = MTP.view.pick, opt_callback = 'mtp_pick',
                                      w = 3.6, scale = 0.7, colour = std('L_BLACK'), no_pips = true }),
            }},
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                button('Load', 'mtp_load', std('GREEN'), 1.8),
                button('Reset All', 'mtp_reset_all', std('RED'), 1.8),
            }},
        }},
    }}
end

--============================================================
-- Page
--============================================================
function G.UIDEF.mtp_themes()
    MTP.scan()
    local g = current_group()
    local e = selected()
    MTP.view.key = e and e.key

    local body = { n = G.UIT.R, config = { align = 'tm', padding = 0.08 }, nodes = {
        grid(g),
        e and editor(e) or nil,
    }}

    return create_UIBox_generic_options({
        back_func = 'mtp_back',
        contents = {
            { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
                label('Themes', 0.6),
            }},
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                label(MTP.current_name .. '  -  ' .. MTP.changed_count() .. ' changed', 0.32, std('UI.TEXT_INACTIVE')),
            }},
            body,
            theme_bar(),
            { n = G.UIT.R, config = { align = 'cm', minh = 0.3 }, nodes = {
                { n = G.UIT.T, config = { ref_table = MTP.view, ref_value = 'status', scale = 0.32, colour = std('FILTER'), shadow = true } },
            }},
        },
    })
end

-- A hooked name field would outlive its node and take the next keypress.
local function release_text()
    if G.CONTROLLER then G.CONTROLLER.text_input_hook = nil end
end

-- Every change that alters the layout rebuilds the page in place. Slider drags do not: the
-- sync func writes them through without a rebuild.
function MTP.reopen()
    release_text()
    G.FUNCS.exit_overlay_menu()
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{ definition = G.UIDEF.mtp_themes(), config = { offset = { x = 0, y = 0 } } }
end

local function status(msg)
    MTP.view.status = msg or ''
end

--============================================================
-- Callbacks
--============================================================
local function open(host)
    MTP.view.host = host
    status('')
    MTP.view.name = (MTP.current_name ~= MTP.STANDARD) and MTP.current_name or ''
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{ definition = G.UIDEF.mtp_themes() }
end

G.FUNCS.mtp_open = function() open('settings') end

-- From the SMODS mod menu there is no Settings page to return to; Back simply closes.
G.FUNCS.mtp_open_from_mods = function() open('mods') end

-- Runs every frame while the editor is open: pushes slider values into the color.
G.FUNCS.mtp_sync = function(e)
    local sel = MTP.view.key and MTP.entries[MTP.view.key]
    if not sel or MTP.edit.key ~= sel.key then return end
    local r = math.floor(MTP.edit.r + 0.5)
    local g = math.floor(MTP.edit.g + 0.5)
    local b = math.floor(MTP.edit.b + 0.5)
    local a = math.floor(MTP.edit.a + 0.5)
    local t = sel.t
    if r ~= math.floor(t[1] * 255 + 0.5) or g ~= math.floor(t[2] * 255 + 0.5)
        or b ~= math.floor(t[3] * 255 + 0.5) or a ~= math.floor((t[4] or 1) * 255 + 0.5) then
        MTP.set(sel, { r / 255, g / 255, b / 255, a / 255 }, not advanced())
        MTP.edit.hex = '#' .. MTP.to_hex(t)
    end
end

G.FUNCS.mtp_select = function(e)
    MTP.view.key = e.config.mtp_key
    status('')
    MTP.reopen()
end

G.FUNCS.mtp_group = function(args)
    MTP.view.group = args.to_key
    MTP.view.page = 1
    local g = groups()[args.to_key]
    MTP.view.key = g and g.entries[1] and g.entries[1].key
    MTP.reopen()
end

G.FUNCS.mtp_page = function(args)
    MTP.view.page = args.to_key
    local g = current_group()
    local e = g and g.entries[(args.to_key - 1) * PER_PAGE + 1]
    MTP.view.key = e and e.key
    MTP.reopen()
end

G.FUNCS.mtp_toggle_mode = function()
    MTP.CFG.advanced = not advanced()
    MTP.view.group, MTP.view.page = 1, 1
    MTP.persist()
    MTP.reopen()
end

G.FUNCS.mtp_pick = function(args)
    MTP.view.pick = args.to_key
end

G.FUNCS.mtp_copy_hex = function()
    local e = selected()
    if not e then return end
    MTP.copy('#' .. MTP.to_hex(e.t))
    status('Copied #' .. MTP.to_hex(e.t))
end

G.FUNCS.mtp_paste_hex = function()
    local e = selected()
    local c = MTP.parse_hex(MTP.paste())
    if not (e and c) then status('Clipboard does not hold a hex color'); MTP.reopen(); return end
    MTP.set(e, c, not advanced())
    status('Pasted #' .. MTP.to_hex(c))
    MTP.reopen()
end

G.FUNCS.mtp_reset_color = function()
    local e = selected()
    if not e then return end
    MTP.set(e, e.default, not advanced(), true)
    status('Reset ' .. name_of(e))
    MTP.reopen()
end

G.FUNCS.mtp_save = function()
    local ok, msg = MTP.save_theme(MTP.view.name)
    if ok then
        MTP.persist()
        local names = MTP.list_themes()
        for i, n in ipairs(names) do if n == MTP.current_name then MTP.view.pick = i end end
    end
    status(msg)
    MTP.reopen()
end

G.FUNCS.mtp_load = function()
    local name = MTP.view.names and MTP.view.names[MTP.view.pick]
    if not name then return end
    local ok, msg = MTP.load_theme(name)
    if ok then
        MTP.persist()
        MTP.view.name = (name ~= MTP.STANDARD) and MTP.current_name or ''
    end
    status(msg)
    MTP.reopen()
end

G.FUNCS.mtp_reset_all = function()
    MTP.apply({}, MTP.STANDARD)
    MTP.persist()
    MTP.view.name = ''
    status('Back to Standard')
    MTP.reopen()
end

G.FUNCS.mtp_copy_code = function()
    MTP.copy(MTP.encode(MTP.current, MTP.view.name ~= '' and MTP.view.name or MTP.current_name))
    status('Share code copied - ' .. MTP.changed_count() .. ' colors')
end

G.FUNCS.mtp_paste_code = function()
    local overrides, name = MTP.decode(MTP.paste())
    if not overrides then status('Clipboard does not hold a theme'); MTP.reopen(); return end
    MTP.apply(overrides, name or 'Pasted')
    MTP.persist()
    MTP.view.name = MTP.current_name
    status('Applied ' .. MTP.current_name .. ' - Save to keep it as a file')
    MTP.reopen()
end

G.FUNCS.mtp_folder = function()
    MTP.open_folder()
end

-- Back returns to whichever menu opened the page, on the tab that holds the Themes button.
G.FUNCS.mtp_back = function()
    release_text()
    if MTP.dirty then MTP.persist() end
    MTP.refresh_background()
    if MTP.view.host == 'settings' then
        MTP.return_tab = MTP.host_tab()
        G.FUNCS.settings(nil, true)
        MTP.return_tab = nil
    else
        G.FUNCS.exit_overlay_menu()
    end
end

--============================================================
-- Vanilla seams
--============================================================
-- The tab the Themes button lives on. Video is hidden on platforms without window settings
-- (create_UIBox_settings checks G.F_VIDEO_SETTINGS), so Graphics hosts it there instead.
function MTP.host_tab()
    return G.F_VIDEO_SETTINGS and 'Video' or 'Graphics'
end

local settings_tab_ref = G.UIDEF.settings_tab
function G.UIDEF.settings_tab(tab, ...)
    local t = settings_tab_ref(tab, ...)
    if tab == MTP.host_tab() and type(t) == 'table' and t.nodes then
        t.nodes[#t.nodes + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            UIBox_button({ button = 'mtp_open', label = { 'Themes' }, minw = 3, colour = G.C.PURPLE }),
        }}
    end
    return t
end

-- The profile and language buttons are painted from their own palette entry instead of a mix
-- made once when the menu is built, so a theme reaches them and keeps reaching them live.
local MENU_BUTTONS = { profile_select = 'MENU_BUTTON', language_selection = 'LANG_BUTTON' }

local function repaint_menu_buttons(node)
    if type(node) ~= 'table' then return end
    local key = node.config and MENU_BUTTONS[node.config.button]
    if key then node.config.colour = G.C.MTP[key] end
    for _, child in ipairs(node.nodes or {}) do repaint_menu_buttons(child) end
end

local main_menu_buttons_ref = create_UIBox_main_menu_buttons
function create_UIBox_main_menu_buttons(...)
    local t = main_menu_buttons_ref(...)
    repaint_menu_buttons(t)
    return t
end

local profile_button_ref = create_UIBox_profile_button
function create_UIBox_profile_button(...)
    local t = profile_button_ref(...)
    repaint_menu_buttons(t)
    return t
end

-- Every button a mod builds takes the theme's Mod Buttons color, when the theme sets one. A
-- mod's code runs from a chunk SMODS names '=[SMODS <id> "<file>"]' (preflight/loader.lua:886,
-- SMODS core is id _), which is how its UIBox_button calls are told from vanilla's. The Mods
-- button itself is patched into vanilla's menu, so it is caught by id.
local function modded_caller()
    local info = debug.getinfo(3, 'S')
    return info ~= nil and type(info.source) == 'string' and info.source:sub(1, 8) == '=[SMODS '
end

local UIBox_button_ref = UIBox_button
function UIBox_button(args, ...)
    if type(args) == 'table' and MTP.current and MTP.current['MTP.MOD_BUTTON']
        and (args.id == 'mods_button' or modded_caller()) then
        args.colour = G.C.MTP.MOD_BUTTON
    end
    return UIBox_button_ref(args, ...)
end

-- Reopening Settings lands on its first tab; this selects the host tab instead, once.
local create_tabs_ref = create_tabs
function create_tabs(args, ...)
    local want = MTP.return_tab
    if want and type(args) == 'table' and type(args.tabs) == 'table' then
        MTP.return_tab = nil
        local hit
        for _, tab in ipairs(args.tabs) do
            if tab.tab_definition_function_args == want then hit = tab end
        end
        if hit then
            for _, tab in ipairs(args.tabs) do tab.chosen = (tab == hit) end
        end
    end
    return create_tabs_ref(args, ...)
end

-- Esc leaves the menu without passing Back; the theme is saved either way.
local exit_overlay_ref = G.FUNCS.exit_overlay_menu
G.FUNCS.exit_overlay_menu = function(...)
    if MTP.dirty then
        MTP.persist()
        MTP.refresh_background()
    end
    return exit_overlay_ref(...)
end

-- Vanilla maps a typed 0 to the letter o (button_callbacks.lua:1004, a seed-entry rule). The
-- theme name is not a seed, so its 0 is inserted as a 0.
local text_input_key_ref = G.FUNCS.text_input_key
G.FUNCS.text_input_key = function(args)
    local hook = G.CONTROLLER and G.CONTROLLER.text_input_hook
    local cfg = hook and hook.config and hook.config.ref_table
    if args and args.key == '0' and cfg and cfg.mtp_text and cfg.text then
        local text = cfg.text
        TRANSPOSE_TEXT_INPUT(0)
        if cfg.max_length > string.len(text.ref_table[text.ref_value]) then
            MODIFY_TEXT_INPUT{ letter = '0', text_table = text, pos = text.current_position + 1 }
            TRANSPOSE_TEXT_INPUT(1)
        end
        return
    end
    return text_input_key_ref(args)
end
