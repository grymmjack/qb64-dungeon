# OPENTHECHEST — API

**THE THREE CLASPS** · `OPENTHECHEST.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Three colour-coded clasps, opened in one order. Every clasp is re-dealt after
each pick, so the answer is a colour and never a position.

## Entry point

```basic
FUNCTION PlayChest% (lv AS INTEGER)
```

THE INTEGRATION POINT: it must take the run's code table, not own one. See below.

Integration signature should become the standard one:

```basic
FUNCTION PlayChest% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | opened |
| `MG_LOST` | the fuse ran out |
| `MG_LEFT` | backed away |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `FUSE_SECS` — seconds once armed -- see the invariant, this is NOT free to change
- `HUMAN_PICK` — the modelled cost of a deliberate pick; the fuse is proved against it


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `CLASPS / HUES` — three of each; a code is a permutation of the hues
- `LEVELS` — 9 -- one code per dungeon level
- `ARTN` — the art key table size


## Art keys

- `chest.closed`
- `chest.open`
- `chest.blown`
- `clasp.closed`
- `clasp.open`
- `lid`
- `box` — the hoard beneath
- `cursor`


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `chest.pick` — moving the cursor
- `chest.correct`
- `chest.wrong`
- `chest.shuffle` — the clasps tumbling
- `chest.open`
- `chest.trap`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

`minigame-tense` once the fuse is armed, and only then

## Theme keys

- `minigame.chest.clasp.a/b/c` — the three clasp colours -- CONTENT, a pack may want different ones
- `minigame.chest.wood`
- `minigame.chest.fuse` — the shared fuse colours


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** level -- and the run's code table
- **reports in `MG_RESULT`:** outcome, gold, `learned` (this level's code is now known)
- **must survive a save:** THE CODES AND WHICH ARE KNOWN. A reload that re-charges a player for a code they already bought is the worst kind of bug, because it looks like the game working. Format: nine `<code><K|->` groups on one save line.

## Content that belongs in a data pack

clasp colours and count; the fuse and the pick estimate

## Stat hook

**none -- the LEVEL MEMORY is the mechanic** — nothing; a stat hook would undercut the code being worth learning

## Invariants the integration must not break

1. a player who KNOWS the code wins EVERY time. If the re-deal can ever put a needed colour out of reach, the level memory is worthless and the first chest was robbery
2. the re-deal is UNIFORM. Forcing it to always change means excluding the identity permutation, which biases where the answer lands (measured 40/20/40 against 33/33/33). Visible movement is a presentation problem and is solved by the tumble animation
3. the fuse NEVER stops. Nothing blocks; messages carry an expiry and the shuffle is a frame counter. The first version paused and then discounted those seconds back, which is a fuse you can watch stop AND a rule someone must remember at every future pause
4. a wrong clasp never touches the fuse -- which makes the fuse LENGTH the only thing between a patient guesser and a free chest. At 6.5s a simulated guesser opened 100% of chests by elimination. The length is derived: one more pick must fit, two must not
5. one code per LEVEL, shared by every chest on it, learned once, and two levels may share a code by chance -- forcing them distinct is itself information


Each of these is an assertion in `OPENTHECHEST.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
