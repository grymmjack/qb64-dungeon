$Debug
'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BI'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bi'

CONST TRUE = -1, FALSE = NOT TRUE

DIM AS STRING BOARD_ANSI, BOARD_ANSI_NO_LABELS, BOARD_ANSI_LEVEL_SECTORS
BOARD_ANSI$ = LoadFileFromDisk$("assets/ansi/board-132x50-no-labels.ans")
BOARD_ANSI_LEVEL_SECTORS$ = LoadFileFromDisk$("assets/ansi/board-132x50-no-labels.ans")

DIM SHARED AS _UNSIGNED LONG yellow2, black2, brown2, bright_blue2
yellow2~&      = _RGB32(&HFF, &HFF, &H55)
black2~&       = _RGB32(&H00, &H00, &H00)
brown2~&       = _RGB32(&HAA, &H55, &H00)
bright_blue2~& = _RGB32(&H55, &H55, &HFF)

DIM SHARED AS LONG CANVAS, CANVAS_COPY, LEVEL_SECTORS

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 51   ' SCREEN HEIGHT IN CHARACTERS + 1 MORE TO PREVENT SCOLLING OFF
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 16   ' HEIGHT OF 1 CHARACTER

$RESIZE:ON
$RESIZE:STRETCH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY& = _NEWIMAGE(SW * CW, SH * CH, 32)
LEVEL_SECTORS& = _NEWIMAGE(SW * CW, SH * CH, 32)
_FONT CH
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

' clear canvas
SCREEN CANVAS&
_DEST CANVAS&
_SOURCE CANVAS&
CLS , black2~&
PrintANSI(BOARD_ANSI$)

' copy canvas to the copy
_DEST CANVAS_COPY&
CLS , black2~&
PrintANSI(BOARD_ANSI$)
_DEST CANVAS&

' load level sectors
_DEST LEVEL_SECTORS&
CLS , black2~&
PrintANSI(BOARD_ANSI_LEVEL_SECTORS$)
_DEST CANVAS&

TYPE SECTOR
    start_x AS INTEGER
    start_y AS INTEGER
    end_x   AS INTEGER
    end_y   AS INTEGER
    w       AS INTEGER
    h       AS INTEGER
    kolor   AS _UNSIGNED LONG
    label   AS STRING
END TYPE
DIM SHARED SECTORS(1 TO 9) AS SECTOR

TYPE CURSOR
    x              AS INTEGER
    y              AS INTEGER
    prev_x         AS INTEGER
    prev_y         AS INTEGER
    cursor_color   AS _UNSIGNED LONG
    in_sector      AS INTEGER
    in_room        AS INTEGER
    on_path        AS INTEGER
    on_door        AS INTEGER
    on_secret_door AS INTEGER
END TYPE
DIM SHARED c AS CURSOR

' setup CURSOR
c.x% = 59*CW
c.y% = 24*CH
c.cursor_color~& = _RGB32(&HFF, &H00, &H00, &HAA)
c.prev_x% = c.x%
c.prev_y% = c.y%

' setup SECTORS
' LEVEL 1
SECTORS(1).kolor~&  = _RGB32(&H55, &HFF, &H55) ' BRIGHT GREEN
SECTORS(1).label$   = "LEVEL 1 - MAIN GALLERY"
SECTORS(1).start_x% = 41
SECTORS(1).start_y% = 17
SECTORS(1).end_x%   = 79
SECTORS(1).end_y%   = 32
SECTORS(1).w%       = SECTORS(1).end_x% - SECTORS(1).start_x%
SECTORS(1).h%       = SECTORS(1).end_y% - SECTORS(1).start_y%

' LEVEL 2
SECTORS(2).kolor~&  = _RGB32(&H00, &HAA, &H00) ' DARK GREEN
SECTORS(2).label$   = "LEVEL 2 - GUARD ROOM + KITCHEN"
SECTORS(2).start_x% = 1
SECTORS(2).start_y% = 17
SECTORS(2).end_x%   = 40
SECTORS(2).end_y%   = 33
SECTORS(2).w%       = SECTORS(2).end_x% - SECTORS(2).start_x%
SECTORS(2).h%       = SECTORS(2).end_y% - SECTORS(2).start_y%

' LEVEL 3
SECTORS(3).kolor~& = _RGB32(&HAA, &H00, &H00) ' DARK RED
SECTORS(3).label$   = "LEVEL 3 - ARMORY"
SECTORS(3).start_x% = 1
SECTORS(3).start_y% = 1
SECTORS(3).end_x%   = 34
SECTORS(3).end_y%   = 16
SECTORS(3).w%       = SECTORS(3).end_x% - SECTORS(3).start_x%
SECTORS(3).h%       = SECTORS(3).end_y% - SECTORS(3).start_y%

' LEVEL 4
SECTORS(4).kolor~& = _RGB32(&HFF, &H55, &H55) ' BRIGHT RED
SECTORS(4).label$   = "LEVEL 4 - STORE ROOM"
SECTORS(4).start_x% = 1
SECTORS(4).start_y% = 34
SECTORS(4).end_x%   = 40
SECTORS(4).end_y%   = 50
SECTORS(4).w%       = SECTORS(4).end_x% - SECTORS(4).start_x%
SECTORS(4).h%       = SECTORS(4).end_y% - SECTORS(4).start_y%

' LEVEL 5
SECTORS(5).kolor~& = _RGB32(&HFF, &H55, &HFF) ' BRIGHT PURPLE
SECTORS(5).label$   = "LEVEL 5 - TORTURE CHAMBER"
SECTORS(5).start_x% = 41
SECTORS(5).start_y% = 33
SECTORS(5).end_x%   = 80
SECTORS(5).end_y%   = 50
SECTORS(5).w%       = SECTORS(5).end_x% - SECTORS(5).start_x%
SECTORS(5).h%       = SECTORS(5).end_y% - SECTORS(5).start_y%

' LEVEL 6
SECTORS(6).kolor~& = _RGB32(&H00, &HAA, &HAA) ' DARK CYAN
SECTORS(6).label$   = "LEVEL 6 - KING'S QUARTERS"
SECTORS(6).start_x% = 80
SECTORS(6).start_y% = 17
SECTORS(6).end_x%   = 117
SECTORS(6).end_y%   = 32
SECTORS(6).w%       = SECTORS(6).end_x% - SECTORS(6).start_x%
SECTORS(6).h%       = SECTORS(6).end_y% - SECTORS(6).start_y%

' LEVEL 7
SECTORS(7).kolor~& = _RGB32(&H55, &HFF, &HFF) ' BRIGHT CYAN
SECTORS(7).label$   = "LEVEL 7 - WIZ'S QUARTERS"
SECTORS(7).start_x% = 79
SECTORS(7).start_y% = 1
SECTORS(7).end_x%   = 117
SECTORS(7).end_y%   = 16
SECTORS(7).w%       = SECTORS(7).end_x% - SECTORS(7).start_x%
SECTORS(7).h%       = SECTORS(7).end_y% - SECTORS(7).start_y%

' LEVEL 8
SECTORS(8).kolor~& = _RGB32(&H55, &H55, &H55) ' BRIGHT BLACK
SECTORS(8).label$   = "LEVEL 8 - QUEEN'S QUARTERS"
SECTORS(8).start_x% = 81
SECTORS(8).start_y% = 33
SECTORS(8).end_x%   = 117
SECTORS(8).end_y%   = 50
SECTORS(8).w%       = SECTORS(8).end_x% - SECTORS(8).start_x%
SECTORS(8).h%       = SECTORS(8).end_y% - SECTORS(8).start_y%

' LEVEL 9
SECTORS(9).kolor~& = _RGB32(&HAA, &H00, &HAA) ' DARK PURPLE
SECTORS(9).label$   = "LEVEL 9 - THE CRYPT"
SECTORS(9).start_x% = 35
SECTORS(9).start_y% = 1
SECTORS(9).end_x%   = 78
SECTORS(9).end_y%   = 16
SECTORS(9).w%       = SECTORS(9).end_x% - SECTORS(9).start_x%
SECTORS(9).h%       = SECTORS(9).end_y% - SECTORS(9).start_y%

' render initial labels for board
render_room_labels

' draw CURSOR one time to start
CURSOR.draw

' loop waiting for input to move CURSOR
DIM k AS STRING
DIM p AS INTEGER
DIM cur_sector AS INTEGER
DO:
    _LIMIT 30
    k$ = UCASE$(INKEY$)
    IF k$ = "" THEN k$ = CHR$(0)
    p% = INSTR("WASD", k$)
    IF p% <> 0 THEN
        CURSOR.move k$
    END IF
    CURSOR.update_state
    _DISPLAY
LOOP UNTIL k$=CHR$(27)
SYSTEM



SUB CURSOR.move (k AS STRING)
    c.prev_x% = c.x%
    c.prev_y% = c.y%
    IF k$ = "A" THEN c.x% = c.x% - CW
    IF k$ = "D" THEN c.x% = c.x% + CW
    IF k$ = "W" THEN c.y% = c.y% - CH
    IF k$ = "S" THEN c.y% = c.y% + CH
    CURSOR.keep_in_bounds
    IF CURSOR.can_move = TRUE THEN
        CURSOR.erase
        CURSOR.draw
        SOUND 350, 0.1
    ELSE
        c.x% = c.prev_x%
        c.y% = c.prev_y%
        SOUND 200, 0.1
    END IF
END SUB


SUB CURSOR.keep_in_bounds
    IF c.x% + CW > SW * CW THEN c.x% = SW-CW
    IF c.y% + CH > SH * CH THEN c.y% = SH-CH
    IF c.x% - CW < 0 THEN c.x% = 0
    IF c.y% - CH < 0 THEN c.y% = 0
    IF c.x% > SW * CW THEN c.x% = SW-CW
    IF c.y% > SH * CH THEN c.y% = SH-CH
    IF c.x% < 0 THEN c.x% = 0
    IF c.y% < 0 THEN c.y% = 0
END SUB


SUB CURSOR.update_state
    DIM AS LONG img_box
    DIM cur_sector AS INTEGER
    DIM in_sector AS SECTOR
    DIM state AS STRING
    state$ = ""
    img_box& = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY&, img_box&, (c.x%, c.y%)-(c.x%+CW, c.y%+CH)
    c.on_path%        = is_path(img_box&)
    c.in_room%        = in_room(img_box&)
    c.on_door%        = is_door(img_box&)
    c.on_secret_door% = is_secret_door(img_box&)
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H00, &H00, &H00)
    cur_sector%  = SECTOR.get_by_xy(c.x%, c.y%)
    in_sector    = SECTORS(cur_sector%)
    _PRINTSTRING(0, 50 * CH), "SECTOR(" + _TRIM$(STR$(cur_sector%)) + "): " + in_sector.label$
    ' show state
    IF c.on_path% = TRUE THEN state$ = state$ + " ON PATH"
    IF c.in_room% = TRUE THEN state$ = state$ + " IN ROOM"
    IF c.on_door% = TRUE THEN state$ = state$ + " ON DOOR"
    IF c.on_secret_door% = TRUE THEN state$ = state$ + " ON SECRET DOOR"
    _PRINTSTRING(80 * CW, 50 * CH), "                                             "
    _PRINTSTRING(80 * CW, 50 * CH), state$
END SUB


FUNCTION CURSOR.can_move%
    DIM AS LONG img_box
    DIM AS INTEGER __on_path, __in_room, __on_door, __on_secret_door
    img_box& = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY&, img_box&, (c.x%, c.y%)-(c.x%+CW, c.y%+CH)
    __on_path%        = is_path(img_box&)
    __in_room%        = in_room(img_box&)
    __on_door%        = is_door(img_box&)
    __on_secret_door% = is_secret_door(img_box&)
    CURSOR.can_move = __on_path% OR __in_room% OR __on_door% OR __on_secret_door%
END FUNCTION


SUB CURSOR.erase
    _SOURCE CANVAS_COPY&
    _DEST CANVAS&
    _PUTIMAGE
    _SOURCE CANVAS&
    render_room_labels
END SUB


SUB CURSOR.draw
    LINE (c.x%, c.y%)-(c.x%+CW-1, c.y%+CH-1), c.cursor_color~&, BF
END SUB


FUNCTION image_is_monochromatic% (img AS LONG, kolor AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor
    DIM AS _UNSIGNED LONG check_color
    DIM AS LONG old_source
    old_source& = _SOURCE
    _SOURCE img&
    FOR y% = 0 TO _HEIGHT(img&) - 1
        FOR x% = 0 TO _WIDTH(img&) - 1
            check_color~& = POINT(x%, y%)
            IF (check_color~& <> kolor~&) THEN
                _SOURCE old_source&
                image_is_monochromatic = FALSE
                EXIT FUNCTION
            ELSE
                IF check_color~& = kolor~& THEN has_kolor% = TRUE
            END IF
        NEXT x%
    NEXT y%
    _SOURCE old_source&
    image_is_monochromatic = has_kolor%
END FUNCTION


FUNCTION image_is_diachromatic% (img AS LONG, kolor1 AS _UNSIGNED LONG, kolor2 AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor1, has_kolor2
    DIM AS _UNSIGNED LONG check_color
    DIM AS LONG old_source
    old_source& = _SOURCE
    _SOURCE img&
    FOR y% = 0 TO _HEIGHT(img&) - 1
        FOR x% = 0 TO _WIDTH(img&) - 1 
            check_color~& = POINT(x%, y%)
            IF (check_color~& <> kolor1~&) AND (check_color~& <> kolor2~&) THEN
                _SOURCE old_source&
                image_is_diachromatic = FALSE
                EXIT FUNCTION
            ELSE
                IF check_color~& = kolor1~& THEN has_kolor1% = TRUE
                IF check_color~& = kolor2~& THEN has_kolor2% = TRUE
            END IF
        NEXT x%
    NEXT y%
    _SOURCE old_source&
    image_is_diachromatic = has_kolor1% AND has_kolor2%
END FUNCTION


FUNCTION is_path% (img AS LONG)
    c.on_path% = image_is_monochromatic(img&, yellow2~&)
    is_path = c.on_path%
END FUNCTION

FUNCTION in_room% (img AS LONG)
    DIM sector_color AS _UNSIGNED LONG
    DIM sector AS INTEGER
    sector% = SECTOR.get_by_xy(c.x%, c.y%)
    sector_color~& = SECTORS(sector%).kolor~&
    c.in_room% = ( _
           image_is_diachromatic(img&, sector_color~&, brown2~&) _
        OR image_is_diachromatic(img&, sector_color~&, bright_blue2~&) _
        OR image_is_monochromatic(img&, sector_color~&) _
    )
    in_room = c.in_room%
END FUNCTION

FUNCTION is_door% (img AS LONG)
    DIM AS INTEGER is_door_on_path, is_door_in_room, is_door_fullblock, sector
    DIM sector_color AS _UNSIGNED LONG
    sector%            = SECTOR.get_by_xy(c.x%, c.y%)
    sector_color~&     = SECTORS(sector%).kolor~&
    is_door_on_path%   = image_is_diachromatic(img&, yellow2~&, brown2~&)
    is_door_in_room%   = image_is_diachromatic(img&, sector_color~&, brown2~&)
    is_door_fullblock% = image_is_monochromatic(img&, brown2~&)
    c.on_door%         = is_door_on_path% OR is_door_in_room% OR is_door_fullblock%
    is_door = c.on_door%
END FUNCTION


FUNCTION is_secret_door% (img AS LONG)
    DIM AS INTEGER is_secret_door_on_path, is_secret_door_in_room, is_secret_door_fullblock, sector
    DIM sector_color AS _UNSIGNED LONG
    sector%                   = SECTOR.get_by_xy(c.x%, c.y%)
    sector_color~&            = SECTORS(sector%).kolor~&
    is_secret_door_on_path%   = image_is_diachromatic(img&, yellow2~&, bright_blue2~&)
    is_secret_door_in_room%   = image_is_diachromatic(img&, sector_color~&, bright_blue2~&)
    is_secret_door_fullblock% = image_is_monochromatic(img&, bright_blue2~&)
    c.on_secret_door%         = is_secret_door_on_path% OR is_secret_door_in_room% OR is_secret_door_fullblock%
    is_secret_door = c.on_secret_door%
END FUNCTION



SUB render_room_labels
    DIM AS _UNSIGNED LONG fg_color_blue, fg_color_red
    fg_color_blue~& = _RGB32(&H00, &H00, &HAA)
    fg_color_red~&  = _RGB32(&HFF, &H55, &H55)

    COLOR fg_color_red~&, yellow2~&
    _PRINTSTRING(57*CW,23*CH), "START"

    COLOR fg_color_blue~&, yellow2~&

    _PRINTSTRING(57*CW,25*CH), "MAIN"
    _PRINTSTRING(56*CW,26*CH), "GALLERY"

    _PRINTSTRING(14*CW,10*CH), "ARMORY"

    _PRINTSTRING(47*CW,7*CH), "THE"
    _PRINTSTRING(47*CW,8*CH), "CRYPT"

    _PRINTSTRING(83*CW,9*CH), "WIZ'S"
    _PRINTSTRING(84*CW,10*CH), "LAB"

    _PRINTSTRING(93*CW,7*CH), "WIZ'S"
    _PRINTSTRING(93*CW,8*CH), "TREASURE"

    _PRINTSTRING(3*CW,26*CH), "KITCHEN"

    _PRINTSTRING(18*CW,23*CH), "GUARD"
    _PRINTSTRING(18*CW,24*CH), "ROOM"

    _PRINTSTRING(18*CW,41*CH), "STORE"
    _PRINTSTRING(18*CW,42*CH), "ROOM"

    _PRINTSTRING(49*CW,39*CH), "TORTURE"
    _PRINTSTRING(49*CW,40*CH), "CHAMBER"

    _PRINTSTRING(88*CW,42*CH), "QUEEN'S"
    _PRINTSTRING(88*CW,43*CH), "ANNEX"

    _PRINTSTRING(87*CW,34*CH), "QUEEN'S"
    _PRINTSTRING(87*CW,35*CH), "TREASURE"

    _PRINTSTRING(90*CW,27*CH), "KING'S"
    _PRINTSTRING(88*CW,28*CH), "LIBRARY"

    _PRINTSTRING(104*CW,21*CH), "KING'S"
    _PRINTSTRING(104*CW,22*CH), "TREASURE"
END SUB


' gets sector
FUNCTION SECTOR.get_by_xy% (x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER
    DIM s AS SECTOR
    DIM AS INTEGER sx, ex, sy, ey
    FOR i% = 1 TO 9
        s = SECTORS(i%)
        sx% = (s.start_x% - 1) * CW
        ex% = (s.end_x% - 1) * CW
        sy% = (s.start_y% - 1) * CH
        ey% = (s.end_y% - 1) * CH
        IF x% >= sx% AND x% <= ex% AND y% >= sy% AND y% <= ey% THEN
            SECTOR.get_by_xy% = i%
            EXIT FUNCTION
        END IF
    NEXT i%
    SECTOR.get_by_xy% = 0
END FUNCTION


' Loads a whole file from disk into memory
FUNCTION LoadFileFromDisk$ (path AS STRING)
    IF FILEEXISTS(path) THEN
        DIM AS LONG fh: fh& = FREEFILE
        OPEN path$ FOR BINARY ACCESS READ AS fh
        LoadFileFromDisk = INPUT$(LOF(fh), fh)
        CLOSE fh
    END IF
END FUNCTION

'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BM'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bas'
