#!/usr/bin/env bash
# Generate every art asset in the game manifest via ~/pixelmon's --art (full-res
# SDXL) mode, across the ComfyUI render farm.
#
# This is the DIGITAL-ART sibling of generate.sh. Same manifest, same farm, same
# resume/logging -- but instead of pixel sprites it renders NATIVE 1024px SDXL
# illustrations (no pixel-art LoRA, no palette lock, no downscale, no transparency).
# The game's DrawSpriteFit% scales the big source down into its panels, so a 1024px
# source is crisper than a 128px one, not a problem.
#
# Assets are written into a PACK subdirectory of assets/pixel-art/ (pack containers):
#     assets/pixel-art/<pack>/<folder>/<name>.png
# The game selects a pack in SETTINGS; the default art pack here is "SDXL-1".
#
#   ./art-from-manifest.sh                               # SDXL-1 pack, everything not already done
#   ./art-from-manifest.sh --server rtx classes          # a folder filter on one node
#   ./art-from-manifest.sh --pack SDXL-1 --server rtx,mac # pick nodes for the whole pack
#   ./art-from-manifest.sh --style-prefix darkest        # force a look on top of every asset
#
# Resumable: skips any asset whose clean <pack>/<folder>/<name>.png already exists. Auto-detects
# which ComfyUI nodes are up (unless --server is given) and splits the work across them round-robin
# (one worker per node, in parallel). Each asset gets a clean "<name>.png" for the game to load.
#
# NOTE ON PROMPTS: the manifest prompts were authored for pixel art and often contain
# "pixel art / crisp pixels / transparent background". Those are passed through verbatim
# (they only softly nudge the look). Strip them in assets/data/art-prompts.txt if you want
# a cleaner SDXL result.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PIXELMON="$HOME/pixelmon/bin/pixelmon"
# The manifest is CANONICAL: it comes from the game itself (`dungeon.run imagemanifest`), so the
# asset LIST is derived from the content tables and cannot drift from what the game actually loads.
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
  # BOTH manifests -- they cover different halves (general art + strategic-combat art). The
  # pixel-art/ prefix filter below keeps only our media from each.
  ( cd "$GAME" && ./dungeon.run imagemanifest nocolor ) >  "$MANIFEST" 2>/dev/null
  ( cd "$GAME" && ./dungeon.run fightmanifest nocolor ) >> "$MANIFEST" 2>/dev/null
  echo "manifest : dungeon.run imagemanifest + fightmanifest  ($(grep -c '^pixel-art/' "$MANIFEST") pixel-art assets)"
fi
grep -q '^pixel-art/' "$MANIFEST" || { echo "manifest has no pixel-art rows - aborting"; exit 1; }

# --- args -------------------------------------------------------------------
PACK="SDXL-1"          # which pack subdir under assets/pixel-art/ to write into
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
# Only pixel-art rows are ours. The folder may be nested (monsters/beasts), and it MATTERS:
# the game only ever looks inside those category subfolders. NOTE: we deliberately IGNORE the
# manifest size here -- art mode renders at pixelmon's native 1024 (see gen_one).
# pure-bash trim -- xargs chokes on apostrophes in the skipped non-pixel rows ("hero's ...")
trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }
# art_size: manifest size (N or WxH) -> WxH scaled so the LONG side is ~1024, rounded to /64.
# Art mode has no downscale step, so this preserves each asset's intended ASPECT at SDXL
# resolution (square 128 -> 1024x1024; 264x200 -> 1024x768; 192 -> 1024x1024) instead of
# forcing everything square. SDXL wants ~1024 on the long side to look its best.
art_size() {
  local s="$1" w h L=1024
  if [[ "$s" == *x* ]]; then w="${s%%x*}"; h="${s##*x}"; else w="$s"; h="$s"; fi
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || { printf '%dx%d' "$L" "$L"; return; }
  awk -v w="$w" -v h="$h" -v L="$L" 'BEGIN{
    if (w>=h){nw=L; nh=L*h/w} else {nh=L; nw=L*w/h}
    nw=int((nw+32)/64)*64; nh=int((nh+32)/64)*64
    if(nw<64)nw=64; if(nh<64)nh=64
    printf "%dx%d", nw, nh }'
}

folders=(); names=(); styles=(); sizes=(); prompts=()
while IFS='|' read -r pth style size prompt; do
  pth="$(trim "$pth")"
  case "$pth" in
    pixel-art/*) : ;;
    *) continue ;;                               # comments, blanks, and ansi-art rows
  esac
  pth="${pth#pixel-art/}"; pth="${pth%.png}"
  folder="${pth%/*}"; name="${pth##*/}"
  [ "$folder" = "$pth" ] && continue
  [ -z "$folder" ] && continue
  [ -z "$name" ] && continue
  style="$(trim "$style")"; size="$(trim "$size")"
  prompt="$(trim "$prompt")"
  [ -n "$FILTER" ] && [[ "$folder" != *"$FILTER"* ]] && continue
  folders+=("$folder"); names+=("$name"); styles+=("$style"); sizes+=("$size"); prompts+=("$prompt")
done < "$MANIFEST"

total=${#names[@]}
[ "$total" -eq 0 ] && { echo "Nothing to generate (filter: '${FILTER:-none}')."; exit 0; }
echo "-> pack '$PACK' [ART / SDXL ~1024px, aspect-preserved]: $total asset(s) across ${#UP[@]} node(s): ${UP[*]}${STYLE_PREFIX:+  [style-prefix: $STYLE_PREFIX]}"

# Reproducibility log: the seed pixelmon actually used for each render (art files are named
# ..._s<SEED>_art_...), so any image can be regenerated -- `pixelmon "<prompt>" --art --seed N`.
SEEDS="$ROOT/$PACK/SEEDS.tsv"
mkdir -p "$ROOT/$PACK"
[ -f "$SEEDS" ] || printf '# path\tseed\tstyle\tsize\n' > "$SEEDS"

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
  local style asz
  style="$(combine_style "${styles[$i]}")"
  asz="$(art_size "${sizes[$i]}")"   # aspect preserved, long side ~1024
  echo "  [$node] $PACK/${folders[$i]}/${nm}  ($style, $asz)  <- ${prompts[$i]:0:42}..."
  # --art  : full-res SDXL illustration (no pixel LoRA / palette / downscale)
  # --size : aspect-preserving ~1024 long side (NOT the manifest's 128/192 sprite size).
  # NO --transparent (a no-op in art mode). --no-open is REQUIRED for batch use
  # (otherwise pixelmon xdg-opens each raw temp we then rename).
  local style_arg=(); [ -n "$style" ] && style_arg=(--style "$style")
  if "$PIXELMON" "${prompts[$i]}" "${style_arg[@]}" --art --size "$asz" --no-open \
        --server "$node" --output-to "$dir" --name "$nm" --create-dirs >/dev/null 2>&1; then
    local produced; produced="$(ls -t "$dir/${nm}"_*.png 2>/dev/null | head -1)"
    if [ -n "$produced" ]; then
      # scrape the seed pixelmon used out of the raw filename (..._s<SEED>_art_...) BEFORE deleting
      local seed; seed="$(basename "$produced" | sed -n 's/.*_s\([0-9][0-9]*\)_art_.*/\1/p')"
      cp -f "$produced" "$dir/${nm}.png"   # clean name for the game to load
      rm -f "$dir/${nm}"_*.png             # tidy up the raw pixelmon temp(s)
      printf '%s/%s.png\t%s\t%s\t%s\n' "${folders[$i]}" "$nm" "${seed:-unknown}" "$style" "$asz" >> "$SEEDS"
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
echo "DONE. pack '$PACK': $(find "$ROOT/$PACK" -name '*.png' ! -name '*_*.png' | wc -l) clean image(s) in $ROOT/$PACK"
