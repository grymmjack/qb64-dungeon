#!/usr/bin/env bash
# Generate every pixel-art asset in manifest.txt via ~/pixelmon across the ComfyUI render farm.
#
#   ./generate.sh              # generate everything not already done
#   ./generate.sh monsters     # only rows whose folder contains "monsters"
#   ./generate.sh items        # only items, etc.
#
# Resumable: skips any asset whose raw output already exists. Auto-detects which ComfyUI
# nodes are up and splits the work across them round-robin (one worker per node, in parallel).
# Each asset also gets a clean "<name>.png" copy for the game to load.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PIXELMON="$HOME/pixelmon/bin/pixelmon"
MANIFEST="$ROOT/manifest.txt"
FILTER="${1:-}"

# --- the render farm (name -> host:port) ---
declare -A NODES=( [local]=127.0.0.1:8188 [titan]=192.168.1.172:8188 [rtx]=192.168.1.77:8188 [mac]=192.168.1.120:8188 )
UP=()
for n in local titan rtx mac; do
  code=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://${NODES[$n]}/system_stats" 2>/dev/null)
  if [ "$code" = "200" ]; then UP+=("$n"); echo "node UP  : $n (${NODES[$n]})"; else echo "node down: $n"; fi
done
[ ${#UP[@]} -eq 0 ] && { echo "No ComfyUI nodes are up. Launch at least one and re-run."; exit 1; }

# --- read the manifest ---
folders=(); names=(); styles=(); sizes=(); prompts=()
while IFS='|' read -r folder name style size prompt; do
  case "$folder" in ''|\#*|' '*'#'*) : ;; esac
  folder="$(echo "$folder" | xargs)"; [ -z "$folder" ] && continue
  case "$folder" in \#*) continue ;; esac
  name="$(echo "$name" | xargs)"; style="$(echo "$style" | xargs)"; size="$(echo "$size" | xargs)"
  prompt="$(echo "$prompt" | sed 's/^ *//; s/ *$//')"
  [ -n "$FILTER" ] && [[ "$folder" != *"$FILTER"* ]] && continue
  folders+=("$folder"); names+=("$name"); styles+=("$style"); sizes+=("$size"); prompts+=("$prompt")
done < "$MANIFEST"

total=${#names[@]}
[ "$total" -eq 0 ] && { echo "Nothing to generate (filter: '${FILTER:-none}')."; exit 0; }
echo "-> $total asset(s) across ${#UP[@]} node(s): ${UP[*]}"

gen_one() {  # $1 = manifest index, $2 = node name
  local i="$1" node="$2" dir="$ROOT/${folders[$i]}" nm="${names[$i]}"
  mkdir -p "$dir"
  # resume off the CLEAN file (the raw pixelmon temp is deleted after each render)
  if [ -f "$dir/${nm}.png" ]; then echo "  skip ${folders[$i]}/${nm}"; return; fi
  echo "  [$node] ${folders[$i]}/${nm}  <- ${prompts[$i]:0:52}..."
  if "$PIXELMON" "${prompts[$i]}" --style "${styles[$i]}" --size "${sizes[$i]}" --transparent \
        --server "$node" --output-to "$dir" --name "$nm" --create-dirs >/dev/null 2>&1; then
    local produced; produced="$(ls -t "$dir/${nm}"_*.png 2>/dev/null | head -1)"
    if [ -n "$produced" ]; then
      cp -f "$produced" "$dir/${nm}.png"   # clean name for the game to load
      rm -f "$dir/${nm}"_*.png             # tidy up the raw pixelmon temp(s) -- keeps assets/ clean
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
echo "DONE. $(find "$ROOT" -name '*.png' ! -name '*_*.png' | wc -l) clean sprite(s) ready in $ROOT"
