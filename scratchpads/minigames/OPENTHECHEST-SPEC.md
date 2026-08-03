# OPENTHECHEST — spec

**Built** — `OPENTHECHEST.bas`, 32 assertions. This was written *before* the code,
because the interesting half is not the puzzle, it is the **level-scoped memory**,
and that is an API decision that had to be right before any drawing happened.

Kept as the design record, and **updated where building it changed the design** —
a spec that quietly disagrees with the code is worse than no spec, because both
look authoritative.

## The chest

A chest with three locks set under the lid, each a different colour. Arrows pick
a lock, a key opens it. Under the chest sits a box for the contents.

Placeholder art for now; ANSI art later — so nothing may depend on the art, and
the drawing goes through one routine that can be swapped whole.

## The mechanic

1. Three clasps are shown. You choose which to open **first**.
2. **Correct** → that clasp stays open and keeps its colour, and **every** clasp
   is re-dealt across the positions — the opened ones too.
3. **Wrong** → the mechanism **arms**. See "the open question" below.
4. Three correct choices in a row → the chest opens, no trap.

The re-deal after each pick is the whole design: it means the answer cannot be a
*position*. What you are remembering is an ordered sequence of **colours** — and
the chest deliberately refuses to let you cache it as "left, middle, right".

> **Changed while building:** the first cut re-dealt only the clasps still *shut*,
> which with three clasps means two, which is a coin flip — so half of all
> shuffles changed nothing visible and the chest looked like it had ignored you.
> Every clasp moves now.
>
> It is **not** forced to differ, though. Guaranteeing a change means excluding
> the identity permutation, and that biases where the answer lands: measured
> 40/20/40 against a uniform 33/33/33. Visible movement is a presentation
> problem and is solved in presentation — the clasps visibly tumble, so the one
> time in six that a uniform re-deal lands back where it started still reads as a
> shuffle that happened.

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
CHEST_ART("clasp.closed")     CHEST_ART("clasp.open")   CHEST_ART("lid")
CHEST_ART("box")              CHEST_ART("cursor")

' colours are NAMED, not hardcoded -- the three clasp colours are content, and a
' data pack may want different ones (or more than three)
CHEST_HUE("clasp.a") ... and so on, through the theme, with a fallback each

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

The number of clasps should come from the same table rather than being three
forever — three is a tuning value, not an architecture. (Called *clasps* in the
code: `LOCK` is a QB64 reserved word.)

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
- a wrong pick has a real cost (or the guess is free and there is no game) —
  which ended up being the fuse rather than instant destruction, below
- the fuse: perfect play never arms it; a correct clasp winds it back but does
  not disarm it; a scripted pause is never charged against it

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

**The fuse never stops.** Nothing in the play loop blocks: messages carry an
expiry and the shuffle is a frame counter, so the clock is pure wall time from
the moment it was armed. The first version paused to show each message and then
pushed the fuse origin forward to hand those seconds back — two faults wearing
one coat, because a fuse you can watch stop is not a fuse, and every pause is a
place someone has to remember to discount. There is nothing left to discount.
(The only blocking waits are the three terminal screens — opened, destroyed,
already-known — where no fuse is running.)

**A wrong clasp never touches the fuse.** It does not reset it and it is not
fined — the clock simply keeps counting, which is what a burning fuse does. That
makes the LENGTH the only thing between a patient guesser and a free chest,
because the colours are on screen: try one, try another, and the third is forced.

So the fuse is derived from that, not chosen. The clock starts *on* the wrong
pick that arms it, so what it buys you is how many **more** picks you get:

| | |
|---|---|
| fuse | 4.5s |
| a pick (reading three colours and choosing) | 2.5s |

`2.5 ≤ 4.5` — one more pick, so a single mistake is recoverable *if you then know
the answer*.
`2 × 2.5 > 4.5` — but not two, so you cannot try every colour in turn.

The first cut sat at 6.5s, which buys **two** more picks — exactly enough to
exhaust three colours by elimination. The simulated guesser opened **100%** of
chests. That was not a bad test, it was a fuse long enough to make the puzzle
free and the level code worthless alongside it.

At 4.5s a patient guesser opens **0.500** of chests: real teeth, and still a
genuine mercy next to the instant loss it replaced. That number is simulated
against the real `TryClasp%` every run, because it is the number that decides
whether learning a level's code is worth anything at all.

## Still open

Whether the fuse should also be the mechanism for chests found on a level whose
code you already know. Right now those open instantly with no roll at all, which
is the point of the level memory; if that turns out to feel like nothing is
happening, a short "you already know this one" flourish is presentation, not
rules.
