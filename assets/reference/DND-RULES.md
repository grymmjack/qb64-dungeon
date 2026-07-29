# D&D Mode — Rules (Newschool)

This is the game's **own** dungeon-crawl mode (`opt_oldschool = FALSE`) — a D&D-flavoured
layer that the board game does *not* have: rolled attributes, hit points, armour class, a
d20 to-hit system, multi-round combat, healing potions, curios and traps. If you want the
faithful 1975 board-game rules instead, switch **Oldschool** on in SETTINGS (those rules
are the separate *Rules of the Dungeon* reference).

## 1. Your character

You pick a **class** and roll six abilities — **STR, INT, WIS, DEX, CON, CHA** — then the
game derives your combat stats from them.

| Class | Gold to win | Hit die | To-hit base | Damage | AC base | Attacks with |
|---|---|---|---|---|---|---|
| Hero | 10,000 | d10 | +2 | d8 | 15 | STR |
| Elf | 10,000 | d8 | +1 | d6 | 13 | STR |
| Superhero | 20,000 | d12 | +3 | d10 | 17 | STR |
| Wizard | 30,000 | d6 | +2 | d10 | 12 | INT |

**Ability modifier** = `(score - 10) / 2`, rounded down — it steps every **2** points:

| Score | 3 | 4–5 | 6–7 | 8–9 | 10–11 | 12–13 | 14–15 | 16–17 | 18 |
|---|---|---|---|---|---|---|---|---|---|
| Modifier | -4 | -3 | -2 | -1 | +0 | +1 | +2 | +3 | +4 |

**Derived stats:**
- **HP** = three hit dice + **3 x your CON modifier** (one CON bonus per hit die). So CON 18 (+4) → **+12 HP**.
- **AC** = class base **+ DEX modifier** (higher AC = harder to hit).
- **To-hit** = class base **+ STR** (Wizard: **+ INT**).
- **Damage** = your class die **+ STR** (Wizard: **+ INT**).

**Rolling** is 3d6 per ability, or **4d6 drop-lowest** with SETTINGS → *Stat Roll*. With
SETTINGS → *Flexible Stats* you can also **Assign** the rolled scores where you want, or
**Point-buy** them (spend a pool up from 3, max 18).

## 2. Combat — multi-round d20

Step onto a room's monster and a fight begins. Each round:

1. **You attack:** roll **d20 + to-hit vs the monster's AC**. On a hit, roll your **damage die (+ mod)** off its HP.
2. **Natural 20 = critical:** auto-hit, **double damage dice**, a screen-shaking BOOM.
3. **Natural 1 = fumble:** auto-miss (and maybe a mishap).
4. **The monster strikes back:** it rolls d20 + its bonus vs **your AC**; on a hit it rolls damage off your HP. A monster nat 20 crits you; a nat 1 fumbles.
5. Repeat until the monster drops (you win + loot) or **you** drop.

Monsters have **HP and AC that scale with depth** (and a boss is tougher). Press **[H]** in a
fight to quaff a **healing potion** (small = 1d4, large = 1d8+1) — but not at full HP.

## 3. Getting downed, lives, and loot recovery

Hit 0 HP and you're **downed**: you **lose all your gold and magic**, are dragged back to
**START**, and revived. Returning to START also **heals you to full**. Each death adds a
skull; reach your **Max Deaths** and the run is **forfeited** (permadeath).

With **Loot Recovery** on, your dropped hoard is **left where you fell** — trek back and
kill whatever took it to reclaim your gold and items ("revenge"). *Souls-like* recovery
gives you only **one** chance: die again before reclaiming and it's gone forever.

## 4. Magic items & treasure

Slaying a room's monster yields its treasure (gold) and sometimes an item:

- **Magic Sword +N** — adds to your to-hit *and* damage.
- **Magic Armor / Shield** — raise your AC.
- **Magic Bow** — +2 to-hit.
- **Elf Boots** — +2 movement and you slip away from fights more easily.
- **ESP Medallion** — peek a room's monster before you commit.
- **Crystal Ball** — press **[V]** to scry every room's contents.
- **Secret Door Card** — your searches never fail.
- **Teleport Scroll** — press **[T]** to whisk back to START.

## 5. Curios & traps

Between fights you may stumble on a **curio** — a chest, fountain, shrine, idol, gamble,
peddler, corpse, mushroom, obelisk, cache, or a **mimic** that turns out to be a monster.
Each offers a choice (open/drink/pry/eat…) with a reward or a risk. Some chests are
**trapped**; traps also spring on their own:

| Trap | Effect | Save with |
|---|---|---|
| Poison | damage over several turns | CON |
| Bomb | burst damage, maybe catch fire | DEX |
| Frost | freeze (multiplayer) or cold damage | CON |
| Siren | draws more wandering monsters | WIS |

Lingering too long (idle, repeated searches) can summon a **wandering monster** to ambush you.

## 6. Secret doors, sight, and the map

- **Secret doors** are hidden; press **[F]** to search near a wall (the Elf is better at it, and a Secret Door Card auto-finds). The first one you find grants the **Level Key**.
- With **Line of Sight** on, you only see what your torch reaches; explored ground stays dimly remembered.
- Deeper levels hold tougher monsters and richer treasure.

## 7. XP & winning

Each kill grants **XP** (scaled by the monster's depth; a boss is worth double) and you can
**level up** for more HP. To **win**: carry the **Level Key** *and* at least your class's gold
total back to the **START** chamber.

## Chronicle it
Press **[M]** any time for the Game Menu — your character sheet, a run summary, the event
log, the bestiary, a treasury of what you've found, these rules, and the controls.
