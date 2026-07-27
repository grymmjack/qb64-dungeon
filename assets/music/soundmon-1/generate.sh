#!/usr/bin/env bash
# Regenerate the soundmon-1 music set from tracks.txt.
#
# Reads  name | seconds | bpm | key | tags  and produces <name>.wav here — the
# bare names assets/music/playlist.txt expects (it picks the best file that
# exists for a name, and .wav is top of that ladder).
#
# Uses soundmon --song (ACE-Step 1.5), NOT --music: Stable Audio tops out at 47s
# and wanders on anything longer, while ACE is an actual music model that holds
# a theme for minutes and takes bpm/key directly. No --lyrics = instrumental.
#
# DYNAMIC DISPATCH: boxes pull the next track when they go free, rather than
# each being pre-assigned a fixed share. Song generation times vary enormously
# across a mixed fleet — measured on this one, 28s on an RTX 3070 versus 468s on
# an RX 6600, a 16x spread — so dealing the work out evenly by COUNT strands the
# whole run behind the slowest card. This is the same lesson soundmon's own
# --server pool encodes; the pre-dealt version of this script did not, and a
# 9-track run finished ~3x later than it needed to.
#
#   ./generate.sh                      # everything
#   ./generate.sh crypt inferno        # only these
#   BOXES="rtx,titan" ./generate.sh    # pick boxes (rtx/RTX 3070 is fastest)
set -uo pipefail

cd "$(dirname "$(readlink -f "$0")")"
MANIFEST="tracks.txt"
BOXES="${BOXES:-local,titan,mac,rtx}"

# OGG=1 ./generate.sh  -> compress output (~25x smaller). The game tries
# .ogg BEFORE .wav for sfx/narration, so ogg wins automatically there; for
# MUSIC the ladder ends at .wav (best), so an .ogg is only used if no .wav
# sits beside it — which is why this replaces rather than adds.
OGG_ARG="${OGG:+--ogg}"

command -v soundmon >/dev/null || { echo "soundmon not on PATH"; exit 1; }

IFS=',' read -ra POOL <<< "$BOXES"
WANT=("$@")
want() {
    [ ${#WANT[@]} -eq 0 ] && return 0
    for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done
    return 1
}

QUEUE="$(mktemp)"; LOCK="$(mktemp)"
trap 'rm -f "$QUEUE" "$LOCK"' EXIT

n=0
while IFS='|' read -r name secs bpm key tags; do
    name="$(echo "$name" | xargs)"; [ -z "$name" ] && continue
    case "$name" in \#*) continue;; esac
    want "$name" || continue
    printf '%s|%s|%s|%s|%s\n' "$name" "$(echo "$secs" | xargs)" "$(echo "$bpm" | xargs)" \
           "$(echo "$key" | xargs)" "$(echo "$tags" | xargs)" >> "$QUEUE"
    n=$((n + 1))
done < <(grep -v '^[[:space:]]*#' "$MANIFEST")

echo "▶ ${n} track(s), dynamic dispatch across ${#POOL[@]} box(es): ${POOL[*]}"
echo "  (songs are slow — a 60s track runs ~30s on a fast card, minutes on a slow one)"

# Atomically pop the next job. The lock is held for both the read and the
# delete, so two boxes can never claim the same track.
take() {
    (
        flock 9
        head -n 1 "$QUEUE"
        sed -i '1d' "$QUEUE"
    ) 9>"$LOCK"
}

run_box() {
    local srv="$1" job
    while :; do
        job="$(take)"
        [ -z "$job" ] && break
        IFS='|' read -r name secs bpm key tags <<< "$job"
        local t0=$SECONDS
        soundmon "$tags" --song --seconds "$secs" --bpm "$bpm" --key "$key" \
                 --name "$name" --server "$srv" $OGG_ARG --output-to . --no-open >/dev/null 2>&1
        local made
        made="$(find . -maxdepth 1 \( -name "${name}_*.wav" -o -name "${name}_*.ogg" \) -printf '%T@ %p\n' \
                | sort -rn | head -1 | cut -d' ' -f2-)"
        if [ -n "$made" ]; then
            ext="${made##*.}"
            mv -f "$made" "./${name}.${ext}"
            find . -maxdepth 1 \( -name "${name}_*.wav" -o -name "${name}_*.ogg" \) -delete
            echo "   ✅ ${srv%%:*}  ${name}.${ext}  ($((SECONDS - t0))s)"
        else
            echo "   ❌ ${srv%%:*}  ${name}  (nothing produced)"
        fi
    done
}

for srv in "${POOL[@]}"; do run_box "$srv" & done
wait

echo "▶ done — $(find . -maxdepth 1 \( -name '*.wav' -o -name '*.ogg' \) | wc -l) track(s) in $(pwd)"
