$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' d4 verification at the GAME'S ACTUAL d4 camera (CAM_TILT=85, near top-down) using the
' committed showcase pose Rx(90+CAM_TILT-4)*FACE_Q. Top row LIGHT OFF, bottom row LIGHT ON.
' The value must read at the apex for each of 1..4. Writes dicelab.png.
CONST TILE = 210
DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = TILE: cfg.BOX_H = TILE
cfg.DIE_SIZE = 74
cfg.CAM_TILT = 85: cfg.CAM_YAW = 2.4
cfg.BODY_KOLOR = _RGB32(150, 40, 48)

SCREEN _NEWIMAGE(TILE * 4, TILE * 2 + 40, 32)
_DEST 0: CLS , _RGB32(52, 34, 122)

DICE3D_HW = 0
DICE3D_BOXBUF = _NEWIMAGE(cfg.BOX_W, cfg.BOX_H, 32)
dice3d_build 4
DIM atlas AS LONG: atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)

REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
DICE3D_DICE(0).SIDES = 4
DICE3D_DICE(0).ATLAS = atlas
DICE3D_DICE(0).FADE = 1
DICE3D_DICE(0).PX = cfg.BOX_W / 2
DICE3D_DICE(0).PY = cfg.BOX_H / 2
DICE3D_DICE(0).PZ = 0

DIM axisX AS DICE3D_VEC3, rxt AS DICE3D_QUAT, qc AS DICE3D_QUAT
axisX.X = 1: axisX.Y = 0: axisX.Z = 0
dice3d_qaxisangle axisX, (90 + cfg.CAM_TILT - 4) * 0.0174532925, rxt

DIM v AS INTEGER, row AS INTEGER
FOR v = 1 TO 4
    DICE3D_DICE(0).VALUE = v
    dice3d_qmul rxt, DICE3D_FACE_Q(DICE3D_VAL2FACE(v)), qc
    DICE3D_DICE(0).Q = qc
    FOR row = 0 TO 1
        cfg.LIGHT_ENABLED = (row = 1) * -1
        _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122)
        dice3d_render_die DICE3D_DICE(0), cfg
        _DEST 0
        _PUTIMAGE ((v - 1) * TILE, 30 + row * TILE), DICE3D_BOXBUF, 0
    NEXT
    COLOR _RGB32(180, 255, 180), _RGB32(52, 34, 122)
    _PRINTSTRING ((v - 1) * TILE + 60, 12), "rolled" + STR$(v)
NEXT
COLOR _RGB32(255, 240, 150), _RGB32(52, 34, 122)
_PRINTSTRING (10, TILE * 2 + 22), "d4 @ CAM_TILT=85 (real game d4 view)   top: light off   bottom: light on"
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
