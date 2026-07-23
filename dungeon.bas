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
    is_boss AS INTEGER       ' room flag: tougher guardian
    treasure AS INTEGER      ' loose treasure cache in this room (gold)
    trapped AS INTEGER       ' the cache is trapped
    looted  AS INTEGER       ' cache already taken
    secret_here AS INTEGER   ' a secret door (with the Level Key) hides here
    secret_found AS INTEGER  ' the secret door has been revealed
END TYPE

TYPE CURSOR
    x            AS INTEGER
    y            AS INTEGER
    prev_x       AS INTEGER
    prev_y       AS INTEGER
    cursor_color AS _UNSIGNED LONG
END TYPE

TYPE PCLASS
    name         AS STRING
    gold_goal    AS LONG
    combat_bonus AS INTEGER     ' added to the 2d6 attack roll
    secret_bonus AS INTEGER     ' edge at finding secret doors (future use)
    blurb        AS STRING
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
DIM SHARED CLASSES(1 TO 4) AS PCLASS
DIM SHARED player_class AS INTEGER
DIM SHARED die_a AS INTEGER, die_b AS INTEGER    ' last dice shown by RollDiceShow
DIM SHARED has_key AS INTEGER                     ' player holds the Level Key

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
InitClasses
player_class = 1                 ' default HERO until the player creates a character

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
    SECTORS(6).monster = "OGRE": SECTORS(6).mnum = 9: SECTORS(6).mgold = 1400: SECTORS(6).is_boss = TRUE

    SECTORS(7).kolor = _RGB32(&H55, &HFF, &HFF): SECTORS(7).label = "LEVEL 7 - WIZ'S QUARTERS"
    SECTORS(7).start_x = 79: SECTORS(7).start_y = 1: SECTORS(7).end_x = 117: SECTORS(7).end_y = 16
    SECTORS(7).treasure = 600                      ' unguarded cache

    SECTORS(8).kolor = _RGB32(&H55, &H55, &H55): SECTORS(8).label = "LEVEL 8 - QUEEN'S QUARTERS"
    SECTORS(8).start_x = 81: SECTORS(8).start_y = 33: SECTORS(8).end_x = 117: SECTORS(8).end_y = 50
    SECTORS(8).treasure = 800: SECTORS(8).trapped = TRUE   ' rich but trapped

    SECTORS(9).kolor = _RGB32(&HAA, &H00, &HAA): SECTORS(9).label = "LEVEL 9 - THE CRYPT"
    SECTORS(9).start_x = 35: SECTORS(9).start_y = 1: SECTORS(9).end_x = 78: SECTORS(9).end_y = 16
    SECTORS(9).secret_here = TRUE                  ' SEARCH here to reveal the Level Key
END SUB


SUB InitClasses
    CLASSES(1).name = "HERO": CLASSES(1).gold_goal = 2000
    CLASSES(1).combat_bonus = 0: CLASSES(1).secret_bonus = 0
    CLASSES(1).blurb = "Balanced. A fair fighter with no glaring weakness."

    CLASSES(2).name = "ELF": CLASSES(2).gold_goal = 2000
    CLASSES(2).combat_bonus = 0: CLASSES(2).secret_bonus = 2
    CLASSES(2).blurb = "Nimble. Twice as likely to slip through secret doors."

    CLASSES(3).name = "SUPERHERO": CLASSES(3).gold_goal = 2600
    CLASSES(3).combat_bonus = 1: CLASSES(3).secret_bonus = 0
    CLASSES(3).blurb = "Mightiest in melee (+1 to attacks) -- but needs more gold."

    CLASSES(4).name = "WIZARD": CLASSES(4).gold_goal = 3000
    CLASSES(4).combat_bonus = 2: CLASSES(4).secret_bonus = 1
    CLASSES(4).blurb = "Bends fate with magic (+2 to attacks). Greediest goal."
END SUB


' Class-select screen reached from the menu's CREATE A CHARACTER option.
' Returns the chosen class index (1-4), or 0 if the player backs out.
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
FUNCTION PlayGame%
    DIM k AS STRING
    DIM AS INTEGER sec, res

    DIM i AS INTEGER
    class_name = CLASSES(player_class).name
    gold = 0: target_gold = CLASSES(player_class).gold_goal: turn_num = 0: steps_left = 0: need_roll = TRUE
    has_key = FALSE
    SECTORS(2).malive = TRUE: SECTORS(3).malive = TRUE
    SECTORS(5).malive = TRUE: SECTORS(6).malive = TRUE
    FOR i = 1 TO 9
        SECTORS(i).looted = FALSE: SECTORS(i).secret_found = FALSE
    NEXT i

    StartBoard
    Banner "Gather " + _TRIM$(STR$(target_gold)) + " gold AND the Level Key, then return to START.", "[SPACE] roll   WASD move   [F] search rooms for secret doors   fight for gold   ESC flee"
    WaitKey
    cursor_erase: cursor_draw
    DrawHUD: _DISPLAY

    DO
        _LIMIT 60
        k = UCASE$(INKEY$)

        IF k = CHR$(27) THEN PlayGame = OUT_FLEE: EXIT FUNCTION
        IF k = "F" THEN DoSearch

        IF need_roll THEN
            IF k = " " THEN
                turn_num = turn_num + 1
                steps_left = RollDiceShow(1)
                need_roll = FALSE
                cursor_erase             ' wipe the dice box, restore the board
                cursor_draw
            END IF
        ELSE
            IF (k = "W" OR k = "A" OR k = "S" OR k = "D") AND steps_left > 0 THEN
                IF TryMove(k) THEN
                    steps_left = steps_left - 1
                    IF InRoomNow THEN
                        sec = SECTOR.get_by_xy(c.x, c.y)
                        IF sec >= 1 THEN
                            ' living monster guards the room?
                            IF SECTORS(sec).malive AND LEN(SECTORS(sec).monster) > 0 THEN
                                res = DoCombat(sec)
                                IF res = 1 THEN PlayGame = OUT_LOSE: EXIT FUNCTION
                            END IF
                            ' loose treasure in a cleared / unguarded room?
                            IF SECTORS(sec).treasure > 0 AND NOT SECTORS(sec).looted AND NOT SECTORS(sec).malive THEN
                                CollectTreasure sec
                            END IF
                        END IF
                    END IF
                    ' victory: enough gold, hold the Level Key, and back at the entrance
                    IF gold >= target_gold AND has_key THEN
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
    DIM AS INTEGER d1, d2, sm, need, bonus
    DIM bhint AS STRING, bstr AS STRING
    need = SECTORS(sec).mnum
    bonus = CLASSES(player_class).combat_bonus
    DoCombat = 0

    IF bonus > 0 THEN bhint = "  (" + class_name + " +" + _TRIM$(STR$(bonus)) + ")" ELSE bhint = ""
    DIM lead AS STRING
    IF SECTORS(sec).is_boss THEN lead = "The BOSS " + SECTORS(sec).monster ELSE lead = "A " + SECTORS(sec).monster
    Banner lead + " guards the " + SECTORS(sec).label + "!", "Roll " + _TRIM$(STR$(need)) + "+ on 2d6" + bhint + "     [SPACE] ATTACK     [ESC] FLEE"

    DO
        _LIMIT 60
        k = INKEY$
        IF k = CHR$(27) THEN
            c.x = c.prev_x: c.y = c.prev_y      ' back out the way you came
            EXIT DO
        ELSEIF k = " " THEN
            sm = RollDiceShow(2)
            d1 = die_a: d2 = die_b: sm = sm + bonus
            IF bonus > 0 THEN bstr = " +" + _TRIM$(STR$(bonus)) ELSE bstr = ""
            IF sm >= need THEN
                SECTORS(sec).malive = FALSE
                gold = gold + SECTORS(sec).mgold
                Sfx "hit"
                Banner "You slay the " + SECTORS(sec).monster + "!   (2d6 = " + _TRIM$(STR$(d1)) + " + " + _TRIM$(STR$(d2)) + bstr + " = " + _TRIM$(STR$(sm)) + ")", "+ " + _TRIM$(STR$(SECTORS(sec).mgold)) + " GOLD      [ press any key ]"
                WaitKey
                EXIT DO
            ELSEIF d1 = 1 AND d2 = 1 THEN
                Sfx "lose"
                Banner "SNAKE EYES!  The " + SECTORS(sec).monster + " strikes you down.", "[ press any key ]"
                WaitKey
                DoCombat = 1
                EXIT DO
            ELSE
                DoConsequence sec, sm
                EXIT DO
            END IF
        END IF
        _DISPLAY
    LOOP

    cursor_erase
    cursor_draw
    _DISPLAY
END FUNCTION


' Dungeon!-style outcome when an attack misses (but isn't a fatal snake-eyes).
' The monster survives; the player suffers a randomised setback.
SUB DoConsequence (sec AS INTEGER, sm AS INTEGER)
    DIM roll AS INTEGER, mon AS STRING, lost AS LONG
    mon = SECTORS(sec).monster
    roll = RollDie(6)
    SELECT CASE roll
        CASE 1, 2
            Banner "The " + mon + " drives you back to the entrance!   (2d6 = " + _TRIM$(STR$(sm)) + ")", "[ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH
            c.prev_x = c.x: c.prev_y = c.y
        CASE 3, 4
            Banner "You trade blows with the " + mon + " -- a standoff.", "You hold your ground but the turn is spent.   [ press any key ]"
            WaitKey
            c.x = c.prev_x: c.y = c.prev_y
            steps_left = 0: need_roll = TRUE
        CASE 5
            lost = 200: IF lost > gold THEN lost = gold
            gold = gold - lost
            Banner "Wounded!  You flee and drop " + _TRIM$(STR$(lost)) + " gold.", "[ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH
            c.prev_x = c.x: c.prev_y = c.y
        CASE ELSE
            Banner "You parry the " + mon + " and scramble back a step.", "[ press any key ]"
            WaitKey
            c.x = c.prev_x: c.y = c.prev_y
    END SELECT
    Sfx "miss"
END SUB


' Grab (or spring the trap on) a room's loose treasure cache.
SUB CollectTreasure (sec AS INTEGER)
    DIM amt AS INTEGER, lost AS LONG
    amt = SECTORS(sec).treasure
    SECTORS(sec).looted = TRUE
    IF SECTORS(sec).trapped THEN
        lost = amt \ 2
        gold = gold + amt - lost
        Sfx "trap"
        Banner "A TRAP springs in the " + SECTORS(sec).label + "!", "You grab " + _TRIM$(STR$(amt)) + " gold but lose " + _TRIM$(STR$(lost)) + " to the trap.   [ press any key ]"
    ELSE
        gold = gold + amt
        Sfx "treasure"
        Banner "Treasure!  You loot the " + SECTORS(sec).label + ".", "+ " + _TRIM$(STR$(amt)) + " GOLD      [ press any key ]"
    END IF
    WaitKey
    cursor_erase
    cursor_draw
    _DISPLAY
END SUB


' [F] search the current room for a secret door. Only the Crypt hides one (the
' Level Key); the Elf's secret_bonus makes the d6 check far more reliable.
SUB DoSearch
    DIM sec AS INTEGER, roll AS INTEGER
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec < 1 OR NOT InRoomNow THEN
        Sfx "search"
        Banner "You search, but there are only bare walls here.", "(Search inside a room.)   [ press any key ]"
        WaitKey
        cursor_erase: cursor_draw: _DISPLAY
        EXIT SUB
    END IF
    IF SECTORS(sec).secret_here AND NOT SECTORS(sec).secret_found THEN
        roll = RollDie(6) + CLASSES(player_class).secret_bonus
        IF roll >= 5 THEN
            SECTORS(sec).secret_found = TRUE
            has_key = TRUE
            RevealSecretDoor sec
            Sfx "secret"
            Banner "A SECRET DOOR grinds open in the " + SECTORS(sec).label + "!", "You claim the LEVEL KEY.   [ press any key ]"
        ELSE
            Sfx "search"
            Banner "You run your hands over the cold stone... nothing yet.", "(Keep searching -- an Elf has the keenest eye.)   [ press any key ]"
        END IF
    ELSE
        Sfx "search"
        Banner "You search the " + SECTORS(sec).label + " but find no secrets.", "[ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: _DISPLAY
END SUB


' Paint a bright-blue secret-door tile into a room (on both canvases) so it
' shows and reads as passable terrain afterwards.
SUB RevealSecretDoor (sec AS INTEGER)
    DIM AS INTEGER dx, dy
    dx = ((SECTORS(sec).start_x + SECTORS(sec).end_x) \ 2) * CW
    dy = ((SECTORS(sec).start_y + SECTORS(sec).end_y) \ 2) * CH
    _DEST CANVAS_COPY: LINE (dx, dy)-(dx + CW - 1, dy + CH - 1), BRIGHT_BLUE, BF
    _DEST CANVAS: LINE (dx, dy)-(dx + CW - 1, dy + CH - 1), BRIGHT_BLUE, BF
END SUB


' ============================================================================
'  END SCREENS
' ============================================================================
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
        cursor_erase
        cursor_draw
        IF OnDoorNow THEN Sfx "door" ELSE Sfx "move"
        TryMove = TRUE
    ELSE
        c.x = c.prev_x: c.y = c.prev_y
        Sfx "bump"
        TryMove = FALSE
    END IF
END FUNCTION


' TRUE if the cursor cell contains a door (brown), i.e. we just stepped on one.
FUNCTION OnDoorNow%
    DIM img AS LONG, r AS INTEGER
    img = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY, img, (c.x, c.y)-(c.x + CW, c.y + CH)
    r = image_is_monochromatic(img, BROWN)
    IF NOT r THEN r = image_is_diachromatic(img, YELLOW, BROWN)
    _FREEIMAGE img
    OnDoorNow = r
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
    DIM keytag AS STRING
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec >= 1 THEN lbl = SECTORS(sec).label ELSE lbl = "THE HALLS"
    IF has_key THEN keytag = "KEY" ELSE keytag = "no key"
    LINE (0, 50 * CH)-(SW * CW, 51 * CH), BLACK, BF
    COLOR WHITE, BLACK
    hud = " " + class_name + "   GOLD " + _TRIM$(STR$(gold)) + "/" + _TRIM$(STR$(target_gold)) + "   " + keytag + "   TURN " + _TRIM$(STR$(turn_num)) + "   STEPS " + _TRIM$(STR$(steps_left)) + "   " + lbl
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
