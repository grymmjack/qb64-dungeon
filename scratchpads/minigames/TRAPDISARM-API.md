# TRAPDISARM — API

**FIVE WIRES AND A SET OF NOTES** · `TRAPDISARM.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Deduce the one legal cut order from notes scratched on the plate.

## Entry point

```basic
FUNCTION PlayTrap% (intel AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayTrap% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | disarmed |
| `MG_LOST` | two strikes |
| `MG_LEFT` | backed away |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `(strike count)` — how many wrong cuts before it fires


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `WIRES` — 5; PERMS must equal WIRES! and BuildPerms is written for it
- `PERMS` — 120 -- the uniqueness scan is a full enumeration
- `MAXCLUE` — note-table bound
- `CL_BEFORE / CL_ADJ / CL_NOTAT / CL_AT` — note kinds; each needs a case in Holds% AND in NoteText$


## Art keys

- `wire.copper` — ...
- `wire.sinew` — ...
- `wire.bone` — ...
- `wire.iron` — ...
- `wire.silver` — ...
- `trap.plate` — the notes
- `wire.cut` — a cut wire


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `trap.cut`
- `trap.snap` — a wrong cut
- `trap.disarm`
- `trap.fire`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

`minigame-tense`

## Theme keys

- `minigame.trap.wire.*` — one per wire colour
- `minigame.trap.note` — C_TEXT
- `minigame.trap.cut` — C_DIM


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** intel
- **reports in `MG_RESULT`:** outcome, hp_delta
- **must survive a save:** nothing

## Content that belongs in a data pack

wire names and colours; the note KINDS are structural

## Stat hook

**INT** — extra TRUE notes about the same unchanged order

## Invariants the integration must not break

1. EVERY generated puzzle has exactly one solution, brute-forced over all 120 orderings on every generation
2. ...and that solution is the order the player is graded against -- unique-but-different would be the cruellest possible bug
3. every note is load-bearing: switch any one off and the answer goes ambiguous
4. INT's extra notes are TRUE of the same unchanged order, and the answer stays unique with them on


Each of these is an assertion in `TRAPDISARM.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
