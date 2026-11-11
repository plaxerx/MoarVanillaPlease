# Moar Vanilla Please

All seven of my [Balatro](https://www.playbalatro.com/) mods in one package. Everything here
extends the base game along the lines it already runs on, without reinventing how Balatro
works.

**Alpha.** Balance and content are still moving.

## What's included

| Content | Effect |
|---|---|
| **31 challenges** | Numbers 21–51, continuing the vanilla list. Economy squeezes, hand restrictions and full-run twists |
| **8 stakes above Gold** | Platinum, Titanium, Diamond, Legendary, Mythic, Radiant, Ascendant, Impossible |
| **Erratic Mode** | Start on a random deck, stake and sleeve with 0–8 rolled mutations drawn from a pool of 100 |
| **Prismatic Deck** | Every vanilla deck's upside at once |
| **Prismatic Sleeve** | Every vanilla sleeve's upside at once |
| **Vanilla Deck** | Only vanilla Jokers can appear |
| **Vanilla Sleeve** | Only vanilla Consumables, Vouchers and Tags. Together with the Vanilla Deck, only vanilla content |
| **NANEINF Lite** | A sandbox challenge with easier access to endless runs |
| **Ensign / Commander / Captain** | Amulet-only challenges scoring with `+`, `^` and `^^`, each with custom Ante scaling |
| **Peek Store** | Shows what the next few shop rerolls hold. Off by default |
| **Themes** | Recolor the game. Every color its menus, panels, badges and blinds use sits in one editable palette under **Settings → Video → Themes**, with stock themes, saved themes and share codes |
| **Stats** | A live **Run Info → Stats** tab, a per-profile **Career Stats** page (deck-by-stake completion grid, per-Joker and per-Boss breakdowns, full run history), and extra rows on the Win and Game Over screens |
| **Steady Frames** | Keeps Lua's garbage collector ahead of the game so the frame rate holds over a long session |

Challenge 51 is **Baby's First Balatro** — a deliberately gentle version for a young child
learning the loop. Jokers only ever add Chips, Mult or money, Boss Blinds have no ability,
and nothing gets destroyed, retriggered or multiplied.

The stake ladder is its own progression. Legendary is the first real ceiling; the four above
it are a different game.

Themes and Stats never touch a run: they draw no RNG and move no cards, so a seeded run plays
out exactly as it would without them. Their settings are the extra **Themes** and **Stats**
tabs on this mod's page in the Mods menu.

## Requirements

- [Steamodded](https://github.com/Steamodded/smods) `>=1.0.0~BETA-0400` (tested on 26.1002.0)
- [Lovely](https://github.com/ethangreen-dev/lovely-injector)

## Recommended mods

Public mods that make the game better to play, and that this one is tested alongside:

- [Card Sleeves](https://github.com/larswijn/CardSleeves) — sleeves as a second deck modifier.
  Needed for the Prismatic and Vanilla sleeves, and lets Erratic Mode roll a sleeve
- [Saturn](https://github.com/OceanRamen/Saturn) — quality of life: stacked consumables and
  skippable animations
- [Cartomancer](https://github.com/stupxd/Cartomancer) — quality of life and performance: a
  compact, stacked deck view, Joker area controls, a cap on score flames and other
  optimizations for long runs
- [Amulet](https://github.com/frostice482/amulet) 3.5.4+ — big-number support for high-scoring
  runs, a maintained fork of Talisman. Ensign, Commander and Captain appear only when it is
  installed

[Galdur](https://github.com/Eremel/Galdur)'s run setup is built into Steamodded 26.x, so it is
not needed on a current Steamodded.

## Installation

Copy the `MoarVanillaPlease` folder into your Balatro mods directory:

```
%APPDATA%/Balatro/Mods/MoarVanillaPlease/
```

Restart the game. Lovely patches are read from the installed copy at launch, so a running game
will not pick up changes.

## Split versions

The same content is also published as smaller mods, for anyone who wants only part of it:

- [MoarStakesPlease](https://github.com/plaxerx/MoarStakesPlease) — the stake ladder
- [MoarChallengesPlease](https://github.com/plaxerx/MoarChallengesPlease) — the challenges
- [ErraticMode](https://github.com/plaxerx/erraticmode) — the rolled mutations
- [Pinochle](https://github.com/plaxerx/pinochle) — the decks, sleeves, sandbox challenges and
  Peek Store
- MoarThemesPlease — the theme editor
- MoarStatsPlease — the stat tracker
- SteadyFrames — the garbage-collector pacing

Those each declare a conflict with this mod, so **install this one or those, not both**.
If both are present, Moar Vanilla Please wins and the others stay dormant.

Saved themes are shared with the standalone Moar Themes Please (both read
`%APPDATA%/Balatro/MoarThemesPlease/themes/`), and career stats live in the profile, so
switching between the bundle and the split versions keeps both.

## Companion mod

[Endless Engines](https://github.com/plaxerx/EndlessEngines) is a separate mod built alongside
this one. The two are independent and use distinct key prefixes, so they can be installed
together or on their own.

## Credits

Made by [plaxerx](https://github.com/plaxerx), with development assistance from
[Claude](https://claude.ai).

Balatro is by LocalThunk. This mod is unofficial and not affiliated with the developer or
publisher.
