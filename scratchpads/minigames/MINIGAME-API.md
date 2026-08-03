# The mini-game contract

Every `<GAME>-API.md` in this folder describes one prototype against **this**
document. Read this once; the per-game files then only have to say what is
different about that game.

The goal is that moving a prototype into `qb64-dungeon` is **wiring, not
rewriting**: the model transfers as-is, and everything the game can see or hear
arrives through a named hook that the engine already has.

---

## 1. The shape of a mini-game

Four entry points. Nothing else is public.

```basic
SUB   <Game>Init                                  ' once, at load
FUNCTION Play<Game>% (ctx AS MG_CTX, res AS MG_RESULT)   ' one play
SUB   Dump_<Game>                                 ' the [`] dev console topic
SUB   <Game>SelfTest                              ' assertions, headless
```

**`Play` returns an outcome and fills a result. It does not touch the world.**

That is the single most important rule here. A mini-game that reaches out and
adds gold, or subtracts HP, or calls `RecordKill` itself, is a mini-game that
cannot be tested headlessly, cannot be replayed, and cannot be reused by
`examples/minimal`. It reports; the caller applies.

```basic
TYPE MG_CTX                       ' everything the game may READ
    level     AS INTEGER          ' dungeon level 1..9
    seat      AS INTEGER          ' hot-seat player index 1..4
    str       AS INTEGER
    intel     AS INTEGER          ' `int` is reserved
    wis       AS INTEGER
    dex       AS INTEGER
    con       AS INTEGER
    cha       AS INTEGER
    hp        AS INTEGER
    hpmax     AS INTEGER
    gold      AS LONG
    stake     AS LONG             ' what the caller is willing to risk
END TYPE

TYPE MG_RESULT                    ' everything the game may CHANGE, as a report
    outcome   AS INTEGER          ' MG_WON | MG_LOST | MG_LEFT
    gold      AS LONG             ' signed: winnings or losses
    hp_delta  AS INTEGER          ' signed
    item      AS INTEGER          ' item code granted, 0 = none
    learned   AS INTEGER          ' game-specific flag the RUN must remember
    note      AS STRING * 48      ' one line for the event log
END TYPE
```

`MG_WON` / `MG_LOST` / `MG_LEFT` are already defined in `MG.bi` and keep their
values. **`MG_LEFT` is not a loss** — the player walked away, and the caller
should charge nothing.

### Why `learned` exists

Some games have state that outlives a single play and belongs to the *run*, not
to the mini-game: OPENTHECHEST's per-level combination is the clear case. The
mini-game must not own it, because it has to survive a save/load and has to be
shared across every chest on a level. So it asks through `ctx`, reports through
`res.learned`, and the run stores it. See `OPENTHECHEST-API.md`.

---

## 2. Colours — `Thm~&`

```basic
kol = Thm~&("minigame.plinko.stud", _RGB32(&H90, &H98, &HA8))
kol = ThmA~&("minigame.plinko.flash", _RGB32(&HFF, &HF0, &H90), alpha)
```

Every call passes **its own fallback**, so a missing file, a missing key and a
bad value all mean *leave that colour exactly as it is*. That is what makes a
theme pack able to restyle three colours and stay silent about the rest.

Rules:

- key prefix is **`minigame.<game>.<thing>`**, lower case, dotted
- `ThmA~&` for anything whose alpha is computed per frame — theming a packed
  colour would freeze the animation
- **never** theme a colour that means something mechanically. The board's
  `YELLOW`/`BROWN`/`BRIGHT_BLUE`/`BLACK` are collision values, not ink, and
  `ThemeReserved%` refuses `board.*` for exactly that reason. If a mini-game ever
  reads a pixel to decide what a thing *is*, that colour is reserved too and must
  be documented as such in its API file.
- `Thm~&` is a **pure lookup** and lives in `engine/TEXT.bas`. It does not
  lazy-load; before `LoadTheme` runs it returns the fallback, which is the same
  answer as a missing file. Do not add a load call to it.

## 3. Text — `Say$`

```basic
PrintCentered y, Say$("minigame.riddle.prompt")
```

`Say$` returns **the key itself** when the key is missing, so untranslated text
is visible rather than blank and migration can be incremental. Keys follow the
same `minigame.<game>.<thing>` shape.

Any player-facing sentence belongs in `strings.txt`. Anything in a selftest or a
dev dump does not — those are diagnostics, and hard-coding them keeps a data pack
from being able to break the tests.

## 4. Art — by name, resolved per piece

Mini-games never name a file. They declare **keys**, and the game binds them:

```basic
' pixel art, through the art pack, then the flat default
p$ = ArtFile$("minigames/plinko/coin.png")
' ANSI art
ANSI_Print _READFILE$(AnsiFile$("minigames/plinko/case.ans"))
```

Three rules, all of which the engine already enforces somewhere and all of which
have cost this project real time:

1. **Missing means fallback, never failure.** A pack shipping three of eight
   pieces gets its three and the built-in placeholders for the rest. Same rule as
   `Say$` and `Thm~&`.
2. **A placeholder must stay detectable as one**, or `imagemanifest audit`
   counts a stand-in as finished art. `ArtLooksPlaceholder%` (colour count) and
   `AnsiIsBlank%` (zero glyphs) do that. Do not "fix" a missing asset by
   committing a box with a caption in it.
3. **The mini-game must not care which kind it got.** One draw routine takes a
   key and decides between pixel art, ANSI art and the placeholder. That is the
   seam that lets art land later as data rather than as a code change.

Every per-game file lists its art keys as a table. Those keys are what the
manifest will be generated from, so they are a commitment, not a suggestion.

## 5. Sound — `Sfx`, and never `SOUND`

```basic
Sfx "minigame.lockpick.pin"                 ' file if a pack has it, else Tone
SfxOr "minigame.plinko.clack", 620, 0.5     ' sample, else this exact beep
```

- **every distinct sound goes through the dispatcher**, so all of them are
  pack-overridable. The hand-tuned `Tone` fallback is the design, not a stopgap.
- **raw `SOUND` is forbidden.** It ignores `audio_muted` completely, which is how
  the test suite ended up beeping at whoever ran it. `tests/audit-mute.sh` is the
  rule in the game; `audit-quiet.sh` is the rule here.
- **`SOUND` is a QUEUE, not a speaker.** Anything that can fire per frame — a
  bounce, a tick, a peg — must be rate-limited at the call site *and* bounded
  centrally. PLINKO enqueued ~100,000 beeps at startup once; it played them all.
- **nothing calls `_SNDCLOSE`.** It calls `RetireSound`, and `ReapSounds` frees
  the handle once the mixer is provably done with it. Freeing a node the device
  thread is mid-read of corrupts the heap.
- any loop that plays audio **must call `AudioTick`**, or crossfades freeze and
  narration goes silent.

## 6. Music — cues

```basic
PlayCue "minigame-tense"      ' overrides the level track
EndCue                        ' restores it
```

`PlayCue` is a **no-op when the file is absent**, so a cue never cuts to silence.
A mini-game that opens a cue must close it on *every* exit path, including
`MG_LEFT` and including an error.

## 7. Narration

`Narrate "<key>"` plays `assets/narration/<pack>/<key>.<ext>` if it exists and is
silent otherwise. When a crawl is narrated its per-glyph typewriter blips are
muted so the voice carries it. Optional for every mini-game; free when unused.

## 8. Dice

Any roll a *player* would recognise as a roll goes through:

```basic
n = GameRoll(count, sides, bonus, "label")
```

which honours the SETTINGS **Real Dice** toggle (the player rolls physical dice
and types the result) and **Dice Math** (who adds the modifier). A mini-game that
rolls with `RND` where the player expects dice silently breaks Real Dice for that
player.

Internal randomness that is *not* a die — a shuffle, a peg bounce, a spawn
position — is `RND` and should stay that way.

## 9. The frame chokepoint — `Present`

`qb64-dungeon` has no single main loop; it has ~40 nested blocking loops. `Present`
is the one place every frame passes through, and the `[`]` dev console hotkey and
`_RESIZE` handling are polled there.

**Any loop a mini-game runs must call `Present`.** A mini-game loop that draws and
`_DISPLAY`s directly is a screen the console cannot open over and the window
cannot be resized on.

## 10. The chronicle

Outcomes are reported by the caller, not the mini-game, but the *hooks* are:

`RecordCurio` / `RecordTrap` / `RecordTreasure` / `RecordItem` / `LogEvent`, and
gains route through `CurioGain` (which does `LogTreasure` + `RecordTreasure` +
`LogEvent` together) rather than through `LogTreasure` alone.

## 11. The dev console

Every mini-game registers **one dump topic**, and `tests/audit-dumps.sh` enforces
all four legs of it: topic name ⇄ `SUB Dump_<Game>` ⇄ a `RegisterDump` line ⇄ a
dispatch `CASE`. The missing-`CASE` leg is the dangerous one — QB64 parses a call
to an undefined SUB as a **label** and silently never runs it.

Convention: `Dump_X` (with the underscore) declares a topic; `DumpX` is a private
helper.

## 12. The engine / game boundary

`engine/` names no `game/` symbol, enforced by `tests/audit-boundary.sh`, and
`examples/minimal` proves it by building a second game on `engine/` alone.

So: a mini-game that is **generic** (a gauge, a maze tracer) may live in
`engine/` and must reach the game only through a `Game_*` hook. A mini-game that
knows about goblins, dungeon levels or the hoard belongs in `game/`. Every
per-game file says which side it lands on and why.

## 13. Settings

A mini-game that needs a player-facing option adds one SETTINGS row. `BuildSetLayout`
must place the id into a column **and** a row — an unplaced id simply does not
draw, with no error, and `dungeon.run settingsshot` fails on exactly that.

## 14. Errors

`dungeon.bas` already arms `ON ERROR GOTO DungeonFatal` before anything can fail.
A mini-game must not open a dialog, must not add its own handler, and must not
assume an optional asset exists — a missing one is a fallback, per §4.

---

## What each `<GAME>-API.md` adds

| section | what it pins down |
|---|---|
| **What it is** | two lines, and where it fits in the dungeon |
| **Entry point** | the exact signature and what each outcome means |
| **Config** | every tuning constant, split into *tuning* and *structural* |
| **Art keys** | the complete list — this is what the manifest is generated from |
| **Sound keys** | ditto, plus the beeper fallback each one must have |
| **Music** | the cue name, or none |
| **Theme keys** | every colour, with its fallback |
| **Run state** | what it reads from `MG_CTX` and what it reports in `MG_RESULT` |
| **Save** | anything that must survive a reload, and the format |
| **Stat hook** | which ability, and what it buys — always *information or time* |
| **Invariants** | the assertions the integration must not break, and why |
| **Side** | `engine/` or `game/`, with the reason |

### Structural vs tuning

A **tuning** constant can be changed by a data pack and the game still works.
A **structural** one cannot: change it and an invariant breaks, or the maths that
a payout or a budget was derived from stops holding.

That distinction is the reason the split is in every file. PLINKO's `SHRINE_CUT`
is tuning; its `PEGCOLS` is structural, because the stud grid has to reach the
walls or a coin falls straight through and the measured distribution is a lie.

---

## House rules these all inherit

1. **A decision, not a roll.** If the optimal play is always the same, it is a
   cutscene.
2. **Stats read, they do not cheat.** Every stat hook in the built set buys
   information or time — a hint, a look, a fumble, a note, seconds on a fuse.
   None moves a pin, re-deals a puzzle or bends a roll.
3. **Fairness is provable or it is not claimed.** Odds get a Monte Carlo;
   generated content gets a solvability proof, on every generation.
4. **Failure costs something, and losing is survivable.**
5. **Teach in the first ten seconds.**
