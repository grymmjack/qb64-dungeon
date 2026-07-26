# DUNGEON! — Rules Reference (for this project)

This is our own plain-text summary of the **TSR _Dungeon!_ board game** (David R. Megarry,
1975; revised 1980/81), written to document exactly which rules this game's **Oldschool mode**
(`opt_oldschool`) reproduces and where it deviates. It is a mechanics reference in our own
words — not a transcription. Faithful OCR transcriptions of the physical rulebooks live in
[`manuals/`](manuals/) (`Game Manual.txt`, `Introductory Game.txt`) — checked against those.

Every rule below is tagged **→ in this game** with the function / setting that implements it,
so the doc doubles as a map between the board game and the code.

## Sources
- Official rulebook scan (© 1975/1980/1981 TSR), read from the page images —
  <https://obj.vassalengine.org/images/2/26/Dungeon_Rules.pdf>
- Wikipedia, "Dungeon!" (editions, class lists) — <https://en.wikipedia.org/wiki/Dungeon!>
- magisterrex, box contents & card counts (1981 printing) —
  <https://magisterrex.wordpress.com/2011/04/11/whats-in-that-game-box-dungeon-fantasy-boardgame/>
- Skeleton Code Machine, design history — <https://www.skeletoncodemachine.com/p/tsr-dungeon>
- EN World, review of the 2012 WotC edition — <https://www.enworld.org/threads/review-of-dungeon-fantasy-board-game-by-wizards-of-the-coast.661531/>

---

## 1. Choosing an adventurer — pick a class, no stats

Players **pick a class** (a coloured pawn). There is **no attribute generation** — no STR/INT/
DEX, nothing to roll. Each class only differs in its fighting strength, its gold-to-win, and one
special ability.

| Class | Gold to win | Fighting | Special ability |
|---|---|---|---|
| **Elf** | 10,000 | weakest | finds secret doors on a d6 of **1–4** (others 1–2) |
| **Hero** | 10,000 | modest | the baseline all-rounder |
| **Superhero** | 20,000 | strongest | brute force against the deep levels |
| **Wizard** | 30,000 | good fighter | casts **spells**; **cannot use a Magic Sword** |

The rulebook calls wizards "good fighters, but not the best" — on many cards their kill number
equals the Superhero's (e.g. the Troll: Superhero 8, Wizard 8, Hero 10), so they are **not** weak
in melee; their real edge is spells. The **Introductory Game** uses only Elf and Hero (levels
1–4); the full game adds Superhero and Wizard.

**→ in this game:** you pick a class in `SelectClass`; Oldschool mode routes to
`RollCharacterClassic` (no dice), which only names the champion. Class data lives in
`CLASSES()` (`include/SECTOR.bas`) with the exact gold goals above. The Elf's secret-door edge
is `secret_bonus`; the Wizard's no-sword rule is enforced in `ClaimTreasure`.

## 2. Moving — up to 5 spaces, your choice, no movement die

On your turn you move **1, 2, 3, 4, or 5 spaces — you choose.** **The dice are _not_ used to set
how far you move.** Corridors, stairs, rooms, and chambers each count as one space; doors and
secret doors are free (they don't count). You **stop** when you step into an uncleared room or
chamber (you must fight the monster there). You may move 0 to stay and fight or search again.
At the very start of the game the dice are rolled once, only to decide **turn order** (highest
first, then clockwise).

**→ in this game:** the faithful rule is a SETTINGS option, **Move Style → "up to 5 (Dungeon!)"**
(`opt_movedice = FALSE`). `StartTurnMove` gives each turn `MOVE_MAX` (5) steps; you move up to
them and press `[SPACE]` to end the turn early. Stepping into a monster room ends the turn as in
the board game. The alternative **"roll 1d6"** style is a common house variant, kept as the
default. (Turn order isn't modelled — solo/hot-seat play just cycles seats.)

## 3. Fighting — one 2d6 roll vs. the monster's per-class number

There are **no hit points and no armour class.** Combat is a single binary roll:

1. You may only fight in rooms/chambers (never the Main Gallery). Room monsters guard treasure;
   chamber monsters guard none.
2. The monster card lists a target number **for each class**.
3. **Roll 2d6. If you meet or beat your class's number, you kill the monster** and (in a room)
   take its treasure.
4. A **dash "—"** for your class means you cannot kill it without a **Magic Sword** (or, for a
   Wizard, the right spell).
5. You strike first; the monster only hits back if you **miss** the kill roll.

**→ in this game:** `DoCombat` (Oldschool). The per-class number is `MON_N(level, slot, class)`;
a Magic Sword lowers the number you need (`target = need - item_sword`); "—" monsters are the
`unbeatable` case.

## 4. When you miss — the Monster Attack Table (2d6)

Miss the kill roll and the monster strikes back — roll 2d6 on the rulebook's **Monster Attack
Table** (verbatim from `manuals/Game Manual.txt`):

| 2d6 | Result |
|---|---|
| **2** | **Adventurer killed!** Drop **all** treasures. (May re-enter the game as a weaker class.) |
| **3** | **Wounded!** Drop **all** treasures; back to Start; lose next turn. |
| **4–5** | Retreat **two** spaces; drop **one** treasure; lose next turn. |
| **6** | Retreat **one** space; drop **one** treasure. |
| **7** | No effect; next turn may leave the space or attack. |
| **8** | Retreat **one** space; drop **one** treasure. |
| **9–10** | Retreat **two** spaces; drop **one** treasure; lose next turn. |
| **11** | No effect; next turn may leave the space or attack. |
| **12** | **Wounded!** Drop **all** treasures; back to Start; lose next turn. |

The table is symmetric around 7 **except** that a **2 kills** while a **12 only wounds**. "Killed"
removes the pawn (the player to your left blindly returns two of your treasures to the piles; you
may re-enter next turn at Start as a **weaker** class — a dead Wizard comes back Superhero/Hero/Elf,
never Wizard). "Wounded" sends you to Start and costs **all** your treasure, but not the pawn. No
result ever ends the game outright.

**→ in this game:** `MonsterAttack` uses a **simplified, gold-based adaptation** — the game tracks
one gold total, not individual treasure cards:

| 2d6 | Game result |
|---|---|
| 2 | Killed — drop all gold + items, back to START (revive; not eliminated) |
| 3 | Serious wound — drop **half** your gold, back to START |
| 4–6 | Light wound — drop 1000 gold, retreat, lose the turn |
| 7–8 | Stunned — drop 500 gold |
| 9–12 | Missed — no effect |

**Fidelity gap:** the game is gentler than the printed table — a **12** is harmless here but a
catastrophic *Wounded* in the real game; a **3** costs half your gold instead of all; and **9–11**
never wound. Making Oldschool combat honour the printed 9-outcome table exactly is a one-function
change to `MonsterAttack`, kept as a future faithfulness pass.

## 5. Treasure & magic items

Kill a **room** monster and draw one treasure card from that level's pile (plus grab any
treasures other players dropped there). Most cards are just a **gold value**. The magic cards:

- **Magic Sword** — adds to your kill rolls and can slay a "—" monster (a +1 sword kills a "—"
  monster on a 12, a +2 sword on 11+). It's **+1 or +2**, set by a 2d6 roll when found (deeper =
  likelier +2: 1st level 12=+2, 6th level 7+=+2; the Intro Game is +1 only). **A player uses only
  one at a time.** Wizards can't use it at all.
- **Secret Door Card** — you find every secret door automatically (no roll).
- **ESP Medallion** — look at a room's monster before you enter.
- **Crystal Ball** — look into any room from afar (its monster and treasure).
- **Wizard Spell Cards** (Expert, Wizard only) — Fire Ball, Lightning Bolt, Teleport. Some
  monsters are immune to a given element.

The deck holds several Magic Swords and a couple each of the utility cards; the printed rules
never make an item unique-per-player — they only restrict **use** ("one Magic Sword at a time").
Holding a redundant second ESP/Crystal/Secret-Door card does nothing, since their effect is
binary.

**→ in this game:** `ClaimTreasure`. Oldschool keeps a **single copy** of each magic item (a
house simplification the player asked for): a duplicate is sold for gold, the Magic Sword is a
flat +1 (no `+1…+5` upgrading), and there is **no Armor Class**, so Shield/Armor cards (a D&D-
mode feature) are sold as gold. ESP Medallion, Crystal Ball, and Secret Door Card are the
faithful utilities; Wizard spells are not yet implemented.

## 6. Winning

Return to the **Start** chamber holding at least your class's gold total. (This game adds a
**Level Key** you must also carry — a house rule; see below.)

**→ in this game:** the win check is `gold >= target_gold AND has_key` back at START.

## 7. What _Dungeon!_ does **not** have

No hit points, no armour class, no attributes, no experience or levels, no healing potions. A
fight is one roll; a loss costs treasure and position, never health. Oldschool mode honours this
by disabling all of those (they belong to this game's separate **D&D mode**, `opt_oldschool =
FALSE`).

---

## This game's deliberate house rules (deviations, on purpose)

- **9 levels** instead of the classic 6 (deeper = tougher/richer), with named sectors.
- **A Level Key** hidden on a deep level, required to win (adds a fetch objective).
- **A D&D mode** (`opt_oldschool = FALSE`) that layers on hit points, armour class, a d20
  to-hit system, rolled attributes, XP/levels, healing potions, and curio chests — none of
  which are _Dungeon!_. That mode is the game's own thing; Oldschool mode is the faithful one.
- **Move Style** is a setting so the player can choose the faithful "up to 5" or the popular
  roll-1d6 house variant.

## Edition notes
- **1975 / 1980 / 1981 (classic):** Elf, Hero, Superhero, Wizard; the rules above.
- **1989 "The New Dungeon!":** six classes (Warrior, Elf, Dwarf, Wizard, Paladin, Thief);
  per-class gold totals unverified.
- **2012 (Wizards of the Coast):** four classes renamed to D&D archetypes (Rogue, Cleric,
  Fighter, Wizard) with the same gold totals and the same 2d6/no-HP combat.
