# MAZE — API

**THE SIREN'S MAZE** · `MAZE.bas` · lands in **`engine/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Trace a path to the sigil before the fuse burns out. Generic: it knows nothing
about the dungeon, which is why it can live in engine/.

## Entry point

```basic
FUNCTION PlayMaze% (w AS INTEGER, h AS INTEGER, wis AS INTEGER)
```

`w`/`h` are odd cell counts; the maze is generated, never authored.

Integration signature should become the standard one:

```basic
FUNCTION PlayMaze% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | reached the sigil |
| `MG_LOST` | fuse expired |
| `MG_LEFT` | walked away |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `BRAID_PCT` — how many dead ends get opened up -- higher is easier and less maze-like
- `WARD_W / WARD_H` — maze size; must stay ODD or the generator has no valid cells


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `MZ_MAX` — array bound; raising it costs memory, lowering it truncates
- `W_N / ALLWALLS` — wall bitmask; the generator and the renderer share it


## Art keys

- `maze.wall` — corridor wall
- `maze.floor` — corridor
- `maze.sigil` — the goal
- `maze.trace` — where you have been


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `maze.step` — a footfall
- `maze.wall` — bumping a wall
- `maze.sigil` — the ward breaking


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

`minigame-tense` cue, ended on every exit path

## Theme keys

- `minigame.maze.wall` — C_DIM
- `minigame.maze.trace` — C_COOL
- `minigame.maze.sigil` — C_TITLE
- `minigame.maze.fuse` — the shared fuse colours


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing -- a maze is per-encounter

## Content that belongs in a data pack

size and braid percentage per dungeon level, so deeper wards are harder

## Stat hook

**WIS** — seconds on the fuse

## Invariants the integration must not break

1. every generated maze is SOLVABLE, checked on every generation and not sampled
2. the fuse is long enough for the measured worst-case solve at a human pace
3. braiding never disconnects the sigil


Each of these is an assertion in `MAZE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
