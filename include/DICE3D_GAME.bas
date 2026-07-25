$INCLUDEONCE
'' DICE3D_GAME.bas -- glue between the dungeon and the DICE3D module.
'  Loads the player + monster dice sets and rolls them inside a box overlaid on the
'  dungeon's CANVAS (which IS the screen -- SCREEN CANVAS). GameRoll routes here when
'  the active Dice Style is 3D; otherwise the font/pip dice are used. Included at the
'  bottom, after include/DICE3D/_ALL.BM (so the dice3d_* API exists).

' Load the player's and monster's 3D dice sets. Both default to assets/data/diceset.txt
' (the purple/green crystal set); a separate assets/data/diceset-monster.txt overrides
' the monster set if present. dice3d_ready gates 3D -- a missing/bad set falls back to
' the font dice so the game never breaks.
' Read the dice-set manifest (assets/data/dicesets.txt): each line "display name | file".
SUB LoadDiceManifest
    DIM i AS INTEGER
    DSET_COUNT = 0
    ReadDataFile "assets/data/dicesets.txt"
    FOR i = 1 TO DLINE_N
        IF DSET_COUNT < UBOUND(DSET_NAME) THEN
            DSET_COUNT = DSET_COUNT + 1
            DSET_NAME(DSET_COUNT) = DField$(DLINE(i), 1)
            DSET_FILE(DSET_COUNT) = DField$(DLINE(i), 2)
        END IF
    NEXT i
END SUB

' Load the player's and monster's chosen 3D dice sets (by manifest index). Falls back to
' the single legacy assets/data/diceset.txt if the manifest is empty. dice3d_ready gates
' 3D -- a missing/bad set means the game quietly uses the font dice instead.
SUB LoadDiceSets
    DIM ok AS INTEGER
    LoadDiceManifest
    dice3d_ready = FALSE
    IF DSET_COUNT <= 0 THEN
        ok = dice3d_set_load%(DSET3D(), "assets/data/diceset.txt")
        IF ok THEN dice3d_ready = -1: ok = dice3d_set_load%(MSET3D(), "assets/data/diceset.txt")
        EXIT SUB
    END IF
    IF opt_dice3d_set < 1 OR opt_dice3d_set > DSET_COUNT THEN opt_dice3d_set = 1
    IF opt_mon_dice3d_set < 1 OR opt_mon_dice3d_set > DSET_COUNT THEN opt_mon_dice3d_set = 1
    ok = dice3d_set_load%(DSET3D(), "assets/data/dicesets/" + _TRIM$(DSET_FILE(opt_dice3d_set)))
    IF ok THEN dice3d_ready = -1
    ok = dice3d_set_load%(MSET3D(), "assets/data/dicesets/" + _TRIM$(DSET_FILE(opt_mon_dice3d_set)))
END SUB

' Roll n dice of `sides` sides as animated 3D dice and return the raw sum (no bonus --
' GameRoll adds that, matching the font/pip paths). `what` is the caption. Picks the
' monster set when dice3d_use_mon is set (Push/PopMonsterDice), else the player set.
CONST DICE3D_SS = 2          ' (settings preview only) supersample the static preview image

' GL projection calibration for a 1056x816 CANVAS at view depth Z (from x11grab tests):
' 1 model unit ~= 103 screen px at Z=-5, so 1 box-pixel ~= 1/103 GPU units. HW_S is derived
' from DIE_SIZE so a die renders at exactly its physics footprint.
CONST DICE3D_HW_ZBASE = -5.0
CONST DICE3D_HW_PXPERUNIT = 103.0

FUNCTION Show3DRoll% (n AS INTEGER, sides AS INTEGER, what AS STRING)
    DIM cfg AS DICE3D_CONFIG, idx AS INTEGER, notation AS STRING, hdr AS STRING
    DIM AS INTEGER tw, th, tx, ty, hf, hbw, hbx
    DIM pxk AS SINGLE
    REDIM r(1 TO 1) AS INTEGER

    idx = dice3d_set_index%(sides): IF idx < 0 THEN idx = 0
    IF dice3d_use_mon THEN cfg = MSET3D(idx) ELSE cfg = DSET3D(idx)

    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF

    ' The tray (a software box on CANVAS) -- the 3D dice render on the GL layer over it.
    ' The tray is sized to FIT THE DICE (compact); the header/caption gets its own, wider
    ' box above it, so a long caption doesn't blow the tray up into a big empty box.
    cfg.DIE_SIZE = 24                              ' die radius in box/screen px (small, ~font-sized)
    tw = 96 + n * 58
    IF tw > SW * CW - 40 THEN tw = SW * CW - 40
    th = 82
    tx = (SW * CW - tw) \ 2
    ty = 14 * CH
    cfg.BOX_W = tw: cfg.BOX_H = th                 ' physics tray (box pixels == screen pixels)
    hbw = (LEN(hdr) + 4) * CW                      ' header box: caption width, its own
    IF hbw < tw THEN hbw = tw
    IF hbw > SW * CW - 20 THEN hbw = SW * CW - 20
    hbx = (SW * CW - hbw) \ 2

    ' Hardware (OpenGL) present: native-resolution, hardware-filtered = genuinely smooth,
    ' independent of the software-canvas fullscreen scaling.
    pxk = 1.0 / DICE3D_HW_PXPERUNIT
    DICE3D_HW = -1
    DICE3D_HWATLAS = 0
    DICE3D_HW_Z = DICE3D_HW_ZBASE
    DICE3D_HW_PXK = pxk
    DICE3D_HW_S = cfg.DIE_SIZE * pxk               ' render the die at its physics footprint
    DICE3D_HW_CX = 0                               ' tray centred horizontally on screen
    DICE3D_HW_CY = -((ty + th * 0.5) - SH * CH * 0.5) * pxk   ' shift up to the tray row
    DICE3D_UPRIGHT = -1                            ' show each die's result upright + readable

    ' Sound: a throw rattle now, then per-bounce BEEPS + a settle BOOP straight from the
    ' physics (tone fallback via DICE3D_SND_VOL) -- or real per-bounce clacks + settle thud
    ' if you drop assets/sfx/dice_edge.* / dice_settle.* files in.
    cfg.SOUND_ENABLED = opt_sfx
    cfg.SND_EDGE_H = SfxHandle("dice_edge")
    cfg.SND_SETTLE_H = SfxHandle("dice_settle")
    IF opt_sfx THEN DICE3D_SND_VOL = opt_sfxvol / 10 ELSE DICE3D_SND_VOL = 0
    Sfx "diceroll"

    ' Draw the framed header (caption-width) + a compact tray on CANVAS (crisp); GL dice over.
    _DEST CANVAS: _FONT CH
    LINE (hbx, 10 * CH)-(hbx + hbw, 13 * CH), BOXBG, BF
    LINE (hbx, 10 * CH)-(hbx + hbw, 13 * CH), REDU, B
    LINE (tx, ty)-(tx + tw, ty + th), BOXBG, BF
    LINE (tx, ty)-(tx + tw, ty + th), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered 11, hdr
    _DISPLAY

    notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    dice3d_roll notation, cfg, r()                 ' animates on the GL layer, returns settled
    IF SfxHandle("dice_settle") = 0 THEN Sfx "diceland"

    ' Hold the settled dice a readable beat -- must keep RE-rendering the GL dice each frame
    ' (the hardware layer is cleared every _DISPLAY), else they vanish. Any key skips it.
    _KEYCLEAR
    FOR hf = 1 TO 42
        _LIMIT 60
        dice3d_present_hw cfg
        IF INKEY$ <> "" THEN EXIT FOR
    NEXT hf
    _KEYCLEAR

    IF DICE3D_HWATLAS <> 0 THEN _FREEIMAGE DICE3D_HWATLAS: DICE3D_HWATLAS = 0
    DICE3D_HW = 0
    Show3DRoll = dice3d_total%
END FUNCTION


' -- SETTINGS preview: the SAME hardware (OpenGL) render as a roll, drawn live each frame --

' (Re)build the d20 mesh, a hardware atlas per side, and a posed die (showing 20 upright).
' PREV3D_P / PREV3D_M now hold HARDWARE atlas handles (not preview images).
SUB Build3DPreviews
    DIM pc AS DICE3D_CONFIG, a AS LONG, f AS INTEGER
    Free3DPreviews
    IF NOT dice3d_ready THEN EXIT SUB
    dice3d_build 20
    pc = DSET3D(dice3d_set_index%(20)): pc.DIE_SIZE = 96
    a = dice3d_make_atlas&(pc, pc.BODY_KOLOR, 0): PREV3D_P = _COPYIMAGE(a, 33): _FREEIMAGE a
    pc = MSET3D(dice3d_set_index%(20)): pc.DIE_SIZE = 96
    a = dice3d_make_atlas&(pc, pc.BODY_KOLOR, 0): PREV3D_M = _COPYIMAGE(a, 33): _FREEIMAGE a
    REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
    DICE3D_DICE(0).SIDES = 20: DICE3D_DICE(0).FADE = 1: DICE3D_DICE(0).VALUE = 20
    f = DICE3D_VAL2FACE(20): IF f >= 0 AND f < DICE3D_NF THEN DICE3D_DICE(0).Q = DICE3D_FACE_Q(f)
END SUB

SUB Free3DPreviews
    IF PREV3D_P <> 0 THEN _FREEIMAGE PREV3D_P: PREV3D_P = 0
    IF PREV3D_M <> 0 THEN _FREEIMAGE PREV3D_M: PREV3D_M = 0
END SUB

' Render the cached posed d20 via the hardware path at settings column gxc, using the
' side's hardware atlas + its set cfg (for the camera angle). Called each settings frame,
' so the preview looks exactly like the smooth roll. DICE3D_HW is left off (we call the
' hardware renderer directly, without the software-present branch).
SUB DrawDice3DPreviewAt (gxc AS INTEGER, lbl AS STRING, atlas AS LONG, setcfg AS DICE3D_CONFIG)
    DIM AS INTEGER gx, gy, scx, scy
    DIM cfg AS DICE3D_CONFIG, pxk AS SINGLE
    gx = gxc * CW: gy = 15 * CH
    _DEST CANVAS: _FONT CH
    COLOR GREY, BLACK: _PRINTSTRING (gx, gy - 3 * CH), lbl
    IF atlas = 0 THEN EXIT SUB
    IF UBOUND(DICE3D_DICE) < LBOUND(DICE3D_DICE) THEN EXIT SUB
    cfg = setcfg
    cfg.BOX_W = 150: cfg.BOX_H = 150: cfg.DIE_SIZE = 42
    scx = gx + 75: scy = gy + 60                    ' screen centre of this preview
    pxk = 1.0 / DICE3D_HW_PXPERUNIT
    DICE3D_HWATLAS = atlas
    DICE3D_HW_Z = DICE3D_HW_ZBASE: DICE3D_HW_PXK = pxk
    DICE3D_HW_S = cfg.DIE_SIZE * pxk
    DICE3D_HW_CX = (scx - SW * CW * 0.5) * pxk
    DICE3D_HW_CY = -(scy - SH * CH * 0.5) * pxk
    DICE3D_DICE(0).PX = cfg.BOX_W * 0.5: DICE3D_DICE(0).PY = cfg.BOX_H * 0.5: DICE3D_DICE(0).PZ = 0
    dice3d_render_die_hw DICE3D_DICE(0), cfg
END SUB
