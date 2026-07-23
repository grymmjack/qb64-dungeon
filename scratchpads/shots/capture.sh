#!/usr/bin/env bash
# capture.sh <app.run> <out.png> [settle_secs] [hard_timeout]
# Launch a FULLSCREEN QB64PE app, fullscreen-capture via spectacle (KWin), tear
# down by exact PID group. Adapted from ~/git/DRAW/DEV/qb64-shot.sh.
#
# Hard rules learned from that harness:
#   * NEVER `pkill -f` / `pgrep -f <path>` — under the agent's eval-wrapped shell
#     it matches the matcher's OWN argv and SIGTERMs the persistent shell
#     (observed: exit 144). Kill ONLY by the exact integer PID / process group.
#   * spectacle fullscreen capture (-b -n -f) is the Wayland-safe path; import
#     here has no X11 support and QB64 sets no _NET_WM_PID so window search fails.
set -uo pipefail
APP="$1"; OUT="$2"; SETTLE="${3:-4}"; HARD="${4:-20}"
cd /home/grymmjack/git/qb64-dungeon/scratchpads
[ -x "./$APP" ] || { echo "error: not executable: $APP" >&2; exit 2; }

# Launch in its own process group under a hard-timeout backstop.
setsid timeout -k 2 "$HARD" "./$APP" >/dev/null 2>&1 &
PID=$!
echo "launched $APP pid=$PID"

cleanup() {
    kill -TERM -"$PID" 2>/dev/null
    for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null || break; sleep 0.2; done
    kill -KILL -"$PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

# liveness-checked settle
ticks=$(awk -v s="$SETTLE" 'BEGIN{printf "%d",(s/0.2)+0.5}')
for _ in $(seq 1 "$ticks"); do
    kill -0 "$PID" 2>/dev/null || { echo "error: app exited during settle" >&2; exit 3; }
    sleep 0.2
done

setsid spectacle -b -n -f -o "$OUT" -d 400 2>/dev/null
sleep 0.5
if [ -s "$OUT" ]; then
    echo "CAPTURED -> $OUT  $(identify -format '%wx%h' "$OUT" 2>/dev/null)"
else
    echo "NO OUTPUT FILE" >&2; exit 6
fi
# trap teardown fires on exit
