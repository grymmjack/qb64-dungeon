' ============================================================================
'  DATALINT.bas -- `dungeon.run datalint`: validate the loaded CONTENT tables.
'
'  Everything about this game is data (assets/data/<pack>/*.txt), and a data-pack IS a
'  whole game -- so a content mistake is as real a bug as a code one, and far quieter.
'  It never crashes; the level just plays wrong. This checks the tables AFTER they load,
'  so it validates the ACTIVE data pack, not the files on disk.
'
'  Only OBJECTIVE errors are reported -- things that make data unreachable or malformed.
'  Balance ("is a Fire Ball scroll too strong for level 2?") is a design call and is
'  deliberately not linted.
'
'  The check that motivated this: items.txt used to OVERRIDE a treasure slot, and a room
'  rolls 1 of its level's 3 slots uniformly -- so a level whose 3 slots were all items could
'  NEVER yield a gold treasure card, and its treasures.txt rows were dead data. That had
'  silently happened to levels 5, 6 and 8. Items now live in a separate per-level POOL with
'  its own drop chance (ITEM_PCT_<n>), which removes that failure mode by construction; the
'  checks here cover the new ones -- a chance with no pool, a pool with no chance, a
'  zero-weight entry that can never be drawn, and a 100% chance that starves gold.
' ============================================================================

' ============================================================================
'  `dungeon.run roomlint` -- is every detected room actually PLAYABLE?
'
'  THE PROBLEM IT FOUND. DetectRooms decides a cell belongs to a room by sampling ONE pixel,
'  the cell's centre. Movement (InRoomNow / CanMove) demands the WHOLE cell be the floor colour.
'  Those two disagree on any cell the art draws with a HALF-BLOCK glyph -- and the board is full
'  of them: 432 upper-halves (0xDF), 410 lower-halves (0xDC), 91 left (0xDD), 42 right (0xDE).
'  A lower/right half paints the half the centre pixel lands in, so the flood claims it while
'  movement refuses it. That produced two failures that looked unrelated in play:
'
'    * 20 of 93 rooms seated their monster/grave marker on a cell nothing can stand on (or in a
'      DOORWAY), so those rooms never fired an encounter and never grew a headstone.
'    * the 11 LEVEL PLAQUES ("4th", "5th", ...) -- blocks of level colour with letters printed
'      on them -- flood-filled into ROOMS() at up to 4 cells, cleared the MIN_ROOM size gate,
'      and were handed a monster and a hoard apiece. The Level Key could land on one, which
'      would have made the run quietly unwinnable.
'
'  BOTH ARE FIXED (PlaceRoomMarkers + RoomIsDecor% in game/SECTOR.bas), so a clean board now
'  reports only the 11 plaques as DECORATION and nothing else. This stays as the regression
'  check: the board art is data, and an edit can reintroduce either failure with no other
'  symptom. The decorative half-blocks themselves are NORMAL -- they are the art's room lips,
'  never meant to be walked on.
'
'  Writes roomlint.png as well: a table of room numbers cannot show you that the phantom strips
'  all run along the TOP edge of rooms (the 0xDF lip), or which markers sit in doorways. The
'  board IS the data here, so the overlay is the primary output and the table is its index.
' ============================================================================
SUB RoomLint
    DIM r AS INTEGER, cx AS INTEGER, cy AS INTEGER, oldsrc AS LONG, k AS INTEGER
    DIM tot_fl AS LONG, tot_dr AS LONG, tot_mx AS LONG, col AS _UNSIGNED LONG
    DIM badmark AS INTEGER, ondoor AS INTEGER, nisland AS INTEGER, nomon AS INTEGER, nsmall AS INTEGER
    ' Per-cell verdict (CRK_*), computed ONCE. CellRoomKind% reads all 128 pixels of a cell, so
    ' a second sweep for the overlay would double an already slow pass over ~6700 cells.
    DIM verdict(0 TO 131, 0 TO 60) AS INTEGER
    DIM rfloor(1 TO 400) AS INTEGER, rdoor(1 TO 400) AS INTEGER, rmix(1 TO 400) AS INTEGER
    DIM rbad(1 TO 400) AS INTEGER, risle(1 TO 400) AS INTEGER
    DIM why AS STRING, note AS STRING
    _DEST _CONSOLE
    PRINT PipeCol$("|15roomlint|07 -- detected rooms vs cells the player can actually stand on")
    PRINT
    oldsrc = _SOURCE: _SOURCE FULL_BOARD
    '--- tally per room from the cached classification --------------------------
    ' ROOMKIND was filled by PlaceRoomMarkers during the board build, so this reports exactly
    ' what marker placement and the size gate acted on -- no second opinion to drift from.
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            verdict(cx, cy) = CRK_NONE
            r = ROOMAT(cx, cy)
            IF r >= 1 AND r <= ROOM_N THEN
                k = ROOMKIND(cx, cy)
                verdict(cx, cy) = k
                SELECT CASE k
                    CASE CRK_FLOOR: rfloor(r) = rfloor(r) + 1
                    CASE CRK_DOOR: rdoor(r) = rdoor(r) + 1
                    CASE ELSE: rmix(r) = rmix(r) + 1
                END SELECT
            END IF
        NEXT cx
    NEXT cy
    '--- ISLAND test: can the player even get in? ---------------------------
    ' A block with no walkable cell touching it from OUTSIDE is decorative, not a room -- the
    ' level-number plaques ("4th", "5th"...) are exactly this: a few cells of level colour with
    ' text on them, floating in black. They still flood-fill into ROOMS() and still get handed a
    ' monster and a hoard, which is why they show up here as unreachable.
    FOR r = 1 TO ROOM_N: risle(r) = -1: NEXT r
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            r = ROOMAT(cx, cy)
            IF r >= 1 AND r <= ROOM_N THEN
                IF risle(r) THEN
                    IF RoomTouchesOutside%(cx, cy, r) THEN risle(r) = 0
                END IF
            END IF
        NEXT cx
    NEXT cy
    PRINT PipeCol$("  |08room lvl  cells floor door mixed  marker cell  verdict")
    FOR r = 1 TO ROOM_N
        tot_fl = tot_fl + rfloor(r): tot_dr = tot_dr + rdoor(r): tot_mx = tot_mx + rmix(r)
        k = ROOMKIND(ROOMS(r).cx, ROOMS(r).cy)
        why = ""
        IF RoomIsDecor%(r) THEN
            ' No plain floor anywhere in the block -- decoration, not a room. RandomizeRooms
            ' skips these now, so they hold no monster and no hoard.
            IF risle(r) THEN
                why = "|13DECORATION|07 -- no floor + no way in (a level plaque)"
            ELSE
                why = "|13DECORATION|07 -- no plain floor anywhere (a level plaque)"
            END IF
            nisland = nisland + 1: rbad(r) = -1
        ELSEIF k = CRK_MIXED OR k = CRK_NONE THEN
            why = "|12MARKER UNREACHABLE|07 -- sits where nothing can stand": badmark = badmark + 1: rbad(r) = -1
        ELSEIF k = CRK_DOOR THEN
            why = "|14marker ON A DOORWAY|07 -- should sit inside the room": ondoor = ondoor + 1: rbad(r) = -2
        END IF
        IF LEN(why) > 0 THEN
            note = _TRIM$(STR$(ROOMS(r).cx)) + "," + _TRIM$(STR$(ROOMS(r).cy))
            PRINT PipeCol$("  " + PadR$(_TRIM$(STR$(r)), 5) + PadR$(_TRIM$(STR$(ROOMS(r).sec)), 5) + PadR$(_TRIM$(STR$(ROOMS(r).cells)), 6) + PadR$(_TRIM$(STR$(rfloor(r))), 6) + PadR$(_TRIM$(STR$(rdoor(r))), 5) + PadR$(_TRIM$(STR$(rmix(r))), 7) + PadR$(note, 13) + why)
        END IF
        IF LEN(_TRIM$(ROOMS(r).monster)) = 0 THEN
            nomon = nomon + 1
            PRINT PipeCol$("  " + PadR$(_TRIM$(STR$(r)), 5) + PadR$(_TRIM$(STR$(ROOMS(r).sec)), 5) + PadR$(_TRIM$(STR$(ROOMS(r).cells)), 6) + PadR$(_TRIM$(STR$(rfloor(r))), 6) + PadR$(_TRIM$(STR$(rdoor(r))), 5) + PadR$(_TRIM$(STR$(rmix(r))), 7) + PadR$(_TRIM$(STR$(ROOMS(r).cx)) + "," + _TRIM$(STR$(ROOMS(r).cy)), 13) + "|12NO MONSTER|07 -- a room with nothing in it")
        END IF
        IF rfloor(r) < 4 THEN nsmall = nsmall + 1      ' would the old size gate have skipped it?
    NEXT r
    OrphanBlockScan verdict()
    RoomLintOverlay verdict(), rfloor(), rmix(), rbad(), risle()
    _SOURCE oldsrc
    _DEST _CONSOLE          ' the overlay draws to CANVAS -- without this the summary below
    '                         is PRINTed onto the board image and never reaches the terminal
    PRINT
    PRINT PipeCol$("  rooms detected: |11" + _TRIM$(STR$(ROOM_N)) + "|07   (only PROBLEM rooms are listed above)")
    PRINT PipeCol$("  cells: |10" + _TRIM$(STR$(tot_fl)) + " plain floor|07 / |11" + _TRIM$(STR$(tot_dr)) + " doorway|07 / |08" + _TRIM$(STR$(tot_mx)) + " decorative half-block (not walkable, by design)|07")
    IF nomon = 0 THEN
        PRINT PipeCol$("  |10every room holds a monster|07 (DECORATION blocks are not rooms and are not counted)")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(nomon)) + " room(s) hold NO monster|07 -- listed above; a room with nothing in it is a dead end")
    END IF
    PRINT PipeCol$("  rooms with fewer than 4 plain-floor cells: |11" + _TRIM$(STR$(nsmall)) + "|07 (the old MIN_ROOM size gate would have emptied these)")
    IF nisland > 0 THEN
        PRINT PipeCol$("  |13" + _TRIM$(STR$(nisland)) + " DECORATION block(s)|07 -- level colour with letters on it, no plain floor: not rooms")
        PRINT PipeCol$("  |08  -> RandomizeRooms skips these, so they hold no monster and no hoard")
    END IF
    IF badmark > 0 THEN
        PRINT PipeCol$("  |12" + _TRIM$(STR$(badmark)) + " room(s) seat their marker on a cell the player CANNOT stand on|07")
        PRINT PipeCol$("  |08  -> that room never fires an encounter and never shows a headstone")
    END IF
    IF ondoor > 0 THEN
        PRINT PipeCol$("  |14" + _TRIM$(STR$(ondoor)) + " room(s) seat their marker on a DOORWAY|07 -- walkable, but the grave sits in the door")
    END IF
    IF badmark = 0 AND ondoor = 0 AND nisland = 0 THEN PRINT PipeCol$("  |10every room is enterable and every marker sits on plain floor|07")
    PRINT
    PRINT PipeCol$("  wrote |10roomlint.png|07 -- the board with every problem cell and room marked")
    SYSTEM 0
END SUB


' ============================================================================
'  `dungeon.run sectorauto` -- can the SECTOR RECTANGLES be derived from the art alone?
'
'  THE IDEA (grymmjack's): each dungeon level paints its rooms in its own colour, and the
'  levels do not interleave -- so the bounding box of every cell of level N's colour IS level
'  N's rectangle. If that holds, sectors.txt's hand-typed rects and the painted sector mask are
'  both redundant: two files that have to agree with the art, and whose disagreement is exactly
'  what strands rooms (see OrphanBlockScan).
'
'  This measures it instead of assuming it. A cell counts only if it is UNIFORMLY one level's
'  colour -- half-blocks and text glyphs are ambiguous and are skipped, which is the same rule
'  CellRoomKind% uses. It reports every level's box, the cell count behind it, and every
'  overlapping pair, twice: over the whole image, and with the decorative regions excluded (the
'  DUNGEON logo and the legend swatches both paint in level colours, so they wreck a bounding
'  box while being nothing to do with the map -- which is the case for a decoration layer).
'
'  Sampled from FULL_BOARD via the game's own ANSI renderer, deliberately: a hand-rolled ANSI
'  decoder gets the sticky-SGR case wrong (see MaskNormalize$) and silently mis-reads bright
'  cyan for cyan -- i.e. level 7 for level 6 -- which is exactly the answer this must not fake.
' ============================================================================
SUB SectorAutoDerive
    DIM cx AS INTEGER, cy AS INTEGER, s AS INTEGER, oldsrc AS LONG
    ' The derived boxes from the LAST pass are kept, so the overlay can draw the same rects the
    ' final table printed rather than recomputing them (and risking a different answer).
    DIM dx1(1 TO 9) AS INTEGER, dy1(1 TO 9) AS INTEGER, dx2(1 TO 9) AS INTEGER, dy2(1 TO 9) AS INTEGER
    DIM dcnt(1 TO 9) AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15sectorauto|07 -- deriving each level's rectangle from the board art alone")
    oldsrc = _SOURCE: _SOURCE FULL_BOARD
    SectorBoxReport "over the WHOLE image", 0, 0, SW - 1, SH - 1, dx1(), dy1(), dx2(), dy2(), dcnt()
    ' The logo lives right of the play area and the legend on the bottom rows; both paint in
    ' level colours. Excluding them models what a decoration LAYER would remove.
    SectorBoxReport "excluding the logo (col 116+) and legend (row 48+)", 0, 0, 115, 47, dx1(), dy1(), dx2(), dy2(), dcnt()
    ' The board's top FRAME is drawn in level-3 red, which stretches level 3's box across the
    ' whole width. One more row excluded is the difference between "nearly" and "cleanly".
    SectorBoxReport "...and the top frame row (row 0) -- i.e. MAP ONLY", 0, 1, 115, 47, dx1(), dy1(), dx2(), dy2(), dcnt()
    SectorGapReport
    SectorGapOverlay dx1(), dy1(), dx2(), dy2(), dcnt()
    _SOURCE oldsrc
    _DEST _CONSOLE
    PRINT
    PRINT PipeCol$("  |08A level whose box overlaps another cannot be expressed as a rectangle: either the")
    PRINT PipeCol$("  |08art interleaves them, or something outside the map is painted in its colour.")
    SYSTEM 0
END SUB


' How many cells can the player STAND on that no rect and no mask cell claims? Those resolve to
' sector 0, and a corridor with no level is a real hole: the HUD reads "level 0", music does not
' switch, and a wandering monster there has no depth to roll from. Reported per row-band so a
' gap can be found on the board rather than just counted.
SUB SectorGapReport
    DIM cx AS INTEGER, cy AS INTEGER, gaps AS LONG, walk AS LONG, k AS INTEGER, reach AS LONG
    DIM minx AS INTEGER, maxx AS INTEGER, miny AS INTEGER, maxy AS INTEGER
    minx = 999: miny = 999: maxx = -1: maxy = -1
    ReachFromStart GAPREACH()
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            k = CellKind%(cx, cy)
            IF k >= 1 THEN
                walk = walk + 1
                IF SECTOR.get_by_xy(cx * CW, cy * CH) < 1 THEN
                    gaps = gaps + 1
                    IF GAPREACH(cx, cy) THEN
                        ' Only a cell the player can actually WALK to is a real hole. The rest
                        ' are the logo's yellow fill, which reads as "path" but is sealed off.
                        reach = reach + 1
                        IF cx < minx THEN minx = cx
                        IF cx > maxx THEN maxx = cx
                        IF cy < miny THEN miny = cy
                        IF cy > maxy THEN maxy = cy
                    END IF
                END IF
            END IF
        NEXT cx
    NEXT cy
    _DEST _CONSOLE
    PRINT
    PRINT PipeCol$("  |11walkable cells with NO level|07 (neither the mask nor a sectors.txt rect claims them)")
    IF gaps = 0 THEN
        PRINT PipeCol$("  |10none|07 -- every walkable cell resolves to a level")
    ELSEIF reach = 0 THEN
        PRINT PipeCol$("  |10none the player can reach|07 (" + _TRIM$(STR$(gaps)) + " unclaimed cells exist, but all are sealed off -- logo/legend art)")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(reach)) + " REACHABLE|07 of " + _TRIM$(STR$(gaps)) + " unclaimed (" + _TRIM$(STR$(walk)) + " walkable total), spanning cols " + _TRIM$(STR$(minx)) + "-" + _TRIM$(STR$(maxx)) + ", rows " + _TRIM$(STR$(miny)) + "-" + _TRIM$(STR$(maxy)))
        PRINT PipeCol$("  |08  the other " + _TRIM$(STR$(gaps - reach)) + " are sealed off (the logo's yellow fill reads as `path` but nothing can walk to it)")
        PRINT PipeCol$("  |08  a reachable corridor with no level: HUD reads 0, music will not switch, a wanderer has no depth")
    END IF
END SUB


' Flood the walkable board from START, 8-way (the game moves diagonally). Answers "could the
' player ever stand here?", which is what separates a real gap in the sector cover from a
' patch of decorative art that merely happens to be painted a walkable colour.
SUB ReachFromStart (seen() AS INTEGER)
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER, cx AS INTEGER, cy AS INTEGER
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1: seen(cx, cy) = 0: NEXT cx
    NEXT cy
    IF CellKind%(START_CX, START_CY) < 1 THEN EXIT SUB
    head = 0: tail = 0
    QX(0) = START_CX: QY(0) = START_CY: seen(START_CX, START_CY) = -1: tail = 1
    DO WHILE head < tail
        x = QX(head): y = QY(head): head = head + 1
        FOR cy = -1 TO 1
            FOR cx = -1 TO 1
                IF cx <> 0 OR cy <> 0 THEN ReachVisit x + cx, y + cy, seen(), tail
            NEXT cx
        NEXT cy
    LOOP
END SUB

SUB ReachVisit (x AS INTEGER, y AS INTEGER, seen() AS INTEGER, tail AS INTEGER)
    IF x < 0 OR y < 0 OR x > SW - 1 OR y > SH - 1 THEN EXIT SUB
    IF seen(x, y) THEN EXIT SUB
    IF CellKind%(x, y) < 1 THEN EXIT SUB
    seen(x, y) = -1: QX(tail) = x: QY(tail) = y: tail = tail + 1
END SUB

' One pass: bounding box + cell count per level within a window, then the overlap verdict.
SUB SectorBoxReport (title AS STRING, wx1 AS INTEGER, wy1 AS INTEGER, wx2 AS INTEGER, wy2 AS INTEGER, x1() AS INTEGER, y1() AS INTEGER, x2() AS INTEGER, y2() AS INTEGER, cnt() AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER, s AS INTEGER, a AS INTEGER, b AS INTEGER, nov AS INTEGER
    FOR s = 1 TO 9: x1(s) = 999: y1(s) = 999: x2(s) = -1: y2(s) = -1: cnt(s) = 0: NEXT s
    FOR cy = wy1 TO wy2
        FOR cx = wx1 TO wx2
            s = CellSolidSector%(cx, cy)
            IF s >= 1 THEN
                IF cx < x1(s) THEN x1(s) = cx
                IF cy < y1(s) THEN y1(s) = cy
                IF cx > x2(s) THEN x2(s) = cx
                IF cy > y2(s) THEN y2(s) = cy
                cnt(s) = cnt(s) + 1
            END IF
        NEXT cx
    NEXT cy
    _DEST _CONSOLE
    PRINT
    PRINT PipeCol$("  |11" + title + "|07")
    PRINT PipeCol$("  |08lvl  derived rect (c1,r1,c2,r2)   cells   sectors.txt says")
    FOR s = 1 TO 9
        IF cnt(s) = 0 THEN
            PRINT PipeCol$("  " + PadR$(_TRIM$(STR$(s)), 5) + "|12(no cells of this colour found)|07")
        ELSE
            PRINT PipeCol$("  " + PadR$(_TRIM$(STR$(s)), 5) + PadR$(_TRIM$(STR$(x1(s))) + "," + _TRIM$(STR$(y1(s))) + "," + _TRIM$(STR$(x2(s))) + "," + _TRIM$(STR$(y2(s))), 28) + PadR$(_TRIM$(STR$(cnt(s))), 8) + _TRIM$(STR$(SECTORS(s).start_x)) + "," + _TRIM$(STR$(SECTORS(s).start_y)) + "," + _TRIM$(STR$(SECTORS(s).end_x)) + "," + _TRIM$(STR$(SECTORS(s).end_y)))
        END IF
    NEXT s
    FOR a = 1 TO 8
        FOR b = a + 1 TO 9
            IF cnt(a) > 0 AND cnt(b) > 0 THEN
                IF x1(a) <= x2(b) AND x1(b) <= x2(a) THEN
                    IF y1(a) <= y2(b) AND y1(b) <= y2(a) THEN
                        nov = nov + 1
                        PRINT PipeCol$("  |12OVERLAP|07 level " + _TRIM$(STR$(a)) + " and level " + _TRIM$(STR$(b)))
                    END IF
                END IF
            END IF
        NEXT b
    NEXT a
    IF nov = 0 THEN
        PRINT PipeCol$("  |10NO OVERLAPS|07 -- every level is a clean rectangle; the art alone can define the sectors")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(nov)) + " overlapping pair(s)|07 -- rectangles alone cannot express this layout as-is")
    END IF
END SUB

' Paint the level map and save sectorauto.png: which level every WALKABLE cell resolves to, and
' -- the point of the picture -- every cell that resolves to NONE.
'
' A count ("96 unclaimed cells") tells you there is a hole; it cannot tell you the holes are a
' one-cell seam running down column 41 between levels 2 and 1, which is what you actually need
' to know to fix the mask. Walkable cells are tinted with their level's own colour, so the
' sector layout reads at a glance and the unclaimed cells stand out as flat WHITE against it.
' The derived rectangles are outlined in each level's colour on top.
SUB SectorGapOverlay (dx1() AS INTEGER, dy1() AS INTEGER, dx2() AS INTEGER, dy2() AS INTEGER, dcnt() AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER, s AS INTEGER, px AS INTEGER, py AS INTEGER, k AS INTEGER
    DIM gaps AS LONG, walk AS LONG, col AS _UNSIGNED LONG
    ReachFromStart GAPREACH()
    _DEST CANVAS
    _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(0, 0, 0, 170), BF        ' dim the art so the tints read
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            k = CellKind%(cx, cy)
            IF k >= 1 THEN
                walk = walk + 1
                px = cx * CW: py = cy * CH
                s = SECTOR.get_by_xy(cx * CW, cy * CH)
                IF s >= 1 THEN
                    col = SECTORS(s).kolor
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGBA32(_RED32(col), _GREEN32(col), _BLUE32(col), 120), BF
                ELSEIF GAPREACH(cx, cy) THEN
                    gaps = gaps + 1
                    ' flat white + a red rim -- unmistakable against nine tinted levels. Only
                    ' cells the player can actually WALK to get this treatment.
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HFF, &HFF, &HFF), BF
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HFF, &H00, &H00), B
                ELSE
                    ' unclaimed, but sealed off -- the logo's yellow fill. Dim, not alarming.
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&H50, &H50, &H50, 160), BF
                END IF
            END IF
        NEXT cx
    NEXT cy
    '--- the DERIVED rectangles, outlined in each level's colour ------------
    FOR s = 1 TO 9
        IF dcnt(s) > 0 THEN
            LINE (dx1(s) * CW, dy1(s) * CH)-((dx2(s) + 1) * CW - 1, (dy2(s) + 1) * CH - 1), SECTORS(s).kolor, B
            _FONT CH
            COLOR _RGB32(0, 0, 0), SECTORS(s).kolor
            _PRINTSTRING (dx1(s) * CW + 1, dy1(s) * CH + 1), _TRIM$(STR$(s))
        END IF
    NEXT s
    '--- legend ------------------------------------------------------------
    LINE (0, (SH - 3) * CH)-(SW * CW - 1, SH * CH - 1), _RGB32(0, 0, 0), BF
    _FONT CH
    COLOR _RGB32(&HFF, &HFF, &H80), _RGB32(0, 0, 0)
    _PRINTSTRING (1 * CW, (SH - 3) * CH), "sectorauto -- " + _TRIM$(STR$(walk)) + " walkable cells; " + _TRIM$(STR$(gaps)) + " REACHABLE cells are claimed by no level (grey = unclaimed but sealed off)"
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&HC0, &H00, &H00)
    _PRINTSTRING (1 * CW, (SH - 2) * CH), " WHITE "
    COLOR _RGB32(&HA0, &HA0, &HA0), _RGB32(0, 0, 0)
    _PRINTSTRING (8 * CW, (SH - 2) * CH), "= you can WALK here, but no level claims it -- PlayerLevel% now carries the last level in"
    COLOR _RGB32(&HA0, &HA0, &HA0), _RGB32(0, 0, 0)
    _PRINTSTRING (1 * CW, (SH - 1) * CH), "tinted = the level that cell resolves to    outlined box + number = that level's DERIVED rect"
    _SAVEIMAGE "sectorauto.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |10sectorauto.png|07 -- every walkable cell tinted by level; unclaimed ones in WHITE")
END SUB


' Which level's colour fills cell (cx,cy) ENTIRELY? 0 if the cell is not uniformly one level
' colour. Uniform-only on purpose: a half-block or a text glyph is two colours, so it belongs
' to no level with certainty and must not stretch a bounding box.
FUNCTION CellSolidSector% (cx AS INTEGER, cy AS INTEGER)
    DIM s AS INTEGER
    CellSolidSector% = 0
    s = SectorByColor%(POINT(cx * CW + CW \ 2, cy * CH + CH \ 2))
    IF s < 1 THEN EXIT FUNCTION
    IF CellRoomKind%(cx, cy, SECTORS(s).kolor) = CRK_FLOOR THEN CellSolidSector% = s
END FUNCTION


' ============================================================================
'  ORPHAN BLOCKS -- floor the ART paints that DetectRooms never turned into a room.
'
'  DetectRooms seeds a block only when the cell's colour matches the colour of the SECTOR the
'  cell is in: `SECTOR.get_by_xy(...) = sec` AND `POINT(centre) = SECTORS(sec).kolor`. The
'  sector comes from the painted sector MASK, the colour from the board art -- two separate
'  files -- so a block whose art colour disagrees with the mask underneath it is never seeded.
'  It stays visible on the board, with doors leading into it, and holds nothing at all.
'
'  That failure is invisible in play (an empty room just looks cleared) and invisible in the
'  room table (the block is not in it), which is exactly why it needs its own scan. `verdict`
'  is marked so the overlay can paint them.
' ============================================================================
SUB OrphanBlockScan (verdict() AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER, s AS INTEGER, m AS INTEGER, n AS INTEGER
    DIM col AS _UNSIGNED LONG, seen(0 TO 131, 0 TO 60) AS INTEGER
    DIM minx AS INTEGER, maxx AS INTEGER, miny AS INTEGER, maxy AS INTEGER, cnt AS INTEGER
    DIM flr AS INTEGER, hdr AS INTEGER, noMask AS INTEGER, decor AS INTEGER, lostcells AS LONG
    PRINT
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF ROOMAT(cx, cy) = 0 AND seen(cx, cy) = 0 THEN
                col = POINT(cx * CW + CW \ 2, cy * CH + CH \ 2)
                s = SectorByColor%(col)
                IF s >= 1 THEN
                    ' a floor-coloured cell that belongs to no room -- flood the whole block
                    cnt = 0: flr = 0: minx = cx: maxx = cx: miny = cy: maxy = cy
                    OrphanFlood cx, cy, col, seen(), cnt, flr, minx, miny, maxx, maxy, verdict()
                    IF cnt >= 2 THEN
                        m = SECTOR.get_by_xy(((minx + maxx) \ 2) * CW, ((miny + maxy) \ 2) * CH)
                        IF flr = 0 THEN
                            decor = decor + 1              ' no cell to stand on: a plaque or trim
                        ELSEIF m < 1 THEN
                            noMask = noMask + 1            ' outside the play area (logo / legend art)
                        ELSE
                            ' REAL LOST ROOM: it has floor, the mask covers it, and yet the two
                            ' disagree about which level owns it -- so nothing ever seeded it.
                            n = n + 1: lostcells = lostcells + flr
                            IF hdr = 0 THEN
                                hdr = -1
                                PRINT PipeCol$("  |12LOST ROOMS|07 -- painted floor, inside the play area, that never became a room:")
                                PRINT PipeCol$("  |08 floor  at            art paints   sector mask says")
                            END IF
                            PRINT PipeCol$("  " + PadR$(_TRIM$(STR$(flr)), 7) + PadR$(_TRIM$(STR$(minx)) + "," + _TRIM$(STR$(miny)) + "-" + _TRIM$(STR$(maxx)) + "," + _TRIM$(STR$(maxy)), 14) + PadR$("level " + _TRIM$(STR$(s)), 13) + OrphanWhy$(s, m))
                        END IF
                    END IF
                END IF
            END IF
        NEXT cx
    NEXT cy
    IF n = 0 THEN
        PRINT PipeCol$("  |10no lost rooms|07 -- every painted floor block inside the play area became a room")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(n)) + " LOST ROOM(s)|07, " + _TRIM$(STR$(lostcells)) + " floor cells -- visible, door-connected, and completely empty")
        PRINT PipeCol$("  |08  DetectRooms seeds a block only where the ART colour equals the colour of the")
        PRINT PipeCol$("  |08  SECTOR the MASK paints under it. Two different files; where they disagree, the")
        PRINT PipeCol$("  |08  block is invisible to detection. Fix the mask (board-132x50-sector-mask.ans).")
    END IF
    IF noMask > 0 THEN PRINT PipeCol$("  |08(" + _TRIM$(STR$(noMask)) + " floor-coloured block(s) sit where the mask paints NO level -- the logo/legend art outside the board; ignored)")
    IF decor > 0 THEN PRINT PipeCol$("  |08(" + _TRIM$(STR$(decor)) + " block(s) with no cell to stand on -- the level plaques and trim; ignored)")
END SUB

' Why did this block never get seeded? The art colour and the sector mask underneath disagree,
' so DetectRooms' `colour = SECTORS(sector).kolor` test never fires for any cell in it.
FUNCTION OrphanWhy$ (artsec AS INTEGER, masksec AS INTEGER)
    IF masksec <> artsec THEN
        OrphanWhy$ = "|12level " + _TRIM$(STR$(masksec)) + "|07 -- MISMATCH: mask must say " + _TRIM$(STR$(artsec))
    ELSE
        OrphanWhy$ = "|14level " + _TRIM$(STR$(masksec)) + "|07 -- matches; block is on a board edge row/col"
    END IF
END FUNCTION

' Flood one orphan block (same centre colour, 4-connected, not in any room), recording its
' size, how much of it is real standable FLOOR, its bounding box, and tagging its cells in
' `verdict` for the overlay.
SUB OrphanFlood (sx AS INTEGER, sy AS INTEGER, col AS _UNSIGNED LONG, seen() AS INTEGER, cnt AS INTEGER, flr AS INTEGER, minx AS INTEGER, miny AS INTEGER, maxx AS INTEGER, maxy AS INTEGER, verdict() AS INTEGER)
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER
    head = 0: tail = 0
    QX(0) = sx: QY(0) = sy: seen(sx, sy) = -1: tail = 1
    DO WHILE head < tail
        x = QX(head): y = QY(head): head = head + 1
        cnt = cnt + 1
        IF CellRoomKind%(x, y, col) = CRK_FLOOR THEN flr = flr + 1
        verdict(x, y) = CRK_ORPHAN
        IF x < minx THEN minx = x
        IF x > maxx THEN maxx = x
        IF y < miny THEN miny = y
        IF y > maxy THEN maxy = y
        OrphanVisit x - 1, y, col, seen(), tail
        OrphanVisit x + 1, y, col, seen(), tail
        OrphanVisit x, y - 1, col, seen(), tail
        OrphanVisit x, y + 1, col, seen(), tail
    LOOP
END SUB

SUB OrphanVisit (x AS INTEGER, y AS INTEGER, col AS _UNSIGNED LONG, seen() AS INTEGER, tail AS INTEGER)
    IF x < 0 OR y < 0 OR x > SW - 1 OR y > SH - 1 THEN EXIT SUB
    IF seen(x, y) THEN EXIT SUB
    IF ROOMAT(x, y) <> 0 THEN EXIT SUB
    IF POINT(x * CW + CW \ 2, y * CH + CH \ 2) <> col THEN EXIT SUB
    seen(x, y) = -1: QX(tail) = x: QY(tail) = y: tail = tail + 1
END SUB


' Does cell (cx,cy) of room r touch a walkable cell OUTSIDE the room? That is the test for
' "can you get in at all": a block whose entire perimeter is wall/black is decorative.
' Diagonals count -- the game moves 8-way.
FUNCTION RoomTouchesOutside% (cx AS INTEGER, cy AS INTEGER, r AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER
    RoomTouchesOutside% = 0
    FOR dy = -1 TO 1
        FOR dx = -1 TO 1
            IF dx <> 0 OR dy <> 0 THEN
                nx = cx + dx: ny = cy + dy
                IF nx >= 0 AND nx <= SW - 1 AND ny >= 0 AND ny <= SH - 1 THEN
                    IF ROOMAT(nx, ny) <> r THEN
                        IF CellKind%(nx, ny) >= 1 THEN RoomTouchesOutside% = -1: EXIT FUNCTION
                    END IF
                END IF
            END IF
        NEXT dx
    NEXT dy
END FUNCTION


' Paint the roomlint verdict over the board and save roomlint.png.
'
' Layering matters: the tints go down first, then the room markers, then the labels, so a
' room number is never buried under its own tint. The board is dimmed underneath because the
' art is already saturated -- a translucent red over a bright magenta room floor is otherwise
' indistinguishable from the floor.
'
'   red cell       a PHANTOM cell: DetectRooms counted it into a room, CanMove refuses it
'   green cell     ordinary walkable room floor
'   white box      this room's monster/grave marker, and the player can reach it
'   red X + number the marker sits on a cell that CANNOT be reached -- this room never fires
'                  an encounter and never shows a headstone
'   yellow number  the room has phantom cells but its marker is still reachable
SUB RoomLintOverlay (verdict() AS INTEGER, rfloor() AS INTEGER, rmix() AS INTEGER, rbad() AS INTEGER, risle() AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER, r AS INTEGER, px AS INTEGER, py AS INTEGER
    DIM lx AS INTEGER, ly AS INTEGER, lab AS STRING, i AS INTEGER, tries AS INTEGER
    DIM nbad AS INTEGER, nmix AS INTEGER, nisle AS INTEGER, ndoor AS INTEGER
    DIM taken(0 TO 131, 0 TO 60) AS INTEGER          ' label occupancy, so numbers can't collide
    _DEST CANVAS
    _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(0, 0, 0, 150), BF          ' dim the art so the tints read
    '--- per-cell verdict tints ---------------------------------------------
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            px = cx * CW: py = cy * CH
            SELECT CASE verdict(cx, cy)
                CASE CRK_FLOOR
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&H30, &HC0, &H50, 110), BF
                CASE CRK_DOOR
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&H40, &H90, &HFF, 170), BF
                CASE CRK_MIXED
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&H90, &H70, &H30, 150), BF
                CASE CRK_ORPHAN
                    LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HFF, &H20, &HFF, 200), BF   ' painted floor that is in NO room
            END SELECT
        NEXT cx
    NEXT cy
    '--- each room's marker cell --------------------------------------------
    FOR r = 1 TO ROOM_N
        cx = ROOMS(r).cx: cy = ROOMS(r).cy
        IF cx >= 0 AND cy >= 0 AND cx <= 131 AND cy <= 60 THEN
            px = cx * CW: py = cy * CH
            IF rbad(r) = -1 THEN
                LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HFF, &H40, &H40), BF    ' unreachable / decor island
                LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HFF, &HF0, &H40)        ' X through it
                LINE (px, py + CH - 1)-(px + CW - 1, py), _RGB32(&HFF, &HF0, &H40)
            ELSEIF rbad(r) = -2 THEN
                LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HFF, &HA0, &H20), BF    ' marker sitting in a doorway
                LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&H20, &H10, &H00), B
            ELSE
                LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&HF0, &HF0, &HF0), B
            END IF
        END IF
    NEXT r
    '--- labels LAST, so no tint or box can bury them ------------------------
    ' Rooms can sit a cell apart, so their numbers collide (76 and 77 printed as "7677").
    ' Claim the cells a label covers and nudge the next one down until it finds clear space.
    _FONT CH
    FOR r = 1 TO ROOM_N
        nmix = nmix + rmix(r)
        IF rbad(r) <> 0 THEN
            cx = ROOMS(r).cx: cy = ROOMS(r).cy
            IF cx >= 0 AND cy >= 0 AND cx <= 131 AND cy <= 60 THEN
                lab = _TRIM$(STR$(r))
                lx = cx + 1: ly = cy
                IF lx + LEN(lab) > SW - 1 THEN lx = cx - LEN(lab)   ' keep it on the board
                IF lx < 0 THEN lx = 0
                FOR tries = 0 TO 3                                  ' nudge down past any claimed row
                    IF LabelFree%(taken(), lx, ly, LEN(lab)) THEN EXIT FOR
                    IF ly + 1 > SH - 4 THEN EXIT FOR
                    ly = ly + 1
                NEXT tries
                FOR i = -1 TO LEN(lab)                          ' claim a cell of padding each side
                    IF lx + i >= 0 AND lx + i <= 131 THEN
                        IF ly >= 0 AND ly <= 60 THEN taken(lx + i, ly) = -1
                    END IF
                NEXT i
                IF rfloor(r) = 0 THEN
                    ' Same test RoomIsDecor% uses -- NOT the island test, which only catches the
                    ' plaques that float in black. A plaque sitting against a corridor is still
                    ' decoration; what makes it one is having no cell to stand on.
                    nisle = nisle + 1
                    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&HA0, &H00, &HA0)   ' decoration -- not a room
                ELSEIF rbad(r) = -1 THEN
                    nbad = nbad + 1
                    COLOR _RGB32(&H10, &H00, &H00), _RGB32(&HFF, &H80, &H80)   ' marker on an unwalkable cell
                ELSE
                    ndoor = ndoor + 1
                    COLOR _RGB32(&H10, &H10, &H00), _RGB32(&HFF, &HC0, &H40)   ' marker in a doorway
                END IF
                _PRINTSTRING (lx * CW, ly * CH), lab
            END IF
        END IF
    NEXT r
    '--- legend + verdict, over the board's own key rows (this is a diagnostic, not the map) ---
    LINE (0, (SH - 4) * CH)-(SW * CW - 1, SH * CH - 1), _RGB32(0, 0, 0), BF
    COLOR _RGB32(&HFF, &HFF, &H80), _RGB32(0, 0, 0)
    _PRINTSTRING (1 * CW, (SH - 4) * CH), "roomlint -- " + _TRIM$(STR$(ROOM_N)) + " rooms | " + _TRIM$(STR$(nisle)) + " DECORATION blocks (no floor to stand on) | " + _TRIM$(STR$(nbad)) + " markers on unwalkable cells | " + _TRIM$(STR$(ndoor)) + " markers in DOORWAYS"
    COLOR _RGB32(&H60, &HE0, &H80), _RGB32(0, 0, 0)
    _PRINTSTRING (1 * CW, (SH - 3) * CH), "GREEN cell = plain room floor"
    COLOR _RGB32(&H70, &HB0, &HFF), _RGB32(0, 0, 0)
    _PRINTSTRING (32 * CW, (SH - 3) * CH), "BLUE cell = doorway (walkable, but a threshold)"
    COLOR _RGB32(&HC0, &H98, &H50), _RGB32(0, 0, 0)
    _PRINTSTRING (81 * CW, (SH - 3) * CH), "TAN cell = decorative half-block (" + _TRIM$(STR$(nmix)) + ")"
    COLOR _RGB32(&HF0, &HF0, &HF0), _RGB32(0, 0, 0)
    _PRINTSTRING (1 * CW, (SH - 2) * CH), "WHITE box = monster/grave marker, correctly on plain floor"
    COLOR _RGB32(&HFF, &HA0, &H20), _RGB32(0, 0, 0)
    _PRINTSTRING (61 * CW, (SH - 2) * CH), "ORANGE box = marker sitting IN A DOORWAY"
    COLOR _RGB32(&HFF, &H40, &H40), _RGB32(0, 0, 0)
    _PRINTSTRING (1 * CW, (SH - 1) * CH), "RED box + X = marker on a cell nothing can stand on"
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&HA0, &H00, &HA0)
    _PRINTSTRING (55 * CW, (SH - 1) * CH), "n"
    COLOR _RGB32(&HA0, &HA0, &HA0), _RGB32(0, 0, 0)
    _PRINTSTRING (56 * CW, (SH - 1) * CH), " = DECORATION (a level plaque): level colour + letters, no floor -- skipped, not a room"
    _SAVEIMAGE "roomlint.png", CANVAS
END SUB


' Are the `n` cells at (lx,ly) -- PLUS one cell of padding each side -- still free for a label?
' The padding is the point: two labels that merely abut read as one number ("76" beside "77"
' prints as "7677"), which is worse than an overlap because it looks like a valid room index.
FUNCTION LabelFree% (taken() AS INTEGER, lx AS INTEGER, ly AS INTEGER, n AS INTEGER)
    DIM i AS INTEGER
    LabelFree% = 0
    IF ly < 0 OR ly > 60 THEN EXIT FUNCTION
    FOR i = -1 TO n
        IF lx + i >= 0 AND lx + i <= 131 THEN
            IF taken(lx + i, ly) THEN EXIT FUNCTION
        END IF
    NEXT i
    LabelFree% = -1
END FUNCTION


SUB DataLint
    DIM lvl AS INTEGER, slot AS INTEGER, nitem AS INTEGER, errs AS INTEGER, warns AS INTEGER
    DIM i AS INTEGER, nm AS STRING, code AS INTEGER, goldslots AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15datalint|07 -- validating the loaded content tables (data pack: |11" + _TRIM$(opt_datapack) + "|07)")
    PRINT

    '--- treasure slots + the magic-item POOL ---------------------------------
    ' Items no longer override a treasure slot, so every treasures.txt row is reachable by
    ' construction. What CAN go wrong now: a level with a drop chance but no pool to draw
    ' from (silently never yields an item), or a pool with no chance (dead rows).
    PRINT PipeCol$("|11item drop odds|07 (ITEM_PCT_<n> = how often; items.txt weight = which)")
    IF ITEMS_OLDFMT THEN
        PRINT PipeCol$("  |14!!|07 items.txt uses the LEGACY `lvl | slot | name | gold | type` layout.")
        PRINT PipeCol$("       It still loads (slot ignored, equal weights), but migrate to")
        PRINT PipeCol$("       `lvl | name | gold | type | weight` to control rarity.")
        warns = warns + 1
    END IF
    FOR lvl = 1 TO 9
        nitem = ITM_N(lvl)
        IF ITEM_PCT(lvl) > 0 AND nitem = 0 THEN
            PRINT PipeCol$("  |12!! level " + LTRIM$(STR$(lvl)) + "|07: ITEM_PCT is " + LTRIM$(STR$(ITEM_PCT(lvl))) + "% but the item pool is EMPTY -- it can never yield an item")
            errs = errs + 1
        ELSEIF ITEM_PCT(lvl) = 0 AND nitem > 0 THEN
            PRINT PipeCol$("  |14!! level " + LTRIM$(STR$(lvl)) + "|07: " + LTRIM$(STR$(nitem)) + " item(s) in the pool but ITEM_PCT is 0 -- those rows are dead")
            warns = warns + 1
        ELSEIF ITEM_PCT(lvl) >= 100 THEN
            PRINT PipeCol$("  |12!! level " + LTRIM$(STR$(lvl)) + "|07: ITEM_PCT is " + LTRIM$(STR$(ITEM_PCT(lvl))) + "% -- this level can never yield a GOLD treasure card")
            errs = errs + 1
        ELSE
            PRINT PipeCol$("  |10ok|07 level " + LTRIM$(STR$(lvl)) + ": " + LTRIM$(STR$(ITEM_PCT(lvl))) + "% item chance from a pool of " + LTRIM$(STR$(nitem)))
        END IF
        ' a pool entry that can never be drawn
        FOR slot = 1 TO nitem
            IF ITM_W(lvl, slot) <= 0 THEN
                PRINT PipeCol$("  |14!!|07 " + _TRIM$(ITM_NAME(lvl, slot)) + " (level " + LTRIM$(STR$(lvl)) + ") has weight 0 -- never drawn")
                warns = warns + 1
            END IF
            code = ITM_CODE(lvl, slot)
            ' 1..5, 7..13 are handled by ClaimTreasure; 6 (Level Key) is placed dynamically
            IF code < 1 OR code > 13 OR code = 6 THEN
                PRINT PipeCol$("  |12!!|07 " + _TRIM$(ITM_NAME(lvl, slot)) + " (level " + LTRIM$(STR$(lvl)) + ") has unhandled type code " + LTRIM$(STR$(code)))
                errs = errs + 1
            END IF
        NEXT slot
    NEXT lvl
    PRINT

    '--- every slot must actually be filled -----------------------------------
    PRINT PipeCol$("|11table completeness|07")
    FOR lvl = 1 TO 9
        FOR slot = 1 TO 3
            IF LEN(_TRIM$(TRE_NAME(lvl, slot))) = 0 THEN
                PRINT PipeCol$("  |12!!|07 treasure slot " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " has no name")
                errs = errs + 1
            END IF
            IF LEN(_TRIM$(MON_NAME(lvl, slot))) = 0 THEN
                PRINT PipeCol$("  |12!!|07 monster slot " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " has no name")
                errs = errs + 1
            END IF
        NEXT slot
    NEXT lvl

    '--- a gold slot worth 0 is a silent dud ----------------------------------
    FOR lvl = 1 TO 9
        FOR slot = 1 TO 3
            IF TRE_ITEM(lvl, slot) = 0 AND TRE_GOLD(lvl, slot) <= 0 THEN
                PRINT PipeCol$("  |14!!|07 treasure " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " (" + _TRIM$(TRE_NAME(lvl, slot)) + ") is worth 0 gold and is not an item")
                warns = warns + 1
            END IF
        NEXT slot
    NEXT lvl

    ' (item type codes are checked per POOL entry above -- treasure slots are always gold)

    '--- chamber event table --------------------------------------------------
    ' Mechanics are keyed by `kind`; a typo'd kind silently never fires (ChamberEventKind$
    ' returns it, the SELECT CASE has no branch, and you get a gauntlet instead).
    PRINT PipeCol$("|11chamber events|07")
    IF NCHMEV <= 0 THEN
        PRINT PipeCol$("  |14!!|07 no chamber-events.txt loaded -- chambers fall back to gauntlet-only")
        warns = warns + 1
    ELSE
        DIM gw AS INTEGER, tw AS INTEGER, kk AS STRING
        FOR i = 1 TO NCHMEV
            kk = _TRIM$(CHM_EV(i).kind)
            tw = tw + CHM_EV(i).weight
            IF kk = "gauntlet" THEN gw = gw + CHM_EV(i).weight
            SELECT CASE kk
                CASE "gauntlet", "shrine", "hazard", "boon", "lord"
                CASE ELSE
                    PRINT PipeCol$("  |12!!|07 event '" + kk + "' has no mechanic in code -- it would silently play as a gauntlet")
                    errs = errs + 1
            END SELECT
            IF CHM_EV(i).weight <= 0 THEN
                PRINT PipeCol$("  |14!!|07 event '" + kk + "' has weight " + LTRIM$(STR$(CHM_EV(i).weight)) + " -- it can never be drawn")
                warns = warns + 1
            END IF
            IF CHM_EV(i).maxlvl > 0 AND CHM_EV(i).minlvl > CHM_EV(i).maxlvl THEN
                PRINT PipeCol$("  |12!!|07 event '" + kk + "' has minlvl > maxlvl -- eligible at NO depth")
                errs = errs + 1
            END IF
        NEXT i
        IF gw <= 0 THEN
            PRINT PipeCol$("  |12!!|07 no 'gauntlet' entry with weight -- chambers would stop spawning monsters")
            errs = errs + 1
        ELSEIF tw > 0 THEN
            PRINT PipeCol$("  |10ok|07 " + LTRIM$(STR$(NCHMEV)) + " event(s); gauntlet is " + LTRIM$(STR$(gw * 100 / tw)) + "% of the weight")
        END IF
    END IF
    PRINT

    '--- classes -------------------------------------------------------------
    FOR i = 1 TO UBOUND(CLASSES)
        nm = _TRIM$(CLASSES(i).name)
        IF LEN(nm) = 0 THEN
            PRINT PipeCol$("  |12!!|07 class " + LTRIM$(STR$(i)) + " has no name")
            errs = errs + 1
        ELSEIF CLASSES(i).gold_goal <= 0 THEN
            PRINT PipeCol$("  |12!!|07 class " + nm + " has a win goal of " + LTRIM$(STR$(CLASSES(i).gold_goal)) + " -- unwinnable/instant-win")
            errs = errs + 1
        END IF
    NEXT i
    IF errs = 0 AND warns = 0 THEN PRINT PipeCol$("  |10ok|07 everything else checks out")
    PRINT

    IF errs > 0 THEN
        PRINT PipeCol$("|12datalint: " + LTRIM$(STR$(errs)) + " error(s)|07, " + LTRIM$(STR$(warns)) + " warning(s)")
        SYSTEM 1
    END IF
    PRINT PipeCol$("|10datalint: clean|07 (" + LTRIM$(STR$(warns)) + " warning(s))")
    SYSTEM 0
END SUB


' ============================================================================
'  `dungeon.run econdump` -- what does the gold economy actually look like?
'
'  Written because decoupling item drops from treasure slots CHANGED the economy's shape
'  (more gold treasure cards, fewer magic items, fewer duplicate-item sales), and the honest
'  answer to "did that break win pacing?" was "play twenty games and see". This computes it
'  instead, from the SAME tables and odds the game uses.
'
'  It reports EXPECTED values, not a simulation: expected gold per room on a level is
'    (1 - ITEM_PCT/100) * (average gold across that level's 3 treasure slots)
'  because a room rolls 1 of 3 slots uniformly and an ITEM_PCT fraction of rooms yield a
'  magic item instead. Items are counted separately and NOT as gold: taking one the first
'  time pays nothing (you get the item) -- only a duplicate sells. So the gold column is a
'  floor, and real runs land above it as duplicates accumulate.
'
'  Room counts come from the real board, so the numbers are for the actual map.
' ============================================================================
SUB EconDump
    DIM lvl AS INTEGER, slot AS INTEGER, r AS INTEGER
    DIM nroom(1 TO 9) AS INTEGER   ' NOT `rooms` -- that shadows the shared ROOMS() array
    DIM avgg(1 TO 9) AS DOUBLE, goldl(1 TO 9) AS DOUBLE, itemsl(1 TO 9) AS DOUBLE
    DIM tot AS DOUBLE, cum AS DOUBLE, totitems AS DOUBLE, sumg AS DOUBLE, ns AS INTEGER
    DIM hitHero AS INTEGER, hitSuper AS INTEGER, hitWiz AS INTEGER
    DIM ln AS STRING

    RANDOMIZE 20260729                             ' any seed: room COUNTS are map geometry, not RNG
    StartBoard
    RandomizeRooms
    _DEST _CONSOLE

    FOR r = 1 TO ROOM_N                            ' rooms that actually hold an encounter
        lvl = ROOMS(r).sec
        IF lvl >= 1 AND lvl <= 9 THEN
            IF LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN nroom(lvl) = nroom(lvl) + 1
        END IF
    NEXT r

    PRINT PipeCol$("|15econdump|07 -- expected gold economy (data pack: |11" + _TRIM$(opt_datapack) + "|07)")
    PRINT
    PRINT PipeCol$("|11  lvl  rooms  avg gold/slot  item%   exp. gold   exp. items|07")
    FOR lvl = 1 TO 9
        sumg = 0: ns = 0
        FOR slot = 1 TO 3
            sumg = sumg + TRE_GOLD(lvl, slot): ns = ns + 1
        NEXT slot
        IF ns > 0 THEN avgg(lvl) = sumg / ns
        goldl(lvl) = nroom(lvl) * avgg(lvl) * (100 - ITEM_PCT(lvl)) / 100
        itemsl(lvl) = nroom(lvl) * ITEM_PCT(lvl) / 100
        tot = tot + goldl(lvl): totitems = totitems + itemsl(lvl)
        ' built up in steps -- QB64's `_` line continuation mangles a long concatenation
        ln = RPad$(LTRIM$(STR$(lvl)), 5)
        ln = ln + RPad$(LTRIM$(STR$(nroom(lvl))), 7)
        ln = ln + RPad$(LTRIM$(STR$(INT(avgg(lvl)))), 15)
        ln = ln + RPad$(LTRIM$(STR$(ITEM_PCT(lvl))) + "%", 8)
        ln = ln + RPad$(LTRIM$(STR$(INT(goldl(lvl)))), 12)
        ln = ln + LTRIM$(STR$(INT(itemsl(lvl) * 10) / 10))
        PRINT PipeCol$("  " + ln)
    NEXT lvl
    PRINT
    PRINT PipeCol$("  total expected treasure gold on the whole board: |14" + LTRIM$(STR$(INT(tot))) + "|07")
    PRINT PipeCol$("  total expected magic items:                      |14" + LTRIM$(STR$(INT(totitems * 10) / 10)) + "|07")
    PRINT PipeCol$("  |08(gold is a FLOOR -- items pay nothing on first pickup, only duplicates sell)")
    PRINT

    ' Win pacing: how deep must you get to afford each class's target, clearing every
    ' room down to that depth? This is the number that actually matters after a rebalance.
    PRINT PipeCol$("|11win pacing|07 -- shallowest depth whose cumulative gold covers each target")
    cum = 0
    FOR lvl = 1 TO 9
        cum = cum + goldl(lvl)
        IF hitHero = 0 AND cum >= 10000 THEN hitHero = lvl
        IF hitSuper = 0 AND cum >= 20000 THEN hitSuper = lvl
        IF hitWiz = 0 AND cum >= 30000 THEN hitWiz = lvl
        PRINT PipeCol$("   through level " + LTRIM$(STR$(lvl)) + ": " + RIGHT$("          " + LTRIM$(STR$(INT(cum))), 10) + " gold")
    NEXT lvl
    PRINT
    EconTarget "HERO / ELF", 10000, hitHero
    EconTarget "SUPERHERO", 20000, hitSuper
    EconTarget "WIZARD", 30000, hitWiz
    PRINT
    MonsterCurveDump
    PRINT
    PRINT PipeCol$("  |08Tune with tuning.txt ITEM_PCT_<n> (how often items drop) and treasures.txt")
    PRINT PipeCol$("  |08(gold values), and the MON_/BOSS_/LORD_ rows for the monster curve.")
    PRINT PipeCol$("  |08Re-run this after any change -- no playthrough needed.")
    SYSTEM 0
END SUB


' The MONSTER CURVE, per depth and per spawn kind, straight out of MonsterStats/MonsterToHit%.
' A difficulty complaint is almost never about one monster -- it is about a stat that compounded
' across several multipliers -- and this is the only way to SEE that without a playthrough. HP is
' printed as its real min..max range rather than an average, because the range is what a player
' actually meets; the caps are flagged wherever they bite.
SUB MonsterCurveDump
    DIM lv AS INTEGER, hp AS INTEGER, ac AS INTEGER, sides AS INTEGER
    DIM lo AS INTEGER, hi AS INTEGER, s AS STRING
    PRINT PipeCol$("|15monster curve|07 -- HP range / AC / to-hit by depth (tuning.txt MON_*, BOSS_*, LORD_*)")
    PRINT
    PRINT PipeCol$("  |08lvl   room HP      AC  hit    LORD HP      AC  hit    boss HP      AC  hit")
    FOR lv = 1 TO 9
        sides = MON_HP_DIE_BASE + lv * MON_HP_DIE_STEP: IF sides < 1 THEN sides = 1
        lo = lv * MON_HP_PER_LVL + 1: hi = lv * MON_HP_PER_LVL + sides
        ac = MON_AC_BASE + lv: IF ac > MON_AC_MAX THEN ac = MON_AC_MAX
        s = "  " + PadR$(_TRIM$(STR$(lv)), 6) + PadR$(_TRIM$(STR$(lo)) + "-" + _TRIM$(STR$(hi)), 13)
        s = s + PadR$(_TRIM$(STR$(ac)), 4) + PadR$(ModStr$(MonsterToHit%(lv, MK_ROOM)), 7)
        ' the chamber LORD -- the compound case that produced a 70 HP / AC 18 / +10 guardian
        hp = lo * LORD_HP_PCT \ 100: ac = MON_AC_BASE + lv + LORD_AC_BONUS
        IF ac > MON_AC_MAX THEN ac = MON_AC_MAX
        s = s + PadR$(_TRIM$(STR$(hp)) + "-" + _TRIM$(STR$(hi * LORD_HP_PCT \ 100)), 13)
        s = s + PadR$(_TRIM$(STR$(ac)), 4) + PadR$(ModStr$(MonsterToHit%(lv, MK_LORD)), 7)
        s = s + PadR$(_TRIM$(STR$(BOSS_HP_BASE + lv * BOSS_HP_PER_LVL + 1)) + "-" + _TRIM$(STR$(BOSS_HP_BASE + lv * BOSS_HP_PER_LVL + 10)), 13)
        s = s + PadR$(_TRIM$(STR$(BOSS_AC)), 4) + ModStr$(MonsterToHit%(lv, MK_BOSS))
        PRINT s
    NEXT lv
    PRINT
    PRINT PipeCol$("  |08caps: MON_AC_MAX " + _TRIM$(STR$(MON_AC_MAX)) + " (the boss's own BOSS_AC is exempt -- it IS the wall), MON_TOHIT_MAX " + _TRIM$(STR$(MON_TOHIT_MAX)) + " (applies to all)")
    PRINT PipeCol$("  |08a hero's AC/to-hit come from classes.txt + ability mods; compare the two before tuning")
END SUB

' One win-pacing line. depth 0 = the whole board cannot fund that target.
SUB EconTarget (who AS STRING, target AS LONG, depth AS INTEGER)
    IF depth = 0 THEN
        PRINT PipeCol$("   |12" + who + "|07 (" + LTRIM$(STR$(target)) + "): NOT reachable from treasure gold alone")
    ELSE
        PRINT PipeCol$("   |10" + who + "|07 (" + LTRIM$(STR$(target)) + "): affordable by clearing through level |14" + LTRIM$(STR$(depth)) + "|07")
    END IF
END SUB


' Left-justify s in a field of w characters (pads right). The mirror of engine TEXT.bas
' PadR$, kept local because this is console table layout, not a game/engine concern.
FUNCTION RPad$ (s AS STRING, w AS INTEGER)
    IF LEN(s) >= w THEN RPad$ = s + " " ELSE RPad$ = s + SPACE$(w - LEN(s))
END FUNCTION
