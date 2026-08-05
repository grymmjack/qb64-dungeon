' ============================================================================
'  CUTPLAY.bas -- the standalone cut-scene player.
'
'  Build:  qb64pe -w -x engine/cutplay/CUTPLAY.bas -o cutplay.run
'          ...FROM THE REPO ROOT, and the binary MUST live at the repo root:
'          QB64PE chdirs to the executable at startup, so `assets/...` only
'          resolves when the .run sits beside `assets/`. A binary built into
'          scratchpads/ silently fails every _FILEEXISTS -- see CLAUDE.md.
'
'  Modes:
'      cutplay.run <file.cut> [key=value ...]   play, with hot reload
'      cutplay.run lint <file.cut|all>          compile only, report, exit code
'      cutplay.run shot <file.cut> <t> <out>    render at t seconds -> PNG
'      cutplay.run selftest                     headless assertions
'
'  Keys while playing:
'      [R] reload from disk    [P] pause      [->] jump 1s ahead
'      [L] loop                [S] screenshot [SPACE] advance / hurry text
'      [1..4] pick a choice    [ESC] skip / quit
' ============================================================================
$CONSOLE
'$INCLUDE:'../CUTSCENE.BI'
'$INCLUDE:'CUTMOCK.bi'
'$INCLUDE:'../ansi/ANSIPrint.bi'

'--- A RUNTIME ERROR MUST NEVER OPEN A DIALOG.
'    An unhandled QB64 error pops a modal box and waits for a CLICK; under
'    xvfb (every lint run, every shot, every gate) nobody can click it, so the
'    process just hangs with no output saying why. Armed before anything can
'    fail. The branch is on whether a WINDOW IS UP, not on a list of mode
'    names -- a list rots every time a mode is added. ---
ON ERROR GOTO CutplayFatal

DIM SHARED SCREEN_SHOWN AS INTEGER
DIM SHARED ERR_COUNT AS INTEGER
CONST ERR_MAX = 24

DIM SHARED PLAY_LOOP AS INTEGER
DIM SHARED SHOT_PATH AS STRING

CUT_ASSETROOT = "assets/"
CUT_GRIDFONT = 16                  ' QB64's built-in 8x16
CUT_TEXTSPEED = 45
CUT_MODE = CUT_MANUAL
MOCK_PACK = "default"

'--- argument scan -----------------------------------------------------------
DIM mode AS STRING, target AS STRING, i AS INTEGER, a AS STRING
DIM shotT AS SINGLE, shotOut AS STRING, nargs AS INTEGER

mode = "play"
FOR i = 1 TO _COMMANDCOUNT
    a = COMMAND$(i)
    SELECT CASE LCASE$(a)
        CASE "lint": mode = "lint": _CONTINUE
        CASE "shot": mode = "shot": _CONTINUE
        CASE "selftest": mode = "selftest": _CONTINUE
        CASE "edit": mode = "edit": _CONTINUE
        CASE "editshot": mode = "editshot": _CONTINUE
        CASE "auto": CUT_MODE = CUT_AUTO: _CONTINUE
        CASE "quiet": CUT_QUIET = TRUE: _CONTINUE
        CASE "loop": PLAY_LOOP = TRUE: _CONTINUE
    END SELECT
    IF INSTR(a, "=") > 1 THEN MockSetFromArg a: _CONTINUE
    nargs = nargs + 1
    SELECT CASE nargs
        CASE 1: target = a
        CASE 2: shotT = CutNum!(a)
        CASE 3: shotOut = a
    END SELECT
NEXT i

'--- headless modes must be SILENT and must never wait for anything ---
IF mode <> "play" _ANDALSO mode <> "edit" _ANDALSO mode <> "editshot" THEN
    CUT_QUIET = TRUE
    CUT_MODE = CUT_AUTO
END IF
'--- the editor scrubs by re-simulating, which would replay every sound each
'    time the playhead moved. Silent by design. ---
IF mode = "edit" _ORELSE mode = "editshot" THEN CUT_QUIET = TRUE

SELECT CASE mode
    CASE "lint": DoLint target: SYSTEM CutExitCode%
    CASE "selftest": DoSelftest: SYSTEM CutExitCode%
END SELECT

IF LEN(target) = 0 THEN
    _DEST _CONSOLE
    PRINT "usage: cutplay.run <file.cut> [key=value ...]"
    PRINT "       cutplay.run lint <file.cut|all>"
    PRINT "       cutplay.run shot <file.cut> <seconds> <out.png>"
    PRINT "       cutplay.run edit <file.cut>          see it, scrub it, tune it"
    PRINT "       cutplay.run selftest"
    PRINT
    PrintCutKeys
    SYSTEM 2
END IF

'--- screen ------------------------------------------------------------------
SCREEN _NEWIMAGE(CUT_PXW, CUT_PXH, 32)
_FONT 16
_TITLE "cutplay -- " + target
_DISPLAY
SCREEN_SHOWN = TRUE

SELECT CASE mode
    CASE "shot": DoShot target, shotT, shotOut: MockAudioShutdown: SYSTEM CutExitCode%
    CASE "edit": DoEdit target
    CASE "editshot": DoEditShot target, shotT, shotOut: MockAudioShutdown: SYSTEM CutExitCode%
    CASE ELSE: DoPlay target
END SELECT

MockAudioShutdown
SYSTEM 0

' ============================================================================
'  Fatal-error handler.
'  No window up  -> print something greppable and exit non-zero, so a script
'                   can act on it instead of blocking on a dialog.
'  Window up     -> a human is watching; one missing optional asset should not
'                   end their scene. Capped, so an error inside the frame loop
'                   still aborts rather than scrolling forever.
' ============================================================================
CutplayFatal:
IF SCREEN_SHOWN = 0 THEN
    _DEST _CONSOLE
    PRINT "!! QB64 RUNTIME ERROR" + STR$(ERR) + " at line" + STR$(_ERRORLINE)
    PRINT "   " + _ERRORMESSAGE$(ERR)
    SYSTEM 1
END IF
ERR_COUNT = ERR_COUNT + 1
IF ERR_COUNT > ERR_MAX THEN
    _DEST _CONSOLE
    PRINT "!! QB64 RUNTIME ERROR" + STR$(ERR) + " at line" + STR$(_ERRORLINE) + " (repeated; aborting)"
    SYSTEM 1
END IF
RESUME NEXT

' ============================================================================
'  Modes
' ============================================================================

'--- exit code carries the verdict: 0 clean, 1 errors. A lint you have to READ
'    to know the answer is a lint that never gets wired into a gate. ---
FUNCTION CutExitCode% ()
    IF CUT_NFATAL > 0 THEN CutExitCode% = 1 ELSE CutExitCode% = 0
END FUNCTION

SUB DoLint (target AS STRING)
    DIM scn(0 TO 255) AS STRING, n AS INTEGER, i AS INTEGER
    DIM tot AS INTEGER, bad AS INTEGER, warn AS INTEGER, ok AS INTEGER

    _DEST _CONSOLE

    IF LCASE$(target) = "all" _ORELSE LEN(target) = 0 THEN
        CutFindScenes scn(), n
    ELSE
        n = 1
        scn(1) = target
    END IF

    IF n = 0 THEN
        PRINT "no .cut scn found under " + CUT_ASSETROOT + "cutscenes/"
        EXIT SUB
    END IF

    FOR i = 1 TO n
        ok = CutCompile%(scn(i))
        '--- Compiling proves the SCRIPT is well formed. It says nothing about
        '    whether the art and audio it names are on disk -- and a scene
        '    whose backdrop is missing still compiles, still plays, and just
        '    shows the wrong thing. Walk the ops and resolve every asset. ---
        CutLintAssets
        tot = tot + 1
        PRINT scn(i); " -- "; LTRIM$(STR$(CUT_NOP)); " ops, "; LTRIM$(STR$(CUT_NLBL)); " labels";
        IF CUT_NERR = 0 THEN
            PRINT "  [OK]"
        ELSE
            PRINT
            CutPrintDiags
        END IF
        IF CUT_NFATAL > 0 THEN bad = bad + 1
        warn = warn + (CUT_NERR - CUT_NFATAL)
    NEXT i

    PRINT
    PRINT LTRIM$(STR$(tot)); " scene(s), "; LTRIM$(STR$(bad)); " with errors, "; LTRIM$(STR$(warn)); " warning(s)"

    '--- CUT_NFATAL is per-compile, so the LAST file would otherwise decide the
    '    exit code for the whole run. ---
    IF bad > 0 THEN CUT_NFATAL = bad ELSE CUT_NFATAL = 0
END SUB

'--- Resolve every asset a compiled scene names, WITHOUT playing it.
'
'  Art is loaded lazily at the moment an op executes, so a missing backdrop on
'  a branch nobody took during testing stays invisible until a player takes
'  that branch. Here every op is checked, both arms of every conditional
'  included, because the check walks the PROGRAM and not an execution.
'
'  Missing audio is a WARNING, not an error: a silent effect is a legitimate
'  state (the game falls back to a beeper tone, and packs ship partial sets).
'  Missing ART is an error -- there is no sensible fallback for a picture.
SUB CutLintAssets
    DIM i AS INTEGER, f AS INTEGER, pth AS STRING, nm AS STRING
    DIM nframes AS INTEGER, missing AS INTEGER, firstmiss AS STRING

    FOR i = 1 TO CUT_NOP
        SELECT CASE CUT_OPS(i).cmd

            CASE OP_SHOW
                pth = CutStrGet$(CUT_OPS(i).s2)
                IF LEN(pth) > 0 THEN
                    IF LEN(Game_CutArtPath$(pth)) = 0 THEN
                        CutErrAdd 2, CUT_OPS(i).srcline, "art not found: " + pth
                    END IF
                END IF

            CASE OP_TRANS
                '--- a transition's `to "<path>"` is stored as layer|path ---
                pth = CutStrGet$(CUT_OPS(i).s3)
                f = INSTR(pth, "|")
                IF f > 0 THEN
                    pth = MID$(pth, f + 1)
                    IF LEN(Game_CutArtPath$(pth)) = 0 THEN
                        CutErrAdd 2, CUT_OPS(i).srcline, "art not found: " + pth
                    END IF
                END IF

            CASE OP_PORTRAIT
                pth = CutStrGet$(CUT_OPS(i).s1)
                IF LEN(pth) > 0 THEN
                    IF LEN(Game_CutArtPath$(pth)) = 0 THEN
                        CutErrAdd 2, CUT_OPS(i).srcline, "portrait not found: " + pth
                    END IF
                END IF

            CASE OP_ANIM
                '--- EVERY frame, not just the first. A sequence that is one
                '    frame short plays fine until it reaches the end, and then
                '    shows a MISSING box mid-animation. ---
                nm = CutStrGet$(CUT_OPS(i).s2)
                nframes = CINT(CUT_OPS(i).n1)
                missing = 0
                firstmiss = ""
                FOR f = 1 TO nframes
                    pth = CutFramePath$(nm, f)
                    IF LEN(Game_CutArtPath$(pth)) = 0 THEN
                        missing = missing + 1
                        IF LEN(firstmiss) = 0 THEN firstmiss = pth
                    END IF
                NEXT f
                IF missing > 0 THEN
                    CutErrAdd 2, CUT_OPS(i).srcline, "anim " + nm + ": " + LTRIM$(STR$(missing)) + " of" + STR$(nframes) + " frames not found (first: " + firstmiss + ")"
                END IF

            CASE OP_MUSIC, OP_CUE
                nm = CutStrGet$(CUT_OPS(i).s1)
                IF LEN(nm) > 0 THEN
                    IF LEN(Game_CutAudioPath$("music", nm)) = 0 THEN
                        CutErrAdd 1, CUT_OPS(i).srcline, "no music named '" + nm + "' (scene will play silent)"
                    END IF
                END IF

            CASE OP_SFX
                nm = CutStrGet$(CUT_OPS(i).s1)
                IF LEN(nm) > 0 THEN
                    IF LEN(Game_CutAudioPath$("sfx", nm)) = 0 THEN
                        CutErrAdd 1, CUT_OPS(i).srcline, "no sfx named '" + nm + "'"
                    END IF
                END IF

            CASE OP_NARRATE
                nm = CutStrGet$(CUT_OPS(i).s1)
                IF LEN(nm) > 0 THEN
                    IF LEN(Game_CutAudioPath$("narration", nm)) = 0 THEN
                        CutErrAdd 1, CUT_OPS(i).srcline, "no narration for key '" + nm + "'"
                    END IF
                END IF

        END SELECT
    NEXT i
END SUB

SUB CutPrintDiags
    DIM i AS INTEGER, tag AS STRING
    FOR i = 1 TO CUT_NERR
        IF CUT_ERRSEV(i) = 2 THEN tag = "  ERROR" ELSE tag = "  warn "
        IF CUT_ERRLINE(i) > 0 THEN
            PRINT tag; " line"; CUT_ERRLINE(i); ": "; CUT_ERR(i)
        ELSE
            PRINT tag; "      : "; CUT_ERR(i)
        END IF
    NEXT i
END SUB

'--- enumerate every pack's scenes. Two passes over _FILES$ because the
'    directory walk cannot be re-entered while it is being consumed. ---
SUB CutFindScenes (scn() AS STRING, n AS INTEGER)
    DIM packs(0 TO 63) AS STRING, np AS INTEGER, i AS INTEGER
    DIM root AS STRING, d AS STRING, f AS STRING

    root = CUT_ASSETROOT + "cutscenes/"
    n = 0
    IF NOT _DIREXISTS(root) THEN EXIT SUB

    d = _FILES$(root)
    DO WHILE LEN(d) > 0
        IF d <> "." THEN
            IF d <> ".." THEN
                IF _DIREXISTS(root + d) THEN
                    '--- _FILES$ hands back directories WITH a trailing
                    '    slash, so joining one on produces `default//x.cut`.
                    '    Harmless to open, but it is the path printed in every
                    '    diagnostic, and a doubled slash reads as a bug in the
                    '    scene rather than in the lister. ---
                    IF RIGHT$(d, 1) = "/" THEN d = LEFT$(d, LEN(d) - 1)
                    IF np < 63 THEN np = np + 1: packs(np) = d
                END IF
            END IF
        END IF
        d = _FILES$
    LOOP

    FOR i = 1 TO np
        f = _FILES$(root + packs(i) + "/*.cut")
        DO WHILE LEN(f) > 0
            '--- skip `_`-prefixed fragments: they are `include` targets and do
            '    not stand alone, so linting them as scenes reports errors that
            '    are not errors. ---
            IF LEFT$(f, 1) = "_" THEN f = _FILES$: _CONTINUE
            IF n < 255 THEN
                n = n + 1
                scn(n) = root + packs(i) + "/" + f
            END IF
            f = _FILES$
        LOOP
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Play, with hot reload
' ----------------------------------------------------------------------------
'--- The key list, printed where it cannot be missed. Which keys reach the
'    ENGINE and which are this tool's own is the part worth stating: the
'    authoring keys do not exist in the game, and someone who learns them here
'    would otherwise expect them there. ---
SUB PrintCutKeys
    DIM d AS LONG
    d = _DEST
    _DEST _CONSOLE
    PRINT "keys -- these three also work IN THE GAME (they are the engine's):"
    PRINT "  SPACE/ENTER  advance (1st press dumps the line, 2nd moves on)"
    PRINT "  ESC          skip the scene (unless it declared `noskip`)"
    PRINT "  1-4 W/S      pick a choice"
    PRINT
    PRINT "authoring keys -- cutplay.run ONLY, not in the game:"
    PRINT "  R            recompile from disk and restart"
    PRINT "  P            pause          L   loop"
    PRINT "  ->           jump 1s ahead  S   screenshot -> cutscene-shot.png"
    _DEST d
END SUB

SUB DoPlay (target AS STRING)
    DIM r AS INTEGER, k AS STRING, kk AS STRING
    DIM running AS INTEGER

    IF CutStart%(target) = 0 THEN
        CutShowDiagsOnScreen
        DO
            k = INKEY$
            IF k = CHR$(27) THEN EXIT SUB
            IF LCASE$(k) = "r" THEN
                IF CutStart%(target) THEN EXIT DO
                CutShowDiagsOnScreen
            END IF
            _LIMIT 30
        LOOP
    END IF

    PrintCutKeys

    running = TRUE
    DO
        r = CutTick%
        CutDrawOverlay
        _DISPLAY

        DO
            k = INKEY$
            IF LEN(k) = 0 THEN EXIT DO
            kk = LCASE$(k)

            SELECT CASE kk
                CASE "r"
                    '--- HOT RELOAD: recompile from disk and start over. The
                    '    whole point of compiling at load rather than
                    '    interpreting text is that this is honest -- what you
                    '    watch is what the parser actually produced. ---
                    IF CutStart%(target) = 0 THEN CutShowDiagsOnScreen
                    _CONTINUE
                CASE "p"
                    CutTogglePause
                    _CONTINUE
                CASE "l"
                    PLAY_LOOP = NOT PLAY_LOOP
                    _CONTINUE
                CASE "s"
                    CutSaveShot "cutscene-shot.png"
                    _CONTINUE
            END SELECT

            '--- right arrow: jump a second ahead. Shifting every time origin
            '    BACKWARDS is the same mechanism the pause uses forwards, so
            '    there is no separate seek path to get wrong. ---
            IF k = CHR$(0) + "M" THEN
                CUT_MODE = CUT_AUTO
                CutShiftClocks -1#
                _CONTINUE
            END IF

            '--- ESC ALWAYS ends the scene HERE, even one marked `noskip`.
            '    That flag is a promise to the player that a beat will land; it
            '    has no business trapping the author inside a 40-second scene
            '    they are trying to iterate on. The engine still honours it --
            '    this is the tool overriding, not the rule changing. ---
            IF k = CHR$(27) THEN
                CutSkip
                _CONTINUE
            END IF

            CutKeyFeed k
        LOOP

        IF r <> CUT_RUNNING THEN
            IF PLAY_LOOP THEN
                r = CutStart%(target)
            ELSE
                EXIT DO
            END IF
        END IF

        _LIMIT 60
    LOOP

    CutShowEnd r
END SUB

'--- compile + begin. Returns FALSE when the scene will not run. ---
FUNCTION CutStart% (target AS STRING)
    DIM okc AS INTEGER
    CutEnd
    okc = CutCompile%(target)
    IF okc = 0 THEN CutStart% = FALSE: EXIT FUNCTION
    CutBegin
    CutStart% = TRUE
END FUNCTION

SUB CutShowDiagsOnScreen
    DIM i AS INTEGER, r AS INTEGER
    CLS , _RGB32(20, 0, 0)
    CutTextAt 2, 1, "CANNOT PLAY  " + CUT_FILE, _RGB32(255, 120, 120)
    r = 3
    FOR i = 1 TO CUT_NERR
        IF r > CUT_SH - 3 THEN EXIT FOR
        IF CUT_ERRSEV(i) = 2 THEN
            CutTextAt 2, r, "ERROR line" + STR$(CUT_ERRLINE(i)) + ": " + CUT_ERR(i), _RGB32(255, 160, 160)
        ELSE
            CutTextAt 2, r, "warn  line" + STR$(CUT_ERRLINE(i)) + ": " + CUT_ERR(i), _RGB32(220, 200, 120)
        END IF
        r = r + 1
    NEXT i
    CutTextAt 2, CUT_SH - 2, "[R] reload from disk    [ESC] quit", _RGB32(160, 160, 170)
    _DISPLAY
END SUB

SUB CutShowEnd (r AS INTEGER)
    DIM s AS STRING
    SELECT CASE r
        CASE CUT_DONE: s = "scene complete"
        CASE CUT_SKIPPED: s = "skipped"
        CASE CUT_ERROR: s = "SCENE ERROR"
        CASE ELSE: s = "stopped"
    END SELECT
    CutTextAt 2, CUT_SH - 2, s, _RGB32(200, 200, 210)
    _DISPLAY
END SUB

'--- the authoring HUD. Deliberately shows resolved paths and the live op
'    index: "which line am I looking at" is the question an author actually
'    has, and guessing it from the picture is what makes scripting painful. ---
SUB CutDrawOverlay
    DIM s AS STRING, srcln AS INTEGER
    IF CUT_PC >= 1 THEN
        IF CUT_PC <= CUT_NOP THEN srcln = CUT_OPS(CUT_PC).srcline
    END IF

    s = "op " + LTRIM$(STR$(CUT_PC)) + "/" + LTRIM$(STR$(CUT_NOP))
    s = s + "  line " + LTRIM$(STR$(srcln))
    s = s + "  t " + LEFT$(LTRIM$(STR$(CUT_NOW - CUT_T0)), 4)
    s = s + "  cam " + LEFT$(LTRIM$(STR$(CUT_CAMX)), 4) + "," + LEFT$(LTRIM$(STR$(CUT_CAMY)), 4)
    s = s + " z" + LEFT$(LTRIM$(STR$(CUT_CAMZ)), 4)
    IF CUT_PAUSED THEN s = s + "  [PAUSED]"
    IF PLAY_LOOP THEN s = s + "  [LOOP]"
    IF CUT_MISSING > 0 THEN s = s + "  MISSING:" + STR$(CUT_MISSING)

    LINE (0, 0)-(CUT_PXW - 1, CUT_CH - 1), _RGBA32(0, 0, 0, 170), BF
    CutTextAt 1, 0, s, _RGB32(150, 200, 150)
END SUB

SUB CutSaveShot (path AS STRING)
    _SAVEIMAGE path, _DEST
END SUB

' ----------------------------------------------------------------------------
'  Shot: run the scene headlessly to time T, then save the frame.
'
'  Ticked at a FIXED 60 steps per simulated second rather than in real time --
'  a screenshot has to land on the same frame every run or it is useless as a
'  regression check.
' ----------------------------------------------------------------------------
SUB DoShot (target AS STRING, atT AS SINGLE, outp AS STRING)
    DIM r AS INTEGER, i AS INTEGER, steps AS LONG, dt AS DOUBLE
    DIM o AS STRING, scr AS LONG

    o = outp
    IF LEN(o) = 0 THEN o = "cutscene-shot.png"

    '--- HOLD ON TO THE SCREEN. Printing a status line means _DEST _CONSOLE,
    '    and leaving it there points the whole renderer at the console: every
    '    _PUTIMAGE then fails with "illegal function call" and the title card's
    '    dashes come out in the terminal. Console printing has to be bracketed,
    '    never left switched on. ---
    scr = _DEST

    IF CutStart%(target) = 0 THEN
        _DEST _CONSOLE
        PRINT "cannot compile " + target
        CutPrintDiags
        _DEST scr
        EXIT SUB
    END IF

    '--- DRIVE the clock rather than nudging it. Shifting every tween origin
    '    back by dt each frame looked equivalent, but real time kept advancing
    '    underneath, so the scene aged by (dt + however long that frame took to
    '    render). A 20-second pan finished by a requested t of about 14, and a
    '    "fixed simulated time" screenshot was nothing of the sort. ---
    CUT_CLKFIXED = TRUE
    CUT_NOW = 0
    CutBegin
    CUT_NOW = 0
    CUT_T0 = 0
    CUT_LASTFRAME = 0

    dt = 1# / 60#
    steps = atT / dt
    IF steps < 1 THEN steps = 1
    IF steps > 60000 THEN steps = 60000

    FOR i = 1 TO steps
        CUT_NOW = CUT_NOW + dt          ' one frame of simulated time, exactly
        r = CutTick%
        IF r <> CUT_RUNNING THEN EXIT FOR
    NEXT i

    CUT_CLKFIXED = FALSE

    _SAVEIMAGE o, scr

    _DEST _CONSOLE
    PRINT "wrote " + o + "  (op " + LTRIM$(STR$(CUT_PC)) + "/" + LTRIM$(STR$(CUT_NOP)) + ", missing assets:" + STR$(CUT_MISSING) + ")"
    IF LEN(MOCK_LOG) > 0 THEN
        PRINT "-- scene did --"
        PRINT MOCK_LOG;
    END IF
    _DEST scr
END SUB

' ============================================================================
'  Bodies. Order is irrelevant -- QB64 resolves procedures globally and no
'  body file declares anything at file scope. Assembling a program is these
'  few lines plus the two headers at the top.
' ============================================================================
'$INCLUDE:'../CUTSCENE_PARSE.bas'
'$INCLUDE:'../CUTSCENE_COMP.bas'
'$INCLUDE:'../CUTSCENE_VM.bas'
'$INCLUDE:'../CUTSCENE_ZIP.bas'
'$INCLUDE:'../CUTSCENE_EXEC.bas'
'$INCLUDE:'../CUTSCENE_DRAW.bas'
'$INCLUDE:'../CUTSCENE_GIF.bas'
'$INCLUDE:'CUTMOCK.bas'
'$INCLUDE:'CUTEDIT.bas'
'$INCLUDE:'CUTTEST.bas'
'$INCLUDE:'../ansi/ANSIPrint.bas'
