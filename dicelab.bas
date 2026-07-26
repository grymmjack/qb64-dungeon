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

SCREEN _NEWIMAGE(TILE * 6, TILE + 40, 32)
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

' Render the showcase pose for several values -- the read (winning) face should carry a
' warm sheen from the read-face highlight, the others not.
DIM f AS INTEGER, i AS INTEGER, v AS INTEGER
DIM vals(0 TO 3) AS INTEGER
vals(0) = 1: vals(1) = 2: vals(2) = sides - 1: vals(3) = sides
FOR i = 0 TO 3
    v = vals(i)
    IF v >= 1 AND v <= sides THEN
        f = DICE3D_VAL2FACE(v)
        DICE3D_DICE(0).VALUE = v
        DICE3D_DICE(0).Q = DICE3D_FACE_Q(f)
        _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122)
        dice3d_render_die DICE3D_DICE(0), cfg
        _DEST 0
        _PUTIMAGE (i * TILE, 30), DICE3D_BOXBUF, 0
        COLOR _RGB32(255, 240, 150), _RGB32(52, 34, 122)
        _PRINTSTRING (i * TILE + 20, 8), "value =" + STR$(v)
    END IF
NEXT
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
