' ============================================================================
'  engine/FPS.bas -- LOOK AROUND: a first-person view of where you are standing.
'
'      dungeon.run fpsshot <col> <row> <deg> <out.png>     one frame, headless
'      in game: [Q]                                        turn on the spot
'
'  The board art is already the collision map -- the game decides what a cell is
'  by sampling its COLOUR. That means the dungeon is a 3D level that nobody has
'  ever looked at from inside it, and a raycaster needs no new level data at
'  all: solid/empty comes from CellKind%, and which LEVEL a wall belongs to
'  comes from SECTORAT, exactly as movement and the HUD read them.
'
'  So this view cannot disagree with the map. If a wall is here in 3D it is here
'  on the board, because it is the same array. That is also what makes it a
'  debugging tool as much as a toy: a secret door reads as solid wall from in
'  here for the same reason it reads as solid to the player's feet.
'
'  HOW IT DRAWS
'
'  Classic DDA raycasting, one ray per column of a SMALL buffer (FPS_W x FPS_H)
'  that is then stretch-blitted to the canvas. Rendering small and scaling up is
'  not a compromise here -- it is the look. It also keeps the per-frame cost in
'  the hundreds of operations rather than the hundreds of thousands, which is
'  what makes this possible in BASIC at all.
'
'  Walls are drawn with _PUTIMAGE from a ONE-PIXEL-WIDE slice of the texture,
'  stretched to the column height. That hands the scaling to the blitter instead
'  of doing it a pixel at a time.
'
'  Everything composites into FPS_BUF, a 32-bit software image, so the
'  distance-fog overlays are ordinary alpha blends done by QB64 in software --
'  the reliable path. (Translucent HARDWARE tiles are the thing that rendered
'  invisible on a reporter's GPU during the 3D dice work; see DICE3D.)
'
'  ZONES. Which texture a wall wears is the one thing the engine cannot know:
'  "level 3 is the Armoury and it is dark red" is this game's idea. So it asks
'  through two hooks -- Game_FpsZone% (which zone is this cell in) and
'  Game_FpsZoneColor~& (what colour is that zone) -- and a game with one zone
'  and one colour is a perfectly good answer.
'
'  DOORS ARE NOT WALLS. A brown door cell is walkable, so a ray passes straight
'  through it and the doorway appears as a gap in the wall -- which is what a
'  doorway looks like. An UNFOUND secret door is painted black in COLLIDE_BOARD,
'  so it reads as solid stone from in here too. Both fall out of using the
'  collision layer rather than a second, hand-made 3D map.
' ============================================================================

CONST FPS_W = 264                    ' render buffer, stretched to the canvas
CONST FPS_H = 204
CONST FPS_TEXW = 128                 ' expected wall-texture size (any size works)
CONST FPS_MAXDIST = 24               ' cells; past this a ray gives up and fogs out
'--- how tall a wall is, in cells. 1.0 is the textbook value and it makes this
'    board read as a hedge maze: the corridors here are several cells wide, so a
'    one-cell wall is chest-high from across one. 1.8 is a dungeon. ---
CONST FPS_WALLH = 1.8

' ----------------------------------------------------------------------------
'  Setup
' ----------------------------------------------------------------------------
SUB FpsInit
    DIM i AS INTEGER, p AS STRING

    IF FPS_BUF < -1 THEN EXIT SUB                    ' already built
    FPS_BUF = _NEWIMAGE(FPS_W, FPS_H, 32)
    FPS_FOV = 1.15                                   ' ~66 degrees, the classic feel

    '--- one wall texture per LEVEL, resolved through the art pack like every
    '    other sprite. A level with no texture falls back to a procedural one,
    '    so the view works before any art exists -- which is the only way to
    '    develop the geometry without waiting on a generator. ---
    FOR i = 1 TO 9
        p = PixelArtFile$("fps/wall-" + LTRIM$(STR$(i)) + ".png")
        IF LEN(p) > 0 THEN FPS_TEX(i) = _LOADIMAGE(p, 32)
        IF FPS_TEX(i) >= -1 THEN
            FPS_TEX(i) = FpsMakeTexture&(i)
        ELSE
            FpsTintTexture FPS_TEX(i), i
        END IF
    NEXT i
END SUB

'--- A procedural stone texture in the level's own colour. Not a placeholder to
'    be ashamed of: it is derived from the board palette, so the 3D walls match
'    the 2D map even with no art shipped at all. ---
FUNCTION FpsMakeTexture& (lvl AS INTEGER)
    DIM h AS LONG, d AS LONG, x AS INTEGER, y AS INTEGER
    DIM kbase AS _UNSIGNED LONG, r AS INTEGER, g AS INTEGER, b AS INTEGER
    DIM n AS INTEGER, bh AS INTEGER, bw AS INTEGER, xoff AS INTEGER

    h = _NEWIMAGE(FPS_TEXW, FPS_TEXW, 32)
    d = _DEST: _DEST h

    kbase = Game_FpsZoneColor~&(lvl)
    '--- stone, not paint: the level colour dragged most of the way to dark
    '    grey, or every wall would glow like a menu ---
    r = (_RED32(kbase) + 90) \ 4
    g = (_GREEN32(kbase) + 90) \ 4
    b = (_BLUE32(kbase) + 90) \ 4

    CLS , _RGB32(r, g, b)

    '--- courses of blocks, offset every other row, with the mortar darker and
    '    a per-block brightness jitter so a flat wall still has texture ---
    bh = 16: bw = 32
    FOR y = 0 TO FPS_TEXW - 1 STEP bh
        xoff = 0
        IF ((y \ bh) MOD 2) = 1 THEN xoff = bw \ 2
        FOR x = -bw TO FPS_TEXW - 1 STEP bw
            n = (((x + y * 7) \ 8) MOD 5) * 4 - 8
            LINE (x + xoff + 1, y + 1)-(x + xoff + bw - 2, y + bh - 2), _
                 _RGB32(FpsClamp%(r + n + 14), FpsClamp%(g + n + 14), FpsClamp%(b + n + 14)), BF
        NEXT x
    NEXT y

    _DEST d
    FpsMakeTexture& = h
END FUNCTION

'--- Wash a loaded texture toward its level's colour.
'
'    The generated stone came back grey however the prompt was worded, which
'    is the right call for a stone texture and the wrong one for THIS game: the
'    board tells you which level you are on by COLOUR, and a 3D view that drops
'    that is a view you can get lost in for the wrong reason. A light wash keeps
'    every scratch and block edge the generator drew and still says "crypt" or
'    "armoury" at a glance. Alpha-blended into a software image, so it is the
'    reliable blend path.
'
'    Kept OUT of the art: tinting on load means one grey texture per level can
'    become nine, and a pack that ships nine hand-painted ones is washed by so
'    little it does not matter. ---
SUB FpsTintTexture (h AS LONG, lvl AS INTEGER)
    DIM d AS LONG, k AS _UNSIGNED LONG
    IF h >= -1 THEN EXIT SUB
    k = Game_FpsZoneColor~&(lvl)
    d = _DEST: _DEST h
    LINE (0, 0)-(_WIDTH(h) - 1, _HEIGHT(h) - 1), _RGBA32(_RED32(k), _GREEN32(k), _BLUE32(k), 62), BF
    _DEST d
END SUB

FUNCTION FpsClamp% (v AS INTEGER)
    '--- single-line IF has no ELSEIF in QB64; this must stay a block ---
    IF v < 0 THEN
        FpsClamp% = 0
    ELSEIF v > 255 THEN
        FpsClamp% = 255
    ELSE
        FpsClamp% = v
    END IF
END FUNCTION

' ----------------------------------------------------------------------------
'  Is this cell solid to a ray?
'
'  The SAME question movement asks, answered by the SAME routine. A 3D view with
'  its own idea of what a wall is would be a second map to keep in sync, and the
'  first thing it would do is disagree.
' ----------------------------------------------------------------------------
FUNCTION FpsSolid% (cx AS INTEGER, cy AS INTEGER)
    IF cx < 0 _ORELSE cy < 0 _ORELSE cx > SW - 1 _ORELSE cy > SH - 1 THEN FpsSolid% = -1: EXIT FUNCTION
    IF CellKind%(cx, cy) = 0 THEN FpsSolid% = -1 ELSE FpsSolid% = 0
END FUNCTION

' ----------------------------------------------------------------------------
'  One frame, from (px,py) in CELLS (fractional -- the eye stands mid-cell)
'  looking along ang radians, into FPS_BUF.
' ----------------------------------------------------------------------------
SUB FpsRender (px AS SINGLE, py AS SINGLE, ang AS SINGLE)
    DIM x AS INTEGER, y AS INTEGER
    DIM camx AS SINGLE, rdx AS SINGLE, rdy AS SINGLE
    DIM dirx AS SINGLE, diry AS SINGLE, planex AS SINGLE, planey AS SINGLE
    DIM mapx AS INTEGER, mapy AS INTEGER, stepx AS INTEGER, stepy AS INTEGER
    DIM sidex AS SINGLE, sidey AS SINGLE, ddx AS SINGLE, ddy AS SINGLE
    DIM hit AS INTEGER, side AS INTEGER, dist AS SINGLE
    DIM lineh AS INTEGER, y1 AS INTEGER, y2 AS INTEGER
    DIM wallx AS SINGLE, tx AS INTEGER, tex AS LONG, lvl AS INTEGER
    DIM fog AS INTEGER, d AS LONG, hz AS INTEGER

    d = _DEST
    _DEST FPS_BUF

    dirx = COS(ang): diry = SIN(ang)
    '--- the camera plane is perpendicular to the direction and as long as the
    '    half-FOV tangent; every ray is dir + plane*camx, which is what keeps
    '    the projection rectilinear instead of fish-eyed ---
    planex = -diry * TAN(FPS_FOV / 2)
    planey = dirx * TAN(FPS_FOV / 2)

    hz = FPS_H \ 2 + FPS_PITCH
    IF hz < 30 THEN hz = 30
    IF hz > FPS_H - 30 THEN hz = FPS_H - 30
    FpsDrawFloors px, py, ang, hz

    FOR x = 0 TO FPS_W - 1
        camx = 2 * x / (FPS_W - 1) - 1
        rdx = dirx + planex * camx
        rdy = diry + planey * camx

        mapx = INT(px): mapy = INT(py)
        IF rdx = 0 THEN ddx = 1E+30 ELSE ddx = ABS(1 / rdx)
        IF rdy = 0 THEN ddy = 1E+30 ELSE ddy = ABS(1 / rdy)

        IF rdx < 0 THEN
            stepx = -1: sidex = (px - mapx) * ddx
        ELSE
            stepx = 1: sidex = (mapx + 1 - px) * ddx
        END IF
        IF rdy < 0 THEN
            stepy = -1: sidey = (py - mapy) * ddy
        ELSE
            stepy = 1: sidey = (mapy + 1 - py) * ddy
        END IF

        '--- DDA: always advance whichever grid line is nearer, so every cell the
        '    ray crosses is visited exactly once and none is skipped ---
        hit = 0
        DO
            IF sidex < sidey THEN
                sidex = sidex + ddx: mapx = mapx + stepx: side = 0
            ELSE
                sidey = sidey + ddy: mapy = mapy + stepy: side = 1
            END IF
            IF FpsSolid%(mapx, mapy) THEN hit = -1
            IF side = 0 THEN dist = sidex - ddx ELSE dist = sidey - ddy
            IF dist > FPS_MAXDIST THEN EXIT DO
        LOOP UNTIL hit

        IF hit = 0 THEN FPS_ZBUF(x) = 1E+30: _CONTINUE

        IF dist < 0.02 THEN dist = 0.02
        FPS_ZBUF(x) = dist                  ' what a sprite in this column must be nearer than
        lineh = FPS_H * FPS_WALLH / dist
        y1 = hz - lineh \ 2
        y2 = hz + lineh \ 2
        IF y1 < 0 THEN y1 = 0
        IF y2 > FPS_H - 1 THEN y2 = FPS_H - 1
        IF y2 < y1 THEN _CONTINUE

        '--- where along the wall face the ray landed, 0..1 -> texture column ---
        IF side = 0 THEN wallx = py + dist * rdy ELSE wallx = px + dist * rdx
        wallx = wallx - INT(wallx)
        tex = FpsWallTex&(mapx, mapy, stepx, stepy, side, lvl)
        tx = INT(wallx * _WIDTH(tex))
        IF tx < 0 THEN tx = 0
        IF tx > _WIDTH(tex) - 1 THEN tx = _WIDTH(tex) - 1

        '--- ONE source column, stretched. The blitter does the scaling. ---
        _PUTIMAGE (x, y1)-(x, y2), tex, FPS_BUF, (tx, 0)-(tx, _HEIGHT(tex) - 1)

        '--- distance fog, plus a flat darkening of every N/S face. That second
        '    one is the oldest trick in raycasting and it is worth more than any
        '    texture: without it two perpendicular walls of the same stone meet
        '    at an invisible corner. ---
        fog = FpsFog%(dist)
        IF side = 1 THEN fog = fog + 38
        IF fog > 245 THEN fog = 245
        IF fog > 0 THEN LINE (x, y1)-(x, y2), _RGBA32(0, 0, 6, fog)
    NEXT x

    FpsDrawSprites px, py, dirx, diry, planex, planey, hz

    _DEST d
END SUB

' ----------------------------------------------------------------------------
'  BILLBOARDS -- monsters, graves, doors.
'
'  A sprite is projected by INVERTING the camera matrix: the same [dir|plane]
'  that turned a screen column into a ray turns a world offset back into a
'  screen column and a depth. Doing it that way rather than with an angle
'  comparison is what keeps a sprite in exactly the column the wall behind it
'  would be in -- an angle-based version drifts at the edges of the view, which
'  reads as sprites sliding along the wall as you turn.
'
'  Drawn far-to-near and clipped PER COLUMN against the wall depth buffer, so a
'  monster behind a corner is hidden by the corner and not by a rectangle.
' ----------------------------------------------------------------------------
SUB FpsDrawSprites (px AS SINGLE, py AS SINGLE, dirx AS SINGLE, diry AS SINGLE, planex AS SINGLE, planey AS SINGLE, hz AS INTEGER)
    DIM i AS INTEGER, j AS INTEGER, n AS INTEGER, t AS INTEGER
    DIM sx AS SINGLE, sy AS SINGLE, invdet AS SINGLE
    DIM tx AS SINGLE, ty AS SINGLE, scrx AS INTEGER
    DIM sw2 AS INTEGER, sh2 AS INTEGER, x1 AS INTEGER, x2 AS INTEGER
    DIM y1 AS INTEGER, y2 AS INTEGER, col AS INTEGER, u AS INTEGER
    DIM h AS LONG, fog AS INTEGER, lift AS INTEGER

    IF FSP_N < 1 THEN EXIT SUB

    '--- painter order: far first ---
    FOR i = 1 TO FSP_N
        FSP_D(i) = (FSP_X(i) - px) * (FSP_X(i) - px) + (FSP_Y(i) - py) * (FSP_Y(i) - py)
        FSP_ORD(i) = i
    NEXT i
    FOR i = 1 TO FSP_N - 1
        FOR j = 1 TO FSP_N - i
            IF FSP_D(FSP_ORD(j)) < FSP_D(FSP_ORD(j + 1)) THEN
                t = FSP_ORD(j): FSP_ORD(j) = FSP_ORD(j + 1): FSP_ORD(j + 1) = t
            END IF
        NEXT j
    NEXT i

    invdet = planex * diry - dirx * planey
    IF invdet = 0 THEN EXIT SUB
    invdet = 1 / invdet

    FOR n = 1 TO FSP_N
        i = FSP_ORD(n)
        h = Sprite&(FSP_PATH(i))
        IF h >= -1 THEN FPS_RJ_IMG = FPS_RJ_IMG + 1: _CONTINUE

        sx = FSP_X(i) - px
        sy = FSP_Y(i) - py
        '--- into camera space: ty is depth along the view axis ---
        tx = invdet * (diry * sx - dirx * sy)
        ty = invdet * (-planey * sx + planex * sy)
        IF ty <= 0.15 THEN FPS_RJ_BEHIND = FPS_RJ_BEHIND + 1: _CONTINUE
        IF ty > FPS_MAXDIST THEN FPS_RJ_FAR = FPS_RJ_FAR + 1: _CONTINUE

        scrx = INT((FPS_W / 2) * (1 + tx / ty))
        sh2 = ABS(INT(FPS_H * FSP_SCALE(i) / ty))
        sw2 = sh2 * _WIDTH(h) / _HEIGHT(h)
        IF sw2 < 1 _ORELSE sh2 < 1 THEN _CONTINUE

        '--- lift 0 seats the sprite ON the floor: its FEET land where the wall
        '    of the same depth meets the ground, which is the only placement
        '    that survives the horizon moving under mouse-look ---
        lift = (FPS_H * FPS_WALLH / ty) / 2 - sh2 * (1 - FSP_LIFT(i))
        y1 = hz - sh2 \ 2 - lift + sh2 \ 2
        y1 = hz + INT((FPS_H * FPS_WALLH / ty) / 2) - sh2 - INT(FSP_LIFT(i) * sh2)
        y2 = y1 + sh2 - 1

        x1 = scrx - sw2 \ 2
        x2 = x1 + sw2 - 1
        IF x2 < 0 _ORELSE x1 > FPS_W - 1 THEN FPS_RJ_OFF = FPS_RJ_OFF + 1: _CONTINUE

        fog = FpsFog%(ty)

        FOR col = x1 TO x2
            IF col < 0 _ORELSE col > FPS_W - 1 THEN _CONTINUE
            IF ty >= FPS_ZBUF(col) THEN FPS_RJ_Z = FPS_RJ_Z + 1: _CONTINUE
            u = INT((col - x1) * _WIDTH(h) / sw2)
            IF u < 0 THEN u = 0
            IF u > _WIDTH(h) - 1 THEN u = _WIDTH(h) - 1
            _PUTIMAGE (col, y1)-(col, y2), h, FPS_BUF, (u, 0)-(u, _HEIGHT(h) - 1)
            IF fog > 0 THEN LINE (col, y1)-(col, y2), _RGBA32(0, 0, 6, fog)
            FPS_DREW = FPS_DREW + 1
        NEXT col
    NEXT n
END SUB

'--- the game hands billboards in through this, once per frame ---
SUB FpsAddSprite (cx AS SINGLE, cy AS SINGLE, path AS STRING, scale AS SINGLE, lift AS SINGLE)
    IF FSP_N >= FPS_SPR_MAX THEN EXIT SUB
    IF LEN(path) = 0 THEN EXIT SUB
    FSP_N = FSP_N + 1
    FSP_X(FSP_N) = cx
    FSP_Y(FSP_N) = cy
    FSP_PATH(FSP_N) = path
    FSP_SCALE(FSP_N) = scale
    FSP_LIFT(FSP_N) = lift
END SUB

SUB FpsClearSprites
    FSP_N = 0
END SUB

'--- fog rises with distance and then stops, so the far end of a long hall is
'    dark but never pure black -- pure black reads as "nothing rendered" ---
FUNCTION FpsFog% (dist AS SINGLE)
    DIM v AS INTEGER
    v = (dist - 1.2) * 15
    IF v < 0 THEN v = 0
    IF v > 205 THEN v = 205
    FpsFog% = v
END FUNCTION

'--- which texture a wall face wears: the level of the EMPTY cell in front of
'    it, not the wall cell itself. Wall cells are unpainted black and belong to
'    no level; the room they face is what gives them their character. ---
FUNCTION FpsWallTex& (mapx AS INTEGER, mapy AS INTEGER, stepx AS INTEGER, stepy AS INTEGER, side AS INTEGER, lvl AS INTEGER)
    DIM fx AS INTEGER, fy AS INTEGER, s AS INTEGER
    fx = mapx: fy = mapy
    IF side = 0 THEN fx = mapx - stepx ELSE fy = mapy - stepy
    s = 0
    IF fx >= 0 _ANDALSO fy >= 0 _ANDALSO fx <= SW - 1 _ANDALSO fy <= SH - 1 THEN s = Game_FpsZone%(fx, fy)
    IF s < 1 _ORELSE s > 9 THEN s = 1
    lvl = s
    FpsWallTex& = FPS_TEX(s)
END FUNCTION

' ----------------------------------------------------------------------------
'  Floor and ceiling.
'
'  Per-pixel floor casting is the textbook answer and it is far too slow here --
'  it is FPS_W*FPS_H inner-loop iterations in BASIC. But a floor's JOB in this
'  game is to say which level you are standing on, and that is a colour the map
'  already knows. So each screen ROW is drawn as one horizontal line in the
'  colour of the cell that row's distance lands on, straight down the centre
'  ray. ~100 LINEs a frame instead of 54,000 PSETs, and the floor still changes
'  colour as you cross from a corridor into a room -- which is the whole point.
' ----------------------------------------------------------------------------
SUB FpsDrawFloors (px AS SINGLE, py AS SINGLE, ang AS SINGLE, hz AS INTEGER)
    DIM y AS INTEGER, rowd AS SINGLE, fx AS SINGLE, fy AS SINGLE
    DIM cx AS INTEGER, cy AS INTEGER, k AS _UNSIGNED LONG
    DIM r AS INTEGER, g AS INTEGER, b AS INTEGER, fog AS INTEGER

    CLS , _RGB32(0, 0, 0)

    FOR y = hz + 1 TO FPS_H - 1
        '--- the distance at which the floor projects onto this row ---
        rowd = (0.5 * FPS_H) / (y - hz)
        IF rowd > FPS_MAXDIST THEN _CONTINUE

        fx = px + COS(ang) * rowd
        fy = py + SIN(ang) * rowd
        cx = INT(fx): cy = INT(fy)

        k = 0
        IF cx >= 0 _ANDALSO cy >= 0 _ANDALSO cx <= SW - 1 _ANDALSO cy <= SH - 1 THEN k = FpsFloorColor~&(cx, cy)

        fog = FpsFog%(rowd)
        r = _RED32(k): g = _GREEN32(k): b = _BLUE32(k)
        '--- floors are the board's own colours, taken down to a walkable-stone
        '    brightness so they read as ground rather than as a lit surface ---
        r = r \ 3: g = g \ 3: b = b \ 3

        LINE (0, y)-(FPS_W - 1, y), _RGB32(FpsClamp%(r), FpsClamp%(g), FpsClamp%(b)), BF
        IF fog > 0 THEN LINE (0, y)-(FPS_W - 1, y), _RGBA32(0, 0, 6, fog), BF

        '--- the ceiling mirrors the floor row, much darker: it gives the eye a
        '    horizon and a sense of height without needing its own art ---
        LINE (0, 2 * hz - y)-(FPS_W - 1, 2 * hz - y), _RGB32(r \ 3, g \ 3, b \ 3 + 6), BF
        IF fog > 0 THEN LINE (0, 2 * hz - y)-(FPS_W - 1, 2 * hz - y), _RGBA32(0, 0, 6, fog), BF
    NEXT y
END SUB

'--- the colour the board paints this cell, read from the COLLISION layer for
'    the same reason everything else reads it there: the decoration layer has
'    art on it that means nothing to what you can walk on ---
FUNCTION FpsFloorColor~& (cx AS INTEGER, cy AS INTEGER)
    DIM s AS LONG, k AS _UNSIGNED LONG
    s = _SOURCE
    _SOURCE COLLIDE_BOARD
    k = POINT(cx * CW + CW \ 2, cy * CH + CH \ 2)
    _SOURCE s
    FpsFloorColor~& = k
END FUNCTION

' ----------------------------------------------------------------------------
'  The screen: render small, blit big, then the chrome.
' ----------------------------------------------------------------------------
SUB FpsPresent (px AS SINGLE, py AS SINGLE, ang AS SINGLE)
    FpsRender px, py, ang
    _DEST CANVAS
    _PUTIMAGE (0, 0)-(SW * CW - 1, SH * CH - 1), FPS_BUF, CANVAS
    FpsChrome px, py, ang
END SUB

'--- a compass, the cell, and the level. The point of this view is to be lost
'    in it; the point of the chrome is that you can still say where you are. ---
SUB FpsChrome (px AS SINGLE, py AS SINGLE, ang AS SINGLE)
    DIM s AS STRING, lvl AS INTEGER, cx AS INTEGER, cy AS INTEGER

    cx = INT(px): cy = INT(py)
    lvl = 0
    IF cx >= 0 _ANDALSO cy >= 0 _ANDALSO cx <= SW - 1 _ANDALSO cy <= SH - 1 THEN lvl = Game_FpsZone%(cx, cy)

    LINE (0, (SH - 2) * CH)-(SW * CW - 1, SH * CH - 1), _RGBA32(0, 0, 0, 210), BF
    COLOR _RGB32(210, 230, 255), _RGBA32(0, 0, 0, 0)
    s = "cell " + LTRIM$(STR$(cx)) + "," + LTRIM$(STR$(cy)) + "   level " + LTRIM$(STR$(lvl)) + _
        "   facing " + FpsCompass$(ang)
    _PRINTSTRING (2 * CW, (SH - 2) * CH), s
    COLOR _RGB32(140, 150, 170), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (2 * CW, (SH - 1) * CH), "[W/S] walk   [A/D or mouse] turn   [,/.] strafe   [mouse up/down] look   [Q] back to the board"
END SUB

FUNCTION FpsCompass$ (ang AS SINGLE)
    DIM a AS SINGLE, i AS INTEGER
    DIM nm(0 TO 7) AS STRING
    nm(0) = "E": nm(1) = "SE": nm(2) = "S": nm(3) = "SW"
    nm(4) = "W": nm(5) = "NW": nm(6) = "N": nm(7) = "NE"
    '--- screen space: +y is DOWN, so +angle turns south. Naming it correctly
    '    here is cheaper than remembering it at every call site. ---
    a = ang
    DO WHILE a < 0: a = a + 6.2831853: LOOP
    DO WHILE a >= 6.2831853: a = a - 6.2831853: LOOP
    i = INT((a + 0.3926991) / 0.7853982) MOD 8
    FpsCompass$ = nm(i)
END FUNCTION

' ----------------------------------------------------------------------------
'  Interactive: stand where the player stands and turn.
'
'  `live` = opened over a run, so the board is photographed and restored -- the
'  same trick the dev console and the map debugger use, and the reason this can
'  be opened from anywhere without knowing what was on screen.
' ----------------------------------------------------------------------------
SUB FpsLook (px AS SINGLE, py AS SINGLE, live AS INTEGER)
    DIM k AS STRING, quit AS INTEGER, snap AS LONG
    DIM mx AS INTEGER, lastmx AS INTEGER, first AS INTEGER

    FpsInit
    IF live THEN
        snap = _NEWIMAGE(SW * CW, SH * CH, 32)
        _PUTIMAGE (0, 0), CANVAS, snap
    END IF

    first = -1
    DO
        FpsPresent px, py, FPS_ANG
        Present

        '--- mouse look. The first frame only ESTABLISHES where the pointer is:
        '    taking a delta against an uninitialised last-x would snap the view
        '    round by however far the pointer happened to be from zero. ---
        WHILE _MOUSEINPUT: WEND
        mx = _MOUSEX
        IF first THEN lastmx = mx: first = 0
        IF mx <> lastmx THEN FPS_ANG = FPS_ANG + (mx - lastmx) * 0.004
        lastmx = mx

        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 75: FPS_ANG = FPS_ANG - 0.09
                CASE 77: FPS_ANG = FPS_ANG + 0.09
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            SELECT CASE LCASE$(k)
                CASE "a": FPS_ANG = FPS_ANG - 0.09
                CASE "d": FPS_ANG = FPS_ANG + 0.09
                CASE "s": _SAVEIMAGE "fpsshot.png", CANVAS
                CASE CHR$(27): quit = TRUE
            END SELECT
        END IF
        IF quit THEN EXIT DO
        _LIMIT 30
    LOOP

    IF live THEN
        _PUTIMAGE (0, 0), snap, CANVAS
        _FREEIMAGE snap
    END IF
END SUB

'--- headless: one frame from a named cell and heading ---
SUB FpsShot (cx AS INTEGER, cy AS INTEGER, deg AS SINGLE, outp AS STRING)
    DIM d AS LONG
    FpsInit
    '--- SNAP to the nearest cell you could actually stand on. A shot aimed at a
    '    wall renders the inside of that wall, which is a full screen of texture
    '    and looks exactly like a broken renderer -- and picking standable cells
    '    out of a 132x51 board by hand is how you spend an afternoon. ---
    FpsSnapWalkable cx, cy
    FPS_ANG = deg * 3.14159265 / 180
    '--- put the player here too: the sprite pass rejects by distance from the
    '    PLAYER, and a shot taken from somewhere the player is not would show an
    '    empty world and look like the billboards were broken ---
    c.x = cx * CW: c.y = cy * CH
    FpsClearSprites
    Game_FpsPopulate
    '--- `aim` points the camera at the nearest billboard. Hunting by hand for a
    '    cell that happens to face a monster is how a sprite bug survives a
    '    dozen screenshots of empty corridor. ---
    IF INSTR(LCASE$(COMMAND$), "aim") > 0 THEN FpsAimAtSprite cx + 0.5, cy + 0.5
    FpsPresent cx + 0.5, cy + 0.5, FPS_ANG
    _SAVEIMAGE outp, CANVAS
    d = _DEST: _DEST _CONSOLE
    PRINT PipeCol$("|07  rejects: image |14" + LTRIM$(STR$(FPS_RJ_IMG)) + "|07 behind |14" + LTRIM$(STR$(FPS_RJ_BEHIND)) + _
                   "|07 far |14" + LTRIM$(STR$(FPS_RJ_FAR)) + "|07 offscreen |14" + LTRIM$(STR$(FPS_RJ_OFF)) + _
                   "|07 zbuf |14" + LTRIM$(STR$(FPS_RJ_Z)) + "|07")
    PRINT PipeCol$("|07  sprites offered |14" + LTRIM$(STR$(FSP_N)) + "|07, columns drawn |14" + LTRIM$(STR$(FPS_DREW)) + "|07")
    PRINT PipeCol$("|15fps|07 -- cell |14" + LTRIM$(STR$(cx)) + "," + LTRIM$(STR$(cy)) + _
                   "|07 facing |14" + LTRIM$(STR$(INT(deg))) + "|07 -> |10" + outp + "|07")
    _DEST d
END SUB


' ============================================================================
'  WALKING -- the FPS view as a RENDER MODE of the play loop, not a mode of
'  its own.
'
'  This is the whole design decision. A separate first-person loop would have
'  needed its own copy of movement, encounters, triggers, chambers, the solo
'  timer, hot-seat turn passing and the win check -- and every one of those
'  copies would drift. Instead [Q] sets a flag, the play loop draws this
'  instead of the board, and the movement keys are REMAPPED to the direction
'  you are facing before they reach the code that already exists.
'
'  So walking in 3D is walking. Stepping onto a monster starts the same fight,
'  a cut-scene trigger fires, a chamber counts you in, and the save records a
'  perfectly ordinary position -- because it IS one.
' ============================================================================

'--- The eye LERPS toward the player's cell rather than jumping to it. Movement
'    is still strictly grid-based (the collision map is a grid and re-deriving
'    it in floating point would be a second, disagreeing map) -- this only
'    smooths what the eye does between two legal cells. ---
SUB FpsFollow (moving AS INTEGER)
    DIM tx AS SINGLE, ty AS SINGLE, d AS SINGLE

    tx = (c.x \ CW) + 0.5
    ty = (c.y \ CH) + 0.5
    IF FPS_EYEX = 0 _ANDALSO FPS_EYEY = 0 THEN FPS_EYEX = tx: FPS_EYEY = ty

    d = ABS(tx - FPS_EYEX) + ABS(ty - FPS_EYEY)
    FPS_EYEX = FPS_EYEX + (tx - FPS_EYEX) * 0.35
    FPS_EYEY = FPS_EYEY + (ty - FPS_EYEY) * 0.35
    IF ABS(tx - FPS_EYEX) < 0.02 THEN FPS_EYEX = tx
    IF ABS(ty - FPS_EYEY) < 0.02 THEN FPS_EYEY = ty

    '--- head bob only while actually crossing ground, so standing still is
    '    still. Driven by the distance left to travel rather than by a timer,
    '    which is what keeps it in step with the walking. ---
    IF d > 0.05 THEN
        FPS_BOB = FPS_BOB + 0.55
    ELSE
        FPS_BOB = FPS_BOB * 0.7
    END IF
END SUB

'--- one frame from where the player is standing ---
SUB FpsPresentPlayer
    DIM bob AS SINGLE, sav AS SINGLE
    FpsInit
    FpsFollow 0

    FpsClearSprites
    Game_FpsPopulate

    sav = FPS_PITCH
    bob = SIN(FPS_BOB) * 3
    FPS_PITCH = FPS_PITCH + bob
    FpsRender FPS_EYEX, FPS_EYEY, FPS_ANG
    FPS_PITCH = sav

    _DEST CANVAS
    _PUTIMAGE (0, 0)-(SW * CW - 1, SH * CH - 1), FPS_BUF, CANVAS
    FpsChrome FPS_EYEX, FPS_EYEY, FPS_ANG
END SUB

'--- Turn with the mouse. Called from the play loop, and it must not eat the
'    button the debug overlay uses to teleport, so it reads movement only. ---
SUB FpsMouseLook
    DIM mx AS INTEGER, my AS INTEGER
    WHILE _MOUSEINPUT: WEND
    mx = _MOUSEX: my = _MOUSEY
    IF FPS_MFIRST = 0 THEN FPS_MLX = mx: FPS_MLY = my: FPS_MFIRST = -1
    IF mx <> FPS_MLX THEN FPS_ANG = FPS_ANG + (mx - FPS_MLX) * 0.004
    IF my <> FPS_MLY THEN
        FPS_PITCH = FPS_PITCH + (my - FPS_MLY) * 0.35
        IF FPS_PITCH < -40 THEN FPS_PITCH = -40
        IF FPS_PITCH > 40 THEN FPS_PITCH = 40
    END IF
    FPS_MLX = mx: FPS_MLY = my
END SUB

'--- Remap a movement key to the direction the EYE is facing.
'
'    W/S walk forward and back, A/D TURN, [,]/[.] strafe. The board's own keys
'    are absolute (W is north), and keeping them absolute in here would mean
'    walking sideways down a corridor you are looking along.
'
'    Returns the board direction to hand to TryMove, or "" when the key was
'    consumed as a turn. ---
FUNCTION FpsMapKey$ (k AS STRING)
    SELECT CASE k
        CASE "A": FPS_ANG = FPS_ANG - 0.16: FpsMapKey$ = "": EXIT FUNCTION
        CASE "D": FPS_ANG = FPS_ANG + 0.16: FpsMapKey$ = "": EXIT FUNCTION
        CASE "W": FpsMapKey$ = FpsDirName$(FPS_ANG)
        CASE "S": FpsMapKey$ = FpsDirName$(FPS_ANG + 3.14159265)
        CASE "SL": FpsMapKey$ = FpsDirName$(FPS_ANG - 1.5707963)
        CASE "SR": FpsMapKey$ = FpsDirName$(FPS_ANG + 1.5707963)
        CASE ELSE: FpsMapKey$ = k
    END SELECT
END FUNCTION

'--- an angle to one of the EIGHT board directions. Eight, not four, because
'    the board moves diagonally and a 3D view that could only walk the compass
'    points would be a worse game than the one it is showing. ---
FUNCTION FpsDirName$ (ang AS SINGLE)
    DIM a AS SINGLE, i AS INTEGER
    DIM nm(0 TO 7) AS STRING
    nm(0) = "D": nm(1) = "SE": nm(2) = "S": nm(3) = "SW"
    nm(4) = "A": nm(5) = "NW": nm(6) = "W": nm(7) = "NE"
    a = ang
    DO WHILE a < 0: a = a + 6.2831853: LOOP
    DO WHILE a >= 6.2831853: a = a - 6.2831853: LOOP
    i = INT((a + 0.3926991) / 0.7853982) MOD 8
    FpsDirName$ = nm(i)
END FUNCTION

'--- entering and leaving. The eye is seeded from the player and the facing
'    from the last direction walked, so the view opens looking the way you were
'    already going rather than always east. ---
SUB FpsEnter (lastdir AS STRING)
    FpsInit
    FPS_ON = TRUE
    FPS_EYEX = (c.x \ CW) + 0.5
    FPS_EYEY = (c.y \ CH) + 0.5
    FPS_MFIRST = 0
    FPS_PITCH = 0
    SELECT CASE lastdir
        CASE "W": FPS_ANG = -1.5707963
        CASE "S": FPS_ANG = 1.5707963
        CASE "A": FPS_ANG = 3.14159265
        CASE "NE": FPS_ANG = -0.7853982
        CASE "NW": FPS_ANG = -2.3561945
        CASE "SE": FPS_ANG = 0.7853982
        CASE "SW": FPS_ANG = 2.3561945
        CASE ELSE: FPS_ANG = 0
    END SELECT
END SUB

SUB FpsLeave
    FPS_ON = FALSE
END SUB


'--- nearest standable cell, searched in rings so the answer is the closest one
'    rather than the first one a scan order happens to reach ---
SUB FpsSnapWalkable (cx AS INTEGER, cy AS INTEGER)
    DIM r AS INTEGER, dx AS INTEGER, dy AS INTEGER
    IF FpsSolid%(cx, cy) = 0 THEN EXIT SUB
    FOR r = 1 TO 24
        FOR dy = -r TO r
            FOR dx = -r TO r
                IF ABS(dx) = r _ORELSE ABS(dy) = r THEN
                    IF FpsSolid%(cx + dx, cy + dy) = 0 THEN
                        cx = cx + dx: cy = cy + dy
                        EXIT SUB
                    END IF
                END IF
            NEXT dx
        NEXT dy
    NEXT r
END SUB


'--- turn to face the nearest billboard, whatever it is ---
SUB FpsAimAtSprite (px AS SINGLE, py AS SINGLE)
    DIM i AS INTEGER, d AS SINGLE, best AS SINGLE, bi AS INTEGER
    DIM want AS STRING
    '--- `aim mon` restricts to a named kind, because the nearest billboard is
    '    usually a torch and a monster bug hides behind a working torch ---
    IF INSTR(LCASE$(COMMAND$), "aimmon") > 0 THEN want = "monsters/"
    best = 1E+30
    FOR i = 1 TO FSP_N
        IF LEN(want) > 0 _ANDALSO INSTR(LCASE$(FSP_PATH(i)), want) = 0 THEN _CONTINUE
        '--- and only ones actually in SIGHT: aiming at something behind a wall
        '    renders a wall and reads as a broken sprite pass ---
        IF FpsLineClear%(px, py, FSP_X(i), FSP_Y(i)) = 0 THEN _CONTINUE
        d = (FSP_X(i) - px) * (FSP_X(i) - px) + (FSP_Y(i) - py) * (FSP_Y(i) - py)
        IF d > 1 _ANDALSO d < best THEN best = d: bi = i
    NEXT i
    IF bi = 0 THEN EXIT SUB
    FPS_ANG = _ATAN2(FSP_Y(bi) - py, FSP_X(bi) - px)
END SUB


'--- is there an unbroken line between two points? Stepped finely enough that a
'    diagonal cannot slip through the corner between two solid cells. ---
FUNCTION FpsLineClear% (x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE)
    DIM n AS INTEGER, i AS INTEGER, x AS SINGLE, y AS SINGLE
    n = INT((ABS(x2 - x1) + ABS(y2 - y1)) * 4) + 1
    FOR i = 1 TO n - 1
        x = x1 + (x2 - x1) * i / n
        y = y1 + (y2 - y1) * i / n
        IF FpsSolid%(INT(x), INT(y)) THEN FpsLineClear% = 0: EXIT FUNCTION
    NEXT i
    FpsLineClear% = -1
END FUNCTION
