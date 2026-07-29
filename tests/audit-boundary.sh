#!/usr/bin/env bash
# Boundary audit: which GAME symbols does engine/ still name?
#
# No linker enforces the engine/game split (QB64 compiles as one translation unit), so a
# hand-maintained ledger drifts. This rebuilds it mechanically: collect every symbol game/
# owns, then intersect with the identifiers appearing in each engine/ file. Anything that
# comes back -- other than a Game_* hook -- is boundary debt.
#
# Usage: tests/audit-boundary.sh [-v]     (-v lists the offending symbols per file)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
VERBOSE=0; [[ "${1:-}" == "-v" ]] && VERBOSE=1

python3 - "$VERBOSE" <<'PY'
import re, sys, glob, os
verbose = sys.argv[1] == "1"

# ---- symbols the GAME owns -------------------------------------------------
own = set()
for f in glob.glob("game/*.bas"):
    for l in open(f, encoding="utf-8", errors="replace"):
        m = re.match(r'\s*(?:SUB|FUNCTION)\s+([A-Za-z_][\w.]*)', l, re.I)
        if m: own.add(m.group(1).lower().rstrip("$%&!#~"))

for l in open("game/GAME.BI", encoding="utf-8", errors="replace"):
    if l.strip().startswith("'"): continue
    l = re.sub(r"'.*$", "", l)
    m = re.match(r'\s*DIM\s+SHARED\s+(.*)$', l, re.I)
    if m:
        body = m.group(1)
        # "AS <type>" prefix form:  DIM SHARED AS INTEGER a, b, c
        pre = re.match(r'\s*AS\s+[\w_]+\s+(.*)$', body, re.I)
        if pre: body = pre.group(1)
        # split on commas NOT inside parentheses (array bounds)
        depth = 0; cur = ""; parts = []
        for ch in body:
            if ch == "(": depth += 1
            elif ch == ")": depth -= 1
            if ch == "," and depth == 0: parts.append(cur); cur = ""
            else: cur += ch
        parts.append(cur)
        for p in parts:
            n = re.match(r'\s*([A-Za-z_][\w.]*)', p)
            if n: own.add(n.group(1).lower().rstrip("$%&!#~"))
    m = re.match(r'\s*(?:CONST|TYPE)\s+([A-Za-z_][\w.]*)', l, re.I)
    if m: own.add(m.group(1).lower())
    if re.match(r'\s*CONST\s', l, re.I):                 # CONST A = 1, B = 2
        for n in re.findall(r'([A-Za-z_][\w.]*)\s*=', l): own.add(n.lower())

# words that are QB64 keywords or shared type names -- never real leaks
NOISE = {"as","fill","room","player","sector","rooms","maxhit","integer","long","string",
         "single","double","shared","dim","const","type"}
own -= NOISE
own = {s for s in own if not s.startswith("game_")}

# ---- what engine/ names ----------------------------------------------------
bad = 0
for f in sorted(glob.glob("engine/*.bas")) + ["engine/ENGINE.BI"]:
    seen = set()
    for l in open(f, encoding="utf-8", errors="replace"):
        if l.strip().startswith("'"): continue
        l = re.sub(r"'.*$", "", l)                       # trailing comment
        l = re.sub(r'"[^"]*"', '""', l)                  # string literals
        for w in re.findall(r'[A-Za-z_][\w.]*', l):
            if w.lower() in own: seen.add(w.lower())
    name = os.path.basename(f)
    if seen:
        bad += 1
        print(f"  LEAK  {name:16s} {len(seen)} symbol(s)")
        if verbose: print("          " + " ".join(sorted(seen)))
    else:
        print(f"  clean {name}")

print()
print(f"{bad} engine file(s) still name game symbols." if bad else "ENGINE IS CLEAN -- no engine file names a game symbol.")

# ---- hook-contract completeness -------------------------------------------
# Every Game_* hook the engine CALLS must be implemented by BOTH game/ and the
# reference game in examples/minimal.
#
# Do not rely on "the demo stops compiling" to catch a missing hook: a bare
# `Game_Foo` statement whose SUB is undefined parses as a LABEL, not a call --
# it compiles clean and silently does nothing. That is how Game_RenderHUD was
# added and examples/minimal kept building without it. This check is the alarm.
called = set()
for f in glob.glob("engine/*.bas") + ["engine/DICE3D_GAME.bas"]:
    if not os.path.exists(f): continue
    for l in open(f, encoding="utf-8", errors="replace"):
        if l.strip().startswith("'"): continue
        l = re.sub(r"'.*$", "", l)
        for n in re.findall(r'\b(Game_[A-Za-z_]\w*)', l): called.add(n.lower().rstrip("$%&!#~"))

def implemented(paths):
    have = set()
    for f in paths:
        if not os.path.exists(f): continue
        for l in open(f, encoding="utf-8", errors="replace"):
            m = re.match(r'\s*(?:SUB|FUNCTION)\s+(Game_[A-Za-z_]\w*)', l, re.I)
            if m: have.add(m.group(1).lower().rstrip("$%&!#~"))
    return have

game_have = implemented(glob.glob("game/*.bas"))
mini_have = implemented(glob.glob("examples/minimal/*.bas"))

print()
print(f"hook contract: engine calls {len(called)} Game_* hook(s)")
for label, have in (("game/", game_have), ("examples/minimal/", mini_have)):
    missing = sorted(called - have)
    if missing:
        bad += 1
        print(f"  MISSING in {label}: {' '.join(missing)}")
    else:
        print(f"  {label} implements all of them")

# ---- ENGINE.BI must not hoard game data -----------------------------------
# The check above is ONE-DIRECTIONAL: it asks "does engine name a game symbol". Anything
# misfiled INTO ENGINE.BI is engine-owned by definition and stays invisible to it -- which
# is how 27 globals (D&D ability scores, ruleset switches, turn machinery) sat in the engine
# header unnoticed. The sharper question is simply: does any engine/ file actually USE this?
decls = []
for l in open("engine/ENGINE.BI", encoding="utf-8", errors="replace"):
    if l.strip().startswith("'"): continue
    l = re.sub(r"'.*$", "", l)
    m = re.match(r'\s*DIM\s+SHARED\s+(.*)$', l, re.I)
    if not m: continue
    body = m.group(1)
    pre = re.match(r'\s*AS\s+(?:_UNSIGNED\s+)?[\w_]+\s+(.*)$', body, re.I)
    if pre: body = pre.group(1)
    d = 0; cur = ""; parts = []
    for ch in body:
        if ch == "(": d += 1
        elif ch == ")": d -= 1
        if ch == "," and d == 0: parts.append(cur); cur = ""
        else: cur += ch
    parts.append(cur)
    for pt in parts:
        n = re.match(r'\s*([A-Za-z_][\w.]*)', pt)
        if n: decls.append(n.group(1))

engine_src = glob.glob("engine/*.bas")
engine_txt = []
for f in engine_src:
    for l in open(f, encoding="utf-8", errors="replace"):
        if l.strip().startswith("'"): continue
        engine_txt.append(re.sub(r"'.*$", "", l))
engine_blob = "".join(engine_txt)

# RESERVED: engine concepts the engine does not consume YET. Listed explicitly so the fact
# stays visible instead of being silently exempt -- the audit still reports them, it just
# does not fail on them. Turn structure (whose turn, steps left, roll owed) is engine by
# design; the deeper tactical-combat screen in plans/PLANS.todo will need engine-side
# initiative + turn order and will consume these. Remove a name from here the moment an
# engine/ file uses it, or move it to GAME.BI if that never happens.
RESERVED = {"turn_num", "steps_left", "need_roll"}

orphan = [n for n in decls
          if not re.search(r'\b%s\b' % re.escape(n), engine_blob, re.I)]
reserved = [n for n in orphan if n.lower() in RESERVED]
orphan = [n for n in orphan if n.lower() not in RESERVED]

print()
print(f"ENGINE.BI hoarding check: {len(decls)} globals declared")
if orphan:
    bad += 1
    print(f"  {len(orphan)} declared in ENGINE.BI but used by NO engine/ file:")
    print("      " + " ".join(sorted(orphan)))
    print("  Either move the declaration to game/GAME.BI, or move its consumer into engine/.")
else:
    print("  no ENGINE.BI global is orphaned")
if reserved:
    print("  reserved (engine by design, no engine consumer yet): " + " ".join(sorted(reserved)))

sys.exit(1 if bad else 0)
PY
