''
' D4LEAN-SHOT -- render a d4 at several D4_LEAN values, side by side, and save a PNG.
'
' Modelled on Rick's DICE3D-SHOT.BAS harness (~/git/qb64/qb64/GRAPHICS/3D/DICE3D/), which is
' the thing that makes this verifiable at all: it drives a real dice3d_roll and captures the
' SOFTWARE screen, so it works headless under xvfb where the hardware _MAPTRIANGLE layer does
' not appear in a _SAVEIMAGE.
'
' D4_LEAN decides which way the tetra's value-BASE tips off square-on:
'   negative -> toward the camera, a sliver of the bottom shows (the old hardcoded -4)
'   positive -> away, the bottom is hidden
'
' Build + run from the repo root:  qb64pe -w -x engine/DICE3D/D4LEAN-SHOT.BAS -o d4lean.run
'
OPTION _EXPLICIT
$IF FALSE = UNDEFINED AND TRUE = UNDEFINED THEN
    CONST FALSE = 0: CONST TRUE = NOT FALSE
$END IF
_TITLE "D4 lean"
RANDOMIZE 1234

'$INCLUDE:'_ALL.BI'

DIM SHARED SCR AS LONG
SCR = _NEWIMAGE(1100, 420, 32)
SCREEN SCR
CLS , _RGB32(16, 16, 22)
COLOR _RGB32(255, 255, 80), _RGBA32(0, 0, 0, 0)
_PRINTSTRING (330, 12), "D 4   R E A D   P O S E   --   value 3"
COLOR _RGB32(170, 170, 170), _RGBA32(0, 0, 0, 0)
_PRINTSTRING (120, 34), "negative leans the base TOWARD you (bottom visible)  --  positive leans it AWAY"

DIM leans(1 TO 5) AS SINGLE
leans(1) = -4: leans(2) = 0: leans(3) = 8: leans(4) = 14: leans(5) = 20

' The GAME sets this (DICE3D_GAME.bas), and it is what makes dice3d_showcase run at all --
' the routine D4_LEAN lives in. Without it a die settles to its PHYSICS rest and the lean has
' no effect whatsoever, which is exactly the false negative this harness first produced.
DICE3D_UPRIGHT = -1

DIM cfg AS DICE3D_CONFIG, i AS INTEGER
REDIM results(1 TO 1) AS INTEGER
FOR i = 1 TO 5
    dice3d_config_defaults cfg
    cfg.BOX_X = 20 + (i - 1) * 214: cfg.BOX_Y = 70
    cfg.BOX_W = 200: cfg.BOX_H = 260
    ' The box BACK is what clears each animation frame. With it off, every tumble frame
    ' paints over the last and the result is a smear rather than a die.
    cfg.BOX_SHOW_OUTLINE = FALSE
    cfg.BOX_SHOW_BACK = TRUE: cfg.BOX_BACK_KOLOR = _RGB32(16, 16, 22)
    cfg.DIE_SIZE = 62
    cfg.CAM_TILT = 85                        ' the angle the GAME renders a d4 at
    cfg.CAM_YAW = 2.4
    cfg.D4_LEAN = leans(i)
    ' let the roll SETTLE -- the read pose is the whole point, a tumble frame tells us nothing
    dice3d_roll "1d4", cfg, results()
    COLOR _RGB32(255, 255, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (cfg.BOX_X + 50, cfg.BOX_Y + cfg.BOX_H + 14), "LEAN " + _TRIM$(STR$(leans(i)))
    COLOR _RGB32(140, 200, 140), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (cfg.BOX_X + 50, cfg.BOX_Y + cfg.BOX_H + 30), "rolled " + _TRIM$(STR$(results(1)))
NEXT i
_DISPLAY
_SAVEIMAGE "d4lean.png", SCR
SYSTEM

'$INCLUDE:'_ALL.BM'
