-- Endless Engines - Decks
-- The FLUX deck + FLUX sleeve.
--
-- Renamed from "Misprint": the theme outgrew the name. A misprint is an error on
-- a single card. This deck randomizes every number the game runs on - joker
-- values, card chips, poker hands, shop prices, reroll costs, pack sizes,
-- consumables. That isn't a misprint, it's instability. Flux.
--
-- Original implementation, not copied from Cryptid (GPL, and copying would drag
-- in a hard dependency). The one idea borrowed is the LOGARITHMIC roll: sampling
-- uniformly in log-space makes a 5x buff and a 5x nerf equally likely. A linear
-- roll over 0.1-10 would average ~5x and just be free power.

local CFG = EEng.CFG

--============================================================
-- Roll helpers
--============================================================

-- Never rolled: counters, IDs, structural values.
EEng.flux_blacklist = {
    id = true, qty = true, card_limit = true, extra_slots_used = true,
    perish_tally = true, times_played = true, extra_slots_used = true,
    suit_nominal = true, base_nominal = true, face_nominal = true, nominal = true,
    colour = true, immutable = true,
    -- our own bookkeeping; rolling these would break the jokers
    rounds = true, granted = true, per = true, max = true, seen = true,
    last_hand = true, rerolls = true, needed = true, retrigger = true,
    revives = true, per_sale = true,
    -- Talisman big-number internals (belt and braces)
    sign = true, array = true, scale = true, mantissa = true, exponent = true,
    layer = true, m = true, e = true,
}

-- CRITICAL (Talisman): a "number" may be a plain Lua number OR a Talisman big
-- number, which is a TABLE ({sign=, array=, scale=}). is_number() is true for both.
-- This MUST be tested before any type(v)=='table' branch, or a big number looks
-- like a plain container, we recurse into it, and we randomize its internal
-- sign/scale fields - producing a corrupt big number that later crashes with
-- "attempt to compare table with number".
function EEng.isnum(v)
    if is_number then return is_number(v) end
    return type(v) == 'number'
end

function EEng.plain(v)
    if type(v) == 'number' then return v end
    if to_number then
        local n = to_number(v)
        if type(n) == 'number' then return n end
    end
    return nil
end

local function is_int(x)
    return type(x) == 'number' and x == math.floor(x)
end

function EEng.flux_active()
    return G.GAME and G.GAME.modifiers and G.GAME.modifiers.eeng_flux_min ~= nil
end

local function bounds()
    return (G.GAME.modifiers.eeng_flux_min or 1), (G.GAME.modifiers.eeng_flux_max or 1)
end

-- Roll one value.
-- INTEGER PRESERVATION: if the original was a whole number, the result is a whole
-- number (min 1). That is what keeps hand size, discards, hands and "select N
-- cards" sane on Tarots/Planets/Vouchers - they are all integers, so they can
-- never come back as 2.7.
-- A card caches ONE factor per key.
--
-- This is not an optimization, it is a correctness fix. Consumables store some
-- values TWICE: The Star has both ability.max_highlighted and a nested copy at
-- ability.consumeable.max_highlighted. fluxize() walks the top level AND one level
-- into tables, so it used to draw a FRESH random number for each - the tooltip read
-- one roll (5) and can_use() read the other (2). Same key => same factor => the two
-- copies now always agree.
function EEng.factor_for(card, key)
    card.eeng_factors = card.eeng_factors or {}
    if not card.eeng_factors[key] then
        local mn, mx = bounds()
        card.eeng_factors[key] = EEng.log_roll('eeng_flux', mn, mx)
    end
    return card.eeng_factors[key]
end

-- Roll one value.
-- INTEGER PRESERVATION: if the original was a whole number, the result is a whole
-- number (min 1). That keeps hand size, discards, hands and "select N cards" sane
-- on Tarots/Planets/Vouchers - they are all integers, so they can never come back
-- as 2.7.
-- MULTIPLICATIVE keys are inert at 1; ADDITIVE keys are inert at 0. Rolling an
-- inert value turns nothing into something.
-- This caused the "random x5/x6/x7 chips with no jokers" bug: SMODS gives EVERY
-- card h_x_chips = 1 and x_chips = 1 by default (overrides.lua:2782-2783). The old
-- guard only covered x_mult/Xmult/x_chips, so h_x_chips = 1 got rolled to 5, 6, 7 -
-- every card in hand silently became an xChips multiplier.
-- Probability denominators. A wide roll here is not spicy, it's a coin flip on whether a
-- card exists at all - Wheel of Fortune at 1-in-1 is not a misprint, it's a different game.
EEng.odds_keys = { odds = true, odds2 = true }

-- Money. Same reasoning: 0.1x-10x on a payout is an economy, not a variance.
EEng.money_keys = {
    dollars = true, p_dollars = true, h_dollars = true, money = true,
    dollar_mod = true, extra_value = true,
}

EEng.mult_keys = {
    x_mult = true, Xmult = true, x_chips = true,
    h_x_mult = true, h_x_chips = true,
    x_score = true, h_x_score = true,
    x_blind_size = true, h_x_blind_size = true,
    perma_x_mult = true, perma_x_chips = true,
    perma_h_x_mult = true, perma_h_x_chips = true,
}

-- A value is INERT when rolling it would conjure something from nothing.
-- Zero is inert for EVERY key, including multiplicative ones. SMODS hands every card
-- h_x_mult = 0 by default (overrides.lua:2775) - and the multiplicative floor of 1.1 was
-- turning that 0 into 1.1, so every card in hand quietly became an x1.1 held-in-hand
-- multiplier. Hence "random held in hand procs" the moment a Flux run started.
function EEng.is_inert(v, key)
    local n = EEng.plain(v)
    if n == nil then return true end
    if n == 0 then return true end                       -- nothing to scale
    if EEng.mult_keys[key] and n == 1 then return true end  -- x1 does nothing
    return false
end

function EEng.inert(key)
    return EEng.mult_keys[key] and 1 or 0
end

function EEng.roll_value(v, key, factor)
    if not EEng.isnum(v) then return v end
    if EEng.flux_blacklist[key] then return v end
    if EEng.is_inert(v, key) then return v end
    local mn, mx = bounds()
    if mn == mx then return v end

    factor = factor or EEng.log_roll('eeng_flux', mn, mx)

    -- Odds and money get a TIGHT band (0.5x-2x). A wide roll on a probability denominator
    -- isn't spicy - Wheel of Fortune at 1-in-1 is a different game. And 0.1x-10x on a payout
    -- is an economy, not variance.
    if EEng.odds_keys[key] or EEng.money_keys[key] then
        factor = math.max(0.5, math.min(2, factor))
    end

    if type(v) == 'number' then
        local r = v * factor
        -- Multipliers get ONE decimal place and a floor of 1.1. x1.3 and x1.7 are
        -- interesting; x0.5 is just a penalty nobody would ever keep on the board.
        -- (This is also what left a Steel card sitting there with a negative value
        -- that never procced.)
        if EEng.mult_keys[key] then
            r = math.floor(r * 10 + 0.5) / 10
            return math.max(1.1, r)
        end
        if is_int(v) then
            r = math.floor(r + 0.5)              -- round, don't floor
            if v >= 1 and r < 1 then r = 1 end   -- never collapse a count to 0
            return r
        end
        return tonumber(string.format('%.2g', r)) or v
    end
    -- big number: multiply whole, never touch internals, never string.format a table
    return v * factor
end

--============================================================
-- Card values
--============================================================

-- Death is excluded on purpose: it copies a card, and rolling that count to 3+
-- is degenerate.
local FLUX_SETS = { Joker = true, Tarot = true, Planet = true, Spectral = true, Voucher = true }

-- SPECTRALS ROLL ADDITIVELY, not multiplicatively.
-- Incantation destroys a card to make 4 Enhanced cards. A 10x roll asks for 40 - and
-- the game caps the creation long before that, so the "misprint" silently evaporates
-- and you just get the cap. Multiplying a small count is meaningless when the ceiling
-- is close; a +/- swing around the base value is the roll that actually lands.
local SPECTRAL_DELTA_MIN, SPECTRAL_DELTA_MAX = -2, 3

-- Anything that picks cards out of your hand is bounded by the hand-selection limit.
-- A Tarot claiming to convert 9 cards to Diamonds is a lie: you can only ever highlight
-- 5. Cap it at the truth.
local SELECT_CAP = 5

-- Keys that COUNT CARDS. Every one of these is bounded by reality: you can highlight at
-- most 5, you can't discard 9 cards you don't have, and a retrigger that fires 10 times
-- isn't a misprint, it's a different joker. Cap them all at 5, floor at 1.
local COUNT_KEYS = {
    max_highlighted = true,   -- Tarot selection
    faces = true,             -- Faceless Joker's discard requirement
    repetitions = true,       -- retrigger counts (Hanging Chad, Mime, Sock and Buskin...)
    retriggers = true,
    d_remaining = true,
}

-- Per-card roll bands. The global 0.1x-10x is right for a raw xMult, but wrong for a
-- joker whose whole identity is a small integer or a payout that snowballs.
local CARD_CAPS = {
    j_hanging_chad = { min = 1,   max = 5,  int = true },  -- retrigger count
    j_hermit       = { min = 0.5, max = 3 },               -- money doubler
    j_temperance   = { min = 0.5, max = 3 },               -- sell-value payout
    j_faceless     = { min = 1,   max = 5,  int = true },
    j_mime         = { min = 1,   max = 5,  int = true },
    j_sock_and_buskin = { min = 1, max = 5, int = true },
    j_dusk         = { min = 1,   max = 5,  int = true },
    j_seltzer      = { min = 1,   max = 5,  int = true },
    -- Vouchers that add SLOTS. A small chance at +2 or +3, never more.
    v_overstock_norm = { min = 1, max = 3, int = true },
    v_overstock_plus = { min = 1, max = 3, int = true },
    v_grabber        = { min = 1, max = 3, int = true },
    v_nacho_tong     = { min = 1, max = 3, int = true },
    v_wasteful       = { min = 1, max = 3, int = true },
    v_recyclomancy   = { min = 1, max = 3, int = true },
    v_paint_brush    = { min = 1, max = 3, int = true },
    v_palette        = { min = 1, max = 3, int = true },
}

-- Cards whose payout SNOWBALLS with a multiplier. Mail-In Rebate pays per matching
-- discarded card, so a 10x roll on its $5 is a money printer. These roll additively - a
-- +/- swing instead of a ratio. (It's also less code than special-casing the payout.)
local ADDITIVE_CARDS = {
    j_mail = true, j_faceless = true, j_todo_list = true, j_delayed_grat = true,
}
local FLUX_SKIP = { c_death = true }   -- Death copies a card; rolling that to 3+ is degenerate

-- Playing cards (set 'Default'/'Enhanced') only roll their ENHANCEMENT payouts.
-- A whitelist, not a blacklist: a playing card's ability table is full of things
-- that must not move (perma_* bookkeeping, seals, debuff state).
local ENH_SETS = { Default = true, Enhanced = true }

-- Playing-card enhancements are rolled as a PERMA BONUS, not by overwriting the
-- base value. Two reasons:
--   1) The enhancement's tooltip (+30 Chips etc.) is generated from the enhancement
--      CENTER, not from this card, so overwriting ability.bonus changed the effect
--      but never the text. Perma bonuses ARE rendered on the card
--      (SMODS.localize_perma_bonuses), so the number you see is the number you get.
--   2) The base value stays vanilla, so nothing downstream that reads it breaks.
-- ENHANCEMENTS ARE ROLLED DIRECTLY ON THE ABILITY.
--
-- The previous version wrote the delta into a perma_* bonus. Three things went wrong:
--   1) The card showed TWO lines - "+4 Mult" and a separate "+3 Mult" - instead of one
--      combined number, because perma bonuses render as their own entry.
--   2) perma_x_mult fires as a SEPARATE multiplier, so Steel procced x1.5 then x0.5.
--   3) Worst: perma bonuses SURVIVED an enhancement change. Turn a Mult card into a
--      plain card and it kept the perma - which is where a bare 7 of Clubs handing you
--      +2 Mult in hand came from.
-- Writing the ability directly fixes all three. The tooltips are corrected below by
-- taking ownership of each enhancement's loc_vars so they read this card's real values.
local ENH_KEYS = {
    bonus = true, mult = true,
    h_mult = true, h_chips = true,
    p_dollars = true, h_dollars = true,
    x_mult = true, h_x_mult = true, x_chips = true, h_x_chips = true,
}

local function flux_enhancement(card)
    for k, _ in pairs(ENH_KEYS) do
        local base = card.ability[k]
        if EEng.isnum(base) then
            local b = EEng.plain(base) or 0
            if not EEng.is_inert(base, k) then   -- only roll what this enhancement grants
                local rolled = EEng.plain(EEng.roll_value(base, k, EEng.factor_for(card, k))) or b
                if EEng.mult_keys[k] then
                    card.ability[k] = math.max(1.1, math.min(3.0, rolled))
                else
                    card.ability[k] = math.max(1, math.floor(rolled + 0.5))
                end
            end
        end
    end
    -- Lucky and Glass also roll their ODDS, not just their payouts. The gamble is the
    -- point of those cards; a Lucky card that pays differently but hits at exactly the
    -- vanilla rate isn't really misprinted.
    -- Odds live in different places depending on the enhancement (ability.odds for some,
    -- ability.extra.odds for others), so roll BOTH. Only checking .extra is why Lucky odds
    -- never moved. A LOW denominator is a good roll: 1-in-2 for the money is the dream.
    local ck = card.config and card.config.center_key
    if ck == 'm_lucky' or ck == 'm_glass' then
        local function roll_odds(tbl, k)
            -- ability.extra is a NUMBER on some enhancements (Glass: extra = 4), not a table.
            -- Indexing it is what crashed. Only walk real tables.
            if type(tbl) ~= 'table' then return end
            if not EEng.isnum(tbl[k]) then return end
            local b = EEng.plain(tbl[k]) or 5
            local f = EEng.log_roll('eeng_odds', 0.5, 2)   -- Wheel of Fortune got silly wider than this
            tbl[k] = math.max(2, math.min(20, math.floor(b * f + 0.5)))
        end
        for _, k in ipairs({ 'odds', 'odds2' }) do
            roll_odds(card.ability, k)
            roll_odds(card.ability.extra, k)
        end
    end
end

-- Keys that may only ever go UP. A -1 hand size Joker is a Joker nobody takes, so
-- rolling one is just wasted content. These roll upward only, and the card's price
-- scales with how much stronger the roll made it (see Card:set_cost).
local BUFF_ONLY = { h_size = true, d_size = true }

-- These vouchers set the SHOP RATE for Tarots/Planets. They're the exception to the
-- buff-only rule on vouchers: a Tarot Merchant that rolled to 0.2x and all but wipes
-- Tarots out of the shop is a genuinely interesting problem to play around, not a
-- dead card. Rolled to one decimal, floored at 0.1.
local RATE_VOUCHERS = {
    v_tarot_merchant = true, v_tarot_tycoon = true,
    v_planet_merchant = true, v_planet_tycoon = true,
}

-- Vouchers are a LOTTERY, not a smooth roll. Half the time you get exactly what the card
-- says. The rest is a discrete jackpot table - and yes, one slot in six is a DOWNGRADE, so
-- a +0 Antimatter is a real (and memorable) outcome.
--   3/6 base | 1/6 +1 | 1/6 +2 | 1/6 -1
local VOUCHER_POOL = { 0, 0, 0, 1, 2, -1 }

local function flux_buff_only(card, k, v)
    local b = EEng.plain(v) or 0
    if b <= 0 then return v end
    card.eeng_deltas = card.eeng_deltas or {}
    if card.eeng_deltas['bo_' .. k] == nil then
        card.eeng_deltas['bo_' .. k] = VOUCHER_POOL[pseudorandom('eeng_voucher', 1, #VOUCHER_POOL)]
    end
    local rolled = math.max(0, math.floor(b + 0.5) + card.eeng_deltas['bo_' .. k])
    card.eeng_power = math.max(card.eeng_power or 1, (rolled > 0 and rolled or 1) / b)
    return rolled
end

-- Scaling Jokers (Constellation, Hologram, Vampire, Campfire...) all START at x1, which is
-- inert - so their base never rolled and only the GAIN did. Give the base a real starting
-- value too, and lean it AGAINST the gain: a strong opening usually means it climbs slowly,
-- a feeble opening usually means it climbs hard. One time in four it doesn't lean at all,
-- which is where the legendary pulls (and the trash) come from.
local SCALE_BASE_KEYS = { 'x_mult', 'Xmult', 'xmult' }
local GAIN_KEYS = { 'Xmult_mod', 'x_mult_mod', 'xmult_gain', 'extra', 'mult_mod', 'chip_mod' }

local function flux_scaling_base(card)
    local a = card.ability
    local tbl = (type(a.extra) == 'table') and a.extra or a
    local basek
    for _, k in ipairs(SCALE_BASE_KEYS) do
        if EEng.plain(tbl[k]) == 1 then basek = k break end
    end
    if not basek then return end

    -- Full 0.1x-10x on the base, because the GAIN leans inverse to it: a monstrous opening
    -- almost always crawls, a pathetic opening almost always rockets. The 1-in-4 that
    -- doesn't lean is where both the legendary pull and the total trash come from.
    local mn, mx = bounds()
    local bf = EEng.log_roll('eeng_scale_base', mn, mx)
    tbl[basek] = math.max(1.1, math.floor(bf * 10 + 0.5) / 10)

    local lean = (pseudorandom('eeng_scale_lean') < 0.75) and (1 / bf) or bf
    card.eeng_factors = card.eeng_factors or {}
    for _, gk in ipairs(GAIN_KEYS) do
        if card.eeng_factors[gk] == nil then
            card.eeng_factors[gk] = math.max(0.1, math.min(10, lean))
        end
    end
end

function EEng.fluxize(card)
    if not card or not card.ability then return end
    if not EEng.flux_active() then return end
    if card.eeng_fluxed then return end

    local set = card.ability.set
    local enh = ENH_SETS[set]
    if not FLUX_SETS[set] and not enh then return end

    local ck = card.config and card.config.center_key
    if ck and FLUX_SKIP[ck] then card.eeng_fluxed = true return end

    if enh then
        flux_enhancement(card)
        card.eeng_fluxed = true
        return
    end

    -- Vouchers only ever buff you, so every number on one is buff-only. That's what
    -- makes a $6 Wasteful granting +2 discards possible but rare: the roll can't nerf
    -- it, so the price carries the balance instead.
    local ck2 = card.config and card.config.center_key
    local voucher = (set == 'Voucher') and not (ck2 and RATE_VOUCHERS[ck2])
    if set == 'Joker' then flux_scaling_base(card) end

    local spectral = (set == 'Spectral')

    -- A 2-card Tarot rolling down to 1 is a strict downgrade and it was landing far too
    -- often. Bias hard toward the vanilla count, and make +1 twice as likely as -1.
    local SELECT_POOL = { 0, 0, 0, 0, 1, 1, -1 }

    -- Cache the delta per card+key. max_highlighted lives in TWO places on a consumable
    -- (ability.max_highlighted and ability.consumeable.max_highlighted); drawing a fresh
    -- random for each meant the tooltip and can_use() disagreed - "says 2, lets me pick 1".
    card.eeng_deltas = card.eeng_deltas or {}
    local function delta_for(k)
        if card.eeng_deltas[k] == nil then
            card.eeng_deltas[k] = SELECT_POOL[pseudorandom('eeng_count', 1, #SELECT_POOL)]
        end
        return card.eeng_deltas[k]
    end

    local function roll_one(k, v)
        if COUNT_KEYS[k] then
            local b = EEng.plain(v) or 1
            return math.max(1, math.min(SELECT_CAP, math.floor(b + 0.5) + delta_for(k)))
        end
        local pv = EEng.plain(v)
        if spectral and is_int(pv or 0) then
            local b = pv or 0
            if b <= 0 then return v end
            local d = pseudorandom('eeng_spectral', SPECTRAL_DELTA_MIN, SPECTRAL_DELTA_MAX)
            return math.max(1, b + d)                      -- additive, floor 1
        end
        if ck2 and ADDITIVE_CARDS[ck2] and pv and is_int(pv) and pv > 0 and not EEng.mult_keys[k] then
            if card.eeng_deltas[k] == nil then
                card.eeng_deltas[k] = pseudorandom('eeng_add', -2, 3)
            end
            return math.max(1, pv + card.eeng_deltas[k])
        end
        -- Small whole numbers (gain-per-trigger counters like Canio's) roll additively.
        if pv and is_int(pv) and pv >= 1 and pv <= 3 and not EEng.mult_keys[k] then
            if card.eeng_deltas[k] == nil then
                card.eeng_deltas[k] = pseudorandom('eeng_small', -1, 2)
            end
            return math.max(1, pv + card.eeng_deltas[k])
        end
        if BUFF_ONLY[k] or voucher then
            return flux_buff_only(card, k, v)
        end
        return EEng.roll_value(v, k, EEng.factor_for(card, k))
    end

    local caps = ck2 and CARD_CAPS[ck2]

    local function clamp(k, v)
        -- Blacklisted keys are bookkeeping and must never be touched - not even by a cap.
        -- CARD_CAPS was applied to EVERY key, so Hanging Chad's {min=1} was quietly forcing
        -- ability.card_limit from 0 to 1. That is the phantom "Slots Used / Card Limit".
        if EEng.flux_blacklist[k] then return v end
        local n = EEng.plain(v)
        if not n then return v end
        if COUNT_KEYS[k] then
            return math.max(1, math.min(SELECT_CAP, math.floor(n + 0.5)))
        end
        if caps then
            n = math.max(caps.min, math.min(caps.max, n))
            if caps.int then n = math.max(1, math.floor(n + 0.5)) end
            return n
        end
        return v
    end

    for k, v in pairs(card.ability) do
        if EEng.isnum(v) then
            card.ability[k] = clamp(k, roll_one(k, v))
        elseif type(v) == 'table' and not EEng.flux_blacklist[k] then
            for _k, _v in pairs(v) do
                if EEng.isnum(_v) then v[_k] = clamp(_k, roll_one(_k, _v)) end
            end
        end
    end
    card.eeng_fluxed = true
end


local eeng_set_ability = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
    -- Changing enhancement must DISCARD the previous roll. Carrying it over is how a
    -- plain card ended up holding a Mult card's leftover randomness.
    local key = center and (center.key or center)
    if self.eeng_center_key and self.eeng_center_key ~= key then
        self.eeng_factors = nil
        self.eeng_fluxed = nil
    end
    self.eeng_center_key = key

    eeng_set_ability(self, center, initial, delay_sprites)
    if not EEng.flux_active() then return end

    self.eeng_fluxed = nil
    EEng.fluxize(self)

    -- Booster packs: size -2/+3, choices -1/+1 (floor 1, choices <= size).
    if self.ability and self.ability.set == 'Booster' and not self.eeng_pack_rolled then
        local size = EEng.plain(self.ability.extra) or 4
        local choose = EEng.plain(self.ability.choose) or 1
        size = math.max(1, size + pseudorandom('eeng_pack_size', -2, 3))
        choose = math.max(1, math.min(size, choose + pseudorandom('eeng_pack_choose', -1, 1)))
        self.ability.extra = size
        self.ability.choose = choose
        self.eeng_pack_rolled = true
    end
end

-- Playing cards get random chip values. base.nominal IS the card's chips.
-- Kept a plain integer: Talisman deliberately excludes nominal from big numbers.
local eeng_set_base = Card.set_base
function Card:set_base(card, initial)
    eeng_set_base(self, card, initial)
    if not EEng.flux_active() then return end
    if self.base and type(self.base.nominal) == 'number' then
        local mn, mx = bounds()
        local n = math.floor(self.base.nominal * EEng.log_roll('eeng_flux_card', mn, mx) + 0.5)
        self.base.nominal = math.max(1, n)
    end
end

-- ENHANCEMENT TOOLTIPS: nothing to do here.
--
-- There WAS a block here taking ownership of every enhancement's loc_vars to make the
-- tooltip read this card's rolled numbers. It was wrong twice over:
--   1) It ran on EVERY deck, not just Flux - so a vanilla or Prismatic run got my guessed
--      variable order too. That is what blanked the Bonus tooltip, dropped the "+" off
--      Empress's Mult, and mangled Lucky.
--   2) It was unnecessary. Balatro's enhancement descriptions already read card.ability,
--      and we now roll card.ability DIRECTLY (not into perma_*), so the tooltips update on
--      their own. Cryptid's misprintize relies on exactly this and doesn't touch loc_vars.

--============================================================
-- Poker hands
--============================================================
-- Base chips/mult get rolled, then the PER-LEVEL GAIN is compensated inversely:
-- a hand whose base got gutted levels up harder, and a hand that rolled absurdly
-- strong levels up slower. It's a lean, not a guarantee (clamped 0.25x-4x), so
-- Planet cards become the way you repair a bad roll.
--
-- Talisman note: Talisman.igo() converts every hand field to a big number. Writing
-- a plain number back breaks that invariant, and in Lua 5.1 a table-vs-number
-- comparison raises "attempt to compare table with number" with no chance for a
-- metamethod. So: compute in plain space, always write back via to_big().
function EEng.flux_hands()
    G.E_MANAGER:add_event(Event({
        func = function()
            if not G.GAME.hands then return true end
            local mn, mx = bounds()

            local function put(vals, key, factor)
                local base = EEng.plain(vals[key])
                if not base then return end
                local nv = math.max(1, math.floor(base * factor + 0.5))
                vals[key] = to_big and to_big(nv) or nv
            end

            for _, vals in pairs(G.GAME.hands) do
                local f_chips = EEng.log_roll('eeng_flux', mn, mx)
                local f_mult  = EEng.log_roll('eeng_flux', mn, mx)
                put(vals, 'chips',   f_chips)
                put(vals, 's_chips', f_chips)
                put(vals, 'mult',    f_mult)
                put(vals, 's_mult',  f_mult)

                -- Compensation on level-up gains FAVOURS the inverse, it doesn't guarantee
                -- it. Most of the time a gutted hand levels up hard and a monster hand levels
                -- up slowly. But 1 time in 4 it rolls WITH the base instead - so occasionally
                -- you get a monster that also scales like one, or a wreck that stays a wreck
                -- and you simply learn to avoid that hand all run. That's the fun part.
                local function comp(f)
                    if pseudorandom('eeng_planet') < 0.25 then
                        return math.min(4, math.max(0.25, f))        -- doubles down
                    end
                    return math.min(4, math.max(0.25, 1 / f))        -- compensates
                end
                put(vals, 'l_chips', comp(f_chips))
                put(vals, 'l_mult',  comp(f_mult))
            end
            return true
        end
    }))
end

--============================================================
-- Shop economy
--============================================================
-- Prices: -6/+6 flat, floor $1 ($0 with a Rental sticker). Symmetric, so the shop
-- is no more expensive on average than vanilla. Deliberately NOT
-- Cryptid's 0.1x-10x multiplier, which produced nonsense prices. A flat band
-- keeps the shop readable but still swingy.
local eeng_set_cost = Card.set_cost
function Card:set_cost()
    eeng_set_cost(self)
    if not EEng.flux_active() then return end
    if self.eeng_cost_delta == nil then
        self.eeng_cost_delta = pseudorandom('eeng_cost', -6, 6)
    end
    local floor_c = (self.ability and self.ability.rental) and 0 or 1
    local c = EEng.plain(self.cost) or 0
    -- Strictly-better rolls cost strictly more. A voucher rolled to +2 discards is
    -- worth roughly double, so it prices at roughly double - and the flat variance on
    -- top is what still lets a bargain slip through now and then.
    -- The power multiplier is CAPPED. A voucher that rolled twice as strong should cost
    -- roughly twice as much - it should not be able to roll a 10x price tag, which is
    -- what made things dumbly expensive.
    local power = math.min(2.5, self.eeng_power or 1)
    c = math.floor(c * power + 0.5)
    self.cost = math.max(floor_c, c + self.eeng_cost_delta)
    -- Sell value follows the rolled price. A Rental priced at $0 must SELL for $0 - the
    -- old floor of 1 meant you could buy a free rental and sell it for a dollar, forever.
    self.sell_cost = math.max(floor_c, math.floor(self.cost / 2))
        + (self.ability and EEng.plain(self.ability.extra_value) or 0)
end

-- Rerolls: base cost -2/+2 per shop; the per-reroll INCREASE is randomized to
-- 1 + {-2, 0, +1} = {-1, +1, +2}, so a reroll can actually get cheaper.
-- calculate_reroll_cost(true) is what runs when a shop opens - that's where we
-- reset and re-roll the base.
local eeng_calc_reroll = calculate_reroll_cost
function calculate_reroll_cost(skip_increment)
    eeng_calc_reroll(skip_increment)
    if not EEng.flux_active() then return end
    if not (G.GAME and G.GAME.current_round) then return end

    if skip_increment then
        G.GAME.eeng_reroll_delta = pseudorandom('eeng_reroll_base', -2, 2)
    else
        local pool = { -2, 0, 1 }
        G.GAME.eeng_reroll_delta = (G.GAME.eeng_reroll_delta or 0)
            + pool[pseudorandom('eeng_reroll_inc', 1, 3)]
    end

    -- A free reroll is FREE. Vanilla sets the cost to 0 when free_rerolls > 0; adding a
    -- delta on top of that is what silently broke Chaos the Clown's free rerolls.
    if (EEng.plain(G.GAME.current_round.free_rerolls) or 0) > 0 then
        G.GAME.current_round.reroll_cost = 0
        return
    end
    local c = EEng.plain(G.GAME.current_round.reroll_cost) or 0
    -- Clamped at 0: a negative reroll cost PAYS you to reroll, which is an
    -- infinite-money loop. Vouchers can still drive it to free.
    G.GAME.current_round.reroll_cost = math.max(0, c + G.GAME.eeng_reroll_delta)
end

--============================================================
-- COPIES ARE EXACT
--============================================================
-- Death copies a card. So does Blueprint, so does the Fool. Every copy goes through
-- Card:set_ability / Card:set_base, which are precisely the hooks that roll values -
-- so a "copy" was coming out with a fresh, different set of numbers. Carrying the roll
-- state across makes a copy a copy.
local eeng_copy_card = copy_card
function copy_card(other, new_card, card_scale, playing_card, strip_edition)
    local c = eeng_copy_card(other, new_card, card_scale, playing_card, strip_edition)
    if not EEng.flux_active() then return c end   -- nothing of ours to carry on other decks
    if c and other then
        c.eeng_fluxed      = other.eeng_fluxed
        c.eeng_factors     = other.eeng_factors
        c.eeng_cost_delta  = other.eeng_cost_delta
        c.eeng_power       = other.eeng_power
        c.eeng_pack_rolled = other.eeng_pack_rolled
        c.eeng_deltas      = other.eeng_deltas
        if other.base and c.base and type(other.base.nominal) == 'number' then
            c.base.nominal = other.base.nominal   -- same chips, not a re-roll
        end
    end
    return c
end

--============================================================
-- SORTING FIX
--============================================================
-- Vanilla Card:get_nominal() sorts by base.nominal - and base.nominal IS the card's
-- chip value. Flux randomizes chips, so "sort by rank" was really sorting by chips,
-- and "sort by suit" broke too because nominal is that sort's dominant term.
--
-- Fix: sort by base.id (the intrinsic rank), which Flux never touches. Cryptid hit
-- this exact wall and solved it the same way ("use ID to work with glitched/misprint").
local eeng_get_nominal = Card.get_nominal
function Card:get_nominal(mod)
    if not EEng.flux_active() or not self.base then
        return eeng_get_nominal(self, mod)
    end
    local rank = EEng.plain(self.base.id) or 2
    local suit = EEng.plain(self.base.suit_nominal) or 0
    local face = EEng.plain(self.base.face_nominal) or 0
    local uniq = (self.unique_val or 0) * 0.000001

    -- stone cards have neither rank nor suit; keep them parked, as vanilla does
    if self.ability and self.ability.effect == 'Stone Card' then
        return -10000 + uniq
    end
    if mod == 'suit' then
        return suit * 1000000 + rank * 10 + face + uniq  -- suit dominates, rank breaks ties
    end
    return rank * 1000000 + suit * 10 + face + uniq      -- rank dominates, suit breaks ties
end

--============================================================
-- EDITIONS
--============================================================
-- Foil chips, Holo mult, Poly xMult, Negative's slot. Read at scoring from
-- card.edition.chips / .mult / .x_mult, so rolling them there works.
-- card_limit stays an integer >= 1 (Negative must still grant a slot).
local eeng_set_edition = Card.set_edition
function Card:set_edition(edition, immediate, silent, delay)
    eeng_set_edition(self, edition, immediate, silent, delay)
    if not EEng.flux_active() then return end
    local e = self.edition
    if not e or e.eeng_rolled then return end
    -- card_limit and extra_slots_used are BOOKKEEPING, not payouts. SMODS adds
    -- edition.card_limit into ability.card_limit on apply and subtracts it again on the next
    -- set_edition. Rolling it in between means the add and the subtract use different
    -- numbers, so the counter drifts - which surfaced as phantom "Slots Used"/"Card Limit"
    -- tooltips, a free discard, and eventually a nil table at scoring time. Leave them be.
    for _, k in ipairs({ 'chips', 'mult', 'x_mult' }) do
        if EEng.isnum(e[k]) then
            e[k] = EEng.roll_value(e[k], k, EEng.factor_for(self, 'edition_' .. k))
        end
    end
    e.eeng_rolled = true
end

--============================================================
-- MEMED VANILLA CARDS
--============================================================
-- Strength: normally +1 rank. Under Flux the shift is rolled - it can leap 3 ranks,
-- do nothing at all, or run BACKWARDS.
--
-- This wraps SMODS.modify_rank rather than taking ownership of the Strength card.
-- Strength is a VANILLA center (c_strength) and SMODS hardcodes the +1 inside its
-- use() body, so a take_ownership on it silently did nothing - which is why Strength
-- "decided not to strength". Wrapping the function it actually calls cannot miss.
-- Side effect, and a welcome one on a chaos deck: anything else that shifts rank by
-- exactly 1 gets the same treatment.
-- The shift is rolled ONCE per run, not per use. Rolling it per use meant the card said
-- "+1 rank" and then did whatever it liked - the label was a lie and the effect was
-- unplannable. One shift for the whole run is misprinted, but it's HONEST: you learn
-- what your Strength does and you build around it.
function EEng.strength_shift()
    if not EEng.flux_active() then return 1 end
    if not G.GAME.eeng_strength then
        local pool = { -1, 1, 1, 1, 1, 2, 2, 3 }   -- -1 is now 1-in-8, not 1-in-6
        G.GAME.eeng_strength = pool[pseudorandom('eeng_strength', 1, #pool)]
    end
    return G.GAME.eeng_strength
end

local eeng_modify_rank = SMODS.modify_rank
function SMODS.modify_rank(card, amount, manual_sprites)
    if EEng.flux_active() and amount == 1 then
        amount = EEng.strength_shift()
        if amount == 0 then return true end
    end
    return eeng_modify_rank(card, amount, manual_sprites)
end

SMODS.Consumable:take_ownership('strength', {
    loc_txt = {
        name = 'Strength',
        text = { 'Increases rank of up to', '{C:attention}#1#{} selected cards by {C:attention}#2#{}' },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = { center.ability.max_highlighted, EEng.strength_shift() } }
    end,
}, true)

-- Runner: normally only counts a Straight. Under Flux it latches onto a random poker
-- hand for the run - it might be the Straight, it might be Two Pair, it might be Flush
-- House. Same joker, wildly different deck it wants.
function EEng.runner_hand()
    if not EEng.flux_active() then return 'Straight' end
    if not G.GAME.eeng_runner then
        local pool = {}
        for k, _ in pairs(G.GAME.hands or {}) do pool[#pool + 1] = k end
        table.sort(pool)
        G.GAME.eeng_runner = #pool > 0 and pool[pseudorandom('eeng_runner', 1, #pool)] or 'Straight'
    end
    return G.GAME.eeng_runner
end

SMODS.Joker:take_ownership('runner', {
    loc_txt = {
        name = 'Runner',
        text = {
            'Gains {C:chips}+#2#{} Chips if played',
            'hand contains a {C:attention}#3#{}',
            '{C:inactive}(Currently {C:chips}+#1#{C:inactive} Chips)',
        },
    },
    loc_vars = function(self, info_queue, center)
        return { vars = {
            center.ability.extra.chips, center.ability.extra.chip_mod,
            localize(EEng.runner_hand(), 'poker_hands'),
        } }
    end,
    calculate = function(self, card, context)
        if context.before and not context.blueprint then
            local h = EEng.runner_hand()
            if context.poker_hands and context.poker_hands[h] and next(context.poker_hands[h]) then
                card.ability.extra.chips = card.ability.extra.chips + card.ability.extra.chip_mod
                return { message = localize('k_upgrade_ex'), colour = G.C.CHIPS, card = card }
            end
        end
        if context.joker_main and EEng.plain(card.ability.extra.chips) ~= 0 then
            return { chips = card.ability.extra.chips }
        end
    end,
}, true)

-- Walkie Talkie: normally hardwired to 10s and 4s. Under Flux the two target ranks
-- are rolled once per run. The ranks live in the joker's CALCULATE, not its config,
-- so they can only be changed by owning the joker outright.
function EEng.walkie_ranks()
    if not EEng.flux_active() then return { 10, 4 } end
    if not G.GAME.eeng_walkie then
        local a = pseudorandom('eeng_walkie_a', 2, 14)
        local b = pseudorandom('eeng_walkie_b', 2, 14)
        if b == a then b = (a % 13) + 2 end
        G.GAME.eeng_walkie = { a, b }
    end
    return G.GAME.eeng_walkie
end

local RANK_NAME = { [2]='2',[3]='3',[4]='4',[5]='5',[6]='6',[7]='7',[8]='8',[9]='9',
                    [10]='10',[11]='Jack',[12]='Queen',[13]='King',[14]='Ace' }

SMODS.Joker:take_ownership('walkie_talkie', {
    loc_txt = {
        name = 'Walkie Talkie',
        text = {
            'Each played {C:attention}#3#{} or {C:attention}#4#{} gives',
            '{C:chips}+#1#{} Chips and {C:mult}+#2#{} Mult',
        },
    },
    loc_vars = function(self, info_queue, center)
        local r = EEng.walkie_ranks()
        return { vars = {
            center.ability.extra.chips, center.ability.extra.mult,
            RANK_NAME[r[1]] or r[1], RANK_NAME[r[2]] or r[2],
        } }
    end,
    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play and not context.end_of_round
            and context.other_card then
            local r = EEng.walkie_ranks()
            local id = context.other_card:get_id()
            if id == r[1] or id == r[2] then
                return {
                    chips = card.ability.extra.chips,
                    mult = card.ability.extra.mult,
                }
            end
        end
    end,
}, true)

--============================================================
-- TAGS
--============================================================
-- Tags are not Cards, so none of the hooks above touch them. They get their own.
--
-- Design note: tags are rolled UPWARD only. A good half of the vanilla tag list is
-- already weak-to-useless, and a Flux roll that made Handy Tag worse would just be
-- content nobody engages with. So the floor is the vanilla value and the roll only
-- goes up - the variance is in HOW much better, not whether.
--
-- Joker tags (Uncommon, Rare, Foil, Holo, Polychrome, Negative) hand out ONE joker.
-- Under Flux they can hand out several: the tag re-applies itself N times.
EEng.joker_tags = {
    tag_uncommon = true, tag_rare = true, tag_negative = true,
    tag_foil = true, tag_holo = true, tag_polychrome = true,
}

if Tag and Tag.init then
    local eeng_tag_init = Tag.init
    function Tag:init(key, for_collection, _blind_type)
        eeng_tag_init(self, key, for_collection, _blind_type)
        if for_collection or not EEng.flux_active() then return end

        -- roll whatever numbers the tag carries, upward only
        if type(self.config) == 'table' then
            for k, v in pairs(self.config) do
                if EEng.isnum(v) and not EEng.flux_blacklist[k] then
                    local b = EEng.plain(v) or 0
                    if b > 0 then
                        local f = EEng.log_roll('eeng_tag', 1, 6)
                        local rolled = math.floor(b * f + 0.5)
                        self.config[k] = math.max(b, rolled)
                    end
                end
            end
        end

        -- how many jokers does this hand out?
        if EEng.joker_tags[self.key] then
            local pool = { 1, 1, 2, 2, 3 }
            self.eeng_copies = pool[pseudorandom('eeng_tag_copies', 1, #pool)]
        end
    end

    local eeng_tag_apply = Tag.apply_to_run
    function Tag:apply_to_run(_context)
        local res = eeng_tag_apply(self, _context)
        -- Re-run the tag for each extra copy. Guarded hard: only joker tags, only when
        -- the first application actually fired, and the counter is cleared immediately
        -- so a re-entrant call can't loop.
        if EEng.flux_active() and self.eeng_copies and self.eeng_copies > 1
            and EEng.joker_tags[self.key] and self.triggered and not self.eeng_copying then
            self.eeng_copying = true
            local extra = self.eeng_copies - 1
            self.eeng_copies = nil
            for _ = 1, extra do
                self.triggered = nil
                pcall(eeng_tag_apply, self, _context)
            end
            self.eeng_copying = nil
            self.triggered = true
        end
        return res
    end
end

--============================================================
-- APPLY THE POOL LAST
--============================================================
-- Everything in start_run() that could overwrite our loadout has already run by the
-- time this returns, so this is the only place the values are safe. Guarded by a flag
-- so loading a save doesn't re-roll a run that's already in progress.
local eeng_start_run = Game.start_run
function Game:start_run(args)
    eeng_start_run(self, args)
    local p = G.GAME and G.GAME.eeng_pool
    if not p or G.GAME.eeng_pool_applied then return end
    G.GAME.eeng_pool_applied = true

    if G.GAME.round_resets then
        G.GAME.round_resets.hands = p.hands
        G.GAME.round_resets.discards = p.discards
    end
    if G.GAME.current_round then
        G.GAME.current_round.hands_left = p.hands
        G.GAME.current_round.discards_left = p.discards
    end
    if G.hand then G.hand.config.card_limit = p.hand_size end
    if G.jokers then G.jokers.config.card_limit = p.joker_slots end
    if G.consumeables then G.consumeables.config.card_limit = p.consumable_slots end
    local cur = EEng.plain(G.GAME.dollars) or 0
    if p.dollars ~= cur and ease_dollars then ease_dollars(p.dollars - cur, true) end
end

--============================================================
-- FLUX DECK
--============================================================
SMODS.Back{
    key = 'flux',
    atlas = 'eeng_jokers', pos = { x = 4, y = 1 },
    unlocked = true, discovered = true,
    config = { eeng_flux_min = CFG.misprint.min, eeng_flux_max = CFG.misprint.max },
    loc_txt = {
        name = 'Flux Deck',
        text = {
            'Every value is {C:attention}randomized{}:',
            '{C:attention}Jokers{}, {C:attention}cards{}, {C:attention}poker hands{},',
            '{C:attention}prices{}, {C:attention}rerolls{}, {C:attention}packs{}',
            '{C:inactive}(between {C:blue}#1#X{C:inactive} and {C:blue}#2#X{C:inactive})',
        },
    },
    loc_vars = function(self, info_queue, back)
        return { vars = { CFG.misprint.min, CFG.misprint.max } }
    end,
    apply = function(self)
        G.GAME.modifiers.eeng_flux_min = self.config.eeng_flux_min
        G.GAME.modifiers.eeng_flux_max = self.config.eeng_flux_max
        EEng.flux_hands()
    end,
}

--============================================================
-- FLUX SLEEVE (requires CardSleeves)
--============================================================
if not CardSleeves then return end

-- CardSleeves sleeves are 73x95, NOT the 71x95 used for jokers/decks. Pointing the
-- sleeve at the joker atlas is what broke the sleeve's cutoff shape and icon: every
-- cell was sliced 2px narrow. Sleeves need their own atlas.
SMODS.Atlas{
    key = 'eeng_sleeves',
    path = 'eeng_sleeves.png',
    px = 73,
    py = 95,
}

-- WEIGHTED POINT POOL (only on the Flux deck combo).
-- Everything costs 1 point, except hands (3) and joker slots (2).
-- Vanilla white stake therefore costs 4x3 + 5x2 + 3 + 8 + 2 + 4 = 39 points.
-- (That's 39, NOT 34 - so the baseline is COMPUTED from the real starting params
-- at runtime instead of hardcoded. Stays correct under any stake, and under any
-- other mod that changes the starting loadout.)
-- We roll a total of baseline..baseline+2 and repartition it: never fewer points
-- than vanilla, so it can't be an objective nerf, but distributed wildly.
-- FLOORS ARE THE SAFETY RAIL, not a budgeting inconvenience. Zero consumable slots
-- isn't a spicy roll, it's a dead run - the same for zero discards. Every floor here is
-- a value the run remains PLAYABLE at, and the variance lives above them.
--
-- The surplus starts at 1, never 0: the repartition is always worth at least one point
-- more than vanilla, so on average the deck is marginally in your favour. It should
-- feel like a gamble you're slightly winning, not a coin flip on whether the run works.
local POOL = {
    weights = { hands = 3, joker_slots = 2, discards = 1, hand_size = 1,  consumable_slots = 1, dollars = 1 },
    floors  = { hands = 3, joker_slots = 4, discards = 2, hand_size = 6,  consumable_slots = 1, dollars = 0 },
    ceils   = { hands = 7, joker_slots = 8, discards = 7, hand_size = 12, consumable_slots = 4, dollars = 15 },
    surplus_min = 1, surplus_max = 3,
    deck_min = 40, deck_max = 60,
}

local function roll_pool()
    local sp = G.GAME.starting_params
    local vanilla = {
        hands            = EEng.plain(sp.hands) or 4,
        joker_slots      = EEng.plain(sp.joker_slots) or 5,
        discards         = EEng.plain(sp.discards) or 3,
        hand_size        = EEng.plain(sp.hand_size) or 8,
        consumable_slots = EEng.plain(sp.consumable_slots) or 2,
        dollars          = EEng.plain(sp.dollars) or 4,
    }

    local baseline = 0
    for k, w in pairs(POOL.weights) do baseline = baseline + (vanilla[k] or 0) * w end
    local total = baseline + pseudorandom('eeng_pool_total', POOL.surplus_min, POOL.surplus_max)

    local cur, spent, keys = {}, 0, {}
    for k, _ in pairs(POOL.weights) do
        cur[k] = POOL.floors[k]
        spent = spent + cur[k] * POOL.weights[k]
        keys[#keys + 1] = k
    end
    table.sort(keys) -- deterministic order for a given seed

    local guard = 0
    while spent < total and guard < 500 do
        guard = guard + 1
        local k = keys[pseudorandom('eeng_pool_spend', 1, #keys)]
        local w = POOL.weights[k]
        if cur[k] < POOL.ceils[k] and spent + w <= total then
            cur[k] = cur[k] + 1
            spent = spent + w
        else
            local any = false
            for _, j in ipairs(keys) do
                if cur[j] < POOL.ceils[j] and spent + POOL.weights[j] <= total then any = true break end
            end
            if not any then break end
        end
    end
    return cur
end

CardSleeves.Sleeve{
    key = 'flux',
    name = 'Flux Sleeve',
    atlas = 'eeng_sleeves', pos = { x = 0, y = 0 },
    unlocked = true, discovered = true,
    config = {},

    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_eeng_flux' then
            self.config = { flux_run = true }
            return { key = self.key .. '_alt', vars = { POOL.deck_min, POOL.deck_max } }
        else
            self.config = { flux_values = true }
            return { key = self.key, vars = { CFG.misprint.min, CFG.misprint.max } }
        end
    end,

    loc_txt = {
        name = 'Flux Sleeve',
        text = {
            'Every value is {C:attention}randomized{}',
            '{C:inactive}(between {C:blue}#1#X{C:inactive} and {C:blue}#2#X{C:inactive})',
        },
    },

    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(self)

        -- Alone: mirror the deck.
        if self.config.flux_values then
            G.GAME.modifiers.eeng_flux_min = CFG.misprint.min
            G.GAME.modifiers.eeng_flux_max = CFG.misprint.max
            EEng.flux_hands()
        end

        -- On the Flux deck: values are already chaos, so the sleeve destabilizes
        -- the RUN itself - loadout repartitioned, deck rebuilt from scratch.
        if self.config.flux_run then
            local p = roll_pool()
            G.GAME.starting_params.hands            = p.hands
            G.GAME.starting_params.discards         = p.discards
            G.GAME.starting_params.hand_size        = p.hand_size
            G.GAME.starting_params.joker_slots      = p.joker_slots
            G.GAME.starting_params.consumable_slots = p.consumable_slots
            -- dollars is one of the fields Talisman big-ifies, so respect that
            G.GAME.starting_params.dollars = to_big and to_big(p.dollars) or p.dollars

            -- Stash the roll. It gets APPLIED after Game:start_run() finishes (see the
            -- wrapper below), not here.
            --
            -- Applying it here is what made the values "go random, then snap back to
            -- vanilla": a sleeve applies partway through start_run, and the rest of
            -- start_run then re-derives round_resets / current_round / card_limits from
            -- starting_params it had already read. Only joker_slots is read late enough
            -- to survive - which is exactly the one value that stuck. Applying last
            -- means nothing runs after us to undo it.
            G.GAME.eeng_pool = p

            local target = pseudorandom('eeng_slv_deck', POOL.deck_min, POOL.deck_max)

            G.E_MANAGER:add_event(Event({
                func = function()
                    if not G.playing_cards or #G.playing_cards == 0 then return true end

                    -- Erratic-style: every card gets a random rank AND suit, so
                    -- the deck's composition changes, not just its size.
                    local pool = {}
                    for k, _ in pairs(G.P_CARDS) do pool[#pool + 1] = k end
                    table.sort(pool)

                    -- DECK RESIZE.
                    -- The old version called c:remove() AND table.remove(G.playing_cards).
                    -- Card:remove() already unregisters the card, so the manual removal
                    -- deleted a SECOND, still-live card from the registry while leaving it
                    -- in G.deck. The deck then held more cards than the registry knew about,
                    -- which is where "29/22" came from. Fix: mutate the deck, then rebuild
                    -- G.playing_cards from G.deck.cards as the single source of truth.
                    local n = #G.playing_cards
                    if target < n then
                        for _ = 1, n - target do
                            if #G.deck.cards <= 1 then break end
                            local i = pseudorandom('eeng_slv_trim', 1, #G.deck.cards)
                            local c = G.deck.cards[i]
                            if c then
                                table.remove(G.deck.cards, i)
                                c:remove()
                            end
                        end
                    elseif target > n then
                        for _ = 1, target - n do
                            local src = G.deck.cards[pseudorandom('eeng_slv_pad', 1, #G.deck.cards)]
                            if src then
                                local c = copy_card(src, nil, nil, nil)
                                c:add_to_deck()
                                G.deck:emplace(c)
                            end
                        end
                    end

                    -- single source of truth: the registry mirrors the deck exactly
                    G.playing_cards = {}
                    for _, c in ipairs(G.deck.cards) do
                        c.playing_card = #G.playing_cards + 1
                        G.playing_cards[#G.playing_cards + 1] = c
                    end

                    if #pool > 0 then
                        for _, c in ipairs(G.playing_cards) do
                            local key = pool[pseudorandom('eeng_erratic', 1, #pool)]
                            if G.P_CARDS[key] then c:set_base(G.P_CARDS[key]) end
                        end
                    end
                    if G.deck then G.deck:set_ranks() end
                    return true
                end
            }))
        end
    end,
}

-- The alt description lives in localization/en-us.lua.
-- It must NOT be registered here with SMODS.process_loc_text: at main-chunk time
-- G.localization.descriptions.Sleeve does not exist yet, so that call crashes on
-- a nil ref_table. SMODS auto-loads the mod's localization/ folder at the right
-- point, which is how CardSleeves registers its own _alt keys.

--============================================================
-- PRISMATIC DECK  (staged)
--============================================================
-- The "all" deck: every vanilla deck's PERK, none of their drawbacks.
-- Deliberately omitted: Abandoned's no-faces, Checkered's suit lock, Plasma's x2
-- blind size, Black's -1 hand, Painted's -1 Joker, Nebula's -1 consumable. Those are
-- the prices those decks pay; a deck that stacked all the costs too would be
-- unplayable, and one that stacked the perks is already the point.
--
-- STAGED, not balanced. It is knowingly very strong - that's the fantasy - but the
-- numbers below are the obvious knobs.
SMODS.Back{
    key = 'prismatic',
    atlas = 'eeng_jokers', pos = { x = 0, y = 2 },
    unlocked = true, discovered = true,
    config = {},
    loc_txt = {
        name = 'Prismatic Deck',
        text = {
            'Every {C:attention}vanilla deck{}\'s upside,',
            'and none of their downsides',
            '{C:red}No Joker stickers{} can appear',
            '{C:red}Achievements are disabled{}',
        },
    },
    apply = function(self)
        local sp = G.GAME.starting_params

        sp.hands       = sp.hands + 1          -- Blue
        sp.discards    = sp.discards + 1       -- Red
        sp.joker_slots = sp.joker_slots + 1    -- Black
        sp.hand_size   = sp.hand_size + 2      -- Painted
        sp.dollars     = (EEng.plain(sp.dollars) or 4) + 10  -- Yellow
        if to_big then sp.dollars = to_big(sp.dollars) end   -- Talisman owns this field

        G.GAME.modifiers.money_per_hand    = (G.GAME.modifiers.money_per_hand or 1) + 1  -- Green
        G.GAME.modifiers.money_per_discard = (G.GAME.modifiers.money_per_discard or 0) + 1

        G.GAME.spectral_rate = 2                       -- Ghost
        sp.erratic_suits_and_ranks = true              -- Erratic

        -- Magic / Nebula / Zodiac hand you their vouchers up front
        for _, v in ipairs({ 'v_crystal_ball', 'v_telescope', 'v_tarot_merchant',
                             'v_planet_merchant', 'v_overstock_norm' }) do
            if G.P_CENTERS[v] then
                G.GAME.used_vouchers[v] = true
                G.GAME.starting_voucher_count = (G.GAME.starting_voucher_count or 0) + 1
                G.E_MANAGER:add_event(Event({ func = function()
                    Card.apply_to_run(nil, G.P_CENTERS[v]); return true
                end }))
            end
        end

        -- Prismatic is deliberately, unapologetically broken. So it opts OUT of the
        -- things that only make sense on a fair run: no Eternal/Perishable/Rental
        -- stickers can appear on Jokers no matter the stake, and achievements are off.
        G.GAME.modifiers.enable_eternals_in_shop   = false
        G.GAME.modifiers.enable_perishables_in_shop = false
        G.GAME.modifiers.enable_rentals_in_shop     = false
        G.GAME.eeng_no_stickers = true
        G.GAME.seeded = true          -- Balatro's own switch for "this run doesn't count"

        -- Magic's two Fools, Ghost's Hex
        G.E_MANAGER:add_event(Event({ func = function()
            for _, key in ipairs({ 'c_fool', 'c_fool', 'c_hex' }) do
                if G.P_CENTERS[key] and G.consumeables then
                    local c = create_card('Tarot', G.consumeables, nil, nil, nil, nil, key, 'deck')
                    c:add_to_deck()
                    G.consumeables:emplace(c)
                end
            end
            return true
        end }))
    end,
    calculate = function(self, back, context)
        -- Plasma: balance chips and mult (without Plasma's doubled blind)
        if context.final_scoring_step then
            return { balance = true }
        end
        -- Anaglyph: a Double Tag after every Boss Blind
        if context.round_eval and G.GAME.last_blind and G.GAME.last_blind.boss then
            G.E_MANAGER:add_event(Event({ func = function()
                add_tag(Tag('tag_double'))
                play_sound('generic1', 0.9 + math.random() * 0.1, 0.8)
                return true
            end }))
        end
    end,
}

-- Nothing gets to sticker a Joker on a Prismatic run, whatever the stake says.
local eeng_eternal = SMODS.Sticker and SMODS.Sticker.should_apply
if SMODS.Sticker and SMODS.Sticker.should_apply then
    local ref = SMODS.Sticker.should_apply
    function SMODS.Sticker:should_apply(card, center, area, rate)
        if G.GAME and G.GAME.eeng_no_stickers then return false end
        return ref(self, card, center, area, rate)
    end
end

--============================================================
-- PRISMATIC SLEEVE
--============================================================
-- Alone: every vanilla sleeve's upside at once (the sleeves mirror the decks, so this
-- is the deck's package again - meaning you can wear it over ANY deck and stack it).
-- On the Prismatic Deck: the perks are already there, so the sleeve doubles the
-- economy and hands you the run's tempo instead - the "all combos" payoff.
local function prismatic_perks(double)
    local n = double and 2 or 1
    local sp = G.GAME.starting_params
    sp.hands       = sp.hands + 1 * n
    sp.discards    = sp.discards + 1 * n
    sp.joker_slots = sp.joker_slots + 1 * n
    sp.hand_size   = sp.hand_size + 2 * n
    sp.dollars     = (EEng.plain(sp.dollars) or 4) + 10 * n
    if to_big then sp.dollars = to_big(sp.dollars) end

    G.GAME.modifiers.money_per_hand    = (G.GAME.modifiers.money_per_hand or 1) + 1 * n
    G.GAME.modifiers.money_per_discard = (G.GAME.modifiers.money_per_discard or 0) + 1 * n
    G.GAME.spectral_rate = math.max(G.GAME.spectral_rate or 0, 2 * n)
    sp.erratic_suits_and_ranks = true
end

CardSleeves.Sleeve{
    key = 'prismatic',
    name = 'Prismatic Sleeve',
    atlas = 'eeng_sleeves', pos = { x = 1, y = 0 },
    unlocked = true, discovered = true,
    config = {},

    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_eeng_prismatic' then
            self.config = { prismatic_double = true }
            return { key = self.key .. '_alt' }
        end
        self.config = { prismatic = true }
        return { key = self.key }
    end,

    loc_txt = {
        name = 'Prismatic Sleeve',
        text = {
            'Every {C:attention}vanilla sleeve{}\'s',
            'upside, all at once',
            '{C:red}No Joker stickers{}, {C:red}no achievements{}',
        },
    },

    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(self)

        -- Over any other deck: every vanilla sleeve's upside - and the same opt-out.
        G.GAME.modifiers.enable_eternals_in_shop    = false
        G.GAME.modifiers.enable_perishables_in_shop = false
        G.GAME.modifiers.enable_rentals_in_shop     = false
        G.GAME.eeng_no_stickers = true
        G.GAME.seeded = true

        if self.config.prismatic then
            prismatic_perks(false)
            return
        end

        if not self.config.prismatic_double then return end

        -- ON THE PRISMATIC DECK: the deck already handed you every sleeve's BASE effect,
        -- so stacking it again would just be a bigger number. A Card Sleeves combo is
        -- supposed to CHANGE the deal, not scale it - a sharper edge with a retooled
        -- cost, or a sideways benefit in the same flavour. So the combo is every
        -- sleeve's COMBO, in spirit:
        local sp = G.GAME.starting_params

        -- Magic combo: a second copy of every starting consumable
        -- Nebula combo: Telescope AND Observatory
        for _, v in ipairs({ 'v_observatory', 'v_grabber', 'v_wasteful', 'v_paint_brush' }) do
            if G.P_CENTERS[v] and not G.GAME.used_vouchers[v] then
                G.GAME.used_vouchers[v] = true
                G.E_MANAGER:add_event(Event({ func = function()
                    Card.apply_to_run(nil, G.P_CENTERS[v]); return true
                end }))
            end
        end

        -- Zodiac combo: shops are deep. Anaglyph combo: you open on a Double Tag.
        sp.consumable_slots = sp.consumable_slots + 2
        G.GAME.modifiers.eeng_no_stickers = true
        G.E_MANAGER:add_event(Event({ func = function()
            add_tag(Tag('tag_double')); add_tag(Tag('tag_charm')); return true
        end }))

        -- Checkered combo: the deck skews hard to one suit instead of being random.
        -- THE RETOOL: Erratic's chaos is switched OFF for a guaranteed Flush engine.
        sp.erratic_suits_and_ranks = false
        G.E_MANAGER:add_event(Event({ func = function()
            if not G.playing_cards then return true end
            for _, c in ipairs(G.playing_cards) do
                if pseudorandom('eeng_prism_suit') < 0.75 then
                    SMODS.change_base(c, 'Spades')
                end
            end
            return true
        end }))
    end,
}

--============================================================
-- VOUCHERS MUST APPLY WHAT THEY ADVERTISE
--============================================================
-- Balatro's slot vouchers hardcode "+1" inside their redeem() - they never read their own
-- config. So Flux rolling Paint Brush to +2 changed the TOOLTIP and nothing else: it still
-- handed you exactly one card of hand size. Own the redeems and make them read
-- card.ability.extra, which is the number the player was actually shown.
local function eeng_voucher(key, fn)
    pcall(function()
        SMODS.Voucher:take_ownership(key, { redeem = fn }, true)
    end)
end

local function amt(card, dflt)
    local n = EEng.plain(card and card.ability and card.ability.extra)
    if not n or n < 1 then return dflt or 1 end
    return math.floor(n + 0.5)
end

-- +Hands
for _, k in ipairs({ 'grabber', 'nacho_tong' }) do
    eeng_voucher(k, function(self, card)
        local n = amt(card)
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + n
        ease_hands_played(n)
    end)
end

-- +Discards
for _, k in ipairs({ 'wasteful', 'recyclomancy' }) do
    eeng_voucher(k, function(self, card)
        local n = amt(card)
        G.GAME.round_resets.discards = G.GAME.round_resets.discards + n
        ease_discard(n)
    end)
end

-- +Hand size
for _, k in ipairs({ 'paint_brush', 'palette' }) do
    eeng_voucher(k, function(self, card)
        local n = amt(card)
        G.GAME.starting_params.hand_size = G.GAME.starting_params.hand_size + n
        if G.hand then
            G.hand.config.card_limit = G.hand.config.card_limit + n
            -- NO draw here. Vouchers are redeemed in the SHOP, where there is no hand to draw
            -- into - calling draw_from_deck_to_hand() there deals cards onto a dead table and
            -- wedges the run. Vanilla just raises the limit; the next round deals up to it.
        end
    end)
end

-- +Shop slots
for _, k in ipairs({ 'overstock_norm', 'overstock_plus' }) do
    eeng_voucher(k, function(self, card)
        local n = amt(card)
        if SMODS.change_shop_size then
            SMODS.change_shop_size(n)
        elseif G.GAME.shop then
            G.GAME.shop.joker_max = (G.GAME.shop.joker_max or 2) + n
        end
    end)
end


-- Chaos the Clown hardcodes ONE free reroll in its calculate - it never reads its own
-- config, so Flux rolling it to 3 changed the tooltip and nothing else. Same disease as the
-- slot vouchers.
pcall(function()
    SMODS.Joker:take_ownership('chaos_the_clown', {
        calculate = function(self, card, context)
            if context.setting_blind and not context.blueprint then
                local n = math.max(1, math.floor((EEng.plain(card.ability.extra) or 1) + 0.5))
                G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + n
                calculate_reroll_cost(true)
            end
        end,
    }, true)
end)
