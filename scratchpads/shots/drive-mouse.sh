#!/usr/bin/env bash
# drive-mouse.sh <out.png> — enter play, toggle the [~] debug overlay, move the
# mouse to plant the crosshair, roll+step into a room, capture the inspector.
set -uo pipefail
OUT="$1"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 40 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.4}"; }

sleep 4
key Return 1.5        # intro -> menu
key Return 1.5        # ENTER THE DUNGEON -> play
key space  1.0        # dismiss the instruction banner
key grave  0.5        # toggle the [~] debug overlay
key space  0.6        # roll movement dice
for s in 1 2 3; do key s 0.25; done   # step down a few cells
# plant the mouse crosshair over the middle-left of the board
xdotool mousemove 1500 900
sleep 0.6
setsid spectacle -b -n -f -o "$OUT" -d 250 2>/dev/null
sleep 0.5
[ -s "$OUT" ] && echo "CAPTURED -> $OUT" || echo "NO OUTPUT"
