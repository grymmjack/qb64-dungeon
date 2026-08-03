# TRUENAME — API

**SPEAK ITS NAME** · `TRUENAME.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

A warded door names a thing by description; you type what it is. The roster is
on screen, so it is RECALL, not a vocabulary exam.

## Entry point

```basic
FUNCTION PlayName% (wis AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayName% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | named enough in a row |
| `MG_LOST` | out of lives |
| `MG_LEFT` | backed away |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `WINSTREAK` — how many
- `READ_TIME` — seconds to read the clue before typing


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `SLOW_CPS` — the typing pace the fuse is DERIVED from -- lowering it to make the game harder is changing an estimate to fit, not tuning
- `ROSTER` — how many entries


## Art keys

- `name.door` — the ward
- `name.roster` — the list frame


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `name.key` — a keystroke
- `name.right`
- `name.wrong`
- `name.timeout`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.name.clue` — C_TITLE
- `minigame.name.typed` — C_TEXT
- `minigame.name.hint` — C_COOL


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing

## Content that belongs in a data pack

the roster -- and it should come from the BESTIARY, so it stays in step with the monsters that actually exist

## Stat hook

**WIS** — the first letter

## Invariants the integration must not break

1. the fuse is derived from the LONGEST name at a one-finger pace, with reading time ON TOP. Nobody may lose this for typing slowly; they lose it for not knowing
2. matching ignores case, spacing and punctuation, and still rejects near misses
3. no two names normalise to the same key, or one of them becomes unanswerable


Each of these is an assertion in `TRUENAME.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
