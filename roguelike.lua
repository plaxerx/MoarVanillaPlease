-- Endless Engines - Gauntlet deck + Endless vouchers

--============================================================
-- ROGUELIKE DECK  (wireframe)
--============================================================
-- The idea: every blind is a fork in the road. You don't get a Tag for skipping - you
-- get one for TAKING THE HARD ROAD. Two roads exist:
--
--   GAUNTLET - the blind is juiced to 3x its normal requirement.
--   CURSED   - the blind is normal, but you fight it short a hand, a discard,
--              two cards of hand size, or a Joker slot.
--
-- Beat it and you're paid in a Tag. The curse lifts when the blind dies.
--
-- WIREFRAME NOTE: the road is currently ROLLED FOR YOU, not chosen. That's deliberate
-- for now - it exercises every moving part (blind scaling, curse apply/restore, tag
-- payout) without needing a custom blind-select UI. Once this is proven in play, the
-- roll becomes a button and the deck becomes an actual map.

-- ============================================================
-- CURSES
-- ============================================================
-- Joker and consumable slots are NOT curses: a curse lifts when the blind dies, so
-- shrinking a slot you aren't filling mid-round costs precisely nothing. Everything here
-- bites during the round itself, or costs real money.
--
-- amt is the KNOB. On the deck-and-sleeve combo every amt is doubled (see curse_amt),
-- because that combo also pays double tags - the price goes up with the reward.
local CURSES = {
    { key = 'hands',         amt = 1, label = '-1 Hand' },
    { key = 'discards',      amt = 1, label = '-1 Discard' },
    { key = 'hand_size',     amt = 1, label = '-1 Hand Size' },
    { key = 'hand_cost',     amt = 2, label = '$2 per Hand' },
    { key = 'discard_cost',  amt = 2, label = '$2 per Discard' },
    -- Sticker curses only enter the pool once the stake actually deals that sticker.
    -- These do NOT lift at round end - a sticker is forever. That's the point of them.
    { key = 'sticker', sticker = 'eternal',    amt = 1, label = 'Eternal a Joker',
      gate = function() return G.GAME.modifiers.enable_eternals_in_shop end },
    { key = 'sticker', sticker = 'perishable', amt = 1, label = 'Perish a Joker',
      gate = function() return G.GAME.modifiers.enable_perishables_in_shop end },
    { key = 'sticker', sticker = 'rental',     amt = 1, label = 'Rent a Joker',
      gate = function() return G.GAME.modifiers.enable_rentals_in_shop end },
}

-- TAG TIERS. The curse count is the PRICE OF THE TAG on offer, so a Voucher Tag costs you
-- three curses and a Juggle Tag costs one. Anything unlisted defaults to 1.
local TAG_TIER = {
    -- 2 curses
    tag_coupon = 2, tag_double = 2, tag_economy = 2, tag_ethereal = 2,
    tag_garbage = 2, tag_handy = 2, tag_holo = 2, tag_foil = 2,
    -- 3 curses
    tag_investment = 3, tag_negative = 3, tag_polychrome = 3,
    tag_rare = 3, tag_voucher = 3,
}

local function tier_of(tag_key)
    return (tag_key and TAG_TIER[tag_key]) or 1
end

-- Boss blinds have NO tag in vanilla - blind_tags only ever holds Small and Big, because
-- a Boss can't be skipped. So we mint one. It's always 2 curses and always drawn from the
-- 2/3-curse pool: a Boss curse count can't leak information about a tag you can't see.
local BOSS_TAG_POOL = {
    'tag_coupon', 'tag_double', 'tag_economy', 'tag_ethereal', 'tag_garbage',
    'tag_handy', 'tag_holo', 'tag_foil', 'tag_investment', 'tag_negative',
    'tag_polychrome', 'tag_rare', 'tag_voucher',
}

function EEng.blind_tag(blind_type)
    blind_type = blind_type or (G.GAME and G.GAME.blind_on_deck) or 'Small'
    if blind_type == 'Boss' then
        G.GAME.eeng_boss_tags = G.GAME.eeng_boss_tags or {}
        local ante = (G.GAME.round_resets and G.GAME.round_resets.ante) or 1
        if not G.GAME.eeng_boss_tags[ante] then
            G.GAME.eeng_boss_tags[ante] = BOSS_TAG_POOL[pseudorandom('eeng_boss_tag', 1, #BOSS_TAG_POOL)]
        end
        return G.GAME.eeng_boss_tags[ante]
    end
    local t = G.GAME.round_resets and G.GAME.round_resets.blind_tags
    return t and t[blind_type] or nil
end

function EEng.curse_count(blind_type)
    blind_type = blind_type or (G.GAME and G.GAME.blind_on_deck) or 'Small'
    if blind_type == 'Boss' then return 2 end
    return tier_of(EEng.blind_tag(blind_type))
end

-- Double the bite on the deck+sleeve combo.
local function curse_amt(c)
    return c.amt * ((G.GAME.eeng_road_tags or 1) > 1 and 2 or 1)
end

local function apply_curse(c, on)
    local n = curse_amt(c) * (on and -1 or 1)

    if c.key == 'hands' then
        if G.GAME.round_resets then G.GAME.round_resets.hands = G.GAME.round_resets.hands + n end
        if G.GAME.current_round then
            G.GAME.current_round.hands_left = math.max(1, (EEng.plain(G.GAME.current_round.hands_left) or 1) + n)
        end
    elseif c.key == 'discards' then
        if G.GAME.round_resets then G.GAME.round_resets.discards = G.GAME.round_resets.discards + n end
        if G.GAME.current_round then
            G.GAME.current_round.discards_left = math.max(0, (EEng.plain(G.GAME.current_round.discards_left) or 0) + n)
        end
    elseif c.key == 'hand_size' and G.hand then
        G.hand.config.card_limit = math.max(2, G.hand.config.card_limit + n)

    -- Money curses are a toll, not a stat change: they're charged as you play.
    elseif c.key == 'hand_cost' then
        G.GAME.eeng_hand_cost = on and curse_amt(c) or nil
    elseif c.key == 'discard_cost' then
        G.GAME.eeng_discard_cost = on and curse_amt(c) or nil

    -- Stickers are permanent. There is nothing to undo, so only the "on" pass does work.
    elseif c.key == 'sticker' and on then
        if G.jokers and G.jokers.cards and #G.jokers.cards > 0 then
            local j = G.jokers.cards[pseudorandom('eeng_sticker', 1, #G.jokers.cards)]
            if j then
                j.ability[c.sticker] = true
                if c.sticker == 'perishable' then
                    j.ability.perish_tally = G.GAME.perishable_rounds or 5
                end
                j:juice_up(0.5, 0.5)
            end
        end
    end
end

-- G.GAME is SERIALISED to a thread Channel by the autosave every few frames, and
-- Channel:push cannot serialise a function. Our curse entries carry gate = function()...,
-- so storing the tables themselves in G.GAME made every save throw
-- "bad argument #1 to 'push'". Store INDICES; resolve to the table on use.
function EEng.curse_by_id(i)
    return CURSES[i]
end

local function ids_to_curses(ids)
    local out = {}
    for _, i in ipairs(ids or {}) do
        if CURSES[i] then out[#out + 1] = CURSES[i] end
    end
    return out
end

-- Deal N distinct curses for a blind, filtered by whatever the stake actually allows.
-- Returns a list of INDICES into CURSES.
function EEng.peek_curse(blind_type)
    blind_type = blind_type or (G.GAME and G.GAME.blind_on_deck) or 'Small'
    local ante = (G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    if G.GAME.eeng_curse_ante ~= ante then
        G.GAME.eeng_curse_ante = ante
        G.GAME.eeng_curses = nil       -- fresh set each ante, stable within it
    end
    G.GAME.eeng_curses = G.GAME.eeng_curses or {}

    if not G.GAME.eeng_curses[blind_type] then
        local want = EEng.curse_count(blind_type)

        local pool = {}
        for i, c in ipairs(CURSES) do
            if not c.gate or c.gate() then pool[#pool + 1] = i end
        end

        local chosen, taken = {}, {}
        if G.GAME.eeng_last_curse then taken[G.GAME.eeng_last_curse] = true end
        local guard = 0
        while #chosen < want and guard < 100 do
            guard = guard + 1
            local i = pool[pseudorandom('eeng_curse', 1, #pool)]
            local c = CURSES[i]
            if c and not taken[c.label] then
                taken[c.label] = true
                chosen[#chosen + 1] = i        -- store the INDEX, never the table
            end
            if #chosen >= #pool then break end
        end
        G.GAME.eeng_curses[blind_type] = chosen
    end
    return G.GAME.eeng_curses[blind_type]
end

-- Short one-liner for the blind-select box. Three curses on three lines would overflow the
-- box, so they're joined into one string.
function EEng.curse_labels(blind_type)
    local parts = {}
    for _, c in ipairs(ids_to_curses(EEng.peek_curse(blind_type))) do
        parts[#parts + 1] = c.label
    end
    return parts
end

function EEng.curse_text(blind_type)
    local parts = EEng.curse_labels(blind_type)
    if #parts == 0 then return '?' end
    return table.concat(parts, ' + ')
end

-- ============================================================
-- THE CURSE, VISIBLE ALL ROUND
-- ============================================================
-- attention_text flashes once and is gone, which is no help four hands deep when you can't
-- remember why your hand is small. This sits in the middle of the board - the same place a
-- Boss Blind puts its warning - and stays until the blind dies.
EEng.curse_banner = nil

function EEng.hide_curse_banner()
    if EEng.curse_banner then
        EEng.curse_banner:remove()
        EEng.curse_banner = nil
    end
end

function EEng.show_curse_banner(labels)
    EEng.hide_curse_banner()
    if not (G.play and G.play.T) then return end
    if type(labels) ~= 'table' then labels = { tostring(labels) } end

    -- In-round: keep it to a single line. There's room across the board, and stacking rows
    -- made the box tall enough for played cards to cover it.
    local rows = { {
        n = G.UIT.R, config = { align = 'cm', padding = 0.02 },
        nodes = {
            { n = G.UIT.T, config = { text = 'CURSED  ', scale = 0.45, shadow = true,
                                      colour = G.C.WHITE } },
            { n = G.UIT.T, config = { text = table.concat(labels, '   '), scale = 0.35,
                                      shadow = true, colour = G.C.WHITE } },
        },
    } }
    -- Static text node, NOT a DynaText. A floating/rotating DynaText recomputes its own
    -- transform every frame, and that was the source of the random push() crash.
    EEng.curse_banner = UIBox{
        definition = {
            n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR },
            nodes = {{
                n = G.UIT.C,
                config = { align = 'cm', padding = 0.09, r = 0.1, emboss = 0.05,
                           colour = adjust_alpha(G.C.PURPLE, 0.8) },
                nodes = rows,
            }},
        },
        -- Lifted clear of the cards: it was sitting right on top of them and colliding
        -- with the pulse effects.
        config = { align = 'cm', offset = { x = 0, y = -2.6 }, major = G.play, bond = 'Weak' },
    }
end

-- Lift every active curse and clear the road. Safe to call repeatedly.
function EEng.clear_road()
    if G.GAME.eeng_active_curses then
        local list = ids_to_curses(G.GAME.eeng_active_curses)
        for _, c in ipairs(list) do apply_curse(c, false) end
        G.GAME.eeng_last_curse = list[1] and list[1].label
        G.GAME.eeng_active_curses = nil
    end
    G.GAME.eeng_hand_cost = nil
    G.GAME.eeng_discard_cost = nil
    G.GAME.eeng_armed = nil
    G.GAME.eeng_road = nil
    G.GAME.eeng_gauntlet_armed = nil
    EEng.hide_curse_banner()
    -- NB: G.GAME.eeng_curses is deliberately NOT cleared here. It's the set that was
    -- previewed; wiping it made pick_road re-roll a different curse than the one shown.
    -- peek_curse() retires it when the ante turns over.
end

local function pick_road(force)
    local bt = (G.GAME and G.GAME.blind_on_deck) or 'Small'
    local road = force or (EEng.is_armed(bt) and 'gauntlet') or 'cursed'
    G.GAME.eeng_road = road
    G.GAME.eeng_road_blind = bt

    if road == 'gauntlet' then
        local c = G.GAME.blind.chips
        G.GAME.blind.chips = (to_big and to_big(c) or c) * 3
        G.GAME.blind.chip_text = number_format(G.GAME.blind.chips)
        attention_text{ text = 'GAUNTLET X3', scale = 0.8, hold = 1.2, cover = G.play,
                        cover_colour = G.C.RED, align = 'cm' }
        EEng.hide_curse_banner()
    else
        local ids = EEng.peek_curse(bt)
        G.GAME.eeng_active_curses = ids            -- indices only: G.GAME must stay serialisable
        for _, c in ipairs(ids_to_curses(ids)) do apply_curse(c, true) end
        EEng.show_curse_banner(EEng.curse_labels(bt))
    end
end

-- Beat the road, take THE TAG THAT WAS ON THE BLIND. The old version called
-- get_next_tag_key(), which mints a brand new random tag with no relationship to the one
-- the blind-select screen showed you. That is why the reward never matched the preview.
local function pay_road()
    local bt = G.GAME.eeng_road_blind or G.GAME.blind_on_deck or 'Small'
    local key = EEng.blind_tag(bt) or 'tag_uncommon'
    local n = G.GAME.eeng_road_tags or 1

    EEng.clear_road()
    G.GAME.eeng_road_blind = nil

    for _ = 1, n do
        G.E_MANAGER:add_event(Event({ func = function()
            add_tag(Tag(key))
            play_sound('generic1', 0.9 + math.random() * 0.1, 0.8)
            return true
        end }))
    end
end

-- ============================================================
-- CHOOSING THE ROAD (blind select screen)
-- ============================================================
-- Borrowed wholesale from how Ortalab does it: wrap create_UIBox_blind_choice to inject
-- nodes into the blind's box, and drive everything off the real select_blind_button that
-- already lives inside it.
--
-- Each selectable blind now shows the curse it would inflict, and gets a second button.
-- Press Select and you fight it cursed. Press GAUNTLET and you fight it at 3x score with
-- no curse. Either road pays a Tag - the Gauntlet is what you pick when the curse looks
-- worse than the maths.

-- A TOGGLE, not a second Select button. Arm or disarm the Gauntlet, then press Select as
-- normal. Keeps one obvious "go" button instead of two competing ones.
-- Armed state is PER BLIND. It used to be one global flag, so lighting up the Small Blind's
-- toggle lit up all three - and you couldn't tell which road you'd actually chosen.
G.FUNCS.eeng_toggle_gauntlet = function(e)
    local bt = e.config and e.config.eeng_blind
    if not bt then return end
    G.GAME.eeng_armed = G.GAME.eeng_armed or {}
    G.GAME.eeng_armed[bt] = not G.GAME.eeng_armed[bt]
    play_sound('button', G.GAME.eeng_armed[bt] and 1.1 or 0.8, 0.7)
end

function EEng.is_armed(bt)
    return (G.GAME.eeng_armed or {})[bt or G.GAME.blind_on_deck or 'Small'] and true or false
end

-- The label is a static text node, so it can't be rewritten after the box is built. The
-- armed state is carried by COLOUR instead, resynced every frame from the same handler
-- Ortalab uses. Red = you're running the Gauntlet; grey = you're taking the curse.
local eeng_choice_handler = G.FUNCS.blind_choice_handler
G.FUNCS.blind_choice_handler = function(e)
    eeng_choice_handler(e)
    if not (G.GAME and G.GAME.eeng_roguelike) then return end
    local armed = EEng.is_armed(e.config.id)     -- only THIS blind's state

    local btn = e.UIBox and e.UIBox:get_UIE_by_ID('eeng_gauntlet_' .. tostring(e.config.id))
    if btn and btn.config then
        btn.config.colour = armed and G.C.RED or G.C.GREY
    end
    -- and mark the real Select button so you can't miss which road you're on
    local sel = e.UIBox and e.UIBox:get_UIE_by_ID('select_blind_button')
    if sel and sel.config then
        sel.config.outline = armed and 1 or nil
        sel.config.outline_colour = armed and G.C.RED or nil
    end
end

local eeng_blind_choice = create_UIBox_blind_choice
function create_UIBox_blind_choice(type, run_info)
    local box = eeng_blind_choice(type, run_info)
    if run_info then return box end
    if not (G.GAME and G.GAME.eeng_roguelike) then return box end

    -- Same insertion point Ortalab uses for its mod badges.
    -- NB: the `type` parameter shadows Lua's global type() in this scope, so don't call it.
    local ok, container = pcall(function() return box.nodes[1].nodes[2].nodes end)
    if not ok or not container or not container[1] then return box end

    local forced = (G.GAME.eeng_force_road == 'gauntlet')   -- Roguelike Sleeve
    local curse_txt = EEng.curse_text(type)
    local n_curse = EEng.curse_count(type)

    if forced then
        -- Deck + Sleeve: the road isn't a choice, so there's no toggle and no curse to
        -- preview. Say plainly what the deal is instead of leaving a bare "X3" hanging there.
        table.insert(container, { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
            { n = G.UIT.T, config = { text = 'GAUNTLET X3', scale = 0.35,
                                      colour = G.C.RED, shadow = true } },
        }})
        table.insert(container, { n = G.UIT.R, config = { align = 'cm', padding = 0.005 }, nodes = {
            { n = G.UIT.T, config = { text = 'Mandatory', scale = 0.22,
                                      colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }})
        table.insert(container, { n = G.UIT.R, config = { align = 'cm', padding = 0.005 }, nodes = {
            { n = G.UIT.T, config = { text = 'Pays 2 copies of the Tag', scale = 0.22,
                                      colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        }})
        return box
    end

    -- Both roads are stated up front. Which one you're on is shown by the toggle's colour,
    -- so neither line has to be rewritten when you click.
    -- One line, however many curses. Three stacked lines would blow the box out.
    table.insert(container, { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
        { n = G.UIT.T, config = { text = n_curse .. (n_curse == 1 and ' Curse' or ' Curses'),
                                  scale = 0.3, colour = G.C.PURPLE, shadow = true } },
    }})
    -- Two curses fit on one line - the box has the width for it. Only THREE needs breaking
    -- up, and even then two rows (2 + 1) rather than three, because three rows runs off the
    -- bottom of the box.
    local labels = EEng.curse_labels(type)
    local lines = {}
    if #labels <= 2 then
        lines[1] = table.concat(labels, ' + ')
    else
        lines[1] = labels[1] .. ' + ' .. labels[2]
        lines[2] = table.concat({ unpack(labels, 3) }, ' + ')
    end
    for _, line in ipairs(lines) do
        if line ~= '' then
            table.insert(container, { n = G.UIT.R, config = { align = 'cm', padding = 0.005 }, nodes = {
                { n = G.UIT.T, config = { text = line, scale = 0.22,
                                          colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            }})
        end
    end

    table.insert(container, { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
        { n = G.UIT.C, config = { align = 'cm', padding = 0.06, r = 0.1, minw = 2.6,
                                  colour = EEng.is_armed(type) and G.C.RED or G.C.GREY,
                                  button = 'eeng_toggle_gauntlet',
                                  eeng_blind = type,
                                  hover = true, shadow = true,
                                  id = 'eeng_gauntlet_' .. tostring(type) },
          nodes = {
            { n = G.UIT.T, config = { text = 'Gauntlet Run', scale = 0.33,
                                      colour = G.C.UI.TEXT_LIGHT, shadow = true } },
          }},
    }})

    return box
end

-- ============================================================
-- SEEING THE CURSE DURING THE ROUND
-- ============================================================
-- attention_text flashes once and is gone, which is no use when you're four hands deep
-- and can't remember why your hand is small. Fold the road into the blind's own name, so
-- it sits in the HUD for the whole round.
local eeng_blind_set = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
    eeng_blind_set(self, blind, reset, silent)
    if not (G.GAME and G.GAME.eeng_roguelike) then return end
    if reset or not self.name then return end

    local suffix
    if G.GAME.eeng_road == 'gauntlet' then
        suffix = ' [GAUNTLET X3]'
    elseif G.GAME.eeng_curse then
        suffix = ' [' .. G.GAME.eeng_curse.label .. ']'
    end
    if suffix and not tostring(self.name):find('%[') then
        self.name = tostring(self.name) .. suffix
        if self.loc_name then self.loc_name = tostring(self.loc_name) .. suffix end
    end
end

SMODS.Back{
    key = 'roguelike',
    atlas = 'eeng_jokers', pos = { x = 1, y = 2 },
    unlocked = true, discovered = true,
    config = {},
    loc_txt = {
        name = 'Gauntlet Deck',
        text = {
            'Every Blind is a {C:attention}road{}:',
            '{C:red}Gauntlet{} - Blind needs {C:attention}3X{} score',
            '{C:purple}Cursed{} - fight it short a resource',
            'Survive the road, take a {C:attention}Tag{}',
        },
    },
    apply = function(self)
        G.GAME.eeng_roguelike = true
    end,
    calculate = function(self, back, context)
        -- Tear down, then build. clear_road() on setting_blind is what guarantees a curse
        -- never survives into the next blind.
        if context.setting_blind then
            EEng.clear_road()
            pick_road(G.GAME.eeng_force_road)
        end
        -- Pay on end_of_round: that is the moment the blind is beaten. The previous version
        -- paid on round_eval, but ALSO cleared the road on end_of_round "for safety" - and
        -- end_of_round fires FIRST, so the road was gone before the payout ever looked for
        -- it. The safety net was eating the reward.
        if context.end_of_round and G.GAME.eeng_road then
            pay_road()
        end
        -- money curses are a toll, charged as you go
        if context.before and G.GAME.eeng_hand_cost and not context.blueprint then
            ease_dollars(-G.GAME.eeng_hand_cost)
        end
        if context.pre_discard and not context.hook and G.GAME.eeng_discard_cost then
            ease_dollars(-G.GAME.eeng_discard_cost)
        end
    end,
}

--============================================================
-- ROGUELIKE SLEEVE
--============================================================
-- Alone: every road is the Gauntlet. No curses, no dice - you always know exactly what
-- you signed up for, and it's always the hard one. Wear it over any deck.
-- On the Roguelike Deck: the roads still roll, but they pay double.
if CardSleeves then
    CardSleeves.Sleeve{
        key = 'roguelike',
        name = 'Gauntlet Sleeve',
        atlas = 'eeng_sleeves', pos = { x = 2, y = 0 },
        unlocked = true, discovered = true,
        config = {},
        loc_vars = function(self)
            if self.get_current_deck_key() == 'b_eeng_roguelike' then
                self.config = { double_pay = true }
                return { key = self.key .. '_alt' }
            end
            self.config = { always_gauntlet = true }
            return { key = self.key }
        end,
        loc_txt = {
            name = 'Gauntlet Sleeve',
            text = {
                'Every Blind is a {C:red}Gauntlet{}:',
                'needs {C:attention}3X{} score, pays a {C:attention}Tag{}',
                '{C:inactive}(no curses, no dice)',
            },
        },
        apply = function(self, sleeve)
            CardSleeves.Sleeve.apply(self)
            if self.config.always_gauntlet then
                G.GAME.eeng_roguelike = true
                G.GAME.eeng_force_road = 'gauntlet'
            elseif self.config.double_pay then
                -- The combo forgot to flag eeng_roguelike, which is the gate on the entire
                -- blind-select UI - so the deck showed the roads and the combo showed nothing.
                G.GAME.eeng_roguelike = true
                G.GAME.eeng_road_tags = 2
                G.GAME.eeng_force_road = 'gauntlet'
            end
        end,
        -- Back:calculate only fires for the Roguelike BACK. Worn over any other deck the
        -- sleeve has to drive the roads itself, so it carries the same hooks. The
        -- eeng_road guard stops both firing twice on the Roguelike deck.
        calculate = function(self, sleeve, context)
            if not G.GAME.eeng_roguelike then return end
            -- same order as the Back (see the note there)
            if context.setting_blind then
                EEng.clear_road()
                pick_road(G.GAME.eeng_force_road)
            end
            if context.end_of_round and G.GAME.eeng_road then
                pay_road()
            end
            if context.before and G.GAME.eeng_hand_cost and not context.blueprint then
                ease_dollars(-G.GAME.eeng_hand_cost)
            end
            if context.pre_discard and not context.hook and G.GAME.eeng_discard_cost then
                ease_dollars(-G.GAME.eeng_discard_cost)
            end
        end,
    }
end

--============================================================
-- ENDLESS VOUCHERS  (ante 9+ only)
--============================================================
-- follows win_ante too: Diamond Stake wins at 10, so endless starts after 10
local function endless_only(self)
    local ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    return ante > EEng.endless_start()
end

-- Legendary Jokers normally have a rarity weight of ZERO in the shop - they exist only
-- behind The Soul. Rather than fight that weight (0 times any multiplier is still 0),
-- Royal short-circuits the roll outright.
local eeng_poll_rarity = SMODS.poll_rarity
function SMODS.poll_rarity(_pool_key, _rand_key)
    if G.GAME and G.GAME.eeng_royal and _pool_key == 'Joker' then
        if pseudorandom('eeng_royal') < (G.GAME.eeng_royal_rate or 0.03) then
            return 'Legendary'
        end
    end
    return eeng_poll_rarity(_pool_key, _rand_key)
end

-- Negative is roughly a 0.3% roll in the shop. These vouchers multiply that.
local eeng_poll_edition = poll_edition
function poll_edition(_key, _mod, _no_neg, _guaranteed, _options)
    local m = G.GAME and G.GAME.eeng_neg_mult
    if m and m > 1 and not _no_neg then
        local rate = 0.003 * m * (G.GAME.edition_rate or 1)
        if pseudorandom('eeng_neg') < rate then
            return { negative = true }
        end
    end
    return eeng_poll_edition(_key, _mod, _no_neg, _guaranteed, _options)
end

SMODS.Voucher{
    key = 'royal',
    atlas = 'eeng_jokers', pos = { x = 2, y = 2 },
    unlocked = true, discovered = true,
    cost = 12,
    in_pool = endless_only,
    loc_txt = {
        name = 'Royal Voucher',
        text = {
            '{C:legendary,E:1}Legendary{} Jokers can',
            'appear in the {C:attention}shop{}',
        },
    },
    redeem = function(self, card)
        G.GAME.eeng_royal = true
        G.GAME.eeng_royal_rate = 0.03
    end,
}

SMODS.Voucher{
    key = 'imperial',
    atlas = 'eeng_jokers', pos = { x = 3, y = 2 },
    unlocked = true, discovered = true,
    cost = 20,
    requires = { 'v_eeng_royal' },
    in_pool = endless_only,
    loc_txt = {
        name = 'Imperial Voucher',
        text = {
            '{C:attention}Mega Spectral{} Packs are',
            'guaranteed to contain {C:legendary,E:1}The Soul{}',
        },
    },
    redeem = function(self, card)
        G.GAME.eeng_royal = true
        G.GAME.eeng_imperial = true
        G.GAME.eeng_royal_rate = 0.06
    end,
}

SMODS.Voucher{
    key = 'negative',
    atlas = 'eeng_jokers', pos = { x = 4, y = 2 },
    unlocked = true, discovered = true,
    cost = 12,
    in_pool = endless_only,
    loc_txt = {
        name = 'Negative Voucher',
        text = {
            '{C:dark_edition}Negative{} Jokers appear',
            '{C:attention}3X{} more often in the shop',
        },
    },
    redeem = function(self, card)
        G.GAME.eeng_neg_mult = math.max(G.GAME.eeng_neg_mult or 1, 3)
    end,
}

SMODS.Voucher{
    key = 'antimatter',
    atlas = 'eeng_jokers', pos = { x = 5, y = 2 },
    unlocked = true, discovered = true,
    cost = 20,
    requires = { 'v_eeng_negative' },
    in_pool = endless_only,
    loc_txt = {
        name = 'Antimatter Voucher',
        text = {
            '{C:dark_edition}Negative{} Jokers appear',
            '{C:attention}5X{} more often in the shop',
        },
    },
    redeem = function(self, card)
        G.GAME.eeng_neg_mult = math.max(G.GAME.eeng_neg_mult or 1, 5)
    end,
}

-- The Soul guarantee. Boosters expose a create_card hook, which is the clean seam:
-- force slot 1 of a Mega Spectral pack to be The Soul when Imperial is redeemed.
-- Only intervene when Imperial is actually redeemed, and DELEGATE otherwise.
-- Returning a bare { set = 'Spectral' } replaced vanilla's own create_card wholesale,
-- stripping the config it builds (soul_rate, edition rates, and the rest) - which is what
-- was spawning the swarm of drifting particles in Mega Spectral packs.
for _, k in ipairs({ 'spectral_mega_1', 'spectral_mega_2' }) do
    pcall(function()
        local center = G.P_CENTERS['p_' .. k]
        local ref = center and center.create_card
        SMODS.Booster:take_ownership(k, {
            create_card = function(self, card, i)
                if G.GAME and G.GAME.eeng_imperial and i == 1 then
                    return { set = 'Spectral', key = 'c_soul' }
                end
                if ref then return ref(self, card, i) end
                return nil   -- nil = let the game generate this slot exactly as it always did
            end,
        }, true)
    end)
end
