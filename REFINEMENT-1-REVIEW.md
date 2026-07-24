# Refinement-1 — what's ready to check out ☕🎄

Everything below is on branch **`refinement-1`** (pushed). Build from the repo root
and press **F5** in VS Code, or:

```
qb64pe -w -x dungeon.bas -o dungeon.run   # look for the "Output:" line = success
./dungeon.run
```

Your `dungeon-settings.dat` and `dungeon-lords.dat` were preserved (backed up before every
risky step). Your `GJ` lord is still there.

> **Verified** = I saw it on screen this session. **Build-verified** = compiles + logic
> traced, but I couldn't screenshot it (mostly because blind auto-navigation can't reliably
> walk into a monster room — the safe MAIN GALLERY has no monsters).

---

## The big new stuff

### 1. You can finally SEE the board  ✅ Verified
- Every room now shows its monster as a **`§`** glyph (red-on-cyan, matching the legend).
- The player is drawn as their **number** (`1`, white-on-blue) instead of a blank square;
  hot-seat rivals show their own number on their colour.
- A green **`$`** marks a fallen rival's recoverable loot (multiplayer).
- **Field-of-View aware:** FOV off (your default) → all monsters show so you can scout and
  spot wandering spawns; FOV on → a room only reveals its monster once you've explored it.

### 2. The Level Key is no longer a level-1 gimme  ✅ Verified (screens) / logic
- The key is now the treasure of **one random room on a deep level (2–9, never the boss)**.
  You get it by **clearing that room**. No more winning a level-1 lap.
- The descent narration + `[C]` sheet hint the **level**; the **Crystal Ball** (`[V]`) now
  pinpoints the exact room — *"the LEVEL KEY is guarded by the GIANT RATS on the 5th level."*
  That's the Crystal Ball finally earning its keep.
- Secret doors no longer hand out the key — they just open passages now.

### 3. Lingering has consequences (wandering monsters + omens)  ✅ Verified live
- Hanging about — repeated **`[F]` searches** or ~10s of **standing idle** — raises a hidden
  danger meter. The first two ticks flash an **atmospheric omen** (*"You hear faint scuffling
  in the dark…"*, *"Red eyes glint at the edge of your torchlight…"* — two escalating pools,
  ~16 lines). The **third** sends a **wandering monster of the current level** after you.
- **Moving to a new cell resets the meter** — exploring is safe, only loitering is punished.
- Wanderers travel light: half-treasure gold, no cards, no key, and never ambush at the entrance.

### 4. Legendary Lords — full chronicles  ✅ Verified
- The hall of fame is **navigable** (`W/S`), sorted by gold, with a **DEEPEST** column.
- `[ENTER]` opens a champion's **chronicle**: ability scores, deepest level reached, and a
  **1st→9th table of kills + gold per level**. (Old `GJ`-style records still load as "elder
  record / --".)
- Saved in a new v2 record; the file read was hardened (`_READFILE$`) against a QB64 EOF bug.

### 5. Bigger magic-item deck  ✅ Build-verified
Grew from 5 special cards to **10**, seeded across the level pools (richer + rarer with depth):
- **Shield** (+2 AC), **Magic Armor** (+3 AC) — best-worn wins.
- **Magic Bow** (+2 to-hit).
- **Elf Boots** (+2 to the movement roll, boardgame mode).
- **Teleport Scroll** — press **`[T]`** to whisk back to START (heals you; consumable).
- Plus the existing Magic Sword / Secret Door Card / ESP Medallion / Crystal Ball.
- The `[C]` sheet lists them and shows your **effective** AC / To-Hit; `[T]` is on the `[?]` screen.

### 6. Dice that actually roll  ✅ Verified
- Dice now **fall, bounce off the walls/floor with inertia + damping**, flashing faces as they
  tumble, then **ease into their row** on the final values. Both the polyhedral font dice and
  the pip dice; paced by your **Dice Speed** setting.

---

## Smaller fixes from your play session (earlier in the branch)  ✅ Verified live in combat

A wandering GOBLINS fight confirmed the whole combat stack on screen at once — the
combat panel + HP bars, the to-hit roll captioned `-= to hit the GOBLINS =-`, the die
settling on 6, and the modifier line `6 + 2 = 8` (Hero now +2 to-hit after the balance pass).

- **Combat HP bar drains as damage lands** (it used to look like the monster was still alive at 1 HP when you'd killed it).
- **Dice box shows the modifier maths** — `5 + 3 = 8` for damage, `6 + 2 = 8` for to-hit.
- **Character sheet spells out the bonuses** — `To-Hit +5 = +2 class +3 STR`, etc.
- **Combat Speed setting** (Slow/Normal/Fast/Wait-for-key) so a held key can't blow past results.
- **Defaults match your config** (D&D, 4d6-drop, Sapphire, slow dice + combat, smoothing on).

## Balance nudge (best-judgment)

- **Class base to-hit halved** (Hero 4→2, Elf 3→1, Superhero 6→3, Wizard 5→2). Your `+7` was
  `+4 class +3 STR`; a STR-16 Hero now sits at `+5`. It's still *exactly* class + attribute —
  just a less inflated class base. Combined with the deep-level key, fights should bite now.
  **Easy to revert or re-tune** in `include/SECTOR.bas` (InitClasses) if it swings too far.

---

## Things worth your eyes / decisions I made

- **Item drop frequencies are my best guess**, not a verified count against the DUNGEON! manual
  (there's no manual scan in the repo). The deck + odds live in `InitMonsterTables` /
  `SetItem` — easy to retune once you have the real card counts. Flagged in code + `PLANS.todo`.
- **Wandering-monster tuning**: threshold = 3 lingering ticks; idle tick = ~10s; omen flash = 1.7s.
  All one-liners in `dungeon.bas` (`LoiterTick` / `WanderEncounter` / the idle handler).
- **Per-level Lords tracking is single-player-exact**; hot-seat shares the working globals, so
  multiplayer chronicles can blur across champions. Noted for later if MP records matter.
- **Elf Boots** only help in **boardgame** movement (free-move has no step limit) — by design.
- The **DPoly dice fonts** are still of **unverified licence** (`assets/fonts/dpoly/README.md`).

## Deferred (captured in `PLANS.todo`, not built)

- Nothing from tonight's list is outstanding — all six items shipped. Longer-term roadmap
  (engine extraction, chamber/LORD events, the deep tactical-combat screen from your mockup)
  is still in `PLANS.todo`.

---

## Commits (newest first)

```
1b733aa  Balance: halve class base to-hit so early combat isn't a walkover
36a7520  Dice physics: dice fall, bounce, and tumble into the row
2155333  Legendary Lords overhaul: per-level chronicle + selectable character sheets
d009148  Expand the magic-item deck: Shield, Armor, Bow, Elf Boots, Teleport
e67f818  Draw board entities: monsters (§), player-as-number, loot ($) — FOV-aware
1d65cb5  Level Key hidden in a random deep room; defaults match player's config
f51c39b  Wandering monsters + atmospheric omens from lingering
```
(plus the earlier session fixes: HP-bar drain, modifier maths, derivation line, Combat Speed.)

No PR opened — `refinement-1` is all yours to review and merge when you're happy.

Sleep well — this was a joy to build. — Claude
