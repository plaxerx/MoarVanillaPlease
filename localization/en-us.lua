return {
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
                    "{C:inactive}(Ante 1 needs {C:attention}350{C:inactive} chips)",
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
                    "Must reach {C:attention}Ante 10{} to win",
                    "{C:attention}Boss Blinds{} appear every",
                    "{C:attention}8{} and {C:attention}10{} Antes",
                    "{s:0.8}Applies all previous Stakes",
                },
            },
            stake_eeng_mythic = {
                name = "Mythic Stake",
                text = {
                    "{C:money}$1{} of interest is earned",
                    "per {C:money}$7{} instead of per {C:money}$5{}",
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
