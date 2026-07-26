$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' A visual lab for the 3D dice: render each face-value of a die statically (software
' path -> DICE3D_BOXBUF, which _SAVEIMAGE can capture) so I can SEE the pose/value.
' Usage: dicelab.run <sides>   (default 4). Writes dicelab.png.
CONST TILE = 150, DSZ = 44
DIM sides AS INTEGER
sides = 4
IF LEN(COMMAND$) > 0 THEN sides = VAL(COMMAND$)
IF sides < 4 THEN sides = 4

DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = TILE: cfg.BOX_H = TILE
cfg.DIE_SIZE = DSZ
cfg.CAM_TILT = 32: cfg.CAM_YAW = 0
cfg.WIRE_ENABLED = -1: cfg.WIRE_OPACITY = 0.5: cfg.WIRE_KOLOR = _RGB32(20, 20, 30)

SCREEN _NEWIMAGE(TILE * 3, TILE * 2 + 80, 32)
_DEST 0: CLS , _RGB32(52, 34, 122)

DICE3D_HW = 0                          ' force the software render path
DICE3D_BOXBUF = _NEWIMAGE(cfg.BOX_W, cfg.BOX_H, 32)
dice3d_build sides
DIM atlas AS LONG
cfg.BODY_KOLOR = _RGB32(150, 40, 48): atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)

REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
DICE3D_DICE(0).SIDES = sides
DICE3D_DICE(0).ATLAS = atlas
DICE3D_DICE(0).FADE = 1
DICE3D_DICE(0).PX = cfg.BOX_W / 2
DICE3D_DICE(0).PY = cfg.BOX_H / 2
DICE3D_DICE(0).PZ = 0

' Compare current FACE_Q vs tilt-corrected pose (Rx(camtilt)*FACE_Q) at CAM_TILT=32.
DIM f AS INTEGER, i AS INTEGER, v AS INTEGER
DIM axisX AS DICE3D_VEC3, rx AS DICE3D_QUAT, qc AS DICE3D_QUAT
axisX.X = 1: axisX.Y = 0: axisX.Z = 0
dice3d_qaxisangle axisX, 32 * 0.0174532925, rx
DIM vals(0 TO 2) AS INTEGER
vals(0) = 1: vals(1) = 2: vals(2) = 4
FOR i = 0 TO 2
    v = vals(i): f = DICE3D_VAL2FACE(v): DICE3D_DICE(0).VALUE = v
    ' top row: current (reverted) FACE_Q
    DICE3D_DICE(0).Q = DICE3D_FACE_Q(f)
    _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122): dice3d_render_die DICE3D_DICE(0), cfg
    _DEST 0: _PUTIMAGE (i * TILE, 30), DICE3D_BOXBUF, 0
    COLOR _RGB32(255, 200, 200), _RGB32(52, 34, 122): _PRINTSTRING (i * TILE + 8, 8), "now val" + STR$(v)
    ' bottom row: tilt-corrected
    dice3d_qmul rx, DICE3D_FACE_Q(f), qc: DICE3D_DICE(0).Q = qc
    _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122): dice3d_render_die DICE3D_DICE(0), cfg
    _DEST 0: _PUTIMAGE (i * TILE, TILE + 60), DICE3D_BOXBUF, 0
    COLOR _RGB32(200, 255, 200), _RGB32(52, 34, 122): _PRINTSTRING (i * TILE + 8, TILE + 42), "fixed val" + STR$(v)
NEXT
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
