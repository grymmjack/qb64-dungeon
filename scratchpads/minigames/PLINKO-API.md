# PLINKO — API

**THE FORTUNE SHRINE** · `PLINKO.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Real physics. Slide a coin along the lip, let go, watch it clatter through a
rectangular grid of iron studs into a slot.

## Entry point

```basic
FUNCTION PlayPlinko% (startpurse AS LONG)
```

one drop per call is the better integration shape; the prototype loops for convenience.

Integration signature should become the standard one:

```basic
FUNCTION PlayPlinko% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | tripled the stake |
| `MG_LOST` | ran out |
| `MG_LEFT` | walked |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `SHRINE_CUT` — the house cut; payouts renormalise around it automatically
- `RISK_LOW / MED / HIGH curves` — variance only -- the edge is identical across all three, asserted
- `DROPN` — how many placements along the lip


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `PEGROWS / PEGCOLS` — the grid MUST reach both walls; anything less leaves a clear channel and a coin falls through untouched
- `GRAV / BOUNCE / WALLBOUNCE / KICK / TOPPLE / RELEASE_JITTER` — the physics the payout table is MEASURED from -- change any and the table changes with it
- `DT / SUBSTEP-equivalent` — the fixed step the measurement and the animation share


## Art keys

- `plinko.case` — the cabinet
- `plinko.stud` — one iron stud
- `plinko.coin` — the coin
- `plinko.slot` — a payout slot
- `plinko.lip` — the release rail


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `plinko.clack` — stud hit, pitched by impact -- MUST be rate limited
- `plinko.wall` — a wall bounce
- `plinko.land` — the slot
- `plinko.release` — letting go


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none -- the clatter is the sound design

## Theme keys

- `minigame.plinko.stud` — _RGB32(&H90,&H98,&HA8)
- `minigame.plinko.coin` — _RGB32(&HFF,&HD8,&H60)
- `minigame.plinko.case` — _RGB32(&H10,&H0E,&H14)
- `minigame.plinko.slot` — C_DIM


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** gold, stake
- **reports in `MG_RESULT`:** outcome, gold
- **must survive a save:** nothing -- but see below

## Content that belongs in a data pack

the cut and the three risk curves. NOT the physics constants: those are structural.

## Stat hook

**none directly -- PLACEMENT is the skill** — nothing; a stat hook here would undercut the one decision the game has

## Invariants the integration must not break

1. payouts are MEASURED from the physics at load, never derived -- a bouncing body in a walled field has no closed form
2. the payout table is rebuilt whenever the board is re-measured, so a table can never outlive its measurement
3. no placement returns more than the advertised edge; the BEST one hits it exactly, so skill is worth the maximum and still cannot beat the house
4. every slot is reachable, or the board is advertising a payout it never pays
5. the measurement runs SILENT -- it drives the real physics ten thousand times at load, and every stud hit asks for a sound


Each of these is an assertion in `PLINKO.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
