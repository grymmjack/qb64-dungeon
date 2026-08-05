#!/usr/bin/env bash
# Compile and run every tests/TEST-*.bas. Exits non-zero if any suite fails.
#
# Usage:  tests/run-tests.sh [name-fragment ...]
#   tests/run-tests.sh            # all suites
#   tests/run-tests.sh stats      # only suites whose filename matches "stats"
#
# The compiler comes from $QB64PE, else the qb64pe on PATH, else a few known spots.
# NOTE: a QB64 compile that fails on a reserved word prints "Name already in use"
# and never prints the word "error" -- so success is detected by the "Output:" line
# and a fresh binary, never by grepping for failures.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

find_qb64() {
    if [[ -n "${QB64PE:-}" && -x "$QB64PE" ]]; then echo "$QB64PE"; return; fi
    local c
    c=$(command -v qb64pe 2>/dev/null) && [[ -x "$c" ]] && { echo "$c"; return; }
    for c in "$HOME/git/qb64pe/qb64pe" "$HOME/qb64pe/qb64pe" /opt/qb64pe/qb64pe; do
        [[ -x "$c" ]] && { echo "$c"; return; }
    done
}

QB=$(find_qb64)
if [[ -z "$QB" ]]; then
    echo "run-tests: no qb64pe compiler found. Set QB64PE=/path/to/qb64pe" >&2
    exit 2
fi

mkdir -p tests/tmp
pass=0; fail=0; failed=()

for src in tests/TEST-*.bas; do
    [[ -e "$src" ]] || continue
    name=$(basename "$src" .bas)

    # optional filters: skip suites matching none of the given fragments
    if (( $# > 0 )); then
        keep=0
        for want in "$@"; do
            shopt -s nocasematch
            [[ "$name" == *"$want"* ]] && keep=1
            shopt -u nocasematch
        done
        (( keep )) || continue
    fi

    bin="tests/$name.run"
    rm -f "$bin"
    out=$("$QB" -w -x "$src" -o "$bin" 2>&1)

    if ! grep -q '^Output:' <<<"$out" || [[ ! -x "$bin" ]]; then
        echo "COMPILE FAIL  $name"
        grep -vE '^\[|%\[A$|^$' <<<"$out" | tail -6 | sed 's/^/    /'
        (( fail++ )); failed+=("$name (compile)")
        continue
    fi

    # Run it. A QB64 RUNTIME error prints "Runtime error:" and can still exit 0
    # (it prompts "Continue?"), so exit code alone is not enough -- require the
    # suite's own summary line, which only T_Done prints.
    run_out=$("./$bin" 2>&1); rc=$?
    printf '%s\n' "$run_out"

    if [[ $rc -ne 0 ]]; then
        (( fail++ )); failed+=("$name")
    elif grep -q 'Runtime error' <<<"$run_out"; then
        echo "    (runtime error -- suite aborted)"
        (( fail++ )); failed+=("$name (runtime)")
    elif ! grep -q ' passed, ' <<<"$run_out"; then
        echo "    (no summary line -- suite did not reach T_Done)"
        (( fail++ )); failed+=("$name (incomplete)")
    else
        (( pass++ ))
    fi
done

# With an explicit filter the caller wants one suite, not the whole gate.
if (( $# == 0 )); then
    echo
    echo "-- boundary audit (engine/ must name no game symbol) --"
    if tests/audit-boundary.sh | tail -1; then :; else (( fail++ )); failed+=("audit-boundary"); fi

    echo "-- shadow audit (no local named after a high-risk global) --"
    if tests/audit-shadow.sh | tail -1; then :; else (( fail++ )); failed+=("audit-shadow"); fi


# ---------------------------------------------------------------------------
# devrun -- run a dungeon.run dev mode under xvfb, RETRYING ONCE on failure.
#
# Why a retry: three different checks (fightshot, fogdump, savetest) each went red
# exactly once during a full gate run and then passed standalone, and passed 18/18
# when hammered back-to-back and under CPU load. Something in running six
# `xvfb-run -a` instances through one script is occasionally flaky in a way that is
# not reproducible in isolation -- and a gate that cries wolf gets ignored, which
# costs far more than one repeated run.
#
# A retry is safe here because these checks are DETERMINISTIC: same board, same
# tables, same assertions. A real failure fails both times. Set DEVRUN_TRIES=1 to
# disable if you are ever chasing the flake itself.
#
# Usage:  devrun <timeout> <expect-substring> <cmd...>
# Sets:   DEVRUN_OUT (combined output of the last attempt)
devrun() {
    local secs="$1" expect="$2"; shift 2
    local tries="${DEVRUN_TRIES:-2}" i
    for (( i = 1; i <= tries; i++ )); do
        DEVRUN_OUT=$(setsid timeout "$secs" xvfb-run -a "$@" 2>&1) && \
            grep -qF -- "$expect" <<<"$DEVRUN_OUT" && return 0
        (( i < tries )) && echo "     (retry $i/$((tries-1)) -- first attempt did not report '$expect')"
    done
    return 1
}

    echo "-- short-circuit audit (AND/OR evaluate both sides) --"
    if tests/audit-shortcircuit.sh | tail -1; then :; else (( fail++ )); failed+=("audit-shortcircuit"); fi
    echo "-- dump registry (tests/audit-dumps.sh) --"
    if tests/audit-dumps.sh | tail -1; then :; else (( fail++ )); failed+=("audit-dumps"); fi
    echo "-- headless mute (tests/audit-mute.sh) --"
    if tests/audit-mute.sh | tail -1; then :; else (( fail++ )); failed+=("audit-mute"); fi

    echo "-- pack-fallback audit (a partial pack must degrade to default/) --"
    if tests/audit-packfallback.sh | tail -3; then :; else (( fail++ )); failed+=("audit-packfallback"); fi

    # The data EDITOR writes to the same tables the game reads at launch, so the
    # claim that matters is not how it looks -- it is that load->save is a no-op
    # and that rewriting one field cannot shred the rest of the row. Proven by
    # planting the wrong split rule for strings.txt, which made row 8's inline
    # pipe colour "|10" come back as "| 10": the gate went red.
    echo "-- data editor round-trip (dungeon.run dataedittest) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 90 "survives load" ./dungeon.run dataedittest nocolor; then
            grep -E 'survives load' <<<"$DEVRUN_OUT" | sed 's/^/  /'
        else
            grep -E 'BAD|FAILED' <<<"$DEVRUN_OUT" | head -6 | sed 's/^/    /'
            (( fail++ )); failed+=("dataedittest")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Content tables: a data mistake never crashes, the level just plays wrong.
    echo "-- content tables (dungeon.run datalint) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "datalint: clean" ./dungeon.run datalint nocolor; then dl="$DEVRUN_OUT"
            grep -E 'datalint: clean' <<<"$dl" | sed 's/^/  /'
        else
            dl="$DEVRUN_OUT"
            grep -E '!!|error' <<<"$dl" | head -8 | sed 's/^/    /'
            (( fail++ )); failed+=("datalint")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Pack scanning. What is on disk and what SETTINGS offers are different questions -- a folder
    # with no assets of that kind is skipped, and one holding qb64-dungeon.ignore is skipped
    # whatever is in it. Neither is visible from a file listing, which is how a DAW project
    # sitting in assets/music/ came to look like a music pack.
    echo "-- content packs (dungeon.run packs) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "packs" ./dungeon.run packs nocolor; then pl="$DEVRUN_OUT"
            grep -E '^  (SFX|Music|Art|Data)' <<<"$pl" | sed 's/^/  /'
        else
            (( fail++ )); failed+=("packs")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # The theme file. Colours resolve by NAME with a per-call-site fallback, so a typo does not
    # fail -- it silently keeps the built-in colour and a pack author sees no change at all.
    echo "-- theme colours (dungeon.run themelint) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "themelint" ./dungeon.run themelint nocolor; then tl="$DEVRUN_OUT"
            grep -E 'colour\(s\) loaded|asked for' <<<"$tl" | sed 's/^/  /'
        else
            tl="$DEVRUN_OUT"
            grep -E 'BAD' <<<"$tl" | head -4 | sed 's/^/    /'
            (( fail++ )); failed+=("themelint")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Ability-roll methods. A method is two claims -- how it LOOKS and what it PRODUCES -- and
    # "3d6 re-roll 1s & 2s" once shipped as 3d4+6: identical maths, visibly the wrong dice, and
    # nothing could tell. This checks the half a screenshot cannot.
    echo "-- ability-roll methods (dungeon.run statroll) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 120 "statroll" ./dungeon.run statroll 4000 nocolor; then sr="$DEVRUN_OUT"
            grep -E 'animated .*fast' <<<"$sr" | sed 's/^/  /'
        else
            sr="$DEVRUN_OUT"
            grep -E 'BAD' <<<"$sr" | head -4 | sed 's/^/    /'
            (( fail++ )); failed+=("statroll")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # SETTINGS layout. An option id that BuildSetLayout never places simply does not draw --
    # no error, the screen looks normal, one row is just missing. That is how the per-category
    # audio-format rows vanished when the id space outgrew the SL_* arrays' hardcoded bounds.
    echo "-- settings layout (dungeon.run settingsshot) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "settingsshot" ./dungeon.run settingsshot nocolor; then sl="$DEVRUN_OUT"
            grep -E 'option row' <<<"$sl" | sed 's/^/  /'
        else
            sl="$DEVRUN_OUT"
            grep -E 'BAD|never placed' <<<"$sl" | head -4 | sed 's/^/    /'
            (( fail++ )); failed+=("settingsshot")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # CUT-SCENE WIRING. Every hook that plays a scene falls through gracefully when the
    # scene is absent -- which is right, but means a RENAMED or MISTYPED scene is
    # indistinguishable from one never written: nothing errors and the beat simply stops
    # happening. cutwire prints the map; the gate fails only if a name the game asks for
    # once resolved and now does not, which is what a rename looks like.
    echo "-- cut-scene wiring (dungeon.run cutwire) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 90 "cutwire" ./dungeon.run cutwire nocolor; then cw="$DEVRUN_OUT"
            grep -E 'answered' <<<"$cw" | sed 's/^/  /'
            # every chamber must have a scene: those twelve are shipped, so a miss here is a
            # slug that has drifted out of step with chambers.txt rather than unwritten art.
            if grep -qE '^\s*--\s+chamber-' <<<"$cw"; then
                echo "    BAD -- a chamber scene no longer resolves (slug drift?)"
                grep -E '^\s*--\s+chamber-' <<<"$cw" | head -4 | sed 's/^/    /'
                (( fail++ )); failed+=("cutwire")
            fi
        else
            (( fail++ )); failed+=("cutwire")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # BOARD TRIGGERS + BOARD ART. Both fail silently and look exactly like "nothing is
    # there": a trigger on an unwalkable cell can never fire, and an overlay whose art does
    # not resolve draws nothing. overlaylint also DRAWS them and requires the board's pixels
    # to change, because "the data is valid" and "you can see it" are different claims.
    echo "-- board triggers + overlays (dungeon.run triggerlint / overlaylint) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 90 "triggerlint" ./dungeon.run triggerlint nocolor; then tl="$DEVRUN_OUT"
            grep -E 'trigger\(s\)$|ok  --' <<<"$tl" | head -2 | sed 's/^/  /'
        else
            tl="$DEVRUN_OUT"; grep -E 'BAD' <<<"$tl" | head -4 | sed 's/^/    /'
            (( fail++ )); failed+=("triggerlint")
        fi
        if devrun 90 "overlaylint" ./dungeon.run overlaylint nocolor; then ol="$DEVRUN_OUT"
            grep -E 'changed the board|ok  --' <<<"$ol" | head -2 | sed 's/^/  /'
        else
            ol="$DEVRUN_OUT"; grep -E 'BAD|drew NOTHING' <<<"$ol" | head -4 | sed 's/^/    /'
            (( fail++ )); failed+=("overlaylint")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # The rules screen's GENERATED sections. Most of what a player reads there is assembled at
    # display time from live settings + stats.txt, so no file on disk contains it and nothing else
    # in the gate can see it. An empty ability section is what a missing stats.txt looks like.
    echo "-- generated rules text (dungeon.run ruleslint) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "ruleslint" ./dungeon.run ruleslint nocolor; then rl="$DEVRUN_OUT"
            grep -E 'ability line' <<<"$rl" | sed 's/^/  /'
        else
            rl="$DEVRUN_OUT"
            grep -E 'BAD|!!' <<<"$rl" | head -5 | sed 's/^/    /'
            (( fail++ )); failed+=("ruleslint")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Secret-mask reachability. The mask is hand-painted ART, and a region no door opens is
    # unreachable forever -- which matters because killing the monster in key_room is the ONLY
    # way to get the Level Key. Cheap insurance against an art edit stranding a region.
    echo "-- secret-mask reachability (dungeon.run fogdump) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "mask OK" ./dungeon.run fogdump nocolor; then fg="$DEVRUN_OUT"
            grep -E 'mask OK' <<<"$fg" | sed 's/^/  /'
        else
            fg="$DEVRUN_OUT"
            grep -E '^!!|VERDICT|ORPHAN' <<<"$fg" fogdump.txt 2>/dev/null | head -5 | sed 's/^/    /'
            (( fail++ )); failed+=("fogdump (orphaned mask region)")
        fi
        rm -f fogdump.png fogdump-regions.png fogdump.txt
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Tactical-combat screen: renders a synthetic 1-vs-4 encounter to a PNG. A pure smoke
    # check -- it proves the renderer runs, the layout resolves, and the 8x8 font switch is
    # restored, none of which the layout suite can see (that one never draws a pixel).
    echo "-- tactical combat screen (dungeon.run fightshot) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "wrote fightshot.png" ./dungeon.run fightshot nocolor; then fs="$DEVRUN_OUT"
            grep -E 'actors:|portraits found:' <<<"$fs" | sed 's/^/  /'
        else
            fs="$DEVRUN_OUT"
            printf '%s\n' "$fs" | sed 's/^/    /'
            (( fail++ )); failed+=("fightshot")
        fi
        rm -f fightshot.png
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Save-format round-trip: the stream is positional, so a field added on one side and
    # not the other silently shifts everything after it. Also loads a COPY of the player's
    # real save to prove a format bump did not orphan it.
    echo "-- save round-trip + backward compat (dungeon.run savetest) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 90 "savetest: PASS" ./dungeon.run savetest; then sv="$DEVRUN_OUT"
            grep -E 'seat isolation|round-tripped|compat:|loaded OK' <<<"$sv" | sed 's/^/  /'
        else
            sv="$DEVRUN_OUT"
            printf '%s\n' "$sv" | sed 's/^/    /'
            (( fail++ )); failed+=("savetest")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Bestiary discovery is deliberately NOT in the save, so a save round-trip cannot cover it.
    # The thing worth testing is the thing that makes it useful: discover, throw the run away,
    # come back and still know.
    # The auto-walker: pure logic no screenshot can check and nobody can be asked to sit
    # through. It must PATH, PROGRESS, and not churn its goal -- the churn assertion caught a
    # walker that made 400 legal closing moves and arrived nowhere.
    echo "-- auto-move pathing (dungeon.run automovetest) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 120 "automovetest: PASS" ./dungeon.run automovetest nocolor; then
            grep -E 'walked|closest|goal changed' <<<"$DEVRUN_OUT" | sed 's/^/  /'
        else
            am="$DEVRUN_OUT"
            grep -E 'FAIL|walked|closest|goal changed' <<<"$am" | head -6 | sed 's/^/    /'
            (( fail++ )); failed+=("automovetest")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Dice rolls: the one part of the UI that had NO headless check at all, which is why the
    # regression where dice animated on a totally black screen could only be caught by playing
    # the game and could only be reported with a photo of a monitor. rollshot drives the real
    # roll functions over the real board and asserts each settled frame is mostly NOT black.
    echo "-- dice styles render over the board (dungeon.run rollshot) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 120 "dice styles rendered over the board" ./dungeon.run rollshot nocolor; then
            grep -E '^  (ok|BAD)' <<<"$DEVRUN_OUT" | sed 's/^/  /'
        else
            grep -E 'BAD|never reached|did not render' <<<"$DEVRUN_OUT" | head -6 | sed 's/^/    /'
            (( fail++ )); failed+=("rollshot")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    echo "-- bestiary discovery survives a new run (dungeon.run bestiarytest) --"
    if [[ -x ./dungeon.run ]]; then
        if devrun 60 "OK --" ./dungeon.run bestiarytest nocolor; then bt="$DEVRUN_OUT"
            grep -E 'met |OK --' <<<"$bt" | sed 's/^/  /'
        else
            bt="$DEVRUN_OUT"
            printf '%s\n' "$bt" | sed 's/^/    /'
            (( fail++ )); failed+=("bestiarytest")
        fi
    else
        echo "  SKIP -- no dungeon.run built"
    fi

    # Separability proof: a game that is NOT DUNGEON!, built on engine/ alone.
    # If engine/ ever grows a hidden game dependency, this stops compiling.
    echo "-- separability (examples/minimal on engine/ alone) --"
    rm -f examples/minimal/minimal.run
    mout=$("$QB" -w -x examples/minimal/minimal.bas -o examples/minimal/minimal.run 2>&1)
    if ! grep -q '^Output:' <<<"$mout" || [[ ! -x examples/minimal/minimal.run ]]; then
        echo "  COMPILE FAIL -- engine/ no longer builds without game/"
        grep -vE '^\[|%\[A$|^$' <<<"$mout" | tail -6 | sed 's/^/    /'
        (( fail++ )); failed+=("minimal (compile)")
    elif devrun 60 "OK" ./examples/minimal/minimal.run selftest; then sout="$DEVRUN_OUT"
        echo "  $(grep -E 'secret doors|brown doors' <<<"$sout" | tr -s ' ' | paste -sd'|' -)"
        echo "  OK -- the engine drives a non-DUNGEON! game"
    else
        sout="$DEVRUN_OUT"
        printf '%s\n' "$sout" | sed 's/^/    /'
        (( fail++ )); failed+=("minimal (selftest)")
    fi
fi

echo
if (( fail == 0 )); then
    if (( pass == 0 )); then echo "no suites matched."; exit 0; fi
    if (( $# == 0 )); then
        echo "ALL GREEN -- $pass suite(s) + audits + separability proof passed."
    else
        echo "ALL GREEN -- $pass suite(s) passed (filtered: audits + separability NOT run)."
    fi
    exit 0
fi
echo "$fail check(s) FAILED: ${failed[*]}"
exit 1
