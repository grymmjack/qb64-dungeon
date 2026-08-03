# RIDDLE — API

**THE MAGIC MOUTH** · `RIDDLE.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

A carved mouth asks a riddle. Answer it, or it keeps the door shut.
Sits on the magic-mouth chamber events from PLANS.todo.

## Entry point

```basic
FUNCTION PlayRiddle% (idx AS INTEGER, wis AS INTEGER)
```

`idx` picks the riddle; pass -1 for a random unasked one.

Integration signature should become the standard one:

```basic
FUNCTION PlayRiddle% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | answered |
| `MG_LOST` | out of attempts -- the door stays shut |
| `MG_LEFT` | walked away, no penalty |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `MAXRIDDLE` — how many riddles the table can hold


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `RID_SOLVED / RID_FAILED / RID_FLED` — legacy outcome codes; map to MG_* at the boundary


## Art keys

- `mouth.idle` — the carved face, closed
- `mouth.speaking` — mid-riddle
- `mouth.pleased` — answered
- `mouth.angry` — failed


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `riddle.ask` — a low stone grind
- `riddle.right` — a satisfied hum
- `riddle.wrong` — a stone snap
- `riddle.hint` — a whisper


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none -- it is a conversation, not a set piece

## Theme keys

- `minigame.riddle.prompt` — C_TITLE
- `minigame.riddle.answer` — C_TEXT
- `minigame.riddle.hint` — C_COOL


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis, level (riddle difficulty band)
- **reports in `MG_RESULT`:** outcome, note
- **must survive a save:** which riddles have been asked this run, or the same one repeats

## Content that belongs in a data pack

riddles belong in a data-pack table (`riddles.txt`: prompt | answers | hint), not in code

## Stat hook

**WIS** — extra attempts, and a successful save buys a hint

## Invariants the integration must not break

1. answer matching is generous about case, spacing and articles, and strict about being right
2. every riddle has at least one accepted answer, checked at load
3. a hint never contains the answer


Each of these is an assertion in `RIDDLE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
