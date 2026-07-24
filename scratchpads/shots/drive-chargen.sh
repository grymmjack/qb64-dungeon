#!/usr/bin/env bash
# drive-chargen.sh <mid.png> <final.png> — intro -> menu -> CREATE A CHARACTER ->
# pick HERO -> watch the 3d6 roll-up. Capture a mid-roll frame and the final sheet.
set -uo pipefail
MID="$1"; FINAL="$2"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 60 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.4}"; }

sleep 4
echo "active: $(xdotool getactivewindow getwindowname 2>/dev/null)"
key Return 1.5        # intro -> menu
key s      0.6        # menu: ENTER -> CREATE A CHARACTER
key Return 1.5        # -> class select (default HERO)
key Return 1.2        # confirm HERO -> roll-up begins
sleep 4               # a few abilities in
setsid spectacle -b -n -f -o "$MID" -d 250 2>/dev/null
sleep 0.4
[ -s "$MID" ] && echo "MID -> $MID" || echo "NO MID"
sleep 10              # let the remaining abilities + HP finish
setsid spectacle -b -n -f -o "$FINAL" -d 250 2>/dev/null
sleep 0.4
[ -s "$FINAL" ] && echo "FINAL -> $FINAL" || echo "NO FINAL"
