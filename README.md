# DUNGEON!

A dungeon-crawler written in **QB64 Phoenix Edition (QB64PE)** BASIC, adapting the
mechanics of TSR's classic **_Dungeon!_ board game (1975)** into a real-time,
text-mode video game. The graphics are ANSI / text-mode art rendered to off-screen
32-bit images, and gameplay (movement, rooms, sectors, collision) is driven by
**sampling the pixels of that rendered art** rather than a separate tile model —
the art literally _is_ the map.

Nine dungeon levels, four classes (Hero / Elf / Superhero / Wizard) with authentic
win totals, two combat systems (classic Dungeon! 2d6-vs-target and a D&D-style
d20/HP mode), secret doors, curios, traps, hot-seat multiplayer, solo challenge
modes, animated polyhedral dice, and near-death "juice" (blood, vignette, heartbeat).

## Build & run

The game builds from a **plain checkout — no submodule build dependency.** The one
thing it needed from a third-party library (an ANSI renderer) is **vendored** in
`include/ansi/`, and file reads use QB64PE's built-in `_READFILE$`.

- Requires a local **[QB64PE](https://www.qb64phoenix.com/)** install (4.4.0 / 4.5.0).
- In VS Code with the `grymmjack.qb64pe` extension, open **`dungeon.bas`** and press **F5**.
- By hand: `qb64pe -w -x dungeon.bas -o dungeon.run` (`.exe` on Windows), then run it.

`dungeon.run --help` lists the command-line dev/diagnostic modes.

## Assets are generated — and self-describing

Almost everything the game shows and plays lives in editable files under `assets/`
(pipe-delimited data tables, ANSI art, pixel art, audio). The visual and audio
assets are produced by two companion generators, and the game emits its own
**manifests** telling those generators exactly what to make (path, size/length, and
a prompt or the line to speak, all computed from the loaded data):

| Generator | Makes | Fed by |
|---|---|---|
| **[pixelmon](https://github.com/grymmjack/pixelmon)** | pixel-art sprites (`assets/pixel-art/`) and ANSI art (`assets/ansi-art/`) | `dungeon.run imagemanifest`, `dungeon.run uimanifest` |
| **[soundmon](https://github.com/grymmjack/soundmon)** | sound effects, music, and spoken narration (`assets/sfx/`, `assets/music/`, `assets/narration/`) | `dungeon.run audiomanifest` |

Each manifest line is `path | (size or length) | prompt-or-text`, so a generator
can consume it directly — e.g. `dungeon.run audiomanifest | grep '^sfx/'`.

### Packs (themes)

SFX, music, narration, and pixel-art each support **packs**: drop a themed set into a
sub-folder (e.g. `assets/sfx/soundmon-souls/`) and select it in **SETTINGS**. The flat
folders are the default; a pack overrides only what it ships and falls back to the main
assets for anything it's missing.

## Learn more

- **[CLAUDE.md](CLAUDE.md)** — full architecture (art-as-collision, sectors, masks, packs, dice, combat).
- **[assets/README.md](assets/README.md)** — the player/modder map of every editable asset.
- **[DUNGEON-RULES.md](DUNGEON-RULES.md)** — the _Dungeon!_ rules this reproduces.
- **[PLANS.todo](PLANS.todo)** — roadmap and the source of truth for intended rules.
