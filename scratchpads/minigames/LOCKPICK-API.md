# LOCKPICK — API

**THE PICK AND THE PINS** · `LOCKPICK.bas` · lands in **`engine/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

Feel for the notch that sets each pin on a 24-notch dial. A SEARCH, not a
quick-time event -- the catalogue rejected the QTE version explicitly.

## Entry point

```basic
FUNCTION PlayLock% (dex AS INTEGER)
```


Integration signature should become the standard one:

```basic
FUNCTION PlayLock% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | every pin set |
| `MG_LOST` | the fuse ran out |
| `MG_LEFT` | gave up |

## Configuration

**Tuning** — a data pack may set these and the game still works:

- `PINS` — how many pins
- `(the fuse base in LockFuse!)` — seconds


**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

- `NOTCHES` — dial size; the band table and the coarse JUMP are derived from it
- `JUMP` — the coarse step; must divide NOTCHES or the sweep misses positions
- `T_FINE / T_JUMP / T_SET / T_MISS` — move costs -- the fuse budget is DERIVED from these
- `THINK_PER_MOVE` — the human allowance the fuse is proved against


## Art keys

- `lock.dial` — the dial
- `lock.marker` — the pick position
- `lock.pin.set` — a set pin
- `lock.pin.open` — an unset one


Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

- `lock.turn` — one notch
- `lock.jump` — a coarse jump
- `lock.set` — a pin giving
- `lock.slip` — a wrong set
- `lock.snap` — the fuse


Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

`minigame-tense`

## Theme keys

- `minigame.lock.dial` — C_DIM
- `minigame.lock.marker` — C_COOL
- `minigame.lock.set` — C_GOOD


Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** dex
- **reports in `MG_RESULT`:** outcome
- **must survive a save:** nothing

## Content that belongs in a data pack

pin count and fuse per level

## Stat hook

**DEX** — seconds on the fuse, and nothing else

## Invariants the integration must not break

1. the fuse drains in BOTH real time and move cost -- with only the latter, standing still was free and the fuse was a move budget wearing a bar
2. an efficient search fits, proved EXHAUSTIVELY over all 576 (start, target) pairs, not sampled
3. brute force does NOT fit, on move cost alone, so a key-masher cannot beat it -- this is the assertion that broke when the fuse grew and forced T_FINE up
4. the direction hint is only offered inside CLOSE range and always points the SHORT way round


Each of these is an assertion in `LOCKPICK.bas`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
