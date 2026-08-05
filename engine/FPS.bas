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
CONST FPS_SHADE_LV = 7               ' pre-darkened sprite copies per distance band
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

    p = PixelArtFile$("fps/door.png")
    IF LEN(p) > 0 THEN FPS_DOORTEX = _LOADIMAGE(p, 32)
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
    DIM hit AS INTEGER, side AS INTEGER, dist AS SINGLE, isdoor AS INTEGER
    DIM lineh AS INTEGER, y1 AS INTEGER, y2 AS INTEGER
    DIM wallx AS SINGLE, tx AS INTEGER, tex AS LONG, lvl AS INTEGER
    DIM fog AS INTEGER, d AS LONG, hz AS INTEGER, warm AS INTEGER

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
        isdoor = 0
        DO
            IF sidex < sidey THEN
                sidex = sidex + ddx: mapx = mapx + stepx: side = 0
            ELSE
                sidey = sidey + ddy: mapy = mapy + stepy: side = 1
            END IF
            IF FpsSolid%(mapx, mapy) THEN hit = -1
            IF side = 0 THEN dist = sidex - ddx ELSE dist = sidey - ddy
            '--- A DOOR is a THIN WALL standing on the cell's MIDLINE, not a
            '    solid cell. It has to be thin: the cell is walkable and you
            '    step onto it, so a solid door would be a door you cannot go
            '    through. Standing it at the midline is also what puts you IN
            '    the doorway for a step, with the frame either side of you. ---
            IF hit = 0 _ANDALSO FpsDoorAt%(mapx, mapy) THEN
                IF FpsThinHit%(px, py, rdx, rdy, mapx, mapy, side, ddx, ddy, sidex, sidey, dist, wallx) THEN
                    hit = -1: isdoor = -1
                END IF
            END IF
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

        '--- where along the wall face the ray landed, 0..1 -> texture column.
        '    A door already worked its own out when it decided it was hit. ---
        IF isdoor = 0 THEN
            IF side = 0 THEN wallx = py + dist * rdy ELSE wallx = px + dist * rdx
            wallx = wallx - INT(wallx)
        END IF
        IF isdoor THEN
            tex = FPS_DOORTEX
        ELSE
            tex = FpsWallTex&(mapx, mapy, stepx, stepy, side, lvl)
        END IF
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
        IF fog > 250 THEN fog = 250
        IF fog > 0 THEN LINE (x, y1)-(x, y2), _RGBA32(0, 0, 6, fog)
        warm = FpsWarm%(dist)
        IF warm > 0 THEN LINE (x, y1)-(x, y2), _RGBA32(255, 150, 60, warm)
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
    DIM h AS LONG, fog AS INTEGER, lift AS INTEGER, hurt AS LONG

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
        h = FpsCutout&(FSP_PATH(i), h)

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
        '--- a slow idle rise and fall, phase-shifted per sprite by its position
        '    so a row of skeletons does not breathe in unison. Scaled by 1/ty so
        '    a distant one does not jitter a whole pixel. ---
        IF FSP_BOB(i) THEN y1 = y1 + INT(SIN(FPS_IDLE + FSP_X(i) + FSP_Y(i) * 1.7) * (sh2 * 0.045))
        y2 = y1 + sh2 - 1

        x1 = scrx - sw2 \ 2
        x2 = x1 + sw2 - 1
        IF x2 < 0 _ORELSE x1 > FPS_W - 1 THEN FPS_RJ_OFF = FPS_RJ_OFF + 1: _CONTINUE

        '--- FOG A SPRITE BY SHADING THE IMAGE, never by painting over its
        '    screen columns. The columns are its bounding BOX, so a translucent
        '    dark overlay paints a faintly-different-dark RECTANGLE around it --
        '    invisible in a bright corridor and glaring once the torch made the
        '    dungeon dark. Exactly the mistake the red flash made first. ---
        fog = FpsFog%(ty)
        IF fog > 8 THEN h = FpsShadeImage&(FSP_PATH(i), h, fog)
        '--- is THIS the thing that was just struck? If so, swap in a RED copy
        '    of the image rather than painting red over the column: a column
        '    overlay ignores the sprite's alpha and paints a red RECTANGLE, box
        '    and all, which is what the first version did. ---
        hurt = 0
        IF FPS_FLASH > 0 THEN
            IF INT(FSP_X(i)) = FPS_FLASHX _ANDALSO INT(FSP_Y(i)) = FPS_FLASHY THEN
                '--- the red is drawn OVER the real sprite, not instead of it,
                '    so the monster is still recognisably itself while it is
                '    lit up. Gated on the decay so it blinks rather than fades
                '    to a pink smear. ---
                IF FPS_FLASH > 0.35 THEN hurt = FpsHurtImage&(FSP_PATH(i), h)
            END IF
        END IF

        FOR col = x1 TO x2
            IF col < 0 _ORELSE col > FPS_W - 1 THEN _CONTINUE
            IF ty >= FPS_ZBUF(col) THEN FPS_RJ_Z = FPS_RJ_Z + 1: _CONTINUE
            u = INT((col - x1) * _WIDTH(h) / sw2)
            IF u < 0 THEN u = 0
            IF u > _WIDTH(h) - 1 THEN u = _WIDTH(h) - 1
            _PUTIMAGE (col, y1)-(col, y2), h, FPS_BUF, (u, 0)-(u, _HEIGHT(h) - 1)
            IF hurt < -1 THEN _PUTIMAGE (col, y1)-(col, y2), hurt, FPS_BUF, (u, 0)-(u, _HEIGHT(hurt) - 1)
            FPS_DREW = FPS_DREW + 1
        NEXT col
    NEXT n
END SUB

'--- the game hands billboards in through this, once per frame ---
SUB FpsAddSprite (cx AS SINGLE, cy AS SINGLE, path AS STRING, scale AS SINGLE, lift AS SINGLE)
    FpsAddSpriteEx cx, cy, path, scale, lift, 0
END SUB

'--- `bob` marks a sprite as ALIVE: it breathes. A grave should not. ---
SUB FpsAddSpriteEx (cx AS SINGLE, cy AS SINGLE, path AS STRING, scale AS SINGLE, lift AS SINGLE, bob AS INTEGER)
    IF FSP_N >= FPS_SPR_MAX THEN EXIT SUB
    IF LEN(path) = 0 THEN EXIT SUB
    FSP_N = FSP_N + 1
    FSP_X(FSP_N) = cx
    FSP_Y(FSP_N) = cy
    FSP_PATH(FSP_N) = path
    FSP_SCALE(FSP_N) = scale
    FSP_LIFT(FSP_N) = lift
    FSP_BOB(FSP_N) = bob
END SUB

SUB FpsClearSprites
    FSP_N = 0
    FPS_IDLE = FPS_IDLE + 0.07          ' the world's own slow breath, one tick a frame
    FpsTorchTick                        ' one flame per frame, not one per surface
END SUB

' ----------------------------------------------------------------------------
'  LIGHT -- you are carrying a torch, you are not standing in a lit room.
'
'  The old version was DISTANCE FOG: everything dimmed at a fixed linear rate and
'  bottomed out at a floor so the far end of a hall stayed visible. That reads as
'  a uniformly-lit dungeon photographed through haze, which is a different place
'  from the one this game is about.
'
'  A torch is a POINT SOURCE. Its light falls off with the square of distance,
'  it has a definite reach, and past that reach there is nothing -- not haze,
'  nothing. Three things follow from modelling it that way rather than tuning the
'  fog curve:
'
'    * corridors get genuinely dark, so walking one is a decision
'    * the reach FLICKERS, and a flicker is the single cheapest thing that makes
'      a still picture feel like a lit room instead of a rendered one
'    * near surfaces take a WARM cast and far ones a cold blue-black, which is
'      what a flame actually does and what no amount of grey fog can imitate
'
'  Torch Light OFF (opt_fpslight = 0) restores the flat distance fog, because
'  the dark is a choice and somebody will want to see where they are going.
' ----------------------------------------------------------------------------

'--- how much light reaches something this far away, 0..1 ---
FUNCTION FpsLight! (dist AS SINGLE)
    DIM r AS SINGLE, t AS SINGLE

    IF opt_fpslight <= 0 THEN
        '--- flat fog: the old behaviour, kept whole ---
        t = 1 - (dist - 1.2) / 13.7
        IF t > 1 THEN t = 1
        IF t < 0.2 THEN t = 0.2
        FpsLight! = t
        EXIT FUNCTION
    END IF

    r = FPS_TORCH_R
    IF r <= 0 THEN r = 6.5
    IF dist >= r THEN FpsLight! = 0: EXIT FUNCTION

    '--- inverse-square, normalised so it is 1 at the flame and 0 at the reach.
    '    The subtraction at the end is what makes the edge of the light a real
    '    edge: without it the curve only ASYMPTOTES to dark and the far wall
    '    keeps a permanent grey glow that gives the whole level away. ---
    t = 1 / (1 + (dist / (r * 0.42)) ^ 2)
    t = (t - 1 / (1 + (r / (r * 0.42)) ^ 2)) / (1 - 1 / (1 + (r / (r * 0.42)) ^ 2))
    IF t < 0 THEN t = 0
    IF t > 1 THEN t = 1
    FpsLight! = t
END FUNCTION

'--- the darkening alpha for a surface at this distance ---
FUNCTION FpsFog% (dist AS SINGLE)
    DIM v AS INTEGER
    v = (1 - FpsLight!(dist)) * 255
    IF v < 0 THEN v = 0
    IF v > 255 THEN v = 255
    FpsFog% = v
END FUNCTION

'--- the WARM cast on a surface close enough to be in the flame's colour. A
'    separate pass from the darkening because they pull opposite ways: one adds
'    orange, the other subtracts everything, and doing both in one blend just
'    gives muddy brown. ---
FUNCTION FpsWarm% (dist AS SINGLE)
    DIM t AS SINGLE
    IF opt_fpslight <= 0 THEN EXIT FUNCTION
    t = FpsLight!(dist)
    IF t < 0.55 THEN EXIT FUNCTION
    FpsWarm% = (t - 0.55) * 150
END FUNCTION

'--- The torch reach for THIS frame, flickering. Advanced once per frame in
'    FpsClearSprites so every surface in a frame is lit by the same flame --
'    ticking it per surface would make the walls disagree about how bright the
'    torch is, which reads as static rather than as firelight. ---
SUB FpsTorchTick
    DIM reach AS SINGLE          ' NOT `base` -- reserved word in QB64
    SELECT CASE opt_fpslight
        CASE 1: reach = 4.5              ' guttering
        CASE 3: reach = 10.5             ' a proper brand
        CASE ELSE: reach = 7             ' a torch
    END SELECT
    FPS_TORCH_T = FPS_TORCH_T + 0.31
    '--- two incommensurate sines: one period is not a rational multiple of the
    '    other, so the flicker never settles into a visible loop ---
    FPS_TORCH_R = reach * (1 + SIN(FPS_TORCH_T) * 0.035 + SIN(FPS_TORCH_T * 2.7) * 0.025)
END SUB

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
    DIM r AS INTEGER, g AS INTEGER, b AS INTEGER, fog AS INTEGER, warm AS INTEGER

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
        warm = FpsWarm%(rowd)
        IF warm > 0 THEN LINE (0, y)-(FPS_W - 1, y), _RGBA32(255, 150, 60, warm), BF

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
'--- ONE composer. FpsPresent (the headless shot) and FpsPresentPlayer (the
'    play loop) used to each blit the buffer themselves, and the camera impulses
'    were added to only one of them -- so the shot could not photograph the very
'    thing it exists to photograph. Both go through here now. ---
SUB FpsCompose (px AS SINGLE, py AS SINGLE, ang AS SINGLE)
    DIM ex AS SINGLE, ey AS SINGLE, ox AS INTEGER, oy AS INTEGER, k AS INTEGER
    DIM sav AS SINGLE, bob AS SINGLE

    '--- A LUNGE moves the EYE along the facing, so the walls move in
    '    perspective the way stepping forward does. A SHAKE moves the BLIT,
    '    because a shake is the picture rattling rather than you walking about
    '    -- shaking the eye through a raycaster makes the world swim. ---
    FpsDecay
    ex = px + COS(ang) * FPS_LUNGE * 0.45
    ey = py + SIN(ang) * FPS_LUNGE * 0.45

    sav = FPS_PITCH
    bob = SIN(FPS_BOB) * 3
    FPS_PITCH = FPS_PITCH + bob
    FpsRender ex, ey, ang
    FPS_PITCH = sav

    _DEST CANVAS
    IF FPS_SHAKE > 0 THEN
        '--- alternate the sign every frame so it JUDDERS rather than drifting
        '    off in one direction ---
        FPS_SHAKESIGN = -FPS_SHAKESIGN
        IF FPS_SHAKESIGN = 0 THEN FPS_SHAKESIGN = 1
        ox = FPS_SHAKE * 22 * FPS_SHAKESIGN
        oy = FPS_SHAKE * 14 * FPS_SHAKESIGN
        '--- and OVER-COVER by the same amount. Offsetting the blit alone leaves
        '    a strip of whatever was on the canvas before showing along one edge
        '    -- which here is the 2D BOARD, so a shake flashed the map at you. ---
        k = ABS(ox) + ABS(oy) + 2
    END IF
    _PUTIMAGE (ox - k, oy - k)-(SW * CW - 1 + ox + k, SH * CH - 1 + oy + k), FPS_BUF, CANVAS
    FpsDrawHand
    FpsChrome px, py, ang
END SUB

SUB FpsPresent (px AS SINGLE, py AS SINGLE, ang AS SINGLE)
    FpsCompose px, py, ang
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
    IF INSTR(LCASE$(COMMAND$), "aimdoor") > 0 THEN FpsAimAtDoor cx + 0.5, cy + 0.5
    '--- `hurt` fires the combat impulses so a still frame can show them: a
    '    flash and a shake are three frames long in play and unphotographable
    '    by hand ---
    IF INSTR(LCASE$(COMMAND$), "hurt") > 0 THEN
        FpsAimAtSprite cx + 0.5, cy + 0.5
        IF FPS_AIMED > 0 THEN FpsFlashAt INT(FSP_X(FPS_AIMED)), INT(FSP_Y(FPS_AIMED))
        FpsShakeNow 0.7
        FpsLungeNow 0.6
        FPS_SWING = 0.5
    END IF
    FpsPresent cx + 0.5, cy + 0.5, FPS_ANG
    _SAVEIMAGE outp, CANVAS
    d = _DEST: _DEST _CONSOLE
    IF FPS_AIMED > 0 THEN PRINT PipeCol$("|07  aimed sprite |14" + FSP_PATH(FPS_AIMED) + "|07")
    PRINT PipeCol$("|07  hand |14" + FPS_HANDPATH + "|07 handle |14" + LTRIM$(STR$(FPS_HANDH)) + "|07")
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
    FpsInit
    FpsFollow 0
    FpsClearSprites
    Game_FpsPopulate
    FpsCompose FPS_EYEX, FPS_EYEY, FPS_ANG
END SUB

'--- every impulse decays here, in ONE place. Scattering the decay across the
'    setters is how one of them ends up never decaying and the screen shakes
'    forever. ---
SUB FpsDecay
    IF FPS_SHAKE > 0 THEN
        FPS_SHAKE = FPS_SHAKE - 0.055
        IF FPS_SHAKE < 0 THEN FPS_SHAKE = 0
    END IF
    IF FPS_LUNGE > 0 THEN
        FPS_LUNGE = FPS_LUNGE - 0.09
        IF FPS_LUNGE < 0 THEN FPS_LUNGE = 0
    END IF
    IF FPS_FLASH > 0 THEN
        FPS_FLASH = FPS_FLASH - 0.09
        IF FPS_FLASH < 0 THEN FPS_FLASH = 0
    END IF
END SUB

'--- the three impulses the game fires. Magnitudes are 0..1 so a caller says
'    how hard, not how many pixels -- pixels are this module's business. ---
SUB FpsShakeNow (amt AS SINGLE)
    IF amt > FPS_SHAKE THEN FPS_SHAKE = amt
    IF FPS_SHAKE > 1 THEN FPS_SHAKE = 1
END SUB

SUB FpsLungeNow (amt AS SINGLE)
    IF amt > FPS_LUNGE THEN FPS_LUNGE = amt
    IF FPS_LUNGE > 1 THEN FPS_LUNGE = 1
END SUB

'--- the thing you just hit lights up red. Keyed to a CELL rather than to a
'    sprite index, because the sprite list is rebuilt from scratch every frame
'    and an index would point at whatever happened to land in that slot. ---
SUB FpsFlashAt (cx AS INTEGER, cy AS INTEGER)
    FPS_FLASH = 1
    FPS_FLASHX = cx
    FPS_FLASHY = cy
END SUB

' ----------------------------------------------------------------------------
'  THE HELD WEAPON
'
'  Drawn onto the CANVAS at full size rather than into the little render buffer,
'  because it never needs perspective and blowing a 200px sprite up 4x to match
'  the buffer would throw away every pixel the generator drew.
'
'  It bobs with the walk, using the same FPS_BOB the eye does but a quarter-turn
'  out of phase -- an arm that swings in time with the head reads as a limb
'  bolted to the skull. The SWING is a separate one-shot arc triggered by a
'  blow landing, so a fight has a hand in it.
' ----------------------------------------------------------------------------
SUB FpsDrawHand
    DIM h AS LONG, w AS INTEGER, ht AS INTEGER, x AS INTEGER, y AS INTEGER
    '--- NOT `sw`: QB64 identifiers are case-insensitive, so a local `sw` shadows
    '    the shared SW (screen width in cells) and `SW * CW` silently becomes 0.
    '    The hand drew at x = -317. tests/audit-shadow.sh lists `sw` for exactly
    '    this reason and would have said so the moment the gate ran. ---
    DIM p AS STRING, bx AS SINGLE, by AS SINGLE, swing AS SINGLE

    p = Game_FpsHandArt$
    FPS_HANDPATH = p
    IF LEN(p) = 0 THEN EXIT SUB
    h = Sprite&(p)
    FPS_HANDH = h
    IF h >= -1 THEN EXIT SUB

    '--- big enough to feel held: a third of the screen height ---
    ht = (SH * CH) * 0.42
    w = ht * _WIDTH(h) / _HEIGHT(h)

    bx = COS(FPS_BOB * 0.5) * 6
    by = ABS(SIN(FPS_BOB * 0.5)) * 7

    '--- the swing: a quick arc up-and-across, decaying back to rest ---
    swing = 0
    IF FPS_SWING > 0 THEN
        FPS_SWING = FPS_SWING - 0.06
        IF FPS_SWING < 0 THEN FPS_SWING = 0
        swing = SIN(FPS_SWING * 3.14159265)
    END IF

    x = SW * CW - w + 20 + bx - swing * (w * 0.5)
    y = SH * CH - ht + 8 + by - swing * (ht * 0.28)

    _PUTIMAGE (x, y)-(x + w - 1, y + ht - 1), h, CANVAS
END SUB

'--- called by the game when a blow lands, so the arm moves when the fight does ---
SUB FpsSwing
    FPS_SWING = 1
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
    FPS_AIMED = bi
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


'--- Does this ray meet the door plane inside this cell?
'
'    The door stands across the middle of the cell, perpendicular to whichever
'    way you walk through it -- which is decided by the WALLS around it, not by
'    the ray: a door in a north-south corridor hangs east-west. Solve for the
'    ray parameter at that midline, and accept only if the crossing is inside
'    the cell. Anything else and you would see doors through the wall beside
'    them.
'
'    dist and wallx come back updated, because a thin wall is nearer than the
'    cell boundary the DDA measured to. ---
FUNCTION FpsThinHit% (px AS SINGLE, py AS SINGLE, rdx AS SINGLE, rdy AS SINGLE, _
                      mapx AS INTEGER, mapy AS INTEGER, side AS INTEGER, _
                      ddx AS SINGLE, ddy AS SINGLE, sidex AS SINGLE, sidey AS SINGLE, _
                      dist AS SINGLE, wallx AS SINGLE)
    DIM t AS SINGLE, hx AS SINGLE, hy AS SINGLE, vert AS INTEGER

    '--- which way the door hangs: across the corridor it sits in. Solid cells
    '    to left and right mean the way through is north-south, so the door
    '    faces east-west. ---
    vert = 0
    IF FpsSolid%(mapx - 1, mapy) _ANDALSO FpsSolid%(mapx + 1, mapy) THEN
        vert = 0                                  ' walls beside it: door lies flat (E-W)
    ELSEIF FpsSolid%(mapx, mapy - 1) _ANDALSO FpsSolid%(mapx, mapy + 1) THEN
        vert = -1                                 ' walls above and below: door stands (N-S)
    ELSE
        '--- an open doorway with no jambs either side: hang it across the way
        '    the ray is travelling most, which is the only guess left ---
        vert = (ABS(rdx) > ABS(rdy))
    END IF

    IF vert THEN
        IF rdx = 0 THEN EXIT FUNCTION
        t = (mapx + 0.5 - px) / rdx
        IF t <= 0 THEN EXIT FUNCTION
        hy = py + t * rdy
        IF hy < mapy _ORELSE hy > mapy + 1 THEN EXIT FUNCTION
        wallx = hy - mapy
    ELSE
        IF rdy = 0 THEN EXIT FUNCTION
        t = (mapy + 0.5 - py) / rdy
        IF t <= 0 THEN EXIT FUNCTION
        hx = px + t * rdx
        IF hx < mapx _ORELSE hx > mapx + 1 THEN EXIT FUNCTION
        wallx = hx - mapx
    END IF

    '--- the ray parameter IS the perpendicular distance here, because rdx/rdy
    '    are the unnormalised camera-space ray -- the same quantity the DDA
    '    produces, so near/far ordering stays consistent between the two ---
    dist = t
    FpsThinHit% = -1
END FUNCTION

'--- a door the player has not opened yet. An OPENED door stops being drawn --
'    it swung out of the way, and leaving it hanging there would be a door you
'    walk through while looking at it. ---
FUNCTION FpsDoorAt% (cx AS INTEGER, cy AS INTEGER)
    IF cx < 0 _ORELSE cy < 0 _ORELSE cx > SW - 1 _ORELSE cy > SH - 1 THEN EXIT FUNCTION
    IF FPS_DOORTEX >= -1 THEN EXIT FUNCTION
    IF DOOROPEN(cx, cy) THEN EXIT FUNCTION
    FpsDoorAt% = Game_FpsIsDoor%(cx, cy)
END FUNCTION


'--- turn toward the nearest door in sight, so the thin-wall door can be
'    photographed without hunting the board for one ---
SUB FpsAimAtDoor (px AS SINGLE, py AS SINGLE)
    DIM i AS INTEGER, d AS SINGLE, best AS SINGLE, bi AS INTEGER
    best = 1E+30
    FOR i = 1 TO DOOR_N
        IF FpsLineClear%(px, py, DOOR_X(i) + 0.5, DOOR_Y(i) + 0.5) = 0 THEN _CONTINUE
        d = (DOOR_X(i) + 0.5 - px) * (DOOR_X(i) + 0.5 - px) + (DOOR_Y(i) + 0.5 - py) * (DOOR_Y(i) + 0.5 - py)
        IF d > 0.5 _ANDALSO d < best THEN best = d: bi = i
    NEXT i
    IF bi = 0 THEN EXIT SUB
    FPS_ANG = _ATAN2(DOOR_Y(bi) + 0.5 - py, DOOR_X(bi) + 0.5 - px)
END SUB


' ----------------------------------------------------------------------------
'  The HURT image -- a red copy of a sprite, alpha intact.
'
'  Built once per sprite and cached, because it is a per-pixel pass. Painting
'  red over the sprite's screen COLUMNS instead is a one-liner and it is wrong:
'  the columns are the bounding box, so a monster flashes as a red rectangle
'  with the monster faintly inside it. The alpha has to survive, and only the
'  image knows where it is.
' ----------------------------------------------------------------------------
FUNCTION FpsHurtImage& (path AS STRING, src AS LONG)
    DIM i AS INTEGER, w AS INTEGER, ht AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM d AS LONG, so AS LONG, k AS _UNSIGNED LONG, a AS INTEGER

    FOR i = 1 TO FPS_HURT_N
        IF FPS_HURT_KEY(i) = path THEN FpsHurtImage& = FPS_HURT_IMG(i): EXIT FUNCTION
    NEXT i
    IF FPS_HURT_N >= UBOUND(FPS_HURT_IMG) THEN FpsHurtImage& = src: EXIT FUNCTION

    w = _WIDTH(src): ht = _HEIGHT(src)
    IF w < 1 _ORELSE ht < 1 THEN FpsHurtImage& = src: EXIT FUNCTION

    d = _DEST: so = _SOURCE
    FPS_HURT_N = FPS_HURT_N + 1
    FPS_HURT_KEY(FPS_HURT_N) = path
    FPS_HURT_IMG(FPS_HURT_N) = _NEWIMAGE(w, ht, 32)

    _SOURCE src
    _DEST FPS_HURT_IMG(FPS_HURT_N)
    CLS , _RGBA32(0, 0, 0, 0)
    FOR y = 0 TO ht - 1
        FOR x = 0 TO w - 1
            k = POINT(x, y)
            a = _ALPHA32(k)
            IF a > 0 THEN
                '--- keep some of the original luminance so the shape still
                '    reads; a flat silhouette loses the monster entirely ---
                '--- a translucent red WASH, not a silhouette: the shape has to
                '    stay readable, it is the thing you are fighting ---
                PSET (x, y), _RGBA32(255, 40, 30, a * 0.62)
            END IF
        NEXT x
    NEXT y
    _DEST d: _SOURCE so
    FpsHurtImage& = FPS_HURT_IMG(FPS_HURT_N)
END FUNCTION


' ----------------------------------------------------------------------------
'  Black-background sprites.
'
'  Some sprites in the art packs were drawn on an opaque BLACK field rather than
'  on transparency. On a 2D panel nobody notices. Standing in a dark corridor
'  they are black RECTANGLES hanging in the air, and the darker the lighting got
'  the worse they looked -- the torch made an old art problem visible rather
'  than causing one.
'
'  So: if a sprite's four corners are opaque black, cache a copy with black
'  keyed out. Corners rather than a pixel count, because a monster can be very
'  dark without being on a black field, and all four corners being pure black is
'  what a background looks like and what a subject does not.
'
'  The COPY matters. _CLEARCOLOR on the shared cached image would change how the
'  sprite draws everywhere else in the game, from a decision taken by the
'  raycaster.
' ----------------------------------------------------------------------------
FUNCTION FpsCutout& (path AS STRING, src AS LONG)
    DIM i AS INTEGER, so AS LONG, d AS LONG, w AS INTEGER, ht AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, cp AS LONG, k AS _UNSIGNED LONG
    DIM cr AS INTEGER, cg AS INTEGER, cb AS INTEGER, n AS INTEGER

    FOR i = 1 TO FPS_CUT_N
        IF FPS_CUT_KEY(i) = path THEN FpsCutout& = FPS_CUT_IMG(i): EXIT FUNCTION
    NEXT i
    IF FPS_CUT_N >= UBOUND(FPS_CUT_IMG) THEN FpsCutout& = src: EXIT FUNCTION

    w = _WIDTH(src): ht = _HEIGHT(src)
    IF w < 2 _ORELSE ht < 2 THEN FpsCutout& = src: EXIT FUNCTION

    so = _SOURCE: d = _DEST
    _SOURCE src

    '--- the four corners must AGREE, and be dark. Agreement is the real test:
    '    a monster can be very dark all over without being on a field, but four
    '    corners that are the same dark colour is a background. ---
    IF FpsCornerField%(w, ht, cr, cg, cb) = 0 THEN
        _SOURCE so
        FPS_CUT_N = FPS_CUT_N + 1
        FPS_CUT_KEY(FPS_CUT_N) = path
        FPS_CUT_IMG(FPS_CUT_N) = src
        FpsCutout& = src
        EXIT FUNCTION
    END IF

    cp = _NEWIMAGE(w, ht, 32)
    _DEST cp
    CLS , _RGBA32(0, 0, 0, 0)
    FOR y = 0 TO ht - 1
        FOR x = 0 TO w - 1
            _SOURCE src
            k = POINT(x, y)
            _DEST cp
            '--- keyed by NEARNESS to the field colour, not by an exact match:
            '    these backgrounds are often a faint gradient rather than one
            '    flat value, and _CLEARCOLOR only removes the exact shade --
            '    which leaves a box with a hole in the middle of it. ---
            IF ABS(_RED32(k) - cr) + ABS(_GREEN32(k) - cg) + ABS(_BLUE32(k) - cb) > 40 THEN
                PSET (x, y), k
            END IF
        NEXT x
    NEXT y
    _DEST d: _SOURCE so

    FPS_CUT_N = FPS_CUT_N + 1
    FPS_CUT_KEY(FPS_CUT_N) = path
    FPS_CUT_IMG(FPS_CUT_N) = cp
    FpsCutout& = cp
END FUNCTION

'--- do the four corners agree on one dark colour? Returns it if so. ---
FUNCTION FpsCornerField% (w AS INTEGER, ht AS INTEGER, cr AS INTEGER, cg AS INTEGER, cb AS INTEGER)
    DIM k1 AS _UNSIGNED LONG, k2 AS _UNSIGNED LONG, k3 AS _UNSIGNED LONG, k4 AS _UNSIGNED LONG
    k1 = POINT(0, 0): k2 = POINT(w - 1, 0)
    k3 = POINT(0, ht - 1): k4 = POINT(w - 1, ht - 1)
    IF _ALPHA32(k1) < 250 _ORELSE _ALPHA32(k2) < 250 THEN EXIT FUNCTION
    IF _ALPHA32(k3) < 250 _ORELSE _ALPHA32(k4) < 250 THEN EXIT FUNCTION

    cr = (_RED32(k1) + _RED32(k2) + _RED32(k3) + _RED32(k4)) \ 4
    cg = (_GREEN32(k1) + _GREEN32(k2) + _GREEN32(k3) + _GREEN32(k4)) \ 4
    cb = (_BLUE32(k1) + _BLUE32(k2) + _BLUE32(k3) + _BLUE32(k4)) \ 4

    '--- dark, or it is not a black field and keying it would eat the art ---
    IF cr > 60 _ORELSE cg > 60 _ORELSE cb > 60 THEN EXIT FUNCTION
    '--- and all four close to that average ---
    IF FpsFarFrom%(k1, cr, cg, cb) _ORELSE FpsFarFrom%(k2, cr, cg, cb) THEN EXIT FUNCTION
    IF FpsFarFrom%(k3, cr, cg, cb) _ORELSE FpsFarFrom%(k4, cr, cg, cb) THEN EXIT FUNCTION
    FpsCornerField% = -1
END FUNCTION

FUNCTION FpsFarFrom% (k AS _UNSIGNED LONG, cr AS INTEGER, cg AS INTEGER, cb AS INTEGER)
    IF ABS(_RED32(k) - cr) + ABS(_GREEN32(k) - cg) + ABS(_BLUE32(k) - cb) > 36 THEN FpsFarFrom% = -1
END FUNCTION




' ----------------------------------------------------------------------------
'  Shaded sprite copies.
'
'  A sprite has to be dimmed by distance like everything else, and the only way
'  to do that WITHOUT painting over its transparent pixels is to dim the image.
'  So: a handful of pre-darkened copies per sprite, built on demand and cached,
'  and the renderer picks the nearest level.
'
'  This is the same answer the 3D dice reached for the same reason -- there the
'  brightness levels are baked into the texture atlas as columns. Overlaying is
'  always the tempting one-liner and it is always wrong the moment alpha is
'  involved.
'
'  Quantised to FPS_SHADE_LV steps because the alternative is a fresh per-pixel
'  pass every time a monster moves a foot nearer.
' ----------------------------------------------------------------------------
FUNCTION FpsShadeImage& (path AS STRING, src AS LONG, fog AS INTEGER)
    DIM lv AS INTEGER, kk AS STRING, i AS INTEGER
    DIM w AS INTEGER, ht AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM so AS LONG, d AS LONG, cp AS LONG, k AS _UNSIGNED LONG, f AS SINGLE

    lv = (fog * FPS_SHADE_LV) \ 256
    IF lv < 1 THEN FpsShadeImage& = src: EXIT FUNCTION
    IF lv > FPS_SHADE_LV - 1 THEN lv = FPS_SHADE_LV - 1

    kk = path + "#" + LTRIM$(STR$(lv))
    FOR i = 1 TO FPS_SH_N
        IF FPS_SH_KEY(i) = kk THEN FpsShadeImage& = FPS_SH_IMG(i): EXIT FUNCTION
    NEXT i
    IF FPS_SH_N >= UBOUND(FPS_SH_IMG) THEN FpsShadeImage& = src: EXIT FUNCTION

    w = _WIDTH(src): ht = _HEIGHT(src)
    IF w < 1 _ORELSE ht < 1 THEN FpsShadeImage& = src: EXIT FUNCTION

    f = 1 - lv / FPS_SHADE_LV
    so = _SOURCE: d = _DEST
    cp = _NEWIMAGE(w, ht, 32)
    _DEST cp: CLS , _RGBA32(0, 0, 0, 0)
    FOR y = 0 TO ht - 1
        FOR x = 0 TO w - 1
            _SOURCE src
            k = POINT(x, y)
            _DEST cp
            IF _ALPHA32(k) > 0 THEN
                PSET (x, y), _RGBA32(_RED32(k) * f, _GREEN32(k) * f, _BLUE32(k) * f + 2, _ALPHA32(k))
            END IF
        NEXT x
    NEXT y
    _DEST d: _SOURCE so

    FPS_SH_N = FPS_SH_N + 1
    FPS_SH_KEY(FPS_SH_N) = kk
    FPS_SH_IMG(FPS_SH_N) = cp
    FpsShadeImage& = cp
END FUNCTION
