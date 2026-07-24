# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A dungeon-crawler game written in **QB64 Phoenix Edition (QB64PE)** BASIC. Graphics are
ANSI/text-mode art rendered to off-screen 32-bit images; gameplay (movement, rooms,
sectors, collision) is driven by sampling the pixels of that rendered art rather than a
separate tile data model.

**Design basis: TSR's _Dungeon!_ board game (1975).** Treat its mechanics as the rules
reference. Original: 6 levels (deeper = tougher monsters / richer treasure); classes with
different treasure-to-win goals (Hero 10k GP, Elf 10k + 2× secret-door odds, Superhero
20k, Wizard 30k with ranged/teleport magic); combat = move onto a monster and roll 2d6 vs
the monster's number; treasure sits under the monster; win by returning to the start
chamber with your class's target. This project expands that to **9 levels** — the 9
`SECTORS` and their room labels (Armory, The Crypt, King's/Queen's/Wizard's Quarters,
Torture Chamber, …) are the Dungeon! rooms, and `PLANS.todo` (dice `1d20`/`3d6+3DL`,
turns/step-limits, secret-door detection, `has_level_key`/`is_boss_room` room flags,
character create, "Lords of Legend") is the adaptation's rule set.

## Setup

Dependencies are git submodules and **must** be fetched before anything compiles:

```
git submodule init
git submodule update
```

- `include/Toolbox64` — a740g's library; this project uses `FileOps` (`LoadFile$` /
  `LoadFileFromDisk$`) and `ANSIPrint` (`ANSI_Print`, which renders `.ans` bytes to the
  current `_DEST` image).
- `include/QB64_GJ_LIB` — grymmjack's `_GJ_LIB.BI` / `_GJ_LIB.BM` helpers.

## Build & run

There is no CLI build script; compilation goes through the QB64PE compiler, wired up as
VS Code tasks in [.vscode/tasks.json](.vscode/tasks.json). The compiler path comes from
the `qb64pe.compilerPath` setting (provided by the `grymmjack.qb64pe` extension).

- **BUILD: Compile** → `qb64pe -w -x <file> -o <file>.run` (`.exe` on Windows). `-w`
  compiles with warnings, `-x` compiles without launching the IDE.
- **EXECUTE: Run** (default build task, bound to **F5**) → runs `BUILD: Compile` then
  executes the resulting `.run`/`.exe`. The active editor file is the compilation unit —
  whichever `.bas` is focused is what gets built.
- `.run`/`.exe` outputs are git-ignored; each `.bas` compiles to a sibling binary.

To compile a single file by hand: `qb64pe -w -x <path/to/file.bas> -o <path/to/file.run>`
(needs a local QB64PE install; the exact binary path is machine-specific).

There are no automated tests. The `TEST-*.bas` files in `scratchpads/` are manual,
runnable prototypes, not a test suite.

## Screenshotting the apps

These prototypes run `_FULLSCREEN`, so to capture one, use
`scratchpads/shots/capture.sh <app.run> <out.png>` (patterned on
`~/git/DRAW/DEV/qb64-shot.sh`). It launches under `setsid timeout`, lets the app render,
takes a fullscreen `spectacle` capture, and tears down by exact PID/process group.
Environment specifics that dictate this approach:

- Session is KDE **Wayland**: `grim` fails (no `wlr-screencopy`); **`spectacle -b -n -f`**
  is the working capturer. Because the apps are fullscreen, no window lookup is needed —
  which is good, since QB64 windows expose no class / `_NET_WM_PID`, so `xdotool` can't
  find them, and the local `import`/ImageMagick has no X11 support anyway.
- **Never `pkill -f <app>`** to stop it — under an agent's eval-wrapped shell that pattern
  matches the killer's own argv and SIGTERMs the shell (exit 144). Kill by exact PID only.

## Where the code lives

- **`dungeon.bas`** (repo root) — the playable game. The main file is now thin (~290 lines):
  top includes `include/DUNGEON.BI` (all `CONST`s, `TYPE`s, and `DIM SHARED` globals — must
  load first), then the screen/init setup, the `INTRO → MENU → PLAY → WIN/LOSE` state machine
  (`SELECT CASE game_state`), the **core game loop** (`PlayGame` / `DoCombat` / `MonsterAttack`
  / `ClaimTreasure`), and finally the module bodies. The SUBs/FUNCTIONs are split into
  bottom-`'$INCLUDE`'d modules: **`include/SECTOR.bas`** (sector geometry + monster/treasure/
  class data + `RandomizeRooms`), **`include/BOARD.bas`** (board render, fog-of-war, secret
  doors, pixel-colour collision), **`include/CURSOR.bas`** (movement + draw/erase), and
  **`include/MENU.bas`** (intro, menu, class-select, SETTINGS, dialogs, HUD, dice, sound), and
  **`include/LORDS.bas`** (persistent hall of fame + LOAD A CHARACTER, saved to the git-ignored
  `dungeon-lords.dat`). QB64 resolves
  SUBs globally, so the main-file loop can call any module SUB regardless of include order;
  the only ordering rule is that `DUNGEON.BI`'s declarations come before the executable setup. Encounters ride the existing pixel-color collision:
  each `SECTOR` carries an optional monster, and stepping onto a room floor (`InRoomNow`)
  in a sector with a live monster triggers combat (`DoCombat`). Movement (1d6) and 2d6 rolls
  animate on-screen pip dice (`RollDiceShow` / `DrawDie`); polyhedral dice (d20/d8/d10) use a
  number tumbler (`ShowRollText`). Every roll goes through `GameRoll(n, sides, bonus, label)`
  (with `DoRoll` a d6 wrapper over it): with the SETTINGS **Real Dice** toggle on, the player
  rolls their own physical dice and types the result (`PromptRoll`) — the **Dice Math** toggle
  decides whether they add the modifier or the game does.
  **Two combat systems**, chosen by the SETTINGS **Oldschool** toggle (default ON): ON is the
  classic Dungeon! **2d6-vs-target** (`DoCombat`, one roll — slay or roll the Monster Attack
  Table), OFF is **D&D-style** (`DoCombatDnD`) — multi-round with monster **HP + AC**
  (`SECTOR.mhp/mhp_now/mac`, scaled by level in `RandomizeRooms`) and per-class **HP / to-hit /
  damage die / AC** (`PCLASS.hp/tohit/dmg/ac` in `InitClasses`): each round the player rolls
  d20+to-hit vs the monster's AC then a damage die (`DrawCombatPanel` shows HP bars); the
  monster strikes back (computer-rolled) against the player's AC/HP; natural 20 crits (double
  dice), natural 1 fumbles; being downed loses all gold and drags you back to START (revived),
  and returning to START heals to full. Both systems honour Real Dice. Four player classes
  (`CLASSES(1..4)`: Hero/Elf/Superhero/Wizard) with the authentic DUNGEON! win totals
  (10k/10k/20k/30k) are chosen via CREATE A CHARACTER (`SelectClass`), which then rolls the
  character **old-school** (`RollCharacter`): 3d6 for STR/INT/WIS/DEX/CON/CHA — or **4d6
  drop-lowest** with the SETTINGS **Stat Roll** toggle — plus HP on the class hit die. The
  scores derive the D&D combat stats (`player_tohit/ac/dmgdie/dmgbonus/maxhp` via `AbilMod` =
  floor((score-10)/2), STR for fighters / INT for the Wizard); `InitDefaultChar` supplies
  baseline stats for the default HERO and loaded champions. Movement is 8-way — WASD/arrows
  plus numpad diagonals (`NormKey$` → `NW/NE/SW/SE`, `TryMove`/`IsMoveKey`) — and stepping onto
  a door hops one cell further so you pass through it. `[?]` `ShowKeys` lists every binding.
  About 1 in 6 brown doors are **reinforced** (`DetectDoors`/`MarkStrongDoors`/`DOOR_STRONG`):
  bumping one (`StrongDoorAhead`) forces a STR check to `BreakDoorAttempt` it (thud + splinter
  sounds). The SETTINGS **Boardgame** toggle (default ON) governs movement: ON is the classic
  roll-1d6-then-step-that-many turn structure; OFF (`opt_boardgame` FALSE) is free "computer
  game" walking — the roll/`steps_left`/`need_roll` bookkeeping is bypassed and the HUD shows
  `FREE MOVE`. Every directional menu (`SelectClass` included) routes keys through `NormKey$`,
  so arrows and the numpad work anywhere WASD does. SETTINGS also carry **volume sliders** (Music/SFX/Voice, `opt_*vol` 0-10; all effects
  route through `Tone`, music through `_SNDVOL music_handle`) and a **Voice** toggle that blips
  per glyph in the typewriter **`ScrollText`** window (used for the game-open narration).
  **Rooms are rolled fresh each game** (`RandomizeRooms`): each level's sector draws an
  authentic monster + treasure from that level's pool (`InitMonsterTables`), and one deep
  sector becomes the boss lair (`is_boss`). Each monster carries its exact **per-class** 2d6
  kill numbers from the cards (`MON_N[level,slot,class]`; `13` = the "-" that needs a Magic
  Sword), and combat targets the player-class number directly. A missed attack rolls the
  authentic **MONSTER ATTACK TABLE** (`MonsterAttack`: killed / serious wound / light wound /
  stunned / missed). Special treasure cards grant powers (`ClaimTreasure`): **Magic Sword**
  (+1/+2; a Wizard can't wield one), **Secret Door Card** (searches never fail), **ESP
  Medallion** (peek a monster's treasure), **Crystal Ball** (`[V]` `ScryView` reveals every
  room's contents). A `[C]` character sheet (`ShowCharSheet`) lists class, gold, key, and
  items. All events route through the `Sfx` dispatcher. Build/run from the repo root (asset
  paths are `assets/...`, not `../assets/...`).
- **Secret doors / fog-of-war** (`dungeon.bas`, `InitFog`). The board loads from
  `assets/ansi/_/board-132x60-no-labels.ans` (same map as the no-secrets board **plus**
  bright-blue secret-door tiles). At load, `DetectSecretDoors` scans a pristine `FULL_BOARD`
  image for those tiles; a BFS from START (doors treated as walls) marks the "public" area,
  and a second BFS seeded from every door marks the door-connected "secret" cells. The played
  `CANVAS`/`CANVAS_COPY` are `FULL_BOARD` with the secret cells + doors painted black — so
  hidden doors read as ordinary wall and the base map matches the no-secrets layout. `[F]`
  `DoSearch` (Elf's `secret_bonus` helps) flood-fills outward from a found door
  (`RevealRegionFromDoor`), copying just that region back from `FULL_BOARD` — revealing the
  door and only what it connects to. The first door found grants the Level Key; the win
  requires gold **and** `has_key` **and** returning to START.
- **`scratchpads/`** — the active workshop. The prototypes `dungeon.bas` was built from
  live here (`TEST-MOVEMENT-MAP.bas` = movement/collision; `TEST-MENU.bas` = animated ANSI
  menu; `wip.bas` = intro→board flow). `const.bas` / `types.bas` hold shared CONSTs and
  TYPEs pulled in via `'$INCLUDE`. `scratchpads/shots/` holds the capture harness.
- **`include/`** — `DUNGEON.BI` (header) + `SECTOR.bas` / `BOARD.bas` / `CURSOR.bas` /
  `MENU.bas` (the game's module bodies, `'$INCLUDE`'d by `dungeon.bas`), plus the `Toolbox64`
  and `QB64_GJ_LIB` submodules.
- **`assets/ansi/`** — the game's actual graphics: `.ans`/`.icy`/`.xb` text-mode art,
  including the board, menu pieces, and monsters. These are content, not decoration —
  the board art is also the collision map.
- **`assets/music/`** — `.rad` (Reality Adlib Tracker) tracks played via `_SNDOPEN`.

[PLANS.todo](PLANS.todo) (todo.txt/@done format) is the roadmap and the source of truth
for intended game rules (rooms, doors, dice, turns, cursor states).

## Core architecture

**ANSI art as both graphics and collision map.** A `.ans` file is loaded as a byte
string and `ANSI_Print`'d onto a `_NEWIMAGE(SW*CW, SH*CH, 32)` canvas. The screen is a
fixed character grid — **132×51 chars** at an **8×16 px** font cell (`SW/SH/CW/CH`
globals). Cell (col,row) maps to pixels (col*CW, row*CH).

**Pixel-color collision.** To decide whether the cursor can move, the engine copies the
cell-sized region under the cursor into a scratch image and inspects its pixels:
- `image_is_monochromatic(img, color)` — every pixel is exactly `color`.
- `image_is_diachromatic(img, c1, c2)` — every pixel is `c1` or `c2` (and both present).

`is_path` (all YELLOW), `in_room` (sector color, optionally + BROWN door / BRIGHT_BLUE),
and `is_door`/`is_secret_door` build on these. `CURSOR.can_move` ORs the states together.
Colors are exact `_RGB32` matches, so **art must use the exact palette values** the code
checks — anti-aliasing or an off-by-one color silently breaks movement. Board ANSI is
rendered with `$RESIZE:STRETCH` + `_FULLSCREEN _SQUAREPIXELS, _SMOOTH`.

**Two-canvas draw/erase.** `CANVAS` is what's shown and drawn onto; `CANVAS_COPY` holds
the pristine board. The cursor `_PUTIMAGE`s a clean copy back to erase, and samples
`CANVAS_COPY` (never the dirtied `CANVAS`) when testing collision, so the cursor's own
pixels can't be mistaken for terrain.

**Sectors.** The board is divided into 9 `SECTOR`s (`SECTORS(1 TO 9)`), each a rectangle
with a `kolor` and `label`. `SECTOR.get_by_xy` resolves a pixel position to a sector,
and the sector's color is what `in_room` matches against — this is how "which dungeon
level am I in" is derived from position + art color.

## QB64PE conventions in this codebase

- Type-sigil naming: `%` INTEGER, `&` LONG, `~&` `_UNSIGNED LONG` (colors/image handles),
  `$` STRING. Names are frequently declared `AS <type>` and *also* used with a sigil.
- `'$INCLUDE:'path'` (note: `.bi`/`.bas` split — types/declares in `.bi`, bodies in
  `.bas`, included at top and bottom of the file respectively).
- `DIM SHARED` for globals; metacommands like `$RESIZE:ON`, `$Debug`, `$RESIZE:STRETCH`.
- `CONST TRUE = -1, FALSE = NOT TRUE` (BASIC true is -1).
- Image handles from `_NEWIMAGE` must be `_FREEIMAGE`'d; sounds `_SNDCLOSE`'d.
- `SUB`/`FUNCTION` names use dotted pseudo-namespaces (`CURSOR.move`, `SECTOR.get_by_xy`).
  **Gotcha:** a *dotted* SUB name written as a statement immediately before a colon is
  parsed as a **label**, not a call, and silently never runs — e.g. `CURSOR.erase: CURSOR.draw`
  makes `CURSOR.erase` a no-op label (compiles clean, no error). Put each dotted call on its
  own line, or avoid dots in SUB names (`dungeon.bas` uses `cursor_erase`/`cursor_draw`).
  Dotted *functions* inside expressions (`x = SECTOR.get_by_xy(...)`) are unaffected.

## Line endings (enforced via .gitattributes)

- Everything is LF **except `**/*.ans`, which are CRLF** — ANSI art relies on CRLF; do
  not normalize it.
- `.bas`/`.bi`/`.bm`/`.frm` are tagged `linguist-language=qb64` so GitHub classifies them
  correctly.
