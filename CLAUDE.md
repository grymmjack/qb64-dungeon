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
- **`audit-dumps.sh`** — the `[`]` dev console's DUMP REGISTRY, checked in all three directions:
  topic `foo` ⇄ `SUB Dump_Foo` ⇄ a `RegisterDump` line ⇄ a dispatch `CASE`. The missing-`CASE` case
  is the dangerous one — QB64 parses a call to an undefined SUB as a **label** and silently never
  runs it. Convention: `Dump_X` (underscore) declares a topic; `DumpX` is a private helper.
- **`audit-mute.sh`** — can any sound escape a headless run? `audio_muted` gated every *sample*
  path, but `SOUND` is a QB64 statement rather than a call into the audio layer, so raw uses
  bypassed it entirely and blipped the PC speaker at whoever ran the gate. Raw `SOUND` is allowed
  only where the mute is provably applied (`Tone`, `VoiceBlip`, and DICE3D's physics — gated at
  the call site via `cfg.SOUND_ENABLED`), **and** those sites must still actually check it.
- **`dungeon.run datalint`** — validates the ACTIVE data pack's content tables: item drop odds vs
  pool contents, unhandled item codes, chamber-event kinds with no mechanic, unwinnable class goals.
- **`dungeon.run settingsshot`** — renders SETTINGS to PNG **and** fails if any live option id was
  never given a column and a row by `BuildSetLayout`. An unplaced id simply does not draw: no
  error, the screen looks normal, one row is missing. That is exactly how three rows vanished when
  the id space outgrew `SL_COL`/`SL_ROW`/`SORD`'s hardcoded 64 (now sized from `SETOPT_MAX`).
  Retired ids are listed in `SetIdRetired%` so a genuine loss still fails.
- **`dungeon.run statroll [n]`** — samples every ability-roll METHOD and checks its true range,
  plus that the animated path and the no-animation `[Shift-R]` twin are the SAME distribution. A
  method is two claims — how it LOOKS and what it PRODUCES — and "3d6 re-roll 1s & 2s" once
  shipped as `3d4+6`: identical maths (a d6 re-rolling 1s and 2s *is* a uniform 3–6), visibly the
  wrong dice on screen, and nothing in the gate could tell. `creatorshot` now shoots the ROLL
  screen (`creatorshot-roll.png`) as well as the point-buy editor, which is the other half.
- **`dungeon.run ruleslint`** — the rules screen's GENERATED sections (the live "your game, right
  now" table and the ability reference built from `stats.txt`) exist in no file on disk, so nothing
  else can see them. An empty ability section — what a missing/renamed `stats.txt` looks like from
  the player's side — fails rather than quietly saying less.
- **`dungeon.run fogdump`** — VERDICTS on secret-mask reachability. A hand-painted region that no
  door opens is unreachable forever, and killing the monster in `key_room` is the ONLY way to get
  the Level Key, so an art edit could otherwise strand it and make runs quietly unwinnable.
- **`dungeon.run savetest`** — save/load round-trip of the positional token stream (hot-seat seat
  isolation, 4-seat round-trip incl. names with spaces, chamber progress), plus a read-only load
  of a COPY of the player's real save to prove a format bump has not orphaned it.
- **`examples/minimal`** — builds + selftests a second game on `engine/` alone, proving the engine
  carries no hidden DUNGEON! dependency.

Also useful, not in the gate:

- **`dungeon.run rollshot`** also reconciles each dice style's published per-die faces
  (`DIE_FACE`/`PublishFaces`) against its own returned total. Combat initiative throws two d20s in
  ONE animation and reads them apart, so a renderer publishing nothing would decide every fight's
  turn order from zeroes with nothing on screen looking wrong.
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
- **Sector geometry is DERIVED from the board art** — no authored rectangles, no painted mask.
  `DeriveSectors` (game/SECTOR.bas, called first thing in `Game_PopulateBoard`) takes the tight
  bounding box of every cell painted uniformly in a level's colour, then **expands each box a row
  or column at a time until it meets a neighbour or the board edge** — that expansion is what
  claims the corridors, which state no colour of their own. It fills `SECTORAT(cx,cy)` and
  overwrites `SECTORS().start_x/…`; `SECTOR.get_by_xy` is then a straight `SECTORAT` lookup with
  no fallback. **The art always wins**: after the boxes land, any cell actually painted a level
  colour is reassigned to that level, so levels can be any shape. It samples **`FULL_COLLIDE`** —
  over the display board the logo, legend and frame all paint in level colours and the derivation
  fails 15 ways; over the collision layer it is clean, 9/9, no overlaps (`dungeon.run sectorauto`).
  `sectors.txt` now supplies only **id | label | colour** (its col/row columns are ignored but kept
  so existing data packs parse), and both `board-132x50-sector-mask.ans` and the `sectorgen` dev
  mode are **retired**. Three files used to say where a level is; when the copies disagreed with
  the art, 12 rooms painted at level 5/6 sat under a mask claiming level 1 and never existed.

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
- **`[`]` DEV CONSOLE + the DUMP REGISTRY** (`engine/CONSOLE.bas`, `engine/TELEMETRY.bas`,
  `game/DUMP.bas`). A Quake-style drop-down opened by **backtick from ANY screen** — menus,
  dialogs, the dice tumble, mid-fade. That works because its hotkey is polled in **`Present`**,
  this game's one per-frame chokepoint: there is no main loop, there are ~40 nested blocking loops,
  and the long note in `engine/UI.bas` already settled the same argument for `_RESIZE`. It polls
  **`_KEYDOWN`, not `INKEY$`**, so it never steals a keypress from the loop that owns the screen,
  and it **photographs `CANVAS` on open and restores it on close**, so it works over screens it
  knows nothing about. Type `dump` for the topic list, or a topic name directly.
  **The registry is the point**: a dump is not a one-off, it is
  `topic foo` ⇄ `SUB Dump_Foo` ⇄ a `RegisterDump` line ⇄ a dispatch `CASE`, all four enforced by
  `tests/audit-dumps.sh`. Engine topics (`summary audio music sfx narration images vars sounds`)
  live in `CONSOLE.bas`; game topics (`game character map monster`) live in `game/DUMP.bas` behind
  the `Game_RegisterDumps` / `Game_DevDump%` hook pair, so `engine/` still names no game symbol.
  **TELEMETRY is recorded at the CHOKEPOINTS, never at call sites** — `Sfx`, `Narrate`,
  `BeginTrack` and `DrawSpriteFit%` each log one line, so a feature added later is covered without
  anyone remembering. It is a separate dependency-free module because `TEST-ARTPACK` compiles
  `ARTPACK.bas` in isolation and a one-line log call would otherwise drag the whole console in.
- **`[TAB]` / `[Shift-TAB]` overlay** — `[TAB]` shows/hides the overlay box; `[Shift-TAB]` swaps it
  between **RUN STATS** and **BEARINGS** (`DrawBearingsOverlay`, game/DUMP.bas): what music / sfx /
  narration / art is playing or drawn *with full resolved paths* and the beeper fallback marked as
  such, plus level, cell, room and chamber. It reads the same telemetry rings the console does, so
  the two views can never disagree.
- **`[~]` debug overlay & test panel** (`DrawDebug`/`DebugTestMenu`, BOARD.bas). `[~]` **only** —
  backtick is the dev console now.  `[~]`
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
  (md→text renderer) / `TEXT` (string utils) / `CONSOLE` (the `[`]` dev console + dump registry) /
  `TELEMETRY` (what is playing/showing, logged at the chokepoints)), a swappable **`game/`**
  (`GAME.BI` header + `HOOKS` /
  `OVERLAYS` (board overlays + render hooks) / `LOADERS` / `CHAMBERS` (named-hall detection) /
  `MANIFEST` (audio manifest + SFX roster) / `DEBUG` (`[~]` overlay + `[0]` cheat panel) /
  `PLAYERS` (hot-seat seats) /
  `COMBAT` (combat/treasure) / `DUMP` (game dump topics + the bearings overlay) / `PLAY`
  (drops/loiter/encounters/search/doors) / `MENU` (screens +
  char-gen + HUD) / `SPRITES` (entity→sprite + manifests) / `SECTOR` / `SOLO` / `FLAVOR` / `CTEXT` /
  `CURIO` / `EFFECTS` / `SAVEGAME` / `CHRONICLE` / `LORDS`). `dungeon.bas` is now a thin assembly
  (setup + state machine + `PlayGame` + the `$INCLUDE` block). The vendored `ansi/` renderer, the
  `DICE3D/` module and its `DICE3D_GAME` presentation layer now live under **`engine/`**, so that
  directory is self-contained on disk; `include/` holds only the `Toolbox64` / `QB64_GJ_LIB`
  reference submodules, **not** compiled.
  **`engine/` names no `game/` symbol** — every engine→game call goes through one of 14 `Game_*`
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
  **Which FORMAT wins** is two settings, not one: **Audio Format** (`opt_audiopref`) is the
  inherited order every category follows, and **Music / SFX / Voice Format** (`opt_fmt_music` /
  `opt_fmt_sfx` / `opt_fmt_narr`) override it per category. The model is **override-THEN-inherit,
  never a hard filter** — the explicit choice is tried first and the inherited ladder still runs
  behind it, so picking FLAC for music does not silence a pack that only ships `.ogg`. Music can
  also prefer **trackers** (a different kind of asset, not a container choice) and SFX can pick the
  **PC speaker**, which resolves to an empty ladder so every effect falls through to its hand-tuned
  `Tone`. All three resolvers (`OpenSfx&` / `ResolveMusicIn$` / `FirstAudioFile$`) build their
  extension list from one `AudioLadder`, so the categories cannot drift apart.
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
- **NOTHING calls `_SNDCLOSE` directly — it calls `RetireSound`.** `_SNDOPEN` hangs a node on
  miniaudio's mixing graph that a **device thread** walks every buffer callback; `_SNDCLOSE` frees
  that node from the game thread, and freeing one the mixer is mid-read of corrupts the heap. With
  13 music packs on disk, walking the SETTINGS Music Pack row ran `_SNDCLOSE` + `_SNDOPEN` at
  key-repeat rate — always inside the 2.5s crossfade, with the outgoing track still audible — and
  aborted a real session with `double free or corruption (fasttop)` behind a GLX `BadAccess` (the
  render thread simply drew the next bad pointer). Same class as the `SYSTEM`-teardown race
  documented in `OpenSfx&`. `RetireSound` **silences and stops** a handle at once (writes to a node
  the mixer owns are benign; only the FREE is fatal) and parks it; `ReapSounds`, called from
  `AudioTick`, frees it once it is both old enough (`SND_RETIRE_SEC`) and no longer playing, with a
  hard cap (`SND_RETIRE_CAP_SEC`) so a handle whose `_SNDPLAYING` never settles cannot pin decoded
  audio forever. `dump sounds` shows the queue — one that never drains is a bug.
- **A headless run must be SILENT, and `audio_muted` is not enough on its own.** Every *sample*
  path checks it, but `SOUND` is a QB64 **statement**, not a call into the audio layer, so a raw
  `SOUND` bypasses the mute completely. That is how the DICE3D per-bounce clicks and `VoiceBlip`'s
  typewriter fallback blipped the PC speaker at whoever ran the gate. `tests/audit-mute.sh` is the
  rule: raw `SOUND` only where the mute is provably applied — and those sites must still check it.
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
- **THEME — named presentation colours** (`assets/data/<pack>/theme/colors.txt`, `LoadTheme`/`Thm~&`
  in `engine/DATA.bas`). `key | RRGGBB` (or `RRGGBBAA`). Every call site passes its own fallback —
  `Thm~&("ui.red", _RGB32(&HFF,&H55,&H55))` — so a missing file, missing key or bad value all mean
  "leave that colour exactly as it is", the same *missing means unchanged* rule `Say$` uses. That
  is what makes converting the codebase safe **one file at a time**, and it means a pack can
  restyle three colours and stay silent about the other hundred.
  **The board colours are deliberately NOT themeable.** `YELLOW`/`BROWN`/`BRIGHT_BLUE`/`BLACK` are
  not ink, they are **collision values**: the art IS the collision map and `BOARD.bas` asks
  `POINT(...) = BROWN` to decide what a cell is. Recolouring them from a theme would not restyle
  the game, it would stop doors being doors while everything still looked right. They belong to
  the ANSI-ART pack that ships the art they must match, and `ThemeReserved%` refuses `board.*` keys.
  Dice body/ink are excluded too — those are a player SETTING with its own palettes.
  **`dungeon.run themelint`** (gated) lists every key, proves the file is actually being read (it
  asks for a known key with a fallback the file could never return), and confirms the board names
  are still reserved — because a misspelt key does not fail, it silently keeps the built-in colour
  and the pack author sees no change at all. `dump theme` shows the same live, marking which keys
  have actually been asked for.
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

- **PLACEHOLDER ART is detected by CONTENT, not by a list** (`ArtLooksPlaceholder%`, engine/ARTPACK.bas).
  A stand-in is a *file*, so every "does the asset exist" check says yes, the generator skips it,
  and the game happily draws it — the art looks missing while every audit reports 0 missing.
  `assets/PLACEHOLDERS.txt` records them as `path|bytes` and retires an entry when the size
  changes, which is right but not sufficient: the list was **emptied once** on the belief the work
  was done, and three stand-ins then audited as finished permanently. Counting distinct opaque
  colours needs no bookkeeping — the placeholder tool draws a box, a diagonal and a caption (4
  colours) while the sparsest real art here uses 23, so the `ART_PLACEHOLDER_COLORS = 8` threshold
  sits in a wide gap rather than between two close numbers. `RealAssetAt%` consults both, so
  **`dungeon.run imagemanifest audit`** lists a placeholder as still-to-make.

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

**Half-block ISLANDS are trim, and `boardsplit` drops them from layer-0.** The level plaques are
drawn with little half-block flourishes painted in a level colour, so the "contains a collision
colour" rule would file them as collision — where they mean nothing, since nothing can stand on
them and nothing connects to them. Colour cannot tell trim from a structural room lip, but
**neighbours can**: a real lip always touches the room it edges, so a half block with nothing
painted around it in the collision layer is decoration (13 of them). They are marked in full
*before* any are moved — moving as you scan lets one removal blank the neighbour that made the
next cell non-island, making the result scan-order dependent.

`PlaceRoomMarkers` (game/SECTOR.bas) runs once after every block is flooded, caches the verdict in
`ROOMKIND()`, records `ROOM.floor_cells`, and seats each marker on the **most enclosed** plain-floor
cell (closeness to the block centre is only the tie-break) — that is what keeps graves out of
doorways. `RoomIsDecor%` (no plain floor at all) is what `RandomizeRooms` skips, since `ROOM.cells`
counts a 4-cell plaque as a room. **Verify with `dungeon.run roomlint` after ANY board-art edit.**

**Room detection reads the ART, not geometry.** `DetectRooms` seeds a block wherever a cell is
painted one of the nine level colours and takes the room's level **from that colour**;
`RoomVisit` floods by colour alone. It used to ask `SECTOR.get_by_xy` first and require the
paint to agree — and where the two files disagreed (art said level 5, the mask said level 1) the
room simply never existed: 12 **LOST ROOMS**, 38 visible, door-connected floor cells that were
unreachable forever. Likewise `Game_FloorColorAt~&` now **reads the cell's own pixel** and
returns it if the game knows it as a floor colour. **Gotcha:** that hook samples `_SOURCE`, and
`CanMove`/`InRoomNow` reach the board by `_PUTIMAGE` rather than `_SOURCE` — both pin
`_SOURCE COLLIDE_BOARD` around the call, or the answer comes from whatever image the previous
caller happened to leave selected. Verify with `dungeon.run roomlint` ("no lost rooms").

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
- **HELD DICE — a PARTIAL re-roll** (`RollHoldSet`/`RollHoldClear`/`RollHeld%` in `engine/UI.bas`,
  `dice3d_hold` in the DICE3D module). A die can be pinned for the next roll: it keeps the seat
  and the face it had, sits out the physics, and is not re-read; the rest of the tray tumbles
  around it. All three renderers honour it (pips, font polyhedra, 3D), and `AnimatedRoll%` clears
  the pins afterwards so a renderer that ignores them cannot leave them armed. This is what makes
  "3d6, **re-roll 1s**" / "**re-roll 1s and 2s**" (`RollRerollLow%`, the `STAT_3D6RR1`/`STAT_3D6RR2` methods, which HIT POINTS follow too, capped by SETTINGS **Re-roll Tries**) look like the rule
  it is: three dice stay on the table and only the low ones are thrown again. It shipped twice
  wrong first — as `3d4+6` (exact maths, nonsense picture) and then as a fresh tray holding only
  the low dice (right maths, the kept dice vanish) — so `rollshot` now asserts that a pinned die
  comes back with the face it was pinned to **and on the same seat**, in every style.
  A multi-pass roll must also be wrapped in **`RollSeqBegin`/`RollSeqEnd`**: each pass is its own
  call into the roller, and each call photographs the screen, draws its tray and puts the
  photograph BACK — so the tray and every die on it vanished between passes and were rebuilt.
  Even with the seats pinned, a box blinking out and back reads as the dice being thrown around.
  Inside a sequence the snapshot is taken once and restored once, so only the dice change.
  **Contact response**: `dice3d_separate` used to resolve overlaps by teleporting dice apart with
  no velocity change at all, so a die *slid* off its neighbour. It now applies an equal-mass
  impulse along the contact normal plus a spin kick, with a held die treated as **infinite mass**
  — it absorbs nothing and gives the whole rebound back, which is what "it does not budge" has to
  mean physically as well as positionally. Separation also **relaxes** (`DICE3D_SEP_PASSES`): the
  tray is barely taller than one die, so dice cannot slip past each other vertically and
  separation is effectively 1-D — one pass leaves an out-of-order pair overlapping. And
  `dice3d_place_free` gives a die being re-thrown a start position clear of the pinned ones,
  because a die dropped onto a held neighbour can end up **wedged** between two of them with
  nowhere to go.
- **Dice are painter-sorted against EACH OTHER** (`dice3d_depth_order`), not just internally. Each
  die already sorted its own triangles — correct within a convex die — but nothing ordered die
  against die, so they drew in array order and a later die always covered an earlier one whichever
  was actually nearer. A die rolling past a resting one appeared to pass straight **through** it.
  Depth is `PY` (positions map 1:1 to the top-down box; `PZ` only lifts a die up-screen).
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
- **`AND` / `OR` never short-circuit — but `_ANDALSO` / `_ORELSE` DO.** `IF n > 0 AND ROOMS(n).x`
  still reads `ROOMS(0)`; with `$CHECKING:ON` that is a hard `Subscript out of range`. QB64PE now
  provides short-circuiting operators, **verified in this repo's compiler**:

  | with `n = 0` | |
  |---|---|
  | `IF n > 0 _ANDALSO a(n) = 11` | survives — right side skipped |
  | `IF n = 0 _ORELSE a(n) = 11`  | survives — right side skipped |
  | `IF n > 0 AND a(n) = 11`      | **`Subscript out of range`** |

  So a bounds guard or a side-effecting call (a die roll!) can now be written on one line with
  `_ANDALSO`, instead of nesting `IF`s. `tests/audit-shortcircuit.sh` still flags plain `AND`/`OR`
  guards — nesting and `_ANDALSO` are both valid fixes. Existing nested `IF`s are correct as-is;
  there is no need to churn them.
- **Gotcha:** single-line `IF` does not support `ELSEIF` / `ELSE IF` chains, and `LINE`, `SEG`,
  `VAL`, `CLS` are reserved words that can't be used as variable names.
- **Gotcha:** relative paths resolve against the **executable's** directory, not the shell's cwd
  — QB64PE chdirs to the binary at startup (`_CWD$` = the exe's dir, `_STARTDIR$` = where it was
  launched). That is *why* `dungeon.run` must sit at the repo root for `assets/...` to resolve;
  a test binary built into `scratchpads/` silently fails every `_FILEEXISTS`/`_LOADFONT`.
- **A runtime error must NEVER open a dialog.** An unhandled QB64 error pops a modal message box
  (`Line: 165 ... File not found / Continue? [Yes] [No]`) and waits for a **click** — under
  `xvfb` (every dev mode, every gate run, every capture) nobody can click it, so the process
  hangs with no output saying why. `dungeon.bas` arms **`ON ERROR GOTO DungeonFatal`** before
  anything can fail, and the handler branches on **`screen_shown`**, not on the curated
  `devmode` list:
  - **no window up** → print `!! QB64 RUNTIME ERROR <n> at line <l>` + `_ERRORMESSAGE$`, then
    `SYSTEM 1`. Greppable, non-zero, instant — a script can act on it.
  - **window up (a human is playing)** → `RESUME NEXT`, so one missing optional asset does not
    end someone's run. Capped at `ERR_MAX` so an error inside the 60fps loop still aborts.

  `screen_shown` (set at `_SCREENSHOW`) is the test because "is a human looking at a window" is
  the actual question; a list of mode names silently rots every time a dev mode is added.
- **Headless verification:** `$CONSOLE:ONLY` turns a throwaway `.bas` into a stdout tool
  (`PRINT` goes to the terminal), which beats screenshotting for checking things like font
  handles, file paths, or computed values.

## Line endings (enforced via .gitattributes)

- Everything is LF **except `**/*.ans`, which are CRLF** — ANSI art relies on CRLF; do
  not normalize it.
- `.bas`/`.bi`/`.bm`/`.frm` are tagged `linguist-language=qb64` so GitHub classifies them
  correctly.
