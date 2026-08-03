# Mini-game prototypes

Standalone scratchpads for the mini-games in [plans/PLANS.todo](../../plans/PLANS.todo).
Built here first to get the *mechanic* right, then integrated into the game.

Each prototype has the same three modes, which is what makes building them here worth it:

| mode | what it does |
|---|---|
| `./X.run selftest` | assertions on the MODEL, to stdout, non-zero exit on failure |
| `./X.run shot` | render one representative frame to `X-shot.png` |
| `./X.run` | play it |

**`selftest` is the point.** A mini-game is mostly a small rules engine wearing a screen,
and the rules are what has to be right — so the model is written to be assertable with no
display, and the drawing is kept thin enough that one frame proves it.

**`shot` exists because passing every logic test and drawing nothing is a real failure**,
and only a picture catches it. It caught one immediately: BASIC binds `*` tighter than `\`,
so `(SW - LEN(s)) \ 2 * CW` is `(SW - LEN(s)) \ (2 * CW)` — every line centred at x=6 while
31 assertions passed.

## Building

```bash
cd scratchpads/minigames
qb64pe -w -x RIDDLE.bas -o RIDDLE.run
xvfb-run -a ./RIDDLE.run selftest
xvfb-run -a ./RIDDLE.run shot
```

## The prototypes

| file | where it fits | mechanic | stat | asserts |
|---|---|---|---|---|
| `RIDDLE.bas` | Magic mouths — save WIS | answer matching; WIS buys attempts, a save buys a hint | WIS | 31 |
| `MAZE.bas` | Magic sirens — save WIS | trace a perfect maze to the sigil against a fuse | WIS | 14 |
| `DODGE.bas` | Arrow slits — gesture | step PERPENDICULAR to the arrow; DEX widens the window | DEX | 19 |
| `GAMBLE.bas` | Tavern — gamble | push-your-luck 2d6; any ONE takes the pot | WIS reads odds | 14 |
| `CRAPS.bas` | Tavern | come-out, then chase the point; when to walk | — | 20 |
| `PLINKO.bas` | Fortune shrine | real physics; place the coin on the lip, payouts MEASURED from the board | placement is skill | 13 |
| `GUESS.bas` | A bound spirit | binary search under a guess budget | INT buys guesses | 9 |
| `RPS.bas` | A goblin duel | read the opponent's habit and exploit it | WIS spots the tell | 15 |
| `RUNEMEMORY.bas` | A rune slab | concentration, W×H, turn budget, **pain runes cost 1 HP per reveal** | memory itself | 16 |
| `MONKEYSEE.bas` | A shrine floor | Simon — the sequence EXTENDS, it never re-rolls | WIS buys recalls | 13 |
| `LOCKPICK.bas` | Chests, doors | search a 24-notch dial by feel, against a fuse that burns two ways | DEX buys fuse | 18 |
| `TRAPDISARM.bas` | Trapped chests | deduce the one legal cut order from the notes | INT buys notes | 13 |
| `CUPSHUFFLE.bas` | A street dealer | follow the coin; the game never palms it | WIS buys a fumble | 12 |
| `WHACKAGOBLIN.bas` | A cellar | go/no-go — a third of what pops up must NOT be hit | DEX buys time | 9 |
| `BLACKJACK.bas` | Tavern, higher stakes | basic strategy vs two wrong strategies | — | 17 |
| `SPINWHEEL.bas` | A wall wheel | CRANK it up/down; a heavy wheel with real momentum, and a price for teasing it | — | 34 |
| `TRUENAME.bas` | A warded door | name the thing from its description | WIS buys a letter | 17 |
| `SCRAMBLE.bas` | A carved door | unscramble the word; no anagram may be ambiguous | INT reveals letters | 15 |
| `OPENTHECHEST.bas` | Any chest | three colour clasps, re-dealt every pick; a wrong one lights a fuse | — (level memory) | 35 |

**Every fairness claim in that table is measured, not asserted by hand.** Where a game has
odds they are simulated; where it generates a puzzle, solvability is checked on every
generation; where it has a clock, the clock is derived from what a slow human can do.
That is not ceremony. It has caught: a turn budget in RUNEMEMORY one turn under the true
worst case; a target score in WHACKAGOBLIN that failed attentive players a third of the
time; two anagrams eight entries apart in SCRAMBLE's word list; a PLINKO coin pinned on a
stud for three thousand frames while the board still produced a plausible distribution out
of the survivors; and a SPINWHEEL crank that decayed faster than a hand could work it.

**And one it could not catch**, which is the more useful lesson: SPINWHEEL passed 60,000
spins of "the result is read, not chosen" while announcing a wedge two positions from the
one under the pointer. The test replayed the same sign convention the bug lived in. It
took a screenshot and a human-shaped question — *is the pointer on the wedge it just
named?* — so `shot` is not a nicety.

See [BOW-AND-MAGIC.md](BOW-AND-MAGIC.md) for why bow and magic are **not** here.

## Error handling

Every prototype arms `ON ERROR GOTO MgFatal` before anything can fail, for the same reason
`dungeon.bas` does: an unhandled QB64 error opens a **modal dialog that waits for a click**,
and under `xvfb` nobody can click it, so the process just hangs with no output saying why.
The handler prints the error and line to stdout and exits non-zero.

Audio goes through `MgBeep`, never `SOUND`. A raw `SOUND` ignores every mute flag that
exists, so the one thing standing between a headless selftest and an unwanted chirp is that
no prototype calls it directly. `selftest` and `shot` both set `MG_QUIET`.

## QB64 traps these hit, in order

Each of these cost a build. They are all in the project CLAUDE.md; they still land.

| trap | what it looked like |
|---|---|
| `AND`/`OR` never short-circuit | `LOOP UNTIL i < 3 OR p = SEQ(i-1)` read `SEQ(0)` and died on the first stone. `_ORELSE` fixes it |
| a FUNCTION's own name in its body is a **recursive call** | `IF LEN(x) > LongestName% THEN` blew the stack instantly |
| reserved words everywhere | `WEND` (closes a WHILE) as an array name; `RND` as a loop variable |
| a zero-arg FUNCTION takes **no parentheses** at the call site | `ReplayMatches%()` is a syntax error |
| single-line `IF` has no `ELSE IF` chain | had to break soft-18 strategy into a block |
| identifiers are case-insensitive | a local `ring` collides with `FUNCTION Ring%` |
| `RANDOMIZE n` twice with the same `n` does **not** reset the stream | the "same seed, same deal" test compared two different deals and failed |

## Integration

Nothing here includes the engine. When one moves into the game the MODEL functions transfer
as-is; only presentation is rewritten against `ChroniclePanel` and the theme colours, and
outcomes route through the existing `CurioGain` / `Record*` hooks.

## What is deliberately NOT here

Design authority for anything combat-shaped is `plans/TACTICAL-COMBAT.md` and the
gesture-combat design bible, and its rule is explicit:

> Sword vs bow vs spell is art + tuning over this same engine, not new code.
> **Do NOT build five mini-games.**

So **bow and magic are not prototypes in this folder.** They are tuning of the existing
composure gauge (`engine/GAUGE.bas` + `engine/GESTURE.bas`) — different knobs, different
art, same engine. Building them as separate mini-games would be a direct contradiction of
the plan, and would fragment the one thing the design says should stay unified.
