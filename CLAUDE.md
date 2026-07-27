# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A dungeon-crawler game written in **QB64 Phoenix Edition (QB64PE)** BASIC. Graphics are
ANSI/text-mode art rendered to off-screen 32-bit images; gameplay (movement, rooms,
sectors, collision) is driven by sampling the pixels of that rendered art rather than a
separate tile data model.

**Design basis: TSR's _Dungeon!_ board game (1975).** Treat its mechanics as the rules
reference — [DUNGEON-RULES.md](DUNGEON-RULES.md) is the full plain-text rules summary (movement,
combat, items, the Monster Attack Table) mapped to the code, and is what **Oldschool mode**
(`opt_oldschool`) reproduces. Original: 6 levels (deeper = tougher monsters / richer treasure); classes with
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
  **`include/MENU.bas`** (intro, menu, class-select, SETTINGS, dialogs, HUD, dice, sound),
  **`include/LORDS.bas`** (persistent hall of fame + LOAD A CHARACTER, saved to the git-ignored
  `dungeon-lords.dat`), and **`include/CHRONICLE.bas`** (the in-game **Game Menu** `[M]` reference
  suite). QB64 resolves
  SUBs globally, so the main-file loop can call any module SUB regardless of include order;
  the only ordering rule is that `DUNGEON.BI`'s declarations come before the executable setup. Encounters ride the existing pixel-color collision:
  each `SECTOR` carries an optional monster, and stepping onto a room floor (`InRoomNow`)
  in a sector with a live monster triggers combat (`DoCombat`). **Dice** — every d6 roll
  (movement 1d6, combat 2d6, the 3d6 ability rolls) animates hand-drawn pip dice
  (`RollPips` / `DrawDie`; `RollDiceShow` is a 1-arg wrapper), and every non-d6 roll draws a real
  polyhedron from the **DPoly OTF dice fonts** in `assets/fonts/dpoly` (`InitDice` /
  `DrawFontDie` / `ShowRollText`) — see "Dice fonts" below. Every roll goes through `GameRoll(n, sides, bonus, label)`
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
  **Per-room encounters, rolled fresh each game.** `DetectRooms` (BOARD.bas) flood-fills the
  board's coloured blocks into ~90 individual `ROOMS()` (cell→room map in `ROOMAT()`), skipping
  the entrance chamber and tiny label blocks (`ROOM.cells < 4`). `RandomizeRooms` then gives
  EVERY room its own authentic monster + treasure from its level's pool (`InitMonsterTables`;
  sector 1 included), with one deep room the boss lair (`is_boss`). Stepping onto a room cell
  looks up `ROOMAT` and fights that room's monster — `DoCombat`/`DoCombatDnD`/`MonsterAttack`/
  `ClaimTreasure` all take a **room index** and read `ROOMS(rm)` (the level label still comes
  from `ROOMS(rm).sec` → `SECTORS`). `DrawTombstones` paints a headstone on each cleared room
  (via `cursor_draw`); dying calls `DropEverything` (gold + all special cards). `SECTOR`'s old
  monster fields are now vestigial. **Chambers** (the big named halls, distinct from `ROOMS`):
  `DetectChambers` (BOARD.bas, openness flood-fill from each label anchor) fills `CHAMBERAT(cx,cy)`
  = chamber id; per the board game a chamber holds **3 monsters and NO treasure**. Stepping into a
  fresh chamber (`cur_chamber` transition in the play loop, never on a room cell) fires
  `ChamberEncounter(cid)`: ONE monster of that level rises (scratch `ROOMS(ROOM_N+2)` slot,
  `is_chamber = TRUE` so `ClaimTreasure` grants no treasure but still `RecordKill`s), fought with
  `DoCombat`; leave and re-enter for the next until `CHM_DEAD(cid) = 3`. `PickChamberGraves` seats
  3 spread cells at detection; `DrawChamberGraves` paints up to `CHM_DEAD` headstones. The Main
  Gallery / entrance (the chamber containing START) never spawns. The `[~]` debug overlay tints
  every `CHAMBERAT>0` cell (magenta = spawning, green = 3 graves) — those are the trigger cells,
  vs the magenta `+` crosses which are only label seeds. **Solo play modes** (`include/SOLO.bas`,
  SETTINGS **Solo Mode**, single-player only): **Time Limit** (`opt_solomins` 30/25/20/15 min; time
  out = lose), **Item Search** (`SoloPickQuest` marks the deepest rich hoard as `solo_item_room`;
  claim it to win, two deaths = lose), **Monster Prey** (a level-6 `hunt_*` monster BFS-chases the
  player one cell per step over `FULL_BOARD` so it uses secret doors — `HunterAdvance` fills
  `HDIST`; it catching you = lose, you stepping onto it = `HunterFight` → kill respawns a fresh one).
  `SoloTick` (play-loop, every frame) sets `solo_result` = `OUT_WIN`/`OUT_LOSE`; `DrawSoloHUD` is the
  top status ribbon; solo state resets per run (`SoloReset`) and is not saved (loaded games play
  normal). **Hot-seat multiplayer** (`include/PLAYERS.bas`): SETTINGS
  **Players** (1-4; >1 forces Boardgame ON). The active player's state IS the working globals;
  `PLAYERS(1..4)` parks each between turns via `Load/SaveActivePlayer`, `SetupPlayers` runs each
  through class-select + roll-up + `PromptName$`, `EndPlayerTurn`/`NextActivePlayer`/`AnnounceTurn`
  pass the seat, and `cursor_draw` shows every player's token (`PLAYER.kolor`).
  Each monster carries its exact **per-class** 2d6
  kill numbers from the cards (`MON_N[level,slot,class]`; `13` = the "-" that needs a Magic
  Sword), and combat targets the player-class number directly. A missed attack rolls the
  authentic **MONSTER ATTACK TABLE** (`MonsterAttack`: killed / serious wound / light wound /
  stunned / missed). Special treasure cards grant powers (`ClaimTreasure`): **Magic Sword**
  (+1/+2; a Wizard can't wield one), **Secret Door Card** (searches never fail), **ESP
  Medallion** (peek a monster's treasure), **Crystal Ball** (`[V]` `ScryView` reveals every
  room's contents). A `[C]` character sheet (`ShowCharSheet`) lists class, gold, key, and
  items. All events route through the `Sfx` dispatcher. Build/run from the repo root (asset
  paths are `assets/...`, not `../assets/...`).
- **Chronicle / Game Menu (`[M]`)** (`include/CHRONICLE.bas`). A per-run journal + reference
  suite: `GameMenu` opens **Character Sheet / Game Summary / Event Log / Bestiary / Treasury /
  Rules / Controls / Resume**. All counters live in `DUNGEON.BI` (`g_rooms_explored`,
  `g_monsters_slain`, `g_crits`, …, the `BEAST_*`/`TRE_*` tallies, and the `EVLOG()` single-line
  event log); `ChronicleReset` zeroes them each run **and seeds the Bestiary with the full 27-monster
  roster** (so unmet monsters still list at 0). Gameplay feeds them through `Record*` hooks —
  `RecordEnterRoom`/`RecordEncounter`/`RecordKill`/`RecordFled`/`RecordDeath`/`RecordLootRescue`/
  `RecordTreasure`/`RecordItem`/`RecordSecret`/`RecordWander`/`RecordCrit`/`RecordFumble`/
  `RecordLevelDone` — placed at the matching moments in `DoCombat`/`DoCombatDnD`/`ClaimTreasure`/
  `DropEverything`/`CollectDrop`/`WanderEncounter`/`DoSearch`/the play loop. **Gotcha:** `DoCombat`
  already calls `RecordEncounter` for every fight (rooms AND wander slots), so `RecordWander` must
  NOT re-bump `BEAST_ENC` or wanderers double-count. **Curios/traps** feed the chronicle too:
  `CurioGain` (CURIO.bas's gains route through it instead of bare `LogTreasure`) does
  `LogTreasure` + `RecordTreasure` + `LogEvent`, and `RecordCurio`/`RecordTrap` log the encounter
  and the save outcome — so curio spoils show in the **Treasury** and everything shows in the
  **Event Log**. The Treasury (`ShowTreasury`) is a Bestiary-style lightbar with a framed treasure
  IMAGE per row via `TreasureSprite$`/`TreBase$` (SPRITES.bas): normalise the name (drop
  `(+1)`/`(spare)` qualifiers, keep plurals), try `assets/pixel-art/treasures/` then `items/`, then
  keyword fallbacks (`InStrAny%`) for gems/cups/coffers/coins/gear. `ShowRules` reads
  `DUNGEON-RULES.md`, folds its typographic UTF-8 to ASCII (`Utf8ToAscii$`/`SubstAll$` — the CP437
  grid font renders each UTF-8 byte as a separate DOS glyph otherwise), strips `**`/`` ` `` markdown,
  and is also reachable from the title screen via `[R]`. The **Lords of Legend** screen (`include/LORDS.bas`,
  `ShowLordDetail`) now carries a **v3** record (`…|ab|mapid|events`): `ShowEnd` snapshots the final
  board to `dungeon-lords-map-<mapid>.png` before name-entry, and `SaveLord` persists that id + the
  last ~180 events (joined by `" ~~ "`); the detail view adds `[E]` chronicle log (`ShowLordLog`) and
  `[M]` map-at-escape (`ShowLordMap`) beside the existing ability/per-level character sheet.
- **Line-of-sight fog-of-war** (SETTINGS **Line of Sight**, `opt_fov`, default off). Separate
  from the secret-door fog: `LOS_LIT` (in sight now) + `LOS_SEEN` (ever explored) masks.
  `ComputeFOV` casts Bresenham rays (`CastRay`) from the player out to a radius, each stopping
  at the first opaque (black-wall) cell sampled from `CANVAS_COPY`; `cursor_erase` recomputes
  only when the player's cell changed. `FovRender` blacks the screen, blits back only `LOS_SEEN`
  cells from `CANVAS_COPY`, and dims those not currently `LOS_LIT`. Collision still reads the
  full `CANVAS_COPY`, so you can walk into the dark. Room labels (`PutLabel`), tombstones, and
  rival tokens are hidden until seen. **Gotcha:** the dim/hide tests must be `LOS_LIT(x,y) = 0`,
  not `NOT LOS_LIT(...)` — `NOT` is bitwise, so `NOT 1` = -2 (still truthy).
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
- **`assets/data/`** — the editable **content database**: pipe-delimited `.txt` files
  (`monsters` / `treasures` / `items` / `bosses` / `traps` / `effects`), loaded at launch by
  **`include/DATA.bas`** into the same shared tables the old hard-coded `Init*` routines used
  (via `Mob`/`SetTreSlot`/`SetItem`/`AddFX`, and `LoadTraps` for the `TRAPS()` array). Fields
  are TRIMMED so columns can be space-padded; `#` = comment. `InitMonsterTables` and
  `InitEffects` are now thin wrappers that call the `Load*` subs. Edit a file, press F5 — no
  code change needed to rebalance. Trap *mechanics* (poison/bomb/frost/siren) stay in code,
  keyed by each row's `kind`; everything else about a trap (name, save stat, dice, messages)
  is data. Room/combat prose lives in the sibling **`assets/flavor/`** files: `regular`/
  `special` room lines, `maxhit`, `forfeit` (see FLAVOR.bas), plus **per-monster and
  per-class combat event text** — `monster_events.txt` / `class_events.txt` (`key | event |
  text`, events attack/miss/crit/fumble/death, `key "*"` = default), loaded by **CTEXT.bas**
  so each monster/class gets biology-appropriate hit/miss/crit/fumble/death lines. All flavor
  supports `{mon} {player} {class} {dmg} {deaths} {level} {room} {treasure} {weapon}` tokens
  via `Fill$`; combat sets the `FX_*` context globals before each line.
- **Configurable UI fonts** — `assets/data/ui-fonts.txt` (`region | fontfile | size`) maps UI
  regions to TrueType fonts in `assets/fonts/ui/`, loaded by `LoadUIFonts` into `UIF_*` handles
  (0 = the built-in 8×16 grid font, handle `CH`). Wrap a draw block with `UIFontOn h` /
  `UIFontOff` (restores `CH`). Applied to room labels (`PutLabel`), the combat panel
  (`DrawCombatPanel`, loaded MONOSPACE so HP bars stay even), and message banners (`Banner`).
  `PrintCentered` centres by `_PRINTWIDTH` (pixel-accurate for proportional fonts; unchanged for
  the grid font, where `_PRINTWIDTH` = `LEN*8`). The board ANSI art itself stays the fixed grid.
- **Near-death juice layering** (`include/JUICE.bas`): the blood/vignette (`DrawWounds`) is drawn
  in `cursor_erase` right after the board art and **before** `render_room_labels`, so labels /
  tokens / HUD / combat panel all render on top (board → blood → text). The vignette is a soft
  RADIAL gaussian: `InitVignette` pre-bakes `NVIG` low-res overlays (a near-death ramp) once, and
  `DrawWounds` stretch-blits the level-appropriate one each frame (`VIG()`).

[assets/README.md](assets/README.md) is the player/modder-facing map of every editable
asset (data tables, flavor prose, music playlist, sound effects) with formats and the
token list — keep it in sync when the asset formats change.

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

**Dice fonts (DPoly).** Non-d6 rolls are drawn with the six **DPoly** OTF dice fonts in
`assets/fonts/dpoly` (dafont.com/dpoly), loaded by `InitDice` into `DFONT()` **indexed by side
count** (`DFONT(20)` is the d20 font). Every glyph *is* a die face, so a d20 showing 17 is the
character `Q` printed in the d20 font:

- **`A` = the die's lowest face**, so face *n* is `CHR$(64 + n)` — d20 `A`..`T` = 1..20, d12
  `A`..`L`, d8 `A`..`H`, d4 `A`..`D`. The **d10 is the exception**: its first glyph is the **0**
  face (`A`=0, `B`=1 … `J`=9, and `K`..`T` are the 00/10/…/90 percentile faces), so a rolled 10
  draws that `0` like a real ten-sider. `DieGlyphCode` encodes exactly this.
- **UPPERCASE = solid die, lowercase = outline die** (same face). `DrawFontDie` prints the solid
  variant in a body colour and then the outline variant *on top* in an ink colour under
  **`_PRINTMODE _KEEPBACKGROUND`** — which yields a filled die with a **contrasting** number, a
  look neither variant gives alone. `_KEEPBACKGROUND` is essential: the default
  `_FILLBACKGROUND` would blank pass 1 with pass 2's background.
- **Never load these `"monospace"`.** That flag squeezes every glyph into a fixed cell narrower
  than the point size (d20 @56pt → a 49px cell) and **clips the polyhedra's left/right points**.
  Load proportional and measure the real advance with **`_UPRINTWIDTH`** (`DieWidth`) —
  `_FONTWIDTH` returns 0 for proportional fonts.
- **Draw with `_UPRINTSTRING`, not `_PRINTSTRING`.** `_PRINTSTRING` clips each glyph to its font
  **cell**, and these dice draw their top vertex *above* the cell — so `_PRINTSTRING` slices the
  point off flat (worse on the pointy d20/d8; invisible at rest, obvious once you look at the top
  edge). `_UPRINTSTRING` renders the whole glyph, point intact. It draws the point *above* the
  `py` origin, so leave a little headroom above the dice in the layout.
- Fonts that fail to load leave a handle of `0`; `ShowRollText` then falls back to the plain
  number tumbler (`ShowRollValue`) rather than crashing.
- The look is player-configurable in SETTINGS and persisted: **Dice Colour** (`opt_dicecolor`,
  6 palettes via `DiceColors`), **Dice Finish** (`opt_dicesolid`, solid/hollow), **D6 Style**
  (`opt_d6pips`, pip art vs the font's numbered six — the font's d6 is a *numbered square*, which
  is why the hand-drawn pips are the default), and **Dice Speed** (`opt_dicespeed`; `DiceTiming`
  returns the frame count / frame rate / settle frame / hold). `SETTINGS` renders a live 2×3
  sample grid on the right via `DrawDicePreview`. **The running total is only drawn once
  `f >= settle`** — showing it during the tumble spoils the roll. The roll box (`ShowRollTextEx`)
  auto-sizes to the wider of the dice row and its caption/`sum` line, so a single narrow die
  never leaves the `-= rolling 1d20 =-` header spilling past the box edges.
- **Pixel Smoothing** (`opt_smooth`, default off) is a display setting applied by `ApplyDisplay`
  (the one place the three `_FULLSCREEN` sites route through): on = `_FULLSCREEN _SQUAREPIXELS,
  _SMOOTH` (bilinear — soft, and it makes the tumbling dice shimmer); off = `_FULLSCREEN
  _SQUAREPIXELS` (crisp pixel-doubling, which suits the ANSI/text art and kills the shimmer).
- **3D dice top-light** (the DICE3D `LIGHT_*` config fields): a view-space Lambert directional
  light shades each face by `ambient + (1-ambient)*max(0, N·L)` so top-facing surfaces catch
  light and the dice read as solid 3D (and the **d4's apex** — its read point — is lit, which the
  read-face sheen can't do since a d4's value face is its hidden base). `_MAPTRIANGLE` can't tint
  a texture, and translucent overlays are unreliable (some GL drivers drop a semi-transparent
  `_COPYIMAGE(,33)` tile to invisible — the first attempt showed nothing on the reporter's GPU).
  So the shading is baked **into the atlas as opaque brightness COLUMNS**: `dice3d_make_atlas`
  lays out `DICE3D_LIGHT_NLEV` copies of each face tile left→right, column 0 full-bright and each
  next column darker (opaque black over it, up to `DICE3D_LIGHT_MAXDARK`); the renderers compute a
  per-face level (`dice3d_shade_level`) and add `level*DICE3D_TILE` to the source U — opaque
  sampling, identical on the software and hardware paths, GL-safe. (The 12px UV `MARGIN` keeps the
  face polygon off the column seams, so `_SMOOTH` never bleeds between brightness columns. Copy
  column 0 through a scratch tile — `_PUTIMAGE` image-onto-itself is an illegal call.) The
  set-loader seeds on-defaults so sets predating the keys still light up. The SETTINGS **Dice
  Light** slider (`opt_dicelight` 0 Off/1 Soft/2 Normal/3 Strong) drives `ApplyDiceLight`, which
  overrides `LIGHT_ENABLED`/`AMBIENT`/`INTENSITY` per roll and per preview (direction stays from
  the set); those map to which columns get sampled, so toggling needs no atlas rebake.
  **d4 read pose:** a d4 is a **top-read** tetra —
  the value is on the hidden base and repeats at the top apex, so `dice3d_showcase` seats the
  value face DOWN with `Rx(90 + CAM_TILT - 4) * FACE_Q(f)` (NOT `FACE_Q(f)` alone, which would
  point it at the camera and misread). The game renders the d4 at `CAM_TILT=85`, other dice at 21.5.

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
- **Gotcha (subtle, cost hours):** identifiers are **case-insensitive**, so a local like
  `DIM ch AS INTEGER` **shadows the `DIM SHARED CH`** (font-cell height / font handle) *within
  that procedure*. It compiles clean; then `_FONT CH` sees the local `0` → runtime **"Invalid
  handle"**, and any `... * CH` coordinate silently becomes `0`. Never name a local after a
  short shared global (`CH`/`CW`/`SW`/`SH`/`c`); the char-code locals are `chcode`. UDT string
  fields are also kept **fixed-length** (`name AS STRING * 16`, `_TRIM$` on read) as the safe idiom.
- **Gotcha:** single-line `IF` does not support `ELSEIF` / `ELSE IF` chains, and `LINE`, `SEG`,
  `VAL`, `CLS` are reserved words that can't be used as variable names.
- **Gotcha:** relative paths resolve against the **executable's** directory, not the shell's cwd
  — QB64PE chdirs to the binary at startup (`_CWD$` = the exe's dir, `_STARTDIR$` = where it was
  launched). That is *why* `dungeon.run` must sit at the repo root for `assets/...` to resolve;
  a test binary built into `scratchpads/` silently fails every `_FILEEXISTS`/`_LOADFONT`.
- **Headless verification:** `$CONSOLE:ONLY` turns a throwaway `.bas` into a stdout tool
  (`PRINT` goes to the terminal), which beats screenshotting for checking things like font
  handles, file paths, or computed values.

## Line endings (enforced via .gitattributes)

- Everything is LF **except `**/*.ans`, which are CRLF** — ANSI art relies on CRLF; do
  not normalize it.
- `.bas`/`.bi`/`.bm`/`.frm` are tagged `linguist-language=qb64` so GitHub classifies them
  correctly.
