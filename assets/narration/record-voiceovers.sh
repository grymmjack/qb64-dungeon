#!/usr/bin/env bash
# Record a narration pack in your OWN voice, from the game's own audio manifest.
#
# The manifest is the authoritative list: `dungeon.run audiomanifest` computes it
# from the loaded data, so it is always current and always uses the keys the
# engine actually looks for at runtime. This pulls the narration rows out of it,
# strips the "narration/" path prefix (the key becomes the FILENAME, so leaving
# it on would write into a subfolder), and hands the result to soundmon --record.
#
#   ./record-voiceovers.sh grymmjack                 # all narration lines
#   ./record-voiceovers.sh grymmjack 'chamber\.'     # only the chambers
#   ./record-voiceovers.sh grymmjack '!regular\.'    # everything EXCEPT ambience
#   DEVICE="Blue Yeti" ./record-voiceovers.sh grymmjack
#
# Quit any time with Q -- progress lives on disk, so re-running the same command
# picks up at the first line you have not recorded yet.
set -euo pipefail

PACK="${1:-}"
FILTER="${2:-}"
[ -n "$PACK" ] || { sed -n '2,14p' "$0" | sed 's/^# \?//'; exit 1; }

cd "$(dirname "$(readlink -f "$0")")"      # assets/narration/
ROOT="$(readlink -f ../..)"                # the qb64-dungeon checkout
DEST="$(pwd)/$PACK"

command -v soundmon >/dev/null || { echo "soundmon not on PATH"; exit 1; }
[ -x "$ROOT/dungeon.run" ] || { echo "no dungeon.run at $ROOT"; exit 1; }

mkdir -p "$DEST"

# A leading '!' inverts, so one argument covers both "only these" and "all but
# these" -- quote it, or the shell will try to expand it.
apply_filter() {
  if   [ -z "$FILTER" ];               then cat
  elif [ "${FILTER#\!}" != "$FILTER" ]; then grep -Ev "^${FILTER#\!}"
  else                                      grep -E "^$FILTER"
  fi
}

# KEEP=1 preserves a lines.txt you have hand-edited (to make a line read better
# aloud); otherwise it is rebuilt from the manifest every run, which is the point.
if [ "${KEEP:-0}" = "1" ] && [ -f "$DEST/lines.txt" ]; then
  echo "▶ keeping existing $PACK/lines.txt (KEEP=1)"
else
  "$ROOT/dungeon.run" audiomanifest \
    | grep '^narration/' \
    | sed 's|^narration/||' \
    | apply_filter \
    > "$DEST/lines.txt"
fi

COUNT=$(grep -c '|' "$DEST/lines.txt" || true)
[ "$COUNT" -gt 0 ] || { echo "no lines matched filter '${FILTER}'"; exit 1; }
DONE=$(find "$DEST" -maxdepth 1 \( -name '*.ogg' -o -name '*.wav' \) | wc -l)
echo "▶ $COUNT line(s) to voice into $PACK/  ($DONE already recorded)"

# Any extra arguments are passed straight through to soundmon.
exec soundmon --record-file "$DEST/lines.txt" \
              --output-to "$DEST" --create-dirs --ogg \
              ${DEVICE:+--device "$DEVICE"} \
              "${@:3}"
