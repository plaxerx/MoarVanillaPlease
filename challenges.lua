-- Moar Vanilla Please - Challenges. A continuation of the vanilla list from 21-50.
--
-- Game:start_run turns `rules.custom = {{id = 'foo'}}` into `G.GAME.modifiers.foo = true`
-- (or `value = x` stores x instead). A custom rule is a named flag on the run that the
-- hooks below read - the same seam vanilla uses for chips_dollar_cap.

local function m(id) return G.GAME and G.GAME.modifiers and G.GAME.modifiers[id] end

--============================================================
-- Shop / economy hooks
--============================================================

local mvp_set_cost = Card.set_cost
function Card:set_cost()
    mvp_set_cost(self)
    if not (m('mvp_black_market') or m('mvp_thrift_store') or m('mvp_no_refunds')) then return end

    local c = MVP.plain(self.cost) or 0
    local set = self.ability and self.ability.set
    if m('mvp_black_market') then c = c * 2 end
    if m('mvp_thrift_store') and (set == 'Joker' or set == 'Booster') then
        c = math.floor(c * 0.5)
    end
    local floor_c = (self.ability and self.ability.rental) and 0 or 1
    self.cost = math.max(floor_c, c)
    if m('mvp_no_refunds') then
        self.sell_cost = 0
    else
        self.sell_cost = math.max(floor_c, math.floor(self.cost / 2))
            + (self.ability and MVP.plain(self.ability.extra_value) or 0)
    end
end

local mvp_can_reroll = G.FUNCS.can_reroll
G.FUNCS.can_reroll = function(e)
    mvp_can_reroll(e)
    if m('mvp_no_reroll') then
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

local mvp_impulse_armed = false

-- Jokers are sold entering the shop rather than at Boss Blind end, so the cash-out screen
-- still pays the blind reward first. Keyed on ante to fire once per shop.
local function joker_draft_sweep()
    if not (m('mvp_joker_draft') and G.jokers and G.GAME.round_resets) then return end
    local ante = MVP.plain(G.GAME.round_resets.ante) or 0
    if G.GAME.mvp_draft_ante == ante then return end
    G.GAME.mvp_draft_ante = ante
    for i = #G.jokers.cards, 1, -1 do
        local c = G.jokers.cards[i]
        if c and not c.ability.eternal then
            ease_dollars(MVP.plain(c.cost) or 0)
            c:start_dissolve()
        end
    end
end

local mvp_update_shop = Game.update_shop
function Game:update_shop(dt)
    mvp_update_shop(self, dt)
    joker_draft_sweep()
    if not (m('mvp_impulse_buyer') and mvp_impulse_armed) then return end
    local card = G.shop_jokers and G.shop_jokers.cards and G.shop_jokers.cards[1]
    if not card then return end
    mvp_impulse_armed = false

    local price = MVP.plain(card.cost) or 0
    local dollars = MVP.plain(G.GAME.dollars) or 0
    if price > dollars then return end
    pcall(G.FUNCS.buy_from_shop, { config = { ref_table = card } })
end

local mvp_reroll = G.FUNCS.reroll_shop
G.FUNCS.reroll_shop = function(e)
    if m('mvp_gambler') then
        G.GAME.mvp_gambler_rerolls = (G.GAME.mvp_gambler_rerolls or 0) + 1
        if G.jokers and #G.jokers.cards > 0 and pseudorandom('mvp_gambler') < 1 / 6 then
            local c = G.jokers.cards[pseudorandom('mvp_gambler_pick', 1, #G.jokers.cards)]
            if c and not c.ability.eternal then
                play_sound('glass' .. math.random(1, 6), math.random() * 0.2 + 0.9, 0.5)
                c:start_dissolve()
            end
        end
    end
    return mvp_reroll(e)
end

local mvp_calc_reroll = calculate_reroll_cost
function calculate_reroll_cost(skip_increment)
    mvp_calc_reroll(skip_increment)
    if not (G.GAME and G.GAME.current_round) then return end
    if m('mvp_gambler') then
        local done = G.GAME.mvp_gambler_rerolls or 0
        G.GAME.current_round.reroll_cost = math.max(0, done + 1 - 10)
    end
    if m('mvp_impulse_buyer') then
        mvp_impulse_armed = true 
    end
end

--============================================================
-- Card pools
--============================================================
-- Vanilla keeps no global SUITS/RANKS, so these are ours, declared here for the
-- hand-legality and Recursion hooks below. Keys match G.P_CARDS ('S_A', 'H_T').
local SUITS = { 'S', 'H', 'D', 'C' }
local RANKS = { '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A' }
local FACES = { 'J', 'Q', 'K' }

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

-- Lower order = stronger hand: SMODS numbers PokerHands from Flush Five (1) down.
local function hand_order(name)
    local ph = SMODS.PokerHands and SMODS.PokerHands[name]
    return ph and ph.order or 99
end

-- The un-localized hand name, resolved the way scoring resolves it: the first return of
-- get_poker_hand_info, which play_cards_from_highlighted itself calls.
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

local mvp_debuff_hand = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, check)
    if mvp_debuff_hand(self, cards, hand, handname, check) then return true end

    if m('mvp_suit_up') and suits_in(cards) < 4 then return true end

    -- Only the real call (check falsy) happens once per played hand, and only a hand that
    -- passes actually scores, so a rejected hand can't become the bar to beat.
    if m('mvp_poker_purist') and handname then
        local ord, rank = hand_order(handname), top_rank(cards)
        local prev, prev_rank = G.GAME.mvp_last_hand_order, G.GAME.mvp_last_hand_rank or 0
        if prev then
            if ord > prev then return true end
            if ord == prev and rank <= prev_rank then return true end
        end
        if not check then
            G.GAME.mvp_last_hand_order = ord
            G.GAME.mvp_last_hand_rank = rank
        end
    end

    if m('mvp_balanstro') and handname and G.GAME.hands then
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
                -- evaluate_play_intro already counted this hand before the real debuff_hand
                -- call, so it looks played once more than every rival; undo that here. The
                -- check=true preview runs before the increment and needs no adjustment.
                local mine = MVP.plain(this.played) or 0
                if not check then mine = mine - 1 end
                local min
                for name, matches in pairs(parts) do
                    if next(matches) and G.GAME.hands[name] then
                        local p = MVP.plain(G.GAME.hands[name].played) or 0
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
local mvp_eval_round = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function(...)
    if m('mvp_trial') and G.GAME.round_resets
        and G.GAME.blind_on_deck and G.GAME.blind_on_deck ~= 'Boss' then
        local bs = G.GAME.round_resets.blind_states
        if bs then
            bs[G.GAME.blind_on_deck] = 'Defeated'
            if bs.Boss == 'Defeated' then bs.Boss = 'Upcoming' end
        end
    end
    -- Poker Purist resets each round, so the next round's first hand has nothing to beat.
    G.GAME.mvp_last_hand_order = nil
    G.GAME.mvp_last_hand_rank = nil
    return mvp_eval_round(...)
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

local mvp_destroying = SMODS.calculate_destroying_cards
function SMODS.calculate_destroying_cards(context, cards_destroyed, scoring_hand)
    mvp_destroying(context, cards_destroyed, scoring_hand)
    if not scoring_hand then return end

    if m('mvp_glass_house') and context.scoring_name ~= 'Full House' then
        for _, c in ipairs(context.full_hand or {}) do
            mark_destroyed(c, cards_destroyed)
        end
    end

    if m('mvp_recursion') then
        local replaced = 0
        for _, c in ipairs(scoring_hand) do
            if not c.getting_sliced then replaced = replaced + 1 end
            mark_destroyed(c, cards_destroyed)
        end
        if replaced > 0 then
            for _ = 1, replaced do
                local proto = {
                    s = SUITS[pseudorandom('mvp_rec_s', 1, #SUITS)],
                    r = RANKS[pseudorandom('mvp_rec_r', 1, #RANKS)],
                    e = ENH_POOL[pseudorandom('mvp_rec_e', 1, #ENH_POOL)],
                }
                G.E_MANAGER:add_event(Event({ func = function()
                    card_from_control(proto); return true
                end }))
            end
        end
    end
end

-- 43: steel cards rust leaving play for the discard. draw_from_play_to_discard iterates
-- G.play.cards at exactly that moment. Debuff only, no destruction, so the card scored
-- normally this hand; mvp_rusted keeps it debuffed from the next draw on. card1 is The
-- Hook's discard sound.
local mvp_draw_discard = G.FUNCS.draw_from_play_to_discard
G.FUNCS.draw_from_play_to_discard = function(e)
    if m('mvp_rusty_deck') and G.play then
        for _, c in ipairs(G.play.cards) do
            if SMODS.has_enhancement and SMODS.has_enhancement(c, 'm_steel') and not c.mvp_rusted then
                c.mvp_rusted = true
                c:set_debuff(true)
                -- Per card, as The Hook does it (blind.lua:509-516).
                c:juice_up(0.3, 0.3)
                play_sound('card1', 1)
            end
        end
    end
    return mvp_draw_discard(e)
end

--============================================================
-- Joker lifecycle hooks
--============================================================

local mvp_cloning = false

local mvp_add_to_deck = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    mvp_add_to_deck(self, from_debuff)
    if not (self.ability and self.ability.set == 'Joker') then return end

    if m('mvp_all_perishable') and not self.ability.perishable
        and not (self.config and self.config.center and self.config.center.perishable_compat == false) then
        self.ability.perishable = true
        self.ability.perish_tally = G.GAME.perishable_rounds or 5
    end

    if m('mvp_one_trick') and not mvp_cloning then
        local src = self
        G.E_MANAGER:add_event(Event({ func = function()
            if G.jokers and not mvp_cloning then
                mvp_cloning = true
                local want = (G.jokers.config.card_limit or 0) - #G.jokers.cards
                for _ = 1, math.min(want, 20) do
                    local c = copy_card(src, nil)
                    c:add_to_deck()
                    G.jokers:emplace(c)
                end
                mvp_cloning = false
            end
            return true
        end }))
    end
end

local mvp_sell = G.FUNCS.sell_card
G.FUNCS.sell_card = function(e)
    local card = e and e.config and e.config.ref_table
    local key = m('mvp_one_trick') and card and card.config and card.config.center_key
    local res = mvp_sell(e)
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

local mvp_create_card = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    local c = mvp_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    if c and c.ability then
        if c.ability.set == 'Joker' then
            if m('mvp_all_perishable') and not c.ability.perishable
                and not (c.config and c.config.center and c.config.center.perishable_compat == false) then
                c.ability.perishable = true
                c.ability.perish_tally = G.GAME.perishable_rounds or 5
            end
            if m('mvp_tenant') and not c.ability.rental then
                c.ability.rental = true
                if c.set_cost then c:set_cost() end   -- rentals price at $1; recompute
            end
        elseif c.ability.set == 'Default' or c.ability.set == 'Enhanced' then
            -- 37: the set_debuff wrapper below turns this into debuffed-unless-Wild.
            if m('mvp_wild_west') then c:set_debuff(false) end
        end
    end
    return c
end

local mvp_calc_retriggers = SMODS.calculate_retriggers
function SMODS.calculate_retriggers(card, context, _ret)
    local ret = mvp_calc_retriggers(card, context, _ret)
    if m('mvp_double_down') and card and card.ability and card.ability.set == 'Joker'
        and SMODS.insert_repetitions then
        SMODS.insert_repetitions(ret, { repetitions = 1, message = localize('k_again_ex') },
            card, 'joker_retrigger')
    end
    return ret
end

-- Retriggers only replay scoring, so Jokers that fire once per event (Cartomancer on blind
-- select, Rocket at end of round) are never doubled. calculate_joker runs a second time for
-- those contexts only; scoring keeps to the retrigger path above.
local DD_EVENT_CONTEXTS = {
    'setting_blind', 'first_hand_drawn', 'hand_drawn', 'pre_discard', 'discard',
    'end_of_round', 'buying_card', 'open_booster', 'skip_blind', 'reroll_shop',
    'using_consumeable', 'skipping_booster', 'ending_shop', 'card_added',
}

local mvp_calc_joker = Card.calculate_joker
function Card:calculate_joker(context, ...)
    local eff, post = mvp_calc_joker(self, context, ...)
    if m('mvp_double_down') and context and self.ability and self.ability.set == 'Joker'
        and not context.blueprint_card and not context.retrigger_joker
        and not context.retrigger_joker_check and not self.mvp_dd_running then
        for _, key in ipairs(DD_EVENT_CONTEXTS) do
            if context[key] then
                self.mvp_dd_running = true          -- rerun must not re-enter here
                pcall(mvp_calc_joker, self, context, ...)
                self.mvp_dd_running = nil
                break
            end
        end
    end
    return eff, post
end

--============================================================
-- Run-shape hooks
--============================================================
local mvp_start_run = Game.start_run
function Game:start_run(args)
    mvp_start_run(self, args)
    if not (G.GAME and G.GAME.modifiers) then return end
    if m('mvp_half_a_hand') then
        if G.hand then G.hand.config.highlighted_limit = 3 end
        if G.GAME.starting_params then G.GAME.starting_params.play_limit = 3 end
    end
    if m('mvp_long_game') then G.GAME.win_ante = 16 end
end

local mvp_ease_ante = ease_ante
function ease_ante(mod)
    mvp_ease_ante(mod)
    if m('mvp_final_form') and G.jokers and MVP.plain(mod) and MVP.plain(mod) > 0 then
        G.jokers.config.card_limit = G.jokers.config.card_limit + 1
    end
    -- Legendary Run twist: Chicot is destroyed on reaching ante 8, bypassing its Eternal.
    if m('mvp_legendary_twist') and G.jokers and not G.GAME.mvp_chicot_destroyed
        and G.GAME.round_resets and (MVP.plain(G.GAME.round_resets.ante) or 0) >= 8 then
        G.GAME.mvp_chicot_destroyed = true
        for i = #G.jokers.cards, 1, -1 do
            local c = G.jokers.cards[i]
            local ck = c.config and (c.config.center_key or (c.config.center and c.config.center.key))
            if ck == 'j_chicot' then c:start_dissolve() end
        end
    end
end

local mvp_get_blind_amount = get_blind_amount
function get_blind_amount(ante)
    local base = mvp_get_blind_amount(ante)
    if m('mvp_double_down') and ante and ante > 1 then
        return (to_big and to_big(base) or base) * 2
    end
    return base
end

-- G.GAME.blind is one Blind object reused for every blind, so an "already did this" flag
-- would latch after the first. Recompute from the incoming blind config instead.
local mvp_set_blind_ch = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    mvp_set_blind_ch(self, blind, reset, silent)
    if reset then return end
    if m('mvp_tenant') then
        self.dollars = (MVP.plain(blind and blind.dollars) or 0) * 2
        G.GAME.current_round.dollars_to_be_earned = self.dollars > 0
            and string.rep(localize('$'), self.dollars) or ''
    end
end

--============================================================
-- Bosses in Small/Big slots (50, and Erratic Mode's Boss Rush)
--============================================================

local function bosses_everywhere()
    if not m('mvp_trial') then return false end
    return (G.GAME.round_resets and G.GAME.round_resets.ante or 1) >= 2
end

-- Vanilla rerolls the shop Voucher whenever the defeated blind isn't literally bl_small or
-- bl_big, so a Boss in the Small/Big slot would pay a new Voucher every round. Keep the
-- current one unless the actual Boss slot was beaten.
local mvp_next_vouchers = SMODS.get_next_vouchers
function SMODS.get_next_vouchers(existing)
    if not existing
        and m('mvp_trial')
        and G.STATE == G.STATES.ROUND_EVAL
        and G.GAME and G.GAME.blind_on_deck and G.GAME.blind_on_deck ~= 'Boss'
        and G.GAME.current_round and G.GAME.current_round.voucher then
        return G.GAME.current_round.voucher
    end
    return mvp_next_vouchers(existing)
end

-- Vanilla reset_blinds only refreshes blind_choices.Boss each ante. Re-roll Small and Big
-- too, so they draw fresh from the boss pool the way the real Boss slot does.
local mvp_reset_blinds = reset_blinds
function reset_blinds()
    -- Vanilla clears Boss to 'Upcoming' inside the call, so read the marker first.
    local bs = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    local new_ante = bs and bs.Boss == 'Defeated'
    mvp_reset_blinds()
    local rr = G.GAME and G.GAME.round_resets
    if not (rr and rr.blind_choices) then return end
    if bosses_everywhere() then
        for _, slot in ipairs({ 'Small', 'Big' }) do
            local cur = G.P_BLINDS[rr.blind_choices[slot]]
            if new_ante or not (cur and cur.boss) then
                rr.blind_choices[slot] = get_new_boss()
            end
        end
    end
end

-- Reports the SLOT a blind sits in, so bookkeeping keyed on blind type treats a Boss in
-- the Small/Big slot as that slot. mvp_true_blind_type suspends this for callers really
-- asking "is this a Boss Blind".
local mvp_get_type = Blind.get_type
function Blind:get_type()
    if not (G.GAME and G.GAME.mvp_true_blind_type)
        and bosses_everywhere() and G.GAME.blind_on_deck and G.GAME.blind_on_deck ~= 'Boss' then
        return G.GAME.blind_on_deck
    end
    return mvp_get_type(self)
end

-- Luchador gates its disable on get_type() == 'Boss', so the slot answer above would
-- refuse to cancel a Boss in the Small/Big slot - the one tool The Trial hands you.
local mvp_sell_card = Card.sell_card
function Card:sell_card()
    local luchador = self.ability and self.ability.name == 'Luchador'
    local saved = G.GAME and G.GAME.mvp_true_blind_type
    if luchador and G.GAME then G.GAME.mvp_true_blind_type = true end
    local ret = mvp_sell_card(self)
    if luchador and G.GAME then G.GAME.mvp_true_blind_type = saved end
    return ret
end

-- Luchador's tooltip reads the same check to show whether it can disable the blind now,
-- so it must agree with the sell above.
local mvp_ability_table = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(vars_only)
    local luchador = self.ability and self.ability.name == 'Luchador'
    local saved = G.GAME and G.GAME.mvp_true_blind_type
    if luchador and G.GAME then G.GAME.mvp_true_blind_type = true end
    local ret = mvp_ability_table(self, vars_only)
    if luchador and G.GAME then G.GAME.mvp_true_blind_type = saved end
    return ret
end

--============================================================
-- Debuffs (37 / 43)
--============================================================
local mvp_card_set_debuff = Card.set_debuff
function Card:set_debuff(should_debuff)
    local playing = self.ability and (self.ability.set == 'Default' or self.ability.set == 'Enhanced')
    if playing and m('mvp_wild_west') and not is_wild(self) then should_debuff = true end
    if self.mvp_rusted then should_debuff = true end
    return mvp_card_set_debuff(self, should_debuff)
end

--============================================================
-- Board note (28's always-visible rule)
--============================================================

local mvp_note = nil

local function sync_board_note()
    local want = G.STAGE == G.STAGES.RUN and G.STATE == G.STATES.SELECTING_HAND
        and m('mvp_suit_up') and G.play and G.play.T
    if want and not mvp_note then
        mvp_note = UIBox{
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
    elseif mvp_note and not want then
        mvp_note:remove()
        mvp_note = nil
    end
end

local mvp_game_update_ch = Game.update
function Game:update(dt)
    mvp_game_update_ch(self, dt)
    sync_board_note()
end

--============================================================
-- Description screen safety
--============================================================
local mvp_ch_desc_tab = G.UIDEF.challenge_description_tab
function G.UIDEF.challenge_description_tab(args)
    local ch = args and args._id and G.CHALLENGES[args._id]
    local r = ch and ch.restrictions
    if r and type(r.banned_cards) == 'function' then r.banned_cards = r.banned_cards() end
    return mvp_ch_desc_tab(args)
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
challenge('no_refunds', 'No Refunds', { custom = { { id = 'mvp_no_refunds' } } })
challenge('black_market', 'Black Market', { custom = { { id = 'mvp_black_market' } } })
challenge('thrift_store', 'Thrift Store', {
    custom = { { id = 'mvp_thrift_store' }, { id = 'mvp_no_reroll' } },
    vouchers = { { id = 'v_overstock_norm' }, { id = 'v_overstock_plus' } },
})
challenge('impulse_buyer', 'Impulse Buyer', { custom = { { id = 'mvp_impulse_buyer' } } })
challenge('homeless', 'Homeless', {
    custom = { { id = 'mvp_homeless' } },
    modifiers = { { id = 'dollars', value = -20 } },
    jokers = { { id = 'j_vagabond', eternal = true } },
})
-- The Tarot/Planet vouchers would only raise the rate of cards this challenge removed.
local ban_consumable_vouchers = {
    { id = 'v_tarot_merchant' }, { id = 'v_tarot_tycoon' },
    { id = 'v_planet_merchant' }, { id = 'v_planet_tycoon' },
    { id = 'v_observatory' }, { id = 'v_omen_globe' },
}
challenge('ivory_tower', 'Ivory Tower', {
    custom = { { id = 'mvp_ivory_tower' } },
    modifiers = { { id = 'dollars', value = 20 } },
    banned_cards = merge_pools(ban_tarots, ban_planets, ban_spectrals, ban_nonbuffoon_boosters,
                               ban_consumable_vouchers),
    banned_tags = { { id = 'tag_charm' }, { id = 'tag_meteor' }, { id = 'tag_ethereal' } },
})
challenge('new_beginnings', 'New Beginnings', {
    custom = { { id = 'mvp_new_beginnings' } },
    banned_cards = ban_unlockable_jokers,
})
challenge('suit_up', 'Suit Up', {
    custom = { { id = 'mvp_suit_up' } },
    consumeables = { { id = 'c_lovers' }, { id = 'c_fool' } },
    jokers = { { id = 'j_flower_pot', eternal = true } },
    banned_other = {
        { id = 'bl_goad', type = 'blind' }, { id = 'bl_head', type = 'blind' },
        { id = 'bl_club', type = 'blind' }, { id = 'bl_window', type = 'blind' },
    },
})
challenge('one_trick', 'The One Trick', { custom = { { id = 'mvp_one_trick' } } })
challenge('no_common_sense', 'No Common Sense', {
    custom = { { id = 'mvp_no_commons' } },
    banned_cards = ban_commons,
})
challenge('everything_price', 'Everything For a Price', { custom = { { id = 'mvp_all_perishable' } } })
challenge('joker_draft', 'Joker Draft', { custom = { { id = 'mvp_joker_draft' } } })
challenge('legendary_run', 'Legendary Run, but..', {
    custom = { { id = 'mvp_legendary_twist' } },
    modifiers = { { id = 'joker_slots', value = 0 } },
    jokers = {
        { id = 'j_caino',     eternal = true },
        { id = 'j_triboulet', eternal = true },
        { id = 'j_yorick',    eternal = true },
        { id = 'j_chicot',    eternal = true },
        { id = 'j_perkeo',    eternal = true },
    },
    -- Luchador and The Soul are the two routes to extra Legendaries; both banned to keep
    -- the starting five the only ones in the run.
    banned_cards = { { id = 'j_luchador' }, { id = 'c_soul' } },
    banned_other = {
        { id = 'bl_final_acorn',  type = 'blind' },
        { id = 'bl_final_vessel', type = 'blind' },
        { id = 'bl_final_heart',  type = 'blind' },
        { id = 'bl_final_bell',   type = 'blind' },
    },
})
challenge('half_a_hand', 'Half a Hand', {
    custom = { { id = 'mvp_half_a_hand' } },
    jokers = { { id = 'j_half', edition = 'negative', eternal = true } },
})
challenge('slow_hands', 'Slow Hands', {
    custom = { { id = 'mvp_slow_hands' } },
    modifiers = { { id = 'hand_size', value = 13 }, { id = 'hands', value = 2 }, { id = 'discards', value = 1 } },
})
challenge('poker_purist', 'Poker Purist', {
    custom = { { id = 'mvp_poker_purist' } },
    jokers = { { id = 'j_space', edition = 'negative' } },
})
challenge('wild_west', 'Wild West', {
    custom = { { id = 'mvp_wild_west' } },
    deck = { type = 'Challenge Deck', cards = full_deck('m_wild') },
})
challenge('balanstro', 'Balanstro', {
    custom = { { id = 'mvp_balanstro' } },
    jokers = { { id = 'j_obelisk', edition = 'negative', eternal = true } },
})
challenge('double_down', 'Double Down', { custom = { { id = 'mvp_double_down' } } })
challenge('final_form', 'Final Form', {
    custom = { { id = 'mvp_final_form' } },
    modifiers = { { id = 'joker_slots', value = 0 } },
})
challenge('recursion', 'Recursion', { custom = { { id = 'mvp_recursion' } } })
challenge('glass_house', 'Glass House', {
    custom = { { id = 'mvp_glass_house' } },
    deck = { type = 'Challenge Deck', cards = full_deck('m_glass') },
})
challenge('rusty_deck', 'Rusty Deck', {
    custom = { { id = 'mvp_rusty_deck' } },
    deck = { type = 'Challenge Deck', cards = full_deck('m_steel') },
})
challenge('ancient_technology', 'Ancient Technology', {
    custom = { { id = 'mvp_ancient_tech' } },
    banned_cards = merge_pools(ban_planets, ban_planet_packs),
    banned_tags = { { id = 'tag_meteor' } },
})
challenge('stargazer', 'Stargazer', {
    custom = { { id = 'mvp_stargazer' } },
    banned_cards = merge_pools(ban_tarots, ban_tarot_packs),
    banned_tags = { { id = 'tag_charm' } },
})
challenge('recovered', 'The Recovered', {
    custom = { { id = 'mvp_recovered' } },
    modifiers = { { id = 'hand_size', value = 5 } },
    deck = { type = 'Challenge Deck', cards = face_deck() },
})
challenge('tenant', 'The Tenant', {
    custom = {
        { id = 'mvp_tenant' },
        { id = 'money_per_hand', value = 2 },
    },
    banned_cards = { { id = 'j_credit_card' } },
    banned_other = { { id = 'bl_ox', type = 'blind' } },
})
challenge('gambler', 'The Gambler', {
    custom = { { id = 'mvp_gambler' }, { id = 'mvp_gambler_risk' } },
    banned_cards = { { id = 'v_reroll_surplus' }, { id = 'v_reroll_glut' } },
})
challenge('long_game', 'The Long Game', { custom = { { id = 'mvp_long_game' } } })
-- Chicot disables Boss Blinds and the Boss Tag / reroll vouchers re-roll them, both of
-- which would defuse a challenge made entirely of Boss Blinds.
challenge('trial', 'The Trial', {
    custom = { { id = 'mvp_trial' } },
    jokers = { { id = 'j_luchador' } },
    -- Vouchers go in banned_cards, not banned_other: the challenge screen's ban list only
    -- draws banned_other entries with type == 'blind', so vouchers there are never shown.
    banned_cards = { { id = 'j_chicot' }, { id = 'v_directors_cut' }, { id = 'v_retcon' } },
    banned_tags = { { id = 'tag_boss' } },
})
