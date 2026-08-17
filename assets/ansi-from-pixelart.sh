#!/usr/bin/env bash
# Turn a generated PIXEL-ART pack into an ANSI-ART pack with kaleidotron.
#
#   assets/ansi-from-pixelart.sh <pack> [subpath ...]
#
#   assets/ansi-from-pixelart.sh JuggernautXL-DarkestDungeon
#   assets/ansi-from-pixelart.sh JuggernautXL-DarkestDungeon monsters/undead/ghoul.ans
#   PRESET="ANSI 80x25 not bad" FORCE=1 assets/ansi-from-pixelart.sh JuggernautXL-1
#
# The flow is: gen high-res AI images (pixel-art/<pack>/, via art-from-manifest.sh)
# -> convert each to ANSI here. kaleidotron does a MUCH better textmode conversion
# than a text->ANSI model: the AI detail survives the trip down to a character grid.
#
# The manifest is still the contract. Each `ansi-art/...` row gives the output
# subpath and, crucially, the CHARACTER GRID size the game expects:
#
#   ansi-art/monsters/animals/giant-rat.ans | darkest | 18x12 | <prompt>
#
# The subpath (minus `ansi-art/`) is exactly what AnsiFile$() asks for, and it's
# also the pixel-art PNG's subpath (with .png) — so no mapping table. The PixelFX
# PRESET supplies the pack's LOOK (palette + shading); `--cols/--rows/--cell`
# override the grid so every asset lands at its manifest size, `strategic-combat/*`
# on the 8x8 tactical cell and everything else on the 8x16 board cell.
#
# Env:
#   PRESET="ANSI 80x25 not bad"   kaleidotron PixelFX preset (the pack's colour +
#                                 shading identity). Put it in a pack.conf to let a
#                                 pack describe its own look. Run `kaleidotron
#                                 --list-presets` to see them; must be an ANSI one.
#   PACK_OUT=<name>               ansi-art/ folder name (default: same as <pack>).
#   FORMAT=auto|ans|xb|tnd        textmode format (default: the preset's).
#   FORCE=1                       re-convert assets that already exist.
#   MANIFEST=<file>               use this manifest instead of dungeon.run's.
set -uo pipefail

ASSETS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GAME="$(dirname "$ASSETS")"
PACK="${1:?usage: $0 <pack> [subpath ...]}"
shift || true
WANT=("$@")

SRC="$ASSETS/pixel-art/$PACK"
DEST="$ASSETS/ansi-art/${PACK_OUT:-$PACK}"
PRESET="${PRESET:-ANSI 80x25 not bad}"
[ -f "$SRC/pack.conf" ] && . "$SRC/pack.conf"
[ -f "$DEST/pack.conf" ] && . "$DEST/pack.conf"

# Locate kaleidotron: PATH, then the usual build dirs.
KT="$(command -v kaleidotron || true)"
for c in "$HOME/git/kaleidotron/target/release/kaleidotron" \
         "$HOME/git/kaleidotron/target/debug/kaleidotron"; do
    [ -z "$KT" ] && [ -x "$c" ] && KT="$c"
done
[ -x "$KT" ] || { echo "kaleidotron not found (build it: cd ~/git/kaleidotron && cargo build --release)"; exit 1; }
[ -d "$SRC" ] || { echo "no pixel-art pack at $SRC — generate it first (art-from-manifest.sh --pack $PACK)"; exit 1; }

MAN="$(mktemp)"; trap 'rm -f "$MAN"' EXIT
if [ -n "${MANIFEST:-}" ] && [ -s "$MANIFEST" ]; then
    cp "$MANIFEST" "$MAN"
else
    [ -x "$GAME/dungeon.run" ] || { echo "no $GAME/dungeon.run — build it first (F5)"; exit 1; }
    ( cd "$GAME" && ./dungeon.run imagemanifest nocolor ) >  "$MAN" 2>/dev/null
    ( cd "$GAME" && ./dungeon.run fightmanifest nocolor ) >> "$MAN" 2>/dev/null
fi
grep -q '^ansi-art/' "$MAN" || { echo "manifest has no ansi-art rows — aborting"; exit 1; }

trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }
want() { [ ${#WANT[@]} -eq 0 ] && return 0; for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done; return 1; }

made=0 skipped=0 missing=0 failed=0
FMT_ARG=(); [ -n "${FORMAT:-}" ] && FMT_ARG=(--format "$FORMAT")

while IFS='|' read -r f_path f_style f_size f_prompt; do
    path="$(trim "$f_path")"
    case "$path" in ansi-art/*) sub="${path#ansi-art/}";; *) continue;; esac
    [ -z "$sub" ] && continue
    want "$sub" || continue

    size="$(trim "$f_size")"
    cols="${size%%x*}"; rest="${size#*x}"; rows="${rest%% *}"
    case "$cols$rows" in ''|*[!0-9]*) echo "  ?? bad size '$size' for $sub"; continue;; esac

    # Cell comes from the group: the tactical screen is 8x8, else the 8x16 board.
    case "$sub" in strategic-combat/*) cell=8x8;; *) cell=8x16;; esac

    png="$SRC/${sub%.ans}.png"
    out="$DEST/$sub"
    if [ ! -f "$png" ]; then
        printf '  ?? %-50s (no pixel-art PNG — generate the image first)\n' "$sub"
        missing=$((missing+1)); continue
    fi
    if [ -z "${FORCE:-}" ] && [ -f "$out" ]; then
        skipped=$((skipped+1)); continue
    fi

    mkdir -p "$(dirname "$out")"
    if "$KT" --batch "$png" --preset "$PRESET" \
             --cols "$cols" --rows "$rows" --cell "$cell" \
             "${FMT_ARG[@]}" --outdir "$(dirname "$out")" >/dev/null 2>&1; then
        printf '  ✅ %-50s %sx%s @%s\n' "$sub" "$cols" "$rows" "$cell"
        made=$((made+1))
    else
        printf '  ❌ %-50s (conversion failed)\n' "$sub"
        failed=$((failed+1))
    fi
done < "$MAN"

echo "▶ ansi-art/${PACK_OUT:-$PACK}: $made converted, $skipped kept, $missing missing PNG, $failed failed"
echo "  preset: \"$PRESET\"   →  $DEST"
[ "$failed" -eq 0 ]
