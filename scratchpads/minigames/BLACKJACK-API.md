# BLACKJACK — API

**TWENTY-ONE** · `BLACKJACK.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

One deck, dealer stands on all 17s, natural pays 3:2, double on the first two,
no splits, no hole-card peek. The only game here whose skill is a TABLE.

## Entry point

```basic
FUNCTION PlayJack% (purse AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayJack% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | doubled the purse |
| `MG_LOST` | broke |
| `MG_LEFT` | cashed out |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `BJ_PAY` — the natural payout -- changing it changes the measured edge
- `RESHUFFLE` — penetration


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `DECKN` — 52; ShoeWellFormed% asserts four of each rank
- `MAXHAND` — bound
- `(the strategy table)` — it IS the game's advice; a wrong table is worse than none


## Art keys

- `card.<rank>` — thirteen faces
- `card.back` — the hole card
- `jack.felt` — the table


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `card.deal`
- `card.hit`
- `jack.win`
- `jack.bust`
- `jack.natural`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.jack.felt` — dark green
- `minigame.jack.win` — C_GOOD
- `minigame.jack.bust` — C_BAD


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** gold, stake
- **reports in `MG_RESULT`:** outcome, gold
- **must survive a save:** nothing

## Content that belongs in a data pack

the rules variant and the payout; the strategy table follows the rules and must be re-measured if they change

## Stat hook

**none** — nothing -- basic strategy is the skill and it is learnable

## Invariants the integration must not break

1. basic strategy loses slowly (-0.25 per 100 staked), mimic-the-dealer loses several times faster (-5.09), never-bust worse still (-15.75). If those three do not come out in that order the table is wrong -- and a wrong table teaches a habit that costs money while calling it advice
2. the shoe deals WITHOUT replacement, or the measured edge is fiction
3. soft-hand arithmetic is right on three-card hands, which is where the classic ace bug lives


Each of these is an assertion in `BLACKJACK.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
