' ============================================================================
'  DUNGEON.BI -- constants, TYPEs and shared globals (top include)
' ============================================================================
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
    treasure AS INTEGER      ' gold value of the treasure the monster guards
    treasure_name AS STRING  ' name of that treasure (Dungeon!-style)
    trapped AS INTEGER       ' the treasure is trapped
    looted  AS INTEGER       ' treasure already taken
    secret_here AS INTEGER   ' (unused) legacy flag
    secret_found AS INTEGER  ' (unused) legacy flag
    treasure_item AS INTEGER ' special-item code for this room's treasure (see TRE_ITEM)
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
' Dungeon!-style monster + treasure pools, 3 per level (levels 1-9), randomised per game.
DIM SHARED MON_NAME(1 TO 9, 1 TO 3) AS STRING
' per-class 2d6 kill numbers from the cards: [level, slot, class] 1=Hero 2=Elf 3=Superhero 4=Wizard (13 = can't kill barehanded)
DIM SHARED MON_N(1 TO 9, 1 TO 3, 1 TO 4) AS INTEGER
DIM SHARED TRE_NAME(1 TO 9, 1 TO 3) AS STRING, TRE_GOLD(1 TO 9, 1 TO 3) AS INTEGER
DIM SHARED TRE_ITEM(1 TO 9, 1 TO 3) AS INTEGER   ' 0=gold, 1=MagicSword+1, 2=MagicSword+2, 3=SecretDoorCard
DIM SHARED BOSS_NAME(1 TO 4) AS STRING
' player inventory (special treasure cards)
DIM SHARED item_sword AS INTEGER      ' Magic Sword combat bonus held (0/1/2)
DIM SHARED item_secret_card AS INTEGER ' holds the Secret Door Card
DIM SHARED item_esp AS INTEGER        ' ESP Medallion: peek the treasure a monster guards
DIM SHARED item_crystal AS INTEGER    ' Crystal Ball: [V] scry every room's contents
DIM SHARED die_a AS INTEGER, die_b AS INTEGER    ' last dice shown by RollDiceShow
DIM SHARED has_key AS INTEGER                     ' player holds the Level Key
' Secret doors auto-detected from the board art (bright-blue tiles), hidden until searched.
DIM SHARED SD_X(1 TO 500) AS INTEGER, SD_Y(1 TO 500) AS INTEGER
DIM SHARED SD_FOUND(1 TO 500) AS INTEGER, SD_N AS INTEGER
DIM SHARED FULL_BOARD AS LONG                     ' pristine board (doors + secret rooms visible)
DIM SHARED VIS(0 TO 131, 0 TO 60) AS _BYTE        ' 1 = cell currently revealed
DIM SHARED DOORCELL(0 TO 131, 0 TO 60) AS _BYTE   ' 1 = a secret-door cell
DIM SHARED SECRET(0 TO 131, 0 TO 60) AS _BYTE     ' 1 = fogged (door-connected sealed cell)
DIM SHARED QX(0 TO 8000) AS INTEGER, QY(0 TO 8000) AS INTEGER   ' flood-fill queue
' settings (toggled from the SETTINGS menu) + the run timer
DIM SHARED opt_music AS INTEGER, opt_sfx AS INTEGER, opt_showdice AS INTEGER, opt_fullscreen AS INTEGER
DIM SHARED opt_realdice AS INTEGER    ' player rolls their own physical dice and types the result
DIM SHARED opt_dicemath AS INTEGER    ' TRUE: player adds modifiers; FALSE: the game adds them
DIM SHARED game_start AS DOUBLE                   ' TIMER at play start (elapsed-time display)
DIM SHARED player_name AS STRING                  ' champion name (Legendary Lords / save)
DIM SHARED dbg_on AS INTEGER, moves_made AS INTEGER   ' [~] debug overlay + move counter
