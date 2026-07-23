#!/usr/bin/env bash
# drive-slidertext.sh <settings.png> <scroll.png> — capture SETTINGS with the volume
# sliders (SFX Vol nudged), then the scrolling THE DESCENT narration mid-reveal.
set -uo pipefail
SET="$1"; SCROLL="$2"
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
for i in 1 2 3; do key s 0.25; done   # move to SFX Vol (item 4)
key a 0.25; key a 0.25                # lower it a couple notches (8 -> 6)
sleep 0.3
setsid spectacle -b -n -f -o "$SET" -d 250 2>/dev/null
sleep 0.5
[ -s "$SET" ] && echo "SETTINGS -> $SET" || echo "NO SETTINGS"

key Escape 0.8                        # back to menu (sel on SETTINGS)
for i in 1 2 3 4; do key w 0.3; done  # back up to ENTER (item 1)
key Return 0.6                        # ENTER THE DUNGEON -> board + narration
sleep 2.6                             # let THE DESCENT type partway out
setsid spectacle -b -n -f -o "$SCROLL" -d 250 2>/dev/null
sleep 0.5
[ -s "$SCROLL" ] && echo "SCROLL -> $SCROLL" || echo "NO SCROLL"
