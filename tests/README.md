# Headless engine tests

Assert suites for the **game-free** `engine/` modules. QB64PE has no test framework, so
`TESTLIB.bas` is the whole thing (~120 lines): count assertions, print only failures, and
exit non-zero so a runner can gate on it.

```sh
tests/run-tests.sh            # THE GATE: suites + both audits + the separability proof
tests/run-tests.sh stats      # only suites matching "stats" (skips the audits/proof)
QB64PE=/path/to/qb64pe tests/run-tests.sh    # explicit compiler
```

With no arguments `run-tests.sh` also runs:

- **`audit-boundary.sh`** — no `engine/` file may name a `game/` symbol (see
  [../engine/ENGINE.md](../engine/ENGINE.md)).
- **`audit-shadow.sh`** — no local may be named after a high-risk shared global. QB64
  identifiers are case-insensitive, so `DIM brown` inside a SUB silently shadows the
  shared `BROWN` colour. That exact bug made `DetectDoors` return zero doors forever,
  so the game's reinforced doors never once appeared. It compiles clean and warns about
  nothing — only a scan catches it.
- **`audit-shortcircuit.sh`** — QB64's `AND`/`OR` are bitwise and **always evaluate both
  sides**, so `IF rm > 0 AND ROOMS(rm).malive` still reads `ROOMS(0)`. With `$Debug` off
  that is a silent out-of-bounds read, not a crash. The audit flags the precise shape:
  an operand guarding a variable's *bounds* combined with a later operand subscripting
  by it. The codebase is currently clean; the audit is verified against planted hazards.
- **`../engine/examples/minimal`** — builds and selftests a second game on `engine/` alone. If
  the engine grows a hidden DUNGEON! dependency, this stops compiling.

Also wired as the VS Code tasks **TEST: Run engine tests** and **TEST: Run engine tests
(this file)**.

## What can be tested this way

Only modules whose functions touch nothing but QB64 built-ins — no rendered `CANVAS`, no
loaded font, no game tables. Today: `TEXT`, `STATS`, `MARKDOWN`, `SAVEIO`, `ARTPACK`, and
the pure half of `DATA` — 200 assertions across 6 suites.

Everything else stays verified through the real binary's dev modes (`dungeon.run
chamberdump`, `audiomanifest`, `ansilint`) or a play-test. Don't contort engine code into
testability at the cost of clarity; see [../engine/ENGINE.md](../engine/ENGINE.md) for
where the real boundary work is.

A module that *nearly* qualifies can be tested by **stubbing its collaborators** — see the
`PackIndex%`/`Sfx` stubs at the bottom of `TEST-DATA.bas`. Because QB64 compiles everything
as one translation unit, an unresolved call is a compile error, so the stubs are also an
honest record of what that module actually depends on.

## Writing a suite

Name it `TEST-<MODULE>.bas` and follow this skeleton — the runner picks it up automatically:

```basic
$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'    ' only if the module needs the shared globals

T_Begin "engine/THING.bas"

T_Group "SomeFunc$"
T_EqS "does the thing", SomeFunc$("in"), "out"

T_Done

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/THING.bas'
```

Assertions: `T_EqS` (string), `T_EqI` (numeric), `T_True` / `T_False`, `T_FileIs`.
Helpers: `T_Group` (label, printed only if something under it fails), `T_ReadAll$`,
`T_Rm`, `T_Vis$` (renders `<ESC>`/`<CR>`/`<LF>` so control-character diffs are readable).

Scratch files go in `tests/tmp/` (git-ignored); `T_Begin` chdirs to the repo root, so use
the same relative paths the game uses.

## QB64 traps this harness is shaped around

Each of these cost real debugging time — two of them while building the harness itself.

- **Identifiers are case-insensitive.** `DIM SHARED T_FAIL` collides with `SUB T_Fail`
  ("Name already in use"). Hence the counters are `T_NPASS`/`T_NFAIL` and the group label
  is `T_GRPNAME`. Same trap as a local `ch` shadowing the global `CH`.
- **A failed compile may never print the word "error".** Reserved words and name
  collisions print *"Name already in use"*, so `run-tests.sh` gates on the `Output:` line
  and a fresh binary instead of grepping for failures.
- **A runtime error can still exit 0** (QB64 prompts "Continue?"). So the runner also
  requires the suite's own summary line — a suite that dies before `T_Done` is a failure.
- **Relative paths resolve against the executable's directory**, not the shell's cwd, and
  test binaries live in `tests/`. `T_Begin` calls `T_RepoRoot` to fix that once.
- **`MKDIR` on an existing directory is a runtime error**, not a no-op — guard with
  `_DIREXISTS`.

## Verifying the harness itself

A suite that cannot fail is worthless. After changing `TESTLIB.bas`, break an assertion on
purpose and confirm it is reported with `want`/`got` **and** that `run-tests.sh` exits
non-zero.
