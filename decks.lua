-- Endless Engines - Decks
-- The PRISMATIC deck + PRISMATIC sleeve.

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
if SMODS.Sticker and SMODS.Sticker.should_apply then
    local ref = SMODS.Sticker.should_apply
    function SMODS.Sticker:should_apply(card, center, area, rate)
        if G.GAME and G.GAME.eeng_no_stickers then return false end
        return ref(self, card, center, area, rate)
    end
end

--============================================================
-- PRISMATIC SLEEVE (requires CardSleeves)
--============================================================
-- Alone: every vanilla sleeve's upside at once (the sleeves mirror the decks, so this
-- is the deck's package again - meaning you can wear it over ANY deck and stack it).
-- On the Prismatic Deck: the perks are already there, so the sleeve doubles the
-- economy and hands you the run's tempo instead - the "all combos" payoff.
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

-- The alt description lives in localization/en-us.lua.
-- It must NOT be registered here with SMODS.process_loc_text: at main-chunk time
-- G.localization.descriptions.Sleeve does not exist yet, so that call crashes on
-- a nil ref_table. SMODS auto-loads the mod's localization/ folder at the right
-- point, which is how CardSleeves registers its own _alt keys.
