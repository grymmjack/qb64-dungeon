#!/usr/bin/env bash
# Generate an ANSI art pack from the game's own manifest, with ansimon.
#
#   assets/generate-ansi-from-manifest.sh <pack> [subpath ...]
#
#   assets/generate-ansi-from-manifest.sh ansimon-1
#   assets/generate-ansi-from-manifest.sh ansimon-1 strategic-combat/monsters/goblin.ans
#   FORCE=1 BOXES=rtx assets/generate-ansi-from-manifest.sh ansimon-1
#
# The sibling of generate-from-manifest.sh, same shape: the manifest is the
# contract, the pack is a directory, the farm is a flock'd queue with dynamic
# dispatch. Nothing here restates a size — `dungeon.run fightmanifest` derives
# every one from assets/data/ui-fight-layout.txt, so editing the layout and
# re-running this is the whole workflow.
#
# The manifest rows this consumes look like:
#
#   ansi-art/strategic-combat/monsters/goblin.ans | ansi | 33x25 chars @8x8 | <prompt>
#
# `path` minus the leading `ansi-art/` is exactly the subpath AnsiFile$() asks
# for (engine/ARTPACK.bas), so the pack layout falls out of the manifest and
# needs no mapping table. @8x8 becomes ansimon's --vga50; @8x16 is its default.
#
# Env:
#   BOXES=local,mac,rtx   farm pool (any down box is skipped)
#   FORCE=1               re-render assets that already exist
#   PNG=1                 also keep a .png of each piece (off: pixel-viewer
#                         renders .ans directly, so a twin only clutters)
#   SEED=4242             fixed so a re-run reproduces the pack
#   STEPS=30              sampler steps
#   LORA / STRENGTH       override ansimon's defaults
set -uo pipefail

ASSETS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GAME="$(dirname "$ASSETS")"
PACK="${1:?usage: $0 <pack> [subpath ...]}"
shift || true
WANT=("$@")

BOXES="${BOXES:-local,mac,rtx}"
SEED="${SEED:-4242}"
STEPS="${STEPS:-30}"
DEST="$ASSETS/ansi-art/$PACK"

command -v ansimon >/dev/null || { echo "ansimon not on PATH"; exit 1; }
mkdir -p "$DEST"
[ -f "$DEST/pack.conf" ] && . "$DEST/pack.conf"

MAN="$(mktemp)"; QUEUE="$(mktemp)"; LOCK="$(mktemp)"
trap 'rm -f "$MAN" "$QUEUE" "$LOCK"' EXIT

if [ -n "${MANIFEST:-}" ] && [ -s "$MANIFEST" ]; then
    cp "$MANIFEST" "$MAN"
else
    [ -x "$GAME/dungeon.run" ] || { echo "no $GAME/dungeon.run — build it first (F5)"; exit 1; }
    ( cd "$GAME" && ./dungeon.run fightmanifest ) > "$MAN" 2>/dev/null
fi
grep -qE '\| *ansi *\|' "$MAN" || { echo "manifest has no ansi rows — aborting"; exit 1; }

trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }
want() {
    [ ${#WANT[@]} -eq 0 ] && return 0
    for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done
    return 1
}

AUDITOR="$ASSETS/audit-ansi-pack.py"
APY="$(command -v python3)"
[ -x "$HOME/ComfyUI/.venv/bin/python" ] && APY="$HOME/ComfyUI/.venv/bin/python"
REJECTS="$(mktemp)"; trap 'rm -f "$MAN" "$QUEUE" "$LOCK" "$REJECTS"' EXIT

build_queue() {   # $1 = "all" | path to a reject list
    : > "$QUEUE"; total=0; skipped=0
    while IFS='|' read -r f_path f_kind f_size f_prompt; do
    [ "$(trim "$f_kind")" = ansi ] || continue
    path="$(trim "$f_path")"
    case "$path" in ansi-art/*) sub="${path#ansi-art/}";; *) sub="$path";; esac
    size="$(trim "$f_size")"; prompt="$(trim "$f_prompt")"
    [ -z "$sub" ] || [ -z "$prompt" ] && continue
    # "33x25 chars @8x8" -> cols, rows, cell
    cols="${size%%x*}"
    rest="${size#*x}"; rows="${rest%% *}"
    cell="${size##*@}"
    case "$cols$rows" in ''|*[!0-9]*) echo "  ?? bad size '$size' for $sub"; continue;; esac
    want "$sub" || continue
    if [ "$1" != all ]; then
        # Re-roll round: only what the audit rejected.
        grep -qxF "$sub" "$1" || { skipped=$((skipped+1)); continue; }
    elif [ -z "${FORCE:-}" ] && [ -f "$DEST/$sub" ]; then
        skipped=$((skipped+1)); continue
    fi
    printf '%s|%s|%s|%s|%s\n' "$sub" "$cols" "$rows" "$cell" "$prompt" >> "$QUEUE"
    total=$((total+1))
    done < "$MAN"
}

IFS=',' read -ra POOL <<< "$BOXES"
take() { ( flock 9; head -n 1 "$QUEUE"; sed -i '1d' "$QUEUE" ) 9>"$LOCK"; }

run_box() {
    local srv="$1" job sub cols rows cell prompt td out fails=0 t0
    while :; do
        job="$(take)"; [ -z "$job" ] && break
        IFS='|' read -r sub cols rows cell prompt <<< "$job"
        t0=$SECONDS
        td="$(mktemp -d)"
        # Per-asset seed, derived from the subpath so it stays reproducible.
        # A single pack-wide seed means every portrait starts from the SAME
        # noise, and at 33x25 the LoRA has so little room that shared noise plus
        # a shared prompt shape collapses them toward one face — measured: the
        # closest pairs sat at 0.049 thumbnail distance against a 0.157 median.
        # ROUND shifts it so a re-roll after an audit failure lands somewhere new.
        jobseed=$(( (SEED + $(printf '%s' "$sub" | cksum | cut -d' ' -f1) \
                    + ROUND * 7919) % 2147483647 ))
        set -- --cols "$cols" --rows "$rows" --format ans \
               --seed "$jobseed" --steps "$STEPS" --no-open \
               --title "$(basename "${sub%.ans}")" --author grymmjack \
               --group "$PACK" --name out --output-to "$td"
        [ "$cell" = "8x8" ] && set -- "$@" --vga50
        [ -n "${LORA:-}" ] && set -- "$@" --lora "$LORA"
        [ -n "${STRENGTH:-}" ] && set -- "$@" --lora-strength "$STRENGTH"
        if ansimon "$prompt" --server "$srv" "$@" >"$td/log" 2>&1; then
            out="$(find "$td" -maxdepth 1 -name '*.ans' | head -1)"
        else
            out=""
        fi
        if [ -n "$out" ]; then
            mkdir -p "$DEST/$(dirname "$sub")"
            mv -f "$out" "$DEST/$sub"
            # PNG=1 keeps ansimon's render beside the .ans. Off by default:
            # pixel-viewer renders .ans natively, so a PNG twin just doubles
            # every row of the thumbnail grid with an identical image and
            # doubles the pack on disk. It is worth having for anyone WITHOUT
            # an .ans-aware viewer, which is why it is a switch and not a
            # deletion. The .ans is always the asset the game loads.
            if [ -n "${PNG:-}" ]; then
                find "$td" -maxdepth 1 -name '*_ansi_*.png' -exec \
                     mv -f {} "$DEST/${sub%.ans}.png" \; 2>/dev/null
            fi
            printf '  ✅ %-52s %3ss  %s\n' "$sub" "$((SECONDS - t0))" "$srv"
            fails=0
        else
            # ROCm prints "amdgpu.ids: No such file or directory" on every run;
            # it is noise and would otherwise be the last line, hiding the cause.
            printf '  ❌ %-52s %s  %s\n' "$sub" "$srv" \
                   "$(grep -vE 'amdgpu\.ids' "$td/log" 2>/dev/null \
                      | grep -vE '^\s*$' | tail -1 | head -c 70)"
            fails=$((fails + 1))
            # Dynamic dispatch means a dead box would otherwise drain the whole
            # queue into a hole. Retire it and let the healthy boxes finish.
            if [ "$fails" -ge 3 ]; then
                echo "  ⚠ $srv failed 3 in a row — dropping it from the pool"
                rm -rf "$td"; break
            fi
        fi
        rm -rf "$td"
    done
}

audit() {
    [ -x "$AUDITOR" ] || { echo "  (no auditor at $AUDITOR — skipping)"; return 0; }
    "$APY" "$AUDITOR" --pack "$PACK" --assets "$ASSETS" \
        --manifest "$MAN" --reject-file "$REJECTS" 2>&1 | grep -v 'amdgpu\.ids'
    return "${PIPESTATUS[0]}"
}

# Generate, audit, re-roll whatever failed, until the audit is clean or ROUNDS
# is spent. The seed shifts by round, so a rejected asset genuinely gets
# different noise instead of re-rendering the same picture forever.
ROUNDS="${ROUNDS:-3}"
ROUND=0
mode=all
while :; do
    build_queue "$mode"
    if [ "$total" -eq 0 ]; then
        [ "$ROUND" -eq 0 ] && { echo "▶ ansi-art/$PACK: nothing to do ($skipped present)"; }
        break
    fi
    echo "▶ ansi-art/$PACK round $((ROUND + 1))/$ROUNDS: $total to render, $skipped kept  [$BOXES]"
    for srv in "${POOL[@]}"; do run_box "$srv" & done
    wait
    stranded=$(wc -l < "$QUEUE")
    [ "$stranded" -gt 0 ] && echo "  ⚠ $stranded job(s) never ran (all boxes dropped)"

    if audit; then
        echo "▶ audit clean"
        break
    fi
    ROUND=$((ROUND + 1))
    if [ "$ROUND" -ge "$ROUNDS" ]; then
        echo "▶ $ROUNDS round(s) spent; $(wc -l < "$REJECTS") asset(s) still flagged."
        echo "  Re-run to keep trying, or accept them — the flags are advisory,"
        echo "  not proof the art is unusable."
        break
    fi
    mode="$REJECTS"
    echo "▶ re-rolling $(wc -l < "$REJECTS") flagged asset(s) with fresh seeds"
done

made=$(find "$DEST" -name '*.ans' | wc -l)
echo "▶ done — $made .ans in $DEST"
exit 0
