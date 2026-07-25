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
CONST DICE3D_SS = 2          ' supersample factor: render the box 2x, smooth-downscale -> AA dice

FUNCTION Show3DRoll% (n AS INTEGER, sides AS INTEGER, what AS STRING)
    DIM cfg AS DICE3D_CONFIG, idx AS INTEGER, notation AS STRING, hdr AS STRING
    DIM AS INTEGER dbw, dbh, dbx, dby, dds, hf, smoothed
    REDIM r(1 TO 1) AS INTEGER

    ' The AA'd dice live on CANVAS; _SQUAREPIXELS (crisp) upscales it nearest-neighbour,
    ' which re-jaggies them (integer scaling ignores the smooth flag). Switch to a
    ' bilinear STRETCH just for the roll -- that genuinely smooths the upscale -- then
    ' ApplyDisplay restores the player's crisp mode, so the ANSI art stays crisp the rest
    ' of the time. (The board stretches slightly to fill during the roll; the dice are the
    ' focus, and they come out smooth.)
    smoothed = FALSE
    IF opt_fullscreen THEN _FULLSCREEN _STRETCH, _SMOOTH: smoothed = -1

    idx = dice3d_set_index%(sides): IF idx < 0 THEN idx = 0
    IF dice3d_use_mon THEN cfg = MSET3D(idx) ELSE cfg = DSET3D(idx)

    ' On-screen dice sized to roughly match the 2D font dice (~56px across).
    dds = 30                                        ' half-extent -> ~60px die

    ' Caption / roll header (sizes the box so a long caption never spills).
    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF

    ' Compact tray: just enough room for the dice to scatter, widened for more dice
    ' and to fit the caption. Small footprint, like the old font-dice box.
    dbw = 70 + n * 64
    IF dbw < (LEN(hdr) + 4) * CW THEN dbw = (LEN(hdr) + 4) * CW
    IF dbw > SW * CW - 40 THEN dbw = SW * CW - 40
    dbh = 116
    dbx = (SW * CW - dbw) \ 2
    dby = 14 * CH

    ' Render at SSx into the box buffer, then dice3d_present smooth-downscales to the
    ' on-screen rect (dbx,dby,dbw,dbh) -- crisp, anti-aliased dice.
    cfg.BOX_X = dbx: cfg.BOX_Y = dby
    cfg.BOX_W = dbw * DICE3D_SS: cfg.BOX_H = dbh * DICE3D_SS
    cfg.DIE_SIZE = dds * DICE3D_SS
    DICE3D_SSDIV = DICE3D_SS
    DICE3D_UPRIGHT = -1                             ' turn each die to show its result upright + readable

    ' Sound: a throw rattle now; per-bounce clacks + a settle thud come from optional
    ' files (assets/sfx/dice_edge.*, dice_settle.*) via the module's SND hooks. Without
    ' those files we still play a 'landed' click after the dice settle (see below).
    cfg.SOUND_ENABLED = opt_sfx
    cfg.SND_EDGE_H = SfxHandle("dice_edge")
    cfg.SND_SETTLE_H = SfxHandle("dice_settle")
    Sfx "diceroll"

    ' The "roll box": a framed header above the tray (the box the font dice used to show).
    _DEST CANVAS: _FONT CH
    LINE (dbx, 11 * CH)-(dbx + dbw, 14 * CH), BOXBG, BF
    LINE (dbx, 11 * CH)-(dbx + dbw, 14 * CH), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered 12, hdr
    _DISPLAY

    notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    dice3d_roll notation, cfg, r()                 ' animates in the box, returns when settled
    IF SfxHandle("dice_settle") = 0 THEN Sfx "diceland"   ' 'landed' click if no settle-sound file

    ' Hold the settled dice a readable beat so back-to-back rolls (to-hit -> damage ->
    ' the monster's swing) don't blur together. Any key skips it.
    _KEYCLEAR
    FOR hf = 1 TO 42
        _LIMIT 60
        IF INKEY$ <> "" THEN EXIT FOR
        _DISPLAY
    NEXT hf
    _KEYCLEAR

    DICE3D_SSDIV = 0                                ' leave the shared flag off for other callers
    IF smoothed THEN ApplyDisplay                  ' restore the player's crisp fullscreen
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
