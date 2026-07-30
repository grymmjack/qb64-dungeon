#!/usr/bin/env bash
# Shadow audit: locals/params named after a HIGH-RISK shared global.
#
# QB64 identifiers are CASE-INSENSITIVE, so `DIM brown AS INTEGER` inside a SUB
# silently shadows the shared BROWN colour for that whole procedure. It compiles
# clean and there is no warning -- the code just quietly reads the wrong thing.
#
# This is not hypothetical: engine/BOARD.bas DetectDoors counted hits in a local
# named `brown`, so `IF POINT(...) = BROWN` compared each pixel against the
# COUNTER instead of AA5500. It found zero doors, forever. MarkStrongDoors marked
# nothing, StrongDoorAhead always returned 0, and the game's reinforced-door
# feature never once fired. Found by examples/minimal, fixed 2026-07-29.
#
# Only the genuinely dangerous globals are flagged -- the screen metrics, the
# cursor, and the collision palette. Those are the ones used for coordinate math
# and colour comparison in nearly every procedure, so shadowing one corrupts
# silently rather than loudly. Shadowing e.g. `gold` with a parameter that MEANS
# a gold amount is fine and common, so it is not flagged.
#
# Usage: tests/audit-shadow.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

python3 - <<'PY'
import re, sys, glob, os

# Shadowing ANY of these silently breaks coordinate math or colour comparison.
RISKY = {
    "ch","cw","sw","sh","c",                                  # cell metrics + the cursor
    "black","white","grey","yellow","brown","bright_blue",     # collision palette
    "redu","greenu","yellowu","cyanu","boxbg",                 # ui palette
    "canvas","canvas_copy","full_board",                       # image handles
    # The big shared UDT arrays. Shadowing one does not just read the wrong value -- the
    # local has no fields, so `ROOMS(r).sec` becomes "Invalid expression" and the compiler
    # points at the USE site, not the DIM. Cheap to catch here instead.
    "rooms","players","sectors","classes","curios","traps",
}

hits = []
for f in sorted(glob.glob("engine/*.bas") + glob.glob("game/*.bas")
                + glob.glob("examples/*/*.bas") + ["dungeon.bas"]):
    proc = "(file scope)"
    for i, l in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        if l.strip().startswith("'"): continue
        code = re.sub(r"'.*$", "", l)

        m = re.match(r'\s*(SUB|FUNCTION)\s+([A-Za-z_][\w.]*)', code, re.I)
        if m: proc = m.group(2)

        names = []
        # A DIM's declarations end at the first ':' statement separator -- without this,
        # `DIM oldsrc AS LONG: _SOURCE FULL_BOARD` reads FULL_BOARD as a declared local.
        d = re.match(r'\s*DIM\s+(?!SHARED)([^:]*)', code, re.I)
        if d:
            body = d.group(1)
            # "DIM AS <type> a, b" -- strip the type prefix (incl. _UNSIGNED LONG)
            pre = re.match(r'\s*AS\s+(?:_UNSIGNED\s+)?[\w_]+\s+(.*)$', body, re.I)
            if pre: body = pre.group(1)
            names += re.findall(r'([A-Za-z_]\w*)\s*(?:\([^)]*\))?\s*(?:AS\b|,|$)', body)
        if m:
            p = re.search(r'\(([^)]*)\)', code)
            if p: names += re.findall(r'([A-Za-z_]\w*)\s*(?:\([^)]*\))?\s+AS\b', p.group(1))

        for n in names:
            if n.lower() in RISKY:
                hits.append((f, i, proc, n))

if not hits:
    print("no local shadows a high-risk shared global.")
    sys.exit(0)

print("LOCALS/PARAMS SHADOWING A HIGH-RISK SHARED GLOBAL:")
print("(rename the local -- the convention is a suffixed name, e.g. `chcode`, `kolor`, `hits`)")
for f, i, proc, n in hits:
    print(f"  {f}:{i}  {proc}()  ->  {n}")
print(f"\n{len(hits)} site(s).")
sys.exit(1)
PY
