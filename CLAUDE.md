# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A dungeon-crawler game written in **QB64 Phoenix Edition (QB64PE)** BASIC. Graphics are
ANSI/text-mode art rendered to off-screen 32-bit images; gameplay (movement, rooms,
sectors, collision) is driven by sampling the pixels of that rendered art rather than a
separate tile data model.

**Design basis: TSR's _Dungeon!_ board game (1975).** Treat its mechanics as the rules
reference — [DUNGEON-RULES.md](assets/reference/DUNGEON-RULES.md) is the full plain-text rules summary (movement,
combat, items, the Monster Attack Table) mapped to the code, and is what **Oldschool mode**
(`opt_oldschool`) reproduces. Original: 6 levels (deeper = tougher monsters / richer treasure); classes with
different treasure-to-win goals (Hero 10k GP, Elf 10k + 2× secret-door odds, Superhero
20k, Wizard 30k with ranged/teleport magic); combat = move onto a monster and roll 2d6 vs
the monster's number; treasure sits under the monster; win by returning to the start
chamber with your class's target. This project expands that to **9 levels** — the 9
`SECTORS` and their room labels (Armory, The Crypt, King's/Queen's/Wizard's Quarters,
Torture Chamber, …) are the Dungeon! rooms, and `plans/PLANS.todo` (dice `1d20`/`3d6+3DL`,
turns/step-limits, secret-door detection, `has_level_key`/`is_boss_room` room flags,
character create, "Lords of Legend") is the adaptation's rule set.

## Setup

The game itself has **no external submodule build dependency** — the one thing it needed
from Toolbox64 (the ANSI renderer) is **vendored** in `engine/ansi/` (see below). File
reads use QB64PE's built-in `_READFILE$`. So `dungeon.bas` compiles from a plain checkout.

- **`engine/ansi/`** — vendored `ANSIPrint` + its `GraphicOps`/`Common`/`Types`/`Debug`
  headers (from Toolbox64 @ `8c5d57d`, the last commit that compiles on QB64PE **4.4.0 and
  4.5.0**). Provides `ANSI_Print` (renders `.ans` bytes to the current `_DEST`). We vendored
  it because Toolbox64 `main`'s newer `ANSIPrint`→`Graphics2D.h` reaches a QB64PE internal
  (`write_page`) that fails to compile under 4.5.0 (see `scratchpads/TOOLBOX64-write_page-bug.md`).
  Do **not** re-point these includes at the `Toolbox64` submodule.
- `include/Toolbox64`, `include/QB64_GJ_LIB` — submodules kept for reference / other tools;
  **not** included by the game. If present, fetch with `git submodule update --init`.

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

**Tests:** `tests/run-tests.sh` (VS Code task **TEST: Run engine tests**) is the gate — run it
after any structural change. It runs, in order:

- the headless assert suites in `tests/TEST-*.bas` — `engine/TEXT.bas`, `STATS`, `MARKDOWN`,
  `SAVEIO`, `ARTPACK`, `TABLE`, `GAUGE`, and the pure half of `DATA` (**285 assertions, 8 suites**).
- **`audit-boundary.sh`** — no `engine/` file may name a `game/` symbol; every `Game_*` hook the
  engine CALLS must be DEFINED by both `game/` and `examples/minimal/`; and no ENGINE.BI global
  may be unused by all of `engine/` (that last one is the sharper question — a *one-directional*
  name check can never see something misfiled INTO the engine header).
- **`audit-shadow.sh`** — no local named after a high-risk shared global. QB64 identifiers are
  case-insensitive, so a local `brown` shadowed the shared `BROWN` and made `DetectDoors` return
  zero doors forever, silently disabling reinforced doors. Also covers the big UDT arrays
  (`ROOMS`/`PLAYERS`/…), where the compiler blames the *use* site rather than the `DIM`.
- **`audit-shortcircuit.sh`** — QB64's `AND`/`OR` always evaluate both sides, so `IF n > 0 AND
  ROOMS(n).x` still reads `ROOMS(0)`, and an `AND` around anything with a side effect (a die
  roll) is a correctness bug, not just a bounds risk.
- **`dungeon.run datalint`** — validates the ACTIVE data pack's content tables: item drop odds vs
  pool contents, unhandled item codes, chamber-event kinds with no mechanic, unwinnable class goals.
- **`dungeon.run fogdump`** — VERDICTS on secret-mask reachability. A hand-painted region that no
  door opens is unreachable forever, and killing the monster in `key_room` is the ONLY way to get
  the Level Key, so an art edit could otherwise strand it and make runs quietly unwinnable.
- **`dungeon.run savetest`** — save/load round-trip of the positional token stream (hot-seat seat
  isolation, 4-seat round-trip incl. names with spaces, chamber progress), plus a read-only load
  of a COPY of the player's real save to prove a format bump has not orphaned it.
- **`examples/minimal`** — builds + selftests a second game on `engine/` alone, proving the engine
  carries no hidden DUNGEON! dependency.

Also useful, not in the gate:

- **`dungeon.run econdump`** — expected gold economy + win pacing per class, and the **monster
  curve** (HP range / AC / to-hit per depth for room, chamber-LORD and boss spawns, straight out
  of `MonsterStats`/`MonsterToHit%`), so a balance change can be measured instead of playtested.
- **`dungeon.run roomlint`** — every detected room vs the cells the player can actually stand on,
  as a table AND as **`roomlint.png`** (green = plain floor, blue = doorway, tan = the art's
  decorative half-block lip, and each room's monster/grave marker boxed white / orange if it sits
  in a doorway / red+X if it sits somewhere unwalkable). A clean board reports only the 11 level
  plaques as DECORATION, and those are dropped from `ROOMS()` entirely, so **every room holds a
  monster**. Keep it clean: the art is data, so an edit can silently strand a room's monster
  again. See "Room detection" below.
- **`dungeon.run boardfix`** — re-spells half-block cells so the **collision colour is the
  FOREGROUND**. A half-block shows two colours and which one is "foreground" is arbitrary, but the
  collision map reads a cell BY its colour — four secret doors on the level-5 rooms were spelled
  with the door blue in the *background*, so they read as magenta cells with blue behind them.
  Flipping the glyph (`▀`↔`▄`, `▌`↔`▐`) and swapping the pair is the same picture spelled the other
  way. It is **not** a repaint: `SameRender%` renders both versions through `ANSI_Print` and refuses
  to write unless every pixel matches, and it is idempotent. iCE / bright backgrounds are fine and
  used freely — the flip is only about which half is named first, never about dimming anything.
- **`dungeon.run charsheet`** — renders the `[C]` character sheet for a fully-kitted hero to
  `charsheet.png`. Layout only breaks when the sheet is FULL, so a default-state shot proves
  nothing.
- **`dungeon.run sectorauto`** — derives each level's rectangle from the board art alone (the
  bounding box of every cell uniformly painted that level's colour) and reports overlaps, plus a
  count of walkable cells that resolve to **no level**. Two findings worth keeping in mind: over
  the raw image the derivation fails (15 overlapping pairs — the DUNGEON logo, the legend swatches
  and the top frame all paint in level colours), but excluding those *decorative* regions it comes
  out **clean, 9/9, no overlaps**. It also writes **`sectorauto.png`**: every walkable cell tinted
  with the level it resolves to, the derived rects outlined, and any cell claimed by **no** level
  flagged — **white** if the player can actually walk there, dim grey if it is sealed-off art. That
  split matters — the raw count is dominated by the logo, whose yellow fill reads as `path` but is
  sealed off. **91 unclaimed, 0 reachable** on a clean board; anything reachable is a real hole.

Only *game-free* engine modules that touch nothing but QB64 built-ins can be unit-tested;
everything else is verified through the binary's dev modes (`chamberdump`, `audiomanifest`,
`imagemanifest`, `uimanifest`, `ansilint`, `settingsshot`, `savetest`, `datalint`, `econdump`,
`roomlint`, `charsheet`, `fogdump`) or a play-test. See [tests/README.md](tests/README.md) for the skeleton, the assert
API, and the QB64 traps it is shaped around. (The `TEST-*.bas` files in `scratchpads/` are
unrelated — manual runnable prototypes, not suites.)

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
  top includes the header roll-ups **`engine/_ALL.BI` then `game/_ALL.BI`** (all `CONST`s,
  `TYPE`s, and `DIM SHARED` globals — must load first, **engine before game**), then the
  screen/init setup, the `INTRO → MENU → PLAY → WIN/LOSE` state machine (`SELECT CASE
  game_state`), the **core game loop** (`PlayGame` / `DoCombat` / `MonsterAttack` /
  `ClaimTreasure`), and finally the module bodies. **The codebase is mid-refactor into a
  reusable `engine/` + a swappable `game/`** — see [engine/ENGINE.md](engine/ENGINE.md) for the
  layout, the `Game_*` hook contract, and the boundary-debt ledger (this is the authority for
  which dir a module lives in; the per-feature prose below still names some modules by their old
  `include/` path). The SUBs/FUNCTIONs are split into bottom-`'$INCLUDE`'d modules:
  **`game/SECTOR.bas`** (sector geometry + monster/treasure/class data + `RandomizeRooms`),
  **`engine/BOARD.bas`** (board render, fog-of-war, secret doors, pixel-colour collision),
  **`engine/CURSOR.bas`** (movement + draw/erase), **`game/HOOKS.bas`** (the engine↔game
  contract — `Game_OnEnterCell%` / `Game_WinReached%`), and — still in `include/` pending the
  split — **`include/MENU.bas`** (intro, menu, class-select, SETTINGS, dialogs, HUD, dice, sound),
  **`include/LORDS.bas`** (persistent hall of fame + LOAD A CHARACTER, saved to the git-ignored
  `dungeon-lords.dat`), and **`include/CHRONICLE.bas`** (the in-game **Game Menu** `[M]` reference
  suite). QB64 resolves
  SUBs globally, so the main-file loop can call any module SUB regardless of include order;
  the only ordering rule is that the headers (`engine/_ALL.BI` then `game/_ALL.BI`) come before
  the executable setup, and the bodies (`engine/_ALL.BM` then `game/_ALL.BM`) go at the bottom.
  Assembling a program is those FOUR lines. Body order is irrelevant because QB64 resolves
  procedures globally AND no body file declares anything at file scope — keep that invariant:
  a new shared global or `CONST` belongs in a `.BI` header, never in a `.bas`. Encounters ride the existing pixel-color collision:
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
  `VoiceBlip` plays an optional `assets/sfx/voice.*` sample (pack-aware, `_SNDPLAYCOPY` per glyph)
  when present and otherwise falls back to the PC-speaker `SOUND` tone — so the text-crawl voice
  is themeable like any other effect (keep the sample short; it fires once per letter).
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
  `DetectChambers` (BOARD.bas) fills `CHAMBERAT(cx,cy)` = chamber id. The board art is fixed, so
  the exact map is hand-authored in **`assets/data/chambers.txt`** (one `name | c1 | r1 | c2 | r2`
  rectangle per chamber; every walkable cell inside becomes a trigger cell) and loaded by
  `LoadChambers` — the openness-flood-fill heuristic is only the fallback when that file is
  missing/empty. Per the board game a chamber holds **3 monsters and NO treasure**. Stepping into a
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
  top status ribbon; solo state resets per run (`SoloReset`) and is **persisted in the save**
  (SAVEGAME.bas `SOLO`/`SITEM`/`HMON` lines) so a timed / item-hunt / monster-prey run resumes
  in its mode on Continue. **Hot-seat multiplayer** (`include/PLAYERS.bas`): SETTINGS
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
  room's contents). **Wizard spells** (`spell_fire`/`spell_bolt` charges + `item_teleport`;
  helpers grouped before `DoCombat`): a Wizard opens each game with a spellbook (3 Fire Ball /
  3 Lightning Bolt / 2 Teleport) that refills on each descent, casts `[F]`/`[L]` in a fight
  (`WizardCastOldschool` = auto-slay unless `MonsterImmune%`, and the Wizard's only way past a
  "-" monster; D&D-mode = 3d6/4d6 to the monster's HP), and **Spell Card** treasures
  (`items.txt` codes 12/13) grant +2 charges to a Wizard while any other class sells the scroll.
  A `[C]` character sheet (`ShowCharSheet`) lists class, gold, key, and
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
  door and only what it connects to. (`DoSearch` does NOT grant the Level Key -- the only way
  to get it is killing the monster in `key_room`, via `ClaimTreasure` item code 6. Because that
  is the single path, `RandomizeRooms` refuses to place the key in a room it cannot reach:
  a room inside a hand-painted secret REGION that no door opens is skipped as a candidate
  (`RoomReachable%`), or the run would be quietly unwinnable. `dungeon.run fogdump` gives a
  VERDICT on that -- it exits non-zero and names any orphaned region, since the mask is art and
  an edit can strand one with no other symptom.) The win
  requires gold **and** `has_key` **and** returning to START.
- **Secret-region MASK** (the exact, art-as-data replacement for the flood above).
  `LoadSecretMask` (BOARD.bas) loads a same-size painted ANSI, `assets/ansi/board-132x50-secret-mask.ans`:
  **black = public, any non-black cell = secret**, and a **same-colour 4-connected run = one
  REGION** (a colour change or a black gap splits regions — so you paint each secret area, and
  each *nesting level* a different colour). `InitFog` prefers the mask (`MASK_ON`) and falls back
  to the flood only when the file is absent/empty. Each detected blue door maps to the region it
  opens (`RegionAtDoor`→`DOOR_REGION`), and `RevealRegionFromDoor` then reveals **exactly** that
  region (no flood, no ambiguity, no leftover specks). **Nested secrets** work naturally: a door
  painted the inner region's colour opens that inner region; it stays hidden inside the outer
  region until found by `DoSearch` (which is proximity-based, not sight-based) — `ComputeMaskLevels`
  tags each region's nesting depth. The mask is generated as a starter by `dungeon.run maskgen`
  (writes secret cells + a **SAUCE** record so ANSI editors read the 132×50 / IBM VGA dims), then
  hand-painted. `dungeon.run fogdump` renders the fogged board + a region overlay for verification.
  The `[~]` debug view tints each region, marks every secret door by nesting level (green entry /
  cyan nested / **red X = unmapped, a dead door**), and the mouse line shows `reg:/lvl:/door→`.
- **Sector MASK** (`assets/ansi/board-132x50-sector-mask.ans`, the art-as-data replacement for the
  `sectors.txt` rectangles). Same idea as the secret mask: a same-size painted ANSI where **each
  cell's colour = which dungeon level owns it**, so levels can be any shape, not just rectangles.
  `LoadSectorMask` (SECTOR.bas) fills `SECTORAT(cx,cy)` (0-based cells) via `SectorByColor%` (exact
  match to a `SECTORS().kolor`); when the file is present `SECTORMASK_ON` is set and `SECTOR.get_by_xy%`
  returns `SECTORAT(cx,cy)` — **but where a cell is black/unpainted (`SECTORAT = 0`) it falls through
  to the `sectors.txt` rect loop**, so a *partial* mask never bricks movement (painted cells still
  win, so any-shape levels hold; the rects only backstop the gaps). The rect loop is also the whole
  story when no mask file is present.
  Black = sector 0 — harmless over walls/corridors/doors, but a room floor sitting on black won't
  register a level (and `CanMove` needs `sec >= 1`). Generated as a starter by `dungeon.run sectorgen`
  (paints each rect with **bg-colour + space**, not `fg + █` — an editor renders `█` with a sliver
  gap that reads as black seams; iCE bright-bg `5;4x` matches the hand-paint), plus a SAUCE record.
  Both generators (`maskgen`/`sectorgen`) **refuse to overwrite** an existing mask (they only ever
  write a fresh file, so SAUCE lands at EOF and a hand-painted mask is never clobbered);
  `dungeon.run --help` lists every dev mode.
- **Mask line-ending / SGR gotcha + `MaskNormalize$` + `ansilint`.** A mask is art-as-data —
  every cell must sample as *exactly* its painted colour — and two things an ANSI editor emits
  silently corrupt that: **(1) CRLF line endings.** Each row is exactly `SW` (132) printable
  columns, so ANSIPrint auto-wraps at column 132 **and then** the CRLF advances again — a blank
  row between every painted row ("black bands"), so half the cells read as sector 0 and rooms go
  unenterable. The working board/secret-mask sidestep this by having **no per-row line breaks** at
  all (pure 132-col auto-wrap). **(2) Sticky SGR attributes.** A bright iCE background (`ESC[5;42m`,
  the blink bit = high-intensity bg) stays set when the next run only changes the colour (`ESC[46m`),
  so teal bleeds to bright-cyan and level 6 reads as level 7. Both are repaired at **load** by
  `MaskNormalize$` (DATA.bas) — strip CR/LF so rows auto-wrap, inject `ESC[0m` before every SGR run
  so each cell is self-contained, and stop at the `0x1A` EOF so SAUCE isn't rendered — which
  `LoadSectorMask` and `LoadSecretMask` both apply. Two CLI tools pair with it: **`dungeon.run
  ansilint [file]`** (read-only; no file = both board masks) reports line endings, per-row printable
  width, SAUCE dims, **the iCE flag**, how many cells `MaskNormalize$` changes (0 = clean), and each
  painted colour mapped to its level (flagging unmapped colours and unpainted levels); **`dungeon.run ansifix
  <file>`** rewrites a mask to the clean canonical form (`MaskNormalize$` + fresh SAUCE), backing the
  original up to `<file>.bak` (loaders already normalise at load — this just cleans the *stored*
  file). **Gotcha:** ANSIPrint renders each SGR bg correctly *in isolation*; the corruption only
  appears in a full file, so verify a mask by rendering the WHOLE thing (or run `ansilint`), never a
  single code.
- **iCE colours must be DECLARED in SAUCE.** Bright backgrounds are used freely and are the right
  tool — but a bright background is spelled with the **blink bit**, so an editor has to be told the
  file means "bright", not "blinking". That is `SAUCE.TFlags` bit 0 (`&H13` = iCE + 8-pixel font +
  square pixels, what `SauceRecord$` writes). Leave it clear and an editor honours it literally: it
  drops the bit and renders every bright background as its **dim twin**, so the yellow halls read as
  brown islands and a mask's teal level 6 reads as level 7's bright cyan — the file is silently
  wrong in the one tool used to hand-edit it, while the game (whose ANSIPrint honours iCE) looks
  fine. `SauceRecord$` hardcoded TFlags to 0 for a long time, so **every** generator
  (`boardsplit`/`boardfix`/`maskgen`/`sectorgen`/`ansifix`) quietly stripped the flag back off any
  hand-fixed art. `ansilint` now reports it, and only complains when the file actually uses bright
  backgrounds.
- **Colored CLI:** all dev-mode/`--help` console output goes through `PipeCol$` (DATA.bas),
  a self-contained Mystic-BBS-style pipe-colour formatter (`|10` green = OK, `|12` red = BAD, `|14`
  yellow = WARN, `|PI` = literal `|`) — same `|NN` notation as `QB64_GJ_LIB/PIPEPRINT` but with no
  submodule dependency (keeps the plain-checkout build). Honours the `CLI_COLOR` global, which
  `dungeon.bas` clears on `NO_COLOR` (env) or a `nocolor` arg — then the codes are stripped to plain text.
- **`[~]` debug overlay & test panel** (`DrawDebug`/`DebugTestMenu`, BOARD.bas). `[~]` (or backtick)
  toggles the overlay — region/sector/chamber tints and a mouse readout (`sec:/reg:/lvl:/door→/cham:/
  dead:`); toggling **off repaints** the board (`cursor_erase`/`cursor_draw`/`DrawHUD`) so the frozen
  overlay is wiped, not left stuck. With it on, **left-click teleports** the player to any cell
  (`dbg_click_armed` debounces so one press = one jump), and **`[0]` opens `DebugTestMenu`** — a modal
  cheat panel for fast playtesting: spawn a curio (`DoCurio`) / wandering monster (`WanderEncounter`) /
  trap (`SpringTrap`), grant all items + Level Key, +potions, heal full, +5000 gold, reveal all secret
  doors, or set up win-ready state. It calls the real gameplay hooks so the test path exercises the
  same code as play.
- **`scratchpads/`** — the active workshop. The prototypes `dungeon.bas` was built from
  live here (`TEST-MOVEMENT-MAP.bas` = movement/collision; `TEST-MENU.bas` = animated ANSI
  menu; `wip.bas` = intro→board flow). `const.bas` / `types.bas` hold shared CONSTs and
  TYPEs pulled in via `'$INCLUDE`. `scratchpads/shots/` holds the capture harness.
- **`engine/` / `game/` / `include/`** — the module bodies `'$INCLUDE`'d by `dungeon.bas`, sorted
  into a reusable **`engine/`** (`ENGINE.BI` header + `BOARD` / `CURSOR` / `MUSIC` / `JUICE` /
  `GESTURE` / `STATS` / `DATA` (game-free reader) / `PLAYERS` / `UI` (fades + UI primitives + sound +
  the dice subsystem) / `ARTPACK` (pixel-art load/fit/pack) / `SAVEIO` (save plumbing) / `MARKDOWN`
  (md→text renderer) / `TEXT` (string utils)), a swappable **`game/`** (`GAME.BI` header + `HOOKS` /
  `OVERLAYS` (board overlays + render hooks) / `LOADERS` / `CHAMBERS` (named-hall detection) /
  `MANIFEST` (audio manifest + SFX roster) / `DEBUG` (`[~]` overlay + `[0]` cheat panel) /
  `PLAYERS` (hot-seat seats) /
  `COMBAT` (combat/treasure) / `PLAY` (drops/loiter/encounters/search/doors) / `MENU` (screens +
  char-gen + HUD) / `SPRITES` (entity→sprite + manifests) / `SECTOR` / `SOLO` / `FLAVOR` / `CTEXT` /
  `CURIO` / `EFFECTS` / `SAVEGAME` / `CHRONICLE` / `LORDS`). `dungeon.bas` is now a thin assembly
  (setup + state machine + `PlayGame` + the `$INCLUDE` block). The vendored `ansi/` renderer, the
  `DICE3D/` module and its `DICE3D_GAME` presentation layer now live under **`engine/`**, so that
  directory is self-contained on disk; `include/` holds only the `Toolbox64` / `QB64_GJ_LIB`
  reference submodules, **not** compiled.
  **`engine/` names no `game/` symbol** — every engine→game call goes through one of 11 `Game_*`
  hooks, enforced by `tests/audit-boundary.sh`, and `examples/minimal` is a second game on
  `engine/` alone that proves it.
  **[engine/ENGINE.md](engine/ENGINE.md) is the authority** (layout, the `Game_*` hook contract, and
  the record of how each boundary leak was closed).
- **`assets/ansi/`** — the game's actual graphics: `.ans`/`.icy`/`.xb` text-mode art,
  including the board, menu pieces, and monsters. These are content, not decoration —
  the board art is also the collision map.
- **`assets/music/`** — `.rad` (Reality Adlib Tracker) tracks played via `_SNDOPEN`.
  **Audio packs** (MUSIC.bas): a *sub-folder* of `assets/sfx/` or `assets/music/` is a "theme"
  the player picks in SETTINGS (**SFX Pack** / **Music Pack**, `opt_sfxpack`/`opt_musicpack`,
  persisted as strings). `ScanAllPacks` (startup + on SETTINGS open) enumerates subdirs via
  `_FILES$` in two passes (collect names, then keep those with ≥1 audio file — so junk like a
  `bitwig/` project dir is skipped) into `SFXPACKS()`/`MUSICPACKS()`; index 0 = `(main)` = the
  flat dir. `RegisterSfx`/`ResolveMusic$` try the selected pack dir first and **fall back to the
  flat dir** per file, so a partial pack overrides only what it ships. Cycling a pack reloads SFX
  (`ReloadSfxPack`) or re-resolves the current track immediately. A saved pack whose folder has
  since vanished falls back to `(main)` (validated in `ScanAllPacks`). **Art packs** (SPRITES.bas,
  `opt_artpack`, SETTINGS **Art Pack** row): a sub-folder of `assets/pixel-art/` that MIRRORS the
  category layout (`monsters/`, `treasures/`, …) is a visual theme; `ArtFile$(subpath)` resolves the
  pack dir first then the flat main dir per sprite (so a partial pack overrides only what it ships),
  and every sprite path (`MonsterSprite$`/`TreasureSprite$`/`ClassSprite$`/`LocationSprite$`/
  `SpecialSprite$`/`CurioSprite$`) routes through it. `ScanArtPacks` enumerates subdirs that AREN'T a
  known category (`IsArtCategory%`); sprites resolve on demand so switching packs needs no reload.
  **Narration** is a THIRD
  pack type (`assets/narration/`, `opt_narration`/`opt_narrationpack`, one SETTINGS row cycling
  *off → (main) → packs* via `CycleNarration`): spoken audio named after a **`strings.txt` key**
  (`Narrate "win.title"` plays `assets/narration/[pack]/win.title.<ext>`), load-on-demand, one line
  at a time, volume off Voice Vol — silent if absent (the typewriter blips still cover it). **Any
  narratable text is hooked** via `HasNarration%`/`NarrateStop` + a stable key: end screens
  (`win.title`/`lose.title`), the intro crawl (`intro.descent`), ambient one-liners (`FlavorLineVO`,
  `regular.<lvl>.<idx>`), named rooms (`ScrollTextArt`→`room.<slug>`), chambers
  (`chamber.<slug>`, description from **`assets/flavor/chambers.txt`** via `ChamberDesc$`), and curios
  (`curio.<kind>`). `NarrSlug$` normalises a name to a key; when a crawl is narrated its per-glyph
  blips are muted so the voice carries it. Add `Narrate "<key>"` at any other text site to voice it.
  **Music CUES** (`PlayCue`/`EndCue`, `music_cue_active`): non-level tracks that temporarily override
  the level music — `victory`/`lose` (one screen) and `combat-low`/`combat-high`/`combat-intense`
  (`CombatCueName$` by level/boss, looped through a D&D fight, `EndCue` restores the level track).
  `PlayCue` is a no-op when the cue file is absent, so cues never cut to silence.
- **Sound routing / themeability.** Every distinct sound goes through the `Sfx` dispatcher (file if a
  pack/flat sample exists, else a hand-tuned `Tone` beeper fallback), so ALL are pack-overridable.
  Two helpers keep animation audio themeable without losing the crafted fallback: `SfxOr(nm, freq,
  dur)` plays sample `nm` if loaded else `Tone freq,dur` (used for the dice-sum ticks
  `dice-math-1`/`dice-math-2`), and `DiceAnimSfx(f, settle, ...)` fires `diceroll` on the throw /
  `diceland` on the settle and only beeps the per-frame tumble rattle when no `diceroll` sample is
  loaded. `VoiceBlip` likewise prefers a `voice` sample over the PC-speaker tone. The only
  procedural-by-design sounds are the per-frame tumble texture and per-glyph blips — both overridden
  by a sample when present.
- **`assets/data/`** — the editable **content database**: pipe-delimited `.txt` files,
  loaded at launch by **`include/DATA.bas`** into the same shared tables the old hard-coded
  `Init*` routines used. **DATA PACKS:** every file now lives under a named pack subfolder — the
  base game is **`assets/data/default/`** + **`assets/flavor/default/`**. `DataPath$` (DATA.bas)
  rewrites each `"assets/data/<f>"`/`"assets/flavor/<f>"` load through the SETTINGS **Data Pack**
  (`opt_datapack`, default `default`): the selected pack is tried first, **per-file**, falling back
  to `default/` — so a *partial* pack overrides only the tables/flavor it ships. A pack IS a whole
  game (swap monsters/treasures/tuning/classes/strings + flavor prose). It applies on the **next
  launch** (data loads once at startup, like the ANSI board pack); `ScanDataPacks` enumerates
  `assets/data/` subdirs, `CycleDataPack` switches, persisted as `datapack`. The two funnels
  `ReadDataFile`/`ParseFlavorFile` both route through `DataPath$`, so the file names below are the
  *logical* paths (physically under `default/`). `DATA.bas` is the shared reader: `ReadDataFile(path)` fills `DLINE()`
  and `DField$(ln, n)` returns field `n` (**trimmed**, so columns can be space-padded; `#` =
  comment; blank lines ignored), plus helpers `HexRGB~&`, `SGRForColor$`/`SGRBgForColor$` (colour
  → ANSI SGR, used by the mask generators), `SauceRecord$`, and `MaskNormalize$` (see the mask
  gotcha below). Almost every `Init*` is now a
  thin wrapper over a `Load*` sub:
  - **Content:** `monsters` / `treasures` / `items` / `bosses` / `curios` / `traps` / `effects`
    (via `Mob`/`SetTreSlot`/`SetItem`/`AddFX`, `LoadTraps` → `TRAPS()`). `InitMonsterTables` /
    `InitEffects` are the wrappers.
  - **Board layout:** `sectors.txt` (`id|label|col1|row1|col2|row2|RRGGBB` → `LoadSectors`, the
    fallback rects + level colours) and `labels.txt` (`col|row|text`, 0-based → `LoadLabels`).
  - **Tuning & presentation:** `tuning.txt` (`KEY|value` balance knobs → `LoadTuning`, filling
    the `DIM SHARED … AS INTEGER` globals that used to be `CONST`s — potion %, treasure odds,
    idle/wander/XP timers, `MOVE_MAX`…), `classes.txt` (→ `LoadClasses`, the four `PCLASS`
    records), `dice-colors.txt` (`id|name|body|ink` → `LoadDiceColors`, filling `DICE_BODY/INK/
    CNAME()` that `DiceColors`/`ColorName$` read), and `strings.txt` (`key|text`, **split on the
    FIRST `|`** → `LoadStrings`; `Say$("key")` looks one up and returns the **key itself** if
    missing, so untranslated text is visible not blank — migration is incremental).
  Edit a file, press F5 — no code change needed to rebalance. Trap *mechanics*
  (poison/bomb/frost/siren) stay in code, keyed by each row's `kind`; everything else about a
  trap (name, save stat, dice, messages) is data. Room/combat prose lives in the sibling **`assets/flavor/`** files: `regular`/
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

[PLANS.todo](plans/PLANS.todo) (todo.txt/@done format) is the roadmap and the source of truth
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
the pristine board. The cursor `_PUTIMAGE`s a clean copy back to erase, so the cursor's own
pixels can't be mistaken for terrain.

**Board LAYERS — display and collision are separate images.** The art is both the picture and
the collision map, which used to force every painted cell to mean something to movement.
`BuildBoardImages` (engine/BOARD.bas) renders two pristine images from
`assets/ansi-art/<pack>/`:

| | |
|---|---|
| `FULL_COLLIDE` | **layer-0** alone (`layer-0-board-collisions.ans`) — walkable colours, nothing else |
| `FULL_BOARD`   | layer-0 with **layer-1** (`layer-1-board-decoration.ans`) composited over it via `_CLEARCOLOR BLACK` — what the player SEES |

`InitFog` builds `CANVAS_COPY`/`CANVAS` (display) **and** `COLLIDE_BOARD` (collision) from those,
blacking secret cells in **all three**; `RevealCell` restores all three, because a revealed door
must become *walkable*, not merely visible. Every collision read goes to a collision image —
detection scans (`DetectRooms`/`DetectDoors`/`DetectSecretDoors`/`DetectChambers`/solo pathing)
use `FULL_COLLIDE`; runtime cell samples (`InRoomNow`/`OnDoorNow`/`is_path`/`CellKind`) use
`COLLIDE_BOARD`. Erase, FOV and the label/token draws stay on `CANVAS_COPY`.

**The point is walk-over decoration**: art drawn into layer-1 reaches the display and is invisible
to collision, so painting a decoration onto a corridor cell no longer makes it a wall. Generate
the layers with **`dungeon.run boardsplit`**, which refuses to write unless layer-0 + layer-1
composites back to the source board pixel for pixel. **Fallback is per-file and lives in
`BuildBoardImages`, not in game startup** — a missing layer-0 means both images are the combined
board (the old behaviour), which is what keeps `examples/minimal` working.

Colors are exact `_RGB32` matches, so **art must use the exact palette values** the code checks.

**Sectors.** The board is divided into 9 `SECTOR`s (`SECTORS(1 TO 9)`), loaded from
`assets/data/sectors.txt` (rectangle + `kolor` + `label` per level). `SECTOR.get_by_xy`
resolves a pixel position to a sector, and the sector's color is what `in_room` matches
against — this is how "which dungeon level am I in" is derived from position + art color.
When the **sector MASK** (`board-132x50-sector-mask.ans`) is present it supersedes the rects:
`SECTOR.get_by_xy` returns `SECTORAT(cx,cy)` directly, letting levels be any shape (see the
Sector MASK bullet above).

**Room detection — the art draws in HALF CELLS, so "is this a room cell?" has three answers.**
`DetectRooms`/`FloodRoom` flood a block by sampling **one pixel** (the cell centre); movement
(`InRoomNow`/`CanMove`) demands the **whole cell** be the floor colour. The board art draws room
lips with half-block glyphs (`0xDF`/`0xDC`/`0xDD`/`0xDE`, ~975 cells) and prints the level plaques
("4th", "5th") as letters on a block of level colour — both pass the one-pixel test and fail the
whole-cell one. `CellRoomKind%` (engine/BOARD.bas) is the shared answer:

| | |
|---|---|
| `CRK_FLOOR` | every pixel is floor — the only place a monster or headstone may sit |
| `CRK_DOOR`  | floor + a door colour: walkable, but a **threshold**, not a place to stand something |
| `CRK_MIXED` | floor + anything else (a half-block's dark half, a text glyph) — **not walkable**, and that is by design: these are decorative |

`PlaceRoomMarkers` (game/SECTOR.bas) runs once after every block is flooded, caches the verdict in
`ROOMKIND()`, records `ROOM.floor_cells`, and seats each marker on the **most enclosed** plain-floor
cell (closeness to the block centre is only the tie-break) — that is what keeps graves out of
doorways. `RoomIsDecor%` (no plain floor at all) is what `RandomizeRooms` skips, since `ROOM.cells`
counts a 4-cell plaque as a room. **Verify with `dungeon.run roomlint` after ANY board-art edit.**

**Which level is the player on? — `PlayerLevel%` (game/SECTOR.bas), and it is STICKY.**
A coloured room cell states its own level; a yellow **corridor** cell does not, so it only has a
level if the sector mask paints one under it or a `sectors.txt` rect covers it. 91 of the board's
3156 walkable cells satisfy neither, though **none are currently reachable** (`dungeon.run
sectorauto`; it is the logo's yellow fill, sealed off). An unclaimed cell answers `0` —
not a level: the HUD read "LEVEL 0", `PlayLevelMusic` had no track, and a wandering monster there
had no depth. `PlayerLevel%` resolves normally, **remembers every success**, and returns the last
known level when the lookup fails — so an unclaimed corridor carries the level you walked in from.

- The mask and the rects stay exactly as authoritative as before; this only fills their gaps.
- **`sectors.txt` is 0-BASED**, like every other cell coordinate here (the mask, `ROOMAT`,
  `CHAMBERAT`, `chambers.txt`, the `[~]` readout). The rect fallback used to subtract 1, treating
  it as 1-based, which shifted every rectangle one cell LEFT of the region it names — the tell is
  level 9, whose `end_x` (78) *is* its art's rightmost column, so the rect stopped one short of
  its own rooms and that column resolved to level 7. **Fixed**; it also closed the last reachable
  hole (cell 40, between level 2 ending at 40 and level 1 starting at 42). Room detection is
  unchanged at 82 rooms — the mask supersedes the rects nearly everywhere, which is why nobody
  noticed for so long.
- `SECTOR.get_by_xy` stays **pure** — the board build, the FOV caster and the debug mouse readout
  ask it about arbitrary cells with no player in existence. The stickiness lives at the player,
  never in the lookup. All ten `SECTOR.get_by_xy(c.x, c.y)` call sites now go through `PlayerLevel%`.
- `LoadActivePlayer` calls `SeedPlayerLevel` so a hot-seat seat cannot inherit the previous
  player's depth. Not saved — it self-heals from position.
- **Consequence:** walk out of level 9 into an unclaimed corridor and a wanderer there is a level
  **9** monster. You dragged the depth out with you.

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
