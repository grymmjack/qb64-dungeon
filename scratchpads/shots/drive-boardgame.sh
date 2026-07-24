#!/usr/bin/env bash
# drive-boardgame.sh <settings.png> <board.png> — toggle Boardgame Mode OFF, then
# enter the dungeon and walk with ARROW keys (no dice roll). Capture both.
set -uo pipefail
SET="$1"; BOARD="$2"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 55 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.35}"; }

sleep 4
key Return 1.5                        # intro -> menu
for i in 1 2 3 4; do key s 0.3; done  # -> SETTINGS (item 5)
key Return 1.0                        # open SETTINGS
for i in $(seq 1 10); do key s 0.2; done  # move down to Boardgame (item 11)
key Return 0.4                        # toggle -> free move
sleep 0.3
setsid spectacle -b -n -f -o "$SET" -d 250 2>/dev/null
sleep 0.5
[ -s "$SET" ] && echo "SETTINGS -> $SET" || echo "NO SETTINGS"

key Escape 0.8                        # back to menu
for i in 1 2 3 4; do key w 0.3; done  # -> ENTER
key Return 0.8                        # enter dungeon -> narration
key space 0.5; key space 0.5; key space 0.6; key space 0.6   # skip narration + banner
# free movement with ARROW keys -- no dice roll needed
for i in 1 2 3 4 5; do key Down 0.28; done
for i in 1 2 3 4; do key Right 0.28; done
sleep 0.3
setsid spectacle -b -n -f -o "$BOARD" -d 250 2>/dev/null
sleep 0.5
[ -s "$BOARD" ] && echo "BOARD -> $BOARD" || echo "NO BOARD"
