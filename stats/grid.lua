-- Moar Stats Please - the completion grid. Which stakes have been cleared on which decks,
-- and with which sleeves.
--
-- THE THIRD DIMENSION
-- Decks x Stakes is a natural grid. Sleeves make it a cube, and a cube does not fit on a
-- screen, so the third axis is a SLICE rather than a subdivision:
--
--   * Row axis toggles between Decks and Sleeves. Both are drawn against Stakes.
--   * With Decks on the rows, a sleeve filter picks which slice of the cube to read:
--     "Any sleeve" collapses the axis, and choosing one reads the deck+sleeve+stake cell.
--
-- A slice keeps every cell one glyph and the grid one screen however many decks, stakes and
-- sleeves are installed. Subdividing cells instead would have to shrink with the roster and
-- would be unreadable by the time three mods are loaded.
--
-- SCALING
-- Rows come from G.P_CENTER_POOLS, columns from G.P_CENTER_POOLS.Stake, sleeves from the
-- sleeve pool: a modded deck or stake appears with no edit here. Cell size is computed from
-- the column count, so more stakes means smaller chips rather than a grid off the edge of
-- the screen.

local LABEL_W = 2.5
local GRID_W = 5.4

MSP.view = MSP.view or {}
MSP.view.axis = MSP.view.axis or 'decks'
MSP.view.sleeve = MSP.view.sleeve or nil        -- nil = any sleeve

--============================================================
-- Rosters
--============================================================
local function pool(name)
    return (G.P_CENTER_POOLS and G.P_CENTER_POOLS[name]) or {}
end

local function name_of(key, set)
    local ok, n = pcall(function() return localize{ type = 'name_text', key = key, set = set } end)
    if ok and n and n ~= '' and n ~= 'ERROR' then return n end
    local c = G.P_CENTERS and G.P_CENTERS[key]
    return (c and c.name) or tostring(key)
end

-- Stakes in ladder order, carrying the colour the game already uses for them so the grid
-- matches the chips on the deck select screen.
local function stake_list()
    local out = {}
    for i, center in ipairs(pool('Stake')) do
        local colour = center.colour
        if get_stake_col then
            local ok, c = pcall(get_stake_col, i)
            if ok and c then colour = c end
        end
        local label = name_of(center.key, 'Stake')
        out[#out + 1] = {
            key = center.key,
            index = i,
            colour = colour or G.C.WHITE,
            label = label,
            abbr = (label:gsub('%s*Stake%s*', '')):sub(1, 2),
        }
    end
    return out
end

-- Ordered the way the collection orders decks, so the grid reads in the same sequence the
-- deck select screen does. Modded decks carry an order too and slot in on their own.
local function deck_list()
    local out = {}
    for _, center in ipairs(pool('Back')) do
        out[#out + 1] = { key = center.key, order = MSP.num(center.order, 999),
                          label = name_of(center.key, 'Back') }
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)
    return out
end

-- Sleeves only exist when CardSleeves is loaded. Falling back to the keys already recorded
-- means the axis still works if the pool is named something else in a future version.
local function sleeve_list(store)
    local out, seen = {}, {}
    for _, center in ipairs(pool('Sleeve')) do
        if center.key and not seen[center.key] then
            seen[center.key] = true
            out[#out + 1] = { key = center.key, order = MSP.num(center.order, 999),
                              label = name_of(center.key, 'Sleeve') }
        end
    end
    if #out == 0 and store then
        for key in pairs((store.groups or {}).sleeves or {}) do
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = { key = key, order = 999, label = name_of(key, 'Sleeve') }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)
    return out
end

--============================================================
-- Cell state
--============================================================
-- Vanilla's own count of wins per deck per stake, used as the baseline so runs from before
-- this mod was installed still count. wins_by_key is preferred over wins: the latter is
-- indexed by stake POSITION, which moves whenever a stake mod is added or removed.
local function vanilla_wins(deck_key, stake)
    local p = G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    local du = p and p.deck_usage and p.deck_usage[deck_key]
    if not du then return 0 end
    if du.wins_by_key then return MSP.num(du.wins_by_key[stake.key]) end
    if du.wins then return MSP.num(du.wins[stake.index]) end
    return 0
end

-- How many times this row has cleared this stake. `sleeve` narrows a deck row to one slice
-- of the cube; without it the deck row means "with any sleeve".
--
-- Vanilla keeps counting its own deck_usage whether this mod is loaded or not, so its number
-- is a superset of ours: every win we recorded is in there too. Taking the larger of the two
-- therefore restores pre-install history without counting anything twice - adding them would
-- double every win since install.
local function win_count(store, axis, row_key, stake, sleeve, use_vanilla)
    local group, key
    if axis == 'sleeves' then
        group, key = 'sleeve_stakes', MSP.matrix_key(row_key, stake.key)
    elseif sleeve then
        group, key = 'combo_stakes', MSP.matrix_key(row_key, sleeve, stake.key)
    else
        group, key = 'deck_stakes', MSP.matrix_key(row_key, stake.key)
    end
    local ours = MSP.tally_get(store, group, key, 'wins')

    -- The baseline only answers the plain deck-versus-stake question. Vanilla keeps no
    -- record of which sleeve was worn, so a slice cannot borrow from it.
    if use_vanilla and axis == 'decks' and not sleeve then
        return math.max(ours, vanilla_wins(row_key, stake))
    end
    return ours
end

--============================================================
-- Nodes
--============================================================
local function chip(colour, filled, w)
    return { n = G.UIT.C, config = { align = 'cm', minw = w, maxw = w, minh = w, r = 0.08,
                                     colour = filled and colour or G.C.UI.TRANSPARENT_LIGHT }, nodes = {} }
end

-- A grid cell carrying its win count. Vanilla's own New Game screen already answers
-- "cleared or not", so the number is the point of this table - a deck beaten once on Gold
-- reads differently from one beaten thirty times.
--
-- Zero stays an empty outline rather than a "0": at a glance the lit cells still have to
-- read as a completion map, and a grid of zeroes buries that.
-- Stake colours run from near-white to near-black, so the count picks its own contrast
-- rather than assuming a light chip.
local function ink_for(colour)
    local r, g, b = MSP.num(colour[1], 1), MSP.num(colour[2], 1), MSP.num(colour[3], 1)
    return (0.299 * r + 0.587 * g + 0.114 * b) < 0.55 and G.C.WHITE or G.C.BLACK
end

local function count_cell(count, colour, w, text_scale)
    local nodes = {}
    if count > 0 then
        nodes[1] = { n = G.UIT.T, config = { text = tostring(count), scale = text_scale,
                                             colour = ink_for(colour), shadow = false } }
    end
    return { n = G.UIT.C, config = { align = 'cm', minw = w, maxw = w, minh = w * 0.72, r = 0.08,
                                     colour = count > 0 and colour or G.C.UI.TRANSPARENT_LIGHT },
             nodes = nodes }
end

local function gap(w)
    return { n = G.UIT.C, config = { minw = w, minh = 0.05 }, nodes = {} }
end

local function grid_row(label, cells, dim)
    return { n = G.UIT.R, config = { align = 'cl', padding = 0.02 }, nodes = {
        { n = G.UIT.C, config = { align = 'cr', minw = LABEL_W, maxw = LABEL_W, padding = 0.03 }, nodes = {
            { n = G.UIT.T, config = { text = label, scale = 0.28,
                                      colour = dim and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT } },
        }},
        { n = G.UIT.C, config = { align = 'cl' }, nodes = cells },
    }}
end

--============================================================
-- Controls
--============================================================
G.FUNCS.mstat_set_axis = function(e)
    local axis = e and e.config and e.config.mstat_axis
    if not axis then return end
    MSP.view.axis = axis
    if axis == 'sleeves' then MSP.view.sleeve = nil end
    MSP.reopen_career()
end

-- The sleeve filter cycles rather than listing: the roster is open-ended, and a button per
-- sleeve would push the grid off the screen as soon as a sleeve pack is installed.
G.FUNCS.mstat_cycle_sleeve = function()
    local sleeves = sleeve_list(MSP.current_store and MSP.current_store())
    if #sleeves == 0 then return end
    local idx = 0
    for i, s in ipairs(sleeves) do if s.key == MSP.view.sleeve then idx = i break end end
    idx = idx + 1
    MSP.view.sleeve = (idx > #sleeves) and nil or sleeves[idx].key
    MSP.reopen_career()
end

local function button(label, fn, on, extra_key, extra_val, w)
    local cfg = { align = 'cm', minw = w or 1.8, minh = 0.45, r = 0.1, padding = 0.05,
                  colour = on and G.C.GREEN or G.C.BLACK, hover = not on, shadow = true,
                  button = fn, one_press = true }
    if extra_key then cfg[extra_key] = extra_val end
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.03 }, nodes = {
        { n = G.UIT.C, config = cfg, nodes = {
            { n = G.UIT.T, config = { text = label, scale = 0.3,
                                      colour = on and G.C.WHITE or G.C.UI.TEXT_LIGHT } },
        }},
    }}
end

--============================================================
-- The page
--============================================================
function G.UIDEF.mstat_completion()
    local store = MSP.current_store()
    if not store then
        return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = {
            { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
                { n = G.UIT.T, config = { text = 'No profile loaded.', scale = 0.35, colour = G.C.UI.TEXT_INACTIVE } },
            }},
        }}
    end

    local stakes = stake_list()
    local sleeves = sleeve_list(store)
    local axis = MSP.view.axis
    local rows_src = (axis == 'sleeves') and sleeves or deck_list()

    -- Cell size falls out of the column count, so the grid holds its width whatever the
    -- installed stake ladder looks like. Cells now carry a number, so they need enough room
    -- for the widest count actually present rather than a fixed square.
    local n = math.max(1, #stakes)
    local cell_w = math.max(0.22, math.min(0.44, (GRID_W + 1.2) / n))
    local pad = math.max(0.02, cell_w * 0.14)
    local text_scale = math.max(0.16, math.min(0.26, cell_w * 0.62))

    -- The vanilla baseline is only meaningful where vanilla itself was counting: it has no
    -- notion of these buckets, and every win it knows about was an honest one.
    local use_vanilla = (MSP.view.bucket == 'all' or MSP.view.bucket == 'normal')

    -- Header: a filled chip per stake with its name abbreviated underneath, which is what
    -- makes a 16-stake ladder readable without a legend block.
    local head_cells = {}
    for _, s in ipairs(stakes) do
        head_cells[#head_cells + 1] = { n = G.UIT.C, config = { align = 'cm' }, nodes = {
            { n = G.UIT.R, config = { align = 'cm' }, nodes = { chip(s.colour, true, cell_w) } },
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                { n = G.UIT.T, config = { text = s.abbr, scale = 0.2, colour = G.C.UI.TEXT_INACTIVE } },
            }},
        }}
        head_cells[#head_cells + 1] = gap(pad)
    end
    head_cells[#head_cells + 1] = { n = G.UIT.C, config = { align = 'cm', minw = cell_w + 0.1 }, nodes = {
        { n = G.UIT.T, config = { text = 'all', scale = 0.2, colour = G.C.UI.TEXT_INACTIVE } },
    }}

    local body = { grid_row('', head_cells) }
    local done, total, wins_total = 0, 0, 0
    for _, r in ipairs(rows_src) do
        local cells, row_done, row_wins = {}, 0, 0
        for _, s in ipairs(stakes) do
            local wins = win_count(store, axis, r.key, s, MSP.view.sleeve, use_vanilla)
            if wins > 0 then row_done, done = row_done + 1, done + 1 end
            row_wins = row_wins + wins
            total = total + 1
            cells[#cells + 1] = count_cell(wins, s.colour, cell_w, text_scale)
            cells[#cells + 1] = gap(pad)
        end
        wins_total = wins_total + row_wins

        -- Row total: how many wins this deck or sleeve has to its name across the ladder.
        cells[#cells + 1] = { n = G.UIT.C, config = { align = 'cm', minw = cell_w + 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = row_wins > 0 and tostring(row_wins) or '-',
                                      scale = 0.24,
                                      colour = row_wins > 0 and G.C.WHITE or G.C.UI.TEXT_INACTIVE } },
        }}
        body[#body + 1] = grid_row(r.label, cells, row_done == 0)
    end

    if #rows_src == 0 then
        body[#body + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = (axis == 'sleeves') and 'No sleeves installed.' or 'No decks found.',
                                      scale = 0.32, colour = G.C.UI.TEXT_INACTIVE } },
        }}
    end

    local sleeve_label = 'Any sleeve'
    if MSP.view.sleeve then
        for _, s in ipairs(sleeves) do if s.key == MSP.view.sleeve then sleeve_label = s.label end end
    end

    local controls = { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
        button('Decks', 'mstat_set_axis', axis == 'decks', 'mstat_axis', 'decks'),
        button('Sleeves', 'mstat_set_axis', axis == 'sleeves', 'mstat_axis', 'sleeves'),
    }}
    if axis == 'decks' and #sleeves > 0 then
        controls.nodes[#controls.nodes + 1] = gap(0.2)
        controls.nodes[#controls.nodes + 1] =
            button(sleeve_label, 'mstat_cycle_sleeve', MSP.view.sleeve ~= nil, nil, nil, 2.6)
    end

    local pct = total > 0 and (100 * done / total) or 0
    local summary = { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
        { n = G.UIT.T, config = { text = ('%d / %d cleared  (%.0f%%)'):format(done, total, pct),
                                  scale = 0.36, colour = done >= total and G.C.GREEN or G.C.UI.TEXT_LIGHT,
                                  shadow = true } },
        { n = G.UIT.T, config = { text = ('   ·   %d wins'):format(wins_total),
                                  scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
    }}

    return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR, padding = 0.04 }, nodes = {
        controls,
        summary,
        MSP.scrolled(body, 5.4),
        { n = G.UIT.R, config = { align = 'cm', padding = 0.04, maxw = 8 }, nodes = {
            { n = G.UIT.T, config = {
                text = (axis == 'decks' and MSP.view.sleeve)
                    and 'Wins with this deck and sleeve together.'
                    or (axis == 'decks' and 'Wins with each deck, any sleeve.' or 'Wins with each sleeve, any deck.'),
                scale = 0.26, colour = G.C.UI.TEXT_INACTIVE } },
        }},
    }}
end
