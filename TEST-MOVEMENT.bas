CONST TRUE = -1, FALSE = NOT TRUE, CW = 8, CH = 16, SW = 320, SH = 200

DIM SHARED AS _UNSIGNED LONG yellow, black
yellow~& = _RGB32(&HFF, &HFF, &H55)
black~&  = _RGB32(&H00, &H00, &H00)

DIM SHARED AS LONG CANVAS, CANVAS_COPY
CANVAS&      = _NEWIMAGE(SW, SH, 32)
CANVAS_COPY& = _NEWIMAGE(SW, SH, 32)

' clear canvas
SCREEN CANVAS&
_DEST CANVAS&
_SOURCE CANVAS&
CLS , black~&

' draw a yellow box
LINE (0,0)-(10 * CW, 10 * CH), yellow~&, BF
' draw another longer thinner yellow box
LINE (9 * CW, 0)-(20 * CW, 3 * CH), yellow~&, BF
' draw another yellow box
LINE (13 * CW, 2 * CH)-(30 * CW, 9 * CH), yellow~&, BF
_DEST CANVAS_COPY&
_PUTIMAGE
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
c.x% = 0
c.y% = 0
c.cursor_color~& = _RGB32(&HFF, &H00, &H00)
c.prev_x% = 0
c.prev_y% = 0

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
        ' CURSOR.keep_in_bounds
        CURSOR.erase
        CURSOR.draw
    ELSE
        c.x% = c.prev_x%
        c.y% = c.prev_y%
    END IF
END SUB


SUB CURSOR.keep_in_bounds
    IF c.x% + CW > SW THEN c.x% = SW-CW
    IF c.y% + CH > SH THEN c.y% = SH-CH
    IF c.x% < 0 THEN c.x% = 0
    IF c.y% < 0 THEN c.y% = 0
END SUB


FUNCTION CURSOR.can_move%
    DIM AS LONG img_box
    img_box& = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY&, img_box&, (c.x%, c.y%)-(c.x%+CW, c.y%+CH)
    CURSOR.can_move = image_is_monochromatic(img_box&, yellow~&)
END FUNCTION


SUB CURSOR.erase
    _SOURCE CANVAS_COPY&
    _DEST CANVAS&
    _PUTIMAGE
    _SOURCE CANVAS&
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
    FOR y% = 0 TO _HEIGHT(img&)-1
        FOR x% = 0 TO _WIDTH(img&)-1
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
