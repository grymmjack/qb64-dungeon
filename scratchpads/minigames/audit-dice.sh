#!/usr/bin/env bash
# ============================================================================
#  audit-dice.sh -- is every die the PLAYER rolls actually a die they may roll?
#
#  qb64-dungeon has a Real Dice setting: the player rolls physical dice on their
#  table and types the result, and a Dice Math setting for who adds the modifier.
#  A mini-game that rolls a d6 with the raw RNG silently opts that player out --
#  the setting is on, and the game rolls anyway, and nothing looks wrong.
#
#  So: any raw MgRoll% of a DIE-SHAPED number (4, 6, 8, 10, 12, 20) has to be
#  justified in place, with an inline `' not a die:` waiver. That forces a
#  decision at each site instead of a policy nobody re-reads. The legitimate
#  cases are real and common -- a Monte Carlo runs hundreds of thousands of times
#  with nobody watching and must never be able to prompt.
#
#  What it CANNOT check: that a game needing individual faces rolls its dice
#  individually. Under Real Dice the engine publishes no faces at all (the player
#  rolled physical dice; the game never saw them), so rolling 2d6 and reading
#  DieFace% works perfectly with animation and breaks for every Real Dice player.
#  That one is a per-game assertion -- see GAMBLE.bas.
#
#  Run from scratchpads/minigames.
# ============================================================================
set -u
fail=0

echo "== 1. every die-shaped raw roll is waived in place =="
bad=0
for f in *.bas; do
    # harness includes, not prototypes -- they have no selftest and no API doc
    case "$f" in MG.bas|MGDICE.bas) continue ;; esac
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # a waiver is an inline `' not a die:` comment on the SAME line
        case "$line" in
            *"' not a die"*) ;;
            *) echo "  BAD -- $f: $(echo "$line" | sed 's/^[[:space:]]*//')"; bad=1; fail=1 ;;
        esac
    done <<EOF
$(grep -nE 'MgRoll%\((4|6|8|10|12|20)\)' "$f" | grep -vE '^[0-9]+:[[:space:]]*'"'")
EOF
done
[ $bad -eq 0 ] && echo "  ok -- every raw die-shaped roll says why it is not a player's die"

echo
echo "== 2. the dice contract mirrors the engine, name for name =="
miss=""
for want in "FUNCTION GameRoll%" "FUNCTION PromptRoll%" "FUNCTION AnimatedRoll%" \
            "SUB PublishFaces" "FUNCTION DieFace%" "SUB RollSeqBegin" "SUB RollSeqEnd"; do
    grep -q "^$want" MGDICE.bas || miss="$miss ${want##* }"
done
for want in "opt_realdice" "opt_dicemath" "DIE_FACE_N"; do
    grep -q "$want" MGDICE.bi || miss="$miss $want"
done
if [ -n "$miss" ]; then
    echo "  BAD -- the shim no longer matches engine/UI.bas:$miss"
    fail=1
else
    echo "  ok -- GameRoll% / PromptRoll% / AnimatedRoll% / PublishFaces / DieFace% / RollSeq*"
    echo "        plus opt_realdice, opt_dicemath, DIE_FACE_N -- integration is DELETING the shim"
fi

echo
echo "== 3. Real Dice publishes no faces =="
if grep -A12 '^FUNCTION GameRoll%' MGDICE.bas | grep -q 'DIE_FACE_N = 0'; then
    echo "  ok -- the real-dice path clears the face table rather than leaving stale values"
else
    echo "  BAD -- GameRoll% no longer clears DIE_FACE_N on the Real Dice path"
    fail=1
fi

echo
echo "== 4. every dice game exercises the contract in its selftest =="
dbad=0
for f in $(grep -lE '(^|[^A-Za-z_])GameRoll%\(' *.bas 2>/dev/null | grep -vE '^MG(DICE)?\.bas$'); do
    if ! grep -q 'MgDiceSelfTest' "$f"; then
        echo "  BAD -- $f rolls dice but never runs MgDiceSelfTest"
        dbad=1; fail=1
    fi
done
[ $dbad -eq 0 ] && echo "  ok -- every prototype that rolls dice asserts the contract"

echo
echo "== 5. the 3D dice are the GAME's module, not a copy =="
if grep -q "INCLUDE:'../../engine/DICE3D/_ALL.BM'" MGDICE.bas &&
   grep -q "INCLUDE:'../../engine/DICE3D/_ALL.BI'" MGDICE.bi; then
    echo "  ok -- MGDICE pulls in engine/DICE3D directly, so a prototype shows what the game will"
else
    echo "  BAD -- MGDICE no longer links the game's own DICE3D module"
    fail=1
fi
if grep -q '^SUB PresentNoFlip' MGDICE.bas; then
    echo "  ok -- DICE3D's one host dependency is stubbed"
else
    echo "  BAD -- PresentNoFlip stub is gone; DICE3D will not link"
    fail=1
fi

echo
if [ $fail -eq 0 ]; then echo "audit-dice: ALL GREEN"; else echo "audit-dice: PROBLEMS"; fi
exit $fail
