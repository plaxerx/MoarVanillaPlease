return {
    misc = {
        dictionary = {
            -- MoarChallengesPlease
            k_mvp_suit_up = "HANDS MUST CONTAIN ALL 4 SUITS",
        },
        v_text = {
            -- MoarChallengesPlease
            ch_c_mvp_no_refunds     = { "All sell values are set to {C:money}$0{}" },
            ch_c_mvp_black_market   = { "All shop prices are doubled" },
            ch_c_mvp_thrift_store   = { "Jokers and packs cost {C:attention}50%{} less" },
            ch_c_mvp_no_reroll      = { "The shop cannot be {C:attention}rerolled{}" },
            ch_c_mvp_impulse_buyer  = { "The first shop item buys itself if affordable" },
            ch_c_mvp_half_a_hand    = { "Can only select {C:attention}3{} cards at a time" },
            ch_c_mvp_slow_hands     = { "A big hand, but few to play. Play it slowly" },
            ch_c_mvp_suit_up        = { "Played hands must contain all 4 suits" },
            ch_c_mvp_one_trick      = { "Jokers you gain fill every slot with copies of itself. Selling one sells all copies" },
            ch_c_mvp_all_perishable = { "All Jokers are {C:eternal}Perishable{}" },
            ch_c_mvp_joker_draft    = { "Jokers are automatically sold for full value after each Boss Blind" },
            ch_c_mvp_poker_purist   = { "Each hand must beat the last played poker hand. {C:inactive}(Resets each round)" },
            ch_c_mvp_wild_west      = { "All cards except {C:attention}Wild{} cards are debuffed" },
            ch_c_mvp_balanstro      = { "Only your least played hand type may be played" },
            ch_c_mvp_double_down    = { "Jokers trigger twice. Blind sizes are doubled after Ante 1" },
            ch_c_mvp_final_form     = { "Gain {C:attention}+1{} Joker slot each Ante" },
            ch_c_mvp_recursion      = { "Scored cards are destroyed and replaced with random enhanced cards" },
            ch_c_mvp_glass_house    = { "Any hand that is not a {C:attention}Full House{} is destroyed" },
            ch_c_mvp_rusty_deck     = { "Steel cards are debuffed once played" },
            ch_c_mvp_tenant         = { "All Jokers are Rental. Income from blinds and hands is doubled" },
            ch_c_mvp_gambler        = { "First {C:attention}10{} rerolls are free, then {C:money}+$1{} each" },
            ch_c_mvp_gambler_risk   = { "Each reroll has a {C:green}1 in 6{} chance to destroy a Joker" },
            ch_c_mvp_long_game      = { "Must defeat Ante 16 to win" },
            ch_c_mvp_trial          = { "Every blind after Ante 1 is a Boss Blind" },
            ch_c_mvp_legendary_twist = { "{C:attention}Chicot{} is destroyed upon reaching {C:attention}Ante 8{}" },
            ch_c_mvp_homeless       = { "Start at {C:money}-$20{} with an {C:eternal}Eternal{} {C:attention}Vagabond{}" },
            ch_c_mvp_ivory_tower    = { "Only {C:attention}Jokers{} and {C:attention}Buffoon Packs{} appear. Start with {C:money}$20{}" },
            ch_c_mvp_new_beginnings = { "Only the {C:attention}Jokers{} from a fresh save appear" },
            ch_c_mvp_no_commons     = { "{C:attention}Common{} Jokers cannot appear" },
            ch_c_mvp_ancient_tech   = { "No {C:planet}Planet{} cards, packs or tags" },
            ch_c_mvp_stargazer      = { "No {C:tarot}Tarot{} cards, packs or tags" },
            ch_c_mvp_recovered      = { "Start with only {C:attention}face cards{}. Hand size is {C:attention}5{}" },
            ch_c_mvp_baby           = { "{C:attention}Jokers{} only add {C:chips}Chips{}, {C:mult}Mult{} and {C:money}money{}" },
            ch_c_mvp_baby_jokers    = { "No {C:attention}XMult{}, retriggers, copying or destruction" },
            ch_c_mvp_baby_bosses    = { "Boss Blinds have no ability. Blinds cannot be skipped" },
            -- Pinochle
            -- localize{type='text'} returns after the FIRST line, so one entry per rule row
            ch_c_mvp_sandbox       = { "Training for Ante 39 goals" },
            ch_c_mvp_ensign        = { "{C:attention}Chips/Mult{} operator becomes {C:chips,s:1.5}+{}" },
            ch_c_mvp_commander     = { "{C:attention}Chips/Mult{} operator becomes {C:dark_edition}^{}" },
            ch_c_mvp_captain       = { "{C:attention}Chips/Mult{} operator becomes {C:dark_edition}^^{}" },
            ch_c_mvp_blind_scaling = { "Custom blind scaling" },
        },
    },
    descriptions = {
        -- MoarStakesPlease
        Stake = {
            stake_mvp_platinum = {
                name = "Platinum Stake",
                text = {
                    "Required score scales",
                    "faster for each {C:attention}Ante{}",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_titanium = {
                name = "Titanium Stake",
                text = {
                    "{C:red}+1{} Discard",
                    "{C:blue}-1{} Hand",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_diamond = {
                name = "Diamond Stake",
                text = {
                    "Interest is earned per",
                    "{C:money}$7{} instead of {C:money}$5{}",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_legendary = {
                name = "Legendary Stake",
                text = {
                    "{s:0.8}Required score scales",
                    "{s:0.8}even faster for each {s:0.8,C:attention}Ante{}",
                    "{s:0.8,C:inactive}(Ante 1 included){}",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_mythic = {
                name = "Mythic Stake",
                text = {
                    "{s:0.8}Must reach {s:0.8,C:attention}Ante 10{s:0.8} to win.",
                    "{s:0.8,C:attention}Boss Blinds{s:0.8} appear every",
                    "{s:0.8,C:attention}8{s:0.8} and {s:0.8,C:attention}10{s:0.8} Antes",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_radiant = {
                name = "Radiant Stake",
                text = {
                    "{C:blue}+1{} Hand",
                    "{C:attention}-1{} Joker Slot",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_ascendant = {
                name = "Ascendant Stake",
                text = {
                    "{s:0.8}Required score scales",
                    "{s:0.8}EVEN FASTER for each {s:0.8,C:attention}Ante{}",
                    "{s:0.8,C:inactive}(Ante 1 included){}",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_mvp_impossible = {
                name = "Impossible Stake",
                text = {
                    "{s:0.8,C:blue}-1{s:0.8} Hand",
                    "{s:0.8,C:red}-1{s:0.8} Discard",
                    "{s:0.8,C:attention}-1{s:0.8} Hand Size",
                    "{s:0.8}Applies all previous Stakes {s:0.8,C:inactive}(Good luck){}",
                },
            },
        },
        Other = {
            mvp_platinum_sticker = {
                name = "Platinum Sticker",
                text = { "Used to win on", "{C:attention}Platinum Stake{} difficulty" },
            },
            mvp_titanium_sticker = {
                name = "Titanium Sticker",
                text = { "Used to win on", "{C:attention}Titanium Stake{} difficulty" },
            },
            mvp_diamond_sticker = {
                name = "Diamond Sticker",
                text = { "Used to win on", "{C:attention}Diamond Stake{} difficulty" },
            },
            mvp_legendary_sticker = {
                name = "Legendary Sticker",
                text = { "Used to win on", "{C:attention}Legendary Stake{} difficulty" },
            },
            mvp_mythic_sticker = {
                name = "Mythic Sticker",
                text = { "Used to win on", "{C:attention}Mythic Stake{} difficulty" },
            },
            mvp_radiant_sticker = {
                name = "Radiant Sticker",
                text = { "Used to win on", "{C:attention}Radiant Stake{} difficulty" },
            },
            mvp_ascendant_sticker = {
                name = "Ascendant Sticker",
                text = { "Used to win on", "{C:attention}Ascendant Stake{} difficulty" },
            },
            mvp_impossible_sticker = {
                name = "Impossible Sticker",
                text = { "Used to win on", "{C:attention}Impossible Stake{} difficulty {C:inactive}(wtf??){}" },
            },
        },
        -- Pinochle
        Sleeve = {
            sleeve_mvp_prismatic_alt = {
                name = "Prismatic Sleeve",
                text = {
                    "Provides the upside of each sleeve",
                    "{C:red}Achievements are disabled{}",
                },
            },
            sleeve_mvp_vanilla_alt = {
                name = "Vanilla Sleeve",
                text = {
                    "Only {C:attention}vanilla content{}",
                    "can appear",
                },
            },
        },
    },
}
