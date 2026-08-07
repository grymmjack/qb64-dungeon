#!/usr/bin/env bash
# ============================================================================
#  engine/new-game.sh -- start a new game on this engine.
#
#      engine/new-game.sh ../my-game "MY GAME"
#
#  Writes a project that COMPILES AND RUNS on the spot: an assembly file, every
#  hook stubbed, an asset tree with a board in it, and a README saying what to
#  edit first. Walk around with the arrow keys, then start replacing things.
#
#  IT GENERATES FROM examples/minimal, deliberately. That is the second game
#  this engine already drives, it implements every hook, and it is checked by
#  the test gate on every run -- so this scaffolder cannot drift from the
#  contract the way a hand-written template would. When a hook is added,
#  minimal gains it (the gate insists) and so does every project made after.
#
#  What it does NOT do is invent content. A scaffolded game is deliberately
#  almost empty: one board, one zone, no monsters. The engine is the parts; what
#  you put in the tank is the game.
# ============================================================================
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"        # wherever the engine lives
# The engine ships its own examples/, so this works whether the engine is a
# subdirectory of a game (engine/examples/minimal) or the repo root itself
# (./examples/minimal). The demo belongs to the ENGINE -- it is the proof that
# the boundary holds, and the template this scaffolder generates from.
src="$here/examples/minimal"

dest="${1:-}"
title="${2:-NEW GAME}"

if [[ -z "$dest" ]]; then
    echo "usage: engine/new-game.sh <target-dir> [\"GAME TITLE\"]"
    echo "  e.g. engine/new-game.sh ../my-game \"CAVERNS OF X\""
    exit 2
fi
if [[ -e "$dest" ]]; then
    echo "!! $dest already exists -- refusing to write over it."
    exit 1
fi
if [[ ! -d "$src" ]]; then
    echo "!! cannot find $src -- the scaffolder generates from examples/minimal."
    exit 1
fi

slug="$(basename "$dest")"
mkdir -p "$dest"

# --- the engine itself -------------------------------------------------------
# Copied rather than referenced, so the new project stands alone from minute
# one. Point it at a submodule later if you would rather track the engine.
cp -R "$here" "$dest/engine"
rm -rf "$dest/engine/.git" 2>/dev/null || true

# --- the hooks: minimal's, verbatim ------------------------------------------
# These ARE the contract. Every one is a stub that answers "nothing here yet",
# which is a legitimate answer for all of them -- that is why the engine can run
# a game that has not been written.
cp "$src/HOOKS.bas" "$dest/HOOKS.bas"

# --- the assembly ------------------------------------------------------------
# The asset root is anchored to _STARTDIR$ -- the directory the game was
# LAUNCHED from. A bare "assets/" does not resolve reliably here: a QB64 binary
# reports _CWD$ as neither its own directory nor the shell's, while _STARTDIR$
# tracks the launch directory correctly. See CLAUDE.md.
sed -e "s|\\.\\./\\.\\./engine/|engine/|g" \
    -e "s|AssetRoot \"examples/minimal/assets/\"|AssetRoot _STARTDIR\$ + \"assets/\"|g" \
    -e "s|examples/minimal/assets/|assets/|g" \
    -e "s|minimal: engine booted under a non-DUNGEON! game|$title: booted|g" \
    "$src/minimal.bas" > "$dest/$slug.bas"

# --- the asset tree ----------------------------------------------------------
# Every kind the assembly declares gets a default/ folder, so a first asset has
# somewhere obvious to go.
for kind in ansi-art pixel-art sfx music narration cutscenes data flavor; do
    mkdir -p "$dest/assets/$kind/default"
done
mkdir -p "$dest/assets/fonts"
cp "$src/assets/ansi-art/default/board-132x50-no-labels.ans" \
   "$dest/assets/ansi-art/default/board-132x50-no-labels.ans"

cat > "$dest/README.md" <<EOF
# $title

Built on the engine in [engine/](engine/). It compiles and runs as-is:

\`\`\`sh
qb64pe -w -x $slug.bas -o $slug.run
./$slug.run              # arrows/WASD to walk, ESC to quit
./$slug.run selftest     # what the engine found in your board
\`\`\`

## What you have

A board (\`assets/ansi-art/default/board-132x50-no-labels.ans\`) and nothing else.
The engine reads that art as **both the picture and the collision map** — bright
yellow is walkable, plain yellow is a door, bright blue is a secret door, black
is wall. Redraw it in any ANSI editor and the level changes.

## What to edit first

| file | what it decides |
|---|---|
| \`$slug.bas\` | where your assets live (\`AssetRoot\` / \`AssetKind\`) |
| \`HOOKS.bas\` | everything the engine asks your game |

Every hook is stubbed with a "nothing here yet" answer, which is why this runs
before you have written a game. Fill them in as you need them:

* \`Game_FloorColorAt~&\` — which colours you count as floor
* \`Game_ZoneCount%\` / \`Game_ZoneName\$\` — your levels or areas
* \`Game_OnEnterCell%\` — what happens when the player steps somewhere
* \`Game_MapRegister\` — layers and events for the map debugger (\`[~]\` then \`[9]\`)

## Tools you already have

\`\`\`sh
./$slug.run mapdebug      # every derived board layer, toggleable
./$slug.run dataedit      # your data tables as a grid
./$slug.run packbrowse    # your content packs, with previews
\`\`\`
EOF

echo "created $dest"
echo "  engine/        the engine, copied in"
echo "  $slug.bas      the assembly -- declares where your assets live"
echo "  HOOKS.bas      every hook, stubbed"
echo "  assets/        one board, and a home for everything else"
echo
echo "next:  cd $dest && qb64pe -w -x $slug.bas -o $slug.run && ./$slug.run"
