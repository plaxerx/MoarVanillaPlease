-- Pinochle - custom decks

--============================================================
-- Custom Functions
--============================================================

local function grant_vouchers(keys, as_starting)
    for _, v in ipairs(keys) do
        if G.P_CENTERS[v] and not G.GAME.used_vouchers[v] then
            G.GAME.used_vouchers[v] = true
            if as_starting then
                G.GAME.starting_voucher_count = (G.GAME.starting_voucher_count or 0) + 1
            end
            G.E_MANAGER:add_event(Event({ func = function()
                local ok, err = pcall(Card.apply_to_run, nil, G.P_CENTERS[v])
                if not ok then
                    sendWarnMessage(('voucher %s failed: %s'):format(v, tostring(err)), 'Pinochle')
                end
                return true
            end }))
        end
    end
end

local function starting_consumables(keys)
    G.E_MANAGER:add_event(Event({ func = function()
        for _, key in ipairs(keys) do
            if G.P_CENTERS[key] and G.consumeables then
                local c = create_card('Tarot', G.consumeables, nil, nil, nil, nil, key, 'deck')
                c:add_to_deck()
                G.consumeables:emplace(c)
            end
        end
        return true
    end }))
end

local function ban_modded_objects(pool, predicate)
    G.GAME.banned_keys = G.GAME.banned_keys or {}
    for fallback_key, object in pairs(pool or {}) do
        if type(object) == 'table' and object.original_mod
            and (not predicate or predicate(object)) then
            G.GAME.banned_keys[object.key or fallback_key] = true
        end
    end
end

local function vanilla_jokers_only()
    G.GAME.modifiers.no_modded_jokers = true
    G.GAME.modifiers.mvp_vanilla_jokers_only = true
    ban_modded_objects(G.P_CENTERS, function(object)
        return object.set == 'Joker'
    end)
end

local function vanilla_consumables_only()
    G.GAME.modifiers.mvp_vanilla_consumables_only = true
    ban_modded_objects(G.P_CENTERS, function(object)
        return object.set ~= 'Joker' and object.set ~= 'Back'   -- never ban the deck in play
    end)
    ban_modded_objects(G.P_TAGS)
    ban_modded_objects(G.P_BLINDS)
    ban_modded_objects(G.P_SEALS)
end

local function vanilla_content_only()
    vanilla_jokers_only()
    vanilla_consumables_only()
    G.GAME.modifiers.mvp_vanilla_only = true
end

--============================================================
-- PRISMATIC DECK - Every vanilla deck's upside.
--============================================================

SMODS.Back{
    key = 'prismatic',
    atlas = 'mvp_decks', pos = { x = 0, y = 0 },
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
        sp.dollars     = (MVP.plain(sp.dollars) or 4) + 10  -- Yellow
        if to_big then sp.dollars = to_big(sp.dollars) end

        G.GAME.modifiers.money_per_hand    = (G.GAME.modifiers.money_per_hand or 1) + 1  -- Green
        G.GAME.modifiers.money_per_discard = (G.GAME.modifiers.money_per_discard or 0) + 1 -- Green

        G.GAME.spectral_rate = math.max(G.GAME.spectral_rate or 0, 2)  -- Ghost
        sp.erratic_suits_and_ranks = true                              -- Erratic

        -- Magic, Nebula, and Zodiac
        grant_vouchers({ 'v_crystal_ball', 'v_telescope', 'v_tarot_merchant',
                         'v_planet_merchant', 'v_overstock_norm' }, true)

        G.GAME.mvp_no_stickers = true
        G.GAME.seeded = true   -- workaround to prevent achievement cheese

        starting_consumables({ 'c_fool', 'c_fool', 'c_hex' })   -- Magic, Ghost
    end,
    calculate = function(self, back, context)
        if context.final_scoring_step then
            return { balance = true }   -- Plasma
        end
        if context.round_eval and G.GAME.last_blind and G.GAME.last_blind.boss then
            G.E_MANAGER:add_event(Event({ func = function()   -- Anaglyph
                add_tag(Tag('tag_double'))
                play_sound('generic1', 0.9 + math.random() * 0.1, 0.8)
                return true
            end }))
        end
    end,
}

if SMODS.Sticker and SMODS.Sticker.should_apply then -- workaround for sticker cheese
    local ref = SMODS.Sticker.should_apply
    function SMODS.Sticker:should_apply(card, center, area, rate)
        if G.GAME and G.GAME.mvp_no_stickers then return false end
        return ref(self, card, center, area, rate)
    end
end

--============================================================
-- VANILLA DECK - Designed for modded games to exclude modded content
--============================================================

SMODS.Back{
    key = 'vanilla',
    atlas = 'mvp_decks', pos = { x = 1, y = 0 },
    unlocked = true, discovered = true,
    config = {},
    loc_txt = {
        name = 'Vanilla Deck',
        text = {
            'Only {C:attention}vanilla Jokers{}',
            'can appear',
        },
    },
    apply = function(self)
        vanilla_jokers_only()
    end,
}

--============================================================
-- PRISMATIC SLEEVE (requires CardSleeves)
--============================================================
if not CardSleeves then return end

SMODS.Atlas{
    key = 'mvp_sleeves',
    path = 'mvp_sleeves.png',
    px = 73,
    py = 95,
}

local function prismatic_perks(double)
    local n = double and 2 or 1
    local sp = G.GAME.starting_params
    sp.hands       = sp.hands + 1 * n 			-- Blue
    sp.discards    = sp.discards + 1 * n 		-- Red
    sp.joker_slots = sp.joker_slots + 1 * n 	-- Black
    sp.hand_size   = sp.hand_size + 2 * n 		-- Painted
    sp.dollars     = (MVP.plain(sp.dollars) or 4) + 10 * n 		-- Yellow
    if to_big then sp.dollars = to_big(sp.dollars) end

    G.GAME.modifiers.money_per_hand    = (G.GAME.modifiers.money_per_hand or 1) + 1 * n		-- Green
    G.GAME.modifiers.money_per_discard = (G.GAME.modifiers.money_per_discard or 0) + 1 * n	-- Green
    G.GAME.spectral_rate = math.max(G.GAME.spectral_rate or 0, 2 * n)	-- Ghost
    sp.erratic_suits_and_ranks = true	-- Erratic
end

CardSleeves.Sleeve{
    key = 'prismatic',
    name = 'Prismatic Sleeve',
    atlas = 'mvp_sleeves', pos = { x = 0, y = 0 },
    unlocked = true, discovered = true,
    config = {},

    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_mvp_prismatic' then
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
            'upside applied',
            '{C:red}Joker stickers and achievements disabled{}',
        },
    },

    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(self)

        self.config = MVP.on_deck('b_mvp_prismatic')
            and { prismatic_double = true } or { prismatic = true }

        G.GAME.mvp_no_stickers = true
        G.GAME.seeded = true

        if self.config.prismatic then
            prismatic_perks(false)  
            return
        end

        if not self.config.prismatic_double then return end

        local sp = G.GAME.starting_params

		-- Magic, Nebula, and Zodiac
        grant_vouchers({ 'v_observatory', 'v_grabber', 'v_wasteful', 'v_paint_brush' })

        sp.consumable_slots = sp.consumable_slots + 2
        G.E_MANAGER:add_event(Event({ func = function()		-- Anaglyph
            add_tag(Tag('tag_double')); add_tag(Tag('tag_charm')); return true
        end }))

        sp.erratic_suits_and_ranks = false
        G.E_MANAGER:add_event(Event({ func = function()
            if not G.playing_cards then return true end
            for _, c in ipairs(G.playing_cards) do
                if pseudorandom('mvp_prism_suit') < 0.75 then	-- Checkered
                    SMODS.change_base(c, 'Spades')
                end
            end
            return true
        end }))
    end,
}

--============================================================
-- VANILLA SLEEVE (requires CardSleeves)
--============================================================

CardSleeves.Sleeve{
    key = 'vanilla',
    name = 'Vanilla Sleeve',
    atlas = 'mvp_sleeves', pos = { x = 1, y = 0 },
    unlocked = true, discovered = true,
    config = {},

    loc_vars = function(self)
        if self.get_current_deck_key() == 'b_mvp_vanilla' then
            return { key = self.key .. '_alt' }
        end
        return { key = self.key }
    end,

    loc_txt = {
        name = 'Vanilla Sleeve',
        text = {
            'Only {C:attention}vanilla Consumables{}',
            '{C:attention}Vouchers{} and {C:attention}Tags{} can appear',
        },
    },

    apply = function(self, sleeve)
        CardSleeves.Sleeve.apply(self)
        if MVP.on_deck('b_mvp_vanilla') then
            vanilla_content_only()
        else
            vanilla_consumables_only()
        end
    end,
}
