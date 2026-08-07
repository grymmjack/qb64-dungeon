' ============================================================================
'  game/MAPREG.bas -- DUNGEON!'s layers and events for the map debugger.
'
'  The debugger itself is engine/MAPDEBUG.bas and knows nothing about rooms,
'  chambers or curios. This is the half that does: it REGISTERS what this game
'  has, fills each layer from the array the game itself reads, and fires each
'  event through the routine gameplay already calls.
'
'  Nothing here recomputes anything for display. A layer that derived its own
'  answer could agree with itself and still be wrong about the game.
' ============================================================================

'--- Layer 1 and 2 come up on: "which level owns this cell" and "where can I
'    stand" are the two that orient you. The rest are opt-in. ---
SUB Game_MapRegister
    MapLayer "sectors", ML_CELL
    MapLayer "walkable", ML_CELL
    MapLayer "rooms", ML_CELL
    MapLayer "roomkind", ML_CELL
    MapLayer "doors", ML_MARK
    MapLayer "chambers", ML_CELL
    MapLayer "secret", ML_CELL
    MapLayer "trig/ovl", ML_MARK
    MapLayer "markers", ML_MARK

    MapEvent "Teleport the player here", -1
    MapEvent "Spawn a CURIO", -1
    MapEvent "Fight a WANDERING monster (this level)", -1
    MapEvent "Spring a TRAP", -1
    MapEvent "Fight this ROOM's monster", -1
    MapEvent "CHAMBER encounter here", -1
    MapEvent "Play a CUT-SCENE...", 0
    MapEvent "Reveal the SECRET region here", 0
    MapEvent "Write a TRIGGER for this cell into triggers.txt", 0
END SUB

'--- Fill one CELL layer. Reads the same arrays movement, fog and combat read. ---
SUB Game_MapLayerFill (idx AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            SELECT CASE idx
                CASE 1: MapPut cx, cy, MdSectorColor~&(SECTORAT(cx, cy))
                CASE 2
                    IF CellKind%(cx, cy) <> 0 THEN MapPut cx, cy, _RGB32(40, 220, 90)
                CASE 3
                    IF ROOMAT(cx, cy) <> 0 THEN MapPut cx, cy, MdRoomColor~&(ROOMAT(cx, cy))
                CASE 4: MapPut cx, cy, MdKindColor~&(ROOMKIND(cx, cy))
                CASE 6
                    IF CHAMBERAT(cx, cy) <> 0 THEN MapPut cx, cy, _RGB32(255, 120, 255)
                CASE 7
                    IF SECRET(cx, cy) <> 0 THEN MapPut cx, cy, _RGB32(90, 90, 255)
            END SELECT
        NEXT cx
    NEXT cy
END SUB

'--- ...and draw one MARK layer. These are POINTS, not regions: a door is a
'    threshold and a marker is where one thing stands. ---
SUB Game_MapLayerMarks (idx AS INTEGER)
    DIM i AS INTEGER
    SELECT CASE idx
        CASE 5
            FOR i = 1 TO DOOR_N
                IF DOOR_STRONG(i) THEN
                    MapMark DOOR_X(i), DOOR_Y(i), _RGB32(255, 160, 40)
                ELSE
                    MapMark DOOR_X(i), DOOR_Y(i), _RGB32(190, 120, 60)
                END IF
            NEXT i
        CASE 8
            FOR i = 1 TO TRIG_N
                MapMark TRIG_COL(i), TRIG_ROW(i), _RGB32(255, 80, 80)
            NEXT i
            FOR i = 1 TO OVL_N
                MapMark OVL_COL(i), OVL_ROW(i), _RGB32(120, 220, 255)
            NEXT i
        CASE 9
            FOR i = 1 TO ROOM_N
                IF ROOMS(i).cx >= 0 THEN MapMark ROOMS(i).cx, ROOMS(i).cy, _RGB32(255, 255, 255)
            NEXT i
    END SELECT
END SUB

'--- Everything this game believes about a cell, for the readout line. This is
'    the part a PNG cannot do. ---
FUNCTION Game_MapReadout$ (cx AS INTEGER, cy AS INTEGER)
    DIM s AS STRING, i AS INTEGER
    s = "lvl " + LTRIM$(STR$(SECTORAT(cx, cy)))
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
    Game_MapReadout$ = s
END FUNCTION

'--- Fire an event AT a cell. Returns TRUE to close the menu.
'
'    Every row calls the SAME routine gameplay calls -- DoCurio, WanderEncounter,
'    SpringTrap, DoCombat%, ChamberEncounter, PlayCutscene%,
'    RevealRegionFromDoor -- so a curio fired from here rolls the same table,
'    plays the same sound and feeds the same chronicle. A test path that is its
'    own code proves nothing about the real one. ---
FUNCTION Game_MapEvent% (idx AS INTEGER, cx AS INTEGER, cy AS INTEGER)
    DIM rm AS INTEGER, cid AS INTEGER
    rm = ROOMAT(cx, cy)
    cid = CHAMBERAT(cx, cy)
    SELECT CASE idx
        CASE 1: MdTeleport: Game_MapEvent% = -1
        CASE 2: MdFire 2, rm, cid: Game_MapEvent% = -1
        CASE 3: MdFire 3, rm, cid: Game_MapEvent% = -1
        CASE 4: MdFire 4, rm, cid: Game_MapEvent% = -1
        CASE 5
            IF rm > 0 THEN MdFire 5, rm, cid: Game_MapEvent% = -1
        CASE 6
            IF cid > 0 THEN MdFire 6, rm, cid: Game_MapEvent% = -1
        CASE 7: MdScenePicker
        CASE 8: MdRevealHere
        CASE 9: MdWriteTrigger
    END SELECT
END FUNCTION

FUNCTION MdSectorColor~& (s AS INTEGER)
    IF s < 1 _ORELSE s > 9 THEN MdSectorColor~& = 0: EXIT FUNCTION
    MdSectorColor~& = SECTORS(s).kolor
END FUNCTION


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


FUNCTION MdKindColor~& (k AS INTEGER)
    SELECT CASE k
        CASE CRK_FLOOR: MdKindColor~& = _RGB32(60, 255, 60)
        CASE CRK_DOOR: MdKindColor~& = _RGB32(255, 200, 60)
        CASE CRK_MIXED: MdKindColor~& = _RGB32(255, 60, 60)
        CASE ELSE: MdKindColor~& = 0
    END SELECT
END FUNCTION


SUB MdTeleport
    c.x = MD_SX * CW
    c.y = MD_SY * CH
    SeedPlayerLevel c.x, c.y
    MD_MSG = "teleported to " + LTRIM$(STR$(MD_SX)) + "," + LTRIM$(STR$(MD_SY))
END SUB


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





'--- The host's answers to the placement tools. The engine writes the row and
'    then asks for a reload, because the CHECK on a placement is the layer view
'    showing what it actually claimed -- not what it was meant to claim. ---
FUNCTION Game_MapZone% (cx AS INTEGER, cy AS INTEGER)
    Game_MapZone% = SECTORAT(cx, cy)
END FUNCTION

SUB Game_MapReload (what AS INTEGER)
    SELECT CASE what
        CASE 1: LoadOverlays
        CASE 2: DetectChambers
    END SELECT
END SUB

'--- Which scenes exist, what they are called and what counts as seen is the
'    cut-scene layer's business, and that is assembled by the game. ---
SUB Game_MapScenePick
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
            IF played THEN MD_MSG = "played " + _TRIM$(STORY_NAME(sel)) ELSE MD_MSG = "scene would not play"
            done = TRUE
        ELSEIF k = CHR$(27) THEN
            done = TRUE
        END IF
        IF sel < 1 THEN sel = STORY_N
        IF sel > STORY_N THEN sel = 1
    LOOP UNTIL done
END SUB
