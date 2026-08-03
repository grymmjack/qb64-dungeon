# DODGE — API

**THE ARROW SLITS** · `DODGE.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Arrows come out of the wall; step PERPENDICULAR to the shot, not away from it.
The corridor trap from PLANS.todo.

## Entry point

```basic
FUNCTION PlayVolley% (n AS INTEGER, dex AS INTEGER, hits AS INTEGER)
```

`n` arrows in the volley; `hits` is how many are already on you.

Integration signature should become the standard one:

```basic
FUNCTION PlayVolley% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | the volley passed |
| `MG_LOST` | took the arrows |
| `MG_LEFT` | backed out of the corridor |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `D_N` — arrows per volley


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `DG_CLEAN / DG_HURT / DG_FLED` — legacy outcome codes; map to MG_* at the boundary


## Art keys

- `arrow.flight` — the arrow in the air
- `slit.armed` — a loaded slit
- `slit.spent` — a fired one
- `dodge.hero` — the player token


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `dodge.release` — the string
- `dodge.pass` — it goes by
- `dodge.hit` — it does not


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none -- it is over in seconds

## Theme keys

- `minigame.dodge.arrow` — C_WARN
- `minigame.dodge.safe` — C_GOOD
- `minigame.dodge.hit` — C_BAD


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** dex, hp
- **reports in `MG_RESULT`:** outcome, hp_delta
- **must survive a save:** nothing

## Content that belongs in a data pack

arrows per volley and window width per level

## Stat hook

**DEX** — a wider reaction window

## Invariants the integration must not break

1. the window is never shorter than human reaction time, at any depth
2. the correct move is always perpendicular -- a slit that can be dodged by standing still is a slit that teaches the wrong lesson


Each of these is an assertion in `DODGE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
