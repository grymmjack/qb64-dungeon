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
    MapDebugScreen 0
END SUB

' ----------------------------------------------------------------------------
'  The screen. `live` = there is a run in progress behind it, which is what
'  makes the EVENT menu mean anything: firing a curio with no player, no level
'  and no HP would be a demo of the menu, not a test of the curio.
'
'  When live it photographs CANVAS on entry and puts it back on exit, the same
'  trick the dev console uses -- so it can be opened over the board without
'  knowing anything about what was drawn there.
' ----------------------------------------------------------------------------
SUB MapDebugScreen (live AS INTEGER)
    DIM k AS STRING, quit AS INTEGER, snap AS LONG

    MD_LIVE = live
    IF MD_ON(1) = 0 _ANDALSO MD_ON(2) = 0 _ANDALSO MD_ON(3) = 0 THEN
        '--- everything on at once would be mud; start with the two that answer
        '    "where can I stand" and "which level is this". ---
        MD_ON(1) = TRUE
        MD_ON(2) = TRUE
        MD_ART = TRUE
        MD_ALPHA = 110
    END IF
    IF MD_ALPHA = 0 THEN MD_ALPHA = 110

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
            IF k >= "1" _ANDALSO k <= "9" THEN MD_ON(VAL(k)) = NOT MD_ON(VAL(k))
            SELECT CASE LCASE$(k)
                CASE "0": MD_ART = NOT MD_ART
                CASE "a": MdAll TRUE
                CASE "n": MdAll FALSE
                CASE "-", "_": MD_ALPHA = MD_ALPHA - 20: IF MD_ALPHA < 30 THEN MD_ALPHA = 30
                CASE "=", "+": MD_ALPHA = MD_ALPHA + 20: IF MD_ALPHA > 240 THEN MD_ALPHA = 240
                CASE "s": _SAVEIMAGE "mapdebug.png", CANVAS: MD_MSG = "wrote mapdebug.png"
                CASE "e": MdEventMenu
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
        cursor_erase: cursor_draw: DrawHUD: Present
    END IF
END SUB

'--- left-click picks the cell. Debounced, so one press is one pick. ---
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

    '--- the selected cell, drawn last so no layer can hide it ---
    LINE (MD_SX * CW - 1, MD_SY * CH - 1)-(MD_SX * CW + CW, MD_SY * CH + CH), _RGB32(255, 255, 255), B
    LINE (MD_SX * CW - 2, MD_SY * CH - 2)-(MD_SX * CW + CW + 1, MD_SY * CH + CH + 1), _RGB32(0, 0, 0), B

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
    _PRINTSTRING (28 * CW, CH), "[0] art  [A] all  [N] none  [-/=] tint " + LTRIM$(STR$(MD_ALPHA)) + "  [click/arrows] pick cell  [E] EVENT  [S] shot  [ESC]"
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

    '--- the SELECTED cell, not the pointer. The pointer moves the moment you
    '    reach for a key, and a readout that changes while you read it is
    '    useless; click to move the selection instead. ---
    cx = MD_SX
    cy = MD_SY
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

    IF LEN(MD_MSG) > 0 THEN s = s + "    " + MD_MSG

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
    IF INSTR(LCASE$(COMMAND$), "event") > 0 THEN MD_SX = 16: MD_SY = 9
    MdDraw
    '--- "event" in the layer string also paints the EVENT panel, so the gate
    '    can see the one screen that only ever exists inside an input loop ---
    IF INSTR(LCASE$(COMMAND$), "event") > 0 THEN
        MdEventPaint ROOMAT(MD_SX, MD_SY), CHAMBERAT(MD_SX, MD_SY), 34, 8
    END IF
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


' ============================================================================
'  THE EVENT MENU -- fire a real game event AT the selected cell.
'
'  The map debugger already answers "what does the game think is here". The
'  other half of a board question is "and what happens when the player is
'  there", which until now meant walking across the dungeon to find out --
'  or, for a cut-scene trigger, walking to a cell whose coordinates you were
'  trying to establish in the first place.
'
'  Every row calls the SAME routine gameplay calls. Nothing here re-implements
'  an encounter: a curio spawned from this menu goes through DoCurio, so it
'  rolls the same table, plays the same sound and feeds the same chronicle. A
'  test path that is its own code proves nothing about the real one.
'
'  Rows that need a live run say so and refuse rather than half-working -- with
'  no player there is no level, no HP and no gold, and a "curio" fired into
'  that is a picture of a menu working.
' ============================================================================
SUB MdEventMenu
    DIM k AS STRING, done AS INTEGER, rm AS INTEGER, cid AS INTEGER
    DIM bg AS _UNSIGNED LONG, x AS INTEGER, y AS INTEGER, i AS INTEGER

    bg = _RGB32(&H00, &H00, &H30)
    x = 34: y = 8
    DO
        _LIMIT 60
        MdDraw
        _DEST CANVAS
        rm = ROOMAT(MD_SX, MD_SY)
        cid = CHAMBERAT(MD_SX, MD_SY)

        MdEventPaint rm, cid, x, y
        Present

        k = INKEY$
        SELECT CASE k
            CASE "1": IF MD_LIVE THEN MdTeleport: done = TRUE
            CASE "2": IF MD_LIVE THEN MdFire 2, rm, cid: done = TRUE
            CASE "3": IF MD_LIVE THEN MdFire 3, rm, cid: done = TRUE
            CASE "4": IF MD_LIVE THEN MdFire 4, rm, cid: done = TRUE
            CASE "5": IF MD_LIVE _ANDALSO rm > 0 THEN MdFire 5, rm, cid: done = TRUE
            CASE "6": IF MD_LIVE _ANDALSO cid > 0 THEN MdFire 6, rm, cid: done = TRUE
            CASE "7": MdScenePicker
            CASE "8": MdRevealHere
            CASE "9": MdWriteTrigger
            CASE CHR$(27): done = TRUE
        END SELECT
    LOOP UNTIL done
END SUB

'--- a menu row that can be unavailable. Greyed rather than hidden: a row that
'    vanishes reads as a missing feature, one that greys reads as a state. ---
SUB MdRow (x AS INTEGER, y AS INTEGER, k AS STRING, s AS STRING, avail AS INTEGER)
    IF avail THEN
        COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H00, &H00, &H30)
    ELSE
        COLOR _RGB32(&H70, &H70, &H80), _RGB32(&H00, &H00, &H30)
    END IF
    _PRINTSTRING ((x + 3) * CW, y * CH), k + "   " + s
END SUB

'--- put the player on the selected cell, exactly as the [~] overlay's click
'    does. The board is repainted around the new position by the caller. ---
SUB MdTeleport
    c.x = MD_SX * CW
    c.y = MD_SY * CH
    SeedPlayerLevel c.x, c.y
    MD_MSG = "teleported to " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY))
END SUB

'--- Fire the real thing. The player is moved to the cell first, because every
'    one of these reads the player's position for its level, its flavour text
'    and its chronicle entry -- firing a level-9 room's monster while standing
'    on level 1 would be a different event wearing the same name. ---
SUB MdFire (what AS INTEGER, rm AS INTEGER, cid AS INTEGER)
    DIM res AS INTEGER
    c.x = MD_SX * CW
    c.y = MD_SY * CH
    SeedPlayerLevel c.x, c.y
    cursor_erase: cursor_draw: DrawHUD: Present

    SELECT CASE what
        CASE 2: DoCurio 0
        CASE 3: WanderEncounter
        CASE 4: SpringTrap rm
        CASE 5: res = DoCombat%(rm)
        CASE 6: ChamberEncounter cid
    END SELECT
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB

'--- Play any scene in the pack, from the map. The roster is the Storybook's,
'    so a pack that ships its own scenes gets them here for free. ---
SUB MdScenePicker
    DIM k AS STRING, sel AS INTEGER, done AS INTEGER, i AS INTEGER, y AS INTEGER
    DIM bg AS _UNSIGNED LONG, played AS INTEGER

    StorybookScan
    IF STORY_N = 0 THEN MD_MSG = "no cut-scenes in this pack": EXIT SUB
    bg = _RGB32(&H00, &H00, &H30)
    sel = 1
    DO
        _LIMIT 60
        _DEST CANVAS
        LINE (30 * CW, 4 * CH)-(102 * CW, (7 + STORY_N) * CH), bg, BF
        LINE (30 * CW, 4 * CH)-(102 * CW, (7 + STORY_N) * CH), _RGB32(&H55, &HFF, &HFF), B
        COLOR _RGB32(&HFF, &HFF, &H55), bg
        _PRINTSTRING (34 * CW, 5 * CH), "-=  P L A Y   A   C U T - S C E N E  =-"
        FOR i = 1 TO STORY_N
            y = 6 + i
            IF i = sel THEN
                COLOR _RGB32(&HFF, &HFF, &HFF), bg
                _PRINTSTRING (33 * CW, y * CH), CHR$(16) + " " + _TRIM$(STORY_NAME(i))
            ELSE
                COLOR _RGB32(&HA0, &HA8, &HB8), bg
                _PRINTSTRING (35 * CW, y * CH), _TRIM$(STORY_NAME(i))
            END IF
        NEXT i
        Present
        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: sel = sel - 1
                CASE 80: sel = sel + 1
            END SELECT
        ELSEIF k = CHR$(13) THEN
            played = PlayCutscene%(_TRIM$(STORY_NAME(sel)))
            IF played THEN MD_MSG = "played " + _TRIM$(STORY_NAME(sel)) ELSE MD_MSG = "scene would not play: " + _TRIM$(STORY_NAME(sel))
            done = TRUE
        ELSEIF k = CHR$(27) THEN
            done = TRUE
        END IF
        IF sel < 1 THEN sel = STORY_N
        IF sel > STORY_N THEN sel = 1
    LOOP UNTIL done
END SUB

'--- Reveal whatever secret region the selected cell belongs to, by finding the
'    door that opens it. Going through RevealRegionFromDoor rather than painting
'    the cells directly is the point: a revealed door must become WALKABLE, not
'    merely visible, and only the real routine does all three images. ---
SUB MdRevealHere
    DIM i AS INTEGER, reg AS INTEGER, n AS INTEGER
    IF SECRET(MD_SX, MD_SY) = 0 THEN MD_MSG = "no secret region at that cell": EXIT SUB
    reg = MASKREG(MD_SX, MD_SY)
    FOR i = 1 TO SD_N
        IF DOOR_REGION(i) = reg _ANDALSO reg > 0 THEN
            IF SD_FOUND(i) = 0 THEN SD_FOUND(i) = -1: RevealRegionFromDoor i: n = n + 1
        END IF
    NEXT i
    IF n > 0 THEN
        MD_MSG = "revealed region " + LTRIM$(STR$(reg)) + " via " + LTRIM$(STR$(n)) + " door(s)"
    ELSE
        MD_MSG = "region " + LTRIM$(STR$(reg)) + " has NO door -- unreachable (see fogdump)"
    END IF
END SUB

'--- Append a trigger row for the selected cell to the pack's triggers.txt.
'
'    This is the loop that was actually painful: to place a cut-scene on the
'    board you needed the cell's coordinates, and to get those you walked there
'    with the overlay on and copied two numbers into a file by hand. Here the
'    cell is already selected and its level is already known, so the row writes
'    itself -- and it goes in as TEXT, appended, so the file stays exactly as
'    hand-editable as it was.
SUB MdWriteTrigger
    DIM path AS STRING, f AS INTEGER, row AS STRING, lvl AS INTEGER
    DIM k AS STRING, sel AS INTEGER, done AS INTEGER, i AS INTEGER, y AS INTEGER
    DIM bg AS _UNSIGNED LONG

    StorybookScan
    IF STORY_N = 0 THEN MD_MSG = "no cut-scenes in this pack": EXIT SUB
    bg = _RGB32(&H00, &H00, &H30)
    sel = 1
    DO
        _LIMIT 60
        _DEST CANVAS
        LINE (30 * CW, 4 * CH)-(102 * CW, (8 + STORY_N) * CH), bg, BF
        LINE (30 * CW, 4 * CH)-(102 * CW, (8 + STORY_N) * CH), _RGB32(&H55, &HFF, &HFF), B
        COLOR _RGB32(&HFF, &HFF, &H55), bg
        _PRINTSTRING (34 * CW, 5 * CH), "-=  T R I G G E R   A T   " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY)) + "  =-"
        FOR i = 1 TO STORY_N
            y = 6 + i
            IF i = sel THEN
                COLOR _RGB32(&HFF, &HFF, &HFF), bg
                _PRINTSTRING (33 * CW, y * CH), CHR$(16) + " " + _TRIM$(STORY_NAME(i))
            ELSE
                COLOR _RGB32(&HA0, &HA8, &HB8), bg
                _PRINTSTRING (35 * CW, y * CH), _TRIM$(STORY_NAME(i))
            END IF
        NEXT i
        COLOR _RGB32(&HAA, &HAA, &HAA), bg
        _PRINTSTRING (33 * CW, (7 + STORY_N) * CH), "[ENTER] append the row   [ESC] cancel"
        Present
        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: sel = sel - 1
                CASE 80: sel = sel + 1
            END SELECT
        ELSEIF k = CHR$(13) THEN
            done = TRUE
        ELSEIF k = CHR$(27) THEN
            MD_MSG = "cancelled"
            EXIT SUB
        END IF
        IF sel < 1 THEN sel = STORY_N
        IF sel > STORY_N THEN sel = 1
    LOOP UNTIL done

    lvl = SECTORAT(MD_SX, MD_SY)
    path = "assets/data/" + _TRIM$(opt_datapack) + "/triggers.txt"
    IF _FILEEXISTS(path) = 0 THEN path = "assets/data/default/triggers.txt"
    row = LTRIM$(STR$(lvl)) + " | " + LTRIM$(STR$(MD_SX)) + " | " + LTRIM$(STR$(MD_SY)) + " | " + _TRIM$(STORY_NAME(sel)) + " | 1"

    f = FREEFILE
    OPEN path FOR APPEND AS #f
    PRINT #f, row
    CLOSE #f
    MD_MSG = "appended to " + path + ":  " + row
END SUB


'--- the event panel's drawing, split out so a headless shot can paint one
'    frame of it. A menu that is only ever drawn inside its own input loop
'    cannot be checked by anything but a person looking at it. ---
SUB MdEventPaint (rm AS INTEGER, cid AS INTEGER, x AS INTEGER, y AS INTEGER)
    DIM bg AS _UNSIGNED LONG
    bg = _RGB32(&H00, &H00, &H30)
    LINE (x * CW, y * CH)-((x + 64) * CW, (y + 30) * CH), bg, BF
    LINE (x * CW, y * CH)-((x + 64) * CW, (y + 30) * CH), _RGB32(&H55, &HFF, &HFF), B
    COLOR _RGB32(&HFF, &HFF, &H55), bg
    _PRINTSTRING ((x + 2) * CW, (y + 1) * CH), "-=  E V E N T   A T   " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY)) + "  =-"

    COLOR _RGB32(&HFF, &HFF, &HFF), bg
    MdRow x, y + 3, "1", "Teleport the player here", MD_LIVE
    MdRow x, y + 5, "2", "Spawn a CURIO", MD_LIVE
    MdRow x, y + 7, "3", "Fight a WANDERING monster (this level)", MD_LIVE
    MdRow x, y + 9, "4", "Spring a TRAP", MD_LIVE
    IF rm > 0 THEN
        MdRow x, y + 11, "5", "Fight this ROOM's monster (" + _TRIM$(ROOMS(rm).monster) + ")", MD_LIVE
    ELSE
        MdRow x, y + 11, "5", "Fight this ROOM's monster -- no room here", 0
    END IF
    IF cid > 0 THEN
        MdRow x, y + 13, "6", "CHAMBER encounter (" + _TRIM$(CHM_NAME(cid)) + ")", MD_LIVE
    ELSE
        MdRow x, y + 13, "6", "CHAMBER encounter -- no chamber here", 0
    END IF
    MdRow x, y + 15, "7", "Play a CUT-SCENE...", -1
    MdRow x, y + 17, "8", "Reveal the SECRET region here", -1
    MdRow x, y + 19, "9", "Write a TRIGGER for this cell into triggers.txt", -1

    COLOR _RGB32(&HAA, &HAA, &HAA), bg
    IF MD_LIVE = 0 THEN
        _PRINTSTRING ((x + 2) * CW, (y + 22) * CH), "greyed rows need a run in progress -- open this from [~] in game"
    END IF
    _PRINTSTRING ((x + 2) * CW, (y + 24) * CH), "the selected cell is the one boxed in white; click to move it"
    COLOR _RGB32(&HFF, &HFF, &H55), bg
    _PRINTSTRING ((x + 2) * CW, (y + 27) * CH), "[ESC] back"
END SUB
