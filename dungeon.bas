' ============================================================================
'  DUNGEON  -  a QB64PE adaptation of TSR's DUNGEON! (1975) board game
'  Vertical slice: INTRO -> MENU -> PLAY (turn/dice movement + combat) -> END
'
'  Build:  qb64pe -w -x dungeon.bas -o dungeon.run   (run from repo root)
' ============================================================================
'$INCLUDE:'include/Toolbox64/FileOps.bi'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bi'

'$INCLUDE:'include/DUNGEON.BI'
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
FULL_BOARD = _NEWIMAGE(SW * CW, SH * CH, 32)
_TITLE "DUNGEON"
_FONT CH
SCREEN CANVAS
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

BOARD_ANSI = LoadFile$("assets/ansi/_/board-132x60-no-labels.ans")   ' same map, with secret doors
InitSectors
InitClasses
InitMonsterTables
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
_FREEIMAGE FULL_BOARD
SYSTEM

' ============================================================================
'  CORE GAME LOOP
' ============================================================================

FUNCTION PlayGame%
    DIM k AS STRING
    DIM AS INTEGER sec, res

    DIM i AS INTEGER
    class_name = CLASSES(player_class).name
    gold = 0: target_gold = CLASSES(player_class).gold_goal: turn_num = 0: steps_left = 0: need_roll = TRUE
    has_key = FALSE: item_sword = 0: item_secret_card = FALSE: item_esp = FALSE: item_crystal = FALSE
    RandomizeRooms                   ' roll fresh Dungeon! monsters + treasures per game

    StartBoard
    Banner "Gather " + _TRIM$(STR$(target_gold)) + " gold AND the Level Key, then return to START.", "[SPACE] roll  WASD move  [F] search  [C] character  fight for treasure  ESC flee"
    WaitKey
    cursor_erase: cursor_draw
    DrawHUD: _DISPLAY

    DO
        _LIMIT 60
        k = UCASE$(INKEY$)

        IF k = CHR$(27) THEN PlayGame = OUT_FLEE: EXIT FUNCTION
        IF k = "F" THEN DoSearch
        IF k = "C" THEN ShowCharSheet
        IF k = "V" THEN ScryView

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
                            ' a monster guards this room's treasure?
                            IF SECTORS(sec).malive AND LEN(SECTORS(sec).monster) > 0 THEN
                                res = DoCombat(sec)
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
    DIM AS INTEGER d1, d2, sm, need, target, unbeatable
    DIM lead AS STRING, p2 AS STRING, whatguards AS STRING
    need = SECTORS(sec).mnum
    target = need - item_sword                ' the raw 2d6 the player must roll (Magic Sword helps)
    unbeatable = (target > 12)                ' "-" on the card: needs a stronger blade
    IF target < 2 THEN target = 2
    DoCombat = 0

    IF SECTORS(sec).is_boss THEN lead = "The BOSS " + SECTORS(sec).monster ELSE lead = "A " + SECTORS(sec).monster
    ' the treasure is face-down under the monster -- unless the ESP Medallion peeks it
    whatguards = " guards the " + SECTORS(sec).label + "!"
    IF item_esp THEN whatguards = " guards a " + SECTORS(sec).treasure_name + "!"
    IF unbeatable THEN
        p2 = "Only a Magic Sword can harm it -- [ESC] FLEE"
    ELSE
        p2 = "Roll " + _TRIM$(STR$(target)) + "+ on 2d6 to slay it   [SPACE] ATTACK   [ESC] FLEE"
    END IF
    Banner lead + whatguards, p2

    DO
        _LIMIT 60
        k = INKEY$
        IF k = CHR$(27) THEN
            c.x = c.prev_x: c.y = c.prev_y      ' back out the way you came
            EXIT DO
        ELSEIF k = " " AND NOT unbeatable THEN
            sm = RollDiceShow(2)
            d1 = die_a: d2 = die_b
            IF sm >= target THEN
                SECTORS(sec).malive = FALSE: SECTORS(sec).looted = TRUE
                Sfx "treasure"
                ClaimTreasure sec, sm
                EXIT DO
            ELSE
                MonsterAttack sec               ' failed -- roll on the Monster Attack Table
                EXIT DO
            END IF
        END IF
        _DISPLAY
    LOOP

    cursor_erase
    cursor_draw
    _DISPLAY
END FUNCTION


' Authentic DUNGEON! MONSTER ATTACK TABLE: when your attack fails, the monster
' strikes back -- roll 2d6 and apply the result.
SUB MonsterAttack (sec AS INTEGER)
    DIM r AS INTEGER, mon AS STRING, lost AS LONG
    mon = SECTORS(sec).monster
    r = RollDiceShow(2)
    SELECT CASE r
        CASE 2                                  ' ADVENTURER KILLED!
            lost = gold: gold = 0
            Sfx "lose"
            Banner mon + " ATTACK (2): ADVENTURER KILLED!", "You drop all your treasure and crawl back to START.   [ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
        CASE 3                                   ' SERIOUS WOUND
            lost = gold \ 2: gold = gold - lost
            Sfx "trap"
            Banner mon + " ATTACK (3): SERIOUS WOUND!", "You drop half your treasure (" + _TRIM$(STR$(lost)) + ") and retreat to START.   [ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
        CASE 4, 5, 6                             ' LIGHT WOUND
            lost = 1000: IF lost > gold THEN lost = gold
            gold = gold - lost
            Sfx "miss"
            Banner mon + " ATTACK (" + _TRIM$(STR$(r)) + "): LIGHT WOUND!", "You drop " + _TRIM$(STR$(lost)) + " gold, retreat, and lose the turn.   [ press any key ]"
            WaitKey
            c.x = c.prev_x: c.y = c.prev_y
            steps_left = 0: need_roll = TRUE
        CASE 7, 8                                ' STUNNED
            lost = 500: IF lost > gold THEN lost = gold
            gold = gold - lost
            Sfx "miss"
            Banner mon + " ATTACK (" + _TRIM$(STR$(r)) + "): STUNNED!", "You drop " + _TRIM$(STR$(lost)) + " gold.   [ press any key ]"
            WaitKey
            c.x = c.prev_x: c.y = c.prev_y
        CASE ELSE                                ' 9+ MISSED
            Sfx "bump"
            Banner "The " + mon + " MISSES!  (" + _TRIM$(STR$(r)) + ")", "No harm done -- stand and fight again, or flee.   [ press any key ]"
            WaitKey
            c.x = c.prev_x: c.y = c.prev_y
    END SELECT
END SUB


' Award a slain room's treasure -- gold, or a special item card.
SUB ClaimTreasure (sec AS INTEGER, sm AS INTEGER)
    DIM slay AS STRING, line2 AS STRING, itm AS INTEGER
    slay = "You slay the " + SECTORS(sec).monster + "!  (2d6 = " + _TRIM$(STR$(sm)) + ")"
    itm = SECTORS(sec).treasure_item
    SELECT CASE itm
        CASE 1, 2                                ' Magic Sword (+1 / +2)
            IF player_class = 4 THEN             ' a Wizard cannot use a Magic Sword
                gold = gold + 500
                line2 = "A " + SECTORS(sec).treasure_name + " -- a Wizard can't wield it; you sell it for 500 gold."
            ELSEIF itm > item_sword THEN         ' keep only the stronger sword
                item_sword = itm
                line2 = "You take up the " + SECTORS(sec).treasure_name + "!  (+" + _TRIM$(STR$(itm)) + " to your attacks)"
            ELSE
                gold = gold + 500
                line2 = "Another " + SECTORS(sec).treasure_name + " -- you already hold a keener blade; +500 gold."
            END IF
        CASE 3                                    ' Secret Door Card
            item_secret_card = TRUE
            line2 = "You find the SECRET DOOR CARD -- you now sense secret doors automatically!"
        CASE 4                                    ' ESP Medallion
            item_esp = TRUE
            line2 = "You don the ESP MEDALLION -- you can now sense each room's treasure!"
        CASE 5                                    ' Crystal Ball
            item_crystal = TRUE
            line2 = "You grasp the CRYSTAL BALL -- press [V] to scry the whole dungeon!"
        CASE ELSE                                 ' plain gold treasure
            gold = gold + SECTORS(sec).treasure
            line2 = "You claim the " + SECTORS(sec).treasure_name + " -- " + _TRIM$(STR$(SECTORS(sec).treasure)) + " GOLD!"
    END SELECT
    Banner slay, line2 + "   [ press any key ]"
    WaitKey
END SUB


' [C] character sheet: class, wealth, and the special items carried.

' ============================================================================
'  MODULES
' ============================================================================
'$INCLUDE:'include/SECTOR.bas'
'$INCLUDE:'include/BOARD.bas'
'$INCLUDE:'include/CURSOR.bas'
'$INCLUDE:'include/MENU.bas'

'$INCLUDE:'include/Toolbox64/FileOps.bas'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bas'
