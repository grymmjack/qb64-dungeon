#!/usr/bin/env bash
# Generate every pixel-art asset in manifest.txt via ~/pixelmon across the ComfyUI render farm.
#
# Assets are written into a PACK subdirectory of assets/pixel-art/ (pack containers):
#     assets/pixel-art/<pack>/<folder>/<name>.png
# The game selects a pack in SETTINGS; "default" is the base pack.
#
#   ./generate.sh                                        # default pack, everything not already done
#   ./generate.sh monsters                               # default pack, only folders containing "monsters"
#   ./generate.sh --pack pixelmon-1 --style-prefix darkest
#                                                        # a themed pack, forcing a dark gritty
#                                                        # Darkest-Dungeon look on top of every asset
#   ./generate.sh --pack pixelmon-1 --server rtx,mac items
#                                                        # pick nodes + a folder filter for a pack
#
# Resumable: skips any asset whose clean <pack>/<folder>/<name>.png already exists. Auto-detects
# which ComfyUI nodes are up (unless --server is given) and splits the work across them round-robin
# (one worker per node, in parallel). Each asset gets a clean "<name>.png" for the game to load.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PIXELMON="$HOME/pixelmon/bin/pixelmon"
# The manifest is CANONICAL: it comes from the game itself (`dungeon.run imagemanifest`), so the
# asset LIST is derived from the content tables and cannot drift from what the game actually loads.
# The authored style/size/prompt per asset lives in assets/data/art-prompts.txt and is merged in
# by the manifest. Same model the ansi and audio generators already use.
#   MANIFEST=<file> overrides with a pre-captured manifest (dungeon.run is a binary F5 replaces,
#   so a rebuild during a long run would otherwise change the list mid-flight).
GAME="$(cd "$ROOT/../.." && pwd)"
MANIFEST_SRC="${MANIFEST:-}"

MANIFEST="$(mktemp)"
trap 'rm -f "$MANIFEST"' EXIT
if [ -n "$MANIFEST_SRC" ] && [ -s "$MANIFEST_SRC" ]; then
  cp "$MANIFEST_SRC" "$MANIFEST"
  echo "manifest : $MANIFEST_SRC (pre-captured)"
else
  [ -x "$GAME/dungeon.run" ] || { echo "no $GAME/dungeon.run - build it first (F5)"; exit 1; }
  ( cd "$GAME" && ./dungeon.run imagemanifest nocolor ) > "$MANIFEST" 2>/dev/null
  echo "manifest : dungeon.run imagemanifest  ($(grep -m1 '^# ENTRIES:' "$MANIFEST"))"
fi
grep -q '^pixel-art/' "$MANIFEST" || { echo "manifest has no pixel-art rows - aborting"; exit 1; }

# --- args -------------------------------------------------------------------
PACK="default"        # which pack subdir under assets/pixel-art/ to write into
STYLE_PREFIX=""        # style(s) to prepend to every asset's manifest style (themed packs)
SERVER_LIST=""         # explicit node list (comma alias list); empty = auto-detect the farm
FILTER=""              # folder substring filter
while [ "$#" -gt 0 ]; do
  case "$1" in
    --pack)          PACK="${2:?--pack needs a name}"; shift 2 ;;
    --style-prefix)  STYLE_PREFIX="${2:?--style-prefix needs a style}"; shift 2 ;;
    --server)        SERVER_LIST="${2:?--server needs a list}"; shift 2 ;;
    -h|--help)       grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    --*)             echo "unknown option: $1" >&2; exit 2 ;;
    *)               FILTER="$1"; shift ;;
  esac
done

# --- the render farm (name -> host:port) ------------------------------------
declare -A NODES=( [local]=127.0.0.1:8188 [titan]=192.168.1.172:8188 [rtx]=192.168.1.77:8188 [mac]=192.168.1.120:8188 )
probe() {  # $1 = alias -> echoes the alias if the node answers, else nothing
  local n="$1"
  [ -z "${NODES[$n]:-}" ] && { echo "unknown server: $n" >&2; return; }
  local code; code=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://${NODES[$n]}/system_stats" 2>/dev/null)
  if [ "$code" = "200" ]; then echo "$n"; fi
}
UP=()
if [ -n "$SERVER_LIST" ]; then
  IFS=',' read -ra want <<< "$SERVER_LIST"
  for n in "${want[@]}"; do
    if [ -n "$(probe "$n")" ]; then UP+=("$n"); echo "node UP  : $n (${NODES[$n]})"; else echo "node down: $n (requested)"; fi
  done
else
  for n in local titan rtx mac; do
    if [ -n "$(probe "$n")" ]; then UP+=("$n"); echo "node UP  : $n (${NODES[$n]})"; else echo "node down: $n"; fi
  done
fi
[ ${#UP[@]} -eq 0 ] && { echo "No ComfyUI nodes are up. Launch at least one and re-run."; exit 1; }

# --- read the manifest ------------------------------------------------------
# Canonical format (dungeon.run imagemanifest):
#     pixel-art/<folder>/<name>.png | style | size | prompt
# Only pixel-art rows are ours -- the same manifest also carries ansi-art rows for ansimon, so
# the media prefix is the filter. The folder may be nested (monsters/beasts), and it MATTERS:
# the game only ever looks inside those category subfolders.
folders=(); names=(); styles=(); sizes=(); prompts=()
while IFS='|' read -r pth style size prompt; do
  pth="$(echo "$pth" | xargs)"
  case "$pth" in
    pixel-art/*) : ;;
    *) continue ;;                               # comments, blanks, and ansi-art rows
  esac
  pth="${pth#pixel-art/}"; pth="${pth%.png}"
  folder="${pth%/*}"; name="${pth##*/}"
  # Every manifest path is <folder>/<name>; a path with no slash would make folder == name and
  # write to the pack root, where the game never looks. Skip it rather than misplace the file.
  [ "$folder" = "$pth" ] && continue
  [ -z "$folder" ] && continue
  [ -z "$name" ] && continue
  style="$(echo "$style" | xargs)"; size="$(echo "$size" | xargs)"
  prompt="$(echo "$prompt" | sed 's/^ *//; s/ *$//')"
  [ -n "$FILTER" ] && [[ "$folder" != *"$FILTER"* ]] && continue
  folders+=("$folder"); names+=("$name"); styles+=("$style"); sizes+=("$size"); prompts+=("$prompt")
done < "$MANIFEST"

total=${#names[@]}
[ "$total" -eq 0 ] && { echo "Nothing to generate (filter: '${FILTER:-none}')."; exit 0; }
echo "-> pack '$PACK': $total asset(s) across ${#UP[@]} node(s): ${UP[*]}${STYLE_PREFIX:+  [style-prefix: $STYLE_PREFIX]}"

# prepend STYLE_PREFIX to a row's style, dropping duplicate comma tokens (order preserved)
combine_style() {
  [ -z "$STYLE_PREFIX" ] && { printf '%s' "$1"; return; }
  printf '%s,%s' "$STYLE_PREFIX" "$1" | awk -F',' '{
    out=""; for (i=1;i<=NF;i++) if (!seen[$i]++) out=(out==""?$i:out","$i); print out
  }'
}

gen_one() {  # $1 = manifest index, $2 = node name
  local i="$1" node="$2" dir="$ROOT/$PACK/${folders[$i]}" nm="${names[$i]}"
  mkdir -p "$dir"
  # resume off the CLEAN file (the raw pixelmon temp is deleted after each render)
  if [ -f "$dir/${nm}.png" ]; then echo "  skip $PACK/${folders[$i]}/${nm}"; return; fi
  local style; style="$(combine_style "${styles[$i]}")"
  echo "  [$node] $PACK/${folders[$i]}/${nm}  ($style)  <- ${prompts[$i]:0:46}..."
  if "$PIXELMON" "${prompts[$i]}" --style "$style" --size "${sizes[$i]}" --transparent \
        --server "$node" --output-to "$dir" --name "$nm" --create-dirs >/dev/null 2>&1; then
    local produced; produced="$(ls -t "$dir/${nm}"_*.png 2>/dev/null | head -1)"
    if [ -n "$produced" ]; then
      cp -f "$produced" "$dir/${nm}.png"   # clean name for the game to load
      rm -f "$dir/${nm}"_*.png             # tidy up the raw pixelmon temp(s)
    else
      echo "  WARN  no output produced for ${nm} on $node"
    fi
  else
    echo "  FAILED ${nm} on $node"
  fi
}

# one worker loop per up-node, running in parallel; assets dealt round-robin
for ni in "${!UP[@]}"; do
  (
    node="${UP[$ni]}"
    for (( i=ni; i<total; i+=${#UP[@]} )); do gen_one "$i" "$node"; done
  ) &
done
wait
echo "DONE. pack '$PACK': $(find "$ROOT/$PACK" -name '*.png' ! -name '*_*.png' | wc -l) clean sprite(s) in $ROOT/$PACK"
