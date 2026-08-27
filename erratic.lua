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
         mods().mvp_mut_blind_mult = 2
         sp().hands = (sp().hands or 4) + 2
         sp().discards = (sp().discards or 3) + 2
     end }

mut{ key = 'sudden_death', name = 'Sudden Death', category = 'Challenge',
     text = { 'One hand per Blind', 'Start with {C:dark_edition}Negative{} {C:attention}Dusk{}' },
     conflicts = { 'painted_hands', 'quick_hands', 'double_trouble' },
     apply = function()
         sp().hands = 1
         start_joker('j_dusk', 'negative') 
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

mut{ key = 'poverty', name = 'Poverty', category = 'Challenge',
     text = { 'Start with {C:money}$0{} and {C:dark_edition}Negative{} {C:attention}To Do List{}', 'No {C:attention}interest{}' },
     conflicts = { 'high_roller', 'capitalism', 'penny_pincher' },
     apply = function()
         sp().dollars = 0
         mods().no_interest = true   
         start_joker('j_todo_list', 'negative')
     end }

mut{ key = 'inflation', name = 'Inflation', category = 'Challenge',
     text = { 'Each reroll raises future', 'base reroll cost by {C:money}$1{}' },
     conflicts = { 'everything_must_go' },
     apply = function() mods().inflation = true end }  

mut{ key = 'no_refunds', name = 'No Refunds', category = 'Challenge',
     text = { 'Sell value of all items is {C:money}$0{}' },
     conflicts = { 'no_commitments', 'high_roller' },
     apply = function() mods().mvp_mut_no_refunds = true end }

mut{ key = 'minimalist', name = 'Minimalist', category = 'Challenge',
     text = { 'Start with {C:attention}3{} Joker slots' },
     conflicts = { 'collector' },
     apply = function() sp().joker_slots = 3 end }

mut{ key = 'eternal_kingdom', name = 'Eternal Kingdom', category = 'Challenge',
     text = { 'All {C:attention}Jokers{} are {C:eternal}Eternal{}' },
     conflicts = { 'rental_market', 'no_commitments' },
     apply = function() mods().all_eternal = true end }  

mut{ key = 'rental_market', name = 'Rental Market', category = 'Challenge',
     text = { 'All {C:attention}Jokers{} are {C:rental}Rental{}' },
     conflicts = { 'eternal_kingdom' },
     apply = function() mods().mvp_mut_all_rental = true end }

mut{ key = 'rare_earth', name = 'Rare Earth', category = 'Challenge',
     text = { '{C:red}Rare{} Jokers cannot appear' },
     conflicts = { 'no_common_sense', 'middle_child', 'equality' },
     apply = function() mods().mvp_mut_no_rare = true end }

mut{ key = 'no_common_sense', name = 'No Common Sense', category = 'Challenge',
     text = { '{C:attention}Common{} Jokers cannot appear' },
     conflicts = { 'rare_earth', 'middle_child' },
     apply = function() mods().mvp_mut_no_common = true end }

mut{ key = 'middle_child', name = 'Middle Child Syndrome', category = 'Challenge',
     text = { '{C:attention}Uncommon{} Jokers cannot appear' },
     conflicts = { 'rare_earth', 'no_common_sense' },
     apply = function() mods().mvp_mut_no_uncommon = true end }

mut{ key = 'no_magic', name = 'No Magic', category = 'Challenge',
     text = { 'No {C:tarot}Tarot{} cards' },
     conflicts = { 'arcane' },
     apply = function() mods().mvp_mut_no_tarots = true end }

mut{ key = 'no_science', name = 'No Science', category = 'Challenge',
     text = { 'No {C:planet}Planet{} cards' },
     conflicts = { 'astronomer' },
     apply = function() mods().mvp_mut_no_planets = true end }

mut{ key = 'go_with_the_flow', name = 'Go with the Flow', category = 'Challenge',
     text = { 'No {C:red}Discards{}', 'Start with {C:dark_edition}Negative{} {C:attention}Green Joker{}' },
     conflicts = { 'penny_pincher', 'aggressive', 'double_trouble' },
     apply = function()
         sp().discards = 0
         mods().mvp_mut_ban_discard_vouchers = true
         start_joker('j_green_joker', 'negative')
     end }

--============================================================
-- BOONS
--============================================================
mut{ key = 'high_roller', name = 'High Roller', category = 'Boon',
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

mut{ key = 'everything_must_go', name = 'Everything Must Go', category = 'Boon',
     text = { 'Everything is {C:attention}50%{} cheaper', '{C:red}-1{} Joker slot' },
     conflicts = { 'inflation', 'high_roller', 'no_refunds', 'minimalist', 'collector', 'card_pulls' },
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

mut{ key = 'heavy_deck', name = 'Heavy Deck', category = 'Boon',
     text = { 'Start with {C:attention}+48{} cards,', 'all {C:attention}randomly enhanced{}' },
     conflicts = { 'thin_deck', 'broken_deck', 'lucky_seven' },
     apply = function()
         mods().mvp_mut_deck_delta = 48
         mods().mvp_mut_all_enhanced = true
     end }

mut{ key = 'limited_edition', name = 'Limited Edition', category = 'Boon',
     text = { '{C:attention}10{} random starting cards', 'gain a random {C:dark_edition}edition{}' },
     conflicts = { 'broken_deck' },
     apply = function() mods().mvp_mut_random_editions = 10 end }

mut{ key = 'painted_hands', name = 'Painted Hands', category = 'Boon',
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

--============================================================
-- TWISTS
--============================================================
mut{ key = 'card_pulls', name = 'Card Pulls', category = 'Twist',
     text = { 'Everything in the shop costs {C:attention}2X{}', '{C:attention}Booster Packs{} cost {C:attention}50%{} less' },
     conflicts = { 'clearance_rack', 'everything_must_go' },
     apply = function()
         mods().mvp_mut_nonpack_mult = 2
         mods().mvp_mut_pack_price_mult = 0.5
     end }

mut{ key = 'capitalism', name = 'Capitalism', category = 'Twist',
     text = { '{C:money}Starting cash{}, {C:attention}interest cap{} and', 'shop prices are all {C:attention}doubled{}' },
     conflicts = { 'poverty', 'high_roller', 'everything_must_go', 'card_pulls' },
     apply = function()
         sp().dollars = (MVP.plain(sp().dollars) or 4) * 2
         G.GAME.interest_cap = (G.GAME.interest_cap or 25) * 2
         mods().mvp_mut_price_mult = 2
     end }

mut{ key = 'equality', name = 'Equality', category = 'Twist',
     text = { 'Jokers appear in {C:attention}random{} rarities' },
     conflicts = { 'rare_earth', 'no_common_sense', 'middle_child' },
     apply = function() mods().mvp_mut_random_rarity = true end }

mut{ key = 'no_commitments', name = 'No Commitments', category = 'Twist',
     text = { 'Leftmost {C:attention}Joker{} auto-sells for full', 'value each round. No {C:eternal}Eternal{} Jokers' },
     conflicts = { 'no_refunds' },
     apply = function() mods().mvp_mut_autosell_leftmost = true end }

mut{ key = 'thin_deck', name = 'Thin Deck', category = 'Twist',
     text = { 'Start with {C:attention}20{} random plain cards' },
     conflicts = { 'heavy_deck', 'broken_deck' },
     apply = function() mods().mvp_mut_deck_target = 20 end }

mut{ key = 'broken_deck', name = 'Broken Deck', category = 'Twist',
     text = { '{C:attention}10{} random starting cards', 'gain a random {C:attention}seal{}' },
     conflicts = { 'thin_deck', 'heavy_deck' },
     apply = function() mods().mvp_mut_random_seals = 10 end }

mut{ key = 'rankless', name = 'Rankless', category = 'Twist',
     text = { '{C:attention}Number cards{} become {C:attention}Stone Cards{}' },
     conflicts = { 'heavy_deck', 'thin_deck', 'courtless', 'wild_deck' },
     apply = function() mods().mvp_mut_numbers_to_stone = true end }

mut{ key = 'courtless', name = 'Courtless', category = 'Twist',
     text = { '{C:attention}Number cards{} removed', '{C:attention}Face cards{} tripled' },
     conflicts = { 'heavy_deck', 'thin_deck', 'rankless', 'wild_deck' },
     apply = function()
         mods().mvp_mut_no_numbers = true
         mods().mvp_mut_triple_faces = true
     end }

mut{ key = 'wild_deck', name = 'Wild Deck', category = 'Twist',
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

mut{ key = 'spectral_world', name = 'Spectral World', category = 'Twist',
     text = { 'Only {C:spectral}Spectral{} cards appear' },
     conflicts = { 'arcane', 'astronomer', 'no_magic', 'no_science' },
     apply = function()
         mods().mvp_mut_no_tarots = true
         mods().mvp_mut_no_planets = true
         mods().mvp_mut_spectral_rate = 4   
     end }

mut{ key = 'chaos_theory', name = 'Chaos Theory', category = 'Twist',
     text = { 'Hand types\' base {C:chips}Chips{} and', '{C:mult}Mult{} are randomized' },
     conflicts = {},
     apply = function() mods().mvp_mut_chaos_theory = true end }

mut{ key = 'clearance_rack', name = 'Clearance Rack', category = 'Twist',
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
        if #candidates == 0 then return false end
        local mt = candidates[math.random(1, #candidates)]
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
                sendWarnMessage('Mutation ' .. key .. ' failed to apply: ' .. tostring(err), 'ErraticMode')
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
    if dollars_changed then
        self.sound_pings = self.dollars + 2
        if G.GAME.current_round then
            G.GAME.current_round.dollars_to_be_earned =
                self.dollars > 0 and string.rep(localize('$'), self.dollars) or ''
        end
    end
end

local function apply_blind_hides()
    local bs = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
    if not bs then return end
    if mm('mvp_mut_no_small') then bs.Small = 'Hide' end
    if mm('mvp_mut_no_big') then bs.Big = 'Hide' end
end

local mvp_mut_reset_blinds = reset_blinds
function reset_blinds()
    mvp_mut_reset_blinds()
    apply_blind_hides()
end

local mvp_mut_get_new_boss = get_new_boss -- Double Boss
function get_new_boss()
    if mm('mvp_mut_finisher_cadence') and G.GAME.round_resets and G.GAME.win_ante then
        local a = G.GAME.round_resets.ante
        if a >= 4 and a % 4 == 0 and a % G.GAME.win_ante ~= 0 then
            local saved = G.GAME.win_ante
            G.GAME.win_ante = 4         
            local boss = mvp_mut_get_new_boss()
            G.GAME.win_ante = saved
            return boss
        end
    end
    return mvp_mut_get_new_boss()
end

local mvp_mut_calc_reroll = calculate_reroll_cost
function calculate_reroll_cost(skip_increment)
    mvp_mut_calc_reroll(skip_increment)
    local cr = G.GAME and G.GAME.current_round
    if mm('mvp_mut_reroll_surcharge') and cr and (MVP.plain(cr.free_rerolls) or 0) <= 0 then
        local c = MVP.plain(cr.reroll_cost) or 0
        cr.reroll_cost = c + mm('mvp_mut_reroll_surcharge')
    end
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
    return mvp_mut_eval_round(...)
end

local mvp_mut_set_cost = Card.set_cost  -- Shop prices for High Roller / Clearance Sale / Card Pulls / Collector / No Refunds.
function Card:set_cost()
    mvp_mut_set_cost(self)
    local any = mm('mvp_mut_price_mult') or mm('mvp_mut_nonpack_mult')
        or mm('mvp_mut_pack_price_mult') or mm('mvp_mut_joker_surcharge')
        or mm('mvp_mut_price_flat') or mm('mvp_mut_no_refunds')
    if not any then return end

    local set = self.ability and self.ability.set
    local c = MVP.plain(self.cost) or 0
    if c > 0 then
        if mm('mvp_mut_price_mult') then c = c * mm('mvp_mut_price_mult') end
        if mm('mvp_mut_nonpack_mult') and set ~= 'Booster' then c = c * mm('mvp_mut_nonpack_mult') end
        if mm('mvp_mut_pack_price_mult') and set == 'Booster' then c = c * mm('mvp_mut_pack_price_mult') end
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

local BANNED_RARITY = {
    mvp_mut_no_common   = { Common = true },
    mvp_mut_no_uncommon = { Uncommon = true },
    mvp_mut_no_rare     = { Rare = true, Legendary = true },
}

local mvp_mut_poll_rarity = SMODS.poll_rarity
function SMODS.poll_rarity(_pool_key, _rand_key)
    if _pool_key ~= 'Joker' then return mvp_mut_poll_rarity(_pool_key, _rand_key) end
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

    local saved = ot.rarities
    ot.rarities = kept
    local ok, r = pcall(mvp_mut_poll_rarity, _pool_key, _rand_key)
    ot.rarities = saved   -- restored on the error path too, or every later poll is skewed
    if not ok then return mvp_mut_poll_rarity(_pool_key, _rand_key) end
    return r
end

local mvp_mut_create_card = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    local c = mvp_mut_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    if c and c.ability and c.ability.set == 'Joker' then
        if mm('mvp_mut_all_rental') and not c.ability.rental and c.set_rental then -- set_rental/set_eternal rather than a direct ability write
            c:set_rental(true)
        end
        if mm('mvp_mut_autosell_leftmost') and c.ability.eternal and c.set_eternal then -- No Commitments: no Eternal Jokers, so the leftmost stays sellable.
            c:set_eternal(false)
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
end

local function ban_pool(pool_key)
    for _, v in ipairs(G.P_CENTER_POOLS[pool_key] or {}) do
        if v.key then G.GAME.banned_keys[v.key] = true end
    end
end


local CONSUMABLE_BAN = { -- Ban a whole consumable type: its cards, its Booster packs, and its skip Tag.
    Tarot  = { packs = 'arcana',    tag = 'tag_charm'  },
    Planet = { packs = 'celestial', tag = 'tag_meteor' },
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
            local fc = 0.5 + pseudorandom('mvp_mut_chaos_c') * 1.5
            local fm = 0.5 + pseudorandom('mvp_mut_chaos_m') * 1.5
            put(h, 'chips', fc); put(h, 's_chips', fc)
            put(h, 'mult', fm);  put(h, 's_mult', fm)
        end
    end
end

--============================================================
-- Deck rebuilds
--============================================================
local ENH = { 'm_bonus', 'm_mult', 'm_wild', 'm_glass', 'm_steel', 'm_gold', 'm_lucky' }
local SEALS = { 'Red', 'Blue', 'Gold', 'Purple' }

local function rebuild_deck()
    if not (G.playing_cards and #G.playing_cards > 0 and G.deck) then return end

    if mm('mvp_mut_wild_deck') or mm('mvp_mut_all_enhanced') then
        for _, c in ipairs(G.playing_cards) do
            local key = mm('mvp_mut_wild_deck') and 'm_wild' or ENH[pseudorandom('mvp_mut_enh', 1, #ENH)]
            if G.P_CENTERS[key] then c:set_ability(G.P_CENTERS[key], true, true) end
        end
    end
    local function pick_cards(n) -- Pick N distinct cards, shared by the random-seal / random-edition mutations.
        local idx, out = {}, {}
        for i = 1, #G.playing_cards do idx[i] = i end
        for _ = 1, math.min(n, #idx) do
            local pick = pseudorandom('mvp_mut_pick', 1, #idx)
            out[#out + 1] = G.playing_cards[idx[pick]]
            table.remove(idx, pick)
        end
        return out
    end

    if mm('mvp_mut_random_seals') then -- Broken Deck: N random cards get a random seal.
        for _, c in ipairs(pick_cards(mm('mvp_mut_random_seals'))) do
            c:set_seal(SEALS[pseudorandom('mvp_mut_seal', 1, #SEALS)], true, true)
        end
    end

    if mm('mvp_mut_random_editions') then -- Limited Edition: N random cards get a random edition.
        local EDS = { 'e_foil', 'e_holo', 'e_polychrome', 'e_negative' }
        for _, c in ipairs(pick_cards(mm('mvp_mut_random_editions'))) do
            local ek = EDS[pseudorandom('mvp_mut_edition', 1, #EDS)]
            if c.set_edition then c:set_edition({ [ek:gsub('^e_', '')] = true }, true, true) end
        end
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
    if not (G.GAME and G.GAME.mvp_mutations and #G.GAME.mvp_mutations > 0) then return end
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
                local card = create_card('Joker', G.jokers, nil, nil, nil, nil, j.k, 'mvp_mut')
                if j.e and card.set_edition then card:set_edition({ [j.e] = true }, true, true) end
                card:add_to_deck()
                G.jokers:emplace(card)
                return true
            end }))
        end
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

local function is_prismatic(key)
    return type(key) == 'string' and key:find('prismatic', 1, true) ~= nil
end

local function random_deck()
    local pool = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Back or {}) do
        if v.unlocked and not v.omit and not is_prismatic(v.key) then pool[#pool + 1] = v end
    end
    if #pool == 0 then return G.P_CENTERS.b_red end
    return pool[math.random(1, #pool)]
end

local function random_sleeve_key()
    if not CardSleeves then return nil end
    local pool = {}
    for _, s in pairs(G.P_CENTER_POOLS.Sleeve or {}) do
        if s.key and s.key ~= 'sleeve_casl_none' and not is_prismatic(s.key)
            and (type(s.is_unlocked) ~= 'function' or s:is_unlocked()) then
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

G.FUNCS.mvp_start_mutation = function(e)
    if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu() end
    local deck  = random_deck()
    local stake = math.random(STAKE_MIN, STAKE_MAX)
    if CardSleeves then -- If CardSleeves installed
        local sk = random_sleeve_key()
        if sk then G.viewed_sleeve = sk end
    end
    if G.GAME then G.GAME.viewed_back = Back(deck) end
    local count = mutation_count()
    mvp_pending = { count = count, keys = MVP.roll_mutations(count) }
    G.FUNCS.start_run(e, { stake = stake, deck = deck })
end

local mvp_apply_to_run = Back.apply_to_run
function Back:apply_to_run(...)
    local ours = false
    if mvp_pending and G.GAME then
        G.GAME.mvp_mutation = true
        G.GAME.mvp_mutation_count = mvp_pending.count
        G.GAME.mvp_mutations = mvp_pending.keys
        mvp_pending = nil
        mvp_finish_pending = true
        ours = true
        MVP.mutations_apply()   -- before the deck perk below
    end
    local ret = mvp_apply_to_run(self, ...)
    if ours then MVP.mutations_post_deck() end   -- deck and sleeve have both landed by here
    return ret
end

local mvp_erratic_start_run = Game.start_run
function Game:start_run(args)
    mvp_erratic_start_run(self, args)
    -- apply_to_run consumes this, but a save load skips that seam entirely, so clear it
    -- rather than leave a rolled set staged for whatever run starts next.
    mvp_pending = nil
    if mvp_finish_pending then
        mvp_finish_pending = false
        MVP.mutations_finish()   -- deck rebuild, now that G.deck exists
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
            UIBox_button({
                label = { 'Mutation List' },
                button = 'mvp_mutation_list',
                colour = G.C.GREY,
                minw = 3, scale = 0.3, minh = 0.4,
            }),
        }},
    }}
end

--============================================================
-- Mutation List overlay (reference inventory of every mutation)
--============================================================

local function strip_markup(s)
    return (tostring(s or ''):gsub('{[^}]*}', ''))
end

local CAT_COLOUR = { Challenge = G.C.RED, Boon = G.C.GREEN, Twist = G.C.PURPLE }
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
function G.UIDEF.mvp_mutations_tab(args)
    local rows = {}
    for _, mt in ipairs(MVP.mutation_list()) do
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
            { n = G.UIT.T, config = { text = mt.name, scale = 0.4,
                                      colour = CAT_COLOUR[mt.category] or G.C.PURPLE, shadow = true } },
        }}
        for _, line in ipairs(mt.text or {}) do
            rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.01 }, nodes = {
                { n = G.UIT.T, config = { text = strip_markup(line), scale = 0.28, colour = G.C.UI.TEXT_LIGHT } },
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
    if not (G.GAME and G.GAME.mvp_mutation and G.GAME.mvp_mutations
            and #G.GAME.mvp_mutations > 0) then
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
