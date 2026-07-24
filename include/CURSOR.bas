' ============================================================================
'  CURSOR.bas -- cursor movement + draw/erase
' ============================================================================

FUNCTION TryMove% (k AS STRING)
    c.prev_x = c.x: c.prev_y = c.y
    SELECT CASE k
        CASE "A": c.x = c.x - CW
        CASE "D": c.x = c.x + CW
        CASE "W": c.y = c.y - CH
        CASE "S": c.y = c.y + CH
        CASE "NW": c.x = c.x - CW: c.y = c.y - CH
        CASE "NE": c.x = c.x + CW: c.y = c.y - CH
        CASE "SW": c.x = c.x - CW: c.y = c.y + CH
        CASE "SE": c.x = c.x + CW: c.y = c.y + CH
    END SELECT
    cursor_keep_in_bounds
    IF CanMove THEN
        cursor_erase
        cursor_draw
        IF OnSecretDoorNow THEN
            Sfx "secretpass"
        ELSEIF OnDoorNow THEN
            Sfx "door"
        ELSE
            Sfx "move"
        END IF
        TryMove = TRUE
    ELSE
        c.x = c.prev_x: c.y = c.prev_y
        Sfx "bump"
        TryMove = FALSE
    END IF
END FUNCTION


' TRUE if k is any of the eight movement directions (orthogonal + diagonal).
FUNCTION IsMoveKey% (k AS STRING)
    SELECT CASE k
        CASE "W", "A", "S", "D", "NW", "NE", "SW", "SE": IsMoveKey = TRUE
        CASE ELSE: IsMoveKey = FALSE
    END SELECT
END FUNCTION


' TRUE if the cursor cell contains a door (brown), i.e. we just stepped on one.

SUB cursor_keep_in_bounds
    IF c.x + CW > SW * CW THEN c.x = SW - CW
    IF c.y + CH > SH * CH THEN c.y = SH - CH
    IF c.x < 0 THEN c.x = 0
    IF c.y < 0 THEN c.y = 0
END SUB



SUB cursor_erase
    _DEST CANVAS
    _PUTIMAGE (0, 0)-(SW * CW - 1, SH * CH - 1), CANVAS_COPY, CANVAS, (0, 0)-(SW * CW - 1, SH * CH - 1)
    render_room_labels
END SUB



SUB cursor_draw
    DIM p AS INTEGER
    _DEST CANVAS
    ' other hot-seat players' tokens (drawn under the active cursor)
    IF num_players > 1 THEN
        FOR p = 1 TO num_players
            IF p <> cur_player AND PLAYERS(p).active THEN
                LINE (PLAYERS(p).cx, PLAYERS(p).cy)-(PLAYERS(p).cx + CW - 1, PLAYERS(p).cy + CH - 1), PLAYERS(p).kolor, BF
            END IF
        NEXT p
    END IF
    LINE (c.x, c.y)-(c.x + CW - 1, c.y + CH - 1), c.cursor_color, BF
END SUB


' Fold arrow keys (2-char INKEY$) and the numeric keypad into WASD.
FUNCTION NormKey$ (k AS STRING)
    DIM r AS STRING
    r = k
    IF LEN(k) = 2 THEN
        SELECT CASE ASC(RIGHT$(k, 1))
            CASE 72: r = "W"        ' up arrow
            CASE 80: r = "S"        ' down arrow
            CASE 75: r = "A"        ' left arrow
            CASE 77: r = "D"        ' right arrow
            CASE 71: r = "NW"       ' Home  (numpad 7, NumLock off)
            CASE 73: r = "NE"       ' PgUp  (numpad 9)
            CASE 79: r = "SW"       ' End   (numpad 1)
            CASE 81: r = "SE"       ' PgDn  (numpad 3)
        END SELECT
    ELSEIF k = "8" THEN
        r = "W"
    ELSEIF k = "2" THEN
        r = "S"
    ELSEIF k = "4" THEN
        r = "A"
    ELSEIF k = "6" THEN
        r = "D"
    ELSEIF k = "7" THEN
        r = "NW"                    ' numpad diagonals (NumLock on)
    ELSEIF k = "9" THEN
        r = "NE"
    ELSEIF k = "1" THEN
        r = "SW"
    ELSEIF k = "3" THEN
        r = "SE"
    END IF
    NormKey$ = r
END FUNCTION
