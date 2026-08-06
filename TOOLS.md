# TOOLS — the editors, debuggers and lints

Everything here ships **inside `dungeon.run`**. There is no separate tool binary and nothing to
install: a mode is chosen by an argument on the command line, or by a key in a running game.

Run them from the **repo root**. QB64PE chdirs to the executable at startup, so `assets/...`
only resolves if `dungeon.run` sits beside `assets/`.

    ./dungeon.run <mode> [args]

---

## The editors

### MAP DEBUGGER — `./dungeon.run mapdebug`, or `[~]` then `[9]` in game

Every layer the game *derives* from the board art, on one screen, over the board.

| key | layer |
|---|---|
| `1` | sectors (which dungeon level owns a cell) |
| `2` | walkable |
| `3` | rooms |
| `4` | room-kind — floor / doorway / decoration |
| `5` | doors |
| `6` | chambers |
| `7` | secret regions |
| `8` | triggers + overlays |
| `9` | room markers (where a monster or grave sits) |

`0` toggles the board art · `A`/`N` all/none · `-`/`=` tint strength · `S` writes `mapdebug.png` ·
`ESC` out.

**Click or arrow to pick a cell**, then:

- **`[E]` fires a real event there** — teleport, curio, wandering monster, trap, this room's
  monster, this chamber's encounter, any cut-scene in the pack, reveal the secret region here,
  or **append a trigger row for this cell to `triggers.txt`**. Rows that need a live run grey
  out, so open it from `[~]` `[9]` in a game rather than from the command line if you want them.
- **`[O]` places a board overlay** — pick art, aim, `[-/=]` scale, `[L]` lit, `[ENTER]` writes to
  `overlays.txt` and reloads. `[X]` deletes the one on this cell.
- **`[C]` drags a chamber rectangle** — `[ENTER]` drops a corner, move, `[ENTER]` names it and
  writes to `chambers.txt`, then re-derives so layer 6 shows what it actually claimed.

Headless: `./dungeon.run mapdebugshot 1234 out.png` (the digits are layers; add `event` to
include the event panel).

---

### DATA EDITOR — `./dungeon.run dataedit`

Every pipe-delimited table as a grid, with column names lifted from each file's own header
comment. Covers `assets/data/<pack>/`, its `theme/` subdir, and `assets/flavor/<pack>/` —
**35 tables**: monsters, treasures, items, curios, traps, classes, tuning, strings, chambers,
triggers, overlays, theme colours, and all the flavor prose.

`arrows` move · `ENTER` edits the cell · `I` inserts a row · `X` deletes one · `S` saves ·
`R` reloads · `TAB` back to the file list · `ESC` out.

Saving backs up to `<file>.bak` first and only ever on an explicit `S`. Comments, blank lines
and column alignment survive — only the line you edited is rewritten.

---

### PACK BROWSER — `./dungeon.run packbrowse`, or `[B]` from SETTINGS

All six kinds of content pack with real previews instead of just a name.

| kind | preview |
|---|---|
| ART | four sprites drawn **from that pack** |
| SFX | how much of the effect roster it ships, as a bar |
| MUSIC / NARRATION | its files |
| DATA / ANSI ART | what it ships, and therefore what it overrides |

`arrows` pick · `TAB` next kind · `P` plays one of *its* sounds · `ENTER` selects it (audio and
art apply now; data and ansi art on next launch) · `ESC` out.

---

### CUT-SCENE PLAYER + EDITOR — `engine/cutplay/cutplay.run`

Its own binary, because it is the authoring loop for the cut-scene language.

    cutplay.run assets/cutscenes/default/intro.cut
    cutplay.run <scene.cut> class=wizard gold=6000    # drive a branch
    cutplay.run <scene.cut> edit                      # timeline editor: scrub and tune
    cutplay.run <scene.cut> lint                      # resolve every asset it names
    cutplay.run <scene.cut> shot out.png              # one frame at a fixed time

`[R]` recompiles from disk and restarts. Full reference: **[engine/cutplay/CUTPLAY.md](engine/cutplay/CUTPLAY.md)**
for the player, **[assets/cutscenes/CUT-DSL.md](assets/cutscenes/CUT-DSL.md)** for the language.

---

## In-game keys worth knowing

| key | what |
|---|---|
| `` ` `` | dev console — type `dump` for the topic list. Works from **any** screen. |
| `~` | debug overlay; then `[0]` cheat panel, `[9]` map debugger, left-click teleports |
| `Q` | first-person view **(WIP)** — W/S walk, A/D turn, `,`/`.` strafe, mouse looks |
| `TAB` | run-stats overlay; `Shift-TAB` swaps it to BEARINGS (what is playing / drawn, with paths) |
| `M` | game menu — character sheet, bestiary, treasury, event log, rules, storybook |
| `?` | every key binding |

---

## Lints — the ones that answer a question you cannot see

Most of these are in the test gate (`tests/run-tests.sh`) and exit non-zero on failure.

| mode | what it catches |
|---|---|
| `roomlint` | a room whose monster sits somewhere nothing can stand — run after **any** board-art edit |
| `datalint` | drop odds vs pool contents, unhandled item codes, unwinnable class goals |
| `dataedittest` | load → save is a no-op across all 35 tables |
| `triggerlint` | a cut-scene trigger on an unwalkable cell, or naming a scene that does not exist |
| `overlaylint` | an overlay whose art does not resolve, or that draws nothing |
| `windlint` | the secret-door draught: falloff shape, and which packs ship a sample |
| `themelint` | proves the theme file is actually being read (a misspelt key silently keeps the default) |
| `fogdump` | a secret region no door opens — which can strand the Level Key and make a run unwinnable |
| `sectorauto` | derives each level's rectangle from the art alone; reports overlaps and holes |
| `spritealpha` | sprites drawn on an opaque background (a floating box in first person) |
| `ansilint [file]` | mask line endings, per-row width, the **iCE flag**, unmapped colours |
| `packs` | what SETTINGS will actually offer, which is not the same as what is on disk |
| `econdump` | expected gold economy, win pacing per class, and the monster curve by depth |

Add `nocolor` to any of them for plain output (or set `NO_COLOR`).

`./dungeon.run --help` lists everything.

---

## Screenshot modes

These render one frame and write a PNG, so a screen can be checked without watching it:
`settingsshot` · `charsheet` · `creatorshot` · `rollshot` · `storyshot` · `fightshot` ·
`mapdebugshot` · `dataeditshot` · `packbrowseshot` · `fpsshot <col> <row> <deg> out.png`.

`fpsshot` also accepts `aim` / `aimmon` / `aimdoor` (turn to the nearest sprite or door **in
line of sight**), `hurt` (fire the combat impulses so a still frame shows them) and `hand`.
It snaps to the nearest walkable cell, and prints why any sprite was rejected.
