-- Moar Stats Please - the stat registry.
--
-- ONE source of truth. Every counter the mod tracks is declared here with its label and
-- display format; the trackers write these keys, the store sums them, and the UI walks this
-- table to draw itself. Adding a stat means adding a row here and one MSP.inc call.
--
-- fmt: int (default) | money | score | pct | x | avg | time
-- A `derive` entry is not stored - it is computed from the stored counters at draw time, so
-- rates and averages never go stale and never need a migration.

MSP.CATS = {
    { id = 'hands',   label = 'Hands' },
    { id = 'cards',   label = 'Cards' },
    { id = 'blinds',  label = 'Blinds' },
    { id = 'economy', label = 'Economy' },
    { id = 'shop',    label = 'Shop' },
    { id = 'items',   label = 'Jokers & Consumables' },
    { id = 'deck',    label = 'Deck' },
    { id = 'meta',    label = 'Runs' },
}

local S = {}
local function stat(cat, key, label, fmt, opts)
    local e = { cat = cat, key = key, label = label, fmt = fmt or 'int' }
    for k, v in pairs(opts or {}) do e[k] = v end
    S[#S + 1] = e
end

--============================================================
-- Hands
--============================================================
stat('hands', 'hands_played',      'Hands played')
stat('hands', 'discards_used',     'Discards used')
stat('hands', 'hands_unused',      'Hands left unplayed')
stat('hands', 'discards_unused',   'Discards left unused')
stat('hands', 'total_score',       'Total chips scored', 'score')
stat('hands', 'hands_leveled',     'Hand levels gained')
stat('hands', 'one_hand_rounds',   'Blinds cleared in one hand')
stat('hands', 'no_discard_rounds', 'Blinds cleared without discarding')
stat('hands', 'hands_debuffed',    'Hands nullified by a Boss')
stat('hands', 'royal_flushes',     'Royal Flushes')
stat('hands', 'avg_score',         'Average hand score', 'score',
     { derive = function(t) return MSP.num(t.hands_played) > 0 and MSP.num(t.total_score) / MSP.num(t.hands_played) or 0 end })

--============================================================
-- Cards
--============================================================
stat('cards', 'cards_played',     'Cards played')
stat('cards', 'cards_discarded',  'Cards discarded')
stat('cards', 'cards_drawn',      'Cards drawn')
stat('cards', 'cards_scored',     'Cards that scored')
stat('cards', 'cards_unscored',   'Cards played that did not score')
stat('cards', 'face_played',      'Face cards played')
stat('cards', 'aces_played',      'Aces played')
stat('cards', 'numbered_played',  'Numbered cards played')
stat('cards', 'enhanced_played',  'Enhanced cards played')
stat('cards', 'edition_played',   'Edition cards played')
stat('cards', 'sealed_played',    'Sealed cards played')
stat('cards', 'debuffed_played',  'Debuffed cards played')
stat('cards', 'retriggers',       'Card retriggers')

--============================================================
-- Blinds
--============================================================
stat('blinds', 'blinds_defeated', 'Blinds defeated')
stat('blinds', 'small_defeated',  'Small Blinds defeated')
stat('blinds', 'big_defeated',    'Big Blinds defeated')
stat('blinds', 'boss_defeated',   'Boss Blinds defeated')
stat('blinds', 'blinds_skipped',  'Blinds skipped')
stat('blinds', 'boss_rerolls',    'Boss Blinds rerolled')
stat('blinds', 'tags_taken',      'Tags taken')
stat('blinds', 'rounds',          'Rounds played')
stat('blinds', 'antes',           'Antes cleared')
stat('blinds', 'skip_rate',       'Blinds skipped', 'pct',
     { derive = function(t)
         local d = MSP.num(t.blinds_defeated) + MSP.num(t.blinds_skipped)
         return d > 0 and 100 * MSP.num(t.blinds_skipped) / d or 0
       end })

--============================================================
-- Economy
--============================================================
stat('economy', 'earned_total',    'Money earned', 'money')
stat('economy', 'earned_blinds',   'From blind rewards', 'money')
stat('economy', 'earned_interest', 'From interest', 'money')
stat('economy', 'earned_hands',    'From unused hands', 'money')
stat('economy', 'earned_jokers',   'From Jokers', 'money')
stat('economy', 'earned_sales',    'From selling', 'money')
stat('economy', 'earned_other',    'From everything else', 'money')
stat('economy', 'spent_total',     'Money spent', 'money')
stat('economy', 'spent_cards',     'On shop cards', 'money')
stat('economy', 'spent_vouchers',  'On Vouchers', 'money')
stat('economy', 'spent_packs',     'On Booster Packs', 'money')
stat('economy', 'spent_rerolls',   'On rerolls', 'money')
stat('economy', 'rent_paid',       'Rent paid', 'money')
stat('economy', 'times_broke',     'Times at $0 or less')
stat('economy', 'interest_caps',   'Rounds at the interest cap')
stat('economy', 'net_dollars',     'Net cash flow', 'money',
     { derive = function(t) return MSP.num(t.earned_total) - MSP.num(t.spent_total) end })

--============================================================
-- Shop
--============================================================
stat('shop', 'shop_visits',       'Shops visited')
stat('shop', 'rerolls',           'Rerolls')
stat('shop', 'cards_bought',      'Cards bought')
stat('shop', 'jokers_bought',     'Jokers bought')
stat('shop', 'tarots_bought',     'Tarots bought')
stat('shop', 'planets_bought',    'Planets bought')
stat('shop', 'spectrals_bought',  'Spectrals bought')
stat('shop', 'playing_bought',    'Playing cards bought')
stat('shop', 'vouchers_bought',   'Vouchers redeemed')
stat('shop', 'packs_bought',      'Booster Packs bought')
stat('shop', 'packs_opened',      'Booster Packs opened')
stat('shop', 'pack_cards_taken',  'Cards taken from packs')
stat('shop', 'packs_skipped',     'Booster Packs skipped')
stat('shop', 'avg_rerolls',       'Rerolls per shop', 'avg',
     { derive = function(t) return MSP.num(t.shop_visits) > 0 and MSP.num(t.rerolls) / MSP.num(t.shop_visits) or 0 end })

--============================================================
-- Jokers & consumables
--============================================================
stat('items', 'jokers_gained',     'Jokers gained')
stat('items', 'jokers_sold',       'Jokers sold')
stat('items', 'jokers_destroyed',  'Jokers destroyed')
stat('items', 'cards_sold',        'Cards sold')
stat('items', 'consumables_used',  'Consumables used')
stat('items', 'tarots_used',       'Tarots used')
stat('items', 'planets_used',      'Planets used')
stat('items', 'spectrals_used',    'Spectrals used')
stat('items', 'negatives_seen',    'Negative cards obtained')
stat('items', 'legendaries_seen',  'Legendary Jokers obtained')

--============================================================
-- Deck
--============================================================
stat('deck', 'cards_added',       'Cards added to deck')
stat('deck', 'cards_destroyed',   'Cards destroyed')
stat('deck', 'enhancements_set',  'Enhancements applied')
stat('deck', 'editions_set',      'Editions applied')
stat('deck', 'seals_set',         'Seals applied')

--============================================================
-- Runs (career only - a run does not count itself)
--============================================================
stat('meta', 'runs_started',   'Runs started',   'int', { career_only = true })
stat('meta', 'runs_won',       'Runs won',       'int', { career_only = true })
stat('meta', 'runs_lost',      'Runs lost',      'int', { career_only = true })
stat('meta', 'runs_abandoned', 'Runs abandoned', 'int', { career_only = true })
stat('meta', 'playtime',       'Time played',    'time')
stat('meta', 'win_rate',       'Win rate',       'pct',
     { career_only = true,
       derive = function(t)
         local f = MSP.num(t.runs_won) + MSP.num(t.runs_lost)
         return f > 0 and 100 * MSP.num(t.runs_won) / f or 0
       end })

MSP.STATS = S

-- Fast key -> entry lookup, and the per-category ordered lists the UI draws from.
MSP.STAT_BY_KEY = {}
MSP.STATS_BY_CAT = {}
for _, e in ipairs(S) do
    MSP.STAT_BY_KEY[e.key] = e
    MSP.STATS_BY_CAT[e.cat] = MSP.STATS_BY_CAT[e.cat] or {}
    local list = MSP.STATS_BY_CAT[e.cat]
    list[#list + 1] = e
end

--============================================================
-- Records
--============================================================
-- Career highs. `mag` marks the ones held as magnitudes (MSP.mag) rather than plain numbers,
-- because a score can outgrow a double.
MSP.RECORDS = {
    { key = 'best_hand',     label = 'Best hand',            fmt = 'score', mag = true },
    { key = 'best_chips',    label = 'Most chips',           fmt = 'score', mag = true },
    { key = 'best_mult',     label = 'Most mult',            fmt = 'score', mag = true },
    { key = 'best_overkill', label = 'Biggest overkill',     fmt = 'x' },
    { key = 'high_ante',     label = 'Highest ante' },
    { key = 'high_round',    label = 'Highest round' },
    { key = 'most_money',    label = 'Most money',           fmt = 'money' },
    { key = 'most_jokers',   label = 'Most Jokers held' },
    { key = 'biggest_deck',  label = 'Largest deck' },
    { key = 'win_streak',    label = 'Best win streak' },
    { key = 'loss_streak',   label = 'Worst loss streak' },
    { key = 'longest_run',   label = 'Longest run',          fmt = 'time' },
    { key = 'fastest_win',   label = 'Fastest win',          fmt = 'time', lowest = true },
    { key = 'fewest_hands_win', label = 'Fewest hands to win', lowest = true },
}

--============================================================
-- Card breakdown groups
--============================================================
-- Nested tallies keyed by suit / rank / enhancement etc. Kept out of the flat counter list
-- because their keys come from the game, not from us: a modded suit or enhancement lands
-- here on its own without a schema edit.
MSP.GROUPS = {
    { id = 'suits',        label = 'Cards played by suit' },
    { id = 'ranks',        label = 'Cards played by rank' },
    { id = 'enhancements', label = 'Enhancements played' },
    { id = 'editions',     label = 'Editions played' },
    { id = 'seals',        label = 'Seals played' },
    -- 'hands' is deliberately absent: poker hands get their own table, drawn from the full
    -- roster so hands you have never landed still show, which a sorted-by-count group cannot
    -- do.
    { id = 'jokers',       label = 'Jokers' },
    { id = 'joker_scale',  label = 'Joker scaling (best reached)' },
    { id = 'consumables',  label = 'Consumables used' },
    { id = 'vouchers',     label = 'Vouchers redeemed' },
    { id = 'tags',         label = 'Tags taken' },
    { id = 'bosses',       label = 'Boss Blinds' },
    { id = 'packs',        label = 'Booster Packs' },
    { id = 'decks',        label = 'Decks' },
    { id = 'sleeves',      label = 'Sleeves' },
    { id = 'stakes',       label = 'Stakes' },
}
