' ============================================================================
'  game/MAPDEBUG.bas -- the MAP DEBUGGER: every derived layer, toggleable.
'
'      dungeon.run mapdebug
'
'  The board is the map: rooms, sectors, doors, chambers and secret regions are
'  all DERIVED by scanning the art, and each derivation has its own dump mode
'  that writes a PNG. Those answer "is it right" one question at a time, in
'  separate files, from a cold start.
'
'  This answers them together, on one screen, live -- because the questions are
'  almost always about a RELATIONSHIP: is this room's cell inside the sector the
'  mask claims? Does that door open the region next to it? Is the trigger cell
'  the walkable one or the wall beside it? Flipping two layers on top of each
'  other answers that in a second; two PNGs and a memory does not.
'
'  Every layer here reads the SAME arrays the game reads. Nothing is recomputed
'  for display, so what you see is what movement, fog and combat will see -- a
'  debugger that derives its own answer can agree with itself and still be
'  wrong about the game.
' ============================================================================

CONST MD_LAYERS = 9

SUB DumpMapDebug
    DIM k AS STRING, i AS INTEGER, quit AS INTEGER
    DIM mx AS INTEGER, my AS INTEGER

    '--- everything on by default would be mud; start with the two that answer
    '    "where can I stand" and "which level is this". ---
    MD_ON(1) = TRUE                     ' sectors
    MD_ON(2) = TRUE                     ' walkable
    MD_ART = TRUE
    MD_ALPHA = 110

    DO
        MdDraw
        Present

        k = INKEY$
        IF LEN(k) = 1 THEN
            IF k >= "1" _ANDALSO k <= "9" THEN MD_ON(VAL(k)) = NOT MD_ON(VAL(k))
            SELECT CASE LCASE$(k)
                CASE "0": MD_ART = NOT MD_ART
                CASE "a": MdAll TRUE
                CASE "n": MdAll FALSE
                CASE "-", "_": MD_ALPHA = MD_ALPHA - 20: IF MD_ALPHA < 30 THEN MD_ALPHA = 30
                CASE "=", "+": MD_ALPHA = MD_ALPHA + 20: IF MD_ALPHA > 240 THEN MD_ALPHA = 240
                CASE "s": _SAVEIMAGE "mapdebug.png", CANVAS
                CASE CHR$(27): quit = TRUE
            END SELECT
        END IF
        IF quit THEN EXIT DO
        _LIMIT 30
    LOOP
END SUB

SUB MdAll (v AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO MD_LAYERS: MD_ON(i) = v: NEXT i
END SUB

' ----------------------------------------------------------------------------
'  One frame
' ----------------------------------------------------------------------------
SUB MdDraw
    DIM cx AS INTEGER, cy AS INTEGER, i AS INTEGER

    _DEST CANVAS
    IF MD_ART THEN
        _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    ELSE
        CLS , _RGB32(0, 0, 0)
    END IF

    '--- per-cell tints, back to front ---
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF MD_ON(1) THEN MdCell cx, cy, MdSectorColor~&(SECTORAT(cx, cy))
            IF MD_ON(2) THEN
                IF CellKind%(cx, cy) <> 0 THEN MdCell cx, cy, _RGB32(40, 220, 90)
            END IF
            IF MD_ON(3) THEN
                IF ROOMAT(cx, cy) <> 0 THEN MdCell cx, cy, MdRoomColor~&(ROOMAT(cx, cy))
            END IF
            IF MD_ON(4) THEN MdCell cx, cy, MdKindColor~&(ROOMKIND(cx, cy))
            IF MD_ON(6) THEN
                IF CHAMBERAT(cx, cy) <> 0 THEN MdCell cx, cy, _RGB32(255, 120, 255)
            END IF
            IF MD_ON(7) THEN
                IF SECRET(cx, cy) <> 0 THEN MdCell cx, cy, _RGB32(90, 90, 255)
            END IF
        NEXT cx
    NEXT cy

    '--- doors are points, not regions ---
    IF MD_ON(5) THEN
        FOR i = 1 TO DOOR_N
            IF DOOR_STRONG(i) THEN
                MdBox DOOR_X(i), DOOR_Y(i), _RGB32(255, 160, 40)
            ELSE
                MdBox DOOR_X(i), DOOR_Y(i), _RGB32(190, 120, 60)
            END IF
        NEXT i
    END IF

    '--- the data files that place things ON the board ---
    IF MD_ON(8) THEN
        FOR i = 1 TO TRIG_N
            MdBox TRIG_COL(i), TRIG_ROW(i), _RGB32(255, 80, 80)
        NEXT i
        FOR i = 1 TO OVL_N
            MdBox OVL_COL(i), OVL_ROW(i), _RGB32(120, 220, 255)
        NEXT i
    END IF

    '--- room/chamber markers, so a grave sitting in a doorway is visible ---
    IF MD_ON(9) THEN
        FOR i = 1 TO ROOM_N
            IF ROOMS(i).cx >= 0 THEN MdBox ROOMS(i).cx, ROOMS(i).cy, _RGB32(255, 255, 255)
        NEXT i
    END IF

    MdLegend
    MdReadout
END SUB

'--- a translucent tint over one cell. Translucent on purpose: the whole point
'    is seeing a layer AGAINST the art and against the other layers. ---
SUB MdCell (cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG)
    IF k = 0 THEN EXIT SUB
    LINE (cx * CW, cy * CH)-(cx * CW + CW - 1, cy * CH + CH - 1), _
         _RGBA32(_RED32(k), _GREEN32(k), _BLUE32(k), MD_ALPHA), BF
END SUB

'--- an outline, for things that are a POINT rather than an area ---
SUB MdBox (cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG)
    IF cx < 0 _ORELSE cy < 0 _ORELSE cx > SW - 1 _ORELSE cy > SH - 1 THEN EXIT SUB
    LINE (cx * CW, cy * CH)-(cx * CW + CW - 1, cy * CH + CH - 1), k, B
END SUB

FUNCTION MdSectorColor~& (s AS INTEGER)
    IF s < 1 _ORELSE s > 9 THEN MdSectorColor~& = 0: EXIT FUNCTION
    MdSectorColor~& = SECTORS(s).kolor
END FUNCTION

'--- rooms cycle a small palette: adjacent rooms differing is what matters,
'    not which colour any one room gets ---
FUNCTION MdRoomColor~& (r AS INTEGER)
    SELECT CASE r MOD 6
        CASE 0: MdRoomColor~& = _RGB32(255, 90, 90)
        CASE 1: MdRoomColor~& = _RGB32(90, 255, 140)
        CASE 2: MdRoomColor~& = _RGB32(120, 160, 255)
        CASE 3: MdRoomColor~& = _RGB32(255, 220, 90)
        CASE 4: MdRoomColor~& = _RGB32(255, 130, 255)
        CASE ELSE: MdRoomColor~& = _RGB32(120, 255, 255)
    END SELECT
END FUNCTION

'--- the three answers to "is this a room cell", which is the distinction that
'    strands a monster on a cell nothing can stand on ---
FUNCTION MdKindColor~& (k AS INTEGER)
    SELECT CASE k
        CASE CRK_FLOOR: MdKindColor~& = _RGB32(60, 255, 60)
        CASE CRK_DOOR: MdKindColor~& = _RGB32(255, 200, 60)
        CASE CRK_MIXED: MdKindColor~& = _RGB32(255, 60, 60)
        CASE ELSE: MdKindColor~& = 0
    END SELECT
END FUNCTION

' ----------------------------------------------------------------------------
'  Chrome
' ----------------------------------------------------------------------------
SUB MdLegend
    DIM y AS INTEGER
    LINE (0, 0)-(SW * CW - 1, 3 * CH - 1), _RGBA32(0, 0, 0, 205), BF
    COLOR _RGB32(150, 200, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (4, 0), "MAP DEBUG"

    MdKey 14, 0, 1, "1 sectors"
    MdKey 28, 0, 2, "2 walkable"
    MdKey 43, 0, 3, "3 rooms"
    MdKey 56, 0, 4, "4 roomkind"
    MdKey 71, 0, 5, "5 doors"
    MdKey 84, 0, 6, "6 chambers"
    MdKey 99, 0, 7, "7 secret"
    MdKey 112, 0, 8, "8 trig/ovl"
    MdKey 14, 1, 9, "9 markers"

    COLOR _RGB32(150, 150, 165), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (28 * CW, CH), "[0] art  [A] all  [N] none  [-/=] tint " + LTRIM$(STR$(MD_ALPHA)) + "  [S] shot  [ESC]"
END SUB

SUB MdKey (col AS INTEGER, row AS INTEGER, n AS INTEGER, s AS STRING)
    IF MD_ON(n) THEN
        COLOR _RGB32(255, 232, 150), _RGBA32(0, 0, 0, 0)
    ELSE
        COLOR _RGB32(105, 105, 120), _RGBA32(0, 0, 0, 0)
    END IF
    _PRINTSTRING (col * CW, row * CH), s
END SUB

'--- Everything the game believes about the cell under the pointer, in one
'    line. This is the part a PNG cannot do. ---
SUB MdReadout
    DIM cx AS INTEGER, cy AS INTEGER, s AS STRING, i AS INTEGER

    cx = _MOUSEX \ CW
    cy = _MOUSEY \ CH
    WHILE _MOUSEINPUT: WEND
    cx = _MOUSEX \ CW
    cy = _MOUSEY \ CH
    IF cx < 0 _ORELSE cy < 0 _ORELSE cx > SW - 1 _ORELSE cy > SH - 1 THEN EXIT SUB

    s = "cell " + LTRIM$(STR$(cx)) + "," + LTRIM$(STR$(cy))
    s = s + "   lvl " + LTRIM$(STR$(SECTORAT(cx, cy)))
    IF CellKind%(cx, cy) = 0 THEN s = s + "   SOLID" ELSE s = s + "   walkable"
    IF ROOMAT(cx, cy) <> 0 THEN s = s + "   room " + LTRIM$(STR$(ROOMAT(cx, cy)))
    IF CHAMBERAT(cx, cy) <> 0 THEN s = s + "   chamber " + _TRIM$(CHM_NAME(CHAMBERAT(cx, cy)))
    IF SECRET(cx, cy) <> 0 THEN s = s + "   SECRET"
    SELECT CASE ROOMKIND(cx, cy)
        CASE CRK_FLOOR: s = s + "   floor"
        CASE CRK_DOOR: s = s + "   doorway"
        CASE CRK_MIXED: s = s + "   decoration"
    END SELECT
    FOR i = 1 TO TRIG_N
        IF TRIG_COL(i) = cx _ANDALSO TRIG_ROW(i) = cy THEN s = s + "   trigger:" + _TRIM$(TRIG_SCENE(i))
    NEXT i
    FOR i = 1 TO OVL_N
        IF OVL_COL(i) = cx _ANDALSO OVL_ROW(i) = cy THEN s = s + "   overlay:" + _TRIM$(OVL_ART(i))
    NEXT i

    LINE (0, (SH - 1) * CH)-(SW * CW - 1, SH * CH - 1), _RGBA32(0, 0, 0, 215), BF
    COLOR _RGB32(200, 230, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (4, (SH - 1) * CH), s
END SUB

'--- headless: draw one frame with a given layer set and save it, so the
'    debugger itself can be checked by looking at what it drew ---
SUB DumpMapDebugShot (mask AS STRING, outp AS STRING)
    DIM i AS INTEGER, d AS LONG
    MdAll FALSE
    MD_ART = TRUE
    MD_ALPHA = 110
    FOR i = 1 TO LEN(mask)
        IF MID$(mask, i, 1) >= "1" _ANDALSO MID$(mask, i, 1) <= "9" THEN MD_ON(VAL(MID$(mask, i, 1))) = TRUE
    NEXT i
    MdDraw
    _SAVEIMAGE outp, CANVAS
    d = _DEST: _DEST _CONSOLE
    PRINT PipeCol$("|15mapdebug|07 -- layers |14" + mask + "|07 -> |10" + outp + "|07")
    _DEST d
END SUB


'--- `mapdebugshot 1234 out.png` -- the digits are the layers to switch on ---
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
