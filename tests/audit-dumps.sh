#!/usr/bin/env bash
# Dump-registry audit: is every [`] dev-console dump topic actually wired up, end to end?
#
# The dump topics are meant to be MAINTAINED alongside the game rather than accumulate as
# orphaned one-offs nobody trusts, so the contract is mechanical and checked here in all three
# directions. For a topic `foo`:
#
#   1. a RegisterDump "foo", ... line declares it (so `dump` lists it and `dump foo` is offered)
#   2. a SUB Dump_Foo implements it
#   3. a dispatch CASE "foo" routes to that SUB
#
# Miss any one and the failure is silent in the worst way: a topic that lists but does nothing,
# a dump nobody can reach, or -- worst -- a CASE naming a SUB that does not exist, which QB64
# parses as a LABEL and simply never runs (the same trap tests/audit-boundary.sh guards for the
# Game_* hooks). None of that is visible until someone types the command and gets nothing.
#
# CONVENTION, and it is load-bearing: `Dump_X` (with the underscore) declares topic X.
# `DumpX` (no underscore) is a private helper and is ignored here.
#
# Usage: tests/audit-dumps.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

python3 - <<'PY'
import re, sys, glob

FILES = ["engine/CONSOLE.bas"] + sorted(glob.glob("game/*.bas"))

registered = {}   # topic -> file it was registered in
subs = {}         # topic -> file the SUB Dump_X lives in
cases = set()     # topics named by a dispatch CASE

for f in FILES:
    for n, l in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        if l.lstrip().startswith("'"):
            continue
        m = re.search(r'RegisterDump\s+"([^"]+)"', l, re.I)
        if m:
            registered[m.group(1).lower()] = f
        m = re.match(r'\s*SUB\s+Dump_(\w+)', l, re.I)
        if m:
            subs[m.group(1).lower()] = f
        # dispatch arms: CASE "foo": Dump_Foo   /  CASE "foo", "bar": ...
        if re.match(r'\s*CASE\s+"', l, re.I):
            for t in re.findall(r'"([^"]+)"', l):
                cases.add(t.lower())

bad = 0

def fail(msg):
    global bad
    bad += 1
    print(f"  BAD  {msg}")

print(f"dump registry: {len(registered)} topic(s) registered, {len(subs)} Dump_* SUB(s)")

for topic, f in sorted(registered.items()):
    if topic not in subs:
        fail(f'topic "{topic}" (registered in {f}) has no SUB Dump_{topic.capitalize()}')
    elif topic not in cases:
        fail(f'topic "{topic}" has a SUB but no dispatch CASE "{topic}" -- `dump {topic}` does nothing')

for topic, f in sorted(subs.items()):
    # `summary` is dispatched on both sides: the engine owns the topic and asks the game to
    # append its part through the same hook, so the game has a CASE but no RegisterDump.
    if topic not in registered and topic != "summary":
        fail(f'SUB Dump_{topic.capitalize()} in {f} is not registered -- nothing can reach it')

if not bad:
    print(f"  OK -- every topic registers, implements and dispatches")

sys.exit(1 if bad else 0)
PY
