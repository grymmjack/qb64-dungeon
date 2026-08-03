' ============================================================================
'  MAZE.bas -- DISARM MAZE mini-game prototype (scratchpad)
'
'  PLANS.todo: "Magic sirens - save WIS - mini-game disarm maze".
'
'  A siren wails. To silence it you trace a path through the ward's lattice from
'  the outer edge to the sigil at its heart, one step at a time, before the alarm
'  finishes summoning. WIS buys time: the modifier adds seconds to the fuse.
'
'  WHY IT IS SHAPED THIS WAY
'
'  A generated maze has exactly one way to be broken, and it is fatal: NO PATH.
'  A player asked to solve an unsolvable puzzle under a timer cannot tell the
'  difference between "I am bad at this" and "this was impossible", and will
'  rightly conclude the game cheated. So generation is a recursive-backtracker
'  carve -- which is a spanning tree and therefore solvable BY CONSTRUCTION --
'  and the selftest still proves reachability independently, over many seeds,
'  because "by construction" is an argument and a BFS is evidence.
'
'  Difficulty scales by SIZE and by fuse seconds, never by making the maze
'  unfair: no dead-end traps, no hidden walls. The tension is the clock.
'
'  RUN:
'    qb64pe -w -x MAZE.bas -o MAZE.run
'    ./MAZE.run selftest     assertions (generation, solvability, fuse, movement)
'    ./MAZE.run shot         one frame -> maze-shot.png
'    ./MAZE.run              play it
' ============================================================================
$CONSOLE
OPTION _EXPLICIT

CONST TRUE = -1, FALSE = NOT TRUE

'--- the lattice. Cells carry WALL BITS, so a wall is shared by both neighbours
'    and cannot disagree with itself (the classic bug in wall-per-cell mazes). ---
CONST MZ_MAX = 31                       ' odd sizes only: a carve grid needs a centre cell
CONST W_N = 1, W_E = 2, W_S = 4, W_W = 8
CONST ALLWALLS = 15

DIM SHARED MZ(0 TO MZ_MAX, 0 TO MZ_MAX) AS INTEGER   ' wall bits still standing
DIM SHARED MZ_W AS INTEGER, MZ_H AS INTEGER
DIM SHARED MZ_SX AS INTEGER, MZ_SY AS INTEGER        ' start (an edge cell)
DIM SHARED MZ_GX AS INTEGER, MZ_GY AS INTEGER        ' the sigil (centre)

'--- outcome ---
CONST MZ_DISARMED = 1
CONST MZ_TOOSLOW = 2
CONST MZ_FLED = 3

DIM SHARED AS INTEGER SW, SH, CW, CH
SW = 132: SH = 51: CW = 8: CH = 16

DIM SHARED T_RUN AS INTEGER, T_BAD AS INTEGER

DIM cmd AS STRING
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN MazeSelfTest

SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)

IF INSTR(cmd, "SHOT") > 0 THEN
    RANDOMIZE 7
    MazeGen 15, 11
    ' from the REAL start, not the centre -- shooting the player on top of the sigil
    ' hides the sigil and the frame proves nothing about it
    DrawMaze MZ_SX, MZ_SY, 6.4, "trace the ward to its heart", TRUE
    _SAVEIMAGE "maze-shot.png"
    _DEST _CONSOLE
    PRINT "wrote maze-shot.png"
    SYSTEM
END IF

DIM outcome AS INTEGER
outcome = PlayMaze(13, 9, 12)                       ' WIS 12 = no modifier
_DEST _CONSOLE
PRINT "outcome ="; outcome
SYSTEM


' ----------------------------------------------------------------------------
'  GENERATION -- recursive backtracker (iterative; a spanning tree by construction)
' ----------------------------------------------------------------------------

' Carve a perfect maze of w x h cells. "Perfect" = exactly one path between any
' two cells: no loops, no isolated regions, so the sigil is always reachable.
SUB MazeGen (w AS INTEGER, h AS INTEGER)
    DIM x AS INTEGER, y AS INTEGER, i AS INTEGER
    DIM stackx(0 TO MZ_MAX * MZ_MAX) AS INTEGER, stacky(0 TO MZ_MAX * MZ_MAX) AS INTEGER
    DIM sp AS INTEGER, cx AS INTEGER, cy AS INTEGER
    DIM dirs(1 TO 4) AS INTEGER, nd AS INTEGER, d AS INTEGER, j AS INTEGER, t AS INTEGER
    DIM nx AS INTEGER, ny AS INTEGER
    DIM seen(0 TO MZ_MAX, 0 TO MZ_MAX) AS INTEGER

    IF w < 3 THEN w = 3
    IF h < 3 THEN h = 3
    IF w > MZ_MAX THEN w = MZ_MAX
    IF h > MZ_MAX THEN h = MZ_MAX
    MZ_W = w: MZ_H = h

    FOR y = 0 TO h - 1
        FOR x = 0 TO w - 1
            MZ(x, y) = ALLWALLS: seen(x, y) = FALSE
        NEXT x
    NEXT y

    cx = 0: cy = 0
    seen(cx, cy) = TRUE
    sp = 0: stackx(0) = cx: stacky(0) = cy
    DO
        ' collect unvisited neighbours
        nd = 0
        IF cy > 0 THEN IF NOT seen(cx, cy - 1) THEN nd = nd + 1: dirs(nd) = W_N
        IF cx < w - 1 THEN IF NOT seen(cx + 1, cy) THEN nd = nd + 1: dirs(nd) = W_E
        IF cy < h - 1 THEN IF NOT seen(cx, cy + 1) THEN nd = nd + 1: dirs(nd) = W_S
        IF cx > 0 THEN IF NOT seen(cx - 1, cy) THEN nd = nd + 1: dirs(nd) = W_W
        IF nd = 0 THEN
            IF sp = 0 THEN EXIT DO                  ' back at the root with nowhere to go: done
            sp = sp - 1: cx = stackx(sp): cy = stacky(sp)
        ELSE
            d = dirs(INT(RND * nd) + 1)
            nx = cx: ny = cy
            SELECT CASE d
                CASE W_N: ny = cy - 1
                CASE W_E: nx = cx + 1
                CASE W_S: ny = cy + 1
                CASE W_W: nx = cx - 1
            END SELECT
            ' knock the wall out of BOTH cells -- one shared wall, two bookkeepers
            MZ(cx, cy) = MZ(cx, cy) AND (ALLWALLS - d)
            MZ(nx, ny) = MZ(nx, ny) AND (ALLWALLS - Opposite%(d))
            seen(nx, ny) = TRUE
            sp = sp + 1: stackx(sp) = nx: stacky(sp) = ny
            cx = nx: cy = ny
        END IF
    LOOP

    ' The sigil sits at the centre; you enter from an edge cell. Both are just
    ' cells in the same spanning tree, so a path always exists.
    MZ_GX = w \ 2: MZ_GY = h \ 2
    PickStart
END SUB

' Choose the entry point: a random EDGE cell that is genuinely far from the sigil.
'
' Picking any edge cell at random is the obvious version and it is wrong -- on a
' small maze the random edge can land two steps from the centre, and the player
' gets a "puzzle" they solve by pressing a direction twice. Measured over 200
' mazes the shortest solution that produced was 2 steps.
'
' So: BFS out from the sigil, find the furthest edge cell, and choose among the
' edge cells at least 60% of that distance away. Still varied, never trivial.
SUB PickStart
    DIM x AS INTEGER, y AS INTEGER, best AS INTEGER, cut AS INTEGER, n AS INTEGER, pick AS INTEGER
    DIM cand AS INTEGER
    DIM dist(0 TO MZ_MAX, 0 TO MZ_MAX) AS INTEGER
    BfsFrom MZ_GX, MZ_GY, dist()
    best = 0
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 1
            IF IsEdge%(x, y) THEN IF dist(x, y) > best THEN best = dist(x, y)
        NEXT x
    NEXT y
    cut = INT(best * 0.6)
    IF cut < 1 THEN cut = 1
    n = 0
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 1
            IF IsEdge%(x, y) THEN IF dist(x, y) >= cut THEN n = n + 1
        NEXT x
    NEXT y
    IF n = 0 THEN MZ_SX = 0: MZ_SY = 0: EXIT SUB          ' degenerate board: any corner will do
    pick = INT(RND * n) + 1
    cand = 0
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 1
            IF IsEdge%(x, y) THEN
                IF dist(x, y) >= cut THEN
                    cand = cand + 1
                    IF cand = pick THEN MZ_SX = x: MZ_SY = y: EXIT SUB
                END IF
            END IF
        NEXT x
    NEXT y
END SUB

FUNCTION IsEdge% (x AS INTEGER, y AS INTEGER)
    IsEdge% = (x = 0 OR y = 0 OR x = MZ_W - 1 OR y = MZ_H - 1)
END FUNCTION

' Step distances from (fx,fy) to every cell. Shared by PickStart and the tests.
SUB BfsFrom (fx AS INTEGER, fy AS INTEGER, dist() AS INTEGER)
    DIM qx(0 TO MZ_MAX * MZ_MAX) AS INTEGER, qy(0 TO MZ_MAX * MZ_MAX) AS INTEGER
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER, i AS INTEGER
    DIM d AS INTEGER, nx AS INTEGER, ny AS INTEGER
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 1: dist(x, y) = -1: NEXT x
    NEXT y
    head = 0: qx(0) = fx: qy(0) = fy: dist(fx, fy) = 0: tail = 1
    DO WHILE head < tail
        x = qx(head): y = qy(head): head = head + 1
        FOR i = 1 TO 4
            SELECT CASE i
                CASE 1: d = W_N
                CASE 2: d = W_E
                CASE 3: d = W_S
                CASE ELSE: d = W_W
            END SELECT
            IF CanStep%(x, y, d) THEN
                nx = x: ny = y
                SELECT CASE d
                    CASE W_N: ny = y - 1
                    CASE W_E: nx = x + 1
                    CASE W_S: ny = y + 1
                    CASE W_W: nx = x - 1
                END SELECT
                IF dist(nx, ny) < 0 THEN
                    dist(nx, ny) = dist(x, y) + 1
                    qx(tail) = nx: qy(tail) = ny: tail = tail + 1
                END IF
            END IF
        NEXT i
    LOOP
END SUB

FUNCTION Opposite% (d AS INTEGER)
    SELECT CASE d
        CASE W_N: Opposite% = W_S
        CASE W_S: Opposite% = W_N
        CASE W_E: Opposite% = W_W
        CASE ELSE: Opposite% = W_E
    END SELECT
END FUNCTION

' Can you step from (x,y) in direction d? Only if that wall is gone and the
' destination is on the board.
FUNCTION CanStep% (x AS INTEGER, y AS INTEGER, d AS INTEGER)
    CanStep% = FALSE
    IF x < 0 OR y < 0 OR x >= MZ_W OR y >= MZ_H THEN EXIT FUNCTION
    IF (MZ(x, y) AND d) <> 0 THEN EXIT FUNCTION              ' wall still standing
    SELECT CASE d
        CASE W_N: IF y = 0 THEN EXIT FUNCTION
        CASE W_S: IF y = MZ_H - 1 THEN EXIT FUNCTION
        CASE W_E: IF x = MZ_W - 1 THEN EXIT FUNCTION
        CASE W_W: IF x = 0 THEN EXIT FUNCTION
    END SELECT
    CanStep% = TRUE
END FUNCTION


' ----------------------------------------------------------------------------
'  SOLVABILITY -- independent of the generator, on purpose
' ----------------------------------------------------------------------------

' Shortest number of steps from start to sigil, or -1 if unreachable. A BFS, not
' a claim: the generator argues every maze is solvable, this measures it.
FUNCTION MazeSolveLen% ()
    DIM qx(0 TO MZ_MAX * MZ_MAX) AS INTEGER, qy(0 TO MZ_MAX * MZ_MAX) AS INTEGER
    DIM dist(0 TO MZ_MAX, 0 TO MZ_MAX) AS INTEGER
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER, i AS INTEGER
    DIM d AS INTEGER, nx AS INTEGER, ny AS INTEGER
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 1: dist(x, y) = -1: NEXT x
    NEXT y
    head = 0: tail = 0
    qx(0) = MZ_SX: qy(0) = MZ_SY: dist(MZ_SX, MZ_SY) = 0: tail = 1
    DO WHILE head < tail
        x = qx(head): y = qy(head): head = head + 1
        IF x = MZ_GX AND y = MZ_GY THEN MazeSolveLen% = dist(x, y): EXIT FUNCTION
        FOR i = 1 TO 4
            SELECT CASE i
                CASE 1: d = W_N
                CASE 2: d = W_E
                CASE 3: d = W_S
                CASE ELSE: d = W_W
            END SELECT
            IF CanStep%(x, y, d) THEN
                nx = x: ny = y
                SELECT CASE d
                    CASE W_N: ny = y - 1
                    CASE W_E: nx = x + 1
                    CASE W_S: ny = y + 1
                    CASE W_W: nx = x - 1
                END SELECT
                IF dist(nx, ny) < 0 THEN
                    dist(nx, ny) = dist(x, y) + 1
                    qx(tail) = nx: qy(tail) = ny: tail = tail + 1
                END IF
            END IF
        NEXT i
    LOOP
    MazeSolveLen% = -1
END FUNCTION

' How many cells the BFS can reach at all. A perfect maze reaches every one --
' anything less means the carve left an island, which is the failure the player
' would experience as an unwinnable puzzle.
FUNCTION MazeReachCount% ()
    DIM qx(0 TO MZ_MAX * MZ_MAX) AS INTEGER, qy(0 TO MZ_MAX * MZ_MAX) AS INTEGER
    DIM seen(0 TO MZ_MAX, 0 TO MZ_MAX) AS INTEGER
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER, i AS INTEGER
    DIM d AS INTEGER, nx AS INTEGER, ny AS INTEGER, n AS INTEGER
    head = 0: qx(0) = MZ_SX: qy(0) = MZ_SY: seen(MZ_SX, MZ_SY) = TRUE: tail = 1: n = 1
    DO WHILE head < tail
        x = qx(head): y = qy(head): head = head + 1
        FOR i = 1 TO 4
            SELECT CASE i
                CASE 1: d = W_N
                CASE 2: d = W_E
                CASE 3: d = W_S
                CASE ELSE: d = W_W
            END SELECT
            IF CanStep%(x, y, d) THEN
                nx = x: ny = y
                SELECT CASE d
                    CASE W_N: ny = y - 1
                    CASE W_E: nx = x + 1
                    CASE W_S: ny = y + 1
                    CASE W_W: nx = x - 1
                END SELECT
                IF NOT seen(nx, ny) THEN
                    seen(nx, ny) = TRUE: n = n + 1
                    qx(tail) = nx: qy(tail) = ny: tail = tail + 1
                END IF
            END IF
        NEXT i
    LOOP
    MazeReachCount% = n
END FUNCTION


' ----------------------------------------------------------------------------
'  RULES
' ----------------------------------------------------------------------------

FUNCTION AbilMod% (score AS INTEGER)
    AbilMod% = INT((score - 10) / 2)
END FUNCTION

' Seconds on the fuse. Scaled to the maze's OWN shortest path, not to its size:
' a big maze with a short solution should not be more generous than a small maze
' with a winding one. Two seconds per required step, plus WIS.
FUNCTION MazeFuse! (steps AS INTEGER, wis AS INTEGER)
    DIM s AS SINGLE
    s = steps * 2.0 + AbilMod%(wis) * 2.0
    IF s < 6 THEN s = 6                     ' never so short that reading the board loses
    MazeFuse! = s
END FUNCTION


' ----------------------------------------------------------------------------
'  PLAY
' ----------------------------------------------------------------------------

FUNCTION PlayMaze% (w AS INTEGER, h AS INTEGER, wis AS INTEGER)
    DIM px AS INTEGER, py AS INTEGER, k AS STRING, ext AS INTEGER
    DIM t0 AS DOUBLE, el AS SINGLE, fuse AS SINGLE, steps AS INTEGER
    MazeGen w, h
    steps = MazeSolveLen%
    fuse = MazeFuse!(steps, wis)
    px = MZ_SX: py = MZ_SY
    t0 = TIMER
    DO
        el = TIMER - t0
        IF el < 0 THEN el = el + 86400!
        IF el >= fuse THEN PlayMaze% = MZ_TOOSLOW: EXIT FUNCTION
        DrawMaze px, py, fuse - el, "trace the ward to its heart", FALSE
        k = INKEY$: ext = 0
        IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
        IF k = CHR$(27) THEN PlayMaze% = MZ_FLED: EXIT FUNCTION
        IF ext = 72 OR UCASE$(k) = "W" THEN IF CanStep%(px, py, W_N) THEN py = py - 1
        IF ext = 80 OR UCASE$(k) = "S" THEN IF CanStep%(px, py, W_S) THEN py = py + 1
        IF ext = 75 OR UCASE$(k) = "A" THEN IF CanStep%(px, py, W_W) THEN px = px - 1
        IF ext = 77 OR UCASE$(k) = "D" THEN IF CanStep%(px, py, W_E) THEN px = px + 1
        IF px = MZ_GX AND py = MZ_GY THEN
            DrawMaze px, py, fuse - el, "The wail chokes off. The ward is dead.", FALSE
            _DELAY 2
            PlayMaze% = MZ_DISARMED: EXIT FUNCTION
        END IF
        _LIMIT 60
    LOOP
END FUNCTION


' ----------------------------------------------------------------------------
'  DRAW -- two screen cells per maze cell, so corridors read as corridors
' ----------------------------------------------------------------------------

' Render as a (2W+1) x (2H+1) GRID of characters: odd coords are cell floors, even
' coords are the walls between them. That is the only layout where a horizontal wall
' has anywhere to live -- the first version drew two screen cells per maze cell and
' had no row for north/south walls at all, so every corridor read as a vertical bar
' and the maze looked like a barcode.
'
' Each grid column is drawn 2 characters wide, because the font cell is 8x16: two of
' them is 16x16, so the maze comes out square instead of squashed.
SUB DrawMaze (px AS INTEGER, py AS INTEGER, secs AS SINGLE, msg AS STRING, showpath AS INTEGER)
    DIM gx AS INTEGER, gy AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM ox AS INTEGER, oy AS INTEGER, solid AS INTEGER
    DIM wall AS _UNSIGNED LONG, fl AS _UNSIGNED LONG
    DIM gw AS INTEGER, gh AS INTEGER
    CLS , _RGB32(8, 6, 12)
    wall = _RGB32(&H6E, &H5A, &H9E)
    fl = _RGB32(&H1A, &H16, &H26)
    gw = MZ_W * 2 + 1: gh = MZ_H * 2 + 1
    ox = (SW - gw * 2) \ 2
    oy = 9
    FOR gy = 0 TO gh - 1
        FOR gx = 0 TO gw - 1
            solid = MazeGridSolid%(gx, gy)
            IF solid THEN
                LINE ((ox + gx * 2) * CW, (oy + gy) * CH)-((ox + gx * 2 + 2) * CW - 1, (oy + gy + 1) * CH - 1), wall, BF
            ELSE
                LINE ((ox + gx * 2) * CW, (oy + gy) * CH)-((ox + gx * 2 + 2) * CW - 1, (oy + gy + 1) * CH - 1), fl, BF
            END IF
        NEXT gx
    NEXT gy
    ' the sigil, then you on top of it
    COLOR _RGB32(&HFF, &HD2, &H50), fl
    _PRINTSTRING ((ox + (MZ_GX * 2 + 1) * 2) * CW, (oy + MZ_GY * 2 + 1) * CH), "*"
    COLOR _RGB32(&H55, &HFF, &H55), fl
    _PRINTSTRING ((ox + (px * 2 + 1) * 2) * CW, (oy + py * 2 + 1) * CH), "@"
    ' chrome
    COLOR _RGB32(&HFF, &HE0, &H50), 0
    CenterText 3, "-=  A  M A G I C   S I R E N  =-"
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 5, msg
    DrawFuse secs, ox, gw
    COLOR _RGB32(&H55, &HFF, &H55), 0
    CenterText oy + gh + 2, "[arrows/WASD] trace     [ESC] flee"
    _DISPLAY
END SUB

' Is this character of the (2W+1)x(2H+1) grid a wall?
'   odd  , odd   -> a cell floor            (never solid)
'   even , even  -> a post between four walls (always solid)
'   odd  , even  -> horizontal wall: the N wall of the cell below it
'   even , odd   -> vertical wall:   the W wall of the cell to its right
FUNCTION MazeGridSolid% (gx AS INTEGER, gy AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER
    IF (gx AND 1) = 1 AND (gy AND 1) = 1 THEN MazeGridSolid% = FALSE: EXIT FUNCTION
    IF (gx AND 1) = 0 AND (gy AND 1) = 0 THEN MazeGridSolid% = TRUE: EXIT FUNCTION
    IF (gx AND 1) = 1 THEN
        cx = (gx - 1) \ 2: cy = gy \ 2                  ' horizontal wall above cell (cx,cy)
        IF cy > MZ_H - 1 THEN MazeGridSolid% = TRUE: EXIT FUNCTION
        MazeGridSolid% = ((MZ(cx, cy) AND W_N) <> 0)
    ELSE
        cx = gx \ 2: cy = (gy - 1) \ 2                  ' vertical wall left of cell (cx,cy)
        IF cx > MZ_W - 1 THEN MazeGridSolid% = TRUE: EXIT FUNCTION
        MazeGridSolid% = ((MZ(cx, cy) AND W_W) <> 0)
    END IF
END FUNCTION

' The same draining bar the luck fuse and the gesture gauge use, so the three
' read as one language rather than three widgets.
SUB DrawFuse (secs AS SINGLE, ox AS INTEGER, gw AS INTEGER)
    DIM fx AS INTEGER, fw AS INTEGER, fy AS INTEGER, frac AS SINGLE, kol AS _UNSIGNED LONG
    fx = ox * CW: fw = gw * 2 * CW: fy = 7 * CH          ' the bar spans the MAZE, not the screen
    frac = secs / 20.0: IF frac > 1 THEN frac = 1
    IF frac < 0 THEN frac = 0
    LINE (fx, fy)-(fx + fw, fy + CH - 4), _RGB32(40, 40, 46), BF
    IF frac > 0.35 THEN kol = _RGB32(170, 150, 70) ELSE kol = _RGB32(220, 60, 50)
    LINE (fx, fy)-(fx + INT(fw * frac), fy + CH - 4), kol, BF
END SUB

SUB CenterText (row AS INTEGER, s AS STRING)
    _PRINTSTRING (((SW - LEN(s)) \ 2) * CW, row * CH), s     ' parens: `*` binds tighter than `\`
END SUB


' ----------------------------------------------------------------------------
'  SELFTEST
' ----------------------------------------------------------------------------

SUB Ok (label AS STRING, cond AS INTEGER)
    T_RUN = T_RUN + 1
    IF cond THEN PRINT "  ok   "; label ELSE PRINT "  FAIL "; label: T_BAD = T_BAD + 1
END SUB

SUB MazeSelfTest
    DIM i AS INTEGER, n AS INTEGER, bad AS INTEGER, minlen AS INTEGER, maxlen AS INTEGER
    DIM cells AS INTEGER, unreach AS INTEGER, L AS INTEGER, trivial AS INTEGER
    _DEST _CONSOLE
    PRINT "MAZE selftest"
    PRINT

    PRINT " generation, over 200 random mazes of assorted sizes"
    minlen = 9999: maxlen = 0
    FOR i = 1 TO 200
        RANDOMIZE i
        MazeGen 5 + (i MOD 11) * 2, 5 + (i MOD 7) * 2
        cells = MZ_W * MZ_H
        IF MazeReachCount% <> cells THEN unreach = unreach + 1
        L = MazeSolveLen%
        IF L < 0 THEN bad = bad + 1
        IF L = 0 THEN trivial = trivial + 1
        IF L > 0 AND L < minlen THEN minlen = L
        IF L > maxlen THEN maxlen = L
    NEXT i
    Ok "every maze is solvable (BFS finds the sigil)", bad = 0
    Ok "every cell is reachable -- no carved-off islands", unreach = 0
    Ok "never starts ON the sigil (no instant win)", trivial = 0
    ' A random edge cell can land two steps from the centre on a small maze -- a
    ' "puzzle" solved by pressing a direction twice. PickStart exists to stop that,
    ' and this is the assertion that holds it to it.
    Ok "never a trivial walk-in (>= 4 steps, always)", minlen >= 4
    Ok "starts on an EDGE cell", StartIsEdge%
    PRINT "       shortest solution seen"; minlen; " longest"; maxlen

    PRINT
    PRINT " walls are shared, not duplicated"
    RANDOMIZE 42: MazeGen 11, 11
    Ok "if A opens east, B opens west (all pairs)", WallsAgree%
    Ok "the outer border is sealed", BorderSealed%

    PRINT
    PRINT " movement respects walls"
    Ok "cannot step through a standing wall", CannotPhase%
    Ok "cannot step off the board", OffBoardBlocked%

    PRINT
    PRINT " fuse from WIS and the maze's own solution"
    Ok "scales with the SOLUTION, not the size", MazeFuse!(20, 10) > MazeFuse!(5, 10)
    Ok "WIS adds time", MazeFuse!(10, 18) > MazeFuse!(10, 10)
    Ok "low WIS never drops below the floor", MazeFuse!(1, 3) >= 6

    PRINT
    PRINT USING "  ### assertion(s), ### failed"; T_RUN; T_BAD
    IF T_BAD > 0 THEN SYSTEM 1
    PRINT "  ALL GREEN"
    SYSTEM
END SUB

' The bug this catches: a carve that clears the wall bit in one cell but not its
' neighbour. The maze then looks fine and is passable in one direction only.
FUNCTION WallsAgree% ()
    DIM x AS INTEGER, y AS INTEGER
    WallsAgree% = TRUE
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 2
            IF ((MZ(x, y) AND W_E) = 0) <> ((MZ(x + 1, y) AND W_W) = 0) THEN WallsAgree% = FALSE
        NEXT x
    NEXT y
    FOR y = 0 TO MZ_H - 2
        FOR x = 0 TO MZ_W - 1
            IF ((MZ(x, y) AND W_S) = 0) <> ((MZ(x, y + 1) AND W_N) = 0) THEN WallsAgree% = FALSE
        NEXT x
    NEXT y
END FUNCTION

FUNCTION StartIsEdge% ()
    StartIsEdge% = IsEdge%(MZ_SX, MZ_SY)
END FUNCTION

FUNCTION BorderSealed% ()
    DIM x AS INTEGER, y AS INTEGER
    BorderSealed% = TRUE
    FOR x = 0 TO MZ_W - 1
        IF (MZ(x, 0) AND W_N) = 0 THEN BorderSealed% = FALSE
        IF (MZ(x, MZ_H - 1) AND W_S) = 0 THEN BorderSealed% = FALSE
    NEXT x
    FOR y = 0 TO MZ_H - 1
        IF (MZ(0, y) AND W_W) = 0 THEN BorderSealed% = FALSE
        IF (MZ(MZ_W - 1, y) AND W_E) = 0 THEN BorderSealed% = FALSE
    NEXT y
END FUNCTION

FUNCTION CannotPhase% ()
    DIM x AS INTEGER, y AS INTEGER
    CannotPhase% = TRUE
    FOR y = 0 TO MZ_H - 1
        FOR x = 0 TO MZ_W - 1
            IF (MZ(x, y) AND W_N) <> 0 THEN IF CanStep%(x, y, W_N) THEN CannotPhase% = FALSE
            IF (MZ(x, y) AND W_E) <> 0 THEN IF CanStep%(x, y, W_E) THEN CannotPhase% = FALSE
        NEXT x
    NEXT y
END FUNCTION

FUNCTION OffBoardBlocked% ()
    OffBoardBlocked% = TRUE
    IF CanStep%(0, 0, W_W) THEN OffBoardBlocked% = FALSE
    IF CanStep%(0, 0, W_N) THEN OffBoardBlocked% = FALSE
    IF CanStep%(MZ_W - 1, MZ_H - 1, W_E) THEN OffBoardBlocked% = FALSE
    IF CanStep%(MZ_W - 1, MZ_H - 1, W_S) THEN OffBoardBlocked% = FALSE
    IF CanStep%(-1, 0, W_E) THEN OffBoardBlocked% = FALSE
END FUNCTION
