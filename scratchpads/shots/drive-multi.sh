#!/usr/bin/env bash
# drive-multi.sh <settings.png> <setup.png> <board.png> — set Players=2, create two
# characters (names AL / BO), then capture two tokens on the shared board.
# Show Dice is toggled OFF so the roll-ups are instant and the drive stays in sync.
set -uo pipefail
SET="$1"; SETUP="$2"; BOARD="$3"
cd /home/grymmjack/git/qb64-dungeon || exit 2
setsid timeout -k 2 80 ./dungeon.run >/dev/null 2>&1 &
PID=$!
cleanup(){ kill -TERM -"$PID" 2>/dev/null; for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null||break; sleep 0.2; done; kill -KILL -"$PID" 2>/dev/null; }
trap cleanup EXIT INT TERM
key(){ xdotool key --clearmodifiers "$1"; sleep "${2:-0.4}"; }
cap(){ setsid spectacle -b -n -f -o "$1" -d 250 2>/dev/null; sleep 0.4; [ -s "$1" ] && echo "OK -> $1" || echo "NO $1"; }

sleep 4
key Return 1.5                          # intro -> menu
for i in 1 2 3 4; do key s 0.3; done    # -> SETTINGS
key Return 1.0                          # open settings
for i in $(seq 1 6); do key s 0.2; done # -> Show Dice (item 7)
key Return 0.4                          # toggle Show Dice OFF (instant rolls)
for i in 1 2 3 4 5; do key s 0.2; done  # -> Players (item 12)
key d 0.4                               # Players -> 2 (forces Boardgame locked)
sleep 0.3
cap "$SET"

key Escape 0.8                          # back to menu
for i in 1 2 3 4; do key w 0.3; done    # -> ENTER
key Return 1.2                          # ENTER THE DUNGEON -> SetupPlayers
cap "$SETUP"                            # "PLAYER 1 -- choose your champion" banner

# --- Player 1 ---
key space 1.0                           # dismiss the setup banner -> class select
key Return 1.2                          # confirm HERO -> roll-up (instant, Show Dice off)
key Return 1.0                          # keep the rolled hero -> name prompt
xdotool type "AL"; sleep 0.3; key Return 1.0
# --- Player 2 ---
key space 1.0                           # dismiss banner -> class select
key s 0.4                               # move to ELF
key Return 1.2                          # confirm ELF -> roll-up
key Return 1.0                          # keep -> name prompt
xdotool type "BO"; sleep 0.3; key Return 1.2

# game start: narration + banner + turn announce
key space 0.6; key space 0.6; key space 0.8   # skip narration
key space 0.8                           # dismiss instruction banner
key space 1.0                           # dismiss "PLAYER 1 your turn"
# Player 1 takes a turn and walks off START so tokens separate
key space 0.8                           # roll movement
for i in 1 2 3 4; do key Down 0.3; done
key space 1.2                           # dismiss "PLAYER 2 your turn"
sleep 0.4
cap "$BOARD"                            # two tokens: P1 moved, P2 at START
