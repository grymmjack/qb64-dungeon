#!/usr/bin/env bash
# Short-circuit audit: guards that do not actually guard.
#
# QB64's AND / OR are BITWISE and ALWAYS evaluate BOTH operands. So this, which
# reads like a safe guard in almost any other language:
#
#     IF rm > 0 AND ROOMS(rm).malive THEN ...
#
# still evaluates ROOMS(0) when rm is 0. With $Debug off that is not a crash --
# it silently reads out-of-bounds memory, so the condition may come out either
# way and the bug is invisible until it isn't. The fix is to nest the IFs.
#
# This flags the precise dangerous shape: an operand that GUARDS a variable
# (v > 0, v >= 1, v <> 0, v <= N, NOT v...) combined with a LATER operand that
# uses that same variable as an array SUBSCRIPT or passes it to a call.
#
# Usage: tests/audit-shortcircuit.sh [-v]      (-v also prints the source line)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
VERBOSE=0; [[ "${1:-}" == "-v" ]] && VERBOSE=1

python3 - "$VERBOSE" <<'PY'
import re, sys, glob, os
verbose = sys.argv[1] == "1"

def split_top(cond):
    """Split a condition on top-level AND/OR (not inside parens or strings)."""
    out, cur, depth, instr, i = [], "", 0, False, 0
    while i < len(cond):
        ch = cond[i]
        if ch == '"': instr = not instr
        if not instr:
            if ch == "(": depth += 1
            elif ch == ")": depth -= 1
            if depth == 0:
                m = re.match(r'\s+(AND|OR)\s+', cond[i:], re.I)
                if m:
                    out.append(cur); cur = ""; i += m.end(); continue
        cur += ch; i += 1
    out.append(cur)
    return out

# Variables a guard operand protects. Only BOUNDS-shaped comparisons count -- against a
# numeric literal or an UBOUND/count. `p <> cur_player` is a filter, not a bounds guard,
# and flagging it is noise: PLAYERS(p) is in range either way.
GUARD = re.compile(r'\b([A-Za-z_]\w*)\s*(?:>=?|<=?)\s*-?\d+\b', re.I)
GUARD_NE0 = re.compile(r'\b([A-Za-z_]\w*)\s*<>\s*0\b', re.I)
GUARD_UB = re.compile(r'\b([A-Za-z_]\w*)\s*<=?\s*(?:UBOUND\s*\(|\w*_N\b)', re.I)
NOTG  = re.compile(r'\bNOT\s+([A-Za-z_]\w*)\b', re.I)

hits = []
for f in sorted(glob.glob("engine/*.bas") + glob.glob("game/*.bas")
                + glob.glob("examples/*/*.bas") + ["dungeon.bas"]):
    for i, raw in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        if raw.strip().startswith("'"): continue
        line = re.sub(r"'.*$", "", raw)
        m = re.search(r'\b(?:ELSEIF|IF)\b(.*?)\bTHEN\b', line, re.I)
        if not m: continue
        cond = m.group(1)
        if not re.search(r'\s(AND|OR)\s', cond, re.I): continue

        ops = split_top(cond)
        if len(ops) < 2: continue

        guarded = set()
        for oi, op in enumerate(ops):
            # anything this operand uses as a subscript / call argument
            for call in re.finditer(r'\b([A-Za-z_]\w*)\s*\(([^()]*)\)', op):
                args = call.group(2)
                for v in re.findall(r'\b([A-Za-z_]\w*)\b', args):
                    if v.lower() in guarded:
                        hits.append((f, i, v, call.group(1), raw.strip()))
            # register guards this operand establishes, for LATER operands
            for rx in (GUARD, GUARD_NE0, GUARD_UB, NOTG):
                for g in rx.finditer(op): guarded.add(g.group(1).lower())

if not hits:
    print("no non-short-circuit guard hazards found.")
    sys.exit(0)

print("GUARDS THAT DO NOT GUARD (AND/OR evaluate both sides):")
seen = set()
for f, i, v, arr, src in hits:
    key = (f, i, v, arr)
    if key in seen: continue
    seen.add(key)
    print(f"  {f}:{i}   guard on `{v}` but `{arr}({v}...)` is still evaluated")
    if verbose: print(f"      {src}")
print(f"\n{len(seen)} site(s). Fix by nesting the IFs.")
sys.exit(1)
PY
