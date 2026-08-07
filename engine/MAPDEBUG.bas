' ============================================================================
'  engine/MAPDEBUG.bas -- the MAP DEBUGGER: every derived layer, toggleable.
'
'      dungeon.run mapdebug            (or [~] then [9] over a live run)
'
'  A board is DERIVED -- which cells are walkable, which room a cell belongs to,
'  which region is secret. Each derivation can be dumped to its own PNG, and
'  those answer one question at a time from a cold start. The questions that
'  actually come up are about a RELATIONSHIP between two of them, and two PNGs
'  and a memory cannot answer that; two translucent layers over the same board
'  answer it in a second.
'
'  ENGINE, not game. A debugger that only debugs one game is a feature, not
'  tooling, and the next game deserves this on day one. The engine owns the
'  screen, the toggles, the selection, the panels and the shot mode, and knows
'  nothing about rooms or chambers.
'
'  THE HOST REGISTERS ITS LAYERS AND EVENTS -- the same shape as the dump
'  registry in CONSOLE.bas, and for the same reason. With a fixed set of
'  accessors the engine would enumerate what layers exist and every new one
'  would be an engine edit. With a registry the game adds a layer, and so could
'  a pack.
'
'      MapLayer "sectors", ML_CELL      ' the game fills a colour per cell
'      MapLayer "doors",   ML_MARK      ' ...or draws its own marks
'      MapEvent "Spawn a CURIO", -1     ' -1 = needs a run in progress
'
'  A CELL layer is filled ONCE PER FRAME into ML_BUF rather than answered per
'  cell: per-cell dispatch is 6,732 calls per layer per frame; filling is one.
'
'  Nothing is recomputed for display -- a layer is whatever the game put in the
'  buffer, and that is the array the game itself reads. A debugger that derives
'  its own answer can agree with itself and still be wrong about the game.
' ============================================================================

'--- Registration, called by the host through Game_MapRegister. ---
SUB MapLayer (nm AS STRING, kind AS INTEGER)
    IF ML_N >= ML_MAX THEN EXIT SUB
    ML_N = ML_N + 1
    ML_NAME(ML_N) = nm
    ML_KIND(ML_N) = kind
END SUB

SUB MapEvent (label AS STRING, needslive AS INTEGER)
    IF MEV_N >= MEV_MAX THEN EXIT SUB
    MEV_N = MEV_N + 1
    MEV_LABEL(MEV_N) = label
    MEV_LIVE(MEV_N) = needslive
END SUB

'--- Ask the host for its layers ONCE; re-registering would stack duplicates. ---
SUB MapDebugInit
    IF ML_N > 0 THEN EXIT SUB
    Game_MapRegister
    '--- open with the first two on. Everything at once is mud, and by
    '    convention a host registers its most orienting layers first. ---
    IF ML_N >= 1 THEN ML_ON(1) = TRUE
    IF ML_N >= 2 THEN ML_ON(2) = TRUE
    MD_ART = TRUE
    IF MD_ALPHA = 0 THEN MD_ALPHA = 110
END SUB

SUB MapClearBuf
    DIM cx AS INTEGER, cy AS INTEGER
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            ML_BUF(cx, cy) = 0
        NEXT cx
    NEXT cy
END SUB

'--- the host writes a cell's tint through this, so the buffer's bounds are
'    checked in ONE place instead of in every game that fills a layer ---
SUB MapPut (cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG)
    IF cx < 0 _ORELSE cy < 0 _ORELSE cx > SW - 1 _ORELSE cy > SH - 1 THEN EXIT SUB
    ML_BUF(cx, cy) = k
END SUB

'--- ...and marks its points through this ---
SUB MapMark (cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG)
    MdBox cx, cy, k
END SUB

SUB DumpMapDebug
    MapDebugScreen 0
END SUB


SUB MapDebugScreen (live AS INTEGER)
    DIM k AS STRING, quit AS INTEGER, snap AS LONG

    MD_LIVE = live
    MapDebugInit

    IF live THEN
        snap = _NEWIMAGE(SW * CW, SH * CH, 32)
        _PUTIMAGE (0, 0), CANVAS, snap
        MD_SX = c.x \ CW
        MD_SY = c.y \ CH
    END IF

    DO
        MdDraw
        Present
        MdMouse

        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: MD_SY = MD_SY - 1
                CASE 80: MD_SY = MD_SY + 1
                CASE 75: MD_SX = MD_SX - 1
                CASE 77: MD_SX = MD_SX + 1
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            IF k >= "1" _ANDALSO k <= "9" THEN
                IF VAL(k) <= ML_N THEN ML_ON(VAL(k)) = NOT ML_ON(VAL(k))
            END IF
            SELECT CASE LCASE$(k)
                CASE "0": MD_ART = NOT MD_ART
                CASE "a": MdAll TRUE
                CASE "n": MdAll FALSE
                CASE "-", "_": MD_ALPHA = MD_ALPHA - 20: IF MD_ALPHA < 30 THEN MD_ALPHA = 30
                CASE "=", "+": MD_ALPHA = MD_ALPHA + 20: IF MD_ALPHA > 240 THEN MD_ALPHA = 240
                CASE "s": _SAVEIMAGE "mapdebug.png", CANVAS: MD_MSG = "wrote mapdebug.png"
                CASE "e": MdEventMenu
                CASE "o": MdPlaceOverlay
                CASE "c": MdPlaceChamber
                CASE CHR$(27): quit = TRUE
            END SELECT
        END IF
        IF MD_SX < 0 THEN MD_SX = 0
        IF MD_SY < 0 THEN MD_SY = 0
        IF MD_SX > SW - 1 THEN MD_SX = SW - 1
        IF MD_SY > SH - 1 THEN MD_SY = SH - 1
        IF quit THEN EXIT DO
        _LIMIT 30
    LOOP

    IF live THEN
        _PUTIMAGE (0, 0), snap, CANVAS
        _FREEIMAGE snap
        '--- NOTE each on its own line. `Game_RenderHUD: Present` parses the
        '    name as a LABEL, not a call, and silently does nothing. ---
        cursor_erase
        cursor_draw
        Game_RenderHUD
        Present
    END IF
END SUB


SUB MdMouse
    DIM cx AS INTEGER, cy AS INTEGER
    WHILE _MOUSEINPUT: WEND
    cx = _MOUSEX \ CW
    cy = _MOUSEY \ CH
    IF _MOUSEBUTTON(1) THEN
        IF MD_CLICK = 0 THEN
            IF cx >= 0 _ANDALSO cy >= 0 _ANDALSO cx <= SW - 1 _ANDALSO cy <= SH - 1 THEN
                MD_SX = cx: MD_SY = cy
            END IF
            MD_CLICK = TRUE
        END IF
    ELSE
        MD_CLICK = FALSE
    END IF
END SUB


SUB MdAll (v AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO ML_N: ML_ON(i) = v: NEXT i
END SUB


SUB MdCell (cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG)
    IF k = 0 THEN EXIT SUB
    LINE (cx * CW, cy * CH)-(cx * CW + CW - 1, cy * CH + CH - 1), _
         _RGBA32(_RED32(k), _GREEN32(k), _BLUE32(k), MD_ALPHA), BF
END SUB


SUB MdBox (cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG)
    IF cx < 0 _ORELSE cy < 0 _ORELSE cx > SW - 1 _ORELSE cy > SH - 1 THEN EXIT SUB
    LINE (cx * CW, cy * CH)-(cx * CW + CW - 1, cy * CH + CH - 1), k, B
END SUB


SUB MdLegend
    DIM i AS INTEGER, col AS INTEGER, row AS INTEGER
    LINE (0, 0)-(SW * CW - 1, 3 * CH - 1), _RGBA32(0, 0, 0, 205), BF
    COLOR _RGB32(150, 200, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (4, 0), "MAP DEBUG"

    '--- laid out from the REGISTRY, so a host with four layers gets four keys
    '    and one with twelve gets twelve. The old version hardcoded nine
    '    positions, which is a second place to edit for every layer added. ---
    FOR i = 1 TO ML_N
        col = 14 + ((i - 1) MOD 8) * 14
        row = (i - 1) \ 8
        MdKey col, row, i, LTRIM$(STR$(i)) + " " + ML_NAME(i)
    NEXT i

    COLOR _RGB32(150, 150, 165), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (14 * CW, 2 * CH), "[0] art  [A] all  [N] none  [-/=] tint " + LTRIM$(STR$(MD_ALPHA)) + "  [click/arrows] cell  [E] event  [O] overlay  [C] chamber  [S] shot  [ESC]"
END SUB


SUB MdKey (col AS INTEGER, row AS INTEGER, n AS INTEGER, s AS STRING)
    IF ML_ON(n) THEN
        COLOR _RGB32(255, 232, 150), _RGBA32(0, 0, 0, 0)
    ELSE
        COLOR _RGB32(105, 105, 120), _RGBA32(0, 0, 0, 0)
    END IF
    _PRINTSTRING (col * CW, row * CH), s
END SUB


SUB DumpMapDebugShot (mask AS STRING, outp AS STRING)
    DIM i AS INTEGER, d AS LONG
    DIM rx1 AS INTEGER, ry1 AS INTEGER, rx2 AS INTEGER, ry2 AS INTEGER
    MapDebugInit
    MdAll FALSE
    MD_ART = TRUE
    MD_ALPHA = 110
    FOR i = 1 TO LEN(mask)
        IF MID$(mask, i, 1) >= "1" _ANDALSO MID$(mask, i, 1) <= "9" THEN IF VAL(MID$(mask, i, 1)) <= ML_N THEN ML_ON(VAL(MID$(mask, i, 1))) = TRUE
    NEXT i
    IF INSTR(LCASE$(COMMAND$), "event") > 0 THEN MD_SX = 16: MD_SY = 9
    IF INSTR(LCASE$(COMMAND$), "overlay") > 0 THEN MD_SX = 13: MD_SY = 9: MdScanArt: MD_PL_SCALE = 0.5: MD_PL_LIT = -1
    IF INSTR(LCASE$(COMMAND$), "chamber") > 0 THEN MD_SX = 24: MD_SY = 12: MD_RC1X = 13: MD_RC1Y = 7: MD_RC_SET = -1: MdEnsureLayer "chambers"
    MdDraw
    '--- "event" in the layer string also paints the EVENT panel, so the gate
    '    can see the one screen that only ever exists inside an input loop ---
    IF INSTR(LCASE$(COMMAND$), "event") > 0 THEN
        MdEventPaint 34, 8
    END IF
    IF INSTR(LCASE$(COMMAND$), "overlay") > 0 THEN MdOverlayPaint
    IF INSTR(LCASE$(COMMAND$), "chamber") > 0 THEN MdChamberPaint rx1, ry1, rx2, ry2
    _SAVEIMAGE outp, CANVAS
    d = _DEST: _DEST _CONSOLE
    PRINT PipeCol$("|15mapdebug|07 -- layers |14" + mask + "|07 -> |10" + outp + "|07")
    _DEST d
END SUB



FUNCTION MdArgMask$
    DIM i AS INTEGER, a AS STRING
    MdArgMask$ = "12"
    FOR i = 1 TO _COMMANDCOUNT
        a = COMMAND$(i)
        IF LEN(a) > 0 _ANDALSO LEN(a) <= 9 THEN
            IF MdAllDigits%(a) THEN MdArgMask$ = a
        END IF
    NEXT i
END FUNCTION


FUNCTION MdAllDigits% (a AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO LEN(a)
        IF MID$(a, i, 1) < "1" _ORELSE MID$(a, i, 1) > "9" THEN MdAllDigits% = 0: EXIT FUNCTION
    NEXT i
    MdAllDigits% = -1
END FUNCTION


FUNCTION MdArgOut$
    DIM i AS INTEGER, a AS STRING
    MdArgOut$ = "mapdebug.png"
    FOR i = 1 TO _COMMANDCOUNT
        a = COMMAND$(i)
        IF INSTR(LCASE$(a), ".png") > 0 THEN MdArgOut$ = a
    NEXT i
END FUNCTION



SUB MdRow (x AS INTEGER, y AS INTEGER, k AS STRING, s AS STRING, avail AS INTEGER)
    IF avail THEN
        COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H00, &H00, &H30)
    ELSE
        COLOR _RGB32(&H70, &H70, &H80), _RGB32(&H00, &H00, &H30)
    END IF
    _PRINTSTRING ((x + 3) * CW, y * CH), k + "   " + s
END SUB


SUB MdClampSel
    IF MD_SX < 0 THEN MD_SX = 0
    IF MD_SY < 0 THEN MD_SY = 0
    IF MD_SX > SW - 1 THEN MD_SX = SW - 1
    IF MD_SY > SH - 1 THEN MD_SY = SH - 1
END SUB


SUB MdScanArt
    MD_PL_N = 0
    MdScanArtDir AssetPackDir$("cutscenes", opt_datapack) + "art/"
    MdScanArtDir AssetPackDir$("cutscenes", "") + "art/"
    IF MD_PL_SEL < 1 THEN MD_PL_SEL = 1
    IF MD_PL_SEL > MD_PL_N THEN MD_PL_SEL = MD_PL_N
END SUB


SUB MdScanArtDir (dirpath AS STRING)
    DIM e AS STRING, lo AS STRING, i AS INTEGER, dup AS INTEGER
    IF _DIREXISTS(dirpath) = 0 THEN EXIT SUB
    e = _FILES$(dirpath)
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) <> "/" THEN
            lo = LCASE$(e)
            IF INSTR(lo, ".gif") > 0 _ORELSE INSTR(lo, ".png") > 0 THEN
                dup = 0
                FOR i = 1 TO MD_PL_N
                    IF LCASE$(MD_PL_ART(i)) = lo THEN dup = -1
                NEXT i
                IF dup = 0 _ANDALSO MD_PL_N < UBOUND(MD_PL_ART) THEN
                    MD_PL_N = MD_PL_N + 1
                    MD_PL_ART(MD_PL_N) = e
                END IF
            END IF
        END IF
        e = _FILES$
    LOOP
END SUB


FUNCTION MdScaleStep! (cur AS SINGLE, dir AS INTEGER)
    DIM v(1 TO 8) AS SINGLE, i AS INTEGER, at AS INTEGER
    v(1) = 0.25: v(2) = 0.5: v(3) = 0.75: v(4) = 1
    v(5) = 1.5: v(6) = 2: v(7) = 3: v(8) = 4
    at = 2
    FOR i = 1 TO 8
        IF ABS(v(i) - cur) < 0.01 THEN at = i
    NEXT i
    at = at + dir
    IF at < 1 THEN at = 1
    IF at > 8 THEN at = 8
    MdScaleStep! = v(at)
END FUNCTION


FUNCTION MdNum$ (v AS SINGLE)
    DIM s AS STRING
    s = LTRIM$(RTRIM$(STR$(v)))
    IF INSTR(s, ".") > 0 THEN
        DO WHILE RIGHT$(s, 1) = "0": s = LEFT$(s, LEN(s) - 1): LOOP
        IF RIGHT$(s, 1) = "." THEN s = LEFT$(s, LEN(s) - 1)
    END IF
    MdNum$ = s
END FUNCTION


FUNCTION MdMin% (a AS INTEGER, b AS INTEGER)
    IF a < b THEN MdMin% = a ELSE MdMin% = b
END FUNCTION


FUNCTION MdMax2% (a AS INTEGER, b AS INTEGER)
    IF a > b THEN MdMax2% = a ELSE MdMax2% = b
END FUNCTION


FUNCTION MdTypeIn$ (prompt AS STRING)
    DIM v AS STRING, k AS STRING, done AS INTEGER, py AS INTEGER
    DIM bg AS _UNSIGNED LONG
    bg = _RGB32(&H30, &H00, &H30)
    py = SH \ 2
    DO
        _LIMIT 60
        _DEST CANVAS
        LINE (20 * CW, (py - 2) * CH)-(112 * CW, (py + 2) * CH), bg, BF
        LINE (20 * CW, (py - 2) * CH)-(112 * CW, (py + 2) * CH), _RGB32(&H55, &HFF, &HFF), B
        COLOR _RGB32(&HFF, &HFF, &H55), bg
        _PRINTSTRING (22 * CW, (py - 1) * CH), prompt
        COLOR _RGB32(&HFF, &HFF, &HFF), bg
        _PRINTSTRING (22 * CW, (py + 1) * CH), v + CHR$(219)
        Present
        k = INKEY$
        IF LEN(k) = 1 THEN
            SELECT CASE ASC(k)
                CASE 13: done = TRUE
                CASE 27: MdTypeIn$ = "": EXIT FUNCTION
                CASE 8: IF LEN(v) > 0 THEN v = LEFT$(v, LEN(v) - 1)
                CASE ELSE
                    '--- a pipe would invent a column in a pipe-delimited file ---
                    IF ASC(k) >= 32 _ANDALSO k <> "|" _ANDALSO LEN(v) < 30 THEN v = v + k
            END SELECT
        END IF
    LOOP UNTIL done
    MdTypeIn$ = v
END FUNCTION


SUB MdEventMenu
    DIM k AS STRING, done AS INTEGER, i AS INTEGER
    DO
        _LIMIT 60
        MdDraw
        MdEventPaint 34, 8
        Present

        k = INKEY$
        IF k = CHR$(27) THEN EXIT SUB
        i = MdEvIndex%(k)
        IF i >= 1 _ANDALSO i <= MEV_N THEN
            IF MEV_LIVE(i) = 0 _ORELSE MD_LIVE THEN
                '--- the HOST fires it. Every row calls the routine gameplay
                '    calls; a test path that is its own code proves nothing
                '    about the real one. ---
                IF Game_MapEvent%(i, MD_SX, MD_SY) THEN EXIT SUB
            END IF
        END IF
    LOOP UNTIL done
END SUB


'--- the event panel's drawing, split from its input loop so a headless shot can
'    paint it: a screen that exists only inside its own loop can be checked by
'    nothing but a person looking at it. Every row comes from the REGISTRY. ---
SUB MdEventPaint (x AS INTEGER, y AS INTEGER)
    DIM bg AS _UNSIGNED LONG, i AS INTEGER, h AS INTEGER
    bg = _RGB32(&H00, &H00, &H30)
    _DEST CANVAS

    h = 14 + MEV_N * 2
    LINE (x * CW, y * CH)-((x + 64) * CW, (y + h) * CH), bg, BF
    LINE (x * CW, y * CH)-((x + 64) * CW, (y + h) * CH), _RGB32(&H55, &HFF, &HFF), B
    COLOR _RGB32(&HFF, &HFF, &H55), bg
    _PRINTSTRING ((x + 2) * CW, (y + 1) * CH), "-=  E V E N T   A T   " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY)) + "  =-"

    FOR i = 1 TO MEV_N
        MdRow x, y + 2 + i * 2, MdEvKey$(i), MEV_LABEL(i), (MEV_LIVE(i) = 0) _ORELSE MD_LIVE
    NEXT i

    COLOR _RGB32(&HAA, &HAA, &HAA), bg
    IF MD_LIVE = 0 THEN
        _PRINTSTRING ((x + 2) * CW, (y + h - 8) * CH), "greyed rows need a run in progress -- open this from [~] in game"
    END IF
    _PRINTSTRING ((x + 2) * CW, (y + h - 6) * CH), "the selected cell is the one boxed in white; click to move it"
    COLOR _RGB32(&HFF, &HFF, &H55), bg
    _PRINTSTRING ((x + 2) * CW, (y + h - 3) * CH), "[ESC] back"
END SUB

'--- 1-9 then A-... so a host may register more than nine events ---
FUNCTION MdEvKey$ (i AS INTEGER)
    IF i <= 9 THEN MdEvKey$ = LTRIM$(STR$(i)) ELSE MdEvKey$ = CHR$(64 + i - 9)
END FUNCTION

FUNCTION MdEvIndex% (k AS STRING)
    DIM code AS INTEGER    ' NOT `c` -- that shadows the shared cursor (audit-shadow)
    IF LEN(k) <> 1 THEN EXIT FUNCTION
    IF k >= "1" _ANDALSO k <= "9" THEN MdEvIndex% = VAL(k): EXIT FUNCTION
    code = ASC(UCASE$(k))
    IF code >= 65 _ANDALSO code <= 90 THEN MdEvIndex% = 9 + (code - 64)
END FUNCTION

'--- switch a named layer on, for the placement tools that depend on one ---
SUB MdEnsureLayer (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO ML_N
        IF LCASE$(ML_NAME(i)) = LCASE$(nm) THEN ML_ON(i) = TRUE: EXIT SUB
    NEXT i
END SUB



SUB MdPlaceOverlay
    DIM k AS STRING, done AS INTEGER

    MdScanArt
    IF MD_PL_N = 0 THEN MD_MSG = "no art in assets/cutscenes/*/art/": EXIT SUB
    IF MD_PL_SCALE <= 0 THEN MD_PL_SCALE = 0.5

    DO
        _LIMIT 60
        MdDraw
        MdOverlayPaint
        Present
        MdMouse

        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: MD_SY = MD_SY - 1
                CASE 80: MD_SY = MD_SY + 1
                CASE 75: MD_SX = MD_SX - 1
                CASE 77: MD_SX = MD_SX + 1
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            SELECT CASE LCASE$(k)
                CASE ",", "<": MD_PL_SEL = MD_PL_SEL - 1
                CASE ".", ">": MD_PL_SEL = MD_PL_SEL + 1
                CASE "-", "_": MD_PL_SCALE = MdScaleStep!(MD_PL_SCALE, -1)
                CASE "=", "+": MD_PL_SCALE = MdScaleStep!(MD_PL_SCALE, 1)
                CASE "l": MD_PL_LIT = NOT MD_PL_LIT
                CASE "x": MdDeleteOverlayHere
                CASE CHR$(13): MdWriteOverlay
                CASE CHR$(27): done = TRUE
            END SELECT
        END IF
        IF MD_PL_SEL < 1 THEN MD_PL_SEL = MD_PL_N
        IF MD_PL_SEL > MD_PL_N THEN MD_PL_SEL = 1
        MdClampSel
    LOOP UNTIL done
END SUB


SUB MdOverlayPaint
    DIM h AS LONG, pth AS STRING, bg AS _UNSIGNED LONG
    DIM w AS INTEGER, ht AS INTEGER, x AS INTEGER, y AS INTEGER, py AS INTEGER

    bg = _RGB32(&H00, &H00, &H30)
    _DEST CANVAS

    pth = Game_CutArtPath$(_TRIM$(MD_PL_ART(MD_PL_SEL)))
    IF LEN(pth) > 0 THEN
        h = Sprite&(pth)
        IF h < -1 THEN
            w = _WIDTH(h) * MD_PL_SCALE
            ht = _HEIGHT(h) * MD_PL_SCALE
            IF w > 0 _ANDALSO ht > 0 THEN
                x = MD_SX * CW + CW \ 2 - w \ 2
                y = MD_SY * CH + CH \ 2 - ht \ 2
                _PUTIMAGE (x, y)-(x + w - 1, y + ht - 1), h, CANVAS
            END IF
        END IF
    END IF

    '--- the panel sits low, so it is not over the cell you are aiming at ---
    py = SH - 14
    LINE (2 * CW, py * CH)-(52 * CW, (py + 11) * CH), bg, BF
    LINE (2 * CW, py * CH)-(52 * CW, (py + 11) * CH), _RGB32(&H55, &HFF, &HFF), B
    COLOR _RGB32(&HFF, &HFF, &H55), bg
    _PRINTSTRING (4 * CW, (py + 1) * CH), "-=  P L A C E   O V E R L A Y  =-"
    COLOR _RGB32(&HFF, &HFF, &HFF), bg
    _PRINTSTRING (4 * CW, (py + 3) * CH), "art    " + _TRIM$(MD_PL_ART(MD_PL_SEL)) + "  (" + LTRIM$(STR$(MD_PL_SEL)) + "/" + LTRIM$(STR$(MD_PL_N)) + ")"
    _PRINTSTRING (4 * CW, (py + 4) * CH), "cell   " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY)) + "   level " + LTRIM$(STR$(Game_MapZone%(MD_SX, MD_SY)))
    _PRINTSTRING (4 * CW, (py + 5) * CH), "scale  " + MdNum$(MD_PL_SCALE)
    IF MD_PL_LIT THEN
        _PRINTSTRING (4 * CW, (py + 6) * CH), "lit    1  (only once the cell has been seen)"
    ELSE
        _PRINTSTRING (4 * CW, (py + 6) * CH), "lit    0  (always drawn)"
    END IF
    COLOR _RGB32(&HAA, &HAA, &HAA), bg
    _PRINTSTRING (4 * CW, (py + 8) * CH), "[,/.] art   [-/=] scale   [L] lit   [arrows/click] cell"
    _PRINTSTRING (4 * CW, (py + 9) * CH), "[ENTER] write the row   [X] delete the one here   [ESC] back"
END SUB


SUB MdPlaceChamber
    DIM k AS STRING, done AS INTEGER
    DIM x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER

    MD_RC_SET = 0
    DO
        _LIMIT 60
        MdEnsureLayer "chambers"            ' you cannot judge a rect without the layer it feeds
        MdDraw
        MdChamberPaint x1, y1, x2, y2
        Present
        MdMouse

        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: MD_SY = MD_SY - 1
                CASE 80: MD_SY = MD_SY + 1
                CASE 75: MD_SX = MD_SX - 1
                CASE 77: MD_SX = MD_SX + 1
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            SELECT CASE LCASE$(k)
                CASE CHR$(13)
                    IF MD_RC_SET THEN
                        MdWriteChamber x1, y1, x2, y2
                        MD_RC_SET = 0
                    ELSE
                        MD_RC1X = MD_SX: MD_RC1Y = MD_SY: MD_RC_SET = -1
                    END IF
                CASE "x": MdDeleteChamberHere
                CASE CHR$(27)
                    IF MD_RC_SET THEN MD_RC_SET = 0 ELSE done = TRUE
            END SELECT
        END IF
        MdClampSel
    LOOP UNTIL done
END SUB


SUB MdChamberPaint (x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER)
    DIM bg AS _UNSIGNED LONG, py AS INTEGER

    bg = _RGB32(&H00, &H00, &H30)
    _DEST CANVAS

    IF MD_RC_SET THEN
        x1 = MdMin%(MD_RC1X, MD_SX): x2 = MdMax2%(MD_RC1X, MD_SX)
        y1 = MdMin%(MD_RC1Y, MD_SY): y2 = MdMax2%(MD_RC1Y, MD_SY)
        LINE (x1 * CW, y1 * CH)-((x2 + 1) * CW - 1, (y2 + 1) * CH - 1), _RGBA32(255, 120, 255, 70), BF
        LINE (x1 * CW, y1 * CH)-((x2 + 1) * CW - 1, (y2 + 1) * CH - 1), _RGB32(255, 255, 255), B
    END IF

    py = SH - 12
    LINE (2 * CW, py * CH)-(66 * CW, (py + 9) * CH), bg, BF
    LINE (2 * CW, py * CH)-(66 * CW, (py + 9) * CH), _RGB32(&H55, &HFF, &HFF), B
    COLOR _RGB32(&HFF, &HFF, &H55), bg
    _PRINTSTRING (4 * CW, (py + 1) * CH), "-=  C H A M B E R   R E C T A N G L E  =-"
    COLOR _RGB32(&HFF, &HFF, &HFF), bg
    IF MD_RC_SET THEN
        _PRINTSTRING (4 * CW, (py + 3) * CH), "rect   " + LTRIM$(STR$(x1)) + "," + LTRIM$(STR$(y1)) + "  ->  " + LTRIM$(STR$(x2)) + "," + LTRIM$(STR$(y2))
        _PRINTSTRING (4 * CW, (py + 4) * CH), "move to the far corner, then [ENTER] to name it"
    ELSE
        _PRINTSTRING (4 * CW, (py + 3) * CH), "cell   " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY))
        _PRINTSTRING (4 * CW, (py + 4) * CH), "[ENTER] drops the first corner here"
    END IF
    COLOR _RGB32(&HAA, &HAA, &HAA), bg
    _PRINTSTRING (4 * CW, (py + 6) * CH), "[arrows/click] cell   [X] delete the chamber here   [ESC] back"
    _PRINTSTRING (4 * CW, (py + 7) * CH), "keep boxes tight -- every walkable cell inside becomes a trigger"
END SUB


'--- Everything the game believes about the SELECTED cell, in one line. The
'    engine contributes the coordinate; every other fact is the host's, because
'    only the host knows what a room or a chamber is. ---
SUB MdReadout
    DIM s AS STRING

    IF MD_SX < 0 _ORELSE MD_SY < 0 _ORELSE MD_SX > SW - 1 _ORELSE MD_SY > SH - 1 THEN EXIT SUB
    s = "cell " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY)) + "   " + Game_MapReadout$(MD_SX, MD_SY)
    IF LEN(MD_MSG) > 0 THEN s = s + "    " + MD_MSG

    LINE (0, (SH - 1) * CH)-(SW * CW - 1, SH * CH - 1), _RGBA32(0, 0, 0, 215), BF
    COLOR _RGB32(200, 230, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (4, (SH - 1) * CH), s
END SUB


SUB MdDraw
    DIM cx AS INTEGER, cy AS INTEGER, i AS INTEGER

    _DEST CANVAS
    IF MD_ART THEN
        _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    ELSE
        CLS , _RGB32(0, 0, 0)
    END IF

    '--- Every layer the HOST registered, in order, back to front. The engine
    '    knows none of their names: a CELL layer is whatever the game put in the
    '    buffer, a MARK layer draws itself. ---
    FOR i = 1 TO ML_N
        IF ML_ON(i) = 0 THEN _CONTINUE
        IF ML_KIND(i) = ML_CELL THEN
            MapClearBuf
            Game_MapLayerFill i
            FOR cy = 0 TO SH - 1
                FOR cx = 0 TO SW - 1
                    IF ML_BUF(cx, cy) <> 0 THEN MdCell cx, cy, ML_BUF(cx, cy)
                NEXT cx
            NEXT cy
        ELSE
            Game_MapLayerMarks i
        END IF
    NEXT i

    '--- the selected cell, drawn last so no layer can hide it ---
    LINE (MD_SX * CW - 1, MD_SY * CH - 1)-(MD_SX * CW + CW, MD_SY * CH + CH), _RGB32(255, 255, 255), B
    LINE (MD_SX * CW - 2, MD_SY * CH - 2)-(MD_SX * CW + CW + 1, MD_SY * CH + CH + 1), _RGB32(0, 0, 0), B

    MdLegend
    MdReadout
END SUB


'--- Choosing and playing a scene is the HOST's: the roster, the titles and
'    what "seen" means all belong to the cut-scene layer the game assembles.
'    The engine only offers the row. ---
SUB MdScenePicker
    Game_MapScenePick
END SUB


SUB MdWriteOverlay
    DIM path AS STRING, f AS INTEGER, row AS STRING
    path = MdDataPath$("overlays.txt")
    row = LTRIM$(STR$(Game_MapZone%(MD_SX, MD_SY))) + " | " + LTRIM$(STR$(MD_SX)) + " | " + LTRIM$(STR$(MD_SY))
    row = row + " | " + _TRIM$(MD_PL_ART(MD_PL_SEL)) + " | " + MdNum$(MD_PL_SCALE) + " | "
    IF MD_PL_LIT THEN row = row + "1" ELSE row = row + "0"

    f = FREEFILE
    OPEN path FOR APPEND AS #f
    PRINT #f, row
    CLOSE #f
    Game_MapReload 1                        ' show the consequence, not the intention
    MD_MSG = "wrote: " + row
END SUB


SUB MdDeleteOverlayHere
    DIM path AS STRING, r AS INTEGER, hit AS INTEGER
    path = MdDataPath$("overlays.txt")
    DeLoad path
    FOR r = 1 TO DE_NROW
        IF VAL(DeField$(r, 2)) = MD_SX _ANDALSO VAL(DeField$(r, 3)) = MD_SY THEN
            DE_CUR = r
            DeDeleteRow
            hit = -1
            EXIT FOR
        END IF
    NEXT r
    IF hit THEN
        DeSave
        Game_MapReload 1
        MD_MSG = "deleted the overlay at " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY))
    ELSE
        MD_MSG = "no overlay at that cell"
    END IF
END SUB


FUNCTION MdDataPath$ (nm AS STRING)
    DIM p AS STRING
    p = AssetPackDir$("data", opt_datapack) + nm
    IF _FILEEXISTS(p) THEN MdDataPath$ = p ELSE MdDataPath$ = AssetPackDir$("data", "") + nm
END FUNCTION


SUB MdWriteChamber (x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER)
    DIM nm AS STRING, path AS STRING, f AS INTEGER, row AS STRING
    nm = MdTypeIn$("Name this chamber")
    IF LEN(_TRIM$(nm)) = 0 THEN MD_MSG = "cancelled -- an unnamed chamber is not a chamber": EXIT SUB

    path = MdDataPath$("chambers.txt")
    row = _TRIM$(nm) + " | " + LTRIM$(STR$(x1)) + " | " + LTRIM$(STR$(y1)) + " | " + LTRIM$(STR$(x2)) + " | " + LTRIM$(STR$(y2))
    f = FREEFILE
    OPEN path FOR APPEND AS #f
    PRINT #f, row
    CLOSE #f

    '--- re-derive, so layer 6 shows what the rect actually claimed rather than
    '    what it was meant to. Note this rebuilds CHAMBERAT from scratch, which
    '    resets a live run's per-chamber kill progress -- fine while authoring,
    '    which is the only time this screen is open. ---
    Game_MapReload 2
    MD_MSG = "wrote: " + row + "   (regions re-derived)"
END SUB


SUB MdDeleteChamberHere
    DIM path AS STRING, r AS INTEGER, hit AS INTEGER
    DIM x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER
    path = MdDataPath$("chambers.txt")
    DeLoad path
    FOR r = 1 TO DE_NROW
        x1 = VAL(DeField$(r, 2)): y1 = VAL(DeField$(r, 3))
        x2 = VAL(DeField$(r, 4)): y2 = VAL(DeField$(r, 5))
        IF MD_SX >= MdMin%(x1, x2) _ANDALSO MD_SX <= MdMax2%(x1, x2) THEN
            IF MD_SY >= MdMin%(y1, y2) _ANDALSO MD_SY <= MdMax2%(y1, y2) THEN
                MD_MSG = "deleted chamber " + DeField$(r, 1)
                DE_CUR = r
                DeDeleteRow
                hit = -1
                EXIT FOR
            END IF
        END IF
    NEXT r
    IF hit THEN
        DeSave
        Game_MapReload 2
    ELSE
        MD_MSG = "no chamber rectangle covers that cell"
    END IF
END SUB


