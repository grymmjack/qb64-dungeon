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

    echo "-- short-circuit audit (AND/OR evaluate both sides) --"
    if tests/audit-shortcircuit.sh | tail -1; then :; else (( fail++ )); failed+=("audit-shortcircuit"); fi

    # Save-format round-trip: the stream is positional, so a field added on one side and
    # not the other silently shifts everything after it. Also loads a COPY of the player's
    # real save to prove a format bump did not orphan it.
    echo "-- save round-trip + backward compat (dungeon.run savetest) --"
    if [[ -x ./dungeon.run ]]; then
        if sv=$(setsid timeout 90 xvfb-run -a ./dungeon.run savetest 2>&1) && grep -q 'savetest: PASS' <<<"$sv"; then
            grep -E 'seat isolation|round-tripped|compat:|loaded OK' <<<"$sv" | sed 's/^/  /'
        else
            printf '%s\n' "$sv" | sed 's/^/    /'
            (( fail++ )); failed+=("savetest")
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
    elif sout=$(setsid timeout 60 xvfb-run -a ./examples/minimal/minimal.run selftest 2>&1) && grep -q '^OK$' <<<"$sout"; then
        echo "  $(grep -E 'secret doors|brown doors' <<<"$sout" | tr -s ' ' | paste -sd'|' -)"
        echo "  OK -- the engine drives a non-DUNGEON! game"
    else
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
