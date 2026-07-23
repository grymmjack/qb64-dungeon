' ============================================================================
'  MENU.bas -- intro, menu, class-select, dialogs, HUD, dice, sound
' ============================================================================

FUNCTION SelectClass%
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, yrow AS INTEGER
    sel = player_class: IF sel < 1 OR sel > 4 THEN sel = 1
    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        IF k = "W" OR k = "A" THEN
            sel = sel - 1: IF sel < 1 THEN sel = 4
            SOUND 200, 0.1
        END IF
        IF k = "S" OR k = "D" THEN
            sel = sel + 1: IF sel > 4 THEN sel = 1
            SOUND 200, 0.1
        END IF
        IF k = CHR$(13) THEN SelectClass = sel: EXIT FUNCTION
        IF k = CHR$(27) THEN SelectClass = 0: EXIT FUNCTION

        _DEST CANVAS: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 5, "C H O O S E   Y O U R   C H A M P I O N"
        FOR i = 1 TO 4
            yrow = 12 + (i - 1) * 7
            IF i = sel THEN
                LINE (28 * CW, (yrow - 1) * CH)-(104 * CW, (yrow + 3) * CH), BOXBG, BF
                LINE (28 * CW, (yrow - 1) * CH)-(104 * CW, (yrow + 3) * CH), REDU, B
                COLOR WHITE, BOXBG: PrintCentered yrow, CLASSES(i).name + "   (goal " + _TRIM$(STR$(CLASSES(i).gold_goal)) + " gold)"
                COLOR YELLOWU, BOXBG: PrintCentered yrow + 2, CLASSES(i).blurb
            ELSE
                COLOR GREY, BLACK: PrintCentered yrow, CLASSES(i).name + "   (goal " + _TRIM$(STR$(CLASSES(i).gold_goal)) + " gold)"
            END IF
        NEXT i
        COLOR CYANU, BLACK: PrintCentered 45, "[W/S] choose      [ENTER] confirm      [ESC] back"
        _DISPLAY
    LOOP
END FUNCTION


' ============================================================================
'  INTRO
' ============================================================================

SUB ShowIntro
    DIM ansi AS STRING, mus AS LONG, k AS STRING
    ansi = LoadFile$("assets/ansi/vermin-radioactive-logo.ans")
    mus = _SNDOPEN("assets/music/vr-theme.rad")
    IF mus > 0 THEN _SNDPLAY mus
    _DEST CANVAS: _FONT CH: CLS , BLACK
    ANSI_Print (ansi)
    _DISPLAY
    DO: _LIMIT 30: k = INKEY$: _DISPLAY: LOOP UNTIL k <> ""
    IF mus > 0 THEN _SNDSTOP mus: _SNDCLOSE mus
END SUB


' ============================================================================
'  MENU
' ============================================================================

FUNCTION RunMenu%
    DIM logo AS STRING
    DIM lw(1 TO 4) AS STRING, rw(1 TO 4) AS STRING, bl(1 TO 6) AS STRING
    DIM AS LONG iLogo, iLeft, iRight, iBlock, mus
    DIM AS INTEGER sel, i, result, chosen
    DIM AS LONG t
    DIM k AS STRING

    logo = LoadFile$("assets/ansi/dungeon-menu-logo.ans")
    FOR i = 1 TO 4: lw(i) = LoadFile$("assets/ansi/dungeon-menu-left-wall-" + _TRIM$(STR$(i)) + ".ans"): NEXT
    FOR i = 1 TO 4: rw(i) = LoadFile$("assets/ansi/dungeon-menu-right-wall-" + _TRIM$(STR$(i)) + ".ans"): NEXT
    FOR i = 1 TO 6: bl(i) = LoadFile$("assets/ansi/dungeon-menu-block-" + _TRIM$(STR$(i)) + ".ans"): NEXT

    iLogo = _NEWIMAGE(102 * CW, 15 * CH, 32)
    iLeft = _NEWIMAGE(15 * CW, 51 * CH, 32)
    iRight = _NEWIMAGE(16 * CW, 51 * CH, 32)
    iBlock = _NEWIMAGE(95 * CW, 31 * CH, 32)
    _DEST iLogo: _FONT CH: ANSI_Print (logo)
    _DEST iLeft: _FONT CH: ANSI_Print (lw(1))
    _DEST iRight: _FONT CH: ANSI_Print (rw(1))
    _DEST iBlock: _FONT CH: ANSI_Print (bl(1))

    mus = _SNDOPEN("assets/music/everdark.rad")
    IF mus > 0 THEN _SNDLOOP mus

    sel = 1: t = 0: result = 0
    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        IF k = "A" OR k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = 6
        IF k = "D" OR k = "S" THEN sel = sel + 1: IF sel > 6 THEN sel = 1
        IF k = "A" OR k = "W" OR k = "S" OR k = "D" THEN SOUND 200, 0.1
        IF k = CHR$(13) THEN
            IF sel = 1 THEN
                result = MENU_ENTER: EXIT DO
            ELSEIF sel = 2 THEN
                chosen = SelectClass
                IF chosen > 0 THEN player_class = chosen
            ELSEIF sel = 6 THEN
                result = MENU_FLEE: EXIT DO
            ELSE
                SOUND 110, 0.2           ' LOAD / LORDS / SETTINGS not in this build
            END IF
        END IF
        IF k = CHR$(27) THEN result = MENU_FLEE: EXIT DO

        ' torch-flicker the walls now and then
        t = t + 1
        IF t MOD 10 = 0 THEN
            i = RollDie(5)
            IF i <= 4 THEN
                _DEST iLeft: CLS , BLACK: ANSI_Print (lw(i))
                _DEST iRight: CLS , BLACK: ANSI_Print (rw(i))
            END IF
        END IF

        ' compose the frame
        _DEST CANVAS: CLS , BLACK
        _PUTIMAGE (0, 0), iLeft
        _PUTIMAGE (116 * CW, 0), iRight
        _PUTIMAGE (14 * CW, 0), iLogo
        _DEST iBlock: CLS , BLACK: ANSI_Print (bl(sel))
        _DEST CANVAS: _PUTIMAGE (19 * CW, 15 * CH), iBlock
        COLOR CYANU, BLACK: PrintCentered 47, "CHAMPION: " + CLASSES(player_class).name
        _DISPLAY
    LOOP

    IF mus > 0 THEN _SNDSTOP mus: _SNDCLOSE mus
    _FREEIMAGE iLogo: _FREEIMAGE iLeft: _FREEIMAGE iRight: _FREEIMAGE iBlock
    RunMenu = result
END FUNCTION


' ============================================================================
'  PLAY
' ============================================================================

SUB ShowCharSheet
    DIM y AS INTEGER, swordtxt AS STRING
    _DEST CANVAS
    LINE (30 * CW, 14 * CH)-(102 * CW, 38 * CH), BOXBG, BF
    LINE (30 * CW, 14 * CH)-(102 * CW, 38 * CH), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered 16, "-=  C H A R A C T E R  =-"
    COLOR WHITE, BOXBG
    PrintCentered 19, "Champion:  " + class_name
    PrintCentered 21, "Gold:  " + _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold))
    IF has_key THEN PrintCentered 23, "Level Key:  HELD" ELSE PrintCentered 23, "Level Key:  not yet found"
    IF item_sword > 0 THEN swordtxt = "Magic Sword +" + _TRIM$(STR$(item_sword)) ELSE swordtxt = "(none)"
    PrintCentered 25, "Magic Sword:  " + swordtxt
    IF item_secret_card THEN PrintCentered 27, "Secret Door Card:  HELD" ELSE PrintCentered 27, "Secret Door Card:  (none)"
    IF item_esp THEN PrintCentered 29, "ESP Medallion:  HELD" ELSE PrintCentered 29, "ESP Medallion:  (none)"
    IF item_crystal THEN PrintCentered 31, "Crystal Ball:  HELD  ([V] to scry)" ELSE PrintCentered 31, "Crystal Ball:  (none)"
    COLOR CYANU, BOXBG: PrintCentered 34, CLASSES(player_class).blurb
    COLOR YELLOWU, BOXBG: PrintCentered 37, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [V] Crystal Ball: scry every level's guardian and the treasure it hides.

SUB ScryView
    DIM i AS INTEGER, y AS INTEGER, mons AS STRING, tre AS STRING
    IF NOT item_crystal THEN
        Banner "You have no way to scry the dungeon.", "Find the CRYSTAL BALL first.   [ press any key ]"
        WaitKey
        cursor_erase: cursor_draw: DrawHUD: _DISPLAY
        EXIT SUB
    END IF
    _DEST CANVAS
    LINE (20 * CW, 8 * CH)-(112 * CW, 45 * CH), BOXBG, BF
    LINE (20 * CW, 8 * CH)-(112 * CW, 45 * CH), CYANU, B
    COLOR CYANU, BOXBG: PrintCentered 10, "-=  C R Y S T A L   B A L L  =-"
    FOR i = 2 TO 9
        y = 12 + (i - 2) * 4
        IF SECTORS(i).malive THEN mons = SECTORS(i).monster ELSE mons = "(cleared)"
        IF SECTORS(i).looted THEN tre = "looted" ELSE tre = SECTORS(i).treasure_name
        COLOR WHITE, BOXBG: PrintCentered y, SECTORS(i).label
        COLOR GREY, BOXBG: PrintCentered y + 1, mons + "   guarding   " + tre
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 43, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [F] search for a hidden secret door within a couple of cells of the cursor.
' The Elf's secret_bonus makes the d6 check far more reliable. The first door
' found also yields the Level Key.

SUB ShowEnd (win AS INTEGER)
    _DEST CANVAS: _FONT CH: CLS , BLACK
    IF win THEN
        Sfx "win"
        COLOR GREENU, BLACK: PrintCentered 20, "V I C T O R Y"
        COLOR WHITE, BLACK: PrintCentered 23, "You escape the dungeon with " + _TRIM$(STR$(gold)) + " gold and the Level Key!"
    ELSE
        Sfx "lose"
        COLOR REDU, BLACK: PrintCentered 20, "Y O U   D I E D"
        COLOR GREY, BLACK: PrintCentered 23, "The dungeon claims another soul..."
    END IF
    COLOR YELLOWU, BLACK: PrintCentered 27, "[ press any key to return to the menu ]"
    _DISPLAY
    WaitKey
END SUB


' ============================================================================
'  BOARD + CURSOR  (pixel-color collision, adapted from TEST-MOVEMENT-MAP.bas)
' ============================================================================

SUB DrawHUD
    DIM sec AS INTEGER, lbl AS STRING, hud AS STRING
    _DEST CANVAS
    DIM keytag AS STRING
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec >= 1 THEN lbl = SECTORS(sec).label ELSE lbl = "THE HALLS"
    IF has_key THEN keytag = "KEY" ELSE keytag = "no key"
    DIM inv AS STRING
    IF item_sword > 0 THEN inv = inv + "  SWD+" + _TRIM$(STR$(item_sword))
    IF item_secret_card THEN inv = inv + "  SDC"
    IF item_esp THEN inv = inv + "  ESP"
    IF item_crystal THEN inv = inv + "  CRY"
    LINE (0, 50 * CH)-(SW * CW, 51 * CH), BLACK, BF
    COLOR WHITE, BLACK
    hud = " " + class_name + "   GOLD " + _TRIM$(STR$(gold)) + "/" + _TRIM$(STR$(target_gold)) + "   " + keytag + inv + "   TURN " + _TRIM$(STR$(turn_num)) + "   STEPS " + _TRIM$(STR$(steps_left)) + "   " + lbl
    _PRINTSTRING (0, 50 * CH), hud
    IF need_roll THEN
        COLOR YELLOWU, BLACK
        _PRINTSTRING ((SW - 17) * CW, 50 * CH), "[SPACE] ROLL DICE"
    ELSEIF gold >= target_gold AND has_key THEN
        COLOR GREENU, BLACK
        _PRINTSTRING ((SW - 23) * CW, 50 * CH), "RETURN TO START TO WIN!"
    END IF
END SUB



SUB Banner (l1 AS STRING, l2 AS STRING)
    _DEST CANVAS
    LINE (18 * CW, 21 * CH)-(114 * CW, 30 * CH), BOXBG, BF
    LINE (18 * CW, 21 * CH)-(114 * CW, 30 * CH), REDU, B
    COLOR WHITE, BOXBG: PrintCentered 24, l1
    COLOR YELLOWU, BOXBG: PrintCentered 27, l2
    _DISPLAY
END SUB



SUB PrintCentered (row AS INTEGER, t AS STRING)
    DIM x AS INTEGER
    x = (SW - LEN(t)) \ 2
    IF x < 0 THEN x = 0
    _PRINTSTRING (x * CW, row * CH), t
END SUB



SUB WaitKey
    DIM k AS STRING
    DO: k = INKEY$: LOOP UNTIL k = ""              ' drain buffered keys
    DO: _LIMIT 60: k = INKEY$: _DISPLAY: LOOP UNTIL k <> ""
END SUB



FUNCTION RollDie% (sides AS INTEGER)
    RollDie = INT(RND * sides) + 1
END FUNCTION


' Named sound effects (SOUND queues in the background, so short sequences play out).

SUB Sfx (kind AS STRING)
    SELECT CASE kind
        CASE "move": SOUND 350, 0.08
        CASE "bump": SOUND 170, 0.12
        CASE "door": SOUND 300, 0.06: SOUND 520, 0.09
        CASE "secret": SOUND 700, 0.05: SOUND 950, 0.05: SOUND 1250, 0.12
        CASE "treasure": SOUND 820, 0.05: SOUND 1040, 0.05: SOUND 1320, 0.12
        CASE "trap": SOUND 240, 0.1: SOUND 150, 0.14: SOUND 90, 0.22
        CASE "hit": SOUND 620, 0.05: SOUND 320, 0.12
        CASE "miss": SOUND 200, 0.14
        CASE "search": SOUND 300, 0.05: SOUND 260, 0.05
        CASE "win": SOUND 523, 0.12: SOUND 659, 0.12: SOUND 784, 0.12: SOUND 1046, 0.28
        CASE "lose": SOUND 300, 0.16: SOUND 220, 0.16: SOUND 130, 0.34
        CASE "select": SOUND 220, 0.06
    END SELECT
END SUB


' A single square pip.

SUB Pip (x AS INTEGER, y AS INTEGER, r AS INTEGER, col AS _UNSIGNED LONG)
    LINE (x - r, y - r)-(x + r, y + r), col, BF
END SUB


' Draw one d6 face (value 1-6) as an sz x sz die at pixel (px,py).

SUB DrawDie (px AS INTEGER, py AS INTEGER, sz AS INTEGER, pips AS INTEGER)
    DIM AS INTEGER x2, y2, r, cxl, cxm, cxr, cyt, cym, cyb
    DIM AS _UNSIGNED LONG face, edge, pipc
    face = _RGB32(&HF0, &HF0, &HE6): edge = _RGB32(&H78, &H78, &H70): pipc = _RGB32(&H18, &H10, &H10)
    x2 = px + sz: y2 = py + sz
    LINE (px + 5, py + 5)-(x2 + 5, y2 + 5), _RGB32(&H00, &H00, &H00), BF   ' drop shadow
    LINE (px, py)-(x2, y2), face, BF
    LINE (px, py)-(x2, y2), edge, B
    r = sz \ 11
    cxl = px + sz \ 4: cxm = px + sz \ 2: cxr = x2 - sz \ 4
    cyt = py + sz \ 4: cym = py + sz \ 2: cyb = y2 - sz \ 4
    IF pips = 1 OR pips = 3 OR pips = 5 THEN Pip cxm, cym, r, pipc
    IF pips >= 2 THEN
        Pip cxl, cyt, r, pipc
        Pip cxr, cyb, r, pipc
    END IF
    IF pips >= 4 THEN
        Pip cxr, cyt, r, pipc
        Pip cxl, cyb, r, pipc
    END IF
    IF pips = 6 THEN
        Pip cxl, cym, r, pipc
        Pip cxr, cym, r, pipc
    END IF
END SUB


' Tumble n d6 on screen (with a rolling sound), settle on the result, and
' return the total. The individual faces land in die_a / die_b.

FUNCTION RollDiceShow% (n AS INTEGER)
    DIM AS INTEGER sz, gap, bw, bx, by, f, j
    sz = 52: gap = 18
    bw = n * sz + (n - 1) * gap
    bx = (SW * CW - bw) \ 2
    by = 33 * CH
    die_a = RollDie(6): die_b = 0
    IF n = 2 THEN die_b = RollDie(6)

    FOR f = 1 TO 16
        _DEST CANVAS
        LINE (bx - gap, by - gap)-(bx + bw + gap, by + sz + gap), BOXBG, BF
        LINE (bx - gap, by - gap)-(bx + bw + gap, by + sz + gap), REDU, B
        FOR j = 0 TO n - 1
            IF f < 13 THEN
                DrawDie bx + j * (sz + gap), by, sz, RollDie(6)
            ELSEIF j = 0 THEN
                DrawDie bx, by, sz, die_a
            ELSE
                DrawDie bx + sz + gap, by, sz, die_b
            END IF
        NEXT j
        SOUND 380 + f * 28, 0.05
        _DISPLAY
        _LIMIT 22
    NEXT f
    _DELAY 0.7                       ' hold so the settled dice are readable

    IF n = 2 THEN RollDiceShow = die_a + die_b ELSE RollDiceShow = die_a
END FUNCTION


