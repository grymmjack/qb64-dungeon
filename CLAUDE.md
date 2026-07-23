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

- **`dungeon.bas`** (repo root) — the playable game: a vertical slice that assembles the
  three prototypes into one program via an `INTRO → MENU → PLAY → WIN/LOSE` state machine
  (`SELECT CASE game_state`), each state a self-contained SUB/FUNCTION (`ShowIntro`,
  `RunMenu`, `PlayGame`, `ShowEnd`). Encounters ride the existing pixel-color collision:
  each `SECTOR` carries an optional monster, and stepping onto a room floor (`InRoomNow`)
  in a sector with a live monster triggers 2d6 combat (`DoCombat`, with a Dungeon!-style
  miss table in `DoConsequence`). Four player classes (`CLASSES(1..4)`: Hero/Elf/Superhero/
  Wizard) with distinct gold goals + combat bonuses are chosen via the menu's CREATE A
  CHARACTER (`SelectClass`). Build/run it from the repo root (asset paths are `assets/...`,
  not `../assets/...`).
- **`scratchpads/`** — the active workshop. The prototypes `dungeon.bas` was built from
  live here (`TEST-MOVEMENT-MAP.bas` = movement/collision; `TEST-MENU.bas` = animated ANSI
  menu; `wip.bas` = intro→board flow). `const.bas` / `types.bas` hold shared CONSTs and
  TYPEs pulled in via `'$INCLUDE`. `scratchpads/shots/` holds the capture harness.
- **`include/`** — the *destination* for a refactor into shared modules (`BOARD`,
  `CURSOR`, `SECTOR`, `image`). Most are still empty stubs; `CURSOR.bas` and `SECTOR.bas`
  hold the extracted `TYPE`s. See the Refactor section of [PLANS.todo](PLANS.todo).
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
