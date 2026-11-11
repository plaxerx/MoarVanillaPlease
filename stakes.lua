-- Moar Stakes Please - stakes

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

--============================================================
-- Custom Functions
--============================================================

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

-- Mythic and beyond's new ante victory requirement. `roll` is whichever Boss roll is being
-- wrapped.
local function boss_cadence(roll, ...)
    local mods = G.GAME and G.GAME.modifiers
    if mods and mods.mvp_boss_cadence and G.GAME.round_resets and G.GAME.win_ante then
        local a = G.GAME.round_resets.ante
        if a > 0 and a % 8 == 0 and a % G.GAME.win_ante ~= 0 then
            local saved = G.GAME.win_ante
            G.GAME.win_ante = 8
            local boss = roll(...)
            G.GAME.win_ante = saved
            return boss
        end
    end
    return roll(...)
end

local mvp_get_new_boss = get_new_boss
function get_new_boss()
    return boss_cadence(mvp_get_new_boss)
end

-- Steamodded 26.x rolls each Ante's Boss through SMODS.get_new_blind and keeps get_new_boss
-- for the Boss reroll and the Boss Tag, so the cadence sits on both.
if SMODS.get_new_blind then
    local mvp_get_new_blind = SMODS.get_new_blind
    function SMODS.get_new_blind(blind_type, ...)
        if blind_type ~= nil and blind_type ~= 'boss' then return mvp_get_new_blind(blind_type, ...) end
        return boss_cadence(mvp_get_new_blind, blind_type, ...)
    end
end

--============================================================
-- INTEREST
--============================================================

function MVP.interest_step()
    if not G.GAME then return 5 end
    -- mvp_interest_7 is read only as a fallback, for a run saved before interest_step existed.
    return MVP.plain(G.GAME.interest_step) or (G.GAME.mvp_interest_7 and 7) or 5
end

local VANILLA_STEP = 5

function MVP.interest_payout()
    if not G.GAME then return 0 end
    local dollars = MVP.plain(G.GAME.dollars) or 0
    local cap = (MVP.plain(G.GAME.interest_cap) or 25) / VANILLA_STEP
    local amount = MVP.plain(G.GAME.interest_amount) or 1

    local base = math.min(math.floor(dollars / MVP.interest_step()), cap)
    if amount <= 1 then return amount * base end
    local bonus = math.min(math.floor(dollars / VANILLA_STEP), cap)
    return base + (amount - 1) * bonus
end


--============================================================
-- Added Stakes
--============================================================

SMODS.Stake{
    key = 'platinum',
    order = 9,
    name = 'Platinum Stake',
    atlas = 'mvp_chips',
    pos = { x = 0, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 0, y = 0 },
    applied_stakes = { 'gold' },
    prefix_config = { applied_stakes = { mod = false } },
    unlocked_stake = 'mvp_titanium',
    colour = HEX('E2E4E8'),
    shiny = true,
    loc_txt = {},
    modifiers = function()
        set_blinds(4)   -- increased blind requirements on row 4
    end,
}
SMODS.Stake{
    key = 'titanium',
    order = 10,
    name = 'Titanium Stake',
    atlas = 'mvp_chips',
    pos = { x = 1, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 1, y = 0 },
    applied_stakes = { 'mvp_platinum' },
    unlocked_stake = 'mvp_diamond',
    colour = HEX('7A8086'),
    shiny = true,
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.discards = sp.discards + 1 -- we returned your discard
        sp.hands = math.max(1, sp.hands - 1) -- for a price..
    end,
}
SMODS.Stake{
    key = 'diamond',
    order = 11,
    name = 'Diamond Stake',
    atlas = 'mvp_chips',
    pos = { x = 2, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 2, y = 0 },
    applied_stakes = { 'mvp_titanium' },
    unlocked_stake = 'mvp_legendary',
    colour = HEX('B0ECFC'),
    shiny = true,
    loc_txt = {},
    modifiers = function()
        -- A number any mod can set, not a stake-specific flag - see MVP.interest_step.
        G.GAME.interest_step = 7
    end,
}
SMODS.Stake{
    key = 'legendary', -- I placed this as the first realistic gate for difficulty, feel free to stop here...
    order = 12,
    name = 'Legendary Stake',
    atlas = 'mvp_chips',
    pos = { x = 3, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 3, y = 0 },
    applied_stakes = { 'mvp_diamond' },
    colour = HEX('C448BE'),
    shiny = true,
    loc_txt = {},
    modifiers = function()
        set_blinds(5)   -- increased blind requirements on row 5
    end,
}
SMODS.Stake{
    key = 'mythic', -- ...or don't, you have to win ante 10 now for the remaining 4 stakes!
    order = 13,
    name = 'Mythic Stake',
    atlas = 'mvp_chips',
    pos = { x = 4, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 4, y = 0 },
    applied_stakes = { 'mvp_legendary' },
    unlocked_stake = 'mvp_radiant',
    colour = HEX('7A3FB8'),
    shiny = true,
    loc_txt = {},
    modifiers = function()
        G.GAME.win_ante = 10
        G.GAME.modifiers.mvp_boss_cadence = true
    end,
}
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
    shiny = true,
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.hands = sp.hands + 1 -- I have altered the deal
        sp.joker_slots = math.max(1, sp.joker_slots - 1) -- Pray I do not alter the deal again
    end,
}
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
    shiny = true,
    loc_txt = {},
    modifiers = function()
        set_blinds(6)   -- increased blind requirements on row 5
    end,
}
SMODS.Stake{
    key = 'impossible',
    order = 16,
    name = 'Impossible Stake',
    atlas = 'mvp_chips',
    pos = { x = 7, y = 0 },
    sticker_atlas = 'mvp_stickers', sticker_pos = { x = 7, y = 0 },
    applied_stakes = { 'mvp_ascendant' },
    colour = HEX('C4183C'),
    shiny = true,
    loc_txt = {},
    modifiers = function()
        local sp = G.GAME.starting_params
        sp.hands = math.max(1, sp.hands - 1) -- I altered the deal again
        sp.discards = math.max(0, sp.discards - 1) -- good luck
        sp.hand_size = math.max(3, sp.hand_size - 1) -- you'll need it
    end,
}
