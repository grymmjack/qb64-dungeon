# OPENTHECHEST — spec

Not built yet. Written down first because the interesting half is not the puzzle,
it is the **level-scoped memory**, and that is an API decision that has to be
right before any drawing happens.

## The chest

A chest with three locks set under the lid, each a different colour. Arrows pick
a lock, a key opens it. Under the chest sits a box for the contents.

Placeholder art for now; ANSI art later — so nothing may depend on the art, and
the drawing goes through one routine that can be swapped whole.

## The mechanic

1. Three locks are shown. You choose which to open **first**.
2. **Correct** → that lock stays open, and keeps its colour. The *remaining*
   locks then **randomise their colours and positions**.
3. **Wrong** → the trap fires. The chest and everything in it is destroyed.
4. Three correct choices in a row → the chest opens, no trap.

The re-randomisation after each correct pick is the whole design: it means the
answer cannot be a *position*. What you are remembering is an ordered sequence of
**colours** — red, then green, then blue — and the board deliberately refuses to
let you cache it as "left, middle, right".

Blind odds are 1 in 6 (3 × 2 × 1), which is brutal, and is exactly why the next
section exists.

## THE LEVEL CODE — the part that makes it fair

**Every chest on the same dungeon level has the same combination.** Each of the
nine levels has its own.

So the first chest on a level is a gamble, and the ones after it are a reward for
having survived the first. The player is not solving nine hundred puzzles, they
are learning nine codes — and the cost of learning each one is paid exactly once,
on the first chest of that level.

This means the mini-game **cannot own its own state**. It has to ask, and it has
to report back:

```basic
' What is the combination on this level? Rolled once per level per run and then
' stable -- every chest on level `lv` shares it.
FUNCTION ChestCode$ (lv AS INTEGER)          ' e.g. "RGB" -- an ordered colour triple

' Has the player already cracked this level's chests?
FUNCTION ChestCodeKnown% (lv AS INTEGER)

' Called when a chest is opened successfully. From here on, every chest on this
' level opens without a guess.
SUB ChestCodeLearn (lv AS INTEGER)

' The mini-game itself. If ChestCodeKnown%(lv) it should NOT re-ask -- it opens,
' says the player already knows this level's locks, and returns MG_WON.
FUNCTION PlayChest% (lv AS INTEGER)
```

Rules that fall out of that, and that the selftest has to hold:

- codes are **per level, per run** — rolled at the start of a run, not per chest
- a code, once learned, stays learned for the rest of the run
- descending to a new level means an **unknown** code again
- learning level 4's code tells you nothing about level 5's
- two levels *may* roll the same code by chance; that must not be prevented
  (forcing them distinct is itself information), but it must not be assumed
  either
- codes belong in the **save file**, or a reload hands back a puzzle the player
  has already paid for

## ART AND SOUND ARE PARAMETERS, NOT CODE

The prototype draws placeholders. The real thing must be able to take **pixel art
or ANSI art** for every piece, without the mini-game knowing which it got — the
game already has both pipelines (`ArtFile$` resolves pixel art through the art
pack; `ANSI_Print` renders `.ans`), and the chest must not care.

So every visual and every noise is looked up by NAME through a small table, and
the mini-game never names a file, a colour value, or a tone:

```basic
' one entry per drawable piece; kind = pixel art, ANSI art, or the built-in
' placeholder, resolved per piece so a half-finished art pack still runs
CHEST_ART("chest.closed")     CHEST_ART("chest.open")   CHEST_ART("chest.blown")
CHEST_ART("lock.closed")      CHEST_ART("lock.open")    CHEST_ART("lid")
CHEST_ART("box")              CHEST_ART("cursor")

' colours are NAMED, not hardcoded -- the three lock colours are content, and a
' data pack may want different ones (or more than three)
CHEST_HUE("lock.a") ... and so on, through the theme, with a fallback each

' every sound by name, through the game's Sfx dispatcher, so a pack can override
' any of them and the beeper fallback still covers a pack that ships none
"chest.pick" "chest.correct" "chest.wrong" "chest.shuffle" "chest.open" "chest.trap"
```

Two rules that come with that, both of which the engine already enforces
elsewhere and both of which have bitten this project before:

- **a missing asset means "use the fallback", never "fail"** — same rule as
  `Say$` and `Thm~&`: a pack that ships three of the eight pieces gets its three
  and the placeholders for the rest
- **a placeholder must be detectable as one**, so `imagemanifest audit` still
  lists it as work to do rather than counting the stand-in as finished art. That
  is `ArtLooksPlaceholder%` / `AnsiIsBlank%`, and it exists because a stand-in is
  a file and every "does it exist" check says yes

The number of locks should come from the same table rather than being three
forever — three is a tuning value, not an architecture.

## What the selftest will have to prove

- every code is a permutation of the three colours — no repeats, all three used
- all six permutations are reachable, roughly equally
- **blind play wins 1 in 6**, measured, not asserted from the arithmetic
- a player who knows the code wins **every** time — the re-randomisation must
  never be able to make a known code fail, which is the bug that would make the
  whole level-memory idea worthless
- the re-randomisation genuinely moves things: after a correct pick, position is
  uninformative about the remaining answer
- solving one chest on a level makes every later chest on that level free, and
  changes nothing about any other level
- a wrong pick destroys the contents (the stake is real, or the guess is free
  and there is no game)

## The open question, and how it got answered

The question was whether a wrong first pick should destroy the chest outright or
cost something and let you retry. Destroying it is cleaner and matches "trap",
but it makes the first chest of every level a 1-in-6 coin flip for the whole
hoard, which is a lot to ask of a player who has just arrived on a new level.

**Answered by a fuse instead of by choosing either.** A wrong clasp *arms* the
mechanism: twelve seconds, wound back to full by each correct clasp and never
disarmed. So it is still a trap and still frightening, but the punishment for one
mistake is pressure rather than an instant loss — and the one thing that must not
work still does not, because guessing your way through the colours costs more
time than the fuse has.

That made `TRAP_DESTROYS` a dead constant, and it has been removed rather than
left sitting there labelled as an open decision.

Both halves are asserted against the same three numbers:

| | |
|---|---|
| fuse | 12s |
| a pick (reading three colours and choosing) | 2.5s |
| a further wrong clasp | −4s |

`2.5 + 4 + 2.5 ≤ 12` — one blunder is recoverable at a human pace.
`2 × (2.5 + 4) > 12` — brute force is not.

## Still open

Whether the fuse should also be the mechanism for chests found on a level whose
code you already know. Right now those open instantly with no roll at all, which
is the point of the level memory; if that turns out to feel like nothing is
happening, a short "you already know this one" flourish is presentation, not
rules.
