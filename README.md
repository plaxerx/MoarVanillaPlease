# Moar Vanilla Please

All seven of my vanilla-friendly [Balatro](https://www.playbalatro.com/) mods in one package. Everything here
extends the base game without major content additions works and is intended to play as a companion to vanilla
or enhancement for content mods through difficulty scaling and play metrics.

**Alpha.** Balance and content are constantly evolving.

## What's included

| Content | Effect |
|---|---|
| **31 new challenges** | Vanilla-friendly challenges that add new flavors to the current challenge list including a practice NANEINF mode and new scoring modes |
| **8 stakes above Gold** | Platinum, Titanium, Diamond, Legendary*, Mythic, Radiant, Ascendant, Impossible** |
| **Erratic Mode** | Start on a random deck, stake and sleeve (if [Card Sleeves](https://github.com/larswijn/CardSleeves) is installed) with rolled mutations drawn from a pool of 100 |
| **Prismatic Deck** | A new deck that applies every vanilla deck's upside at once |
| **Prismatic Sleeve** | (if [Card Sleeves](https://github.com/larswijn/CardSleeves) is installed) Every vanilla deck sleeves' upsides at once |
| **Vanilla Deck** | Modded content fixer where only vanilla Jokers will appear |
| **Vanilla Sleeve** | (if [Card Sleeves](https://github.com/larswijn/CardSleeves) is installed) Only vanilla Consumables, Vouchers and Tags. Together with the Vanilla Deck, only vanilla content entirely |
| **Peek Store** | Shows what the next few shop rerolls hold. Turned off by default (turn on in mod settings) |
| **UI Themes** | Recolor the game! All menus, panels, badges and blinds are customizable with stock themes, saved themes, and import/export codes |
| **More Stats** | New trackable stats such as deck-by-stake completion grid, per-Joker and per-Boss breakdowns, full run history, and extra statistics on the Win and Game Over screens |
| **Steady Frames** | Balatro can frame drop considerably deep into the late game. This keeps Lua's garbage collector ahead of the game minimizing frame rate deterioration |

*Legendary is intended to be the new ceiling of Vanilla Balatro
**Impossible is designed to be defined. Good for Balatro mods that make the game too easy and properly scale modded power creep

## Required mods

- [Steamodded](https://github.com/Steamodded/smods) `>=1.0.0~BETA-0400` (tested on 26.1002.0)
- [Lovely](https://github.com/ethangreen-dev/lovely-injector)

## Recommended mods

- [Card Sleeves](https://github.com/larswijn/CardSleeves) — sleeves as a second deck modifier.
  Needed for the Prismatic and Vanilla sleeves, and lets Erratic Mode roll a sleeve
- [Saturn](https://github.com/OceanRamen/Saturn) — quality of life: stacked consumables and
  skippable animations
- [Cartomancer](https://github.com/stupxd/Cartomancer) — quality of life and performance: a
  compact, stacked deck view, Joker area controls, a cap on score flames and other
  optimizations for long runs
- [Amulet](https://github.com/frostice482/amulet) 3.5.4+ — big-number support for high-scoring
  runs, a maintained fork of Talisman. New scoring methodology challenges only appear when this is
  installed

## Installation

Copy the `MoarVanillaPlease` folder into your Balatro mods directory:

```
%APPDATA%/Balatro/Mods/MoarVanillaPlease/
```

Restart the game. Lovely patches are read from the installed copy at launch, so a running game
will not pick up changes.

## Separated versions

The same content is also published as smaller mods should you want only pieces of this mod:

- [MoarStakesPlease](https://github.com/plaxerx/MoarStakesPlease) — the new stakes
- [MoarChallengesPlease](https://github.com/plaxerx/MoarChallengesPlease) — the new challenges
- [ErraticMode](https://github.com/plaxerx/erraticmode) — the random mode with mutations
- [Pinochle](https://github.com/plaxerx/pinochle) — the decks, sandbox challenges, and peeking
- MoarThemesPlease — the theme editor TBD
- MoarStatsPlease — the stat tracker TBD
- SteadyFrames — the garbage-collector pacing

These are incompatible when running with MoarVanillaPlease so **install these or this mod, not both**.

## Companion mod

[Endless Engines](https://github.com/plaxerx/EndlessEngines) is my content additions mod to service
the lack of end game content in Balatro and diversify Endless Mode that is compatible with this mod.

## Credits

Made by [plaxerx](https://github.com/plaxerx), with development assistance from [Claude](https://claude.ai).

Balatro is by LocalThunk. This mod is unofficial and not affiliated with the developer or publisher.
