# CRAPS — API

**CRAPS** · `CRAPS.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Come-out roll, then chase the point. The decision is when to walk.

## Entry point

```basic
FUNCTION PlayCraps% (purse AS LONG, bet AS LONG)
```

pass-line only; the caller owns the purse.

Integration signature should become the standard one:

```basic
FUNCTION PlayCraps% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | the point made |
| `MG_LOST` | sevened out |
| `MG_LEFT` | walked with the purse |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `(the payout table)` — in data, not code


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `CR_COMEOUT / CR_POINT` — phase codes; the whole rule set keys off them


## Art keys

- `craps.d6` — a die face
- `craps.layout` — the felt
- `craps.puck` — on/off marker


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `craps.throw`
- `craps.natural`
- `craps.point`
- `craps.sevenout`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.craps.point` — C_TITLE
- `minigame.craps.loss` — C_BAD


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** gold, stake
- **reports in `MG_RESULT`:** outcome, gold
- **must survive a save:** nothing

## Content that belongs in a data pack

payouts

## Stat hook

**none -- pure odds, deliberately** — nothing; this is the one game where no stat reads for you

## Invariants the integration must not break

1. the house edge is asserted against the PUBLISHED figure for these exact rules (1.414% pass line), not against a number that felt right
2. the rules on screen are the rules simulated -- the player asked for a variant once and the maths moved with it


Each of these is an assertion in `CRAPS.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
