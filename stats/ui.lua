-- Moar Stats Please - the three display surfaces.
--
--   1. A Stats tab inside the in-run Run Info overlay.
--   2. A career page, reachable from the mod menu, with a tab per bucket and a sub-tab per
--      category, plus records, breakdowns and the run history.
--   3. Extra rows on the Game Over / win screen.
--
-- Every list that can outgrow the screen is wrapped in an SMODS scroll box, with a plain
-- column as the fallback when SMODS is too old to have one.

local ROW_W = 6.6

--============================================================
-- Colour
--============================================================
-- Rows sit on the dark page, so they are dark plates with light text. The previous scheme
-- put pure white (G.C.UI.TEXT_LIGHT is {1,1,1,1}) on darken(G.C.JOKER_GREY, 0.1) - and
-- JOKER_GREY is #bfc7d5, a LIGHT grey - which is white on near-white.
--
-- Resolved through functions rather than tables built at load: G.C is assembled at boot and
-- this file is only guaranteed to run after it, not to be re-read if a mod restyles it.
local function plate(alt)
    return alt and darken(G.C.L_BLACK, 0.45) or darken(G.C.L_BLACK, 0.28)
end

-- A value wears the game's own colour for what it is, so a number reads as money or chips or
-- mult before the label is read at all.
local function value_colour(fmt)
    if fmt == 'money' then return G.C.MONEY end
    if fmt == 'score' then return G.C.BLUE end       -- chips
    if fmt == 'x'     then return G.C.RED  end       -- mult
    if fmt == 'pct'   then return G.C.GREEN end
    if fmt == 'time'  then return G.C.PURPLE end
    return G.C.UI.TEXT_LIGHT
end

-- Each section gets its own accent, which is what lets a long scroll be navigated by colour
-- rather than by reading every header.
local function cat_colour(id)
    local map = {
        hands = G.C.BLUE, cards = G.C.ORANGE, blinds = G.C.RED, economy = G.C.MONEY,
        shop = G.C.GREEN, items = G.C.PURPLE, deck = G.C.ORANGE, meta = G.C.FILTER,
    }
    return map[id] or G.C.FILTER
end

-- Sections in the Breakdown get an accent too, matched to what they are about.
local function group_colour(gid)
    local map = {
        jokers = G.C.PURPLE, joker_scale = G.C.RED, consumables = G.C.SECONDARY_SET and G.C.SECONDARY_SET.Tarot,
        vouchers = G.C.SECONDARY_SET and G.C.SECONDARY_SET.Voucher, tags = G.C.ORANGE,
        bosses = G.C.RED, packs = G.C.GREEN, decks = G.C.BLUE, sleeves = G.C.BLUE,
        stakes = G.C.GOLD, suits = G.C.ORANGE, ranks = G.C.ORANGE,
        enhancements = G.C.BLUE, editions = G.C.PURPLE, seals = G.C.GOLD,
    }
    return map[gid] or G.C.FILTER
end

--============================================================
-- Rows
--============================================================
-- One label-and-value line. Zero values are dimmed rather than hidden: an explicit 0 is
-- information, and a list that changes length as you play is hard to read.
--
-- `alt` alternates the plate shade. Banding is what makes a label on the left and a number
-- on the right read as the same row across six inches of empty middle.
local function row(label, value, opts)
    opts = opts or {}
    local dim = opts.dim
    local w = opts.w or ROW_W
    local ts = opts.scale or 1
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.035, minw = w, r = 0.1,
                                     colour = opts.colour or plate(opts.alt) }, nodes = {
        { n = G.UIT.C, config = { align = 'cl', padding = 0.04, minw = w * 0.6, maxw = w * 0.6 }, nodes = {
            { n = G.UIT.T, config = { text = label, scale = 0.33 * ts,
                                      colour = dim and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT } },
        }},
        { n = G.UIT.C, config = { align = 'cr', padding = 0.04, minw = w * 0.36, maxw = w * 0.38 }, nodes = {
            { n = G.UIT.T, config = { text = value, scale = 0.36 * ts,
                                      colour = dim and G.C.UI.TEXT_INACTIVE or (opts.value_colour or G.C.UI.TEXT_LIGHT),
                                      shadow = not dim } },
        }},
    }}
end

-- A section title on its own coloured bar, so sections are findable while scrolling.
local function header(text, colour, w)
    colour = colour or G.C.FILTER
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.05, minw = w or ROW_W, minh = 0.42,
                                     r = 0.1, colour = darken(colour, 0.55) }, nodes = {
        { n = G.UIT.C, config = { align = 'cm', minw = 0.14, minh = 0.3, r = 0.05, colour = colour }, nodes = {} },
        { n = G.UIT.C, config = { align = 'cl', padding = 0.08 }, nodes = {
            { n = G.UIT.T, config = { text = text, scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }},
    }}
end

local function note(text)
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.05, maxw = ROW_W }, nodes = {
        { n = G.UIT.T, config = { text = text, scale = 0.28, colour = G.C.UI.TEXT_INACTIVE } },
    }}
end

-- Wraps a column of rows in a scroll box so a long list stays on screen. Shared with
-- grid.lua, which builds its own rows but wants the same scrolling behaviour.
function MSP.scrolled(rows, maxh)
    maxh = maxh or 6.2
    local content = { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
        { n = G.UIT.C, config = { align = 'tm', padding = 0.02 }, nodes = rows } } }

    if SMODS.UIScrollBox and SMODS.GUI and SMODS.GUI.scrollbar then
        local box = SMODS.UIScrollBox({
            content = { definition = { n = G.UIT.ROOT, config = { colour = G.C.CLEAR }, nodes = { content } },
                        config = { align = 'cm' } },
            overflow = { node_config = { maxh = maxh, r = 0.1 } },
            sync_mode = 'offset',
        })
        return { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, colour = G.C.BLACK }, nodes = {
            { n = G.UIT.C, config = {}, nodes = { { n = G.UIT.O, config = { object = box } } } },
            { n = G.UIT.C, config = { padding = 0.05 }, nodes = {
                SMODS.GUI.scrollbar({ w = 0.12, h = maxh - 0.1, scroll_collision_obj = box,
                                      knob_h = maxh / 6, bg_colour = { 0, 0, 0, 0.2 } }),
            }},
        }}
    end
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, colour = G.C.BLACK }, nodes = { content } }
end

local function page(rows, maxh)
    if #rows == 0 then
        rows = { note('Nothing tracked yet.') }
    end
    return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR, padding = 0.05 }, nodes = { MSP.scrolled(rows, maxh) } }
end

--============================================================
-- Naming
--============================================================
-- Turns a game key into something readable, preferring the game's own localised name so a
-- modded Joker or Boss reads correctly without this mod knowing anything about it.
local function pretty(key, set)
    if key == nil then return '?' end
    key = tostring(key)
    if set then
        local ok, name = pcall(function() return localize{ type = 'name_text', key = key, set = set } end)
        if ok and name and name ~= '' and name ~= 'ERROR' then return name end
    end
    local center = G.P_CENTERS and G.P_CENTERS[key]
    if center and center.name then return center.name end
    local blind = G.P_BLINDS and G.P_BLINDS[key]
    if blind and blind.name then return blind.name end
    local tag = G.P_TAGS and G.P_TAGS[key]
    if tag and tag.name then return tag.name end
    -- Fall back to the bare key with its type prefix stripped.
    return (key:gsub('^[a-z]+_', ''):gsub('_', ' '))
end

local SET_FOR_GROUP = {
    jokers = 'Joker', vouchers = 'Voucher', tags = 'Tag', bosses = 'Blind',
    decks = 'Back', sleeves = 'Sleeve', stakes = 'Stake',
}

--============================================================
-- Stat pages
--============================================================
-- One category of the schema, drawn from a store (a run or a career bucket). `is_run` is
-- passed rather than flagged onto the store, because the run store is the live G.GAME table
-- and anything written there ends up in the save file.
local function category_rows(store, cat_id, is_run)
    local rows = {}
    for _, e in ipairs(MSP.STATS_BY_CAT[cat_id] or {}) do
        local skip = e.career_only and is_run
        if not skip then
            local v = MSP.stat_value(store, e)
            rows[#rows + 1] = row(e.label, MSP.format(v, e.fmt), {
                dim = (MSP.num(v) == 0),
                value_colour = value_colour(e.fmt),
                alt = (#rows % 2 == 1),
            })
        end
    end
    return rows
end

local function records_rows(store)
    local rows = {}
    for _, def in ipairs(MSP.RECORDS) do
        local entry = store.records and store.records[def.key]
        if entry then
            rows[#rows + 1] = row(def.label, MSP.record_text(def, entry),
                                  { value_colour = G.C.GOLD, alt = (#rows % 2 == 1) })
            -- Where and when the record was set, in small type under the value.
            if entry.seed or entry.date then
                rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cr', padding = 0.01, minw = ROW_W }, nodes = {
                    { n = G.UIT.T, config = { text = ('%s  %s'):format(tostring(entry.seed or ''), tostring(entry.date or '')),
                                              scale = 0.24, colour = G.C.UI.TEXT_INACTIVE } },
                }}
            end
        else
            rows[#rows + 1] = row(def.label, '-', { dim = true, alt = (#rows % 2 == 1) })
        end
    end
    return rows
end

--============================================================
-- Poker hands
--============================================================
-- Every poker hand the game knows about, in the game's own order - best hand first, the way
-- the Poker Hands tab lists them. Hands that have never been landed are still shown: Flush
-- Five sitting at zero is information, and a list that grows as you play is hard to read.
--
-- The roster comes from G.GAME.hands and SMODS.PokerHands, so a modded hand appears here
-- with no edit, and anything already recorded is included even if its mod is now absent.
local function hand_roster(store)
    local out, seen = {}, {}
    local function push(key, order)
        if key and not seen[key] then
            seen[key] = true
            out[#out + 1] = { key = key, order = MSP.num(order, 999) }
        end
    end
    for k, v in pairs((G.GAME and G.GAME.hands) or {}) do push(k, type(v) == 'table' and v.order) end
    for k, v in pairs((SMODS and SMODS.PokerHands) or {}) do push(k, type(v) == 'table' and v.order) end
    for k in pairs((store.groups or {}).hands or {}) do push(k, nil) end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    return out
end

local function hand_name(key)
    local ok, nm = pcall(localize, key, 'poker_hands')
    if ok and nm and nm ~= '' and nm ~= 'ERROR' then return nm end
    return key
end

local function hands_rows(store, is_run, phase)
    phase = phase or 'all'
    local g = (store.groups or {}).hands or {}
    local rows = {}
    for _, h in ipairs(hand_roster(store)) do
        local f = g[h.key]
        local played = MSP.field_for(f, 'played', phase)

        local bits = { played .. ' played' }
        local best = MSP.mag_for(f, 'best', phase)
        if best and best.str then bits[#bits + 1] = 'best ' .. best.str end
        local royal = MSP.field_for(f, 'royal', phase)
        if royal > 0 then bits[#bits + 1] = royal .. ' royal' end

        -- In a run the level that matters is the one in play; across a career it is the
        -- highest ever reached.
        local live = is_run and G.GAME and G.GAME.hands and G.GAME.hands[h.key]
        local lvl_mag = MSP.mag_for(f, 'level', phase)
        local lvl = live and MSP.num(live.level) or (lvl_mag and MSP.num(lvl_mag.num)) or 0
        if lvl > 0 then bits[#bits + 1] = 'lvl ' .. math.floor(lvl) end

        rows[#rows + 1] = row(hand_name(h.key), table.concat(bits, '  '),
                              { dim = played == 0, alt = (#rows % 2 == 1) })
    end
    return rows
end

-- Field names as a player would say them. The scaling tracker reports whatever field a
-- Joker happens to grow, including from mods, so an unknown name falls through readably
-- rather than being dropped.
local SCALE_LABEL = {
    x_mult = 'X-mult', Xmult = 'X-mult', xmult = 'X-mult', h_x_mult = 'X-mult in hand',
    perma_x_mult = 'X-mult', mult = 'Mult', perma_mult = 'Mult', h_mult = 'Mult in hand',
    chips = 'Chips', perma_bonus = 'Chips', h_chips = 'Chips in hand', dollars = '$',
    h_size = 'Hand size', d_size = 'Discards',
}

local function scale_label(field)
    local leaf = field:match('([^.]+)$') or field
    return SCALE_LABEL[leaf] or (leaf:gsub('_', ' '))
end

-- A breakdown group, sorted so the interesting entries land at the top. Scaling rows sort by
-- magnitude; everything else by its running count.
local function group_rows(store, gid, phase)
    phase = phase or 'all'
    local g = store.groups and store.groups[gid]
    if not g then return {} end

    local scale = (gid == 'joker_scale')
    local list = {}
    for key, fields in pairs(g) do
        -- Sum only the fields belonging to this phase, so an entry that saw no play in the
        -- selected phase sorts to the bottom and can be dropped entirely.
        local total = 0
        for f, v in pairs(fields) do
            if not MSP.is_mag_field(f) and f:sub(-8) ~= '_endless' then
                total = total + MSP.field_for(fields, f, phase)
            end
        end
        local best = MSP.mag_for(fields, 'best', phase)
        list[#list + 1] = {
            key = key, fields = fields, total = total, best = best,
            rank = scale and MSP.num(best and best.log, -1e300) or total,
        }
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.key < b.key
    end)

    local set = SET_FOR_GROUP[gid]
    local rows = {}
    for _, item in ipairs(list) do
        local f = item.fields
        local function n(field) return MSP.field_for(f, field, phase) end

        -- Nothing happened here in the selected phase, so the row would be a line of zeroes.
        local empty = (item.total == 0) and not (scale and item.best)
        if not empty then
            local value
            if gid == 'decks' or gid == 'stakes' or gid == 'sleeves' then
                value = ('%d played  %dW / %dL'):format(n('plays'), n('wins'), n('losses'))
            elseif gid == 'bosses' then
                value = ('met %d  beat %d  lost %d'):format(n('faced'), n('defeated'), n('lost_to'))
            elseif gid == 'joker_scale' then
                value = (item.best and item.best.str) or '-'
            elseif gid == 'jokers' then
                local bits = {}
                if n('bought') > 0 then bits[#bits + 1] = n('bought') .. ' bought' end
                if n('rounds') > 0 then bits[#bits + 1] = n('rounds') .. ' rounds' end
                if n('triggers') > 0 then bits[#bits + 1] = MSP.format(n('triggers'), 'int') .. ' triggers' end
                if n('sold') > 0 then bits[#bits + 1] = n('sold') .. ' sold' end
                if n('wins') > 0 then bits[#bits + 1] = n('wins') .. 'W' end
                if n('losses') > 0 then bits[#bits + 1] = n('losses') .. 'L' end
                if n('paid') > 0 then bits[#bits + 1] = '+$' .. n('paid') end
                if n('rent') > 0 then bits[#bits + 1] = '-$' .. n('rent') .. ' rent' end
                value = table.concat(bits, '  ')
            elseif gid == 'packs' then
                value = ('%d opened  %d bought'):format(n('opened'), n('bought'))
            else
                value = MSP.format(item.total, 'int')
            end

            local label = pretty(item.key, set)
            if scale then
                -- Key is jokerkey@field; the field is what grew.
                local jk, fld = item.key:match('^(.-)@(.+)$')
                label = jk and (pretty(jk, 'Joker') .. '  ' .. scale_label(fld)) or label
            end
            rows[#rows + 1] = row(label, value, {
                alt = (#rows % 2 == 1),
                value_colour = scale and G.C.RED or nil,
            })
        end
    end
    return rows
end

--============================================================
-- Surface 1: the Run Info tab
--============================================================
-- Presents the live run. G.GAME.mstat is the store, and it is read straight - no flush is
-- needed, because the run's own counters are always current.
function G.UIDEF.mstat_run_tab()
    local r = MSP.run()
    if not r then return page({ note('No run in progress.') }) end

    local rows = {}
    local m = r.meta or {}
    rows[#rows + 1] = header('This run', G.C.GREEN)
    rows[#rows + 1] = row('Deck', pretty(m.deck, 'Back'))
    if m.sleeve then rows[#rows + 1] = row('Sleeve', pretty(m.sleeve)) end
    rows[#rows + 1] = row('Stake', m.stake_key and pretty(m.stake_key, 'Stake') or ('Stake ' .. tostring(m.stake or 1)))
    rows[#rows + 1] = row('Seed', tostring(m.seed or '?'))
    rows[#rows + 1] = row('Time', MSP.format(r.time, 'time'))

    rows[#rows + 1] = header('Records', G.C.GOLD)
    for _, n in ipairs(records_rows(r)) do rows[#rows + 1] = n end

    for _, cat in ipairs(MSP.CATS) do
        local body = category_rows(r, cat.id, true)
        if #body > 0 then
            rows[#rows + 1] = header(cat.label, cat_colour(cat.id))
            for _, n in ipairs(body) do rows[#rows + 1] = n end
        end
        -- The poker hand table belongs with the hand counters it explains.
        if cat.id == 'hands' then
            rows[#rows + 1] = header('Poker hands', cat_colour('hands'))
            for _, n in ipairs(hands_rows(r, true)) do rows[#rows + 1] = n end
        end
    end

    for _, grp in ipairs(MSP.GROUPS) do
        local body = group_rows(r, grp.id)
        if #body > 0 then
            rows[#rows + 1] = header(grp.label, group_colour(grp.id))
            for _, n in ipairs(body) do rows[#rows + 1] = n end
        end
    end

    return page(rows, 7.2)
end

-- Injects the tab into vanilla's Run Info without rebuilding it. The tab list is only
-- reachable while run_info is running, so create_tabs is borrowed for exactly that one call
-- and put straight back - which also means every other mod's tabs are still there.
local mstat_run_info = G.UIDEF.run_info
function G.UIDEF.run_info(...)
    if not (MSP.CFG and MSP.CFG.run_tab) then return mstat_run_info(...) end

    local original = create_tabs
    create_tabs = function(args)
        create_tabs = original
        if args and args.tabs then
            args.tabs[#args.tabs + 1] = {
                label = 'Stats',
                tab_definition_function = G.UIDEF.mstat_run_tab,
            }
        end
        return original(args)
    end

    local ok, ret = pcall(mstat_run_info, ...)
    create_tabs = original
    if not ok then error(ret) end
    return ret
end

--============================================================
-- Surface 2: the career page
--============================================================
-- Built up rather than replaced: grid.lua adds its own axis and sleeve keys to this same
-- table, and load order should not decide which of them survives.
MSP.view = MSP.view or {}
MSP.view.bucket = MSP.view.bucket or 'all'
MSP.view.tab = MSP.view.tab or 'overview'
MSP.view.phase = MSP.view.phase or 'all'

-- Which career store the page is currently showing. Shared with grid.lua.
function MSP.current_store()
    if MSP.view.bucket == 'all' then return MSP.combined_career() end
    return MSP.career(MSP.view.bucket)
end
local current_store = MSP.current_store

-- Switching phase rebuilds the overlay, like every other control here: tab contents are
-- built once when the tab is created.
G.FUNCS.mstat_set_phase = function(e)
    local id = e and e.config and e.config.mstat_phase
    if not id then return end
    MSP.view.phase = id
    MSP.reopen_career()
end

local function phase_buttons()
    local cols = {}
    for _, ph in ipairs(MSP.PHASES) do
        local on = (MSP.view.phase == ph.id)
        cols[#cols + 1] = { n = G.UIT.C, config = { align = 'cm', padding = 0.03 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', minw = 1.7, minh = 0.42, r = 0.1, padding = 0.04,
                                      colour = on and G.C.BLUE or darken(G.C.L_BLACK, 0.3),
                                      hover = not on, shadow = true,
                                      button = 'mstat_set_phase', mstat_phase = ph.id,
                                      one_press = true }, nodes = {
                { n = G.UIT.T, config = { text = ph.label, scale = 0.3,
                                          colour = on and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE } },
            }},
        }}
    end
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = cols }
end

local function overview_page()
    local store = current_store()
    if not store then return page({ note('No profile loaded.') }) end

    local rows = { header('Records', G.C.GOLD) }
    for _, n in ipairs(records_rows(store)) do rows[#rows + 1] = n end

    rows[#rows + 1] = header('Runs', cat_colour('meta'))
    for _, n in ipairs(category_rows(store, 'meta')) do rows[#rows + 1] = n end

    local s = store.streak
    if s then
        rows[#rows + 1] = row('Current win streak', MSP.format(s.win, 'int'),
                              { value_colour = G.C.GREEN })
        rows[#rows + 1] = row('Current loss streak', MSP.format(s.loss, 'int'),
                              { value_colour = G.C.RED, alt = true })
    end
    return page(rows)
end

local function totals_page()
    local store = current_store()
    if not store then return page({}) end
    local rows = {}
    for _, cat in ipairs(MSP.CATS) do
        if cat.id ~= 'meta' then
            local body = category_rows(store, cat.id)
            if #body > 0 then
                rows[#rows + 1] = header(cat.label, cat_colour(cat.id))
                for _, n in ipairs(body) do rows[#rows + 1] = n end
            end
        end
    end
    return page(rows)
end

local function breakdown_page()
    local store = current_store()
    if not store then return page({}) end
    local phase = MSP.view.phase

    -- The phase control lives on this page rather than beside the bucket buttons: it only
    -- changes what Breakdown shows, and a global control that silently does nothing on three
    -- of the five tabs is worse than no control.
    local rows = { phase_buttons() }

    rows[#rows + 1] = header('Poker hands', cat_colour('hands'))
    for _, n in ipairs(hands_rows(store, false, phase)) do rows[#rows + 1] = n end

    for _, grp in ipairs(MSP.GROUPS) do
        local body = group_rows(store, grp.id, phase)
        if #body > 0 then
            rows[#rows + 1] = header(grp.label, group_colour(grp.id))
            for _, n in ipairs(body) do rows[#rows + 1] = n end
        end
    end

    if #rows <= 2 then
        rows[#rows + 1] = note(phase == 'endless'
            and 'No Endless play recorded yet.'
            or 'Nothing tracked yet.')
    end
    return page(rows)
end

-- The run log, newest first. Two lines per run: the result and where it got to, then the
-- identity underneath in small type.
local function history_page()
    local st = MSP.profile()
    if not st or #st.runs == 0 then
        return page({ note('No finished runs yet.') })
    end

    local rows = {}
    for i = #st.runs, 1, -1 do
        local rec = st.runs[i]
        if MSP.view.bucket == 'all' or rec.bucket == MSP.view.bucket then
            local colour = rec.result == 'win' and G.C.GREEN
                or rec.result == 'loss' and G.C.RED or G.C.UI.TEXT_INACTIVE
            local label = ('%s  %s'):format(rec.date or '?', pretty(rec.deck, 'Back'))
            local value = ('%s  Ante %d'):format((rec.result or '?'):upper(), MSP.num(rec.ante))
            rows[#rows + 1] = row(label, value, { value_colour = colour })
            rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cl', padding = 0.01, minw = ROW_W }, nodes = {
                { n = G.UIT.T, config = {
                    text = ('   %s · %s · %d hands · best %s · %s'):format(
                        rec.stake_key and pretty(rec.stake_key, 'Stake') or ('Stake ' .. MSP.num(rec.stake, 1)),
                        tostring(rec.seed or '?'), MSP.num(rec.hands),
                        tostring(rec.best_hand or '0'), MSP.format(rec.time, 'time')),
                    scale = 0.24, colour = G.C.UI.TEXT_INACTIVE } },
            }}
        end
    end
    if #rows == 0 then return page({ note('No finished runs in this bucket.') }) end
    return page(rows)
end

-- Changing what the page shows rebuilds the whole overlay: tab contents are built once when
-- the tab is created and there is no repaint hook to push new numbers through. Shared with
-- grid.lua, whose axis and sleeve controls need the same rebuild.
function MSP.reopen_career()
    G.FUNCS.exit_overlay_menu()
    G.FUNCS.mstat_open_career()
end

G.FUNCS.mstat_set_bucket = function(e)
    local id = e and e.config and e.config.mstat_bucket
    if not id then return end
    MSP.view.bucket = id
    MSP.reopen_career()
end

local function bucket_buttons()
    local opts = { { id = 'all', label = 'All' } }
    for _, b in ipairs(MSP.BUCKETS) do opts[#opts + 1] = b end

    local cols = {}
    for _, o in ipairs(opts) do
        local on = (MSP.view.bucket == o.id)
        cols[#cols + 1] = { n = G.UIT.C, config = { align = 'cm', padding = 0.04 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', minw = 1.5, minh = 0.5, r = 0.1, padding = 0.05,
                                      colour = on and G.C.GREEN or G.C.BLACK, hover = not on, shadow = true,
                                      button = 'mstat_set_bucket', mstat_bucket = o.id, one_press = true }, nodes = {
                { n = G.UIT.T, config = { text = o.label, scale = 0.34,
                                          colour = on and G.C.WHITE or G.C.UI.TEXT_LIGHT } },
            }},
        }}
    end
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = cols }
end

-- A tab definition function runs when its tab is selected, which is the only signal the
-- game offers. Recording the id there is what lets a bucket or axis change reopen the page
-- on the tab the player was already looking at instead of throwing them back to Overview.
local function tab(id, label, fn)
    return {
        label = label,
        chosen = (MSP.view.tab == id),
        tab_definition_function = function()
            MSP.view.tab = id
            return fn()
        end,
    }
end

function G.UIDEF.mstat_career()
    return create_UIBox_generic_options({
        back_func = 'exit_overlay_menu',
        contents = {
            { n = G.UIT.R, config = { align = 'cm', padding = 0.06 }, nodes = {
                { n = G.UIT.T, config = { text = 'Career Stats', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            }},
            bucket_buttons(),
            create_tabs({
                tabs = {
                    tab('overview',   'Overview',   overview_page),
                    tab('completion', 'Completion', function() return G.UIDEF.mstat_completion() end),
                    tab('totals',     'Totals',     totals_page),
                    tab('breakdown',  'Breakdown',  breakdown_page),
                    tab('history',    'History',    history_page),
                },
                tab_h = 7,
                snap_to_nav = true,
            }),
        },
    })
end

G.FUNCS.mstat_open_career = function()
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    G.FUNCS.overlay_menu{ definition = G.UIDEF.mstat_career() }
end

--============================================================
-- Surface 3: the Game Over screen
--============================================================
-- Vanilla rebuilds the root's first node as ONE row of two columns - the jimbo_spot on the
-- left, the score panel on the right (UI_definitions.lua:3247). The extra stats go in as a
-- third column of that same row: the overlay keeps its height, so nothing is pushed off the
-- bottom of the screen, and the block sits on the far side from Jimbo and his speech bubble.
--
-- Narrow and unscrolled on purpose. Width is the scarce axis once there are three columns,
-- and a scrollbar would spend some of it.
local GO_W = 4.0

local GO_JOKERS = 5

-- A small second line under a Joker, capped to the column so a long one shrinks to fit
-- rather than running into the next column (engine/ui.lua:166 scales a node's contents
-- down to its maxw).
local function detail(text)
    return { n = G.UIT.R, config = { align = 'cl', padding = 0.01, minw = GO_W, maxw = GO_W }, nodes = {
        { n = G.UIT.T, config = { text = '   ' .. text, scale = 0.25, colour = G.C.UI.TEXT_INACTIVE } },
    }}
end

-- The Jokers this run actually had, longest-held first. Built from the run's own Joker
-- tallies, so a Joker shows here only if this run touched it.
local function run_jokers(r)
    local list = {}
    for key, f in pairs((r.groups and r.groups.jokers) or {}) do
        list[#list + 1] = { key = key, f = f }
    end
    table.sort(list, function(a, b)
        local ra, rb = MSP.num(a.f.rounds), MSP.num(b.f.rounds)
        if ra ~= rb then return ra > rb end
        local ta, tb = MSP.num(a.f.triggers), MSP.num(b.f.triggers)
        if ta ~= tb then return ta > tb end
        return a.key < b.key
    end)
    return list
end

-- A Joker's strongest scaled value this run, if it scales at all.
local function best_scale(r, key)
    local best, field
    for k, e in pairs((r.groups and r.groups.joker_scale) or {}) do
        local jk, fld = k:match('^(.-)@(.+)$')
        if jk == key and e.best_log and (not best or e.best_log > best.best_log) then
            best, field = e, fld
        end
    end
    return best and (scale_label(field) .. ' ' .. tostring(best.best_str)) or nil
end

local function game_over_panel(r)
    local rows = {}
    local function add(label, value, colour)
        rows[#rows + 1] = row(label, value, { w = GO_W, scale = 0.85, value_colour = colour,
                                              alt = (#rows % 2 == 1) })
    end
    add('Time played', MSP.format(r.time, 'time'), G.C.PURPLE)
    add('Hands played', MSP.format(r.t.hands_played, 'int'))
    add('Discards used', MSP.format(r.t.discards_used, 'int'))
    add('Money earned', MSP.format(r.t.earned_total, 'money'), G.C.MONEY)
    add('Money spent', MSP.format(r.t.spent_total, 'money'), G.C.MONEY)
    -- Rent only matters to a run that carried a Rental card, so it shows only then.
    if MSP.num(r.t.rent_paid) > 0 then add('Rent paid', MSP.format(r.t.rent_paid, 'money'), G.C.RED) end
    add('Rerolls', MSP.format(r.t.rerolls, 'int'))
    add('Blinds skipped', MSP.format(r.t.blinds_skipped, 'int'))

    local ov = r.records and r.records.best_overkill
    if ov then add('Biggest overkill', MSP.record_text({ fmt = 'x' }, ov), G.C.RED) end

    local body = {
        header('Moar Stats', G.C.GREEN, GO_W),
        { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
            { n = G.UIT.C, config = { align = 'tm', padding = 0.02 }, nodes = rows },
        }},
    }

    -- Capped, because this column shares the screen's height with the score panel beside
    -- it; the full list lives in Run Info and the career Breakdown.
    local jokers = run_jokers(r)
    if #jokers > 0 then
        local jrows = {}
        for i = 1, math.min(GO_JOKERS, #jokers) do
            local key, f = jokers[i].key, jokers[i].f
            local paid = MSP.num(f.paid)
            jrows[#jrows + 1] = row(pretty(key, 'Joker'), paid > 0 and ('+$' .. paid) or '', {
                w = GO_W, scale = 0.85, value_colour = G.C.MONEY, alt = (i % 2 == 0),
            })

            local bits = {}
            if MSP.num(f.rounds) > 0 then bits[#bits + 1] = MSP.num(f.rounds) .. ' rounds' end
            if MSP.num(f.triggers) > 0 then bits[#bits + 1] = MSP.format(f.triggers, 'int') .. ' triggers' end
            if MSP.num(f.rent) > 0 then bits[#bits + 1] = '$' .. MSP.num(f.rent) .. ' rent' end
            local sc = best_scale(r, key)
            if sc then bits[#bits + 1] = sc end
            if #bits > 0 then jrows[#jrows + 1] = detail(table.concat(bits, '  ')) end
        end
        if #jokers > GO_JOKERS then
            jrows[#jrows + 1] = detail(('+%d more in Run Info'):format(#jokers - GO_JOKERS))
        end

        body[#body + 1] = header('Jokers', G.C.PURPLE, GO_W)
        body[#body + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
            { n = G.UIT.C, config = { align = 'tm', padding = 0.02 }, nodes = jrows },
        }}
    end

    -- Styled like vanilla's own score panel beside it: black, embossed, rounded.
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.1 }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.06, colour = G.C.BLACK, emboss = 0.05, r = 0.1 }, nodes = body },
    }}
end

-- Both end-of-run screens are built the same way: vanilla replaces the root's first node with
-- ONE row of [jimbo_spot column | score column] - create_UIBox_game_over at
-- UI_definitions.lua:3247 and create_UIBox_win at :3112. The panel joins that row as a third
-- column on either screen.
--
-- The row is found by the id vanilla gives the Jimbo spot, rather than by position alone, so
-- another mod reshuffling the root leaves the panel off instead of somewhere odd.
local function holds_jimbo(node, depth)
    if type(node) ~= 'table' or depth > 4 then return false end
    if node.config and node.config.id == 'jimbo_spot' then return true end
    for _, child in ipairs(node.nodes or {}) do
        if holds_jimbo(child, depth + 1) then return true end
    end
    return false
end

local function attach_panel(box)
    if not (MSP.CFG and MSP.CFG.game_over_rows) then return box end
    local target = box and box.nodes and box.nodes[1]
    if not (target and target.nodes and holds_jimbo(target, 0)) then return box end

    local ok, panel = pcall(function()
        local r = MSP.run()
        return r and game_over_panel(r) or nil
    end)
    if ok and panel then target.nodes[#target.nodes + 1] = panel end
    return box
end

local mstat_game_over = create_UIBox_game_over
function create_UIBox_game_over(...)
    return attach_panel(mstat_game_over(...))
end

local mstat_win = create_UIBox_win
function create_UIBox_win(...)
    return attach_panel(mstat_win(...))
end
