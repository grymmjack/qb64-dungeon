# RUNEMEMORY — API

**THE RUNE SLAB** · `RUNEMEMORY.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Concentration on a W x H slab. Some pairs are PAIN runes and cost 1 HP every
time they are revealed -- which is what makes memory a mechanic and not a theme.

## Entry point

```basic
FUNCTION PlaySlab% (cols AS INTEGER, rows AS INTEGER, painpairs AS INTEGER, hpmax AS INTEGER, intel AS INTEGER)
```

an odd cell count silently drops one stone rather than dealing an unmatchable one.

Integration signature should become the standard one:

```basic
FUNCTION PlaySlab% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | slab cleared |
| `MG_LOST` | out of turns, or out of HP |
| `MG_LEFT` | walked away KEEPING what was matched |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `cols / rows` — slab size, per level
- `painpairs` — how many cursed pairs
- `hpmax` — the HP the slab may spend


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `MAXTILES` — array bound
- `RUNE_N` — how many distinct runes exist; must be >= pairs


## Art keys

- `rune.back` — a face-down stone
- `rune.seen` — one you have turned before
- `rune.<name>` — one per rune
- `rune.pain` — the cursed marking


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `rune.turn`
- `rune.match`
- `rune.bite` — a pain rune -- distinct and nasty


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.rune.back` — C_DIM
- `minigame.rune.seen` — C_WARN
- `minigame.rune.face` — C_GOOD
- `minigame.rune.pain` — C_BAD


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** intel, hp, hpmax
- **reports in `MG_RESULT`:** outcome, hp_delta, gold (spoils for pairs matched)
- **must survive a save:** nothing -- a slab is per-encounter

## Content that belongs in a data pack

size, pain-pair count and HP allowance per level

## Stat hook

**INT** — turns on the budget

## Invariants the integration must not break

1. perfect play clears EVERY deal inside the turn budget -- the first budget I derived sat one turn under the measured worst case
2. the budget is not padded either: the worst case sits just under it
3. damage is charged per REVEAL, not per stone -- that is the entire design, and it is what makes the three simulated memory tiers bleed 6.3 / 8.8 / 48.6 HP
4. perfect play never dies on the default slab


Each of these is an assertion in `RUNEMEMORY.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
