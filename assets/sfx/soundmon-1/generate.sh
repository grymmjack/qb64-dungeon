#!/usr/bin/env bash
# Regenerate the soundmon-1 SFX pack from effects.txt.
#
# Reads  name | seconds | max | style | prompt  rows and produces <name>.wav here,
# which is exactly what the game's SFX-pack loader wants (see ../README.txt).
#
# Fans the work across the render farm by pinning ONE soundmon process per box
# and dealing the effects round-robin. soundmon's own --server pool parallelises
# a multi-job run, but each effect here needs its own prompt/length/style, so
# one process per box is the simpler way to keep every GPU busy.
#
#   ./generate.sh                      # use the default box list
#   BOXES="local,titan" ./generate.sh  # or pick your own
#   ./generate.sh hit crit boom        # regenerate only these effects
set -uo pipefail

cd "$(dirname "$(readlink -f "$0")")"
MANIFEST="effects.txt"
BOXES="${BOXES:-local,titan,mac,rtx}"
SEED_ARG="${SEED:+--seed $SEED}"

# OGG=1 ./generate.sh  -> compress output (~25x smaller). The game tries
# .ogg BEFORE .wav for sfx/narration, so ogg wins automatically there; for
# MUSIC the ladder ends at .wav (best), so an .ogg is only used if no .wav
# sits beside it — which is why this replaces rather than adds.
OGG_ARG="${OGG:+--ogg}"

command -v soundmon >/dev/null || { echo "soundmon not on PATH"; exit 1; }

IFS=',' read -ra POOL <<< "$BOXES"
WANT=("$@")

want() {   # no args = regenerate everything
    [ ${#WANT[@]} -eq 0 ] && return 0
    for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done
    return 1
}

# Deal the rows out to per-box job lists.
declare -a JOBS
n=0
while IFS='|' read -r name secs maxs style prompt; do
    name="$(echo "$name" | xargs)"
    [ -z "$name" ] && continue
    case "$name" in \#*) continue;; esac
    want "$name" || continue
    JOBS[$((n % ${#POOL[@]}))]+="$name|$(echo "$secs" | xargs)|$(echo "$maxs" | xargs)|$(echo "$style" | xargs)|$(echo "$prompt" | xargs)"$'\n'
    n=$((n + 1))
done < <(grep -v '^[[:space:]]*#' "$MANIFEST")

echo "▶ ${n} effect(s) across ${#POOL[@]} box(es): ${POOL[*]}"

run_box() {   # $1 = server alias, $2 = newline-separated jobs
    local srv="$1"
    while IFS='|' read -r name secs maxs style prompt; do
        [ -z "${name:-}" ] && continue
        local cap=""
        [ "${maxs:-0}" != "0" ] && cap="--max-seconds $maxs"
        soundmon "$prompt" --style "$style" --seconds "$secs" --name "$name" \
                 $cap --server "$srv" $OGG_ARG --output-to . --no-open $SEED_ARG >/dev/null 2>&1
        # soundmon names files <name>_<secs>s_<fmt>_s<seed>_00001_.wav; the game
        # wants a bare <name>.wav, so collapse to that (newest wins on a re-run).
        local made
        made="$(find . -maxdepth 1 \( -name "${name}_*.wav" -o -name "${name}_*.ogg" \) -printf '%T@ %p\n' \
                | sort -rn | head -1 | cut -d' ' -f2-)"
        if [ -n "$made" ]; then
            ext="${made##*.}"
            mv -f "$made" "./${name}.${ext}"
            find . -maxdepth 1 \( -name "${name}_*.wav" -o -name "${name}_*.ogg" \) -delete
            echo "   ✅ ${srv%%:*}  ${name}.${ext}"
        else
            echo "   ❌ ${srv%%:*}  ${name}  (nothing produced)"
        fi
    done <<< "$2"
}

for i in "${!POOL[@]}"; do
    [ -n "${JOBS[$i]:-}" ] && run_box "${POOL[$i]}" "${JOBS[$i]}" &
done
wait

echo "▶ done — $(find . -maxdepth 1 \( -name '*.wav' -o -name '*.ogg' \) | wc -l) file(s) in $(pwd)"
