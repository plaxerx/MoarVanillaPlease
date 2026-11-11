-- Moar Themes Please - the palette. Every color table the game draws with, found, labelled,
-- grouped, and snapshotted at its Standard value.
--
-- A theme only ever writes INTO the game's own color tables. UI nodes hold `color = G.C.RED`
-- by reference, so an in-place write repaints everything already on screen; replacing the
-- table would strand every node built before the change on the old one.
--
-- One table, one entry. SMODS aliases freely - G.C.STAKES[1] IS G.C.WHITE, and a vanilla
-- rarity's badge color IS G.C.RARITY[1] - so entries are keyed by table identity and the
-- first path to reach a table names it. The curated list runs first, so a vanilla color is
-- always named by its vanilla path.

MTP.groups = {}
MTP.entries = {}            -- key -> entry
MTP.by_table = {}           -- color table -> entry

local function group(id, label)
    local g = { id = id, label = label, entries = {} }
    MTP.groups[#MTP.groups + 1] = g
    MTP.groups[id] = g
    return g
end

group('core',      'Core')
group('surface',   'Surfaces')
group('ui',        'Interface')
group('sticker',   'Stickers & Packs')
group('set',       'Card Sets')
group('secondary', 'Set Accents')
group('rarity',    'Rarities')
group('blind',     'Blinds')
group('boss',      'Boss Blinds')
group('hand',      'Hand Levels')
group('suit',      'Suits')
group('suit_hc',   'Suits (High Contrast)')
group('stake',     'Stakes')
group('mod',       'Modded')

-- Colors vanilla never names. The profile and language buttons mix White and Grey at build
-- time (UI_definitions.lua:6740, 6796), and a mod picks its own button colors, so each gets a
-- table here for the wraps in ui.lua to point those buttons at. Mod Buttons only applies once a
-- theme sets it; Standard leaves every mod's buttons as the mod drew them.
G.C.MTP = G.C.MTP or {
    MENU_BUTTON = mix_colours(G.C.WHITE, G.C.GREY, 0.2),
    LANG_BUTTON = mix_colours(G.C.WHITE, G.C.GREY, 0.2),
    MOD_BUTTON = HEX('8867A5'),
}

-- Where a discovered path lands when the curated list does not name it.
local GROUP_OF = {
    UI = 'ui', SET = 'set', SECONDARY_SET = 'secondary', RARITY = 'rarity', BLIND = 'blind',
    HAND_LEVELS = 'hand', SO_1 = 'suit', SO_2 = 'suit_hc',
}

-- Colors the game drives itself every frame or every blind; a theme value would be
-- overwritten before it was ever seen.
--   EDITION / DARK_EDITION   animated (game.lua:2635)
--   DYN_UI, BACKGROUND       eased toward the blind's colors
--   UI_CHIPS / UI_MULT       copies of BLUE / RED, flashed while scoring (game.lua:2105)
--   SUITS                    aliases of SO_1 / SO_2 or a deck skin, rebound on contrast toggle
--   STAKES                   aliases of each stake's color, named by stake key instead
--   CLEAR                    the transparent color; recoloring it fills every empty box
local SKIP = {
    CLEAR = true, EDITION = true, DARK_EDITION = true, DYN_UI = true, BACKGROUND = true,
    UI_CHIPS = true, UI_MULT = true, UI_CHIPLICK = true, UI_MULTLICK = true,
    SUITS = true, STAKES = true,
}

-- Vanilla's colors, in the order the menu lists them.
local CURATED = {
    { 'core', 'MULT', 'Mult' },
    { 'core', 'XMULT', 'XMult' },
    { 'core', 'CHIPS', 'Chips' },
    { 'core', 'MONEY', 'Money' },
    { 'core', 'FILTER', 'Attention' },
    { 'core', 'IMPORTANT', 'Important' },
    { 'core', 'RED', 'Red' },
    { 'core', 'BLUE', 'Blue' },
    { 'core', 'GREEN', 'Green' },
    { 'core', 'PALE_GREEN', 'Pale Green' },
    { 'core', 'ORANGE', 'Orange' },
    { 'core', 'GOLD', 'Gold' },
    { 'core', 'YELLOW', 'Yellow' },
    { 'core', 'PURPLE', 'Purple' },
    { 'core', 'CHANCE', 'Chance' },
    { 'core', 'BLIND_SIZE', 'Blind Size' },

    { 'surface', 'BLACK', 'Panel' },
    { 'surface', 'L_BLACK', 'Panel Light' },
    { 'surface', 'GREY', 'Grey' },
    { 'surface', 'JOKER_GREY', 'Frame' },
    { 'surface', 'WHITE', 'White' },

    { 'ui', 'UI.TEXT_LIGHT', 'Text Light' },
    { 'ui', 'UI.TEXT_DARK', 'Text Dark' },
    { 'ui', 'UI.TEXT_INACTIVE', 'Text Inactive' },
    { 'ui', 'UI.BACKGROUND_LIGHT', 'Background Light' },
    { 'ui', 'UI.BACKGROUND_WHITE', 'Background White' },
    { 'ui', 'UI.BACKGROUND_DARK', 'Background Dark' },
    { 'ui', 'UI.BACKGROUND_INACTIVE', 'Background Off' },
    { 'ui', 'UI.OUTLINE_LIGHT', 'Outline Light' },
    { 'ui', 'UI.OUTLINE_LIGHT_TRANS', 'Outline Faint' },
    { 'ui', 'UI.OUTLINE_DARK', 'Outline Dark' },
    { 'ui', 'UI.TRANSPARENT_LIGHT', 'Glass Light' },
    { 'ui', 'UI.TRANSPARENT_DARK', 'Glass Dark' },
    { 'ui', 'UI.HOVER', 'Hover' },
    { 'ui', 'MTP.MENU_BUTTON', 'Profile Button' },
    { 'ui', 'MTP.LANG_BUTTON', 'Language Button' },
    { 'ui', 'MTP.MOD_BUTTON', 'Mod Buttons' },

    { 'sticker', 'VOUCHER', 'Voucher' },
    { 'sticker', 'BOOSTER', 'Booster' },
    { 'sticker', 'ETERNAL', 'Eternal' },
    { 'sticker', 'PERISHABLE', 'Perishable' },
    { 'sticker', 'RENTAL', 'Rental' },

    { 'set', 'SET.Default', 'Default' },
    { 'set', 'SET.Enhanced', 'Enhanced' },
    { 'set', 'SET.Joker', 'Joker' },
    { 'set', 'SET.Tarot', 'Tarot' },
    { 'set', 'SET.Planet', 'Planet' },
    { 'set', 'SET.Spectral', 'Spectral' },
    { 'set', 'SET.Voucher', 'Voucher' },

    { 'secondary', 'SECONDARY_SET.Default', 'Default' },
    { 'secondary', 'SECONDARY_SET.Enhanced', 'Enhanced' },
    { 'secondary', 'SECONDARY_SET.Joker', 'Joker' },
    { 'secondary', 'SECONDARY_SET.Tarot', 'Tarot' },
    { 'secondary', 'SECONDARY_SET.Planet', 'Planet' },
    { 'secondary', 'SECONDARY_SET.Spectral', 'Spectral' },
    { 'secondary', 'SECONDARY_SET.Voucher', 'Voucher' },
    { 'secondary', 'SECONDARY_SET.Edition', 'Edition' },

    { 'rarity', 'RARITY.1', 'Common' },
    { 'rarity', 'RARITY.2', 'Uncommon' },
    { 'rarity', 'RARITY.3', 'Rare' },
    { 'rarity', 'RARITY.4', 'Legendary' },

    { 'blind', 'BLIND.Small', 'Small Blind' },
    { 'blind', 'BLIND.Big', 'Big Blind' },
    { 'blind', 'BLIND.Boss', 'Boss Blind' },
    { 'blind', 'BLIND.won', 'Defeated' },

    { 'hand', 'HAND_LEVELS.1', 'Level 1' },
    { 'hand', 'HAND_LEVELS.2', 'Level 2' },
    { 'hand', 'HAND_LEVELS.3', 'Level 3' },
    { 'hand', 'HAND_LEVELS.4', 'Level 4' },
    { 'hand', 'HAND_LEVELS.5', 'Level 5' },
    { 'hand', 'HAND_LEVELS.6', 'Level 6' },
    { 'hand', 'HAND_LEVELS.7', 'Level 7+' },

    { 'suit', 'SO_1.Hearts', 'Hearts' },
    { 'suit', 'SO_1.Diamonds', 'Diamonds' },
    { 'suit', 'SO_1.Spades', 'Spades' },
    { 'suit', 'SO_1.Clubs', 'Clubs' },
    { 'suit_hc', 'SO_2.Hearts', 'Hearts' },
    { 'suit_hc', 'SO_2.Diamonds', 'Diamonds' },
    { 'suit_hc', 'SO_2.Spades', 'Spades' },
    { 'suit_hc', 'SO_2.Clubs', 'Clubs' },
}

--============================================================
-- Color values
--============================================================
-- A color is a bare array of three or four numbers. Rejecting anything with a metatable or
-- a named field keeps out SMODS gradients and other objects that merely carry [1]..[4].
function MTP.is_color(t)
    if type(t) ~= 'table' or getmetatable(t) then return false end
    if type(t[1]) ~= 'number' or type(t[2]) ~= 'number' or type(t[3]) ~= 'number' then return false end
    if t[4] ~= nil and type(t[4]) ~= 'number' then return false end
    for k in pairs(t) do
        if type(k) ~= 'number' or k < 1 or k > 4 then return false end
    end
    return true
end

local function byte(v)
    return math.max(0, math.min(255, math.floor((v or 1) * 255 + 0.5)))
end

-- RRGGBB, or RRGGBBAA when the color is not opaque.
function MTP.to_hex(c)
    local s = string.format('%02X%02X%02X', byte(c[1]), byte(c[2]), byte(c[3]))
    local a = byte(c[4] == nil and 1 or c[4])
    if a ~= 255 then s = s .. string.format('%02X', a) end
    return s
end

-- Accepts RGB, RRGGBB or RRGGBBAA with or without a leading #. Nil for anything else.
function MTP.parse_hex(s)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^#', '')
    if s:match('^%x%x%x$') then
        s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2)
    end
    if not (s:match('^%x%x%x%x%x%x$') or s:match('^%x%x%x%x%x%x%x%x$')) then return nil end
    local a = (#s == 8) and tonumber(s:sub(7, 8), 16) or 255
    return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255,
             tonumber(s:sub(5, 6), 16) / 255, a / 255 }
end

-- Writes a value into a color table IN PLACE; see the header for why.
function MTP.write(t, c)
    t[1], t[2], t[3] = c[1], c[2], c[3]
    t[4] = c[4] or 1
end

--============================================================
-- Registry
--============================================================
-- A numeric segment is tried as a number first. Amulet answers any missing HAND_LEVELS key
-- with the Level 7+ color (talisman/break_inf/sanitizer.lua), so the string '1' is never nil
-- there and every level would resolve to Level 7.
local function resolve(path)
    local node = G.C
    for seg in path:gmatch('[^%.]+') do
        if type(node) ~= 'table' then return nil end
        local n, v = tonumber(seg), nil
        if n then v = rawget(node, n) end
        if v == nil then v = node[seg] end
        node = v
    end
    return node
end

-- Readable label for a key no curated row names: 'cry_epic' -> 'Cry Epic'.
local function pretty(seg)
    seg = tostring(seg):gsub('_', ' ')
    return (seg:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b:lower() end))
end

-- Registers one color table. A table seen before under another path is an alias and is
-- skipped. The Standard value is snapshotted HERE, before any theme touches it, and a key the
-- active theme already overrides is applied immediately - a color found after boot picks
-- the theme up the moment it appears.
local function register(key, t, gid, label)
    if not MTP.is_color(t) or MTP.by_table[t] or MTP.entries[key] then return end
    local e = { key = key, t = t, group = gid, label = label,
                default = { t[1], t[2], t[3], t[4] or 1 } }
    e.default_hex = MTP.to_hex(e.default)
    MTP.entries[key] = e
    MTP.by_table[t] = e
    local g = MTP.groups[gid]
    g.entries[#g.entries + 1] = e
    local hex = MTP.current and MTP.current[key]
    local c = hex and MTP.parse_hex(hex)
    if c then MTP.write(t, c) end
end

local function sorted_keys(tbl)
    local keys = {}
    for k in pairs(tbl) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) and type(a) == 'number' then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function blind_name(key, blind)
    local ok, s = pcall(localize, { type = 'name_text', set = 'Blind', key = key })
    if ok and type(s) == 'string' and s ~= '' and s ~= 'ERROR' then return s end
    return blind.name or key
end

local function stake_name(key, stake)
    local ok, s = pcall(localize, { type = 'name_text', set = 'Stake', key = key })
    if ok and type(s) == 'string' and s ~= '' and s ~= 'ERROR' then return s end
    return stake.name or key
end

-- Walks every source of color and registers what it has not seen. Safe to call repeatedly:
-- boot runs it once everything is injected, and the menu runs it again on open in case a mod
-- added colors late.
function MTP.scan()
    if not (G and G.C) then return end

    for _, row in ipairs(CURATED) do
        register(row[2], resolve(row[2]), row[1], row[3])
    end

    -- Stakes by key, never by ladder index: the index moves when a stake mod is added.
    if G.P_STAKES then
        local keys = sorted_keys(G.P_STAKES)
        table.sort(keys, function(a, b)
            local oa, ob = G.P_STAKES[a].order or 1e9, G.P_STAKES[b].order or 1e9
            if oa ~= ob then return oa < ob end
            return a < b
        end)
        for _, k in ipairs(keys) do
            local s = G.P_STAKES[k]
            if type(s) == 'table' then register('STAKE.' .. k, s.colour, 'stake', stake_name(k, s)) end
        end
    end

    if G.P_BLINDS then
        local keys = sorted_keys(G.P_BLINDS)
        table.sort(keys, function(a, b)
            local oa, ob = G.P_BLINDS[a].order or 1e9, G.P_BLINDS[b].order or 1e9
            if oa ~= ob then return oa < ob end
            return a < b
        end)
        for _, k in ipairs(keys) do
            local b = G.P_BLINDS[k]
            if type(b) == 'table' then register('BOSS.' .. k, b.boss_colour, 'boss', blind_name(k, b)) end
        end
    end

    -- Everything else in G.C, two levels deep: vanilla's leftovers, SMODS rarities and
    -- consumable types, and whatever other mods hang there.
    for _, k in ipairs(sorted_keys(G.C)) do
        local v = G.C[k]
        if not SKIP[k] and type(v) == 'table' then
            if MTP.is_color(v) then
                register(tostring(k), v, 'mod', pretty(k))
            elseif not getmetatable(v) then
                local gid = GROUP_OF[k] or 'mod'
                for _, k2 in ipairs(sorted_keys(v)) do
                    local label = (gid == 'mod') and (pretty(k) .. ' ' .. pretty(k2)) or pretty(k2)
                    register(tostring(k) .. '.' .. tostring(k2), v[k2], gid, label)
                end
            end
        end
    end
end

-- Groups that have at least one color, in menu order. Theme files always use this full list.
function MTP.live_groups()
    local out = {}
    for _, g in ipairs(MTP.groups) do
        if #g.entries > 0 then out[#out + 1] = g end
    end
    return out
end

--============================================================
-- Basic mode
--============================================================
-- The menu's default view: the nineteen colors that carry the look of the menus and the
-- table, under plain names. Advanced mode lists every group.
local BASIC = {
    { 'L_BLACK', 'Menus' },
    { 'BLACK', 'Panels' },
    { 'GREY', 'Overlay' },
    { 'JOKER_GREY', 'Frames' },
    { 'UI.TEXT_LIGHT', 'Text' },
    { 'UI.TEXT_DARK', 'Dark Text' },
    { 'WHITE', 'White' },
    { 'BLIND.Small', 'Table Felt' },
    { 'RED', 'Red / Mult' },
    { 'BLUE', 'Blue / Chips' },
    { 'GREEN', 'Green' },
    { 'ORANGE', 'Back Buttons' },
    { 'GOLD', 'Gold' },
    { 'MONEY', 'Money' },
    { 'FILTER', 'Highlight' },
    { 'PURPLE', 'Purple' },
    { 'MTP.MENU_BUTTON', 'Profile Button' },
    { 'MTP.LANG_BUTTON', 'Language Button' },
    { 'MTP.MOD_BUTTON', 'Mod Buttons' },
}

-- In basic mode a color carries the ones vanilla keeps identical to it, so one swatch
-- recolors what reads as one thing: Mult boxes with Red, the Big Blind felt with the Small.
MTP.FOLLOWERS = {
    RED = { 'MULT', 'XMULT' },
    BLUE = { 'CHIPS' },
    FILTER = { 'IMPORTANT' },
    ['BLIND.Small'] = { 'BLIND.Big' },
}

local basic_group = { id = 'basic', label = 'Basic', entries = {}, labels = {} }

-- The groups the menu shows: every group in advanced mode, else the one Basic group.
function MTP.menu_groups(advanced)
    if advanced then return MTP.live_groups() end
    basic_group.entries = {}
    for _, row in ipairs(BASIC) do
        local e = MTP.entries[row[1]]
        if e then
            basic_group.entries[#basic_group.entries + 1] = e
            basic_group.labels[row[1]] = row[2]
        end
    end
    return { basic_group }
end

--============================================================
-- Applying a theme
--============================================================
-- The derived colors the palette skips, re-derived from what they copy.
local function refresh_derived()
    local C = G.C
    if C.UI_CHIPS and C.BLUE then MTP.write(C.UI_CHIPS, C.BLUE) end
    if C.UI_MULT and C.RED then MTP.write(C.UI_MULT, C.RED) end
end

-- The felt is eased toward a blind color at each state change (common_events.lua:354);
-- re-easing it shows a theme on the table without waiting for the next blind. Queues an
-- event, so it runs once per theme change, never per slider frame.
function MTP.refresh_background()
    if G.STAGE == G.STAGES.RUN and ease_background_colour_blind and G.STATE then
        pcall(ease_background_colour_blind, G.STATE)
    end
end

-- Makes `overrides` (key -> hex) the whole theme: every registered color takes its override,
-- or its Standard value when the theme does not mention it.
function MTP.apply(overrides, name)
    MTP.current = {}
    overrides = overrides or {}
    -- The language button shared the profile button's color before it had its own; a theme
    -- written then still paints both.
    if overrides['MTP.MENU_BUTTON'] and not overrides['MTP.LANG_BUTTON'] then
        overrides['MTP.LANG_BUTTON'] = overrides['MTP.MENU_BUTTON']
    end
    for key, hex in pairs(overrides) do
        local e = MTP.entries[key]
        local c = MTP.parse_hex(hex)
        -- Keys this session has not registered are kept: they belong to a mod that is not
        -- loaded right now, and dropping them would strip them from the theme on next save.
        if c and (not e or MTP.to_hex(c) ~= e.default_hex) then
            MTP.current[key] = MTP.to_hex(c)
        end
    end
    for key, e in pairs(MTP.entries) do
        local c = MTP.current[key] and MTP.parse_hex(MTP.current[key]) or e.default
        MTP.write(e.t, c)
    end
    MTP.current_name = name or 'Standard'
    refresh_derived()
    MTP.refresh_background()
    MTP.dirty = true
end

local function set_one(e, c)
    MTP.write(e.t, c)
    local hex = MTP.to_hex(c)
    MTP.current[e.key] = (hex ~= e.default_hex) and hex or nil
end

-- Sets one color live and records it against the theme. With `cascade` its followers take
-- the same value, or their own Standard value when it is being reset.
function MTP.set(e, c, cascade, reset)
    -- A built-in theme stops being itself the moment a color changes; renaming it keeps the
    -- boot from re-reading the shipped version over the player's edit.
    if MTP.current_name == 'Standard' then
        MTP.current_name = 'Custom'
    elseif MTP.stock and MTP.stock(MTP.current_name) then
        MTP.current_name = 'My ' .. MTP.current_name
    end
    set_one(e, c)
    if cascade then
        for _, k in ipairs(MTP.FOLLOWERS[e.key] or {}) do
            local f = MTP.entries[k]
            if f then set_one(f, reset and f.default or c) end
        end
    end
    refresh_derived()
    MTP.dirty = true
end

-- Count of colors the theme changes, for the menu header.
function MTP.changed_count()
    local n = 0
    for _ in pairs(MTP.current or {}) do n = n + 1 end
    return n
end
