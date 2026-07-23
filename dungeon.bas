' ============================================================================
'  DUNGEON  -  a QB64PE adaptation of TSR's DUNGEON! (1975) board game
'  Vertical slice: INTRO -> MENU -> PLAY (turn/dice movement + combat) -> END
'
'  Build:  qb64pe -w -x dungeon.bas -o dungeon.run   (run from repo root)
' ============================================================================
'$INCLUDE:'include/Toolbox64/FileOps.bi'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bi'

' TRUE / FALSE come from Toolbox64's Types.bi (included above).

' --- game states ---
CONST ST_INTRO = 0, ST_MENU = 1, ST_PLAY = 2, ST_WIN = 3, ST_LOSE = 4, ST_QUIT = 5
' --- menu results ---
CONST MENU_ENTER = 1, MENU_FLEE = 2
' --- play outcomes ---
CONST OUT_WIN = 1, OUT_LOSE = 2, OUT_FLEE = 3
' --- the entrance chamber (cell coords) ---
CONST START_CX = 59, START_CY = 24

TYPE SECTOR
    start_x AS INTEGER
    start_y AS INTEGER
    end_x   AS INTEGER
    end_y   AS INTEGER
    kolor   AS _UNSIGNED LONG
    label   AS STRING
    monster AS STRING
    mnum    AS INTEGER       ' 2d6 total needed to defeat
    mgold   AS INTEGER       ' treasure guarded (sits under the monster)
    malive  AS INTEGER
END TYPE

TYPE CURSOR
    x            AS INTEGER
    y            AS INTEGER
    prev_x       AS INTEGER
    prev_y       AS INTEGER
    cursor_color AS _UNSIGNED LONG
END TYPE

DIM SHARED AS INTEGER SW, SH, CW, CH
DIM SHARED AS LONG CANVAS, CANVAS_COPY
DIM SHARED AS _UNSIGNED LONG YELLOW, BLACK, BROWN, BRIGHT_BLUE
DIM SHARED AS _UNSIGNED LONG WHITE, GREY, REDU, GREENU, YELLOWU, CYANU, BOXBG
DIM SHARED BOARD_ANSI AS STRING
DIM SHARED SECTORS(1 TO 9) AS SECTOR
DIM SHARED c AS CURSOR
DIM SHARED AS LONG gold, target_gold
DIM SHARED AS INTEGER turn_num, steps_left, need_roll
DIM SHARED class_name AS STRING

SW = 132: SH = 51: CW = 8: CH = 16

' collision palette (must match the board ANSI art exactly)
YELLOW = _RGB32(&HFF, &HFF, &H55)
BLACK = _RGB32(&H00, &H00, &H00)
BROWN = _RGB32(&HAA, &H55, &H00)
BRIGHT_BLUE = _RGB32(&H55, &H55, &HFF)
' UI palette
WHITE = _RGB32(&HFF, &HFF, &HFF)
GREY = _RGB32(&HAA, &HAA, &HAA)
REDU = _RGB32(&HFF, &H55, &H55)
GREENU = _RGB32(&H55, &HFF, &H55)
YELLOWU = _RGB32(&HFF, &HFF, &H55)
CYANU = _RGB32(&H55, &HFF, &HFF)
BOXBG = _RGB32(&H20, &H00, &H00)

RANDOMIZE TIMER

$RESIZE:ON
$RESIZE:STRETCH
CANVAS = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY = _NEWIMAGE(SW * CW, SH * CH, 32)
_TITLE "DUNGEON"
_FONT CH
SCREEN CANVAS
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

BOARD_ANSI = LoadFile$("assets/ansi/board-132x50-no-secrets.ans")
InitSectors

' ---------------------------------------------------------------- state machine
DIM game_state AS INTEGER, r AS INTEGER, o AS INTEGER
game_state = ST_INTRO
DO
    SELECT CASE game_state
        CASE ST_INTRO
            ShowIntro
            game_state = ST_MENU
        CASE ST_MENU
            r = RunMenu
            IF r = MENU_ENTER THEN game_state = ST_PLAY ELSE game_state = ST_QUIT
        CASE ST_PLAY
            o = PlayGame
            SELECT CASE o
                CASE OUT_WIN: game_state = ST_WIN
                CASE OUT_LOSE: game_state = ST_LOSE
                CASE ELSE: game_state = ST_MENU
            END SELECT
        CASE ST_WIN
            ShowEnd TRUE
            game_state = ST_MENU
        CASE ST_LOSE
            ShowEnd FALSE
            game_state = ST_MENU
        CASE ST_QUIT
            EXIT DO
    END SELECT
LOOP

_FULLSCREEN _OFF
SCREEN 0: _DEST 0
_DELAY 0.5
_FREEIMAGE CANVAS
_FREEIMAGE CANVAS_COPY
SYSTEM


' ============================================================================
'  SETUP
' ============================================================================
SUB InitSectors
    ' LEVEL 1 - MAIN GALLERY (the safe entrance hub, no monster)
    SECTORS(1).kolor = _RGB32(&H55, &HFF, &H55): SECTORS(1).label = "LEVEL 1 - MAIN GALLERY"
    SECTORS(1).start_x = 41: SECTORS(1).start_y = 17: SECTORS(1).end_x = 79: SECTORS(1).end_y = 32

    SECTORS(2).kolor = _RGB32(&H00, &HAA, &H00): SECTORS(2).label = "LEVEL 2 - GUARD ROOM"
    SECTORS(2).start_x = 1: SECTORS(2).start_y = 17: SECTORS(2).end_x = 40: SECTORS(2).end_y = 33
    SECTORS(2).monster = "GOBLIN": SECTORS(2).mnum = 7: SECTORS(2).mgold = 700

    SECTORS(3).kolor = _RGB32(&HAA, &H00, &H00): SECTORS(3).label = "LEVEL 3 - ARMORY"
    SECTORS(3).start_x = 1: SECTORS(3).start_y = 1: SECTORS(3).end_x = 34: SECTORS(3).end_y = 16
    SECTORS(3).monster = "SKELETON": SECTORS(3).mnum = 8: SECTORS(3).mgold = 900

    SECTORS(4).kolor = _RGB32(&HFF, &H55, &H55): SECTORS(4).label = "LEVEL 4 - STORE ROOM"
    SECTORS(4).start_x = 1: SECTORS(4).start_y = 34: SECTORS(4).end_x = 40: SECTORS(4).end_y = 50

    SECTORS(5).kolor = _RGB32(&HFF, &H55, &HFF): SECTORS(5).label = "LEVEL 5 - TORTURE CHAMBER"
    SECTORS(5).start_x = 41: SECTORS(5).start_y = 33: SECTORS(5).end_x = 80: SECTORS(5).end_y = 50
    SECTORS(5).monster = "WRAITH": SECTORS(5).mnum = 8: SECTORS(5).mgold = 1000

    SECTORS(6).kolor = _RGB32(&H00, &HAA, &HAA): SECTORS(6).label = "LEVEL 6 - KING'S QUARTERS"
    SECTORS(6).start_x = 80: SECTORS(6).start_y = 17: SECTORS(6).end_x = 117: SECTORS(6).end_y = 32
    SECTORS(6).monster = "OGRE": SECTORS(6).mnum = 9: SECTORS(6).mgold = 1400

    SECTORS(7).kolor = _RGB32(&H55, &HFF, &HFF): SECTORS(7).label = "LEVEL 7 - WIZ'S QUARTERS"
    SECTORS(7).start_x = 79: SECTORS(7).start_y = 1: SECTORS(7).end_x = 117: SECTORS(7).end_y = 16

    SECTORS(8).kolor = _RGB32(&H55, &H55, &H55): SECTORS(8).label = "LEVEL 8 - QUEEN'S QUARTERS"
    SECTORS(8).start_x = 81: SECTORS(8).start_y = 33: SECTORS(8).end_x = 117: SECTORS(8).end_y = 50

    SECTORS(9).kolor = _RGB32(&HAA, &H00, &HAA): SECTORS(9).label = "LEVEL 9 - THE CRYPT"
    SECTORS(9).start_x = 35: SECTORS(9).start_y = 1: SECTORS(9).end_x = 78: SECTORS(9).end_y = 16
END SUB


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
    DIM AS INTEGER sel, i, result
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
            IF sel = 1 THEN result = MENU_ENTER: EXIT DO
            IF sel = 6 THEN result = MENU_FLEE: EXIT DO
            SOUND 110, 0.2               ' options not in this build
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
        _DISPLAY
    LOOP

    IF mus > 0 THEN _SNDSTOP mus: _SNDCLOSE mus
    _FREEIMAGE iLogo: _FREEIMAGE iLeft: _FREEIMAGE iRight: _FREEIMAGE iBlock
    RunMenu = result
END FUNCTION


' ============================================================================
'  PLAY
' ============================================================================
FUNCTION PlayGame%
    DIM k AS STRING
    DIM AS INTEGER sec, res

    class_name = "HERO"
    gold = 0: target_gold = 2000: turn_num = 0: steps_left = 0: need_roll = TRUE
    SECTORS(2).malive = TRUE: SECTORS(3).malive = TRUE
    SECTORS(5).malive = TRUE: SECTORS(6).malive = TRUE

    StartBoard
    Banner "DUNGEON  -  gather " + _TRIM$(STR$(target_gold)) + " gold, then return to START", "[SPACE] roll dice   WASD move   fight monsters for their gold   ESC flee"
    WaitKey
    cursor_erase: cursor_draw
    DrawHUD: _DISPLAY

    DO
        _LIMIT 60
        k = UCASE$(INKEY$)

        IF k = CHR$(27) THEN PlayGame = OUT_FLEE: EXIT FUNCTION

        IF need_roll THEN
            IF k = " " THEN
                turn_num = turn_num + 1
                steps_left = RollDie(6)
                need_roll = FALSE
            END IF
        ELSE
            IF (k = "W" OR k = "A" OR k = "S" OR k = "D") AND steps_left > 0 THEN
                IF TryMove(k) THEN
                    steps_left = steps_left - 1
                    ' encounter check: on a room floor with a living monster?
                    IF InRoomNow THEN
                        sec = SECTOR.get_by_xy(c.x, c.y)
                        IF sec >= 1 THEN
                            IF SECTORS(sec).malive AND LEN(SECTORS(sec).monster) > 0 THEN
                                res = DoCombat(sec)
                                IF res = 1 THEN PlayGame = OUT_LOSE: EXIT FUNCTION
                            END IF
                        END IF
                    END IF
                    ' victory check: enough gold AND back at the entrance
                    IF gold >= target_gold THEN
                        IF ABS((c.x \ CW) - START_CX) <= 1 AND ABS((c.y \ CH) - START_CY) <= 1 THEN
                            PlayGame = OUT_WIN: EXIT FUNCTION
                        END IF
                    END IF
                    IF steps_left <= 0 THEN need_roll = TRUE
                END IF
            END IF
        END IF

        DrawHUD
        _DISPLAY
    LOOP
END FUNCTION


FUNCTION DoCombat% (sec AS INTEGER)
    DIM k AS STRING
    DIM AS INTEGER d1, d2, sm, need
    need = SECTORS(sec).mnum
    DoCombat = 0

    Banner "A " + SECTORS(sec).monster + " guards the " + SECTORS(sec).label + "!", "Roll " + _TRIM$(STR$(need)) + "+ on 2d6 to win     [SPACE] ATTACK     [ESC] FLEE"

    DO
        _LIMIT 60
        k = INKEY$
        IF k = CHR$(27) THEN
            c.x = c.prev_x: c.y = c.prev_y      ' back out the way you came
            EXIT DO
        ELSEIF k = " " THEN
            d1 = RollDie(6): d2 = RollDie(6): sm = d1 + d2
            IF sm >= need THEN
                SECTORS(sec).malive = FALSE
                gold = gold + SECTORS(sec).mgold
                Banner "You slay the " + SECTORS(sec).monster + "!   (2d6 = " + _TRIM$(STR$(d1)) + " + " + _TRIM$(STR$(d2)) + " = " + _TRIM$(STR$(sm)) + ")", "+ " + _TRIM$(STR$(SECTORS(sec).mgold)) + " GOLD      [ press any key ]"
                WaitKey
                EXIT DO
            ELSEIF sm = 2 THEN
                Banner "SNAKE EYES!  The " + SECTORS(sec).monster + " strikes you down.", "[ press any key ]"
                WaitKey
                DoCombat = 1
                EXIT DO
            ELSE
                Banner "The " + SECTORS(sec).monster + " wounds you!   (2d6 = " + _TRIM$(STR$(sm)) + ")", "You retreat to the entrance.      [ press any key ]"
                WaitKey
                c.x = START_CX * CW: c.y = START_CY * CH
                c.prev_x = c.x: c.prev_y = c.y
                EXIT DO
            END IF
        END IF
        _DISPLAY
    LOOP

    cursor_erase: cursor_draw: _DISPLAY
END FUNCTION


' ============================================================================
'  END SCREENS
' ============================================================================
SUB ShowEnd (win AS INTEGER)
    _DEST CANVAS: _FONT CH: CLS , BLACK
    IF win THEN
        COLOR GREENU, BLACK: PrintCentered 20, "V I C T O R Y"
        COLOR WHITE, BLACK: PrintCentered 23, "You escape the dungeon with " + _TRIM$(STR$(gold)) + " gold!"
    ELSE
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
SUB StartBoard
    _DEST CANVAS_COPY: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)   ' clean board (collision source)
    _DEST CANVAS: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)
    render_room_labels
    c.cursor_color = _RGB32(&HFF, &H00, &H00, &HAA)
    c.x = START_CX * CW: c.y = START_CY * CH
    c.prev_x = c.x: c.prev_y = c.y
    cursor_draw
    _DISPLAY
END SUB


FUNCTION TryMove% (k AS STRING)
    c.prev_x = c.x: c.prev_y = c.y
    IF k = "A" THEN c.x = c.x - CW
    IF k = "D" THEN c.x = c.x + CW
    IF k = "W" THEN c.y = c.y - CH
    IF k = "S" THEN c.y = c.y + CH
    cursor_keep_in_bounds
    IF CanMove THEN
        cursor_erase: cursor_draw
        SOUND 350, 0.1
        TryMove = TRUE
    ELSE
        c.x = c.prev_x: c.y = c.prev_y
        SOUND 200, 0.1
        TryMove = FALSE
    END IF
END FUNCTION


SUB cursor_keep_in_bounds
    IF c.x + CW > SW * CW THEN c.x = SW - CW
    IF c.y + CH > SH * CH THEN c.y = SH - CH
    IF c.x < 0 THEN c.x = 0
    IF c.y < 0 THEN c.y = 0
END SUB


SUB cursor_erase
    _DEST CANVAS
    _PUTIMAGE (0, 0)-(SW * CW - 1, SH * CH - 1), CANVAS_COPY, CANVAS, (0, 0)-(SW * CW - 1, SH * CH - 1)
    render_room_labels
END SUB


SUB cursor_draw
    _DEST CANVAS
    LINE (c.x, c.y)-(c.x + CW - 1, c.y + CH - 1), c.cursor_color, BF
END SUB


' TRUE if the cell under the cursor is walkable: path, room floor, door, or secret door.
FUNCTION CanMove%
    DIM img AS LONG, ok AS INTEGER, sec AS INTEGER, col AS _UNSIGNED LONG
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    ok = image_is_monochromatic(img, YELLOW)                        ' path
    IF NOT ok THEN ok = image_is_diachromatic(img, YELLOW, BROWN)         ' door on path
    IF NOT ok THEN ok = image_is_diachromatic(img, YELLOW, BRIGHT_BLUE)   ' secret door on path
    IF NOT ok THEN ok = image_is_monochromatic(img, BROWN)               ' solid door
    IF NOT ok THEN ok = image_is_monochromatic(img, BRIGHT_BLUE)         ' solid secret door
    IF NOT ok THEN
        sec = SECTOR.get_by_xy(c.x, c.y)
        IF sec >= 1 THEN
            col = SECTORS(sec).kolor
            ok = image_is_monochromatic(img, col)
            IF NOT ok THEN ok = image_is_diachromatic(img, col, BROWN)
            IF NOT ok THEN ok = image_is_diachromatic(img, col, BRIGHT_BLUE)
        END IF
    END IF
    _FREEIMAGE img
    CanMove = ok
END FUNCTION


' TRUE if the cursor cell is a room floor (its sector's color).
FUNCTION InRoomNow%
    DIM img AS LONG, r AS INTEGER, sec AS INTEGER, col AS _UNSIGNED LONG
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec < 1 THEN InRoomNow = FALSE: EXIT FUNCTION
    col = SECTORS(sec).kolor
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    r = image_is_monochromatic(img, col)
    IF NOT r THEN r = image_is_diachromatic(img, col, BROWN)
    IF NOT r THEN r = image_is_diachromatic(img, col, BRIGHT_BLUE)
    _FREEIMAGE img
    InRoomNow = r
END FUNCTION


FUNCTION image_is_monochromatic% (img AS LONG, kolor AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor
    DIM check_color AS _UNSIGNED LONG
    DIM old_source AS LONG
    old_source = _SOURCE
    _SOURCE img
    FOR y = 0 TO _HEIGHT(img) - 1
        FOR x = 0 TO _WIDTH(img) - 1
            check_color = POINT(x, y)
            IF check_color <> kolor THEN
                _SOURCE old_source
                image_is_monochromatic = FALSE
                EXIT FUNCTION
            ELSE
                has_kolor = TRUE
            END IF
        NEXT x
    NEXT y
    _SOURCE old_source
    image_is_monochromatic = has_kolor
END FUNCTION


FUNCTION image_is_diachromatic% (img AS LONG, kolor1 AS _UNSIGNED LONG, kolor2 AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor1, has_kolor2
    DIM check_color AS _UNSIGNED LONG
    DIM old_source AS LONG
    old_source = _SOURCE
    _SOURCE img
    FOR y = 0 TO _HEIGHT(img) - 1
        FOR x = 0 TO _WIDTH(img) - 1
            check_color = POINT(x, y)
            IF (check_color <> kolor1) AND (check_color <> kolor2) THEN
                _SOURCE old_source
                image_is_diachromatic = FALSE
                EXIT FUNCTION
            ELSE
                IF check_color = kolor1 THEN has_kolor1 = TRUE
                IF check_color = kolor2 THEN has_kolor2 = TRUE
            END IF
        NEXT x
    NEXT y
    _SOURCE old_source
    image_is_diachromatic = has_kolor1 AND has_kolor2
END FUNCTION


FUNCTION SECTOR.get_by_xy% (x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER
    DIM s AS SECTOR
    DIM AS INTEGER sx, ex, sy, ey
    FOR i = 1 TO 9
        s = SECTORS(i)
        sx = (s.start_x - 1) * CW
        ex = (s.end_x - 1) * CW
        sy = (s.start_y - 1) * CH
        ey = (s.end_y - 1) * CH
        IF x >= sx AND x <= ex AND y >= sy AND y <= ey THEN
            SECTOR.get_by_xy = i
            EXIT FUNCTION
        END IF
    NEXT i
    SECTOR.get_by_xy = 0
END FUNCTION


' ============================================================================
'  HUD + UI HELPERS
' ============================================================================
SUB DrawHUD
    DIM sec AS INTEGER, lbl AS STRING, hud AS STRING
    _DEST CANVAS
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec >= 1 THEN lbl = SECTORS(sec).label ELSE lbl = "THE HALLS"
    LINE (0, 50 * CH)-(SW * CW, 51 * CH), BLACK, BF
    COLOR WHITE, BLACK
    hud = " " + class_name + "    GOLD " + _TRIM$(STR$(gold)) + "/" + _TRIM$(STR$(target_gold)) + "    TURN " + _TRIM$(STR$(turn_num)) + "    STEPS " + _TRIM$(STR$(steps_left)) + "    " + lbl
    _PRINTSTRING (0, 50 * CH), hud
    IF need_roll THEN
        COLOR YELLOWU, BLACK
        _PRINTSTRING ((SW - 17) * CW, 50 * CH), "[SPACE] ROLL DICE"
    ELSEIF gold >= target_gold THEN
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


SUB render_room_labels
    DIM AS _UNSIGNED LONG fg_color_blue, fg_color_red
    fg_color_blue = _RGB32(&H00, &H00, &HAA)
    fg_color_red = _RGB32(&HFF, &H55, &H55)
    _DEST CANVAS

    COLOR fg_color_red, YELLOW
    _PRINTSTRING (57 * CW, 23 * CH), "START"
    COLOR fg_color_blue, YELLOW
    _PRINTSTRING (57 * CW, 25 * CH), "MAIN"
    _PRINTSTRING (56 * CW, 26 * CH), "GALLERY"
    _PRINTSTRING (14 * CW, 10 * CH), "ARMORY"
    _PRINTSTRING (47 * CW, 7 * CH), "THE"
    _PRINTSTRING (47 * CW, 8 * CH), "CRYPT"
    _PRINTSTRING (83 * CW, 9 * CH), "WIZ'S"
    _PRINTSTRING (84 * CW, 10 * CH), "LAB"
    _PRINTSTRING (93 * CW, 7 * CH), "WIZ'S"
    _PRINTSTRING (93 * CW, 8 * CH), "TREASURE"
    _PRINTSTRING (3 * CW, 26 * CH), "KITCHEN"
    _PRINTSTRING (18 * CW, 23 * CH), "GUARD"
    _PRINTSTRING (18 * CW, 24 * CH), "ROOM"
    _PRINTSTRING (18 * CW, 41 * CH), "STORE"
    _PRINTSTRING (18 * CW, 42 * CH), "ROOM"
    _PRINTSTRING (49 * CW, 39 * CH), "TORTURE"
    _PRINTSTRING (49 * CW, 40 * CH), "CHAMBER"
    _PRINTSTRING (88 * CW, 42 * CH), "QUEEN'S"
    _PRINTSTRING (88 * CW, 43 * CH), "ANNEX"
    _PRINTSTRING (87 * CW, 34 * CH), "QUEEN'S"
    _PRINTSTRING (87 * CW, 35 * CH), "TREASURE"
    _PRINTSTRING (90 * CW, 27 * CH), "KING'S"
    _PRINTSTRING (88 * CW, 28 * CH), "LIBRARY"
    _PRINTSTRING (104 * CW, 21 * CH), "KING'S"
    _PRINTSTRING (104 * CW, 22 * CH), "TREASURE"
END SUB

'$INCLUDE:'include/Toolbox64/FileOps.bas'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bas'
