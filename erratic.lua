-- Erratic Mode.
--
-- Mutations are rolled per run rather than baked into a challenge object like rules.custom,
-- so they are stored as a list of KEYS on G.GAME
--
-- Each mutation carries:
--   key       - stable id stored in G.GAME.mvp_mutations
--   name      - shown in the Mutation List and View Deck > Mutations
--   category  - 'Challenge' | 'Boon' | 'Twist'. Slot 1 is always a Challenge, slot 2 always
--               a Boon, every slot after is equal-odds among the three.
--   text      - one or two short lines
--   conflicts - mutation keys that can't co-exist with this one, made symmetric at load.
--   weight    - how often it's picked, relative to the rest of its category (default 1, 0 = never).
--   apply     - runs once at run start (pcall'd), setting starting_params / modifiers /
--               flags that the hooks below read.
--

MVP.MUTATIONS = {}
MVP.MUT_BY_KEY = {}

local function mut(t)
    MVP.MUTATIONS[#MVP.MUTATIONS + 1] = t
    MVP.MUT_BY_KEY[t.key] = t
    return t
end

local function sp() return G.GAME.starting_params end
local function mods() return G.GAME.modifiers end

local function start_joker(key, edition) -- Queue a starting Joker for the run.
    G.GAME.mvp_mut_jokers = G.GAME.mvp_mut_jokers or {}
    G.GAME.mvp_mut_jokers[#G.GAME.mvp_mut_jokers + 1] = { k = key, e = edition }
end

local function start_random_joker(rarity, edition) -- Queue a random starting Joker of a rarity (0 Common, 0.8 Uncommon).
    G.GAME.mvp_mut_random_jokers = G.GAME.mvp_mut_random_jokers or {}
    G.GAME.mvp_mut_random_jokers[#G.GAME.mvp_mut_random_jokers + 1] = { r = rarity, e = edition }
end

local function ban(keys)
    for _, k in ipairs(keys) do G.GAME.banned_keys[k] = true end
end

-- One seeded pick per Ante, stable across reloads: the same Ante always rolls the same value.
local function ante_pick(name, options)
    if not (G.GAME and options and #options > 0) then return nil end
    G.GAME.mvp_mut_rolls = G.GAME.mvp_mut_rolls or {}
    local ante = MVP.plain(G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    local r = G.GAME.mvp_mut_rolls[name]
    if not r or r.ante ~= ante then
        r = { ante = ante, v = pseudorandom_element(options, pseudoseed('mvp_' .. name .. ante)) }
        G.GAME.mvp_mut_rolls[name] = r
    end
    return r.v
end

local SUITS = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }
local RARITY_LABEL = { 'Common', 'Uncommon', 'Rare' }

local function grant_voucher(key) -- Grant a Voucher's run effect at start
    if not (G.GAME and G.P_CENTERS and G.P_CENTERS[key]) then return end
    G.GAME.used_vouchers = G.GAME.used_vouchers or {}
    G.GAME.used_vouchers[key] = true
    G.E_MANAGER:add_event(Event({ func = function()
        G.GAME.starting_voucher_count = (G.GAME.starting_voucher_count or 0) + 1
        Card.apply_to_run(nil, G.P_CENTERS[key])
        return true
    end }))
end

--============================================================
-- CHALLENGES
--============================================================
mut{ key = 'double_boss', name = 'Double Boss', category = 'Challenge',
     text = { 'A {C:attention}Finisher Boss{} every 4 Antes', 'starting at Ante 4' },
     conflicts = { 'marathon' },
     apply = function() mods().mvp_mut_finisher_cadence = true end }

mut{ key = 'double_trouble', name = 'Double Trouble', category = 'Challenge',
     text = { 'All Blinds require {C:attention}2X{} score', '{C:blue}+2{} Hands, {C:red}+2{} Discards' },
     conflicts = { 'mercy_rule', 'go_with_the_flow', 'marathon' },
     apply = function()
         mods().mvp_mut_blind_mult = (mods().mvp_mut_blind_mult or 1) * 2
         sp().hands = (sp().hands or 4) + 2
         sp().discards = (sp().discards or 3) + 2
     end }

mut{ key = 'sudden_death', name = 'Sudden Death', category = 'Challenge',
     text = { 'One hand per Blind', 'Start with {C:dark_edition}Negative{} {C:attention}Dusk{}' },
     conflicts = { 'painted_hands', 'quick_hands', 'double_trouble' },
     apply = function()
         sp().hands = 1
         start_joker('j_dusk', 'negative')
         ban({ 'v_grabber', 'v_nacho_tong', 'j_burglar' })   -- they add Hands back
     end }

mut{ key = 'marathon', name = 'Marathon', category = 'Challenge',
     text = { 'Must beat {C:attention}Ante 10{} to win' },
     conflicts = { 'double_boss', 'double_trouble', 'escalation' },
     apply = function() mods().mvp_mut_win_ante = 10 end }

mut{ key = 'escalation', name = 'Escalation', category = 'Challenge',
     text = { 'Each defeated Blind raises the', 'next Blind by {C:attention}10%{}' },
     conflicts = { 'mercy_rule', 'marathon' },
     apply = function() mods().mvp_mut_escalation = true end }

mut{ key = 'no_small_talk', name = 'No Small Talk', category = 'Challenge',
     text = { '{C:attention}Small Blinds{} are removed' },
     conflicts = { 'big_brother' },
     apply = function() mods().mvp_mut_no_small = true end }

mut{ key = 'big_brother', name = 'Big Brother Isn\'t Watching', category = 'Challenge',
     text = { '{C:attention}Big Blinds{} are removed' },
     conflicts = { 'no_small_talk' },
     apply = function() mods().mvp_mut_no_big = true end }

mut{ key = 'poverty', name = 'Poverty', category = 'Challenge', weight = 0.7,
     text = { 'Start with {C:money}$0{} and {C:dark_edition}Negative{} {C:attention}To Do List{}', 'No {C:attention}interest{}' },
     conflicts = { 'high_roller', 'capitalism', 'penny_pincher' },
     apply = function()
         sp().dollars = 0
         mods().no_interest = true
         start_joker('j_todo_list', 'negative')
         ban({ 'v_seed_money', 'v_money_tree', 'j_to_the_moon' })   -- interest only
     end }

mut{ key = 'reroll_creep', name = 'Reroll Creep', category = 'Challenge',
     text = { 'Each reroll raises future', 'base reroll cost by {C:money}$1{}' },
     conflicts = { 'everything_must_go' },
     apply = function() mods().mvp_mut_reroll_creep = true end }

-- Everything that only cheapens or rewards rerolls is a dead pick, so it is banned.
mut{ key = 'no_rerolls', name = 'No Rerolls', category = 'Challenge',
     text = { 'Cannot {C:green}Reroll{} in the shop' },
     conflicts = { 'reroll_creep', 'reroll_royalty', 'galloping_domino', 'overstocked' },
     apply = function()
         mods().mvp_mut_no_reroll = true
         ban({ 'v_reroll_surplus', 'v_reroll_glut', 'j_chaos', 'j_flash', 'tag_d_six' })
     end }

mut{ key = 'no_refunds', name = 'No Refunds', category = 'Challenge',
     text = { 'Sell value of all items is {C:money}$0{}' },
     conflicts = { 'no_commitments', 'high_roller' },
     apply = function()
         mods().mvp_mut_no_refunds = true
         -- each pays out sell value, which is always $0 here
         ban({ 'j_egg', 'j_gift', 'j_swashbuckler', 'c_temperance', 'j_ceremonial' })
     end }

mut{ key = 'minimalist', name = 'Minimalist', category = 'Challenge', weight = 0.7,
     text = { 'Start with {C:attention}3{} Joker slots' },
     conflicts = { 'collector' },
     apply = function() sp().joker_slots = 3 end }

mut{ key = 'eternal_kingdom', name = 'Eternal Kingdom', category = 'Challenge', weight = 0.5,
     text = { 'All {C:attention}Jokers{} are {C:eternal}Eternal{}' },
     conflicts = { 'rental_market', 'no_commitments' },
     apply = function()
         mods().all_eternal = true
         ban({ 'j_ceremonial' })   -- can't destroy an Eternal Joker
     end }

mut{ key = 'rental_market', name = 'Rental Market', category = 'Challenge', weight = 0.7,
     text = { 'All {C:attention}Jokers{} are {C:rental}Rental{}' },
     conflicts = { 'eternal_kingdom' },
     apply = function() mods().mvp_mut_all_rental = true end }

mut{ key = 'rare_earth', name = 'Rare Earth', category = 'Challenge',
     text = { '{C:red}Rare{} Jokers cannot appear' },
     conflicts = { 'no_common_sense', 'middle_child', 'equality' },
     apply = function()
         mods().mvp_mut_no_rare = true
         ban({ 'tag_rare', 'c_wraith' })   -- they pass a rarity to create_card, skipping poll_rarity
     end }

mut{ key = 'no_common_sense', name = 'No Common Sense', category = 'Challenge',
     text = { '{C:attention}Common{} Jokers cannot appear' },
     conflicts = { 'rare_earth', 'middle_child' },
     apply = function()
         mods().mvp_mut_no_common = true
         ban({ 'j_riff_raff', 'tag_top_up' })   -- they pass a rarity to create_card, skipping poll_rarity
     end }

mut{ key = 'middle_child', name = 'Middle Child Syndrome', category = 'Challenge',
     text = { '{C:attention}Uncommon{} Jokers cannot appear' },
     conflicts = { 'rare_earth', 'no_common_sense' },
     apply = function()
         mods().mvp_mut_no_uncommon = true
         ban({ 'tag_uncommon' })   -- it passes a rarity to create_card, skipping poll_rarity
     end }

mut{ key = 'no_magic', name = 'No Magic', category = 'Challenge', weight = 0.7,
     text = { 'No {C:tarot}Tarot{} cards' },
     conflicts = { 'arcane' },
     bans = { 'Tarot' },
     apply = function() mods().mvp_mut_no_tarots = true end }

mut{ key = 'no_science', name = 'No Science', category = 'Challenge', weight = 0.7,
     text = { 'No {C:planet}Planet{} cards' },
     conflicts = { 'astronomer' },
     bans = { 'Planet' },
     apply = function() mods().mvp_mut_no_planets = true end }

mut{ key = 'go_with_the_flow', name = 'Go with the Flow', category = 'Challenge', weight = 0.7,
     text = { 'No {C:red}Discards{}', 'Start with {C:dark_edition}Negative{} {C:attention}Green Joker{}' },
     conflicts = { 'penny_pincher', 'aggressive', 'double_trouble' },
     apply = function()
         sp().discards = 0
         mods().mvp_mut_ban_discard_vouchers = true
         start_joker('j_green_joker', 'negative')
         ban({ 'j_drunkard', 'j_merry_andy',                     -- they add Discards back
               'j_yorick', 'j_hit_the_road', 'j_faceless', 'j_mail', 'j_trading', 'j_castle',
               'j_burnt', 'j_delayed_grat', 'j_banner',            -- discard triggers, or count the ones left
               'Purple', 'c_medium' })                             -- Purple Seals trigger on discard
     end }

mut{ key = 'toll_road', name = 'Toll Road', category = 'Challenge',
     text = { 'Each {C:red}discard{} costs {C:money}$1{}' },
     conflicts = { 'go_with_the_flow', 'penny_pincher', 'aggressive' },
     apply = function() mods().mvp_mut_toll = 1 end }

mut{ key = 'perishable_world', name = 'Perishable World', category = 'Challenge', weight = 0.7,
     text = { 'All {C:attention}Jokers{} are {C:perishable}Perishable{}' },
     conflicts = { 'eternal_kingdom' },
     apply = function() mods().mvp_mut_all_perishable = true end }

mut{ key = 'wheel_of_misfortune', name = 'Wheel of Misfortune', category = 'Challenge',
     text = { '{C:green}1 in 10{} cards are', 'drawn face down' },
     conflicts = {},
     apply = function() mods().mvp_mut_wheel = 10 end }

mut{ key = 'hooked', name = 'Hooked', category = 'Challenge',
     text = { 'After each hand, {C:attention}2{} random cards', 'in hand are discarded', '{C:attention}+1{} Hand Size' },
     conflicts = {},
     apply = function()
         mods().mvp_mut_hooked = true
         sp().hand_size = (sp().hand_size or 8) + 1
     end }

mut{ key = 'fragile_deck', name = 'Fragile Deck', category = 'Challenge',
     text = { 'Played cards have a {C:green}1 in 12{}', 'chance to be destroyed' },
     conflicts = {},
     apply = function() mods().mvp_mut_fragile = 12 end }

mut{ key = 'speed_run', name = 'Speed Run', category = 'Challenge',
     text = { 'Win at {C:attention}Ante 6{}', 'All Blinds require {C:attention}1.5X{} score' },
     conflicts = { 'marathon', 'double_boss' },
     apply = function()
         mods().mvp_mut_win_ante = 6
         mods().mvp_mut_blind_mult = (mods().mvp_mut_blind_mult or 1) * 1.5
     end }

mut{ key = 'last_in_line', name = 'Last in Line', category = 'Challenge',
     text = { 'Each Ante, one random suit', 'is always drawn {C:attention}last{}' },
     conflicts = {},
     detail = function() return 'This Ante: ' .. (MVP.last_suit() or '-') end,
     apply = function() mods().mvp_mut_last_suit = true end }

mut{ key = 'landlords_due', name = 'Landlord\'s Due', category = 'Challenge',
     text = { 'Each {C:attention}Boss{} defeated makes', 'a random Joker {C:rental}Rental{}' },
     conflicts = { 'rental_market' },
     apply = function() mods().mvp_mut_landlord = true end }

mut{ key = 'rarity_raid', name = 'Rarity Raid', category = 'Challenge',
     text = { 'Each Ante, {C:attention}Boss Blinds{} debuff', 'every Joker of one random rarity' },
     conflicts = {},
     detail = function() return 'This Ante: ' .. (RARITY_LABEL[MVP.raid_rarity() or 0] or '-') end,
     apply = function() mods().mvp_mut_rarity_raid = true end }

mut{ key = 'odds_evens', name = 'Odds & Evens', category = 'Challenge',
     text = { 'Each Ante, the {C:attention}Boss Blind{} debuffs', 'all odd or all even ranks' },
     conflicts = {},
     detail = function()
         local p = MVP.raid_parity()
         return 'This Ante: ' .. (p == 'odd' and 'A, 9, 7, 5, 3' or p == 'even' and '10, 8, 6, 4, 2' or '-')
     end,
     apply = function() mods().mvp_mut_parity = true end }

mut{ key = 'big_brother_watching', name = 'Big Brother Is Watching', category = 'Challenge',
     text = { '{C:green}1 in 3{} Big Blinds are', 'replaced by a {C:attention}Boss Blind{}' },
     conflicts = { 'big_brother' },
     apply = function() mods().mvp_mut_big_boss = 3 end }

-- One suit dead for the run. Wild Cards count as every suit, so they are debuffed too, as
-- under vanilla's suit Bosses. A Checkered Deck has no Clubs or Diamonds to debuff.
for _, s in ipairs({
    { 'heartless',   'Heartless',   'Hearts',   'hearts',   false, 'c_sun' },
    { 'diamondless', 'Diamondless', 'Diamonds', 'diamonds', true,  'c_star' },
    { 'clubless',    'Clubless',    'Clubs',    'clubs',    true,  'c_moon' },
    { 'spadeless',   'Spadeless',   'Spades',   'spades',   false, 'c_world' },
}) do
    local others = { 'smeared_rule' }
    for _, o in ipairs({ 'heartless', 'diamondless', 'clubless', 'spadeless' }) do
        if o ~= s[1] then others[#others + 1] = o end
    end
    mut{ key = s[1], name = s[2], category = 'Challenge',
         text = { 'All {C:' .. s[4] .. '}' .. s[3] .. '{} are debuffed', 'for the whole run' },
         conflicts = others,
         no_decks = s[5] and { 'b_checkered', 'sleeve_casl_checkered' } or nil,
         apply = function()
             mods().mvp_mut_dead_suit = s[3]
             -- Suit Jokers stay. Smeared Joker would spread the debuff to a second suit, and
             -- the suit's own Tarot only makes more dead cards.
             ban({ 'c_lovers', 'j_smeared', s[6] })
         end }
end

mut{ key = 'ox_tax', name = 'Ox Tax', category = 'Challenge',
     text = { 'Playing your most played', 'poker hand costs {C:money}$2{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_ox_tax = 2 end }

mut{ key = 'no_skipping', name = 'No Skipping', category = 'Challenge',
     text = { 'Blinds can\'t be {C:attention}skipped{}' },
     conflicts = {},
     apply = function()
         mods().mvp_mut_no_skip = true
         ban({ 'j_throwback' })   -- scales on skipped Blinds
     end }

mut{ key = 'verdant_pact', name = 'Verdant Pact', category = 'Challenge', weight = 0.7,
     text = { 'In {C:attention}Boss Blinds{}, all cards are', 'debuffed until you sell a Joker' },
     conflicts = { 'eternal_kingdom' },
     apply = function() mods().mvp_mut_verdant = true end }

mut{ key = 'weak_spells', name = 'Weak Spells', category = 'Challenge',
     text = { '{C:tarot}Tarot{} and {C:spectral}Spectral{} cards', 'target {C:attention}1{} fewer card (min 1)' },
     conflicts = {},
     apply = function() mods().mvp_mut_weak_spells = true end }

mut{ key = 'expiration_date', name = 'Expiration Date', category = 'Challenge',
     text = { 'Unused consumables are destroyed', 'at the end of each {C:attention}Ante{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_expiration = true end }

mut{ key = 'deck_weight', name = 'Deck Weight', category = 'Challenge',
     text = { 'Blinds require {C:attention}+1%{} score for', 'each card in deck below {C:attention}52{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_deck_weight = 0.01 end }

mut{ key = 'watered_down', name = 'Watered Down', category = 'Challenge',
     text = { 'Joker values are {C:attention}20%{} lower', '{C:inactive}(odds unchanged)' },
     conflicts = { 'powerhouse' },
     apply = function() mods().mvp_mut_joker_scale = 0.8 end }

mut{ key = 'stale_cards', name = 'Stale Cards', category = 'Challenge',
     text = { 'Cards played this Ante', 'are drawn {C:attention}last{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_stale = true end }

--============================================================
-- BOONS
--============================================================
mut{ key = 'high_roller', name = 'High Roller', category = 'Boon', weight = 0.7,
     text = { 'Start with {C:money}$50{}', 'Shop prices {C:attention}doubled{}' },
     conflicts = { 'poverty', 'capitalism' },
     apply = function()
         sp().dollars = 50
         mods().mvp_mut_price_mult = 2
     end }

mut{ key = 'mercy_rule', name = 'Mercy Rule', category = 'Boon',
     text = { '{C:attention}Bosses{} need {C:attention}50%{} less score', '{C:inactive}No Boss cash reward' },
     conflicts = { 'double_trouble', 'escalation' },
     apply = function() mods().mvp_mut_mercy = true end }

mut{ key = 'everything_must_go', name = 'Everything Must Go', category = 'Boon', weight = 0.7,
     text = { 'Everything is {C:attention}50%{} cheaper', '{C:red}-1{} Joker slot' },
     conflicts = { 'reroll_creep', 'high_roller', 'no_refunds', 'minimalist', 'collector', 'card_pulls' },
     apply = function()
         mods().mvp_mut_price_mult = 0.5
         sp().joker_slots = math.max(1, (sp().joker_slots or 5) - 1)
     end }

mut{ key = 'collector', name = 'Collector', category = 'Boon',
     text = { 'Maximum {C:attention}7{} Joker slots', 'Jokers cost {C:money}+$2{} each' },
     conflicts = { 'minimalist' },
     apply = function()
         sp().joker_slots = 7
         mods().mvp_mut_joker_surcharge = 2
     end }

mut{ key = 'heavy_deck', name = 'Heavy Deck', category = 'Boon', weight = 0.7,
     text = { 'Start with {C:attention}+48{} randomly', '{C:attention}enhanced{} cards' },
     conflicts = { 'thin_deck', 'broken_deck', 'lucky_seven' },
     apply = function()
         mods().mvp_mut_deck_delta = 48
         mods().mvp_mut_all_enhanced = true
     end }

mut{ key = 'limited_edition', name = 'Limited Edition', category = 'Boon',
     text = { '{C:attention}10{} random starting cards', 'gain a random {C:dark_edition}edition{}' },
     conflicts = { 'broken_deck' },
     apply = function() mods().mvp_mut_random_editions = 10 end }

mut{ key = 'painted_hands', name = 'Painted Hands', category = 'Boon', weight = 0.7,
     text = { '{C:attention}+3{} Hand Size', '{C:blue}-2{} Hands' },
     conflicts = { 'quick_hands', 'sudden_death' },
     apply = function()
         sp().hand_size = (sp().hand_size or 8) + 3
         sp().hands = math.max(1, (sp().hands or 4) - 2)
     end }

mut{ key = 'arcane', name = 'Arcane', category = 'Boon',
     text = { 'Start with the {C:tarot}Tarot Merchant{}', '{C:attention}Voucher{}' },
     conflicts = { 'astronomer', 'no_magic' },
     apply = function() grant_voucher('v_tarot_merchant') end }

mut{ key = 'astronomer', name = 'Astronomer', category = 'Boon',
     text = { 'Start with the {C:planet}Planet Merchant{}', '{C:attention}Voucher{}' },
     conflicts = { 'arcane', 'no_science' },
     apply = function() grant_voucher('v_planet_merchant') end }

mut{ key = 'chip_focus', name = 'Chip Focus', category = 'Boon',
     text = { '{C:chips}Chip{} values doubled', '{C:mult}Mult{} halved' },
     conflicts = { 'mult_focus' },
     apply = function() mods().mvp_mut_score_focus = 'chips' end }

mut{ key = 'mult_focus', name = 'Mult Focus', category = 'Boon',
     text = { '{C:mult}Mult{} values doubled', '{C:chips}Chips{} halved' },
     conflicts = { 'chip_focus' },
     apply = function() mods().mvp_mut_score_focus = 'mult' end }

mut{ key = 'penny_pincher', name = 'Penny Pincher', category = 'Boon',
     text = { 'Remaining {C:red}Discards{} give {C:money}$1{} each' },
     conflicts = { 'go_with_the_flow' },
     apply = function() mods().money_per_discard = 1 end }

mut{ key = 'treasure_hunter', name = 'Treasure Hunter', category = 'Boon',
     text = { 'Beating a {C:attention}Boss{} also rewards', 'a {C:attention}Voucher{}. Blind cash reward {C:money}halved{}' },
     conflicts = { 'double_boss' },
     apply = function() mods().mvp_mut_treasure = true end }

mut{ key = 'lucky_seven', name = 'Lucky Seven', category = 'Boon',
     text = { 'Starting {C:attention}7s{} are {C:attention}Lucky{}', 'with a {C:red}Red Seal{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_lucky_sevens = true end }

mut{ key = 'opening_act', name = 'Opening Act', category = 'Boon',
     text = { 'Start with {C:attention}2{} random', '{C:blue}Common{} Jokers' },
     conflicts = { 'no_common_sense' },
     apply = function() start_random_joker(0); start_random_joker(0) end }

mut{ key = 'polychrome_debut', name = 'Polychrome Debut', category = 'Boon',
     text = { 'Start with a random', '{C:dark_edition}Polychrome{} {C:green}Uncommon{} Joker' },
     conflicts = { 'middle_child' },
     apply = function() start_random_joker(0.8, 'polychrome') end }

mut{ key = 'voucher_starter', name = 'Voucher Starter', category = 'Boon',
     text = { 'Start with {C:attention}2{} random', 'tier-1 {C:attention}Vouchers{}' },
     conflicts = { 'fair_play' },
     apply = function() mods().mvp_mut_voucher_starter = 2 end }

mut{ key = 'tag_team', name = 'Tag Team', category = 'Boon',
     text = { 'Start with {C:attention}2{} random {C:attention}Tags{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_tag_team = 2 end }

mut{ key = 'reroll_royalty', name = 'Reroll Royalty', category = 'Boon',
     text = { 'The first {C:green}Reroll{} in', 'each shop is free' },
     conflicts = { 'galloping_domino' },
     apply = function() mods().mvp_mut_free_reroll = true end }

mut{ key = 'encore', name = 'Encore', category = 'Boon',
     text = { '{C:blue}+1{} Hand during', '{C:attention}Boss Blinds{}' },
     conflicts = { 'sudden_death' },
     apply = function() mods().mvp_mut_boss_hand = 1 end }

mut{ key = 'second_wind', name = 'Second Wind', category = 'Boon',
     text = { '{C:red}+1{} Discard during', '{C:attention}Boss Blinds{}' },
     conflicts = { 'go_with_the_flow' },
     apply = function() mods().mvp_mut_boss_discard = 1 end }

mut{ key = 'rocket_fuel', name = 'Rocket Fuel', category = 'Boon',
     text = { 'Blind payout {C:money}+$1{} for', 'every {C:attention}Boss{} defeated' },
     conflicts = {},
     apply = function() mods().mvp_mut_rocket = true end }

mut{ key = 'gift_wrapped', name = 'Gift Wrapped', category = 'Boon',
     text = { 'Jokers and consumables gain', '{C:money}$1{} sell value each round' },
     conflicts = { 'no_refunds' },
     apply = function() mods().mvp_mut_gift = 1 end }

mut{ key = 'hikers_trail', name = 'Hiker\'s Trail', category = 'Boon',
     text = { 'Played cards permanently', 'gain {C:chips}+2{} Chips when scored' },
     conflicts = {},
     apply = function() mods().mvp_mut_hiker = 2 end }

mut{ key = 'leveled_up', name = 'Leveled Up', category = 'Boon',
     text = { 'Start with {C:attention}2{} random', 'poker hands at {C:attention}level 3{}' },
     conflicts = {},
     apply = function() mods().mvp_mut_leveled_up = 2 end }

mut{ key = 'spectral_visit', name = 'Spectral Visit', category = 'Boon',
     text = { 'Start with a random', '{C:spectral}Spectral{} card' },
     conflicts = {},
     apply = function() mods().mvp_mut_spectral_visit = true end }

mut{ key = 'credit_line', name = 'Credit Line', category = 'Boon',
     text = { 'Go up to {C:red}-$10{} in debt' },
     conflicts = {},
     apply = function() G.GAME.bankrupt_at = (G.GAME.bankrupt_at or 0) - 10 end }

mut{ key = 'showmans_stage', name = 'Showman\'s Stage', category = 'Boon',
     text = { 'Duplicate Jokers and', 'consumables can appear' },
     conflicts = {},
     apply = function() mods().mvp_mut_showman = true end }

mut{ key = 'powerhouse', name = 'Powerhouse', category = 'Boon',
     text = { 'Joker values are {C:attention}25%{} higher', '{C:inactive}(odds unchanged)' },
     conflicts = { 'watered_down' },
     apply = function() mods().mvp_mut_joker_scale = 1.25 end }

-- Doubles the game's probabilities the way Oops! All 6s does. The mutations' own odds
-- (Fragile Deck, Wheel of Misfortune, Big Brother Is Watching, Fabled Shop) are fixed.
mut{ key = 'favorable_odds', name = 'Favorable Odds', category = 'Boon',
     text = { 'All {C:green}probabilities{} are doubled', '{C:inactive}(mutation odds unchanged)' },
     conflicts = {},
     apply = function()
         G.GAME.probabilities = G.GAME.probabilities or { normal = 1 }
         G.GAME.probabilities.normal = (G.GAME.probabilities.normal or 1) * 2
     end }

--============================================================
-- TWISTS
--============================================================
mut{ key = 'card_pulls', name = 'Card Pulls', category = 'Twist', weight = 0.7,
     text = { 'Everything in the shop costs {C:attention}2X{}', '{C:attention}Booster Packs{} cost {C:attention}50%{} less' },
     conflicts = { 'clearance_rack', 'everything_must_go' },
     apply = function()
         mods().mvp_mut_nonpack_mult = 2
         mods().mvp_mut_pack_price_mult = 0.5
     end }

-- Seed Money sets the interest cap to $50 outright (card.lua:2279), which this already gives,
-- and Money Tree needs it to appear.
mut{ key = 'capitalism', name = 'Capitalism', category = 'Twist', weight = 0.7,
     text = { '{C:money}Starting cash{}, {C:attention}interest cap{} and', 'shop prices are all {C:attention}doubled{}' },
     conflicts = { 'poverty', 'high_roller', 'everything_must_go', 'card_pulls' },
     apply = function()
         sp().dollars = (MVP.plain(sp().dollars) or 4) * 2
         G.GAME.interest_cap = (G.GAME.interest_cap or 25) * 2
         mods().mvp_mut_price_mult = 2
         ban({ 'v_seed_money', 'v_money_tree' })
     end }

mut{ key = 'equality', name = 'Equality', category = 'Twist',
     text = { 'Jokers appear in {C:attention}random{} rarities' },
     conflicts = { 'rare_earth', 'no_common_sense', 'middle_child' },
     apply = function() mods().mvp_mut_random_rarity = true end }

mut{ key = 'no_commitments', name = 'No Commitments', category = 'Twist',
     text = { 'Leftmost {C:attention}Joker{} auto-sells for full', 'value each round. No {C:eternal}Eternal{} Jokers' },
     conflicts = { 'no_refunds' },
     apply = function() mods().mvp_mut_autosell_leftmost = true end }

mut{ key = 'thin_deck', name = 'Thin Deck', category = 'Twist', weight = 0.7,
     text = { 'Start with {C:attention}20{} random plain cards' },
     conflicts = { 'heavy_deck', 'broken_deck' },
     apply = function() mods().mvp_mut_deck_target = 20 end }

mut{ key = 'broken_deck', name = 'Broken Deck', category = 'Twist',
     text = { '{C:attention}10{} random starting cards', 'gain a random {C:attention}seal{}' },
     conflicts = { 'thin_deck', 'heavy_deck' },
     apply = function() mods().mvp_mut_random_seals = 10 end }

mut{ key = 'rankless', name = 'Rankless', category = 'Twist', weight = 0.7,
     text = { '{C:attention}Number cards{} become {C:attention}Stone Cards{}' },
     conflicts = { 'heavy_deck', 'thin_deck', 'courtless', 'wild_deck' },
     apply = function() mods().mvp_mut_numbers_to_stone = true end }

mut{ key = 'courtless', name = 'Courtless', category = 'Twist', weight = 0.7,
     text = { '{C:attention}Number cards{} removed', '{C:attention}Face cards{} tripled' },
     conflicts = { 'heavy_deck', 'thin_deck', 'rankless', 'wild_deck' },
     apply = function()
         mods().mvp_mut_no_numbers = true
         mods().mvp_mut_triple_faces = true
     end }

mut{ key = 'wild_deck', name = 'Wild Deck', category = 'Twist', weight = 0.7,
     text = { 'All cards are {C:attention}Wild{}' },
     conflicts = { 'heavy_deck' },
     apply = function() mods().mvp_mut_wild_deck = true end }

mut{ key = 'quick_hands', name = 'Quick Hands', category = 'Twist',
     text = { '{C:blue}+3{} Hands', '{C:attention}-2{} Hand Size' },
     conflicts = { 'painted_hands' },
     apply = function()
         sp().hands = (sp().hands or 4) + 3
         sp().hand_size = math.max(3, (sp().hand_size or 8) - 2)
     end }

mut{ key = 'very_merry', name = 'Very Merry', category = 'Twist',
     text = { '{C:red}+5{} Discards', '{C:blue}-2{} Hands' },
     conflicts = { 'go_with_the_flow', 'sudden_death' },
     apply = function()
         sp().discards = (sp().discards or 3) + 5
         sp().hands = math.max(1, (sp().hands or 4) - 2)
     end }

mut{ key = 'hoarder', name = 'Hoarder', category = 'Twist',
     text = { 'Cards held in hand gain', '{C:mult}+1{} Mult each round' },
     conflicts = { 'aggressive' },
     apply = function() mods().mvp_mut_hoarder = true end }

mut{ key = 'aggressive', name = 'Aggressive', category = 'Twist',
     text = { 'Unused {C:blue}Hands{} give no money', 'Unused {C:red}Discards{} give {C:money}$1{} each' },
     conflicts = { 'hoarder', 'go_with_the_flow' },
     apply = function()
         mods().no_extra_hand_money = true  
         mods().money_per_discard = 1   
     end }

mut{ key = 'chaos_theory', name = 'Chaos Theory', category = 'Twist',
     text = { 'Hand types\' base {C:chips}Chips{} and', '{C:mult}Mult{} are randomized' },
     conflicts = {},
     apply = function() mods().mvp_mut_chaos_theory = true end }

mut{ key = 'clearance_rack', name = 'Clearance Rack', category = 'Twist', weight = 0.7,
     text = { 'Shops have {C:attention}one fewer{} pack', 'Shop prices {C:money}-$1{}' },
     conflicts = { 'overstocked', 'high_roller', 'capitalism' },
     apply = function()
         mods().mvp_mut_fewer_packs = true
         mods().mvp_mut_price_flat = (mods().mvp_mut_price_flat or 0) - 1
     end }

mut{ key = 'overstocked', name = 'Overstocked', category = 'Twist',
     text = { 'Shops have {C:attention}one extra{} of each item', 'Rerolls cost {C:money}+$2{}' },
     conflicts = { 'clearance_rack', 'high_roller', 'capitalism' },
     apply = function()
         mods().mvp_mut_more_stock = true
         mods().mvp_mut_reroll_surcharge = 2
     end }

-- House rules: a Joker's effect for the whole run. The Joker itself would be a dead pick.
mut{ key = 'four_fingers_rule', name = 'Four Fingers Rule', category = 'Twist', weight = 0.7,
     text = { 'Flushes and Straights can be', 'made with {C:attention}4{} cards' },
     conflicts = {},
     apply = function() mods().mvp_mut_four_fingers = true; ban({ 'j_four_fingers' }) end }

mut{ key = 'shortcut_rule', name = 'Shortcut Rule', category = 'Twist', weight = 0.7,
     text = { 'Straights can skip', '{C:attention}one{} rank' },
     conflicts = {},
     apply = function() mods().mvp_mut_shortcut = true; ban({ 'j_shortcut' }) end }

mut{ key = 'smeared_rule', name = 'Smeared Rule', category = 'Twist',
     text = { '{C:hearts}Hearts{}/{C:diamonds}Diamonds{} and {C:spades}Spades{}/{C:clubs}Clubs{}', 'count as the same suit' },
     conflicts = {},
     apply = function() mods().mvp_mut_smeared = true; ban({ 'j_smeared' }) end }

mut{ key = 'splash_rule', name = 'Splash Rule', category = 'Twist',
     text = { 'Every {C:attention}played card{} scores' },
     conflicts = {},
     apply = function() mods().mvp_mut_splash = true; ban({ 'j_splash' }) end }

mut{ key = 'deck_medley', name = 'Deck Medley', category = 'Twist',
     text = { 'Also gain the perk of a second', 'random {C:attention}vanilla deck{}' },
     conflicts = {},
     detail = function()
         local k = G.GAME and G.GAME.mvp_mut_medley
         return 'Second deck: ' .. ((k and G.P_CENTERS[k] and G.P_CENTERS[k].name) or '-')
     end,
     apply = function() mods().mvp_mut_medley = true end }

mut{ key = 'mega_packs', name = 'Mega Packs', category = 'Twist',
     text = { 'All {C:attention}Booster Packs{} are {C:attention}Mega{}', 'Packs cost {C:attention}2X{}' },
     conflicts = { 'card_pulls' },
     apply = function() mods().mvp_mut_mega_packs = true end }

mut{ key = 'boss_rush', name = 'Boss Rush', category = 'Twist', weight = 0.7,
     text = { 'Small and Big Blinds give no cash', '{C:attention}Boss Blinds{} give {C:money}$10{}' },
     conflicts = { 'mercy_rule', 'treasure_hunter' },
     apply = function() mods().mvp_mut_boss_rush = 10 end }

-- The Ghost Deck and sleeve already do this.
mut{ key = 'ghost_shop', name = 'Ghost Shop', category = 'Twist',
     text = { '{C:spectral}Spectral{} cards can', 'appear in the shop' },
     conflicts = {},
     no_decks = { 'b_ghost', 'sleeve_casl_ghost' },
     apply = function() mods().mvp_mut_spectral_rate = 2 end }

mut{ key = 'fabled_shop', name = 'Fabled Shop', category = 'Twist',
     text = { '{C:legendary}Legendary{} Jokers can appear in', 'the shop ({C:green}1 in 100{}). {C:red}-1{} Joker slot' },
     conflicts = { 'minimalist', 'collector' },
     apply = function()
         mods().mvp_mut_fabled = 100
         sp().joker_slots = math.max(1, (sp().joker_slots or 5) - 1)
     end }

-- The flat cost overwrites every discount, so the reroll Vouchers and the D6 Tag are dead.
-- Free rerolls (Chaos the Clown) still skip it.
mut{ key = 'galloping_domino', name = 'Galloping Domino', category = 'Twist',
     text = { 'Rerolls always cost {C:money}$7{}' },
     conflicts = { 'reroll_creep', 'overstocked', 'reroll_royalty' },
     apply = function()
         mods().mvp_mut_flat_reroll = 7
         ban({ 'v_reroll_surplus', 'v_reroll_glut', 'tag_d_six' })
     end }

mut{ key = 'fair_play', name = 'Fair Play', category = 'Twist', weight = 0.25,
     text = { '{C:attention}Vouchers{} never appear in the shop', '{C:blue}+1{} Hand, {C:red}+1{} Discard' },
     conflicts = { 'treasure_hunter', 'voucher_starter', 'overstocked', 'sudden_death', 'go_with_the_flow' },
     apply = function()
         mods().mvp_mut_fair_play = true
         sp().vouchers_in_shop = 0
         sp().hands = (sp().hands or 4) + 1
         sp().discards = (sp().discards or 3) + 1
         ban({ 'tag_voucher' })
     end }

--============================================================
-- ROLLING
--============================================================

local function build_conflicts()
    local cm = {}
    for _, mt in ipairs(MVP.MUTATIONS) do cm[mt.key] = cm[mt.key] or {} end
    for _, mt in ipairs(MVP.MUTATIONS) do
        for _, ck in ipairs(mt.conflicts or {}) do
            cm[mt.key][ck] = true
            if cm[ck] then cm[ck][mt.key] = true end
        end
    end
    return cm
end

function MVP.roll_mutations(n)
    n = math.max(0, math.min(8, math.floor((n or 0) + 0.5)))
    if n == 0 then return {} end

    local by_cat = { Challenge = {}, Boon = {}, Twist = {} }
    for _, mt in ipairs(MVP.MUTATIONS) do
        if by_cat[mt.category] then by_cat[mt.category][#by_cat[mt.category] + 1] = mt end
    end
    for _, list in pairs(by_cat) do
        table.sort(list, function(a, b) return a.key < b.key end)
    end

    local cm = build_conflicts()
    local chosen, taken, blocked = {}, {}, {}

    local function pick_from(cat)
        local candidates = {}
        for _, mt in ipairs(by_cat[cat] or {}) do
            if not taken[mt.key] and not blocked[mt.key] then candidates[#candidates + 1] = mt end
        end
        local total = 0
        for _, mt in ipairs(candidates) do total = total + (mt.weight or 1) end
        if total <= 0 then return false end
        local roll, mt = math.random() * total, nil
        for _, c in ipairs(candidates) do
            roll = roll - (c.weight or 1)
            if (c.weight or 1) > 0 then mt = c end   -- last positive-weight candidate absorbs float error
            if roll < 0 and mt == c then break end
        end
        taken[mt.key] = true
        chosen[#chosen + 1] = mt.key
        for ck in pairs(cm[mt.key] or {}) do blocked[ck] = true end
        return true
    end

    local cats = { 'Challenge', 'Boon', 'Twist' }
    for i = 1, n do
        local want = (i == 1 and 'Challenge') or (i == 2 and 'Boon') or cats[math.random(1, 3)]
        if not pick_from(want) then
            for _, c2 in ipairs(cats) do 	-- Fall back through the other categories so the slot still fills.
                if c2 ~= want and pick_from(c2) then break end
            end
        end
    end
    return chosen
end

function MVP.apply_mutations()
    if not (G.GAME and G.GAME.mvp_mutations) then return end
    for _, key in ipairs(G.GAME.mvp_mutations) do
        local mm = MVP.MUT_BY_KEY[key]
        if mm and mm.apply then
            local ok, err = pcall(mm.apply) -- One bad mutation must not take the whole run down with it.
            if not ok then
                sendWarnMessage('Mutation ' .. key .. ' failed to apply: ' .. tostring(err), 'MoarVanillaPlease')
            end
        end
    end
end

function MVP.mutation_list()
    local out = {}
    for _, key in ipairs((G.GAME and G.GAME.mvp_mutations) or {}) do
        local mm = MVP.MUT_BY_KEY[key]
        if mm then out[#out + 1] = mm end
    end
    return out
end

--============================================================
-- HOOKS
--============================================================
local function mm(id) return G.GAME and G.GAME.modifiers and G.GAME.modifiers[id] end

local mvp_mut_blind_amount = get_blind_amount
function get_blind_amount(ante)
    local base = mvp_mut_blind_amount(ante)
    local mult = 1
    if mm('mvp_mut_blind_mult') then mult = mult * mm('mvp_mut_blind_mult') end
    if mm('mvp_mut_escalation') then
        mult = mult * (1 + 0.10 * (G.GAME.mvp_mut_blinds_beaten or 0))
    end
    if mm('mvp_mut_deck_weight') and G.playing_cards then   -- Deck Weight
        mult = mult * (1 + mm('mvp_mut_deck_weight') * math.max(0, 52 - #G.playing_cards))
    end
    if mult == 1 then return base end
    return (to_big and to_big(base) or base) * mult
end

local mvp_mut_set_blind = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    mvp_mut_set_blind(self, blind, reset, silent)
    if reset or not blind then return end
    local dollars_changed = false
    if mm('mvp_mut_mercy') and self.boss then
        if self.chips then
            self.chips = (to_big and to_big(self.chips) or self.chips) * 0.5
            self.chip_text = number_format(self.chips)
        end
        self.dollars = 0
        dollars_changed = true
    end
    if mm('mvp_mut_treasure') then
        self.dollars = math.max(0, math.floor((MVP.plain(self.dollars) or 0) / 2))
        dollars_changed = true
    end
    if mm('mvp_mut_boss_rush') then
        self.dollars = self.boss and mm('mvp_mut_boss_rush') or 0
        dollars_changed = true
    end
    if mm('mvp_mut_rocket') and (G.GAME.mvp_mut_bosses_beaten or 0) > 0 then   -- Rocket Fuel
        self.dollars = (MVP.plain(self.dollars) or 0) + G.GAME.mvp_mut_bosses_beaten
        dollars_changed = true
    end
    if self.boss then
        if mm('mvp_mut_boss_hand') then ease_hands_played(mm('mvp_mut_boss_hand')) end      -- Encore
        if mm('mvp_mut_boss_discard') then ease_discard(mm('mvp_mut_boss_discard')) end     -- Second Wind
        -- Verdant Pact arms only when a Joker can be sold, or the Blind could not be won.
        if mm('mvp_mut_verdant') and G.jokers then
            for _, j in ipairs(G.jokers.cards) do
                if not (j.ability and j.ability.eternal) then G.GAME.mvp_mut_verdant_on = true break end
            end
            if G.GAME.mvp_mut_verdant_on then
                for _, c in ipairs(G.playing_cards or {}) do SMODS.recalc_debuff(c) end
            end
        end
    end
    if dollars_changed then
        self.sound_pings = self.dollars + 2
        if G.GAME.current_round then
            G.GAME.current_round.dollars_to_be_earned =
                self.dollars > 0 and string.rep(localize('$'), self.dollars) or ''
        end
    end
end

local function hidden(slot)
    return (slot == 'Small' and mm('mvp_mut_no_small')) or (slot == 'Big' and mm('mvp_mut_no_big'))
end

-- blind_on_deck must name a blind the select screen built a box for, or nothing is clickable.
local function settle_blind_on_deck(select_next)
    local bs = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    local deck = G.GAME and G.GAME.blind_on_deck
    if not (bs and deck and hidden(deck)) then return end
    bs[deck] = 'Hide'
    local nxt = (deck == 'Small' and not hidden('Big')) and 'Big' or 'Boss'
    if select_next then bs[nxt] = 'Select' end
    G.GAME.blind_on_deck = nxt
end

local function apply_blind_hides()
    local bs = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    if not bs then return end
    if mm('mvp_mut_no_small') then bs.Small = 'Hide' end
    if mm('mvp_mut_no_big') then bs.Big = 'Hide' end
    settle_blind_on_deck(false)
end

local mvp_mut_raw_new_boss = get_new_boss
local mvp_mut_regular_roll = false

-- A Boss for the Big slot: never a Finisher, whatever the Ante. Another mod's cadence can
-- still hand one back, and then the slot keeps its Big Blind.
local function regular_boss()
    local saved = G.GAME.win_ante
    G.GAME.win_ante = 1e9
    mvp_mut_regular_roll = true
    local ok, boss = pcall(mvp_mut_raw_new_boss)
    mvp_mut_regular_roll = false
    G.GAME.win_ante = saved
    local blind = ok and boss and G.P_BLINDS[boss]
    if not blind or (blind.boss and blind.boss.showdown) then return nil end
    return boss
end

local mvp_mut_reset_blinds = reset_blinds
function reset_blinds()
    local bs = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    local new_ante = bs and bs.Boss == 'Defeated'
    mvp_mut_reset_blinds()
    if new_ante and mm('mvp_mut_big_boss') and G.GAME.round_resets.blind_choices then   -- Big Brother Is Watching
        local choices = G.GAME.round_resets.blind_choices
        choices.Big = 'bl_big'
        if pseudorandom('mvp_mut_big_boss') < 1 / mm('mvp_mut_big_boss') then
            choices.Big = regular_boss() or 'bl_big'
        end
    end
    apply_blind_hides()
end

-- A Boss in the Big slot is still the Big Blind: end_round advances the Ante on
-- get_type() == 'Boss' (state_events.lua:128), which would skip the real Boss.
local mvp_mut_get_type = Blind.get_type
function Blind:get_type()
    local t = mvp_mut_get_type(self)
    if t == 'Boss' and mm('mvp_mut_big_boss') and G.GAME.blind_on_deck == 'Big' then return 'Big' end
    return t
end

-- Vanilla skip steps Small -> Big -> Boss without checking for 'Hide': skipping Small under
-- Big Brother lands on the hidden Big Blind, which has no box on screen, and softlocks.
local mvp_mut_skip_blind = G.FUNCS.skip_blind
G.FUNCS.skip_blind = function(e)
    if mm('mvp_mut_no_skip') then return end   -- No Skipping
    mvp_mut_skip_blind(e)
    settle_blind_on_deck(true)
end

-- A button that can't be used looks like Discard with none left (can_discard): grey and
-- unclickable. hover = false also drops the hover shade, as vanilla does for the Skip
-- button of a Blind that isn't up next.
local function grey_out(e)
    e.config.button = nil
    e.config.hover = false
    e.config.colour = G.C.UI.BACKGROUND_INACTIVE
end

-- No Skipping: the Skip button's per-frame func is its hover proxy, so it is greyed out
-- there. blind_choice_handler paints it red when its Blind comes up; this runs every
-- frame after that. The proxy itself still shows the Tag's tooltip on hover.
local mvp_mut_hover_tag_proxy = G.FUNCS.hover_tag_proxy
G.FUNCS.hover_tag_proxy = function(e)
    mvp_mut_hover_tag_proxy(e)
    if mm('mvp_mut_no_skip') and e and e.config then grey_out(e) end
end

-- No Rerolls: the Reroll button is greyed out the same way, and reroll_shop is guarded for
-- any other route in (the controller shortcut, other mods).
local mvp_mut_can_reroll = G.FUNCS.can_reroll
G.FUNCS.can_reroll = function(e)
    mvp_mut_can_reroll(e)
    if mm('mvp_mut_no_reroll') and e and e.config then grey_out(e) end
end

local mvp_mut_reroll_shop = G.FUNCS.reroll_shop
G.FUNCS.reroll_shop = function(e)
    if mm('mvp_mut_no_reroll') then return end
    return mvp_mut_reroll_shop(e)
end

-- Double Boss: a Finisher every 4th Ante. `roll` is whichever Boss roll is being wrapped.
local function finisher_cadence(roll, ...)
    if not mvp_mut_regular_roll and mm('mvp_mut_finisher_cadence') and G.GAME.round_resets and G.GAME.win_ante then
        local a = G.GAME.round_resets.ante
        if a >= 4 and a % 4 == 0 and a % G.GAME.win_ante ~= 0 then
            local saved = G.GAME.win_ante
            G.GAME.win_ante = 4
            local boss = roll(...)
            G.GAME.win_ante = saved
            return boss
        end
    end
    return roll(...)
end

local mvp_mut_get_new_boss = get_new_boss
function get_new_boss()
    return finisher_cadence(mvp_mut_get_new_boss)
end

-- Steamodded 26.x rolls each Ante's Boss through SMODS.get_new_blind and keeps get_new_boss
-- for the Boss reroll and the Boss Tag, so the cadence sits on both.
if SMODS.get_new_blind then
    local mvp_mut_get_new_blind = SMODS.get_new_blind
    function SMODS.get_new_blind(blind_type, ...)
        if blind_type ~= nil and blind_type ~= 'boss' then return mvp_mut_get_new_blind(blind_type, ...) end
        return finisher_cadence(mvp_mut_get_new_blind, blind_type, ...)
    end
end

local mvp_mut_calc_reroll = calculate_reroll_cost
function calculate_reroll_cost(skip_increment)
    mvp_mut_calc_reroll(skip_increment)
    local cr = G.GAME and G.GAME.current_round
    if not cr then return end
    -- Vanilla passes skip_increment = falsy only after a paid reroll.
    if mm('mvp_mut_reroll_creep') and not skip_increment then
        G.GAME.mvp_mut_reroll_creep = (G.GAME.mvp_mut_reroll_creep or 0) + 1
    end
    if (MVP.plain(cr.free_rerolls) or 0) > 0 then return end
    local extra = (mm('mvp_mut_reroll_surcharge') or 0) + (mm('mvp_mut_reroll_creep') and G.GAME.mvp_mut_reroll_creep or 0)
    if extra ~= 0 then
        cr.reroll_cost = (MVP.plain(cr.reroll_cost) or 0) + extra
    end
    if mm('mvp_mut_flat_reroll') then cr.reroll_cost = mm('mvp_mut_flat_reroll') end   -- Galloping Domino
end

local mvp_mut_eval_round = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function(...)
    if mm('mvp_mut_escalation') then
        G.GAME.mvp_mut_blinds_beaten = (G.GAME.mvp_mut_blinds_beaten or 0) + 1
    end
    if mm('mvp_mut_hoarder') and G.hand then
        for _, c in ipairs(G.hand.cards) do
            if c.ability then
                c.ability.perma_h_mult = (MVP.plain(c.ability.perma_h_mult) or 0) + 1
            end
        end
    end
    if mm('mvp_mut_treasure') and G.GAME.blind and G.GAME.blind.boss
        and add_tag and Tag and G.P_TAGS and G.P_TAGS.tag_voucher then
        add_tag(Tag('tag_voucher'))
    end

    if mm('mvp_mut_autosell_leftmost') and G.jokers and G.jokers.cards[1] then
        local c = G.jokers.cards[1]
        if ease_dollars then ease_dollars(MVP.plain(c.cost) or 0) end   
        c:start_dissolve()
    end

    if mm('mvp_mut_gift') then   -- Gift Wrapped
        for _, area in ipairs({ G.jokers, G.consumeables }) do
            for _, c in ipairs((area and area.cards) or {}) do
                c.ability.extra_value = (MVP.plain(c.ability.extra_value) or 0) + mm('mvp_mut_gift')
                c:set_cost()
            end
        end
    end
    G.GAME.mvp_mut_verdant_on = nil
    -- Boss-only debuffs end with the Blind. Vanilla's reset pass skips Jokers (blind.lua:236).
    if mm('mvp_mut_rarity_raid') or mm('mvp_mut_parity') or mm('mvp_mut_verdant') then
        for _, area in ipairs({ G.jokers, G.hand, G.deck, G.discard }) do
            for _, c in ipairs((area and area.cards) or {}) do SMODS.recalc_debuff(c) end
        end
    end
    if G.GAME.blind and G.GAME.blind.boss and G.GAME.blind_on_deck == 'Boss' then   -- end of the Ante
        G.GAME.mvp_mut_bosses_beaten = (G.GAME.mvp_mut_bosses_beaten or 0) + 1
        if mm('mvp_mut_landlord') and G.jokers then   -- Landlord's Due
            local pool = {}
            for _, j in ipairs(G.jokers.cards) do
                if not j.ability.rental and j.config.center.rental_compat ~= false then pool[#pool + 1] = j end
            end
            local j = pseudorandom_element(pool, pseudoseed('mvp_mut_landlord'))
            if j then j:set_rental(true); j:juice_up() end
        end
        if mm('mvp_mut_expiration') and G.consumeables then   -- Expiration Date
            for _, c in ipairs(G.consumeables.cards) do c:start_dissolve() end
        end
    end
    return mvp_mut_eval_round(...)
end

local mvp_mut_set_cost = Card.set_cost  -- Shop prices for High Roller / Clearance Sale / Card Pulls / Collector / No Refunds.
function Card:set_cost()
    mvp_mut_set_cost(self)
    local any = mm('mvp_mut_price_mult') or mm('mvp_mut_nonpack_mult')
        or mm('mvp_mut_pack_price_mult') or mm('mvp_mut_joker_surcharge')
        or mm('mvp_mut_price_flat') or mm('mvp_mut_no_refunds') or mm('mvp_mut_mega_packs')
    if not any then return end

    local set = self.ability and self.ability.set
    local c = MVP.plain(self.cost) or 0
    -- 0 is a flag (Coupon, Astronomer) and Rentals are pinned to $1 by vanilla; neither is ours to move.
    if c > 0 and not (self.ability and self.ability.rental) then
        if mm('mvp_mut_price_mult') then c = c * mm('mvp_mut_price_mult') end
        if mm('mvp_mut_nonpack_mult') and set ~= 'Booster' then c = c * mm('mvp_mut_nonpack_mult') end
        if mm('mvp_mut_pack_price_mult') and set == 'Booster' then c = c * mm('mvp_mut_pack_price_mult') end
        if mm('mvp_mut_mega_packs') and set == 'Booster' then c = c * 2 end
        if mm('mvp_mut_joker_surcharge') and set == 'Joker' then c = c + mm('mvp_mut_joker_surcharge') end
        if mm('mvp_mut_price_flat') then c = c + mm('mvp_mut_price_flat') end   
        self.cost = math.max(1, math.floor(c + 0.5))  
    end

    if mm('mvp_mut_no_refunds') then
        self.sell_cost = 0
    else
        self.sell_cost = math.max(1, math.floor((MVP.plain(self.cost) or 0) / 2))
            + (self.ability and MVP.plain(self.ability.extra_value) or 0)
    end
    self.sell_cost_label = self.facing == 'back' and '?' or self.sell_cost
end

local RARITY_NAME = { 'Common', 'Uncommon', 'Rare', 'Legendary' }   -- poll_rarity's numbers

local BANNED_RARITY = {
    mvp_mut_no_common   = { Common = true },
    mvp_mut_no_uncommon = { Uncommon = true },
    mvp_mut_no_rare     = { Rare = true },
}

local mvp_mut_poll_rarity = SMODS.poll_rarity
function SMODS.poll_rarity(_pool_key, _rand_key)
    if _pool_key ~= 'Joker' then return mvp_mut_poll_rarity(_pool_key, _rand_key) end
    -- Fabled Shop: shop Jokers roll on 'rarity<ante>sho' (UI_definitions.lua:848).
    if mm('mvp_mut_fabled') and type(_rand_key) == 'string' and _rand_key:sub(-3) == 'sho'
        and pseudorandom('mvp_mut_fabled') < 1 / mm('mvp_mut_fabled') then
        return 4
    end
    if mm('mvp_mut_random_rarity') then
        return pseudorandom('mvp_mut_rarity', 1, 3)
    end

    local ban
    for flag, keys in pairs(BANNED_RARITY) do
        if mm(flag) then ban = keys break end
    end
    local ot = ban and SMODS.ObjectTypes and SMODS.ObjectTypes[_pool_key]
    if not (ot and ot.rarities) then return mvp_mut_poll_rarity(_pool_key, _rand_key) end

    local kept = {}
    for _, v in ipairs(ot.rarities) do
        if not ban[v.key] then kept[#kept + 1] = v end
    end
    if #kept == 0 then return mvp_mut_poll_rarity(_pool_key, _rand_key) end     -- Nothing left to roll would mean an empty pool and no Jokers at all; leave it alone.

    -- The result is still checked: a wrapper below this one can return a rarity without
    -- reading the list (EndlessEngines' Royal Voucher returns Legendary outright).
    local saved, r, failed = ot.rarities, nil, false
    ot.rarities = kept
    for _ = 1, 3 do
        local ok, res = pcall(mvp_mut_poll_rarity, _pool_key, _rand_key)
        if not ok then failed = true break end
        if not ban[RARITY_NAME[res] or res] then r = res break end
    end
    ot.rarities = saved   -- restored on the error path too, or every later poll is skewed
    if failed then return mvp_mut_poll_rarity(_pool_key, _rand_key) end
    if r then return r end
    local first = kept[1].key
    for i, name in ipairs(RARITY_NAME) do
        if name == first then return i end
    end
    return first
end

-- Banning every Tarot or Planet empties the pool, and get_current_pool then falls back to
-- Strength / Pluto (common_events.lua:2454), so the shop's type roll must not land there.
local mvp_mut_card_for_shop = create_card_for_shop
function create_card_for_shop(area)
    if not (mm('mvp_mut_no_tarots') or mm('mvp_mut_no_planets')) then return mvp_mut_card_for_shop(area) end
    local tr, pr = G.GAME.tarot_rate, G.GAME.planet_rate
    if mm('mvp_mut_no_tarots') then G.GAME.tarot_rate = 0 end
    if mm('mvp_mut_no_planets') then G.GAME.planet_rate = 0 end
    local ok, card = pcall(mvp_mut_card_for_shop, area)
    G.GAME.tarot_rate, G.GAME.planet_rate = tr, pr
    if not ok then error(card, 0) end
    return card
end

local mvp_mut_create_card = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    -- A banned forced key falls through to get_current_pool(_type), which errors on a nil type,
    -- and SMODS.create_card{key=...} passes none (CardSleeves' starting consumables do this).
    if _type == nil and forced_key and G.GAME and G.GAME.banned_keys
        and G.GAME.banned_keys[forced_key] and G.P_CENTERS[forced_key] then
        _type = G.P_CENTERS[forced_key].set
    end
    local c = mvp_mut_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    if c and c.ability and c.ability.set == 'Joker' then
        if mm('mvp_mut_all_rental') and not c.ability.rental and c.set_rental then -- set_rental/set_eternal rather than a direct ability write
            c:set_rental(true)
        end
        if mm('mvp_mut_autosell_leftmost') and c.ability.eternal and c.set_eternal then -- No Commitments: no Eternal Jokers, so the leftmost stays sellable.
            c:set_eternal(false)
        end
        if mm('mvp_mut_all_perishable') and not c.ability.perishable and c.set_perishable then
            c:set_perishable(true)
        end
    end
    return c
end

local mvp_mut_add_to_deck = Card.add_to_deck -- Fallback for rentals that never pass through create_card's shop path.
function Card:add_to_deck(from_debuff)
    mvp_mut_add_to_deck(self, from_debuff)
    if mm('mvp_mut_all_rental') and self.ability and self.ability.set == 'Joker'
        and not self.ability.rental and self.set_rental then
        self:set_rental(true)
    end
    if mm('mvp_mut_all_perishable') and self.ability and self.ability.set == 'Joker'
        and not self.ability.perishable and self.set_perishable then
        self:set_perishable(true)
    end
end

--============================================================
-- Per-Ante rolls (Last in Line, Rarity Raid, Odds & Evens)
--============================================================
function MVP.last_suit()
    if not mm('mvp_mut_last_suit') then return nil end
    local options = {}
    for _, s in ipairs(SUITS) do   -- the dead suit is no burden drawn last
        if s ~= mm('mvp_mut_dead_suit') then options[#options + 1] = s end
    end
    return ante_pick('last_suit', options)
end

function MVP.raid_rarity()
    if not mm('mvp_mut_rarity_raid') then return nil end
    return ante_pick('raid_rarity', { 1, 2, 3 })
end

function MVP.raid_parity()
    if not mm('mvp_mut_parity') then return nil end
    return ante_pick('parity', { 'odd', 'even' })
end

-- Odd Todd and Even Steven's ranks; face cards are neither.
local PARITY = { [14] = 'odd', [9] = 'odd', [7] = 'odd', [5] = 'odd', [3] = 'odd',
                 [10] = 'even', [8] = 'even', [6] = 'even', [4] = 'even', [2] = 'even' }

local function in_boss_blind()
    local b = G.GAME and G.GAME.blind
    return b and b.boss and b.in_blind and not b.disabled
end

--============================================================
-- Debuffs. SMODS asks every mod's set_debuff whenever a card's debuff is recalculated
-- (card.lua:689): on Blind start and end, and when a card is created or changes suit.
--============================================================
local EM_MOD = SMODS.current_mod or {}

function EM_MOD.set_debuff(card)
    if not (G.GAME and G.GAME.modifiers and card and card.ability) then return end
    if card.playing_card then
        local dead = mm('mvp_mut_dead_suit')
        if dead and card:is_suit(dead, true) then return true end
        if in_boss_blind() then
            if G.GAME.mvp_mut_verdant_on then return true end
            local p = MVP.raid_parity()
            if p and not SMODS.has_no_rank(card) and PARITY[card:get_id()] == p then return true end
        end
    elseif card.ability.set == 'Joker' and in_boss_blind() then
        local r = MVP.raid_rarity()
        if r and card.config.center.rarity == r then return true end
    end
end

--============================================================
-- Scoring-time effects, as a mod-level calculate (SMODS.get_mods_scoring_targets)
--============================================================
function EM_MOD.calculate(self, context)
    if not (G.GAME and G.GAME.modifiers) then return end
    if context.pre_discard and not context.hook and mm('mvp_mut_toll') then   -- Toll Road
        ease_dollars(-mm('mvp_mut_toll'))
    end
    if context.individual and context.cardarea == G.play and context.other_card
        and mm('mvp_mut_hiker') and not context.blueprint then   -- Hiker's Trail
        local c = context.other_card
        c.ability.perma_bonus = (MVP.plain(c.ability.perma_bonus) or 0) + mm('mvp_mut_hiker')
    end
    if context.destroy_card and context.destroy_card.playing_card
        and (context.cardarea == G.play or context.cardarea == 'unscored')
        and mm('mvp_mut_fragile') and pseudorandom('mvp_mut_fragile') < 1 / mm('mvp_mut_fragile') then
        return { remove = true }   -- Fragile Deck
    end
end

-- Verdant Pact: selling a Joker lifts the debuff for the rest of the Blind.
local mvp_mut_sell_card = Card.sell_card
function Card:sell_card()
    local was_joker = self.ability and self.ability.set == 'Joker'
    local ret = mvp_mut_sell_card(self)
    if was_joker and G.GAME.mvp_mut_verdant_on then
        G.GAME.mvp_mut_verdant_on = nil
        for _, c in ipairs(G.playing_cards or {}) do SMODS.recalc_debuff(c) end
    end
    return ret
end

--============================================================
-- Draws
--============================================================
local mvp_mut_stay_flipped = Blind.stay_flipped   -- Wheel of Misfortune, on top of any Boss
function Blind:stay_flipped(area, card, from_area)
    if mvp_mut_stay_flipped(self, area, card, from_area) then return true end
    if area == G.hand and mm('mvp_mut_wheel') and pseudorandom('mvp_mut_wheel') < 1 / mm('mvp_mut_wheel') then
        return true
    end
end

-- Hooked: The Hook's own discard (blind.lua:503-521), after every hand.
local mvp_mut_press_play = Blind.press_play
function Blind:press_play()
    local ret = mvp_mut_press_play(self)
    if mm('mvp_mut_hooked') then
        G.E_MANAGER:add_event(Event({ func = function()
            local any_selected = nil
            local _cards = {}
            for _, v in ipairs(G.hand.cards) do _cards[#_cards + 1] = v end
            for i = 1, 2 do
                if G.hand.cards[i] then
                    local selected_card, card_key = pseudorandom_element(_cards, pseudoseed('mvp_mut_hook'))
                    G.hand:add_to_highlighted(selected_card, true)
                    table.remove(_cards, card_key)
                    any_selected = true
                    play_sound('card1', 1)
                end
            end
            if any_selected then G.FUNCS.discard_cards_from_highlighted(nil, true) end
            return true
        end }))
        delay(0.7)
    end
    return ret
end

-- Ox Tax: debuff_hand runs once per hand played with check unset (state_events.lua:604).
local mvp_mut_debuff_hand = Blind.debuff_hand
function Blind:debuff_hand(cards, hand, handname, check)
    local ret = mvp_mut_debuff_hand(self, cards, hand, handname, check)
    if not check and mm('mvp_mut_ox_tax') and G.GAME.current_round
        and handname == G.GAME.current_round.most_played_poker_hand then
        ease_dollars(-mm('mvp_mut_ox_tax'))
    end
    return ret
end

-- Last in Line / Stale Cards: drawn last means the front of G.deck.cards.
local mvp_mut_shuffle = CardArea.shuffle
function CardArea:shuffle(_seed)
    local ret = mvp_mut_shuffle(self, _seed)
    if self == G.deck and (mm('mvp_mut_last_suit') or mm('mvp_mut_stale')) then
        local suit = MVP.last_suit()
        local last, rest = {}, {}
        for _, c in ipairs(self.cards) do
            local late = (suit and c.base and c.base.suit == suit and not SMODS.has_no_suit(c))
                or (mm('mvp_mut_stale') and c.ability and c.ability.played_this_ante)
            if late then last[#last + 1] = c else rest[#rest + 1] = c end
        end
        if #last > 0 then
            local n = 0
            for _, list in ipairs({ last, rest }) do
                for _, c in ipairs(list) do n = n + 1; self.cards[n] = c end
            end
            self:set_ranks()
        end
    end
    return ret
end

--============================================================
-- Card values (Weak Spells, Watered Down, Powerhouse)
--============================================================
-- Payout fields only. Counts, odds, thresholds, decays and inert placeholders are not
-- values the player is paid, so they are never scaled.
local SCALE_KEYS = {
    mult = 'add', chips = 'add', t_mult = 'add', t_chips = 'add', s_mult = 'add',
    h_mult = 'add', h_chips = 'add', dollars = 'add', chip_mod = 'add', mult_mod = 'add',
    increase = 'add', hand_add = 'add', max = 'add',
    x_mult = 'x', Xmult = 'x', xmult = 'x', h_x_mult = 'x', x_chips = 'x',
}
-- Per-Joker exceptions to SCALE_KEYS, inside ability.extra.
local SCALE_SKIP = {
    j_bootstraps = { dollars = true },      -- the $5 step, not a payout
    j_ice_cream  = { chip_mod = true },     -- decay
    j_swashbuckler = { mult = true },       -- recomputed from sell values
}
-- Jokers whose `extra` is a plain number: 'add' for a payout, 'gain' for a per-trigger
-- XMult increase (scaled raw), 'x' for an XMult. Anything unlisted (counts, odds,
-- thresholds, decays, unused) is left alone.
local SCALE_EXTRA = {
    j_abstract = 'add', j_arrowhead = 'add', j_banner = 'add', j_blue_joker = 'add', j_bull = 'add',
    j_cloud_9 = 'add', j_credit_card = 'add', j_delayed_grat = 'add', j_egg = 'add', j_erosion = 'add',
    j_even_steven = 'add', j_fibonacci = 'add', j_flash = 'add', j_fortune_teller = 'add', j_gift = 'add',
    j_golden = 'add', j_hiker = 'add', j_mail = 'add', j_matador = 'add', j_odd_todd = 'add',
    j_onyx_agate = 'add', j_red_card = 'add', j_ride_the_bus = 'add', j_rough_gem = 'add',
    j_satellite = 'add', j_scary_face = 'add', j_shoot_the_moon = 'add', j_smiley = 'add',
    j_stone = 'add', j_ticket = 'add', j_to_the_moon = 'add', j_trading = 'add', j_trousers = 'add',
    j_campfire = 'gain', j_constellation = 'gain', j_glass = 'gain', j_hit_the_road = 'gain',
    j_hologram = 'gain', j_lucky_cat = 'gain', j_madness = 'gain', j_obelisk = 'gain',
    j_steel_joker = 'gain', j_throwback = 'gain', j_vampire = 'gain', j_caino = 'gain',
    j_acrobat = 'x', j_ancient = 'x', j_baron = 'x', j_baseball = 'x', j_blackboard = 'x',
    j_drivers_license = 'x', j_flower_pot = 'x', j_idol = 'x', j_photograph = 'x',
    j_seeing_double = 'x', j_triboulet = 'x',
}

local function scaled(v, how, f)
    local n = MVP.plain(v)
    if not n or n == 0 then return v end
    local out
    if how == 'x' then
        if n <= 1 then return v end   -- X1 is inert; the bonus above it is what scales
        out = math.floor((1 + (n - 1) * f) * 100 + 0.5) / 100
    elseif n == math.floor(n) then
        out = math.max(1, math.floor(n * f + 0.5))
    else
        out = math.max(0.01, math.floor(n * f * 100 + 0.5) / 100)
    end
    return (to_big and type(v) == 'table') and to_big(out) or out
end

local function scale_joker(card, f)
    local a, key = card.ability, card.config.center.key
    for k, how in pairs(SCALE_KEYS) do
        if a[k] ~= nil and MVP.isnum(a[k]) and not (k == 'mult' and key == 'j_swashbuckler') then
            a[k] = scaled(a[k], how, f)
        end
    end
    if a.Xmult ~= nil and a.x_mult ~= nil then a.Xmult = a.x_mult end   -- one value, two names
    if type(a.extra) == 'table' then
        local skip = SCALE_SKIP[key] or {}
        for k, v in pairs(a.extra) do
            local how = SCALE_KEYS[k]
            if how and not skip[k] and MVP.isnum(v) then a.extra[k] = scaled(v, how, f) end
        end
    elseif MVP.isnum(a.extra) and SCALE_EXTRA[key] then
        local how = SCALE_EXTRA[key]
        a.extra = scaled(a.extra, how == 'gain' and 'add' or how, f)
    end
end

local mvp_mut_set_ability = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
    mvp_mut_set_ability(self, center, initial, delay_sprites)
    if not (G.GAME and G.GAME.modifiers and self.ability) then return end
    local set = self.ability.set
    if mm('mvp_mut_joker_scale') and set == 'Joker' then
        scale_joker(self, mm('mvp_mut_joker_scale'))
    end
    -- Weak Spells. Death needs exactly two cards, so it keeps its two.
    if mm('mvp_mut_weak_spells') and (set == 'Tarot' or set == 'Spectral')
        and self.config.center.key ~= 'c_death' then
        local n = MVP.plain(self.ability.max_highlighted)
        if n and n > 1 then
            -- consumeable is the center's own config table (card.lua:418); copy before writing.
            if self.ability.consumeable == self.config.center.config then
                self.ability.consumeable = copy_table(self.ability.consumeable)
            end
            self.ability.max_highlighted = n - 1
            if self.ability.consumeable then self.ability.consumeable.max_highlighted = n - 1 end
        end
    end
end

--============================================================
-- Shop
--============================================================
-- Reroll Royalty: one free reroll per shop, on top of the round's own. new_round copies
-- the base into the round from a queued event (state_events.lua:259); this one follows it.
local mvp_mut_new_round = new_round
function new_round(...)
    local ret = mvp_mut_new_round(...)
    if mm('mvp_mut_free_reroll') then
        G.E_MANAGER:add_event(Event({ func = function()
            G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + 1
            calculate_reroll_cost(true)
            return true
        end }))
    end
    return ret
end

-- Mega Packs: the same kind of pack, Mega size.
local mvp_mut_get_pack = get_pack
function get_pack(_key, _type)
    local pack = mvp_mut_get_pack(_key, _type)
    if not (mm('mvp_mut_mega_packs') and pack and pack.kind) or (pack.key or ''):find('mega') then return pack end
    local megas = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Booster or {}) do
        if v.kind == pack.kind and (v.key or ''):find('mega') and not G.GAME.banned_keys[v.key] then
            megas[#megas + 1] = v
        end
    end
    return pseudorandom_element(megas, pseudoseed('mvp_mut_mega')) or pack
end

--============================================================
-- House rules (SMODS reads these Jokers through one helper each)
--============================================================
local mvp_mut_four_fingers = SMODS.four_fingers
function SMODS.four_fingers(hand_type)
    local n = mvp_mut_four_fingers(hand_type)
    if mm('mvp_mut_four_fingers') then return math.min(n, 4) end
    return n
end

local mvp_mut_shortcut = SMODS.shortcut
function SMODS.shortcut()
    return mm('mvp_mut_shortcut') and true or mvp_mut_shortcut()
end

local mvp_mut_smeared = SMODS.smeared_check
function SMODS.smeared_check(card, suit)
    if mvp_mut_smeared(card, suit) then return true end
    if not mm('mvp_mut_smeared') then return false end
    local s = card.base and card.base.suit
    local red = { Hearts = true, Diamonds = true }
    return s ~= nil and (red[s] or false) == (red[suit] or false)
end

-- Splash: evaluate_play reads `SMODS.always_scores(card) or next(find_joker('Splash'))`
-- (overrides.lua:2664), and always_scores is read nowhere else.
local mvp_mut_always_scores = SMODS.always_scores
function SMODS.always_scores(card)
    if mm('mvp_mut_splash') then return true end
    return mvp_mut_always_scores(card)
end

local mvp_mut_showman = SMODS.showman
function SMODS.showman(card_key)
    return mm('mvp_mut_showman') and true or mvp_mut_showman(card_key)
end

--============================================================
-- Deck Medley: the second deck's run-time effects (Plasma's balance, Anaglyph's Double Tag)
--============================================================
local mvp_mut_trigger_effect = Back.trigger_effect
function Back:trigger_effect(args)
    local a, b = mvp_mut_trigger_effect(self, args)
    local k = G.GAME and G.GAME.mvp_mut_medley
    if k and args and self == G.GAME.selected_back and G.P_CENTERS[k] then
        MVP.medley_back = (MVP.medley_back and MVP.medley_back.effect.center.key == k) and MVP.medley_back
            or Back(G.P_CENTERS[k])
        local c, d = mvp_mut_trigger_effect(MVP.medley_back, args)
        if a == nil and b == nil then return c, d end
    end
    return a, b
end

local function ban_pool(pool_key)
    for _, v in ipairs(G.P_CENTER_POOLS[pool_key] or {}) do
        if v.key then G.GAME.banned_keys[v.key] = true end
    end
end


-- Ban a whole consumable type: its cards, its Booster packs, its skip Tag, and everything that
-- only creates or rewards that type. A creator can't simply be left in: with every card of the
-- type banned, get_current_pool falls back to Strength / Pluto (common_events.lua:2454).
local CONSUMABLE_BAN = {
    Tarot  = { packs = 'arcana', tag = 'tag_charm', keys = {
        'v_tarot_merchant', 'v_tarot_tycoon', 'v_omen_globe',     -- Omen Globe only seeds Arcana packs
        'j_8_ball', 'j_cartomancer', 'j_hallucination', 'j_vagabond', 'j_superposition',
        'j_fortune_teller',
        'c_medium', 'Purple',                                      -- Purple seals create Tarots
    } },
    Planet = { packs = 'celestial', tag = 'tag_meteor', keys = {
        'v_planet_merchant', 'v_planet_tycoon', 'v_telescope', 'v_observatory',
        'j_constellation', 'j_satellite', 'j_astronomer',
        'c_high_priestess', 'c_trance', 'Blue',                    -- Blue seals create Planets
    } },
}
local function ban_consumable(pool_key)
    ban_pool(pool_key)
    local cfg = CONSUMABLE_BAN[pool_key]
    if not cfg then return end
    for _, v in ipairs(G.P_CENTER_POOLS.Booster or {}) do
        if v.key and (v.kind == cfg.packs:gsub('^%l', string.upper) or v.key:find(cfg.packs)) then
            G.GAME.banned_keys[v.key] = true
        end
    end
    G.GAME.banned_keys[cfg.tag] = true
    for _, k in ipairs(cfg.keys) do G.GAME.banned_keys[k] = true end
end

local function apply_hand_tweaks() -- Poker-hand base values, applied once the hand table exists.
    local focus = mm('mvp_mut_score_focus')
    if focus and G.GAME.hands then
        local cf = focus == 'chips' and 2 or 0.5
        local mf = focus == 'chips' and 0.5 or 2
        local function scale(h, k, f, floor1)
            local b = MVP.plain(h[k]); if not b then return end
            local nv = math.floor(b * f + 0.5)
            if floor1 then nv = math.max(1, nv) end
            h[k] = to_big and to_big(nv) or nv
        end
        for _, h in pairs(G.GAME.hands) do
            scale(h, 'chips', cf); scale(h, 's_chips', cf); scale(h, 'l_chips', cf)
            scale(h, 'mult', mf, true); scale(h, 's_mult', mf, true); scale(h, 'l_mult', mf, true)
        end
    end

    if mm('mvp_mut_chaos_theory') and G.GAME.hands then  -- Chaos Theory: randomises each hand's base chips and mult independently, 0.5x-2x.
        local function put(h, k, f)
            local b = MVP.plain(h[k]); if not b then return end
            local nv = math.max(1, math.floor(b * f + 0.5))
            h[k] = to_big and to_big(nv) or nv
        end
        for _, h in pairs(G.GAME.hands) do
            -- Uniform in log space, so 0.5x and 2x are equally likely. A linear 0.5-2 roll
            -- averages 1.25x per factor, a buff the text does not promise.
            local fc = 2 ^ (pseudorandom('mvp_mut_chaos_c') * 2 - 1)
            local fm = 2 ^ (pseudorandom('mvp_mut_chaos_m') * 2 - 1)
            put(h, 'chips', fc); put(h, 's_chips', fc)
            put(h, 'mult', fm);  put(h, 's_mult', fm)
        end
    end
end

--============================================================
-- Deck rebuilds
--============================================================
local SEALS = { 'Red', 'Blue', 'Gold', 'Purple' }

local function rebuild_deck()
    if not (G.playing_cards and #G.playing_cards > 0 and G.deck) then return end

    if mm('mvp_mut_wild_deck') and G.P_CENTERS.m_wild then
        for _, c in ipairs(G.playing_cards) do c:set_ability(G.P_CENTERS.m_wild, true, true) end
    end
    if mm('mvp_mut_lucky_sevens') and G.P_CENTERS.m_lucky then -- Lucky Seven: every 7 becomes a Lucky card with a Red Seal.
        for _, c in ipairs(G.playing_cards) do
            if (c.get_id and c:get_id()) == 7 then
                c:set_ability(G.P_CENTERS.m_lucky, true, true)
                c:set_seal('Red', true, true)
            end
        end
    end

    if mm('mvp_mut_numbers_to_stone') and G.P_CENTERS.m_stone then -- Rankless: every number card (rank < Jack) becomes a Stone Card.
        for _, c in ipairs(G.playing_cards) do
            local id = c.get_id and c:get_id() or 0
            if id >= 2 and id < 11 then c:set_ability(G.P_CENTERS.m_stone, true, true) end
        end
    end

    if mm('mvp_mut_no_numbers') then -- Courtless
        for i = #G.deck.cards, 1, -1 do
            local c = G.deck.cards[i]
            local id = c.get_id and c:get_id() or 0
            if id >= 2 and id < 11 and #G.deck.cards > 5 then
                table.remove(G.deck.cards, i)
                c:remove()
            end
        end
        if mm('mvp_mut_triple_faces') then
            local base = {}
            for _, c in ipairs(G.deck.cards) do base[#base + 1] = c end
            for _ = 1, 2 do
                for _, src in ipairs(base) do
                    local c = copy_card(src, nil, nil, nil)
                    c:add_to_deck()
                    G.deck:emplace(c)
                end
            end
        end
    end

    local target
    if mm('mvp_mut_deck_target') then
        target = mm('mvp_mut_deck_target')
    elseif mm('mvp_mut_deck_delta') then
        target = #G.deck.cards + mm('mvp_mut_deck_delta')
    end

    if target then
        local n = #G.deck.cards
        if target < n then
            for _ = 1, n - target do
                if #G.deck.cards <= 1 then break end
                local i = pseudorandom('mvp_mut_trim', 1, #G.deck.cards)
                local c = G.deck.cards[i]
                table.remove(G.deck.cards, i)
                c:remove()
            end
        elseif target > n then
            for _ = 1, target - n do
                local src = G.deck.cards[pseudorandom('mvp_mut_pad', 1, #G.deck.cards)]
                if src then
                    local c = copy_card(src, nil, nil, nil)
                    if mm('mvp_mut_all_enhanced') then -- Heavy Deck: vanilla's own enhancement pool and weights
                        local ek = SMODS.poll_enhancement({ key = 'mvp_mut_enh', guaranteed = true })
                        if ek and G.P_CENTERS[ek] then c:set_ability(G.P_CENTERS[ek], true, true) end
                    end
                    c:add_to_deck()
                    G.deck:emplace(c)
                end
            end
        end
    end

    G.playing_cards = {}
    for _, c in ipairs(G.deck.cards) do
        c.playing_card = #G.playing_cards + 1
        G.playing_cards[#G.playing_cards + 1] = c
    end

    -- After every add/remove above, so Courtless or Thin Deck can't take marked cards back
    -- out and Heavy Deck can't copy them.
    local function pick_cards(n)
        local idx, out = {}, {}
        for i = 1, #G.playing_cards do idx[i] = i end
        for _ = 1, math.min(n, #idx) do
            local pick = pseudorandom('mvp_mut_pick', 1, #idx)
            out[#out + 1] = G.playing_cards[idx[pick]]
            table.remove(idx, pick)
        end
        return out
    end

    if mm('mvp_mut_random_seals') then -- Broken Deck
        local seals, banned = {}, G.GAME.banned_keys or {}
        for _, k in ipairs(SEALS) do
            if not banned[k] then seals[#seals + 1] = k end
        end
        for _, c in ipairs(pick_cards(mm('mvp_mut_random_seals'))) do
            c:set_seal(seals[pseudorandom('mvp_mut_seal', 1, #seals)], true, true)
        end
    end

    if mm('mvp_mut_random_editions') then -- Limited Edition: Aura's roll (base editions, no Negative)
        for _, c in ipairs(pick_cards(mm('mvp_mut_random_editions'))) do
            local ed = poll_edition('mvp_mut_edition', nil, true, true, { 'e_negative', 'e_polychrome', 'e_holo', 'e_foil' })
            if ed and c.set_edition then c:set_edition(ed, true, true) end
        end
    end
    G.deck:set_ranks()
end

--============================================================
-- START
--============================================================
-- Called explicitly by the mode's start_run wrapper, after the rolled keys are stored on
-- G.GAME - not a start_run wrapper of its own, which would nest inside the mode's and run
-- before the keys existed. mvp_mut_applied guards a loaded save, whose modifiers and params
-- are already baked into the serialised G.GAME.

function MVP.mutations_apply()
    if not (G.GAME and G.GAME.mvp_mutations and #G.GAME.mvp_mutations > 0) then return end
    if G.GAME.mvp_mut_applied then return end
    G.GAME.mvp_mut_applied = true

    MVP.apply_mutations()   -- base starting_params + modifier flags

    if mm('mvp_mut_no_tarots') then ban_consumable('Tarot') end
    if mm('mvp_mut_no_planets') then ban_consumable('Planet') end

    if mm('mvp_mut_ban_discard_vouchers') then
        G.GAME.banned_keys['v_wasteful'] = true
        G.GAME.banned_keys['v_recyclomancy'] = true
    end

    if mm('mvp_mut_win_ante') then G.GAME.win_ante = mm('mvp_mut_win_ante') end

    if mm('mvp_mut_voucher_starter') then   -- after the bans, so a banned Voucher is never granted
        local skip = { v_blank = true }
        local back = G.GAME.selected_back and G.GAME.selected_back.effect and G.GAME.selected_back.effect.config or {}
        local sleeve = MVP.SLEEVE_START and MVP.SLEEVE_START[G.GAME.selected_sleeve or ''] or {}
        for _, cfg in ipairs({ back, sleeve }) do   -- the deck and sleeve grant theirs after this
            if cfg.voucher then skip[cfg.voucher] = true end
            for _, k in ipairs(cfg.vouchers or {}) do skip[k] = true end
        end
        local pool = {}
        for _, v in ipairs(G.P_CENTER_POOLS.Voucher or {}) do
            if v.key and not v.mod and not (v.requires and #v.requires > 0) and not skip[v.key]
                and not G.GAME.banned_keys[v.key] then
                pool[#pool + 1] = v.key
            end
        end
        for i = 1, mm('mvp_mut_voucher_starter') do
            local k, idx = pseudorandom_element(pool, pseudoseed('mvp_mut_voucher' .. i))
            if not k then break end
            table.remove(pool, idx)
            grant_voucher(k)
        end
    end

    local em = mods()
    if mm('mvp_mut_fewer_packs') then em.extra_boosters = (em.extra_boosters or 0) - 1 end
    if mm('mvp_mut_more_stock') then
        em.extra_boosters = (em.extra_boosters or 0) + 1
        em.extra_vouchers = (em.extra_vouchers or 0) + 1
        if G.GAME.shop then G.GAME.shop.joker_max = (G.GAME.shop.joker_max or 2) + 1 end
    end

    apply_blind_hides()   -- No Small Talk / Big Brother apply to ante 1 here; reset_blinds handles later antes.
    apply_hand_tweaks()   -- G.GAME.hands already exists here
end

local SP_FLOOR = { hands = 1, discards = 0, hand_size = 1, joker_slots = 0, consumable_slots = 0 }

function MVP.mutations_post_deck()
    if not (G.GAME and ((G.GAME.mvp_mutations and #G.GAME.mvp_mutations > 0) or G.GAME.mvp_flux)) then return end
    local sp = G.GAME.starting_params
    if sp then
        for field, floor_v in pairs(SP_FLOOR) do
            local v = MVP.plain(sp[field])
            if v and v < floor_v then sp[field] = floor_v end
        end
    end
    if mm('mvp_mut_spectral_rate') then
        G.GAME.spectral_rate = math.max(MVP.plain(G.GAME.spectral_rate) or 0,
                                        mm('mvp_mut_spectral_rate'))
    end
end

function MVP.mutations_finish()
    if not (G.GAME and G.GAME.mvp_mutations and #G.GAME.mvp_mutations > 0) then return end

    if G.GAME.mvp_mut_jokers and G.jokers then
        for _, j in ipairs(G.GAME.mvp_mut_jokers) do
            G.E_MANAGER:add_event(Event({ func = function()
                if not G.P_CENTERS[j.k] then return true end
                -- add_joker sets the edition after add_to_deck, or Negative never grants its slot;
                -- it skips create_card, so Eternal Kingdom's all_eternal is passed through by hand.
                add_joker(j.k, j.e, true, mm('all_eternal'))
                return true
            end }))
        end
    end

    for i, j in ipairs(G.GAME.mvp_mut_random_jokers or {}) do   -- Opening Act / Polychrome Debut
        G.E_MANAGER:add_event(Event({ func = function()
            if G.jokers and #G.jokers.cards < G.jokers.config.card_limit then
                local c = create_card('Joker', G.jokers, nil, j.r, nil, nil, nil, 'mvp_start' .. i)
                c:add_to_deck()
                G.jokers:emplace(c)
                if j.e then c:set_edition({ [j.e] = true }, true, true) end
            end
            return true
        end }))
    end

    if mm('mvp_mut_spectral_visit') then
        G.E_MANAGER:add_event(Event({ func = function()
            if G.consumeables and #G.consumeables.cards < G.consumeables.config.card_limit then
                local c = create_card('Spectral', G.consumeables, nil, nil, nil, nil, nil, 'mvp_visit')
                c:add_to_deck()
                G.consumeables:emplace(c)
            end
            return true
        end }))
    end

    if mm('mvp_mut_tag_team') then
        G.E_MANAGER:add_event(Event({ func = function()
            for i = 1, mm('mvp_mut_tag_team') do add_tag(Tag(get_next_tag_key('mvp_team' .. i))) end
            return true
        end }))
    end

    if mm('mvp_mut_leveled_up') then
        G.E_MANAGER:add_event(Event({ func = function()
            local names = {}
            for k, h in pairs(G.GAME.hands or {}) do
                if h.visible then names[#names + 1] = k end
            end
            table.sort(names)   -- pairs() order is undefined
            for i = 1, mm('mvp_mut_leveled_up') do
                local k, idx = pseudorandom_element(names, pseudoseed('mvp_mut_level' .. i))
                if not k then break end
                table.remove(names, idx)
                level_up_hand(nil, k, true, 2)
            end
            return true
        end }))
    end

    G.E_MANAGER:add_event(Event({ func = function() rebuild_deck(); return true end }))
end

--============================================================
-- ERRATIC MODE
--============================================================

local STAKE_MIN, STAKE_MAX = 1, 8   -- White through Gold

local MUT_MIN, MUT_MAX = 0, 8
MVP.mutation_cfg = MVP.mutation_cfg or { count = 0 }

local function mutation_count()
    local n = math.floor((MVP.mutation_cfg.count or MUT_MIN) + 0.5)
    return math.max(MUT_MIN, math.min(MUT_MAX, n))
end

-- Flux mode borrows EndlessEngines' own Flux code, so it only exists when that mod is loaded.
local function flux_available()
    return EEng ~= nil and type(EEng.flux_activate) == 'function'
        and type(EEng.flux_destabilize) == 'function'
end

local function flux_text()
    return { 'Applies {C:attention}Flux{} deck and sleeve', 'randomness to the run.' }
end

-- Hover anywhere on the toggle: the container covers the label, and the checkbox is its own
-- collidable element, so it needs the tooltip too.
local function with_flux_tooltip(node)
    local tip = { title = 'Flux', text = flux_text() }
    node.config = node.config or {}
    node.config.tooltip = tip
    local function walk(n)
        if n.config and n.config.button == 'toggle_button' then n.config.tooltip = tip end
        for _, child in ipairs(n.nodes or {}) do walk(child) end
    end
    walk(node)
    return node
end

-- The Flux Deck and Flux Sleeve together, as the base layer: mutations, the deck perk and the
-- sleeve then land on the rolled loadout, as they would on any deck. The roll is not stashed
-- for EndlessEngines' post-start_run re-apply, which would overwrite all of them.
function MVP.flux_apply()
    if not flux_available() then return end
    EEng.flux_activate()          -- Flux Deck: every value randomized
    EEng.flux_destabilize(false)  -- Flux Sleeve on the Flux Deck: loadout and deck rerolled
end

local function best_mutation()
    local p = G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    return (p and p.mvp_best_mutation) or 0
end

local function record_mutation_win()
    local p = G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    if not p then return end
    local n = G.GAME.mvp_mutation_count or 0
    if n > 0 and n > (p.mvp_best_mutation or 0) then
        p.mvp_best_mutation = n
        if G.save_progress then G:save_progress() end
    end
end

-- Vanilla decks and CardSleeves' own sleeves only. Modded ones (Flux, Gauntlet, Prismatic...)
-- would stack with or contradict the mutations and the Flux toggle.
local VANILLA_DECKS = {
    b_red = true, b_blue = true, b_yellow = true, b_green = true, b_black = true,
    b_magic = true, b_nebula = true, b_ghost = true, b_abandoned = true, b_checkered = true,
    b_zodiac = true, b_painted = true, b_anaglyph = true, b_plasma = true, b_erratic = true,
}

-- True if a deck or sleeve would start the run holding a card the mutations ban (the Magic
-- deck and sleeve's Fools under No Magic), which would hand out exactly what was banned.
-- Both variants of each CardSleeves sleeve that starts with something a ban covers. A sleeve
-- rewrites its own config when drawn on its matching deck, so its live config can't be trusted.
local SLEEVE_START = {
    sleeve_casl_magic  = { consumables = { 'c_fool', 'c_fool' }, vouchers = { 'v_crystal_ball', 'v_omen_globe' } },
    sleeve_casl_nebula = { vouchers = { 'v_telescope', 'v_observatory' } },
    sleeve_casl_zodiac = { vouchers = { 'v_tarot_merchant', 'v_planet_merchant', 'v_overstock_norm' } },
}

local function starts_banned(config, banned)
    if not config then return false end
    for _, k in ipairs(config.consumables or {}) do
        local c = G.P_CENTERS[k]
        if c and banned[c.set] then return true end
    end
    local vouchers = {}
    if config.voucher then vouchers[1] = config.voucher end
    for _, k in ipairs(config.vouchers or {}) do vouchers[#vouchers + 1] = k end
    for set in pairs(banned) do
        local cfg = CONSUMABLE_BAN[set]
        for _, banned_key in ipairs(cfg and cfg.keys or {}) do
            for _, k in ipairs(vouchers) do
                if k == banned_key then return true end
            end
        end
    end
    return false
end

MVP.SLEEVE_START = SLEEVE_START

local function random_deck(banned, nodeck)
    local pool = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Back or {}) do
        if v.unlocked and VANILLA_DECKS[v.key] and not (nodeck or {})[v.key]
            and not starts_banned(v.config, banned) then
            pool[#pool + 1] = v
        end
    end
    if #pool == 0 then return G.P_CENTERS.b_red end
    return pool[math.random(1, #pool)]
end

local function random_sleeve_key(banned, nodeck)
    if not CardSleeves then return nil end
    local pool = {}
    for _, s in pairs(G.P_CENTER_POOLS.Sleeve or {}) do
        if s.key and s.key:find('^sleeve_casl_') and s.key ~= 'sleeve_casl_none' and not (nodeck or {})[s.key]
            and (type(s.is_unlocked) ~= 'function' or s:is_unlocked())
            and not starts_banned(SLEEVE_START[s.key] or s.config, banned) then
            pool[#pool + 1] = s.key
        end
    end
    table.sort(pool)   -- pairs() order is undefined
    if #pool == 0 then return 'sleeve_casl_none' end
    return pool[math.random(1, #pool)]
end

--============================================================
-- Starting a run
--============================================================

local mvp_pending = nil
local mvp_finish_pending = false
local mvp_run_flux_pending = false

G.FUNCS.mvp_start_mutation = function(e)
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    -- Mutations first: the deck and sleeve are picked around what they ban.
    local count = mutation_count()
    local keys = MVP.roll_mutations(count)
    local banned, nodeck = {}, {}
    for _, k in ipairs(keys) do
        local m = MVP.MUT_BY_KEY[k]
        for _, set in ipairs(m and m.bans or {}) do banned[set] = true end
        for _, d in ipairs(m and m.no_decks or {}) do nodeck[d] = true end
    end
    local deck  = random_deck(banned, nodeck)
    local stake = math.random(STAKE_MIN, STAKE_MAX)
    if CardSleeves then -- If CardSleeves installed
        local sk = random_sleeve_key(banned, nodeck)
        if sk then G.viewed_sleeve = sk end
    end
    if G.GAME then G.GAME.viewed_back = Back(deck) end
    mvp_pending = { count = count, keys = keys, banned = banned, nodeck = nodeck,
                   flux = MVP.mutation_cfg.flux == true and flux_available() }
    G.FUNCS.start_run(e, { stake = stake, deck = deck })
end

-- Deck Medley: a second vanilla deck's perk, applied the way the primary's is. Its run-time
-- effects (Plasma, Anaglyph) go through the Back:trigger_effect wrapper.
local function apply_medley(primary)
    if not mm('mvp_mut_medley') then return end
    local pool = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Back or {}) do
        if v.unlocked and VANILLA_DECKS[v.key] and v.key ~= primary.effect.center.key
            and not (G.GAME.mvp_mut_nodeck or {})[v.key]
            and not starts_banned(v.config, G.GAME.mvp_mut_banned_sets or {}) then
            pool[#pool + 1] = v.key
        end
    end
    local k = pseudorandom_element(pool, pseudoseed('mvp_mut_medley'))
    if not k then return end
    G.GAME.mvp_mut_medley = k
    Back(G.P_CENTERS[k]):apply_to_run()
end

local mvp_apply_to_run = Back.apply_to_run
function Back:apply_to_run(...)
    local ours = false
    if mvp_pending and G.GAME then
        G.GAME.mvp_mutation = true
        G.GAME.mvp_mutation_count = mvp_pending.count
        G.GAME.mvp_mutations = mvp_pending.keys
        G.GAME.mvp_mut_banned_sets = mvp_pending.banned
        G.GAME.mvp_mut_nodeck = mvp_pending.nodeck
        G.GAME.mvp_flux = mvp_pending.flux or nil
        mvp_pending = nil
        mvp_finish_pending = true
        ours = true
        if G.GAME.mvp_flux then MVP.flux_apply() end   -- base layer, under the mutations
        MVP.mutations_apply()   -- before the deck perk below
    elseif mvp_run_flux_pending and G.GAME then
        -- New Run's Flux toggle. The Flux Deck or Sleeve already brings it, so it isn't doubled.
        mvp_run_flux_pending = false
        local deck = self.effect and self.effect.center and self.effect.center.key
        local sleeve = G.GAME.selected_sleeve or G.viewed_sleeve
        if deck ~= 'b_eeng_flux' and sleeve ~= 'sleeve_eeng_flux' then
            G.GAME.mvp_flux = true
            MVP.flux_apply()
            ours = true
        end
    end
    local ret = mvp_apply_to_run(self, ...)
    if ours then
        apply_medley(self)
        MVP.mutations_post_deck()   -- deck and sleeve have both landed by here
    end
    return ret
end

local mvp_erratic_start_run = Game.start_run
function Game:start_run(args)
    mvp_erratic_start_run(self, args)
    -- apply_to_run consumes this, but a save load skips that seam entirely, so clear it
    -- rather than leave a rolled set staged for whatever run starts next.
    mvp_pending = nil
    mvp_run_flux_pending = false
    if mvp_finish_pending then
        mvp_finish_pending = false
        MVP.mutations_finish()   -- deck rebuild, now that G.deck exists
    end
end

--============================================================
-- Flux on the New Run screen
--============================================================
-- Erratic's Flux base layer for an ordinary run. The toggle sits in the empty column vanilla
-- leaves right of PLAY (run_setup_option), mirroring Seeded Run on the left, and like Seeded
-- Run it lasts for the session.
MVP.run_flux = MVP.run_flux or { on = false }

local function find_play_row(node)
    for _, child in ipairs(node.nodes or {}) do
        if child.config and child.config.id == 'run_setup_seed' then return node end
        local row = find_play_row(child)
        if row then return row end
    end
end

local mvp_run_setup_option = G.UIDEF.run_setup_option
function G.UIDEF.run_setup_option(_type)
    local t = mvp_run_setup_option(_type)
    if _type == 'New Run' and flux_available() then
        local row = find_play_row(t)
        local slot = row and row.nodes[#row.nodes]
        if slot and slot.config and not slot.config.button and #(slot.nodes or {}) == 0 then
            slot.nodes = { with_flux_tooltip({ n = G.UIT.C, config = { align = 'cm' }, nodes = {
                create_toggle{ col = true, label = 'Flux', label_scale = 0.25, w = 0, scale = 0.7,
                               active_colour = G.C.BLUE, ref_table = MVP.run_flux, ref_value = 'on' },
            }}) }
        end
    end
    return t
end

-- Challenge runs keep their own rules.
local mvp_start_setup_run = G.FUNCS.start_setup_run
G.FUNCS.start_setup_run = function(e)
    mvp_run_flux_pending = G.SETTINGS.current_setup == 'New Run' and MVP.run_flux.on
        and flux_available() and not G.challenge_tab or false
    return mvp_start_setup_run(e)
end

-- Steamodded's paged run select replaces that screen whenever a mod adds a page, as CardSleeves
-- does. The toggle goes at the end of its nav bar, right of Play and Quick Start.
if SMODS.RunSelect and SMODS.RunSelect.Functions then
    local mvp_nav_bar = SMODS.RunSelect.Functions.nav_bar
    function SMODS.RunSelect.Functions.nav_bar()
        local t = mvp_nav_bar()
        if flux_available() then
            t.nodes[#t.nodes + 1] = with_flux_tooltip({ n = G.UIT.C, config = { align = 'cm' }, nodes = {
                create_toggle{ col = true, label = 'Flux', label_scale = 0.25, w = 0, scale = 0.7,
                               active_colour = G.C.BLUE, ref_table = MVP.run_flux, ref_value = 'on' },
            }})
        end
        return t
    end

    local mvp_select_start_run = SMODS.RunSelect.Functions.start_run
    function SMODS.RunSelect.Functions.start_run(...)
        mvp_run_flux_pending = MVP.run_flux.on and flux_available() or false
        return mvp_select_start_run(...)
    end
end

--============================================================
-- The Erratic Mode box (in the Challenges tab)
--============================================================
local function erratic_box(from_game_over)
    local best = best_mutation()
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.1, r = 0.1, colour = G.C.BLACK }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
            { n = G.UIT.T, config = { text = 'Erratic Mode', scale = 0.4,
                                      colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }},
        { n = G.UIT.R, config = { align = 'cm', minw = 8.5, minh = 1.1, padding = 0.15 }, nodes = {
            UIBox_button({
                id = from_game_over and 'from_game_over' or nil,
                label = { 'Start New Mutation' },
                button = 'mvp_start_mutation',
                colour = G.C.PURPLE,
                minw = 4, scale = 0.4, minh = 0.6,
            }),
        }},
        { n = G.UIT.R, config = { align = 'cm', minw = 8.5, padding = 0.1 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
                { n = G.UIT.T, config = { text = 'Mutations', scale = 0.35,
                                          colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            }},
            { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
                create_slider({
                    ref_table = MVP.mutation_cfg, ref_value = 'count',
                    min = MUT_MIN, max = MUT_MAX, decimal_places = 0,
                    w = 3.4, h = 0.4, colour = G.C.PURPLE,
                }),
            }},
            { n = G.UIT.C, config = { align = 'cm', padding = 0.05, minw = 2.6 }, nodes = {
                { n = G.UIT.T, config = {
                    text = 'Best: ' .. (best > 0 and tostring(best) or '-'),
                    scale = 0.3,
                    colour = best > 0 and G.C.GREEN or G.C.UI.TEXT_INACTIVE, shadow = true } },
            }},
        }},
        { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
                UIBox_button({
                    label = { 'Mutation List' },
                    button = 'mvp_mutation_list',
                    colour = G.C.GREY,
                    minw = 3, scale = 0.3, minh = 0.4,
                }),
            }},
            flux_available() and with_flux_tooltip({ n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
                create_toggle({
                    label = 'Flux', ref_table = MVP.mutation_cfg, ref_value = 'flux',
                    col = true, w = 0.8, scale = 0.8, label_scale = 0.35, active_colour = G.C.BLUE,
                }),
            }}) or nil,
        }},
    }}
end

--============================================================
-- Mutation List overlay (reference inventory of every mutation)
--============================================================

local function strip_markup(s)
    return (tostring(s or ''):gsub('{[^}]*}', ''))
end

local CAT_COLOUR = { Challenge = G.C.RED, Boon = G.C.GREEN, Twist = G.C.PURPLE, Flux = G.C.BLUE }
local function mutation_entry_rows(mt)
    local rows = {}
    rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cl', padding = 0.015 }, nodes = {
        { n = G.UIT.T, config = { text = mt.name, scale = 0.32,
                                  colour = CAT_COLOUR[mt.category] or G.C.PURPLE, shadow = true } },
    }}
    for _, line in ipairs(mt.text or {}) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cl', padding = 0 }, nodes = {
            { n = G.UIT.T, config = { text = strip_markup(line),
                                      scale = 0.24, colour = G.C.UI.TEXT_LIGHT } },
        }}
    end
    return rows
end

function G.UIDEF.mvp_mutation_list()
    local list = MVP.MUTATIONS or {}

    local COLS = 2
    local per_col = math.ceil(#list / COLS)
    local columns = {}
    for col = 1, COLS do
        local rows = {}
        for i = (col - 1) * per_col + 1, math.min(col * per_col, #list) do
            for _, r in ipairs(mutation_entry_rows(list[i])) do rows[#rows + 1] = r end
        end
        columns[#columns + 1] = { n = G.UIT.C, config = { align = 'tm', padding = 0.1, minw = 4.2 }, nodes = rows }
    end
    local content_row = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = columns }

    local MAXH = 6.4
    local body
    if SMODS.UIScrollBox and SMODS.GUI and SMODS.GUI.scrollbar then
        local scrollbox = SMODS.UIScrollBox({
            content = {
                definition = { n = G.UIT.ROOT, config = { colour = G.C.CLEAR }, nodes = { content_row } },
                config = { align = 'cm' },
            },
            overflow = { node_config = { maxh = MAXH, r = 0.1 } },
            sync_mode = 'offset',
        })
        body = { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, colour = G.C.BLACK }, nodes = {
            { n = G.UIT.C, config = {}, nodes = { { n = G.UIT.O, config = { object = scrollbox } } } },
            { n = G.UIT.C, config = { padding = 0.05 }, nodes = {
                SMODS.GUI.scrollbar({
                    w = 0.12, h = MAXH - 0.1,
                    scroll_collision_obj = scrollbox,
                    knob_h = MAXH / 6,
                    bg_colour = { 0, 0, 0, 0.2 },
                }),
            }},
        }}
    else
        body = { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, colour = G.C.BLACK }, nodes = { content_row } }
    end

    return create_UIBox_generic_options({
        back_func = 'setup_run',
        contents = {
            { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
                { n = G.UIT.T, config = { text = 'Mutation List', scale = 0.6,
                                          colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            }},
            body,
        },
    })
end

G.FUNCS.mvp_mutation_list = function(e)
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{ definition = G.UIDEF.mvp_mutation_list() }
end

local mvp_uidef_challenges = G.UIDEF.challenges
function G.UIDEF.challenges(from_game_over)
    local t = mvp_uidef_challenges(from_game_over)
    local first = t and t.nodes and t.nodes[1]
    if not (first and first.config and first.config.colour == G.C.BLACK) then return t end
    table.insert(t.nodes, 2, erratic_box(from_game_over))
    return t
end

--============================================================
-- View Deck: the Mutations tab
--============================================================
local function flux_entry()
    return { name = 'Flux', category = 'Flux', text = flux_text() }
end

function G.UIDEF.mvp_mutations_tab(args)
    local rows = {}
    local list = MVP.mutation_list()
    if G.GAME and G.GAME.mvp_flux then table.insert(list, 1, flux_entry()) end
    for _, mt in ipairs(list) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
            { n = G.UIT.T, config = { text = mt.name, scale = 0.4,
                                      colour = CAT_COLOUR[mt.category] or G.C.PURPLE, shadow = true } },
        }}
        for _, line in ipairs(mt.text or {}) do
            rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.01 }, nodes = {
                { n = G.UIT.T, config = { text = strip_markup(line), scale = 0.28, colour = G.C.UI.TEXT_LIGHT } },
            }}
        end
        local ok, detail = pcall(mt.detail or function() end)
        if ok and detail then
            rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.01 }, nodes = {
                { n = G.UIT.T, config = { text = detail, scale = 0.28, colour = G.C.FILTER } },
            }}
        end
    end
    if #rows == 0 then
        rows[1] = { n = G.UIT.R, config = { align = 'cm' }, nodes = {
            { n = G.UIT.T, config = { text = 'No mutations this run', scale = 0.4, colour = G.C.UI.TEXT_INACTIVE } },
        }}
    end
    return { n = G.UIT.ROOT, config = { align = 'cm', padding = 0.1, colour = G.C.CLEAR, minw = 8 }, nodes = rows }
end

local mvp_deck_info = G.UIDEF.deck_info
function G.UIDEF.deck_info(_show_remaining)
    if not (G.GAME and G.GAME.mvp_mutation
            and ((G.GAME.mvp_mutations and #G.GAME.mvp_mutations > 0) or G.GAME.mvp_flux)) then
        return mvp_deck_info(_show_remaining)
    end
    local tabs = _show_remaining and {
        { label = localize('b_remaining'), chosen = true,
          tab_definition_function = G.UIDEF.view_deck, tab_definition_function_args = true },
        { label = localize('b_full_deck'), tab_definition_function = G.UIDEF.view_deck },
    } or {
        { label = localize('b_full_deck'), chosen = true, tab_definition_function = G.UIDEF.view_deck },
    }
    tabs[#tabs + 1] = { label = 'Mutations', tab_definition_function = G.UIDEF.mvp_mutations_tab }
    return create_UIBox_generic_options({ contents = { create_tabs({ tabs = tabs, tab_h = 8, snap_to_nav = true }) } })
end

--============================================================
-- Completed-run bookkeeping
--============================================================
local mvp_erratic_update = Game.update
function Game:update(dt)
    mvp_erratic_update(self, dt)
    if G.GAME and G.GAME.mvp_mutation and G.GAME.won and not G.GAME.mvp_win_recorded then
        G.GAME.mvp_win_recorded = true
        record_mutation_win()
    end
end
