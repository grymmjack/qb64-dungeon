' ============================================================================
'  CHAMBERS.bas -- the GAME's big named halls (Armory, The Crypt, King's Quarters...).
'
'  A "chamber" is a DUNGEON! board-game concept, not an engine one: per the rules a
'  chamber holds 3 monsters and NO treasure, so it is a distinct region kind from the
'  coloured ROOMS. This file owns detection (which cells belong to which chamber) and
'  grave seating; the encounter itself lives in game/PLAY.bas (ChamberEncounter).
'
'  Moved out of engine/BOARD.bas -- the engine's board setup now calls the single
'  Game_PopulateBoard() hook (#8) and the game claims BOTH its region kinds there.
'  Reads FULL_COLLIDE via _SOURCE (the caller sets it, or these set it themselves).
' ============================================================================

' Openness of a cell: how many of the surrounding 5x5 cells are walkable (CellKind 1).
' Chambers are wide-open (approaching 25); corridors are thin (~10). _SOURCE = FULL_COLLIDE.
FUNCTION CellOpen% (cx AS INTEGER, cy AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER, cnt AS INTEGER
    FOR dy = -2 TO 2
        FOR dx = -2 TO 2
            nx = cx + dx: ny = cy + dy
            IF nx >= 0 AND nx <= 131 AND ny >= 0 AND ny <= 60 THEN
                IF CellKind(nx, ny) = 1 THEN cnt = cnt + 1
            END IF
        NEXT
    NEXT
    CellOpen% = cnt
END FUNCTION

' Try to enqueue a chamber cell (walkable + open enough + unassigned) into the BFS.
SUB ChamberTry (x AS INTEGER, y AS INTEGER, cid AS INTEGER, openmin AS INTEGER, tail AS INTEGER)
    IF x < 0 OR x > 131 OR y < 0 OR y > 60 THEN EXIT SUB
    IF CHAMBERAT(x, y) <> 0 THEN EXIT SUB
    IF tail > 8000 THEN EXIT SUB
    IF CellKind(x, y) <> 1 THEN EXIT SUB
    IF CellOpen%(x, y) < openmin THEN EXIT SUB
    CHAMBERAT(x, y) = cid: QX(tail) = x: QY(tail) = y: tail = tail + 1
END SUB

' Flood the wide-open region from a seed cell -> chamber cid; record size + centre.
SUB FloodChamber (sx AS INTEGER, sy AS INTEGER, cid AS INTEGER, openmin AS INTEGER)
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM minx AS INTEGER, maxx AS INTEGER, miny AS INTEGER, maxy AS INTEGER
    head = 0: QX(0) = sx: QY(0) = sy: CHAMBERAT(sx, sy) = cid: tail = 1
    minx = sx: maxx = sx: miny = sy: maxy = sy
    DO WHILE head < tail
        x = QX(head): y = QY(head): head = head + 1
        IF x < minx THEN minx = x
        IF x > maxx THEN maxx = x
        IF y < miny THEN miny = y
        IF y > maxy THEN maxy = y
        ChamberTry x + 1, y, cid, openmin, tail
        ChamberTry x - 1, y, cid, openmin, tail
        ChamberTry x, y + 1, cid, openmin, tail
        ChamberTry x, y - 1, cid, openmin, tail
    LOOP
    CHM_CELLS(cid) = tail
    CHM_CX(cid) = (minx + maxx) \ 2: CHM_CY(cid) = (miny + maxy) \ 2
END SUB

' Load the exact hand-authored chamber map from assets/data/chambers.txt (rectangles in
' cells; every walkable cell inside becomes a trigger cell). Returns TRUE if it built >=1
' chamber -- the fixed board means this beats the openness heuristic. Falls through to the
' heuristic when the file is absent or empty.
FUNCTION LoadChambers%
    LoadChambers = 0
    DIM cf AS STRING: cf = DataPath$("assets/data/chambers.txt")   ' data-pack aware
    IF NOT _FILEEXISTS(cf) THEN EXIT FUNCTION
    DIM whole AS STRING, p AS LONG, nl AS LONG, ln AS STRING, hp AS INTEGER
    DIM nm AS STRING, c1 AS INTEGER, r1 AS INTEGER, c2 AS INTEGER, r2 AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, cnt AS INTEGER, oldsrc AS LONG
    FOR y = 0 TO 60: FOR x = 0 TO 131: CHAMBERAT(x, y) = 0: NEXT: NEXT
    FOR x = 1 TO MAXCHAMBER: CHM_DEAD(x) = 0: CHM_EVDONE(x) = 0: CHM_SEEN(x) = 0: NEXT
    NCHAMBER = 0: cur_chamber = 0
    whole = _READFILE$(cf)
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE
    p = 1
    DO WHILE p <= LEN(whole)
        nl = INSTR(p, whole, CHR$(10))
        IF nl = 0 THEN ln = MID$(whole, p): p = LEN(whole) + 1 ELSE ln = MID$(whole, p, nl - p): p = nl + 1
        IF RIGHT$(ln, 1) = CHR$(13) THEN ln = LEFT$(ln, LEN(ln) - 1)   ' strip CR
        hp = INSTR(ln, "#"): IF hp > 0 THEN ln = LEFT$(ln, hp - 1)     ' strip comment
        ln = _TRIM$(ln)
        IF LEN(ln) > 0 AND INSTR(ln, "|") > 0 THEN
            nm = _TRIM$(NthField$(ln, "|", 1))
            c1 = VAL(NthField$(ln, "|", 2)): r1 = VAL(NthField$(ln, "|", 3))
            c2 = VAL(NthField$(ln, "|", 4)): r2 = VAL(NthField$(ln, "|", 5))
            IF LEN(nm) > 0 AND NCHAMBER < MAXCHAMBER THEN
                IF c2 < c1 THEN SWAP c1, c2
                IF r2 < r1 THEN SWAP r1, r2
                IF c1 < 0 THEN c1 = 0
                IF r1 < 0 THEN r1 = 0
                IF c2 > 131 THEN c2 = 131
                IF r2 > 60 THEN r2 = 60
                NCHAMBER = NCHAMBER + 1
                cnt = 0
                FOR y = r1 TO r2
                    FOR x = c1 TO c2
                        IF CHAMBERAT(x, y) = 0 THEN            ' first rectangle wins a shared cell
                            IF CellKind(x, y) >= 1 THEN CHAMBERAT(x, y) = NCHAMBER: cnt = cnt + 1
                        END IF
                    NEXT x
                NEXT y
                CHM_NAME(NCHAMBER) = nm: CHM_CELLS(NCHAMBER) = cnt
                CHM_CX(NCHAMBER) = (c1 + c2) \ 2: CHM_CY(NCHAMBER) = (r1 + r2) \ 2
                CHM_SEC(NCHAMBER) = SECTOR.get_by_xy(CHM_CX(NCHAMBER) * CW, CHM_CY(NCHAMBER) * CH)
                IF CHM_SEC(NCHAMBER) < 1 THEN CHM_SEC(NCHAMBER) = 1
                IF cnt < 1 THEN
                    NCHAMBER = NCHAMBER - 1                    ' the rectangle held no floor -- drop it
                ELSE
                    PickChamberGraves NCHAMBER
                END IF
            END IF
        END IF
    LOOP
    _SOURCE oldsrc
    LoadChambers = (NCHAMBER > 0)
END FUNCTION

' Detect the named CHAMBERS -- the large yellow spaces -- by flooding the wide-open area
' near each chamber label (so thin corridors are excluded). Call AFTER FULL_COLLIDE is
' painted. Fallback only: the hand-authored chambers.txt map wins when present.
SUB DetectChambers
    DIM i AS INTEGER, dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER, j AS INTEGER, skp AS INTEGER
    DIM sx AS INTEGER, sy AS INTEGER, oldsrc AS LONG, seedmin AS INTEGER, floodmin AS INTEGER
    IF LoadChambers THEN EXIT SUB    ' exact hand-authored map (assets/data/chambers.txt) wins
    REDIM made(1 TO 40) AS INTEGER   ' which labels actually seeded a chamber (for multi-word skip)
    seedmin = 18: floodmin = 18      ' wide-open cells only -- keeps chambers off the thin corridors
    FOR ny = 0 TO 60: FOR nx = 0 TO 131: CHAMBERAT(nx, ny) = 0: NEXT: NEXT
    FOR i = 1 TO MAXCHAMBER: CHM_DEAD(i) = 0: CHM_EVDONE(i) = 0: CHM_SEEN(i) = 0: NEXT
    NCHAMBER = 0: cur_chamber = 0
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE
    FOR i = 1 TO LBL_N
        '--- skip a second word of a multi-word chamber name: if an adjacent EARLIER label
        '    already seeded a chamber, this word belongs to it (THE+CRYPT, TORTURE+CHAMBER) ---
        skp = 0
        FOR j = 1 TO i - 1
            IF made(j) THEN
                IF ABS(LBL_X(i) - LBL_X(j)) <= 2 AND ABS(LBL_Y(i) - LBL_Y(j)) <= 2 THEN skp = -1: EXIT FOR
            END IF
        NEXT
        IF NOT skp THEN
        '--- find an open, unassigned seed near this label (labels sit top-left of a chamber) ---
        sx = -1
        FOR dy = -1 TO 8
            FOR dx = -3 TO 10
                nx = LBL_X(i) + dx: ny = LBL_Y(i) + dy
                IF nx >= 0 AND nx <= 131 AND ny >= 0 AND ny <= 60 THEN
                    IF CHAMBERAT(nx, ny) = 0 AND CellKind(nx, ny) = 1 THEN
                        IF CellOpen%(nx, ny) >= seedmin THEN sx = nx: sy = ny
                    END IF
                END IF
                IF sx >= 0 THEN EXIT FOR
            NEXT
            IF sx >= 0 THEN EXIT FOR
        NEXT
        IF sx >= 0 AND NCHAMBER < MAXCHAMBER THEN
            NCHAMBER = NCHAMBER + 1
            FloodChamber sx, sy, NCHAMBER, floodmin
            CHM_NAME(NCHAMBER) = _TRIM$(LBL_T(i))
            CHM_SEC(NCHAMBER) = SECTOR.get_by_xy(sx * CW, sy * CH)
            IF CHM_CELLS(NCHAMBER) < 8 THEN            ' a stray (label on a corridor / tiny pocket) -- drop it
                FOR dy = 0 TO 60: FOR dx = 0 TO 131: IF CHAMBERAT(dx, dy) = NCHAMBER THEN CHAMBERAT(dx, dy) = 0
                NEXT: NEXT
                NCHAMBER = NCHAMBER - 1
            ELSE
                made(i) = -1                           ' this label kept a chamber (blocks its 2nd word)
                PickChamberGraves NCHAMBER              ' 3 spread cells for its eventual monster graves
            END IF
        END IF
        END IF
    NEXT i
    _SOURCE oldsrc
END SUB

' Choose up to 3 well-separated cells inside a chamber (Manhattan distance >= 4 apart) to
' seat its 3 monster graves. Falls back to the chamber centre if the spread can't be met.
SUB PickChamberGraves (cid AS INTEGER)
    DIM x AS INTEGER, y AS INTEGER, n AS INTEGER
    CHM_GX(cid, 1) = -1: CHM_GX(cid, 2) = -1: CHM_GX(cid, 3) = -1
    n = 0
    FOR y = 0 TO 60
        FOR x = 0 TO 131
            IF CHAMBERAT(x, y) = cid THEN
                IF n = 0 THEN
                    CHM_GX(cid, 1) = x: CHM_GY(cid, 1) = y: n = 1
                ELSEIF n = 1 THEN
                    IF ABS(x - CHM_GX(cid, 1)) + ABS(y - CHM_GY(cid, 1)) >= 4 THEN CHM_GX(cid, 2) = x: CHM_GY(cid, 2) = y: n = 2
                ELSEIF n = 2 THEN
                    IF ABS(x - CHM_GX(cid, 1)) + ABS(y - CHM_GY(cid, 1)) >= 4 THEN
                        IF ABS(x - CHM_GX(cid, 2)) + ABS(y - CHM_GY(cid, 2)) >= 4 THEN CHM_GX(cid, 3) = x: CHM_GY(cid, 3) = y: n = 3
                    END IF
                END IF
            END IF
        NEXT x
        IF n >= 3 THEN EXIT FOR
    NEXT y
    FOR n = 1 TO 3                                          ' any slot never filled -> the centre
        IF CHM_GX(cid, n) < 0 THEN CHM_GX(cid, n) = CHM_CX(cid): CHM_GY(cid, n) = CHM_CY(cid)
    NEXT
END SUB

' graves so far at a cell, or 0 if it isn't a chamber cell (guards the 0 index)
FUNCTION ChamberDeadAt% (cx AS INTEGER, cy AS INTEGER)
    DIM id AS INTEGER
    id = CHAMBERAT(cx, cy)
    IF id >= 1 AND id <= NCHAMBER THEN ChamberDeadAt% = CHM_DEAD(id) ELSE ChamberDeadAt% = 0
END FUNCTION
