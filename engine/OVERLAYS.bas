' ============================================================================
'  engine/OVERLAYS.bas -- ART PLACED ON THE BOARD.
'
'  A row of `level | col | row | art | scale | lit` puts a picture on a cell.
'  `lit` obeys fog and line-of-sight, so a torch you have not walked past is not
'  visible through a wall.
'
'  There is NO board-animation machinery here. The art is drawn through Sprite&,
'  which animates GIFs everywhere, which is exactly why that lives in ARTPACK
'  and not in a call site. An animated overlay animates because ordinary sprites
'  do.
'
'  ENGINE: the format, the fog rule and the centre-anchoring are not facts about
'  DUNGEON!. The host names the file (its tree, its packs) and answers which
'  zone the player is in; everything else is here.
'
'  Anchored on the CELL'S CENTRE, so a sprite of any size sits where the author
'  pointed rather than hanging off to one side.
' ============================================================================

SUB LoadBoardOverlays (path AS STRING)
    DIM i AS INTEGER, nm AS STRING

    OVL_N = 0
    '--- the HOST names the file. The engine owns the FORMAT (level | col | row
    '    | art | scale | lit) and nothing about where a given game keeps it. ---
    ReadDataFile path
    IF DLINE_N = 0 THEN EXIT SUB

    FOR i = 1 TO DLINE_N
        nm = _TRIM$(DField$(DLINE(i), 4))
        IF LEN(nm) = 0 THEN _CONTINUE
        IF OVL_N >= OVL_MAX THEN EXIT FOR
        OVL_N = OVL_N + 1
        OVL_LVL(OVL_N) = VAL(DField$(DLINE(i), 1))
        OVL_COL(OVL_N) = VAL(DField$(DLINE(i), 2))
        OVL_ROW(OVL_N) = VAL(DField$(DLINE(i), 3))
        OVL_ART(OVL_N) = nm
        OVL_SCALE(OVL_N) = VAL(DField$(DLINE(i), 5))
        IF OVL_SCALE(OVL_N) <= 0 THEN OVL_SCALE(OVL_N) = 1
        OVL_LIT(OVL_N) = (VAL(DField$(DLINE(i), 6)) <> 0)
    NEXT i
END SUB


SUB DrawBoardOverlays
    DIM i AS INTEGER, h AS LONG, w AS INTEGER, ht AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, lv AS INTEGER, pth AS STRING

    IF OVL_N < 1 THEN EXIT SUB
    _DEST CANVAS
    lv = Game_MapZone%(c.x \ CW, c.y \ CH)   ' which zone the player is in -- the host's answer

    FOR i = 1 TO OVL_N
        IF OVL_LVL(i) <> 0 THEN
            IF OVL_LVL(i) <> lv THEN _CONTINUE
        END IF

        ' `lit` overlays obey the same fog and line-of-sight rules as anything
        ' else on the board -- a torch you have not walked past should not be
        ' visible through a wall.
        IF OVL_LIT(i) THEN
            IF VIS(OVL_COL(i), OVL_ROW(i)) = 0 THEN _CONTINUE
            IF FovOn% THEN
                IF LOS_SEEN(OVL_COL(i), OVL_ROW(i)) = 0 THEN _CONTINUE
            END IF
        END IF

        pth = Game_CutArtPath$(_TRIM$(OVL_ART(i)))
        IF LEN(pth) = 0 THEN _CONTINUE
        h = Sprite&(pth)                   ' a .gif animates; anything else is a still
        IF h >= -1 THEN _CONTINUE

        w = _WIDTH(h) * OVL_SCALE(i)
        ht = _HEIGHT(h) * OVL_SCALE(i)
        IF w < 1 _ORELSE ht < 1 THEN _CONTINUE

        ' anchored on the CELL's centre, so a sprite of any size sits where the
        ' author pointed rather than hanging off to one side
        x = OVL_COL(i) * CW + CW \ 2 - w \ 2
        y = OVL_ROW(i) * CH + CH \ 2 - ht \ 2

        _PUTIMAGE (x, y)-(x + w - 1, y + ht - 1), h, CANVAS
    NEXT i
END SUB


