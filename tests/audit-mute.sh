#!/usr/bin/env bash
# Mute audit: can any sound escape a headless/dev run?
#
# audio_muted exists because a dev mode has no one to hear it and, worse, because open sound
# handles racing SYSTEM abort roughly one run in ten (see OpenSfx&). Every SAMPLE path checks it.
# The PC SPEAKER did not: `SOUND` is a QB64 statement, not a call into our audio layer, so a raw
# `SOUND` anywhere bypasses the mute entirely and blips at whoever runs the gate. That is exactly
# how the dice-bounce clicks and the typewriter voice blips got out.
#
# THE RULE: `SOUND` may only appear where the mute is provably already applied --
#   * engine/UI.bas Tone, the sanctioned wrapper, which checks audio_muted on its first line
#   * engine/UI.bas VoiceBlip, which does the same
#   * engine/DICE3D/_PHYSICS.BM, a vendored module that cannot see our globals; it is gated by
#     cfg.SOUND_ENABLED, which DICE3D_GAME.bas sets from `opt_sfx AND NOT audio_muted`
# Anything else is a leak. Add a site here only after making it honour the mute.
#
# Usage: tests/audit-mute.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

python3 - <<'PY'
import re, sys, glob

ALLOWED = {
    ("engine/UI.bas", "Tone"),
    ("engine/UI.bas", "VoiceBlip"),
    ("engine/DICE3D/_PHYSICS.BM", None),   # vendored; gated by cfg.SOUND_ENABLED at the call site
}
ALLOWED_FILES = {f for f, _ in ALLOWED if _ is None}

files = sorted(glob.glob("engine/**/*.bas", recursive=True) + glob.glob("engine/**/*.BM", recursive=True)
               + glob.glob("game/*.bas", recursive=True) + ["dungeon.bas"])

bad = []
checked = 0
for f in files:
    proc = ""
    for n, l in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        m = re.match(r'\s*(?:SUB|FUNCTION)\s+([A-Za-z_][\w.]*)', l, re.I)
        if m:
            proc = m.group(1).rstrip("$%&!#~")
        # Strip STRING LITERALS before comments: a dump caption like "-- SOUND EFFECTS --" and a
        # word list containing "sound" are not sound statements, and matching them made the whole
        # audit cry wolf. Quotes first, because an apostrophe inside a string is not a comment.
        code = re.sub(r'"[^"]*"', '""', l)
        code = re.sub(r"'.*$", "", code)
        if not re.search(r'(^|[:\s])SOUND\s+[^_]', code, re.I):
            continue
        if re.search(r'SOUND_ENABLED', code, re.I):
            continue
        checked += 1
        if f in ALLOWED_FILES or (f, proc) in ALLOWED:
            continue
        bad.append(f"{f}:{n}  in {proc or '(main)'}  ->  {code.strip()}")

print(f"mute audit: {checked} raw SOUND statement(s) found")
if bad:
    print("  BAD  raw SOUND outside a mute-checked site -- a dev/headless run will blip:")
    for b in bad:
        print(f"       {b}")
    print("  Route it through Tone, or check audio_muted first, then allow-list it in this script.")
    sys.exit(1)

# The other half: the allow-listed procedures must ACTUALLY still check the mute.
src = open("engine/UI.bas", encoding="utf-8", errors="replace").read()
missing = []
for proc in ("Tone", "VoiceBlip"):
    m = re.search(r'\n\s*SUB\s+' + proc + r'\b(.*?)\nEND SUB', src, re.I | re.S)
    if not m or "audio_muted" not in m.group(1):
        missing.append(proc)
if missing:
    print(f"  BAD  {', '.join(missing)} no longer check audio_muted -- the allow-list is now a lie")
    sys.exit(1)

gsrc = open("engine/DICE3D_GAME.bas", encoding="utf-8", errors="replace").read()
if not re.search(r'SOUND_ENABLED\s*=.*audio_muted', gsrc, re.I):
    print("  BAD  DICE3D_GAME.bas no longer mutes cfg.SOUND_ENABLED -- the dice will blip headless")
    sys.exit(1)

print("  OK -- every sound path honours audio_muted")
PY
