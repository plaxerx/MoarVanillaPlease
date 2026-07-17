-- Endless Engines - Jokers
-- All 18 Jokers, the shared atlas, and shared helpers.
-- Loads decks.lua at the end (deck + sleeve).
--
-- Everything is unlocked = true / discovered = true: modded content should be
-- available immediately, not gated behind vanilla-style discovery.

--============================================================
-- Atlas
--============================================================
SMODS.Atlas{
    key = 'eeng_jokers',
    path = 'eeng_jokers.png',
    px = 71,
    py = 95,
}

--============================================================
-- Tuning (all values live here)
--============================================================
EEng = EEng or {}

EEng.CFG = {
    ledger     = { step = 8, ratio_per_step = 0.20, max_hits = 20 },
    metronome  = { same = 2.0, diff_keep = 0.70 },
    archivist  = { ratio = 1.6 },
    kindling   = { ratio = 1.5 },
    reliquary  = { ratio = 1.08 },
    oracle     = { ratio = 1.5 },
    momentum   = { gain = 0.10, step = 0.05 },
    kaleido    = { base = 1, rounds_per = 3, max = 12 },
    overclock  = { steel = 1.5, glass = 1.5, gold = 3, step = 0.25, gold_step = 1 },
    abacus     = { base = 1.2, step = 0.10 },
    tessellate = { base = 1, rounds_per = 3, max = 12 },
    ensemble   = { antes_per_slot = 2, max_slots = 5 },
    fortune    = { gain = 0.08, seven = 2, poly = 2, proc_bonus = 2 },
    royal      = { gain = 1, max = 6 },
    patron     = { per_sale = 1, max = 5 },
    mistigri   = { xmult = 1.5, retrigger = 1, combo = 0.2, step = 0.1 },
    retail     = { rerolls = 3 },
    necro      = { max = 1 },
    misprint   = { min = 0.1, max = 10 },
}
local CFG = EEng.CFG

-- Jokers only appear in the pool once you're actually in Endless (past ante 8).
-- They are still fully unlocked and visible in the collection from the start.
EEng.ENDLESS_START = 8

--============================================================
-- Shared helpers (also used by decks.lua)
--============================================================
EEng.TB = to_big or function(x) return x end
function EEng.bmul(a, b) return EEng.TB(a) * EEng.TB(b) end

-- Endless doesn't start at ante 8, it starts after the WIN ante - and Diamond Stake
-- moves that to 10. Hardcoding 8 is what leaked the endless Jokers into antes 8/9/10 of
-- a Diamond run that hadn't been won yet.
function EEng.endless_start()
    return (G.GAME and G.GAME.win_ante) or EEng.ENDLESS_START
end

function EEng.endless_only(self)
    local ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    return ante > EEng.endless_start()
end

function EEng.endless_depth()
    local ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    return math.max(0, ante - EEng.endless_start())
end

function EEng.has_enh(c, key)
    if not c then return false end
    if SMODS and SMODS.has_enhancement then return SMODS.has_enhancement(c, key) end
    return c.ability and c.ability.name == (G.P_CENTERS[key] and G.P_CENTERS[key].name)
end

function EEng.is_enhanced(c)
    if not c then return false end
    if SMODS and SMODS.get_enhancements then
        local e = SMODS.get_enhancements(c)
        return e and next(e) ~= nil
    end
    return c.ability and c.ability.set == 'Enhanced'
end

-- 5-card Royal Flush entirely in Spades. Vanilla scores this as a Straight
-- Flush, so the cards are verified directly.
function EEng.is_royal_spades(hand)
    if not hand or #hand ~= 5 then return false end
    local need = { [10] = false, [11] = false, [12] = false, [13] = false, [14] = false }
    for _, c in ipairs(hand) do
        if not c:is_suit('Spades') then return false end
        local id = c:get_id()
        if need[id] == nil then return false end
        need[id] = true
    end
    for _, v in pairs(need) do if not v then return false end end
    return true
end

-- Logarithmic roll: uniform in log-space, so 0.1x and 10x are equally likely.
-- A linear roll over the same range would average ~5x and just be a free buff.
function EEng.log_roll(seed, min, max)
    local lmin, lmax = math.log(min), math.log(max)
    local poll = pseudorandom(seed) * (lmax - lmin) + lmin
    return math.exp(poll)
end

local function grow(card, factor, key)
    key = key or 'Xmult'
    card.ability.extra[key] = EEng.bmul(card.ability.extra[key], factor)
end

local function scaled_msg(card, key)
    key = key or 'Xmult'
    return { message = 'X' .. number_format(card.ability.extra[key]), colour = G.C.MULT, card = card }
end

local bmul, endless_only, has_enh = EEng.bmul, EEng.endless_only, EEng.has_enh

--============================================================
-- 1. Ledger (Uncommon) - economy
--============================================================
SMODS.Joker{
    key = 'ledger',
    atlas = 'eeng_jokers', pos = { x = 0, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, step = CFG.ledger.step, max_factor = 1 + CFG.ledger.ratio_per_step * CFG.ledger.max_hits } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Ledger',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'End of round, gains Mult',
            'scaling with {C:money}money{} held',
            '{C:inactive}(max {X:mult,C:white}X#2#{C:inactive} per round, per {C:money}$#3#{C:inactive})',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.max_factor, center.ability.extra.step } }
    end,
    calculate = function(self, card, context)
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            local dollars = math.max(0, (G.GAME.dollars or 0))
            local hits = math.min(CFG.ledger.max_hits, math.floor(dollars / CFG.ledger.step))
            if hits > 0 then
                grow(card, 1 + CFG.ledger.ratio_per_step * hits)
                return scaled_msg(card)
            end
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 2. Metronome (Uncommon) - one hand type
--============================================================
SMODS.Joker{
    key = 'metronome',
    atlas = 'eeng_jokers', pos = { x = 1, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, same = CFG.metronome.same, keep = CFG.metronome.diff_keep, last_hand = 'None' } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Metronome',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'Same hand as last played: {X:mult,C:white}X#2#{}',
            'Different hand: keeps {C:attention}#3#%{} of Mult',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.same, math.floor(center.ability.extra.keep * 100) } }
    end,
    calculate = function(self, card, context)
        if context.before and not context.blueprint and context.scoring_name then
            if card.ability.extra.last_hand == context.scoring_name then
                grow(card, card.ability.extra.same)
            else
                card.ability.extra.Xmult = bmul(card.ability.extra.Xmult, card.ability.extra.keep)
                if EEng.TB(card.ability.extra.Xmult) < EEng.TB(1) then card.ability.extra.Xmult = 1 end
            end
            card.ability.extra.last_hand = context.scoring_name
            return scaled_msg(card)
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
    add_to_deck = function(self, card, from_debuff)
        card.ability.extra.last_hand = G.GAME.last_hand_played or 'None'
    end,
}

--============================================================
-- 3. Archivist (Uncommon) - hand variety
--============================================================
SMODS.Joker{
    key = 'archivist',
    atlas = 'eeng_jokers', pos = { x = 2, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, ratio = CFG.archivist.ratio, seen = {} } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Archivist',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'First time each round you play a',
            '{C:attention}hand type{} not yet played this round:',
            'gains {X:mult,C:white}X#2#{} Mult',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.ratio } }
    end,
    calculate = function(self, card, context)
        if context.before and not context.blueprint and context.scoring_name then
            card.ability.extra.seen = card.ability.extra.seen or {}
            if not card.ability.extra.seen[context.scoring_name] then
                card.ability.extra.seen[context.scoring_name] = true
                grow(card, card.ability.extra.ratio)
                return scaled_msg(card)
            end
        end
        if context.end_of_round and not context.individual and not context.repetition then
            card.ability.extra.seen = {}
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 4. Kindling (Uncommon) - discards
--============================================================
SMODS.Joker{
    key = 'kindling',
    atlas = 'eeng_jokers', pos = { x = 3, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, ratio = CFG.kindling.ratio } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Kindling',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'Gains {X:mult,C:white}X#2#{} Mult',
            'each time you {C:red}discard{}',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.ratio } }
    end,
    calculate = function(self, card, context)
        if context.pre_discard and not context.hook and not context.blueprint then
            grow(card, card.ability.extra.ratio)
            return scaled_msg(card)
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 5. Reliquary (Rare) - enhanced cards
--============================================================
SMODS.Joker{
    key = 'reliquary',
    atlas = 'eeng_jokers', pos = { x = 4, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, ratio = CFG.reliquary.ratio } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Reliquary',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'Gains {X:mult,C:white}X#2#{} Mult for each',
            'scored {C:attention}enhanced{} card',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.ratio } }
    end,
    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play and not context.end_of_round
            and not context.blueprint and EEng.is_enhanced(context.other_card) then
            grow(card, card.ability.extra.ratio)
            return { card = card }
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 6. Oracle (Uncommon) - consumables
--============================================================
SMODS.Joker{
    key = 'oracle',
    atlas = 'eeng_jokers', pos = { x = 5, y = 0 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, ratio = CFG.oracle.ratio } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Oracle',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'Gains {X:mult,C:white}X#2#{} Mult each time',
            'a {C:attention}consumable{} is used',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.ratio } }
    end,
    calculate = function(self, card, context)
        if context.using_consumable and not context.blueprint then
            grow(card, card.ability.extra.ratio)
            return scaled_msg(card)
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 7. Momentum (Rare) - iterative xMult
--============================================================
SMODS.Joker{
    key = 'momentum',
    atlas = 'eeng_jokers', pos = { x = 6, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, gain = CFG.momentum.gain, step = CFG.momentum.step } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Momentum',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'Each hand: Mult {X:mult,C:white}X(1 + #2#%){}',
            'then that {C:attention}gain{} grows by {C:attention}+#3#%{}',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, math.floor(center.ability.extra.gain * 100), math.floor(center.ability.extra.step * 100) } }
    end,
    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            card.ability.extra.Xmult = bmul(card.ability.extra.Xmult, 1 + card.ability.extra.gain)
            card.ability.extra.gain = card.ability.extra.gain + card.ability.extra.step
            return scaled_msg(card)
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 8. Kaleidoscope (Rare) - retrigger editioned cards
--============================================================
SMODS.Joker{
    key = 'kaleidoscope',
    atlas = 'eeng_jokers', pos = { x = 7, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { retriggers = CFG.kaleido.base, rounds = 0, per = CFG.kaleido.rounds_per, max = CFG.kaleido.max } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Kaleidoscope',
        text = {
            'Retriggers each scored',
            '{C:attention}editioned{} card {C:attention}#1#{} times',
            '{C:inactive}(+1 every #2# rounds, max #3#)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.retriggers, center.ability.extra.per, center.ability.extra.max } }
    end,
    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play and not context.end_of_round
            and context.other_card and context.other_card.edition then
            return { repetitions = card.ability.extra.retriggers, message = localize('k_again_ex') }
        end
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            card.ability.extra.rounds = card.ability.extra.rounds + 1
            if card.ability.extra.rounds % card.ability.extra.per == 0 and card.ability.extra.retriggers < card.ability.extra.max then
                card.ability.extra.retriggers = card.ability.extra.retriggers + 1
                return { message = localize('k_upgrade_ex'), colour = G.C.EDITION, card = card }
            end
        end
    end,
}

--============================================================
-- 9. Overclock (Rare) - steel / glass / gold
--============================================================
SMODS.Joker{
    key = 'overclock',
    atlas = 'eeng_jokers', pos = { x = 8, y = 0 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = {
        steel_x = CFG.overclock.steel, glass_x = CFG.overclock.glass, gold_d = CFG.overclock.gold,
        step = CFG.overclock.step, gold_step = CFG.overclock.gold_step,
    } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Overclock',
        text = {
            'Held {C:attention}Steel{}: {X:mult,C:white}X#1#{} Mult each',
            'Scored {C:attention}Glass{}: {X:mult,C:white}X#2#{} Mult each',
            'End of round: {C:money}$#3#{} per held {C:attention}Gold{}',
            '{C:inactive}(all grow each round)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.steel_x, center.ability.extra.glass_x, center.ability.extra.gold_d } }
    end,
    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.hand and not context.end_of_round
            and not context.blueprint and has_enh(context.other_card, 'm_steel') then
            return { x_mult = card.ability.extra.steel_x, card = card }
        end
        if context.individual and context.cardarea == G.play and not context.end_of_round
            and not context.blueprint and has_enh(context.other_card, 'm_glass') then
            return { x_mult = card.ability.extra.glass_x, card = card }
        end
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            local gold = 0
            if G.hand and G.hand.cards then
                for _, c in ipairs(G.hand.cards) do
                    if has_enh(c, 'm_gold') then gold = gold + 1 end
                end
            end
            card.ability.extra.steel_x = card.ability.extra.steel_x + card.ability.extra.step
            card.ability.extra.glass_x = card.ability.extra.glass_x + card.ability.extra.step
            card.ability.extra.gold_d = card.ability.extra.gold_d + card.ability.extra.gold_step
            if gold > 0 then
                return { dollars = gold * card.ability.extra.gold_d, card = card }
            end
        end
    end,
}

--============================================================
-- 10. Abacus (Rare) - Baron for number cards
--============================================================
SMODS.Joker{
    key = 'abacus',
    atlas = 'eeng_jokers', pos = { x = 9, y = 0 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = CFG.abacus.base, step = CFG.abacus.step } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Abacus',
        text = {
            '{X:mult,C:white} X#1# {} Mult for each',
            '{C:attention}non-face{} card held in hand',
            '{C:inactive}(grows {X:mult,C:white}+#2#{C:inactive} each round)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.step } }
    end,
    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.hand and not context.end_of_round
            and not context.blueprint and context.other_card and not context.other_card:is_face() then
            return { x_mult = card.ability.extra.Xmult, card = card }
        end
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            card.ability.extra.Xmult = card.ability.extra.Xmult + card.ability.extra.step
            return { message = localize('k_upgrade_ex'), colour = G.C.MULT, card = card }
        end
    end,
}

--============================================================
-- 11. Tessellate (Uncommon) - retrigger non-face cards
--============================================================
SMODS.Joker{
    key = 'tessellate',
    atlas = 'eeng_jokers', pos = { x = 6, y = 1 },
    rarity = 2, cost = 7,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { retriggers = CFG.tessellate.base, rounds = 0, per = CFG.tessellate.rounds_per, max = CFG.tessellate.max } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Tessellate',
        text = {
            'Retriggers each scored',
            '{C:attention}non-face{} card {C:attention}#1#{} times',
            '{C:inactive}(+1 every #2# rounds, max #3#)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.retriggers, center.ability.extra.per, center.ability.extra.max } }
    end,
    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play and not context.end_of_round
            and context.other_card and not context.other_card:is_face() then
            return { repetitions = card.ability.extra.retriggers, message = localize('k_again_ex') }
        end
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            card.ability.extra.rounds = card.ability.extra.rounds + 1
            if card.ability.extra.rounds % card.ability.extra.per == 0 and card.ability.extra.retriggers < card.ability.extra.max then
                card.ability.extra.retriggers = card.ability.extra.retriggers + 1
                return { message = localize('k_upgrade_ex'), card = card }
            end
        end
    end,
}

--============================================================
-- 12. Ensemble (Rare) - Joker slots via Endless depth
--   Alternate slot path to Patron. Time-based rather than sacrifice-based.
--============================================================
SMODS.Joker{
    key = 'ensemble',
    atlas = 'eeng_jokers', pos = { x = 7, y = 1 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true, perishable_compat = false,
    config = { extra = { granted = 0, per = CFG.ensemble.antes_per_slot, max = CFG.ensemble.max_slots } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Ensemble',
        text = {
            '{C:attention}+1{} Joker slot for every',
            '{C:attention}#1#{} antes into Endless',
            '{C:inactive}(currently {C:attention}+#2#{C:inactive}, max #3#)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.per, center.ability.extra.granted, center.ability.extra.max } }
    end,
    calculate = function(self, card, context)
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            local target = math.min(card.ability.extra.max, math.floor(EEng.endless_depth() / card.ability.extra.per))
            local delta = target - card.ability.extra.granted
            if delta ~= 0 and G.jokers then
                G.jokers.config.card_limit = G.jokers.config.card_limit + delta
                card.ability.extra.granted = target
                if delta > 0 then
                    return { message = '+' .. delta .. ' Slot', colour = G.C.DARK_EDITION, card = card }
                end
            end
        end
    end,
    add_to_deck = function(self, card, from_debuff)
        if G.jokers then G.jokers.config.card_limit = G.jokers.config.card_limit + (card.ability.extra.granted or 0) end
    end,
    remove_from_deck = function(self, card, from_debuff)
        if G.jokers then G.jokers.config.card_limit = G.jokers.config.card_limit - (card.ability.extra.granted or 0) end
    end,
}

--============================================================
-- 13. Fortune (Rare) - Poly Lucky 7 engine
--============================================================
SMODS.Joker{
    key = 'fortune',
    atlas = 'eeng_jokers', pos = { x = 8, y = 1 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { Xmult = 1, gain = CFG.fortune.gain, seven = CFG.fortune.seven, poly = CFG.fortune.poly, proc = CFG.fortune.proc_bonus } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Fortune',
        text = {
            '{X:mult,C:white} X#1# {} Mult',
            'Each scored {C:attention}Lucky{} card gains {X:mult,C:white}X(1+#2#){}',
            '{C:attention}x#3#{} if a {C:attention}7{}, {C:attention}x#4#{} if {C:dark_edition}Polychrome{}',
            '{C:inactive}(x#5# more when Luck triggers)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.Xmult, center.ability.extra.gain, center.ability.extra.seven, center.ability.extra.poly, center.ability.extra.proc } }
    end,
    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play and not context.end_of_round
            and not context.blueprint and has_enh(context.other_card, 'm_lucky') then
            local inc = card.ability.extra.gain
            if context.other_card:get_id() == 7 then inc = inc * card.ability.extra.seven end
            if context.other_card.edition and context.other_card.edition.polychrome then inc = inc * card.ability.extra.poly end
            if context.other_card.lucky_trigger then inc = inc * card.ability.extra.proc end
            card.ability.extra.Xmult = bmul(card.ability.extra.Xmult, 1 + inc)
            return { card = card }
        end
        if context.joker_main then return { Xmult_mod = card.ability.extra.Xmult } end
    end,
}

--============================================================
-- 14. Royal (Rare) - Royal Flush of Spades quest
--============================================================
SMODS.Joker{
    key = 'royal',
    atlas = 'eeng_jokers', pos = { x = 9, y = 1 },
    rarity = 3, cost = 9,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { retriggers = 0, gain = CFG.royal.gain, max = CFG.royal.max } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Royal',
        text = {
            'Retriggers each scored card {C:attention}#1#{} times',
            'Play a {C:spades}Royal Flush of Spades{}:',
            'permanently {C:attention}+#2#{} retriggers',
            '{C:inactive}(max #3#)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.retriggers, center.ability.extra.gain, center.ability.extra.max } }
    end,
    calculate = function(self, card, context)
        if context.before and not context.blueprint and EEng.is_royal_spades(context.scoring_hand)
            and card.ability.extra.retriggers < card.ability.extra.max then
            card.ability.extra.retriggers = math.min(card.ability.extra.max, card.ability.extra.retriggers + card.ability.extra.gain)
            return { message = localize('k_upgrade_ex'), colour = G.C.SPADES, card = card }
        end
        if context.repetition and context.cardarea == G.play and not context.end_of_round
            and card.ability.extra.retriggers > 0 then
            return { repetitions = card.ability.extra.retriggers, message = localize('k_again_ex') }
        end
    end,
}

--============================================================
-- 15. Retail Explorer (Rare) - packs from rerolls
--   Counter is cumulative across the run: every Nth reroll spawns a pack.
--============================================================
SMODS.Joker{
    key = 'retail_explorer',
    atlas = 'eeng_jokers', pos = { x = 2, y = 1 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true, perishable_compat = true,
    config = { extra = { rerolls = 0, needed = CFG.retail.rerolls } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Retail Explorer',
        text = {
            'Every {C:attention}#1#{} shop {C:attention}rerolls{},',
            'adds a free {C:attention}Booster Pack{} to the shop',
            '{C:inactive}(#2#/#1#)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.needed, center.ability.extra.rerolls } }
    end,
    calculate = function(self, card, context)
        if context.reroll_shop and not context.blueprint then
            card.ability.extra.rerolls = card.ability.extra.rerolls + 1
            if card.ability.extra.rerolls >= card.ability.extra.needed then
                card.ability.extra.rerolls = 0
                G.E_MANAGER:add_event(Event({
                    func = function()
                        if SMODS.add_booster_to_shop then SMODS.add_booster_to_shop() end
                        return true
                    end
                }))
                return { message = 'Pack!', colour = G.C.SECONDARY_SET.Booster, card = card }
            end
            return { message = card.ability.extra.rerolls .. '/' .. card.ability.extra.needed, colour = G.C.BLUE, card = card }
        end
    end,
}

--============================================================
-- 16. Necromancer (Rare) - sacrifices itself to revive a perished Joker
--============================================================
SMODS.Joker{
    key = 'necromancer',
    atlas = 'eeng_jokers', pos = { x = 3, y = 1 },
    rarity = 3, cost = 8,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = false, perishable_compat = false,
    config = { extra = { revives = CFG.necro.max } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Necromancer',
        text = {
            'When {C:attention}sold{}, revives {C:attention}#1#{} {C:red}perished{} Joker',
            'Removes its {C:red}Perishable{} sticker',
            '{C:inactive}(destroys itself)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.revives } }
    end,
    calculate = function(self, card, context)
        if context.selling_self and not context.blueprint then
            local revived = 0
            for _, j in ipairs(G.jokers.cards) do
                if revived >= card.ability.extra.revives then break end
                if j ~= card and j.ability.perishable and (j.ability.perish_tally or 1) <= 0 then
                    j.ability.perishable = false
                    j.ability.perish_tally = nil
                    j.debuff = false
                    if SMODS.recalc_debuff then SMODS.recalc_debuff(j) end
                    j:juice_up(0.5, 0.5)
                    revived = revived + 1
                end
            end
            if revived > 0 then
                return { message = 'Revived!', colour = G.C.PURPLE, card = card }
            end
            return { message = 'No dead!', colour = G.C.GREY, card = card }
        end
    end,
}

--============================================================
-- 17. Patron (Legendary) - sell a Legendary for a Joker slot
--============================================================
SMODS.Joker{
    key = 'patron',
    atlas = 'eeng_jokers', pos = { x = 0, y = 1 },
    rarity = 4, cost = 10,
    unlocked = true, discovered = true,
    blueprint_compat = false, eternal_compat = true, perishable_compat = false,
    config = { extra = { granted = 0, per_sale = CFG.patron.per_sale, max = CFG.patron.max } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Patron',
        text = {
            'Sell a {C:legendary,E:1}Legendary{} Joker:',
            'permanently {C:attention}+#1#{} Joker slot',
            '{C:inactive}(currently {C:attention}+#2#{C:inactive}, max #3#)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.per_sale, center.ability.extra.granted, center.ability.extra.max } }
    end,
    calculate = function(self, card, context)
        if context.selling_card and not context.selling_self and not context.blueprint
            and context.card and context.card.ability and context.card.ability.set == 'Joker' then
            local rar = context.card.config and context.card.config.center and context.card.config.center.rarity
            if (rar == 4 or rar == 'Legendary') and card.ability.extra.granted < card.ability.extra.max then
                local add = math.min(card.ability.extra.per_sale, card.ability.extra.max - card.ability.extra.granted)
                card.ability.extra.granted = card.ability.extra.granted + add
                if G.jokers then G.jokers.config.card_limit = G.jokers.config.card_limit + add end
                return { message = '+' .. add .. ' Slot', colour = G.C.DARK_EDITION, card = card }
            end
        end
    end,
    add_to_deck = function(self, card, from_debuff)
        if G.jokers then G.jokers.config.card_limit = G.jokers.config.card_limit + (card.ability.extra.granted or 0) end
    end,
    remove_from_deck = function(self, card, from_debuff)
        if G.jokers then G.jokers.config.card_limit = G.jokers.config.card_limit - (card.ability.extra.granted or 0) end
    end,
}

--============================================================
-- 18. Mistigri (Legendary) - Aces & Jacks
--   Counterpart to Triboulet (Kings & Queens). Named for the old card game and
--   the Jack of Clubs. An Ace + Jack in one hand is the "blackjack" bonus.
--============================================================
SMODS.Joker{
    key = 'mistigri',
    atlas = 'eeng_jokers', pos = { x = 1, y = 1 },
    rarity = 4, cost = 10,
    unlocked = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, perishable_compat = false,
    config = { extra = { xmult = CFG.mistigri.xmult, retrigger = CFG.mistigri.retrigger, combo = CFG.mistigri.combo, step = CFG.mistigri.step } },
    in_pool = endless_only,
    loc_txt = {
        name = 'Mistigri',
        text = {
            'Scored {C:attention}Aces{} and {C:attention}Jacks{} give {X:mult,C:white}X#1#{} Mult',
            'and are {C:attention}retriggered{} #2# time(s)',
            'A hand with both: permanent {X:mult,C:white}+#3#{} Mult',
            '{C:inactive}(+#4# each round)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.extra.xmult, center.ability.extra.retrigger, center.ability.extra.combo, center.ability.extra.step } }
    end,
    calculate = function(self, card, context)
        if context.repetition and context.cardarea == G.play and not context.end_of_round and context.other_card then
            local id = context.other_card:get_id()
            if id == 14 or id == 11 then
                return { repetitions = card.ability.extra.retrigger, message = localize('k_again_ex') }
            end
        end
        if context.individual and context.cardarea == G.play and not context.end_of_round
            and not context.blueprint and context.other_card then
            local id = context.other_card:get_id()
            if id == 14 or id == 11 then
                return { x_mult = card.ability.extra.xmult, card = card }
            end
        end
        if context.before and not context.blueprint and context.scoring_hand then
            local hasA, hasJ = false, false
            for _, c in ipairs(context.scoring_hand) do
                local id = c:get_id()
                if id == 14 then hasA = true elseif id == 11 then hasJ = true end
            end
            if hasA and hasJ then
                card.ability.extra.xmult = card.ability.extra.xmult + card.ability.extra.combo
                return { message = localize('k_upgrade_ex'), colour = G.C.RED, card = card }
            end
        end
        if context.end_of_round and not context.individual and not context.repetition and not context.blueprint then
            card.ability.extra.xmult = card.ability.extra.xmult + card.ability.extra.step
        end
    end,
}

--============================================================
-- Load the deck + sleeve
--============================================================
assert(SMODS.load_file('decks.lua'))()
assert(SMODS.load_file('stakes.lua'))()
assert(SMODS.load_file('roguelike.lua'))()
