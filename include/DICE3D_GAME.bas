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
SUB LoadDiceSets
    DIM ok AS INTEGER
    dice3d_ready = FALSE
    ok = dice3d_set_load%(DSET3D(), "assets/data/diceset.txt")
    IF ok THEN dice3d_ready = -1
    IF _FILEEXISTS("assets/data/diceset-monster.txt") THEN
        ok = dice3d_set_load%(MSET3D(), "assets/data/diceset-monster.txt")
    ELSEIF dice3d_ready THEN
        ok = dice3d_set_load%(MSET3D(), "assets/data/diceset.txt")
    END IF
END SUB

' Roll n dice of `sides` sides as animated 3D dice and return the raw sum (no bonus --
' GameRoll adds that, matching the font/pip paths). `what` is the caption. Picks the
' monster set when dice3d_use_mon is set (Push/PopMonsterDice), else the player set.
FUNCTION Show3DRoll% (n AS INTEGER, sides AS INTEGER, what AS STRING)
    DIM cfg AS DICE3D_CONFIG, idx AS INTEGER, notation AS STRING, hdr AS STRING
    DIM AS INTEGER bw, bh, bx, by, ds
    REDIM r(1 TO 1) AS INTEGER

    idx = dice3d_set_index%(sides): IF idx < 0 THEN idx = 0
    IF dice3d_use_mon THEN cfg = MSET3D(idx) ELSE cfg = DSET3D(idx)

    ' Size the box to the dungeon screen (override the file's standalone-test coords).
    ' Wider when more dice are thrown so they don't jam; the die size is clamped to fit.
    bw = 360 + (n - 1) * 130: IF bw > SW * CW - 40 THEN bw = SW * CW - 40
    bh = 360
    bx = (SW * CW - bw) \ 2
    by = 13 * CH
    ds = cfg.DIE_SIZE
    IF ds > 52 THEN ds = 52                        ' keep multi-dice rolls readable in-box
    cfg.BOX_X = bx: cfg.BOX_Y = by: cfg.BOX_W = bw: cfg.BOX_H = bh
    cfg.DIE_SIZE = ds

    ' Caption above the box (outside the box rect, so it survives the roll frames).
    _DEST CANVAS: _FONT CH
    LINE (0, 10 * CH)-(SW * CW, 12 * CH), BLACK, BF
    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF
    COLOR YELLOWU, BLACK: PrintCentered 11, hdr
    _DISPLAY

    notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    dice3d_roll notation, cfg, r()                 ' animates in the box, returns when settled

    Show3DRoll = dice3d_total%
END FUNCTION
