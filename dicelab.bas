$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' Beveled dice at the GAME's real settings (cfg.BEVEL=1 -> texture bevel + geometry bevel 0.18).
' Verifies each die type renders rounded AND still reads its value (esp. the d4 top-read).
' Writes dicelab.png.
CONST TILE = 210
DIM dt(0 TO 3) AS INTEGER, dv(0 TO 3) AS INTEGER
dt(0) = 4: dv(0) = 2
dt(1) = 6: dv(1) = 6
dt(2) = 8: dv(2) = 8
dt(3) = 20: dv(3) = 20

DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = TILE: cfg.BOX_H = TILE
cfg.DIE_SIZE = 74
cfg.CAM_TILT = 26: cfg.CAM_YAW = 16
cfg.BEVEL = 1                                  ' matches the game's dice sets
cfg.BODY_KOLOR = _RGB32(150, 40, 48): cfg.NUM_KOLOR = _RGB32(255, 210, 90)

SCREEN _NEWIMAGE(TILE * 4, TILE + 40, 32)
_DEST 0: CLS , _RGB32(52, 34, 122)
DICE3D_HW = 0
DICE3D_BOXBUF = _NEWIMAGE(cfg.BOX_W, cfg.BOX_H, 32)

DIM i AS INTEGER, atlas AS LONG, sides AS INTEGER, tilt AS SINGLE
FOR i = 0 TO 3
    sides = dt(i)
    tilt = cfg.CAM_TILT: IF sides = 4 THEN cfg.CAM_TILT = 85    ' the game views the d4 top-down
    DICE3D_BEVEL = cfg.BEVEL * 0.18: dice3d_build sides
    atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)
    REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
    DICE3D_DICE(0).SIDES = sides
    DICE3D_DICE(0).ATLAS = atlas
    DICE3D_DICE(0).FADE = 1
    DICE3D_DICE(0).PX = cfg.BOX_W / 2: DICE3D_DICE(0).PY = cfg.BOX_H / 2: DICE3D_DICE(0).PZ = 0
    DICE3D_DICE(0).VALUE = dv(i)
    IF sides = 4 THEN
        DIM axisX AS DICE3D_VEC3, rxt AS DICE3D_QUAT, qc AS DICE3D_QUAT
        axisX.X = 1: axisX.Y = 0: axisX.Z = 0
        dice3d_qaxisangle axisX, (90 + cfg.CAM_TILT - 4) * 0.0174532925, rxt
        dice3d_qmul rxt, DICE3D_FACE_Q(DICE3D_VAL2FACE(dv(i))), qc
        DICE3D_DICE(0).Q = qc
    ELSE
        DICE3D_DICE(0).Q = DICE3D_FACE_Q(DICE3D_VAL2FACE(dv(i)))
    END IF
    _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122)
    dice3d_render_die DICE3D_DICE(0), cfg
    _DEST 0
    _PUTIMAGE (i * TILE, 34), DICE3D_BOXBUF, 0
    COLOR _RGB32(200, 255, 200), _RGB32(52, 34, 122)
    _PRINTSTRING (i * TILE + 30, 12), "d" + LTRIM$(STR$(sides)) + " reads" + STR$(dv(i))
    _FREEIMAGE atlas
    cfg.CAM_TILT = tilt
NEXT
DICE3D_BEVEL = 0
COLOR _RGB32(255, 240, 150), _RGB32(52, 34, 122)
_PRINTSTRING (10, TILE + 26), "rounded (geometry) dice at game settings -- values must read"
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
