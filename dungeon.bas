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

opt_music = TRUE: opt_sfx = TRUE: opt_showdice = TRUE: opt_fullscreen = TRUE
opt_realdice = FALSE: opt_dicemath = FALSE   ' default: the computer rolls + does the math
opt_oldschool = TRUE                          ' default: classic Dungeon! 2d6 combat (off = D&D d20/HP)
opt_heroicstats = FALSE                       ' default: straight 3d6 ability rolls (on = 4d6 drop-low)
BOARD_ANSI = LoadFile$("assets/ansi/_/board-132x60-no-labels.ans")   ' same map, with secret doors
InitSectors
InitClasses
InitMonsterTables
player_class = 1                 ' default HERO until the player creates a character
InitDefaultChar 1                ' baseline stats so D&D combat works even without CREATE A CHARACTER

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
    DIM AS INTEGER sec, res, idle_ticks

    DIM i AS INTEGER
    class_name = CLASSES(player_class).name
    gold = 0: target_gold = CLASSES(player_class).gold_goal: turn_num = 0: steps_left = 0: need_roll = TRUE
    has_key = FALSE: item_sword = 0: item_secret_card = FALSE: item_esp = FALSE: item_crystal = FALSE
    moves_made = 0
    player_hp = player_maxhp         ' D&D mode: full HP at the door (max set at character creation)
    RandomizeRooms                   ' roll fresh Dungeon! monsters + treasures per game
    game_start = TIMER               ' start the run timer

    StartBoard
    Banner "Gather " + _TRIM$(STR$(target_gold)) + " gold AND the Level Key, then return to START.", "[SPACE] roll  move  [F] search  [C] sheet  [?] keys  fight  ESC flee"
    WaitKey
    cursor_erase: cursor_draw
    DrawHUD: _DISPLAY

    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        k = NormKey$(k)              ' fold arrow keys + numpad into WASD + diagonals

        ' ambient "idle" tick when the player sits still for a while
        IF k <> "" THEN
            idle_ticks = 0
        ELSE
            idle_ticks = idle_ticks + 1
            IF idle_ticks >= 600 THEN Sfx "idle": idle_ticks = 0
        END IF

        IF k = CHR$(27) THEN PlayGame = OUT_FLEE: EXIT FUNCTION
        IF k = "F" THEN DoSearch
        IF k = "C" THEN ShowCharSheet
        IF k = "V" THEN ScryView
        IF k = "?" OR k = "/" THEN ShowKeys
        IF k = "~" OR k = "`" THEN dbg_on = NOT dbg_on

        IF need_roll THEN
            IF k = " " THEN
                turn_num = turn_num + 1
                steps_left = DoRoll(1, 0, "your MOVEMENT roll")
                need_roll = FALSE
                cursor_erase             ' wipe the dice box, restore the board
                cursor_draw
            END IF
        ELSE
            IF IsMoveKey(k) AND steps_left > 0 THEN
                IF TryMove(k) THEN
                    steps_left = steps_left - 1
                    moves_made = moves_made + 1
                    ' step THROUGH a door, don't stop on it: auto-advance one more cell
                    ' the same direction (a free hop -- costs no movement point)
                    IF OnDoorNow THEN
                        IF TryMove(k) THEN moves_made = moves_made + 1
                    END IF
                    ' returning to the entrance patches you up (D&D mode)
                    IF ABS((c.x \ CW) - START_CX) <= 1 AND ABS((c.y \ CH) - START_CY) <= 1 THEN player_hp = player_maxhp
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
        IF dbg_on THEN DrawDebug
        _DISPLAY
    LOOP
END FUNCTION


FUNCTION DoCombat% (sec AS INTEGER)
    DIM k AS STRING
    DIM AS INTEGER d1, d2, sm, need, target, unbeatable
    DIM lead AS STRING, p2 AS STRING, whatguards AS STRING
    DoCombat = 0
    SECTORS(sec).monster_fought = TRUE
    IF NOT opt_oldschool THEN                      ' D&D d20/HP combat instead of 2d6-vs-target
        DoCombatDnD sec
        cursor_erase: cursor_draw: _DISPLAY
        EXIT FUNCTION
    END IF
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
            sm = DoRoll(2, item_sword, "attacking the " + SECTORS(sec).monster)
            IF last_raw = 12 THEN
                ' natural 12 -- CRITICAL HIT, always slays
                SECTORS(sec).malive = FALSE: SECTORS(sec).looted = TRUE
                Sfx "crit"
                Banner "** CRITICAL HIT! **  (natural 12)", "You cleave the " + SECTORS(sec).monster + " in a single blow!   [ press any key ]"
                WaitKey
                ClaimTreasure sec, sm
                EXIT DO
            ELSEIF last_raw = 2 THEN
                ' natural 2 -- CRITICAL FUMBLE, the monster strikes hard
                Sfx "fumble"
                Banner "** CRITICAL FUMBLE! **  (snake eyes)", "Your blade slips -- the " + SECTORS(sec).monster + " gets a free strike!   [ press any key ]"
                WaitKey
                MonsterAttack sec
                EXIT DO
            ELSEIF sm >= need THEN
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


' ===========================================================================
'  D&D-STYLE COMBAT (Oldschool Mode OFF)
'  Multi-round: player rolls d20 + to-hit vs the monster's AC; on a hit, roll
'  the class damage die (+ Magic Sword) off the monster's HP. The monster then
'  strikes back (computer rolls its d20) against the player's AC and HP. Repeat
'  until the monster drops (win + treasure) or the player is downed (lose gold,
'  dragged back to START and revived). ESC flees; wounds persist if you return.
' ===========================================================================
SUB DoCombatDnD (sec AS INTEGER)
    DIM k AS STRING, mon AS STRING, lead AS STRING
    DIM AS INTEGER lvl, mtohit, atk, dmg, rounds, matk, mdmg, thb, isboss
    DIM lost AS LONG
    mon = SECTORS(sec).monster
    isboss = SECTORS(sec).is_boss
    lvl = sec                                   ' sector index doubles as dungeon level 2..9
    mtohit = lvl: IF isboss THEN mtohit = mtohit + 2
    thb = player_tohit                          ' final to-hit incl. ability modifier
    IF SECTORS(sec).mhp_now <= 0 THEN SECTORS(sec).mhp_now = SECTORS(sec).mhp   ' fresh fight
    rounds = 0
    IF isboss THEN lead = "The BOSS " + mon ELSE lead = "The " + mon

    DO
        _LIMIT 60
        DrawCombatPanel sec, mon, lead
        k = INKEY$
        IF k = CHR$(27) THEN                     ' flee -- back out the way you came
            c.x = c.prev_x: c.y = c.prev_y
            EXIT SUB
        ELSEIF k = " " THEN
            rounds = rounds + 1
            ' ---------- player attacks ----------
            atk = GameRoll(1, 20, thb, "to hit the " + mon)
            IF last_raw = 20 THEN                 ' natural 20: crit, auto-hit, double dice
                dmg = RollDie(player_dmgdie) + RollDie(player_dmgdie) + player_dmgbonus + item_sword
                IF dmg < 1 THEN dmg = 1
                SECTORS(sec).mhp_now = SECTORS(sec).mhp_now - dmg
                Sfx "crit"
                Banner "** CRITICAL HIT! **  (natural 20)", "You savage the " + mon + " for " + _TRIM$(STR$(dmg)) + " damage!   [ press any key ]"
                WaitKey
            ELSEIF last_raw = 1 THEN              ' natural 1: auto-miss
                Sfx "fumble"
                Banner "** FUMBLE! **  (natural 1)", "Your attack goes wide of the " + mon + ".   [ press any key ]"
                WaitKey
            ELSEIF atk >= SECTORS(sec).mac THEN   ' hit
                dmg = RollDie(player_dmgdie) + player_dmgbonus + item_sword
                IF dmg < 1 THEN dmg = 1
                SECTORS(sec).mhp_now = SECTORS(sec).mhp_now - dmg
                Sfx "hit"
                Banner "You HIT!  (d20+" + _TRIM$(STR$(thb)) + " = " + _TRIM$(STR$(atk)) + " vs AC " + _TRIM$(STR$(SECTORS(sec).mac)) + ")", "You deal " + _TRIM$(STR$(dmg)) + " damage.   [ press any key ]"
                WaitKey
            ELSE                                  ' miss
                Sfx "miss"
                Banner "You MISS.  (d20+" + _TRIM$(STR$(thb)) + " = " + _TRIM$(STR$(atk)) + " vs AC " + _TRIM$(STR$(SECTORS(sec).mac)) + ")", "The " + mon + " dodges your blow.   [ press any key ]"
                WaitKey
            END IF

            IF SECTORS(sec).mhp_now <= 0 THEN     ' monster slain
                SECTORS(sec).mhp_now = 0
                SECTORS(sec).malive = FALSE: SECTORS(sec).looted = TRUE
                Sfx "treasure"
                ClaimTreasure sec, rounds
                EXIT SUB
            END IF

            ' ---------- monster strikes back (computer rolls) ----------
            matk = RollDie(20) + mtohit
            IF matk >= player_ac THEN
                mdmg = RollDie(6) + lvl \ 3: IF isboss THEN mdmg = mdmg + 3
                player_hp = player_hp - mdmg
                Sfx "bump"
                Banner "The " + mon + " HITS you!  (d20+" + _TRIM$(STR$(mtohit)) + " = " + _TRIM$(STR$(matk)) + " vs AC " + _TRIM$(STR$(player_ac)) + ")", "You take " + _TRIM$(STR$(mdmg)) + " damage.   [ press any key ]"
                WaitKey
            ELSE
                Banner "The " + mon + " misses you.  (d20+" + _TRIM$(STR$(mtohit)) + " = " + _TRIM$(STR$(matk)) + ")", "You weather the assault.   [ press any key ]"
                WaitKey
            END IF

            IF player_hp <= 0 THEN                ' downed
                player_hp = 0
                SECTORS(sec).player_died = TRUE
                DrawCombatPanel sec, mon, lead
                lost = gold: gold = 0
                Sfx "lose"
                Banner "YOU ARE DOWNED by the " + mon + "!", "You lose all your treasure (" + _TRIM$(STR$(lost)) + ") and are dragged back to START.   [ press any key ]"
                WaitKey
                c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
                player_hp = player_maxhp          ' revived at the entrance
                EXIT SUB
            END IF
        END IF
        _DISPLAY
    LOOP
END SUB


' Draw the D&D combat panel: monster + player HP bars and the action prompt.
SUB DrawCombatPanel (sec AS INTEGER, mon AS STRING, lead AS STRING)
    DIM AS INTEGER bx, by, bw, bh
    bx = 16: by = 39: bw = 100: bh = 10
    _DEST CANVAS
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered by + 1, lead + " blocks your path!"
    COLOR REDU, BOXBG
    PrintCentered by + 3, mon + "   " + HpBar$(SECTORS(sec).mhp_now, SECTORS(sec).mhp, 22) + "  " + _TRIM$(STR$(SECTORS(sec).mhp_now)) + "/" + _TRIM$(STR$(SECTORS(sec).mhp)) + " HP   AC " + _TRIM$(STR$(SECTORS(sec).mac))
    COLOR GREENU, BOXBG
    PrintCentered by + 5, class_name + " (you)   " + HpBar$(player_hp, player_maxhp, 22) + "  " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + " HP   AC " + _TRIM$(STR$(player_ac))
    COLOR CYANU, BOXBG: PrintCentered by + 8, "[SPACE] attack       [ESC] flee"
    _DISPLAY
END SUB


' A textual HP bar, e.g. "[##########----------]".
FUNCTION HpBar$ (cur AS INTEGER, mx AS INTEGER, width AS INTEGER)
    DIM AS INTEGER filled, i
    DIM s AS STRING
    IF mx <= 0 THEN mx = 1
    filled = INT((cur * width) / mx + 0.5)
    IF filled < 0 THEN filled = 0
    IF filled > width THEN filled = width
    s = "["
    FOR i = 1 TO width
        IF i <= filled THEN s = s + "#" ELSE s = s + "-"
    NEXT i
    HpBar$ = s + "]"
END FUNCTION


' Authentic DUNGEON! MONSTER ATTACK TABLE: when your attack fails, the monster
' strikes back -- roll 2d6 and apply the result.
SUB MonsterAttack (sec AS INTEGER)
    DIM r AS INTEGER, mon AS STRING, lost AS LONG
    mon = SECTORS(sec).monster
    r = DoRoll(2, 0, "the " + mon + " strikes back")
    SELECT CASE r
        CASE 2                                  ' ADVENTURER KILLED!
            lost = gold: gold = 0
            SECTORS(sec).player_died = TRUE
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
    IF opt_oldschool THEN
        slay = "You slay the " + SECTORS(sec).monster + "!  (2d6 = " + _TRIM$(STR$(sm)) + ")"
    ELSE
        slay = "You slay the " + SECTORS(sec).monster + "!  (felled in " + _TRIM$(STR$(sm)) + " rounds)"
    END IF
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
'$INCLUDE:'include/LORDS.bas'

'$INCLUDE:'include/Toolbox64/FileOps.bas'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bas'
