# Moar Vanilla Please

All four of my [Balatro](https://www.playbalatro.com/) mods in one package. Everything here
extends the base game along the lines it already runs on, without reinventing how Balatro
works.

**Alpha.** Balance and content are still moving.

## What's included

| Content | Effect |
|---|---|
| **31 challenges** | Numbers 21–51, continuing the vanilla list. Economy squeezes, hand restrictions and full-run twists |
| **8 stakes above Gold** | Platinum, Titanium, Diamond, Legendary, Mythic, Radiant, Ascendant, Impossible |
| **Erratic Mode** | Start on a random deck, stake and sleeve with 0–8 rolled mutations drawn from a pool of 50 |
| **Prismatic Deck** | Every vanilla deck's upside at once |
| **Prismatic Sleeve** | Every vanilla sleeve's upside at once |
| **Vanilla Deck** | Only vanilla Jokers can appear |
| **Vanilla Sleeve** | Only vanilla Consumables, Vouchers and Tags. Together with the Vanilla Deck, only vanilla content |
| **NANEINF Lite** | A sandbox challenge with easier access to endless runs |
| **Ensign / Commander / Captain** | Amulet-only challenges scoring with `+`, `^` and `^^`, each with custom Ante scaling |
| **Peek Store** | Shows what the next few shop rerolls hold. Off by default |

Challenge 51 is **Baby's First Balatro** — a deliberately gentle version for a young child
learning the loop. Jokers only ever add Chips, Mult or money, Boss Blinds have no ability,
and nothing gets destroyed, retriggered or multiplied.

The stake ladder is its own progression. Legendary is the first real ceiling; the four above
it are a different game.

## Requirements

- [Steamodded](https://github.com/Steamodded/smods) `>=1.0.0~BETA-0400`
- [Lovely](https://github.com/ethangreen-dev/lovely-injector)

Optional, supported if present:

- [CardSleeves](https://github.com/larswijn/CardSleeves) — for the Prismatic and Vanilla sleeves
- [Amulet](https://github.com/frostice482/amulet) 3.5.4+ — Ensign, Commander and Captain
  appear only when it is installed
- [Talisman](https://github.com/MathIsFun0/Talisman) — big-number support at high stakes

## Installation

Copy the `MoarVanillaPlease` folder into your Balatro mods directory:

```
%APPDATA%/Balatro/Mods/MoarVanillaPlease/
```

Restart the game. Lovely patches are read from the installed copy at launch, so a running game
will not pick up changes.

## Split versions

The same content is also published as four smaller mods, for anyone who wants only part of it:

- [MoarStakesPlease](https://github.com/plaxerx/MoarStakesPlease) — the stake ladder
- [MoarChallengesPlease](https://github.com/plaxerx/MoarChallengesPlease) — the challenges
- [ErraticMode](https://github.com/plaxerx/erraticmode) — the rolled mutations
- [Pinochle](https://github.com/plaxerx/pinochle) — the decks, sleeves, sandbox challenges and
  Peek Store

Those four each declare a conflict with this mod, so **install this one or those, not both**.
If both are present, Moar Vanilla Please wins and the others stay dormant.

## Companion mod

[Endless Engines](https://github.com/plaxerx/EndlessEngines) is a separate mod built alongside
this one. The two are independent and use distinct key prefixes, so they can be installed
together or on their own.

## Credits

Made by [plaxerx](https://github.com/plaxerx), with development assistance from
[Claude](https://claude.ai).

Balatro is by LocalThunk. This mod is unofficial and not affiliated with the developer or
publisher.
