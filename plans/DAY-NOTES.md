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

| item | tag | adds |
|---|---|---|
| YOU DIED / YOU WIN screen art | @critical | pixel + ansi |
| Player portrait in the combat bar | @critical | class portraits (new size?) |
| ANSI art where only pixel art exists | @critical | ~168 ansi entries |
| Rest systems → rest image | @critical | pixel + ansi |
| Rest systems → narration + SFX | @critical | 1 narration, ~4 sfx |
| Death screen (gravestone) | @high | art + possibly animation frames |
| Stats box | @high | maybe a frame |
| ANSI 9-grid boxes; item display frames | @low | ansi frames |
| White level door | Doors | **board art** (hand-painted, not generated) |
| Board legend: `$` recoverable, fallen-body | Refinement-2 | **board art** |
| More SOUND / SMELL flavor lines (from `eventsaudit`) | — | narration |

Two of those are **hand-painted board art**, not generator output — the white door and the
legend. Those gate `roomlint`/`boardsplit` re-verification, so they want doing before a
generation run rather than after.

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
