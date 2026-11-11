-- Moar Themes Please - saving, loading and sharing themes.
--
-- A theme is Standard plus overrides: a name and a set of `KEY=RRGGBB` pairs. One parser
-- reads every form it travels in:
--   share code  one line, changes only:  MTP1;name=Midnight;RED=223344;UI.TEXT_DARK=101820
--   theme file  one pair per line, EVERY color, grouped under # comments so it reads as a
--               template and can be edited by hand
--   mod config  the share code of the active theme
--
-- Files live in the save directory under MoarThemesPlease/themes/ (%APPDATA%/Balatro on
-- Windows), so a theme shared as a file is installed by dropping it in that folder.

MTP.DIR = 'MoarThemesPlease/themes'
MTP.STANDARD = 'Standard'

local CODE_TAG = 'MTP1'

--============================================================
-- Text form
--============================================================
-- Theme names are also file names, and ; and = delimit the share code.
function MTP.clean_name(name)
    name = tostring(name or ''):gsub('[^%w %-_%(%)!&%+,%.]', '')
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

-- Parses any of the three forms. Returns overrides (key -> hex) and the name, or nil when the
-- text holds no color at all.
function MTP.decode(text)
    if type(text) ~= 'string' then return nil end
    local overrides, name, found = {}, nil, false
    for raw in text:gmatch('[^;\r\n]+') do
        -- A comment is '# ' or a whole # line; '#FE5F55' is a color and must survive.
        local item = raw:gsub('^%s*#.*$', ''):gsub('#%s.*$', '')
        local k, v = item:match('^%s*([%w_%.%-]+)%s*=%s*(.-)%s*$')
        if k then
            if k:lower() == 'name' then
                name = MTP.clean_name(v)
            else
                local c = MTP.parse_hex(v)
                if c then
                    overrides[k] = MTP.to_hex(c)
                    found = true
                end
            end
        end
    end
    if not found and not name then return nil end
    if name == '' then name = nil end
    return overrides, name
end

-- One-line share code holding only what differs from Standard.
function MTP.encode(overrides, name)
    local parts = { CODE_TAG, 'name=' .. MTP.clean_name(name or MTP.STANDARD) }
    local keys = {}
    for k in pairs(overrides or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. '=' .. overrides[k] end
    return table.concat(parts, ';')
end

-- Full theme file: every registered color, in menu order, with its label. Overrides for mods
-- not loaded right now are carried at the bottom so saving never loses them.
function MTP.file_text(overrides, name)
    overrides = overrides or {}
    local out = {
        '# Moar Themes Please theme',
        '# One color per line as KEY = RRGGBB (or RRGGBBAA for transparency).',
        '# A color left out of the file keeps its Standard value.',
        '',
        'name = ' .. MTP.clean_name(name or MTP.STANDARD),
    }
    local written = {}
    for _, g in ipairs(MTP.live_groups()) do
        out[#out + 1] = ''
        out[#out + 1] = '# ' .. g.label
        for _, e in ipairs(g.entries) do
            local hex = overrides[e.key] or e.default_hex
            out[#out + 1] = string.format('%s = %s  # %s', e.key, hex, e.label)
            written[e.key] = true
        end
    end
    local extra = {}
    for k, v in pairs(overrides) do
        if not written[k] then extra[#extra + 1] = k .. ' = ' .. v end
    end
    if #extra > 0 then
        table.sort(extra)
        out[#out + 1] = ''
        out[#out + 1] = '# From mods not currently loaded'
        for _, line in ipairs(extra) do out[#out + 1] = line end
    end
    out[#out + 1] = ''
    return table.concat(out, '\n')
end

--============================================================
-- Files
--============================================================
local function path_for(name)
    return MTP.DIR .. '/' .. name .. '.txt'
end

local function ensure_dir()
    if love.filesystem.getInfo(MTP.DIR) then return true end
    return love.filesystem.createDirectory(MTP.DIR)
end

-- Standard, then the stock themes in their shipped order, then saved themes alphabetically.
-- Standard and the stock themes are built in rather than read from disk, so a file sharing
-- one of their names can never stand in for the real thing.
local function reserved(name)
    return name:lower() == MTP.STANDARD:lower() or MTP.stock(name) ~= nil
end

function MTP.list_themes()
    local names = { MTP.STANDARD }
    for _, t in ipairs(MTP.STOCK or {}) do names[#names + 1] = t.name end
    if not love.filesystem.getInfo(MTP.DIR) then return names end
    local found = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(MTP.DIR)) do
        local base = f:match('^(.+)%.txt$')
        if base and not reserved(base) then found[#found + 1] = base end
    end
    table.sort(found, function(a, b) return a:lower() < b:lower() end)
    for _, n in ipairs(found) do names[#names + 1] = n end
    return names
end

-- Returns true, or false and a message for the menu's status line.
function MTP.save_theme(name)
    name = MTP.clean_name(name)
    if name == '' then return false, 'Name the theme first' end
    if reserved(name) then return false, MTP.clean_name(name) .. ' ships with the mod. Pick another name' end
    if not ensure_dir() then return false, 'Could not create the themes folder' end
    local ok = love.filesystem.write(path_for(name), MTP.file_text(MTP.current, name))
    if not ok then return false, 'Could not write ' .. name .. '.txt' end
    MTP.current_name = name
    MTP.dirty = true
    return true, 'Saved ' .. name
end

function MTP.load_theme(name)
    if name == MTP.STANDARD then
        MTP.apply({}, MTP.STANDARD)
        return true, 'Loaded Standard'
    end
    local stock = MTP.stock(name)
    if stock then
        MTP.apply(MTP.stock_overrides(stock), stock.name)
        return true, 'Loaded ' .. stock.name
    end
    local text = love.filesystem.read(path_for(name))
    local overrides, file_name = MTP.decode(text)
    if not overrides then return false, name .. '.txt has no colors in it' end
    MTP.apply(overrides, file_name or name)
    return true, 'Loaded ' .. MTP.current_name
end

-- The Standard palette as a file, rewritten at boot so it always lists every color this
-- install has, modded ones included. It is the template a new theme starts from.
function MTP.write_template()
    if not ensure_dir() then return end
    pcall(love.filesystem.write, path_for(MTP.STANDARD), MTP.file_text({}, MTP.STANDARD))
end

function MTP.open_folder()
    ensure_dir()
    local dir = love.filesystem.getSaveDirectory() .. '/' .. MTP.DIR
    love.system.openURL('file:///' .. dir:gsub('\\', '/'))
end

--============================================================
-- Clipboard
--============================================================
-- Consoles have no system clipboard; vanilla keeps one in G.CLIPBOARD there (paste_seed).
function MTP.copy(text)
    if G.F_LOCAL_CLIPBOARD then
        G.CLIPBOARD = text
    else
        love.system.setClipboardText(text)
    end
end

function MTP.paste()
    local ok, s = pcall(function()
        return (G.F_LOCAL_CLIPBOARD and G.CLIPBOARD) or love.system.getClipboardText()
    end)
    return (ok and type(s) == 'string') and s or ''
end

--============================================================
-- Persistence
--============================================================
-- The active theme rides in the SMODS mod config as a share code. Written on leaving the
-- menu rather than per slider frame.
function MTP.persist()
    MTP.dirty = false
    MTP.CFG.active = MTP.encode(MTP.current, MTP.current_name)
    if SMODS.save_mod_config then SMODS.save_mod_config(MTP.mod) end
end
