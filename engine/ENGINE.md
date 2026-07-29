# The engine / game split

This repo was refactored from *"a game with a lot of reusable machinery"* into a
**reusable engine** (`engine/`) + a **swappable game** (`game/`), per
[PLANS.todo](../plans/PLANS.todo). The goal was a *separable* engine — one that could be lifted
into its own repo/submodule so the next game starts from it. **That goal is met**: this file is
the map of the boundary, the hook contract, and the record of how each leak was closed.

> **QB64 reality.** The whole program compiles as **one translation unit**: `dungeon.bas`
> `'$INCLUDE`s every module, and QB64 resolves all SUBs/FUNCTIONs and `DIM SHARED` globals
> globally. So the engine/game split is **organizational + conventional**, not enforced by a
> linker. A "hook" is just a well-named SUB the engine calls and the game defines. Nothing stops
> a future edit from reaching straight into `ROOMS()` from `engine/` and compiling fine — which is
> why the boundary is enforced by a **script** (`tests/audit-boundary.sh`), not by good intentions.

## Status: the engine is CLEAN, and separability is PROVEN

**No file in `engine/` names a game symbol** — every engine→game reference goes through a
`Game_*` hook — and `engine/` is now **self-contained on disk**: the vendored ANSI renderer and
the DICE3D module moved in from `include/`, which is left holding only the two reference
submodules. The directory can be copied out as-is.

Separability is not just asserted: **[examples/minimal](../examples/minimal/)** is a second game,
built on `engine/` with nothing from `game/`, that walks a player around the board. It implements
all 11 hooks in ~50 lines.

> **Do not rely on "the demo stops compiling" to catch a missing hook.** A bare `Game_Foo`
> statement whose SUB is undefined parses as a **label**, not a call — it compiles clean and
> silently does nothing. That is exactly what happened when `Game_RenderHUD` was added: the demo
> kept building without it. CLAUDE.md documents this trap for *dotted* names; it applies to **any**
> name that is not a defined SUB. Two defences: never write a hook call in `NAME: statement`
> position (give it its own line), and let `tests/audit-boundary.sh` set-difference the hooks the
> engine CALLS against the ones each game DEFINES. That check is the real alarm.

```sh
tests/run-tests.sh              # everything: unit suites + both audits + the separability proof
tests/audit-boundary.sh -v      # just the boundary; -v lists offending symbols per file
./examples/minimal/minimal.run  # walk around, WASD/arrows, ESC to quit
```

> **Building the second game immediately found a real bug**, which is the argument for doing it.
> `DetectDoors` counted hits in a local named `brown`, and QB64 identifiers are case-insensitive —
> so `IF POINT(...) = BROWN` compared each pixel against the *counter* (0) instead of `AA5500`. It
> had **always** returned zero doors: `MarkStrongDoors` marked nothing, `StrongDoorAhead` always
> returned 0, and the reinforced-door feature never once fired in play. The demo's independent
> recount found 192 doors where `DetectDoors` found 0. Fixed, and `tests/audit-shadow.sh` now
> fails the build if any local shadows a high-risk global (screen metrics, cursor, palette).

## Auditing the boundary (do this before trusting any claim here)

Because no linker enforces the split, a hand-maintained ledger **drifts** — this one did, twice,
and both times the audit caught what the prose had got wrong. So the audit is a script
(`tests/audit-boundary.sh`), not a paragraph: it collects every symbol `game/` owns (each
`SUB`/`FUNCTION` in `game/*.bas`, each `DIM SHARED`/`CONST`/`TYPE` in `GAME.BI`), then intersects
that with the identifiers in each `engine/` file. Anything back — other than a `Game_*` hook — is
boundary debt. It strips comments and string literals, and filters QB64 keywords and shared type
names. It then checks **contract completeness**: every `Game_*` hook the engine calls must be
implemented by both `game/` and `examples/minimal/`.

> **Why a script, not a one-liner.** The obvious `grep '^ *DIM SHARED +\w+'` captures only the
> **first** name on a line, so `DIM SHARED num_players AS INTEGER, cur_player AS INTEGER` hides
> `cur_player` — which is exactly how this audit missed three real leaks mid-refactor. The script
> splits on commas outside parentheses (so array bounds don't confuse it) and handles the
> `DIM SHARED AS INTEGER a, b, c` prefix form.

Add it to any pre-commit check you like; it exits non-zero when the engine is dirty.

## Layout

```
dungeon.bas          thin assembly: screen/CLI setup + state machine + PlayGame + $INCLUDE block
engine/
  ENGINE.BI          reusable globals/types/consts (loaded FIRST)
  ENGINE.md          this file
  ansi/              vendored ANSI renderer (ANSI_Print) -- moved in from include/
  DICE3D/            the 3D polyhedral dice module -- moved in from include/
  DICE3D_GAME.bas    the engine's 3D-dice presentation layer (roll box, sets, previews)
  BOARD              board render, fog/FOV, secret doors + masks, pixel-colour collision
  CURSOR             movement + draw/erase
  MUSIC JUICE GESTURE DATA   .bas modules
  UI                 presentation: fades + UI primitives + sound dispatcher + dice subsystem
  ARTPACK            pixel-art layer: load/cache/fit sprites + art-pack resolution
  SAVEIO             save-file plumbing (HasSave/DeleteSave/AskContinue/TokLoad/Next*)
  STATS              append-only CSV plumbing + the schema-drift rotate guard
  MARKDOWN           markdown -> text-mode renderer (was inside CHRONICLE)
  TEXT               reusable string/format utils (PadR$/NthField$/MMSS$/StrSubst$/PackIndex%)
game/
  GAME.BI            DUNGEON!-specific globals/types/consts (loaded AFTER ENGINE.BI)
  HOOKS.bas          the game side of the engine<->game contract
  OVERLAYS.bas       board overlays (label table + tombstones/graves/entities/hunter/tokens) + render hooks
  LOADERS.bas        game data-table loaders (Load*), moved out of engine/DATA.bas
  CHAMBERS.bas       the big named halls: detect/flood/grave-seat (was in engine/BOARD.bas)
  MANIFEST.bas       audio manifest dump + Game_SfxNames$ roster (was in engine/MUSIC.bas)
  DEBUG.bas          [~] dev overlay + [0] cheat panel (was in engine/BOARD.bas)
  PLAYERS.bas        hot-seat seats: park/restore player state + turn passing (was engine/)
  COMBAT PLAY        combat/treasure + play-loop support (drops/loiter/encounters/search/doors)
  MENU               game screens: class-select, char-gen, intro, menu/settings, HUD
  SPRITES            entity->sprite mapping + popups + manifests
  SAVEGAME CHRONICLE LORDS   .bas  (save payload / per-run journal / hall of fame + settings)
  SECTOR SOLO FLAVOR CTEXT CURIO EFFECTS   .bas modules
include/             reference submodules ONLY (Toolbox64, QB64_GJ_LIB) -- not compiled
tests/               headless assert suites + the boundary/shadow audits (tests/run-tests.sh)
examples/minimal/    a SECOND game on engine/ alone -- the separability proof
```

Header include order (top of `dungeon.bas`): **`engine/ENGINE.BI` then `game/GAME.BI`** — engine
primitives/types first; game types may build on engine ones, never the reverse.

## Header ownership (ENGINE.BI vs GAME.BI)

- **ENGINE.BI** — screen grid + canvas + palette; `CURSOR` type; dice config/fonts + tumbler
  state; audio + pack/narration/art-pack globals; engine `opt_*` (a/v, dice, FOV, char-gen,
  msgdelay, smooth…); fog/FOV + secret-door/mask detection arrays; near-death juice bake data
  (blood/vignette/poison); **active-character stat scaffolding** (`player_hp/maxhp`, ability
  scores, derived to-hit/ac/dmg); save-token stream; data-loader scratch; flood-fill queue;
  `START_CX`/`START_CY` (where the cursor starts on this board).
- **GAME.BI** — `SECTOR`/`ROOM`/`PCLASS`/`PLAYER`/`CURIO_T`/`FXROW`/`TRAPROW`/`EVTROW` types;
  `SECTORS`/`ROOMS` + monster/treasure/item pools; inventory + spell charges + Level Key;
  Dungeon! tuning; chambers; room labels (`LBL_*`/`LABELMASK`); hot-seat seats
  (`PLAYERS`/`num_players`/`cur_player`); solo/hunt state; **ruleset switches** (`opt_oldschool`,
  `opt_boardgame`, `opt_movedice`, `MOVE_MAX`, `opt_lootrecovery`, `opt_maxdeaths`); flavor
  arrays; `FX_*` combat context; the per-run chronicle tallies.

## The engine ↔ game contract

A hook is a `Game_*` SUB/FUNCTION the engine calls and `game/` implements. **11 are live** — and
they are now the *only* way engine code reaches game code. The still-"planned" rows are not debt:
they are inlined in `dungeon.bas`, the **assembly**, which is allowed to name both sides. Lifting
them would make `dungeon.bas` itself reusable; it is not required for `engine/` to be separable.

| # | Hook | Status | Was inlined at |
|---|------|--------|----------------|
| 1 | `Game_WinReached%()` — win predicate | ✅ done | play-loop win check |
| 2 | `Game_OnEnterCell%(cx,cy)` — movement→consequence (encounter/loot/heal/win) | ✅ done | `dungeon.bas` play loop |
| — | `Game_WinReady%()` — shared "gold+key" sub-predicate (HUD hint + #1) | ✅ done | 2 copies (loop + HUD) |
| — | `Game_PoisonLevel!()` — poison overlay intensity 0..1 (JUICE decouple) | ✅ done | `DrawPoison` read of `poison_turns` |
| — | `Game_ShowWounds%()` — may the engine draw near-death blood/vignette? | ✅ done | `DrawWounds` read of `opt_oldschool` |
| — | `Game_SfxNames$()` — the roster of themeable effect names to register | ✅ done | `SfxNameList$` in `engine/MUSIC.bas` |
| — | `Game_FloorColorAt~&(px,py)` — **what colour counts as room floor here** (0 = none) | ✅ done | `SECTOR.get_by_xy`+`SECTORS().kolor` inside `CellKind`/`CanMove`/`InRoomNow` |
| — | `Game_ZoneByColor%` / `Game_ZoneName$` / `Game_ZoneCount%` — zone identity for the mask linter | ✅ done | `SectorByColor%`/`SECTORS().label` inside `AnsiLint` |
| 3 | `Game_Play%()` / `Game_ShowIntro` / `Game_ShowEnd(win)` — state-machine bodies | planned | `dungeon.bas` state machine |
| 4 | `Game_RunOver%()` — lose/forfeit predicate (`player_out`/`solo_result`) | planned | play loop |
| 5 | `Game_RenderHUD()` — repaint the game's HUD layer after the engine wipes an overlay | ✅ done | `DrawHUD` call inside the 3D dice roller |
| 6 | `Game_RenderMapLabels`/`Game_RenderOverlays` — board labels + tombstone/grave/entity/hunter overlays (superseded the guessed per-cell `Game_CellMarker%`) | ✅ done | `render_room_labels`/`DrawTombstones`/`DrawChamberGraves`/`DrawEntities`/`DrawHunter` |
| 7 | `Game_OnRoomDiscovered(rm)` — first-entry (`RoomFlavor`+chronicle) | planned | play loop (now inside #2) |
| 8 | `Game_PopulateBoard()` — the game claims **both** its region kinds: ROOMS (coloured blocks) **and** CHAMBERS (named halls) | ✅ done | `DetectRooms`/`FloodRoom`/`RoomVisit` + `DetectChambers` & co. in `engine/BOARD.bas` |
| 9 | `Game_ResolveEncounter%(rm)` — combat entry (`DoCombat`) | planned | `dungeon.bas` |
| 10 | `Game_MonsterAttack(rm)` — Monster Attack Table (death/gold/retreat) | planned | `dungeon.bas` |
| 11 | `Game_AwardTreasure(rm,sm)` — item table + Level Key (`ClaimTreasure`) | planned | `dungeon.bas` |
| 12 | `Game_OnStep(cx,cy)` — per-move ticks (curio/status/siren/level bonus) | planned | play loop |
| 13 | `Game_OnIdle()` — idle-danger (`LoiterTick`) | planned | play loop |
| 14 | `Game_StartTurn()`/`Game_MoveCost%()` — turn budget (boardgame/boots) | planned | play loop |
| 15 | `Game_OnEnterCleanCell(cx,cy)` — loot recovery (now inside #2) | planned | play loop |
| ~~16~~ | ~~`Game_DebugSpawn%`~~ — **not needed**: the cheat panel moved to `game/DEBUG.bas` and `dungeon.bas` calls it directly | n/a | `DebugTestMenu` (`engine/BOARD.bas`) |

The two indispensable ones (#1, #2) are done — they were the tightest and most central seams.

### Two lessons about hook design

**Prefer a decision to a state read.** The engine should never ask *"what mode is the game in?"*,
only *"should I?"* (`Game_ShowWounds%`), *"how much?"* (`Game_PoisonLevel!`), or *"what value?"*
(`Game_FloorColorAt~&`). A hook returning game *state* just relocates the coupling; one returning
a *decision* survives a game swap. The collision fix is the clearest case: three functions asked
`SECTOR.get_by_xy` → *"which dungeon level is this?"*, a question only DUNGEON! can answer. What
they actually needed was *"what colour is floor here?"* — a plain value. One hook replaced all
three, and the engine stopped knowing that dungeon levels exist.

**Not every leak wants a hook — check who calls it first.** Several planned hooks turned out to be
unnecessary because the leaking code was only ever called from `dungeon.bas`, the assembly. The
`[0]` cheat panel, `DoSearch`, and `BreakDoorAttempt` all lived in `engine/` while naming a dozen
game symbols, but no *engine* module called them. Moving the code to `game/` cleared each leak
with **zero** new contract surface. A hook is only warranted when engine code genuinely must call
into the game mid-algorithm. Adding one where a move would do inflates the contract you have to
keep stable forever.

## Boundary-debt ledger — burned down

Engine-side code that named game symbols directly. **All cleared** as of 2026-07-29; every
`engine/*.bas` and `ENGINE.BI` passes `tests/audit-boundary.sh`. Kept as a record of what moved
and why, because the *reasoning* is what makes the next call easy.

**Cleared:**
- ~~JUICE ← player HP~~ — `player_hp/maxhp` moved into ENGINE.BI (engine→engine) in split B.
- ~~JUICE ← poison~~ — `DrawPoison` takes a pure `intensity` (0..1) param; the game supplies it
  via the `Game_PoisonLevel!()` hook.
- ~~JUICE ← ruleset~~ — `DrawWounds` gated on `opt_oldschool` (a game switch the ledger had
  already wrongly marked cleared). Now the `Game_ShowWounds%()` hook; `engine/JUICE.bas` is clean.
- ~~DATA ← loaders~~ — `Load*` moved to `game/LOADERS.bas`; `engine/DATA.bas` is game-free.
- ~~SAVE plumbing~~ — `engine/SAVEIO.bas` (game-free) + `game/SAVEGAME.bas` (payload).
- ~~CHRONICLE md~~ — reusable md renderer lifted to `engine/MARKDOWN.bas`.
- ~~PadR$/utils~~ — moved to `engine/TEXT.bas` (engine no longer reaches into a game file).
- ~~UI ← StrSubst$~~ — `engine/UI.bas` reached into `game/EFFECTS.bas` for a pure string helper;
  `StrSubst$` moved to `engine/TEXT.bas`. `engine/UI.bas` is now clean.
- ~~SPRITES~~ — split `engine/ARTPACK.bas` (game-free) vs `game/SPRITES.bas` (entity sprites).
- ~~combat rules in `dungeon.bas`~~ — extracted to `game/COMBAT.bas` + `game/PLAY.bas`.
- ~~MENU presentation~~ — the fades/UI/sound/dice runtime lifted to `engine/UI.bas` (game-free).
- ~~BOARD/CURSOR ← rooms (overlays)~~ — `render_room_labels`/`DrawTombstones`/`DrawChamberGraves`/
  `DrawEntities` (+ `EntityDrawX/Y`/`EntityShiftFind`) moved to **`game/OVERLAYS.bas`**; the engine's
  `cursor_erase`/`cursor_draw` reach them only via the `Game_RenderMapLabels`/`Game_RenderOverlays`
  hooks.
- ~~CURSOR ← hunter~~ — `cursor_draw` called `DrawHunter` (a Solo-mode game token) directly; it is
  now the 4th call inside `Game_RenderOverlays`, so the engine's draw path names no game renderer.
- ~~region detect → game~~ — `DetectRooms` + `FloodRoom` moved to `game/SECTOR.bas`; the engine's board
  setup calls the `Game_PopulateBoard()` hook (#8) instead.
- ~~BOARD ← RoomVisit~~ — the room-flood *helper* was left behind in `engine/BOARD.bas` by the move
  above, so `game/SECTOR.bas` reached back into the engine to call it (and the engine still wrote
  `ROOMAT`). Moved beside its only caller in `game/SECTOR.bas`. **Lesson: move the whole call graph,
  then re-audit — a partial move reads as "cleared" but silently inverts the dependency.**
- ~~BOARD ← chambers~~ — `CellOpen%`/`ChamberTry`/`FloodChamber`/`LoadChambers%`/`DetectChambers`/
  `PickChamberGraves`/`ChamberDeadAt%` (~190 lines) moved to **`game/CHAMBERS.bas`**. Rather than a
  new hook, chamber detection folded into the **existing** `Game_PopulateBoard()` — chambers are just
  the game's *other* region kind, so the engine keeps one "claim your regions" seam instead of two.
  `InitFog` and the `chamberdump` dev mode both dropped their direct `DetectChambers` call.
  (Verified: `chamberdump` still reports 43 secret doors / 93 rooms / 12 chambers.)
- ~~MUSIC ← flavor tables~~ — `DumpAudioManifest` (+ its `LookupDesc$` helper) moved to
  **`game/MANIFEST.bas`**: a manifest *is* a listing of this game's content, so it necessarily
  names `REG_FLAV`/`SP_*`/`CHM_FLAV_*`/`CURIOS`. `SfxNameList$` went with it as the
  **`Game_SfxNames$()`** hook — the effect roster (`fireball`, `monster-pain`, …) is game content,
  and `InitSfxFiles` now asks the game for it. `engine/MUSIC.bas` is clean.
  (Verified: `dungeon.run audiomanifest` output is byte-identical, 216 lines.)
- ~~STATS ← run schema~~ — split by *ownership of the columns*: `engine/STATS.bas` keeps
  `CsvCell$`/`Bit$` and a pure `StatAppend(path, header, row)`; the DUNGEON! schema (class, char
  level, XP, gold, oldschool-vs-D&D) moved to `StatLog` in `game/COMBAT.bas`, beside its only
  callers. The engine appends strings and names none of it. `engine/STATS.bas` is clean.
  Because the game now owns the header, `StatHeaderReady%` guards **schema drift**: if an existing
  csv's first line differs from the header about to be written, the stale file is renamed aside
  (`.old`, `.old2`, …) and a fresh one started — so old runs stay readable *and* new runs keep
  logging, instead of misaligned columns (append-anyway) or silent data loss (skip).
  **Gotcha this exposed:** "is the file new?" must be evaluated *after* the guard runs, or a
  rotation leaves the fresh file with no header at all — hence `LOF(f) = 0` on the opened handle
  rather than an `_FILEEXISTS` captured up front.

- ~~BOARD ← labels~~ — `InitLabels`/`LoadLabels`/`AddLabel`/`BuildLabelMask` moved to
  **`game/OVERLAYS.bas`**, beside `render_room_labels` which consumes them: `labels.txt` is game
  content. `PutLabel` stayed in the engine — it is a draw primitive (UI font + FOV gate), not data.
- ~~BOARD debug menu~~ — `DebugTestMenu`/`DebugMenuClose`/`DrawDebug`/`MaskHoverInfo$` (~190 lines)
  moved to **`game/DEBUG.bas`**. **No hook was needed:** `dungeon.bas` was the only caller, so the
  panel simply moved to the side that owns it. It reads engine state (`SD_*`/`MASKREG`/`FOGHIDE`)
  the sanctioned game→engine way. `DrawMaskDoors` stayed — it renders engine secret-door state and
  the engine's own `fogdump` mode uses it.
- ~~BOARD ← search / strong doors~~ — `DoSearch` and `BreakDoorAttempt%` moved to `game/PLAY.bas`.
  Also caller-only-in-`dungeon.bas`, so again no hook. The engine keeps the doors themselves
  (`SD_*`, `DOOR_BROKEN`, `RevealRegionFromDoor`, `StrongDoorAhead`) and the game calls in; the
  *rules* — search odds, the Elf's `secret_bonus`, the Secret Door Card, the DC-13 STR check — left.
- ~~BOARD ← sectors (collision)~~ — the deep one. `CellKind`/`CanMove`/`InRoomNow` derived the
  room-floor colour themselves via `SECTOR.get_by_xy` + `SECTORS().kolor`, i.e. the engine asked
  *"which dungeon level is this?"*. Replaced by the **`Game_FloorColorAt~&(px,py)`** hook — the
  engine asks *"what colour is floor here?"* and compares; 0 means none (safe sentinel, since every
  real colour has alpha 255). `AnsiLint`'s colour→level report went to `Game_ZoneByColor%` /
  `Game_ZoneName$` / `Game_ZoneCount%`, and its wording is now generic ("zones", not "levels").
- ~~START_CX/START_CY~~ — moved from GAME.BI to ENGINE.BI. Where the cursor starts on the board is
  engine state; that it is *also* the win-return point and the heal spot is a DUNGEON! rule, and
  the game still reads the constant freely.
- ~~CURSOR ← players~~ / ~~PLAYERS ← inventory~~ — the last two, and the same debt twice. The
  rival/active seat tokens moved out of `cursor_draw` into `DrawPlayerTokens` (called from
  `Game_RenderOverlays`): the engine owns where the cursor *is*, not what the marker looks like or
  that it carries a seat number. `engine/PLAYERS.bas` moved wholesale to **`game/PLAYERS.bas`** —
  the active player's state *is* the working globals, and those are DUNGEON! (class, gold, Level
  Key, items, ability scores), so `Load/SaveActivePlayer` are game state management. No engine
  module called anything in it.

## Verifying a change

The whole point is that the game keeps working at every step. The full sweep — each line catches
something the others don't:

```sh
qb64pe -w -x dungeon.bas -o dungeon.run       # must print "Output:" AND leave a fresh binary
setsid timeout 12 xvfb-run -a ./dungeon.run   # boots to the menu (exit 124 = still up = OK)
./dungeon.run chamberdump                     # regions unchanged: 43 doors / 93 rooms / 12 chambers
./dungeon.run audiomanifest | wc -l           # content manifest unchanged: 216 lines
./dungeon.run imagemanifest                   # sprite paths (SpriteBase$/TreBase$/UnSlug$)
./dungeon.run ansilint                        # masks lint clean; all 9 zones painted (MaskSample~&)
./dungeon.run settingsshot                    # SETTINGS layout -> settings-shot.png (look at it)
tests/run-tests.sh                            # ALL of: unit suites + 3 audits + separability
```

`tests/run-tests.sh` with no arguments is the gate: unit suites, then `audit-boundary.sh`
(no engine file names a game symbol), `audit-shadow.sh` (no local shadows a high-risk global),
`audit-shortcircuit.sh` (no bounds guard relies on short-circuiting, which QB64 does not do),
and finally building + selftesting `examples/minimal`. Pass a name fragment
(`tests/run-tests.sh stats`) to run a single suite and skip the rest.

`chamberdump` is the cheap regression test for any board-region or collision change — it runs
detection headlessly and writes counts + bounding boxes, so a move that silently loses a region is
caught without a play-test. `audiomanifest` does the same for content tables.

**Compiling proves almost nothing here.** QB64 resolves every symbol globally, so a move that
inverts the dependency direction still builds; and for a *header* split, a dropped-but-unreferenced
global won't error either. Prove those independently: `tests/audit-boundary.sh` for the boundary,
and for a header split, strip comments and set-diff the declaration lines against the pre-split
file.

**Still needs a human at the keyboard:** anything whose only symptom is visual or interactive —
the `[~]` overlay and `[0]` cheat panel, hot-seat token rendering with 2+ players, `[F]` searching,
and bumping a reinforced door. The headless checks above cover their *wiring*, not their look.
