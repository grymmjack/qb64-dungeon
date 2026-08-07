# GRISTLE

**G**rymmjack's **R**eusable **I**nteractive **S**ystems **T**oolkit for **L**ightweight **E**pics

A QB64PE engine for text-mode games, where **the art you draw is the map the game
reads**. Paint a corridor in an ANSI editor and the player can walk down it — there
is no separate tile data, no level format, no export step. The picture *is* the
level.

It also reads as *gristle*: the tough connective tissue between the parts.

```basic
'$INCLUDE:'engine/_ALL.BI'      ' every header
' ... your game ...
'$INCLUDE:'engine/_ALL.BM'      ' every body
```

Two lines. No build system, no package manager, no external dependencies — a plain
checkout compiles.

---

## The idea

    engine = the parts  ·  assets = the fuel  ·  game = the assembly

The engine knows nothing about your game. It does not know where your files live,
what your data tables look like, what a "room" is, or what happens when a player
steps somewhere. It asks — through **hooks** and **registries** — and you answer.

Which means the same engine that runs a nine-level dungeon crawl will run yours,
with your art, your tables, your rules, and **all of the tooling below** working on
day one.

## What you get

| | |
|---|---|
| **Board** | collision, rooms, zones, doors, secret regions, fog-of-war and line-of-sight — all derived by scanning your art |
| **First-person** | a raycaster over the *same* collision data, with billboards, thin-wall doors and a flickering torch |
| **Cut-scenes** | a scripted DSL — layered art, pan/zoom camera, GIF + multi-file ANSI animation, transitions, effects, branching, choices — with its own player and timeline editor |
| **Dice** | 3D polyhedral dice with real physics, plus font and hand-drawn pip renderers |
| **Audio** | music with crossfades, positional loops, sfx, narration, per-category format preferences |
| **Content packs** | every asset tree is `<kind>/<pack>/…`, falling back to `default` **per file**, so a partial pack overrides only what it ships |
| **UI** | 9-grid frames, fades, panels, typewriter text, markdown rendering, a dev console |

## And the tools, which are the point

Every one of these is *engine*, not game — a debugger that only debugs one game is
a feature, not tooling.

```sh
./yourgame.run mapdebug      # every derived board layer, toggleable, over the board
./yourgame.run dataedit      # your data tables as a grid, comments preserved
./yourgame.run packbrowse    # your content packs, with real previews
./yourgame.run --help        # ...and about forty lints and screenshot modes
```

The map debugger draws **your** layers and fires **your** events, because you
register them:

```basic
MapLayer "walkable", ML_CELL      ' you fill a colour per cell
MapLayer "doors",    ML_MARK      ' ...or draw your own marks
MapEvent "Spawn a monster", -1    ' -1 = needs a run in progress
```

Same shape for dump topics, asset kinds, pack kinds and data tables. The engine
provides the mechanism and the registry; you provide the entries. **Nothing is a
fixed list**, so adding one never means editing the engine.

## Start a game

```sh
engine/new-game.sh ../my-game "MY GAME"
cd ../my-game && qb64pe -w -x my-game.bas -o my-game.run && ./my-game.run
```

That project **compiles and runs immediately** — a board you can walk around, every
hook stubbed with a legitimate "nothing here yet" answer, and an asset tree waiting
for content. Then you start replacing things.

The scaffolder generates from [`examples/minimal`](../examples/minimal), which is a
real second game on this engine, checked by the test gate on every run — so it
cannot drift from the contract the way a hand-written template would.

## The rules the engine holds itself to

Enforced by scripts in `tests/`, not by good intentions:

- **No game symbol** in `engine/` — every call out goes through a `Game_*` hook
- **No game path** in `engine/` — hosts *declare* their asset tree; the engine asks for *kinds*
- **No game schema** in `engine/` — hosts declare their tables; four tools then stop guessing
- **A second game proves it** — `examples/minimal` runs on `engine/` alone, with its own asset tree

## Docs

- [ENGINE.md](ENGINE.md) — the boundary, the hook contract, and the record of how each leak was closed
- [cutplay/CUTPLAY.md](cutplay/CUTPLAY.md) — the cut-scene player and editor
- `assets/cutscenes/CUT-DSL.md` (in a host project) — the cut-scene language

## Requirements

[QB64 Phoenix Edition](https://github.com/QB64-Phoenix-Edition/QB64pe) 4.4.0 or
4.5.0. Nothing else.
