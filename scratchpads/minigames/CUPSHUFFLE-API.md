# CUPSHUFFLE — API

**THE COIN AND THE CUPS** · `CUPSHUFFLE.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Follow the coin through a shuffle. The game does not palm it.

## Entry point

```basic
FUNCTION PlayCups% (cups AS INTEGER, swaps AS INTEGER, wis AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayCups% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | named the right cup |
| `MG_LOST` | named a wrong one |
| `MG_LEFT` | walked |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `cups` — 2..5
- `swaps` — how many


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `SLIDE_MIN` — the animation floor -- below it the cups teleport and the game silently becomes a 1-in-N guess
- `MAXCUPS / MAXSWAP` — array bounds


## Art keys

- `cup.closed` — a cup
- `cup.lifted` — one being lifted
- `cup.coin` — the gold piece
- `cup.table` — the surface


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `cup.slide` — one swap
- `cup.lift`
- `cup.win`
- `cup.lose`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.cup.body` — _RGB32(&H70,&H50,&H30)
- `minigame.cup.coin` — C_TITLE


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis
- **reports in `MG_RESULT`:** outcome, gold
- **must survive a save:** nothing

## Content that belongs in a data pack

cup and swap counts per level

## Stat hook

**WIS** — a dealer FUMBLE -- one cup lifted mid-shuffle. Information, not odds.

## Invariants the integration must not break

1. the coin is never moved except by a swap the player was SHOWN -- proved by replaying the swap list over a separately tracked index and demanding it agree
2. no swap is ever a no-op, and the slide has a hard floor: both read as a dropped frame, and a player who cannot follow correctly concludes tracking is pointless
3. the coin finishes under each cup about equally often
4. a WIS fumble only LIFTS a cup -- it never nudges the coin


Each of these is an assertion in `CUPSHUFFLE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
