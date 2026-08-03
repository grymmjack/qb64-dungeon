# MONKEYSEE — API

**MONKEY SEE, MONKEY DO** · `MONKEYSEE.bas` · lands in **`engine/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Simon. Four glyph-stones light in a sequence; repeat it. Every round adds ONE.
Generic enough for engine/.

## Entry point

```basic
FUNCTION PlayMonkey% (wis AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayMonkey% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | cleared the last round |
| `MG_LOST` | a wrong stone |
| `MG_LEFT` | walked |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `WINROUND` — how deep it goes
- `FLASH_MIN` — the readable floor -- lowering it is the one change that can make the game unfair


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `MAXSEQ` — array bound; must exceed WINROUND
- `PADS` — four; the tone table and the key map are sized to it


## Art keys

- `pad.sun` — stone 1
- `pad.moon` — stone 2
- `pad.stag` — stone 3
- `pad.wyrm` — stone 4
- `pad.lit` — the lit overlay


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `pad.sun` — 330Hz
- `pad.moon` — 415Hz
- `pad.stag` — 494Hz
- `pad.wyrm` — 622Hz
- `monkey.fail`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none -- the pads ARE the music

## Theme keys

- `minigame.monkey.pad1..4` — one per stone
- `minigame.monkey.lit` — the lit state


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** wis
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing

## Content that belongs in a data pack

round count and flash timing per level

## Stat hook

**WIS** — [R]ecall charges -- another LOOK at the same sequence, capped

## Invariants the integration must not break

1. the sequence is FIXED up front; each round reveals a longer PREFIX. Regenerating per round is indistinguishable for exactly one round and then feels broken forever
2. no stone lights three times running -- a triple reads as one long flash, i.e. as the game's fault when you lose to it
3. the flash never drops below FLASH_MIN at any depth: past a point faster is not harder, it is unreadable
4. a recall re-shows the SAME sequence -- it does not re-deal


Each of these is an assertion in `MONKEYSEE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
