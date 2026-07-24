#!/usr/bin/env bash
# drive-board.sh <out.png> — intro->menu->play, dismiss banner, capture the board.
set -uo pipefail
OUT="$1"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 30 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.5}"; }
sleep 4
key Return 1.5
key Return 1.5
key space 1.2      # dismiss the instruction banner -> board
sleep 0.4
setsid spectacle -b -n -f -o "$OUT" -d 80 2>/dev/null
sleep 0.5
[ -s "$OUT" ] && echo "CAPTURED -> $OUT" || echo "NO OUTPUT"
