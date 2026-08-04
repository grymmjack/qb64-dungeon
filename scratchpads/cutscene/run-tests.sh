#!/usr/bin/env bash
# =============================================================================
#  run-tests.sh -- the gate for the cut-scene engine.
#
#  Run from the REPO ROOT:   scratchpads/cutscene/run-tests.sh
#
#  Three checks, in order of how much they can tell you:
#
#    1. selftest  -- 100+ headless assertions on the parts that can be checked
#                    without eyes: tokeniser, easing, condition evaluator,
#                    control flow, the runaway guard, the midnight clock wrap.
#    2. lint all  -- every scene in every pack compiles AND every asset it
#                    names resolves on disk. This is the check that catches an
#                    art rename, which nothing else here can see.
#    3. shot      -- every scene is actually RENDERED at a few fixed times and
#                    the frame is required to be non-black. A scene can lint
#                    perfectly and still draw nothing (wrong layer order, a
#                    camera parked off the art, a transition that never
#                    clears) -- and "nothing" is exactly what a missing
#                    backdrop looks like too.
#
#  Everything runs under xvfb: never the live display. The developer is
#  usually using that screen.
# =============================================================================
set -u

QB64="${QB64PE:-/home/grymmjack/git/qb64pe/qb64pe}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

RUN=0
BAD=0

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { RUN=$((RUN+1)); printf '  \033[32mok  \033[0m %s\n' "$*"; }
fail() { RUN=$((RUN+1)); BAD=$((BAD+1)); printf '  \033[31mFAIL\033[0m %s\n' "$*"; }

# --- xvfb-run -a, so a stale lock from another session cannot wedge the gate ---
X() { timeout 180 xvfb-run -a "$@"; }

say "build"
if "$QB64" -w -x scratchpads/cutscene/CUTPLAY.bas -o cutplay.run 2>&1 | grep -qa '^Output:'; then
    ok "cutplay.run compiled"
else
    fail "cutplay.run DID NOT COMPILE"
    # Nothing below can mean anything without a binary.
    printf '\n%d checks, %d failed\n' "$RUN" "$BAD"
    exit 1
fi

say "selftest"
OUT=$(X ./cutplay.run selftest 2>&1)
echo "$OUT" | tail -3 | sed 's/^/  /'
if echo "$OUT" | grep -qa ", 0 failed"; then
    ok "all assertions passed"
else
    fail "assertions failed"
    echo "$OUT" | grep -a "FAIL" | sed 's/^/    /'
fi

say "lint (compile + resolve every asset)"
OUT=$(X ./cutplay.run lint all 2>&1)
echo "$OUT" | sed 's/^/  /'
if echo "$OUT" | grep -qa "0 with errors"; then
    ok "every scene compiles and every asset resolves"
else
    fail "lint reported errors"
fi

say "render (a scene can lint clean and still draw nothing)"
for f in assets/cutscenes/*/*.cut; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .cut)
    lit=0
    for t in 2 6 12; do
        png="/tmp/cutgate-$name-$t.png"
        rm -f "$png"
        X ./cutplay.run shot "$f" "$t" "$png" >/dev/null 2>&1
        if [ -s "$png" ]; then
            # mean brightness: a frame that is entirely black drew nothing.
            # 0.25 is pure black in RGBA (alpha counts toward the mean).
            m=$(magick "$png" -format "%[fx:mean]" info: 2>/dev/null || echo 0)
            if awk "BEGIN{exit !($m > 0.26)}"; then lit=$((lit+1)); fi
        fi
        rm -f "$png"
    done
    if [ "$lit" -gt 0 ]; then
        ok "$name renders ($lit/3 sampled frames have picture)"
    else
        fail "$name rendered NOTHING at any sampled time"
    fi
done

printf '\n-------------------------------------------\n'
printf '%d checks, %d failed\n' "$RUN" "$BAD"
[ "$BAD" -eq 0 ] || exit 1
