# `assets/` — the editable content of the dungeon

Almost everything in the game — the bestiary, loot, traps, all the prose, the music,
and the sound effects — lives in plain text (and audio) files here. **Edit a file and
press F5 to rebuild; no code change needed.** This is the map of what's where.

```
assets/
├── data/      game tables   (monsters, loot, traps, effects, sectors, classes, tuning, UI strings…)
├── flavor/    all the prose (room text, combat event text, epitaphs, brutal-hit lines)
├── music/     playlist.txt  + music tracks (per dungeon level)
├── sfx/       optional real sound-effect files (fall back to the tone beeper)
├── ansi/      the text-mode art — board, board MASKS, menus, monsters (see the caveat below)
└── fonts/     the DPoly polyhedral dice fonts (not meant to be edited)
```

## Shared format rules

- **Pipe-delimited**: fields are separated by `|` and each field is **trimmed**, so you
  can pad with spaces to line the columns up — `1 | 1 | GIANT RATS | 4` reads the same
  as `1|1|GIANT RATS|4`.
- Lines starting with `#` are **comments**; blank lines are ignored.
- Files are **re-read every launch**, so changes are live after F5 (no recompile of code).
- Keep the **column count** right — a monster row needs all 7 fields, a trap row all 10.
- Line endings are **LF** everywhere except the `.ans` art, which must stay **CRLF**.

---

## `assets/data/` — game tables  (loaded by `include/DATA.bas`)

**Content — the bestiary, loot, and encounters:**

| File | One row is… | Columns |
|---|---|---|
| `monsters.txt`  | a monster    | `lvl \| slot \| name \| HERO \| ELF \| SUP \| WIZ` (2d6 kill numbers; 13 = "-") |
| `treasures.txt` | a treasure   | `lvl \| slot \| name \| gold` |
| `items.txt`     | a magic item | `lvl \| slot \| name \| gold \| type` (overrides that treasure slot) |
| `bosses.txt`    | a boss name  | `slot \| name` |
| `curios.txt`    | a curio      | `kind \| name \| weight \| prompt` (fountains, chests, shrines… `kind` picks the mechanic) |
| `traps.txt`     | a curio trap | `kind \| name \| save \| word \| sfx \| die \| trigger \| savemsg \| failtitle \| failbody` |
| `effects.txt`   | a crit/fumble line | `table \| kind \| die \| text` (table 1 crit / 2 you-fumble / 3 monster-fumble) |

**Board layout — geometry read from data + matching board MASKS (see `assets/ansi/`):**

| File | One row is… | Columns |
|---|---|---|
| `sectors.txt`  | a dungeon level | `id \| label \| col1 \| row1 \| col2 \| row2 \| RRGGBB` (fallback rectangle + colour; the sector **mask** overrides the rects when present) |
| `labels.txt`   | a board caption | `col \| row \| text` (0-based cell; blank lines just group the list) |
| `chambers.txt` | a chamber       | `name \| col1 \| row1 \| col2 \| row2` (bounding rectangle in cells; walkable cells inside = its trigger zone) |

**Tuning & presentation — knobs, classes, and all the UI chrome:**

| File | One row is… | Columns |
|---|---|---|
| `tuning.txt`      | a balance knob | `KEY \| value` (potion drop %, treasure odds, idle/wander/XP timers, move max…) |
| `classes.txt`     | a player class | `id \| name \| gold_goal \| combat_bonus \| secret_bonus \| hp \| tohit \| dmg \| ac \| hitdie \| blurb` |
| `dice-colors.txt` | a dice palette | `id \| name \| body \| ink` (RRGGBB; the 6 SETTINGS dice colours) |
| `strings.txt`     | a UI string    | `key \| text` (looked up by `Say$("key")`; **split on the FIRST `\|`**, so text may contain `\|`) |
| `ui-fonts.txt`    | a UI font map  | `region \| fontfile \| size` (see the UI-fonts section below) |

`chambers.txt` is the exact, hand-authored map of the big named halls (3 monsters, no
treasure each). The board art is fixed so these never move; press `[~]` in-game to read a
cell's `col,row` under the mouse, then tighten any box. If a layout file is missing the game
falls back to auto-detecting (chambers by openness, sectors by the `sectors.txt` rects).

Each level (1–9) has **3 monster + 3 treasure slots**; a room rolls one of them. Item
`type` codes and trap `kind` values are documented in the header of each file. Trap
*mechanics* (poison/bomb/frost/siren) are fixed in code by `kind`; everything else about
a trap is data. `strings.txt` migration is incremental — a key that isn't found returns the
key itself, so missing text is visible rather than blank.

---

## `assets/flavor/` — the prose  (loaded by `include/FLAVOR.bas` + `include/CTEXT.bas`)

| File | One row is… | Key |
|---|---|---|
| `regular.txt`        | an ordinary-room one-liner | `level` (1–9) |
| `special.txt`        | a named-room description    | room name — `THE CRYPT`, `ARMORY`, `KING'S LIBRARY`, … |
| `maxhit.txt`         | a "crushing blow" line      | *(no key — just the text)* |
| `forfeit.txt`        | a death epitaph             | *(no key)* |
| `monster_events.txt` | a monster's combat line     | monster name, or `*` (default) — event: attack/miss/crit/fumble/death |
| `class_events.txt`   | a class's combat line       | class name, or `*` — event: attack/miss/crit/fumble/death |

For the `*_events.txt` files the format is `key | event | text`, and **`key "*"` is the
fallback** used when a specific monster/class has no line for that event — so you only
write lines where they matter (a slime dissolves, a dragon immolates). Add as many
variants per (key, event) as you like; one is chosen at random.

### Tokens (usable in any flavor text)

`{player}` champion name (or "you") · `{class}` · `{mon}` · `{dmg}` damage this event ·
`{deaths}` times you've died · `{level}` 1–9 · `{room}` room label · `{treasure}` ·
`{item}` / `{weapon}` your weapon

---

## `assets/music/` — per-level music  (loaded by `include/MUSIC.bas`)

- **`playlist.txt`** maps each level to a track: `level | filename`. Levels sharing a
  filename play seamlessly (the track doesn't restart); a level with no line keeps
  whatever's already playing.
- Drop the tracks themselves in this folder. `_SNDOPEN` reads **`.ogg` `.mp3` `.wav`
  `.flac`** and trackers **`.rad` `.mod` `.xm` `.s3m` `.it`**. Prefer **`.ogg`/`.mp3`**
  for full-length music (a `.wav` is uncompressed and can be huge).
- `vr-theme.rad` (intro) and `everdark.rad` (menu) are referenced directly by the menu
  code, not the playlist.
- **Music packs (themes).** Any *sub-folder* here is a "pack": drop a themed set of the same
  track filenames into `assets/music/<pack-name>/` and pick it in **SETTINGS → Music Pack**.
  The selected pack wins; any track it doesn't include falls back to the flat main folder.
  A subdir only counts as a pack if it holds at least one audio file. With no subdirs, the
  flat folder is all there is (`(main)`).
- **Context cues (not levels).** Besides the per-level tracks, a few bare names play at
  specific moments — drop a file with that name in and it plays; absent, the level track keeps
  going: **`victory`** (win screen), **`lose`** (death screen), and **`combat-low`** /
  **`combat-high`** / **`combat-intense`** (a D&D fight, by level / boss — loops during the
  fight, hands back to the level track after).

---

## `assets/narration/` — optional spoken narration  (loaded by `include/MUSIC.bas`)

Voice-over for the UI lines, keyed by the same keys as **`assets/data/strings.txt`**. Drop a
file named after a string key and the game speaks it when that line shows — e.g.
`win.title.ogg` booms over the victory banner. Absent → nothing spoken (the typewriter blips
still cover it). Extensions: `.ogg .mp3 .wav .flac`. Loaded on demand, one line at a time;
volume follows **Voice Vol**; turn it on and pick a voice with **SETTINGS → Narration**
(cycles *off → (main) → each pack*). Sub-folders are **packs** (voices/themes) exactly like
SFX/Music. Currently spoken: `win.title`, `lose.title` — add `Narrate "<key>"` at any other
string's display site to voice it. See [`narration/README.txt`](narration/README.txt).

---

## `assets/fonts/ui/` + `assets/data/ui-fonts.txt` — UI fonts  (loaded by `LoadUIFonts`)

- Drop TrueType (`.ttf`/`.otf`) fonts in **`assets/fonts/ui/`**, then map UI regions to them in
  **`ui-fonts.txt`**: `region | fontfile | size`. A blank file or size `0` keeps the built-in
  8×16 grid font for that region.
- Regions: **`label`** (room names on the map), **`message`** (narration / banners),
  **`combat`** (the combat panel — loaded MONOSPACE so HP bars stay even), **`menu`** (titles),
  **`hud`** (bottom status bar). `combat`/`hud` are forced monospace; the rest are proportional.
- Edit a row, press F5 — no code change to restyle a region.

---

## `assets/sfx/` — optional real sound effects  (loaded by `include/MUSIC.bas`)

Drop `<name>.ogg` (or `.mp3`/`.wav`/`.flac`) named after an effect and it plays **instead
of** that effect's tone beeper; effects with no file keep beeping. Volume follows the SFX
Vol slider, and effects overlap. The full list of overridable names is in
[`sfx/README.txt`](sfx/README.txt) — e.g. `hit`, `crit`, `treasure`, `chest`, `boom`,
`hiss`, `win`, `lose`, `key`, `move`.

**SFX packs (themes).** Just like music, any *sub-folder* is a pack: put a themed set of the
same effect filenames in `assets/sfx/<pack-name>/` and choose it in **SETTINGS → SFX Pack**.
The pack overrides only the effects it actually ships; anything missing falls back to the
flat folder (and then to the beeper). A subdir counts as a pack only if it holds at least one
audio file; with no subdirs you just get the flat folder (`(main)`).

---

## `assets/ansi/` — the art *is* the map  (⚠ edit with care)

The board, menus, and monster art are `.ans`/`.icy`/`.xb` text-mode files. The **board
art doubles as the collision map**: movement is decided by sampling the exact pixel
colours, so the palette values must match what the engine checks — an anti-aliased or
off-by-one colour silently breaks movement. Safe to retheme the *look*; risky to change
the board's structure or colours without knowing the collision rules (see `CLAUDE.md`).

### Board MASKS — art-as-data overlays (same 132×50 grid as the board)

Two `.ans` files are painted **on top of** the board layout as pure data — one cell's
colour = one value. Paint them in any ANSI editor (fill cells with a coloured **background +
space**, not a `█` block, so rows don't get sliver gaps), and keep the **SAUCE record**
(dimensions) intact.

- **`board-132x50-sector-mask.ans`** — each cell's colour says which dungeon **level** owns
  it, letting levels be any shape (not just the `sectors.txt` rectangles). When present it
  wins; black = sector 0 (harmless over walls/corridors, but a room floor needs a real
  sector). The `[~]` overlay reads the sector under the mouse.
- **`board-132x50-secret-mask.ans`** — each non-black colour marks a **secret region**
  reachable through a hidden door; distinct colours nest secrets-within-secrets. `[F]`
  searching reveals a door and just the region it gates.

Generate starter masks from the current heuristics with `dungeon.run sectorgen` /
`dungeon.run maskgen` (they **refuse to overwrite** an existing mask, so your hand-painted
versions are safe), then paint from there. Run `dungeon.run --help` for all dev modes.

**Two editor artifacts silently corrupt a mask** — the game repairs both when it loads a mask,
but it's worth knowing:

- **CRLF line endings.** Each row is exactly 132 columns, so the renderer wraps at column 132 *and*
  the CRLF then advances again — a blank row between every painted row ("black bands"), and half the
  cells stop registering. (The board and secret mask avoid this by having no line breaks at all.)
- **Sticky bright colours.** A bright (iCE) background left set from one cell can bleed into the next
  cell that only changed the base colour — e.g. teal turning into bright cyan — so a level reads as
  the wrong one.

Run **`dungeon.run ansilint`** (or `dungeon.run ansilint <file.ans>`) to check a mask: it reports the
line endings, row widths, the SAUCE dimensions, and every painted colour mapped to its level —
flagging colours that match no level and levels you haven't painted. It only reads the file, never
writes it. To *fix* a mask's stored file, **`dungeon.run ansifix <file.ans>`** rewrites it clean
(strips the blank-row CR/LFs, resets each colour run) and backs the original up to `<file>.bak`.

Both tools (and `--help`, and the other dev modes) print in colour — green = OK, yellow = warning,
red = problem. Set the `NO_COLOR` environment variable, or append `nocolor` to any command, for
plain text.

---

*Live preference/save files (`dungeon-settings.dat`, `dungeon-save.dat`,
`dungeon-lords.dat`) live at the repo root, are git-ignored, and are written by the game —
don't hand-edit or delete them.*
