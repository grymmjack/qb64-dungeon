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
    DIM pcx AS INTEGER, pcy AS INTEGER
    _DEST CANVAS
    IF opt_fov THEN
        pcx = c.x \ CW: pcy = c.y \ CH
        IF pcx <> fov_cx OR pcy <> fov_cy THEN ComputeFOV   ' recompute sight only when moved
        FovRender
    ELSE
        _PUTIMAGE (0, 0)-(SW * CW - 1, SH * CH - 1), CANVAS_COPY, CANVAS, (0, 0)-(SW * CW - 1, SH * CH - 1)
    END IF
    render_room_labels
END SUB



' Draw the board entities on top of the map: a monster glyph (§, red on cyan --
' matching the legend) in every live-monster room, or a green $ where a fallen
' rival left recoverable loot. Honours Field of View: with FOV off, every monster
' shows (so you can plan / spot random spawns); with FOV on, only rooms you have
' actually explored (LOS_SEEN) reveal their monster.
SUB DrawEntities
    DIM r AS INTEGER, gx AS INTEGER, gy AS INTEGER, vis AS INTEGER
    _DEST CANVAS
    _FONT CH
    FOR r = 1 TO ROOM_N
        gx = ROOMS(r).cx: gy = ROOMS(r).cy
        IF gx >= 0 AND gy >= 0 AND gx <= 131 AND gy <= 60 THEN
            vis = TRUE
            IF opt_fov THEN
                IF LOS_SEEN(gx, gy) = 0 THEN vis = FALSE
            END IF
            IF vis THEN
                IF ROOMS(r).malive AND LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN
                    COLOR _RGB32(&HFF, &H55, &H55), _RGB32(&H55, &HFF, &HFF)   ' § monster: red on cyan
                    _PRINTSTRING (gx * CW, gy * CH), CHR$(21)
                ELSEIF HasDrop(r) THEN
                    COLOR _RGB32(&H55, &HFF, &H55), BLACK                      ' $ recoverable loot: green
                    _PRINTSTRING (gx * CW, gy * CH), "$"
                END IF
            END IF
        END IF
    NEXT r
END SUB


SUB cursor_draw
    DIM p AS INTEGER
    _DEST CANVAS
    DrawTombstones                       ' grey headstones on cleared rooms
    DrawEntities                         ' monster glyphs + recoverable loot (FOV-aware)
    ' other hot-seat players' tokens -- drawn as their NUMBER (white on their colour)
    IF num_players > 1 THEN
        FOR p = 1 TO num_players
            IF p <> cur_player AND PLAYERS(p).active THEN
                IF NOT opt_fov OR LOS_LIT(PLAYERS(p).cx \ CW, PLAYERS(p).cy \ CH) THEN
                    _FONT CH: COLOR WHITE, PLAYERS(p).kolor
                    _PRINTSTRING (PLAYERS(p).cx, PLAYERS(p).cy), _TRIM$(STR$(p))
                END IF
            END IF
        NEXT p
    END IF
    ' the active player -- their NUMBER, white on legend-blue (the "# Player #" key)
    _FONT CH: COLOR WHITE, _RGB32(&H55, &H55, &HFF)
    _PRINTSTRING (c.x, c.y), _TRIM$(STR$(cur_player))
    ' proximity ring: highlight the cursor when a door of interest is adjacent
    DIM ring AS _UNSIGNED LONG, hasring AS INTEGER
    hasring = FALSE
    IF NearSecretDoorHint THEN
        ring = _RGB32(&H40, &H90, &HFF): hasring = TRUE    ' a hidden secret door is near -- search!
    ELSEIF NearStrongDoor THEN
        ring = _RGB32(&HFF, &H88, &H00): hasring = TRUE    ' a reinforced door is adjacent
    ELSEIF NearRegularDoor THEN
        ring = BROWN: hasring = TRUE                        ' an ordinary door is adjacent
    END IF
    IF hasring THEN
        LINE (c.x, c.y)-(c.x + CW - 1, c.y + CH - 1), ring, B
        LINE (c.x - 1, c.y - 1)-(c.x + CW, c.y + CH), ring, B
    END IF
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
