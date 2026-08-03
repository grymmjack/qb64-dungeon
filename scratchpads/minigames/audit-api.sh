#!/usr/bin/env bash
# ============================================================================
#  audit-api.sh -- do the API docs still describe the code?
#
#  An API document is a promise about an integration that has not happened yet,
#  which makes it the single easiest thing in this folder to let rot. Nothing
#  breaks when it drifts; it just quietly starts lying, and it lies most on the
#  day somebody finally uses it.
#
#  So the two claims that CAN be checked mechanically are checked:
#
#    1. every prototype has an API doc, and every API doc has a prototype
#    2. every constant a doc names in its Configuration section actually exists
#       in that prototype -- because the config table is the part an integrator
#       will copy, and a knob that does not exist is worse than an undocumented
#       one
#
#  What it cannot check is whether the prose is true. That is what the per-game
#  Invariants sections are for: each one names an assertion that already exists
#  in the selftest, so the code enforces the claim and the doc only points at it.
#
#  Run from scratchpads/minigames.
# ============================================================================
set -u
fail=0

echo "== 1. every prototype has an API doc =="
for f in *.bas; do
    # harness includes, not prototypes -- they have no selftest and no API doc
    case "$f" in MG.bas|MGDICE.bas) continue ;; esac
    name="${f%.bas}"
    if [ ! -f "$name-API.md" ]; then
        echo "  BAD -- $f has no $name-API.md"
        fail=1
    fi
done
[ $fail -eq 0 ] && echo "  ok -- $(ls *.bas | grep -vc '^MG\.bas$') prototypes, all documented"

echo
echo "== 2. every API doc has a prototype =="
orphan=0
for d in *-API.md; do
    [ "$d" = "MINIGAME-API.md" ] && continue
    name="${d%-API.md}"
    if [ ! -f "$name.bas" ]; then
        echo "  BAD -- $d documents $name.bas, which does not exist"
        orphan=1; fail=1
    fi
done
[ $orphan -eq 0 ] && echo "  ok -- no orphaned docs"

echo
echo "== 3. every documented constant exists in the source =="
bad=0
for d in *-API.md; do
    [ "$d" = "MINIGAME-API.md" ] && continue
    name="${d%-API.md}"
    src="$name.bas"
    [ -f "$src" ] || continue
    # the Configuration section only, up to the Art keys heading
    toks=$(awk '/^## Configuration/{p=1} /^## Art keys/{p=0} p' "$d" \
           | grep -oE '`[A-Z][A-Z_0-9]+`' | tr -d '`' | sort -u)
    for t in $toks; do
        if ! grep -qE "^CONST $t\b|^CONST .*[ ,]$t *=" "$src"; then
            echo "  BAD -- $d names $t, which is not a CONST in $src"
            bad=1; fail=1
        fi
    done
done
[ $bad -eq 0 ] && echo "  ok -- every documented knob exists"

echo
echo "== 4. every prototype flips through the ONE chokepoint =="
flip=0
for f in *.bas; do
    case "$f" in MG.bas|MGDICE.bas) continue ;; esac
    if grep -vE "^[[:space:]]*'" "$f" | grep -qE '(^|[^A-Za-z_])_DISPLAY\b'; then
        echo "  BAD -- $f calls _DISPLAY directly; it must end its frame with MgPresent"
        flip=1; fail=1
    fi
    if ! grep -q 'MgPresent' "$f"; then
        echo "  BAD -- $f never calls MgPresent, so it never flips through the chokepoint"
        flip=1; fail=1
    fi
    if ! grep -q "INCLUDE:'MGDICE.bi'" "$f"; then
        echo "  BAD -- $f does not link the harness (MGDICE), so MgPresent is a label"
        flip=1; fail=1
    fi
done
[ $flip -eq 0 ] && echo "  ok -- one flip, one name; becomes Present on integration"

echo
echo "== 5. the shared contract is present =="
for want in "MG_CTX" "MG_RESULT" "Thm~&" "Say\$" "Sfx" "PlayCue" "GameRoll" "Present" "RetireSound"; do
    if ! grep -qF "$want" MINIGAME-API.md; then
        echo "  BAD -- MINIGAME-API.md no longer mentions $want"
        fail=1
    fi
done
grep -qF "MG_CTX" MINIGAME-API.md && echo "  ok -- the mooring points are all named"

echo
if [ $fail -eq 0 ]; then echo "audit-api: ALL GREEN"; else echo "audit-api: PROBLEMS"; fi
exit $fail
