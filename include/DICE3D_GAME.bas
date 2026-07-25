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

    ' The AA'd dice live on CANVAS, which is nearest-scaled to fullscreen when Pixel
    ' Smoothing is off -- re-jaggying them. Force bilinear fullscreen just for the roll,
    ' then restore, so the tumbling dice are smooth without softening the ANSI art the
    ' rest of the time.
    smoothed = FALSE
    IF opt_fullscreen THEN
        IF NOT opt_smooth THEN _FULLSCREEN _SQUAREPIXELS, _SMOOTH: smoothed = -1
    END IF

    idx = dice3d_set_index%(sides): IF idx < 0 THEN idx = 0
    IF dice3d_use_mon THEN cfg = MSET3D(idx) ELSE cfg = DSET3D(idx)

    ' On-SCREEN dice tray: wider when more dice are thrown so they don't jam.
    dbw = 320 + (n - 1) * 100: IF dbw > SW * CW - 40 THEN dbw = SW * CW - 40
    dbh = 300
    dbx = (SW * CW - dbw) \ 2
    dby = 14 * CH
    dds = cfg.DIE_SIZE: IF dds > 52 THEN dds = 52   ' on-screen half-extent, kept readable

    ' Render at SSx into the box buffer, then dice3d_present smooth-downscales to the
    ' on-screen rect (dbx,dby,dbw,dbh) -- crisp, anti-aliased dice.
    cfg.BOX_X = dbx: cfg.BOX_Y = dby
    cfg.BOX_W = dbw * DICE3D_SS: cfg.BOX_H = dbh * DICE3D_SS
    cfg.DIE_SIZE = dds * DICE3D_SS
    DICE3D_SSDIV = DICE3D_SS

    ' The "roll box": a framed header above the tray (the box the font dice used to show).
    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF
    _DEST CANVAS: _FONT CH
    LINE (dbx, 10 * CH)-(dbx + dbw, 13 * CH), BOXBG, BF
    LINE (dbx, 10 * CH)-(dbx + dbw, 13 * CH), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered 11, hdr
    _DISPLAY

    notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    dice3d_roll notation, cfg, r()                 ' animates in the box, returns when settled

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
