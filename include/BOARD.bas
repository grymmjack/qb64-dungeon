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

SUB StartBoard
    _DEST FULL_BOARD: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)    ' pristine board (everything visible)
    InitFog                          ' build the fogged CANVAS_COPY + CANVAS (secret areas sealed)
    render_room_labels
    c.cursor_color = _RGB32(&HFF, &H00, &H00, &HAA)
    c.x = START_CX * CW: c.y = START_CY * CH
    c.prev_x = c.x: c.prev_y = c.y
    cursor_draw
    _DISPLAY
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



SUB render_room_labels
    DIM AS _UNSIGNED LONG fg_color_blue, fg_color_red
    fg_color_blue = _RGB32(&H00, &H00, &HAA)
    fg_color_red = _RGB32(&HFF, &H55, &H55)
    _DEST CANVAS

    COLOR fg_color_red, YELLOW
    _PRINTSTRING (57 * CW, 23 * CH), "START"
    COLOR fg_color_blue, YELLOW
    _PRINTSTRING (57 * CW, 25 * CH), "MAIN"
    _PRINTSTRING (56 * CW, 26 * CH), "GALLERY"
    _PRINTSTRING (14 * CW, 10 * CH), "ARMORY"
    _PRINTSTRING (47 * CW, 7 * CH), "THE"
    _PRINTSTRING (47 * CW, 8 * CH), "CRYPT"
    _PRINTSTRING (83 * CW, 9 * CH), "WIZ'S"
    _PRINTSTRING (84 * CW, 10 * CH), "LAB"
    _PRINTSTRING (93 * CW, 7 * CH), "WIZ'S"
    _PRINTSTRING (93 * CW, 8 * CH), "TREASURE"
    _PRINTSTRING (3 * CW, 26 * CH), "KITCHEN"
    _PRINTSTRING (18 * CW, 23 * CH), "GUARD"
    _PRINTSTRING (18 * CW, 24 * CH), "ROOM"
    _PRINTSTRING (18 * CW, 41 * CH), "STORE"
    _PRINTSTRING (18 * CW, 42 * CH), "ROOM"
    _PRINTSTRING (49 * CW, 39 * CH), "TORTURE"
    _PRINTSTRING (49 * CW, 40 * CH), "CHAMBER"
    _PRINTSTRING (88 * CW, 42 * CH), "QUEEN'S"
    _PRINTSTRING (88 * CW, 43 * CH), "ANNEX"
    _PRINTSTRING (87 * CW, 34 * CH), "QUEEN'S"
    _PRINTSTRING (87 * CW, 35 * CH), "TREASURE"
    _PRINTSTRING (90 * CW, 27 * CH), "KING'S"
    _PRINTSTRING (88 * CW, 28 * CH), "LIBRARY"
    _PRINTSTRING (104 * CW, 21 * CH), "KING'S"
    _PRINTSTRING (104 * CW, 22 * CH), "TREASURE"
END SUB



' [~] debug overlay: cursor position, cell states, move count, timer.
FUNCTION YN$ (b AS INTEGER)
    IF b THEN YN$ = "Y" ELSE YN$ = "N"
END FUNCTION


SUB DrawDebug
    DIM cx AS INTEGER, cy AS INTEGER, sec AS INTEGER, i AS INTEGER
    DIM onpath AS INTEGER, inroom AS INTEGER, ondoor AS INTEGER, onsecret AS INTEGER, nearsd AS INTEGER
    DIM img AS LONG, el AS LONG, bg AS _UNSIGNED LONG
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
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    bg = _RGB32(&H00, &H00, &H40)
    _DEST CANVAS
    LINE (0, 0)-(50 * CW, 5 * CH), bg, BF
    LINE (0, 0)-(50 * CW, 5 * CH), CYANU, B
    COLOR YELLOWU, bg
    _PRINTSTRING (1 * CW, 0 * CH), "DEBUG [~]  px " + _TRIM$(STR$(c.x)) + "," + _TRIM$(STR$(c.y)) + "   cell " + _TRIM$(STR$(cx)) + "," + _TRIM$(STR$(cy))
    _PRINTSTRING (1 * CW, 1 * CH), "sector " + _TRIM$(STR$(sec)) + "   moves " + _TRIM$(STR$(moves_made)) + "   time " + MMSS$(el)
    _PRINTSTRING (1 * CW, 2 * CH), "path:" + YN$(onpath) + " room:" + YN$(inroom) + " door:" + YN$(ondoor) + " secret:" + YN$(onsecret) + " nearSD:" + YN$(nearsd)
    _PRINTSTRING (1 * CW, 3 * CH), "doors:" + _TRIM$(STR$(SD_N)) + "  key:" + YN$(has_key) + "  sword:+" + _TRIM$(STR$(item_sword)) + "  realdice:" + YN$(opt_realdice)
END SUB
