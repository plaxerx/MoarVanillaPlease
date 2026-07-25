return {
<<<<<<< Updated upstream
=======
    misc = {
        -- Custom challenge rules are rendered by the description screen with
        -- localize{type='text', key='ch_c_'..id}, which reads misc.v_text. Every id used
        -- in a challenge's rules.custom needs an entry here or the rule line reads ERROR.
        v_text = {
            ch_c_eeng_no_refunds     = { "All sell values are set to {C:money}$0{}" },
            ch_c_eeng_black_market   = { "All shop prices are doubled" },
            ch_c_eeng_thrift_store   = { "Jokers and packs cost {C:attention}50%{} less" },
            ch_c_eeng_no_reroll      = { "The shop cannot be {C:attention}rerolled{}" },
            ch_c_eeng_impulse_buyer  = { "The first shop item buys itself if affordable" },
            ch_c_eeng_half_a_hand    = { "Can only select {C:attention}3{} cards at a time" },
            ch_c_eeng_slow_hands     = { "A big hand, but few to play. Play it slowly" },
            ch_c_eeng_suit_up        = { "Played hands must contain all 4 suits" },
            ch_c_eeng_one_trick      = { "Jokers you gain fill every slot with copies of itself. Selling one sells all copies" },
            ch_c_eeng_all_perishable = { "All Jokers are {C:eternal}Perishable{}" },
            ch_c_eeng_joker_draft    = { "Jokers are automatically sold for full value after each Boss Blind" },
            ch_c_eeng_poker_purist   = { "Each hand must beat the last played poker hand. {C:inactive}(Resets each round)" },
            ch_c_eeng_wild_west      = { "All cards except {C:attention}Wild{} cards are debuffed" },
            ch_c_eeng_balanstro      = { "Only your least played hand type may be played" },
            ch_c_eeng_double_down    = { "Jokers trigger twice. Blind sizes are doubled after Ante 1" },
            ch_c_eeng_final_form     = { "Gain {C:attention}+1{} Joker slot each Ante" },
            ch_c_eeng_recursion      = { "Scored cards are destroyed and replaced with random enhanced cards" },
            ch_c_eeng_glass_house    = { "Any hand that is not a {C:attention}Full House{} is destroyed" },
            ch_c_eeng_rusty_deck     = { "Steel cards are debuffed once played" },
            ch_c_eeng_tenant         = { "All Jokers are Rental. Income from blinds and hands is doubled" },
            ch_c_eeng_gambler        = { "First {C:attention}10{} rerolls are free, then {C:money}+$1{} each" },
            ch_c_eeng_gambler_risk   = { "Each reroll has a {C:green}1 in 6{} chance to destroy a Joker" },
            ch_c_eeng_long_game      = { "Must defeat Ante 16 to win" },
            ch_c_eeng_trial          = { "Every blind after Ante 1 is a Boss Blind" },
            ch_c_eeng_legendary_twist = { "{C:attention}Chicot{} is destroyed upon reaching {C:attention}Ante 8{}" },
        },
    },
>>>>>>> Stashed changes
    descriptions = {
        -- Supplied here rather than via loc_txt on purpose. SMODS only runs its
        -- "Applies <that one specific stake>" builder when loc_txt is NON-empty; with an
        -- empty loc_txt it leaves these alone, which is precisely how the vanilla stakes
        -- get the clean "Applies all previous Stakes" line. So we write that line ourselves.
        Stake = {
            stake_eeng_platinum = {
                name = "Platinum Stake",
                text = {
                    "Required score scales",
                    "faster for each {C:attention}Ante{}",
<<<<<<< Updated upstream
                    "{C:inactive}(Ante 1 needs {C:attention}350{C:inactive} chips)",
=======
>>>>>>> Stashed changes
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_titanium = {
                name = "Titanium Stake",
                text = {
                    "{C:red}+1{} Discard",
                    "{C:blue}-1{} Hand",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_diamond = {
                name = "Diamond Stake",
                text = {
<<<<<<< Updated upstream
                    "Must reach {C:attention}Ante 10{} to win",
                    "{C:attention}Boss Blinds{} appear every",
                    "{C:attention}8{} and {C:attention}10{} Antes",
=======
                    "Interest is earned per",
                    "{C:money}$7{} instead of {C:money}$5{}",
>>>>>>> Stashed changes
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_mythic = {
                name = "Mythic Stake",
                text = {
<<<<<<< Updated upstream
                    "{C:money}$1{} of interest is earned",
                    "per {C:money}$7{} instead of per {C:money}$5{}",
=======
                    "Must reach {C:attention}Ante 10{} to win.",
                    "{C:attention}Boss Blinds{} appear every",
                    "{C:attention}8{} and {C:attention}10{} Antes",
>>>>>>> Stashed changes
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_radiant = {
                name = "Radiant Stake",
                text = {
                    "{C:blue}+1{} Hand",
                    "{C:attention}-1{} Joker Slot",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_ascendant = {
                name = "Ascendant Stake",
                text = {
                    "Required score scales",
                    "even faster for each {C:attention}Ante{}",
                    "{C:inactive}(Ante 1 needs {C:attention}500{C:inactive} chips)",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_impossible = {
                name = "Impossible Stake",
                text = {
                    "{C:blue}-1{} Hand",
                    "{C:red}-1{} Discard",
                    "{C:attention}-1{} Hand Size",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_legendary = {
                name = "Legendary Stake",
                text = {
                    "Required score scales",
                    "much faster for each {C:attention}Ante{}",
                    "{C:inactive}(Ante 1 needs {C:attention}400{C:inactive} chips)",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
        },
        Other = {
            eeng_platinum_sticker = {
                name = "Platinum Sticker",
                text = { "Used to win on", "{C:attention}Platinum Stake{} difficulty" },
            },
            eeng_titanium_sticker = {
                name = "Titanium Sticker",
                text = { "Used to win on", "{C:attention}Titanium Stake{} difficulty" },
            },
            eeng_diamond_sticker = {
                name = "Diamond Sticker",
                text = { "Used to win on", "{C:attention}Diamond Stake{} difficulty" },
            },
            eeng_mythic_sticker = {
                name = "Mythic Sticker",
                text = { "Used to win on", "{C:attention}Mythic Stake{} difficulty" },
            },
            eeng_radiant_sticker = {
                name = "Radiant Sticker",
                text = { "Used to win on", "{C:attention}Radiant Stake{} difficulty" },
            },
            eeng_ascendant_sticker = {
                name = "Ascendant Sticker",
                text = { "Used to win on", "{C:attention}Ascendant Stake{} difficulty" },
            },
            eeng_impossible_sticker = {
                name = "Impossible Sticker",
                text = { "Used to win on", "{C:attention}Impossible Stake{} difficulty" },
            },
            eeng_legendary_sticker = {
                name = "Legendary Sticker",
                text = { "Used to win on", "{C:attention}Legendary Stake{} difficulty" },
            },
        },
        Sleeve = {
            sleeve_eeng_flux_alt = {
                name = "Flux Sleeve",
                text = {
                    "Deck already randomizes values,",
                    "so the {C:attention}run{} destabilizes:",
                    "{C:attention}hands{}, {C:attention}discards{}, {C:attention}hand size{},",
                    "{C:attention}Joker slots{}, {C:attention}consumables{} and {C:money}money{}",
                    "are repartitioned, and the deck is",
                    "rebuilt with {C:attention}#1#-#2#{} random cards",
                },
            },
            sleeve_eeng_roguelike_alt = {
                name = "Gauntlet Sleeve",
                text = {
                    "Every {C:red}Gauntlet{} is {C:attention}mandatory{}",
                    "Rewards are {C:attention}doubled{}: you get",
                    "{C:attention}two copies{} of the listed Tag",
                },
            },
            sleeve_eeng_prismatic_alt = {
                name = "Prismatic Sleeve",
                text = {
                    "Deck already grants every upside,",
                    "so the sleeve {C:attention}retools{} instead:",
                    "4 more Vouchers, +2 consumable slots,",
                    "opening Tags, and {C:attention}75% Spades{}",
                    "{C:red}No stickers, no achievements{}",
                },
            },
        },
    },
}
