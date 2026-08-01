# Day notes — 2026-08-01

Companion to `NIGHT-NOTES.md`. `plans/PLANS.todo` stays clean; the thinking lives here.

Rick re-tagged PLANS.todo with **@critical** (next, top-down) / **@high** (after critical) /
**@low** (later). This is my read of what naturally groups, and what I think is mis-ordered.

**Inventory:** 8 @critical · 17 @high · 4 @low.

---

## Decisions (asked and answered, 26-08-01)

| question | Rick's call |
|---|---|
| Generator batching | **Batch ALL manifest-adding work first**, then one farm run, then pure code. @low art frames jump ahead of @high code — accepted, because generating twice is the bigger cost. |
| Rest systems vs `[R]`est | **Two separate features.** The entrance rest is its own scripted thing; `[R]` in the dungeon is unrelated. Do *not* factor them into one mechanic. |
| Bestiary discovery | **Its own file** — `gameplay-data-saves/dungeon-bestiary.dat`. Independent of saves and of the hall of fame, so wiping a run never loses it. |
| +1 stat on level-up | **Re-derive immediately, except CON does not backfill HP.** A CON bump improves future level-up rolls; it does not retroactively grant max HP for levels already gained. |

---

## The one ordering change I would argue for

Rick is **holding the AI asset generators** until this work is done. That makes one grouping
more valuable than any other: **everything that adds a MANIFEST ENTRY should be finished
first, as one batch, so the generators run once.**

Right now that work is scattered across @critical, @high and @low. Generating twice costs a
full farm pass and leaves half the game with placeholder art in between.

**Group 1 — asset-generating (do first, then generate):**

**CORRECTED after checking the manifest against disk.** Two of the biggest-looking @critical
"art" items turn out to need **no generation at all** — the assets already exist and the gap is
code. That shrinks the batch a lot and moves work into the code phase:

| item | tag | verdict |
|---|---|---|
| **ANSI art where only pixel art exists** | @critical | **NOT an asset item.** The manifest is already at 84 pixel + 84 ansi in *parity*, and `imagemanifest audit` reports **0 missing** — every `.ans` is on disk. `opt_artstyle` (0 = ANSI only / 1 = Pixel / 2 = Hybrid) exists too. The gap is that **every draw path calls `DrawSpriteFit%`, which only loads a PNG** — so `opt_artstyle = 0` renders *nothing*. This is a rendering feature: load the `.ans` through `ANSI_Print` into an image and blit it. **No generation needed.** |
| **Player portrait in the combat bar** | @critical | **NOT an asset item.** `classes/{hero,elf,superhero,wizard}` already exist in **both** `.png` and `.ans`. This is layout + placement code. |
| **Death screen (gravestone)** | @high | Mostly not — `markers/gravestone` already exists in both forms. New work is the *animation*, which is code. |
| YOU DIED / YOU WIN screen art | @critical | **GENUINELY NEW** — 0 entries today. |
| Rest image | @critical | **GENUINELY NEW.** |
| ANSI 9-grid frames; item display frames | @low | **GENUINELY NEW** — 0 `frame` entries today. |
| Rest narration + SFX | @critical | **GENUINELY NEW** — 1 narration line, ~4 sfx. |
| More SOUND / SMELL flavor lines | — | **GENUINELY NEW** narration, and must be written *before* the run. |
| White level door | Doors | **hand-painted BOARD art**, not generated. |
| Board legend: `$` recoverable, fallen-body | Refinement-2 | **hand-painted BOARD art**, not generated. |

So the real generation batch is **five new subjects** (two end screens, a rest image, a frame
set, item frames), a handful of SFX, and some narration — not the ~170 entries it looked like.

The board art is hand-painted and gates `roomlint` / `boardsplit` re-verification, so it wants
doing before a generation run rather than after.

---

## The other natural groups

### Group 2 — "every ability score has a job"

- **Explain each stat in the character creator** @critical
- **+1 stat point on level up (cap 18)** @critical
- **Luck re-rolls from CHA** @critical
- **Endure-damage gesture from CON** @high
- **Flourishes from DEX** @high
- Initiative from character level / 2

These are one arc, and the ordering inside it matters: **the side panel is the documentation
of the other five.** Writing it before they exist means writing it twice. I would do the
mechanics first and the panel last, even though the panel is the thing you can see.

### Group 3 — rest & the entrance (currently two items that are one feature)

- **Rest systems** @critical — scrawling text, image, narration, fade-to-white, SFX, and
  "Return to Start Heals should be a game option ON/OFF"
- **[R]est option in the dungeon** @high — 1 HP per press, chance of an encounter

Both are "spend time to heal, risk being found" — but **Rick's call is that they stay two
separate features**, so they are NOT being factored into one mechanic. The entrance rest is a
scripted set-piece tied to the start chamber; `[R]` is an ordinary in-dungeon action with its
own risk. Kept in the same group here only because they are adjacent in feel, not in code.

### Group 4 — gesture extensions (all touch `GAUGE.bas`)

- Endure damage on max damage (CON) @high
- Real-dice mode: ranges under a static bar @high
- Max damage → gesture to confirm a crit @high
- Flourishes from DEX @high

Four features, one file, one set of knobs. Doing them together means calibrating the feel once.

### Group 5 — status effects (one mechanic, five callers)

- **Monster elemental effects** @high — poison / blight / curse / acid, each a save vs a stat
- **Door traps** @high — swamp gas (poison), arrow (DEX), ambush
- Existing curio traps already do save-vs-stat + timed effect

All three are the same shape: *roll a save against an ability, apply a timed effect*. The
existing `TRAPS()` / `SpringTrap` machinery already does it. Building the monster elementals
first gives door traps almost for free.

### Group 6 — dice presentation (all one subsystem)

- D4 angle easier to read @high
- Roll style (hold-space to shake) @high
- Box shake @high

### Group 7 — combat feedback

- Blood overlay on monsters, scaling to death @high (undead use black)
- Close-call banner after a long, nearly-fatal fight @high
- Monsters lunge on attack @low
- Combat UI shakes near death @low

### Group 8 — measurement

- `balancedump` @high
- Stats box (per game, in summary + stats log) @high

---

## Things I noticed while reading

- **Bestiary discovery** (@critical) needs *cross-run* persistence — "ever found during any
  game run". Nothing in the save covers that today. Decided: **its own file.**
- **Door traps** (@high) sits underneath the door-noise item I finished last night, so that
  block is half done — the noise escalates, the trap does not exist yet.
- **`eventsaudit` already has an answer waiting**: SOUND is 6% in `monster_events` and SMELL is
  ~0% in both. If more lines are written, they should be written *before* the narration
  generation run, not after.
- **Two map items are quietly large**: "level 4 cannot reach level 9" and "stairs lead only to
  the next/previous level" both mean editing the board art and re-verifying with `roomlint` /
  `fogdump` / `sectorauto`. They are untagged right now.


---

## Design intent captured while working (26-08-01)

**The Magic Bow is the first MISSILE weapon, not a stat trinket.** Rick: *"I have plans to add
more to the engine/game where it has a top-down perspective too, and missile weapons will
complement melee weapons -- we are just starting small to get the engine solid, and play test."*

So the bow is now **Elf-only** (`IsElf%`, mirroring the Wizard/Magic-Sword refusal): any other
class sells it on pickup, and the curio no longer *offers* one to a class that cannot use it —
offering a reward and then having the player sell it reads as the game wasting your time.

Today it is deliberately thin: +2 to-hit, plus the SHOOT action in tactical combat. The comment
at that bonus now says so, because the risk was a future reader treating "+2 to-hit" as the
whole idea and building around it. **That line is the seam to widen when the top-down
perspective lands — not a special case to work around.**

Consequences already accepted:
- `items/elven-blade` **stays** — the Elf's melee weapon is unchanged; the bow is additional.
- `WeaponSprite$` deliberately shows the MELEE weapon in the combat bar, because [SPACE] attack
  is a melee swing. When missiles become a real mode, the panel will need to show which one is
  in hand rather than assuming.


---

## The stat panel's "(soon)" lines ARE the @high checklist (Rick, 26-08-01)

*"we will build the unbuilt stuff mentioned in character editor after criticals with all @high"*

`assets/data/<pack>/stats.txt` now doubles as a work list: every row flagged `0` is a mechanic
the character creator advertises as coming. Several already have @high entries in PLANS.todo, so
they are the same work seen from two directions:

| stat.txt line (live=0) | PLANS item |
|---|---|
| DEX — flourishes: spend timing for extra damage | *Add Flourishes based on DEX mechanic* @high |
| DEX — accuracy with missile weapons | the missile-weapon arc (see the Magic Bow note above) |
| CON — endure a maximum-damage blow for half | *gesture based "endure damage"* @high |
| CON — resistance to poison, acid, shock | *Give monsters appropriate elemental effects* @high |
| INT — spells carried / recall / magic flourishes | not yet an entry — needs one |
| WIS — sight range, finding hidden things, spell resist | not yet an entry — needs one |
| CHA — barter, fate skew, reaction saves | not yet an entry — needs one |
| STR — heavier armour and melee weapons | not yet an entry — needs one |

**Flipping the flag is the last step of each feature**, and costs nothing but the edit. Four of
the eight groups have no PLANS entry yet; worth adding when the @high pass starts so nothing in
the creator stays permanently "(soon)".
