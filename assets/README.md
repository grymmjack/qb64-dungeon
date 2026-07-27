# `assets/` — the editable content of the dungeon

Almost everything in the game — the bestiary, loot, traps, all the prose, the music,
and the sound effects — lives in plain text (and audio) files here. **Edit a file and
press F5 to rebuild; no code change needed.** This is the map of what's where.

```
assets/
├── data/      game tables   (monsters, treasures, items, bosses, traps, effects)
├── flavor/    all the prose (room text, combat event text, epitaphs, brutal-hit lines)
├── music/     playlist.txt  + music tracks (per dungeon level)
├── sfx/       optional real sound-effect files (fall back to the tone beeper)
├── ansi/      the text-mode art — board, menus, monsters (see the caveat below)
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

| File | One row is… | Columns |
|---|---|---|
| `monsters.txt`  | a monster    | `lvl \| slot \| name \| HERO \| ELF \| SUP \| WIZ` (2d6 kill numbers; 13 = "-") |
| `treasures.txt` | a treasure   | `lvl \| slot \| name \| gold` |
| `items.txt`     | a magic item | `lvl \| slot \| name \| gold \| type` (overrides that treasure slot) |
| `bosses.txt`    | a boss name  | `slot \| name` |
| `traps.txt`     | a curio trap | `kind \| name \| save \| word \| sfx \| die \| trigger \| savemsg \| failtitle \| failbody` |
| `effects.txt`   | a crit/fumble line | `table \| kind \| die \| text` (table 1 crit / 2 you-fumble / 3 monster-fumble) |
| `chambers.txt`  | a chamber    | `name \| col1 \| row1 \| col2 \| row2` (bounding rectangle in cells; walkable cells inside = its trigger zone) |

`chambers.txt` is the exact, hand-authored map of the big named halls (3 monsters, no
treasure each). The board art is fixed so these never move; press `[~]` in-game to read a
cell's `col,row` under the mouse, then tighten any box. If the file is missing the game
falls back to auto-detecting chambers by openness.

Each level (1–9) has **3 monster + 3 treasure slots**; a room rolls one of them. Item
`type` codes and trap `kind` values are documented in the header of each file. Trap
*mechanics* (poison/bomb/frost/siren) are fixed in code by `kind`; everything else about
a trap is data.

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

---

## `assets/ansi/` — the art *is* the map  (⚠ edit with care)

The board, menus, and monster art are `.ans`/`.icy`/`.xb` text-mode files. The **board
art doubles as the collision map**: movement is decided by sampling the exact pixel
colours, so the palette values must match what the engine checks — an anti-aliased or
off-by-one colour silently breaks movement. Safe to retheme the *look*; risky to change
the board's structure or colours without knowing the collision rules (see `CLAUDE.md`).

---

*Live preference/save files (`dungeon-settings.dat`, `dungeon-save.dat`,
`dungeon-lords.dat`) live at the repo root, are git-ignored, and are written by the game —
don't hand-edit or delete them.*
