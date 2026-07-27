#!/usr/bin/env bash
# Generate audio for a pack straight from the game's own manifest.
#
#   ./generate-from-manifest.sh <sfx|music|narration> <pack> [name ...]
#
# `dungeon.run audiomanifest` emits  path | prompt-or-text  for every asset the
# game will ever look up. Driving generation from THAT rather than a
# hand-maintained list means the filenames can't drift out of sync with the
# keys the game asks for — a mismatch is invisible in the audio (the files
# sound perfect) and silently produces assets the game never plays.
#
# By default only MISSING entries are generated, so this is a gap-filler you can
# re-run safely. FORCE=1 regenerates everything.
#
#   ./generate-from-manifest.sh sfx soundmon-1
#   OGG=1 ./generate-from-manifest.sh music soundmon-2
#   VOICE=bm_lewis ./generate-from-manifest.sh narration soundmon-2
#   FORCE=1 ./generate-from-manifest.sh sfx soundmon-1 hit crit
#
# Per-pack knobs live in <pack>/pack.conf (sourced if present):
#   STYLE      extra --style guides appended to every prompt
#   PROMPT_ADD text appended to every prompt (a pack's sonic identity)
#   SECONDS    default length
set -uo pipefail

ASSETS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GAME="$(dirname "$ASSETS")"
SECTION="${1:?usage: $0 <sfx|music|narration> <pack> [name ...]}"
PACK="${2:?usage: $0 <sfx|music|narration> <pack> [name ...]}"
shift 2 || true
WANT=("$@")

BOXES="${BOXES:-local,titan,mac,rtx}"
OGG_ARG="${OGG:+--ogg}"
DEST="$ASSETS/$SECTION/$PACK"
mkdir -p "$DEST"

command -v soundmon >/dev/null || { echo "soundmon not on PATH"; exit 1; }
[ -x "$GAME/dungeon.run" ] || { echo "no $GAME/dungeon.run — build it first (F5)"; exit 1; }

# Pack identity (optional)
STYLE=""; PROMPT_ADD=""; SECONDS_DEF=""
VOICE="${VOICE:-bm_george}"; PITCH="${PITCH:--3}"; SPEED="${SPEED:-0.92}"
[ -f "$DEST/pack.conf" ] && . "$DEST/pack.conf"

MAN="$(mktemp)"; QUEUE="$(mktemp)"; LOCK="$(mktemp)"
trap 'rm -f "$MAN" "$QUEUE" "$LOCK" "$QUEUE.lines"' EXIT
( cd "$GAME" && ./dungeon.run audiomanifest ) > "$MAN" 2>/dev/null

# Trim without xargs: the prompts contain apostrophes ("a monster's snarl"),
# and xargs treats quotes as syntax — it errors out on every such line.
trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }

want() {
    [ ${#WANT[@]} -eq 0 ] && return 0
    for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done
    return 1
}
have() {   # any extension the game accepts already present?
    for e in ogg mp3 wav flac; do [ -f "$DEST/$1.$e" ] && return 0; done
    return 1
}

# --- build the work list -------------------------------------------------
total=0; skipped=0
while IFS='|' read -r path prompt; do
    path="$(trim "$path")"; prompt="$(trim "$prompt")"
    case "$path" in "$SECTION"/*) ;; *) continue;; esac
    name="${path#"$SECTION"/}"
    [ -z "$name" ] && continue
    want "$name" || continue
    if [ -z "${FORCE:-}" ] && have "$name"; then skipped=$((skipped+1)); continue; fi
    printf '%s|%s\n' "$name" "$prompt" >> "$QUEUE"
    total=$((total+1))
done < <(grep -E "^$SECTION/" "$MAN")

if [ "$total" -eq 0 ]; then
    echo "▶ $SECTION/$PACK: nothing to do ($skipped already present)"
    exit 0
fi
echo "▶ $SECTION/$PACK: $total to generate, $skipped already present"

# --- narration: one batched CPU run (Kokoro loads once, ~1s a line) ------
if [ "$SECTION" = narration ]; then
    sed 's/|/ | /' "$QUEUE" > "$QUEUE.lines"
    echo "  voice $VOICE  pitch $PITCH  speed $SPEED  (CPU, no farm)"
    soundmon --narrate-file "$QUEUE.lines" --voice "$VOICE" --pitch "$PITCH" \
             --speed "$SPEED" $OGG_ARG --output-to "$DEST" --create-dirs
    echo "▶ done — $(find "$DEST" -maxdepth 1 \( -name '*.ogg' -o -name '*.wav' \) | wc -l) file(s) in $DEST"
    exit 0
fi

# --- sfx / music: fan across the farm, DYNAMIC dispatch -----------------
IFS=',' read -ra POOL <<< "$BOXES"
take() { ( flock 9; head -n 1 "$QUEUE"; sed -i '1d' "$QUEUE" ) 9>"$LOCK"; }

run_box() {
    local srv="$1" job name prompt made t0 ext
    while :; do
        job="$(take)"; [ -z "$job" ] && break
        name="${job%%|*}"; prompt="${job#*|}"
        [ -n "$PROMPT_ADD" ] && prompt="$prompt, $PROMPT_ADD"
        t0=$SECONDS
        if [ "$SECTION" = music ]; then
            # Songs, not SFX: ACE-Step holds a theme for minutes; Stable Audio
            # tops out at 47s and wanders. bpm/key come from tracks.txt if the
            # pack has one, else ACE's defaults.
            local bpm key secs
            bpm="$(awk -F'|' -v n="$name" '$1 ~ n {gsub(/ /,"",$3); print $3; exit}' "$DEST/tracks.txt" 2>/dev/null)"
            key="$(awk -F'|' -v n="$name" '$1 ~ n {gsub(/^ +| +$/,"",$4); print $4; exit}' "$DEST/tracks.txt" 2>/dev/null)"
            secs="${SECONDS_DEF:-60}"
            soundmon "$prompt" --song --seconds "$secs" \
                     ${bpm:+--bpm $bpm} ${key:+--key "$key"} \
                     --name "$name" --server "$srv" $OGG_ARG \
                     --output-to "$DEST" --no-open >/dev/null 2>&1
        else
            soundmon "$prompt" ${STYLE:+--style "$STYLE"} --seconds "${SECONDS_DEF:-3}" \
                     --name "$name" --server "$srv" $OGG_ARG \
                     --output-to "$DEST" --no-open >/dev/null 2>&1
        fi
        # soundmon names files <name>_<...>_00001_.<ext>; the game wants <name>.<ext>
        made="$(find "$DEST" -maxdepth 1 \( -name "${name}_*.ogg" -o -name "${name}_*.wav" \) \
                -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)"
        if [ -n "$made" ]; then
            ext="${made##*.}"
            mv -f "$made" "$DEST/${name}.${ext}"
            find "$DEST" -maxdepth 1 \( -name "${name}_*.ogg" -o -name "${name}_*.wav" \) -delete
            echo "   ✅ ${srv%%:*}  ${name}.${ext}  ($((SECONDS - t0))s)"
        else
            echo "   ❌ ${srv%%:*}  ${name}  (nothing produced)"
        fi
    done
}

for srv in "${POOL[@]}"; do run_box "$srv" & done
wait
echo "▶ done — $(find "$DEST" -maxdepth 1 \( -name '*.ogg' -o -name '*.wav' \) | wc -l) file(s) in $DEST"
