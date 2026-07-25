-- Moar Vanilla Please - Stakes

SMODS.Atlas{ key = 'eeng_chips', path = 'eeng_chips.png', px = 29, py = 29 }
SMODS.Atlas{ key = 'eeng_stickers', path = 'eeng_stickers.png', px = 71, py = 95 }

--============================================================
-- Blind scaling
--============================================================

local eeng_get_blind_amount = get_blind_amount

-- EXACT blind requirements for antes 0-8, straight from the table. Antes 1-8 are not
-- derived from anything - they're looked up. The old version scaled off the vanilla curve
-- and rounded, which is why the numbers stopped landing on clean hundreds.
--
-- tier 4 = Platinum (and Titanium/Diamond, which inherit it), tier 5 = Legendary.
local BLIND_TABLE = {
<<<<<<< Updated upstream
    [4] = { [0] = 120, 350, 1100, 4000, 12000, 30000, 80000,  160000, 300000 },
    [5] = { [0] = 150, 400, 1200, 4800, 15000, 36000, 120000, 240000, 400000 },
    [6] = { [0] = 200, 500, 1500, 6000, 20000, 50000, 160000, 320000, 500000 },  -- Ascendant
=======
    [4] = { [0] = 100, 300, 1100, 4000, 12000, 30000, 80000,  160000, 300000 },  -- Platinum
    [5] = { [0] = 120, 350, 1200, 4800, 15000, 36000, 120000, 240000, 400000 },  -- Legendary
    [6] = { [0] = 150, 400, 1500, 6000, 20000, 50000, 160000, 320000, 500000 },  -- Ascendant
>>>>>>> Stashed changes
}

-- Past ante 8 the vanilla curve takes over again, lifted by the ratio between our ante-8
-- requirement and Purple's (200,000) - which is the scaling our stakes inherit.
local PURPLE_ANTE8 = 200000

-- TALISMAN: get_blind_amount hands back a BIG NUMBER (a table). Multiplying it is fine;
-- math.floor()ing it is not, and returning a plain number where a big is expected is what
-- crashed scoring with "attempt to compare number with table". Keep the type it gave us.
function get_blind_amount(ante)
    local mods = G.GAME and G.GAME.modifiers
    local tier = mods and mods.eeng_blind_tier
    if not tier or not BLIND_TABLE[tier] then
        return eeng_get_blind_amount(ante)
    end

    local tbl = BLIND_TABLE[tier]
    if ante <= 0 then return to_big and to_big(tbl[0]) or tbl[0] end
    if ante <= 8 then
        local v = tbl[ante]
        return to_big and to_big(v) or v
    end

    local base = eeng_get_blind_amount(ante)
    local mult = tbl[8] / PURPLE_ANTE8          -- 1.5x for Platinum, 2.0x for Legendary
    return (to_big and to_big(base) or base) * mult
end
SMODS.get_blind_amount = get_blind_amount

local function set_blinds(tier)
    local mods = G.GAME.modifiers
    mods.eeng_blind_tier = math.max(mods.eeng_blind_tier or 0, tier)
end

--============================================================
-- Boss cadence (Mythic): showdown Boss Blinds also land on multiples of 8
--============================================================
local eeng_get_new_boss = get_new_boss
function get_new_boss()
    local mods = G.GAME and G.GAME.modifiers
    if mods and mods.eeng_boss_cadence and G.GAME.round_resets and G.GAME.win_ante then
        local a = G.GAME.round_resets.ante
        if a > 0 and a % 8 == 0 and a % G.GAME.win_ante ~= 0 then
            local saved = G.GAME.win_ante
            G.GAME.win_ante = 8
            local boss = eeng_get_new_boss()
            G.GAME.win_ante = saved
            return boss
        end
    end
    return eeng_get_new_boss()
end

--============================================================
-- PLATINUM  - the requirement climbs harder
--============================================================
SMODS.Stake{
    key = 'platinum',
    order = 9,
    name = 'Platinum Stake',
    atlas = 'eeng_chips',
    pos = { x = 0, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 0, y = 0 },
    applied_stakes = { 'gold' },
    -- SMODS auto-prefixes applied_stakes entries (class AND mod), and modify_key skips
    -- a prefix that's already there. So a hand-written 'stake_gold' still gets the MOD
    -- prefix bolted on -> 'eeng_stake_gold' -> ERROR. Write the bare vanilla key and
    -- switch the mod prefix off; SMODS turns it into 'stake_gold' itself.
    prefix_config = { applied_stakes = { mod = false } },
    unlocked_stake = 'eeng_titanium',
    colour = HEX('E2E4E8'),          -- cold pale silver
    loc_txt = {},
    modifiers = function()
        set_blinds(4)   -- Platinum column
    end,
}

--============================================================
-- TITANIUM - your discard comes back, a hand goes away
--============================================================
-- Blue Stake took a discard off you six tiers ago. This gives it back and takes a hand
-- instead: strictly more selection, strictly less scoring. It reads as mercy and plays
-- as a squeeze.
SMODS.Stake{
    key = 'titanium',
    order = 10,
    name = 'Titanium Stake',
    atlas = 'eeng_chips',
    pos = { x = 1, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 1, y = 0 },
    applied_stakes = { 'eeng_platinum' },
    unlocked_stake = 'eeng_diamond',
    colour = HEX('7A8086'),          -- gunmetal
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.discards = sp.discards + 1
        sp.hands = math.max(1, sp.hands - 1)
    end,
}

--============================================================
-- DIAMOND - the vault gets tighter
--============================================================
-- Interest pays per $7 instead of vanilla's $5. The flag drives both the evaluate_round
-- wrapper below and the hardcoded "/5" spots patched in lovely/mvp_patches.toml.
SMODS.Stake{
    key = 'diamond',
    order = 11,
    name = 'Diamond Stake',
    atlas = 'eeng_chips',
    pos = { x = 2, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 2, y = 0 },
    applied_stakes = { 'eeng_titanium' },
    unlocked_stake = 'eeng_legendary',
    colour = HEX('B0ECFC'),          -- icy cyan
    loc_txt = {},
    modifiers = function()
        G.GAME.eeng_interest_7 = true
    end,
}

--============================================================
-- LEGENDARY - the ceiling
--============================================================

SMODS.Stake{
    key = 'legendary',
    order = 12,
    name = 'Legendary Stake',
    atlas = 'eeng_chips',
    pos = { x = 7, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 7, y = 0 },
    applied_stakes = { 'eeng_diamond' },
    colour = HEX('C448BE'),          -- iridescent magenta, gold sheen
    loc_txt = {},
    modifiers = function()
        set_blinds(5)   -- Legendary column
    end,
}

--============================================================
-- MYTHIC  - the run doesn't end at 8
--============================================================
SMODS.Stake{
    key = 'mythic',
    order = 13,
    name = 'Mythic Stake',
    atlas = 'eeng_chips',
    pos = { x = 4, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 4, y = 0 },
    applied_stakes = { 'eeng_legendary' },
    unlocked_stake = 'eeng_radiant',
    colour = HEX('7A3FB8'),
    loc_txt = {},
    modifiers = function()
        G.GAME.win_ante = 10
        G.GAME.modifiers.eeng_boss_cadence = true
    end,
}

<<<<<<< Updated upstream
-- Balatro HARDCODES the $5 interest step: payout = interest_amount * floor(dollars / 5).
-- So interest_amount is dollars-PER-$5, not the threshold - setting it to 7 paid $7 for
-- every $5, which is the exact opposite of the intent. To actually earn per $7, set
-- interest_amount so the product lands on floor(dollars / 7).
local eeng_eval_round = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function(...)
    if G.GAME and G.GAME.eeng_mythic then
        local d = math.max(0, EEng.plain(G.GAME.dollars) or 0)
        local steps = math.floor(d / 5)          -- what vanilla is about to multiply by
        local want  = math.floor(d / 7)          -- what we actually want to pay out
        G.GAME.interest_amount = (steps > 0) and (want / steps) or 0
=======
-- Diamond's $7 interest: hold interest_amount at 1 so the shop reads "1 interest per $7"
-- (the "/5"->"/7" step itself is patched in lovely/mvp_patches.toml).
local eeng_eval_round = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function(...)
    if G.GAME and G.GAME.eeng_interest_7 then
        G.GAME.interest_amount = 1
>>>>>>> Stashed changes
    end
    return eeng_eval_round(...)
end

--============================================================
-- RADIANT - one more hand, one fewer Joker
--============================================================
SMODS.Stake{
    key = 'radiant',
    order = 14,
    name = 'Radiant Stake',
    atlas = 'eeng_chips',
    pos = { x = 5, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 5, y = 0 },
    applied_stakes = { 'eeng_mythic' },
    unlocked_stake = 'eeng_ascendant',
    colour = HEX('E08A1E'),
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.hands = sp.hands + 1
        sp.joker_slots = math.max(1, sp.joker_slots - 1)
    end,
}

--============================================================
-- ASCENDANT - the requirement climbs again
--============================================================

SMODS.Stake{
    key = 'ascendant',
    order = 15,
    name = 'Ascendant Stake',
    atlas = 'eeng_chips',
    pos = { x = 6, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 6, y = 0 },
    applied_stakes = { 'eeng_radiant' },
    unlocked_stake = 'eeng_impossible',
    colour = HEX('2FA05A'),
    loc_txt = {},
    modifiers = function()
        set_blinds(6)   -- Ascendant column
    end,
}

--============================================================
-- IMPOSSIBLE - the name is the description
--============================================================
SMODS.Stake{
    key = 'impossible',
    order = 16,
    name = 'Impossible Stake',
    atlas = 'eeng_chips',
    pos = { x = 3, y = 0 },
    sticker_atlas = 'eeng_stickers', sticker_pos = { x = 3, y = 0 },
    applied_stakes = { 'eeng_ascendant' },
    colour = HEX('C4183C'),
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.hands = math.max(1, sp.hands - 1)
        sp.discards = math.max(0, sp.discards - 1)
        sp.hand_size = math.max(3, sp.hand_size - 1)
    end,
}
