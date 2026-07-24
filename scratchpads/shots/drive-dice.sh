#!/usr/bin/env bash
# drive-dice.sh <a.png> <b.png> <c.png> — open SETTINGS and exercise the new dice
# options: default look, a colour change, and the hollow-outline finish.
set -uo pipefail
A="$1"; B="$2"; C="$3"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 60 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.35}"; }
shot(){ setsid spectacle -b -n -f -o "$1" -d 250 2>/dev/null; sleep 0.6; [ -s "$1" ] && echo "OK -> $1" || echo "MISS $1"; }

sleep 4
key Return 1.5                          # intro -> menu
for i in 1 2 3 4; do key s 0.3; done    # -> SETTINGS
key Return 1.2                          # open SETTINGS
shot "$A"                               # default dice (Blood / solid / pips)

for i in $(seq 1 9); do key s 0.18; done  # -> item 10, Dice Colour
key d 0.3; key d 0.3; key d 0.3           # Blood -> Emerald -> Sapphire -> Gold
sleep 0.3
shot "$B"

key s 0.3                                 # -> item 11, Dice Finish
key Return 0.5                            # solid -> hollow outline
sleep 0.3
shot "$C"
