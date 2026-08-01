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
        _PRINTSTRING (34 * CW, 29 * CH), "T   TACTICAL FIGHT vs 4 foes (this level)  [F]=1 foe"
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
            CASE "T", "F"
                ' Jump straight into the tactical screen from play, so it can be exercised in
                ' situ (real class, real HP, real level) rather than only via `fightshot`.
                DebugMenuClose
                DebugStartFight k
                EXIT SUB
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
' `dungeon.run fightlayout` -- render every named region of the tactical-combat layout as a
' labelled, kind-coloured box to fightlayout.png, and LINT the layout to the console.
'
' Why a PNG dump instead of just eyeballing the numbers: placement is a visual problem, and the
' alternative is running a fight to see whether a box lands where you meant. This renders the
' whole screen description in a second, with no combat, no monsters, no fight code -- so the
' layout can be iterated against the hand-drawn art while the fight itself is still being built.
' (Same reason `settingsshot` exists for the SETTINGS grid.)
'
' The lint half matters more than the picture: a region running past the screen edge, or two
' regions silently overlapping, produces art that is authored correctly and still draws wrong.
' Nothing on screen would tell you which of the two it was.
SUB DumpFightLayout
    DIM i AS INTEGER, j AS INTEGER, img AS LONG, kol AS _UNSIGNED LONG
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER
    DIM scw AS INTEGER, sch AS INTEGER, lbl AS STRING
    DIM oob AS INTEGER, overlaps AS INTEGER, prevdest AS LONG

    _DEST _CONSOLE
    IF LoadLayout%("assets/data/ui-fight-layout.txt", 8, 8) = 0 THEN
        PRINT PipeCol$("|12fightlayout: assets/data/ui-fight-layout.txt is missing or empty.|07")
        EXIT SUB
    END IF
    PRINT PipeCol$("|15fightlayout|07 -- " + LTRIM$(STR$(LAY_N)) + " regions from |11assets/data/ui-fight-layout.txt|07")

    IF LayHas%("screen") THEN
        scw = LayCols%("screen"): sch = LayRows%("screen")
    ELSE
        scw = 132: sch = 100
        PRINT PipeCol$("|14  WARN|07 no 'screen' region -- assuming 132x100")
    END IF
    PRINT PipeCol$("  screen |15" + LTRIM$(STR$(scw)) + "x" + LTRIM$(STR$(sch)) + "|07 cells @8x8 = |15" + _
                   LTRIM$(STR$(scw * 8)) + "x" + LTRIM$(STR$(sch * 8)) + "|07 px")
    PRINT

    '--- lint: every region must fit entirely inside the screen -------------------
    FOR i = 1 TO LAY_N
        IF _TRIM$(LAY_NAME(i)) <> "screen" THEN
            IF LAY_COL(i) < 0 OR LAY_ROW(i) < 0 OR LAY_COL(i) + LAY_W(i) > scw OR LAY_ROW(i) + LAY_H(i) > sch THEN
                PRINT PipeCol$("|12  !! OFF-SCREEN|07 " + _TRIM$(LAY_NAME(i)) + " at " + _
                      LTRIM$(STR$(LAY_COL(i))) + "," + LTRIM$(STR$(LAY_ROW(i))) + " size " + _
                      LTRIM$(STR$(LAY_W(i))) + "x" + LTRIM$(STR$(LAY_H(i))))
                oob = oob + 1
            END IF
            IF LAY_W(i) <= 0 OR LAY_H(i) <= 0 THEN
                PRINT PipeCol$("|12  !! ZERO SIZE|07 " + _TRIM$(LAY_NAME(i)))
                oob = oob + 1
            END IF
        END IF
    NEXT i

    '--- lint: overlapping ART regions ------------------------------------------
    ' Only `art` is checked. text/box/bar regions overlap on purpose (a `box` frame contains
    ' the text it frames), but two art regions sharing cells means one portrait paints over
    ' another -- always a mistake, and one that looks like a draw-order bug in play.
    FOR i = 1 TO LAY_N
        IF LAY_KIND(i) = "art" THEN
            FOR j = i + 1 TO LAY_N
                IF LAY_KIND(j) = "art" THEN
                    IF LAY_COL(i) < LAY_COL(j) + LAY_W(j) AND LAY_COL(j) < LAY_COL(i) + LAY_W(i) THEN
                        IF LAY_ROW(i) < LAY_ROW(j) + LAY_H(j) AND LAY_ROW(j) < LAY_ROW(i) + LAY_H(i) THEN
                            PRINT PipeCol$("|12  !! ART OVERLAP|07 " + _TRIM$(LAY_NAME(i)) + " / " + _TRIM$(LAY_NAME(j)))
                            overlaps = overlaps + 1
                        END IF
                    END IF
                END IF
            NEXT j
        END IF
    NEXT i

    '--- the picture -------------------------------------------------------------
    prevdest = _DEST
    img = _NEWIMAGE(scw * 8, sch * 8, 32)
    _DEST img
    _FONT 8                                  ' the 8x8 built-in -- one glyph per layout cell
    CLS , _RGB32(16, 16, 24)

    FOR i = 1 TO LAY_N
        IF _TRIM$(LAY_NAME(i)) = "screen" THEN GOTO nextRgn
        bx = LAY_COL(i) * 8: by = LAY_ROW(i) * 8
        bw = LAY_W(i) * 8: bh = LAY_H(i) * 8
        IF bw < 1 OR bh < 1 THEN GOTO nextRgn
        kol = LayKindColor~&(LAY_KIND(i))
        LINE (bx, by)-(bx + bw - 1, by + bh - 1), kol, B
        ' A tinted fill on `art` regions so the portrait slots read at a glance.
        IF LAY_KIND(i) = "art" THEN LINE (bx + 1, by + 1)-(bx + bw - 2, by + bh - 2), _RGB32(0, 40, 56), BF
        lbl = _TRIM$(LAY_NAME(i))
        IF LEN(lbl) * 8 > bw - 2 THEN lbl = LEFT$(lbl, (bw - 2) \ 8)
        IF LEN(lbl) > 0 THEN _PRINTSTRING (bx + 1, by + 1), lbl, img
        nextRgn:
    NEXT i

    _SAVEIMAGE "fightlayout.png", img
    _DEST prevdest
    _FREEIMAGE img

    PRINT
    IF oob = 0 AND overlaps = 0 THEN
        PRINT PipeCol$("|10fightlayout: clean|07 -- every region fits, no art overlaps.")
    ELSE
        PRINT PipeCol$("|12fightlayout: " + LTRIM$(STR$(oob)) + " off-screen/zero, " + _
              LTRIM$(STR$(overlaps)) + " art overlap(s).|07")
    END IF
    PRINT PipeCol$("wrote |11fightlayout.png|07 (" + LTRIM$(STR$(scw * 8)) + "x" + LTRIM$(STR$(sch * 8)) + _
                   ") -- |08art=cyan text=white box=grey bar=green menu=yellow log=magenta|07")
END SUB

' Region outline colour by `kind`, so the dump is readable without a legend lookup.
FUNCTION LayKindColor~& (kind AS STRING)
    SELECT CASE kind
        CASE "art": LayKindColor~& = _RGB32(0, 220, 255)
        CASE "text": LayKindColor~& = _RGB32(230, 230, 230)
        CASE "box": LayKindColor~& = _RGB32(110, 110, 120)
        CASE "bar": LayKindColor~& = _RGB32(0, 230, 90)
        CASE "menu": LayKindColor~& = _RGB32(255, 210, 0)
        CASE "log": LayKindColor~& = _RGB32(230, 0, 230)
        CASE ELSE: LayKindColor~& = _RGB32(255, 60, 60)      ' unknown kind -- red, so it stands out
    END SELECT
END FUNCTION

' `dungeon.run fightshot` -- seed a synthetic 1-vs-4 encounter and render the tactical screen
' to fightshot.png, then exit.
'
' This is the counterpart to `fightlayout`: that one proves the BOXES are in the right places,
' this one proves the RENDERER puts real content in them -- portraits, health colours, the
' dead-actor dim, the target highlight, stat/status rows, the log gutter. Neither needs a
' fight to exist, which is the point: the screen and the art can be finished before a single
' line of combat resolution is written, and regressions show up in a PNG instead of a
' play-test. (Same trick as `settingsshot`.)
'
' The values are REPRESENTATIVE, not a real encounter -- deliberately picked to exercise every
' visual branch at once: a full-health foe, a wounded one (yellow), a nearly-dead one (red),
' and a corpse (dimmed), with the third selected as the target.
' `dungeon.run charsheet` -- render the [C] CHARACTER sheet with a MAXED-OUT hero and write
' charsheet.png, then exit. The sheet's layout only breaks when it is FULL: every line used to
' be centred on the whole 132-column screen rather than the panel, which is invisible with a
' short name and no items and runs off both panel edges (and straight across the class
' portrait) once the hero is carrying everything. A shot at default state proves nothing, so
' this deliberately seeds the worst case: long name, every item, a big treasure log.
SUB DumpCharSheet
    DIM i AS INTEGER, n AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15charsheet|07 -- seeding a fully-kitted hero (worst case for the layout)")
    DevPackOverride
    player_name = "Higgs the Unluckiest of All"
    player_class = 1: class_name = _TRIM$(CLASSES(1).name)
    char_level = 5: char_xp = 1150
    player_str = 18: player_int = 6: player_wis = 6: player_dex = 18: player_con = 18: player_cha = 6
    player_hp = 68: player_maxhp = 74
    player_tohit = 6: player_ac = 19: player_dmgdie = 8: player_dmgbonus = 4
    gold = 97275: target_gold = 10000: has_key = 0: key_level = 6
    ' every item at once -- the MAGIC: line is the one that overflowed
    item_sword = 1: item_armor = 3: item_shield = 2: item_bow = -1: item_boots = -1
    item_teleport = 1: item_potion_small = 6: item_potion_large = 2
    item_secret_card = -1: item_esp = -1: item_crystal = -1
    spell_fire = 3: spell_bolt = 3
    cur_player = 1: LOOT_N(1) = 0
    FOR i = 1 TO 50                                   ' a long treasure log, to check the two columns
        n = LOOT_N(1) + 1: LOOT_N(1) = n
        LOOT_NAME(1, n) = MID$("SACK OF GOLD      SILVER CUP        GOLD CUP          SILVER COFFER     HUGE EMERALD      ", ((i MOD 5) * 18) + 1, 18)
        LOOT_GOLD(1, n) = 1000 * ((i MOD 5) + 1)
    NEXT i
    ShowCharSheetPaint                                 ' paint only -- no WaitKey, no board repaint
    _SAVEIMAGE "charsheet.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |10charsheet.png|07")
END SUB


SUB DumpFightShot
    DIM a AS INTEGER, lvl AS INTEGER, nm AS STRING, i AS INTEGER
    DIM hp(1 TO 4) AS INTEGER, mx(1 TO 4) AS INTEGER

    _DEST _CONSOLE
    IF FightInit%("assets/data/ui-fight-layout.txt") = 0 THEN
        PRINT PipeCol$("|12fightshot: the fight layout failed to load -- nothing to render.|07")
        EXIT SUB
    END IF
    PRINT PipeCol$("|15fightshot|07 -- seeding a synthetic 1-vs-4 encounter")
    DevPackOverride

    FightReset
    lvl = 5

    '--- the player (slot 0) -------------------------------------------------
    nm = _TRIM$(CLASSES(player_class).name)
    ' Deliberately BLOODIED (7/24 = 29%), so the health-tier blood + vignette actually render --
    ' DrawWounds only kicks in under 50%, and a shot at full health would show none of it.
    player_hp = 7: player_maxhp = 24
    item_bow = -1                                     ' so the SHOOT row appears in the menu
    FightSetActor 0, "GRYMMJACK", "1st Level " + nm, "classes/" + SpriteBase$(nm), 7, 24
    FightSetArtFallback 0, ClassSprite$(player_class)   ' takes a class INDEX, not a name
    FightSetStat 0, 1, "MELEE:", "+3"
    FightSetStat 0, 2, "RANGED:", "+1"
    FightSetStat 0, 3, "ARMOR:", "AC4"
    FightSetStatus 0, 1, "HEALTH:", HealthWord$(player_hp, player_maxhp)
    FA_STANCE(0) = STANCE_ATTACK
    FightSetStatus 0, 2, "STANCE:", StanceName$(FA_STANCE(0))
    ' A real status effect, so the EFFECT: row shows the live model rather than a placeholder.
    StatusClearAll
    IF StatusApply%(0, "poison", 4.5, 1, -1) > 0 THEN FightSetStatus 0, 3, "EFFECT:", StatusText$(0)
    FightMenuRoot                                     ' the action menu + hint line
    FightSetFuse 0, 0.62

    '--- four foes, one per visual state ------------------------------------
    hp(1) = 12: mx(1) = 12                       ' full     -> green
    hp(2) = 7: mx(2) = 14                        ' wounded  -> yellow
    hp(3) = 2: mx(3) = 16                        ' critical -> red
    hp(4) = 0: mx(4) = 10                        ' dead     -> dimmed portrait, grey name
    FOR a = 1 TO 4
        nm = _TRIM$(MON_NAME(lvl, ((a - 1) MOD 3) + 1))
        IF LEN(nm) = 0 THEN nm = "MONSTER" + LTRIM$(STR$(a))
        FightSetActor a, nm, "", "monsters/" + SpriteBase$(nm), hp(a), mx(a)
        FightSetArtFallback a, MonsterSprite$(nm)
        FightSetStat a, 1, "MELEE:", "+" + LTRIM$(STR$(2 + a))
        FightSetStat a, 2, "RANGED:", "-"
        FightSetStat a, 3, "ARMOR:", "AC" + LTRIM$(STR$(6 + a))
        FightSetStatus a, 1, "HEALTH:", MID$("HALEHURTNEARDEAD", 1, 4)
        FightSetStatus a, 2, "STANCE:", "CIRCLING"
        FightSetStatus a, 3, "EFFECT:", "-"
    NEXT a

    ' Arm the REAL fuse model rather than poking FA_FUSE directly, so this shot exercises the
    ' same code path a fight will. Different tiers give different durations, so one shared
    ' advance leaves the four bars genuinely staggered -- and the colour ramp (cyan/yellow/red)
    ' then shows at a glance which foe is imminent.
    FuseReset
    FOR a = 1 TO 4
        IF FA_ALIVE(a) THEN FuseArmFoe a, a - 1, lvl        ' tiers 0,1,2 (3 clamps to 2)
    NEXT a
    a = FuseStep%(1.4)                                      ' 1.4s of deliberation has passed
    FA_TARGET = 3
    IF FA_ALIVE(2) THEN StaggerActor 2, 2.5           ' show the STAGGERED punish state
    TargetValidate                                          ' never leave the aim on a corpse
    FuseSyncInitiative                                      ' ribbon reads off the live fuses

    FIGHT_ROUND = 4
    FIGHT_BANNER = "BONUS DAMAGE!"

    '--- a log with both gutter-marked and plain lines ----------------------
    FightLog "", "You descend into the " + _TRIM$(SECTORS(lvl).label) + "."
    FightLog "M", "Four shapes uncoil from the dark."
    FightLog "", "You set your feet and raise the blade."
    FightLog "C", "CRITICAL -- you open " + _TRIM$(FA_NAME(3)) + " to the bone!"
    FightLog "", _TRIM$(FA_NAME(4)) + " falls and does not rise."
    FightLog "M", _TRIM$(FA_NAME(1)) + " lunges past your guard."
    FightLog "", "You give ground, breathing hard."

    ' Drive the display off the LIVE model rather than hand-set rows, so the shot cannot show
    ' something the fight itself would not (foe 2's stagger, the poison countdown, health words).
    FightSyncStatus
    FightRender
    ' Health tiers, visible: the same blood + vignette the board uses. Only renders under 50% HP,
    ' which is why the seeded player is deliberately BLOODIED.
    FightBeginDraw
    DrawWounds
    FightEndDraw
    _SAVEIMAGE "fightshot.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  actors: |15" + LTRIM$(STR$(FightLiveFoes%)) + "|07 live foes + the player, target = slot |15" + LTRIM$(STR$(FA_TARGET)) + "|07")
    PRINT PipeCol$("  initiative: |15" + _TRIM$(FIGHT_INIT) + "|07   (soonest fuse to fire)")
    FOR a = 1 TO FIGHT_MAXFOE
        IF FA_USED(a) THEN
            IF FF_ARMED(a) THEN
                PRINT PipeCol$("    foe " + LTRIM$(STR$(a)) + " |15" + _TRIM$(FA_NAME(a)) + "|07 fuse " + LTRIM$(STR$(INT(FA_FUSE(a) * 100))) + "% -- " + FmtSecs$(FuseRemaining!(a)) + " left")
            ELSE
                PRINT PipeCol$("    foe " + LTRIM$(STR$(a)) + " |08" + _TRIM$(FA_NAME(a)) + " -- no fuse (dead)|07")
            END IF
        END IF
    NEXT a
    PRINT PipeCol$("  portraits found: |15" + LTRIM$(STR$(FightShotArtCount%)) + " of 5|07 (missing ones draw a [no art] placeholder)")
    PRINT PipeCol$("wrote |11fightshot.png|07 (" + LTRIM$(STR$(_WIDTH(CANVAS))) + "x" + LTRIM$(STR$(_HEIGHT(CANVAS))) + ")")
    FightFreeTiles
END SUB

' How many of the five actor portraits actually resolved to art. Reported by `fightshot` so a
' blank-looking screen is immediately distinguishable from a broken renderer: 0 of 5 means the
' art is not generated yet, 5 of 5 with a blank screen means the renderer is at fault.
FUNCTION FightShotArtCount%
    DIM a AS INTEGER, n AS INTEGER, fallbacks AS INTEGER
    ' Mirrors FightPortrait&'s resolution order exactly -- including step 3, the general art
    ' fallback. A counter that checked fewer steps than the renderer would report "0 of 5" over a
    ' screen full of art, which is worse than no counter at all.
    FOR a = 0 TO FIGHT_MAXFOE
        IF FA_USED(a) THEN
            IF LEN(AnsiFile$("strategic-combat/" + _TRIM$(FA_ART(a)) + ".ans")) > 0 THEN
                n = n + 1
            ELSEIF LEN(ArtFile$("strategic-combat/" + _TRIM$(FA_ART(a)) + ".png")) > 0 THEN
                n = n + 1
            ELSEIF LEN(_TRIM$(FA_ART2(a))) > 0 THEN
                n = n + 1
                fallbacks = fallbacks + 1
            END IF
        END IF
    NEXT a
    IF fallbacks > 0 THEN PRINT PipeCol$("  |14" + LTRIM$(STR$(fallbacks)) + "|07 of those fell back to the GENERAL art (no fight-sized art yet)")
    FightShotArtCount% = n
END FUNCTION

' Launch a tactical fight from the [0] panel and put the board back afterwards.
'
' The level comes from the player's position (SECTOR.get_by_xy), the same derivation the rest of
' the game uses -- there is no "current level" global to go stale. On return the board has to be
' fully repainted: RunFight% CLS'd CANVAS and left it at the 8x8 font, so without the repaint the
' player would be dropped onto a blank screen with half-height text.
SUB DebugStartFight (which AS STRING)
    DIM lvl AS INTEGER, nfoes AS INTEGER, res AS INTEGER
    lvl = SECTOR.get_by_xy(c.x, c.y)
    IF lvl < 1 THEN lvl = 1
    IF which = "F" THEN nfoes = 1 ELSE nfoes = 4
    res = RunFight%(lvl, nfoes)
    ' Back to the board: restore the font and repaint everything the fight screen wiped.
    _FONT CH
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB

' Let a dev mode preview an ART PACK without touching the player's saved settings.
'
' Scans the command line for any argument that names an existing subfolder of
' assets/ansi-art/ or assets/pixel-art/ and selects it for this run only. Nothing is written to
' dungeon-settings.dat -- that file is the player's live, unrecoverable preferences, and a dev
' mode has no business editing it just to look at a pack.
'
'   dungeon.run fightshot ansimon-1     render the fight screen using that ANSI pack
'   dungeon.run fight 7 3 ansimon-1     play a fight using it
'
' Reports what it picked, because "0 of 5 portraits" is otherwise ambiguous between "the pack
' has no art" and "the pack name was misspelt so the default is still selected".
SUB DevPackOverride
    DIM i AS INTEGER, arg AS STRING
    FOR i = 1 TO _COMMANDCOUNT
        arg = _TRIM$(COMMAND$(i))
        IF LEN(arg) > 0 THEN
            IF _DIREXISTS("assets/ansi-art/" + arg) THEN
                opt_ansipack = arg
                PRINT PipeCol$("  ANSI pack -> |15" + arg + "|07 (this run only; settings not written)")
            END IF
            IF _DIREXISTS("assets/pixel-art/" + arg) THEN
                opt_artpack = arg
                PRINT PipeCol$("  pixel pack -> |15" + arg + "|07 (this run only; settings not written)")
            END IF
        END IF
    NEXT i
END SUB
