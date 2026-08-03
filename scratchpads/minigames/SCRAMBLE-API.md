# SCRAMBLE — API

**THE SCATTERED WORD** · `SCRAMBLE.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Letters carved out of order. Put them back.

## Entry point

```basic
FUNCTION PlayScr% (intel AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayScr% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | enough words |
| `MG_LOST` | out of lives |
| `MG_LEFT` | left |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `WINSTREAK`
- `THINK_TIME` — seconds to solve before typing time starts


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `SLOW_CPS` — as TRUENAME
- `WORDN` — list size


## Art keys

- `scramble.door` — the carved door
- `scramble.tile` — one letter


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `scramble.key`
- `scramble.right`
- `scramble.wrong`
- `scramble.reveal`


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.scramble.letters` — C_TITLE
- `minigame.scramble.reveal` — C_COOL


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** intel
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing

## Content that belongs in a data pack

the word list -- and the anagram check MUST run against whatever a pack supplies

## Stat hook

**INT** — revealing the next letter in place

## Invariants the integration must not break

1. NO TWO WORDS IN THE LIST MAY BE ANAGRAMS. The player unscrambles correctly, types a real answer, and is told they are wrong -- unrecoverable as a player, invisible as an author, because the fault is in the PAIR. The first run of this check found SCEPTRE and SPECTRE eight entries apart in a list I had just written
2. a scramble uses every letter and no others
3. it never comes out as the word itself, and never spells a DIFFERENT word from the list


Each of these is an assertion in `SCRAMBLE.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
