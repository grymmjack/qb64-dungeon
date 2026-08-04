' ============================================================================
'  CUTDRAW.bas -- everything that puts pixels on the screen.
'
'  ORDER, EVERY FRAME:
'      1. composite the layers onto the STAGE
'      2. blit the camera's crop of the stage to the screen
'      3. draw text (subtitle / speaker box / title / crawl / captions)
'      4. draw the choice menu, if one is open
'      5. draw the transition over the top
'
'  Text and menus sit ABOVE the camera, not on the stage, so panning does not
'  drag the dialogue around with the scenery -- the same reason the game draws
'  the HUD after the board rather than onto it.
' ============================================================================

' ----------------------------------------------------------------------------
'  Per-layer opacity.
'
'  Changing an image's alpha in QB64 means REBUILDING the image: _SETALPHA
'  writes into the handle, so the pristine copy has to be kept separately and
'  the working copy re-made. Doing that once per frame during a 2-second fade
'  is 120 full-image copies.
'
'  So opacity is quantised to CUT_ALPHA_STEPS levels and the working copy is
'  rebuilt only when the STEP changes -- 32 rebuilds for that same fade,
'  whatever its duration or the frame rate.
'
'  The range `_RGBA32(0,0,0,1) TO _RGBA32(255,255,255,255)` is the important
'  part: it means "every pixel that is not already fully transparent", so a
'  cut-out sprite keeps its cut-out instead of fading in as a rectangle.
' ----------------------------------------------------------------------------
FUNCTION CutLayerWork& (L AS INTEGER)
    DIM astep AS INTEGER, lvl AS INTEGER, a AS SINGLE

    IF CUT_LAY(L).src >= -1 THEN CutLayerWork& = 0: EXIT FUNCTION

    a = CUT_LAY(L).alpha
    IF a >= 0.999 THEN CutLayerWork& = CUT_LAY(L).src: EXIT FUNCTION
    IF a <= 0.001 THEN CutLayerWork& = 0: EXIT FUNCTION

    astep = INT(a * CUT_ALPHA_STEPS)
    IF astep < 1 THEN astep = 1
    IF astep > CUT_ALPHA_STEPS THEN astep = CUT_ALPHA_STEPS

    IF CUT_LAY(L).work < -1 THEN
        IF CUT_LAY(L).workstep = astep THEN
            CutLayerWork& = CUT_LAY(L).work
            EXIT FUNCTION
        END IF
        _FREEIMAGE CUT_LAY(L).work
        CUT_LAY(L).work = 0
    END IF

    CUT_LAY(L).work = _COPYIMAGE(CUT_LAY(L).src, 32)
    IF CUT_LAY(L).work >= -1 THEN
        CUT_LAY(L).work = 0
        CutLayerWork& = CUT_LAY(L).src
        EXIT FUNCTION
    END IF

    lvl = INT(255 * astep / CUT_ALPHA_STEPS)
    _SETALPHA lvl, _RGBA32(0, 0, 0, 1) TO _RGBA32(255, 255, 255, 255), CUT_LAY(L).work
    CUT_LAY(L).workstep = astep
    CutLayerWork& = CUT_LAY(L).work
END FUNCTION

' ----------------------------------------------------------------------------
'  Composite layers -> stage
' ----------------------------------------------------------------------------
SUB CutComposite
    DIM i AS INTEGER, z AS INTEGER, maxz AS INTEGER
    DIM img AS LONG, olddest AS LONG
    DIM cx AS SINGLE, cy AS SINGLE
    DIM w AS SINGLE, h AS SINGLE, x1 AS LONG, y1 AS LONG

    IF CUT_STAGE >= -1 THEN EXIT SUB
    olddest = _DEST
    _DEST CUT_STAGE
    CLS , _RGB32(0, 0, 0)

    FOR i = 1 TO CUT_MAXLAYER
        IF CUT_LAY(i).used THEN
            IF CUT_LAY(i).z > maxz THEN maxz = CUT_LAY(i).z
        END IF
    NEXT i

    FOR z = 0 TO maxz
        FOR i = 1 TO CUT_MAXLAYER
            IF CUT_LAY(i).used = 0 THEN _CONTINUE
            IF CUT_LAY(i).z <> z THEN _CONTINUE

            img = CutLayerWork&(i)
            IF img >= -1 THEN _CONTINUE

            '--- PARALLAX: 1 = pinned to the stage and so moves fully with the
            '    camera; 0 = pinned to the CAMERA and so never appears to move
            '    at all. Anything between is a depth cue -- a far ridge at 0.3
            '    drifts while the foreground sweeps past. ---
            cx = CUT_LAY(i).x + (CUT_CAMX - 0.5) * (1 - CUT_LAY(i).parallax)
            cy = CUT_LAY(i).y + (CUT_CAMY - 0.5) * (1 - CUT_LAY(i).parallax)

            w = CUT_LAY(i).w * CUT_LAY(i).scale
            h = CUT_LAY(i).h * CUT_LAY(i).scale
            IF w < 1 _ORELSE h < 1 THEN _CONTINUE

            x1 = cx * CUT_STAGEW - w / 2
            y1 = cy * CUT_STAGEH - h / 2

            _PUTIMAGE (x1, y1)-(x1 + w - 1, y1 + h - 1), img, CUT_STAGE
        NEXT i
    NEXT z

    _DEST olddest
END SUB

' ----------------------------------------------------------------------------
'  Camera -> screen.
'
'  ZOOM 1 SHOWS THE LARGEST SCREEN-SHAPED RECTANGLE THAT FITS IN THE STAGE.
'  Defining it that way means the picture is NEVER distorted, whatever aspect
'  the author made the stage; and with the default stage (exactly screen
'  sized) zoom 1 is a plain 1:1 blit, which is the least surprising thing a
'  scene with no camera commands in it could do.
' ----------------------------------------------------------------------------
SUB CutCameraBlit
    DIM baseW AS SINGLE, baseH AS SINGLE, vw AS SINGLE, vh AS SINGLE
    DIM px AS SINGLE, py AS SINGLE, x1 AS LONG, y1 AS LONG
    DIM sx AS INTEGER, sy AS INTEGER, zz AS SINGLE

    IF CUT_STAGE >= -1 THEN EXIT SUB

    IF CUT_STAGEW / CUT_STAGEH >= CUT_PXW / CUT_PXH THEN
        baseH = CUT_STAGEH
        baseW = baseH * CUT_PXW / CUT_PXH
    ELSE
        baseW = CUT_STAGEW
        baseH = baseW * CUT_PXH / CUT_PXW
    END IF

    zz = CUT_CAMZ
    IF zz < 0.05 THEN zz = 0.05
    vw = baseW / zz
    vh = baseH / zz

    px = CUT_CAMX * CUT_STAGEW
    py = CUT_CAMY * CUT_STAGEH

    x1 = px - vw / 2
    y1 = py - vh / 2

    '--- SHAKE is applied to the source rect, not the destination: shaking the
    '    destination would leave a moving black gap at the screen edge. ---
    IF CUT_SHAKEAMP > 0.05 THEN
        sx = INT((RND * 2 - 1) * CUT_SHAKEAMP)
        sy = INT((RND * 2 - 1) * CUT_SHAKEAMP)
        x1 = x1 + sx
        y1 = y1 + sy
    END IF

    '--- keep the view inside the stage, so the camera can never show the void
    '    past the edge of the art ---
    IF x1 < 0 THEN x1 = 0
    IF y1 < 0 THEN y1 = 0
    IF x1 + vw > CUT_STAGEW THEN x1 = CUT_STAGEW - vw
    IF y1 + vh > CUT_STAGEH THEN y1 = CUT_STAGEH - vh
    IF x1 < 0 THEN x1 = 0
    IF y1 < 0 THEN y1 = 0

    _PUTIMAGE (0, 0)-(CUT_PXW - 1, CUT_PXH - 1), CUT_STAGE, _DEST, (x1, y1)-(x1 + vw - 1, y1 + vh - 1)
END SUB

' ----------------------------------------------------------------------------
'  Text helpers
' ----------------------------------------------------------------------------
SUB CutWrap (s AS STRING, w AS INTEGER, outl() AS STRING, n AS INTEGER)
    DIM i AS INTEGER, word AS STRING, cur AS STRING, chx AS STRING

    n = 0
    cur = ""
    FOR i = 1 TO LEN(s) + 1
        IF i <= LEN(s) THEN chx = MID$(s, i, 1) ELSE chx = " "

        IF chx = CHR$(10) THEN
            IF LEN(word) > 0 THEN
                IF LEN(cur) + LEN(word) + 1 > w THEN
                    n = n + 1: outl(n) = cur: cur = word
                ELSE
                    IF LEN(cur) > 0 THEN cur = cur + " " + word ELSE cur = word
                END IF
                word = ""
            END IF
            n = n + 1: outl(n) = cur: cur = ""
            _CONTINUE
        END IF

        IF chx = " " THEN
            IF LEN(word) > 0 THEN
                IF LEN(cur) + LEN(word) + 1 > w THEN
                    n = n + 1: outl(n) = cur
                    cur = word
                ELSE
                    IF LEN(cur) > 0 THEN cur = cur + " " + word ELSE cur = word
                END IF
                word = ""
            END IF
        ELSE
            word = word + chx
        END IF
        IF n >= 60 THEN EXIT SUB
    NEXT i
    IF LEN(cur) > 0 THEN n = n + 1: outl(n) = cur
END SUB

SUB CutTextAt (col AS INTEGER, row AS INTEGER, s AS STRING, k AS _UNSIGNED LONG)
    COLOR k, _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (col * CUT_CW, row * CUT_CH), s
END SUB

SUB CutTextCentered (row AS INTEGER, s AS STRING, k AS _UNSIGNED LONG)
    DIM col AS INTEGER
    '--- BASIC binds * tighter than \, so the parenthesis around the
    '    subtraction is load-bearing; without it every line centres at 0.
    '    (This exact bug shipped in four mini-game prototypes.) ---
    col = (CUT_SW - LEN(s)) \ 2
    IF col < 0 THEN col = 0
    CutTextAt col, row, s, k
END SUB

SUB CutPanel (c1 AS INTEGER, r1 AS INTEGER, c2 AS INTEGER, r2 AS INTEGER, bgcol AS _UNSIGNED LONG, edge AS _UNSIGNED LONG)
    LINE (c1 * CUT_CW, r1 * CUT_CH)-((c2 + 1) * CUT_CW - 1, (r2 + 1) * CUT_CH - 1), bgcol, BF
    LINE (c1 * CUT_CW, r1 * CUT_CH)-((c2 + 1) * CUT_CW - 1, (r2 + 1) * CUT_CH - 1), edge, B
END SUB

' ----------------------------------------------------------------------------
'  Typewriter
' ----------------------------------------------------------------------------
SUB CutTextBegin (holdsecs AS SINGLE)
    CUT_TXSHOWN = 0
    CUT_TXT0 = CUT_NOW
    CUT_TXHOLD = FALSE
    CUT_TXDONE = FALSE
    CUT_TXHOLDSECS = holdsecs
END SUB

'--- reading time when nobody is pressing anything. Long enough to actually
'    read, floor high enough that a two-word line does not flash past. ---
FUNCTION CutAutoHold! (s AS STRING)
    DIM t AS SINGLE
    t = 1.2 + LEN(s) / 18
    IF t < 1.5 THEN t = 1.5
    IF t > 9 THEN t = 9
    CutAutoHold! = t
END FUNCTION

SUB CutTextTick
    DIM total AS INTEGER, want AS INTEGER, hold AS SINGLE

    total = LEN(CUT_TXBODY)
    IF CUT_TXMODE = TX_NONE _ORELSE total = 0 THEN
        CUT_TXDONE = TRUE
        EXIT SUB
    END IF

    '--- the crawl is not typed, it scrolls; it is done when its time is up ---
    IF CUT_TXMODE = TX_CRAWL THEN
        IF CUT_NOW - CUT_TXT0 >= CUT_TXHOLDSECS THEN CUT_TXDONE = TRUE
        EXIT SUB
    END IF

    IF CUT_TXHOLD = 0 THEN
        want = INT((CUT_NOW - CUT_TXT0) * CUT_TEXTSPEED)
        IF want > CUT_TXSHOWN THEN CUT_TXSHOWN = want
        IF CUT_TXSHOWN >= total THEN
            CUT_TXSHOWN = total
            CUT_TXHOLD = TRUE
            CUT_TXHOLDT0 = CUT_NOW
        END IF
        EXIT SUB
    END IF

    '--- fully typed. In MANUAL mode this beat waits for a key (CutAdvance
    '    sets CUT_TXDONE); in AUTO it times out on its own. An explicit
    '    `for <t>` on the line wins over both. ---
    hold = CUT_TXHOLDSECS
    IF hold <= 0 THEN
        IF CUT_MODE = CUT_AUTO THEN
            hold = CutAutoHold!(CUT_TXBODY)
        ELSE
            EXIT SUB
        END IF
    END IF
    IF CUT_NOW - CUT_TXHOLDT0 >= hold THEN CUT_TXDONE = TRUE
END SUB

' ----------------------------------------------------------------------------
'  Text drawing
' ----------------------------------------------------------------------------
SUB CutDrawText
    DIM lines(0 TO 63) AS STRING
    DIM n AS INTEGER, i AS INTEGER, shown AS STRING
    DIM r AS INTEGER, w AS INTEGER, bx AS INTEGER
    DIM ink AS _UNSIGNED LONG, dimk AS _UNSIGNED LONG
    DIM prog AS SINGLE, top AS SINGLE

    ink = _RGB32(232, 226, 208)
    dimk = _RGB32(150, 145, 130)

    SELECT CASE CUT_TXMODE

        CASE TX_SUBTITLE
            shown = LEFT$(CUT_TXBODY, CUT_TXSHOWN)
            CutWrap shown, CUT_SW - 8, lines(), n
            CutPanel 2, CUT_SH - 6, CUT_SW - 3, CUT_SH - 2, _RGBA32(0, 0, 0, 200), _RGBA32(120, 110, 90, 160)
            FOR i = 1 TO n
                IF i > 3 THEN EXIT FOR
                CutTextAt 4, CUT_SH - 5 + (i - 1), lines(i), ink
            NEXT i
            IF CUT_TXHOLD THEN CutBlinkPrompt CUT_SW - 6, CUT_SH - 2

        CASE TX_SPEAKER
            shown = LEFT$(CUT_TXBODY, CUT_TXSHOWN)
            bx = 2
            IF CUT_PORTRAIT < -1 THEN bx = 18
            CutWrap shown, (CUT_SW - 4 - bx), lines(), n
            CutPanel bx, CUT_SH - 9, CUT_SW - 3, CUT_SH - 2, _RGBA32(8, 6, 12, 225), _RGBA32(150, 130, 90, 200)
            CutTextAt bx + 2, CUT_SH - 9, " " + UCASE$(CUT_TXWHO) + " ", _RGB32(226, 188, 96)
            FOR i = 1 TO n
                IF i > 6 THEN EXIT FOR
                CutTextAt bx + 2, CUT_SH - 7 + (i - 1), lines(i), ink
            NEXT i
            IF CUT_PORTRAIT < -1 THEN CutDrawPortrait
            IF CUT_TXHOLD THEN CutBlinkPrompt CUT_SW - 6, CUT_SH - 2

        CASE TX_TITLE
            shown = LEFT$(CUT_TXBODY, CUT_TXSHOWN)
            r = CUT_SH \ 2 - 2
            CutTextCentered r, shown, _RGB32(236, 210, 140)
            CutTextCentered r - 2, STRING$(LEN(CUT_TXBODY) + 6, "-"), _RGB32(110, 92, 60)
            CutTextCentered r + 2, STRING$(LEN(CUT_TXBODY) + 6, "-"), _RGB32(110, 92, 60)
            IF LEN(CUT_TXSUB) > 0 THEN
                IF CUT_TXSHOWN >= LEN(CUT_TXBODY) THEN CutTextCentered r + 4, CUT_TXSUB, dimk
            END IF

        CASE TX_CRAWL
            '--- scrolls from below the screen to above it over its duration,
            '    so the author sets the pace with `for <t>` and never has to
            '    count lines. ---
            CutWrap CUT_TXBODY, CUT_SW - 20, lines(), n
            prog = (CUT_NOW - CUT_TXT0) / CUT_TXHOLDSECS
            IF prog < 0 THEN prog = 0
            IF prog > 1 THEN prog = 1
            top = CUT_SH - prog * (CUT_SH + n + 2)
            FOR i = 1 TO n
                r = INT(top + i)
                IF r >= 0 THEN
                    IF r < CUT_SH THEN CutTextCentered r, lines(i), ink
                END IF
            NEXT i
    END SELECT

    CutDrawCaptions
END SUB

SUB CutBlinkPrompt (col AS INTEGER, row AS INTEGER)
    IF CUT_MODE = CUT_AUTO THEN EXIT SUB
    IF (INT(CUT_NOW * 2) AND 1) = 0 THEN EXIT SUB
    CutTextAt col, row, CHR$(31), _RGB32(200, 180, 120)
END SUB

'--- The portrait gets its OWN framed box, matching the speaker panel.
'
'  Drawn bare it read as a sprite that happened to be lying next to the
'  dialogue rather than as part of it, and nothing stopped it hanging off the
'  bottom of the panel: the fit was computed from the height alone, so a wide
'  portrait overflowed sideways and a tall one overflowed down. Fitting to
'  BOTH axes and then centring in what is left is the whole fix.
SUB CutDrawPortrait
    DIM w AS INTEGER, h AS INTEGER, sc AS SINGLE, scw AS SINGLE, sch AS SINGLE
    DIM c1 AS INTEGER, r1 AS INTEGER, c2 AS INTEGER, r2 AS INTEGER
    DIM bw AS INTEGER, bh AS INTEGER, dx AS INTEGER, dy AS INTEGER

    IF CUT_PORTRAIT >= -1 THEN EXIT SUB
    w = _WIDTH(CUT_PORTRAIT)
    h = _HEIGHT(CUT_PORTRAIT)
    IF w < 1 _ORELSE h < 1 THEN EXIT SUB

    r1 = CUT_SH - 9
    r2 = CUT_SH - 2
    IF CUT_PORTSIDE = 1 THEN
        c1 = CUT_SW - 17
        c2 = CUT_SW - 3
    ELSE
        c1 = 2
        c2 = 16
    END IF

    CutPanel c1, r1, c2, r2, _RGBA32(8, 6, 12, 225), _RGBA32(150, 130, 90, 200)

    '--- the drawable area, one cell in from the frame on every side ---
    bw = (c2 - c1 - 1) * CUT_CW
    bh = (r2 - r1 - 1) * CUT_CH
    IF bw < 1 _ORELSE bh < 1 THEN EXIT SUB

    '--- fit to whichever axis binds first, so it can never overflow either ---
    scw = bw / w
    sch = bh / h
    IF scw < sch THEN sc = scw ELSE sc = sch

    dx = (c1 + 1) * CUT_CW + (bw - w * sc) / 2
    dy = (r1 + 1) * CUT_CH + (bh - h * sc) / 2

    _PUTIMAGE (dx, dy)-(dx + w * sc - 1, dy + h * sc - 1), CUT_PORTRAIT, _DEST
END SUB

SUB CutDrawCaptions
    DIM i AS INTEGER, chx AS INTEGER, s AS STRING
    DIM k AS _UNSIGNED LONG, aa AS INTEGER

    FOR i = 1 TO CUT_MAXCAP
        IF CUT_CAP(i).used = 0 THEN _CONTINUE
        s = _TRIM$(CUT_CAP(i).txt)
        chx = CUT_CAP(i).col
        SELECT CASE CUT_CAP(i).anchor
            CASE ANC_C: chx = chx - LEN(s) \ 2
            CASE ANC_R: chx = chx - LEN(s)
        END SELECT
        IF chx < 0 THEN chx = 0

        aa = INT(CUT_CAP(i).alpha * 255)
        IF aa < 0 THEN aa = 0
        IF aa > 255 THEN aa = 255
        k = _RGBA32(_RED32(CUT_CAP(i).kolor), _GREEN32(CUT_CAP(i).kolor), _BLUE32(CUT_CAP(i).kolor), aa)
        CutTextAt chx, CUT_CAP(i).row, s, k
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Choice menu
' ----------------------------------------------------------------------------
SUB CutChoiceBegin (p AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER

    n = CINT(CUT_OPS(p).n1)
    IF n < 1 THEN EXIT SUB
    IF n > CUT_MAXCHOICE THEN n = CUT_MAXCHOICE

    CUT_CHPROMPT = CutStrGet$(CUT_OPS(p).s1)
    CUT_NCH = n
    CUT_CHSEL = 1
    FOR i = 1 TO n
        CUT_CHTEXT(i) = CutStrGet$(CUT_OPS(p + i).s1)
        CUT_CHTARGET(i) = CINT(CUT_OPS(p + i).n1)
    NEXT i

    '--- step past the OP_OPTIONs: they are data for this op, not code ---
    CUT_PC = p + n + 1
    CUT_WAIT = WAIT_CHOICE
    CUT_CHT0 = CUT_NOW
END SUB

SUB CutChoiceKey (k AS STRING)
    DIM kk AS STRING
    kk = LCASE$(k)

    IF kk = "w" _ORELSE k = CHR$(0) + "H" THEN
        CUT_CHSEL = CUT_CHSEL - 1
        IF CUT_CHSEL < 1 THEN CUT_CHSEL = CUT_NCH
        EXIT SUB
    END IF
    IF kk = "s" _ORELSE k = CHR$(0) + "P" THEN
        CUT_CHSEL = CUT_CHSEL + 1
        IF CUT_CHSEL > CUT_NCH THEN CUT_CHSEL = 1
        EXIT SUB
    END IF
    IF LEN(kk) = 1 THEN
        IF kk >= "1" THEN
            IF kk <= "4" THEN
                IF VAL(kk) <= CUT_NCH THEN
                    CUT_CHSEL = VAL(kk)
                    CutChoiceTake
                    EXIT SUB
                END IF
            END IF
        END IF
    END IF
    IF k = " " _ORELSE k = CHR$(13) THEN CutChoiceTake
END SUB

SUB CutChoiceTake
    DIM t AS INTEGER
    IF CUT_NCH < 1 THEN EXIT SUB
    t = CUT_CHTARGET(CUT_CHSEL)
    CUT_NCH = 0
    CUT_WAIT = WAIT_NONE
    IF t >= 1 THEN CUT_PC = t
END SUB

SUB CutDrawChoice
    DIM i AS INTEGER, r AS INTEGER, w AS INTEGER, c1 AS INTEGER
    DIM s AS STRING, k AS _UNSIGNED LONG

    IF CUT_NCH < 1 THEN EXIT SUB

    w = LEN(CUT_CHPROMPT)
    FOR i = 1 TO CUT_NCH
        IF LEN(CUT_CHTEXT(i)) + 6 > w THEN w = LEN(CUT_CHTEXT(i)) + 6
    NEXT i
    w = w + 6
    IF w > CUT_SW - 6 THEN w = CUT_SW - 6

    c1 = (CUT_SW - w) \ 2
    r = CUT_SH - 12 - CUT_NCH

    CutPanel c1, r, c1 + w, r + CUT_NCH + 3, _RGBA32(10, 8, 16, 235), _RGBA32(170, 145, 95, 220)
    CutTextAt c1 + 3, r + 1, CUT_CHPROMPT, _RGB32(232, 226, 208)

    FOR i = 1 TO CUT_NCH
        s = LTRIM$(STR$(i)) + ") " + CUT_CHTEXT(i)
        IF i = CUT_CHSEL THEN
            k = _RGB32(255, 232, 150)
            LINE ((c1 + 2) * CUT_CW, (r + 2 + i) * CUT_CH)-((c1 + w - 1) * CUT_CW, (r + 3 + i) * CUT_CH - 1), _RGBA32(90, 70, 30, 200), BF
            CutTextAt c1 + 3, r + 2 + i, CHR$(16) + " " + s, k
        ELSE
            CutTextAt c1 + 5, r + 2 + i, s, _RGB32(180, 175, 160)
        END IF
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Transitions
' ----------------------------------------------------------------------------
SUB CutTransStart (kind AS INTEGER, secs AS SINGLE, n3 AS SINGLE, n4 AS SINGLE, colorkey AS STRING)
    DIM i AS LONG, ncell AS LONG, d AS LONG

    CUT_TRKIND = kind
    CUT_TRDUR = secs
    CUT_TRN3 = n3
    CUT_TRN4 = n4
    CUT_TRT0 = CUT_NOW
    CUT_TRCOL = CutColor~&(colorkey, _RGB32(0, 0, 0))

    IF kind = TR_CUT _ORELSE secs <= 0 THEN
        CUT_TRACTIVE = FALSE
        EXIT SUB
    END IF

    CUT_TRACTIVE = TRUE

    '--- which transitions need the OUTGOING picture held? Everything that
    '    reveals the new one from under the old. A flat fade or flash does
    '    not, because it only tints what is already there. ---
    SELECT CASE kind
        CASE TR_FADE, TR_FLASH, TR_STATIC
            CUT_TRSNAP = FALSE
        CASE ELSE
            CUT_TRSNAP = TRUE
    END SELECT

    IF CUT_TRSNAP THEN
        '--- CutExec runs BEFORE CutRender in the tick, so the screen still
        '    holds LAST frame -- which is exactly the outgoing picture. ---
        d = _DEST
        IF CUT_SNAP < -1 THEN _PUTIMAGE (0, 0), d, CUT_SNAP
        CUT_SCRSTEP = -1
    END IF

    IF kind = TR_SCATTER THEN
        ncell = CLNG(CUT_SW) * CLNG(CUT_SH)
        REDIM CUT_SCAT(0 TO ncell) AS SINGLE
        FOR i = 0 TO ncell
            CUT_SCAT(i) = RND
        NEXT i
    END IF
END SUB

SUB CutTransTick
    IF CUT_TRACTIVE = 0 THEN EXIT SUB
    IF CUT_TRDUR <= 0 THEN CUT_TRACTIVE = FALSE: EXIT SUB
    IF CUT_NOW - CUT_TRT0 >= CUT_TRDUR THEN CUT_TRACTIVE = FALSE
END SUB

SUB CutTransDraw
    DIM t AS SINGLE, a AS INTEGER, i AS INTEGER, j AS INTEGER
    DIM x AS LONG, y AS LONG, dx AS LONG, dy AS LONG, hw AS LONG, hh AS LONG
    DIM r AS LONG, cx AS LONG, cy AS LONG, half AS LONG
    DIM idx AS LONG

    IF CUT_TRACTIVE = 0 THEN
        '--- a `fade to <colour>` that has ELAPSED must leave the screen at
        '    that colour, not snap back. The scene is meant to be sitting in
        '    the dark until something changes it. ---
        IF CUT_TRKIND = TR_FADE THEN
            IF CUT_TRN3 = 0 THEN
                LINE (0, 0)-(CUT_PXW - 1, CUT_PXH - 1), CUT_TRCOL, BF
            END IF
        END IF
        EXIT SUB
    END IF

    t = (CUT_NOW - CUT_TRT0) / CUT_TRDUR
    IF t < 0 THEN t = 0
    IF t > 1 THEN t = 1

    SELECT CASE CUT_TRKIND

        CASE TR_FADE
            '--- n3 = 1 means FROM the colour (it clears), 0 means TO it ---
            IF CUT_TRN3 = 1 THEN a = INT((1 - t) * 255) ELSE a = INT(t * 255)
            LINE (0, 0)-(CUT_PXW - 1, CUT_PXH - 1), _RGBA32(_RED32(CUT_TRCOL), _GREEN32(CUT_TRCOL), _BLUE32(CUT_TRCOL), a), BF

        CASE TR_FLASH
            a = INT((1 - t) * 255)
            LINE (0, 0)-(CUT_PXW - 1, CUT_PXH - 1), _RGBA32(_RED32(CUT_TRCOL), _GREEN32(CUT_TRCOL), _BLUE32(CUT_TRCOL), a), BF

        CASE TR_STATIC
            FOR i = 1 TO 900
                x = RND * CUT_PXW
                y = RND * CUT_PXH
                a = INT(RND * 200)
                LINE (x, y)-(x + CUT_CW - 1, y + CUT_CH - 1), _RGBA32(a, a, a, 150), BF
            NEXT i

        CASE TR_DISSOLVE
            CutBlitSnapAlpha 1 - t

        CASE TR_WIPE
            IF CUT_SNAP >= -1 THEN EXIT SUB
            SELECT CASE CINT(CUT_TRN3)
                CASE DIR_L
                    x = INT(t * CUT_PXW)
                    IF x < CUT_PXW THEN _PUTIMAGE (x, 0)-(CUT_PXW - 1, CUT_PXH - 1), CUT_SNAP, _DEST, (x, 0)-(CUT_PXW - 1, CUT_PXH - 1)
                CASE DIR_R
                    x = CUT_PXW - INT(t * CUT_PXW)
                    IF x > 0 THEN _PUTIMAGE (0, 0)-(x - 1, CUT_PXH - 1), CUT_SNAP, _DEST, (0, 0)-(x - 1, CUT_PXH - 1)
                CASE DIR_U
                    y = INT(t * CUT_PXH)
                    IF y < CUT_PXH THEN _PUTIMAGE (0, y)-(CUT_PXW - 1, CUT_PXH - 1), CUT_SNAP, _DEST, (0, y)-(CUT_PXW - 1, CUT_PXH - 1)
                CASE DIR_D
                    y = CUT_PXH - INT(t * CUT_PXH)
                    IF y > 0 THEN _PUTIMAGE (0, 0)-(CUT_PXW - 1, y - 1), CUT_SNAP, _DEST, (0, 0)-(CUT_PXW - 1, y - 1)
            END SELECT

        CASE TR_PUSH
            IF CUT_SNAP >= -1 THEN EXIT SUB
            dx = 0: dy = 0
            SELECT CASE CINT(CUT_TRN3)
                CASE DIR_L: dx = -INT(t * CUT_PXW)
                CASE DIR_R: dx = INT(t * CUT_PXW)
                CASE DIR_U: dy = -INT(t * CUT_PXH)
                CASE DIR_D: dy = INT(t * CUT_PXH)
            END SELECT
            _PUTIMAGE (dx, dy)-(dx + CUT_PXW - 1, dy + CUT_PXH - 1), CUT_SNAP, _DEST

        CASE TR_SPLIT
            IF CUT_SNAP >= -1 THEN EXIT SUB
            half = CUT_PXH \ 2
            dy = INT(t * half)
            _PUTIMAGE (0, -dy)-(CUT_PXW - 1, half - 1 - dy), CUT_SNAP, _DEST, (0, 0)-(CUT_PXW - 1, half - 1)
            _PUTIMAGE (0, half + dy)-(CUT_PXW - 1, CUT_PXH - 1 + dy), CUT_SNAP, _DEST, (0, half)-(CUT_PXW - 1, CUT_PXH - 1)

        CASE TR_IRISOUT, TR_IRISIN
            IF CUT_SNAP >= -1 THEN EXIT SUB
            cx = CUT_TRN3 * CUT_PXW
            cy = CUT_TRN4 * CUT_PXH
            IF CUT_TRKIND = TR_IRISOUT THEN
                r = t * CutIrisMax&(cx, cy)
            ELSE
                r = (1 - t) * CutIrisMax&(cx, cy)
            END IF
            CutSnapExceptCircle cx, cy, r

        CASE TR_SCAN
            IF CUT_SNAP >= -1 THEN EXIT SUB
            y = INT(t * CUT_PXH)
            IF y < CUT_PXH THEN _PUTIMAGE (0, y)-(CUT_PXW - 1, CUT_PXH - 1), CUT_SNAP, _DEST, (0, y)-(CUT_PXW - 1, CUT_PXH - 1)
            LINE (0, y)-(CUT_PXW - 1, y + 1), _RGBA32(230, 240, 255, 210), BF

        CASE TR_SCATTER
            IF CUT_SNAP >= -1 THEN EXIT SUB
            FOR j = 0 TO CUT_SH - 1
                FOR i = 0 TO CUT_SW - 1
                    idx = CLNG(j) * CUT_SW + i
                    IF idx <= UBOUND(CUT_SCAT) THEN
                        IF CUT_SCAT(idx) > t THEN
                            _PUTIMAGE (i * CUT_CW, j * CUT_CH)-((i + 1) * CUT_CW - 1, (j + 1) * CUT_CH - 1), CUT_SNAP, _DEST, (i * CUT_CW, j * CUT_CH)-((i + 1) * CUT_CW - 1, (j + 1) * CUT_CH - 1)
                        END IF
                    END IF
                NEXT i
            NEXT j

        CASE TR_CRTOFF
            IF CUT_SNAP >= -1 THEN EXIT SUB
            LINE (0, 0)-(CUT_PXW - 1, CUT_PXH - 1), _RGB32(0, 0, 0), BF
            IF t < 0.75 THEN
                hh = (1 - t / 0.75) * (CUT_PXH \ 2)
                IF hh < 1 THEN hh = 1
                _PUTIMAGE (0, CUT_PXH \ 2 - hh)-(CUT_PXW - 1, CUT_PXH \ 2 + hh), CUT_SNAP, _DEST
            ELSE
                hw = (1 - (t - 0.75) / 0.25) * (CUT_PXW \ 2)
                IF hw < 1 THEN hw = 1
                LINE (CUT_PXW \ 2 - hw, CUT_PXH \ 2 - 1)-(CUT_PXW \ 2 + hw, CUT_PXH \ 2 + 1), _RGB32(240, 250, 255), BF
            END IF
    END SELECT
END SUB

FUNCTION CutIrisMax& (cx AS LONG, cy AS LONG)
    DIM a AS LONG, b AS LONG, m AS LONG
    a = cx: IF CUT_PXW - cx > a THEN a = CUT_PXW - cx
    b = cy: IF CUT_PXH - cy > b THEN b = CUT_PXH - cy
    m = SQR(CSNG(a) * a + CSNG(b) * b)
    CutIrisMax& = m + 2
END FUNCTION

'--- draw the outgoing frame everywhere EXCEPT a circle, one row-pair at a
'    time. The alternative (mask the incoming frame into the circle) needs the
'    incoming frame saved as well; this way the circle is simply where we do
'    not paint, and what shows through is whatever the scene already drew. ---
SUB CutSnapExceptCircle (cx AS LONG, cy AS LONG, r AS LONG)
    DIM y AS LONG, dy AS LONG, half AS LONG, x1 AS LONG, x2 AS LONG

    FOR y = 0 TO CUT_PXH - 1
        dy = y - cy
        IF ABS(dy) >= r THEN
            _PUTIMAGE (0, y)-(CUT_PXW - 1, y), CUT_SNAP, _DEST, (0, y)-(CUT_PXW - 1, y)
            _CONTINUE
        END IF
        half = SQR(CSNG(r) * r - CSNG(dy) * dy)
        x1 = cx - half
        x2 = cx + half
        IF x1 > 0 THEN _PUTIMAGE (0, y)-(x1 - 1, y), CUT_SNAP, _DEST, (0, y)-(x1 - 1, y)
        IF x2 < CUT_PXW - 1 THEN _PUTIMAGE (x2 + 1, y)-(CUT_PXW - 1, y), CUT_SNAP, _DEST, (x2 + 1, y)-(CUT_PXW - 1, y)
    NEXT y
END SUB

'--- the outgoing frame at partial opacity, quantised like the layers ---
SUB CutBlitSnapAlpha (a AS SINGLE)
    DIM astep AS INTEGER, lvl AS INTEGER

    IF CUT_SNAP >= -1 THEN EXIT SUB
    IF a >= 0.999 THEN
        _PUTIMAGE (0, 0), CUT_SNAP, _DEST
        EXIT SUB
    END IF
    IF a <= 0.001 THEN EXIT SUB

    astep = INT(a * CUT_ALPHA_STEPS)
    IF astep < 1 THEN astep = 1

    IF CUT_SCRSTEP <> astep THEN
        IF CUT_SCRATCH < -1 THEN _FREEIMAGE CUT_SCRATCH
        CUT_SCRATCH = _COPYIMAGE(CUT_SNAP, 32)
        IF CUT_SCRATCH >= -1 THEN CUT_SCRATCH = 0: EXIT SUB
        lvl = INT(255 * astep / CUT_ALPHA_STEPS)
        _SETALPHA lvl, _RGBA32(0, 0, 0, 1) TO _RGBA32(255, 255, 255, 255), CUT_SCRATCH
        CUT_SCRSTEP = astep
    END IF

    IF CUT_SCRATCH < -1 THEN _PUTIMAGE (0, 0), CUT_SCRATCH, _DEST
END SUB

' ----------------------------------------------------------------------------
'  The whole frame
' ----------------------------------------------------------------------------
SUB CutRender
    CutComposite
    CLS , _RGB32(0, 0, 0)
    CutCameraBlit
    CutDrawText
    CutDrawChoice
    CutTransDraw
END SUB
