# The engine / game split

This repo is being refactored from *"a game with a lot of reusable machinery"* into a
**reusable engine** (`engine/`) + a **swappable game** (`game/`), per
[PLANS.todo](../PLANS.todo). The end goal (north star) is a *separable* engine — one that
could be lifted into its own repo/submodule so the next game starts from it. This file is the
map of that boundary and the ledger of work remaining to make it real.

> **QB64 reality.** The whole program compiles as **one translation unit**: `dungeon.bas`
> `'$INCLUDE`s every module, and QB64 resolves all SUBs/FUNCTIONs and `DIM SHARED` globals
> globally. So the engine/game split is **organizational + conventional**, not enforced by a
> linker. A "hook" is just a well-named SUB the engine calls and the game defines. Separability
> is enforced by discipline (engine code names no game symbol except a `Game_*` hook; the engine
> header declares no game data) and tracked by the **debt ledger** below — not by the compiler.

## Layout

```
dungeon.bas          thin assembly: screen/CLI setup + state machine + PlayGame + $INCLUDE block
engine/
  ENGINE.BI          reusable globals/types/consts (loaded FIRST)
  ENGINE.md          this file
  ansi/  DICE3D/      vendored ANSI renderer + 3D dice (logically engine; still under include/)
  BOARD CURSOR MUSIC JUICE GESTURE STATS DATA PLAYERS   .bas modules
  UI                 presentation: fades + UI primitives + sound dispatcher + dice subsystem
  ARTPACK            pixel-art layer: load/cache/fit sprites + art-pack resolution
  SAVEIO             save-file plumbing (HasSave/DeleteSave/AskContinue/TokLoad/Next*)
  MARKDOWN           markdown -> text-mode renderer (was inside CHRONICLE)
  TEXT               reusable string/format utils (PadR$/NthField$/MMSS$)
game/
  GAME.BI            DUNGEON!-specific globals/types/consts (loaded AFTER ENGINE.BI)
  HOOKS.bas          the game side of the engine<->game contract
  LOADERS.bas        game data-table loaders (Load*), moved out of engine/DATA.bas
  COMBAT PLAY        the combat/treasure system + play-loop support (drops/loiter/encounters)
  MENU               game screens: class-select, char-gen, intro, menu/settings, HUD
  SPRITES            entity->sprite mapping + popups + manifests
  SAVEGAME CHRONICLE LORDS   .bas  (save payload / per-run journal / hall of fame + settings)
  SECTOR SOLO FLAVOR CTEXT CURIO EFFECTS   .bas modules
include/             not-yet-split: DICE3D_GAME (dice glue) + the vendored ansi/ + DICE3D/ dirs
```

Header include order (top of `dungeon.bas`): **`engine/ENGINE.BI` then `game/GAME.BI`** — engine
primitives/types first; game types may build on engine ones, never the reverse.

## Header ownership (ENGINE.BI vs GAME.BI)

- **ENGINE.BI** — screen grid + canvas + palette; `CURSOR` type; dice config/fonts + tumbler
  state; audio + pack/narration/art-pack globals; engine `opt_*` (a/v, dice, FOV, char-gen,
  msgdelay, smooth…); fog/FOV + secret-door/mask detection arrays; near-death juice bake data
  (blood/vignette/poison); **active-character stat scaffolding** (`player_hp/maxhp`, ability
  scores, derived to-hit/ac/dmg); save-token stream; data-loader scratch; flood-fill queue.
- **GAME.BI** — `SECTOR`/`ROOM`/`PCLASS`/`PLAYER`/`CURIO_T`/`FXROW`/`TRAPROW`/`EVTROW` types;
  `SECTORS`/`ROOMS` + monster/treasure/item pools; inventory + spell charges + Level Key;
  Dungeon! tuning; chambers; solo/hunt state; **ruleset switches** (`opt_oldschool`,
  `opt_boardgame`, `opt_movedice`, `MOVE_MAX`, `opt_lootrecovery`, `opt_maxdeaths`); flavor
  arrays; `FX_*` combat context; the per-run chronicle tallies.

## The engine ↔ game contract (~15 hooks)

A hook is a `Game_*` SUB/FUNCTION the engine calls and `game/` implements. **2 of 15 are done;**
the rest are still inlined in the play loop / renderers and get lifted in later increments.

| # | Hook | Status | Was inlined at |
|---|------|--------|----------------|
| 1 | `Game_WinReached%()` — win predicate | ✅ done | play-loop win check |
| 2 | `Game_OnEnterCell%(cx,cy)` — movement→consequence (encounter/loot/heal/win) | ✅ done | `dungeon.bas` play loop |
| — | `Game_WinReady%()` — shared "gold+key" sub-predicate (HUD hint + #1) | ✅ done | 2 copies (loop + HUD) |
| — | `Game_PoisonLevel!()` — poison overlay intensity 0..1 (JUICE decouple) | ✅ done | `DrawPoison` read of `poison_turns` |
| 3 | `Game_Play%()` / `Game_ShowIntro` / `Game_ShowEnd(win)` — state-machine bodies | planned | `dungeon.bas` state machine |
| 4 | `Game_RunOver%()` — lose/forfeit predicate (`player_out`/`solo_result`) | planned | play loop |
| 5 | `Game_HUDText$()` / `Game_DrawHUDExtra` — HUD content injection | planned | `DrawHUD` (MENU.bas) |
| 6 | `Game_CellMarker%(rm)` — monster/body/loot/grave glyph per cell | planned | `DrawEntities`/`DrawTombstones`/`DrawChamberGraves` |
| 7 | `Game_OnRoomDiscovered(rm)` — first-entry (`RoomFlavor`+chronicle) | planned | play loop (now inside #2) |
| 8 | `Game_PopulateBoard()` — seed detected rooms (`RandomizeRooms`) | planned | after `StartBoard`/`DetectRooms` |
| 9 | `Game_ResolveEncounter%(rm)` — combat entry (`DoCombat`) | planned | `dungeon.bas` |
| 10 | `Game_MonsterAttack(rm)` — Monster Attack Table (death/gold/retreat) | planned | `dungeon.bas` |
| 11 | `Game_AwardTreasure(rm,sm)` — item table + Level Key (`ClaimTreasure`) | planned | `dungeon.bas` |
| 12 | `Game_OnStep(cx,cy)` — per-move ticks (curio/status/siren/level bonus) | planned | play loop |
| 13 | `Game_OnIdle()` — idle-danger (`LoiterTick`) | planned | play loop |
| 14 | `Game_StartTurn()`/`Game_MoveCost%()` — turn budget (boardgame/boots) | planned | play loop |
| 15 | `Game_OnEnterCleanCell(cx,cy)` — loot recovery (now inside #2) | planned | play loop |

The two indispensable ones (#1, #2) are done — they were the tightest and most central seams.

## Boundary-debt ledger (burn-down toward a separable engine)

Engine-side code that still names game symbols directly. Each line is a future hook/refactor.
"Cleared" = the leak is gone. Until all are cleared, `engine/` cannot be lifted out standalone.

**Cleared:**
- ~~JUICE ← player HP~~ — `player_hp/maxhp` moved into ENGINE.BI (engine→engine) in split B.
- ~~JUICE ← poison~~ — `DrawPoison` takes a pure `intensity` (0..1) param; the game supplies it
  via the `Game_PoisonLevel!()` hook. `engine/JUICE.bas` now names no game symbol.
- ~~DATA ← loaders~~ — `Load*` moved to `game/LOADERS.bas`; `engine/DATA.bas` is game-free.
- ~~SAVE plumbing~~ — `engine/SAVEIO.bas` (game-free) + `game/SAVEGAME.bas` (payload).
- ~~CHRONICLE md~~ — reusable md renderer lifted to `engine/MARKDOWN.bas`.
- ~~PadR$/utils~~ — moved to `engine/TEXT.bas` (engine no longer reaches into a game file).
- ~~SPRITES~~ — split `engine/ARTPACK.bas` (game-free) vs `game/SPRITES.bas` (entity sprites).
- ~~combat rules in `dungeon.bas`~~ — extracted to `game/COMBAT.bas` + `game/PLAY.bas`.
- ~~MENU presentation~~ — the fades/UI/sound/dice runtime lifted to `engine/UI.bas` (game-free).

**Remaining** (each needs a render/visual play-test, so parked for the user):

| Debt | Where (engine side) | Reads game symbol | Fix |
|------|--------------------|-------------------|-----|
| BOARD ← rooms | `engine/BOARD.bas` `DrawTombstones`/`DrawChamberGraves`/`render_room_labels` | `ROOMS`/`CHM_DEAD`/`LBL_*` | hook #6 `Game_CellMarker%` |
| BOARD debug menu | `engine/BOARD.bas` `DebugTestMenu` | calls `WanderEncounter`/`DoCurio`/`SpringTrap`/`LoiterTick` | a `Game_DebugSpawn` hook |
| region detect → game | `engine/BOARD.bas` `DetectRooms` | fills `ROOMS`/`ROOMAT` | hook #8 `Game_PopulateBoard` |
| CURSOR ← rooms | `engine/CURSOR.bas` `DrawEntities` | `ROOMS` (monster/body/loot glyphs) | hook #6 `Game_CellMarker%` |
| PLAYERS ← inventory | `engine/PLAYERS.bas` | `PLAYER` game fields | game-defined player-state blob |
| MENU widget cores | `game/MENU.bas` `RunMenu`/`RunSettings` | still fuse a generic widget with game option/action lists | widget core (engine) + game-supplied lists (MENU-B) |
| SETTINGS schema | `game/LORDS.bas` `SaveSettings`/`LoadSettings` | enumerate game `opt_*` + solo | game-injected save schema |
| `FX_*` context (fine) | `game/*` | `FX_*` | already game→game after the moves; keep in GAME.BI |

## Verifying a change

The whole point is that the game keeps working at every step:

```
qb64pe -w -x dungeon.bas -o dungeon.run          # must print "Output:", no errors
setsid timeout 8 xvfb-run -a ./dungeon.run       # must boot to the menu, no runtime error
```

For a header split, "compiles" is necessary but not sufficient (a dropped-but-unreferenced global
won't error). Prove completeness independently — e.g. strip comments and set-diff the declaration
lines against the pre-split file.
