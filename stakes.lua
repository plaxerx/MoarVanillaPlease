-- Moar Vanilla Please - Stakes

SMODS.Atlas{ key = 'mvp_chips', path = 'mvp_chips.png', px = 29, py = 29 }
SMODS.Atlas{ key = 'mvp_stickers', path = 'mvp_stickers.png', px = 71, py = 95 }

--============================================================
-- Blind scaling
--============================================================

local mvp_get_blind_amount = get_blind_amount

local BLIND_TABLE = {
    [4] = { [0] = 100, 300, 1100, 4000, 12000, 30000, 80000,  160000, 300000 },  -- Platinum
    [5] = { [0] = 120, 350, 1200, 4800, 15000, 36000, 120000, 240000, 400000 },  -- Legendary
    [6] = { [0] = 150, 400, 1500, 6000, 20000, 50000, 160000, 320000, 500000 },  -- Ascendant
}

local PURPLE_ANTE8 = 200000

-- get_blind_amount hands back a big number (a table). Multiplying it is fine; flooring it
-- is not, and returning a plain number where a big is expected crashes scoring.
function get_blind_amount(ante)
    local mods = G.GAME and G.GAME.modifiers
    local tier = mods and mods.mvp_blind_tier
    if not tier or not BLIND_TABLE[tier] then
        return mvp_get_blind_amount(ante)
    end

    local tbl = BLIND_TABLE[tier]
    if ante <= 0 then return to_big and to_big(tbl[0]) or tbl[0] end
    if ante <= 8 then
        local v = tbl[ante]
        return to_big and to_big(v) or v
    end

    local base = mvp_get_blind_amount(ante)
    local mult = tbl[8] / PURPLE_ANTE8          -- 1.5x for Platinum, 2.0x for Legendary
    return (to_big and to_big(base) or base) * mult
end
SMODS.get_blind_amount = get_blind_amount

local function set_blinds(tier)
    local mods = G.GAME.modifiers
    mods.mvp_blind_tier = math.max(mods.mvp_blind_tier or 0, tier)
end

--============================================================
-- Boss cadence (Mythic): showdown Boss Blinds also land on multiples of 8
--============================================================
local mvp_get_new_boss = get_new_boss
function get_new_boss()
    local mods = G.GAME and G.GAME.modifiers
    if mods and mods.mvp_boss_cadence and G.GAME.round_resets and G.GAME.win_ante then
        local a = G.GAME.round_resets.ante
        if a > 0 and a % 8 == 0 and a % G.GAME.win_ante ~= 0 then
            local saved = G.GAME.win_ante
            G.GAME.win_ante = 8
            local boss = mvp_get_new_boss()
            G.GAME.win_ante = saved
            return boss
        end
    end
    return mvp_get_new_boss()
end

--============================================================
-- PLATINUM  - the requirement climbs harder
--============================================================
SMODS.Stake{
    key = 'platinum',
    order = 9,
    name = 'Platinum Stake',
    atlas = 'mvp_chips',
    pos = { x = 0, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 0, y = 0 },
    applied_stakes = { 'gold' },
    -- SMODS auto-prefixes applied_stakes entries, and modify_key skips a prefix already
    -- there - so a hand-written 'stake_gold' still gets 'mvp_' bolted on. Write the bare
    -- vanilla key and switch the mod prefix off.
    prefix_config = { applied_stakes = { mod = false } },
    unlocked_stake = 'mvp_titanium',
    colour = HEX('E2E4E8'),          -- cold pale silver
    loc_txt = {},
    modifiers = function()
        set_blinds(4)   -- Platinum column
    end,
}

--============================================================
-- TITANIUM - your discard comes back, a hand goes away
--============================================================
-- Gives back the discard Blue Stake took and removes a hand instead: strictly more
-- selection, strictly less scoring.
SMODS.Stake{
    key = 'titanium',
    order = 10,
    name = 'Titanium Stake',
    atlas = 'mvp_chips',
    pos = { x = 1, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 1, y = 0 },
    applied_stakes = { 'mvp_platinum' },
    unlocked_stake = 'mvp_diamond',
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
-- wrapper below and the "/5" spots patched in lovely/mvp_patches.toml.
SMODS.Stake{
    key = 'diamond',
    order = 11,
    name = 'Diamond Stake',
    atlas = 'mvp_chips',
    pos = { x = 2, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 2, y = 0 },
    applied_stakes = { 'mvp_titanium' },
    unlocked_stake = 'mvp_legendary',
    colour = HEX('B0ECFC'),          -- icy cyan
    loc_txt = {},
    modifiers = function()
        G.GAME.mvp_interest_7 = true
    end,
}

--============================================================
-- LEGENDARY - the ceiling
--============================================================

SMODS.Stake{
    key = 'legendary',
    order = 12,
    name = 'Legendary Stake',
    atlas = 'mvp_chips',
    pos = { x = 3, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 3, y = 0 },
    applied_stakes = { 'mvp_diamond' },
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
    atlas = 'mvp_chips',
    pos = { x = 4, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 4, y = 0 },
    applied_stakes = { 'mvp_legendary' },
    unlocked_stake = 'mvp_radiant',
    colour = HEX('7A3FB8'),
    loc_txt = {},
    modifiers = function()
        G.GAME.win_ante = 10
        G.GAME.modifiers.mvp_boss_cadence = true
    end,
}

-- Diamond's $7 interest: holds interest_amount at 1 so the shop reads "1 interest per $7".
local mvp_eval_round = G.FUNCS.evaluate_round
G.FUNCS.evaluate_round = function(...)
    if G.GAME and G.GAME.mvp_interest_7 then
        G.GAME.interest_amount = 1
    end
    return mvp_eval_round(...)
end

--============================================================
-- RADIANT - one more hand, one fewer Joker
--============================================================
SMODS.Stake{
    key = 'radiant',
    order = 14,
    name = 'Radiant Stake',
    atlas = 'mvp_chips',
    pos = { x = 5, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 5, y = 0 },
    applied_stakes = { 'mvp_mythic' },
    unlocked_stake = 'mvp_ascendant',
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
    atlas = 'mvp_chips',
    pos = { x = 6, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 6, y = 0 },
    applied_stakes = { 'mvp_radiant' },
    unlocked_stake = 'mvp_impossible',
    colour = HEX('2FA05A'),
    loc_txt = {},
    modifiers = function()
        set_blinds(6)   -- Ascendant column
    end,
}

--============================================================
-- IMPOSSIBLE - good luck
--============================================================
SMODS.Stake{
    key = 'impossible',
    order = 16,
    name = 'Impossible Stake',
    atlas = 'mvp_chips',
    pos = { x = 7, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 7, y = 0 },
    applied_stakes = { 'mvp_ascendant' },
    colour = HEX('C4183C'),
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.hands = math.max(1, sp.hands - 1)
        sp.discards = math.max(0, sp.discards - 1)
        sp.hand_size = math.max(3, sp.hand_size - 1)
    end,
}
