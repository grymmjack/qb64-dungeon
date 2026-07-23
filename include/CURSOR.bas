' ============================================================================
'  CURSOR.bas -- cursor movement + draw/erase
' ============================================================================

FUNCTION TryMove% (k AS STRING)
    c.prev_x = c.x: c.prev_y = c.y
    IF k = "A" THEN c.x = c.x - CW
    IF k = "D" THEN c.x = c.x + CW
    IF k = "W" THEN c.y = c.y - CH
    IF k = "S" THEN c.y = c.y + CH
    cursor_keep_in_bounds
    IF CanMove THEN
        cursor_erase
        cursor_draw
        IF OnDoorNow THEN Sfx "door" ELSE Sfx "move"
        TryMove = TRUE
    ELSE
        c.x = c.prev_x: c.y = c.prev_y
        Sfx "bump"
        TryMove = FALSE
    END IF
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
    _DEST CANVAS
    LINE (c.x, c.y)-(c.x + CW - 1, c.y + CH - 1), c.cursor_color, BF
END SUB


' TRUE if the cell under the cursor is walkable: path, room floor, door, or secret door.
