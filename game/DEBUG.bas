' ============================================================================
'  DEBUG.bas -- the GAME's development overlay + cheat panel.
'
'  [~] (or backtick) toggles the overlay: region/sector/chamber tints and a mouse
'  readout; with it on, left-click teleports the player and [0] opens the cheat
'  panel (spawn a curio/wanderer/trap, grant items + Level Key, potions, heal,
'  gold, reveal all secret doors, set up a win).
'
'  This lives in game/ because it is a dev tool for THIS game: every panel row
'  grants a DUNGEON! item, and the readout names ROOMS / CHAMBERAT / SECTORAT.
'  A different game on this engine would write its own. It freely READS engine
'  state (SD_*/MASKREG/DOOR_REGION/FOGHIDE) and calls engine primitives -- the
'  sanctioned game->engine direction. Moved out of engine/BOARD.bas, which had
'  ~190 lines here naming a dozen game symbols.
'
'  dungeon.bas drives it: `IF dbg_on AND k = "0" THEN DebugTestMenu` in the play
'  loop, and `IF dbg_on THEN DrawDebug` in the render pass -- so no engine->game
'  hook is needed at all; the assembly calls it, not the engine.
' ============================================================================

' Repaint the board after a debug action takes over the screen.
SUB DebugMenuClose
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB

' [~] debug -> press [0] to open this cheat/test panel: spawn encounters, grant
' items/potions/HP/gold/key, reveal doors, set up a win. Left-click the board while
' [~] is on teleports the player. For fast playtesting without grinding there.
SUB DebugTestMenu
    DIM k AS STRING, done AS INTEGER, msg AS STRING, rm AS INTEGER, i AS INTEGER
    DIM bg AS _UNSIGNED LONG
    bg = _RGB32(&H00, &H00, &H30)
    DO
        _LIMIT 60
        _DEST CANVAS
        LINE (30 * CW, 7 * CH)-(102 * CW, 42 * CH), bg, BF
        LINE (30 * CW, 7 * CH)-(102 * CW, 42 * CH), CYANU, B
        COLOR YELLOWU, bg: PrintCentered 8, "-=  D E B U G   T E S T   M E N U  =-"
        COLOR WHITE, bg
        _PRINTSTRING (34 * CW, 11 * CH), "1   Spawn a CURIO here"
        _PRINTSTRING (34 * CW, 13 * CH), "2   Fight a wandering MONSTER (this level)"
        _PRINTSTRING (34 * CW, 15 * CH), "3   Spring a TRAP"
        _PRINTSTRING (34 * CW, 17 * CH), "4   Grant ALL items + the Level Key"
        _PRINTSTRING (34 * CW, 19 * CH), "5   +3 small & +3 large POTIONS"
        _PRINTSTRING (34 * CW, 21 * CH), "6   Heal to FULL"
        _PRINTSTRING (34 * CW, 23 * CH), "7   +5000 GOLD"
        _PRINTSTRING (34 * CW, 25 * CH), "8   Reveal ALL secret doors (+ key)"
        _PRINTSTRING (34 * CW, 27 * CH), "9   WIN-READY (goal gold + key; walk to START)"
        COLOR GREY, bg: _PRINTSTRING (34 * CW, 33 * CH), "left-click the board (with [~] on) = teleport the player"
        COLOR YELLOWU, bg: PrintCentered 35, "[ESC] close"
        IF LEN(msg) > 0 THEN COLOR GREENU, bg: PrintCentered 38, msg
        _DISPLAY
        k = INKEY$
        rm = ROOMAT(c.x \ CW, c.y \ CH)
        SELECT CASE k
            CASE "1": DebugMenuClose: DoCurio 0: EXIT SUB
            CASE "2": DebugMenuClose: WanderEncounter: EXIT SUB
            CASE "3": DebugMenuClose: SpringTrap rm: EXIT SUB
            CASE "4"
                item_sword = 1: item_secret_card = -1: item_esp = -1: item_crystal = -1
                item_bow = -1: item_boots = -1: item_teleport = item_teleport + 3: has_key = -1
                msg = "granted: sword+1, secret card, ESP, crystal, bow, boots, 3 scrolls, KEY"
            CASE "5": item_potion_small = item_potion_small + 3: item_potion_large = item_potion_large + 3: msg = "potions +3 small / +3 large"
            CASE "6": player_hp = player_maxhp: msg = "healed to full (" + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + ")"
            CASE "7": gold = gold + 5000: msg = "gold now " + _TRIM$(STR$(gold))
            CASE "8"
                FOR i = 1 TO SD_N
                    IF NOT SD_FOUND(i) THEN SD_FOUND(i) = -1: RevealRegionFromDoor i
                NEXT i
                has_key = -1: msg = "all secret doors revealed + Level Key granted"
            CASE "9": gold = target_gold: has_key = -1: msg = "win-ready: " + _TRIM$(STR$(gold)) + " gold + key -- return to START"
            CASE CHR$(27): done = -1
        END SELECT
    LOOP UNTIL done
    DebugMenuClose
END SUB

SUB DrawDebug
    DIM cx AS INTEGER, cy AS INTEGER, sec AS INTEGER, i AS INTEGER
    DIM onpath AS INTEGER, inroom AS INTEGER, ondoor AS INTEGER, onsecret AS INTEGER, nearsd AS INTEGER
    DIM img AS LONG, el AS LONG, bg AS _UNSIGNED LONG
    DIM mx AS INTEGER, my AS INTEGER, mcx AS INTEGER, mcy AS INTEGER, kind AS INTEGER, kn AS STRING
    DIM fought AS STRING, died AS STRING, boss AS STRING, loot AS STRING, oldsrc AS LONG
    cx = c.x \ CW: cy = c.y \ CH
    sec = SECTOR.get_by_xy(c.x, c.y)
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    onpath = image_is_monochromatic(img, YELLOW)
    onsecret = image_is_monochromatic(img, BRIGHT_BLUE)
    _FREEIMAGE img
    inroom = InRoomNow
    ondoor = OnDoorNow
    FOR i = 1 TO SD_N
        IF NOT SD_FOUND(i) THEN
            IF ABS(SD_X(i) - cx) <= 2 AND ABS(SD_Y(i) - cy) <= 2 THEN nearsd = -1
        END IF
    NEXT i
    ' current room flags (the room block under the cursor)
    DIM rmid AS INTEGER
    rmid = ROOMAT(cx, cy)
    IF rmid >= 1 THEN
        fought = YN$(ROOMS(rmid).monster_fought): died = YN$(ROOMS(rmid).player_died)
        boss = YN$(ROOMS(rmid).is_boss): loot = YN$(ROOMS(rmid).looted)
    ELSE
        fought = "-": died = "-": boss = "-": loot = "-"
    END IF
    ' mouse crosshair inspector -- drain queued mouse events, sample the cell under it
    DO WHILE _MOUSEINPUT: LOOP
    mx = _MOUSEX: my = _MOUSEY
    mcx = mx \ CW: mcy = my \ CH
    ' click-to-place: a left-click teleports the player to the moused cell (debug testing)
    IF _MOUSEBUTTON(1) THEN
        IF dbg_click_armed = 0 THEN
            IF mcx >= 0 AND mcx <= SW - 1 AND mcy >= 0 AND mcy <= SH - 1 THEN
                c.x = mcx * CW: c.y = mcy * CH: c.prev_x = c.x: c.prev_y = c.y
            END IF
            dbg_click_armed = -1
        END IF
    ELSE
        dbg_click_armed = 0
    END IF
    oldsrc = _SOURCE: _SOURCE CANVAS_COPY
    kind = CellKind(mcx, mcy)
    _SOURCE oldsrc
    SELECT CASE kind
        CASE 1: kn = "OPEN"
        CASE 2: kn = "SECRET"
        CASE ELSE: kn = "WALL"
    END SELECT
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    bg = _RGB32(&H00, &H00, &H40)
    _DEST CANVAS
    ' crosshair through the mouse pointer
    LINE (mx, 0)-(mx, SH * CH - 1), _RGB32(&H00, &HFF, &H00)
    LINE (0, my)-(SW * CW - 1, my), _RGB32(&H00, &HFF, &H00)
    LINE (0, 0)-(52 * CW, 6 * CH), bg, BF
    LINE (0, 0)-(52 * CW, 6 * CH), CYANU, B
    COLOR YELLOWU, bg
    _PRINTSTRING (1 * CW, 0 * CH), "DEBUG [~]  [0]=test menu  click=teleport   px " + _TRIM$(STR$(c.x)) + "," + _TRIM$(STR$(c.y)) + "   cell " + _TRIM$(STR$(cx)) + "," + _TRIM$(STR$(cy))
    _PRINTSTRING (1 * CW, 1 * CH), "sector " + _TRIM$(STR$(sec)) + "   moves " + _TRIM$(STR$(moves_made)) + "   time " + MMSS$(el)
    _PRINTSTRING (1 * CW, 2 * CH), "path:" + YN$(onpath) + " room:" + YN$(inroom) + " onDoor:" + YN$(ondoor) + " nearRD:" + YN$(NearRegularDoor) + " nearStr:" + YN$(NearStrongDoor) + " nearSD:" + YN$(nearsd)
    _PRINTSTRING (1 * CW, 3 * CH), "room " + _TRIM$(STR$(rmid)) + "/" + _TRIM$(STR$(ROOM_N)) + "  fought:" + fought + " died:" + died + " boss:" + boss + " looted:" + loot
    _PRINTSTRING (1 * CW, 4 * CH), "doors:" + _TRIM$(STR$(SD_N)) + "  key:" + YN$(has_key) + "  sword:+" + _TRIM$(STR$(item_sword)) + "  realdice:" + YN$(opt_realdice)
    _PRINTSTRING (1 * CW, 5 * CH), "mouse px " + _TRIM$(STR$(mx)) + "," + _TRIM$(STR$(my)) + "  cell " + _TRIM$(STR$(mcx)) + "," + _TRIM$(STR$(mcy)) + "  " + kn + "  cham:" + _TRIM$(STR$(CHAMBERAT(mcx, mcy))) + " dead:" + _TRIM$(STR$(ChamberDeadAt%(mcx, mcy))) + " sec:" + _TRIM$(STR$(SECTOR.get_by_xy(mcx * CW, mcy * CH))) + " fh:" + YN$(FOGHIDE(mcx, mcy)) + MaskHoverInfo$(mcx, mcy)
    '--- SECTOR overlay. With a sector mask (SECTORMASK_ON) each cell is tinted by its
    '    level colour, read straight from SECTORAT (0-based cells -- SAME coords as the
    '    mouse readout / chambers / mask, no unique -1 offset). Without a mask it falls
    '    back to drawing the sectors.txt rects (which ARE 1-based, hence the -1 there).
    DIM sx2 AS INTEGER, sy2 AS INTEGER, ex2 AS INTEGER, ey2 AS INTEGER, lxp AS INTEGER, lyp AS INTEGER
    DIM scx AS INTEGER, scy AS INTEGER, sid AS INTEGER, sk AS _UNSIGNED LONG
    IF SECTORMASK_ON THEN
        FOR scy = 0 TO SH - 1
            FOR scx = 0 TO SW - 1
                sid = SECTORAT(scx, scy)
                IF sid > 0 THEN
                    sk = SECTORS(sid).kolor
                    LINE (scx * CW, scy * CH)-(scx * CW + CW - 1, scy * CH + CH - 1), _RGBA32(_RED32(sk), _GREEN32(sk), _BLUE32(sk), 60), BF
                END IF
            NEXT scx
        NEXT scy
    ELSE
        FOR i = 1 TO 9
            sx2 = (SECTORS(i).start_x - 1) * CW: sy2 = (SECTORS(i).start_y - 1) * CH
            ex2 = (SECTORS(i).end_x - 1) * CW: ey2 = (SECTORS(i).end_y - 1) * CH
            LINE (sx2, sy2)-(ex2, ey2), SECTORS(i).kolor, B
            COLOR SECTORS(i).kolor, BLACK: _PRINTSTRING (sx2 + 2, sy2 + 1), "S" + _TRIM$(STR$(i))
        NEXT i
    END IF
    FOR i = 1 TO LBL_N
        lxp = LBL_X(i) * CW: lyp = LBL_Y(i) * CH + CH \ 2
        LINE (lxp - 3, lyp)-(lxp + 3, lyp), _RGB32(&HFF, &H00, &HFF)
        LINE (lxp + CW \ 2, lyp - 3)-(lxp + CW \ 2, lyp + 3), _RGB32(&HFF, &H00, &HFF)
    NEXT i
    LINE (START_CX * CW, START_CY * CH)-(START_CX * CW + CW - 1, START_CY * CH + CH - 1), WHITE, B
    '--- CHAMBER trigger overlay: every cell that fires a chamber encounter (CHAMBERAT > 0),
    '    tinted translucent so the art shows through. MAGENTA = still spawning monsters,
    '    GREEN = cleared (3 graves). NOTE: the + crosses above are label SEEDS, not this.
    '    (local is 'cham', never 'ch' -- 'ch' would shadow the shared font-height CH.)
    DIM chx AS INTEGER, chy AS INTEGER, cham AS INTEGER, tint AS _UNSIGNED LONG
    FOR chy = 0 TO 60
        FOR chx = 0 TO 131
            cham = CHAMBERAT(chx, chy)
            IF cham > 0 THEN
                IF CHM_DEAD(cham) >= 3 THEN tint = _RGBA32(&H00, &HFF, &H00, 55) ELSE tint = _RGBA32(&HFF, &H00, &HFF, 70)
                LINE (chx * CW, chy * CH)-(chx * CW + CW - 1, chy * CH + CH - 1), tint, BF
            END IF
            IF FOGHIDE(chx, chy) THEN                        ' ORANGE = a cell force-blacked by fog-hide.txt
                LINE (chx * CW, chy * CH)-(chx * CW + CW - 1, chy * CH + CH - 1), _RGBA32(&HFF, &HA0, &H00, 150), BF
            END IF
            IF MASK_ON THEN                                  ' each secret-mask REGION its own tint
                IF MASKREG(chx, chy) > 0 THEN LINE (chx * CW, chy * CH)-(chx * CW + CW - 1, chy * CH + CH - 1), MaskRegionColor~&(MASKREG(chx, chy), 130), BF
            END IF
        NEXT chx
    NEXT chy
    IF MASK_ON THEN DrawMaskDoors                        ' secret-door markers (level-coloured; red = unmapped)
END SUB

' Overlay the secret doors on the [~] mask view: a box per door, coloured by nesting level
' (green = level-1 entry, cyan = nested/deeper, RED = unmapped -> reveals nothing), with the
' level digit drawn in it. Lets you spot dead doors and see the secret-in-secret structure.
' Mask readout for the [~] mouse line: region id + its level at the hovered cell, and
' (if the cell is a secret door) which region it opens. Empty when no mask is loaded.
FUNCTION MaskHoverInfo$ (mcx AS INTEGER, mcy AS INTEGER)
    IF NOT MASK_ON THEN MaskHoverInfo$ = "": EXIT FUNCTION
    DIM s AS STRING, rg AS INTEGER, i AS INTEGER
    rg = MASKREG(mcx, mcy)
    s = "  reg:" + _TRIM$(STR$(rg))
    IF rg > 0 THEN s = s + " lvl:" + _TRIM$(STR$(MASKLVL(rg)))
    FOR i = 1 TO SD_N
        IF SD_X(i) = mcx AND SD_Y(i) = mcy THEN s = s + " door->" + _TRIM$(STR$(DOOR_REGION(i))): EXIT FOR
    NEXT i
    MaskHoverInfo$ = s
END FUNCTION