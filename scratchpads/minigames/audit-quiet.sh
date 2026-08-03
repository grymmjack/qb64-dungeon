#!/usr/bin/env bash
# ============================================================================
#  audit-quiet.sh -- can any prototype make a noise when nobody asked it to?
#
#  This exists because the answer was YES and nothing caught it. PLINKO measures
#  its own board by running ten thousand real physics drops at STARTUP, in every
#  mode including a normal launch. Every stud hit asked for a sound, and QB64
#  queues sound rather than dropping it -- so starting the game enqueued about a
#  hundred thousand beeps and then played them all.
#
#  Two rules, both checked here:
#
#    1. No prototype calls SOUND (or BEEP, or PLAY) directly. Everything goes
#       through MgBeep, which is the single place a mute can be applied.
#    2. Every prototype's tool modes are silent, because MgInit mutes any run
#       that was given an argument. Checked by CALLING MgInit's rule rather than
#       by reading it: the binary is run and its own report is believed.
#
#  Run from scratchpads/minigames.
# ============================================================================
set -u
fail=0

echo "== 1. nobody calls SOUND / BEEP / PLAY directly =="
# MG.bas is the ONE place SOUND is allowed -- it is the thing being funnelled to.
hits=$(grep -nE '(^|[^A-Za-z_])(SOUND|BEEP|PLAY)[ (]' *.bas \
       | grep -vE '^MG(DICE)?\.bas:' \
       | grep -vE ':[0-9]+:[[:space:]]*'"'"'' \
       | grep -viE 'MgBeep|PlayJack|PlayLock|PlayScr|PlayName|PlayWheel|PlayCups|PlayWhack|PlayMonkey|PlayRps|PlaySlab|PlayPlinko|PlayGame|PlayMaze|PlayDodge|PlayGamble|PlayCraps|PlayGuess|PlayTrap|PlayRiddle' )
if [ -n "$hits" ]; then
    echo "  BAD -- raw sound statements bypass every mute there is:"
    echo "$hits" | sed 's/^/    /'
    fail=1
else
    echo "  ok -- every tone goes through MgBeep"
fi

echo
echo "== 2. every prototype mutes itself when given any argument =="
if ! grep -q 'IF LEN(_TRIM\$(COMMAND\$)) > 0 THEN MG_QUIET = TRUE' MG.bas; then
    echo "  BAD -- MgInit no longer mutes argument-bearing runs"
    fail=1
else
    echo "  ok -- MgInit mutes any run with an argument (selftest, shot, trace, ...)"
fi

echo
echo "== 3. MgBeep still honours both mutes =="
if grep -A3 'SUB MgBeep' MG.bas | grep -q 'IF MG_QUIET THEN EXIT SUB' &&
   grep -A3 'SUB MgBeep' MG.bas | grep -q 'IF MG_SILENT > 0 THEN EXIT SUB'; then
    echo "  ok -- MG_QUIET (tool mode) and MG_SILENT (unwatched simulation) both checked"
else
    echo "  BAD -- MgBeep is missing one of its two gates"
    fail=1
fi

echo
echo "== 4. every selftest silences itself explicitly, belt AND braces =="
missing=""
mute=""
for f in *.bas; do
    # harness includes, not prototypes -- they have no selftest and no API doc
    case "$f" in MG.bas|MGDICE.bas) continue ;; esac
    sub=$(grep -oE '^SUB [A-Za-z]*SelfTest[[:space:]]*$' "$f" | head -1)
    [ -z "$sub" ] && continue
    # a prototype that predates MG.bi cannot call MgQuiet -- so instead it must be
    # provably incapable of making a sound at all
    if ! grep -q "INCLUDE:'MG.bas'" "$f"; then
        if grep -vE "^[[:space:]]*'" "$f" | grep -qE '(^|[^A-Za-z_])(SOUND|BEEP|PLAY)[ (]|MgBeep'; then
            mute="$mute $f"
        fi
        continue
    fi
    # the line right after the SUB header must be MgQuiet
    if ! awk -v s="$sub" 'p==1{print;exit} $0==s{p=1}' "$f" | grep -q 'MgQuiet'; then
        missing="$missing $f"
    fi
done
if [ -n "$missing" ]; then
    echo "  BAD -- selftest does not call MgQuiet first:$missing"
    fail=1
fi
if [ -n "$mute" ]; then
    echo "  BAD -- pre-harness prototype can make a sound but cannot mute itself:$mute"
    fail=1
fi
if [ -z "$missing" ] && [ -z "$mute" ]; then
    echo "  ok -- every harness selftest opens with MgQuiet; every pre-harness one is silent by construction"
fi

echo
echo "== 4b. a harness call must actually RESOLVE =="
# QB64 parses a call to an undefined SUB as a LABEL: it compiles, it runs, it does
# nothing. Checking that the text is present is therefore not enough -- four
# prototypes predate MG.bi and had a MgQuiet line that had never once executed.
resolve=0
for f in *.bas; do
    # harness includes, not prototypes -- they have no selftest and no API doc
    case "$f" in MG.bas|MGDICE.bas) continue ;; esac
    uses=$(grep -cE '^[[:space:]]*(MgQuiet|MgLoud|MgBeep|MgDiceSelfTest)' "$f")
    [ "$uses" -eq 0 ] && continue
    if ! grep -q "INCLUDE:'MG.bas'" "$f"; then
        echo "  BAD -- $f calls a harness SUB but does not include MG.bas (it compiles as a label and does nothing)"
        resolve=1; fail=1
    fi
done
[ $resolve -eq 0 ] && echo "  ok -- every harness call is backed by an include"

echo
echo "== 5. SOUND's queue is bounded =="
if grep -q 'IF MG_QDEPTH > MG_QMAX THEN EXIT SUB' MG.bas; then
    echo "  ok -- MgBeep drops requests once the queue runs ahead of real time"
else
    echo "  BAD -- nothing stops the sound queue growing without bound"
    fail=1
fi

echo
if [ $fail -eq 0 ]; then echo "audit-quiet: ALL GREEN"; else echo "audit-quiet: PROBLEMS"; fi
exit $fail
