$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' Big bullnose-bevel check: d20 + d6, sharp (left) vs rounded (right), at a 3/4 view that reveals
' edges + silhouette. Confirms the roll-over is smooth and nothing pokes out. Writes dicelab.png.
CONST TILE = 300
DIM dt(0 TO 1) AS INTEGER, dv(0 TO 1) AS INTEGER
dt(0) = 20: dv(0) = 20
dt(1) = 6: dv(1) = 6

DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = TILE: cfg.BOX_H = TILE
cfg.DIE_SIZE = 118
cfg.CAM_TILT = 22: cfg.CAM_YAW = 22
cfg.BEVEL = 1
cfg.BODY_KOLOR = _RGB32(150, 40, 48): cfg.NUM_KOLOR = _RGB32(255, 210, 90)

SCREEN _NEWIMAGE(TILE * 2, TILE * 2 + 30, 32)
_DEST 0: CLS , _RGB32(52, 34, 122)
DICE3D_HW = 0
DICE3D_BOXBUF = _NEWIMAGE(cfg.BOX_W, cfg.BOX_H, 32)

DIM row AS INTEGER, col AS INTEGER, atlas AS LONG, sides AS INTEGER, bv AS SINGLE
FOR row = 0 TO 1
    sides = dt(row)
    FOR col = 0 TO 1
        bv = col * 0.18                              ' left sharp, right rounded
        DICE3D_BEVEL = bv: dice3d_build sides
        atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)
        REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
        DICE3D_DICE(0).SIDES = sides
        DICE3D_DICE(0).ATLAS = atlas
        DICE3D_DICE(0).FADE = 1
        DICE3D_DICE(0).PX = cfg.BOX_W / 2: DICE3D_DICE(0).PY = cfg.BOX_H / 2: DICE3D_DICE(0).PZ = 0
        DICE3D_DICE(0).VALUE = dv(row)
        DICE3D_DICE(0).Q = DICE3D_FACE_Q(DICE3D_VAL2FACE(dv(row)))
        _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122)
        dice3d_render_die DICE3D_DICE(0), cfg
        _DEST 0
        _PUTIMAGE (col * TILE, 26 + row * TILE), DICE3D_BOXBUF, 0
        IF row = 0 THEN
            COLOR _RGB32(200, 255, 200), _RGB32(10, 10, 14)
            IF col = 0 THEN _PRINTSTRING (90, 6), "sharp" ELSE _PRINTSTRING (TILE + 80, 6), "rounded"
        END IF
        _FREEIMAGE atlas
    NEXT
NEXT
DICE3D_BEVEL = 0
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
