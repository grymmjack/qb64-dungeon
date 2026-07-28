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
dungeon.bas          the assembly + state machine + play loop + (still) combat rules
engine/
  ENGINE.BI          reusable globals/types/consts (loaded FIRST)
  ENGINE.md          this file
  ansi/  DICE3D/      vendored ANSI renderer + 3D dice (logically engine; still under include/)
  BOARD CURSOR MUSIC JUICE GESTURE STATS DATA PLAYERS   .bas modules
game/
  GAME.BI            DUNGEON!-specific globals/types/consts (loaded AFTER ENGINE.BI)
  HOOKS.bas          the game side of the engine<->game contract
  SECTOR SOLO FLAVOR CTEXT CURIO EFFECTS   .bas modules
include/             not-yet-split (tangled) modules: MENU CHRONICLE SAVEGAME LORDS SPRITES
                     DICE3D_GAME, plus the vendored ansi/ + DICE3D/ dirs
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

| Debt | Where (engine side) | Reads game symbol | Fix |
|------|--------------------|-------------------|-----|
| ~~JUICE ← player HP~~ | `engine/JUICE.bas` | `player_hp/maxhp` | **cleared** in split B — moved into ENGINE.BI (now engine→engine) |
| JUICE ← poison | `engine/JUICE.bas` `DrawPoison` | `poison_turns` | pass an intensity 0..1 param |
| flavor/effects ← context | `game/*` already | `FX_*` | (already game→game after the move; keep in GAME.BI) |
| BOARD ← rooms | `engine/BOARD.bas` `DrawTombstones`/`DrawChamberGraves`/`render_room_labels` | `ROOMS`/`CHM_DEAD`/`LBL_*` | hook #6 `Game_CellMarker%` |
| region detect → game data | `engine/BOARD.bas` `DetectRooms` | fills `ROOMS`/`ROOMAT` | hook #8 `Game_PopulateBoard` |
| DATA ← loaders | `engine/DATA.bas` `Load*` wrappers | monster/treasure/trap tables | move the `Load*` payload to `game/` |
| PLAYERS ← inventory | `engine/PLAYERS.bas` | `PLAYER` game fields | game-defined player-state blob |
| MENU (still include/) | `RunMenu`/`RunSettings`/`DrawHUD`/`ShowEnd` | class/inventory/ruleset opts | widget core + game-supplied item/option/HUD lists |
| SAVE/SETTINGS (still include/) | `SaveGame`/`SaveSettings` | game `opt_*` + solo state | game-injected save schema |

## Verifying a change

The whole point is that the game keeps working at every step:

```
qb64pe -w -x dungeon.bas -o dungeon.run          # must print "Output:", no errors
setsid timeout 8 xvfb-run -a ./dungeon.run       # must boot to the menu, no runtime error
```

For a header split, "compiles" is necessary but not sufficient (a dropped-but-unreferenced global
won't error). Prove completeness independently — e.g. strip comments and set-diff the declaration
lines against the pre-split file.
