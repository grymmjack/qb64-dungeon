# The engine / game split

This repo was refactored from *"a game with a lot of reusable machinery"* into a
**reusable engine** (`engine/`) + a **swappable game** (`game/`), per
[PLANS.todo](../plans/PLANS.todo). The goal was a *separable* engine — one that could be lifted
into its own repo/submodule so the next game starts from it. This file is the map of the
boundary, the hook contract, and the record of how each leak was closed.

> **The bar moved on 26-08-06** and the ledger in the back half of this file was written against
> the old one. "Separable" used to mean *`engine/` names no `game/` symbol, and a second game in
> this repo compiles on it* — which is true and audited. It now means **a stranger can copy
> `engine/` into their own project, point it at their own assets, and get the tools**. By that
> measure the engine is NOT done: it hardcodes ~50 paths into this game's asset tree, and its
> tools carry this game's tables and layers baked in. See *What "reusable" has to mean* below;
> the older sections remain accurate about what they cover.

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

## What "reusable" has to mean (26-08-06)

The bar moved, and the ledger below was written against the old one. **The engine is not
"reusable" because `examples/minimal` compiles inside this repo. It is reusable when the
directory can be lifted into somebody else's project, pointed at their own assets, and hand
them the tools.**

Rick's framing, which is the one to build to:

> **the game is simply the assembly of the parts of the engine, driven by the gas of the assets.**

So there are three things, and each owns something different:

| | owns |
|---|---|
| **`engine/`** | the parts, the FORMATS, the registries, and **all the tooling** |
| **assets** | the content — the fuel |
| **`game/`** | the assembly: which parts, wired how, plus the rules that ARE this game |

Three consequences follow, and only the first is currently true.

### 1. The engine may name no game SYMBOL — done, audited

`tests/audit-boundary.sh`, described below. Clean.

### 2. The engine may name no game PATH — **DONE 26-08-06**, audited

`engine/` hardcoded **51 literal `assets/...` paths**: `assets/data/`,
`assets/pixel-art/`, `assets/music/default/playlist.txt`, `assets/data/theme/colors.txt`,
`assets/fonts/dpoly/`. Every one is the engine depending on something only DUNGEON! has, and
the boundary audit passes anyway — because it checks *symbols*, and a hardcoded path is the
same violation wearing different clothes.

Fixed by a **path registry** (`engine/ASSETS.BI` + `ASSETS.bas`): the assembly declares its
tree once, and the engine asks for KINDS, never paths. `tests/audit-paths.sh` is in the gate;
declaration calls are exempt, because naming a path is what a host is *for*.

```basic
AssetRoot "assets/"                  ' wherever this game keeps its fuel
AssetKind "data",     "data/"
AssetKind "pixelart", "pixel-art/"
AssetKind "music",    "music/"
' ...engine code then only ever writes:
'     AssetPath$("data", "strings.txt")
```

A new game declares a different tree and **not one line of `engine/` changes** —
`examples/minimal` now proves it by declaring its own.

**No defaults, deliberately.** Falling back to `assets/` and the names this game happens to use
would keep everything working, which is the problem: the engine would still know this game's
layout and *nothing would break*, so nobody would find out. An undeclared kind is **recorded**
(`AssetMissing$`) rather than guessed.

**The tree is declared in ONE place** — `game/ASSETTREE.bas` — which `dungeon.bas` and three
unit suites all call. A hand-copied declaration per suite would be three more copies to drift,
the exact failure the registry exists to end.

### 3. The engine owns the FORMATS; the game declares its TABLES — **DONE 26-08-06**, gated

The engine already owns the *reader* (`ReadDataFile` / `DField$`) and the pack model
(pack → `default`, per file). What it does not own is the knowledge of what a table IS — and
that knowledge currently exists in **three places that can disagree**:

| where | what it thinks it knows |
|---|---|
| the file's own header comment | `# lvl \| slot \| name \| HERO \| ELF \| SUP \| WIZ` |
| `DeMaxCols%` (the data editor) | an `IF` chain naming `strings.txt`, `*_events.txt` by name |
| each loader | `DField$(ln, 4)` — the column meanings again, implicitly |

**They did disagree.** The editor capped `monster_events.txt` at its three *visible* columns
while `LoadEventText` reads four — so editing the text column would have swallowed the
narration key into the line the player reads. Three copies, two of them wrong.

Fixed by a **schema registry** (`engine/SCHEMA.BI` + `SCHEMA.bas`), declared by the game in
`game/DATATABLES.bas` — 35 tables, and `dungeon.run schemalint` is in the gate:

```basic
DataTable "monsters.txt", "lvl|slot|name|HERO|ELF|SUP|WIZ"
DataTable "strings.txt",  "key|text"   split_first   ' values legitimately contain pipes
DataTable "triggers.txt", "level|col|row|scene|once"
```

One declaration and **four tools stop guessing**: the editor gets its columns and its split
rule, `datalint` checks arity generically instead of per-table by hand, the manifests know what
exists, and a new game inherits the whole toolchain by declaring its own tables.

`schemalint` compares all three sources — the declaration (authoritative, it is what the loader
reads), the file's own rows, and the comment a modder reads. It found the two `*_events.txt`
files documenting three columns while their loader read four; those comments are fixed.

An **undeclared** table is not an error: every tool falls back to what it did before and the
lint says so out loud. A registry that broke a host for not being filled in yet would simply
not get filled in.

## The tools are ENGINE, not game

A debugger that only debugs DUNGEON! is a feature, not tooling. Everything below belongs in
`engine/`, and the ones still in `game/` are debt:

| tool | now | note |
|---|---|---|
| dev console + dump registry | `engine/` | **the pattern to copy** — see below |
| cut-scene engine + player | `engine/` | |
| data editor | `engine/` | but hardcodes `assets/data/<pack>/` and table names |
| map debugger | **`engine/`** | **moved 26-08-06** — layer + event registries; `game/MAPREG.bas` registers |
| pack browser | **`engine/`** | **moved 26-08-06** — kinds come from the asset registry; 5 hooks |
| storybook | **`engine/`** | **moved 26-08-06** — pulled `ListPanel%`, `MysteryBox` and the whole 9-grid frame system in with it |
| board overlays | **`engine/`** | **moved 26-08-06** — the host names the file, nothing else |
| region/chamber detection | `game/` | the rect→cell-map half only |

### Registries, not accessors

The instinct to price a move by "how many hooks would it need" is wrong twice: hooks ARE the
interface, and a fixed set of accessors is the worse design anyway. With eight accessors the
engine enumerates what layers exist and every new layer is an engine edit. With a **registry**
the game adds a layer and the engine never changes — and so can a *pack*.

`engine/CONSOLE.bas` already does exactly this for dumps: `RegisterDump` + `Game_RegisterDumps`
+ `Game_DevDump%`, with `tests/audit-dumps.sh` enforcing four-way consistency between topic,
SUB, registration and dispatch. **Every registry below wants that same shape and that same
audit**: map layers, debug events, data tables, asset kinds, pack kinds, the sfx roster.

## The test that means it

`examples/minimal` compiling is too weak — it sits inside this repo and eats this repo's
assets, so it cannot detect the engine assuming DUNGEON!'s tree.

**The honest test: give `examples/minimal` its own asset tree** (`examples/minimal/assets/`) —
its own data files, one art pack, its own scenes. Then "the engine does not assume DUNGEON!'s
layout" is enforced by minimal *having no such layout*, and it must still get a working map
debugger, pack browser, data editor and storybook showing **its** layers and **its** packs.

Then add the last step as a gate: copy `engine/` + the template into a scratch directory, build
it there, and run its tools. That is the `cp -r` a stranger would do.

## New audits this implies

| audit | fails when |
|---|---|
| `audit-paths.sh` | any `engine/` file contains a literal `assets/` path |
| `audit-schema.sh` | a table is read by a loader but never declared; or a declaration's arity disagrees with the loader's highest `DField$` index |
| extend `audit-dumps.sh` | the same four-way check for map layers and debug events |

## Auditing the boundary (do this before trusting any claim here)

Because no linker enforces the split, a hand-maintained ledger **drifts** — this one did, twice,
and both times the audit caught what the prose had got wrong. So the audit is a script
(`tests/audit-boundary.sh`), not a paragraph: it collects every symbol `game/` owns (each
`SUB`/`FUNCTION` in `game/*.bas`, each `DIM SHARED`/`CONST`/`TYPE` in `GAME.BI`), then intersects
that with the identifiers in each `engine/` file. Anything back — other than a `Game_*` hook — is
boundary debt. It strips comments and string literals, and filters QB64 keywords and shared type
names. It then checks **contract completeness** (every `Game_*` hook the engine calls must be
implemented by both `game/` and `examples/minimal/`) and **ENGINE.BI hoarding** (see below).

> **The name-matching check is ONE-DIRECTIONAL, and that hid real debt.** Asking "does `engine/`
> name a `game/` symbol" can never flag something misfiled *into* the engine header — it is
> engine-owned by definition. 27 of ENGINE.BI's globals turned out to be referenced by no
> `engine/` file at all (D&D ability scores, ruleset switches, turn machinery). The sharper
> question is just **"does any `engine/` file actually use this?"**, and zero-use is a far
> cleaner signal than name-matching. That check now runs too. When it fires you have two honest
> options: move the declaration to GAME.BI, or move its *consumer* into `engine/`.

**Turn machinery is the deliberate exception, and worth understanding as a design call rather
than an oversight.** `turn_num`/`steps_left`/`need_roll` sit in ENGINE.BI with **no engine
consumer yet**, so the hoarding check would flag them. They are engine by design: turn
*structure* — whose turn it is, how many steps remain, whether a roll is owed — is generic, while
what a turn *costs* and what combat does with it are game rules. The deeper tactical-combat screen
in [PLANS.todo](../plans/PLANS.todo) needs engine-side **initiative + turn order** and will consume
them. So they are listed in a `RESERVED` set in `audit-boundary.sh`, which still **reports** them
every run — visible, not silently exempt — but does not fail on them. Take a name out of that set
the moment an `engine/` file uses it; move it to GAME.BI if that never happens.

The general lesson: "no engine file uses this" is strong evidence of misfiling, but it is
evidence, not proof. A deliberate reservation is legitimate — it just has to be *stated*, not
assumed, or the next reader deletes it.

> **Why a script, not a one-liner.** The obvious `grep '^ *DIM SHARED +\w+'` captures only the
> **first** name on a line, so `DIM SHARED num_players AS INTEGER, cur_player AS INTEGER` hides
> `cur_player` — which is exactly how this audit missed three real leaks mid-refactor. The script
> splits on commas outside parentheses (so array bounds don't confuse it) and handles the
> `DIM SHARED AS INTEGER a, b, c` prefix form.

Add it to any pre-commit check you like; it exits non-zero when the engine is dirty.

## Layout

```
dungeon.bas          thin assembly: screen/CLI setup + state machine + PlayGame + FOUR includes
engine/
  _ALL.BI  _ALL.BM   roll-ups: every engine header / every engine body, one line each
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
  TEXT               reusable string/format utils (PadR$/NthField$/MMSS$/StrSubst$/SubstAll$/PackIndex%)
  GAUGE              the composure gesture model as pure steps -- no draw, no poll (see below)
  LAYOUT             named screen regions loaded from data (LayC%/LayPX%/LayN$ by NAME)
  FIGHT              tactical-combat SCREEN: actor slots + the region-addressed renderer
                     (no combat rules -- slot 0 is the player, 1..4 foes, see below)
  FUSE               parallel attack fuses + target selection (pure model, no drawing)
  STATUS             per-actor status effects (duration + damage-over-time) + stances
  TABLE              weighted/percentile random tables (PctChance%/WeightPick%/WeightPickLvl%)
  CONSOLE            the [`] dev console (hotkey polled in Present, so it opens from ANY loop)
                     + the DUMP REGISTRY -- Dump_* topics, enforced by tests/audit-dumps.sh
  TELEMETRY          what is playing / showing right now, logged at the CHOKEPOINTS (Sfx,
                     Narrate, BeginTrack, DrawSpriteFit%). Kept dependency-free and separate
                     from CONSOLE because TEST-ARTPACK compiles ARTPACK.bas in isolation
game/
  _ALL.BI  _ALL.BM   roll-ups: every game header / every game body, one line each
  GAME.BI            DUNGEON!-specific globals/types/consts (loaded AFTER ENGINE.BI)
  HOOKS.bas          the game side of the engine<->game contract
  OVERLAYS.bas       board overlays (label table + tombstones/graves/entities/hunter/tokens) + render hooks
  LOADERS.bas        game data-table loaders (Load*), moved out of engine/DATA.bas
  CHAMBERS.bas       the big named halls: detect/flood/grave-seat (was in engine/BOARD.bas)
  MANIFEST.bas       audio manifest dump + Game_SfxNames$ roster (was in engine/MUSIC.bas)
  DEBUG.bas          [~] dev overlay + [0] cheat panel (was in engine/BOARD.bas)
  DATALINT.bas       `datalint` dev mode: validate the loaded content tables
  DUMP.bas           the game's dump topics (game/character/map/monster) behind the two dump
                     hooks, + the [Shift-TAB] BEARINGS overlay
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

Assembling a program is **four lines** — the roll-ups make engine/ and game/ drop-in units:

```basic
'$INCLUDE:'engine/_ALL.BI'    ' every engine header  -- FIRST, before any executable line
'$INCLUDE:'game/_ALL.BI'      ' every game header    -- engine before game, never the reverse
   ... setup + state machine + the play loop ...
'$INCLUDE:'engine/_ALL.BM'    ' every engine body    -- at the BOTTOM
'$INCLUDE:'game/_ALL.BM'      ' every game body
```

Nested `'$INCLUDE` paths resolve **relative to the including file's own directory**, which is
what lets the roll-ups list bare filenames and keeps `engine/` copy-out-able as a directory.
(`engine/DICE3D/_ALL.BI` and `engine/ansi/ANSIPrint.bi` already relied on this.)

**Why body order is safe to collapse:** QB64 resolves every SUB/FUNCTION globally, and **no
body file declares anything at file scope** — no `DIM SHARED`, no file-scope `CONST` or `TYPE`;
those live only in the `.BI` headers. That invariant is what makes the roll-up correct rather
than lucky, so keep it: put a new shared global or CONST in a header, never in a `.bas`.
(`GESTURE_FUSE` was the last file-scope `CONST` in a body and moved to ENGINE.BI for this.)

The only ordering rule left is the original one: **headers before any executable line, bodies
at the bottom, engine before game.**

## The tactical-combat screen (GAUGE + LAYOUT + FIGHT)

Three engine modules, added for the tactical combat work, that are worth understanding together
because each one exists to keep the *next* one game-free and testable.

**`LAYOUT.bas` — a screen described as DATA.** `LoadLayout%` reads named rectangles in character
cells from a text file; drawing code asks for `LayPX%("player.art")` instead of a hardcoded column.
Every accessor returns **0 for an unknown region** — asserted in `tests/TEST-LAYOUT.bas`, because a
typo'd region name otherwise draws nothing at (0,0) and reports nothing. Each region carries its
*own* cell size, since one game mixes metrics: the fight screen is 132×100 on an 8×8 cell, the board
is 132×51 on 8×16.

**`GAUGE.bas` — the composure gesture model as pure steps.** No draw, no input polling, so it is
unit-testable with no display (`tests/TEST-GAUGE.bas` asserts the design *principles* as properties:
skill compresses the RANGE rather than shifting the odds; the zone is always fully on the bar).
`GaugeSample%` is the auto-resolve twin and deliberately draws a uniform **phase**, not a uniform
`p`, so it inherits the marker's arcsine distribution — sampling `p` uniformly would make
auto-resolve *easier* than playing.

**`FUSE.bas` — the tactical layer, also pure.** Every foe runs its own countdown *simultaneously*,
and the fuses advance **while the player deliberates** — stand in the menu and something takes the
opening. That is the only real source of pressure in a 1-vs-4; the same fight turn-based has none.
Split from FIGHT.bas because FIGHT.bas needs `CANVAS`, so nothing there can be tested headlessly.
Three things `tests/TEST-FUSE.bas` pins down, each of which fails *silently* if wrong:

- **Two fuses can complete in one frame.** A function returning "the slot that fired" drops the
  second attack. So completion *queues*, and the queue is asserted to drain completely.
- **Order follows whose fuse finished first**, not slot index — otherwise foe 1 permanently
  pre-empts foe 4. `FF_T` is deliberately left un-clamped so the overshoot is measurable; only the
  render value clamps.
- **Corpses neither act nor can be aimed at.** Foes stay on screen after dying, so "dead" is a flag,
  not a removal — every fuse and target path has to check it. `TargetCycle` skips the dead and
  `TargetValidate` moves the aim off a foe that just died, or the next attack appears to whiff.

`FuseNextActor%` makes initiative **emergent** — whoever is closest to acting *right now*, which is
the one fact worth knowing while triaging, and which a rolled turn order cannot express.

**`STATUS.bas` — effects and stances, also pure.** Durations in *seconds* (the fight is real-time,
so "turns" would have no defined length while the player sits in the menu). The bug it exists to
prevent: at 60fps a 2-damage-per-second poison owes `0.0333` per frame and **`INT(0.0333)` is
zero** — the obvious implementation ticks forever and never removes a hit point, with no crash and
no warning, so it survives playtesting looking like "poison is weak". Each effect carries a
fractional accumulator, and **the remainder is paid out on expiry** — without that, `SINGLE`
precision lands a hair under the true total and an effect delivers *less* the finer time is sliced.
`tests/TEST-STATUS.bas` checks the same total at three step sizes; it caught exactly that, off by
one, on the first run.

Effects **refresh rather than stack** (four foes attacking in parallel makes a double-hit in one
second easy, and stacking turns that into an instant kill), a full slot set displaces the
most-nearly-expired rather than dropping a fresh threat, and a corpse is neither ticked nor
targetable. **Stagger is a status, not a flag**, so it expires through the normal tick — as a flag
a missed clear leaves a foe permanently staggered, invisible except as an enemy that never recovers.

**`FIGHT.bas` — actors in, pixels out.** Holds actor slots and the renderer, and **no combat rules**.
Three decisions carry it:

- **Slot 0 is the player, 1..4 are foes.** `FaRgn$(a, "hpbar")` turns a slot into a region name
  (`player.hpbar` / `enemy3.hpbar`), so *one* loop paints all five actors and the player is not a
  special case with duplicated draw code. Adding a sixth actor is a layout-file edit.
- **Stat/status rows are generic `label`+`value` pairs**, not named melee/ranged/armor fields. The
  engine renders "three label: value rows in this region"; what they *say* is the game's business.
  This is the single reason FIGHT.bas can stay game-free.
- **The font switch is bracketed, not delegated.** The board runs `_FONT CH` (8×16) and this screen
  runs `_FONT 8`. `FightRender` sets and restores it, because a caller that forgets leaves the board,
  HUD and every menu rendering at half height with no error to explain it.

Verify all of it without playing a fight:

| command | proves |
|---|---|
| `dungeon.run fightlayout` | the BOXES are placed right (labelled PNG) + lints off-screen / zero-size / overlapping `art` regions |
| `dungeon.run fightshot` | the RENDERER fills them — portraits, health colours, dead-actor dim, target highlight, log gutter — and reports how many portraits resolved, so "no art yet" is distinguishable from "broken renderer" |
| `dungeon.run fightmanifest` | the art still to be generated, sized **from the layout file** so it cannot drift |

## Header ownership (ENGINE.BI vs GAME.BI)

- **ENGINE.BI** — screen grid + canvas + palette; `CURSOR` type; dice config/fonts + tumbler
  state; audio + pack/narration/art-pack globals; engine `opt_*` (a/v, dice, FOV, msgdelay,
  fullscreen/smooth); fog/FOV + secret-door/mask detection arrays; near-death juice bake data
  (blood/vignette/poison); `player_hp`/`player_maxhp` + `player_dmgdie` (the only character
  fields any engine module reads — JUICE bleeds for HP, GESTURE rolls the damage die);
  save-token stream + `SAVE_FILE`; data-loader scratch; flood-fill queue; `START_CX`/`START_CY`;
  **turn machinery** (`turn_num`/`steps_left`/`need_roll`).

  **Every global here is used by at least one `engine/` file, and `audit-boundary.sh` enforces
  that.** 27 were not: the D&D ability scores and derived to-hit/AC, the ruleset switches
  (`opt_flexstats`/`opt_critfumble`/`opt_hardcore`/`opt_combatspeed`/`opt_gestures`/`opt_artstyle`),
  run identity (`run_seed`/`game_start`/`player_name`), `moves_made` and the dev flags — all moved
  to GAME.BI.
  Two (`opt_fullscreen`/`opt_smooth`) were legitimately engine config whose only *consumer* was
  misfiled: `ApplyDisplay` moved from `game/MENU.bas` into `engine/UI.bas` instead.
- **GAME.BI** — `SECTOR`/`ROOM`/`PCLASS`/`PLAYER`/`CURIO_T`/`FXROW`/`TRAPROW`/`EVTROW` types;
  `SECTORS`/`ROOMS` + monster/treasure/item pools; inventory + spell charges + Level Key;
  Dungeon! tuning; chambers; room labels (`LBL_*`/`LABELMASK`); hot-seat seats
  (`PLAYERS`/`num_players`/`cur_player`); solo/hunt state; **ruleset switches** (`opt_oldschool`,
  `opt_boardgame`, `opt_movedice`, `MOVE_MAX`, `opt_lootrecovery`, `opt_maxdeaths`); flavor
  arrays; `FX_*` combat context; the per-run chronicle tallies.

## The engine ↔ game contract

A hook is a `Game_*` SUB/FUNCTION the engine calls and `game/` implements. **`engine/` calls
exactly 11**, and they are the *only* way engine code reaches game code — `examples/minimal`
implements those 11 and nothing else.

> **Three `Game_*` routines are NOT engine hooks, despite the name.** `Game_OnEnterCell%`,
> `Game_WinReached%` and `Game_WinReady%` are called from **`dungeon.bas`** (and `game/MENU.bas`);
> no `engine/` file invokes them. They were the first things extracted, and this file used to call
> #1/#2 "the two indispensable ones… the tightest and most central seams" — which was wrong. They
> are the ASSEMBLY calling the game, which needs no hook at all, since `dungeon.bas` may name both
> sides. They are still useful factorings (the win rule lives in one place instead of three), just
> not contract surface. `examples/minimal` correctly does not implement them, and
> `audit-boundary.sh` correctly does not demand it.

The still-"planned" rows below are not debt either: they are inlined in `dungeon.bas`. Lifting them
would make the *assembly* reusable; it is not required for `engine/` to be separable.

| # | Hook | Status | Was inlined at |
|---|------|--------|----------------|
| 1 | `Game_WinReached%()` — win predicate | ✅ done | play-loop win check |
| 2 | `Game_OnEnterCell%(cx,cy)` — movement→consequence (encounter/loot/heal/win) | ✅ done | `dungeon.bas` play loop |
| — | `Game_WinReady%()` — shared "gold+key" sub-predicate (HUD hint + #1) | ✅ done | 2 copies (loop + HUD) |
| — | `Game_PoisonLevel!()` — poison overlay intensity 0..1 (JUICE decouple) | ✅ done | `DrawPoison` read of `poison_turns` |
| — | `Game_ShowWounds%()` — may the engine draw near-death blood/vignette? | ✅ done | `DrawWounds` read of `opt_oldschool` |
| — | `Game_SfxNames$()` — the roster of themeable effect names to register | ✅ done | `SfxNameList$` in `engine/MUSIC.bas` |
| — | `Game_FloorColorAt~&(px,py)` — **what colour counts as room floor here** (0 = none). Reads the cell's own pixel from the current `_SOURCE`, which must be a COLLISION image | ✅ done | `SECTOR.get_by_xy`+`SECTORS().kolor` inside `CellKind`/`CanMove`/`InRoomNow` |
| — | `Game_ZoneByColor%` / `Game_ZoneName$` / `Game_ZoneCount%` — zone identity for the mask linter | ✅ done | `SectorByColor%`/`SECTORS().label` inside `AnsiLint` |
| — | `Game_RegisterDumps` / `Game_DevDump%(topic)` — the game declares and runs its own `[`]` dev-console dump topics. Two hooks rather than one so a bare `dump` can LIST the game's topics without running any of them | ✅ done | would have been the console naming `ROOMS`/`player_*` directly |
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

Rows #1/#2 and `Game_WinReady%` are marked done but are **assembly→game calls, not engine hooks**
(see the note above the table). The genuine contract is the 11 unnumbered/#6/#8 rows that
`engine/` actually calls.

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

## The gauge: one model, two presentations — RESOLVED

`engine/GAUGE.bas` is the composure **model** — pure steps, unit-tested (`tests/TEST-GAUGE.bas`),
shared by every consumer so none can drift:

| presentation | where | used by |
|---|---|---|
| framed box overlay | `engine/GESTURE.bas` `GaugeLock%` | SECOND WIND, CRIT FLOURISH (board combat) |
| inline bar in `player.gauge` | `engine/FIGHT.bas` `FightGaugeRun%` | FLOURISH, the tactical death-save |
| none — auto-resolve twin | `GaugeSample%` | blind/unplayed resolution, the dominance guard |

`GaugeLock%` **used to carry its own private width/speed math** (`critHW`/`hitHW` computed from
depth inline). Unified 2026-07-30. Two consequences worth knowing:

- A tuning change to `GAUGE.bas` now **does** reach SECOND WIND. Before, it silently did not.
- **Wounds and crowd pressure narrow that gauge too, and character level widens it.** Previously
  its widths came only from `depth`, so a dying hero read the bar exactly as well as a healthy one.

Unifying it broke `examples/minimal`, correctly: `GaugeLock%` had started reading `char_level`, a
**game** symbol. The skill tier now flows **in** as a parameter (`GaugeLock%` / `SecondWind%` /
`CritFlourish%` each take it) and the game derives it with `SkillTier%` — no new hook, per the
"check who calls it first" lesson below.

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
- ~~`SubstAll$` in MARKDOWN~~ — a generic string substitution that only lived in the markdown
  renderer because that was its first caller. `engine/LAYOUT.bas` needs it too (`LayN$`
  substitutes `#` for a panel index), and reaching into MARKDOWN for it would have made every
  layout consumer depend on the whole md→text stack. Moved to `engine/TEXT.bas`, and its
  assertions moved with it (TEST-MARKDOWN → TEST-TEXT), so the suite matches the module.
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
