$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' Colored light preview: a d20 lit by different LIGHT_KOLOR values (white=neutral, then torch/
' moonlight/poison hues). Confirms lit faces wash toward the light colour while white stays as-is.
' Writes dicelab.png.
CONST TILE = 210
DIM lname(0 TO 3) AS STRING, lkol(0 TO 3) AS _UNSIGNED LONG
lname(0) = "white": lkol(0) = _RGB32(255, 255, 255)
lname(1) = "torch": lkol(1) = _RGB32(255, 150, 60)
lname(2) = "moon": lkol(2) = _RGB32(120, 170, 255)
lname(3) = "poison": lkol(3) = _RGB32(140, 255, 120)

DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = TILE: cfg.BOX_H = TILE
cfg.DIE_SIZE = 76
cfg.CAM_TILT = 21.5: cfg.CAM_YAW = 0
cfg.BODY_KOLOR = _RGB32(150, 40, 48)       ' the game's ruby body
cfg.NUM_KOLOR = _RGB32(255, 210, 90)

SCREEN _NEWIMAGE(TILE * 4, TILE + 44, 32)
_DEST 0: CLS , _RGB32(52, 34, 122)
DICE3D_HW = 0
DICE3D_BOXBUF = _NEWIMAGE(cfg.BOX_W, cfg.BOX_H, 32)
dice3d_build 20

DIM lv AS INTEGER, atlas AS LONG
FOR lv = 0 TO 3
    cfg.LIGHT_KOLOR = lkol(lv)
    atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)
    REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
    DICE3D_DICE(0).SIDES = 20
    DICE3D_DICE(0).ATLAS = atlas
    DICE3D_DICE(0).FADE = 1
    DICE3D_DICE(0).PX = cfg.BOX_W / 2
    DICE3D_DICE(0).PY = cfg.BOX_H / 2
    DICE3D_DICE(0).PZ = 0
    DICE3D_DICE(0).VALUE = 20
    DICE3D_DICE(0).Q = DICE3D_FACE_Q(DICE3D_VAL2FACE(20))
    _DEST DICE3D_BOXBUF: CLS , _RGB32(52, 34, 122)
    dice3d_render_die DICE3D_DICE(0), cfg
    _DEST 0
    _PUTIMAGE (lv * TILE, 34), DICE3D_BOXBUF, 0
    COLOR _RGB32(200, 255, 200), _RGB32(52, 34, 122)
    _PRINTSTRING (lv * TILE + 74, 12), lname(lv)
    _FREEIMAGE atlas
NEXT
COLOR _RGB32(255, 240, 150), _RGB32(52, 34, 122)
_PRINTSTRING (10, TILE + 30), "LIGHT_KOLOR: white=neutral, then torch / moonlight / poison (ruby d20)"
_DISPLAY
_SAVEIMAGE "dicelab.png"
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
