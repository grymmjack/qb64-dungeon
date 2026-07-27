#!/usr/bin/env bash
# Regenerate the soundmon-1 narration set from lines.txt.
#
# lines.txt is built from the game's own data by ./build-lines.py; edit either
# one (this script only reads lines.txt, it never rebuilds it). Every "key |
# text" row becomes <key>.wav here.
#
# Narration runs on the CPU via Kokoro — no ComfyUI, no GPU, no render farm.
# An 82M feed-forward model speaks a line in about a second, so there is nothing
# for the farm to speed up. VOICE/PITCH/SPEED default to a booming British DM.
#
#   ./generate.sh
#   VOICE=bm_lewis PITCH=-4 ./generate.sh
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
VOICE="${VOICE:-bm_george}"     # British male, deep — see: soundmon --list-voices
PITCH="${PITCH:--3}"            # semitones down; duration is preserved
SPEED="${SPEED:-0.92}"          # a touch slow reads as grave rather than rushed

# OGG=1 ./generate.sh  -> compress (~3x for speech). The game tries .ogg first.
OGG_ARG="${OGG:+--ogg}"

command -v soundmon >/dev/null || { echo "soundmon not on PATH"; exit 1; }
[ -f lines.txt ] || { echo "no lines.txt — run ./build-lines.py first"; exit 1; }

echo "▶ narrating $(grep -c '|' lines.txt) line(s) as $VOICE (pitch $PITCH, speed $SPEED)"
soundmon --narrate-file lines.txt \
         --voice "$VOICE" --pitch "$PITCH" --speed "$SPEED" \
         $OGG_ARG --output-to . --create-dirs

echo "▶ done — $(find . -maxdepth 1 \( -name '*.wav' -o -name '*.ogg' \) | wc -l) file(s) in $(pwd)"
