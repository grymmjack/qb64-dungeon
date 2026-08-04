' ============================================================================
'  CUTEXEC.bas -- op execution, the frame tick, and asset loading.
' ============================================================================

' ----------------------------------------------------------------------------
'  Clock.
'
'  TIMER RESETS AT MIDNIGHT. Every duration in this engine is a difference of
'  two TIMER samples, so a scene playing across midnight would see time jump
'  backwards by 86400 seconds: every tween would compute a hugely negative
'  progress, clamp to its start value and freeze there, and every `wait` would
'  never elapse. The scene would simply stop, forever, and only ever between
'  23:59:59 and 00:00:00 -- which is to say never during testing.
' ----------------------------------------------------------------------------
FUNCTION CutClock# ()
    DIM t AS DOUBLE
    t = TIMER(0.001)
    IF t < CUT_CLKLAST THEN CUT_CLKWRAP = CUT_CLKWRAP + 86400#
    CUT_CLKLAST = t
    CutClock# = t + CUT_CLKWRAP
END FUNCTION

' ----------------------------------------------------------------------------
'  Art loading
' ----------------------------------------------------------------------------
FUNCTION CutIsAnsi% (path AS STRING)
    DIM s AS STRING
    s = LCASE$(path)
    IF RIGHT$(s, 4) = ".ans" THEN CutIsAnsi% = TRUE: EXIT FUNCTION
    IF RIGHT$(s, 4) = ".icy" THEN CutIsAnsi% = TRUE: EXIT FUNCTION
    IF RIGHT$(s, 3) = ".xb" THEN CutIsAnsi% = TRUE: EXIT FUNCTION
    CutIsAnsi% = FALSE
END FUNCTION

'--- render an .ans to a 32-bit image ONCE. From here on the camera treats it
'    exactly like a bitmap, which is the whole hybrid-layer trick: authored in
'    ANSI, moved in pixels. Black is keyed out so an ANSI layer composites
'    over what is below rather than boxing it out -- the same _CLEARCOLOR
'    BLACK rule BuildBoardImages uses for the board's decoration layer. ---
FUNCTION CutRenderAnsi& (path AS STRING)
    DIM raw AS STRING, img AS LONG, olddest AS LONG, oldfont AS LONG
    DIM cols AS INTEGER, rows AS INTEGER

    raw = _READFILE$(path)
    IF LEN(raw) = 0 THEN CutRenderAnsi& = 0: EXIT FUNCTION

    CutAnsiDims raw, cols, rows
    IF cols < 1 THEN cols = CUT_SW
    IF rows < 1 THEN rows = CUT_SH

    img = _NEWIMAGE(cols * CUT_CW, rows * CUT_CH, 32)
    IF img >= -1 THEN CutRenderAnsi& = 0: EXIT FUNCTION

    olddest = _DEST
    _DEST img
    CLS , _RGB32(0, 0, 0)
    ANSI_Print raw
    _DEST olddest

    _CLEARCOLOR _RGB32(0, 0, 0), img
    CutRenderAnsi& = img
END FUNCTION

'--- widest printable row and how many rows, so an ANSI layer is only as big
'    as the art actually is. Stops at the 0x1A EOF so a SAUCE record is not
'    counted as picture. ---
SUB CutAnsiDims (raw AS STRING, cols AS INTEGER, rows AS INTEGER)
    DIM i AS LONG, chcode AS INTEGER, col AS INTEGER, mx AS INTEGER, rw AS INTEGER
    DIM inesc AS INTEGER

    col = 0: mx = 0: rw = 1
    FOR i = 1 TO LEN(raw)
        chcode = ASC(raw, i)
        IF chcode = 26 THEN EXIT FOR

        IF inesc THEN
            '--- a CSI ends on a byte in 64..126. NOTE the trap documented in
            '    CLAUDE.md: `[` is itself in that range, so the check must come
            '    AFTER consuming the `[` that opened the sequence. ---
            IF chcode >= 64 THEN
                IF chcode <= 126 THEN inesc = FALSE
            END IF
            _CONTINUE
        END IF

        IF chcode = 27 THEN
            inesc = TRUE
            IF i < LEN(raw) THEN
                IF ASC(raw, i + 1) = 91 THEN i = i + 1
            END IF
            _CONTINUE
        END IF

        IF chcode = 10 THEN
            IF col > mx THEN mx = col
            col = 0
            rw = rw + 1
            _CONTINUE
        END IF
        IF chcode = 13 THEN _CONTINUE

        col = col + 1
        IF col >= CUT_SW THEN
            '--- ANSIPrint auto-wraps at the canvas width ---
            IF col > mx THEN mx = col
            col = 0
            rw = rw + 1
        END IF
    NEXT i
    IF col > mx THEN mx = col

    cols = mx
    rows = rw
    IF cols > CUT_SW THEN cols = CUT_SW
END SUB

'--- the one place art enters the engine. A missing file draws a LOUD
'    placeholder instead of nothing: "nothing appeared" is indistinguishable
'    from "the layer is behind something", and this repo has already paid for
'    that once with placeholder art auditing as finished. ---
FUNCTION CutLoadArt& (subpath AS STRING)
    DIM p AS STRING, img AS LONG
    p = Game_CutArtPath$(subpath)
    CUT_LASTART = p

    IF LEN(p) = 0 _ORELSE (NOT _FILEEXISTS(p)) THEN
        CUT_MISSING = CUT_MISSING + 1
        CutErrAdd 1, 0, "missing art: " + subpath
        CutLoadArt& = CutMissingArt&(subpath)
        EXIT FUNCTION
    END IF

    IF CutIsAnsi%(p) THEN
        img = CutRenderAnsi&(p)
    ELSE
        img = _LOADIMAGE(p, 32)
    END IF

    IF img >= -1 THEN
        CUT_MISSING = CUT_MISSING + 1
        CutErrAdd 1, 0, "unreadable art: " + p
        CutLoadArt& = CutMissingArt&(subpath)
        EXIT FUNCTION
    END IF

    CutLoadArt& = img
END FUNCTION

FUNCTION CutMissingArt& (nm AS STRING)
    DIM img AS LONG, olddest AS LONG, w AS INTEGER, h AS INTEGER
    w = 320: h = 200
    img = _NEWIMAGE(w, h, 32)
    IF img >= -1 THEN CutMissingArt& = 0: EXIT FUNCTION
    olddest = _DEST
    _DEST img
    CLS , _RGB32(40, 0, 0)
    LINE (0, 0)-(w - 1, h - 1), _RGB32(255, 60, 60), B
    LINE (0, 0)-(w - 1, h - 1), _RGB32(255, 60, 60)
    LINE (w - 1, 0)-(0, h - 1), _RGB32(255, 60, 60)
    COLOR _RGB32(255, 200, 200), _RGB32(0, 0, 0)
    _PRINTSTRING (8, h \ 2 - 8), "MISSING: " + LEFT$(nm, 36)
    _DEST olddest
    CutMissingArt& = img
END FUNCTION

'--- frame N of a sequence: base "fx/fog" + frame 3 -> "fx/fog-03.png".
'    Two digits because that is what every splitter this repo would use
'    (ffmpeg %02d, ImageMagick -scene) writes by default. ---
FUNCTION CutFramePath$ (abase AS STRING, n AS INTEGER)
    DIM s AS STRING
    s = LTRIM$(STR$(n))
    IF LEN(s) < 2 THEN s = "0" + s
    CutFramePath$ = abase + "-" + s + ".png"
END FUNCTION

' ----------------------------------------------------------------------------
'  Execute ONE op.
' ----------------------------------------------------------------------------
SUB CutExec (p AS INTEGER)
    DIM L AS INTEGER, slot AS INTEGER, s AS STRING, t AS STRING
    DIM fromv AS SINGLE, i AS INTEGER

    SELECT CASE CUT_OPS(p).cmd

        CASE OP_NOP, OP_LABEL
            ' nothing

        CASE OP_END
            CUT_RUNSTATE = CUT_DONE

        CASE OP_WAIT
            IF CUT_OPS(p).async = 0 THEN
                CUT_WAIT = WAIT_TIME
                CUT_WAITT0 = CUT_NOW
                CUT_WAITDUR = CUT_OPS(p).n1
            END IF

        CASE OP_WAITALL
            IF CutAnyTween% THEN CUT_WAIT = WAIT_ALL

        CASE OP_STOPFX
            CutTweensStopAll TRUE

        CASE OP_JUMP
            IF CUT_OPS(p).n1 >= 1 THEN CUT_PC = CUT_OPS(p).n1

        CASE OP_IFGOTO
            IF CutCondEval%(CutStrGet$(CUT_OPS(p).s1)) = 0 THEN
                IF CUT_OPS(p).n1 >= 1 THEN CUT_PC = CUT_OPS(p).n1
            END IF

        ' ---------------- layers ----------------
        CASE OP_SHOW
            L = CutLayerGet%(CutStrGet$(CUT_OPS(p).s1))
            IF L > 0 THEN
                CutLayerSetArt L, CutStrGet$(CUT_OPS(p).s2)
                '--- `show` normally makes a layer a STILL, undoing any earlier
                '    `anim` on it. An animated GIF is a still FILE that animates
                '    itself, so it has to survive that -- clearing the flag here
                '    unconditionally decoded every frame and then showed the
                '    first one forever. ---
                IF CUT_LAY(L).isgif = 0 THEN CUT_LAY(L).isanim = FALSE
                IF CUT_OPS(p).n1 > 0 THEN
                    CUT_LAY(L).alpha = 0
                    slot = CutTweenStart%(TWN_LAYALPHA, L, 0, 1, CUT_OPS(p).n1, EASE_LINEAR)
                    CutMaybeBlock p, slot
                ELSE
                    CUT_LAY(L).alpha = 1
                END IF
            END IF

        CASE OP_HIDE
            L = CutLayerFind%(CutStrGet$(CUT_OPS(p).s1))
            IF L > 0 THEN
                IF CUT_OPS(p).n1 > 0 THEN
                    slot = CutTweenStart%(TWN_LAYALPHA, L, CUT_LAY(L).alpha, 0, CUT_OPS(p).n1, EASE_LINEAR)
                    CutMaybeBlock p, slot
                ELSE
                    CUT_LAY(L).alpha = 0
                END IF
            END IF

        CASE OP_CLEARLAY
            CutLayersFreeAll

        CASE OP_ANIM
            L = CutLayerGet%(CutStrGet$(CUT_OPS(p).s1))
            IF L > 0 THEN
                CUT_LAY(L).isanim = TRUE
                CUT_LAY(L).abase = CutStrGet$(CUT_OPS(p).s2)
                CUT_LAY(L).nframes = CUT_OPS(p).n1
                CUT_LAY(L).fps = CUT_OPS(p).n2
                IF CUT_LAY(L).fps <= 0 THEN CUT_LAY(L).fps = 12
                CUT_LAY(L).amode = CUT_OPS(p).n3
                CUT_LAY(L).frame = 1
                CUT_LAY(L).adone = FALSE
                CUT_LAY(L).atime = CUT_NOW
                CutLayerSetArt L, CutFramePath$(_TRIM$(CUT_LAY(L).abase), 1)
                IF CUT_OPS(p).n4 > 0 THEN
                    CUT_LAY(L).alpha = 0
                    slot = CutTweenStart%(TWN_LAYALPHA, L, 0, 1, CUT_OPS(p).n4, EASE_LINEAR)
                    CutMaybeBlock p, slot
                ELSE
                    CUT_LAY(L).alpha = 1
                END IF
            END IF

        CASE OP_LAYSET
            L = CutLayerGet%(CutStrGet$(CUT_OPS(p).s1))
            IF L > 0 THEN
                SELECT CASE CINT(CUT_OPS(p).n1)
                    CASE LS_X
                        slot = CutTweenStart%(TWN_LAYX, L, CUT_LAY(L).x, CUT_OPS(p).n2, CUT_OPS(p).n3, CINT(CUT_OPS(p).n4))
                        CutMaybeBlock p, slot
                    CASE LS_Y
                        slot = CutTweenStart%(TWN_LAYY, L, CUT_LAY(L).y, CUT_OPS(p).n2, CUT_OPS(p).n3, CINT(CUT_OPS(p).n4))
                        CutMaybeBlock p, slot
                    CASE LS_SCALE
                        slot = CutTweenStart%(TWN_LAYSCALE, L, CUT_LAY(L).scale, CUT_OPS(p).n2, CUT_OPS(p).n3, CINT(CUT_OPS(p).n4))
                        CutMaybeBlock p, slot
                    CASE LS_ALPHA
                        slot = CutTweenStart%(TWN_LAYALPHA, L, CUT_LAY(L).alpha, CUT_OPS(p).n2, CUT_OPS(p).n3, CINT(CUT_OPS(p).n4))
                        CutMaybeBlock p, slot
                    CASE LS_PARALLAX
                        CUT_LAY(L).parallax = CUT_OPS(p).n2
                    CASE LS_Z
                        CUT_LAY(L).z = CINT(CUT_OPS(p).n2)
                    CASE LS_FILL
                        CutLayerCover L, TRUE
                    CASE LS_FIT
                        CutLayerCover L, FALSE
                END SELECT
            END IF

        ' ---------------- camera ----------------
        CASE OP_PAN
            slot = CutTweenStart%(TWN_CAMX, 0, CUT_CAMX, CUT_OPS(p).n1, CUT_OPS(p).n3, CINT(CUT_OPS(p).n4))
            IF slot > 0 THEN CutMaybeBlock p, slot
            slot = CutTweenStart%(TWN_CAMY, 0, CUT_CAMY, CUT_OPS(p).n2, CUT_OPS(p).n3, CINT(CUT_OPS(p).n4))

        CASE OP_ZOOM
            slot = CutTweenStart%(TWN_CAMZ, 0, CUT_CAMZ, CUT_OPS(p).n1, CUT_OPS(p).n2, CINT(CUT_OPS(p).n3))
            CutMaybeBlock p, slot

        CASE OP_CAMSET
            CUT_CAMX = CUT_OPS(p).n1
            CUT_CAMY = CUT_OPS(p).n2
            IF CUT_OPS(p).n3 > 0 THEN CUT_CAMZ = CUT_OPS(p).n3

        CASE OP_SHAKE
            '--- shake decays to nothing on its own; holding the VM for it
            '    would stall the scene on what is meant to be a garnish. ---
            CUT_SHAKEAMP = CUT_OPS(p).n1
            slot = CutTweenStart%(TWN_SHAKE, 0, CUT_OPS(p).n1, 0, CUT_OPS(p).n2, EASE_OUT)

        ' ---------------- transitions ----------------
        CASE OP_TRANS
            CutTransStart CINT(CUT_OPS(p).n1), CUT_OPS(p).n2, CUT_OPS(p).n3, CUT_OPS(p).n4, CutStrGet$(CUT_OPS(p).s1)
            '--- the swap happens AFTER the snapshot, which is the whole
            '    reason it lives inside this op instead of on its own line ---
            IF CUT_OPS(p).s3 > CUT_NOSTR THEN
                s = CutStrGet$(CUT_OPS(p).s3)
                i = INSTR(s, "|")
                IF i > 1 THEN
                    L = CutLayerGet%(LEFT$(s, i - 1))
                    IF L > 0 THEN
                        CutLayerSetArt L, MID$(s, i + 1)
                        IF CUT_LAY(L).isgif = 0 THEN CUT_LAY(L).isanim = FALSE
                        CUT_LAY(L).alpha = 1
                    END IF
                END IF
            END IF
            IF CUT_OPS(p).async = 0 THEN
                IF CUT_TRACTIVE THEN CUT_WAIT = WAIT_TRANS
            END IF

        ' ---------------- text ----------------
        CASE OP_STYLE
            '--- STICKY. n1 = which style, or -1 for the whole scene. n2/n3 say
            '    which of the two this line actually set, so `color title gold`
            '    does not also blank the title font. ---
            IF CUT_OPS(p).n2 <> 0 THEN
                IF CINT(CUT_OPS(p).n1) < 0 THEN
                    CUT_GLOBFONT = CUT_OPS(p).fonth
                ELSE
                    CUT_STYFONT(CINT(CUT_OPS(p).n1)) = CUT_OPS(p).fonth
                END IF
            END IF
            IF CUT_OPS(p).n3 <> 0 THEN
                IF CINT(CUT_OPS(p).n1) < 0 THEN
                    CUT_GLOBCOL = CutColor~&(CutStrGet$(CUT_OPS(p).s1), CUT_GLOBCOL)
                    CUT_GLOBCOLSET = TRUE
                ELSE
                    L = CINT(CUT_OPS(p).n1)
                    CUT_STYCOL(L) = CutColor~&(CutStrGet$(CUT_OPS(p).s1), CUT_DEFCOL(L))
                    CUT_STYCOLSET(L) = TRUE
                END IF
            END IF

        CASE OP_SAY
            CUT_TXOP = p
            CUT_TXBODY = CutFillTokens$(CutStrGet$(CUT_OPS(p).s1))
            CUT_TXWHO = CutFillTokens$(CutStrGet$(CUT_OPS(p).s2))
            IF LEN(CUT_TXWHO) > 0 THEN CUT_TXMODE = TX_SPEAKER ELSE CUT_TXMODE = TX_SUBTITLE
            CutTextBegin CUT_OPS(p).n1
            IF CUT_OPS(p).async = 0 THEN CUT_WAIT = WAIT_TEXT

        CASE OP_TITLE
            CUT_TXOP = p
            CUT_TXBODY = CutFillTokens$(CutStrGet$(CUT_OPS(p).s1))
            CUT_TXSUB = CutFillTokens$(CutStrGet$(CUT_OPS(p).s2))
            CUT_TXMODE = TX_TITLE
            CutTextBegin CUT_OPS(p).n1
            IF CUT_OPS(p).async = 0 THEN CUT_WAIT = WAIT_TEXT

        CASE OP_CRAWL
            CUT_TXOP = p
            CUT_TXBODY = CutFillTokens$(CutStrGet$(CUT_OPS(p).s1))
            CUT_TXMODE = TX_CRAWL
            CutTextBegin CUT_OPS(p).n1
            IF CUT_OPS(p).async = 0 THEN CUT_WAIT = WAIT_TEXT

        CASE OP_CLEARTEXT
            CUT_TXMODE = TX_NONE
            CUT_TXBODY = ""
            CUT_TXHOLD = FALSE
            FOR i = 1 TO CUT_MAXCAP
                CUT_CAP(i).used = FALSE
            NEXT i

        CASE OP_CAPTION
            CutCaptionAdd CutFillTokens$(CutStrGet$(CUT_OPS(p).s1)), CINT(CUT_OPS(p).n1), CINT(CUT_OPS(p).n2), CINT(CUT_OPS(p).n3), CUT_OPS(p).n4, CutStrGet$(CUT_OPS(p).s2), CUT_OPS(p).fonth

        CASE OP_PORTRAIT
            IF CUT_PORTRAIT > 0 THEN _FREEIMAGE CUT_PORTRAIT
            CUT_PORTRAIT = 0
            s = CutStrGet$(CUT_OPS(p).s1)
            IF LEN(s) > 0 THEN CUT_PORTRAIT = CutLoadArt&(s)
            CUT_PORTSIDE = CINT(CUT_OPS(p).n1)

        ' ---------------- audio ----------------
        CASE OP_MUSIC
            s = CutStrGet$(CUT_OPS(p).s1)
            CUT_LASTMUSIC = s
            Game_CutMusic Game_CutAudioPath$("music", s), CUT_OPS(p).n1, CINT(CUT_OPS(p).n2)

        CASE OP_MUSICSTOP
            Game_CutMusicStop CUT_OPS(p).n1

        CASE OP_SFX
            s = CutStrGet$(CUT_OPS(p).s1)
            CUT_LASTSFX = s
            Game_CutSfx s

        CASE OP_NARRATE
            Game_CutNarrate CutStrGet$(CUT_OPS(p).s1)

        CASE OP_CUE
            s = CutStrGet$(CUT_OPS(p).s1)
            CUT_LASTMUSIC = s
            Game_CutMusic Game_CutAudioPath$("cue", s), 0, CINT(CUT_OPS(p).n1)

        ' ---------------- state ----------------
        CASE OP_SET
            Game_CutSetFlag CutStrGet$(CUT_OPS(p).s1), CUT_OPS(p).n1

        CASE OP_GRANT
            Game_CutGrant CutStrGet$(CUT_OPS(p).s1), CUT_OPS(p).n1

        CASE OP_CHOICE
            CutChoiceBegin p

        CASE OP_OPTION
            ' only reachable if a choice fell through; treated as inert
            ' rather than an error, so a scene never dead-ends on one.

    END SELECT
END SUB

'--- a blocking op parks the VM on the tween it just started. An async one
'    does not -- that is the ENTIRE difference between them. ---
SUB CutMaybeBlock (p AS INTEGER, slot AS INTEGER)
    IF CUT_OPS(p).async THEN EXIT SUB
    IF slot < 1 THEN EXIT SUB
    CUT_WAIT = WAIT_TWEEN
    CUT_WAITTWN = slot
END SUB

FUNCTION CutAnyTween% ()
    DIM i AS INTEGER
    FOR i = 1 TO CUT_MAXTWEEN
        IF CUT_TWN(i).active THEN CutAnyTween% = TRUE: EXIT FUNCTION
    NEXT i
    CutAnyTween% = FALSE
END FUNCTION

'--- size a layer against the stage. cover = TRUE fills it and crops the
'    overflow; FALSE fits the whole picture inside and leaves bars. ---
SUB CutLayerCover (L AS INTEGER, cover AS INTEGER)
    DIM sx AS SINGLE, sy AS SINGLE
    IF L < 1 THEN EXIT SUB
    IF CUT_LAY(L).w < 1 _ORELSE CUT_LAY(L).h < 1 THEN EXIT SUB
    sx = CUT_STAGEW / CUT_LAY(L).w
    sy = CUT_STAGEH / CUT_LAY(L).h
    IF cover THEN
        IF sx > sy THEN CUT_LAY(L).scale = sx ELSE CUT_LAY(L).scale = sy
    ELSE
        IF sx < sy THEN CUT_LAY(L).scale = sx ELSE CUT_LAY(L).scale = sy
    END IF
END SUB

SUB CutLayerSetArt (L AS INTEGER, subpath AS STRING)
    DIM img AS LONG, n AS INTEGER, p AS STRING

    '--- an ANIMATED GIF is one file that is really many frames. Decode it
    '    whole, here, so nothing downstream has to know the difference: from
    '    the compositor's point of view the layer just changes picture. ---
    IF CutIsGif%(subpath) THEN
        p = Game_CutArtPath$(subpath)
        IF LEN(p) > 0 THEN
            CutLayerDropArt L
            GifFreeLayer L
            n = GifLoadInto%(L, p)
            IF n > 0 THEN
                CUT_LASTART = p
                CUT_LAY(L).isgif = TRUE
                CUT_LAY(L).isanim = TRUE
                CUT_LAY(L).nframes = n
                CUT_LAY(L).frame = 1
                CUT_LAY(L).adir = 1
                CUT_LAY(L).adone = FALSE
                CUT_LAY(L).amode = AM_LOOP
                CUT_LAY(L).atime = CUT_NOW
                CUT_LAY(L).src = CUT_GIFIMG(L, 1)
                CUT_LAY(L).w = _WIDTH(CUT_GIFIMG(L, 1))
                CUT_LAY(L).h = _HEIGHT(CUT_GIFIMG(L, 1))
                CUT_LAY(L).workstep = -1
                EXIT SUB
            END IF
        END IF
        '--- a .gif that would not decode falls through to the ordinary loader,
        '    which draws the loud MISSING box rather than nothing ---
    END IF

    CutLayerDropArt L
    GifFreeLayer L
    CUT_LAY(L).isgif = FALSE

    img = CutLoadArt&(subpath)
    CUT_LAY(L).src = img
    IF img < -1 THEN
        CUT_LAY(L).w = _WIDTH(img)
        CUT_LAY(L).h = _HEIGHT(img)
    ELSE
        CUT_LAY(L).w = 0
        CUT_LAY(L).h = 0
    END IF
END SUB

'--- release whatever the layer is currently holding. A GIF layer's `src` is
'    borrowed from CUT_GIFIMG and must NOT be freed here -- GifFreeLayer owns
'    those, and freeing one twice is the classic way to corrupt the heap. ---
SUB CutLayerDropArt (L AS INTEGER)
    IF CUT_LAY(L).isgif = 0 THEN
        IF CUT_LAY(L).src < -1 THEN _FREEIMAGE CUT_LAY(L).src
    END IF
    CUT_LAY(L).src = 0
    IF CUT_LAY(L).work < -1 THEN _FREEIMAGE CUT_LAY(L).work
    CUT_LAY(L).work = 0
    CUT_LAY(L).workstep = -1
END SUB

SUB CutCaptionAdd (txt AS STRING, col AS INTEGER, row AS INTEGER, anchor AS INTEGER, fade AS SINGLE, colorkey AS STRING, fonth AS LONG)
    DIM i AS INTEGER, slot AS INTEGER
    FOR i = 1 TO CUT_MAXCAP
        IF CUT_CAP(i).used = 0 THEN slot = i: EXIT FOR
    NEXT i
    IF slot = 0 THEN slot = 1
    CUT_CAP(slot).used = TRUE
    CUT_CAP(slot).txt = txt
    CUT_CAP(slot).col = col
    CUT_CAP(slot).row = row
    CUT_CAP(slot).anchor = anchor
    '--- no `color` on the line means "use the caption STYLE", which is what
    '    makes a scene-wide `color caption gold` actually reach captions ---
    CUT_CAP(slot).kolor = CutInkFor~&(STY_CAPTION, colorkey)
    CUT_CAP(slot).fonth = fonth
    CUT_CAP(slot).born = CUT_NOW
    CUT_CAP(slot).fade = fade
    CUT_CAP(slot).alpha = 0
END SUB

' ----------------------------------------------------------------------------
'  Step: run ops until one declares a wait.
' ----------------------------------------------------------------------------
SUB CutStep
    DIM p AS INTEGER, spent AS INTEGER

    DO
        IF CUT_RUNSTATE <> CUT_RUNNING THEN EXIT SUB
        IF CUT_WAIT <> WAIT_NONE THEN EXIT SUB
        IF CUT_PC < 1 _ORELSE CUT_PC > CUT_NOP THEN
            CUT_RUNSTATE = CUT_DONE
            EXIT SUB
        END IF

        spent = spent + 1
        IF spent > CUT_BUDGET THEN
            CutErrAdd 2, CUT_OPS(CUT_PC).srcline, "runaway scene: over" + STR$(CUT_BUDGET) + " instructions in one frame (an unguarded jump loop?)"
            CUT_RUNSTATE = CUT_ERROR
            EXIT SUB
        END IF

        p = CUT_PC
        CUT_PC = CUT_PC + 1
        CutExec p
    LOOP
END SUB

' ----------------------------------------------------------------------------
'  Wait resolution: is whatever we parked on finished?
' ----------------------------------------------------------------------------
SUB CutWaitCheck
    SELECT CASE CUT_WAIT
        CASE WAIT_NONE
            ' nothing

        CASE WAIT_TIME
            IF CUT_NOW - CUT_WAITT0 >= CUT_WAITDUR THEN CUT_WAIT = WAIT_NONE

        CASE WAIT_TWEEN
            IF CutTweenActive%(CUT_WAITTWN) = 0 THEN CUT_WAIT = WAIT_NONE

        CASE WAIT_ALL
            IF CutAnyTween% = 0 THEN CUT_WAIT = WAIT_NONE

        CASE WAIT_TRANS
            IF CUT_TRACTIVE = 0 THEN CUT_WAIT = WAIT_NONE

        CASE WAIT_TEXT
            CutTextTick
            IF CUT_TXDONE THEN
                CUT_WAIT = WAIT_NONE
                CUT_TXDONE = FALSE
            END IF

        CASE WAIT_CHOICE
            '--- normally resolved by CutKeyFeed. In AUTO mode nobody is going
            '    to press anything -- attract mode, a `shot`, an unattended
            '    demo loop -- so the menu takes its first option rather than
            '    parking the scene there forever. ---
            IF CUT_MODE = CUT_AUTO THEN
                IF CUT_NOW - CUT_CHT0 >= CUT_CHOICE_AUTOSEC THEN CutChoiceTake
            END IF
    END SELECT
END SUB

' ----------------------------------------------------------------------------
'  One frame. The host calls this in its own loop and draws nothing itself.
' ----------------------------------------------------------------------------
FUNCTION CutTick% ()
    DIM alive AS INTEGER

    CUT_NOW = CutClock#

    IF CUT_RUNSTATE <> CUT_RUNNING THEN
        CutTick% = CUT_RUNSTATE
        EXIT FUNCTION
    END IF

    IF CUT_PAUSED THEN
        '--- a pause must not let the clock run on underneath, or everything
        '    in flight snaps forward the instant it un-pauses. Shifting every
        '    origin forward by the frame's delta freezes time itself. ---
        CutShiftClocks CUT_NOW - CUT_LASTFRAME
        CUT_LASTFRAME = CUT_NOW
        CutRender
        CutTick% = CUT_RUNNING
        EXIT FUNCTION
    END IF
    CUT_LASTFRAME = CUT_NOW

    alive = CutTweensTick%
    CutAnimTick
    CutTransTick
    CutCaptionTick
    CutWaitCheck
    CutStep
    CutRender

    Game_CutAudioTick

    CutTick% = CUT_RUNSTATE
END FUNCTION

'--- Shift every time origin.
'
'  POSITIVE dt pushes the origins forward, which FREEZES the scene: it is what
'  a pause does, so nothing in flight snaps ahead when play resumes.
'
'  NEGATIVE dt pulls them back, which ADVANCES the scene by that much -- one
'  mechanism, both directions. That is what `shot` uses to run a scene to a
'  fixed simulated time without waiting for it, and what [->] scrubs with.
'
'  Guarding this on `dt <= 0` (as it first did) silently made every seek a
'  no-op: `shot` stepped a real-time loop that advanced microseconds per
'  iteration, so every screenshot came back on op 3 whatever time was asked
'  for -- and looked plausible, because op 3 does draw something. ---
SUB CutShiftClocks (dt AS DOUBLE)
    DIM i AS INTEGER
    IF dt = 0 THEN EXIT SUB
    FOR i = 1 TO CUT_MAXTWEEN
        IF CUT_TWN(i).active THEN CUT_TWN(i).t0 = CUT_TWN(i).t0 + dt
    NEXT i
    FOR i = 1 TO CUT_MAXCAP
        IF CUT_CAP(i).used THEN CUT_CAP(i).born = CUT_CAP(i).born + dt
    NEXT i
    FOR i = 1 TO CUT_MAXLAYER
        IF CUT_LAY(i).used THEN CUT_LAY(i).atime = CUT_LAY(i).atime + dt
    NEXT i
    CUT_T0 = CUT_T0 + dt
    CUT_WAITT0 = CUT_WAITT0 + dt
    CUT_TXT0 = CUT_TXT0 + dt
    CUT_TXHOLDT0 = CUT_TXHOLDT0 + dt
    CUT_TRT0 = CUT_TRT0 + dt
    CUT_CHT0 = CUT_CHT0 + dt
END SUB

' ----------------------------------------------------------------------------
'  Frame-sequence animation
' ----------------------------------------------------------------------------
SUB CutAnimTick
    DIM i AS INTEGER, adv AS INTEGER, nf AS INTEGER

    FOR i = 1 TO CUT_MAXLAYER
        IF CUT_LAY(i).used = 0 THEN _CONTINUE
        IF CUT_LAY(i).isanim = 0 THEN _CONTINUE
        IF CUT_LAY(i).adone THEN _CONTINUE

        nf = CUT_LAY(i).nframes
        IF nf < 2 THEN _CONTINUE
        IF CUT_LAY(i).isgif THEN
            '--- a GIF times ITSELF: each frame carries its own delay, and
            '    flattening that to one fps is what makes a decoded GIF play
            '    at visibly the wrong speed. ---
            IF CUT_NOW - CUT_LAY(i).atime < CUT_GIFDELAY(i, CUT_LAY(i).frame) THEN _CONTINUE
        ELSE
            IF CUT_NOW - CUT_LAY(i).atime < 1 / CUT_LAY(i).fps THEN _CONTINUE
        END IF

        CUT_LAY(i).atime = CUT_NOW
        adv = CUT_LAY(i).frame + CUT_LAY(i).adir

        SELECT CASE CUT_LAY(i).amode
            CASE AM_LOOP
                IF adv > nf THEN adv = 1
            CASE AM_ONCE
                IF adv > nf THEN
                    adv = nf
                    CUT_LAY(i).adone = TRUE
                END IF
            CASE AM_PINGPONG
                IF adv > nf THEN
                    adv = nf - 1
                    CUT_LAY(i).adir = -1
                    IF adv < 1 THEN adv = 1
                ELSEIF adv < 1 THEN
                    adv = 2
                    CUT_LAY(i).adir = 1
                    IF adv > nf THEN adv = nf
                END IF
        END SELECT

        IF adv <> CUT_LAY(i).frame THEN
            CUT_LAY(i).frame = adv
            IF CUT_LAY(i).isgif THEN
                '--- already in memory: just point at it, and invalidate the
                '    alpha working copy so a faded GIF still fades ---
                CUT_LAY(i).src = CUT_GIFIMG(i, adv)
                IF CUT_LAY(i).work < -1 THEN _FREEIMAGE CUT_LAY(i).work
                CUT_LAY(i).work = 0
                CUT_LAY(i).workstep = -1
            ELSE
                CutLayerSetArt i, CutFramePath$(_TRIM$(CUT_LAY(i).abase), adv)
            END IF
        END IF
    NEXT i
END SUB

SUB CutCaptionTick
    DIM i AS INTEGER, a AS SINGLE
    FOR i = 1 TO CUT_MAXCAP
        IF CUT_CAP(i).used = 0 THEN _CONTINUE
        IF CUT_CAP(i).fade <= 0 THEN
            CUT_CAP(i).alpha = 1
        ELSE
            a = (CUT_NOW - CUT_CAP(i).born) / CUT_CAP(i).fade
            IF a > 1 THEN a = 1
            CUT_CAP(i).alpha = a
        END IF
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Lifecycle
' ----------------------------------------------------------------------------
SUB CutBegin
    DIM i AS INTEGER

    CUT_CLKLAST = 0
    CUT_CLKWRAP = 0
    CUT_NOW = CutClock#
    CUT_T0 = CUT_NOW
    CUT_LASTFRAME = CUT_NOW

    CUT_PC = 1
    CUT_WAIT = WAIT_NONE
    CUT_WAITTWN = 0
    CUT_RUNSTATE = CUT_RUNNING
    CUT_PAUSED = FALSE

    CUT_CAMX = 0.5
    CUT_CAMY = 0.5
    CUT_CAMZ = 1
    CUT_SHAKEAMP = 0

    CUT_TXMODE = TX_NONE
    CUT_TXBODY = ""
    CUT_TXWHO = ""
    CUT_TXSUB = ""
    CUT_TXHOLD = FALSE
    CUT_TXDONE = FALSE
    CUT_TXOP = 0

    CutStyleDefaults
    CutPipeInit

    CUT_TRACTIVE = FALSE
    CUT_NCH = 0
    CUT_CHSEL = 1

    FOR i = 1 TO CUT_MAXTWEEN
        CUT_TWN(i).active = FALSE
    NEXT i
    FOR i = 1 TO CUT_MAXCAP
        CUT_CAP(i).used = FALSE
    NEXT i
    FOR i = 1 TO CUT_MAXLAYER
        CUT_LAY(i).adir = 1
    NEXT i

    CutBuildImages
END SUB

SUB CutEnd
    CutLayersFreeAll
    IF CUT_PORTRAIT > 0 THEN _FREEIMAGE CUT_PORTRAIT: CUT_PORTRAIT = 0
    IF CUT_STAGE < -1 THEN _FREEIMAGE CUT_STAGE: CUT_STAGE = 0
    IF CUT_SNAP < -1 THEN _FREEIMAGE CUT_SNAP: CUT_SNAP = 0
    IF CUT_SCRATCH < -1 THEN _FREEIMAGE CUT_SCRATCH: CUT_SCRATCH = 0
END SUB

SUB CutBuildImages
    IF CUT_STAGE < -1 THEN _FREEIMAGE CUT_STAGE
    IF CUT_SNAP < -1 THEN _FREEIMAGE CUT_SNAP
    IF CUT_SCRATCH < -1 THEN _FREEIMAGE CUT_SCRATCH
    CUT_STAGE = _NEWIMAGE(CUT_STAGEW, CUT_STAGEH, 32)
    CUT_SNAP = _NEWIMAGE(CUT_PXW, CUT_PXH, 32)
    CUT_SCRATCH = _NEWIMAGE(CUT_PXW, CUT_PXH, 32)
END SUB

' ----------------------------------------------------------------------------
'  Input, fed in by the host so the engine never owns the keyboard.
' ----------------------------------------------------------------------------
SUB CutKeyFeed (k AS STRING)
    IF CUT_RUNSTATE <> CUT_RUNNING THEN EXIT SUB

    '--- ESC always skips, unless the scene declared itself unskippable ---
    IF k = CHR$(27) THEN
        IF CUT_NOSKIP = 0 THEN CutSkip
        EXIT SUB
    END IF

    IF CUT_WAIT = WAIT_CHOICE THEN
        CutChoiceKey k
        EXIT SUB
    END IF

    IF k = " " _ORELSE k = CHR$(13) THEN CutAdvance
END SUB

SUB CutAdvance
    IF CUT_WAIT <> WAIT_TEXT THEN EXIT SUB
    IF CUT_TXHOLD THEN
        '--- fully typed already: this press moves on ---
        CUT_TXDONE = TRUE
    ELSE
        '--- still typing: this press dumps the rest, it does NOT skip the
        '    beat. Two presses to pass a line is what makes a hurried reader
        '    and a careful one both feel in control. ---
        CUT_TXSHOWN = LEN(CUT_TXBODY)
    END IF
END SUB

SUB CutSkip
    CutTweensStopAll TRUE
    CUT_TRACTIVE = FALSE
    CUT_RUNSTATE = CUT_SKIPPED
END SUB

SUB CutTogglePause
    CUT_PAUSED = NOT CUT_PAUSED
END SUB
