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
' Load the dice-numeral fonts listed in assets/fonts/dicefonts.txt (name | file | size).
' Entry 1 is always a built-in "Default" (handle 0). Others _LOADFONT their file.
SUB LoadDiceFonts
    DIM i AS INTEGER, fn AS STRING, px AS INTEGER
    DICEFONT_N = 0
    ReadDataFile "assets/fonts/dicefonts.txt"
    FOR i = 1 TO DLINE_N
        IF DICEFONT_N < UBOUND(DICEFONT_NAME) THEN
            DICEFONT_N = DICEFONT_N + 1
            DICEFONT_NAME(DICEFONT_N) = DField$(DLINE(i), 1)
            fn = DField$(DLINE(i), 2): px = VAL(DField$(DLINE(i), 3))
            DICEFONT_PX(DICEFONT_N) = px
            DICEFONT_H(DICEFONT_N) = 0
            IF fn <> "-" AND px > 0 THEN
                IF _FILEEXISTS("assets/fonts/" + fn) THEN DICEFONT_H(DICEFONT_N) = _LOADFONT("assets/fonts/" + fn, px)
            END IF
        END IF
    NEXT i
    IF DICEFONT_N = 0 THEN
        DICEFONT_N = 1: DICEFONT_NAME(1) = "Default": DICEFONT_H(1) = 0: DICEFONT_PX(1) = 0
    END IF
    IF opt_dicefont < 1 OR opt_dicefont > DICEFONT_N THEN opt_dicefont = 1
END SUB

' Apply the selected numeral font (handle + size) to a config before its atlas is baked.
SUB SetDiceFont (cfg AS DICE3D_CONFIG)
    IF opt_dicefont >= 1 AND opt_dicefont <= DICEFONT_N THEN
        cfg.FONT_HANDLE = DICEFONT_H(opt_dicefont)
        IF DICEFONT_PX(opt_dicefont) > 0 THEN cfg.FONT_PX = DICEFONT_PX(opt_dicefont)
    END IF
END SUB

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

' droplow > 0 rolls N dice but keeps the top (N - droplow) -- e.g. Show3DRoll(4,6,0,1,..)
' is the classic 4d6-drop-lowest ability roll. The DICE3D module owns the mechanic: we
' just build the "4d6dl1" notation, and it animates all four, fades the lowest, and
' totals the kept three (dice3d_total%). droplow = 0 is an ordinary NdS roll.
FUNCTION Show3DRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, droplow AS INTEGER, what AS STRING)
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
    ' Roomy tray with its own wider caption header above; a royal-purple "dice box".
    DIM boxviolet AS _UNSIGNED LONG, boxedge AS _UNSIGNED LONG
    boxviolet = _RGB32(&H34, &H22, &H7A)           ' plush violet-blue royal purple
    boxedge = _RGB32(&H8A, &H6C, &HF2)             ' lighter violet border
    cfg.DIE_SIZE = 28                              ' die radius in box/screen px (small)
    ' A lively roll, not a frantic one and not a dead drop: 30 (module default) felt
    ' frantic, 7 barely tumbled ("just drops and bounces once"). ~15 spin + a real
    ' horizontal throw makes the dice skitter and wall-bounce like a genuine roll.
    cfg.SPIN_STRENGTH = 15                          ' tumble speed (deg/frame magnitude)
    cfg.THROW_STRENGTH = 13                         ' scatter velocity -- skitter across the tray
    cfg.RESTITUTION = 0.62                          ' a couple extra bounces before settling (0.55 default)
    tw = 150 + n * 84
    IF tw > SW * CW - 40 THEN tw = SW * CW - 40
    th = 132
    tx = (SW * CW - tw) \ 2
    ty = 12 * CH
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
    DICE3D_ATLAS_DIE = 96                           ' bake a hi-res atlas so the numerals stay sharp
    SetDiceFont cfg                                 ' apply the chosen dice numeral font
    Sfx "diceroll"

    ' Draw the framed royal-purple header (caption-width) + the roomy tray on CANVAS (crisp).
    _DEST CANVAS: _FONT CH
    LINE (hbx, 9 * CH)-(hbx + hbw, 12 * CH), boxviolet, BF
    LINE (hbx, 9 * CH)-(hbx + hbw, 12 * CH), boxedge, B
    LINE (tx, ty)-(tx + tw, ty + th), boxviolet, BF
    LINE (tx, ty)-(tx + tw, ty + th), boxedge, B
    COLOR YELLOWU, boxviolet: PrintCentered 10, hdr
    _DISPLAY

    notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    IF droplow > 0 THEN notation = notation + "dl" + _TRIM$(STR$(droplow))   ' e.g. 4d6dl1
    dice3d_roll notation, cfg, r()                 ' animates on the GL layer, returns settled
    IF SfxHandle("dice_settle") = 0 THEN Sfx "diceland"

    ' Show the roll as a sum under the tray (like the 2D dice: "3 + 3 = 6"), which
    ' persists. The modifier rides along as one more addend -- "3 + 3 + 2  =  8" for
    ' 2d6+2, "17 + 5  =  22" for 1d20+5 -- so the player sees their bonus applied.
    DIM res AS STRING, ri AS INTEGER, rrow AS INTEGER, dropstr AS STRING, kept AS INTEGER
    res = "": dropstr = "": kept = 0
    FOR ri = 1 TO dice3d_count%
        IF dice3d_dropped%(ri) THEN                  ' a 4d6-drop-lowest die that didn't count
            IF LEN(dropstr) > 0 THEN dropstr = dropstr + " "
            dropstr = dropstr + _TRIM$(STR$(dice3d_value%(ri)))
        ELSE
            IF LEN(res) > 0 THEN res = res + " + "
            res = res + _TRIM$(STR$(dice3d_value%(ri)))
            kept = kept + 1
        END IF
    NEXT
    IF bonus > 0 THEN res = res + " + " + _TRIM$(STR$(bonus))
    IF bonus < 0 THEN res = res + " - " + _TRIM$(STR$(-bonus))
    IF kept > 1 OR bonus <> 0 OR LEN(dropstr) > 0 THEN
        res = res + "  =  " + _TRIM$(STR$(dice3d_total% + bonus))
    ELSE
        res = "=  " + res + "  ="                    ' a lone die, no bonus: just frame the number
    END IF
    IF LEN(dropstr) > 0 THEN res = res + "   (drop " + dropstr + ")"
    rrow = (ty + th) \ CH
    _DEST CANVAS: _FONT CH
    LINE (tx, rrow * CH)-(tx + tw, (rrow + 2) * CH), boxviolet, BF
    LINE (tx, rrow * CH)-(tx + tw, (rrow + 2) * CH), boxedge, B
    COLOR WHITE, boxviolet: PrintCentered rrow, res

    ' Hold the settled dice a good long beat (re-render the GL dice each frame or they
    ' vanish -- the hardware layer clears every _DISPLAY). Any key skips ahead.
    _KEYCLEAR
    FOR hf = 1 TO 100
        _LIMIT 60
        dice3d_present_hw cfg
        IF INKEY$ <> "" THEN EXIT FOR
    NEXT hf
    _KEYCLEAR

    IF DICE3D_HWATLAS <> 0 THEN _FREEIMAGE DICE3D_HWATLAS: DICE3D_HWATLAS = 0
    DICE3D_HW = 0
    cursor_erase: cursor_draw                       ' wipe the dice box off the board so the combat
    DrawHUD: _DISPLAY                                ' panel / "you still face..." prompt shows clean next
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
    pc = DSET3D(dice3d_set_index%(20)): pc.DIE_SIZE = 96: SetDiceFont pc
    a = dice3d_make_atlas&(pc, pc.BODY_KOLOR, 0): PREV3D_P = _COPYIMAGE(a, 33): _FREEIMAGE a
    pc = MSET3D(dice3d_set_index%(20)): pc.DIE_SIZE = 96: SetDiceFont pc
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
