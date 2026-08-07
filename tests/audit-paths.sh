#!/usr/bin/env bash
# ============================================================================
#  audit-paths.sh -- the engine may name no GAME PATH.
#
#  audit-boundary.sh checks that engine/ names no game SYMBOL, and it passed
#  cleanly on a codebase with ~50 hardcoded "assets/..." paths inside engine/ --
#  the data tree, the art tree, the fonts, the theme file, the playlist. Every
#  one of those is the engine depending on something only DUNGEON! has, which is
#  the same violation wearing different clothes. Copy engine/ into another
#  project and it goes looking for a tree that is not there.
#
#  So: no literal asset path may appear in engine/. The assembly declares its
#  tree once (game/ASSETTREE.bas) and the engine asks for KINDS
#  (engine/ASSETS.bas: AssetPath$ / AssetDir$ / AssetPackFile$ / AssetRoute$).
#
#  Comments are exempt -- they are where the reasoning lives, and the reasoning
#  frequently needs to name the very path it is explaining the absence of.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
hits=0

for f in engine/*.bas engine/*.BI engine/*/*.bas engine/*/*.bi; do
    [[ -e "$f" ]] || continue
    # strip comments, then look for a quoted literal starting with the root name
    while IFS=: read -r ln text; do
        [[ -z "${ln:-}" ]] && continue
        printf '  !! %s:%s\n' "$f" "$ln"
        printf '     %s\n' "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-100)"
        hits=$((hits + 1))
    done < <(awk -F"'" '{print NR": "$1}' "$f" | grep -E '"assets/' || true)
done

if (( hits )); then
    echo
    echo "$hits hardcoded asset path(s) in engine/ -- the engine must ask for KINDS."
    echo "  declare the tree in game/ASSETTREE.bas, then use AssetPath\$/AssetDir\$/AssetPackFile\$."
    exit 1
fi

echo "no engine/ file names a literal asset path (the tree is declared, not assumed)."
exit 0
