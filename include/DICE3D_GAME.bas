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
    DIM AS INTEGER tw, th, tx, ty, hf
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
    cfg.DIE_SIZE = 40                              ' die radius in box/screen px (~80px die)
    tw = 150 + n * 90
    IF tw < (LEN(hdr) + 4) * CW THEN tw = (LEN(hdr) + 4) * CW
    IF tw > SW * CW - 40 THEN tw = SW * CW - 40
    th = 150
    tx = (SW * CW - tw) \ 2
    ty = 13 * CH
    cfg.BOX_W = tw: cfg.BOX_H = th                 ' physics tray (box pixels == screen pixels)

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

    ' Sound: throw rattle now; per-bounce clacks + settle from optional assets/sfx files.
    cfg.SOUND_ENABLED = opt_sfx
    cfg.SND_EDGE_H = SfxHandle("dice_edge")
    cfg.SND_SETTLE_H = SfxHandle("dice_settle")
    Sfx "diceroll"

    ' Draw the framed header + tray on CANVAS (software, crisp); the GL dice sit over it.
    _DEST CANVAS: _FONT CH
    LINE (tx, 10 * CH)-(tx + tw, 13 * CH), BOXBG, BF
    LINE (tx, 10 * CH)-(tx + tw, 13 * CH), REDU, B
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


' -- SETTINGS preview: a static, readable d20 rendered from a set, cached as an image --

' Render a d20 from `cfg` into a fresh 160x168 image (showing its '20' face upright).
' The caller frees the returned handle. Clobbers the shared mesh/dice -- fine outside a roll.
FUNCTION Make3DPreview& (cfg AS DICE3D_CONFIG)
    DIM img AS LONG, atlas AS LONG, f AS INTEGER, od AS LONG
    DIM AS INTEGER pw, ph, sw, sh
    DIM pc AS DICE3D_CONFIG
    pw = 160: ph = 168
    od = _DEST
    pc = cfg
    sw = pw * DICE3D_SS: sh = ph * DICE3D_SS
    pc.BOX_W = sw: pc.BOX_H = sh: pc.DIE_SIZE = 52 * DICE3D_SS
    img = _NEWIMAGE(pw, ph, 32)
    DICE3D_BOXBUF = _NEWIMAGE(sw, sh, 32)
    dice3d_build 20
    atlas = dice3d_make_atlas&(pc, pc.BODY_KOLOR, 0)
    REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
    DICE3D_DICE(0).SIDES = 20: DICE3D_DICE(0).ATLAS = atlas: DICE3D_DICE(0).FADE = 1
    DICE3D_DICE(0).PX = sw / 2: DICE3D_DICE(0).PY = sh / 2: DICE3D_DICE(0).PZ = 0
    DICE3D_DICE(0).VALUE = 20
    f = DICE3D_VAL2FACE(20): IF f >= 0 AND f < DICE3D_NF THEN DICE3D_DICE(0).Q = DICE3D_FACE_Q(f)
    _DEST DICE3D_BOXBUF: CLS , BLACK
    dice3d_render_die DICE3D_DICE(0), pc
    _DEST img: CLS , BLACK
    _MAPTRIANGLE (0, 0)-(0, sh - 1)-(sw - 1, sh - 1), DICE3D_BOXBUF TO(0, 0)-(0, ph - 1)-(pw - 1, ph - 1), img, _SMOOTH
    _MAPTRIANGLE (0, 0)-(sw - 1, sh - 1)-(sw - 1, 0), DICE3D_BOXBUF TO(0, 0)-(pw - 1, ph - 1)-(pw - 1, 0), img, _SMOOTH
    _DEST od
    _FREEIMAGE atlas: _FREEIMAGE DICE3D_BOXBUF
    Make3DPreview& = img
END FUNCTION

' (Re)build the cached player + monster preview images from the loaded sets.
SUB Build3DPreviews
    Free3DPreviews
    IF NOT dice3d_ready THEN EXIT SUB
    PREV3D_P = Make3DPreview&(DSET3D(dice3d_set_index%(20)))
    PREV3D_M = Make3DPreview&(MSET3D(dice3d_set_index%(20)))
END SUB

SUB Free3DPreviews
    IF PREV3D_P <> 0 THEN _FREEIMAGE PREV3D_P: PREV3D_P = 0
    IF PREV3D_M <> 0 THEN _FREEIMAGE PREV3D_M: PREV3D_M = 0
END SUB

' Blit a cached 3D preview at settings column gxc (mirrors DrawDicePreview's placement).
SUB DrawDice3DPreviewAt (gxc AS INTEGER, lbl AS STRING, img AS LONG)
    DIM AS INTEGER gx, gy
    gx = gxc * CW: gy = 15 * CH
    _DEST CANVAS: _FONT CH
    COLOR GREY, BLACK: _PRINTSTRING (gx, gy - 3 * CH), lbl
    IF img <> 0 THEN _PUTIMAGE (gx, gy), img, CANVAS
END SUB
