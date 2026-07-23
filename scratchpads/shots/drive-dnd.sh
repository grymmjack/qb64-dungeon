#!/usr/bin/env bash
# drive-dnd.sh <panel.png> <attack.png> — walk into the WRAITH's room (D&D mode),
# capture the combat panel, throw one attack, capture the result. PID-group teardown.
set -uo pipefail
PANEL="$1"; ATTACK="$2"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 60 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.35}"; }

sleep 4
echo "active: $(xdotool getactivewindow getwindowname 2>/dev/null)"
key Return 1.5        # intro -> menu
key Return 1.5        # ENTER THE DUNGEON -> play
key space  1.0        # dismiss the instruction banner
# walk down toward the Torture Chamber (WRAITH) to trigger combat
for cycle in 1 2 3 4 5; do
  key space 0.5       # roll movement
  for s in 1 2 3 4 5 6; do key s 0.22; done
done
sleep 0.4
setsid spectacle -b -n -f -o "$PANEL" -d 300 2>/dev/null
sleep 0.5
[ -s "$PANEL" ] && echo "PANEL -> $PANEL" || echo "NO PANEL"

# throw one attack and capture the hit/miss banner
key space 1.2
setsid spectacle -b -n -f -o "$ATTACK" -d 300 2>/dev/null
sleep 0.5
[ -s "$ATTACK" ] && echo "ATTACK -> $ATTACK" || echo "NO ATTACK"
