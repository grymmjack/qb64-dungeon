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
    ' FULL_COLLIDE, not FULL_BOARD: these tools report what MOVEMENT sees, and movement reads
    ' the collision layer. Sampling the display board means sampling layer-1 decoration too --
    ' the logo, the legend and the frame all paint in level colours, so it reported hundreds of
    ' "reachable cells with no level" that the player cannot actually reach.
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE
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
    WalkLint
    PRINT
    PRINT PipeCol$("  wrote |10roomlint.png|07 -- the board with every problem cell and room marked")
    SYSTEM 0
END SUB


' ============================================================================
'  `dungeon.run boardsplit` -- split the board into COLLISION and DECORATION layers.
'
'  Today one file answers two questions that do not have the same answer: "what does this look
'  like" and "what can I walk on". That is why decorative half-block lips read as room floor to
'  the detector but as wall to movement, and why the level plaques became rooms. Splitting them
'  makes both questions answerable, and lets art be drawn that the player can simply walk over.
'
'  THE RULE. A cell goes to layer-0 (collision) when it is UNIFORMLY one collision colour --
'  a full block, or a space whose background is that colour. Those are exactly the cells the
'  movement code already accepts, so the walkable set is preserved EXACTLY and no run plays
'  differently. Everything else -- half-blocks, shading, the text of the level plaques -- is
'  decoration and goes to layer-1 verbatim.
'
'  Layer-0 is emitted as space-on-background rather than a block glyph on a foreground: an
'  editor draws a block character with a hairline gap that samples as black, which would punch
'  holes in the collision map (the same trap sectorgen documents).
'
'  This works off the ANSI SOURCE, not the rendered pixels. From pixels you can see that a cell
'  is white-on-magenta but not that it is the letter "s", so the plaques could not be carried
'  across losslessly -- the characters are in the file, so read the file.
' ============================================================================
SUB BoardSplit
    DIM cx AS INTEGER, cy AS INTEGER, raw AS STRING, kept AS LONG, deco AS LONG
    DIM src AS STRING, p0 AS STRING, p1 AS STRING, f AS INTEGER, ok AS INTEGER
    DIM chA(0 TO 131, 0 TO 60) AS INTEGER, fgA(0 TO 131, 0 TO 60) AS INTEGER, bgA(0 TO 131, 0 TO 60) AS INTEGER
    DIM ch0(0 TO 131, 0 TO 60) AS INTEGER, fg0(0 TO 131, 0 TO 60) AS INTEGER, bg0(0 TO 131, 0 TO 60) AS INTEGER
    DIM ch1(0 TO 131, 0 TO 60) AS INTEGER, fg1(0 TO 131, 0 TO 60) AS INTEGER, bg1(0 TO 131, 0 TO 60) AS INTEGER
    DIM col AS INTEGER
    _DEST _CONSOLE
    src = AnsiFile$("board-132x50-no-labels.ans")
    PRINT PipeCol$("|15boardsplit|07 -- splitting |11" + src + "|07 into collision + decoration layers")
    raw = _READFILE$(src)
    IF LEN(raw) = 0 THEN PRINT PipeCol$("  |12cannot read the board art|07"): SYSTEM 1
    AnsiToCells raw, chA(), fgA(), bgA()

    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            ch0(cx, cy) = 32: fg0(cx, cy) = 7: bg0(cx, cy) = 0     ' layer-0 default: black = wall
            ch1(cx, cy) = 32: fg1(cx, cy) = 7: bg1(cx, cy) = 0     ' layer-1 default: black = transparent
            ' OUTSIDE THE PLAY AREA is decoration whatever it is painted in. The DUNGEON logo
            ' (cols 116+) is drawn in level-3 red and level-4 salmon, the bottom legend swatches
            ' in the path/door/secret colours, and the frame in level-3 red -- all of which the
            ' "contains a collision colour" rule would otherwise pull into the collision map as
            ' walkable floor. `sectorauto` measured the map as cols 0-115, rows 1-47.
            IF NOT InPlayArea%(cx, cy) THEN
                ch1(cx, cy) = chA(cx, cy)
                fg1(cx, cy) = fgA(cx, cy): bg1(cx, cy) = bgA(cx, cy)
                IF chA(cx, cy) <> 32 OR bgA(cx, cy) <> 0 THEN deco = deco + 1
            ELSEIF CellIsCollision%(chA(cx, cy), fgA(cx, cy), bgA(cx, cy)) THEN
                ch0(cx, cy) = chA(cx, cy)                          ' VERBATIM -- see the note below
                fg0(cx, cy) = fgA(cx, cy): bg0(cx, cy) = bgA(cx, cy)
                kept = kept + 1
            ELSE
                ch1(cx, cy) = chA(cx, cy)                          ' decoration, carried over verbatim
                fg1(cx, cy) = fgA(cx, cy): bg1(cx, cy) = bgA(cx, cy)
                IF chA(cx, cy) <> 32 OR bgA(cx, cy) <> 0 THEN deco = deco + 1
            END IF
        NEXT cx
    NEXT cy

    ' --- half-block ISLANDS are TRIM, not structure ---------------------------
    ' The art draws the level plaques with little half-block flourishes around the lettering.
    ' They are painted in a level colour, so the "contains a collision colour" rule sends them
    ' to layer-0 -- where they are meaningless: nothing can stand on them and nothing connects
    ' to them. A REAL room lip always touches the room it edges, so the test is neighbours:
    ' a half block with nothing painted around it in the collision layer is decoration.
    '
    ' Marked in full BEFORE any are moved. Moving as we scan would let one removal blank the
    ' neighbour that made the next cell non-island, and the result would depend on scan order.
    DIM isle(0 TO 131, 0 TO 60) AS INTEGER, isles AS LONG
    FOR cy = 1 TO SH - 2
        FOR cx = 1 TO SW - 2
            IF IsHalfGlyph%(ch0(cx, cy)) THEN
                IF CollisionIsland%(ch0(), bg0(), cx, cy) THEN isle(cx, cy) = -1: isles = isles + 1
            END IF
        NEXT cx
    NEXT cy
    FOR cy = 1 TO SH - 2
        FOR cx = 1 TO SW - 2
            IF isle(cx, cy) THEN
                ch1(cx, cy) = ch0(cx, cy): fg1(cx, cy) = fg0(cx, cy): bg1(cx, cy) = bg0(cx, cy)
                ch0(cx, cy) = 32: fg0(cx, cy) = 7: bg0(cx, cy) = 0
                kept = kept - 1: deco = deco + 1
            END IF
        NEXT cx
    NEXT cy

    p0 = CellsToAnsi$(ch0(), fg0(), bg0(), SH - 1)
    p1 = CellsToAnsi$(ch1(), fg1(), bg1(), SH - 1)
    ok = -1
    ok = ok AND WriteAnsiLayer%(AnsiOutPath$("layer-0-board-collisions.ans"), p0, "DUNGEON! collision layer")
    ok = ok AND WriteAnsiLayer%(AnsiOutPath$("layer-1-board-decoration.ans"), p1, "DUNGEON! decoration layer")
    PRINT
    PRINT PipeCol$("  collision cells: |10" + _TRIM$(STR$(kept)) + "|07 (walkable set preserved exactly)")
    IF isles > 0 THEN PRINT PipeCol$("    |11" + _TRIM$(STR$(isles)) + "|07 half-block island(s) moved to decoration -- label trim with nothing painted around it")
    PRINT PipeCol$("  decoration cells: |11" + _TRIM$(STR$(deco)) + "|07 (half-blocks, shading, the level plaques)")
    PRINT PipeCol$("  |08layer-0 keeps the source's own glyphs and colours, so it renders identically in")
    PRINT PipeCol$("  |08any ANSI viewer -- and a half-painted door stays half-painted, as movement expects.")
    ' Which collision colours ended up ONLY in decoration? A cell that is half secret-door blue
    ' is two-coloured, so the rule above sends it to layer-1 -- and then layer-0 has no secret
    ' door there at all. DetectSecretDoors finds those today because it samples the COMBINED
    ' board and accepts a partial-blue cell; the moment collision reads layer-0 alone, they
    ' vanish. Count them rather than discover it in play.
    DIM lostblue AS LONG, lostdoor AS LONG, lostfloor AS LONG, q AS INTEGER, ci AS INTEGER
    DIM blueminr AS INTEGER, bluemaxr AS INTEGER, brnminr AS INTEGER, brnmaxr AS INTEGER
    blueminr = 999: brnminr = 999: bluemaxr = -1: brnmaxr = -1
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF NOT CellIsCollision%(chA(cx, cy), fgA(cx, cy), bgA(cx, cy)) THEN
                ' not solid -- but does it CONTAIN a collision colour in either half?
                FOR q = 0 TO 1
                    IF q = 0 THEN ci = fgA(cx, cy) ELSE ci = bgA(cx, cy)
                    IF ci <> 0 THEN
                        IF ci = PaletteIndex%(BRIGHT_BLUE) THEN
                            lostblue = lostblue + 1
                            IF cy < blueminr THEN blueminr = cy
                            IF cy > bluemaxr THEN bluemaxr = cy
                        END IF
                        IF ci = PaletteIndex%(BROWN) THEN
                            lostdoor = lostdoor + 1
                            IF cy < brnminr THEN brnminr = cy
                            IF cy > brnmaxr THEN brnmaxr = cy
                        END IF
                    END IF
                NEXT q
            END IF
        NEXT cx
    NEXT cy
    PRINT PipeCol$("  cells holding a collision colour that went to DECORATION (lettering):")
    PRINT PipeCol$("    secret-door blue: |14" + _TRIM$(STR$(lostblue)) + "|07 (rows " + _TRIM$(STR$(blueminr)) + "-" + _TRIM$(STR$(bluemaxr)) + ")     door brown: |14" + _TRIM$(STR$(lostdoor)) + "|07 (rows " + _TRIM$(STR$(brnminr)) + "-" + _TRIM$(STR$(brnmaxr)) + ")")
    IF blueminr >= 48 AND brnminr >= 48 THEN
        PRINT PipeCol$("    |10all below row 48 -- the board's own legend swatches, correctly decoration|07")
    ELSE
        PRINT PipeCol$("    |12some sit INSIDE the play area -- layer-0 would be missing a real door|07")
    END IF
    ' --- what the ART actually contains, so a judgement call is made on data ---
    DIM nbrown AS LONG, nhalf AS LONG, nhalf2 AS LONG, hx AS INTEGER, hy AS INTEGER
    DIM isHalf AS INTEGER
    hx = -1
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF fgA(cx, cy) = PaletteIndex%(BROWN) OR bgA(cx, cy) = PaletteIndex%(BROWN) THEN nbrown = nbrown + 1
            isHalf = 0
            SELECT CASE chA(cx, cy)
                CASE 220, 221, 222, 223: isHalf = -1
            END SELECT
            IF isHalf THEN
                nhalf = nhalf + 1
                IF fgA(cx, cy) <> 0 AND bgA(cx, cy) <> 0 THEN
                    nhalf2 = nhalf2 + 1                     ' TWO non-black colours: a colour transition
                    IF hx < 0 THEN hx = cx: hy = cy
                END IF
            END IF
        NEXT cx
    NEXT cy
    ' NOT a door count -- this mode never runs DetectDoors, and brown is also used as floor.
    ' `dungeon.run roomlint` is what reports doorways.
    PRINT PipeCol$("  board art: |11" + _TRIM$(STR$(nbrown)) + "|07 cells carry BROWN (doors, plus some floor)")
    PRINT PipeCol$("  half-block cells: |11" + _TRIM$(STR$(nhalf)) + "|07 total, |11" + _TRIM$(STR$(nhalf2)) + "|07 with TWO non-black colours (first at " + _TRIM$(STR$(hx)) + "," + _TRIM$(STR$(hy)) + ")")
    ' Which glyph, and which colour pair? A room lip against a corridor is structural; a pair of
    ' greys or a colour-on-colour dash is label trim. Print the top pairs so the call is on data.
    DIM pk AS INTEGER, pj AS INTEGER, best AS LONG, bi AS INTEGER, bj AS INTEGER, bg2 AS INTEGER
    DIM pair(0 TO 15, 0 TO 15) AS LONG, glyphc(0 TO 255) AS LONG, rrow AS STRING
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            SELECT CASE chA(cx, cy)
                CASE 220, 221, 222, 223
                    IF fgA(cx, cy) <> 0 AND bgA(cx, cy) <> 0 THEN
                        pair(fgA(cx, cy), bgA(cx, cy)) = pair(fgA(cx, cy), bgA(cx, cy)) + 1
                        glyphc(chA(cx, cy)) = glyphc(chA(cx, cy)) + 1
                    END IF
            END SELECT
        NEXT cx
    NEXT cy
    PRINT PipeCol$("    by glyph -> lower(220):" + _TRIM$(STR$(glyphc(220))) + "  left(221):" + _TRIM$(STR$(glyphc(221))) + "  right(222):" + _TRIM$(STR$(glyphc(222))) + "  upper(223):" + _TRIM$(STR$(glyphc(223))))
    FOR pj = 1 TO 5
        best = 0: bi = -1
        FOR pk = 0 TO 15
            FOR bg2 = 0 TO 15
                IF pair(pk, bg2) > best THEN best = pair(pk, bg2): bi = pk: bj = bg2
            NEXT bg2
        NEXT pk
        IF bi < 0 THEN EXIT FOR
        PRINT PipeCol$("    fg " + _TRIM$(STR$(bi)) + " on bg " + _TRIM$(STR$(bj)) + " x" + _TRIM$(STR$(best)))
        pair(bi, bj) = 0
    NEXT pj
    PRINT
    BoardSplitVerify raw, p0, p1
    SYSTEM 0
END SUB


' ============================================================================
'  `dungeon.run boardfix` -- put the COLLISION COLOUR in the foreground.
'
'  A half-block cell shows two colours, and which one is the "foreground" is arbitrary: an
'  upper-half blue on yellow and a lower-half yellow on blue are the same picture spelled two
'  ways. That arbitrariness matters, because a cell's identity to the collision map is its
'  colour -- and four secret doors on the level-5 rooms are currently spelled with the door
'  blue in the BACKGROUND, so they read as magenta cells that happen to have blue behind them.
'
'  This flips those cells so the collision colour (secret-door blue, then door brown) is always
'  the foreground. iCE / bright backgrounds are fine and are used freely -- the flip is only
'  about WHICH half is named first, never about dimming anything.
'
'      upper half 223 <-> lower half 220, colours swapped
'      left half  221 <-> right half  222, colours swapped
'
'  Not a repaint: the rendered pixels are proven identical before anything is written, and a
'  cell whose foreground is ALREADY a collision colour is left alone. The original is backed
'  up to <file>.bak first, like ansifix.
' ============================================================================
SUB BoardFix
    DIM cx AS INTEGER, cy AS INTEGER, fixed AS LONG, t AS INTEGER
    DIM src AS STRING, raw AS STRING, outp AS STRING, f AS INTEGER
    DIM chA(0 TO 131, 0 TO 60) AS INTEGER, fgA(0 TO 131, 0 TO 60) AS INTEGER, bgA(0 TO 131, 0 TO 60) AS INTEGER
    _DEST _CONSOLE
    src = AnsiFile$("board-132x50-no-labels.ans")
    raw = _READFILE$(src)
    IF LEN(raw) = 0 THEN PRINT PipeCol$("|12cannot read " + src + "|07"): SYSTEM 1
    PRINT PipeCol$("|15boardfix|07 -- re-spelling half-block cells so the collision colour is the FOREGROUND")
    AnsiToCells raw, chA(), fgA(), bgA()
    FOR cy = 0 TO SH - 2
        FOR cx = 0 TO SW - 1
            IF IsHalfGlyph%(chA(cx, cy)) THEN
                ' Flip only when the background carries a collision colour the foreground does
                ' not -- otherwise the swap would just move the problem to the other half.
                IF CollisionRank%(bgA(cx, cy)) > CollisionRank%(fgA(cx, cy)) THEN
                    SELECT CASE chA(cx, cy)
                        CASE 223: chA(cx, cy) = 220
                        CASE 220: chA(cx, cy) = 223
                        CASE 221: chA(cx, cy) = 222
                        CASE 222: chA(cx, cy) = 221
                    END SELECT
                    t = fgA(cx, cy): fgA(cx, cy) = bgA(cx, cy): bgA(cx, cy) = t
                    fixed = fixed + 1
                    PRINT PipeCol$("    " + _TRIM$(STR$(cx)) + "," + _TRIM$(STR$(cy)) + " -- " + ColorRoleName$(fgA(cx, cy)) + " moved to the foreground")
                END IF
            END IF
        NEXT cx
    NEXT cy
    IF fixed = 0 THEN
        PRINT PipeCol$("  |10every collision colour is already in the foreground|07 -- art unchanged")
        SYSTEM 0
    END IF
    outp = CellsToAnsi$(chA(), fgA(), bgA(), SH - 1)
    ' The whole claim of this tool is "same picture, different spelling", so PROVE it before
    ' touching the file: render both strings through the real ANSI renderer and compare every
    ' pixel. If they differ at all, the rewrite is wrong -- bail rather than corrupt the board.
    IF NOT SameRender%(raw, outp) THEN
        PRINT PipeCol$("  |12the rewrite does NOT render identically|07 -- refusing to write; art untouched")
        SYSTEM 1
    END IF
    f = FREEFILE: OPEN src + ".bak" FOR OUTPUT AS #f: PRINT #f, raw;: CLOSE #f
    f = FREEFILE: OPEN src FOR OUTPUT AS #f
    PRINT #f, outp;
    PRINT #f, CHR$(26);
    PRINT #f, SauceRecord$("DUNGEON! board", SW, SH - 1, LEN(outp));
    CLOSE #f
    PRINT
    PRINT PipeCol$("  re-spelled |10" + _TRIM$(STR$(fixed)) + "|07 cell(s) -- |10verified pixel-for-pixel identical|07")
    PRINT PipeCol$("  original backed up to |14" + src + ".bak|07")
    PRINT PipeCol$("  |08re-run `dungeon.run boardsplit` to regenerate the layers from the corrected art")
    SYSTEM 0
END SUB


' Is this glyph one of the four half-blocks -- the only cells that show two colours at once?
' Is this collision cell an ISLAND -- nothing painted in any of its 8 neighbours?
FUNCTION CollisionIsland% (ch0() AS INTEGER, bg0() AS INTEGER, cx AS INTEGER, cy AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER
    CollisionIsland% = 0
    FOR dy = -1 TO 1
        FOR dx = -1 TO 1
            IF dx <> 0 OR dy <> 0 THEN
                IF cx + dx >= 0 AND cx + dx <= SW - 1 AND cy + dy >= 0 AND cy + dy <= SH - 1 THEN
                    IF ch0(cx + dx, cy + dy) <> 32 OR bg0(cx + dx, cy + dy) <> 0 THEN EXIT FUNCTION
                END IF
            END IF
        NEXT dx
    NEXT dy
    CollisionIsland% = -1
END FUNCTION


FUNCTION IsHalfGlyph% (g AS INTEGER)
    SELECT CASE g
        CASE 220, 221, 222, 223: IsHalfGlyph% = -1
        CASE ELSE: IsHalfGlyph% = 0
    END SELECT
END FUNCTION


' How much does the collision map care about this colour? Higher wins the foreground.
' A secret door outranks a plain door: it is the one the fog machinery has to find.
FUNCTION CollisionRank% (idx AS INTEGER)
    IF idx = PaletteIndex%(BRIGHT_BLUE) THEN CollisionRank% = 3: EXIT FUNCTION
    IF idx = PaletteIndex%(BROWN) THEN CollisionRank% = 2: EXIT FUNCTION
    CollisionRank% = 0
END FUNCTION


FUNCTION ColorRoleName$ (idx AS INTEGER)
    IF idx = PaletteIndex%(BRIGHT_BLUE) THEN ColorRoleName$ = "secret door": EXIT FUNCTION
    IF idx = PaletteIndex%(BROWN) THEN ColorRoleName$ = "door": EXIT FUNCTION
    ColorRoleName$ = "colour " + _TRIM$(STR$(idx))
END FUNCTION


' Do two .ans strings put the SAME pixels on screen? Renders both through ANSI_Print and
' compares. Used to gate boardfix -- a re-spelling that changes any pixel is a bug, not a fix.
FUNCTION SameRender% (a AS STRING, b AS STRING)
    DIM ia AS LONG, ib AS LONG, olddest AS LONG, oldsrc AS LONG
    DIM x AS INTEGER, y AS INTEGER, diff AS LONG
    olddest = _DEST: oldsrc = _SOURCE
    ia = _NEWIMAGE(SW * CW, SH * CH, 32)
    ib = _NEWIMAGE(SW * CW, SH * CH, 32)
    _DEST ia: _FONT CH: CLS , BLACK: ANSI_Print (a)
    _DEST ib: _FONT CH: CLS , BLACK: ANSI_Print (b)
    _SOURCE ia
    FOR y = 0 TO SH * CH - 1
        FOR x = 0 TO SW * CW - 1
            IF POINT(x, y) <> PointOf~&(ib, x, y) THEN diff = diff + 1
        NEXT x
    NEXT y
    _SOURCE oldsrc: _DEST olddest
    _FREEIMAGE ia: _FREEIMAGE ib
    SameRender% = (diff = 0)
END FUNCTION


' PROVE the split is lossless: render the original, render layer-0 with layer-1 composited over
' it (black = transparent), and compare every pixel. A split that changes one cell changes the
' board, and "it looked right" is not a check -- the whole point is that nothing moved.
SUB BoardSplitVerify (raw AS STRING, p0 AS STRING, p1 AS STRING)
    DIM iorig AS LONG, ia AS LONG, ib AS LONG, olddest AS LONG, oldsrc AS LONG
    DIM x AS INTEGER, y AS INTEGER, diff AS LONG, fx AS INTEGER, fy AS INTEGER
    olddest = _DEST: oldsrc = _SOURCE
    iorig = _NEWIMAGE(SW * CW, SH * CH, 32)
    ia = _NEWIMAGE(SW * CW, SH * CH, 32)
    ib = _NEWIMAGE(SW * CW, SH * CH, 32)
    _DEST iorig: _FONT CH: CLS , BLACK: ANSI_Print (raw)
    _DEST ia: _FONT CH: CLS , BLACK: ANSI_Print (p0)
    _DEST ib: _FONT CH: CLS , BLACK: ANSI_Print (p1)
    _CLEARCOLOR BLACK, ib                        ' decoration: black is transparent
    _DEST ia: _PUTIMAGE (0, 0), ib, ia           ' composite = what the game would show
    fx = -1
    _SOURCE ia
    FOR y = 0 TO SH * CH - 1
        FOR x = 0 TO SW * CW - 1
            IF POINT(x, y) <> PointOf~&(iorig, x, y) THEN
                diff = diff + 1
                IF fx < 0 THEN fx = x: fy = y
            END IF
        NEXT x
    NEXT y
    _SOURCE oldsrc: _DEST olddest
    _FREEIMAGE iorig: _FREEIMAGE ia: _FREEIMAGE ib
    _DEST _CONSOLE
    IF diff = 0 THEN
        PRINT PipeCol$("  |10VERIFIED lossless|07 -- layer-0 + layer-1 composites to the original, pixel for pixel")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(diff)) + " pixels differ|07 from the original (first at " + _TRIM$(STR$(fx)) + "," + _TRIM$(STR$(fy)) + ", cell " + _TRIM$(STR$(fx \ CW)) + "," + _TRIM$(STR$(fy \ CH)) + ")")
    END IF
END SUB


' POINT from a specific image without disturbing the caller's _SOURCE for the rest of a scan.
FUNCTION PointOf~& (img AS LONG, x AS INTEGER, y AS INTEGER)
    DIM s AS LONG
    s = _SOURCE: _SOURCE img
    PointOf~& = POINT(x, y)
    _SOURCE s
END FUNCTION

' Does this cell belong to the COLLISION layer?
'
' The first rule was "solid cells only" -- a full block or a space on that background -- on the
' theory that only whole-cell colour matters. That was wrong, and measurably: 36 secret-door and
' 266 door cells are painted as HALF blocks, so they fell into decoration and layer-0 had no
' door there at all. Movement already accepts those (CanMove tests diachromatic(floor, BROWN)
' and diachromatic(floor, BRIGHT_BLUE)), and DetectSecretDoors counts partial blue.
'
' So the rule is "does the cell CONTAIN a collision colour", and matching cells are copied
' VERBATIM rather than flattened to one colour. Flattening would destroy the second fact a
' two-coloured cell carries -- a floor+door cell is both walkable AND a doorway, and squashing
' it to plain brown would make InRoomNow stop seeing room floor there.
'
' Verbatim has a second benefit: layer-0 keeps the source's own encoding, so it renders in any
' ANSI viewer exactly as the board does. The earlier space-on-bright-background form needed a
' viewer that honours iCE bright backgrounds, and one that does not showed the yellow paths as
' brown -- fine for the game, confusing to hand-edit.
'
' TEXT GLYPHS are excluded whatever colour they sit on. That is the level plaques ("4th", "5th"):
' a block of level colour with letters on it, which is decoration wearing a floor colour.
FUNCTION CellIsCollision% (chcode AS INTEGER, f AS INTEGER, b AS INTEGER)
    ' `chcode`, not `c`: QB64 identifiers are case-insensitive and `c` is the shared CURSOR --
    ' a parameter named c would shadow it silently. tests/audit-shadow.sh catches exactly this.
    CellIsCollision% = 0
    IF NOT IsBlockGlyph%(chcode) THEN EXIT FUNCTION            ' lettering is never collision
    IF f <> 0 THEN
        IF IsCollisionIndex%(f) THEN CellIsCollision% = -1: EXIT FUNCTION
    END IF
    IF b <> 0 THEN
        IF IsCollisionIndex%(b) THEN CellIsCollision% = -1
    END IF
END FUNCTION

' Space, the full block, the four half blocks, and the three shade patterns -- the glyphs the
' board draws GEOMETRY with. Anything else is lettering.
FUNCTION IsBlockGlyph% (chcode AS INTEGER)
    SELECT CASE chcode
        CASE 32, 219, 220, 221, 222, 223, 176, 177, 178: IsBlockGlyph% = -1
        CASE ELSE: IsBlockGlyph% = 0
    END SELECT
END FUNCTION

' Is this palette index one the movement code treats as walkable -- a path, a door, a secret
' door, or one of the level floor colours?
FUNCTION IsCollisionIndex% (idx AS INTEGER)
    DIM s AS INTEGER
    IsCollisionIndex% = 0
    IF idx = PaletteIndex%(YELLOW) THEN IsCollisionIndex% = -1: EXIT FUNCTION
    IF idx = PaletteIndex%(BROWN) THEN IsCollisionIndex% = -1: EXIT FUNCTION
    IF idx = PaletteIndex%(BRIGHT_BLUE) THEN IsCollisionIndex% = -1: EXIT FUNCTION
    FOR s = 1 TO 9
        IF idx = PaletteIndex%(SECTORS(s).kolor) THEN IsCollisionIndex% = -1: EXIT FUNCTION
    NEXT s
END FUNCTION

' A palette colour -> its 0-15 index, via the SGR table so there is only one palette mapping
' in the codebase rather than a second copy that can drift from it.
FUNCTION PaletteIndex% (col AS _UNSIGNED LONG)
    DIM v AS INTEGER
    v = VAL(SGRForColor$(col))
    IF v >= 90 THEN PaletteIndex% = v - 90 + 8 ELSE PaletteIndex% = v - 30
END FUNCTION

' Write one layer + its SAUCE record. Refuses to clobber an existing file, like maskgen and
' sectorgen -- these are STARTERS to hand-tune, and silently overwriting hours of editing
' would be the worst thing a generator could do.
FUNCTION WriteAnsiLayer% (path AS STRING, body AS STRING, title AS STRING)
    DIM f AS INTEGER
    WriteAnsiLayer% = -1
    IF _FILEEXISTS(path) THEN
        PRINT PipeCol$("  |14skipped|07 " + path + " -- already exists (delete it to regenerate)")
        EXIT FUNCTION
    END IF
    f = FREEFILE
    OPEN path FOR OUTPUT AS #f
    PRINT #f, body;
    PRINT #f, CHR$(26);                                        ' EOF marker, then SAUCE
    PRINT #f, SauceRecord$(title, SW, SH - 1, LEN(body));
    CLOSE #f
    PRINT PipeCol$("  wrote |10" + path + "|07 (" + _TRIM$(STR$(LEN(body))) + " bytes of art)")
END FUNCTION


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
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE          ' what MOVEMENT sees -- see the note in RoomLint
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
    PRINT PipeCol$("  |08lvl  derived rect (c1,r1,c2,r2)   cells   in use")
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
' CellSolidSector% now lives in game/SECTOR.bas -- DeriveSectors uses it in production.


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
' The board's playable rectangle, measured by `sectorauto`: everything outside it -- the top
' frame, the right-hand border, the bottom legend, the logo -- is painted in level colours but
' is not map. ONE definition, because boardsplit and roomlint disagreeing about where the board
' ends made six frame strips report as LOST ROOMS that DetectRooms was never going to see (its
' own scan starts at row 1).
FUNCTION InPlayArea% (cx AS INTEGER, cy AS INTEGER)
    InPlayArea% = 0
    IF cx < 0 OR cx > 115 THEN EXIT FUNCTION
    IF cy < 1 OR cy > 47 THEN EXIT FUNCTION
    InPlayArea% = -1
END FUNCTION


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
                        ELSEIF m < 1 OR NOT InPlayArea%(minx, miny) OR NOT InPlayArea%(maxx, maxy) THEN
                            noMask = noMask + 1            ' outside the play area (frame / logo / legend art)
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


' ============================================================================
'  `dungeon.run eventsaudit sensory` -- SENSORY COVERAGE of the flavor text.
'
'  Prose that only ever describes what you SEE goes flat: a dungeon should also
'  sound, smell and feel like one. This reads every flavor pool and reports, per
'  pool, how many lines reach each of the five senses -- so a thin sense is a
'  number rather than a hunch.
'
'  Word lists are deliberately visible and editable below. This is a WRITING aid,
'  not a test: it never fails a build, and a low count is a prompt to look, not a
'  defect. Taste especially will always be low, and should be -- a line about
'  taste has to earn its place.
' ============================================================================
SUB EventsAuditSensory
    DIM i AS INTEGER
    DIM tot(1 TO 5) AS LONG, lines AS LONG, hit(1 TO 5) AS LONG, none AS LONG
    DIM sname(1 TO 5) AS STRING
    _DEST _CONSOLE
    sname(1) = "Sight": sname(2) = "Sound": sname(3) = "Touch": sname(4) = "Smell": sname(5) = "Taste"
    PRINT PipeCol$("|15events audit --sensory|07 -- which senses the flavor text actually reaches")
    PRINT

    SensoryPool "monster_events (all)", 1, tot(), lines, none
    SensoryPool "class_events (all)", 2, tot(), lines, none
    PRINT
    PRINT PipeCol$("  |08a line can reach more than one sense, so the percentages do not total 100")
END SUB

' Report one EVT category, and accumulate into the totals.
SUB SensoryPool (title AS STRING, cat AS INTEGER, tot() AS LONG, lines AS LONG, none AS LONG)
    ' `scount`, not `c` -- QB64 identifiers are case-insensitive and `c` is the shared CURSOR.
    ' tests/audit-shadow.sh caught this one the moment it was written.
    DIM i AS INTEGER, s AS INTEGER, n AS LONG, scount(1 TO 5) AS LONG, nn AS LONG, txt AS STRING
    DIM sname(1 TO 5) AS STRING, bar AS STRING, pc AS INTEGER
    sname(1) = "Sight": sname(2) = "Sound": sname(3) = "Touch": sname(4) = "Smell": sname(5) = "Taste"
    FOR i = 1 TO EVT_N
        IF EVT(i).cat = cat THEN
            n = n + 1
            txt = " " + LCASE$(_TRIM$(EVT(i).text)) + " "
            nn = 0
            FOR s = 1 TO 5
                IF SenseHit%(txt, s) THEN scount(s) = scount(s) + 1: nn = nn + 1
            NEXT s
            IF nn = 0 THEN none = none + 1
        END IF
    NEXT i
    PRINT PipeCol$("  |11" + title + "|07  (" + _TRIM$(STR$(n)) + " lines)")
    IF n = 0 THEN EXIT SUB
    FOR s = 1 TO 5
        pc = INT(scount(s) * 100 / n)
        ' ASCII bar: this goes to the terminal, and CHR$(254) is a CP437 block that a UTF-8
    ' console renders as mojibake. The grid font is not in play here.
    bar = STRING$(pc \ 4, 35)
        IF pc >= 25 THEN
            PRINT PipeCol$("     " + PadR$(sname(s), 7) + PadR$(_TRIM$(STR$(scount(s))), 5) + "|10" + PadR$(bar, 25) + "|07" + _TRIM$(STR$(pc)) + "%")
        ELSEIF pc >= 8 THEN
            PRINT PipeCol$("     " + PadR$(sname(s), 7) + PadR$(_TRIM$(STR$(scount(s))), 5) + "|14" + PadR$(bar, 25) + "|07" + _TRIM$(STR$(pc)) + "%")
        ELSE
            PRINT PipeCol$("     " + PadR$(sname(s), 7) + PadR$(_TRIM$(STR$(scount(s))), 5) + "|12" + PadR$(bar, 25) + "|07" + _TRIM$(STR$(pc)) + "%  <- thin")
        END IF
    NEXT s
END SUB

' Does this line reach sense `s` (1 Sight .. 5 Taste)? The word lists ARE the definition --
' edit them freely. Each word is matched with spaces around it, so "ear" cannot fire inside
' "heard" and "see" cannot fire inside "sees" unless "sees" is listed too.
FUNCTION SenseHit% (txt AS STRING, s AS INTEGER)
    DIM w AS STRING, lst AS STRING, p AS INTEGER, q AS INTEGER
    SELECT CASE s
        CASE 1: lst = "see sees saw seen sight look looks looking glint gleam shimmer flash dark darkness shadow shadows light vision blink blinks glance glancing red blood watch watching visage glow glowing"
        CASE 2: lst = "hear hears heard sound roar roars scream screams screaming shriek shrieks cry cries echo echoes echoing snarl growl growls hiss hisses silence shout shouts crack crash thud rattle whisper whispers"
        CASE 3: lst = "feel feels felt pain ache aches throb throbs cold heat hot burning grip grips shaking shiver shivering weight force impact sting stings raw numb wet soaked drenched touch clammy"
        CASE 4: lst = "smell smells stench reek reeks stink stinks rot rotting fetid acrid musty odour odor damp"
        CASE 5: lst = "taste tastes tasted salt salty bitter copper coppery mouth tongue swallow"
    END SELECT
    SenseHit% = 0
    lst = " " + lst + " "
    p = 1
    DO
        q = INSTR(p, lst, " ")
        IF q = 0 THEN EXIT DO
        p = q + 1
        q = INSTR(p, lst, " ")
        IF q = 0 THEN EXIT DO
        w = MID$(lst, p, q - p)
        IF LEN(w) > 0 THEN
            IF INSTR(txt, " " + w + " ") > 0 THEN SenseHit% = -1: EXIT FUNCTION
            IF INSTR(txt, " " + w + ",") > 0 THEN SenseHit% = -1: EXIT FUNCTION
            IF INSTR(txt, " " + w + ".") > 0 THEN SenseHit% = -1: EXIT FUNCTION
            IF INSTR(txt, " " + w + "!") > 0 THEN SenseHit% = -1: EXIT FUNCTION
            IF INSTR(txt, " " + w + ";") > 0 THEN SenseHit% = -1: EXIT FUNCTION
        END IF
        p = q
    LOOP
END FUNCTION



' ============================================================================
'  WALKLINT -- can the player ACTUALLY stand on every cell we call walkable?
'
'  roomlint counts cells by COLOUR (CellRoomKind%). That is not the same question as
'  "will CanMove let me stand here", which is what the player experiences -- and the
'  two drifted apart badly: Game_FloorColorAt~& probed only a cell's CENTRE pixel, so
'  every doorway whose centre landed on the brown half answered "not floor" and became
'  impassable. Every room was still reported enterable, because nothing asked CanMove.
'
'  So ask it. Park the cursor on each FLOOR and DOOR cell and call the real function.
' ============================================================================
SUB WalkLint
    DIM cx AS INTEGER, cy AS INTEGER, k AS INTEGER
    DIM savex AS INTEGER, savey AS INTEGER, oldsrc AS LONG
    DIM nfloor AS LONG, ndoor AS LONG, badfloor AS LONG, baddoor AS LONG
    DIM fx AS INTEGER, fy AS INTEGER
    savex = c.x: savey = c.y
    oldsrc = _SOURCE
    ' CanMove samples COLLIDE_BOARD, and this dev mode never runs InitFog -- so without this the
    ' board it reads is a blank image and EVERY cell reports unwalkable. Use the un-fogged
    ' collision board: this lints the MAP, not what the player has discovered.
    _PUTIMAGE (0, 0), FULL_COLLIDE, COLLIDE_BOARD
    fx = -1
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            k = ROOMKIND(cx, cy)
            IF k = CRK_FLOOR OR k = CRK_DOOR THEN
                c.x = cx * CW: c.y = cy * CH
                IF k = CRK_FLOOR THEN
                    nfloor = nfloor + 1
                    IF NOT CanMove% THEN badfloor = badfloor + 1: IF fx < 0 THEN fx = cx: fy = cy
                ELSE
                    ndoor = ndoor + 1
                    IF NOT CanMove% THEN baddoor = baddoor + 1: IF fx < 0 THEN fx = cx: fy = cy
                END IF
            END IF
        NEXT cx
    NEXT cy
    ' SECRET DOORS are a separate colour and are NOT part of any room block, so ROOMKIND never
    ' sees them -- they need testing by name. Tested against FULL_COLLIDE (the pristine board),
    ' because in play they are deliberately blacked out until found: the question here is
    ' "once revealed, can it be walked through", not "is it visible yet".
    DIM i AS INTEGER, nsec AS LONG, badsec AS LONG, sx AS INTEGER, sy AS INTEGER
    sx = -1
    FOR i = 1 TO SD_N
        c.x = SD_X(i) * CW: c.y = SD_Y(i) * CH
        nsec = nsec + 1
        IF NOT CanMove% THEN badsec = badsec + 1: IF sx < 0 THEN sx = SD_X(i): sy = SD_Y(i)
    NEXT i
    ' ...and every ORDINARY door, by name too: DetectDoors finds cells ROOMKIND may class as
    ' MIXED (a half-painted door in a wall), and those must still be passable.
    DIM nd AS LONG, badnd AS LONG, dx AS INTEGER, dy AS INTEGER
    dx = -1
    FOR i = 1 TO DOOR_N
        c.x = DOOR_X(i) * CW: c.y = DOOR_Y(i) * CH
        nd = nd + 1
        IF NOT CanMove% THEN badnd = badnd + 1: IF dx < 0 THEN dx = DOOR_X(i): dy = DOOR_Y(i)
    NEXT i
    c.x = savex: c.y = savey
    _SOURCE oldsrc
    _DEST _CONSOLE
    IF badfloor = 0 AND baddoor = 0 THEN
        PRINT PipeCol$("  |10CanMove agrees|07 -- all " + _TRIM$(STR$(nfloor)) + " floor and " + _TRIM$(STR$(ndoor)) + " doorway cells are actually walkable")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(badfloor)) + " floor + " + _TRIM$(STR$(baddoor)) + " doorway cell(s) are NOT walkable|07 (first at " + _TRIM$(STR$(fx)) + "," + _TRIM$(STR$(fy)) + ")")
        PRINT PipeCol$("     |14the map says you can stand there and CanMove says you cannot -- the player is walled in")
    END IF
    IF badsec = 0 THEN
        PRINT PipeCol$("  |10all " + _TRIM$(STR$(nsec)) + " secret doors|07 are passable once revealed")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(badsec)) + " of " + _TRIM$(STR$(nsec)) + " SECRET DOORS are not passable|07 (first at " + _TRIM$(STR$(sx)) + "," + _TRIM$(STR$(sy)) + ")")
        PRINT PipeCol$("     |14searching would reveal a door the player still cannot walk through")
    END IF
    IF badnd = 0 THEN
        PRINT PipeCol$("  |10all " + _TRIM$(STR$(nd)) + " detected doors|07 are passable")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(badnd)) + " of " + _TRIM$(STR$(nd)) + " DOORS are not passable|07 (first at " + _TRIM$(STR$(dx)) + "," + _TRIM$(STR$(dy)) + ")")
    END IF
END SUB


' ============================================================================
'  `dungeon.run placeholders` -- fill every MISSING art asset with a labelled stand-in.
'
'  Missing art is currently INVISIBLE: DrawSpriteFit% silently draws nothing, so a
'  subject with no picture looks identical to a subject that was never meant to have
'  one. A placeholder makes the gap loud, at exactly the right size, and lets the game
'  be played and laid out before the render farm has run.
'
'  Runs the image manifest in AUDIT mode (missing only) and writes each entry at the
'  size the manifest asks for: a PNG for pixel-art, a real .ans for ansi-art. Never
'  overwrites -- if a file exists, it is not missing, and the audit will not list it.
' ============================================================================
SUB MakePlaceholders
    DIM i AS INTEGER, ln AS STRING, pth AS STRING, sz AS STRING, made AS LONG
    DIM f1 AS INTEGER, f2 AS INTEGER, nm AS STRING
    _DEST _CONSOLE
    PRINT PipeCol$("|15placeholders|07 -- writing a labelled stand-in for every missing art asset")
    ' Do NOT clear the list first. The audit treats listed paths as missing, so wiping it makes
    ' existing placeholders look like real art -- the audit then reports 0 missing, nothing gets
    ' written, and the list stays empty. Re-running the tool destroyed its own tracking.
    man_audit = TRUE: man_quiet = TRUE           ' build the list, print nothing, keep the buffer
    DumpImageManifest                            ' fills MAN_BUF with ONLY the missing entries
    man_quiet = FALSE
    FOR i = 1 TO MAN_N
        ln = MAN_BUF(i)
        IF LEFT$(ln, 1) <> "#" AND LEN(_TRIM$(ln)) > 0 THEN
            f1 = INSTR(ln, "|")
            IF f1 > 0 THEN
                pth = _TRIM$(LEFT$(ln, f1 - 1))
                f2 = INSTR(f1 + 1, ln, "|")
                IF f2 > 0 THEN
                    sz = _TRIM$(MID$(ln, f2 + 1, INSTR(f2 + 1, ln, "|") - f2 - 1))
                    nm = MID$(pth, _INSTRREV(pth, "/") + 1)
                    IF _INSTRREV(nm, ".") > 0 THEN nm = LEFT$(nm, _INSTRREV(nm, ".") - 1)
                    IF RIGHT$(LCASE$(pth), 4) = ".ans" THEN
                        IF WritePlaceholderAns%(pth, sz, nm) THEN made = made + 1
                    ELSE
                        IF WritePlaceholderPng%(pth, sz, nm) THEN made = made + 1
                    END IF
                END IF
            END IF
        END IF
    NEXT i
    MAN_N = 0
    PRINT PipeCol$("  wrote |10" + _TRIM$(STR$(made)) + "|07 placeholder(s), listed in |14" + PLACEHOLDER_LIST + "|07")
    PRINT PipeCol$("  they still report as |14MISSING|07 in the audit -- a stand-in is a reminder,")
    PRINT PipeCol$("  not an asset, so the work list stays honest while the game stops showing holes.")
    PRINT PipeCol$("  |08dungeon.run placeholders clean|07 removes them when the real art lands.")
END SUB

' Delete every placeholder this tool wrote, using the manifest it kept. A LIST is the honest
' way to do it: a PNG carries no marker saying "I am a stand-in", so guessing from content
' would eventually delete somebody's real art.
SUB CleanPlaceholders
    DIM f AS INTEGER, ln AS STRING, n AS LONG, gone AS LONG
    _DEST _CONSOLE
    PRINT PipeCol$("|15placeholders clean|07 -- removing the stand-ins so the audit tells the truth")
    IF NOT _FILEEXISTS(PLACEHOLDER_LIST) THEN
        PRINT PipeCol$("  |10nothing to clean|07 (no " + PLACEHOLDER_LIST + ")")
        EXIT SUB
    END IF
    f = FREEFILE
    OPEN PLACEHOLDER_LIST FOR INPUT AS #f
    DO UNTIL EOF(f)
        LINE INPUT #f, ln
        ln = _TRIM$(ln)
        IF LEN(ln) > 0 THEN
            n = n + 1
            IF _FILEEXISTS(ln) THEN KILL ln: gone = gone + 1
        END IF
    LOOP
    CLOSE #f
    KILL PLACEHOLDER_LIST
    PRINT PipeCol$("  deleted |10" + _TRIM$(STR$(gone)) + "|07 of " + _TRIM$(STR$(n)) + " listed placeholder(s)")
END SUB

' Append a written placeholder to the list, so `placeholders clean` can find it again.
SUB NotePlaceholder (full AS STRING)
    DIM f AS INTEGER
    IF IsPlaceholder%(full) THEN EXIT SUB        ' already tracked -- never list one twice
    f = FREEFILE
    OPEN PLACEHOLDER_LIST FOR APPEND AS #f
    PRINT #f, full
    CLOSE #f
    IF PH_N < UBOUND(PH_PATH) THEN PH_N = PH_N + 1: PH_PATH(PH_N) = full   ' keep the cache in step
END SUB

' A placeholder PNG: a dashed frame, a diagonal, and the subject name, at the asked-for size.
FUNCTION WritePlaceholderPng% (pth AS STRING, sz AS STRING, nm AS STRING)
    DIM img AS LONG, d AS INTEGER, prevdest AS LONG, full AS STRING, lbl AS STRING
    WritePlaceholderPng% = 0
    d = VAL(sz): IF d < 16 THEN d = 128
    full = "assets/" + PlaceholderPackPath$(pth)
    IF _FILEEXISTS(full) THEN EXIT FUNCTION
    img = _NEWIMAGE(d, d, 32)
    IF img >= -1 THEN EXIT FUNCTION
    prevdest = _DEST: _DEST img
    CLS , _RGBA32(0, 0, 0, 0)                    ' transparent, like the real item art
    LINE (1, 1)-(d - 2, d - 2), _RGB32(&HFF, &H00, &HFF), B
    LINE (1, 1)-(d - 2, d - 2), _RGB32(&H80, &H00, &H80)
    _FONT 8
    COLOR _RGB32(&HFF, &HFF, &H55), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (4, 4), "PLACEHOLDER"
    lbl = nm
    IF LEN(lbl) * 8 > d - 8 THEN lbl = LEFT$(lbl, (d - 8) \ 8)
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (4, d - 12), lbl
    _DEST prevdest
    _SAVEIMAGE full, img
    _FREEIMAGE img
    NotePlaceholder full
    WritePlaceholderPng% = -1
END FUNCTION

' A placeholder .ans: a magenta box of exactly the asked-for character size with the subject
' name inside, plus a SAUCE record so AnsiSprite& reads the right dimensions back.
FUNCTION WritePlaceholderAns% (pth AS STRING, sz AS STRING, nm AS STRING)
    DIM cols AS INTEGER, rows AS INTEGER, xp AS INTEGER, cx AS INTEGER, cy AS INTEGER
    DIM body AS STRING, full AS STRING, lbl AS STRING, f AS INTEGER, glyph AS STRING   ' `glyph`, not `ch`: CH is the shared font-cell height
    WritePlaceholderAns% = 0
    xp = INSTR(sz, "x")
    IF xp > 0 THEN cols = VAL(LEFT$(sz, xp - 1)): rows = VAL(MID$(sz, xp + 1))
    IF cols < 2 THEN cols = 18
    IF rows < 2 THEN rows = 12
    full = "assets/" + PlaceholderPackPath$(pth)
    IF _FILEEXISTS(full) THEN EXIT FUNCTION
    lbl = LEFT$(nm, cols - 2)
    body = CHR$(27) + "[0;1;35m"                 ' bright magenta -- unmistakably not real art
    FOR cy = 0 TO rows - 1
        FOR cx = 0 TO cols - 1
            IF cy = 0 OR cy = rows - 1 OR cx = 0 OR cx = cols - 1 THEN
                glyph = CHR$(219)
            ELSEIF cy = rows \ 2 AND cx >= 1 AND cx - 1 < LEN(lbl) THEN
                glyph = MID$(lbl, cx, 1)
            ELSE
                glyph = " "
            END IF
            body = body + glyph
        NEXT cx
    NEXT cy
    f = FREEFILE
    OPEN full FOR BINARY AS #f
    PUT #f, 1, body
    glyph = CHR$(26): PUT #f, , glyph
    glyph = SauceRecord$("PLACEHOLDER " + nm, cols, rows, LEN(body)): PUT #f, , glyph
    CLOSE #f
    NotePlaceholder full
    WritePlaceholderAns% = -1
END FUNCTION

' Manifest paths are pack-less ("pixel-art/items/sword.png"); placeholders go in the DEFAULT
' pack, which every other pack falls back to -- so one placeholder covers every pack at once.
FUNCTION PlaceholderPackPath$ (pth AS STRING)
    DIM sl AS INTEGER
    sl = INSTR(pth, "/")
    IF sl <= 0 THEN PlaceholderPackPath$ = pth: EXIT FUNCTION
    PlaceholderPackPath$ = LEFT$(pth, sl) + "default/" + MID$(pth, sl + 1)
END FUNCTION
