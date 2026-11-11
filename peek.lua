-- Pinochle - Peek Store.

local PEEK_MAX = 8

--============================================================
-- Visibility
--============================================================
local function is_endless()
    return G.GAME and G.GAME.round_resets and G.GAME.win_ante
        and (G.GAME.round_resets.ante or 1) > G.GAME.win_ante
end

function MVP.peek_allowed()
    if not (G.STATE == G.STATES.SHOP and G.shop_jokers and G.GAME) then return false end
    local mode = (MVP.CFG and MVP.CFG.peek_mode) or 2
    if mode == 1 then return false end
    if mode == 3 then return true end                 -- Always (debug)
    return is_endless() or G.GAME.seeded == true      -- Endless & Seeded
end

local mvp_update_shop = Game.update_shop
function Game:update_shop(dt)
    if not G.shop and G.GAME then G.GAME.mvp_shop_stocked = nil end
    mvp_update_shop(self, dt)
    if G.GAME and G.shop_jokers and #G.shop_jokers.cards > 0 then
        G.GAME.mvp_shop_stocked = true
    end
end

function MVP.peek_ready()
    return MVP.peek_allowed() and G.GAME.mvp_shop_stocked == true
end

local function peek_depth()
    local d = (MVP.CFG and MVP.CFG.peek_depth) or 5
    return math.max(1, math.min(PEEK_MAX, d))
end

--============================================================
-- Reroll cost
--============================================================

local function reroll_cost(r)
    local cr = G.GAME.current_round
    local base = MVP.plain(G.GAME.round_resets.temp_reroll_cost or G.GAME.round_resets.reroll_cost) or 5
    local inc = MVP.plain(cr.reroll_cost_increase) or 0
    local free = MVP.plain(cr.free_rerolls) or 0
    if r <= free then return 0 end
    return math.max(0, base + inc + (r - free - 1))
end

--============================================================
-- Card shop simulation -- we do this to "generate" what potentially comes next, not 100% reliable
--============================================================

local EDITION_TAGS = {
    ['Foil Tag'] = 'e_foil', ['Holographic Tag'] = 'e_holo',
    ['Polychrome Tag'] = 'e_polychrome', ['Negative Tag'] = 'e_negative',
}

local function edition_name(ed)
    if type(ed) == 'table' then ed = next(ed) and ('e_' .. next(ed)) end   -- vanilla-style {foil = true}
    if type(ed) ~= 'string' then return nil end
    local ok, name = pcall(localize, { type = 'name_text', key = ed, set = 'Edition' })
    if ok and name and name ~= '' and name ~= 'ERROR' then return name:lower() end
    return (ed:gsub('^e_', ''))
end

-- Unspent edition Tags wait for the next editionless shop Joker (tag.lua store_joker_modify)
local function pending_edition_tags()
    local q = {}
    for _, tag in ipairs(G.GAME.tags or {}) do
        if not tag.triggered and tag.config and tag.config.type == 'store_joker_modify' then
            if not EDITION_TAGS[tag.name] then break end
            q[#q + 1] = EDITION_TAGS[tag.name]
        end
    end
    return q
end

local function sim_shop_card(tag_q)
    local ante = G.GAME.round_resets.ante   
    G.GAME.spectral_rate = G.GAME.spectral_rate or 0
    local total_rate = G.GAME.joker_rate + G.GAME.playing_card_rate
    for _, v in ipairs(SMODS.ConsumableType.obj_buffer) do
        total_rate = total_rate + G.GAME[v:lower() .. '_rate']
    end
    local polled_rate = pseudorandom(pseudoseed('cdt' .. ante)) * total_rate
    local rates = {
        { type = 'Joker', val = G.GAME.joker_rate },
        { type = 'Tarot', val = G.GAME.tarot_rate },
        { type = 'Planet', val = G.GAME.planet_rate },
        { type = (G.GAME.used_vouchers['v_illusion'] and pseudorandom(pseudoseed('illusion')) > 0.6)
            and 'Enhanced' or 'Base', val = G.GAME.playing_card_rate },
        { type = 'Spectral', val = G.GAME.spectral_rate },
    }
    for _, v in ipairs(SMODS.ConsumableType.obj_buffer) do
        if not (v == 'Tarot' or v == 'Planet' or v == 'Spectral') then
            table.insert(rates, { type = v, val = G.GAME[v:lower() .. '_rate'] })
        end
    end

    local set
    local check_rate = 0
    for _, v in ipairs(rates) do
        if polled_rate > check_rate and polled_rate <= check_rate + v.val then
            set = v.type
            break
        end
        check_rate = check_rate + v.val
    end
    if not set then return { set = '?', key = nil } end

    local key
    if set == 'Base' then
        key = 'c_base'
    else
        local _pool, _pool_key = get_current_pool(set, nil, nil, 'sho')
        key = pseudorandom_element(_pool, pseudoseed(_pool_key))
        local it = 1
        while key == 'UNAVAILABLE' do
            it = it + 1
            key = pseudorandom_element(_pool, pseudoseed(_pool_key .. '_resample' .. it))
        end
    end

    local front
    if set == 'Base' or set == 'Enhanced' then
        front = pseudorandom_element(G.P_CARDS, pseudoseed('front' .. 'sho' .. ante))
    end

    local edition, eternal, perishable, rental, free
    if set == 'Joker' then
        local center, mods, st = G.P_CENTERS[key] or {}, G.GAME.modifiers, SMODS.Stickers
        eternal = mods.all_eternal and center.eternal_compat or nil
        local ep = pseudorandom('etperpoll' .. ante)
        if mods.enable_eternals_in_shop and ep > 0.7 and not st.eternal.should_apply then
            eternal = center.eternal_compat or eternal
        elseif mods.enable_perishables_in_shop and ep > 0.4 and ep <= 0.7 and not st.perishable.should_apply then
            perishable = center.perishable_compat and not eternal or nil
        end
        if mods.enable_rentals_in_shop and pseudorandom('ssjr' .. ante) > 0.7 and not st.rental.should_apply then
            rental = true
        end
        edition = poll_edition('edi' .. 'sho' .. ante)
        if not edition and tag_q[1] then
            edition, free = table.remove(tag_q, 1), true
        end
    end

    if (set == 'Base' or set == 'Enhanced') and G.GAME.used_vouchers['v_illusion']
        and pseudorandom(pseudoseed('illusion')) > 0.8 then
        edition = poll_edition('illusion', nil, true, true)
    end

    return {
        set = set,
        key = key,
        front = front and front.value and { value = front.value, suit = front.suit } or nil,
        edition = edition_name(edition),
        eternal = eternal, perishable = perishable, rental = rental, free = free,
    }
end

--============================================================
-- Prediction engine
--============================================================
local function shallow_copy(t)
    local o = {}
    for k, v in pairs(t or {}) do o[k] = v end
    return o
end

local function restore(t, saved)
    for k in pairs(t) do if saved[k] == nil then t[k] = nil end end
    for k, v in pairs(saved) do t[k] = v end
end

function MVP.predict_shop()
    if not (G.GAME and G.GAME.pseudorandom and G.GAME.current_round) then return {} end
    local depth = peek_depth()
    local joker_max = math.max(1, MVP.plain(G.GAME.shop and G.GAME.shop.joker_max) or 2)

    local used = G.GAME.used_jokers
    local saved_pr, saved_used = shallow_copy(G.GAME.pseudorandom), shallow_copy(used)
    local tag_q = pending_edition_tags()
    local shelf = {}
    for _, c in ipairs(G.shop_jokers.cards) do shelf[#shelf + 1] = c.config.center.key end

    local out = {}
    local ok, err = pcall(function()
        local cumulative = 0
        for r = 1, depth do
            cumulative = cumulative + reroll_cost(r)
            -- Rerolled-away cards leave the pool; fresh ones join it (card.lua Card:remove / set_ability)
            for _, k in ipairs(shelf) do
                if not next(SMODS.find_card(k, true)) then used[k] = nil end
            end
            shelf = {}
            local cards = {}
            for _ = 1, joker_max do
                local c = sim_shop_card(tag_q)
                cards[#cards + 1] = c
                if c.key then used[c.key] = true; shelf[#shelf + 1] = c.key end
            end
            out[r] = { cost = cumulative, cards = cards }
        end
    end)
    if not ok then
        out.error = true
        sendWarnMessage('Peek stopped after reroll ' .. #out .. ': ' .. tostring(err), 'MoarVanillaPlease')
    end

    restore(G.GAME.pseudorandom, saved_pr)
    restore(used, saved_used)
    return out
end

--============================================================
-- Overlay UI
--============================================================

local function set_colour(set)
    local ss = G.C.SECONDARY_SET or {}
    local map = {
        Joker = (G.C.RARITY and G.C.RARITY[1]) or G.C.BLUE,
        Tarot = ss.Tarot, Planet = ss.Planet, Spectral = ss.Spectral, Voucher = ss.Voucher,
        Base = G.C.WHITE, Default = G.C.WHITE, Enhanced = G.C.WHITE,
    }
    return map[set or 'Joker'] or G.C.WHITE
end

local function card_prefix(c)
    local bits = {}
    if c.edition then bits[#bits + 1] = '[' .. c.edition .. ']' end
    if c.free then bits[#bits + 1] = '[free]' end
    if c.eternal then bits[#bits + 1] = '[eternal]' end
    if c.perishable then bits[#bits + 1] = '[perishable]' end
    if c.rental then bits[#bits + 1] = '[rental]' end
    return #bits > 0 and (table.concat(bits, ' ') .. ' ') or ''
end

local function card_name(c)
    if c.set == 'Base' or c.set == 'Default' or c.set == 'Enhanced' then
        local name = c.front and (tostring(c.front.value) .. ' of ' .. tostring(c.front.suit))
            or 'Random Playing Card'
        if c.set == 'Enhanced' and c.key and c.key ~= 'c_base' then
            local center = G.P_CENTERS[c.key]
            if center and center.name then name = name .. ' (' .. center.name .. ')' end
        end
        return name
    end

    if not c.key then return '?' end
    local ok, name = pcall(function()
        return localize{ type = 'name_text', key = c.key, set = c.set or 'Joker' }
    end)
    if ok and name and name ~= '' and name ~= 'ERROR' then return name end
    local center = G.P_CENTERS[c.key]
    return (center and center.name) or c.key
end

function G.UIDEF.mvp_peek_store(rerolls)
    rerolls = rerolls or {}
    local rows = {}
    for r, info in ipairs(rerolls) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.06, minw = 6, r = 0.1,
                                                    colour = G.C.L_BLACK, emboss = 0.05 }, nodes = {
            { n = G.UIT.T, config = { text = 'Reroll ' .. r, scale = 0.36, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            { n = G.UIT.C, config = { align = 'cr', minw = 2 }, nodes = {
                { n = G.UIT.T, config = { text = '$' .. info.cost .. ' total', scale = 0.34,
                                          colour = G.C.MONEY, shadow = true } },
            }},
        }}
        for _, c in ipairs(info.cards) do
            rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cl', padding = 0.015 }, nodes = {
                { n = G.UIT.T, config = { text = '  ' .. card_prefix(c), scale = 0.3,
                                          colour = c.edition and G.C.DARK_EDITION or set_colour(c.set) } },
                { n = G.UIT.T, config = { text = card_name(c), scale = 0.3, colour = set_colour(c.set) } },
            }}
        end
    end
    if rerolls.error then
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'A modded card stopped the peek here', scale = 0.3, colour = G.C.RED } },
        }}
    end
    if #rows == 0 then
        rows[1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Nothing to peek', scale = 0.4, colour = G.C.UI.TEXT_INACTIVE } },
        }}
    end

    local content = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
        { n = G.UIT.C, config = { align = 'tm', padding = 0.05 }, nodes = rows } } }

    local MAXH = 6.6
    local body
    if SMODS.UIScrollBox and SMODS.GUI and SMODS.GUI.scrollbar then
        local scrollbox = SMODS.UIScrollBox({
            content = { definition = { n = G.UIT.ROOT, config = { colour = G.C.CLEAR }, nodes = { content } }, config = { align = 'cm' } },
            overflow = { node_config = { maxh = MAXH, r = 0.1 } },
            sync_mode = 'offset',
        })
        body = { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, colour = G.C.BLACK }, nodes = {
            { n = G.UIT.C, config = {}, nodes = { { n = G.UIT.O, config = { object = scrollbox } } } },
            { n = G.UIT.C, config = { padding = 0.05 }, nodes = {
                SMODS.GUI.scrollbar({ w = 0.12, h = MAXH - 0.1, scroll_collision_obj = scrollbox, knob_h = MAXH / 6, bg_colour = { 0, 0, 0, 0.2 } }),
            }},
        }}
    else
        body = { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, colour = G.C.BLACK }, nodes = { content } }
    end

    return create_UIBox_generic_options({
        back_func = 'exit_overlay_menu',
        contents = {
            { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
                { n = G.UIT.T, config = { text = 'Peek Rolls', scale = 0.6, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            }},
            body,
            { n = G.UIT.R, config = { align = 'cm', padding = 0.04, maxw = 7 }, nodes = {
                { n = G.UIT.T, config = { text = 'Assumes you only reroll (no buying).', scale = 0.28, colour = G.C.UI.TEXT_INACTIVE } },
            }},
        },
    })
end

G.FUNCS.mvp_peek_store = function(e)
    if G.OVERLAY_MENU then return end
    if not MVP.peek_ready() then
        attention_text{ text = 'Shop is still dealing', scale = 0.5, hold = 1.2,
                        major = G.shop_jokers or G.jokers, align = 'cm' }
        return
    end
    local rerolls = MVP.predict_shop()
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{ definition = G.UIDEF.mvp_peek_store(rerolls) }
end

--============================================================
-- Shop button
--============================================================
local mvp_uidef_shop = G.UIDEF.shop
function G.UIDEF.shop()
    local t = mvp_uidef_shop()
    if not (MVP.peek_allowed() and t and t.nodes) then return t end

    local button_row = { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
        UIBox_button({
            label = { 'Peek Rolls' },
            button = 'mvp_peek_store',
            colour = G.C.GOLD or G.C.ORANGE,
            minw = 3, minh = 0.5, scale = 0.4,
        }),
    }}
    return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = {
        button_row,
        { n = G.UIT.R, config = { align = 'cm' }, nodes = t.nodes },
    }}
end
