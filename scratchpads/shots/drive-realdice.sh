#!/usr/bin/env bash
set -uo pipefail
OUT="$1"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 40 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.4}"; }
sleep 4
key Return 1.5                       # intro -> menu (sel 1)
key s 0.3; key s 0.3; key s 0.3; key s 0.3   # menu 1 -> 5 SETTINGS
key Return 1.0                       # open SETTINGS (sel 1)
key s 0.3; key s 0.3; key s 0.3      # settings 1 -> 4 Real Dice
key Return 0.6                       # toggle Real Dice ON
key Escape 0.8                       # back to menu (sel 5)
key w 0.3; key w 0.3; key w 0.3; key w 0.3   # menu 5 -> 1 ENTER THE DUNGEON
key Return 1.5                       # play; instruction banner
key space 1.0                        # dismiss banner
key space 0.8                        # roll movement -> REAL DICE prompt
sleep 0.3
setsid spectacle -b -n -f -o "$OUT" -d 80 2>/dev/null
sleep 0.5
[ -s "$OUT" ] && echo "CAPTURED -> $OUT" || echo "NO OUTPUT"
