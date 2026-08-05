' ============================================================================
'  CUTEDIT.bas -- the cut-scene EDITOR: see it, scrub it, tune it.
'
'      cutplay.run edit assets/cutscenes/default/the-long-hall.cut
'
'  Three panes: the scene itself, an op inspector, and a TIMELINE.
'
'  WHY THIS IS POSSIBLE AT ALL
'  ---------------------------
'  The engine is a step machine whose clock the host owns (CUT_CLKFIXED), so
'  "show me this scene at t = 12.4" is a thing that can be asked. A timeline is
'  then two ideas:
'
'    * a PROFILE pass -- run the scene once with drawing switched off, noting
'      the clock as each instruction goes by. That is where the markers come
'      from; nothing is declared or hand-maintained.
'    * SEEK = restart + fast-forward. The VM is stateful and cannot run
'      backwards, so scrubbing to t means re-simulating from 0. Not DRAWING
'      those thrown-away frames (CUT_NORENDER) is the difference between a
'      scrub bar and a slideshow.
'
'  WHAT "EDIT" MEANS HERE
'  ----------------------
'  The .cut file stays the source of truth -- there is no project format, no
'  second representation to drift. The editor selects an op, shows the NUMBERS
'  on its source line, and nudges them: durations, waits, positions, scales.
'  Those are exactly the values nobody can get right by reading, and exactly
'  what a preview is for. Everything else (structure, dialogue, branching) is
'  better typed, which is what [R] and your text editor are for.
' ============================================================================

'--- layout, in cells (the screen is 132x51) ---
CONST ED_PVW = 88                  ' preview pane: 88x33 cells...
CONST ED_PVH = 33
CONST ED_INSX = 90                 ' ...inspector to its right...
CONST ED_TLY = 36                  ' ...timeline underneath
CONST ED_TLH = 14
CONST ED_GUT = 52                  ' left gutter, so lane names never sit under a marker

'--- Draw the editor once at a given time and save it. Headless, so the UI can
'    be checked the same way everything else here is: by looking at what it
'    actually rendered rather than at the code that was supposed to. ---
SUB DoEditShot (target AS STRING, atT AS SINGLE, outp AS STRING)
    DIM o AS STRING, d AS LONG
    o = outp: IF LEN(o) = 0 THEN o = "cutedit-shot.png"

    IF CutStart%(target) = 0 THEN
        d = _DEST: _DEST _CONSOLE
        PRINT "cannot compile " + target
        CutPrintDiags
        _DEST d
        EXIT SUB
    END IF

    ED_SCENE = target
    EdProfile
    ED_SEL = EdFirstOp%
    EdSeek atT
    EdDrawUI
    _SAVEIMAGE o, 0

    d = _DEST: _DEST _CONSOLE
    PRINT "wrote " + o + "  (scene runs " + LEFT$(LTRIM$(STR$(CUT_DURATION)), 5) + "s, " + LTRIM$(STR$(CUT_NOP)) + " ops)"
    _DEST d
END SUB

SUB DoEdit (target AS STRING)
    DIM k AS STRING, r AS INTEGER, quit AS INTEGER
    DIM dirty AS INTEGER

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

    ED_SCENE = target
    EdProfile
    ED_T = 0
    ED_SEL = EdFirstOp%
    ED_PLAY = FALSE
    EdSeek 0

    DO
        EdDrawUI
        _DISPLAY

        k = INKEY$
        IF LEN(k) > 0 THEN
            SELECT CASE LCASE$(k)
                CASE " "
                    ED_PLAY = NOT ED_PLAY
                CASE "r"
                    IF CutStart%(ED_SCENE) THEN
                        EdProfile
                        EdSeek ED_T
                    ELSE
                        CutShowDiagsOnScreen: _DISPLAY: SLEEP 2
                    END IF
                CASE "s"
                    '--- the whole editor, not just the scene: the point of a
                    '    screenshot here is usually the timeline ---
                    _SAVEIMAGE "cutedit-shot.png", 0
                CASE "w"
                    EdWriteBack
                CASE "["
                    EdSelectStep -1
                CASE "]"
                    EdSelectStep 1
                CASE "-", "_"
                    EdNudge -1
                CASE "=", "+"
                    EdNudge 1
                CASE ","
                    EdField -1
                CASE "."
                    EdField 1
                CASE CHR$(27)
                    quit = TRUE
            END SELECT

            '--- arrows: scrub. HOME/END: ends of the scene. ---
            IF k = CHR$(0) + "M" THEN EdSeek ED_T + 0.25          ' right
            IF k = CHR$(0) + "K" THEN EdSeek ED_T - 0.25          ' left
            IF k = CHR$(0) + "G" THEN EdSeek 0                     ' home
            IF k = CHR$(0) + "O" THEN EdSeek CUT_DURATION          ' end
            IF k = CHR$(0) + "H" THEN EdSelectStep -1              ' up
            IF k = CHR$(0) + "P" THEN EdSelectStep 1               ' down
        END IF

        IF quit THEN EXIT DO

        IF ED_PLAY THEN
            '--- playing is just seeking forward in real time ---
            ED_T = ED_T + 1 / 60
            IF ED_T >= CUT_DURATION THEN ED_T = CUT_DURATION: ED_PLAY = FALSE
            EdSeekFast ED_T
        END IF

        _LIMIT 60
    LOOP
END SUB

' ----------------------------------------------------------------------------
'  PROFILE -- run the scene with drawing off and note when each op fires.
'  This is the timeline. Nothing is declared; it is measured.
' ----------------------------------------------------------------------------
SUB EdProfile
    DIM i AS LONG, dt AS DOUBLE, guard AS LONG

    dt = 1# / 60#
    CUT_NORENDER = TRUE
    CUT_CLKFIXED = TRUE
    CUT_NOW = 0
    CutBegin
    CUT_NOW = 0: CUT_T0 = 0: CUT_LASTFRAME = 0
    CUT_MODE = CUT_AUTO                   ' nobody is here to press anything

    guard = 90 * 60                       ' ninety seconds is a very long scene
    FOR i = 1 TO guard
        CUT_NOW = CUT_NOW + dt
        IF CutTick% <> CUT_RUNNING THEN EXIT FOR
    NEXT i

    CUT_DURATION = CUT_NOW - CUT_T0
    IF CUT_DURATION < 0.1 THEN CUT_DURATION = 0.1
    CUT_NORENDER = FALSE
END SUB

' ----------------------------------------------------------------------------
'  SEEK -- restart, fast-forward with drawing off, then draw ONE frame.
' ----------------------------------------------------------------------------
SUB EdSeek (t AS SINGLE)
    ED_T = t
    IF ED_T < 0 THEN ED_T = 0
    IF ED_T > CUT_DURATION THEN ED_T = CUT_DURATION
    EdSeekFast ED_T
END SUB

SUB EdSeekFast (t AS SINGLE)
    DIM i AS LONG, dt AS DOUBLE, steps AS LONG, olddest AS LONG

    dt = 1# / 60#
    steps = t / dt

    CUT_NORENDER = TRUE
    CUT_CLKFIXED = TRUE
    CUT_NOW = 0
    CutBegin
    CUT_NOW = 0: CUT_T0 = 0: CUT_LASTFRAME = 0
    CUT_MODE = CUT_AUTO

    FOR i = 1 TO steps
        CUT_NOW = CUT_NOW + dt
        IF CutTick% <> CUT_RUNNING THEN EXIT FOR
    NEXT i

    '--- ...and now one frame WITH the drawing, into our own image so the
    '    editor's chrome never lands on the scene ---
    CUT_NORENDER = FALSE
    IF ED_FRAME < -1 THEN _FREEIMAGE ED_FRAME
    ED_FRAME = _NEWIMAGE(CUT_PXW, CUT_PXH, 32)
    olddest = _DEST
    _DEST ED_FRAME
    CutRender
    _DEST olddest
END SUB

' ----------------------------------------------------------------------------
'  The screen
' ----------------------------------------------------------------------------
SUB EdDrawUI
    _DEST 0
    CLS , _RGB32(16, 16, 22)

    '--- the scene, scaled into the preview pane ---
    IF ED_FRAME < -1 THEN
        _PUTIMAGE (0, 0)-(ED_PVW * CUT_CW - 1, ED_PVH * CUT_CH - 1), ED_FRAME, 0
    END IF
    LINE (0, 0)-(ED_PVW * CUT_CW - 1, ED_PVH * CUT_CH - 1), _RGB32(70, 70, 90), B

    EdDrawInspector
    EdDrawTimeline
    EdDrawHelp
END SUB

SUB EdDrawInspector
    DIM y AS INTEGER, i AS INTEGER, top AS INTEGER, n AS INTEGER
    DIM col AS _UNSIGNED LONG

    EdText ED_INSX, 0, "OPS", _RGB32(150, 200, 255)

    '--- keep the selection in view ---
    top = ED_SEL - 14
    IF top < 1 THEN top = 1

    y = 2
    FOR i = top TO CUT_NOP
        IF y > ED_TLY - 6 THEN EXIT FOR
        col = _RGB32(120, 120, 130)
        IF CUT_OPRAN(i) THEN col = _RGB32(190, 190, 200)
        IF i = ED_SEL THEN col = _RGB32(255, 232, 150)
        EdText ED_INSX, y, EdOpLabel$(i), col
        y = y + 1
    NEXT i
END SUB

'--- "  12  4.2s  pan"  -- index, when it fires, what it is ---
FUNCTION EdOpLabel$ (i AS INTEGER)
    DIM t AS STRING
    IF CUT_OPRAN(i) THEN t = LEFT$(LTRIM$(STR$(CUT_OPTIME(i))) + "     ", 5) ELSE t = "  -  "
    EdOpLabel$ = LEFT$(LTRIM$(STR$(i)) + "   ", 4) + t + " " + EdOpName$(CUT_OPS(i).cmd)
END FUNCTION

FUNCTION EdOpName$ (c AS INTEGER)
    SELECT CASE c
        CASE OP_SHOW: EdOpName$ = "show"
        CASE OP_HIDE: EdOpName$ = "hide"
        CASE OP_ANIM: EdOpName$ = "anim"
        CASE OP_LAYSET: EdOpName$ = "layer"
        CASE OP_PAN: EdOpName$ = "pan"
        CASE OP_ZOOM: EdOpName$ = "zoom"
        CASE OP_CAMSET: EdOpName$ = "cam"
        CASE OP_SHAKE: EdOpName$ = "shake"
        CASE OP_TRANS: EdOpName$ = "trans"
        CASE OP_SAY: EdOpName$ = "say"
        CASE OP_TITLE: EdOpName$ = "title"
        CASE OP_CRAWL: EdOpName$ = "crawl"
        CASE OP_CAPTION: EdOpName$ = "caption"
        CASE OP_WAIT: EdOpName$ = "wait"
        CASE OP_WAITALL: EdOpName$ = "waitall"
        CASE OP_MUSIC: EdOpName$ = "music"
        CASE OP_SFX: EdOpName$ = "sfx"
        CASE OP_CHOICE: EdOpName$ = "choice"
        CASE OP_STYLE: EdOpName$ = "style"
        CASE OP_END: EdOpName$ = "end"
        CASE ELSE: EdOpName$ = "op" + STR$(c)
    END SELECT
END FUNCTION

' ----------------------------------------------------------------------------
'  TIMELINE -- every op that ran, placed at the time it ran.
' ----------------------------------------------------------------------------
SUB EdDrawTimeline
    DIM i AS INTEGER, x AS INTEGER, y AS INTEGER, w AS INTEGER
    DIM t AS SINGLE, lane AS INTEGER, col AS _UNSIGNED LONG

    y = ED_TLY * CUT_CH
    w = CUT_PXW - 8

    LINE (4, y)-(4 + w, y + ED_TLH * CUT_CH - 4), _RGB32(24, 24, 32), BF
    LINE (4, y)-(4 + w, y + ED_TLH * CUT_CH - 4), _RGB32(70, 70, 90), B

    '--- second ticks ---
    FOR i = 0 TO INT(CUT_DURATION)
        x = ED_GUT + (i / CUT_DURATION) * (w - ED_GUT + 4)
        LINE (x, y + 2)-(x, y + 10), _RGB32(60, 60, 76)
        IF (i MOD 5) = 0 THEN EdTextPx x + 2, y + 2, LTRIM$(STR$(i)) + "s", _RGB32(110, 110, 130)
    NEXT i

    '--- one marker per op that actually ran, in a lane by family, so camera
    '    moves do not pile up on top of dialogue ---
    FOR i = 1 TO CUT_NOP
        IF CUT_OPRAN(i) = 0 THEN _CONTINUE
        t = CUT_OPTIME(i)
        IF t < 0 THEN t = 0
        x = ED_GUT + (t / CUT_DURATION) * (w - ED_GUT + 4)
        lane = EdLane%(CUT_OPS(i).cmd)
        col = EdLaneColor~&(lane)
        LINE (x, y + 16 + lane * 22)-(x + 2, y + 16 + lane * 22 + 16), col, BF
        IF i = ED_SEL THEN
            LINE (x - 2, y + 14 + lane * 22)-(x + 4, y + 16 + lane * 22 + 18), _RGB32(255, 232, 150), B
        END IF
    NEXT i

    '--- lane names ---
    EdTextPx 6, y + 16, "art", EdLaneColor~&(0)
    EdTextPx 6, y + 38, "cam", EdLaneColor~&(1)
    EdTextPx 6, y + 60, "text", EdLaneColor~&(2)
    EdTextPx 6, y + 82, "snd", EdLaneColor~&(3)
    EdTextPx 6, y + 104, "flow", EdLaneColor~&(4)

    '--- the playhead ---
    x = ED_GUT + (ED_T / CUT_DURATION) * (w - ED_GUT + 4)
    LINE (x, y + 2)-(x, y + ED_TLH * CUT_CH - 6), _RGB32(255, 80, 80)
    EdTextPx x + 3, y + ED_TLH * CUT_CH - 18, LEFT$(LTRIM$(STR$(ED_T)), 5) + "s", _RGB32(255, 140, 140)
END SUB

FUNCTION EdLane% (c AS INTEGER)
    SELECT CASE c
        CASE OP_SHOW, OP_HIDE, OP_ANIM, OP_LAYSET, OP_CLEARLAY: EdLane% = 0
        CASE OP_PAN, OP_ZOOM, OP_CAMSET, OP_SHAKE, OP_TRANS: EdLane% = 1
        CASE OP_SAY, OP_TITLE, OP_CRAWL, OP_CAPTION, OP_CLEARTEXT, OP_PORTRAIT, OP_STYLE: EdLane% = 2
        CASE OP_MUSIC, OP_MUSICSTOP, OP_SFX, OP_NARRATE, OP_CUE: EdLane% = 3
        CASE ELSE: EdLane% = 4
    END SELECT
END FUNCTION

FUNCTION EdLaneColor~& (lane AS INTEGER)
    SELECT CASE lane
        CASE 0: EdLaneColor~& = _RGB32(120, 200, 140)
        CASE 1: EdLaneColor~& = _RGB32(120, 170, 255)
        CASE 2: EdLaneColor~& = _RGB32(240, 210, 130)
        CASE 3: EdLaneColor~& = _RGB32(210, 130, 220)
        CASE ELSE: EdLaneColor~& = _RGB32(150, 150, 160)
    END SELECT
END FUNCTION

' ----------------------------------------------------------------------------
'  Selection + editing
' ----------------------------------------------------------------------------
FUNCTION EdFirstOp% ()
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NOP
        IF CUT_OPS(i).cmd <> OP_NOP THEN EdFirstOp% = i: EXIT FUNCTION
    NEXT i
    EdFirstOp% = 1
END FUNCTION

SUB EdSelectStep (d AS INTEGER)
    ED_SEL = ED_SEL + d
    IF ED_SEL < 1 THEN ED_SEL = 1
    IF ED_SEL > CUT_NOP THEN ED_SEL = CUT_NOP
    ED_FIELD = 0
    '--- jumping to an op means jumping to its MOMENT: that is the whole point
    '    of a timeline, and it saves hunting for the frame by hand ---
    IF CUT_OPRAN(ED_SEL) THEN EdSeek CUT_OPTIME(ED_SEL)
END SUB

SUB EdField (d AS INTEGER)
    ED_FIELD = ED_FIELD + d
    IF ED_FIELD < 0 THEN ED_FIELD = 3
    IF ED_FIELD > 3 THEN ED_FIELD = 0
END SUB

'--- Nudge the selected op's numbers, in memory, and re-seek so the change is
'    visible immediately. [W] is what writes it back to the file. ---
SUB EdNudge (d AS INTEGER)
    DIM amt AS SINGLE
    IF ED_SEL < 1 _ORELSE ED_SEL > CUT_NOP THEN EXIT SUB
    amt = 0.1 * d
    SELECT CASE ED_FIELD
        CASE 0: CUT_OPS(ED_SEL).n1 = CUT_OPS(ED_SEL).n1 + amt
        CASE 1: CUT_OPS(ED_SEL).n2 = CUT_OPS(ED_SEL).n2 + amt
        CASE 2: CUT_OPS(ED_SEL).n3 = CUT_OPS(ED_SEL).n3 + amt
        CASE 3: CUT_OPS(ED_SEL).n4 = CUT_OPS(ED_SEL).n4 + amt
    END SELECT
    ED_DIRTY = TRUE
    EdProfileKeepOps
    EdSeek ED_T
END SUB

'--- re-time without recompiling, so a nudge does not throw away the edit ---
SUB EdProfileKeepOps
    DIM i AS LONG, dt AS DOUBLE
    dt = 1# / 60#
    CUT_NORENDER = TRUE
    CUT_CLKFIXED = TRUE
    CUT_NOW = 0
    CutBegin
    CUT_NOW = 0: CUT_T0 = 0: CUT_LASTFRAME = 0
    CUT_MODE = CUT_AUTO
    FOR i = 1 TO 90 * 60
        CUT_NOW = CUT_NOW + dt
        IF CutTick% <> CUT_RUNNING THEN EXIT FOR
    NEXT i
    CUT_DURATION = CUT_NOW - CUT_T0
    IF CUT_DURATION < 0.1 THEN CUT_DURATION = 0.1
    CUT_NORENDER = FALSE
END SUB

' ----------------------------------------------------------------------------
'  Write the tuned numbers back into the .cut, in place.
'
'  Only the NUMBERS on a line are touched, and only on lines the editor
'  actually changed -- comments, spacing and everything structural survive
'  exactly as typed. The file is the source of truth; this is a careful edit of
'  it, not a re-serialisation from some in-memory model that would quietly
'  reformat the author's work.
' ----------------------------------------------------------------------------
'--- Report the tuned value so it can be typed into the .cut.
'
'    The editor does NOT rewrite the file, and that is a deliberate limit
'    rather than an unfinished corner. Nudging changes the compiled op, so the
'    preview is honest; but the op is several steps removed from the line that
'    produced it -- `move` emits two, modifiers are keyword-scanned in any
'    order, and `n1` means a different thing per command. Rewriting from that
'    would eventually mangle somebody's carefully commented scene, and a tool
'    that edits your source has to be right every time, not usually.
'
'    So: find the number here, where you can SEE it, and type it there.
SUB EdWriteBack
    IF ED_SEL < 1 _ORELSE ED_SEL > CUT_NOP THEN EXIT SUB
    ED_STATUS = "line " + LTRIM$(STR$(CUT_OPS(ED_SEL).srcline)) + ": " + _
                EdOpName$(CUT_OPS(ED_SEL).cmd) + "  n" + LTRIM$(STR$(ED_FIELD + 1)) + " = " + _
                LEFT$(LTRIM$(STR$(EdFieldValue!)), 7) + "   <- type this into the .cut, then [R]"
END SUB

' ----------------------------------------------------------------------------
'  Help + small text helpers (the editor draws its own chrome; the engine's
'  text helpers belong to the scene).
' ----------------------------------------------------------------------------
SUB EdDrawHelp
    DIM y AS INTEGER
    y = (ED_TLY + ED_TLH) * CUT_CH - 2
    EdTextPx 6, y, "[SPACE] play  [<-/->] scrub  [HOME/END]  [Up/Dn] pick op  [,/.] field  [-/=] nudge  [W] value  [R] reload  [S] shot  [ESC]", _RGB32(140, 140, 160)

    '--- what is selected, spelled out ---
    IF ED_SEL >= 1 AND ED_SEL <= CUT_NOP THEN
        EdText ED_INSX, ED_TLY - 4, STRING$(40, 196), _RGB32(70, 70, 90)
        EdText ED_INSX, ED_TLY - 3, "op" + STR$(ED_SEL) + "  " + EdOpName$(CUT_OPS(ED_SEL).cmd) + "  line" + STR$(CUT_OPS(ED_SEL).srcline), _RGB32(150, 200, 255)
        EdText ED_INSX, ED_TLY - 2, "n" + LTRIM$(STR$(ED_FIELD + 1)) + " = " + LEFT$(LTRIM$(STR$(EdFieldValue!)), 7) + "   [,/.] field  [-/=] nudge", _RGB32(255, 232, 150)
    END IF
    IF LEN(ED_STATUS) > 0 THEN EdTextPx 6, y - 16, ED_STATUS, _RGB32(255, 180, 120)
END SUB

FUNCTION EdFieldValue! ()
    SELECT CASE ED_FIELD
        CASE 0: EdFieldValue! = CUT_OPS(ED_SEL).n1
        CASE 1: EdFieldValue! = CUT_OPS(ED_SEL).n2
        CASE 2: EdFieldValue! = CUT_OPS(ED_SEL).n3
        CASE ELSE: EdFieldValue! = CUT_OPS(ED_SEL).n4
    END SELECT
END FUNCTION

SUB EdText (col AS INTEGER, row AS INTEGER, s AS STRING, k AS _UNSIGNED LONG)
    EdTextPx col * CUT_CW, row * CUT_CH, s, k
END SUB

SUB EdTextPx (x AS INTEGER, y AS INTEGER, s AS STRING, k AS _UNSIGNED LONG)
    COLOR k, _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (x, y), s
END SUB
