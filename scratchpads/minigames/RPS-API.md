# RPS — API

**THE GOBLIN'S GAME** · `RPS.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Best of five. The goblin is not random: it has a habit, and WIS decides
whether you can read it.

## Entry point

```basic
FUNCTION PlayRps% (wis AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayRps% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | three throws |
| `MG_LOST` | three throws against |
| `MG_LEFT` | walked |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `PREDICT_PCT` — how often the goblin obeys its habit -- the dial between 'no read possible' and 'a read wins outright'


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `TELLS` — how many habits exist; each needs a counter-play in CounterPlay%


## Art keys

- `rps.rock` — hand
- `rps.paper` — hand
- `rps.scissors` — hand
- `goblin.throwing` — the opponent


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `rps.throw`
- `rps.win`
- `rps.lose`
- `rps.draw`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.rps.win` — C_GOOD
- `minigame.rps.lose` — C_BAD
- `minigame.rps.tell` — C_COOL


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing

## Content that belongs in a data pack

the tells and their obey rate

## Stat hook

**WIS** — seeing the goblin's tell spelled out

## Invariants the integration must not break

1. counter-play beats every tell well above chance, measured over DECIDED throws (draws excluded -- a draw is nobody being right)
2. ...and never approaches certainty, or a spotted tell ends the game
3. blind play sits at even


Each of these is an assertion in `RPS.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
