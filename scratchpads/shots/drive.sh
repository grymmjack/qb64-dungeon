#!/usr/bin/env bash
# drive.sh <out.png> [finalkeys] — launch dungeon.run, walk INTRO->MENU->PLAY,
# roll+move DOWN toward the Torture Chamber (sector 5 = WRAITH) to trigger combat,
# screenshot, tear down by PID. Prints the active window name to confirm focus.
set -uo pipefail
OUT="$1"
cd /home/grymmjack/git/qb64-dungeon

setsid timeout -k 2 60 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM

key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.35}"; }

sleep 4
echo "active: $(xdotool getactivewindow getwindowname 2>/dev/null)"
key Return 1.5        # intro -> menu
key Return 1.5        # menu: ENTER THE DUNGEON -> play (board + banner + WaitKey)
key space  1.0        # dismiss the instruction banner
# five roll-and-walk-down cycles; extra presses past the roll are ignored
DIR="${2:-s}"
for cycle in 1 2 3 4 5; do
  key space 0.5       # roll movement dice
  for s in 1 2 3 4 5 6; do key "$DIR" 0.22; done
done
sleep 0.3

setsid spectacle -b -n -f -o "$OUT" -d 400 2>/dev/null
sleep 0.5
[ -s "$OUT" ] && echo "CAPTURED -> $OUT $(identify -format '%wx%h' "$OUT")" || echo "NO OUTPUT"
