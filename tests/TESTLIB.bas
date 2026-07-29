' ============================================================================
'  TESTLIB.bas -- a tiny assert library for headless ENGINE unit tests.
'
'  QB64PE has no test framework, so this is the whole thing: count assertions,
'  print only failures (quiet on success), and SYSTEM a non-zero exit code if any
'  failed so tests/run-tests.sh can gate on it.
'
'  Scope: engine modules whose functions touch only QB64 built-ins (TEXT, STATS,
'  the pure half of DATA). Anything that needs a rendered CANVAS, a font, or the
'  game's tables is NOT testable this way -- verify those in the real binary
'  (`dungeon.run chamberdump` / `audiomanifest`), per engine/ENGINE.md.
'
'  Traps this harness exists to avoid (all cost real time before):
'   - QB64 chdirs to the EXECUTABLE's dir at startup, so a test binary in tests/
'     resolves "assets/..." to tests/assets/. T_RepoRoot fixes cwd once, up front,
'     so every test sees the same paths the game does.
'   - A reserved word used as an identifier fails with "Name already in use", which
'     does NOT print the word "error" -- the runner checks for the Output: line.
'   - Identifiers are case-insensitive: never name a local after a short shared
'     global (CH/CW/SW/SH/c) or it silently shadows it.
' ============================================================================

' Point the process at the repo root, so tests use the same relative paths as the
' game ("assets/...", "tests/tmp/..."). Binaries live in tests/, so that is one up.
SUB T_RepoRoot
    IF _FILEEXISTS("dungeon.bas") = 0 THEN CHDIR ".."
END SUB

SUB T_Begin (nm AS STRING)
    T_RepoRoot
    T_SUITE = nm
    T_NPASS = 0: T_NFAIL = 0
    T_GRPNAME = "": T_GRPSHOWN = 0
END SUB

' Label the assertions that follow. Printed lazily -- only if one of them fails.
SUB T_Group (nm AS STRING)
    T_GRPNAME = nm: T_GRPSHOWN = 0
END SUB

' Render control characters visibly so a diff of ESC/CR/LF-bearing strings is readable.
FUNCTION T_Vis$ (s AS STRING)
    DIM r AS STRING, i AS INTEGER, b AS INTEGER
    FOR i = 1 TO LEN(s)
        b = ASC(s, i)
        SELECT CASE b
            CASE 27: r = r + "<ESC>"
            CASE 13: r = r + "<CR>"
            CASE 10: r = r + "<LF>"
            CASE 26: r = r + "<EOF>"
            CASE 0: r = r + "<NUL>"
            CASE IS < 32: r = r + "<" + _TRIM$(STR$(b)) + ">"
            CASE ELSE: r = r + CHR$(b)
        END SELECT
    NEXT i
    T_Vis$ = r
END FUNCTION

SUB T_Fail (label AS STRING, got AS STRING, want AS STRING)
    T_NFAIL = T_NFAIL + 1
    IF LEN(T_GRPNAME) > 0 AND T_GRPSHOWN = 0 THEN PRINT "  [" + T_GRPNAME + "]": T_GRPSHOWN = -1
    PRINT "    FAIL " + label
    PRINT "      want: " + T_Vis$(want)
    PRINT "      got : " + T_Vis$(got)
END SUB

' String equality.
SUB T_EqS (label AS STRING, got AS STRING, want AS STRING)
    IF got = want THEN T_NPASS = T_NPASS + 1 ELSE T_Fail label, got, want
END SUB

' Numeric equality (LONG covers the INTEGER/LONG cases we assert on).
SUB T_EqI (label AS STRING, got AS LONG, want AS LONG)
    IF got = want THEN T_NPASS = T_NPASS + 1 ELSE T_Fail label, _TRIM$(STR$(got)), _TRIM$(STR$(want))
END SUB

SUB T_True (label AS STRING, cond AS INTEGER)
    IF cond THEN T_NPASS = T_NPASS + 1 ELSE T_Fail label, "false", "true"
END SUB

SUB T_False (label AS STRING, cond AS INTEGER)
    IF cond THEN T_Fail label, "true", "false" ELSE T_NPASS = T_NPASS + 1
END SUB

' A file exists / does not.
SUB T_FileIs (label AS STRING, path AS STRING, want AS INTEGER)
    DIM there AS INTEGER
    there = (_FILEEXISTS(path) <> 0)
    IF want THEN
        IF there THEN T_NPASS = T_NPASS + 1 ELSE T_Fail label, "missing", "exists: " + path
    ELSE
        IF there THEN T_Fail label, "exists", "missing: " + path ELSE T_NPASS = T_NPASS + 1
    END IF
END SUB

' Whole text file contents (LF-joined, no trailing newline) -- for asserting on a
' file a routine under test wrote.
FUNCTION T_ReadAll$ (path AS STRING)
    DIM f AS INTEGER, ln AS STRING, r AS STRING, n AS INTEGER
    IF _FILEEXISTS(path) = 0 THEN T_ReadAll$ = "<no such file>": EXIT FUNCTION
    f = FREEFILE: OPEN path FOR INPUT AS #f
    DO WHILE NOT EOF(f)
        LINE INPUT #f, ln
        IF n > 0 THEN r = r + CHR$(10)
        r = r + ln: n = n + 1
    LOOP
    CLOSE #f
    T_ReadAll$ = r
END FUNCTION

' Remove a file if present (scratch cleanup; KILL on a missing file is an error).
SUB T_Rm (path AS STRING)
    IF _FILEEXISTS(path) THEN KILL path
END SUB

' Print the summary and exit with 0 (all passed) or 1 (something failed).
SUB T_Done
    PRINT "  " + T_SUITE + ": " + _TRIM$(STR$(T_NPASS)) + " passed, " + _TRIM$(STR$(T_NFAIL)) + " failed"
    IF T_NFAIL > 0 THEN SYSTEM 1
    SYSTEM 0
END SUB
