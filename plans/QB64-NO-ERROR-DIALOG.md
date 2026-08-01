# Stop QB64PE runtime errors from hanging on a modal dialog

*Portable recipe — nothing here is DUNGEON!-specific. Drop it into any QB64PE program.*

## The problem

An **unhandled** QB64 runtime error opens a modal GUI message box:

```
Line: 165 (in main module)
File not found
Continue?          [Yes]  [No]
```

…and waits for a **mouse click**. That is fine when you are sitting there. It is fatal for
anything automated — a headless run under `xvfb`, a screenshot capture, a CI/test script, or an
AI agent driving the binary — because nobody can click it. The process just hangs, prints
nothing useful, and eventually gets killed by a timeout with no clue what went wrong.

## The fix

Three pieces. All of them go in the **main module** (not in an `.BM`/include).

### 1. Arm the handler before anything can fail

Put this near the very top, *before* the first file/asset access — the first thing that errors
is almost always a missing asset during startup.

```basic
ON ERROR GOTO FatalError
CONST ERR_MAX = 20                 ' runtime errors tolerated INTERACTIVELY before giving up
DIM SHARED err_seen AS INTEGER
DIM SHARED screen_shown AS INTEGER ' TRUE once a window is actually on screen
```

### 2. Record when a window actually appears

If you use `$SCREENHIDE` and reveal the window later, set the flag at that moment:

```basic
_SCREENSHOW: screen_shown = TRUE
```

If your program always shows a window immediately, set `screen_shown = TRUE` right after your
`SCREEN _NEWIMAGE(...)` line instead.

### 3. The handler itself

Put it **after** the last executable line of the main module — after your final `SYSTEM`/`END`,
so normal flow can never fall into it, and before any `'$INCLUDE` of procedure bodies.

```basic
SYSTEM              ' <- normal end of your program

FatalError:
    err_seen = err_seen + 1
    _DEST _CONSOLE
    PRINT ""
    PRINT "!! QB64 RUNTIME ERROR " + LTRIM$(STR$(ERR)) + " at line " + LTRIM$(STR$(_ERRORLINE))
    PRINT "!! " + _ERRORMESSAGE$
    IF NOT screen_shown THEN
        ' Nobody can see or click anything. A dialog here would hang forever, so fail loudly
        ' and let the caller's exit code do the talking.
        PRINT "!! no window is up -- aborting"
        SYSTEM 1
    END IF
    IF err_seen > ERR_MAX THEN
        PRINT "!! " + LTRIM$(STR$(err_seen)) + " runtime errors -- not survivable, aborting"
        SYSTEM 1
    END IF
    ' A human is watching: skip the broken statement and carry on, so one missing optional
    ' asset does not end their session.
    PRINT "!! continuing (RESUME NEXT) -- " + LTRIM$(STR$(ERR_MAX - err_seen)) + " more before abort"
    RESUME NEXT
```

## Why branch on `screen_shown` and not on "am I in dev mode?"

The obvious version is `IF devmode THEN SYSTEM 1`, where `devmode` is computed from `COMMAND$`.
**Do not do that.** It is a curated list of mode-name substrings, and it silently rots: every new
CLI mode you add is missing from it, so it takes the *wrong* branch and you are back to a hang.

`screen_shown` asks the question you actually mean — *is a human looking at a window?* — and it
cannot drift, because it is set by the act of showing the window.

## What you get

| situation | before | after |
|---|---|---|
| headless / CI / agent | modal dialog, hangs until timeout, no output | one-line error + **exit code 1**, instantly |
| interactive, minor error | modal dialog interrupts the user | printed to console, program carries on |
| interactive, error storm | dialog per error, forever | aborts after `ERR_MAX` |

## Verifying it (do this — it is quick)

**RESUME NEXT works:**

```basic
$CONSOLE:ONLY
ON ERROR GOTO H
PRINT "before"
OPEN "definitely-not-here.txt" FOR INPUT AS #1    ' boom
PRINT "AFTER  (RESUME NEXT worked)"
SYSTEM 0
H:
    PRINT "  trapped: "; _ERRORMESSAGE$; " on line "; _ERRORLINE
    RESUME NEXT
```

**The abort path works** — easiest way to force a real startup error is to run the binary from a
directory that has none of its assets:

```bash
cp yourprog.run /tmp/ && cd /tmp && ./yourprog.run <some-cli-mode>
echo "exit: $?"          # expect 1, and expect it to return immediately
```

## A related trap you will hit while testing this

**QB64PE resolves relative paths against the EXECUTABLE's directory, not your shell's cwd.**
(`_CWD$` is the exe's dir; `_STARTDIR$` is where it was launched.) So a copy of the binary in
`/tmp` fails *every* asset load — which is genuinely useful for testing the abort path, but will
badly mislead you if you forget it and think you have found a real bug.

## Useful QB64PE keywords

- `ERR` — the error number (53 = File not found)
- `_ERRORLINE` — the line number in the source
- `_ERRORMESSAGE$` — the human-readable message
- `RESUME NEXT` — continue at the statement *after* the one that failed
- `_ERRORHANDLING` — TRUE if an `ON ERROR` handler is currently installed

Wiki: <https://qb64phoenix.com/qb64wiki/index.php/ON_ERROR>
