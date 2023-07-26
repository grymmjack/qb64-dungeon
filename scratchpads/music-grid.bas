''
' Original example (by JP):
' https://qb64phoenix.com/qb64wiki/index.php/PLAY
'
' grymmjack's notes:
'
' Changes to make:
' Humble and simple:
' Fix the top bottom left and right most to have partial plus displays when note fires
'
' Nice to have:
' Variable tempo - note divisors
' Add a bar with the playhead
' Allow hotkeys to adjust the total sequence length
' Drag mouse = on/off without lifting up button (obv. dragderp)
' Patterns where we simply use pageup/down to go to previous and next
'   Maybe a hotkey to toggle loop playback for all the patterns, etc.

'
' Really neat!:
' Allowing QWERTY keyboard and recording (like a tracker)

DIM SHARED grid(16, 16), grid2(16, 16), cur
CONST maxx = 512
CONST maxy = 512
SCREEN _NEWIMAGE(maxx, maxy, 32)
_TITLE "MusicGrid"
cleargrid
$CONSOLE
_CONSOLE ON

DO
    IF TIMER - t# > 1 / 8 THEN ' 1 / 8 = 0.125  (8th note)
        ' debug("TIMER=" + _TRIM$(STR$(TIMER)))
        cur = (cur + 1) AND 15      ' AND 15 = 16 grid long
        t# = TIMER
        ' debug("t#=" + _TRIM$(STR$(t#)))
    END IF
    IF cur <> oldcur THEN
        figuregrid              ' Figure out the grid
        drawgrid                ' using what we figured out draw the cells
        playgrid                ' Make the sound
        oldcur = cur            ' Animation/playback time reset for when column is triggered
    END IF
    domousestuff
    in$ = INKEY$
    IF in$ = "C" OR in$ = "c" THEN cleargrid
LOOP UNTIL in$ = CHR$(27)

SUB drawgrid
    scale! = maxx / 16
    scale2 = maxx \ 16 - 2
    FOR y = 0 TO 15
        y1 = y * scale!
        FOR x = 0 TO 15
            x1 = x * scale!
            c& = _RGB32(grid2(x, y) * 64 + 64, 0, 0) ' Red boxes, red value increases based on if note is on, or neighbor for + = 1 for grid2(x,y)
            LINE (x1, y1)-(x1 + scale2, y1 + scale2), c&, BF
        NEXT x
    NEXT y
END SUB

SUB figuregrid
    FOR y = 0 TO 15
        FOR x = 0 TO 15
            grid2(x, y) = grid(x, y)
        NEXT x
    NEXT y
    FOR y = 1 TO 14
        FOR x = 1 TO 14
            IF grid(x, y) = 1 AND cur = x THEN ' Note exists filled in
                grid2(x, y) = 2 ' Why this?
                 IF grid(x - 1, y) = 0 THEN grid2(x - 1, y) = 1 ' Draws left part of cross
                 IF grid(x + 1, y) = 0 THEN grid2(x + 1, y) = 1 ' Draws right part of cross
                 IF grid(x, y - 1) = 0 THEN grid2(x, y - 1) = 1 ' Draws above part of cross
                 IF grid(x, y + 1) = 0 THEN grid2(x, y + 1) = 1 ' Draws below part of cross
            END IF
        NEXT x
    NEXT y
END SUB

SUB domousestuff
    DO WHILE _MOUSEINPUT
        IF _MOUSEBUTTON(1) THEN
            x = _MOUSEX \ (maxx \ 16)   ' 32
            y = _MOUSEY \ (maxy \ 16)   ' 32
            grid(x, y) = 1 - grid(x, y) ' Toggle cell on off - turn on if off, off if on
        END IF
    LOOP
END SUB

SUB playgrid
    n$ = "L16 "
    scale$ = "O1CO1DO1EO1FO1GO1AO1BO2CO2DO2EO2FO2GO2AO2BO3CO3D"
    ' scale$ = "o1fo1go1ao2co2do2fo2go2ao3co3do3fo3go3ao4co4do4fo"
    FOR y = 15 TO 0 STEP -1 ' Bottom up - bottom = lower top = higher notes
        IF grid(cur, y) = 1 THEN
            note$ = MID$(scale$, 1 + (15 - y) * 3, 3)
            n$ = n$ + note$ + ","   'comma plays 2 or more column notes simultaneously
        END IF
    NEXT y
    n$ = LEFT$(n$, LEN(n$) - 1) ' removing trailing comma
    PLAY n$
END SUB

SUB cleargrid
    FOR y = 0 TO 15
        FOR x = 0 TO 15
            grid(x, y) = 0
        NEXT x
    NEXT y
END SUB

SUB debug(msg AS STRING)
    DIM oldDest AS LONG
    oldDest& = _DEST
    _DEST _CONSOLE
    PRINT msg$
    _DEST oldDest&
END SUB
