#!/usr/bin/env bash
# drive-dice2.sh <pips.png> <poly.png> — CREATE A CHARACTER: catch a 3d6 pip roll
# and the 3dN hit-die roll (polyhedra).
set -uo pipefail
P1="$1"; P2="$2"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 70 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.4}"; }
shot(){ setsid spectacle -b -n -f -o "$1" -d 200 2>/dev/null; sleep 0.5; [ -s "$1" ] && echo "OK -> $1" || echo "MISS $1"; }

sleep 4
key Return 1.5        # intro -> menu
key s      0.6        # -> CREATE A CHARACTER
key Return 1.5        # -> class select (HERO)
key Return 0.9        # confirm -> roll-up begins
sleep 1.6             # first ability roll mid-tumble
shot "$P1"
sleep 9.5             # past all six abilities, into the hit-die roll
shot "$P2"
