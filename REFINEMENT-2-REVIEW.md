# Refinement-2 — the big playtest batch 🎲🗝️

Everything here is on branch **`refinement-1`** (continuing from the overnight
`REFINEMENT-1-REVIEW.md`). Build from the repo root and press **F5**, or:

```
qb64pe -w -x dungeon.bas -o dungeon.run   # success = the "Output:" line
./dungeon.run
```

Your `dungeon-settings.dat` and `dungeon-lords.dat` are untouched (backed up before
every risky step). Two new git-ignored files may appear as you play:
`dungeon-stats.csv` (combat log) and `dungeon-save.dat` (your saved game).

> **Verified** = built + logic traced field-by-field. I could not screenshot the
> running game this session without commandeering your fullscreen while you were
> playing, so the live-visual confirmations are yours to make — flagged below.

---

## 🐛 The bug you hit — fixed first
**Monsters on walls / combat never triggering** (`798e7d3`). Room markers were
placed at each room's *bounding-box center*, which for an L-shaped block lands on
a black wall — so the `§` sat on an unreachable tile and that room's fight never
fired. Markers now snap to the nearest real floor cell. This also underpins the
"monsters off labels" work below.

## ⚔️ Combat & progression
- **Healing potions** (`77e29bb`): treasure hoards have a 50% chance to also hide a
  **Large potion (1d8)**; clearing a whole floor grants a **Small (1d4)** always + a
  Large 30% of the time. **`[H]`** quaffs one (in a fight = free action; asks which
  if you hold both). Shown on the combat panel, the `[C]` sheet, and the HUD.
- **XP + D&D leveling** (`77e29bb`): every kill grants XP (deeper = more, bosses
  double). Clearing a floor **levels you up** — +1 level and a rolled hit die (+CON)
  to max HP, fully rested. Level + XP show on the HUD and sheet.
- **Item progression** (`77e29bb`): swords and armor/shields now **always log to your
  treasures list** and each find is **one step stronger** than the last (a duplicate
  is reforged up), capped at +5 sword / +6 AC. All magic items appear in the log.
- **Crit / fumble engine** (`79b989f`, data-driven `include/EFFECTS.bas`): a critical
  hit plays a cinematic — a random smash-saying (*"AARGH! You hew into the GOBLIN
  with your +2 blade…"*), a dramatic `. . . .` pause, then a payoff (usually
  *"overwhelming courage and pride: heal 1d4"*, sometimes an extra blow). **Fumbles**
  make you hurt yourself / drop your grip / spill gold. **Monster natural-1** = it
  wounds itself or wastes its turn (can even kill itself). Toggle: **Crits & Fumbles**.
- Death now **waits for a keypress** before the blood transition; the **ESP Medallion**
  now **foresees the monster beyond a door** and lets you `[Y]` enter / `[N]` back off.

## 🎁 Curio chests + traps (first curio event) (`d27203f`, `include/CURIO.bas`)
After a room fight, 20% chance a **chest** appears — open for depth-scaled gold (and
sometimes a potion). 25% are **trapped**, each with a **saving throw** (50% base
±10% per relevant ability modifier):
- **Poison darts** — save vs poison (CON); fail = **-1 HP/turn for 1d4 turns**.
- **Bomb** — dodge (DEX); fail = **1d6 damage**, 25% to also catch **fire** (1d4 DoT).
- **Frost bomb** — save vs frost (CON); solo = 1d4 cold damage, **multiplayer = frozen
  in place 1d4 turns**.
- **Magic siren** — save vs magic (WIS); fail = **1d4 turns of swarming wanderers**
  (+20% encounter chance + a per-step spawn roll).

Status effects tick per step and show live in the HUD (`{PSN2}` `{FIRE1}` `{FRZ3}`
`{SIREN2}`).

## 🗺️ Danger, safety & the board
- **Hardcore idle mode** (`75f8a5d`): standing still only passes time (and draws
  wanderers) with the new **"Time Passes When Idle: hardcore / casual"** setting.
  Casual (default) = idling is perfectly safe.
- **Cleared levels are safe** (`75f8a5d`) and **secret-door rooms become sanctuaries**
  once their monster is slain (`98bca88`) — no wandering ambushes there.
- **Lean wander loot** (`75f8a5d`): wandering monsters carry scraps, so you can't farm
  ambushes to a quick win. The idle encounter is now a **30% roll** once the meter fills.
- **Monsters hidden until you reach them** (`f20b732`): no more board-wide spoiler of
  every lair — a room's monster only draws once you've **entered** it (and stays off
  the level labels now). **Per-player DEATHS** tally in the HUD.
- **Loot recovery** (`98bca88`, setting, default ON in D&D): death **leaves your gold +
  magic in the room** (green `$` marker) — trek back, re-clear it, and **reclaim your
  spoils for revenge**. The death banner names the level so you know where to return.

## 🧙 Character creation (`b28fe16`)
- You **press a key to roll each ability** yourself, or **`[A]`** to auto-roll the rest.
- The screen shows the **class up front**: win-gold goal, blurb, special ability, and
  its bases (hit die / to-hit / damage / AC).
- Every hero gets a **humorous D&D name** (*Bort the Unlucky*, *Grimble Facepunch*,
  *Sir Reginald the Mostly Dead*). **`[N]`** rolls a new one anytime.

## 💾 Save / load (`8f18a1f`, `include/SAVEGAME.bas`)
**`[G]`** saves your run (solo). Next time you enter the dungeon you're offered
**`[C]` CONTINUE / `[N]` NEW**. The dungeon is now seed-reproducible, so the save
stores the seed + your deltas (stats, items, position, per-room state, revealed
doors, chronicle, status). Winning clears the save.

## 📊 Combat stats CSV (`c479080`, `include/STATS.bas`)
Every fight appends a row to **`dungeon-stats.csv`** — monster, level, room, outcome,
rounds, **damage dealt vs taken**, HP + gold after, boss/wandering flags. Open it in a
spreadsheet to tune the difficulty curve.

## 🎮 New keys & settings
- **Keys:** `[H]` potion · `[P]` pause (bio break) · `[G]` save · `[T]` teleport ·
  `[V]` scry · `[C]` sheet · `[F]` search · `[?]` full list.
- **Settings** (now a single-column list): Time Passes When Idle · Crits & Fumbles ·
  Loot Recovery — all persisted.

---

## ⚠️ Worth your eyes / decisions I made
- **Save/load is build-verified but not live-tested** — I matched the write/read order
  field by field, but the first real test should be a **save → quit → CONTINUE** cycle.
  It's **single-player** (hot-seat `PLAYERS()` state isn't serialized yet), and `[G]`
  is disabled in multiplayer.
- **Dice rotation — DONE** (`6543415`). The polyhedra now **spin as they tumble** and
  ease upright on settle. I verified the `_MAPTRIANGLE` technique in isolation first
  (`scratchpads/TEST-DICE-ROT.bas` → a PNG of a d20 at 0/20/45/70/90°) so it never
  touched your fullscreen session. Give it a roll and tell me if you want it faster/
  slower or a tighter spin.
- **Trap/chest/potion odds & saving-throw math** are my best-judgment first pass
  (all constants at the top of `DUNGEON.BI` — easy to tune).
- **The board legend is baked ANSI art** — if you want a `$ = your dropped loot` entry
  added to it, that's a quick edit on your side (you offered!). The `$` marker itself
  already draws.

## Commits this session (newest first)
```
8f18a1f  Save/load (seed-reproduced) + CONTINUE
98bca88  Loot recovery + sanctuary rooms + settings compaction
b28fe16  Character creation: interactive roll-up, class info, random names
c479080  Combat stats CSV log
d27203f  Curio chests + traps + status effects
79b989f  Crit/fumble effects engine
f20b732  Placement polish: hide-until-entered, off-labels, deaths HUD
77e29bb  Potions + XP/leveling + item progression + ESP + pause
798e7d3  FIX monster-on-wall / combat-never-fires
75f8a5d  Danger tuning + Hardcore/Crits toggles
```

Have a blast — and tell me what breaks. — Claude
