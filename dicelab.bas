$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' SETTINGS "Dice Light" level preview: a d20 at each opt_dicelight level (Off/Soft/Normal/
' Strong) using the SAME ambient/intensity ApplyDiceLight sets, at the game's non-d4 tilt.
' Confirms the four levels are visually distinct. Writes dicelab.png.
CONST TILE = 210
DIM lname(0 TO 3) AS STRING, lamb(0 TO 3) AS SINGLE, lint(0 TO 3) AS SINGLE, lon(0 TO 3) AS INTEGER
lname(0) = "off": lon(0) = 0
lname(1) = "soft": lon(1) = -1: lamb(1) = 0.62: lint(1) = 0.5
lname(2) = "normal": lon(2) = -1: lamb(2) = 0.5: lint(2) = 0.8
lname(3) = "strong": lon(3) = -1: lamb(3) = 0.38: lint(3) = 1.0

DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = TILE: cfg.BOX_H = TILE
cfg.DIE_SIZE = 76
cfg.CAM_TILT = 21.5: cfg.CAM_YAW = 0
cfg.BODY_KOLOR = _RGB32(60, 120, 190)   ' sapphire-ish (default player set)

SCREEN _NEWIMAGE(TILE * 4, TILE + 44, 32)
_DEST 0: CLS , _RGB32(52, 34, 122)

DICE3D_HW = 0
DICE3D_BOXBUF = _NEWIMAGE(cfg.BOX_W, cfg.BOX_H, 32)
dice3d_build 20
DIM atlas AS LONG: atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)

REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
DICE3D_DICE(0).SIDES = 20
DICE3D_DICE(0).ATLAS = atlas
DICE3D_DICE(0).FADE = 1
DICE3D_DICE(0).PX = cfg.BOX_W / 2
DICE3D_DICE(0).PY = cfg.BOX_H / 2
DICE3D_DICE(0).PZ = 0
DICE3D_DICE(0).VALUE = 20
DICE3D_DICE(0).Q = DICE3D_FACE_Q(DICE3D_VAL2FACE(20))

DIM lv AS INTEGER
FOR lv = 0 TO 3
    cfg.LIGHT_ENABLED = lon(lv)
    cfg.LIGHT_AMBIENT = lamb(lv): cfg.LIGHT_INTENSITY = lint(lv)
    _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122)
    dice3d_render_die DICE3D_DICE(0), cfg
    _DEST 0
    _PUTIMAGE (lv * TILE, 34), DICE3D_BOXBUF, 0
    COLOR _RGB32(180, 255, 180), _RGB32(52, 34, 122)
    _PRINTSTRING (lv * TILE + 70, 12), lname(lv)
NEXT
COLOR _RGB32(255, 240, 150), _RGB32(52, 34, 122)
_PRINTSTRING (10, TILE + 30), "SETTINGS Dice Light levels (d20, sapphire)"
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
