#!/usr/bin/env bash
# drive-char.sh <out.png> — enter play, dismiss banner, open the [C] character sheet.
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
key space 1.2      # dismiss the instruction banner
key c 1.0          # open the character sheet
sleep 0.3
setsid spectacle -b -n -f -o "$OUT" -d 80 2>/dev/null
sleep 0.5
[ -s "$OUT" ] && echo "CAPTURED -> $OUT" || echo "NO OUTPUT"
