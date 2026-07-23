#!/usr/bin/env bash
# drive-extras.sh <settings.png> <keys.png> — capture the SETTINGS screen with the
# new Stat Roll option highlighted/toggled, then the [?] Controls screen in play.
set -uo pipefail
SET="$1"; KEYS="$2"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 50 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.35}"; }

sleep 4
key Return 1.5                       # intro -> menu
for i in 1 2 3 4; do key s 0.3; done # menu: ENTER -> ... -> SETTINGS (item 5)
key Return 1.2                       # -> SETTINGS
for i in 1 2 3 4 5 6; do key s 0.25; done  # move down to "Stat Roll" (item 7)
key Return 0.5                       # toggle it to 4d6 drop-low
sleep 0.4
setsid spectacle -b -n -f -o "$SET" -d 250 2>/dev/null
sleep 0.5
[ -s "$SET" ] && echo "SETTINGS -> $SET" || echo "NO SETTINGS"

key Escape 0.8                       # back to menu (sel still on SETTINGS)
for i in 1 2 3 4; do key w 0.3; done # back up to ENTER (item 1)
key Return 1.5                       # ENTER THE DUNGEON -> play
key space 1.0                        # dismiss the instruction banner
key question 0.8                     # [?] -> Controls screen
sleep 0.3
setsid spectacle -b -n -f -o "$KEYS" -d 250 2>/dev/null
sleep 0.5
[ -s "$KEYS" ] && echo "KEYS -> $KEYS" || echo "NO KEYS"
