-- Pinochle - sandbox challenges

SMODS.Challenge{
    key = 'naneinf_lite',
    loc_txt = { name = 'NANEINF Lite' },
    rules = {
        custom = { { id = 'mvp_sandbox' } },
        modifiers = {
            { id = 'hand_size',        value = 11 },
            { id = 'joker_slots',      value = 7 },
            { id = 'consumable_slots', value = 3 },
            { id = 'hands',            value = 5 },   
            { id = 'discards',         value = 4 },   
            { id = 'dollars',          value = 20 },
        },
    },
    jokers = {
        { id = 'j_perkeo',     edition = 'negative' },
        { id = 'j_ring_master', edition = 'negative' },  
    },
    consumeables = {},
    vouchers = {},
    deck = { type = 'Challenge Deck' },
    restrictions = { banned_cards = {}, banned_tags = {}, banned_other = {} },
    unlocked = function(self) return true end,
}

-- Amulet required for the custom operator challenges
local has_amulet = Talisman and Talisman.Amulet
    and SMODS.Scoring_Calculations
    and SMODS.Scoring_Calculations.talisman_hyper

if not has_amulet then return end

local base_get_blind_amount = get_blind_amount

local function round_ensign_target(amount)
    local plain_amount = MVP.plain(amount)
    local switch_point = G.E_SWITCH_POINT or 1e11
    if not plain_amount or plain_amount >= switch_point then return amount end

    local step
    if plain_amount < 10000 then
        step = 1000
    elseif plain_amount < 100000 then
        step = 10000
    elseif plain_amount < 1e8 then
        step = 100000
    elseif plain_amount < 1e9 then
        step = 1e6
    else
        step = 1e8
    end
    return to_big(math.floor(plain_amount / step + 0.5) * step)
end

local function ensign_blind_amount(ante)
    local plain_ante = MVP.plain(ante)
    if plain_ante and plain_ante <= 8 then
        return to_big(100 * plain_ante * plain_ante)
    end

    local progress = to_big(ante) - to_big(8)
    local growth = to_big(1.6)
        + (to_big(0.75) * progress) ^ (to_big(1) + to_big(0.2) * progress)
    local amount = to_big(6400) * growth ^ (progress / to_big(2))
    return round_ensign_target(amount)
end

local function commander_blind_amount(ante)
    local plain_ante = MVP.plain(ante)
    if plain_ante == 1 then return to_big(10) ^ to_big(7) end
    if plain_ante == 2 then return to_big(10) ^ to_big(16) end
    if plain_ante and plain_ante <= 8 then
        local height = math.max(
            2,
            math.floor(3 * ((10000 / 3) ^ ((plain_ante - 2) / 6)) + 0.5)
        )
        local power_scaled = to_big(100):arrow(1, to_big(height))
        local original = to_big(10) ^ to_big((plain_ante + 2) ^ 2)
        return power_scaled > original and power_scaled or original
    end

    local progress = (to_big(ante) - to_big(8)) / to_big(31)
    local height = to_big(10000) * (to_big(5e147) ^ progress)
    return to_big(100):arrow(1, height)
end

local function captain_blind_amount(ante)
    local plain_ante = MVP.plain(ante)
    local height
    if plain_ante then
        height = math.max(
            2,
            math.floor(3 * ((10000 / 3) ^ ((plain_ante - 2) / 6)) + 0.5)
        )
    else
        height = (
            to_big(3) * (to_big(10000 / 3) ^ ((to_big(ante) - 2) / 6)) + 0.5
        ):floor()
        if height < to_big(2) then height = to_big(2) end
    end
    return to_big(100):arrow(2, to_big(height))
end

get_blind_amount = function(ante)
    if G and G.GAME and G.GAME.modifiers then
        if G.GAME.modifiers.mvp_captain then
            return captain_blind_amount(ante)
        elseif G.GAME.modifiers.mvp_commander then
            return commander_blind_amount(ante)
        elseif G.GAME.modifiers.mvp_ensign then
            return ensign_blind_amount(ante)
        end
    end
    return base_get_blind_amount(ante)
end

-- OmegaNum only. BigAnte is session-wide, so forcing it gave every later run a big-number
-- ante, which crashes mods that loop over antes (Cartomancer's blind info). These curves
-- take a plain ante.
local function force_amulet_features()
    Talisman.forced_features.force_omeganum()
end

local function set_commander_scoring()
    force_amulet_features()
    SMODS.set_scoring_calculation('exponent')
end

local function set_ensign_scoring()
    force_amulet_features()
    SMODS.set_scoring_calculation('add')
end

local function set_captain_scoring()
    force_amulet_features()
    G.GAME.hyper_operator = 2
    SMODS.set_scoring_calculation('talisman_hyper')
end

local start_run_ref = Game.start_run
function Game:start_run(args)
    start_run_ref(self, args)
    if not (G.GAME and G.GAME.modifiers) then return end
    -- Runs saved while BigAnte was forced still load with a big ante.
    local ante = G.GAME.round_resets and G.GAME.round_resets.ante
    if ante and is_big and is_big(ante) and not Talisman.big_ante.has() then
        Talisman.big_ante.disable()
    end
    if G.GAME.modifiers.mvp_captain then
        set_captain_scoring()
    elseif G.GAME.modifiers.mvp_commander then
        set_commander_scoring()
    elseif G.GAME.modifiers.mvp_ensign then
        set_ensign_scoring()
    end
end

SMODS.Challenge{
    key = 'ensign',
    loc_txt = { name = 'Ensign' },
    rules = {
        custom = { { id = 'mvp_ensign' }, { id = 'mvp_blind_scaling' } },
        modifiers = {},
    },
    apply = function(self)
        force_amulet_features()
    end,
    restrictions = { banned_cards = {}, banned_tags = {}, banned_other = {} },
    unlocked = function(self) return true end,
}

SMODS.Challenge{
    key = 'commander',
    loc_txt = { name = 'Commander' },
    rules = {
        custom = { { id = 'mvp_commander' }, { id = 'mvp_blind_scaling' } },
        modifiers = {},
    },
    apply = function(self)
        force_amulet_features()
    end,
    restrictions = { banned_cards = {}, banned_tags = {}, banned_other = {} },
    unlocked = function(self) return true end,
}

SMODS.Challenge{
    key = 'captain',
    loc_txt = { name = 'Captain' },
    rules = {
        custom = { { id = 'mvp_captain' }, { id = 'mvp_blind_scaling' } },
        modifiers = {},
    },
    apply = function(self)
        force_amulet_features()
    end,
    restrictions = { banned_cards = {}, banned_tags = {}, banned_other = {} },
    unlocked = function(self) return true end,
}
