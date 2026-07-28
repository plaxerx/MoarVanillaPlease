-- Moar Vanilla Please - Peek Rolls. A shop tool that predicts the cards in future rerolls,
-- with the cumulative reroll cost to reach each one. Gated by mod config.
--
-- METADATA-ONLY PREDICTION: creates no Card objects, because Card creation and removal
-- touch the controller, event queues, cursor context and card_limits. It replicates only
-- the identity-relevant RNG draws of the real generator, transcribed from
-- common_events.lua:2498+ and UI_definitions.lua:802+, and reads the results as plain data.
--
-- EXACT because Balatro's RNG is per-key streams (G.GAME.pseudorandom[key]): the real
-- reroll consumes the same streams in the same order, so identical draws from the current
-- state yield identical cards. The whole pseudorandom table is restored afterward, so the
-- run's own next reroll starts from untouched state.
--
-- LIMITS: assumes only rerolling - buying, using a consumable, a Tag that edits shop cards,
-- or a rate-changing Voucher purchase changes what actually appears. The overlay says so.
--
-- Must predict while UNPAUSED: pseudoseed() short-circuits to math.random() while paused,
-- so the button handler predicts first, then pauses to show the overlay.

local PEEK_MAX = 8

--============================================================
-- Gating
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

local function peek_depth()
    local d = (MVP.CFG and MVP.CFG.peek_depth) or 5
    return math.max(1, math.min(PEEK_MAX, d))
end

--============================================================
-- Reroll cost
--============================================================
-- Cost of the r-th reroll from now: free while free_rerolls covers it, else the base plus
-- the running increase, which climbs $1 per paid reroll.
local function reroll_cost(r)
    local cr = G.GAME.current_round
    local base = MVP.plain(G.GAME.round_resets.temp_reroll_cost or G.GAME.round_resets.reroll_cost) or 5
    local inc = MVP.plain(cr.reroll_cost_increase) or 0
    local free = MVP.plain(cr.free_rerolls) or 0
    if r <= free then return 0 end
    return math.max(0, base + inc + (r - free - 1))
end

--============================================================
-- One simulated shop card (identity only, no Card object)
--============================================================
-- Transcription of create_card_for_shop's rate walk plus create_card's pool pick, front,
-- sticker and edition rolls. Every pseudorandom/pseudoseed call below exists, with the same
-- key, in the real path; if the game or SMODS changes those lines this must be re-synced.
local function edition_name(ed)
    if type(ed) ~= 'table' then return nil end
    for _, k in ipairs({ 'negative', 'polychrome', 'holo', 'foil' }) do
        if ed[k] then return k end
    end
    return next(ed)
end

local function sim_shop_card()
    local ante = G.GAME.round_resets.ante

    -- Rate walk (UI_definitions.lua:826+).
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

    -- Pool pick (common_events.lua:2552+). 'Base' is hardcoded to c_base with no pool
    -- draw. soulable is nil for shop cards, so the soul rolls never run here.
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

    -- Front (rank+suit) for playing cards (common_events.lua:2563).
    local front
    if set == 'Base' or set == 'Enhanced' then
        front = pseudorandom_element(G.P_CARDS, pseudoseed('front' .. 'sho' .. ante))
    end

    -- Joker-only: shop sticker polls plus edition poll (common_events.lua:2578+). The
    -- sticker streams only advance when the matching modifier is live, same as the real code.
    local edition, eternal, perishable, rental
    if set == 'Joker' then
        -- etperpoll draws unconditionally for shop jokers (modifiers only gate its use),
        -- while ssjr's draw is short-circuit gated. Mirrored exactly.
        local ep = pseudorandom('etperpoll' .. ante)
        if G.GAME.modifiers.enable_eternals_in_shop and ep > 0.7 then eternal = true
        elseif G.GAME.modifiers.enable_perishables_in_shop and ep > 0.4 and ep <= 0.7 then perishable = true end
        if G.GAME.modifiers.enable_rentals_in_shop and pseudorandom('ssjr' .. ante) > 0.7 then
            rental = true
        end
        edition = poll_edition('edi' .. 'sho' .. ante)
    end

    -- Illusion voucher edition for playing cards (UI_definitions.lua:864).
    if (set == 'Base' or set == 'Enhanced') and G.GAME.used_vouchers['v_illusion']
        and pseudorandom(pseudoseed('illusion')) > 0.8 then
        edition = poll_edition('illusion', nil, true, true)
    end

    return {
        set = set,
        key = key,
        front = front and front.value and { value = front.value, suit = front.suit } or nil,
        edition = edition_name(edition),
        eternal = eternal, perishable = perishable, rental = rental,
    }
end

--============================================================
-- Prediction
--============================================================
local function shallow_copy(t)
    local o = {}
    for k, v in pairs(t or {}) do o[k] = v end
    return o
end

-- Returns a list of rerolls, each { cost = cumulative$, cards = {sim_shop_card()...} }.
function MVP.predict_shop()
    if not (G.GAME and G.GAME.pseudorandom and G.GAME.current_round) then return {} end
    local depth = peek_depth()
    local joker_max = math.max(1, MVP.plain(G.GAME.shop and G.GAME.shop.joker_max) or 2)

    -- The only state the simulation advances is the RNG stream table; snapshot and
    -- restore it and the run is untouched.
    local saved_pr = shallow_copy(G.GAME.pseudorandom)

    local out = {}
    pcall(function()
        local cumulative = 0
        for r = 1, depth do
            cumulative = cumulative + reroll_cost(r)
            local cards = {}
            for _ = 1, joker_max do
                cards[#cards + 1] = sim_shop_card()
            end
            out[r] = { cost = cumulative, cards = cards }
        end
    end)

    -- Restore in place, so references to G.GAME.pseudorandom elsewhere stay valid.
    for k in pairs(G.GAME.pseudorandom) do if saved_pr[k] == nil then G.GAME.pseudorandom[k] = nil end end
    for k, v in pairs(saved_pr) do G.GAME.pseudorandom[k] = v end
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

local function card_name(c)
    local bits = {}
    if c.edition then bits[#bits + 1] = '[' .. c.edition .. ']' end
    if c.eternal then bits[#bits + 1] = '[eternal]' end
    if c.perishable then bits[#bits + 1] = '[perishable]' end
    if c.rental then bits[#bits + 1] = '[rental]' end
    local prefix = #bits > 0 and (table.concat(bits, ' ') .. ' ') or ''

    -- Playing cards: the exact front is known, so show it, falling back to "Random
    -- Playing Card" if missing.
    if c.set == 'Base' or c.set == 'Default' or c.set == 'Enhanced' then
        local name = c.front and (tostring(c.front.value) .. ' of ' .. tostring(c.front.suit))
            or 'Random Playing Card'
        if c.set == 'Enhanced' and c.key and c.key ~= 'c_base' then
            local center = G.P_CENTERS[c.key]
            if center and center.name then name = name .. ' (' .. center.name .. ')' end
        end
        return prefix .. name
    end

    if not c.key then return prefix .. '?' end
    local ok, name = pcall(function()
        return localize{ type = 'name_text', key = c.key, set = c.set or 'Joker' }
    end)
    if ok and name and name ~= '' and name ~= 'ERROR' then return prefix .. name end
    local center = G.P_CENTERS[c.key]
    return prefix .. ((center and center.name) or c.key)
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
                { n = G.UIT.T, config = { text = '  ' .. card_name(c), scale = 0.3,
                                          colour = set_colour(c.set) } },
            }}
        end
    end
    if #rows == 0 then
        rows[1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Nothing to peek', scale = 0.4, colour = G.C.UI.TEXT_INACTIVE } },
        }}
    end

    local content = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
        { n = G.UIT.C, config = { align = 'tm', padding = 0.05 }, nodes = rows } } }

    -- Scrollable, like the Mutation List, so a deep peek never runs off-screen.
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
                { n = G.UIT.T, config = { text = 'Assumes you only reroll (no buying, no Tags).', scale = 0.28, colour = G.C.UI.TEXT_INACTIVE } },
            }},
        },
    })
end

G.FUNCS.mvp_peek_store = function(e)
    -- Double-open guard: a second overlay while one is up stacks the cursor context layer
    -- unbalanced, making everything under it unclickable.
    if G.OVERLAY_MENU then return end
    -- Predict before pausing: pseudoseed() returns math.random() while paused.
    local rerolls = MVP.predict_shop()
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{ definition = G.UIDEF.mvp_peek_store(rerolls) }
end

--============================================================
-- The shop button
--============================================================
local mvp_uidef_shop = G.UIDEF.shop
function G.UIDEF.shop()
    local t = mvp_uidef_shop()
    if not (MVP.peek_allowed() and t and t.nodes) then return t end

    -- The shop root lays its children out as columns, so inserting a node would land the
    -- button to the left of the store. Wrapping the whole shop in a vertical stack instead
    -- sits it above, with the original nodes re-parented unchanged.
    local button_row = { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
        UIBox_button({
            label = { 'Peek Rolls' },
            button = 'mvp_peek_store',
            colour = G.C.GOLD or G.C.ORANGE,
            minw = 3, minh = 0.5, scale = 0.4,
            -- No one_press: it sets disable_button=true after the first press, and a
            -- reroll doesn't rebuild the shop UI, so the button would stay dead until the
            -- shop is re-entered. Double-open is handled by the guard in mvp_peek_store.
        }),
    }}
    return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = {
        button_row,
        { n = G.UIT.R, config = { align = 'cm' }, nodes = t.nodes },
    }}
end
