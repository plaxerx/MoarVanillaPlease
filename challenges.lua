-- Moar Vanilla Please - Challenges
--
-- A continuation of the vanilla list from 21 - 50.
-- 
-- HOW A CHALLENGE CARRIES CUSTOM LOGIC
-- Game:start_run turns `rules.custom = {{id = 'foo'}}` into `G.GAME.modifiers.foo = true`
-- (with `value = x` it stores x instead). The id is arbitrary, so a custom rule is just a
-- named flag on the run that the hooks at the bottom of this file read. That's the same
-- seam vanilla uses for chips_dollar_cap, so we borrow it over inventing a parallel
-- channel.
--

local function m(id) return G.GAME and G.GAME.modifiers and G.GAME.modifiers[id] end

-- Custom functions to assist with challenge mode custom rules

--============================================================
-- Shop / economy hooks
--============================================================

local eeng_set_cost = Card.set_cost
function Card:set_cost()
    eeng_set_cost(self)
    if not (m('eeng_black_market') or m('eeng_thrift_store') or m('eeng_no_refunds')) then return end

    local c = EEng.plain(self.cost) or 0
    local set = self.ability and self.ability.set
    if m('eeng_black_market') then c = c * 2 end
    if m('eeng_thrift_store') and (set == 'Joker' or set == 'Booster') then
        c = math.floor(c * 0.5)
    end
    local floor_c = (self.ability and self.ability.rental) and 0 or 1
    self.cost = math.max(floor_c, c)
    if m('eeng_no_refunds') then
        self.sell_cost = 0
    else
        self.sell_cost = math.max(floor_c, math.floor(self.cost / 2))
            + (self.ability and EEng.plain(self.ability.extra_value) or 0)
    end
end

local eeng_can_reroll = G.FUNCS.can_reroll
G.FUNCS.can_reroll = function(e)
    eeng_can_reroll(e)
    if m('eeng_no_reroll') then
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

local eeng_impulse_armed = false

local eeng_update_shop = Game.update_shop
function Game:update_shop(dt)
    eeng_update_shop(self, dt)
    if not (m('eeng_impulse_buyer') and eeng_impulse_armed) then return end
    local card = G.shop_jokers and G.shop_jokers.cards and G.shop_jokers.cards[1]
    if not card then return end
    eeng_impulse_armed = false

    local price = EEng.plain(card.cost) or 0
    local dollars = EEng.plain(G.GAME.dollars) or 0
    if price > dollars then return end   -- "must have money"
    pcall(G.FUNCS.buy_from_shop, { config = { ref_table = card } })
end

local eeng_reroll = G.FUNCS.reroll_shop
G.FUNCS.reroll_shop = function(e)
    if m('eeng_gambler') then
        G.GAME.eeng_gambler_rerolls = (G.GAME.eeng_gambler_rerolls or 0) + 1
        if G.jokers and #G.jokers.cards > 0 and pseudorandom('eeng_gambler') < 1 / 6 then
            local c = G.jokers.cards[pseudorandom('eeng_gambler_pick', 1, #G.jokers.cards)]
            if c and not c.ability.eternal then
                play_sound('glass' .. math.random(1, 6), math.random() * 0.2 + 0.9, 0.5)
                c:start_dissolve()
            end
        end
    end
    return eeng_reroll(e)
end

local eeng_calc_reroll = calculate_reroll_cost
function calculate_reroll_cost(skip_increment)
    eeng_calc_reroll(skip_increment)
    if not (G.GAME and G.GAME.current_round) then return end
    if m('eeng_gambler') then
        local done = G.GAME.eeng_gambler_rerolls or 0
        G.GAME.current_round.reroll_cost = math.max(0, done + 1 - 10)
    end
    if m('eeng_impulse_buyer') then
        eeng_impulse_armed = true 
    end
end

--============================================================
-- Hand legality (28 / 36 / 38)
--============================================================
local SUIT_NAME = { S = 'Spades', H = 'Hearts', D = 'Diamonds', C = 'Clubs' }

local function is_wild(c)
    if SMODS and SMODS.has_enhancement then return SMODS.has_enhancement(c, 'm_wild') end
    return c.config and c.config.center_key == 'm_wild'
end

local function suits_in(cards)
    local seen, wilds = {}, 0
    for _, c in ipairs(cards) do
        if not c.debuff then
            if is_wild(c) then
                wilds = wilds + 1
            else
                for _, s in ipairs(SUITS) do
                    local suit = SUIT_NAME[s]
                    if c:is_suit(suit) and not seen[suit] then
                        seen[suit] = true
                        break
                    end
                end
            end
        end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    return math.min(4, n + wilds)
end

-- Lower order = stronger hand: SMODS numbers PokerHands from its obj_buffer, which runs
-- Flush Five (1) down to High Card.
local function hand_order(name)
    local ph = SMODS.PokerHands and SMODS.PokerHands[name]
    return ph and ph.order or 99
end

-- The un-localized hand name, resolved exactly the way scoring resolves it. Note
-- evaluate_poker_hand() returns the PARTS table, not a name - the name is the first return
-- of get_poker_hand_info, which is what play_cards_from_highlighted itself calls.
local function hand_name_of(cards)
    if not (G.FUNCS and G.FUNCS.get_poker_hand_info and cards and #cards > 0) then return nil end
    local ok, text = pcall(G.FUNCS.get_poker_hand_info, cards)
    if ok and text and text ~= 'NULL' then return text end
    return nil
end

-- The highest scoring rank in a hand, so 36 can rank a high Pair above a low one.
local function top_rank(cards)
    local best = 0
    for _, c in ipairs(cards or {}) do
        local id = c.get_id and c:get_id() or 0
        if id > best then best = id end
    end
    return best
end

local eeng_debuff_hand = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, check)
    if eeng_debuff_hand(self, cards, hand, handname, check) then return true end

    if m('eeng_suit_up') and suits_in(cards) < 4 then return true end

    if m('eeng_poker_purist') and G.GAME.eeng_last_hand_order and handname then
        local ord = hand_order(handname)
        local prev, prev_rank = G.GAME.eeng_last_hand_order, G.GAME.eeng_last_hand_rank or 0
        if ord > prev then return true end
        if ord == prev and top_rank(cards) <= prev_rank then return true end
    end

    if m('eeng_balanstro') and handname and G.GAME.hands then
        local this = G.GAME.hands[handname]
        if this then
            local pool, seen = {}, {}
            for _, c in ipairs(cards or {}) do
                if not seen[c] then seen[c] = true; pool[#pool + 1] = c end
            end
            for _, c in ipairs((G.hand and G.hand.cards) or {}) do
                if not seen[c] then seen[c] = true; pool[#pool + 1] = c end
            end

            local ok, parts = pcall(evaluate_poker_hand, pool)
            if ok and parts then
                local mine = EEng.plain(this.played) or 0
                local min
                for name, matches in pairs(parts) do
                    if next(matches) and G.GAME.hands[name] then
                        local p = EEng.plain(G.GAME.hands[name].played) or 0
                        if not min or p < min then min = p end
                    end
                end
                if min and mine > min then return true end
            end
        end
    end
    return false
end

--============================================================
-- Round / play hooks
--============================================================
local eeng_purist_pending = nil

local eeng_eval_round = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function(...)
    if (m('eeng_trial') or m('eeng_mut_boss_rush')) and G.GAME.round_resets
        and G.GAME.blind_on_deck and G.GAME.blind_on_deck ~= 'Boss' then
        local bs = G.GAME.round_resets.blind_states
        if bs then
            bs[G.GAME.blind_on_deck] = 'Defeated'
            if bs.Boss == 'Defeated' then bs.Boss = 'Upcoming' end
        end
    end
    if m('eeng_joker_draft') and G.GAME.last_blind and G.GAME.last_blind.boss and G.jokers then
        for i = #G.jokers.cards, 1, -1 do
            local c = G.jokers.cards[i]
            if c and not c.ability.eternal then
                ease_dollars(EEng.plain(c.cost) or 0)
                c:start_dissolve()
            end
        end
    end
    G.GAME.eeng_last_hand_order = nil
    G.GAME.eeng_last_hand_rank = nil
    eeng_purist_pending = nil
    return eeng_eval_round(...)
end

local eeng_play_cards = G.FUNCS.play_cards_from_highlighted
G.FUNCS.play_cards_from_highlighted = function(e)
    local played = {}
    for _, c in ipairs((G.hand and G.hand.highlighted) or {}) do played[#played + 1] = c end
    local res = eeng_play_cards(e)

    if m('eeng_poker_purist') then
        local name = hand_name_of(played)
        if name then
            eeng_purist_pending = { ord = hand_order(name), rank = top_rank(played) }
        end
    end
    return res
end

--============================================================
-- Post-scoring card fates (41 / 42 / 43)
--============================================================
local ENH_POOL = { 'm_bonus', 'm_mult', 'm_wild', 'm_glass', 'm_steel', 'm_stone', 'm_gold', 'm_lucky' }

local function mark_destroyed(card, cards_destroyed)
    if card.getting_sliced then return end
    card.getting_sliced = true
    if SMODS.shatters and SMODS.shatters(card) then
        card.shattered = true
    else
        card.destroyed = true
    end
    cards_destroyed[#cards_destroyed + 1] = card
end

local eeng_destroying = SMODS.calculate_destroying_cards
function SMODS.calculate_destroying_cards(context, cards_destroyed, scoring_hand)
    eeng_destroying(context, cards_destroyed, scoring_hand)
    if not scoring_hand then return end

    if m('eeng_poker_purist') and eeng_purist_pending then
        G.GAME.eeng_last_hand_order = eeng_purist_pending.ord
        G.GAME.eeng_last_hand_rank = eeng_purist_pending.rank
        eeng_purist_pending = nil
    end

    if m('eeng_glass_house') and context.scoring_name ~= 'Full House' then
        for _, c in ipairs(context.full_hand or {}) do
            mark_destroyed(c, cards_destroyed)
        end
    end

    if m('eeng_recursion') then
        local replaced = 0
        for _, c in ipairs(scoring_hand) do
            if not c.getting_sliced then replaced = replaced + 1 end
            mark_destroyed(c, cards_destroyed)
        end
        if replaced > 0 then
            for _ = 1, replaced do
                local proto = {
                    s = SUITS[pseudorandom('eeng_rec_s', 1, #SUITS)],
                    r = RANKS[pseudorandom('eeng_rec_r', 1, #RANKS)],
                    e = ENH_POOL[pseudorandom('eeng_rec_e', 1, #ENH_POOL)],
                }
                G.E_MANAGER:add_event(Event({ func = function()
                    card_from_control(proto); return true
                end }))
            end
        end
    end
end

-- 43: steel cards rust as they leave play for the discard - "after the cards score, right
-- before they are discarded from hand". draw_from_play_to_discard iterates G.play.cards at
-- exactly that moment (state_events:539). This is a debuff only (no destruction), so it
-- cannot leave the ghost husks the old destroy-by-hand path did. The card scored its x1.5
-- normally this hand; eeng_rusted keeps it debuffed from the next draw on. card1 is The
-- Hook's discard sound (blind.lua:516), played once for the whole hand.
local eeng_draw_discard = G.FUNCS.draw_from_play_to_discard
G.FUNCS.draw_from_play_to_discard = function(e)
    if m('eeng_rusty_deck') and G.play then
        for _, c in ipairs(G.play.cards) do
            if SMODS.has_enhancement and SMODS.has_enhancement(c, 'm_steel') and not c.eeng_rusted then
                c.eeng_rusted = true
                c:set_debuff(true)
                -- Per card, exactly as The Hook does it (blind.lua:509-516 plays card1
                -- once per card it discards). One call for the whole hand was getting
                -- lost under the end-of-hand audio; per card it reads as a real proc.
                -- juice_up gives the moment a visible tick to match the sound.
                c:juice_up(0.3, 0.3)
                play_sound('card1', 1)
            end
        end
    end
    return eeng_draw_discard(e)
end

--============================================================
-- Joker lifecycle hooks
--============================================================

local eeng_cloning = false

local eeng_add_to_deck = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    eeng_add_to_deck(self, from_debuff)
    if not (self.ability and self.ability.set == 'Joker') then return end

    if m('eeng_all_perishable') and not self.ability.perishable
        and not (self.config and self.config.center and self.config.center.perishable_compat == false) then
        self.ability.perishable = true
        self.ability.perish_tally = G.GAME.perishable_rounds or 5
    end

    if m('eeng_one_trick') and not eeng_cloning then
        local src = self
        G.E_MANAGER:add_event(Event({ func = function()
            if G.jokers and not eeng_cloning then
                eeng_cloning = true
                local want = (G.jokers.config.card_limit or 0) - #G.jokers.cards
                for _ = 1, math.min(want, 20) do
                    local c = copy_card(src, nil)
                    c:add_to_deck()
                    G.jokers:emplace(c)
                end
                eeng_cloning = false
            end
            return true
        end }))
    end
end

local eeng_sell = G.FUNCS.sell_card
G.FUNCS.sell_card = function(e)
    local card = e and e.config and e.config.ref_table
    local key = m('eeng_one_trick') and card and card.config and card.config.center_key
    local res = eeng_sell(e)
    if key and G.jokers then
        for i = #G.jokers.cards, 1, -1 do
            local c = G.jokers.cards[i]
            if c ~= card and c.config and c.config.center_key == key then
                c:start_dissolve()
            end
        end
    end
    return res
end

local eeng_create_card = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    local c = eeng_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    if c and c.ability then
        if c.ability.set == 'Joker' then
            if m('eeng_all_perishable') and not c.ability.perishable
                and not (c.config and c.config.center and c.config.center.perishable_compat == false) then
                c.ability.perishable = true
                c.ability.perish_tally = G.GAME.perishable_rounds or 5
            end
            if m('eeng_tenant') and not c.ability.rental then
                c.ability.rental = true
                if c.set_cost then c:set_cost() end   -- rentals price at $1; recompute
            end
        elseif c.ability.set == 'Default' or c.ability.set == 'Enhanced' then
            -- 37: the set_debuff wrapper below turns this into debuffed-unless-Wild
            if m('eeng_wild_west') then c:set_debuff(false) end
        end
    end
    return c
end

local eeng_calc_retriggers = SMODS.calculate_retriggers
function SMODS.calculate_retriggers(card, context, _ret)
    local ret = eeng_calc_retriggers(card, context, _ret)
    if m('eeng_double_down') and card and card.ability and card.ability.set == 'Joker'
        and SMODS.insert_repetitions then
        SMODS.insert_repetitions(ret, { repetitions = 1, message = localize('k_again_ex') },
            card, 'joker_retrigger')
    end
    return ret
end

--============================================================
-- Run-shape hooks
--============================================================
local eeng_start_run = Game.start_run
function Game:start_run(args)
    eeng_start_run(self, args)
    if not (G.GAME and G.GAME.modifiers) then return end
    if m('eeng_half_a_hand') then
        if G.hand then G.hand.config.highlighted_limit = 3 end
        if G.GAME.starting_params then G.GAME.starting_params.play_limit = 3 end
    end
    if m('eeng_long_game') then G.GAME.win_ante = 16 end
end

local eeng_ease_ante = ease_ante
function ease_ante(mod)
    eeng_ease_ante(mod)
    if m('eeng_final_form') and G.jokers and EEng.plain(mod) and EEng.plain(mod) > 0 then
        G.jokers.config.card_limit = G.jokers.config.card_limit + 1
    end
    -- Legendary Run twist: Chicot is destroyed on reaching Ante 8, bypassing its Eternal.
    if m('eeng_legendary_twist') and G.jokers and not G.GAME.eeng_chicot_destroyed
        and G.GAME.round_resets and (EEng.plain(G.GAME.round_resets.ante) or 0) >= 8 then
        G.GAME.eeng_chicot_destroyed = true
        for i = #G.jokers.cards, 1, -1 do
            local c = G.jokers.cards[i]
            local ck = c.config and (c.config.center_key or (c.config.center and c.config.center.key))
            if ck == 'j_chicot' then c:start_dissolve() end
        end
    end
end

local eeng_get_blind_amount = get_blind_amount
function get_blind_amount(ante)
    local base = eeng_get_blind_amount(ante)
    if m('eeng_double_down') and ante and ante > 1 then
        return (to_big and to_big(base) or base) * 2
    end
    return base
end

local eeng_set_blind_ch = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    eeng_set_blind_ch(self, blind, reset, silent)
    if reset then return end
    if m('eeng_tenant') and self.dollars and not self.eeng_tenant_paid then
        self.eeng_tenant_paid = true
        self.dollars = (EEng.plain(self.dollars) or 0) * 2
    end
end

--============================================================
-- Bosses in Small/Big slots (50, and Erratic Mode's Boss Rush)
--============================================================

local function bosses_everywhere()
    if m('eeng_trial') then
        return (G.GAME.round_resets and G.GAME.round_resets.ante or 1) >= 2
    end
    if m('eeng_mut_boss_rush') then
        return (G.GAME.round_resets and G.GAME.round_resets.ante or 1) >= 3
    end
    return false
end

local eeng_reset_blinds = reset_blinds
function reset_blinds()
    eeng_reset_blinds()
    local rr = G.GAME and G.GAME.round_resets
    if not (rr and rr.blind_choices) then return end
    if bosses_everywhere() then
        for _, slot in ipairs({ 'Small', 'Big' }) do
            local cur = G.P_BLINDS[rr.blind_choices[slot]]
            if not (cur and cur.boss) then rr.blind_choices[slot] = get_new_boss() end
        end
    end
end

local eeng_get_type = Blind.get_type
function Blind:get_type()
    if bosses_everywhere() and G.GAME.blind_on_deck and G.GAME.blind_on_deck ~= 'Boss' then
        return G.GAME.blind_on_deck
    end
    return eeng_get_type(self)
end

--============================================================
-- Debuffs (37 / 43)
--============================================================
local eeng_card_set_debuff = Card.set_debuff
function Card:set_debuff(should_debuff)
    local playing = self.ability and (self.ability.set == 'Default' or self.ability.set == 'Enhanced')
    if playing and m('eeng_wild_west') and not is_wild(self) then should_debuff = true end
    if self.eeng_rusted then should_debuff = true end
    return eeng_card_set_debuff(self, should_debuff)
end

--============================================================
-- Board note (28's always-visible rule)
--============================================================

local eeng_note = nil

local function sync_board_note()
    local want = G.STAGE == G.STAGES.RUN and G.STATE == G.STATES.SELECTING_HAND
        and m('eeng_suit_up') and G.play and G.play.T
    if want and not eeng_note then
        eeng_note = UIBox{
            definition = {
                n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR },
                nodes = {{
                    n = G.UIT.C,
                    config = { align = 'cm', padding = 0.08, r = 0.1, emboss = 0.05,
                               colour = adjust_alpha(G.C.PURPLE, 0.8) },
                    nodes = {{
                        n = G.UIT.T, config = { text = 'HANDS MUST CONTAIN ALL 4 SUITS',
                                                scale = 0.35, shadow = true, colour = G.C.WHITE } },
                    },
                }},
            },
            config = { align = 'cm', offset = { x = 0, y = -2.6 }, major = G.play, bond = 'Weak' },
        }
    elseif eeng_note and not want then
        eeng_note:remove()
        eeng_note = nil
    end
end

local eeng_game_update_ch = Game.update
function Game:update(dt)
    eeng_game_update_ch(self, dt)
    sync_board_note()
end

--============================================================
-- Description screen safety
--============================================================
local eeng_ch_desc_tab = G.UIDEF.challenge_description_tab
function G.UIDEF.challenge_description_tab(args)
    local ch = args and args._id and G.CHALLENGES[args._id]
    local r = ch and ch.restrictions
    if r and type(r.banned_cards) == 'function' then r.banned_cards = r.banned_cards() end
    return eeng_ch_desc_tab(args)
end

--============================================================
-- Ban list helpers
--============================================================

local function pool_ids(pool_key, filter)
    return function()
        local out = {}
        for _, v in ipairs(G.P_CENTER_POOLS[pool_key] or {}) do
            if v.key and (not filter or filter(v)) then out[#out + 1] = { id = v.key } end
        end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end
end

local function merge_pools(...)
    local fns = { ... }
    return function()
        local out, seen = {}, {}
        for _, fn in ipairs(fns) do
            for _, e in ipairs(fn()) do
                if not seen[e.id] then seen[e.id] = true; out[#out + 1] = e end
            end
        end
        return out
    end
end

local ban_planets   = pool_ids('Planet')
local ban_tarots    = pool_ids('Tarot')
local ban_spectrals = pool_ids('Spectral')

local ban_nonbuffoon_boosters = pool_ids('Booster', function(v)
    return not (v.kind == 'Buffoon' or (v.key or ''):find('buffoon'))
end)

local ban_planet_packs = pool_ids('Booster', function(v)
    return v.kind == 'Celestial' or (v.key or ''):find('celestial')
end)

local ban_tarot_packs = pool_ids('Booster', function(v)
    return v.kind == 'Arcana' or (v.key or ''):find('arcana')
end)

local ban_commons   = pool_ids('Joker', function(v) return v.rarity == 1 or v.rarity == 'Common' end)

local ban_unlockable_jokers = pool_ids('Joker', function(v)
    if v.rarity == 4 or v.rarity == 'Legendary' then return false end
    return v.unlock_condition ~= nil or v.unlocked == false
end)

--============================================================
-- Deck builders
--============================================================

local SUITS = { 'S', 'H', 'D', 'C' }
local RANKS = { '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A' }
local FACES = { 'J', 'Q', 'K' }

local function full_deck(enh)
    local t = {}
    for _, s in ipairs(SUITS) do
        for _, r in ipairs(RANKS) do t[#t + 1] = { s = s, r = r, e = enh } end
    end
    return t
end

local function face_deck()
    local t = {}
    for _ = 1, 3 do
        for _, s in ipairs(SUITS) do
            for _, r in ipairs(FACES) do t[#t + 1] = { s = s, r = r } end
        end
    end
    return t
end

local function challenge(key, name, opts)
    opts = opts or {}
    SMODS.Challenge{
        key = key,
        loc_txt = { name = name },
        rules = { custom = opts.custom or {}, modifiers = opts.modifiers or {} },
        jokers = opts.jokers or {},
        consumeables = opts.consumeables or {},
        vouchers = opts.vouchers or {},
        deck = opts.deck or { type = 'Challenge Deck' },
        restrictions = {
            banned_cards = opts.banned_cards or {},
            banned_tags  = opts.banned_tags or {},
            banned_other = opts.banned_other or {},
        },
        unlocked = function(self) return true end,
    }
end

--============================================================
-- Challenges 21-50
--============================================================
challenge('no_refunds', 'No Refunds', { custom = { { id = 'eeng_no_refunds' } } })
challenge('black_market', 'Black Market', { custom = { { id = 'eeng_black_market' } } })
challenge('thrift_store', 'Thrift Store', {
    custom = { { id = 'eeng_thrift_store' }, { id = 'eeng_no_reroll' } },
    vouchers = { { id = 'v_overstock_norm' }, { id = 'v_overstock_plus' } },
})
challenge('impulse_buyer', 'Impulse Buyer', { custom = { { id = 'eeng_impulse_buyer' } } })
challenge('homeless', 'Homeless', {
    modifiers = { { id = 'dollars', value = -20 } },
    jokers = { { id = 'j_vagabond', eternal = true } },
})
challenge('ivory_tower', 'Ivory Tower', {
    modifiers = { { id = 'dollars', value = 20 } },
    banned_cards = merge_pools(ban_tarots, ban_planets, ban_spectrals, ban_nonbuffoon_boosters),
    banned_tags = { { id = 'tag_charm' }, { id = 'tag_meteor' }, { id = 'tag_ethereal' } },
})
challenge('new_beginnings', 'New Beginnings', { banned_cards = ban_unlockable_jokers })
challenge('suit_up', 'Suit Up', {
    custom = { { id = 'eeng_suit_up' } },
    consumeables = { { id = 'c_lovers' }, { id = 'c_fool' } },
    jokers = { { id = 'j_flower_pot', eternal = true } },
    banned_other = {
        { id = 'bl_goad', type = 'blind' }, { id = 'bl_head', type = 'blind' },
        { id = 'bl_club', type = 'blind' }, { id = 'bl_window', type = 'blind' },
    },
})
challenge('one_trick', 'The One Trick', { custom = { { id = 'eeng_one_trick' } } })
challenge('no_common_sense', 'No Common Sense', { banned_cards = ban_commons })
challenge('everything_price', 'Everything For a Price', { custom = { { id = 'eeng_all_perishable' } } })
challenge('joker_draft', 'Joker Draft', { custom = { { id = 'eeng_joker_draft' } } })
challenge('legendary_run', 'Legendary Run, but..', {
    custom = { { id = 'eeng_legendary_twist' } },
    modifiers = { { id = 'joker_slots', value = 0 } },
    jokers = {
        { id = 'j_caino',     eternal = true },
        { id = 'j_triboulet', eternal = true },
        { id = 'j_yorick',    eternal = true },
        { id = 'j_chicot',    eternal = true },
        { id = 'j_perkeo',    eternal = true },
    },
    -- Luchador and The Soul are the two routes to extra/duplicate Legendaries here, so both
    -- are banned to keep the starting five the only Legendaries in the run.
    banned_cards = { { id = 'j_luchador' }, { id = 'c_soul' } },
    banned_other = {
        { id = 'bl_final_acorn',  type = 'blind' },
        { id = 'bl_final_vessel', type = 'blind' },
        { id = 'bl_final_heart',  type = 'blind' },
        { id = 'bl_final_bell',   type = 'blind' },
    },
})
challenge('half_a_hand', 'Half a Hand', {
    custom = { { id = 'eeng_half_a_hand' } },
    jokers = { { id = 'j_half', edition = 'negative', eternal = true } },
})
challenge('slow_hands', 'Slow Hands', {
    custom = { { id = 'eeng_slow_hands' } },
    modifiers = { { id = 'hand_size', value = 13 }, { id = 'hands', value = 2 }, { id = 'discards', value = 1 } },
})
challenge('poker_purist', 'Poker Purist', {
    custom = { { id = 'eeng_poker_purist' } },
    jokers = { { id = 'j_space', edition = 'negative' } },
})
challenge('wild_west', 'Wild West', {
    custom = { { id = 'eeng_wild_west' } },
    deck = { type = 'Challenge Deck', cards = full_deck('m_wild') },
})
challenge('balanstro', 'Balanstro', {
    custom = { { id = 'eeng_balanstro' } },
    jokers = { { id = 'j_obelisk', edition = 'negative', eternal = true } },
})
challenge('double_down', 'Double Down', { custom = { { id = 'eeng_double_down' } } })
challenge('final_form', 'Final Form', {
    custom = { { id = 'eeng_final_form' } },
    modifiers = { { id = 'joker_slots', value = 0 } },
})
challenge('recursion', 'Recursion', { custom = { { id = 'eeng_recursion' } } })
challenge('glass_house', 'Glass House', {
    custom = { { id = 'eeng_glass_house' } },
    deck = { type = 'Challenge Deck', cards = full_deck('m_glass') },
})
challenge('rusty_deck', 'Rusty Deck', {
    custom = { { id = 'eeng_rusty_deck' } },
    deck = { type = 'Challenge Deck', cards = full_deck('m_steel') },
})
challenge('ancient_technology', 'Ancient Technology', {
    banned_cards = merge_pools(ban_planets, ban_planet_packs),
    banned_tags = { { id = 'tag_meteor' } },
})
challenge('stargazer', 'Stargazer', {
    banned_cards = merge_pools(ban_tarots, ban_tarot_packs),
    banned_tags = { { id = 'tag_charm' } },
})
challenge('recovered', 'The Recovered', {
    modifiers = { { id = 'hand_size', value = 5 } },
    deck = { type = 'Challenge Deck', cards = face_deck() },
})
challenge('tenant', 'The Tenant', {
    custom = {
        { id = 'eeng_tenant' },
        { id = 'money_per_hand', value = 2 },
    },
    banned_cards = { { id = 'j_credit_card' } },
    banned_other = { { id = 'bl_ox', type = 'blind' } },
})
challenge('gambler', 'The Gambler', {
    custom = { { id = 'eeng_gambler' }, { id = 'eeng_gambler_risk' } },
    banned_cards = { { id = 'v_reroll_surplus' }, { id = 'v_reroll_glut' } },
})
challenge('long_game', 'The Long Game', { custom = { { id = 'eeng_long_game' } } })
challenge('trial', 'The Trial', {
    custom = { { id = 'eeng_trial' } },
    jokers = { { id = 'j_luchador' } },
    banned_cards = { { id = 'j_chicot' } },
})
