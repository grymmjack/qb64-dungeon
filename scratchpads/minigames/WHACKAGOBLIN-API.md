# WHACKAGOBLIN — API

**WHACK-A-GOBLIN** · `WHACKAGOBLIN.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Nine holes in a cellar floor. About a third of what comes up must NOT be hit --
a go/no-go task rather than a reflex test.

## Entry point

```basic
FUNCTION PlayWhack% (dex AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayWhack% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | reached the target score |
| `MG_LOST` | did not |
| `MG_LEFT` | walked |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `TARGET` — the score needed -- DERIVED from the sloppy-player simulation, not chosen
- `HIT_GOOD / HIT_BAD` — scoring


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `N_FOES / N_DECOYS` — the mix is EXACTLY these counts, shuffled; rolling it per target spread the count 12-26 and broke all three fairness claims at once
- `UP_FLOOR` — the visibility floor, set well clear of REACTION
- `REACTION` — the human budget the floor is measured against
- `HOLES / MAXPOP` — bounds


## Art keys

- `hole.empty` — a hole
- `mob.goblin` — hit this
- `mob.pup` — asleep, do not
- `mob.mimic` — hits back
- `mob.mule` — yours
- `whack.shovel` — the cursor


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `whack.hit` — a goblin
- `whack.wrong` — a decoy
- `whack.miss` — the floor
- `whack.rise` — something coming up


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

`minigame-frantic`

## Theme keys

- `minigame.whack.goblin` — C_GOOD
- `minigame.whack.decoy.*` — one per decoy kind
- `minigame.whack.hole` — C_DIM


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** dex
- **reports in `MG_RESULT`:** outcome, gold, hp_delta
- **must survive a save:** nothing

## Content that belongs in a data pack

the decoy roster and the mix

## Stat hook

**DEX** — longer visibility per target -- time to decide, never an auto-hit

## Invariants the integration must not break

1. a player who swings at EVERYTHING must lose, or the discrimination is decorative
2. perfect discrimination must WIN, on every round
3. a good-but-human player wins too -- at TARGET 14 an attentive player failed a third of all rounds, which is not challenging, it is a game that hates attentive players. It is 12.
4. no hole ever holds two things at once -- that is unresolvable, not hard
5. every target is up longer than human reaction time at any depth


Each of these is an assertion in `WHACKAGOBLIN.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
