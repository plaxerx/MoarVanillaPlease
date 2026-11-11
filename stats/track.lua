-- Moar Stats Please - the trackers. Every vanilla seam the mod listens on.
--
-- HOUSE RULES FOR THIS FILE
--  * A hook records and gets out of the way. It calls the original, returns its result
--    untouched, and never queues an event, spends money or draws an RNG stream.
--  * Every wrap goes through `hook`, which records whether the seam existed. A missing seam
--    costs that one stat, never a crash, and shows up in MSP.hook_report().
--  * Scores are Talisman-sized. They are multiplied in place and handed to MSP.mag; they are
--    never floored and never compared as plain numbers.

--============================================================
-- Wrapping
--============================================================
MSP.HOOKS = {}

-- Wraps `field` on `tbl` with `builder(original)`. Records the outcome so a version bump
-- that renames a seam is visible instead of silent.
local function hook(name, tbl, field, builder)
    if type(tbl) ~= 'table' or type(tbl[field]) ~= 'function' then
        MSP.HOOKS[name] = 'missing'
        return false
    end
    tbl[field] = builder(tbl[field])
    MSP.HOOKS[name] = 'ok'
    return true
end

-- A tracker must never take the run down with it, so every body runs inside pcall.
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then MSP.last_error = tostring(err) end
    end
end

-- Which seams bound and which did not. Printed to the console on load.
function MSP.hook_report()
    local ok_n, miss = 0, {}
    for name, state in pairs(MSP.HOOKS) do
        if state == 'ok' then ok_n = ok_n + 1 else miss[#miss + 1] = name end
    end
    table.sort(miss)
    return ok_n, miss
end

--============================================================
-- Card facts
--============================================================
local function edition_key(card)
    local e = card and card.edition
    if type(e) ~= 'table' then return nil end
    if e.key then return e.key end
    if e.type then return e.type end
    for _, k in ipairs({ 'negative', 'polychrome', 'holo', 'foil' }) do
        if e[k] then return k end
    end
    return next(e)
end

-- A card in the deck rather than a Joker or a consumable. `base.value` is only ever set on
-- a playing card.
local function is_playing_card(card)
    return card and card.base and card.base.value and not (card.ability and card.ability.set == 'Joker')
end

-- The Joker a payout belongs to, while one is being paid. Set around a Joker's own
-- calculation (To Do List calls ease_dollars inline, card.lua:3904) and around SMODS paying a
-- returned {dollars = n} effect (utils.lua SMODS.calculate_individual_effect), then read by
-- the ease_dollars hook. A copy credits the copier: Brainstorm running To Do List earned that
-- money, not To Do List.
local money_source = nil

local function joker_key(card)
    if card and card.ability and card.ability.set == 'Joker' then
        return card.config and card.config.center_key
    end
end

local function seal_key(card)
    local s = card and card.seal
    if type(s) == 'table' then return s.key or s.name end
    return s
end

-- Tallies one played or discarded card across every breakdown group.
local function tally_card(card, field)
    if not (card and card.base) then return end
    if card.base.suit then MSP.tally('suits', card.base.suit, field) end
    if card.base.value then MSP.tally('ranks', card.base.value, field) end

    local center = card.config and card.config.center_key
    if center and center ~= 'c_base' then MSP.tally('enhancements', center, field) end
    local ed = edition_key(card)
    if ed then MSP.tally('editions', ed, field) end
    local sl = seal_key(card)
    if sl then MSP.tally('seals', sl, field) end
end

-- Per-card counters shared by playing and discarding.
local function count_cards(cards, prefix)
    for _, card in ipairs(cards or {}) do
        tally_card(card, prefix)
        if prefix == 'played' then
            MSP.inc('cards_played')
            local id = card.base and card.base.id
            if card.is_face and card:is_face() then MSP.inc('face_played')
            elseif id == 14 then MSP.inc('aces_played')
            else MSP.inc('numbered_played') end
            if card.config and card.config.center_key and card.config.center_key ~= 'c_base' then
                MSP.inc('enhanced_played')
            end
            if edition_key(card) then MSP.inc('edition_played') end
            if seal_key(card) then MSP.inc('sealed_played') end
            if card.debuff then MSP.inc('debuffed_played') end
        else
            MSP.inc('cards_discarded')
        end
    end
end

--============================================================
-- Run lifecycle
--============================================================
-- Abandonment is decided here rather than on reaching the main menu. Going to the menu
-- mid-run does NOT throw a Balatro run away - it stays on disk and Continue picks it back
-- up. A run is only abandoned once a different run starts on top of it.
hook('start_run', Game, 'start_run', function(orig)
    return function(self, args)
        local previous = MSP.active_run
        local ret = orig(self, args)
        safe(function()
            MSP.reset_samplers()
            MSP.begin_run()
            local r = MSP.run()
            -- Continue reloads the same run into a fresh table; matching seeds mean this is
            -- that run coming back, not a new one replacing it.
            if previous and r and previous ~= r and not previous.finished
               and (previous.meta or {}).seed ~= (r.meta or {}).seed then
                MSP.abandon(previous)
            end
        end)()
        return ret
    end
end)

--============================================================
-- Playing a hand
--============================================================
-- Fires once per hand, while the selection still sits in G.hand.highlighted: the only moment
-- the exact cards of this hand are addressable as a set.
hook('play_cards', G.FUNCS, 'play_cards_from_highlighted', function(orig)
    return function(e, ...)
        safe(function()
            local cards = (G.hand and G.hand.highlighted) or {}
            if #cards == 0 then return end
            MSP.inc('hands_played')
            count_cards(cards, 'played')
        end)()
        return orig(e, ...)
    end
end)

-- A scoring parameter at this instant. SMODS keeps chips and mult in Scoring_Parameters and
-- resets them to their defaults in an event queued by evaluate_play_after, so these must be
-- read before that function runs, not after.
local function scoring_parameter(key)
    if SMODS and SMODS.get_scoring_parameter then
        local ok, v = pcall(SMODS.get_scoring_parameter, key)
        if ok and v ~= nil then return v end
    end
    local h = G.GAME and G.GAME.current_round and G.GAME.current_round.current_hand
    return h and h[key] or 0
end

-- The score of the hand being scored right now. This is the same call vanilla itself hands
-- to check_and_set_high_score (state_events.lua:905), so it is the score by definition -
-- including whatever a modded scoring calculation does with chips and mult.
local function hand_score()
    if SMODS and SMODS.calculate_round_score then
        local ok, v = pcall(SMODS.calculate_round_score)
        if ok and v ~= nil then return v end
    end
    -- Fallback for a build without SMODS scoring parameters. Multiplied in place: collapsing
    -- either side to a plain number first is what turns a real Talisman score into inf.
    local c, m = scoring_parameter('chips'), scoring_parameter('mult')
    if to_big then return to_big(c) * to_big(m) end
    return MSP.num(c) * MSP.num(m)
end

-- Records the hand that just finished scoring.
--
-- `scoring_hand` is the FINAL set of cards that scored - built in evaluate_play_intro
-- (state_events.lua:636-653) after Splash, SMODS.always_scores (Stone cards),
-- SMODS.never_scores and any modify_scoring_hand effect have had their say. It is the only
-- honest answer to "which cards scored": in a Pair, the three cards that are not the pair
-- score nothing, and they are not debuffed either, so the old debuff test was measuring a
-- different question altogether.
local function record_hand(handname, disp_name, scoring_hand)
    local chips, mult = scoring_parameter('chips'), scoring_parameter('mult')
    local score = hand_score()
    local ctx = MSP.run_ctx()

    MSP.record('best_hand', score, ctx)
    MSP.record('best_chips', chips, ctx)
    MSP.record('best_mult', mult, ctx)
    MSP.inc('total_score', MSP.num(MSP.mag(score).num))

    local played = (G.play and G.play.cards) and #G.play.cards or 0
    local scored = scoring_hand and #scoring_hand or 0
    MSP.inc('cards_scored', scored)
    MSP.inc('cards_unscored', math.max(0, played - scored))

    if handname then
        MSP.tally('hands', handname, 'played')
        MSP.tally_best('hands', handname, score)
        -- Royal Flush is a ten-high Straight Flush. The game shows it under its own name but
        -- scores and levels it as a Straight Flush (state_events.lua:577-585), so it is
        -- counted as one, with the royal ones noted alongside.
        if disp_name == 'Royal Flush' then
            MSP.inc('royal_flushes')
            MSP.tally('hands', handname, 'royal')
        end
        local h = G.GAME.hands and G.GAME.hands[handname]
        if h then MSP.tally_best('hands', handname, MSP.num(h.level, 1), 'level') end
    end

    -- Overkill: how far past the requirement this single hand landed. Both sides can be
    -- big, so the ratio is taken on log magnitudes and read back as a plain multiplier.
    local need = G.GAME.blind and G.GAME.blind.chips
    if need then
        local a, b = MSP.mag(score), MSP.mag(need)
        if b.log > -1e299 and a.log > -1e299 then
            MSP.record('best_overkill', 10 ^ math.min(300, a.log - b.log), ctx)
        end
    end
end

-- evaluate_play_after is handed the hand name, the display name and the final scoring hand,
-- and runs once per hand after scoring has resolved but before the scoring parameters are
-- reset. Everything about a played hand is available in one place, exactly once.
hook('play_after', _G, 'evaluate_play_after', function(orig)
    return function(text, disp_text, poker_hands, scoring_hand, non_loc_disp_text, ...)
        safe(function() record_hand(text, non_loc_disp_text, scoring_hand) end)()
        return orig(text, disp_text, poker_hands, scoring_hand, non_loc_disp_text, ...)
    end
end)

-- A hand the Boss Blind refused. It still counts as played and still consumes a hand; it
-- just scores nothing.
hook('play_debuff', _G, 'evaluate_play_debuff', function(orig)
    return function(...)
        safe(function() MSP.inc('hands_debuffed') end)()
        return orig(...)
    end
end)

--============================================================
-- Discarding
--============================================================
hook('discard', G.FUNCS, 'discard_cards_from_highlighted', function(orig)
    return function(e, hook_arg, ...)
        safe(function()
            local cards = (G.hand and G.hand.highlighted) or {}
            if #cards == 0 then return end
            -- `hook_arg` marks a forced discard (a Joker or blind doing it), which does not
            -- spend one of the player's discards.
            if not hook_arg then MSP.inc('discards_used') end
            count_cards(cards, 'discarded')
        end)()
        return orig(e, hook_arg, ...)
    end
end)

hook('draw', G.FUNCS, 'draw_from_deck_to_hand', function(orig)
    return function(e, ...)
        local before = (G.hand and #G.hand.cards) or 0
        local ret = orig(e, ...)
        safe(function()
            local after = (G.hand and #G.hand.cards) or 0
            if after > before then MSP.inc('cards_drawn', after - before) end
        end)()
        return ret
    end
end)

--============================================================
-- Blinds
--============================================================
hook('blind_defeat', Blind, 'defeat', function(orig)
    return function(self, silent)
        safe(function()
            MSP.inc('blinds_defeated')
            local cfg = self.config and self.config.blind
            local key = cfg and cfg.key
            if self.boss then
                MSP.inc('boss_defeated')
                if key then MSP.tally('bosses', key, 'defeated') end
            elseif G.GAME and G.GAME.blind_on_deck == 'Small' then
                MSP.inc('small_defeated')
            else
                MSP.inc('big_defeated')
            end
        end)()
        return orig(self, silent)
    end
end)

-- Which Boss the run actually met. Read from the blind config being applied rather than
-- from a flag on the Blind: G.GAME.blind is one reused object, so a flag set on it would
-- latch after the first boss and never move again.
hook('set_blind', Blind, 'set_blind', function(orig)
    return function(self, blind, reset, silent)
        safe(function()
            if reset or not blind then return end
            if blind.boss and blind.key then MSP.tally('bosses', blind.key, 'faced') end
        end)()
        return orig(self, blind, reset, silent)
    end
end)

hook('skip_blind', G.FUNCS, 'skip_blind', function(orig)
    return function(e, ...)
        safe(function()
            MSP.inc('blinds_skipped')
            local tag = G.GAME and G.GAME.round_resets
                and G.GAME.round_resets.blind_tags
                and G.GAME.round_resets.blind_tags[G.GAME.blind_on_deck]
            if tag then
                MSP.inc('tags_taken')
                MSP.tally('tags', tag, 'taken')
            end
        end)()
        return orig(e, ...)
    end
end)

--============================================================
-- Round end
--============================================================
hook('evaluate_round', G.FUNCS, 'evaluate_round', function(orig)
    return function(...)
        safe(function()
            local cr = G.GAME and G.GAME.current_round
            if not cr then return end
            MSP.inc('rounds')

            local hands_left = math.max(0, math.floor(MSP.num(cr.hands_left)))
            local discards_left = math.max(0, math.floor(MSP.num(cr.discards_left)))
            MSP.inc('hands_unused', hands_left)
            MSP.inc('discards_unused', discards_left)

            -- Hands and discards reset per round, so "used this round" is the starting
            -- allowance less what is left standing.
            local sp = G.GAME.starting_params or {}
            local hands_used = math.max(0, MSP.num(G.GAME.round_resets and G.GAME.round_resets.hands or sp.hands) - hands_left)
            local disc_used = math.max(0, MSP.num(G.GAME.round_resets and G.GAME.round_resets.discards or sp.discards) - discards_left)
            if hands_used == 1 then MSP.inc('one_hand_rounds') end
            if disc_used == 0 then MSP.inc('no_discard_rounds') end

            -- How long each Joker was actually kept, which is the difference between one
            -- that got bought and one that earned its slot.
            if G.jokers and G.jokers.cards then
                for _, card in ipairs(G.jokers.cards) do
                    local k = card.config and card.config.center_key
                    if k and card.ability and card.ability.set == 'Joker' then
                        MSP.tally('jokers', k, 'rounds')
                    end
                end
            end
        end)()
        local ret = orig(...)
        safe(function() MSP.flush() end)()
        return ret
    end
end)

-- Cash-out rows are the game's own itemisation of a round's income - blind reward, interest,
-- unused hands, each paying Joker - so the breakdown is read from them rather than guessed.
local EARN_ROWS = {
    blind1 = 'earned_blinds', blind2 = 'earned_blinds', blind3 = 'earned_blinds',
    interest = 'earned_interest', hands = 'earned_hands', discards = 'earned_hands',
}
hook('round_eval_row', _G, 'add_round_eval_row', function(orig)
    return function(config, ...)
        safe(function()
            config = config or {}
            local d = MSP.num(config.dollars)
            if d <= 0 then return end
            local name = config.name
            local key = EARN_ROWS[name]
            if key then
                MSP.inc(key, d)
            elseif type(name) == 'string' and name:sub(1, 2) == 'j_' then
                MSP.inc('earned_jokers', d)
                MSP.tally('jokers', name, 'paid', d)
            elseif name ~= 'bottom' then
                MSP.inc('earned_other', d)
            end
            if config.name == 'interest' and G.GAME and G.GAME.interest_cap
               and d >= MSP.num(G.GAME.interest_cap) then
                MSP.inc('interest_caps')
            end
        end)()
        return orig(config, ...)
    end
end)

--============================================================
-- Money
--============================================================
-- Every dollar in or out of the run passes through here, which makes it the honest total to
-- weigh the itemised sources against.
hook('ease_dollars', _G, 'ease_dollars', function(orig)
    return function(mod, instant, ...)
        safe(function()
            local d = MSP.num(mod)
            if d > 0 then
                MSP.inc('earned_total', d)
                if money_source then MSP.tally('jokers', money_source, 'paid', d) end
            elseif d < 0 then
                MSP.inc('spent_total', -d)
            end
        end)()
        return orig(mod, instant, ...)
    end
end)

--============================================================
-- Shop
--============================================================
local SET_STAT = {
    Joker = 'jokers_bought', Tarot = 'tarots_bought', Planet = 'planets_bought',
    Spectral = 'spectrals_bought', Voucher = 'vouchers_bought', Booster = 'packs_bought',
}

hook('buy_from_shop', G.FUNCS, 'buy_from_shop', function(orig)
    return function(e, ...)
        safe(function()
            local card = e and e.config and e.config.ref_table
            if not card then return end
            local set = card.ability and card.ability.set
            local cost = MSP.num(card.cost)

            MSP.inc('cards_bought')
            local sk = SET_STAT[set]
            if sk then MSP.inc(sk) elseif set then MSP.inc('playing_bought') end

            if set == 'Voucher' then MSP.inc('spent_vouchers', cost)
            elseif set == 'Booster' then MSP.inc('spent_packs', cost)
            else MSP.inc('spent_cards', cost) end

            local key = card.config and card.config.center_key
            if set == 'Joker' and key then
                MSP.inc('jokers_gained')
                MSP.tally('jokers', key, 'bought')
                if card.config.center and card.config.center.rarity == 4 then
                    MSP.inc('legendaries_seen')
                end
            elseif set == 'Voucher' and key then
                MSP.tally('vouchers', key, 'redeemed')
            elseif set == 'Booster' and key then
                MSP.tally('packs', key, 'bought')
            end
            if edition_key(card) == 'negative' or (card.edition and card.edition.negative) then
                MSP.inc('negatives_seen')
            end
        end)()
        return orig(e, ...)
    end
end)

hook('reroll_shop', G.FUNCS, 'reroll_shop', function(orig)
    return function(...)
        safe(function()
            MSP.inc('rerolls')
            MSP.inc('spent_rerolls', MSP.num(G.GAME and G.GAME.current_round and G.GAME.current_round.reroll_cost))
        end)()
        return orig(...)
    end
end)

hook('sell_card', G.FUNCS, 'sell_card', function(orig)
    return function(e, ...)
        safe(function()
            local card = e and e.config and e.config.ref_table
            if not card then return end
            card.mstat_sold = true          -- read by the removal hook, which fires next
            local value = MSP.num(card.sell_cost)
            MSP.inc('earned_sales', value)
            if card.ability and card.ability.set == 'Joker' then
                MSP.inc('jokers_sold')
                local k = card.config and card.config.center_key
                if k then MSP.tally('jokers', k, 'sold') end
            else
                MSP.inc('cards_sold')
            end
        end)()
        return orig(e, ...)
    end
end)

--============================================================
-- Consumables and packs
--============================================================
hook('use_consumeable', Card, 'use_consumeable', function(orig)
    return function(self, area, copier)
        safe(function()
            if copier then return end        -- a copy is the same use, counted once
            MSP.inc('consumables_used')
            local set = self.ability and self.ability.set
            if set == 'Tarot' then MSP.inc('tarots_used')
            elseif set == 'Planet' then MSP.inc('planets_used')
            elseif set == 'Spectral' then MSP.inc('spectrals_used') end
            local k = self.config and self.config.center_key
            if k then MSP.tally('consumables', k, 'used') end
        end)()
        return orig(self, area, copier)
    end
end)

hook('open_pack', Card, 'open', function(orig)
    return function(self, ...)
        safe(function()
            MSP.inc('packs_opened')
            local k = self.config and self.config.center_key
            if k then MSP.tally('packs', k, 'opened') end
        end)()
        return orig(self, ...)
    end
end)

hook('skip_booster', G.FUNCS, 'skip_booster', function(orig)
    return function(...)
        safe(function() MSP.inc('packs_skipped') end)()
        return orig(...)
    end
end)

hook('level_up_hand', _G, 'level_up_hand', function(orig)
    return function(card, hand, instant, amount, ...)
        safe(function()
            MSP.inc('hands_leveled', math.max(1, MSP.num(amount, 1)))
            if hand then MSP.tally('hands', hand, 'levels', math.max(1, MSP.num(amount, 1))) end
        end)()
        return orig(card, hand, instant, amount, ...)
    end
end)

--============================================================
-- Deck changes
--============================================================
-- Cards entering and leaving the deck are counted from the size of G.playing_cards in the
-- sampler below, not from a hook. Card:add_to_deck is the Joker/Voucher "you now own this"
-- method and never sees a playing card, and the many paths that add or destroy one
-- (Spectrals, Death, Glass breaking, a blind eating a card) share no single seam. A size
-- delta catches every one of them and cannot count the opening deal.

-- A sold card is removed like any other. The seller marks it so the removal is not also
-- read as a destruction.
hook('card_remove', Card, 'remove', function(orig)
    return function(self, ...)
        safe(function()
            if self.mstat_sold then return end
            if self.ability and self.ability.set == 'Joker' then MSP.inc('jokers_destroyed') end
        end)()
        return orig(self, ...)
    end
end)

hook('set_edition', Card, 'set_edition', function(orig)
    return function(self, edition, immediate, silent, ...)
        safe(function()
            if edition then
                MSP.inc('editions_set')
                if type(edition) == 'table' and edition.negative then MSP.inc('negatives_seen') end
            end
        end)()
        return orig(self, edition, immediate, silent, ...)
    end
end)

hook('set_seal', Card, 'set_seal', function(orig)
    return function(self, seal, ...)
        safe(function() if seal then MSP.inc('seals_set') end end)()
        return orig(self, seal, ...)
    end
end)

hook('set_ability', Card, 'set_ability', function(orig)
    return function(self, center, initial, delay_sprites, ...)
        safe(function()
            -- Only a deliberate change of an existing playing card counts; the initial
            -- assignment every card gets at creation does not.
            if not initial and center and center.key and center.key ~= 'c_base'
               and center.set == 'Enhanced' and is_playing_card(self) then
                MSP.inc('enhancements_set')
            end
        end)()
        return orig(self, center, initial, delay_sprites, ...)
    end
end)

--============================================================
-- Joker scaling
--============================================================
-- "How big did Lucky Cat get" has no single field to read: the growing number lives in
-- ability.x_mult on one Joker, ability.mult on another, ability.extra.chips on a third, and
-- somewhere else entirely on a modded one.
--
-- So nothing is hardcoded. What makes a Joker a SCALING Joker is that a number on it moved
-- away from where it started, and where it started is the centre's own config - which is
-- static, always present, and survives a reload, unlike a baseline snapshotted per card.
-- Every numeric field that has grown past its centre default is recorded, which picks up
-- modded Jokers with no knowledge of them at all.

-- What "unchanged" means for a field the centre config does not declare: a multiplier that
-- is not there yet is 1, an additive bonus is 0.
local NEUTRAL = {
    x_mult = 1, Xmult = 1, xmult = 1, h_x_mult = 1, perma_x_mult = 1,
    mult = 0, chips = 0, dollars = 0, h_mult = 0, h_chips = 0,
    perma_mult = 0, perma_bonus = 0, h_size = 0, d_size = 0,
}

-- Flattens the numeric fields of an ability or config table. Big numbers are values, not
-- containers, so MSP.isnum is tested before the table branch - walking into one would treat
-- its internals as data.
local function scalars(t, prefix, out, depth)
    if type(t) ~= 'table' then return out end
    for k, v in pairs(t) do
        if type(k) == 'string' then
            if MSP.isnum(v) then
                out[prefix .. k] = v
            elseif depth > 0 and type(v) == 'table' then
                scalars(v, prefix .. k .. '.', out, depth - 1)
            end
        end
    end
    return out
end

local function leaf(field)
    return field:match('([^.]+)$') or field
end

-- Where a value sorts, on the same scale as MSP.mag's `log`. A plain number is ranked here
-- without building a magnitude: this runs for every numeric field of every Joker, four times
-- a second, and a magnitude formats a display string each time it is made.
local LOG10 = math.log10 or function(x) return math.log(x) / math.log(10) end
local function rank(v)
    if type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge then
        return (v > 0) and LOG10(v) or ((v == 0) and -1e300 or -1e299)
    end
    return MSP.mag(v).log
end

-- A centre's config is static, so its fields are flattened once. Weak keys: a centre or card
-- that goes away takes its entry with it.
local base_scalars = setmetatable({}, { __mode = 'k' })
local offered = setmetatable({}, { __mode = 'k' })      -- card -> field -> last value recorded
local offered_endless = nil
local now = {}

-- Records every field of one Joker that has grown past its starting value.
local function sample_joker_scale(card)
    local key = card.config and card.config.center_key
    local center = card.config and card.config.center
    if not (key and center) then return end

    for k in pairs(now) do now[k] = nil end
    scalars(card.ability, '', now, 1)
    local base = type(center.config) == 'table' and base_scalars[center.config]
    if not base then
        base = scalars(center.config, '', {}, 1)
        if type(center.config) == 'table' then base_scalars[center.config] = base end
    end

    -- A mark is kept per phase, so crossing into endless offers every value again.
    if offered_endless ~= MSP.endless then
        offered_endless = MSP.endless
        for c in pairs(offered) do offered[c] = nil end
    end
    local seen = offered[card]
    if not seen then
        seen = {}
        offered[card] = seen
    end

    for field, value in pairs(now) do
        local start = base[field]
        if start == nil then start = NEUTRAL[leaf(field)] end
        -- Only growth counts. A Joker that only ever ticks down (Ice Cream) peaks at its
        -- starting value, which says nothing about how the run went.
        if start ~= nil and rank(value) > rank(start) then
            -- A plain number already recorded at this value has nothing new to say.
            if type(value) ~= 'number' or seen[field] ~= value then
                seen[field] = value
                MSP.tally_best('joker_scale', MSP.matrix_key(key, field), value)
            end
        end
    end
end

-- Times a Joker actually did something. calculate_joker runs per Joker per scoring context,
-- so a Joker that fires on every scored card genuinely registers more triggers than one that
-- fires once a hand - which is the distinction worth having.
--
-- EVERY return value is passed back untouched. Vanilla sometimes returns `nil, true`
-- (card.lua:3900) and SMODS reads that second value as "triggered without an effect"; keeping
-- only the first would quietly change how the game resolves a hand. Varargs rather than a
-- table, because this is the hot path and a table would allocate on every call.
--
-- A copy is counted once, for the copier. When Brainstorm copies a Joker, SMODS runs the
-- copied Joker's calculation with context.blueprint_card set (utils.lua:2261) and Brainstorm's
-- own call then returns the same effect - so the inner call is skipped, or both would count.
local function after_calculate(self, copied, prev, ...)
    money_source = prev
    local effect, triggered = ...
    if (effect or triggered) and not copied then
        local k = joker_key(self)
        -- pcall on the function itself, not a closure: no allocation on the hot path.
        if k then pcall(MSP.tally, 'jokers', k, 'triggers') end
    end
    return ...
end

hook('calculate_joker', Card, 'calculate_joker', function(orig)
    return function(self, context, ...)
        local copied = context and context.blueprint_card
        local prev = money_source
        money_source = joker_key(copied) or joker_key(self)
        return after_calculate(self, copied, prev, orig(self, context, ...))
    end
end)

-- Money a Joker hands back as a returned {dollars = n} effect is paid here, after its own
-- calculation has already finished. Only a Joker source is credited: a Gold Seal pays through
-- the same function with a playing card as the source.
hook('joker_dollars', SMODS, 'calculate_individual_effect', function(orig)
    return function(effect, scored_card, key, amount, ...)
        if key ~= 'dollars' and key ~= 'p_dollars' and key ~= 'h_dollars' then
            return orig(effect, scored_card, key, amount, ...)
        end
        local prev = money_source
        money_source = joker_key(type(effect) == 'table' and effect.card) or joker_key(scored_card)
        local function done(...)
            money_source = prev
            return ...
        end
        return done(orig(effect, scored_card, key, amount, ...))
    end
end)

-- Rent on a Rental card, charged once per card at end of round (card.lua:2638). Read before
-- the original runs, at the rate actually in force - a challenge or mod can change it.
hook('rental', Card, 'calculate_rental', function(orig)
    return function(self, ...)
        safe(function()
            if self.ability and self.ability.rental then
                local rate = MSP.num(G.GAME and G.GAME.rental_rate)
                if rate > 0 then
                    MSP.inc('rent_paid', rate)
                    local k = self.config and self.config.center_key
                    if k then MSP.tally('jokers', k, 'rent', rate) end
                end
            end
        end)()
        return orig(self, ...)
    end
end)

--============================================================
-- Per-frame sampling
--============================================================
-- Some stats are states rather than events: how much money is on the table right now, how
-- deep the run has gone, how long it has been running. They are read once a frame, cheaply,
-- and only while a run is actually live.
local PLAY_STATES = nil
local function in_run()
    if not (G.GAME and G.STATE and G.STATES) then return false end
    if not PLAY_STATES then
        PLAY_STATES = {}
        for _, k in ipairs({ 'SELECTING_HAND', 'HAND_PLAYED', 'DRAW_TO_HAND', 'SHOP', 'BLIND_SELECT',
                            'ROUND_EVAL', 'TAROT_PACK', 'PLANET_PACK', 'SPECTRAL_PACK', 'STANDARD_PACK',
                            'BUFFOON_PACK', 'NEW_ROUND', 'PLAY_TAROT' }) do
            if G.STATES[k] then PLAY_STATES[G.STATES[k]] = true end
        end
    end
    return PLAY_STATES[G.STATE] == true
end

local sample_acc = 0
local was_broke, last_state, last_deck = false, nil, nil

-- Called when a run begins, so per-run baselines never leak across runs.
function MSP.reset_samplers()
    sample_acc, was_broke, last_state, last_deck = 0, false, nil, nil
end

local function sample(dt)
    local r = MSP.run()
    if not r then return end

    -- Refreshed every frame rather than on the 4Hz tick: the trigger hot path reads the
    -- cached flag, and a hand played in the moment an ante turns over should be filed under
    -- the phase it was actually played in.
    MSP.refresh_phase()

    -- Outcome, read from game state rather than from a win or lose function, so it holds
    -- however the run happens to end. finish_run is idempotent, which is what lets a won
    -- run carry on into endless without being counted a second time when it finally dies.
    if not r.finished then
        if G.GAME.won then
            MSP.finish_run('win')
        elseif G.STATE == G.STATES.GAME_OVER then
            local blind = G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind
            if blind and blind.key then MSP.tally('bosses', blind.key, 'lost_to') end
            MSP.finish_run('loss', { beaten_by = blind and blind.key })
        end
    end

    -- Deliberately NOT gated on r.finished: play past a win still accrues into the career
    -- totals, it just does not write a second run record.
    if not G.SETTINGS.paused then
        r.time = MSP.num(r.time) + MSP.num(dt)
        MSP.inc('playtime', MSP.num(dt))
    end

    -- Entering the shop, counted on the transition so a redraw cannot count it twice.
    if G.STATE ~= last_state then
        if G.STATE == G.STATES.SHOP then MSP.inc('shop_visits') end
        last_state = G.STATE
    end

    -- Deck size. The delta catches every path that adds or destroys a card, and starting
    -- the baseline from the first sample of a run keeps the opening deal out of it.
    if G.playing_cards then
        local n = #G.playing_cards
        if last_deck == nil then
            last_deck = n
        elseif n > last_deck then
            MSP.inc('cards_added', n - last_deck)
            last_deck = n
        elseif n < last_deck then
            MSP.inc('cards_destroyed', last_deck - n)
            last_deck = n
        end
    end

    -- Sampled four times a second: often enough to catch a peak, rare enough to cost
    -- nothing.
    sample_acc = sample_acc + MSP.num(dt)
    if sample_acc < 0.25 then return end
    sample_acc = 0

    if G.jokers and G.jokers.cards then
        for _, card in ipairs(G.jokers.cards) do
            if card.ability and card.ability.set == 'Joker' then sample_joker_scale(card) end
        end
    end

    local ctx = MSP.run_ctx()
    MSP.record('most_money', MSP.num(G.GAME.dollars), ctx)
    MSP.record('high_ante', MSP.num(G.GAME.round_resets and G.GAME.round_resets.ante), ctx)
    MSP.record('high_round', MSP.num(G.GAME.round), ctx)
    if G.jokers then MSP.record('most_jokers', #G.jokers.cards, ctx) end
    if G.playing_cards then MSP.record('biggest_deck', #G.playing_cards, ctx) end

    local broke = MSP.num(G.GAME.dollars) <= 0
    if broke and not was_broke then MSP.inc('times_broke') end
    was_broke = broke
end

-- Built once: this runs every frame, and a closure made per call is garbage per frame.
local sample_frame = safe(function(dt)
    if in_run() or G.STATE == G.STATES.GAME_OVER then sample(dt) end
end)

hook('update', Game, 'update', function(orig)
    return function(self, dt, ...)
        local ret = orig(self, dt, ...)
        sample_frame(dt)
        return ret
    end
end)

--============================================================
-- Ante progression
--============================================================
hook('ease_ante', _G, 'ease_ante', function(orig)
    return function(mod, ...)
        safe(function() if MSP.num(mod) > 0 then MSP.inc('antes', MSP.num(mod)) end end)()
        return orig(mod, ...)
    end
end)

--============================================================
-- Load report
--============================================================
do
    local ok_n, miss = MSP.hook_report()
    local msg = ('Moar Stats Please: %d hooks bound'):format(ok_n)
    if #miss > 0 then msg = msg .. (', %d missing: %s'):format(#miss, table.concat(miss, ', ')) end
    if sendInfoMessage then sendInfoMessage(msg, 'MoarVanillaPlease') else print(msg) end
end
