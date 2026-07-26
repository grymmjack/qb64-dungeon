$RESIZE:ON
'$INCLUDE:'include/DICE3D/_ALL.BI'

' ============================================================================
'  HARDWARE dice lab -- run this on YOUR display to see the real GL dice.
'
'  Renders one die on the actual OpenGL layer (dice3d_present_hw), exactly as
'  the game does, at the settled "showcase" rest pose -- so you see precisely
'  what a rolled die looks like, including the read-face sheen and the d4's
'  apex-up top-read. (This can't be screenshotted headless: _SAVEIMAGE does
'  not read back the GL layer, so it must be run on a real screen.)
'
'  KEYS:  LEFT/RIGHT  cycle die type (d4 d6 d8 d10 d12 d20)
'         UP/DOWN     change the shown value
'         SPACE       random value
'         ESC         quit
' ============================================================================

CONST DEG2RAD = 0.0174532925
CONST ZBASE = -5.0, PXPERUNIT = 103.0

DIM SIDESET(0 TO 5) AS INTEGER
SIDESET(0) = 4: SIDESET(1) = 6: SIDESET(2) = 8: SIDESET(3) = 10: SIDESET(4) = 12: SIDESET(5) = 20

DIM cfg AS DICE3D_CONFIG
dice3d_config_defaults cfg
cfg.BOX_W = 480: cfg.BOX_H = 480
cfg.DIE_SIZE = 150
cfg.CAM_TILT = 32: cfg.CAM_YAW = 0
cfg.BODY_KOLOR = _RGB32(150, 40, 48)

SCREEN _NEWIMAGE(900, 700, 32)

DIM pxk AS SINGLE: pxk = 1.0 / PXPERUNIT
DICE3D_HW = -1
DICE3D_HW_Z = ZBASE
DICE3D_HW_PXK = pxk
DICE3D_HW_S = cfg.DIE_SIZE * pxk
DICE3D_HW_CX = 0
DICE3D_HW_CY = 0
DICE3D_UPRIGHT = -1

DIM si AS INTEGER: si = 0 '                which entry of SIDESET
DIM vshow AS INTEGER: vshow = 4 '              shown value
DIM sides AS INTEGER
DIM needBuild AS INTEGER: needBuild = -1
DIM atlas AS LONG: atlas = 0

DIM axisX AS DICE3D_VEC3, rxt AS DICE3D_QUAT, qc AS DICE3D_QUAT
axisX.X = 1: axisX.Y = 0: axisX.Z = 0

DIM k AS INTEGER, lov AS INTEGER, hiv AS INTEGER

DO
    sides = SIDESET(si)
    lov = 1: hiv = sides
    IF sides = 10 THEN lov = 0: hiv = 9
    IF vshow < lov THEN vshow = hiv
    IF vshow > hiv THEN vshow = lov

    IF needBuild THEN
        IF atlas <> 0 THEN _FREEIMAGE atlas: atlas = 0
        IF DICE3D_HWATLAS <> 0 THEN _FREEIMAGE DICE3D_HWATLAS: DICE3D_HWATLAS = 0
        dice3d_build sides
        atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)
        REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
        DICE3D_DICE(0).SIDES = sides
        DICE3D_DICE(0).ATLAS = atlas
        DICE3D_DICE(0).FADE = 1
        DICE3D_DICE(0).PX = cfg.BOX_W / 2
        DICE3D_DICE(0).PY = cfg.BOX_H / 2
        DICE3D_DICE(0).PZ = 0
        needBuild = 0
    END IF

    DICE3D_DICE(0).VALUE = vshow
    '--- showcase rest pose (mirrors dice3d_showcase) ---
    IF sides = 4 THEN
        dice3d_qaxisangle axisX, (90 + cfg.CAM_TILT - 4) * DEG2RAD, rxt
        dice3d_qmul rxt, DICE3D_FACE_Q(DICE3D_VAL2FACE(vshow)), qc
        DICE3D_DICE(0).Q = qc
    ELSE
        DICE3D_DICE(0).Q = DICE3D_FACE_Q(DICE3D_VAL2FACE(vshow))
    END IF

    '--- draw the tray/text on the software screen, then the die on the GL layer ---
    CLS , _RGB32(52, 34, 122)
    COLOR _RGB32(255, 240, 150), _RGB32(52, 34, 122)
    _PRINTSTRING (24, 20), "HARDWARE DICE LAB  --  d" + LTRIM$(STR$(sides)) + "   showing value" + STR$(vshow)
    COLOR _RGB32(170, 180, 220), _RGB32(52, 34, 122)
    _PRINTSTRING (24, 648), "LEFT/RIGHT: die type   UP/DOWN: value   SPACE: random   ESC: quit"
    dice3d_present_hw cfg '                 presents + _DISPLAY

    '--- input ---
    k = 0
    DO
        k = _KEYHIT
        IF k = 0 THEN _LIMIT 60
    LOOP UNTIL k <> 0
    SELECT CASE k
        CASE 19712 '                        RIGHT
            si = si + 1: IF si > 5 THEN si = 0
            needBuild = -1
        CASE 19200 '                        LEFT
            si = si - 1: IF si < 0 THEN si = 5
            needBuild = -1
        CASE 18432 '                        UP
            vshow = vshow + 1
        CASE 20480 '                        DOWN
            vshow = vshow - 1
        CASE 32 '                           SPACE = random value
            vshow = lov + INT(RND * (hiv - lov + 1))
        CASE 27 '                           ESC
            EXIT DO
    END SELECT
LOOP

IF atlas <> 0 THEN _FREEIMAGE atlas
IF DICE3D_HWATLAS <> 0 THEN _FREEIMAGE DICE3D_HWATLAS
SYSTEM

'$INCLUDE:'include/DICE3D/_ALL.BM'
