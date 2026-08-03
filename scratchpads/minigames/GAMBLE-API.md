# GAMBLE — API

**KNUCKLEBONES** · `GAMBLE.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Push-your-luck 2d6 against the house. Any ONE takes the pot.
The tavern gamble.

## Entry point

```basic
FUNCTION PlayGamble% (purse AS LONG, ante AS LONG, wis AS INTEGER)
```

the caller owns the purse; the function reports the swing.

Integration signature should become the standard one:

```basic
FUNCTION PlayGamble% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | banked |
| `MG_LOST` | busted |
| `MG_LEFT` | cashed out |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `HOUSE_PCT` — the rake; tuned by Monte Carlo, so changing it changes the proven edge


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `GB_BANKED / GB_BUST / GB_LEFT` — legacy outcome codes


## Art keys

- `bones.d6` — a knucklebone die face
- `bones.pot` — the pot
- `bones.table` — the felt


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `bones.throw` — the throw
- `bones.settle` — they stop
- `bones.bank` — banking
- `bones.bust` — a one


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.gamble.pot` — C_TITLE
- `minigame.gamble.risk` — C_WARN


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis, gold, stake
- **reports in `MG_RESULT`:** outcome, gold
- **must survive a save:** nothing

## Content that belongs in a data pack

the rake, and the ante ladder

## Stat hook

**WIS** — the odds shown on screen -- it reads, it does not bend

## Invariants the integration must not break

1. the house edge matches the published figure the rake was tuned to, by Monte Carlo
2. WIS shows the odds and never changes them


Each of these is an assertion in `GAMBLE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
