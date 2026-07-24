' ============================================================================
'  BOARD.bas -- board render, fog-of-war, secret doors, pixel-colour collision
' ============================================================================

SUB DoSearch
    DIM i AS INTEGER, ccx AS INTEGER, ccy AS INTEGER, roll AS INTEGER
    DIM found_any AS INTEGER, near_hidden AS INTEGER
    ccx = c.x \ CW: ccy = c.y \ CH
    roll = DoRoll(1, CLASSES(player_class).secret_bonus, "SEARCHING for secret doors")
    IF item_secret_card THEN roll = 99          ' the Secret Door Card never fails
    found_any = FALSE: near_hidden = FALSE
    FOR i = 1 TO SD_N
        IF NOT SD_FOUND(i) THEN
            IF ABS(SD_X(i) - ccx) <= 2 AND ABS(SD_Y(i) - ccy) <= 2 THEN
                near_hidden = TRUE
                IF roll >= 5 THEN
                    SD_FOUND(i) = TRUE
                    RevealRegionFromDoor i    ' reveal door + the area it connects to
                    found_any = TRUE
                END IF
            END IF
        END IF
    NEXT

    IF found_any THEN
        Sfx "secret"
        IF NOT has_key THEN
            has_key = TRUE
            Sfx "key"                             ' the Level Key fanfare
            Banner "A SECRET DOOR grinds open -- the LEVEL KEY lies beyond!", "A hidden passage is revealed.   [ press any key ]"
        ELSE
            Banner "You uncover another SECRET DOOR!", "A hidden passage is revealed.   [ press any key ]"
        END IF
    ELSEIF near_hidden THEN
        Sfx "search"
        Banner "Your fingers trace a faint seam in the stone...", "Something is hidden nearby -- keep searching!   [ press any key ]"
    ELSE
        Sfx "search"
        Banner "You search the walls but find no secrets here.", "[ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: _DISPLAY
END SUB


' Classify a cell of FULL_BOARD by its centre pixel (caller sets _SOURCE FULL_BOARD):
' 0 = wall, 1 = walkable terrain (path/room/door), 2 = secret-door tile.

FUNCTION CellKind% (cx AS INTEGER, cy AS INTEGER)
    DIM col AS _UNSIGNED LONG, sec AS INTEGER
    col = POINT(cx * CW + CW \ 2, cy * CH + CH \ 2)
    IF col = BRIGHT_BLUE THEN CellKind = 2: EXIT FUNCTION
    IF col = YELLOW OR col = BROWN THEN CellKind = 1: EXIT FUNCTION
    sec = SECTOR.get_by_xy(cx * CW, cy * CH)
    IF sec >= 1 THEN
        IF col = SECTORS(sec).kolor THEN CellKind = 1: EXIT FUNCTION
    END IF
    CellKind = 0
END FUNCTION


' Scan FULL_BOARD for bright-blue secret-door tiles and record their cells.

SUB DetectSecretDoors
    DIM cx AS INTEGER, cy AS INTEGER, px AS INTEGER, py AS INTEGER, blue AS INTEGER
    SD_N = 0
    _SOURCE FULL_BOARD
    FOR cy = 1 TO SH - 4
        FOR cx = 1 TO SW - 2
            blue = 0
            FOR py = 1 TO CH - 1 STEP 2
                FOR px = 1 TO CW - 1 STEP 2
                    IF POINT(cx * CW + px, cy * CH + py) = BRIGHT_BLUE THEN blue = blue + 1
                NEXT px
            NEXT py
            IF blue >= 2 AND SD_N < UBOUND(SD_X) THEN
                SD_N = SD_N + 1
                SD_X(SD_N) = cx: SD_Y(SD_N) = cy: SD_FOUND(SD_N) = FALSE
            END IF
        NEXT cx
    NEXT cy
END SUB


' Scan FULL_BOARD for regular (brown) door tiles and record their cells.
SUB DetectDoors
    DIM cx AS INTEGER, cy AS INTEGER, px AS INTEGER, py AS INTEGER, brown AS INTEGER
    DOOR_N = 0
    _SOURCE FULL_BOARD
    FOR cy = 1 TO SH - 4
        FOR cx = 1 TO SW - 2
            brown = 0
            FOR py = 1 TO CH - 1 STEP 2
                FOR px = 1 TO CW - 1 STEP 2
                    IF POINT(cx * CW + px, cy * CH + py) = BROWN THEN brown = brown + 1
                NEXT px
            NEXT py
            IF brown >= 2 AND DOOR_N < UBOUND(DOOR_X) THEN
                DOOR_N = DOOR_N + 1
                DOOR_X(DOOR_N) = cx: DOOR_Y(DOOR_N) = cy
            END IF
        NEXT cx
    NEXT cy
END SUB


' Flood-fill the board's coloured room blocks into individual ROOMs, one per
' connected block of a sector's colour, recording a centre cell and cell->room
' map (ROOMAT). Every reachable room later gets its own monster + treasure.
' Draw a small grey headstone on every room whose monster has been slain, so the
' board shows at a glance which rooms are cleared. (Rendered onto CANVAS after a
' fresh board blit, so it rides along with cursor_draw.)
SUB DrawTombstones
    DIM r AS INTEGER, px AS INTEGER, py AS INTEGER
    DIM grave AS _UNSIGNED LONG, dark AS _UNSIGNED LONG
    grave = _RGB32(&HC8, &HC8, &HC8): dark = _RGB32(&H30, &H30, &H30)
    _DEST CANVAS
    DIM coin AS _UNSIGNED LONG, shine AS _UNSIGNED LONG
    coin = _RGB32(&HFF, &HC0, &H20): shine = _RGB32(&HFF, &HF0, &H90)
    FOR r = 1 TO ROOM_N
        IF VIS(ROOMS(r).cx, ROOMS(r).cy) AND (NOT opt_fov OR LOS_SEEN(ROOMS(r).cx, ROOMS(r).cy)) THEN
            px = ROOMS(r).cx * CW: py = ROOMS(r).cy * CH
            IF ROOMS(r).monster_fought AND NOT ROOMS(r).malive THEN
                LINE (px + 1, py + 5)-(px + CW - 2, py + CH - 1), grave, BF     ' stone body
                LINE (px + 2, py + 3)-(px + CW - 3, py + 6), grave, BF          ' rounded top
                LINE (px + CW \ 2, py + 6)-(px + CW \ 2, py + CH - 3), dark     ' cross (vertical)
                LINE (px + 2, py + 9)-(px + CW - 3, py + 9), dark               ' cross (horizontal)
            END IF
            ' a fallen rival's dropped loot -- a gold coin marker
            IF ROOMS(r).drop_gold > 0 OR ROOMS(r).drop_sword > 0 OR ROOMS(r).drop_secret OR ROOMS(r).drop_esp OR ROOMS(r).drop_crystal THEN
                LINE (px + 2, py + 4)-(px + CW - 3, py + CH - 3), coin, BF
                LINE (px + 3, py + 5)-(px + CW - 4, py + 7), shine, BF
            END IF
        END IF
    NEXT r
END SUB


SUB DetectRooms
    DIM cx AS INTEGER, cy AS INTEGER, sec AS INTEGER
    DIM oldsrc AS LONG
    ROOM_N = 0
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1: ROOMAT(cx, cy) = 0: NEXT cx
    NEXT cy
    oldsrc = _SOURCE: _SOURCE FULL_BOARD
    FOR cy = 1 TO SH - 2
        FOR cx = 1 TO SW - 1
            IF ROOMAT(cx, cy) = 0 THEN
                sec = SECTOR.get_by_xy(cx * CW, cy * CH)
                IF sec >= 1 THEN
                    IF POINT(cx * CW + CW \ 2, cy * CH + CH \ 2) = SECTORS(sec).kolor THEN
                        IF ROOM_N < UBOUND(ROOMS) THEN
                            ROOM_N = ROOM_N + 1
                            FloodRoom cx, cy, sec, ROOM_N
                        END IF
                    END IF
                END IF
            END IF
        NEXT cx
    NEXT cy
    _SOURCE oldsrc
END SUB


' BFS one room block (same sector + colour, 4-connected); record its centre cell.
SUB FloodRoom (sx AS INTEGER, sy AS INTEGER, sec AS INTEGER, rid AS INTEGER)
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM minx AS INTEGER, maxx AS INTEGER, miny AS INTEGER, maxy AS INTEGER
    DIM kol AS _UNSIGNED LONG
    kol = SECTORS(sec).kolor
    head = 0: tail = 0
    QX(0) = sx: QY(0) = sy: ROOMAT(sx, sy) = rid: tail = 1
    minx = sx: maxx = sx: miny = sy: maxy = sy
    DO WHILE head < tail
        x = QX(head): y = QY(head): head = head + 1
        IF x < minx THEN minx = x
        IF x > maxx THEN maxx = x
        IF y < miny THEN miny = y
        IF y > maxy THEN maxy = y
        RoomVisit x - 1, y, sec, rid, kol, tail
        RoomVisit x + 1, y, sec, rid, kol, tail
        RoomVisit x, y - 1, sec, rid, kol, tail
        RoomVisit x, y + 1, sec, rid, kol, tail
    LOOP
    ROOMS(rid).sec = sec
    ROOMS(rid).cells = tail                 ' block size (tail = cells enqueued)
    ROOMS(rid).cx = (minx + maxx) \ 2
    ROOMS(rid).cy = (miny + maxy) \ 2
END SUB


SUB RoomVisit (x AS INTEGER, y AS INTEGER, sec AS INTEGER, rid AS INTEGER, kol AS _UNSIGNED LONG, tail AS INTEGER)
    IF x < 0 OR x > SW - 1 OR y < 0 OR y > SH - 1 THEN EXIT SUB
    IF ROOMAT(x, y) <> 0 THEN EXIT SUB
    IF POINT(x * CW + CW \ 2, y * CH + CH \ 2) <> kol THEN EXIT SUB
    IF SECTOR.get_by_xy(x * CW, y * CH) <> sec THEN EXIT SUB
    ROOMAT(x, y) = rid
    QX(tail) = x: QY(tail) = y: tail = tail + 1
END SUB


' Re-roll which doors are "strong" (must be broken) -- about 1 in 6 -- and clear
' the broken flags.  Called each game so a fresh dungeon reinforces new doors.
SUB MarkStrongDoors
    DIM i AS INTEGER
    FOR i = 1 TO DOOR_N
        DOOR_BROKEN(i) = 0
        IF RollDie(6) = 1 THEN DOOR_STRONG(i) = 1 ELSE DOOR_STRONG(i) = 0
    NEXT i
END SUB


' Index of an un-broken STRONG door at cell (cx,cy), or 0 if none.
FUNCTION StrongDoorHere% (cx AS INTEGER, cy AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO DOOR_N
        IF DOOR_X(i) = cx AND DOOR_Y(i) = cy THEN
            IF DOOR_STRONG(i) AND NOT DOOR_BROKEN(i) THEN StrongDoorHere = i
            EXIT FUNCTION
        END IF
    NEXT i
    StrongDoorHere = 0
END FUNCTION


' Is there a strong door one step in direction k from the cursor? Returns its index.
FUNCTION StrongDoorAhead% (k AS STRING)
    DIM dx AS INTEGER, dy AS INTEGER
    SELECT CASE k
        CASE "A": dx = -1
        CASE "D": dx = 1
        CASE "W": dy = -1
        CASE "S": dy = 1
        CASE "NW": dx = -1: dy = -1
        CASE "NE": dx = 1: dy = -1
        CASE "SW": dx = -1: dy = 1
        CASE "SE": dx = 1: dy = 1
    END SELECT
    StrongDoorAhead = StrongDoorHere(c.x \ CW + dx, c.y \ CH + dy)
END FUNCTION


' Attempt to break a strong door with a STR check (d20 + STR mod vs DC 13).
' Returns TRUE and clears the door if it bursts open.
FUNCTION BreakDoorAttempt% (idx AS INTEGER)
    DIM roll AS INTEGER, m AS INTEGER, tag AS STRING
    Sfx "strongdoor"
    m = AbilMod(player_str)
    roll = RollDie(20) + m
    tag = "  (STR d20" + ModStr$(m) + " = " + _TRIM$(STR$(roll)) + " vs 13)"
    IF roll >= 13 THEN
        DOOR_BROKEN(idx) = 1
        Sfx "breakdoor"
        Banner "You SMASH through the reinforced door!" + tag, "It bursts off its hinges.   [ press any key ]"
        BreakDoorAttempt = TRUE
    ELSE
        Banner "A REINFORCED DOOR resists your shoulder!" + tag, "It holds firm -- hurl yourself at it again.   [ press any key ]"
        BreakDoorAttempt = FALSE
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END FUNCTION


' Build the played board from FULL_BOARD: flood-fill the area reachable from
' START without crossing a door (the "public" area), then black out every
' walkable cell that is only reachable through a door, plus the doors.

SUB InitFog
    DIM cx AS INTEGER, cy AS INTEGER, i AS INTEGER, head AS INTEGER, tail AS INTEGER
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            VIS(cx, cy) = 0: DOORCELL(cx, cy) = 0: SECRET(cx, cy) = 0
        NEXT cx
    NEXT cy

    DetectSecretDoors
    FOR i = 1 TO SD_N: DOORCELL(SD_X(i), SD_Y(i)) = 1: NEXT i
    DetectDoors                          ' regular (brown) doors -> DOOR arrays
    MarkStrongDoors                      ' re-roll which ones are reinforced this game
    DetectRooms                          ' flood-fill the coloured room blocks -> ROOMS / ROOMAT

    ' 1) BFS the public area from START (doors are treated as walls)
    _SOURCE FULL_BOARD
    head = 0: tail = 0
    QX(0) = START_CX: QY(0) = START_CY: VIS(START_CX, START_CY) = 1: tail = 1
    DO WHILE head < tail
        cx = QX(head): cy = QY(head): head = head + 1
        FogVisit cx - 1, cy, tail
        FogVisit cx + 1, cy, tail
        FogVisit cx, cy - 1, tail
        FogVisit cx, cy + 1, tail
    LOOP

    ' 2) BFS the secret network outward from every door (through non-public
    '    walkable cells + doors) so ONLY door-connected areas get fogged --
    '    isolated terrain-coloured graphics (labels, legend) stay visible.
    head = 0: tail = 0
    FOR i = 1 TO SD_N
        IF SECRET(SD_X(i), SD_Y(i)) = 0 THEN
            SECRET(SD_X(i), SD_Y(i)) = 1
            QX(tail) = SD_X(i): QY(tail) = SD_Y(i): tail = tail + 1
        END IF
    NEXT i
    DO WHILE head < tail
        cx = QX(head): cy = QY(head): head = head + 1
        SecretVisit cx - 1, cy, tail
        SecretVisit cx + 1, cy, tail
        SecretVisit cx, cy - 1, tail
        SecretVisit cx, cy + 1, tail
    LOOP

    ' 3) compose the played board: full board, then black out the secret cells
    _PUTIMAGE (0, 0), FULL_BOARD, CANVAS_COPY
    _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF SECRET(cx, cy) = 1 THEN
                _DEST CANVAS_COPY: LINE (cx * CW, cy * CH)-(cx * CW + CW - 1, cy * CH + CH - 1), BLACK, BF
                _DEST CANVAS: LINE (cx * CW, cy * CH)-(cx * CW + CW - 1, cy * CH + CH - 1), BLACK, BF
            END IF
        NEXT cx
    NEXT cy
END SUB


' Public-area BFS helper: enqueue a walkable, unseen, non-door neighbour.

SUB FogVisit (nx AS INTEGER, ny AS INTEGER, tail AS INTEGER)
    IF nx < 0 OR nx > SW - 1 OR ny < 0 OR ny > SH - 1 THEN EXIT SUB
    IF VIS(nx, ny) <> 0 OR DOORCELL(nx, ny) <> 0 THEN EXIT SUB
    IF CellKind(nx, ny) <> 1 THEN EXIT SUB
    VIS(nx, ny) = 1
    QX(tail) = nx: QY(tail) = ny: tail = tail + 1
END SUB


' Secret-network BFS helper: flood into non-public walkable cells and doors.

SUB SecretVisit (nx AS INTEGER, ny AS INTEGER, tail AS INTEGER)
    IF nx < 0 OR nx > SW - 1 OR ny < 0 OR ny > SH - 1 THEN EXIT SUB
    IF SECRET(nx, ny) <> 0 OR VIS(nx, ny) <> 0 THEN EXIT SUB
    IF DOORCELL(nx, ny) = 0 AND CellKind(nx, ny) <> 1 THEN EXIT SUB
    SECRET(nx, ny) = 1
    QX(tail) = nx: QY(tail) = ny: tail = tail + 1
END SUB


' Copy one cell's pristine pixels from FULL_BOARD back onto the played canvases.

SUB RevealCell (cx AS INTEGER, cy AS INTEGER)
    DIM px AS INTEGER, py AS INTEGER
    px = cx * CW: py = cy * CH
    _PUTIMAGE (px, py)-(px + CW - 1, py + CH - 1), FULL_BOARD, CANVAS_COPY, (px, py)-(px + CW - 1, py + CH - 1)
    _PUTIMAGE (px, py)-(px + CW - 1, py + CH - 1), FULL_BOARD, CANVAS, (px, py)-(px + CW - 1, py + CH - 1)
END SUB


' Reveal a found door and flood-fill outward through the sealed area it opens
' onto -- stopping at walls and other (still-hidden) doors.

SUB RevealRegionFromDoor (di AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER, head AS INTEGER, tail AS INTEGER
    _SOURCE FULL_BOARD
    cx = SD_X(di): cy = SD_Y(di)
    RevealCell cx, cy: VIS(cx, cy) = 1
    head = 0: tail = 0: QX(0) = cx: QY(0) = cy: tail = 1
    DO WHILE head < tail
        cx = QX(head): cy = QY(head): head = head + 1
        RevealVisit cx - 1, cy, tail
        RevealVisit cx + 1, cy, tail
        RevealVisit cx, cy - 1, tail
        RevealVisit cx, cy + 1, tail
    LOOP
END SUB


' BFS helper for reveal: reveal a hidden, walkable, non-door neighbour. (_SOURCE = FULL_BOARD)

SUB RevealVisit (nx AS INTEGER, ny AS INTEGER, tail AS INTEGER)
    IF nx < 0 OR nx > SW - 1 OR ny < 0 OR ny > SH - 1 THEN EXIT SUB
    IF VIS(nx, ny) <> 0 OR DOORCELL(nx, ny) <> 0 THEN EXIT SUB
    IF CellKind(nx, ny) <> 1 THEN EXIT SUB
    RevealCell nx, ny
    VIS(nx, ny) = 1
    QX(tail) = nx: QY(tail) = ny: tail = tail + 1
END SUB


' ============================================================================
'  END SCREENS
' ============================================================================

' ================= LINE-OF-SIGHT FOG-OF-WAR (opt_fov) =================

' A cell blocks sight if it is a black wall (read from the collision board).
' Assumes _SOURCE has been set to CANVAS_COPY by the caller.
FUNCTION IsOpaque% (cx AS INTEGER, cy AS INTEGER)
    IF cx < 0 OR cx > SW - 1 OR cy < 0 OR cy > SH - 1 THEN IsOpaque = TRUE: EXIT FUNCTION
    IsOpaque = (POINT(cx * CW + CW \ 2, cy * CH + CH \ 2) = BLACK)
END FUNCTION

' Bresenham ray from the player (x0,y0) to (x1,y1): light every cell until a wall
' blocks it (the wall itself is seen, but nothing beyond).
SUB CastRay (x0 AS INTEGER, y0 AS INTEGER, x1 AS INTEGER, y1 AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER, sx AS INTEGER, sy AS INTEGER, derr AS INTEGER, e2 AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, first AS INTEGER
    x = x0: y = y0: first = -1
    dx = ABS(x1 - x0): dy = ABS(y1 - y0)
    IF x0 < x1 THEN sx = 1 ELSE sx = -1
    IF y0 < y1 THEN sy = 1 ELSE sy = -1
    derr = dx - dy
    DO
        IF x >= 0 AND x <= SW - 1 AND y >= 0 AND y <= SH - 1 THEN LOS_LIT(x, y) = 1: LOS_SEEN(x, y) = 1
        IF x = x1 AND y = y1 THEN EXIT SUB
        IF NOT first THEN IF IsOpaque(x, y) THEN EXIT SUB   ' a wall -- seen, but sight stops here
        first = 0
        e2 = 2 * derr
        IF e2 > -dy THEN derr = derr - dy: x = x + sx
        IF e2 < dx THEN derr = derr + dx: y = y + sy
    LOOP
END SUB

' Recompute which cells are lit from the player's cell (circular radius FOV_R).
SUB ComputeFOV
    CONST FOV_R = 10
    DIM pcx AS INTEGER, pcy AS INTEGER, cx AS INTEGER, cy AS INTEGER, oldsrc AS LONG
    pcx = c.x \ CW: pcy = c.y \ CH
    FOR cy = 0 TO SH - 1: FOR cx = 0 TO SW - 1: LOS_LIT(cx, cy) = 0: NEXT cx: NEXT cy
    oldsrc = _SOURCE: _SOURCE CANVAS_COPY
    FOR cy = pcy - FOV_R TO pcy + FOV_R
        FOR cx = pcx - FOV_R TO pcx + FOV_R
            IF (cx - pcx) * (cx - pcx) + (cy - pcy) * (cy - pcy) <= FOV_R * FOV_R THEN CastRay pcx, pcy, cx, cy
        NEXT cx
    NEXT cy
    _SOURCE oldsrc
    fov_cx = pcx: fov_cy = pcy
END SUB

' Fresh line-of-sight state: nothing explored, then reveal the entrance room.
SUB InitFOV
    DIM cx AS INTEGER, cy AS INTEGER
    FOR cy = 0 TO SH - 1: FOR cx = 0 TO SW - 1: LOS_SEEN(cx, cy) = 0: LOS_LIT(cx, cy) = 0: NEXT cx: NEXT cy
    fov_cx = -999: fov_cy = -999
    ComputeFOV
END SUB

' Draw the board through the fog: black everywhere, blit back explored cells,
' dim the ones not currently in sight.
SUB FovRender
    DIM cx AS INTEGER, cy AS INTEGER, px AS INTEGER, py AS INTEGER, shade AS _UNSIGNED LONG
    shade = _RGB32(&H00, &H00, &H00, &H99)
    _DEST CANVAS
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF LOS_SEEN(cx, cy) THEN
                px = cx * CW: py = cy * CH
                _PUTIMAGE (px, py)-(px + CW - 1, py + CH - 1), CANVAS_COPY, CANVAS, (px, py)-(px + CW - 1, py + CH - 1)
                IF LOS_LIT(cx, cy) = 0 THEN LINE (px, py)-(px + CW - 1, py + CH - 1), shade, BF   ' dim explored-not-lit
            END IF
        NEXT cx
    NEXT cy
END SUB


SUB StartBoard
    _DEST FULL_BOARD: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)    ' pristine board (everything visible)
    InitFog                          ' build the fogged CANVAS_COPY + CANVAS (secret areas sealed)
    c.cursor_color = _RGB32(&HFF, &H00, &H00, &HAA)
    c.x = START_CX * CW: c.y = START_CY * CH
    c.prev_x = c.x: c.prev_y = c.y
    IF opt_fov THEN InitFOV          ' start explored = just the entrance room + line of sight
    cursor_erase                     ' render the board (full, or through the fog) + labels
    cursor_draw
    FadeInCurrent                    ' fade the dungeon in from black
END SUB



FUNCTION OnDoorNow%
    DIM img AS LONG, r AS INTEGER
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    r = image_is_monochromatic(img, BROWN)
    IF NOT r THEN r = image_is_diachromatic(img, YELLOW, BROWN)
    _FREEIMAGE img
    OnDoorNow = r
END FUNCTION


' ---- neighbouring-cell inspection (drives the cursor's proximity states) ----

' Colour of a cell centre in the CURRENT _SOURCE (black if out of bounds).
FUNCTION CellColorAt~& (cx AS INTEGER, cy AS INTEGER)
    IF cx < 0 OR cx > SW - 1 OR cy < 0 OR cy > SH - 1 THEN CellColorAt = BLACK: EXIT FUNCTION
    CellColorAt = POINT(cx * CW + CW \ 2, cy * CH + CH \ 2)
END FUNCTION

' TRUE if any of the cursor's 4 orthogonal neighbours is the given colour.
FUNCTION NeighborHasColor% (kol AS _UNSIGNED LONG)
    DIM cx AS INTEGER, cy AS INTEGER, oldsrc AS LONG, res AS INTEGER
    cx = c.x \ CW: cy = c.y \ CH
    oldsrc = _SOURCE: _SOURCE CANVAS_COPY
    res = FALSE
    IF CellColorAt(cx - 1, cy) = kol THEN res = TRUE
    IF CellColorAt(cx + 1, cy) = kol THEN res = TRUE
    IF CellColorAt(cx, cy - 1) = kol THEN res = TRUE
    IF CellColorAt(cx, cy + 1) = kol THEN res = TRUE
    _SOURCE oldsrc
    NeighborHasColor = res
END FUNCTION

' Adjacent to an ordinary (brown) door?
FUNCTION NearRegularDoor% ()
    NearRegularDoor = NeighborHasColor(BROWN)
END FUNCTION

' Adjacent to an un-broken reinforced (strong) door?
FUNCTION NearStrongDoor% ()
    DIM cx AS INTEGER, cy AS INTEGER
    cx = c.x \ CW: cy = c.y \ CH
    IF StrongDoorHere(cx - 1, cy) > 0 THEN NearStrongDoor = TRUE: EXIT FUNCTION
    IF StrongDoorHere(cx + 1, cy) > 0 THEN NearStrongDoor = TRUE: EXIT FUNCTION
    IF StrongDoorHere(cx, cy - 1) > 0 THEN NearStrongDoor = TRUE: EXIT FUNCTION
    IF StrongDoorHere(cx, cy + 1) > 0 THEN NearStrongDoor = TRUE: EXIT FUNCTION
    NearStrongDoor = FALSE
END FUNCTION

' Within 2 cells of a STILL-HIDDEN secret door -- a hint to search here.
FUNCTION NearSecretDoorHint% ()
    DIM i AS INTEGER, cx AS INTEGER, cy AS INTEGER
    cx = c.x \ CW: cy = c.y \ CH
    FOR i = 1 TO SD_N
        IF NOT SD_FOUND(i) THEN
            IF ABS(SD_X(i) - cx) <= 2 AND ABS(SD_Y(i) - cy) <= 2 THEN NearSecretDoorHint = TRUE: EXIT FUNCTION
        END IF
    NEXT i
    NearSecretDoorHint = FALSE
END FUNCTION


' TRUE if the cursor cell is a (revealed) secret door -- a bright-blue tile.
FUNCTION OnSecretDoorNow%
    DIM img AS LONG, r AS INTEGER
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    r = image_is_monochromatic(img, BRIGHT_BLUE)
    IF NOT r THEN r = image_is_diachromatic(img, YELLOW, BRIGHT_BLUE)
    _FREEIMAGE img
    OnSecretDoorNow = r
END FUNCTION



FUNCTION CanMove%
    DIM img AS LONG, ok AS INTEGER, sec AS INTEGER, col AS _UNSIGNED LONG
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    ok = image_is_monochromatic(img, YELLOW)                        ' path
    IF NOT ok THEN ok = image_is_diachromatic(img, YELLOW, BROWN)         ' door on path
    IF NOT ok THEN ok = image_is_diachromatic(img, YELLOW, BRIGHT_BLUE)   ' secret door on path
    IF NOT ok THEN ok = image_is_monochromatic(img, BROWN)               ' solid door
    IF NOT ok THEN ok = image_is_monochromatic(img, BRIGHT_BLUE)         ' solid secret door
    IF NOT ok THEN
        sec = SECTOR.get_by_xy(c.x, c.y)
        IF sec >= 1 THEN
            col = SECTORS(sec).kolor
            ok = image_is_monochromatic(img, col)
            IF NOT ok THEN ok = image_is_diachromatic(img, col, BROWN)
            IF NOT ok THEN ok = image_is_diachromatic(img, col, BRIGHT_BLUE)
        END IF
    END IF
    _FREEIMAGE img
    CanMove = ok
END FUNCTION


' TRUE if the cursor cell is a room floor (its sector's color).

FUNCTION InRoomNow%
    DIM img AS LONG, r AS INTEGER, sec AS INTEGER, col AS _UNSIGNED LONG
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec < 1 THEN InRoomNow = FALSE: EXIT FUNCTION
    col = SECTORS(sec).kolor
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    r = image_is_monochromatic(img, col)
    IF NOT r THEN r = image_is_diachromatic(img, col, BROWN)
    IF NOT r THEN r = image_is_diachromatic(img, col, BRIGHT_BLUE)
    _FREEIMAGE img
    InRoomNow = r
END FUNCTION



FUNCTION image_is_monochromatic% (img AS LONG, kolor AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor
    DIM check_color AS _UNSIGNED LONG
    DIM old_source AS LONG
    old_source = _SOURCE
    _SOURCE img
    FOR y = 0 TO _HEIGHT(img) - 1
        FOR x = 0 TO _WIDTH(img) - 1
            check_color = POINT(x, y)
            IF check_color <> kolor THEN
                _SOURCE old_source
                image_is_monochromatic = FALSE
                EXIT FUNCTION
            ELSE
                has_kolor = TRUE
            END IF
        NEXT x
    NEXT y
    _SOURCE old_source
    image_is_monochromatic = has_kolor
END FUNCTION



FUNCTION image_is_diachromatic% (img AS LONG, kolor1 AS _UNSIGNED LONG, kolor2 AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor1, has_kolor2
    DIM check_color AS _UNSIGNED LONG
    DIM old_source AS LONG
    old_source = _SOURCE
    _SOURCE img
    FOR y = 0 TO _HEIGHT(img) - 1
        FOR x = 0 TO _WIDTH(img) - 1
            check_color = POINT(x, y)
            IF (check_color <> kolor1) AND (check_color <> kolor2) THEN
                _SOURCE old_source
                image_is_diachromatic = FALSE
                EXIT FUNCTION
            ELSE
                IF check_color = kolor1 THEN has_kolor1 = TRUE
                IF check_color = kolor2 THEN has_kolor2 = TRUE
            END IF
        NEXT x
    NEXT y
    _SOURCE old_source
    image_is_diachromatic = has_kolor1 AND has_kolor2
END FUNCTION



' Draw a room label, but hide it in FOV mode until that spot has been seen.
SUB PutLabel (cx AS INTEGER, cy AS INTEGER, txt AS STRING, fg AS _UNSIGNED LONG)
    IF opt_fov THEN IF LOS_SEEN(cx, cy) = 0 THEN EXIT SUB
    COLOR fg, YELLOW
    _PRINTSTRING (cx * CW, cy * CH), txt
END SUB

SUB render_room_labels
    DIM AS _UNSIGNED LONG b, r
    b = _RGB32(&H00, &H00, &HAA): r = _RGB32(&HFF, &H55, &H55)
    _DEST CANVAS
    PutLabel 57, 23, "START", r
    PutLabel 57, 25, "MAIN", b
    PutLabel 56, 26, "GALLERY", b
    PutLabel 14, 10, "ARMORY", b
    PutLabel 47, 7, "THE", b
    PutLabel 47, 8, "CRYPT", b
    PutLabel 83, 9, "WIZ'S", b
    PutLabel 84, 10, "LAB", b
    PutLabel 93, 7, "WIZ'S", b
    PutLabel 93, 8, "TREASURE", b
    PutLabel 3, 26, "KITCHEN", b
    PutLabel 18, 23, "GUARD", b
    PutLabel 18, 24, "ROOM", b
    PutLabel 18, 41, "STORE", b
    PutLabel 18, 42, "ROOM", b
    PutLabel 49, 39, "TORTURE", b
    PutLabel 49, 40, "CHAMBER", b
    PutLabel 88, 42, "QUEEN'S", b
    PutLabel 88, 43, "ANNEX", b
    PutLabel 87, 34, "QUEEN'S", b
    PutLabel 87, 35, "TREASURE", b
    PutLabel 90, 27, "KING'S", b
    PutLabel 88, 28, "LIBRARY", b
    PutLabel 104, 21, "KING'S", b
    PutLabel 104, 22, "TREASURE", b
END SUB



' [~] debug overlay: cursor position, cell states, move count, timer.
FUNCTION YN$ (b AS INTEGER)
    IF b THEN YN$ = "Y" ELSE YN$ = "N"
END FUNCTION


SUB DrawDebug
    DIM cx AS INTEGER, cy AS INTEGER, sec AS INTEGER, i AS INTEGER
    DIM onpath AS INTEGER, inroom AS INTEGER, ondoor AS INTEGER, onsecret AS INTEGER, nearsd AS INTEGER
    DIM img AS LONG, el AS LONG, bg AS _UNSIGNED LONG
    DIM mx AS INTEGER, my AS INTEGER, mcx AS INTEGER, mcy AS INTEGER, kind AS INTEGER, kn AS STRING
    DIM fought AS STRING, died AS STRING, boss AS STRING, loot AS STRING, oldsrc AS LONG
    cx = c.x \ CW: cy = c.y \ CH
    sec = SECTOR.get_by_xy(c.x, c.y)
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    onpath = image_is_monochromatic(img, YELLOW)
    onsecret = image_is_monochromatic(img, BRIGHT_BLUE)
    _FREEIMAGE img
    inroom = InRoomNow
    ondoor = OnDoorNow
    FOR i = 1 TO SD_N
        IF NOT SD_FOUND(i) THEN
            IF ABS(SD_X(i) - cx) <= 2 AND ABS(SD_Y(i) - cy) <= 2 THEN nearsd = -1
        END IF
    NEXT i
    ' current room flags (the room block under the cursor)
    DIM rmid AS INTEGER
    rmid = ROOMAT(cx, cy)
    IF rmid >= 1 THEN
        fought = YN$(ROOMS(rmid).monster_fought): died = YN$(ROOMS(rmid).player_died)
        boss = YN$(ROOMS(rmid).is_boss): loot = YN$(ROOMS(rmid).looted)
    ELSE
        fought = "-": died = "-": boss = "-": loot = "-"
    END IF
    ' mouse crosshair inspector -- drain queued mouse events, sample the cell under it
    DO WHILE _MOUSEINPUT: LOOP
    mx = _MOUSEX: my = _MOUSEY
    mcx = mx \ CW: mcy = my \ CH
    oldsrc = _SOURCE: _SOURCE CANVAS_COPY
    kind = CellKind(mcx, mcy)
    _SOURCE oldsrc
    SELECT CASE kind
        CASE 1: kn = "OPEN"
        CASE 2: kn = "SECRET"
        CASE ELSE: kn = "WALL"
    END SELECT
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    bg = _RGB32(&H00, &H00, &H40)
    _DEST CANVAS
    ' crosshair through the mouse pointer
    LINE (mx, 0)-(mx, SH * CH - 1), _RGB32(&H00, &HFF, &H00)
    LINE (0, my)-(SW * CW - 1, my), _RGB32(&H00, &HFF, &H00)
    LINE (0, 0)-(52 * CW, 6 * CH), bg, BF
    LINE (0, 0)-(52 * CW, 6 * CH), CYANU, B
    COLOR YELLOWU, bg
    _PRINTSTRING (1 * CW, 0 * CH), "DEBUG [~]  px " + _TRIM$(STR$(c.x)) + "," + _TRIM$(STR$(c.y)) + "   cell " + _TRIM$(STR$(cx)) + "," + _TRIM$(STR$(cy))
    _PRINTSTRING (1 * CW, 1 * CH), "sector " + _TRIM$(STR$(sec)) + "   moves " + _TRIM$(STR$(moves_made)) + "   time " + MMSS$(el)
    _PRINTSTRING (1 * CW, 2 * CH), "path:" + YN$(onpath) + " room:" + YN$(inroom) + " onDoor:" + YN$(ondoor) + " nearRD:" + YN$(NearRegularDoor) + " nearStr:" + YN$(NearStrongDoor) + " nearSD:" + YN$(nearsd)
    _PRINTSTRING (1 * CW, 3 * CH), "room " + _TRIM$(STR$(rmid)) + "/" + _TRIM$(STR$(ROOM_N)) + "  fought:" + fought + " died:" + died + " boss:" + boss + " looted:" + loot
    _PRINTSTRING (1 * CW, 4 * CH), "doors:" + _TRIM$(STR$(SD_N)) + "  key:" + YN$(has_key) + "  sword:+" + _TRIM$(STR$(item_sword)) + "  realdice:" + YN$(opt_realdice)
    _PRINTSTRING (1 * CW, 5 * CH), "mouse px " + _TRIM$(STR$(mx)) + "," + _TRIM$(STR$(my)) + "  cell " + _TRIM$(STR$(mcx)) + "," + _TRIM$(STR$(mcy)) + "  " + kn
END SUB
