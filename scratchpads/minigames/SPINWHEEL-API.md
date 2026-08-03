# SPINWHEEL — API

**THE WHEEL OF MYSTERY** · `SPINWHEEL.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

A heavy iron wheel. Crank it up/down to build momentum, let go, and whatever it
stops on happens. A spin that fails to complete a full turn has BALKED.

## Entry point

```basic
FUNCTION PlayWheel% ()
```

takes nothing today; integration should pass MG_CTX for the level, since the wedge table should vary by depth.

Integration signature should become the standard one:

```basic
FUNCTION PlayWheel% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | always -- the outcome is the wedge, reported in res |
| `MG_LOST` | n/a |
| `MG_LEFT` | did not pull the handle |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `the wedge table` — names, tells, WIDTHS -- the widths ARE the odds and belong in data
- `MAXTRAVEL` — how far a full crank goes
- `FRICTION` — how long it coasts


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `TRAVEL_SLOP` — the anti-aim term; MUST exceed 360 or crank settings become aimable
- `BALK_AT` — one full turn
- `MIN_RELEASE` — below this the handle does not move at all
- `SUBSTEP / MAX_STEP` — the animation's fixed step; a per-frame step made every spin look identical
- `(the square travel curve)` — linear made a weak crank spin nearly as far as a hard one


## Art keys

- `wheel.rim` — the painted rim
- `wheel.hub`
- `wheel.spoke` — the tracking mark -- without it fast and slow both read as a shimmer
- `wheel.pointer`
- `wheel.handle`


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `wheel.crank` — one stroke, pitched by charge
- `wheel.tick` — a wedge passing, pitched by speed
- `wheel.settle`
- `wheel.balk` — the punishment


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

`minigame-fate`, ended when the wedge resolves

## Theme keys

- `minigame.wheel.<wedge>` — one per wedge -- but see below
- `minigame.wheel.spoke` — near-white
- `minigame.wheel.pointer` — C_TITLE


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** level (which wedge table)
- **reports in `MG_RESULT`:** outcome, gold, hp_delta, item -- the WEDGE is the result
- **must survive a save:** nothing

## Content that belongs in a data pack

the whole wedge table, including widths

## Stat hook

**none** — nothing -- the crank is the only input and it deliberately cannot aim

## Invariants the integration must not break

1. the outcome is READ off the angle it stopped at, never picked and animated toward
2. the wedge announced is the wedge DRAWN under the pointer. These are checked SEPARATELY, because the first version passed 60000 spins of the first claim while announcing a wedge two positions from the one on screen -- the test replayed the same sign convention the bug lived in
3. NO crank setting aims the wheel, checked at EVERY setting rather than on average: one exploitable charge value is all it takes
4. a balked wheel finishes the spin ITSELF, so nudging selects nothing
5. the crank is workable by a human hand -- reaching full charge at a human stroke rate, and surviving the moment it takes to reach for SPACE


Each of these is an assertion in `SPINWHEEL.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
