# Mini-game catalogue

Candidates for the dungeon, judged against one bar: **does it have a decision in it?**

A mini-game that is only a die roll is a die roll with extra keystrokes — the Gambler's
Altar already fills that slot. Every entry below is here because there is something to
be *good at*, and something the ability scores can plausibly hook into.

Legend: **[built]** has a prototype · **[next]** designed, worth building · **[maybe]**
interesting but unproven · **[no]** considered and rejected, with the reason.

---

## Built

All eighteen have a `selftest` and a `shot`; see [README.md](README.md) for the full table
and the assertion counts.

| game | where | the decision | stat |
|---|---|---|---|
| **Riddle** | magic mouth | answer matching under a guess budget | WIS |
| **Disarm maze** | magic siren | trace a perfect maze against a fuse | WIS |
| **Arrow dodge** | arrow slits | step perpendicular to the shot | DEX |
| **Knucklebones** | tavern | push-your-luck 2d6, any ONE takes the pot | WIS reads odds |
| **Craps** | tavern | come-out then chase the point; when to walk | — (pure odds) |
| **Plinko** | fortune shrine | which channel to drop from; risk-vs-reward slots | CHA nudges |
| **Guess the number** | a bound spirit | binary search under a guess budget | INT buys guesses |
| **Rock paper scissors** | a goblin duel | read the opponent's TELL and exploit it | WIS spots the tell |
| **Rune slab** | a cursed slab | concentration where forgetting costs HIT POINTS | memory |
| **Monkey see** | a shrine floor | Simon; the sequence extends, it never re-rolls | WIS buys recalls |
| **Lockpick** | chests, doors | search the dial by feel; the clock runs on moves | DEX buys fuse |
| **Trap disarm** | trapped chests | cut wires in the ORDER the notes imply | INT buys notes |
| **Cup shuffle** | a street dealer | follow the coin through an honest shuffle | WIS buys a fumble |
| **Whack-a-goblin** | a cellar | go/no-go: a third of what pops up must not be hit | DEX buys time |
| **Twenty-one** | tavern, high stakes | the only game here whose skill is a TABLE | — |
| **Wheel of mystery** | a wall wheel | *(a ceremony, not a game -- see below)* | — |
| **Speak its name** | a warded door | name the thing from its description | WIS buys a letter |
| **Scattered word** | a carved door | unscramble it; the answer must be the ONLY fit | INT reveals letters |

### The wheel is not a game, and says so

**Wheel of mystery** fails house rule 1 outright: one input, no judgement, whatever it
stops on happens. It is kept because it is the most theatrical way to deliver a random
event, and it is *labelled* rather than dressed up as a decision. What it still has to
prove is that it does not lie — the outcome is read off the angle it stopped at, never
picked first and animated toward, and the wedge widths are the complete truth about the
odds.

---

## Designed, worth building next

**Pickpocket** *(a sleeping guard, a merchant)* — a two-axis timing game: the guard's
breathing rises and falls, you reach in on the exhale and withdraw before the inhale.
Two commits, not one, so greed is the mechanic: take the purse and go, or reach again.
*DEX to steady, CHA to talk your way out when caught.*

**Haggle** *(shops)* — the merchant has a hidden floor price; you make offers, they
counter, and each rejected offer sours them a little. A pure information game: you are
binary-searching a number that gets worse the longer you take. *CHA sets how much
souring you can afford.* Pairs naturally with the town phase in PLANS.todo.

**Stealth crossing** *(a patrolled corridor)* — guards move on a fixed visible cycle;
you advance one tile per beat and must never be in a lit tile when a lantern sweeps.
Chess-like, no reflex needed — the tension is committing to a route. *DEX for extra
moves per beat, WIS to see one beat further ahead.*

**Balance the ledge** *(chasms, rope bridges)* — a drifting marker you correct with
taps; over-correcting is the failure, not under-correcting. Teaches a light touch, which
is a genuinely different skill from the composure gauge's single commit. *DEX.*

**Alchemy mix** *(alchemist, curios)* — combine three of six reagents; the game tells
you "warmer/colder" against a hidden recipe. A deduction game with a small search space
and real memory pressure across attempts. *INT.*

**Rune tracing** *(warded doors)* — a shape is shown for a moment, then hidden, and you
retrace it on a 3×3 grid from memory. Length grows with depth. *INT, and it is the only
memory game in the set.*

**Bones (Liar's Dice)** *(tavern, higher stakes)* — bluffing against a monster with a
readable personality (cautious, reckless, bluffer). Beatable by reading the opponent
rather than the dice. *WIS to spot the type.* The richest of these and the biggest build.

**Fishing** *(underground lakes)* — a hooked thing pulls; you keep line tension in a band
by tapping, too slack and it escapes, too tight and it snaps. *CON for stamina.*
Cheap, calming, and a good pace-breaker between fights.

---

## Maybe — interesting but unproven

- **Torch relay** — cross a dark room lighting sconces before your torch burns out;
  route optimisation under a fuse. Risks feeling like the maze.
- **Echo mapping** — shout, hear returns, deduce the room shape and find the exit blind.
  Lovely idea, hard to make readable in text.
- **Weigh the coins** — a balance puzzle to find the one counterfeit in N. Classic and
  clean, but it is a maths quiz and might read as homework.
- ~~**Card monte**~~ — **built** as `CUPSHUFFLE.bas`. The "unless the shuffle is readable"
  caveat turned out to be the entire design: no swap may be a no-op and the slide has a
  hard floor, because a player who cannot follow correctly concludes tracking is pointless
  and starts guessing, at which point it is a 1-in-3 coin flip wearing a hat.

## Rejected, and why

- **Lockpick-as-QTE** — press the key when the bar is in the zone. That is the composure
  gauge with a lock drawn on it, and the design bible's rule applies: one engine wearing
  masks, not a second engine wearing the same mask. The built version is a *search* for
  a hidden angle instead, which is a different verb — and its clock runs on MOVES rather
  than wall time, so there is no reflex component at all.
- **Combat mini-games per weapon** — explicitly forbidden by PLANS.todo. See
  [BOW-AND-MAGIC.md](BOW-AND-MAGIC.md).
- **Typing tests** — a raw words-per-minute test is fast, cheap, and wrong for a game
  played with one hand on the arrows, and it punishes the wrong skill.
  **Corrected:** this rejected the right thing but was written too broadly, and
  `TRUENAME.bas` / `SCRAMBLE.bas` are now built. The skill in those is *recall* and
  *deduction*; typing is only how the answer is delivered. The line between the two is
  enforced, not asserted: both clocks are derived from the longest possible answer at
  **two characters a second** — a slow, one-finger, look-at-the-keyboard pace — with
  thinking time added on top rather than folded in. Nobody may lose either game because of
  how fast they type.
- **Anything needing a mouse** — the dungeon is keyboard-first; the debug overlay is the
  only mouse surface and it is a dev tool.

---

## The house rules these follow

1. **A decision, not a roll.** If the optimal play is always the same, it is a cutscene.
2. **Stats read, they do not cheat.** WIS shows you the odds; it does not bend them.
   A player who feels the game is fudging in their favour stops trusting a win.
3. **Fairness is provable or it is not claimed.** Anything with odds gets a Monte Carlo
   in its selftest; anything generated gets a solvability proof. This is not ceremony —
   it has caught a turn budget one turn below the true worst case, a target score that
   failed attentive players a third of the time, and two anagrams eight entries apart in
   a word list. None of the three was visible by reading the code.
4. **Failure costs something, and losing is survivable.** These sit inside a dungeon
   crawl, not instead of one.
5. **Teach in the first ten seconds.** The first arrow is slow, the first riddle is
   easy, the first lock is loose.
6. **Whoever the stat helps, it helps them SEE.** Every stat hook in the built set buys
   information or time: a hint, a look, a fumble, a note, seconds on a fuse. None of them
   moves a pin, re-deals a puzzle, or bends a roll — and several files assert exactly
   that, because a player who suspects the game is fudging in their favour stops trusting
   a win.
