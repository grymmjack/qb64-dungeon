# GUESS — API

**THE BOUND SPIRIT** · `GUESS.bas` · lands in **`game/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

It thinks of a number. You have a budget of guesses and it says higher or lower.

## Entry point

```basic
FUNCTION PlayGuess% (intel AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayGuess% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | named it |
| `MG_LOST` | out of guesses |
| `MG_LEFT` | walked |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `GRANGE` — the range; the budget derives from it automatically


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `(the budget formula)` — must never drop below the true worst case, computed by halving


## Art keys

- `spirit.bound` — the spirit
- `spirit.higher` — gesture up
- `spirit.lower` — gesture down


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `guess.higher`
- `guess.lower`
- `guess.right`
- `guess.spent` — the last guess


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

none

## Theme keys

- `minigame.guess.number` — C_TITLE
- `minigame.guess.budget` — C_WARN


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** intel
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing

## Content that belongs in a data pack

the range per level

## Stat hook

**INT** — extra guesses on top of the solvable minimum

## Invariants the integration must not break

1. the budget NEVER drops below ceil(log2(range)), computed by halving rather than by a logarithm
2. perfect play beats every secret in range, checked exhaustively over all of them


Each of these is an assertion in `GUESS.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
