# Deep Tactical Combat — implementation plan

The flagship remaining feature: a 1-vs-up-to-4 encounter screen driven by **gesture
mini-games whose difficulty is derived from the character's stats**.

**Read these three first — they are the authority, this file is only the build order:**

1. **`~/git/qb64pe-lab/greywood/gesture-combat-design.md`** — the design bible (311 lines).
   The north star, per-gesture ancestry, the cross-cutting principles, the mercy/brutal
   dials, and a log of everything already built and tuned in the prototype.
2. **`~/git/qb64pe-lab/greywood/greywood.bas`** — a **working, playtested implementation**
   of this combat system (1536 lines). Phase A is a PORT of this, not an invention.
3. **`assets/ansi-art/default/ui-fight.xb`** — the screen mockup: 132×100 at an **8×8**
   font cell (the board is 132×51 at 8×16 — same 1056px width, double the rows).

> **The single most important thing to internalise:** greywood already discovered that this
> is **one engine wearing many masks** — *"Sword vs. bow vs. spell is art + tuning over this
> same engine, not new code."* Do not build five mini-games. Build one composure engine and
> re-tune it. That conclusion came out of actually shipping the prototype, so it outranks any
> plan written before playing it.

---

## Decisions taken (2026-07-29, with the maintainer)

| # | Decision | Rationale |
|---|---|---|
| 1 | **Third combat mode.** `opt_combatstyle`: 0 Oldschool 2d6 / 1 D&D duel / 2 Tactical | `DoCombatDnD` stays untouched, so nothing existing can regress and the feel can be A/B'd |
| 2 | **Active seat alone** — 1 player vs 1–4 enemies | Matches the mockup exactly (one PLAYER portrait, one PLAYER slot in initiative); other hot-seat seats wait their turn as today |
| 3 | **React when attacked** — a dodge per incoming attack | Independently confirmed by the design doc as *the defense axis*; greywood already implements it |
| 4 | **DEX times, STR/INT pays** — DEX widens windows/fuse for every gesture; the governing stat scales the payoff | Refined by the doc's per-gesture stat knobs (see below) |
| 5 | **Map the notebook attributes onto the existing six** | AIM→DEX, STRENGTH→STR, WILLPOWER→WIS (INT for a Wizard), COURAGE→CHA. No new character data, no save bump, sheet keeps its meaning |
| 6 | **Skill = `char_level`** for now | Already rolled, saved, and gained on clearing a floor. A real per-weapon skill system drops into the same formula later |
| 7 | **Defer positioning** — no hex/oct grid, no facing, no AP | `ui-fight.xb` has no battle grid. The doc's own "strategic layer" section reaches the same conclusion: columns + parallel fuses give the tactical read *"through the back door, with no grid"* |
| 8 | **Vendor the engine into `engine/`** | Same model as `engine/ansi/` (Toolbox64) and `engine/DICE3D/`. Free to adapt to ACTOR + 8×8 cells; cost is manual re-porting of future greywood work |
| 9 | **Port melee + dodge + sampled resolver first** | Covers the common case and the whole attack/defend loop; archery, death-save and juice are additive, not structural |

**Superseded:** an earlier answer picked a vertical "LADDER" geometry for the swing, from the
notebook sketches. The *built and tuned* melee gesture is the **sweeping bar** (`GestureLock`),
which is also what already exists in `engine/GESTURE.bas`. Port the bar. The ladder can return
later as one of the weapon masks.

---

## Three principles that must shape the code from day one

Getting these wrong is expensive to unwind, so they are structural, not polish.

### 1. One model, two presentations
Run the **interactive** sim only for the player's hero moments. For enemy turns, auto-resolve,
and the accessibility toggle, collapse **the same math** to a single sampled outcome — *"the
area each zone occupies **is** its probability."*

So `engine/GAUGE.bas` exposes two entry points over one parameter struct:

```
GaugeRun(knobs, out)      ' interactive: draw, poll, lock  -> zone + quality
GaugeSample(knobs, out)   ' non-interactive: sample the SAME zone areas
```

Both must be driven by identical knobs, or difficulty silently diverges between "you played
it" and "it auto-resolved" — the exact bug class this codebase keeps finding.

### 2. Stats compress the outcome RANGE; they do not shift it
Low skill ⇒ zones so tight that even perfect play yields a modest result (**low ceiling**).
High skill ⇒ zones so forgiving that even sloppy play is decent (**high floor**). Player
execution then moves you *within* the band the stats define. This is what keeps levelling
**and** execution meaningful simultaneously — and it is a different formula shape from
"the window gets bigger", which is what a naive reading produces.

### 3. WYSIWYG is sacred
The zone is **drawn exactly where it is scored, every frame.** No hidden fudge on the sim
tier while the player is watching the bar. (The doc's mercy layer fudges *zones between*
attempts or the *number* on the RNG tier — never the bar you are currently looking at, and
**never a gamble the player opted into**.)

---

## Architecture

### `ACTOR` — the blocking prerequisite
There is no combatant abstraction today: `DoCombatDnD` holds the player in the working
globals and the monster in a `ROOMS(rm)` slot, and nothing is indexed. "Four gnolls" has
nowhere to live, and every mockup feature (initiative order, per-enemy stance, per-enemy
status timers, targeting) needs actors to attach to.

```
TYPE ACTOR
  side, nm, base, alive        ' base = "gnoll" -> art + combat-text lookup
  hp, maxhp, ac, tohit
  melee_nm/die/bonus, ranged_nm/die/bonus, armor_nm
  stance                        ' attacking / guarding / prone
  eff_kind, eff_turns, eff_max, eff_mod
  init                          ' initiative roll
  fuse, fuse_start, fuse_base   ' per-creature wind-up clock (see below)
  atk_type                      ' ONE field, THREE expressions: dodge profile,
END TYPE                        '   screenshake shape, and the dodge verb
DIM SHARED ACT(0 TO 8) AS ACTOR ' 0 = player, 1..4 enemies
```

`atk_type` doing three jobs from one data field is greywood's trick and worth preserving —
it is why the dodge reads as a *decision* rather than a reflex lottery.

### `engine/GAUGE.bas` — vendored composure engine (game-free)
Ported from greywood, adapted to take a **knob struct** instead of reaching for `pHP`/`pSkill`
globals, and to render into a **named layout region** instead of absolute pixels.

Must name no `game/` symbol (`tests/audit-boundary.sh` enforces it). Port list for Phase A:

| From greywood | To | Notes |
|---|---|---|
| `SkillParams` | `GaugeKnobs` struct + a filler | zone widths, sweep speed, jitter, roam, wpRestore |
| `GestureLock%` | `GaugeRun%` | the composure bar; willpower STEADY; low-HP degradation |
| — | `GaugeSample%` | **new**: the sampled twin of the above (principle 1) |
| `DodgeQTE%` | `DodgeRun%` | directional QTE; skill-scaled window; scatter; disappearing options |
| `ResolveDamage&` | `GaugeDamage&` | the shared damage seam both presentations feed |

Deferred to later phases: `ArcheryLock%`, `DeathSave%`, `Impact`/`HitReact`/`CloseEyes`/`BigNum`.

### `engine/LAYOUT.bas` — named screen regions (drafted)
A screen described as **data**: named rectangles in character cells, so drawing code asks for
`enemy3.art` rather than hardcoding coordinates, and the whole screen can be rearranged by
editing a text file. Each region carries its own cell size, because this screen is 8×8 while
the board is 8×16.

This is also what makes the gesture modules placeable: the doc's *"arrange left to right —
STEP 1 → STEP 2 → CRIT — dim module when not in use"* becomes `gesture.step1`, `gesture.step2`,
`gesture.crit` regions.

### Data files (all pack-aware via `DataPath$`)

```
ui-fight-layout.txt   region | col | row | cols | rows | kind | note
gestures.txt          name | modules | attr | skill | note
gauge-tuning.txt      knob | base | per_attr_mod | per_skill | per_depth | per_press
stances.txt           name | tohit_mod | ac_mod | note
health-tiers.txt      name | pct_at_or_below | colour
```

`per_press` is the 1-vs-4 pressure term — **more engaged enemies ⇒ faster sweep, shorter
fuse.** That is what makes a four-enemy round mechanically tenser than a duel rather than
just longer, which was the maintainer's "gestures will be CLUTCH" requirement.

### Resolution tiers — two-thirds already exist
The doc's ladder is auto → digital sim → physical dice. This game **already** has tier 1
(auto-resolve) and tier 3 (**Real Dice**: `opt_realdice` / `opt_dicemath`, where the player
rolls physical dice and types the result). Phase A fills tier 2. `opt_gestures` becomes the
tier-2 toggle rather than a new setting.

---

## Phases

Each phase ends green on `tests/run-tests.sh` and leaves the game playable.

### Phase A — vendor the composure engine  ✅ **the MODEL is done (2026-07-29)**
`engine/GAUGE.bas` + `GAUGEK` in ENGINE.BI. **57 assertions** in `tests/TEST-GAUGE.bas`.

Rather than copy greywood's `GestureLock%` (which interleaves math, drawing and input
polling), the **math was separated into pure steps with no display at all**:

```
GaugeKnobs    actor      -> zone widths / speed / roam / restore
GaugeBegin    seed one attempt (random phase + per-attempt tempo jitter)
GaugeStep     advance ONE frame -> marker p, zone centre zc, ecrit/ehit
GaugeScore    score the CURRENT frame -> zone + quality
GaugeSample   random phase + one Step + Score = the same math, sampled
GaugeSteady   spend a willpower press
GaugeDamage   (stat, zone, quality) -> damage. The shared seam.
GaugeOutOfSweeps / GaugeHpFrac
```

That makes **principle 1 structural, not a promise** — the interactive front-end is a loop
of `Step` + draw + poll + `Score`; auto-resolve is `GaugeSample`. There is only one copy of
the arithmetic, so the two presentations cannot drift.

One subtlety worth keeping: `GaugeSample` draws a uniform **phase**, not a uniform `p`,
because `p = (SIN(phase)+1)/2` — the marker dwells near the bar's ENDS and races through the
CENTRE. A centred zone is genuinely harder to hit by luck, and the sampler inherits that for
free. Sampling `p` uniformly would have quietly made auto-resolve *easier* than playing.

The tests assert the design principles as **properties**, which is the only way they survive
future tuning — including that skill *widens the band* rather than *shifting the odds*.
Verified they bite: making low skill share high skill's widths fails 4 assertions, two of
them the statistical ones ("high skill lands more often than low (30% -> 28%)").

**NOT done in Phase A, deliberately:** `GaugeRun` (the interactive front-end) and `DodgeRun`
(the directional QTE). Both are *drawing and input*, and both need the 8×8 fight screen and
its layout regions, which is Phase B. Porting their pixel code against a screen that does not
exist yet would be guesswork. The model they both sit on is done and tested.

### Phase B — actors + the screen
`ACTOR` array, `ui-fight-layout.txt` authored from the mockup, and a `fightlayout` dev mode
that renders labelled region boxes to a PNG so placement can be iterated against the art
**without running a fight**. Combat still resolves via `GaugeSample` only — no gestures yet.
This is where the screen becomes real and where the art work plugs in.

**B.1 — the screen description: DONE.** `engine/LAYOUT.bas` + `assets/data/default/ui-fight-layout.txt`
(48 named regions) + `dungeon.run fightlayout` + `dungeon.run fightmanifest`, all measured off the
hand-drawn mockup `assets/ansi-art/default/ui-fight.xb` (XBIN 132×100). Numbers that came out of the art:

| what | value |
|---|---|
| screen | **132 × 100** cells on an **8 × 8** cell = **1056 × 800 px**. The board canvas is 132 × 51 @ 8 × 16 = 1056 × **816**, so the fight screen is **exactly as wide and 16 px shorter** — it fits inside the existing canvas, and entering a fight is a **redraw, not a window resize / re-fullscreen**. Same *width* is the load-bearing part: a different width would letterbox horizontally, which is where the four 33-col panels are pitched. The renderer has 16 px (two 8 px rows) spare at the bottom. |
| foe panels | 4 columns on a **33-col pitch** (4 × 33 = exactly 132) |
| **every portrait** | **33 × 25 cells = 264 × 200 px** — player and all four foes are the *same size*, so one portrait is interchangeable between any actor slot |
| structural rules in the art | row 29 (under the portrait band), row 42 (full-width split), col 35 (vertical split of the lower half) |

Three properties worth keeping as the fight gets built:

- **The manifest derives its sizes from the layout file**, it does not restate them. `fightmanifest`
  asks the layout how big `enemy1.art` and `screen` are, so moving a box moves the art-generation
  target with it and art can never be authored to a stale size.
- **ANSI and pixel art are listed as separate entries with a `kind` column**, because their sizes are
  not in the same unit: `ansi` is character cols × rows (plus the cell metric, `@8x8`), `pixel` is the
  region's exact on-screen pixel box — 1:1, so a `.png` blits with no scaling, no letterboxing, and no
  aspect for a generator to guess at. Everything sits under `strategic-combat/`, so
  `grep strategic-combat` selects the whole set.
- **`tests/TEST-LAYOUT.bas` asserts the real shipped layout**, not just the API: every region on-screen,
  all four foe panels identical and evenly pitched, the player portrait equal to a foe's, no two `art`
  regions overlapping, every `kind` known, and every region the code names by string actually present.
  The `fightlayout` lint reports the same things, but only if someone runs it — these run in the gate.

**Still open in Phase B:** the `ACTOR` array and the renderer that draws the layout for real.

### Phase C — the tactical read
Enemy columns with **parallel fuses**, target selection, initiative order, and the dodge
naming its attacker. This is the doc's "strategic layer": triage under time pressure — which
fuse is about to fire, drop the fast one or race the big one. The fuse **drains during
deliberation** (greywood's key pacing fix: run it out and the monster seizes the opening).

### Phase D — gestures live
Wire `GaugeRun` for the player's turn and `DodgeRun` for incoming attacks. Opt-in per the
doc: a plain attack auto-resolves at a safe baseline, and the gesture is a **gamble** with a
higher ceiling and a bounded fail tail. Guard against *dominance* — keep EV close at average
skill so it is a variance choice, not a free upgrade.

### Phase E — status, stances, tiers, juice
Health tiers, stances, per-actor status durations, then the juice port (typed screenshake,
impact flashes, eyes-closing, `BigNum` overlays), then archery and the death-save.

---

## Traps to avoid (collected, each already paid for by someone)

**From the design doc:**
- Frame-to-frame jitter that reads as arbitrary — keep the wander *continuous*, so a miss
  always looks like the player's timing, never the game cheating.
- Oscillation cranked until it is a coin flip.
- Every single hit being a full mini-game — that is what made Judgment Ring drag. The
  opt-in gamble is the fix, and it self-gates better than any designer-side rule.
- Shape/handwriting recognition. Keep it **timing and alignment**.
- Crit-fail cascading into a death spiral. Bound it, telegraph it, make it skill-reducible.

**From this codebase (all cost real debugging):**
- QB64 identifiers are **case-insensitive** — a local named after a shared global silently
  shadows it. `tests/audit-shadow.sh` covers the high-risk set; greywood hit the same class
  with `base` (a reserved word).
- `AND`/`OR` **never short-circuit**, and an `AND` around anything with a side effect (a die
  roll) is a correctness bug, not just a bounds risk.
- A bare `Foo` statement whose SUB is undefined parses as a **label** — it compiles clean and
  silently does nothing. Never write a hook call in `NAME: statement` position.
- The save stream is **positional**. Any new persisted state needs a version gate plus a
  `savetest` assertion, or the whole tail of the file shifts.

## Open, deliberately deferred

- Positioning: hex/oct grid, facing, AP, threatened squares. (Threatened-squares-without-a-grid
  is a cheap middle option if GUARD needs more weight than an AC bonus.)
- A real per-weapon **skill** system (blade/bow/arcane/shield) replacing `char_level`.
- Mercy/brutal regimes and a spendable Fate pool — the doc specifies these well; they want
  the core tuned **without** the net first, per its own engineering-discipline note.
- Archery, the death-save, and the full juice layer (Phase E and beyond).
- Multi-player party combat (decision 2 chose active-seat-only).
