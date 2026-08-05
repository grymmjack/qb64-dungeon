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
    cursor_erase: cursor_draw: DrawHUD: Present
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
        Present
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
    sec = PlayerLevel%
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), COLLIDE_BOARD, img, (c.x, c.y)-(c.x + CW, c.y + CH)
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
    oldsrc = _SOURCE: _SOURCE COLLIDE_BOARD
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
    ' ...and the OTHER extreme. A maxed hero is not the worst case for every row: the stat
    ' DERIVATION line is its widest at a plain level-1 HERO ("To-Hit +2 = +2 class +0 STR ...",
    ' 70 columns against the 67 the span beside the portrait allows), and testing only the
    ' kitted-out character missed it printing straight over the class art.
    player_name = "HERO"
    char_level = 1: char_xp = 0
    player_str = 10: player_int = 10: player_wis = 10: player_dex = 10: player_con = 10: player_cha = 10
    player_hp = 24: player_maxhp = 24
    player_tohit = 2: player_ac = 15: player_dmgdie = 8: player_dmgbonus = 0
    gold = 0: target_gold = 10000: has_key = 0: key_level = 8
    item_sword = 0: item_armor = 0: item_shield = 0: item_bow = 0: item_boots = 0
    item_teleport = 0: item_potion_small = 0: item_potion_large = 0
    item_secret_card = 0: item_esp = 0: item_crystal = 0
    spell_fire = 0: spell_bolt = 0
    LOOT_N(1) = 0
    ShowCharSheetPaint
    _SAVEIMAGE "charsheet-fresh.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |10charsheet.png|07 (fully kitted) and |10charsheet-fresh.png|07 (level-1 HERO)")
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
    ' `fightshot [level]` -- the monsters differ per level, and so does what they are made of:
    ' only a level with UNDEAD on it can show the black-gore path at all (GoreColor~&).
    lvl = 5
    FOR i = 1 TO _COMMANDCOUNT
        IF VAL(COMMAND$(i)) >= 1 AND VAL(COMMAND$(i)) <= 9 THEN lvl = VAL(COMMAND$(i))
    NEXT i
    PRINT PipeCol$("  level -> |15" + LTRIM$(STR$(lvl)) + "|07")

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
        FightSetActor a, nm, "", MonsterArtBase$(nm), hp(a), mx(a)
        FightSetArtFallback a, MonsterSprite$(nm)
        FightSetGore a, GoreColor~&(nm)          ' the four HP tiers above double as the gore ramp
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
    lvl = PlayerLevel%
    IF lvl < 1 THEN lvl = 1
    IF which = "F" THEN nfoes = 1 ELSE nfoes = 4
    res = RunFight%(lvl, nfoes)
    ' Back to the board: restore the font and repaint everything the fight screen wiped.
    _FONT CH
    cursor_erase: cursor_draw: DrawHUD: Present
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
        ' A STYLE override as well as a pack one. Without this every art dev-mode could only
        ' ever shoot whatever style the player's saved settings happen to be in -- so ANSI-only
        ' settings made it impossible to verify any pixel-art change, and vice versa.
        SELECT CASE LCASE$(arg)
            CASE "pixel", "png": opt_artstyle = 1: PRINT PipeCol$("  art style -> |15pixel|07 (this run only)")
            CASE "ansi": opt_artstyle = 0: PRINT PipeCol$("  art style -> |15ANSI|07 (this run only)")
            CASE "hybrid": opt_artstyle = 2: PRINT PipeCol$("  art style -> |15hybrid|07 (this run only)")
        END SELECT
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


' What fraction of `path`'s pixels are not pure black, 0..1 -- sampled on a coarse grid so a
' 1056x816 shot costs a few thousand POINTs, not a million.
'
' This is the whole point of rollshot being a CHECK and not just a screenshot. The dice-box
' regression did not look like a crash or a bad number: the dice animated correctly on a
' completely black screen, because the GL layer flipped the window without the canvas under it.
' A frame like that is ~10% non-black (the tray and its caption); a healthy one is ~95% (the
' whole dungeon board). No human has to look at a PNG to tell those apart.
FUNCTION FrameInkFrac! (path AS STRING)
    DIM img AS LONG, od AS LONG, osrc AS LONG
    DIM AS INTEGER iw, ih, px, py, stp
    DIM AS LONG lit, seen
    FrameInkFrac! = 0
    IF NOT _FILEEXISTS(path) THEN EXIT FUNCTION
    img = _LOADIMAGE(path, 32)
    IF img >= -1 THEN EXIT FUNCTION                  ' _LOADIMAGE failure is >= -1, not 0
    iw = _WIDTH(img): ih = _HEIGHT(img)
    osrc = _SOURCE: _SOURCE img
    stp = 8
    FOR py = 0 TO ih - 1 STEP stp
        FOR px = 0 TO iw - 1 STEP stp
            seen = seen + 1
            IF POINT(px, py) <> BLACK THEN lit = lit + 1
        NEXT px
    NEXT py
    _SOURCE osrc
    _FREEIMAGE img
    IF seen > 0 THEN FrameInkFrac! = lit / seen
END FUNCTION


' `dungeon.run rollshot` -- capture every DICE STYLE mid-roll, at the settled frame.
'
' Until this existed there was NO headless way to see a dice roll, so the dice-box regression
' (dice animating on a black screen) could only be found by playing the game and could only be
' verified by someone taking a photo of their monitor. Now the gate sees it.
'
' It drives the REAL roll functions (AnimatedRoll -> RollPips / ShowRollTextEx / Show3DRoll) over
' the REAL board, so tray placement, the board behind it, the caption and the sum are all shot
' exactly as the player gets them. Two things make that capturable:
'   * roll_shot   -- armed here, saved by RollShotSave at the settle frame, then self-disarming.
'   * dice3d_force_soft -- the 3D dice's hardware path draws to the WINDOW after the canvas blit,
'     where _SAVEIMAGE CANVAS cannot reach it. The software renderer composites into the canvas.
'     So the 3D shots prove LAYOUT (tray, board, sum) but are not a shot of the GL rasteriser.
' Do the PER-DIE faces the renderer published (DIE_FACE / PublishFaces) agree with the total it
' returned? Combat initiative throws two d20s in ONE animation and reads them apart -- the player's
' die and the monster's -- so a renderer that publishes nothing, or publishes the wrong count,
' silently decides every fight's turn order from zeroes. Nothing on screen would look wrong.
'
' Checks count, plausible range, and that the faces sum to the returned raw total. Appends "" when
' fine so a clean run reads exactly as it did before; anything else is loud.
FUNCTION FaceReport$ (n AS INTEGER, total AS INTEGER, sides AS INTEGER)
    DIM i AS INTEGER, sum AS INTEGER, faces AS STRING
    IF DIE_FACE_N <> n THEN
        FaceReport$ = "  |12<< DIE_FACE_N=" + _TRIM$(STR$(DIE_FACE_N)) + ", expected " + _TRIM$(STR$(n)) + "|07"
        rollshot_facebad = -1
        EXIT FUNCTION
    END IF
    sum = 0: faces = ""
    FOR i = 1 TO n
        sum = sum + DieFace%(i)
        IF LEN(faces) > 0 THEN faces = faces + "+"
        faces = faces + _TRIM$(STR$(DieFace%(i)))
        IF DieFace%(i) < 1 OR DieFace%(i) > sides THEN
            FaceReport$ = "  |12<< face " + _TRIM$(STR$(i)) + " = " + _TRIM$(STR$(DieFace%(i))) + " is off a d" + _TRIM$(STR$(sides)) + "|07"
            rollshot_facebad = -1
            EXIT FUNCTION
        END IF
    NEXT i
    IF sum <> total THEN
        FaceReport$ = "  |12<< faces " + faces + " = " + _TRIM$(STR$(sum)) + " but the roll returned " + _TRIM$(STR$(total)) + "|07"
        rollshot_facebad = -1
        EXIT FUNCTION
    END IF
    FaceReport$ = "  |08faces " + faces + "|07"
END FUNCTION

SUB DumpRollShot
    DIM AS INTEGER i, bad, r
    DIM nm AS STRING, f AS SINGLE
    CONST NSHOT = 5
    DIM AS STRING shotName(1 TO NSHOT), shotWhat(1 TO NSHOT)
    DIM AS INTEGER shotN(1 TO NSHOT), shotSides(1 TO NSHOT), shotBonus(1 TO NSHOT)
    DIM AS INTEGER shot3d(1 TO NSHOT), shotPips(1 TO NSHOT)

    _DEST _CONSOLE
    PRINT PipeCol$("|15rollshot|07 -- every dice style, captured at the settled frame")
    DevPackOverride

    '            file                 caption          n  sides bonus  3d  pips
    shotName(1) = "rollshot-pips": shotWhat(1) = "movement"
    shotN(1) = 2: shotSides(1) = 6: shotBonus(1) = 0: shot3d(1) = 0: shotPips(1) = -1
    shotName(2) = "rollshot-d6font": shotWhat(2) = "movement"
    shotN(2) = 2: shotSides(2) = 6: shotBonus(2) = 0: shot3d(2) = 0: shotPips(2) = 0
    shotName(3) = "rollshot-d20": shotWhat(3) = "to hit"
    shotN(3) = 1: shotSides(3) = 20: shotBonus(3) = 5: shot3d(3) = 0: shotPips(3) = 0
    shotName(4) = "rollshot-3d-d6": shotWhat(4) = "movement"
    shotN(4) = 2: shotSides(4) = 6: shotBonus(4) = 0: shot3d(4) = -1: shotPips(4) = -1
    shotName(5) = "rollshot-3d-d20": shotWhat(5) = "to hit"
    shotN(5) = 1: shotSides(5) = 20: shotBonus(5) = 5: shot3d(5) = -1: shotPips(5) = 0

    opt_realdice = FALSE                             ' never prompt for a typed result
    opt_dicespeed = 3                                ' Instant: the settled frame is all we shoot
    dice3d_force_soft = -1                           ' 3D onto the CANVAS, where _SAVEIMAGE can see it
    StartBoard                                       ' a real dungeon under the tray -- that is the check

    bad = 0: rollshot_facebad = 0
    FOR i = 1 TO NSHOT
        cursor_erase: cursor_draw                    ' fresh board per shot -- the roll boxes do not
        Present                                      ' clean themselves up between back-to-back rolls,
        opt_dice3d = shot3d(i): opt_d6pips = shotPips(i)   ' and a stale tray in the frame reads as a bug
        nm = shotName(i) + ".png"
        roll_shot = nm
        r = AnimatedRoll(shotN(i), shotSides(i), shotBonus(i), shotWhat(i))
        _DEST _CONSOLE
        IF LEN(roll_shot) > 0 THEN                   ' still armed = nothing ever reached RollShotSave
            roll_shot = ""
            PRINT PipeCol$("  |12BAD|07  " + shotName(i) + " -- the roll never reached a settle frame")
            bad = bad + 1
        ELSE
            f = FrameInkFrac!(nm)
            IF f < 0.3 THEN
                PRINT PipeCol$("  |12BAD|07  " + nm + " -- " + _TRIM$(STR$(INT(f * 100))) + "% non-black: the roll drew on a BLANK screen, not the board")
                bad = bad + 1
            ELSE
                PRINT PipeCol$("  |10ok |07  " + nm + "  rolled " + _TRIM$(STR$(r)) + ", " + _TRIM$(STR$(INT(f * 100))) + "% non-black" + FaceReport$(shotN(i), r, shotSides(i)))
            END IF
        END IF
    NEXT i

    HeldRerollCheck                                  ' a pinned die must keep its face, every style
    _DEST _CONSOLE                                   ' it ends in RollSeqEnd -> Present, which leaves
    '                                                  _DEST on CANVAS; the summary below is console
    IF rollshot_facebad THEN
        PRINT PipeCol$("|12rollshot: a dice style published per-die faces that disagree with its own total|07")
        bad = bad + 1
    END IF
    IF bad > 0 THEN
        PRINT PipeCol$("|12rollshot: " + _TRIM$(STR$(bad)) + " of " + _TRIM$(STR$(NSHOT)) + " dice style(s) failed|07")
        SYSTEM 1
    END IF
    PRINT PipeCol$("  all |14" + _TRIM$(STR$(NSHOT)) + "|07 dice styles rendered over the board")
END SUB


' `dungeon.run panelshot [class]` -- render the D&D COMBAT PANEL to panelshot.png.
'
' Same reasoning as charsheet: the panel only misbehaves when it is FULL, and now it also
' bookends itself with a class portrait and a weapon tile, which is exactly the kind of layout
' that looks fine until a long monster name or a long caption runs into it.
'
' Takes a class number so all four portraits and all three base weapons can be eyeballed:
'   dungeon.run panelshot 4     the Wizard, so the staff art shows
SUB DumpCombatPanel (pc AS INTEGER)
    DIM rm AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15panelshot|07 -- the D&D combat panel, worst case for the layout")
    DevPackOverride
    player_class = pc: class_name = _TRIM$(CLASSES(pc).name)
    player_name = "Higgs the Unluckiest of All"
    char_level = 5
    player_hp = 31: player_maxhp = 74
    player_ac = 15: item_armor = 3: item_shield = 2
    item_sword = 0                                   ' base weapon: the common case, and the new art
    item_potion_small = 6: item_potion_large = 2
    spell_fire = 3: spell_bolt = 3
    combat_round = 3
    ' a scratch room with the longest monster name in the game, to squeeze the centred text
    rm = ROOM_N + 2
    ROOMS(rm).sec = 9
    ROOMS(rm).monster = "BLACK PUDDING"
    ROOMS(rm).mhp = 88: ROOMS(rm).mhp_now = 61: ROOMS(rm).mac = 17
    cursor_erase
    DrawCombatPanel rm, _TRIM$(ROOMS(rm).monster), _TRIM$(ROOMS(rm).monster)
    _SAVEIMAGE "panelshot.png", CANVAS
    PRINT PipeCol$("  wrote |14panelshot.png|07  (" + _TRIM$(class_name) + ", base weapon, mid-fight)")
END SUB


' `dungeon.run statshot` -- the level-up ability picker, with one score already maxed so both
' the selectable and the "(maxed)" states are visible in one shot.
SUB DumpStatPicker
    _DEST _CONSOLE
    PRINT PipeCol$("|15statshot|07 -- the level-up ability picker (one score maxed, longest blurbs)")
    DevPackOverride
    player_class = 1: class_name = _TRIM$(CLASSES(1).name)
    player_name = "Higgs the Unluckiest of All"
    char_level = 4
    player_str = 18: player_int = 9: player_wis = 11: player_dex = 14: player_con = 12: player_cha = 8
    player_hp = 40: player_maxhp = 52
    DeriveFromStats player_class
    cursor_erase
    LevelUpStatPaint 4
    _SAVEIMAGE "statshot.png", CANVAS
    PRINT PipeCol$("  wrote |14statshot.png|07")
END SUB


' `dungeon.run creatorshot [stat]` -- the character creator's stat screen with the side panel.
' Takes a stat index so the thinnest one (WIS/CHA, mostly planned lines) can be checked too --
' those are the rows most likely to overflow or look wrong.
SUB DumpCreatorShot (statsel AS INTEGER)
    DIM sc(1 TO 6) AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15creatorshot|07 -- character creator + the 'what it does' side panel")
    DevPackOverride
    player_name = "Higgs the Unluckiest of All"
    sc(1) = 16: sc(2) = 9: sc(3) = 11: sc(4) = 14: sc(5) = 13: sc(6) = 8
    DrawFlexStats 1, sc(), statsel, 0, 2, "12 points left to spend"
    _SAVEIMAGE "creatorshot.png", CANVAS
    PRINT PipeCol$("  wrote |14creatorshot.png|07  (cursor on " + StatName$(statsel) + ")")
    ' The ROLL screen too. It is a different renderer (DrawCharGen, not DrawFlexStats) and had no
    ' shot at all, which is how its 'what it does' panel shipped drawn UNDERNEATH the dice tray
    ' with two lines poking out. Shot mid-roll, with `statsel` scores filled in, because that is
    ' the state where the panel, the highlighted row and the tray all compete for the screen.
    DICE3D_YOFF = 14                                 ' the offset the real roll screen uses
    DrawCharGen 1, sc(), statsel, 0
    _SAVEIMAGE "creatorshot-roll.png", CANVAS
    DICE3D_YOFF = 0
    PRINT PipeCol$("  wrote |14creatorshot-roll.png|07  (" + _TRIM$(STR$(statsel)) + " of 6 rolled)")
END SUB


' `dungeon.run gaugeshot [depth] [hp]` -- render the ACTION GESTURE gauge to gaugeshot.png.
'
' Renders BOTH presentations side by side in one file: the timed sweep (top) and the REAL-DICE
' static bar with its d20 face strip (bottom). The two must agree about where the zones are --
' the strip promises "roll a 12 and you land in the purple", and the only way to see that the
' promise holds is to see the same GAUGEK drawn both ways.
'
' depth and hp matter because the zones NARROW with both (GaugeKnobs), so a shot at level 1 in
' full health shows the widest bands the game ever draws and proves nothing about the tight end.
SUB DumpGaugeShot
    DIM k AS GAUGEK, i AS INTEGER, dep AS INTEGER, hpv AS INTEGER, seen AS INTEGER
    _DEST _CONSOLE
    dep = 5: hpv = 0
    FOR i = 1 TO _COMMANDCOUNT
        IF VAL(COMMAND$(i)) >= 1 THEN
            seen = seen + 1
            IF seen = 1 THEN dep = VAL(COMMAND$(i))
            IF seen = 2 THEN hpv = VAL(COMMAND$(i))
        END IF
    NEXT i
    IF dep < 1 THEN dep = 1
    IF dep > 9 THEN dep = 9
    player_maxhp = 24
    IF hpv > 0 THEN player_hp = hpv ELSE player_hp = 18
    PRINT PipeCol$("|15gaugeshot|07 -- depth |14" + LTRIM$(STR$(dep)) + "|07, hp |14" + LTRIM$(STR$(player_hp)) + "/" + LTRIM$(STR$(player_maxhp)) + "|07")

    k.skill = 1
    k.hp = player_hp: k.maxhp = player_maxhp
    k.willmax = 0: k.will = 0
    k.wobble = 0: k.press = 0
    k.depth = dep
    GaugeKnobs k
    GaugeBegin k
    GaugeStep k                                  ' one frame, so the sweeping marker has a position

    _DEST CANVAS: CLS , BLACK
    DrawGauge "TIMED SWEEP", "[SPACE] lock", 0, k, 0.7
    _SAVEIMAGE "gaugeshot-timed.png", CANVAS
    _DEST _CONSOLE                               ' PRINT follows _DEST -- without this it goes to the canvas
    PRINT PipeCol$("  wrote |14gaugeshot-timed.png")

    _DEST CANVAS: CLS , BLACK
    k.p = GaugeDieP!(14, 20)                     ' as though 14 had just been typed
    DrawGaugeEx "REAL DICE", "no fuse -- take your time", 0, k, 1, 0, -1
    DrawGaugeDiceStrip k, "14", ""
    _SAVEIMAGE "gaugeshot.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  zone centre |14" + LEFT$(STR$(k.zc), 6) + "|07  crit +/-|14" + LEFT$(STR$(k.ecrit), 6) + "|07  hit +/-|14" + LEFT$(STR$(k.ehit), 6))
    PRINT PipeCol$("  ranges: |14" + GaugeRangeText$(k))
    PRINT PipeCol$("  wrote |14gaugeshot.png")
END SUB


' `dungeon.run summaryshot` -- the run scorecard, both ways it is shown.
'
' Seeds every counter with a DIFFERENT, wide number on purpose. Equal or small values would
' hide exactly the failures worth catching: a column that does not line up, a label clipped by
' its value, or a value printed past the panel edge. The two shots must agree row for row --
' they read the same StatRowLabel$/StatRowValue$ list, and this is what proves it.
SUB DumpSummaryShot
    _DEST _CONSOLE
    PRINT PipeCol$("|15summaryshot|07 -- the run scorecard, panel + [TAB] overlay")
    ChronicleReset
    game_start = TIMER - 754                       ' 12m 34s in
    player_name = "GRYMMJACK": class_name = "SUPERHERO"
    char_level = 7: char_xp = 12480: gold = 18350: target_gold = 20000
    turn_num = 214: moves_made = 1387
    g_rooms_explored = 48: g_rooms_cleared = 31: g_chambers_cleared = 4
    g_max_level = 9: g_treasures_found = 26: g_gold_found = 18350
    g_items_looted = 7: g_items_used = 19: g_secrets_found = 5
    g_monsters_slain = 63: g_streak_best = 11
    g_crits = 14: g_flourishes = 22: g_fumbles = 6
    g_dmg_dealt = 1042: g_dmg_healed = 318
    g_wander_enc = 9: g_levels_completed = 8
    start_heals = 3: g_rests = 41: g_run_deaths = 2

    _DEST CANVAS: CLS , BLACK
    ChroniclePanel 14, 3, 118, 40, "G A M E   S U M M A R Y", "summary"
    COLOR WHITE, BOXBG: PrintCentered 6, _TRIM$(player_name) + "  the  " + _TRIM$(class_name)
    COLOR GREY, BOXBG: PrintCentered 8, "Level " + EvNum$(char_level) + "    XP " + EvNum$(char_xp) + "    Gold " + EvNum$(gold) + " / " + EvNum$(target_gold)
    DIM i AS INTEGER, y AS INTEGER, col AS INTEGER, per AS INTEGER, lx AS INTEGER
    per = (STATROW_N + 1) \ 2
    FOR i = 1 TO STATROW_N
        IF i <= per THEN col = 0 ELSE col = 1
        y = 11 + ((i - 1) MOD per) * 2
        lx = 18 + col * 50
        COLOR CYANU, BOXBG: _PRINTSTRING (lx * CW, y * CH), PadR$(StatRowLabel$(i), 22)
        COLOR WHITE, BOXBG: _PRINTSTRING ((lx + 23) * CW, y * CH), StatRowValue$(i)
    NEXT i
    _PRINTMODE _FILLBACKGROUND                     ' this shot never calls ChronicleClose
    _SAVEIMAGE "summaryshot.png", CANVAS

    _DEST CANVAS: CLS , _RGB32(&H10, &H14, &H10)   ' a dim "board" behind it, so the panel reads
    opt_statsoverlay = -1
    DrawStatsOverlay
    _SAVEIMAGE "summaryshot-overlay.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  " + LTRIM$(STR$(STATROW_N)) + " stat rows")
    PRINT PipeCol$("  wrote |14summaryshot.png|07 and |14summaryshot-overlay.png")
END SUB


' `dungeon.run deathshot` -- the animated death screen, run for real and captured at the end.
'
' Seeds a plausible dead run: a killer, a level, rescues, and kills spread across levels 1-9 so
' the PILE actually has something to drop. A default-state death would show an empty pile and a
' blank epitaph, which is precisely the layout that cannot break.
SUB DumpDeathShot
    DIM lv AS INTEGER, sl AS INTEGER, nm AS STRING, bi AS INTEGER, i AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15deathshot|07 -- the animated epitaph")
    DevPackOverride
    ChronicleReset
    game_start = TIMER - 1147                       ' 19 minutes in
    player_name = "GRYMMJACK": class_name = _TRIM$(CLASSES(player_class).name)
    g_death_mon = "VAMPIRE": g_death_lv = 6
    g_saved = 2: g_run_deaths = 3
    ' kills across the depth, so the pile stacks level 1 -> level 9 the way a real run would
    FOR lv = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lv, sl))
            IF LEN(nm) > 0 THEN
                bi = BeastIdx%(nm)
                IF bi > 0 THEN BEAST_SLAIN(bi) = 1 + (lv MOD 3)
            END IF
        NEXT sl
    NEXT lv
    death_skipped = FALSE
    DeathScreen
    _SAVEIMAGE "deathshot.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  class |14" + _TRIM$(class_name) + "|07  weapon |14" + DeathWeaponArt$)
    FOR i = 1 TO 7
        IF LEN(EpitaphLine$(i)) > 0 THEN PRINT PipeCol$("  |07" + EpitaphLine$(i))
    NEXT i
    PRINT PipeCol$("  wrote |14deathshot.png")
END SUB


' `dungeon.run automovetest` -- prove the auto-walker actually walks.
'
' This is logic no screenshot can check and no human can be asked to sit through: it either
' paths across a 132x51 board or it wedges in a corridor, and the difference is invisible until
' someone plays it. So the test drives Goal -> Dir -> TryMove directly and asserts PROGRESS:
' the walker must close on its goal, not merely produce legal moves. A path that oscillates
' between two cells forever is made of perfectly legal moves.
'
' automove_run stays 0 throughout: AutoMoveCheck's halts call Banner/WaitKey, which would hang
' with nobody to press a key.
SUB DumpAutoMoveTest
    DIM steps AS INTEGER, i AS INTEGER, dir AS STRING, bad AS INTEGER
    DIM gx AS INTEGER, gy AS INTEGER, px AS INTEGER, py AS INTEGER
    DIM startd AS INTEGER, bestd AS INTEGER, stalls AS INTEGER, moved AS INTEGER
    DIM lastx AS INTEGER, lasty AS INTEGER, lastgx AS INTEGER, lastgy AS INTEGER, goalflips AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15automovetest|07 -- the auto-walker paths the real board")

    IF NOT AutoMoveGoal%(gx, gy) THEN
        PRINT PipeCol$("|12  FAIL|07 -- no goal on a fresh board (every level uncleared, every room alive)")
        SYSTEM 1
    END IF
    px = c.x \ CW: py = c.y \ CH
    PRINT PipeCol$("  start |14" + LTRIM$(STR$(px)) + "," + LTRIM$(STR$(py)) + "|07   goal |14" + LTRIM$(STR$(gx)) + "," + LTRIM$(STR$(gy)))

    dir = AutoMoveDir$(gx, gy)
    IF LEN(dir) = 0 THEN
        PRINT PipeCol$("|12  FAIL|07 -- no first step: the goal is unreachable from START")
        SYSTEM 1
    END IF
    startd = ADIST(px, py)
    bestd = startd
    PRINT PipeCol$("  path length from START: |14" + LTRIM$(STR$(startd)) + "|07 cells")

    steps = 400
    FOR i = 1 TO steps
        IF NOT AutoMoveGoal%(gx, gy) THEN EXIT FOR
        dir = AutoMoveDir$(gx, gy)
        IF LEN(dir) = 0 THEN EXIT FOR                 ' arrived, or genuinely boxed in
        lastx = c.x: lasty = c.y
        IF TryMove(dir) THEN moved = moved + 1
        IF c.x = lastx AND c.y = lasty THEN
            ' The walker chose a direction the mover refused. One or two is a doorway quirk;
            ' a run of them is a wedge, and a wedge is the failure this test exists to catch.
            stalls = stalls + 1
            IF stalls > 8 THEN
                _DEST _CONSOLE
                PRINT PipeCol$("|12  FAIL|07 -- WEDGED at " + LTRIM$(STR$(c.x \ CW)) + "," + LTRIM$(STR$(c.y \ CH)) + " (chose '" + dir + "', mover refused 9x)")
                bad = -1
                EXIT FOR
            END IF
        ELSE
            stalls = 0
        END IF
        px = c.x \ CW: py = c.y \ CH
        IF ADIST(px, py) >= 0 AND ADIST(px, py) < bestd THEN bestd = ADIST(px, py)
        ' Goal churn is the failure that hides behind a passing progress check: a walker that
        ' re-targets every step makes legal, closing moves forever and never arrives.
        IF gx <> lastgx OR gy <> lastgy THEN
            goalflips = goalflips + 1
            lastgx = gx: lastgy = gy
        END IF
    NEXT i

    ' TryMove draws, and drawing sets _DEST CANVAS -- PRINT follows _DEST, so without this the
    ' whole verdict renders onto the game canvas and the console shows nothing at all.
    _DEST _CONSOLE
    PRINT PipeCol$("  walked |14" + LTRIM$(STR$(moved)) + "|07 cells in " + LTRIM$(STR$(i - 1)) + " steps")
    PRINT PipeCol$("  closest approach: |14" + LTRIM$(STR$(bestd)) + "|07 (from " + LTRIM$(STR$(startd)) + ")")
    PRINT PipeCol$("  goal changed |14" + LTRIM$(STR$(goalflips)) + "|07 time(s); ended at " + LTRIM$(STR$(c.x \ CW)) + "," + LTRIM$(STR$(c.y \ CH)))
    IF moved < 10 THEN
        PRINT PipeCol$("|12  FAIL|07 -- barely moved; the walker is not walking")
        bad = -1
    END IF
    IF bestd >= startd THEN
        PRINT PipeCol$("|12  FAIL|07 -- never got closer to a goal (legal moves, no progress)")
        bad = -1
    END IF
    ' CHURN. This is the assertion that matters most, because the bug it guards is invisible to
    ' every other check here: re-picking "nearest room" each step made the walker re-target on
    ' 394 of 400 steps, all of them legal closing moves, and arrive nowhere. Some churn is
    ' expected in this harness (nothing dies, so arriving means picking the next room); a quarter
    ' of all steps is not.
    IF goalflips > steps \ 4 THEN
        PRINT PipeCol$("|12  FAIL|07 -- goal CHURN: re-targeted " + LTRIM$(STR$(goalflips)) + " times in " + LTRIM$(STR$(steps)) + " steps")
        bad = -1
    END IF
    IF bad THEN
        PRINT PipeCol$("|12automovetest: FAIL")
        SYSTEM 1
    END IF
    PRINT PipeCol$("|10automovetest: PASS|07 -- pathed, progressed, never wedged")
END SUB


' ============================================================================
'  `dungeon.run diceobj [set]` -- export the 3D dice as Wavefront OBJ + MTL + atlas PNG,
'  so the game's ACTUAL dice can be rendered in Blender for 2D art.
'
'  The meshes are already explicit (DICE3D_MV vertices, DICE3D_TA/TB/TC triangles), so this is
'  a writer rather than a conversion. The part that is easy to get wrong is the TEXTURE: the
'  numerals are not geometry, they are an atlas, and per-triangle UVs already exist in
'  DICE3D_TUX/TUY. Export the geometry alone and every die imports as a blank polyhedron.
'
'  Two coordinate conventions have to be converted, and both are silent if missed:
'    * OBJ indices are 1-BASED; DICE3D's are 0-based.
'    * OBJ V runs BOTTOM-UP; the atlas is top-down, so v = 1 - (y / height).
'
'  BEVEL is real geometry (opt_diceround drives DICE3D_CFG.BEVEL), so the export states the
'  roundness it was built at -- a re-export at a different setting is a different mesh.
' ============================================================================
' A plain fixed-point decimal, with no exponent and no truncation.
'
' Needed because QB64's STR$ switches to scientific notation for small magnitudes, and the
' obvious `LEFT$(STR$(v), 10)` then CHOPS the exponent: 4.166667E-02 became "4.166667E", which
' is not a number. Every exported OBJ was malformed in exactly the places where a coordinate
' happened to be small -- and it looked completely fine until something tried to parse it.
FUNCTION ObjNum$ (nval AS SINGLE)
    DIM neg AS INTEGER, iv AS LONG, fv AS LONG, a AS DOUBLE, o AS STRING
    a = nval
    IF a < 0 THEN neg = -1: a = -a
    iv = INT(a)
    fv = INT((a - iv) * 1000000 + 0.5)
    IF fv >= 1000000 THEN iv = iv + 1: fv = 0
    o = LTRIM$(STR$(iv)) + "." + RIGHT$("00000" + LTRIM$(STR$(fv)), 6)
    IF neg THEN o = "-" + o
    ObjNum$ = o
END FUNCTION

SUB DumpDiceObj
    DIM sides(1 TO 6) AS INTEGER, si AS INTEGER, sd AS INTEGER
    DIM cfg AS DICE3D_CONFIG, atlas AS LONG, idx AS INTEGER
    DIM f AS INTEGER, t AS INTEGER, v AS INTEGER, fh AS INTEGER
    DIM bnm AS STRING, obj AS STRING, mtl AS STRING, png AS STRING, odir AS STRING
    DIM aw AS INTEGER, ah AS INTEGER, i AS INTEGER, argn AS STRING
    _DEST _CONSOLE
    sides(1) = 4: sides(2) = 6: sides(3) = 8: sides(4) = 10: sides(5) = 12: sides(6) = 20

    LoadDiceFonts: LoadDiceSets
    idx = 0
    FOR i = 1 TO _COMMANDCOUNT                     ' optional dice-set name from the manifest
        argn = _TRIM$(COMMAND$(i))
        FOR t = 1 TO DSET_COUNT
            IF LCASE$(argn) = LCASE$(_TRIM$(DSET_NAME(t))) THEN opt_dice3d_set = t: LoadDiceSets
        NEXT t
    NEXT i

    odir = "diceobj"
    IF _DIREXISTS(odir) = 0 THEN MKDIR odir
    PRINT PipeCol$("|15diceobj|07 -- exporting the dice meshes for Blender")
    PRINT PipeCol$("  set |14" + _TRIM$(DSET_NAME(opt_dice3d_set)) + "|07   roundness |14" + LTRIM$(STR$(opt_diceround)) + "/10")

    FOR si = 1 TO 6
        sd = sides(si)
        idx = dice3d_set_index%(sd): IF idx < 0 THEN idx = 0
        cfg = DSET3D(idx)
        cfg.BEVEL = opt_diceround / 10             ' the mesh IS the roundness setting
        SetDiceFont cfg
        ' dice3d_build reads the SHARED DICE3D_BEVEL, not cfg -- the roll path sets it and we are
        ' not on the roll path. Without this line every die exports as its SHARP hull while the
        ' header cheerfully states a roundness, which is worse than not offering the setting.
        DICE3D_BEVEL = cfg.BEVEL * 0.18
        dice3d_build sd
        atlas = dice3d_make_atlas&(cfg, cfg.BODY_KOLOR, 0)
        IF atlas = 0 THEN
            PRINT PipeCol$("|12  d" + LTRIM$(STR$(sd)) + ": no atlas -- skipped")
            GOTO nextDie
        END IF
        aw = _WIDTH(atlas): ah = _HEIGHT(atlas)

        bnm = "d" + LTRIM$(STR$(sd))
        obj = odir + "/" + bnm + ".obj"
        mtl = odir + "/" + bnm + ".mtl"
        png = odir + "/" + bnm + "-atlas.png"
        _SAVEIMAGE png, atlas

        ' FACE VALUES, one per line, in face order. A renderer cannot work out which face carries
        ' which number from geometry alone -- the numerals live in the atlas -- but the atlas rows
        ' ARE face order, so face index n is at V row n. Writing the values out lets a tool find
        ' "the face showing 20" and turn it upward.
        fh = FREEFILE
        OPEN odir + "/" + bnm + "-faces.txt" FOR OUTPUT AS #fh
        PRINT #fh, "# face_index value   (" + LTRIM$(STR$(DICE3D_NF)) + " faces; atlas row N == face N)"
        FOR f = 0 TO DICE3D_NF - 1
            PRINT #fh, LTRIM$(STR$(f)) + " " + LTRIM$(STR$(DICE3D_FACE_VAL(f)))
        NEXT f
        CLOSE #fh

        fh = FREEFILE
        OPEN mtl FOR OUTPUT AS #fh
        PRINT #fh, "newmtl " + bnm
        PRINT #fh, "Ka 1.000 1.000 1.000"
        PRINT #fh, "Kd 1.000 1.000 1.000"
        PRINT #fh, "d 1.0"
        PRINT #fh, "illum 1"
        PRINT #fh, "map_Kd " + bnm + "-atlas.png"
        CLOSE #fh

        fh = FREEFILE
        OPEN obj FOR OUTPUT AS #fh
        PRINT #fh, "# " + bnm + " from qb64-dungeon (DICE3D)"
        PRINT #fh, "# set: " + _TRIM$(DSET_NAME(opt_dice3d_set)) + "   bevel: " + ObjNum$(cfg.BEVEL)
        PRINT #fh, "# atlas is " + LTRIM$(STR$(aw)) + "x" + LTRIM$(STR$(ah)) + " -- the FIRST column is full-bright;"
        PRINT #fh, "# the columns to its right are pre-darkened lighting levels the GAME samples."
        PRINT #fh, "# For rendering, light it yourself and use column 0 only (that is what these UVs use)."
        PRINT #fh, "mtllib " + bnm + ".mtl"
        PRINT #fh, "o " + bnm
        FOR v = 0 TO DICE3D_NV - 1
            PRINT #fh, "v " + ObjNum$(DICE3D_MV(v).X) + " " + ObjNum$(DICE3D_MV(v).Y) + " " + ObjNum$(DICE3D_MV(v).Z)
        NEXT v
        ' One vt per triangle CORNER: the same vertex carries different UVs on different faces,
        ' so they cannot be shared per-vertex the way positions are.
        FOR t = 0 TO DICE3D_NT - 1
            FOR i = 0 TO 2
                PRINT #fh, "vt " + ObjNum$(DICE3D_TUX(t, i) / aw) + " " + ObjNum$(1 - DICE3D_TUY(t, i) / ah)
            NEXT i
        NEXT t
        PRINT #fh, "usemtl " + bnm
        FOR t = 0 TO DICE3D_NT - 1
            PRINT #fh, "f " + _
                LTRIM$(STR$(DICE3D_TA(t) + 1)) + "/" + LTRIM$(STR$(t * 3 + 1)) + " " + _
                LTRIM$(STR$(DICE3D_TB(t) + 1)) + "/" + LTRIM$(STR$(t * 3 + 2)) + " " + _
                LTRIM$(STR$(DICE3D_TC(t) + 1)) + "/" + LTRIM$(STR$(t * 3 + 3))
        NEXT t
        CLOSE #fh
        _FREEIMAGE atlas
        PRINT PipeCol$("  |10d" + LTRIM$(STR$(sd)) + "|07  " + LTRIM$(STR$(DICE3D_NV)) + " verts, " + LTRIM$(STR$(DICE3D_NT)) + " tris, " + LTRIM$(STR$(DICE3D_NF)) + " faces -> |14" + obj)
        nextDie:
    NEXT si
    PRINT PipeCol$("  wrote |14" + odir + "/|07 -- import the .obj; the .mtl and atlas sit beside it")
END SUB


' `dungeon.run framegen` -- WRITE the engine GDK's sample 9-grid frame.
'
' The frame is just a BOX drawn at (3 x NG_TILEW) x (3 x NG_TILEH) characters -- 12x6 with the
' shipped tiles. There is no special format to learn: open it in an ANSI editor, redraw the box,
' and every panel drawn with NineGridBox% changes. That is the point of shipping it as ART.
'
' Generated rather than hand-authored so the FIRST one is guaranteed correct: exact width, no
' stray line breaks (pure auto-wrap, as the board masks use), self-contained SGR per run, a
' CHR$(26) EOF before the SAUCE, and TFlags=&H13 so an editor honours the bright colours.
SUB DumpFrameGen
    DIM path AS STRING, o AS STRING, r AS INTEGER, ccol AS INTEGER, fh AS INTEGER
    DIM w AS INTEGER, h AS INTEGER, ch2 AS INTEGER
    DIM lineK AS STRING, cornK AS STRING
    _DEST _CONSOLE
    w = NG_TILEW * 3: h = NG_TILEH * 3
    path = "assets/ansi-art/default/frames/gdk-panel.ans"
    IF _DIREXISTS("assets/ansi-art/default/frames") = 0 THEN MKDIR "assets/ansi-art/default/frames"
    lineK = CHR$(27) + "[0;1;36m"                ' bright cyan: the rails
    cornK = CHR$(27) + "[0;1;33m"                ' bright yellow corners, so the 3x3 slicing is
    '                                              VISIBLE in the sample rather than merely implied
    o = ""
    FOR r = 0 TO h - 1
        FOR ccol = 0 TO w - 1
            ch2 = 32
            IF r = 0 OR r = h - 1 THEN ch2 = 205
            IF ccol = 0 OR ccol = w - 1 THEN ch2 = 186
            IF r = 0 AND ccol = 0 THEN ch2 = 201
            IF r = 0 AND ccol = w - 1 THEN ch2 = 187
            IF r = h - 1 AND ccol = 0 THEN ch2 = 200
            IF r = h - 1 AND ccol = w - 1 THEN ch2 = 188
            IF ch2 = 201 OR ch2 = 187 OR ch2 = 200 OR ch2 = 188 THEN
                o = o + cornK + CHR$(ch2)
            ELSEIF ch2 = 32 THEN
                o = o + CHR$(27) + "[0m" + " "
            ELSE
                o = o + lineK + CHR$(ch2)
            END IF
        NEXT ccol
    NEXT r
    o = o + CHR$(27) + "[0m"
    ' CHR$(26) is the DOS EOF that separates ART from SAUCE. Without it the renderer walks
    ' straight into the metadata and DRAWS it -- the frame came out as "!!IBM VGA 260802".
    o = o + CHR$(26) + SauceRecord$("DUNGEON! GDK 9-grid panel frame", w, h, LEN(o))
    ' NEVER overwrite art that already exists. This tool writes a STARTER; once a file is on
    ' disk it belongs to the artist, and clobbering a hand-drawn frame is the most destructive
    ' thing it could possibly do. (It did exactly that once, which is why this guard is here.)
    ' Use the EXISTING base as the seed for the copies, so they inherit the real art, not mine.
    IF _FILEEXISTS(path) THEN
        PRINT PipeCol$("|15framegen|07 -- |14" + path + "|07 already drawn; left alone")
        o = _READFILE$(path)
        FrameSeedCopies o
        EXIT SUB
    END IF
    fh = FREEFILE
    OPEN path FOR OUTPUT AS #fh: CLOSE #fh       ' truncate
    OPEN path FOR BINARY AS #fh
    PUT #fh, 1, o
    CLOSE #fh
    PRINT PipeCol$("|15framegen|07 -- wrote the GDK sample frame")
    PRINT PipeCol$("  |14" + path + "|07   " + LTRIM$(STR$(w)) + "x" + LTRIM$(STR$(h)) + " chars, tiles " + LTRIM$(STR$(NG_TILEW)) + "x" + LTRIM$(STR$(NG_TILEH)))
    PRINT PipeCol$("  It is just a BOX. Redraw it at that size in any ANSI editor and every")
    PRINT PipeCol$("  panel drawn with NineGridBox% changes with it.")
    FrameSeedCopies o
END SUB

' Give every frame registered in ui-frames.txt its own COPY of the base art, if it has none yet.
'
' The point is DIVERGENCE: each context starts identical and can then be redrawn separately --
' a heavy iron combat panel, a lighter scroll for the banner -- with no code change, because the
' registry already points each context at its own file.
'
' Never overwrites. Once a file exists it is the artist's, and regenerating over hand-drawn art
' would be the single most destructive thing this tool could do.
SUB FrameSeedCopies (art AS STRING)
    DIM i AS INTEGER, dest AS STRING, fh AS INTEGER, made AS INTEGER, kept AS INTEGER
    FOR i = 1 TO UIFRAME_N
        dest = "assets/ansi-art/default/" + _TRIM$(UIFRAME_FILE(i)) + ".ans"
        IF _FILEEXISTS(dest) THEN
            kept = kept + 1
        ELSE
            fh = FREEFILE
            OPEN dest FOR OUTPUT AS #fh: CLOSE #fh
            OPEN dest FOR BINARY AS #fh
            PUT #fh, 1, art
            CLOSE #fh
            made = made + 1
            PRINT PipeCol$("  seeded |14" + dest)
        END IF
    NEXT i
    PRINT PipeCol$("  frames: |10" + LTRIM$(STR$(made)) + "|07 seeded, |14" + LTRIM$(STR$(kept)) + "|07 already drawn (never overwritten)")
END SUB


' Draw one demo panel and FILL ITS CONTENT RECT, so the shot proves two separate things: that
' the frame tiles, and that NineGridInner reports an interior the text actually fits inside.
' Drawing the caption at a guessed offset would have proved only the first.
SUB FrameDemo (nm AS STRING, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, cap AS STRING)
    DIM ok AS INTEGER, ic AS INTEGER, ir AS INTEGER, iw AS INTEGER, ih AS INTEGER, y AS INTEGER
    ok = FrameBox%(nm, col, row, cols, rows)
    IF NOT ok THEN EXIT SUB
    FrameInner nm, col, row, cols, rows, ic, ir, iw, ih
    IF iw <= 0 OR ih <= 0 THEN EXIT SUB
    ' A dim wash over the exact content rect -- this is the "blue area" of the 9-grid diagram.
    LINE (ic * CW, ir * CH)-((ic + iw) * CW, (ir + ih) * CH), _RGB32(&H10, &H14, &H3A), BF
    COLOR YELLOWU, _RGB32(&H10, &H14, &H3A)
    _PRINTSTRING (ic * CW, ir * CH), LEFT$(cap, iw)
    COLOR GREY, _RGB32(&H10, &H14, &H3A)
    IF ih >= 2 THEN _PRINTSTRING (ic * CW, (ir + 1) * CH), LEFT$("content " + LTRIM$(STR$(iw)) + "x" + LTRIM$(STR$(ih)), iw)
    FOR y = 2 TO ih - 1
        _PRINTSTRING (ic * CW, (ir + y) * CH), STRING$(iw, 250)     ' fill it, so overflow shows
    NEXT y
END SUB

' `dungeon.run frameshot` -- render the GDK frame at several sizes to prove the tiling.
'
' Sizes that do NOT divide evenly by the tile, on purpose: even division is the case that always
' works, so a shot of only that proves nothing about the clipping.
SUB DumpFrameShot
    DIM p AS STRING, ok AS INTEGER
    _DEST _CONSOLE
    p = AnsiFile$("frames/gdk-panel.ans")
    IF LEN(p) = 0 THEN
        PRINT PipeCol$("|12  no frame art|07 -- run |15dungeon.run framegen|07 first")
        SYSTEM 1
    END IF
    PRINT PipeCol$("|15frameshot|07 -- " + p)
    _DEST CANVAS: _FONT CH: CLS , BLACK
    FrameDemo "panel", 2, 2, 40, 8, "40 x 8 -- even"
    FrameDemo "panel", 46, 2, 23, 8, "23 x 8 -- odd"
    FrameDemo "panel", 72, 2, 8, 4, "min"
    FrameDemo "panel", 2, 12, 100, 14, "100 x 14 -- a wide panel; the rails tile and clip"
    FrameDemo "panel", 2, 28, 17, 19, "17 x 19"
    FrameDemo "panel", 22, 28, 108, 7, "108 x 7"
    _SAVEIMAGE "frameshot.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |14frameshot.png|07 (6 boxes, sizes chosen to NOT divide evenly)")
END SUB


' `dungeon.run bannershot` -- the message banner, at its widest and its narrowest.
'
' The banner AUTO-SIZES to its widest line, so a single shot of one message proves nothing: the
' box width changes, and with a 9-grid frame the corner art has to keep meeting the rails at
' every width. Two banners, one minimum-width and one at the 130-column cap.
SUB DumpBannerShot
    _DEST _CONSOLE
    PRINT PipeCol$("|15bannershot|07 -- message banner, framed")
    IF UiFramed%(UIF_BANNER) THEN
        DIM sl AS INTEGER
        sl = UiSlot%(UIF_BANNER)
        PRINT PipeCol$("  frame |14" + UI_FRAME_PATH(sl) + "|07  border " + LTRIM$(STR$(UI_FRAME_TW(sl))) + " cols x " + LTRIM$(STR$(UI_FRAME_TH(sl))) + " rows")
    ELSE
        PRINT PipeCol$("  |14no frame published|07 -- falling back to the plain LINE box")
    END IF
    _DEST CANVAS: _FONT CH: CLS , BLACK
    Banner "The GIANT SNAKE bars your path!", "[SPACE] ATTACK   [ESC] FLEE   [ press any key ]"
    _SAVEIMAGE "bannershot.png", CANVAS
    _DEST CANVAS: CLS , BLACK
    Banner "You strike the VAMPIRE for 9 damage, and it reels back into the dark of the crypt, hissing.", "Its wounds are grave -- press the advantage while it staggers.   [ press any key ]"
    _SAVEIMAGE "bannershot-wide.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  prompt row: |14" + LTRIM$(STR$(bnr_l2row)))
    PRINT PipeCol$("  wrote |14bannershot.png|07 and |14bannershot-wide.png")
END SUB


' Does a HELD die actually keep its face across a partial re-roll, in every dice style?
'
' "3d6, re-roll 1s & 2s" leaves the kept dice on the table (RollHoldSet). If a renderer ignores
' the hold, the picture is wrong AND the value is wrong -- it silently re-rolls a die the player
' was told they were keeping. Nothing on screen would look broken; the number would just be a
' different number. So assert it rather than eyeball it, for all three renderers.
'
' Also writes rollshot-held.png from the 3D path: the tray should show THREE dice, not one.
SUB HeldRerollCheck
    DIM AS INTEGER i, style, thrown, keep1, keep3, bad
    DIM AS SINGLE px1, py1, px3, py3
    DIM nm AS STRING
    _DEST _CONSOLE
    PRINT PipeCol$("|15held dice|07 -- a pinned die keeps its face across a re-roll")
    FOR style = 1 TO 3
        SELECT CASE style
            CASE 1: opt_dice3d = 0: opt_d6pips = -1: nm = "pips"
            CASE 2: opt_dice3d = 0: opt_d6pips = 0: nm = "font"
            CASE ELSE: opt_dice3d = -1: opt_d6pips = 0: nm = "3D"
        END SELECT
        cursor_erase: cursor_draw: Present
        RollHoldClear
        ' Inside a SEQUENCE, exactly as a real multi-pass re-roll runs -- the shared tray is where
        ' a leftover die would show, and a check that skipped it could not see the bug it is for.
        RollSeqBegin
        thrown = AnimatedRoll(3, 6, 0, "3d6")
        _DEST _CONSOLE                               ' a roll leaves _DEST on CANVAS -- PRINT would
        IF DIE_FACE_N < 3 THEN                       ' otherwise land on the game screen, invisibly
            PRINT PipeCol$("  |12BAD|07  " + nm + " published " + _TRIM$(STR$(DIE_FACE_N)) + " faces, expected 3")
            bad = bad + 1
        ELSE
            keep1 = DieFace%(1): keep3 = DieFace%(3)
            IF style = 3 THEN px1 = dice3d_px!(1): py1 = dice3d_py!(1): px3 = dice3d_px!(3): py3 = dice3d_py!(3)
            RollHoldSet 1, keep1
            RollHoldSet 3, keep3
            IF style = 3 THEN roll_shot = "rollshot-held.png"
            thrown = AnimatedRoll(3, 6, 0, "re-rolling the middle die")
            roll_shot = ""
            _DEST _CONSOLE
            IF DieFace%(1) <> keep1 OR DieFace%(3) <> keep3 THEN
                PRINT PipeCol$("  |12BAD|07  " + nm + " -- held " + _TRIM$(STR$(keep1)) + "/" + _TRIM$(STR$(keep3)) + _
                      " came back " + _TRIM$(STR$(DieFace%(1))) + "/" + _TRIM$(STR$(DieFace%(3))))
                bad = bad + 1
            ELSE
                PRINT PipeCol$("  |10ok |07  " + PadR$(nm, 6) + "held " + _TRIM$(STR$(keep1)) + " and " + _TRIM$(STR$(keep3)) + _
                      ", middle die re-rolled to " + _TRIM$(STR$(DieFace%(2))))
            END IF
            ' A held die must keep its SEAT as well as its face -- "it does not budge" is half
            ' the request and the half that cannot be checked by reading a number off the tray.
            IF style = 3 THEN
                ' Did the re-rolled die end up INSIDE a held one? Overlap is what "it rolls
                ' through it" means, and it is a distance -- so measure it rather than squint.
                ' Threshold is the dice's OWN footprint, not the collision radius. That radius is
                ' DIE_SIZE * 1.30 -- a deliberate cushion -- so dice stop well before they touch,
                ' and testing against the cushion failed on a 2px shortfall where nothing visibly
                ' overlapped at all. "It rolls through it" means the SHAPES intersect.
                DIM AS SINGLE d12, d32, rr
                rr = 2 * 28                            ' 2 x DIE_SIZE: actual contact
                d12 = SQR((dice3d_px!(2) - dice3d_px!(1)) ^ 2 + (dice3d_py!(2) - dice3d_py!(1)) ^ 2)
                d32 = SQR((dice3d_px!(2) - dice3d_px!(3)) ^ 2 + (dice3d_py!(2) - dice3d_py!(3)) ^ 2)
                PRINT PipeCol$("       |08gap to held dice: " + _TRIM$(STR$(INT(d12))) + " and " + _
                      _TRIM$(STR$(INT(d32))) + "  (need " + _TRIM$(STR$(INT(rr))) + ")|07")
                IF d12 < rr - 1 OR d32 < rr - 1 THEN
                    PRINT PipeCol$("  |12BAD|07  3D -- the re-rolled die is OVERLAPPING a held die")
                    bad = bad + 1
                END IF
                ' The dice must not be able to reach the running-total lane. Checked rather than
                ' eyeballed: the tray height, the die size and the inset all feed it, so any one of
                ' them moving can put dice back over the text.
                ' The tray must also END at or above the lane, not inside it -- the tray is a
                ' filled rectangle and the lane can only begin on a text row.
                IF roll_tray_bot > roll_sum_y THEN
                    PRINT PipeCol$("  |12BAD|07  3D -- the tray overlaps the total lane by " + _
                          _TRIM$(STR$(roll_tray_bot - roll_sum_y)) + "px")
                    bad = bad + 1
                END IF
                IF roll_floor_y > roll_sum_y THEN
                    PRINT PipeCol$("  |12BAD|07  3D -- dice can reach the total lane (floor " + _
                          _TRIM$(STR$(roll_floor_y)) + " vs lane " + _TRIM$(STR$(roll_sum_y)) + ")")
                    bad = bad + 1
                ELSE
                    PRINT PipeCol$("  |10ok |07  3D    total lane clear by " + _TRIM$(STR$(roll_sum_y - roll_floor_y)) + "px")
                END IF
                IF ABS(dice3d_px!(1) - px1) > 0.5 OR ABS(dice3d_py!(1) - py1) > 0.5 OR _
                   ABS(dice3d_px!(3) - px3) > 0.5 OR ABS(dice3d_py!(3) - py3) > 0.5 THEN
                    PRINT PipeCol$("  |12BAD|07  3D -- a held die MOVED: (" + _
                          _TRIM$(STR$(INT(px1))) + "," + _TRIM$(STR$(INT(py1))) + ")->(" + _
                          _TRIM$(STR$(INT(dice3d_px!(1)))) + "," + _TRIM$(STR$(INT(dice3d_py!(1)))) + ")  (" + _
                          _TRIM$(STR$(INT(px3))) + "," + _TRIM$(STR$(INT(py3))) + ")->(" + _
                          _TRIM$(STR$(INT(dice3d_px!(3)))) + "," + _TRIM$(STR$(INT(dice3d_py!(3)))) + ")")
                    bad = bad + 1
                ELSE
                    PRINT PipeCol$("  |10ok |07  3D    held dice kept their seats exactly")
                END IF
            END IF
        END IF
        RollSeqEnd
        RollHoldClear
    NEXT style
    IF bad > 0 THEN rollshot_facebad = -1
END SUB

' ----------------------------------------------------------------------------
'  dev: `dungeon.run storyshot` -- render the [M] > Storybook screen to PNGs.
'
'  Shoots THREE states, because a collection screen only breaks at its extremes
'  and a normal run shows none of them: nothing seen (every row a mystery),
'  a mixed roster (the state a real player is in), and everything seen (the
'  longest titles, the fullest list, the scroll).
' ----------------------------------------------------------------------------
SUB DumpStorybook
    DIM i AS INTEGER

    _DEST _CONSOLE
    PRINT PipeCol$("|15storyshot|07 -- rendering the Storybook at its three extremes")
    DevPackOverride

    CUTSEEN_N = 0
    StorybookScan
    PRINT PipeCol$("  roster: |14" + _TRIM$(STR$(STORY_N)) + "|07 scene(s) found")
    IF STORY_N = 0 THEN
        PRINT PipeCol$("  |12BAD|07 -- no scenes found; the Storybook would be empty")
        EXIT SUB
    END IF

    '--- 1. nothing seen ---
    StorybookPaint 1
    _SAVEIMAGE "storyshot-unseen.png", CANVAS
    _DEST _CONSOLE                                     ' StorybookPaint selects CANVAS
    PRINT PipeCol$("  wrote |10storyshot-unseen.png|07")

    '--- 2. every other one seen: the mixed state, and the one where a
    '       mis-numbered question-mark row would show up against a real title ---
    CUTSEEN_N = 0
    FOR i = 1 TO STORY_N STEP 2
        MarkCutsceneSeen _TRIM$(STORY_NAME(i))
    NEXT i
    StorybookPaint 1
    _SAVEIMAGE "storyshot-mixed.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |10storyshot-mixed.png|07")

    '--- 3. all seen ---
    CUTSEEN_N = 0
    FOR i = 1 TO STORY_N
        MarkCutsceneSeen _TRIM$(STORY_NAME(i))
    NEXT i
    StorybookPaint 3
    _SAVEIMAGE "storyshot-all.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |10storyshot-all.png|07")

    '--- and the verdict: every scene must produce a TITLE, or the Storybook
    '    lists rows nobody can identify. A blank title is what a missing
    '    `storybook` line plus a filename that slugs to nothing looks like. ---
    DIM bad AS INTEGER
    FOR i = 1 TO STORY_N
        IF LEN(_TRIM$(STORY_TITLE(i))) = 0 THEN
            bad = bad + 1
            PRINT PipeCol$("  |12BAD|07 -- scene '" + _TRIM$(STORY_NAME(i)) + "' has no title")
        END IF
    NEXT i
    IF bad = 0 THEN
        PRINT PipeCol$("  |10ok|07  -- every scene has a title and a row")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(bad)) + " scene(s) would list unidentifiably|07")
    END IF
END SUB


' ----------------------------------------------------------------------------
'  dev: `dungeon.run gifsprite <file.gif>` -- prove an animated GIF actually
'  animates through the ORDINARY sprite path (Sprite&), which is what every
'  portrait, Bestiary row, combat panel and board overlay already calls.
'
'  Sampling the handle over time is the whole test: if it never changes, the
'  sprite is a still and nobody would be able to tell from looking at one
'  frame -- the same "valid handle, picture never moves" failure the GIF
'  decoder was written for in the first place.
' ----------------------------------------------------------------------------
SUB DumpGifSprite
    DIM pth AS STRING, i AS INTEGER, h AS LONG, prev AS LONG, changes AS INTEGER
    DIM firstH AS LONG, t0 AS DOUBLE, slot AS INTEGER, seen AS STRING

    _DEST _CONSOLE
    pth = ""
    FOR i = 1 TO _COMMANDCOUNT
        IF INSTR(LCASE$(COMMAND$(i)), ".gif") > 0 THEN pth = COMMAND$(i)
    NEXT i
    IF LEN(pth) = 0 THEN pth = "assets/cutscenes/default/art/rune-pulse.gif"

    PRINT PipeCol$("|15gifsprite|07 -- " + pth)
    IF NOT _FILEEXISTS(pth) THEN
        PRINT PipeCol$("  |12BAD|07 -- no such file")
        EXIT SUB
    END IF

    h = Sprite&(pth)
    IF h = 0 THEN
        PRINT PipeCol$("  |12BAD|07 -- Sprite& returned no handle")
        EXIT SUB
    END IF

    '--- how many frames did it decode, and how long is the loop? ---
    slot = 0
    FOR i = 1 TO GSPR_N
        IF GSPR_PATH(i) = pth THEN slot = i
    NEXT i
    IF slot = 0 THEN
        PRINT PipeCol$("  |12BAD|07 -- it did not take the animated path (is it really a .gif?)")
        EXIT SUB
    END IF
    PRINT PipeCol$("  frames: |14" + _TRIM$(STR$(GSPR_FRAMES(slot))) + "|07   loop: |14" + LEFT$(_TRIM$(STR$(GSPR_TOTAL(slot))), 5) + "s|07")
    PRINT PipeCol$("  size:   |14" + _TRIM$(STR$(_WIDTH(h))) + "x" + _TRIM$(STR$(_HEIGHT(h))) + "|07")

    '--- sample across one whole loop and count DISTINCT handles ---
    t0 = TIMER(0.001)
    prev = 0: changes = 0: firstH = 0
    FOR i = 0 TO 40
        DO WHILE TIMER(0.001) - t0 < (GSPR_TOTAL(slot) / 40) * i
            '--- spin: the frame is derived from wall-clock time, so real time
            '    has to pass for it to move ---
        LOOP
        h = Sprite&(pth)
        IF i = 0 THEN firstH = h
        IF h <> prev THEN
            changes = changes + 1
            IF INSTR(seen, "|" + _TRIM$(STR$(h)) + "|") = 0 THEN seen = seen + "|" + _TRIM$(STR$(h)) + "|"
        END IF
        prev = h
    NEXT i

    PRINT PipeCol$("  handle changed |14" + _TRIM$(STR$(changes)) + "|07 time(s) across one loop")
    IF changes > 1 THEN
        PRINT PipeCol$("  |10ok|07  -- it animates through the ordinary Sprite& path")
    ELSE
        PRINT PipeCol$("  |12BAD|07 -- the handle never changed; this is a still")
    END IF
END SUB

' ----------------------------------------------------------------------------
'  dev: `dungeon.run triggerlint` -- validate assets/data/<pack>/triggers.txt.
'
'  A board trigger fails SILENTLY in two ways, and both look identical to
'  "nothing is there":
'
'    * the scene it names does not exist in this pack
'    * the CELL is not walkable, so the player can never stand on it
'
'  Neither errors, neither warns, and the author's only symptom is a beat that
'  never happens. Both are checked here, against the same collision layer the
'  movement code reads.
' ----------------------------------------------------------------------------
'--- spiral outward for a cell the player could actually stand on ---
FUNCTION NearestWalkable$ (cx AS INTEGER, cy AS INTEGER)
    DIM r AS INTEGER, dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER
    NearestWalkable$ = " (no walkable cell within 12)"
    FOR r = 1 TO 12
        FOR dy = -r TO r
            FOR dx = -r TO r
                IF ABS(dx) <> r AND ABS(dy) <> r THEN _CONTINUE   ' ring only
                nx = cx + dx: ny = cy + dy
                IF nx < 0 OR ny < 0 OR nx > SW - 1 OR ny > SH - 1 THEN _CONTINUE
                IF CellKind%(nx, ny) <> 0 THEN
                    NearestWalkable$ = " |14-- try " + _TRIM$(STR$(nx)) + "," + _TRIM$(STR$(ny)) + "|07"
                    EXIT FUNCTION
                END IF
            NEXT dx
        NEXT dy
    NEXT r
END FUNCTION

SUB DumpTriggerLint
    DIM i AS INTEGER, bad AS INTEGER, k AS INTEGER, oldsrc AS LONG
    DIM nm AS STRING, pth AS STRING, lv AS INTEGER, note AS STRING

    _DEST _CONSOLE
    PRINT PipeCol$("|15triggerlint|07 -- board-position cut-scene triggers")
    DevPackOverride
    LoadCutTriggers

    IF TRIG_N = 0 THEN
        PRINT PipeCol$("  no triggers defined (assets/data/" + _TRIM$(opt_datapack) + "/triggers.txt)")
        PRINT PipeCol$("  |10ok|07  -- nothing to get wrong")
        EXIT SUB
    END IF

    PRINT PipeCol$("  " + _TRIM$(STR$(TRIG_N)) + " trigger(s)")
    PRINT

    ' CellKind% samples the collision layer through _SOURCE. FULL_COLLIDE, not
    ' COLLIDE_BOARD: the latter is built by InitFog, which a dev mode does not
    ' run, so it would be handle 0 and every cell would read as solid. This is
    ' the documented split -- detection scans use FULL_COLLIDE, runtime samples
    ' use COLLIDE_BOARD.
    ' pin it, or the answer comes from whatever image was last selected.
    oldsrc = _SOURCE
    _SOURCE FULL_COLLIDE

    FOR i = 1 TO TRIG_N
        nm = _TRIM$(TRIG_SCENE(i))
        note = ""

        pth = CutscenePath$(nm)
        IF LEN(pth) = 0 THEN note = note + " |12no such scene|07"

        k = CellKind%(TRIG_COL(i), TRIG_ROW(i))
        IF k = 0 THEN
            '--- Do not just say no. A chamber's RECTANGLE includes its walls,
            '    so "inside the armory" and "somewhere you can stand" are
            '    different questions, and the author has no way to tell them
            '    apart by eye. Name the nearest cell that would work. ---
            note = note + " |12not walkable|07" + NearestWalkable$(TRIG_COL(i), TRIG_ROW(i))
        END IF

        lv = TRIG_LVL(i)
        IF lv < 0 OR lv > 9 THEN note = note + " |14level out of range|07"

        IF LEN(note) = 0 THEN
            PRINT PipeCol$("  |10ok |07 lvl " + _TRIM$(STR$(lv)) + " @ " + _TRIM$(STR$(TRIG_COL(i))) + "," + _TRIM$(STR$(TRIG_ROW(i))) + "  -> " + nm)
        ELSE
            bad = bad + 1
            PRINT PipeCol$("  |12BAD|07 lvl " + _TRIM$(STR$(lv)) + " @ " + _TRIM$(STR$(TRIG_COL(i))) + "," + _TRIM$(STR$(TRIG_ROW(i))) + "  -> " + nm + note)
        END IF
    NEXT i

    _SOURCE oldsrc

    PRINT
    IF bad = 0 THEN
        PRINT PipeCol$("  |10ok|07  -- every trigger names a real scene on a cell you can stand on")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(bad)) + " trigger(s) can never fire|07")
    END IF
END SUB

' ----------------------------------------------------------------------------
'  dev: `dungeon.run overlaylint` -- validate assets/data/<pack>/overlays.txt.
'
'  Same two silent failures as a trigger, and one more:
'    * the art does not resolve (nothing is drawn, nothing is said)
'    * `lit` is set on a cell the player can never see, so it never appears
'    * the art is a .gif that decodes to a single frame -- a still wearing an
'      animation's name, which is the exact failure the GIF decoder exists for
' ----------------------------------------------------------------------------
SUB DumpOverlayLint
    DIM i AS INTEGER, bad AS INTEGER, warn AS INTEGER, oldsrc AS LONG
    DIM nm AS STRING, pth AS STRING, note AS STRING, h AS LONG, slot AS INTEGER, j AS INTEGER

    _DEST _CONSOLE
    PRINT PipeCol$("|15overlaylint|07 -- art placed on the board")
    DevPackOverride
    LoadBoardOverlays

    IF OVL_N = 0 THEN
        PRINT PipeCol$("  no overlays defined (assets/data/" + _TRIM$(opt_datapack) + "/overlays.txt)")
        PRINT PipeCol$("  |10ok|07  -- nothing to get wrong")
        EXIT SUB
    END IF

    PRINT PipeCol$("  " + _TRIM$(STR$(OVL_N)) + " overlay(s)")
    PRINT

    ' FULL_COLLIDE, not COLLIDE_BOARD: the latter is built by InitFog, which a
    ' dev mode never runs, and every cell would read as solid.
    oldsrc = _SOURCE
    _SOURCE FULL_COLLIDE

    FOR i = 1 TO OVL_N
        nm = _TRIM$(OVL_ART(i))
        note = ""

        pth = Game_CutArtPath$(nm)
        IF LEN(pth) = 0 THEN
            note = note + " |12art not found|07"
        ELSE
            h = Sprite&(pth)
            IF h >= -1 THEN note = note + " |12art will not load|07"
            ' a .gif that decoded to one frame is a still pretending otherwise
            IF SprIsGif%(pth) THEN
                slot = 0
                FOR j = 1 TO GSPR_N
                    IF GSPR_PATH(j) = pth THEN slot = j
                NEXT j
                IF slot > 0 THEN
                    IF GSPR_FRAMES(slot) < 2 THEN note = note + " |14gif has only one frame|07"
                END IF
            END IF
        END IF

        ' `lit` on a cell nothing can ever see means it never draws
        IF OVL_LIT(i) THEN
            IF CellKind%(OVL_COL(i), OVL_ROW(i)) = 0 THEN
                note = note + " |14lit, but the cell is solid -- it may never be revealed|07"
            END IF
        END IF

        IF INSTR(note, "|12") > 0 THEN
            bad = bad + 1
            PRINT PipeCol$("  |12BAD|07 lvl " + _TRIM$(STR$(OVL_LVL(i))) + " @ " + _TRIM$(STR$(OVL_COL(i))) + "," + _TRIM$(STR$(OVL_ROW(i))) + "  " + nm + note)
        ELSEIF LEN(note) > 0 THEN
            warn = warn + 1
            PRINT PipeCol$("  |14warn|07 lvl " + _TRIM$(STR$(OVL_LVL(i))) + " @ " + _TRIM$(STR$(OVL_COL(i))) + "," + _TRIM$(STR$(OVL_ROW(i))) + "  " + nm + note)
        ELSE
            PRINT PipeCol$("  |10ok |07 lvl " + _TRIM$(STR$(OVL_LVL(i))) + " @ " + _TRIM$(STR$(OVL_COL(i))) + "," + _TRIM$(STR$(OVL_ROW(i))) + "  " + nm)
        END IF
    NEXT i

    _SOURCE oldsrc

    PRINT

    '--- ...and now actually DRAW them, and check the pixels changed.
    '
    '    Everything above only proves the TABLE is right. Whether anything
    '    reaches the board depends on the render hook, the fog gate and the
    '    blit -- so sample each cell before and after, and render the result to
    '    a PNG. "The data is valid" and "you can see it" are different claims,
    '    and only the second one is what was asked for. ---
    DIM before(1 TO OVL_MAX) AS _UNSIGNED LONG, drew AS INTEGER, i2 AS INTEGER

    _DEST CANVAS
    _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    '--- reveal the whole board so a `lit` overlay is allowed to appear ---
    FOR i2 = 0 TO SW - 1
        FOR j = 0 TO SH - 1
            VIS(i2, j) = TRUE
        NEXT j
    NEXT i2

    _SOURCE CANVAS
    FOR i = 1 TO OVL_N
        before(i) = POINT(OVL_COL(i) * CW + CW \ 2, OVL_ROW(i) * CH + CH \ 2)
    NEXT i

    DrawBoardOverlays

    drew = 0
    FOR i = 1 TO OVL_N
        IF POINT(OVL_COL(i) * CW + CW \ 2, OVL_ROW(i) * CH + CH \ 2) <> before(i) THEN drew = drew + 1
    NEXT i
    _SOURCE oldsrc

    _SAVEIMAGE "overlayshot.png", CANVAS
    _DEST _CONSOLE
    PRINT PipeCol$("  wrote |10overlayshot.png|07 -- " + _TRIM$(STR$(drew)) + " of " + _TRIM$(STR$(OVL_N)) + " changed the board")
    IF drew < OVL_N THEN
        bad = bad + (OVL_N - drew)
        PRINT PipeCol$("  |12" + _TRIM$(STR$(OVL_N - drew)) + " overlay(s) drew NOTHING even with the board fully revealed|07")
    END IF

    PRINT
    IF bad = 0 THEN
        PRINT PipeCol$("  |10ok|07  -- every overlay resolves, and every one changed the board")
    ELSE
        PRINT PipeCol$("  |12" + _TRIM$(STR$(bad)) + " overlay(s) will draw nothing|07")
    END IF
END SUB
