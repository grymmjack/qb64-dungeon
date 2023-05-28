'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BI'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bi'

CONST TRUE = -1, FALSE = NOT TRUE

DIM AS STRING BOARD_ANSI, BOARD_ANSI_NO_LABELS
BOARD_ANSI$ = LoadFileFromDisk$("assets/ansi/board-132x60-no-labels.ans")

DIM SHARED AS _UNSIGNED LONG yellow2, black2
yellow2~& = _RGB32(&HFF, &HFF, &H55)
black2~&  = _RGB32(&H00, &H00, &H00)

DIM SHARED AS LONG CANVAS, CANVAS_COPY

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 61   ' SCREEN HEIGHT IN CHARACTERS
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 16   ' HEIGHT OF 1 CHARACTER

$RESIZE:ON
$RESIZE:STRETCH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY& = _NEWIMAGE(SW * CW, SH * CH, 32)
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

' setup CURSOR
TYPE CURSOR
    x AS INTEGER
    y AS INTEGER
    prev_x AS INTEGER
    prev_y AS INTEGER
    cursor_color AS _UNSIGNED LONG
END TYPE

DIM SHARED c AS CURSOR
c.x% = 59*CW
c.y% = 24*CH
c.cursor_color~& = _RGB32(&HFF, &H00, &H00, &HAA)
c.prev_x% = c.x%
c.prev_y% = c.y%

' render initial labels for board
render_room_labels

' draw CURSOR one time to start
CURSOR.draw

' loop waiting for input to move CURSOR
DIM k AS STRING
DIM p AS INTEGER
DO:
    _LIMIT 30
    k$ = UCASE$(INKEY$)
    IF k$ = "" THEN k$ = CHR$(0)
    p% = INSTR("WASD", k$)
    IF p% <> 0 THEN
        CURSOR.move k$
    END IF
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
    IF CURSOR.can_move = TRUE THEN
        CURSOR.keep_in_bounds
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
    IF c.x% < 0 THEN c.x% = 0
    IF c.y% < 0 THEN c.y% = 0
END SUB


FUNCTION CURSOR.can_move%
    DIM AS LONG img_box
    img_box& = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY&, img_box&, (c.x%, c.y%)-(c.x%+CW, c.y%+CH)
    CURSOR.can_move = image_is_monochromatic(img_box&, yellow2~&)
END FUNCTION


SUB CURSOR.erase
    _SOURCE CANVAS_COPY&
    _DEST CANVAS&
    _PUTIMAGE
    _SOURCE CANVAS&
    render_room_labels
END SUB


SUB CURSOR.draw
    LINE (c.x%, c.y%)-(c.x%+CW, c.y%+CH), c.cursor_color~&, BF
END SUB


FUNCTION image_is_monochromatic% (img AS LONG, kolor AS _UNSIGNED LONG)
    DIM AS INTEGER x, y
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
            END IF
        NEXT x%
    NEXT y%
    _SOURCE old_source&
    image_is_monochromatic = TRUE
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

    _PRINTSTRING(14*CW,9*CH), "ARMORY"

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

    _PRINTSTRING(105*CW,21*CH), "KING'S"
    _PRINTSTRING(105*CW,22*CH), "TREASURE"
END SUB


' Loads a whole file from disk into memory
Function LoadFileFromDisk$ (path As String)
    If FileExists(path) Then
        Dim As Long fh: fh = FreeFile

        Open path For Binary Access Read As fh

        LoadFileFromDisk = Input$(LOF(fh), fh)

        Close fh
    End If
End Function

'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BM'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bas'
