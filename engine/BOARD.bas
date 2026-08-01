' ============================================================================
'  BOARD.bas -- board render, fog-of-war, secret doors, pixel-colour collision
' ============================================================================

' (DoSearch moved to game/PLAY.bas -- the search ODDS are a DUNGEON! rule (class
'  secret_bonus / Secret Door Card). The engine keeps the doors themselves and
'  RevealRegionFromDoor, which the game calls.)


' Classify a cell of FULL_BOARD by its centre pixel (caller sets _SOURCE FULL_BOARD):
' 0 = wall, 1 = walkable terrain (path/room/door), 2 = secret-door tile.

FUNCTION CellKind% (cx AS INTEGER, cy AS INTEGER)
    DIM col AS _UNSIGNED LONG, floor AS _UNSIGNED LONG
    col = POINT(cx * CW + CW \ 2, cy * CH + CH \ 2)
    IF col = BRIGHT_BLUE THEN CellKind = 2: EXIT FUNCTION
    IF col = YELLOW OR col = BROWN THEN CellKind = 1: EXIT FUNCTION
    floor = Game_FloorColorAt~&(cx * CW, cy * CH)      ' game hook: what counts as floor here?
    IF floor <> 0 THEN
        IF col = floor THEN CellKind = 1: EXIT FUNCTION
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
    ' GOTCHA: the hit counter must NOT be named `brown`. QB64 identifiers are
    ' case-insensitive, so a local `brown` shadows the shared BROWN colour and
    ' `POINT(...) = BROWN` silently compares the pixel against the counter (0)
    ' instead of AA5500 -- so this found ZERO doors, `MarkStrongDoors` marked
    ' nothing, and reinforced doors never appeared in the game. Compare
    ' DetectSecretDoors, whose `blue` vs BRIGHT_BLUE never collided and worked.
    DIM cx AS INTEGER, cy AS INTEGER, px AS INTEGER, py AS INTEGER, hits AS INTEGER
    DOOR_N = 0
    _SOURCE FULL_BOARD
    FOR cy = 1 TO SH - 4
        FOR cx = 1 TO SW - 2
            hits = 0
            FOR py = 1 TO CH - 1 STEP 2
                FOR px = 1 TO CW - 1 STEP 2
                    IF POINT(cx * CW + px, cy * CH + py) = BROWN THEN hits = hits + 1
                NEXT px
            NEXT py
            IF hits >= 2 AND DOOR_N < UBOUND(DOOR_X) THEN
                DOOR_N = DOOR_N + 1
                DOOR_X(DOOR_N) = cx: DOOR_Y(DOOR_N) = cy
            END IF
        NEXT cx
    NEXT cy
END SUB


' Flood-fill the board's coloured room blocks into individual ROOMs, one per
' connected block of a sector's colour, recording a centre cell and cell->room
' map (ROOMAT). Every reachable room later gets its own monster + treasure.


' (Chamber detection + the ROOMAT flood helper moved to game/CHAMBERS.bas and
'  game/SECTOR.bas -- both are DUNGEON! region concepts, claimed via Game_PopulateBoard.)







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
' (BreakDoorAttempt% moved to game/PLAY.bas -- the STR check is a game rule.)


' Build the played board from FULL_BOARD: flood-fill the area reachable from
' START without crossing a door (the "public" area), then black out every
' walkable cell that is only reachable through a door, plus the doors.

' Load the hand-painted secret mask (assets/ansi/board-132x50-secret-mask.ans). Any non-black
' cell is secret; same-colour 4-connected runs form a REGION (a colour change or gap splits
' regions). Fills SECRET + MASKREG + MASKCOL. Returns TRUE (and sets MASK_ON) if it painted
' >=1 secret cell -- the exact, art-as-data replacement for the openness/flood heuristic.
FUNCTION LoadSecretMask%
    LoadSecretMask = 0: MASK_ON = FALSE
    IF NOT _FILEEXISTS(AnsiFile$("board-132x50-secret-mask.ans")) THEN EXIT FUNCTION
    DIM mb AS STRING, mimg AS LONG, olddest AS LONG, oldsrc AS LONG
    DIM x AS INTEGER, y AS INTEGER, cnt AS INTEGER, regid AS INTEGER
    DIM head AS INTEGER, tail AS INTEGER, cx AS INTEGER, cy AS INTEGER
    mb = _READFILE$(AnsiFile$("board-132x50-secret-mask.ans"))
    IF LEN(mb) = 0 THEN EXIT FUNCTION
    mb = MaskNormalize$(mb)                   ' strip CR/LF + reset each SGR run (see ansilint / MaskNormalize$)
    mimg = _NEWIMAGE(SW * CW, SH * CH, 32)
    olddest = _DEST: _DEST mimg: _FONT CH: CLS , BLACK
    ANSI_Print (mb)
    _DEST olddest
    oldsrc = _SOURCE: _SOURCE mimg                    ' sample the mask's cell colours
    cnt = 0
    FOR y = 0 TO SH - 1
        FOR x = 0 TO SW - 1
            MASKCOL(x, y) = MaskSample~&(x, y): MASKREG(x, y) = 0
            IF MASKCOL(x, y) <> BLACK THEN cnt = cnt + 1
        NEXT x
    NEXT y
    _SOURCE oldsrc: _FREEIMAGE mimg
    IF cnt = 0 THEN EXIT FUNCTION                     ' empty mask -> caller uses the flood instead
    ' region ids: same-colour 4-connected components
    regid = 0
    FOR y = 0 TO SH - 1
        FOR x = 0 TO SW - 1
            IF MASKCOL(x, y) <> BLACK AND MASKREG(x, y) = 0 THEN
                regid = regid + 1
                head = 0: QX(0) = x: QY(0) = y: MASKREG(x, y) = regid: tail = 1
                DO WHILE head < tail
                    cx = QX(head): cy = QY(head): head = head + 1
                    MaskFlood cx - 1, cy, regid, MASKCOL(cx, cy), tail
                    MaskFlood cx + 1, cy, regid, MASKCOL(cx, cy), tail
                    MaskFlood cx, cy - 1, regid, MASKCOL(cx, cy), tail
                    MaskFlood cx, cy + 1, regid, MASKCOL(cx, cy), tail
                LOOP
            END IF
        NEXT x
    NEXT y
    FOR y = 0 TO SH - 1: FOR x = 0 TO SW - 1: IF MASKREG(x, y) > 0 THEN SECRET(x, y) = 1
    NEXT x: NEXT y
    MASK_ON = -1: LoadSecretMask = -1
END FUNCTION

' Robust cell-colour sample for the mask (centre, then the 4 mid-half points, so a cell
' painted as a half-block still registers). _SOURCE must be the mask image. BLACK = public.
FUNCTION MaskSample~& (cx AS INTEGER, cy AS INTEGER)
    DIM bx AS INTEGER, by AS INTEGER, kol AS _UNSIGNED LONG
    bx = cx * CW: by = cy * CH
    kol = POINT(bx + CW \ 2, by + CH \ 2): IF kol <> BLACK THEN MaskSample~& = kol: EXIT FUNCTION
    kol = POINT(bx + CW \ 2, by + CH \ 4): IF kol <> BLACK THEN MaskSample~& = kol: EXIT FUNCTION
    kol = POINT(bx + CW \ 2, by + 3 * CH \ 4): IF kol <> BLACK THEN MaskSample~& = kol: EXIT FUNCTION
    kol = POINT(bx + CW \ 4, by + CH \ 2): IF kol <> BLACK THEN MaskSample~& = kol: EXIT FUNCTION
    kol = POINT(bx + 3 * CW \ 4, by + CH \ 2): IF kol <> BLACK THEN MaskSample~& = kol: EXIT FUNCTION
    MaskSample~& = BLACK
END FUNCTION

' Region-flood helper: join a same-colour, unassigned neighbour into region regid.
SUB MaskFlood (nx AS INTEGER, ny AS INTEGER, regid AS INTEGER, wantcol AS _UNSIGNED LONG, tail AS INTEGER)
    IF nx < 0 OR nx > SW - 1 OR ny < 0 OR ny > SH - 1 THEN EXIT SUB
    IF MASKREG(nx, ny) <> 0 THEN EXIT SUB
    IF MASKCOL(nx, ny) <> wantcol THEN EXIT SUB       ' colour change = a new region boundary
    MASKREG(nx, ny) = regid
    QX(tail) = nx: QY(tail) = ny: tail = tail + 1
END SUB

' Which mask region a secret door opens (its own cell, else the first painted neighbour).
FUNCTION RegionAtDoor% (di AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER
    dx = SD_X(di): dy = SD_Y(di)
    RegionAtDoor = 0
    IF MASKREG(dx, dy) > 0 THEN RegionAtDoor = MASKREG(dx, dy): EXIT FUNCTION
    IF dx > 0 THEN IF MASKREG(dx - 1, dy) > 0 THEN RegionAtDoor = MASKREG(dx - 1, dy): EXIT FUNCTION
    IF dx < SW - 1 THEN IF MASKREG(dx + 1, dy) > 0 THEN RegionAtDoor = MASKREG(dx + 1, dy): EXIT FUNCTION
    IF dy > 0 THEN IF MASKREG(dx, dy - 1) > 0 THEN RegionAtDoor = MASKREG(dx, dy - 1): EXIT FUNCTION
    IF dy < SH - 1 THEN IF MASKREG(dx, dy + 1) > 0 THEN RegionAtDoor = MASKREG(dx, dy + 1): EXIT FUNCTION
END FUNCTION

' TRUE if cell is a PUBLIC walkable floor (not secret) -- a door touching one is a
' level-1 entry from the open dungeon. (_SOURCE must be FULL_BOARD.)
FUNCTION NeighPublic% (x AS INTEGER, y AS INTEGER)
    NeighPublic = 0
    IF x < 0 OR x > SW - 1 OR y < 0 OR y > SH - 1 THEN EXIT FUNCTION
    IF SECRET(x, y) = 0 THEN IF CellKind(x, y) >= 1 THEN NeighPublic = -1
END FUNCTION

' A door's parent region: a neighbouring painted region that isn't the one it opens.
FUNCTION DoorParentRegion% (di AS INTEGER, r AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER
    dx = SD_X(di): dy = SD_Y(di): DoorParentRegion = 0
    IF NeighRegionNot%(dx - 1, dy, r) > 0 THEN DoorParentRegion = NeighRegionNot%(dx - 1, dy, r): EXIT FUNCTION
    IF NeighRegionNot%(dx + 1, dy, r) > 0 THEN DoorParentRegion = NeighRegionNot%(dx + 1, dy, r): EXIT FUNCTION
    IF NeighRegionNot%(dx, dy - 1, r) > 0 THEN DoorParentRegion = NeighRegionNot%(dx, dy - 1, r): EXIT FUNCTION
    IF NeighRegionNot%(dx, dy + 1, r) > 0 THEN DoorParentRegion = NeighRegionNot%(dx, dy + 1, r): EXIT FUNCTION
END FUNCTION

FUNCTION NeighRegionNot% (x AS INTEGER, y AS INTEGER, r AS INTEGER)
    NeighRegionNot = 0
    IF x < 0 OR x > SW - 1 OR y < 0 OR y > SH - 1 THEN EXIT FUNCTION
    IF MASKREG(x, y) > 0 THEN IF MASKREG(x, y) <> r THEN NeighRegionNot = MASKREG(x, y)
END FUNCTION

' Compute each region's nesting depth: 1 = reached from the public dungeon, 2 = a secret
' inside a level-1 secret, and so on. Regions still 0 after this are unreachable/unmapped.
SUB ComputeMaskLevels
    DIM di AS INTEGER, r AS INTEGER, p AS INTEGER, it AS INTEGER, changed AS INTEGER, oldsrc AS LONG
    DIM k AS INTEGER
    FOR k = 0 TO UBOUND(MASKLVL): MASKLVL(k) = 0: NEXT
    oldsrc = _SOURCE: _SOURCE FULL_BOARD
    FOR di = 1 TO SD_N                                   ' level 1: doors opening from public floor
        r = DOOR_REGION(di)
        IF r > 0 AND r <= UBOUND(MASKLVL) THEN
            IF NeighPublic(SD_X(di) - 1, SD_Y(di)) OR NeighPublic(SD_X(di) + 1, SD_Y(di)) OR NeighPublic(SD_X(di), SD_Y(di) - 1) OR NeighPublic(SD_X(di), SD_Y(di) + 1) THEN
                IF MASKLVL(r) = 0 THEN MASKLVL(r) = 1
            END IF
        END IF
    NEXT di
    FOR it = 1 TO 40                                     ' propagate: nested = parent depth + 1
        changed = 0
        FOR di = 1 TO SD_N
            r = DOOR_REGION(di)
            IF r > 0 AND r <= UBOUND(MASKLVL) THEN
                IF MASKLVL(r) = 0 THEN
                    p = DoorParentRegion(di, r)
                    IF p > 0 AND p <= UBOUND(MASKLVL) THEN
                        IF MASKLVL(p) > 0 THEN MASKLVL(r) = MASKLVL(p) + 1: changed = -1
                    END IF
                END IF
            END IF
        NEXT di
        IF changed = 0 THEN EXIT FOR
    NEXT it
    _SOURCE oldsrc
END SUB

' A distinct, readable tint colour per mask region id (cycled hue). Alpha for the overlay.
FUNCTION MaskRegionColor~& (id AS INTEGER, alpha AS INTEGER)
    DIM rr AS INTEGER, gg AS INTEGER, bb AS INTEGER
    rr = (id * 53) MOD 180 + 70
    gg = (id * 101 + 40) MOD 180 + 70
    bb = (id * 173 + 90) MOD 180 + 70
    MaskRegionColor~& = _RGBA32(rr, gg, bb, alpha)
END FUNCTION

SUB InitFog
    DIM cx AS INTEGER, cy AS INTEGER, i AS INTEGER, head AS INTEGER, tail AS INTEGER
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            VIS(cx, cy) = 0: DOORCELL(cx, cy) = 0: SECRET(cx, cy) = 0: MASKREG(cx, cy) = 0
        NEXT cx
    NEXT cy

    DetectSecretDoors
    FOR i = 1 TO SD_N: DOORCELL(SD_X(i), SD_Y(i)) = 1: NEXT i
    DetectDoors                          ' regular (brown) doors -> DOOR arrays
    MarkStrongDoors                      ' re-roll which ones are reinforced this game
    Game_PopulateBoard                   ' game hook #8: the game claims its regions (ROOMS + CHAMBERS)

    IF LoadSecretMask THEN
        ' the hand-painted mask drives the fog: SECRET + MASKREG are set. Public = every
        ' non-secret cell (visible now); each secret door maps to the region it opens.
        FOR cy = 0 TO SH - 1
            FOR cx = 0 TO SW - 1
                IF SECRET(cx, cy) = 0 THEN VIS(cx, cy) = 1 ELSE VIS(cx, cy) = 0
            NEXT cx
        NEXT cy
        FOR i = 1 TO SD_N                 ' always hide the blue door tile, and record its region
            SECRET(SD_X(i), SD_Y(i)) = 1: VIS(SD_X(i), SD_Y(i)) = 0
            DOOR_REGION(i) = RegionAtDoor(i)
        NEXT i
        ComputeMaskLevels                 ' nesting depth per region (for the [~] mask overlay)
    ELSE
        ' -- FALLBACK: no mask file -> the openness/flood heuristic --
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
        '    walkable cells + doors) so ONLY door-connected areas get fogged.
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
    END IF

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
    LoadFogHide                          ' 4) black out any hand-listed stray art specks
END SUB

' Force-black specific cells listed in assets/data/fog-hide.txt (one "col,row" per line).
' The board art is fixed, so this is the exact, label-safe way to erase stray specks the
' flood can't reach (isolated non-black cells the secret-room hiding leaves behind). Only
' the cells you list are touched -- read them from the [~] debug overlay's "cell X,Y".
SUB LoadFogHide
    DIM fcx AS INTEGER, fcy AS INTEGER
    FOR fcy = 0 TO 60: FOR fcx = 0 TO 131: FOGHIDE(fcx, fcy) = 0: NEXT: NEXT   ' fresh each build (for the [~] overlay)
    DIM ff AS STRING: ff = DataPath$("assets/data/fog-hide.txt")   ' data-pack aware
    IF NOT _FILEEXISTS(ff) THEN EXIT SUB
    DIM whole AS STRING, p AS LONG, nl AS LONG, ln AS STRING, hp AS INTEGER
    DIM hx AS INTEGER, hy AS INTEGER
    whole = _READFILE$(ff)
    p = 1
    DO WHILE p <= LEN(whole)
        nl = INSTR(p, whole, CHR$(10))
        IF nl = 0 THEN ln = MID$(whole, p): p = LEN(whole) + 1 ELSE ln = MID$(whole, p, nl - p): p = nl + 1
        IF RIGHT$(ln, 1) = CHR$(13) THEN ln = LEFT$(ln, LEN(ln) - 1)   ' strip CR
        hp = INSTR(ln, "#"): IF hp > 0 THEN ln = LEFT$(ln, hp - 1)     ' strip comment
        ln = _TRIM$(ln)
        IF LEN(ln) > 0 AND INSTR(ln, ",") > 0 THEN
            hx = VAL(NthField$(ln, ",", 1)): hy = VAL(NthField$(ln, ",", 2))
            IF hx >= 0 AND hx <= SW - 1 AND hy >= 0 AND hy <= SH - 1 THEN
                FOGHIDE(hx, hy) = 1                          ' remember it for the [~] debug overlay
                _DEST CANVAS_COPY: LINE (hx * CW, hy * CH)-(hx * CW + CW - 1, hy * CH + CH - 1), BLACK, BF
                _DEST CANVAS: LINE (hx * CW, hy * CH)-(hx * CW + CW - 1, hy * CH + CH - 1), BLACK, BF
            END IF
        END IF
    LOOP
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
    DIM cx AS INTEGER, cy AS INTEGER, head AS INTEGER, tail AS INTEGER, rg AS INTEGER
    _SOURCE FULL_BOARD
    IF MASK_ON THEN
        ' mask fog: reveal EXACTLY the door's painted region (no flood, no ambiguity)
        rg = DOOR_REGION(di): IF rg <= 0 THEN EXIT SUB
        FOR cy = 0 TO SH - 1
            FOR cx = 0 TO SW - 1
                IF MASKREG(cx, cy) = rg THEN RevealCell cx, cy: VIS(cx, cy) = 1
            NEXT cx
        NEXT cy
        EXIT SUB
    END IF
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
    DIM col AS _UNSIGNED LONG
    IF cx < 0 OR cx > SW - 1 OR cy < 0 OR cy > SH - 1 THEN IsOpaque = TRUE: EXIT FUNCTION
    col = POINT(cx * CW + CW \ 2, cy * CH + CH \ 2)
    IF col = BLACK THEN IsOpaque = TRUE: EXIT FUNCTION
    ' a closed door (brown) blocks sight -- you can't see into a room until you open
    ' it by passing through (DOOROPEN). Once opened, sight passes through freely.
    IF col = BROWN THEN IF DOOROPEN(cx, cy) = 0 THEN IsOpaque = TRUE: EXIT FUNCTION
    IsOpaque = FALSE
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
    FOR cy = 0 TO 60: FOR cx = 0 TO 131: DOOROPEN(cx, cy) = 0: NEXT cx: NEXT cy   ' all doors start closed
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
        col = Game_FloorColorAt~&(c.x, c.y)            ' game hook: room-floor colour here
        IF col <> 0 THEN
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
    DIM img AS LONG, r AS INTEGER, col AS _UNSIGNED LONG
    col = Game_FloorColorAt~&(c.x, c.y)                ' game hook: room-floor colour here
    IF col = 0 THEN InRoomNow = FALSE: EXIT FUNCTION
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    r = image_is_monochromatic(img, col)
    IF NOT r THEN r = image_is_diachromatic(img, col, BROWN)
    IF NOT r THEN r = image_is_diachromatic(img, col, BRIGHT_BLUE)
    _FREEIMAGE img
    InRoomNow = r
END FUNCTION



' What KIND of room cell is (cx,cy), judged the way MOVEMENT judges it? Reads the current
' _SOURCE directly (no scratch image), so a caller sweeping the whole board does not allocate
' 6600 images. This asks exactly what InRoomNow asks about the cursor's cell, for any cell:
'
'   CRK_NONE  0  not this room colour at all
'   CRK_FLOOR 1  every pixel is the floor colour -- plain, enterable room floor
'   CRK_DOOR  2  floor + a door colour (brown or bright blue) -- enterable, but it is a DOORWAY
'   CRK_MIXED 3  floor plus something else (a half-block's black half, a text glyph) -- NOT
'                enterable, because image_is_monochromatic/diachromatic both fail
'
' The DOOR/MIXED split is what makes this worth having over a yes/no test: a doorway cell is
' walkable but is a terrible place to seat a monster or a headstone, and a mixed cell is the
' board art's decorative half-block lip, which is not meant to be walked on at all.
FUNCTION CellRoomKind% (cx AS INTEGER, cy AS INTEGER, kolor AS _UNSIGNED LONG)
    DIM px AS INTEGER, py AS INTEGER, col AS _UNSIGNED LONG
    DIM sawcol AS INTEGER, sawbrown AS INTEGER, sawblue AS INTEGER, other AS INTEGER
    CellRoomKind% = CRK_NONE
    IF kolor = 0 THEN EXIT FUNCTION
    IF cx < 0 OR cy < 0 OR cx > SW - 1 OR cy > SH - 1 THEN EXIT FUNCTION
    FOR py = 0 TO CH - 1
        FOR px = 0 TO CW - 1
            col = POINT(cx * CW + px, cy * CH + py)
            IF col = kolor THEN
                sawcol = -1
            ELSEIF col = BROWN THEN
                sawbrown = -1
            ELSEIF col = BRIGHT_BLUE THEN
                sawblue = -1
            ELSE
                other = -1
            END IF
        NEXT px
    NEXT py
    IF NOT sawcol THEN EXIT FUNCTION                ' no floor colour here at all: not this room
    IF other THEN CellRoomKind% = CRK_MIXED: EXIT FUNCTION
    IF sawbrown AND sawblue THEN CellRoomKind% = CRK_MIXED: EXIT FUNCTION   ' floor + BOTH door kinds: movement refuses it
    IF sawbrown OR sawblue THEN CellRoomKind% = CRK_DOOR ELSE CellRoomKind% = CRK_FLOOR
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
    UIFontOn UIF_LABEL                              ' configurable room-label font
    _PRINTSTRING (cx * CW, cy * CH), txt
    UIFontOff
END SUB

' (The label TABLE -- InitLabels/LoadLabels/AddLabel/BuildLabelMask -- moved to
'  game/OVERLAYS.bas: labels.txt is game content. PutLabel above stays here; it is a
'  render primitive (UI font + FOV gate), not a data table.)




' [~] debug overlay: cursor position, cell states, move count, timer.
FUNCTION YN$ (b AS INTEGER)
    IF b THEN YN$ = "Y" ELSE YN$ = "N"
END FUNCTION



' `dungeon.run ansilint [file]` -- lint a MASK ANSI (default: both board masks) for the
' art-as-data gotchas we hit: CRLF double-advance ("black bands"), sticky-SGR attribute
' leaks (an iCE-bright background bleeding into the next colour), rows not the canvas width,
' a missing SAUCE record, and colours that map to no dungeon level. Renders the file both
' raw (as ANSIPrint sees it) and through MaskNormalize$ (as the loaders now do), reports the
' difference, then the caller SYSTEMs. Everything here mirrors what MaskNormalize$ repairs.
SUB AnsiLint (pth AS STRING)
    _DEST _CONSOLE
    PRINT PipeCol$("== ansilint: |11" + pth)
    IF NOT _FILEEXISTS(pth) THEN PRINT PipeCol$("   |12(file not found)"): PRINT: EXIT SUB
    DIM raw AS STRING, norm AS STRING, i AS INTEGER, b AS INTEGER
    DIM issector AS INTEGER, datalen AS LONG, cecol AS STRING, cline AS STRING
    raw = _READFILE$(pth)
    issector = (INSTR(UCASE$(pth), "SECTOR") > 0)      ' sector mask -> colours are LEVELS; else REGIONS
    datalen = INSTR(raw, CHR$(26)) - 1                 ' art ends at the 0x1A EOF (SAUCE follows)
    IF datalen < 0 THEN datalen = LEN(raw)
    PRINT PipeCol$("   bytes: " + LTRIM$(STR$(LEN(raw))) + "  (art: " + LTRIM$(STR$(datalen)) + ")")

    ' --- line endings (of the art, before any SAUCE) ---
    DIM ncr AS LONG, nlf AS LONG, ncrlf AS LONG
    FOR i = 1 TO datalen
        b = ASC(raw, i)
        IF b = 13 THEN ncr = ncr + 1
        IF b = 10 THEN nlf = nlf + 1: IF i > 1 THEN IF ASC(raw, i - 1) = 13 THEN ncrlf = ncrlf + 1
    NEXT i
    IF ncrlf > 0 THEN cecol = "|14" ELSE cecol = "|10"
    PRINT PipeCol$("   line-endings: CR=" + LTRIM$(STR$(ncr)) + "  LF=" + LTRIM$(STR$(nlf)) + "  CRLF-pairs=" + cecol + LTRIM$(STR$(ncrlf)))

    ' --- per-row printable width (CRLF-split; ESC..m sequences don't count) ---
    DIM seg_st AS INTEGER, pw AS INTEGER, inesc AS INTEGER, rowcnt AS INTEGER, badw AS INTEGER, firstbad AS INTEGER
    seg_st = 1: firstbad = 0
    FOR i = 1 TO datalen + 1
        IF i > datalen THEN b = 10 ELSE b = ASC(raw, i)
        IF b = 13 THEN _CONTINUE                       ' CR handled at the LF
        IF b = 10 THEN
            ' measure printable width of segment [seg_st, i-1]
            pw = 0: inesc = 0
            DIM k AS INTEGER, kb AS INTEGER
            FOR k = seg_st TO i - 1
                kb = ASC(raw, k)
                IF kb = 27 THEN inesc = 1
                IF inesc = 0 THEN IF kb <> 13 THEN pw = pw + 1
                IF inesc = 1 AND kb >= 64 AND kb <= 126 AND kb <> 91 THEN inesc = 0   ' final byte of CSI ends it
            NEXT k
            IF pw > 0 THEN
                rowcnt = rowcnt + 1
                IF pw <> SW THEN badw = badw + 1: IF firstbad = 0 THEN firstbad = rowcnt
            END IF
            seg_st = i + 1
        END IF
    NEXT i
    IF ncrlf > 0 THEN
        PRINT PipeCol$("   rows (CRLF-split): " + LTRIM$(STR$(rowcnt)) + "  expected printable width " + LTRIM$(STR$(SW)))
        IF badw > 0 THEN PRINT PipeCol$("   |12!!|07 " + LTRIM$(STR$(badw)) + " row(s) not " + LTRIM$(STR$(SW)) + " wide (first: row " + LTRIM$(STR$(firstbad)) + ")")
        IF badw = 0 THEN PRINT PipeCol$("   |14!!|07 full-width rows + CRLF => DOUBLE-ADVANCE (black bands). The loaders")
        IF badw = 0 THEN PRINT PipeCol$("      auto-normalise this; run |11ansifix|07 to clean the stored file too.")
    ELSE
        PRINT PipeCol$("   rows: |10no line breaks (pure " + LTRIM$(STR$(SW)) + "-col auto-wrap) -- OK")
    END IF

    ' --- SAUCE record (last 128 bytes) ---
    IF LEN(raw) >= 128 THEN
        DIM soff AS LONG
        soff = LEN(raw) - 128
        IF MID$(raw, soff + 1, 7) = "SAUCE00" THEN
            DIM scols AS INTEGER, srows AS INTEGER, snote AS STRING
            scols = ASC(raw, soff + 97) + ASC(raw, soff + 98) * 256
            srows = ASC(raw, soff + 99) + ASC(raw, soff + 100) * 256
            IF scols <> SW THEN snote = "  |12(cols should be " + LTRIM$(STR$(SW)) + ")" ELSE snote = "  |10(cols OK)"
            PRINT PipeCol$("   SAUCE: |10present|07  dims=" + LTRIM$(STR$(scols)) + "x" + LTRIM$(STR$(srows)) + snote)
        ELSE
            PRINT PipeCol$("   SAUCE: |12MISSING|07 -- ANSI editors will guess 80 cols and mangle the layout.")
        END IF
    END IF

    ' --- render raw vs normalized; compare cells; map colours to sectors ---
    norm = MaskNormalize$(raw)
    DIM imgR AS LONG, imgN AS LONG, od AS LONG, os AS LONG
    imgR = _NEWIMAGE(SW * CW, SH * CH, 32): imgN = _NEWIMAGE(SW * CW, SH * CH, 32)
    od = _DEST
    _DEST imgR: _FONT CH: CLS , BLACK: ANSI_Print (raw)
    _DEST imgN: _FONT CH: CLS , BLACK: ANSI_Print (norm)
    _DEST od
    os = _SOURCE
    DIM x AS INTEGER, y AS INTEGER, cR AS _UNSIGNED LONG, cN AS _UNSIGNED LONG, diffn AS LONG
    DIM nu AS INTEGER, j AS INTEGER, found AS INTEGER, sid AS INTEGER, unmapped AS LONG
    REDIM ucolr(1 TO 64) AS _UNSIGNED LONG, ucnt(1 TO 64) AS LONG, umap(1 TO 64) AS INTEGER
    DIM seccnt(0 TO 64) AS LONG        ' painted-cell tally per game ZONE (0 = unmapped colour)
    FOR y = 0 TO SH - 1
        FOR x = 0 TO SW - 1
            _SOURCE imgR: cR = MaskSample~&(x, y)
            _SOURCE imgN: cN = MaskSample~&(x, y)
            IF cR <> cN THEN diffn = diffn + 1
            IF cN <> BLACK THEN
                sid = Game_ZoneByColor%(cN)          ' game hook: which zone owns this colour?
                seccnt(sid) = seccnt(sid) + 1
                IF sid = 0 THEN unmapped = unmapped + 1
                found = 0
                FOR j = 1 TO nu
                    IF ucolr(j) = cN THEN ucnt(j) = ucnt(j) + 1: found = -1: EXIT FOR
                NEXT j
                IF NOT found AND nu < 64 THEN nu = nu + 1: ucolr(nu) = cN: ucnt(nu) = 1: umap(nu) = sid
            END IF
        NEXT x
    NEXT y
    _SOURCE os: _FREEIMAGE imgR: _FREEIMAGE imgN

    IF diffn > 0 THEN
        PRINT PipeCol$("   cells changed by normalisation: |14" + LTRIM$(STR$(diffn)) + "|07  (raw is corrupted; the loader fixes it)")
    ELSE
        PRINT PipeCol$("   cells changed by normalisation: |10" + LTRIM$(STR$(diffn)) + "|07  (already clean)")
    END IF
    IF issector THEN PRINT PipeCol$("   distinct painted colours (zones): " + LTRIM$(STR$(nu))) ELSE PRINT PipeCol$("   distinct painted colours (regions): " + LTRIM$(STR$(nu)))
    FOR j = 1 TO nu
        cline = "     " + RIGHT$("000000" + HEX$(ucolr(j) AND &HFFFFFF), 6) + "  x" + LTRIM$(STR$(ucnt(j)))
        IF issector THEN
            IF umap(j) > 0 THEN
                cline = cline + "  |10-> zone " + LTRIM$(STR$(umap(j))) + " (" + Game_ZoneName$(umap(j)) + ")"
            ELSE
                cline = cline + "  |12-> !! no zone (reads as 0)"
            END IF
        ELSE
            cline = cline + "  |08(secret region)"
        END IF
        PRINT PipeCol$(cline)
    NEXT j
    ' zone-mask-only checks (the secret mask's colours are region ids, not zones)
    IF issector THEN
        IF unmapped > 0 THEN PRINT PipeCol$("   |12!!|07 " + LTRIM$(STR$(unmapped)) + " cell(s) painted a colour that is no zone's colour -> zone 0 (unwalkable rooms).")
        DIM anyempty AS INTEGER
        FOR sid = 1 TO Game_ZoneCount%
            IF seccnt(sid) = 0 THEN
                IF anyempty = 0 THEN PRINT PipeCol$("   |14!!|07 unpainted zone(s) (rooms there fall back to the game's rect table):")
                anyempty = -1
                PRINT PipeCol$("        |14zone " + LTRIM$(STR$(sid)) + " " + Game_ZoneName$(sid))
            END IF
        NEXT sid
        IF anyempty = 0 THEN PRINT PipeCol$("   |10all " + LTRIM$(STR$(Game_ZoneCount%)) + " zones painted.")
    END IF
    PRINT
END SUB

' `dungeon.run ansifix <file>` -- rewrite a mask ANSI to the clean canonical form: run it
' through MaskNormalize$ (strip CR/LF blanks, reset each SGR run, stop at EOF) and re-append a
' fresh SAUCE, keeping the file's own dims. Backs the original up to <file>.bak (once), then
' overwrites in place. The loaders already normalise at load, so this is a convenience to clean
' the STORED file (so it opens correctly in an ANSI editor); re-saving from an editor may re-dirty
' it, and the loader will re-clean. KILL before writing so BINARY leaves no stale tail.
SUB AnsiFix (pth AS STRING)
    _DEST _CONSOLE
    PRINT PipeCol$("== ansifix: |11" + pth)
    IF NOT _FILEEXISTS(pth) THEN PRINT PipeCol$("   |12(file not found)"): EXIT SUB
    DIM raw AS STRING, norm AS STRING, cols AS INTEGER, rows AS INTEGER, i AS INTEGER, b AS INTEGER, neol AS LONG
    raw = _READFILE$(pth)
    cols = SW: rows = SH - 1                                   ' default board-mask dims
    IF LEN(raw) >= 128 THEN
        DIM soff AS LONG: soff = LEN(raw) - 128
        IF MID$(raw, soff + 1, 7) = "SAUCE00" THEN
            cols = ASC(raw, soff + 97) + ASC(raw, soff + 98) * 256
            rows = ASC(raw, soff + 99) + ASC(raw, soff + 100) * 256
        END IF
    END IF
    FOR i = 1 TO LEN(raw)                                      ' count CR/LF we strip (for the report)
        b = ASC(raw, i): IF b = 26 THEN EXIT FOR
        IF b = 13 OR b = 10 THEN neol = neol + 1
    NEXT i
    norm = MaskNormalize$(raw)
    DIM fixed AS STRING
    fixed = norm + CHR$(26) + SauceRecord$("DUNGEON! mask", cols, rows, LEN(norm))
    IF NOT _FILEEXISTS(pth + ".bak") THEN
        DIM bkf AS INTEGER: bkf = FREEFILE
        OPEN pth + ".bak" FOR BINARY AS #bkf: PUT #bkf, 1, raw: CLOSE #bkf
        PRINT PipeCol$("   backed up original -> |11" + pth + ".bak")
    ELSE
        PRINT PipeCol$("   |14" + pth + ".bak already exists|07 -- keeping that first backup")
    END IF
    KILL pth
    DIM wf AS INTEGER: wf = FREEFILE
    OPEN pth FOR BINARY AS #wf: PUT #wf, 1, fixed: CLOSE #wf
    PRINT PipeCol$("   removed |14" + LTRIM$(STR$(neol)) + "|07 CR/LF byte(s); rewrote clean (pure auto-wrap + SAUCE)")
    PRINT PipeCol$("   bytes: " + LTRIM$(STR$(LEN(raw))) + " -> " + LTRIM$(STR$(LEN(fixed))))
    PRINT PipeCol$("   |10done|07 -- run |11ansilint " + pth + "|07 to confirm")
END SUB

' (The [~] debug OVERLAY and its [0] cheat panel moved to game/DEBUG.bas -- a dev tool
'  for THIS game: every row grants a DUNGEON! item and the readout names ROOMS/CHAMBERAT/
'  SECTORAT. It reads engine state (SD_*/MASKREG/DOOR_REGION) the sanctioned game->engine
'  way. DrawMaskDoors stays here: it renders ENGINE secret-door state and the engine's own
'  fogdump dev mode uses it.)

SUB DrawMaskDoors
    DIM i AS INTEGER, px AS INTEGER, py AS INTEGER, rg AS INTEGER, lv AS INTEGER, dc AS _UNSIGNED LONG
    _DEST CANVAS
    FOR i = 1 TO SD_N
        px = SD_X(i) * CW: py = SD_Y(i) * CH
        rg = DOOR_REGION(i)
        IF rg <= 0 THEN
            dc = _RGB32(&HFF, &H30, &H30): lv = 0          ' RED = unmapped (dead door)
        ELSE
            lv = MASKLVL(rg)
            IF lv <= 1 THEN dc = _RGB32(&H30, &HFF, &H30) ELSE dc = _RGB32(&H30, &HD0, &HFF)  ' green entry / cyan nested
        END IF
        LINE (px, py)-(px + CW - 1, py + CH - 1), dc, BF
        LINE (px, py)-(px + CW - 1, py + CH - 1), BLACK, B
        COLOR BLACK, dc
        IF lv > 0 THEN _PRINTSTRING (px, py), _TRIM$(STR$(lv)) ELSE _PRINTSTRING (px, py), "X"
    NEXT i
    COLOR WHITE, BLACK
END SUB
