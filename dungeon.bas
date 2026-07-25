' ============================================================================
'  DUNGEON  -  a QB64PE adaptation of TSR's DUNGEON! (1975) board game
'  Vertical slice: INTRO -> MENU -> PLAY (turn/dice movement + combat) -> END
'
'  Build:  qb64pe -w -x dungeon.bas -o dungeon.run   (run from repo root)
' ============================================================================
'$INCLUDE:'include/Toolbox64/FileOps.bi'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bi'

'$INCLUDE:'include/DUNGEON.BI'
'$INCLUDE:'include/DICE3D/_ALL.BI'      ' 3D polyhedral dice (types + globals; bodies at bottom)
'$INCLUDE:'include/DICE3D_GAME.bi'      ' dungeon-side 3D dice sets (needs DICE3D_CONFIG from _ALL.BI)
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
opt_voice = TRUE                              ' typewriter text speaks in blips
opt_musicvol = 7: opt_sfxvol = 8: opt_voicevol = 6   ' 0..10 volume sliders
opt_realdice = FALSE: opt_dicemath = FALSE   ' default: the computer rolls + does the math
opt_oldschool = FALSE                         ' default: D&D d20/HP combat (on = classic Dungeon! 2d6)
opt_heroicstats = TRUE                        ' default: 4d6-drop-lowest ability rolls (off = straight 3d6)
opt_boardgame = FALSE                         ' default: free movement (single player); >1 player forces it ON
opt_fov = FALSE                               ' default off: whole map visible (on = line-of-sight exploration)
num_players = 1                               ' hot-seat players (1..4); >1 forces Boardgame Mode
opt_dicecolor = 3                             ' dice palette: 0 Bone 1 Blood 2 Emerald 3 Sapphire 4 Gold 5 Amethyst
opt_dicesolid = TRUE                          ' filled die body with a contrasting number (off = hollow outline)
opt_d6pips = FALSE                            ' d6 rolls use the font's numbered die (on = hand-drawn pips)
opt_dicespeed = 0                             ' dice tumble pacing: 0 Slow, 1 Normal, 2 Fast, 3 Instant
opt_smooth = TRUE                             ' default: bilinear-smoothed fullscreen (off = crisp pixel-doubled)
opt_combatspeed = 0                           ' (legacy) superseded by opt_msgdelay
opt_msgdelay = 2                              ' message auto-advance hold: 1-5 seconds, or 0 = wait for a key
opt_hardcore = FALSE                          ' default casual: idling is safe (on = time passes while idle)
opt_critfumble = TRUE                         ' default on: the crit/fumble effects engine adds cinematics + swings
opt_mon_dicecolor = 1                         ' monster dice default to a menacing Blood red
opt_mon_dicesolid = TRUE: opt_mon_d6pips = FALSE: opt_mon_dicespeed = 0
opt_dice3d = FALSE: opt_mon_dice3d = FALSE    ' dice render: FALSE = font/pip dice (default), TRUE = 3D dice
opt_dice3d_set = 5: opt_mon_dice3d_set = 1    ' default 3D sets: player Sapphire, monster Ruby (overridden by save)
opt_dicefont = 1                              ' default dice numeral font: built-in (overridden by save)
IF opt_oldschool THEN opt_lootrecovery = 0 ELSE opt_lootrecovery = 1   ' 0 OFF (lost), 1 NORMAL (always reclaim), 2 SOULS-LIKE (one chance)
opt_maxdeaths = 3                             ' lives before permadeath: reach 3 deaths and the run is forfeited (1..9)
LoadSettings                                  ' restore the player's saved preferences (overrides defaults)
ApplyDisplay                                  ' apply fullscreen + smoothing per the (possibly loaded) settings
BOARD_ANSI = LoadFile$("assets/ansi/_/board-132x60-no-labels.ans")   ' same map, with secret doors
InitSectors
InitClasses
InitMonsterTables
InitDice
InitLabels                       ' build the room-label table + the label-cell mask (keeps monsters off labels)
InitEffects                      ' load the crit/fumble effect tables (assets/data/effects.txt)
LoadTraps                        ' load the curio-chest traps (assets/data/traps.txt)
InitFlavor                       ' load the room + combat flavor text (assets/flavor/*.txt)
InitCombatText                   ' load per-monster + per-class combat event text (assets/flavor/*_events.txt)
LoadPlaylist                     ' load the per-level music map (assets/music/playlist.txt)
InitSfxFiles                     ' preload any real sound-effect files (assets/sfx/*); beeper covers the rest
LoadDiceSets                     ' load the 3D dice sets (assets/data/diceset.txt); font dice if it fails
LoadDiceFonts                    ' load the selectable 3D-dice numeral fonts (assets/fonts/dicefonts.txt)
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
            StopLevelMusic                       ' silence the in-game track before the menu music resumes
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
    DIM AS INTEGER sec, res, idle_ticks, sd, mvb, curlvl

    DIM i AS INTEGER
    DIM hint AS STRING
    DIM didload AS INTEGER
    didload = FALSE
    IF HasSave THEN                  ' a saved delve exists -- offer to continue it
        IF AskContinue THEN LoadGameApply: didload = TRUE
    END IF

    IF NOT didload THEN
        SetupPlayers                     ' build every player (multiplayer: class + 3d6 roll-up + name each)
        game_start = TIMER               ' start the run timer
        moves_made = 0: turn_num = 0: steps_left = 0
        cur_player = 1
        run_seed = INT(RND * 2000000000) + 1   ' seed this dungeon so save/load can reproduce it exactly
        RANDOMIZE run_seed
        StartBoard                       ' build the board + fog + DetectRooms (resets the cursor to START)
        RandomizeRooms                   ' give every detected room its own monster + treasure (+ the key room)
        LoadActivePlayer cur_player      ' player 1 becomes the active player (pos / colour / stats)
        need_roll = TRUE: IF NOT opt_boardgame THEN need_roll = FALSE
        loiter = 0                       ' fresh danger meter for lingering
        FOR i = 1 TO 9: lvl_kills(i) = 0: lvl_gold(i) = 0: lvl_reached(i) = FALSE: lvl_cleared(i) = FALSE: NEXT i   ' fresh chronicle
        lvl_reached(1) = TRUE            ' you start on the 1st level
        char_level = 1: char_xp = 0      ' fresh D&D level + XP for this run
        item_potion_small = 0: item_potion_large = 0
        item_armor = 0: item_bow = FALSE: item_boots = FALSE: item_teleport = 0   ' newer items aren't in PLAYER type -- clear them so nothing leaks between games
        poison_turns = 0: fire_turns = 0: frost_turns = 0: siren_turns = 0   ' no lingering trap effects
        deaths(1) = 0: deaths(2) = 0: deaths(3) = 0: deaths(4) = 0           ' fresh skull tally
        player_out = FALSE                                                  ' nobody has forfeited yet

        DIM ident AS STRING                                                 ' "Grognard the Fast, a HERO" (or "the HERO" if unnamed)
        IF _TRIM$(player_name) <> "" THEN ident = _TRIM$(player_name) + ", a " + class_name ELSE ident = "the " + class_name

        IF num_players > 1 THEN
            ScrollText "THE DESCENT", "Torchlight gutters as " + _TRIM$(STR$(num_players)) + " rivals cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. The Level Key is said to lie on the " + Ordinal$(key_level) + " level. Whoever is first to claim its key, a fortune in gold, and return alive to this entrance wins eternal glory. Let the delving begin."
        ELSE
            ScrollText "THE DESCENT", "Torchlight gutters as you, " + ident + ", cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. The Level Key is rumoured to lie on the " + Ordinal$(key_level) + " level -- take it, gather " + _TRIM$(STR$(target_gold)) + " gold, and return alive to this entrance. A Crystal Ball would reveal exactly which room hides it. Few ever escape."
        END IF
    END IF

    cursor_erase: cursor_draw        ' clear the narration, reveal the board
    IF opt_boardgame THEN hint = "[SPACE] roll  " ELSE hint = ""
    IF didload THEN
        Banner "-- RESUMED --  " + _TRIM$(player_name) + " the " + class_name + " returns to the depths.", "[G] saves your progress anytime.   [ press any key ]"
    ELSE
        Banner "Gather " + _TRIM$(STR$(target_gold)) + " gold AND the Level Key, then return to START.", hint + "move  [F] search  [G] save  [?] keys  fight  ESC flee"
    END IF
    WaitKey
    IF NOT didload THEN AnnounceTurn cur_player   ' multiplayer: announce whose turn it is
    cursor_erase: cursor_draw
    DrawHUD: _DISPLAY

    DIM startlvl AS INTEGER                        ' start this level's music before the first step
    music_level = 0: music_curfile = ""
    startlvl = SECTOR.get_by_xy(c.x, c.y): IF startlvl < 1 THEN startlvl = 1
    PlayLevelMusic startlvl

    DO
        _LIMIT 60
        IF player_out THEN                        ' the active player has spent their last life
            ' solo (or last one standing) -> the run is over for good. Delete the save so a
            ' permadeath run can never be "continued" back to life.
            IF HandleForfeit THEN DeleteSave: PlayGame = OUT_LOSE: EXIT FUNCTION
        END IF
        k = UCASE$(INKEY$)
        k = NormKey$(k)              ' fold arrow keys + numpad into WASD + diagonals

        ' HARDCORE only: standing idle counts as lingering -- time passes, danger gathers.
        ' In casual mode (default) you can stand still and plan in perfect safety.
        IF k <> "" THEN
            idle_ticks = 0
        ELSEIF opt_hardcore THEN
            idle_ticks = idle_ticks + 1
            IF idle_ticks >= 600 THEN
                idle_ticks = 0
                IF NOT InRoomNow THEN LoiterTick   ' danger gathers only out in the open halls
            END IF
        END IF

        IF k = CHR$(27) THEN PlayGame = OUT_FLEE: EXIT FUNCTION
        IF k = "F" THEN DoSearch
        IF k = "C" THEN ShowCharSheet
        IF k = "V" THEN ScryView
        IF k = "H" THEN UsePotion FALSE: cursor_erase: cursor_draw: DrawHUD: _DISPLAY
        IF k = "P" THEN PauseGame: idle_ticks = 0
        IF k = "G" AND num_players = 1 THEN SaveAndToast: idle_ticks = 0
        IF k = "?" OR k = "/" THEN ShowKeys
        IF k = "~" OR k = "`" THEN dbg_on = NOT dbg_on

        IF k = "T" AND item_teleport > 0 THEN     ' Teleport Scroll -- whisk back to START
            item_teleport = item_teleport - 1
            Sfx "key"
            Banner "You read a TELEPORT SCROLL -- reality folds around you!", "You reappear at the entrance.   [ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
            player_hp = player_maxhp: need_roll = TRUE: IF NOT opt_boardgame THEN need_roll = FALSE
            steps_left = 0: loiter = 0
            cursor_erase: cursor_draw: FadeInCurrent: DrawHUD: _DISPLAY
        END IF

        IF need_roll THEN
            IF k = " " THEN
                turn_num = turn_num + 1
                mvb = 0: IF item_boots THEN mvb = 2       ' Elf Boots add to the movement roll
                steps_left = DoRoll(1, mvb, "your MOVEMENT roll")
                need_roll = FALSE
                cursor_erase             ' wipe the dice box, restore the board
                cursor_draw
            END IF
        ELSE
            ' frozen by a frost bomb? each move attempt just melts a turn off the ice
            IF IsMoveKey(k) AND frost_turns > 0 THEN
                frost_turns = frost_turns - 1
                Sfx "bump"
                Banner "You are frozen fast!", "The rime locks your limbs (" + _TRIM$(STR$(frost_turns)) + " turns of frost remain)."
                _DELAY 0.7
                cursor_erase: cursor_draw: DrawHUD: _DISPLAY
            ' board-game mode gates movement on the dice roll + steps; free mode walks anytime
            ELSEIF IsMoveKey(k) AND (NOT opt_boardgame OR steps_left > 0) THEN
                sd = StrongDoorAhead(k)
                IF sd > 0 THEN
                    ' a reinforced door blocks the way -- spend the step trying to break it
                    IF opt_boardgame THEN steps_left = steps_left - 1
                    IF BreakDoorAttempt(sd) THEN
                        IF TryMove(k) THEN
                            moves_made = moves_made + 1
                            IF OnDoorNow THEN
                                DOOROPEN(c.x \ CW, c.y \ CH) = TRUE   ' broken door is now open (FOV)
                                IF TryMove(k) THEN moves_made = moves_made + 1
                            END IF
                        END IF
                    END IF
                    IF opt_boardgame AND steps_left <= 0 THEN EndPlayerTurn
                ELSEIF TryMove(k) THEN
                    IF opt_boardgame THEN steps_left = steps_left - 1
                    moves_made = moves_made + 1
                    loiter = 0                     ' moving on resets the lingering danger meter
                    TickStatus                     ' poison/fire bite, siren winds down as a turn passes
                    IF siren_turns > 0 THEN         ' a wailing siren drags monsters to you as you move
                        IF RollDie(100) <= SIREN_MOVE_PCT THEN WanderEncounter
                    END IF
                    curlvl = SECTOR.get_by_xy(c.x, c.y)   ' chronicle the levels you tread
                    IF curlvl >= 1 AND curlvl <= 9 THEN lvl_reached(curlvl) = TRUE
                    PlayLevelMusic curlvl                 ' switch to this level's track (no-op if unchanged)
                    ' step THROUGH a door, don't stop on it: auto-advance one more cell
                    ' the same direction (a free hop -- costs no movement point)
                    IF OnDoorNow THEN
                        DOOROPEN(c.x \ CW, c.y \ CH) = TRUE   ' opening the door lets you see through it (FOV)
                        IF TryMove(k) THEN moves_made = moves_made + 1
                    END IF
                    ' returning to the entrance patches you up (D&D mode)
                    IF ABS((c.x \ CW) - START_CX) <= 1 AND ABS((c.y \ CH) - START_CY) <= 1 THEN player_hp = player_maxhp
                    IF InRoomNow THEN
                        sec = ROOMAT(c.x \ CW, c.y \ CH)   ' which room block are we standing in?
                        IF sec >= 1 THEN
                            IF NOT ROOMS(sec).seen THEN
                                ROOMS(sec).seen = TRUE     ' entering reveals this room's monster on the board
                                RoomFlavor sec             ' first-entry atmosphere (special or level one-liner)
                            END IF
                            ' a monster guards this room's treasure?
                            IF ROOMS(sec).malive AND LEN(_TRIM$(ROOMS(sec).monster)) > 0 THEN
                                ' ESP Medallion (ONLY if held): foresee the monster; [N] backs off.
                                ' NOTE: BASIC's AND does not short-circuit, so EspEnter must be called
                                ' inside its own IF item_esp -- not as "item_esp AND EspEnter(...)",
                                ' which would pop the prompt (and ignore [N]) even without the medallion.
                                IF item_esp THEN
                                    IF EspEnter(sec) THEN
                                        res = DoCombat(sec)
                                        IF opt_boardgame THEN steps_left = 0   ' combat ends your turn
                                    ELSE
                                        c.x = c.prev_x: c.y = c.prev_y         ' heed the warning, step back out
                                        cursor_erase: cursor_draw
                                    END IF
                                ELSE
                                    res = DoCombat(sec)
                                    IF opt_boardgame THEN steps_left = 0       ' no ESP -- straight into the fight
                                END IF
                            END IF
                            ' reclaim dropped loot once the room is clear (your own, solo; a rival's, MP)
                            IF NOT ROOMS(sec).malive AND HasDrop(sec) THEN CollectDrop sec
                        END IF
                    END IF
                    ' victory: enough gold, hold the Level Key, and back at the entrance
                    IF gold >= target_gold AND has_key THEN
                        IF ABS((c.x \ CW) - START_CX) <= 1 AND ABS((c.y \ CH) - START_CY) <= 1 THEN
                            DeleteSave                       ' the run is won -- clear any stale save
                            PlayGame = OUT_WIN: EXIT FUNCTION
                        END IF
                    END IF
                    IF opt_boardgame AND steps_left <= 0 THEN EndPlayerTurn
                END IF
            END IF
        END IF

        DrawHUD
        IF dbg_on THEN DrawDebug
        _DISPLAY
    LOOP
END FUNCTION


' A flee attempt fails (the monster grabs you and drags you back) with a chance
' that climbs the deeper you are: FLEE_FAIL_BASE on level 1, +FLEE_FAIL_STEP per
' level below (level 9 = 55%). TRUE = you are caught; combat continues.
FUNCTION FleeFails% (lvl AS INTEGER)
    DIM pct AS INTEGER, dl AS INTEGER
    dl = lvl: IF dl < 1 THEN dl = 1
    pct = FLEE_FAIL_BASE + (dl - 1) * FLEE_FAIL_STEP
    IF pct < 0 THEN pct = 0
    IF pct > 95 THEN pct = 95
    FleeFails = (RollDie(100) <= pct)
END FUNCTION


' The '[H] HEAL (n)' tail for a combat prompt -- shown only when you actually hold
' a healing potion, with the current count (empty string otherwise).
FUNCTION HealSuffix$
    DIM n AS INTEGER
    n = item_potion_small + item_potion_large
    IF n > 0 THEN HealSuffix$ = "   [H] HEAL (" + _TRIM$(STR$(n)) + ")" ELSE HealSuffix$ = ""
END FUNCTION


' Gods' favour: a fallen adventurer on their LAST life, come back to reclaim spoils
' they never recovered, may (50%) be blessed -- tipping every combat die by +1 per
' death they have already suffered, so sheer persistence can finally win through.
FUNCTION GodsFavor% ()
    DIM d AS INTEGER
    GodsFavor = 0
    IF cur_player >= 1 AND cur_player <= 4 THEN d = deaths(cur_player) ELSE d = deaths(1)
    IF d < 1 THEN EXIT FUNCTION                        ' no boost until you have actually died
    IF d < opt_maxdeaths - 1 THEN EXIT FUNCTION        ' only when this is your final life
    IF NOT AnyDropExists THEN EXIT FUNCTION            ' only while spoils still await reclaiming
    IF RollDie(100) <= 50 THEN GodsFavor = d           ' 50%: the gods tip the dice +d
END FUNCTION


' After a death's flavor banner (caller has already WaitKey'd), run the after-death
' transition. If the fallen adventurer has spent their LAST life they FORFEIT -- a
' grey darkness falls to a sad epitaph and player_out is set so PlayGame ends their
' run. Otherwise they revive at START with a rally naming how many chances remain.
SUB ReviveOrForfeit (rm AS INTEGER)
    DIM diedcount AS INTEGER, chances AS INTEGER
    IF cur_player >= 1 AND cur_player <= 4 THEN diedcount = deaths(cur_player) ELSE diedcount = deaths(1)
    chances = opt_maxdeaths - diedcount           ' resurrections still to come after THIS death
    IF chances <= 0 THEN                           ' out of lives -- the run is over
        ForfeitScreen
        player_out = -1
        EXIT SUB
    END IF
    BloodDrip                                      ' the red death wipe -> black
    c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
    player_hp = player_maxhp                        ' revived, made whole again, at the entrance
    cursor_erase: cursor_draw: FadeInCurrent        ' the dungeon fades back in at START
    Sfx "levelup"
    IF chances = 1 THEN
        Banner "You have perished -- but ONE last chance remains.", "Make it count... better luck this time!   [ press any key ]"
    ELSE
        Banner "You have perished -- but you still have " + _TRIM$(STR$(chances)) + " chances left.", "Rise and delve again... better luck this time!   [ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' The end of a run: a grey darkness (not blood) falls down the screen, then a random
' sad epitaph lingers over the black until a key is pressed.
SUB ForfeitScreen
    DIM ep AS STRING, kk AS STRING
    Sfx "lose"
    DarknessFall                                   ' grey/black cousin of the blood drip
    ep = ForfeitEpitaph$
    _DEST CANVAS: _FONT CH
    COLOR GREY, BLACK: PrintCentered 22, ep
    COLOR _RGB32(&H88, &H88, &H88), BLACK: PrintCentered 25, "Your tale ends here, in the dark."
    COLOR _RGB32(&H55, &H55, &H55), BLACK: PrintCentered 28, "[ press any key ]"
    _DISPLAY
    _KEYCLEAR
    DO: _LIMIT 30: kk = INKEY$: _DISPLAY: LOOP UNTIL kk <> ""
END SUB


' React to a set player_out flag. Returns TRUE if the whole game is over (solo, or
' the last player standing forfeited). In multiplayer, marks the fallen player out
' of the game and passes the seat to a survivor.
FUNCTION HandleForfeit% ()
    DIM i AS INTEGER, alive AS INTEGER
    HandleForfeit = 0
    player_out = 0
    IF num_players <= 1 THEN HandleForfeit = -1: EXIT FUNCTION    ' solo: game over
    IF cur_player >= 1 AND cur_player <= 4 THEN PLAYERS(cur_player).active = FALSE
    alive = 0
    FOR i = 1 TO num_players
        IF PLAYERS(i).active THEN alive = alive + 1
    NEXT i
    IF alive <= 0 THEN HandleForfeit = -1: EXIT FUNCTION          ' nobody left -- game over
    Banner "PLAYER " + _TRIM$(STR$(cur_player)) + " is out of lives!", _TRIM$(player_name) + " the " + class_name + " is lost to the dungeon forever.   [ press any key ]"
    WaitKey
    SaveActivePlayer cur_player                    ' park the (now inactive) fallen player
    cur_player = NextActivePlayer(cur_player)
    LoadActivePlayer cur_player
    cursor_erase: cursor_draw
    AnnounceTurn cur_player
    need_roll = TRUE
END FUNCTION


' ESP Medallion: foresee the monster guarding a room and choose whether to enter.
' Returns TRUE to fight, FALSE to heed the warning and back away.
FUNCTION EspEnter% (rm AS INTEGER)
    DIM k AS STRING, lead AS STRING
    IF ROOMS(rm).is_boss THEN lead = "the BOSS " + _TRIM$(ROOMS(rm).monster) ELSE lead = "a " + _TRIM$(ROOMS(rm).monster)
    Sfx "idle"
    Banner "Your ESP MEDALLION tingles -- " + lead + " lurks beyond this door!", "[Y] enter and fight   [N] back away"
    _KEYCLEAR            ' drain buffered movement keys so Y/N register at once
    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        IF k = "Y" OR k = CHR$(13) OR k = " " THEN EspEnter = -1: EXIT FUNCTION
        IF k = "N" OR k = CHR$(27) THEN EspEnter = 0: EXIT FUNCTION
        _DISPLAY
    LOOP
END FUNCTION


FUNCTION DoCombat% (rm AS INTEGER)
    DIM k AS STRING, mon AS STRING
    DIM AS INTEGER sec, sm, need, target, unbeatable, god_favor
    DIM lead AS STRING, p2 AS STRING, whatguards AS STRING
    DoCombat = 0
    sec = ROOMS(rm).sec                            ' the room's dungeon level (label + kill numbers)
    mon = _TRIM$(ROOMS(rm).monster)
    ROOMS(rm).monster_fought = TRUE
    IF NOT opt_oldschool THEN                      ' D&D d20/HP combat instead of 2d6-vs-target
        combat_active = -1                          ' keep the combat panel constant through rolls/banners
        DoCombatDnD rm
        combat_active = 0                           ' (cleared here so ALL of DoCombatDnD's exits are covered)
        cursor_erase: cursor_draw: _DISPLAY
        EXIT FUNCTION
    END IF
    ' the kill number depends on the ACTIVE player's class (matters in hot-seat)
    IF ROOMS(rm).is_boss THEN
        SELECT CASE player_class
            CASE 1, 2: need = 13
            CASE 3: need = 11
            CASE ELSE: need = 12
        END SELECT
    ELSE
        need = MON_N(sec, ROOMS(rm).mslot, player_class)
    END IF
    god_favor = GodsFavor                     ' desperate last-life spoils-rescue may earn a divine boost
    target = need - item_sword - god_favor    ' the raw 2d6 the player must roll (Magic Sword + the gods help)
    unbeatable = (target > 12)                ' "-" on the card: needs a stronger blade
    IF target < 2 THEN target = 2

    IF ROOMS(rm).is_boss THEN lead = "The BOSS " + mon ELSE lead = "A " + mon
    ' the treasure is face-down under the monster -- unless the ESP Medallion peeks it
    whatguards = " guards the " + SECTORS(sec).label + "!"
    IF item_esp THEN whatguards = " guards a " + _TRIM$(ROOMS(rm).treasure_name) + "!"
    IF unbeatable THEN
        p2 = "Only a Magic Sword can harm it -- [ESC] FLEE"
    ELSE
        p2 = "Roll " + _TRIM$(STR$(target)) + "+ on 2d6 to slay it   [SPACE] ATTACK   [ESC] FLEE"
    END IF
    IF god_favor > 0 THEN                          ' the desperate are watched over -- tell them
        Sfx "levelup"
        Banner "THE GODS FAVOUR THE DESPERATE!", "Fortune lowers the roll you need by " + _TRIM$(STR$(god_favor)) + " this fight.   [ press any key ]"
        WaitKey
    END IF
    Banner lead + whatguards, p2 + HealSuffix$

    DO
        _LIMIT 60
        k = INKEY$
        IF k = CHR$(27) THEN
            IF FleeFails(sec) THEN               ' the deeper you are, the likelier it grabs you
                Sfx "bump"
                Banner "The " + mon + " lunges and drags you back!", "You cannot flee!   [ press any key ]"
                CombatPause
                Banner lead + whatguards, p2 + HealSuffix$   ' re-show the fight prompt
            ELSE
                c.x = c.prev_x: c.y = c.prev_y  ' back out the way you came
                StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "fled", 0, 0, 0
                Banner "You slip away from the " + mon + ".", "It still guards the " + _TRIM$(SECTORS(sec).label) + " -- return to finish it.   [ press any key ]"
                CombatPause
                EXIT DO
            END IF
        ELSEIF k = "H" OR k = "h" THEN           ' quaff a potion -- this IS your action; the monster then strikes
            IF item_potion_small + item_potion_large > 0 THEN
                UsePotion FALSE
                MonsterAttack rm                 ' healing spends your turn, so the monster gets its swing
                EXIT DO
            END IF
        ELSEIF k = " " AND NOT unbeatable THEN
            sm = DoRoll(2, item_sword, "attacking the " + mon)
            IF last_raw = 12 THEN
                ' natural 12 -- CRITICAL HIT, always slays
                ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                Sfx "crit"
                IF opt_critfumble THEN
                    DoCrit rm, mon, WeaponName$, 0     ' cinematic + a heroic heal on the killing blow
                ELSE
                    Banner "** CRITICAL HIT! **  (natural 12)", "You cleave the " + mon + " in a single blow!   [ press any key ]"
                    CombatPause
                END IF
                ClaimTreasure rm, sm
                StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "killed", 1, 0, 0
                EXIT DO
            ELSEIF last_raw = 2 THEN
                ' natural 2 -- CRITICAL FUMBLE
                IF opt_critfumble THEN
                    DoFumble rm, mon, WeaponName$
                ELSE
                    Sfx "fumble"
                    Banner "** CRITICAL FUMBLE! **  (snake eyes)", "Your blade slips -- the " + mon + " gets a free strike!   [ press any key ]"
                    CombatPause
                END IF
                MonsterAttack rm
                EXIT DO
            ELSEIF sm >= need THEN
                ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                Sfx "treasure"
                ClaimTreasure rm, sm
                StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "killed", 1, 0, 0
                EXIT DO
            ELSE
                MonsterAttack rm                ' failed -- roll on the Monster Attack Table
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
SUB DoCombatDnD (rm AS INTEGER)
    DIM k AS STRING, mon AS STRING, lead AS STRING, mhs AS STRING, cdf AS STRING
    DIM AS INTEGER sec, lvl, mtohit, atk, dmg, rounds, matk, mdmg, thb, isboss
    DIM AS INTEGER tot_dealt, tot_taken, wander, vanished, god_favor, acted, did_attack
    DIM lost AS LONG
    wander = (rm > ROOM_N)                       ' TRUE for a wandering-monster scratch slot
    sec = ROOMS(rm).sec
    mon = _TRIM$(ROOMS(rm).monster)
    isboss = ROOMS(rm).is_boss
    lvl = sec                                   ' sector index doubles as dungeon level 1..9
    mtohit = lvl: IF isboss THEN mtohit = mtohit + 2
    thb = player_tohit                          ' final to-hit incl. ability modifier
    IF item_bow THEN thb = thb + 2              ' Magic Bow: strike harder from range
    god_favor = GodsFavor                       ' desperate last-life spoils-rescue may earn a divine dice boost
    IF god_favor > 0 THEN thb = thb + god_favor
    IF ROOMS(rm).mhp_now <= 0 THEN ROOMS(rm).mhp_now = ROOMS(rm).mhp   ' fresh fight
    rounds = 0: combat_round = 1
    IF isboss THEN lead = "The BOSS " + mon ELSE lead = "The " + mon
    FX_MON = mon: FX_LEVEL = sec: FX_ROOM = _TRIM$(SECTORS(sec).label)   ' flavor context for {tokens}
    combat_rm = rm: combat_mon = mon: combat_lead = lead                  ' so DrawHUD can keep the panel painted

    DIM dirty AS INTEGER
    dirty = -1                                   ' clear any lingering pre-combat banner on entry
    IF god_favor > 0 THEN                         ' the desperate are watched over -- tell them
        Sfx "levelup"
        Banner "THE GODS FAVOUR THE DESPERATE!", "Fortune guides your hand: +" + _TRIM$(STR$(god_favor)) + " to every strike this fight.   [ press any key ]"
        WaitKey
    END IF
    DO
        _LIMIT 60
        ' Once an action's banners are done, wipe the message/dice area and redraw
        ' the board so ONLY the combat panel shows -- makes it obvious it's your turn.
        IF dirty THEN cursor_erase: cursor_draw: dirty = 0
        DrawCombatPanel rm, mon, lead
        k = INKEY$
        acted = 0: did_attack = 0
        IF k = CHR$(27) THEN                     ' attempt to flee
            IF FleeFails(lvl) THEN               ' the deeper you are, the likelier it grabs you
                Sfx "bump"
                Banner "The " + mon + " lunges and drags you back!", "You cannot flee!   [ press any key ]"
                CombatPause
                dirty = -1                       ' clear the banner, redraw the panel next loop
            ELSE
                c.x = c.prev_x: c.y = c.prev_y   ' back out the way you came
                StatLog sec, rm, mon, isboss, wander, "fled", rounds, tot_dealt, tot_taken
                Banner "You slip away from the " + mon + ".", "It still guards the " + _TRIM$(SECTORS(sec).label) + " -- return to finish it.   [ press any key ]"
                CombatPause
                EXIT SUB
            END IF
        ELSEIF k = "H" OR k = "h" THEN           ' quaff a potion -- this IS your action; the monster still swings
            IF item_potion_small + item_potion_large > 0 THEN
                UsePotion FALSE
                acted = -1
            END IF
            dirty = -1
        ELSEIF k = " " THEN
            acted = -1: did_attack = -1
            rounds = rounds + 1: combat_round = rounds
            dirty = -1                           ' this round's banners will need clearing next loop
            ' ---------- player attacks ----------
            atk = GameRoll(1, 20, thb, "to hit the " + mon)
            IF last_raw = 20 THEN                 ' natural 20: crit, auto-hit, double dice
                dmg = GameRoll(2, player_dmgdie, player_dmgbonus + item_sword, "CRITICAL damage on the " + mon)
                IF dmg < 1 THEN dmg = 1
                ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - dmg
                IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
                tot_dealt = tot_dealt + dmg
                Sfx "crit"
                DrawCombatPanel rm, mon, lead     ' drain the monster's HP bar before the banner
                IF opt_critfumble THEN
                    DoCrit rm, mon, WeaponName$, dmg    ' cinematic: smash-saying -> pause -> bonus event
                    DrawCombatPanel rm, mon, lead
                ELSE
                    FX_DMG = dmg
                    EventBanner "** CRITICAL HIT! **  (natural 20)", 2, class_name, 3, "You savage the " + mon + " for " + _TRIM$(STR$(dmg)) + " damage!"
                    CombatPause
                END IF
            ELSEIF last_raw = 1 THEN              ' natural 1: auto-miss (and maybe a mishap)
                IF opt_critfumble THEN
                    DoFumble rm, mon, WeaponName$
                    DrawCombatPanel rm, mon, lead
                ELSE
                    Sfx "fumble"
                    FX_DMG = 0
                    EventBanner "** FUMBLE! **  (natural 1)", 2, class_name, 4, "Your attack goes wide of the " + mon + "."
                    CombatPause
                END IF
            ELSEIF atk >= ROOMS(rm).mac THEN      ' hit
                dmg = GameRoll(1, player_dmgdie, player_dmgbonus + item_sword, "your DAMAGE on the " + mon)
                IF dmg < 1 THEN dmg = 1
                ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - dmg
                IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
                tot_dealt = tot_dealt + dmg
                Sfx "hit"
                DrawCombatPanel rm, mon, lead     ' drain the monster's HP bar before the banner
                FX_DMG = dmg
                EventBanner "You HIT!  (d20+" + _TRIM$(STR$(thb)) + " = " + _TRIM$(STR$(atk)) + " vs AC " + _TRIM$(STR$(ROOMS(rm).mac)) + ")", 2, class_name, 1, "You deal " + _TRIM$(STR$(dmg)) + " damage."
                CombatPause
                IF last_raw = player_dmgdie THEN            ' MAX on the damage die -- brutal flavor (even without a crit)
                    mhs = MaxHitSaying$(mon, WeaponName$)
                    IF LEN(mhs) > 0 THEN
                        Sfx "crit"
                        Banner "** A CRUSHING BLOW! **  (max damage)", mhs + "   [ press any key ]"
                        CombatPause
                    END IF
                END IF
            ELSE                                  ' miss
                Sfx "miss"
                FX_DMG = 0
                EventBanner "You MISS.  (d20+" + _TRIM$(STR$(thb)) + " = " + _TRIM$(STR$(atk)) + " vs AC " + _TRIM$(STR$(ROOMS(rm).mac)) + ")", 2, class_name, 2, "The " + mon + " dodges your blow."
                CombatPause
            END IF

            IF ROOMS(rm).mhp_now <= 0 THEN        ' monster slain
                ROOMS(rm).mhp_now = 0
                ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                Sfx "treasure"
                ClaimTreasure rm, rounds
                StatLog sec, rm, mon, isboss, wander, "killed", rounds, tot_dealt, tot_taken
                EXIT SUB
            END IF
        END IF

        IF acted THEN                             ' attacked OR healed -> the monster takes its turn
            IF NOT did_attack THEN rounds = rounds + 1: combat_round = rounds   ' a heal spends a round too

            ' ---------- monster strikes back (you roll its dice in Real-Dice mode, else shown) ----------
            PushMonsterDice: matk = GameRoll(1, 20, mtohit, "the " + mon + "'s ATTACK -- roll ITS d20"): PopMonsterDice
            IF opt_critfumble AND last_raw = 1 THEN     ' the monster fumbles: hurts itself or reels
                DoMonsterFumble rm, mon
                IF ROOMS(rm).mhp_now <= 0 THEN          ' it may have slain itself
                    ROOMS(rm).mhp_now = 0
                    ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                    Sfx "treasure"
                    ClaimTreasure rm, rounds
                    EXIT SUB
                END IF
            ELSEIF last_raw = 20 THEN             ' monster natural 20: crit, auto-hit, DOUBLE damage dice
                PushMonsterDice: mdmg = GameRoll(2, 6, lvl \ 3, "the " + mon + "'s CRITICAL damage -- roll ITS 2d6"): PopMonsterDice
                IF isboss THEN mdmg = mdmg + 3
                IF mdmg < 1 THEN mdmg = 1
                player_hp = player_hp - mdmg
                IF player_hp < 0 THEN player_hp = 0
                tot_taken = tot_taken + mdmg
                Sfx "crit"
                DrawCombatPanel rm, mon, lead     ' drain YOUR HP bar before the banner
                FX_DMG = mdmg
                EventBanner "** the " + mon + " CRITS you! **  (natural 20)", 1, mon, 3, "A savage blow lands for " + _TRIM$(STR$(mdmg)) + " damage!"
                CombatPause
            ELSEIF matk >= player_ac + item_armor THEN
                PushMonsterDice: mdmg = GameRoll(1, 6, lvl \ 3, "the " + mon + "'s DAMAGE -- roll ITS d6"): PopMonsterDice
                IF isboss THEN mdmg = mdmg + 3
                player_hp = player_hp - mdmg
                IF player_hp < 0 THEN player_hp = 0
                tot_taken = tot_taken + mdmg
                Sfx "bump"
                DrawCombatPanel rm, mon, lead     ' drain YOUR HP bar before the banner
                FX_DMG = mdmg
                EventBanner "The " + mon + " HITS you!  (d20+" + _TRIM$(STR$(mtohit)) + " = " + _TRIM$(STR$(matk)) + " vs AC " + _TRIM$(STR$(player_ac + item_armor)) + ")", 1, mon, 1, "You take " + _TRIM$(STR$(mdmg)) + " damage."
                CombatPause
            ELSE
                FX_DMG = 0
                EventBanner "The " + mon + " misses you.  (d20+" + _TRIM$(STR$(mtohit)) + " = " + _TRIM$(STR$(matk)) + ")", 1, mon, 2, "You weather the assault."
                CombatPause
            END IF

            IF player_hp <= 0 THEN                ' downed
                player_hp = 0
                ROOMS(rm).player_died = TRUE
                IF cur_player >= 1 AND cur_player <= 4 THEN deaths(cur_player) = deaths(cur_player) + 1
                DrawCombatPanel rm, mon, lead
                FX_MON = mon: FX_DMG = mdmg        ' your class's own death cry, if it has one
                cdf = EventLine$(2, class_name, 5)
                IF LEN(cdf) > 0 THEN Banner "YOU ARE SLAIN!", cdf + "   [ press any key ]": WaitKey
                lost = gold
                vanished = FALSE                  ' SOULS-LIKE: dying again forfeits a hoard you never reclaimed
                IF opt_lootrecovery = 2 THEN vanished = AnyDropExists
                StatLog sec, rm, mon, isboss, wander, "died", rounds, tot_dealt, tot_taken
                DropEverything rm                 ' drop gold AND the special cards (in the room, MP)
                Sfx "lose"
                IF vanished THEN
                    Banner "You clutch your bloody fist to your chest and reach for the loot you had hoped to reclaim,", "as it vanishes before your very eyes -- and the world fades to black.   [ press any key ]"
                ELSEIF opt_lootrecovery >= 1 AND NOT wander THEN
                    Banner "YOU ARE DOWNED by the " + mon + "!", "Your spoils (" + _TRIM$(STR$(lost)) + " gold + magic) lie in the " + _TRIM$(SECTORS(sec).label) + " -- return for revenge!   [ press any key ]"
                ELSE
                    Banner "YOU ARE DOWNED by the " + mon + "!", "You lose your treasure (" + _TRIM$(STR$(lost)) + " gold) and all magic, dragged back to START.   [ press any key ]"
                END IF
                WaitKey                           ' let the death sink in before the transition
                ReviveOrForfeit rm                ' blood (or grey forfeit) -> revive with a rally, or end the run
                EXIT SUB
            END IF
        END IF
        _DISPLAY
    LOOP
END SUB


' Draw the D&D combat panel: monster + player HP bars and the action prompt.
SUB DrawCombatPanel (rm AS INTEGER, mon AS STRING, lead AS STRING)
    DIM AS INTEGER bx, by, bw, bh
    bx = 16: by = 39: bw = 100: bh = 10
    _DEST CANVAS
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), REDU, B
    COLOR YELLOWU, BOXBG
    IF combat_round > 1 THEN                      ' between rounds -- the fight is on-going; prompt to act again
        PrintCentered by + 1, "You still face " + LCASE$(LEFT$(_TRIM$(lead), 1)) + MID$(_TRIM$(lead), 2) + " -- choose your action!"
    ELSE                                          ' first look -- the encounter opens
        PrintCentered by + 1, _TRIM$(lead) + " blocks your path!"
    END IF
    COLOR CYANU, BOXBG: _PRINTSTRING ((bx + 2) * CW, (by + 1) * CH), "LEVEL" + STR$(ROOMS(rm).sec)
    COLOR REDU, BOXBG: _PRINTSTRING ((bx + bw - 12) * CW, (by + 1) * CH), "ROUND:" + STR$(combat_round)
    COLOR REDU, BOXBG
    PrintCentered by + 3, mon + "   " + HpBar$(ROOMS(rm).mhp_now, ROOMS(rm).mhp, 22) + "  " + _TRIM$(STR$(ROOMS(rm).mhp_now)) + "/" + _TRIM$(STR$(ROOMS(rm).mhp)) + " HP   AC " + _TRIM$(STR$(ROOMS(rm).mac))
    COLOR GREENU, BOXBG
    PrintCentered by + 5, class_name + " (you)   " + HpBar$(player_hp, player_maxhp, 22) + "  " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + " HP   AC " + _TRIM$(STR$(player_ac + item_armor))
    COLOR CYANU, BOXBG
    IF item_potion_small > 0 OR item_potion_large > 0 THEN
        PrintCentered by + 8, "[SPACE] attack    [H] potion (" + _TRIM$(STR$(item_potion_small + item_potion_large)) + ")    [ESC] flee"
    ELSE
        PrintCentered by + 8, "[SPACE] attack       [ESC] flee"
    END IF
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
SUB MonsterAttack (rm AS INTEGER)
    DIM r AS INTEGER, mon AS STRING, lost AS LONG, vanished AS INTEGER
    mon = _TRIM$(ROOMS(rm).monster)
    PushMonsterDice: r = DoRoll(2, 0, "the " + mon + "'s ATTACK -- roll ITS 2d6"): PopMonsterDice   ' Real Dice: you roll for the monster
    SELECT CASE r
        CASE 2                                  ' ADVENTURER KILLED!
            lost = gold
            ROOMS(rm).player_died = TRUE
            IF cur_player >= 1 AND cur_player <= 4 THEN deaths(cur_player) = deaths(cur_player) + 1
            vanished = FALSE                    ' SOULS-LIKE: a second fall forfeits an unreclaimed hoard
            IF opt_lootrecovery = 2 THEN vanished = AnyDropExists
            DropEverything rm                   ' killed = drop gold AND all special cards (in the room, MP)
            Sfx "lose"
            IF vanished THEN
                Banner "You clutch your bloody fist to your chest and reach for the loot you had hoped to reclaim,", "as it vanishes before your very eyes -- and the world fades to black.   [ press any key ]"
            ELSEIF opt_lootrecovery >= 1 AND rm <= ROOM_N THEN
                Banner mon + " ATTACK (2): ADVENTURER KILLED!", "Your spoils (" + _TRIM$(STR$(lost)) + " gold + magic) lie in the " + _TRIM$(SECTORS(ROOMS(rm).sec).label) + " -- return for revenge!   [ press any key ]"
            ELSE
                Banner mon + " ATTACK (2): ADVENTURER KILLED!", "You lose your treasure (" + _TRIM$(STR$(lost)) + " gold) and all magic, then crawl back to START.   [ press any key ]"
            END IF
            WaitKey                             ' let the death sink in before the transition
            ReviveOrForfeit rm                  ' blood (or grey forfeit) -> revive with a rally, or end the run
        CASE 3                                   ' SERIOUS WOUND
            lost = gold \ 2: gold = gold - lost
            Sfx "trap"
            Banner mon + " ATTACK (3): SERIOUS WOUND!", "You drop half your treasure (" + _TRIM$(STR$(lost)) + ") and retreat to START.   [ press any key ]"
            CombatPause
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
        CASE 4, 5, 6                             ' LIGHT WOUND
            lost = 1000: IF lost > gold THEN lost = gold
            gold = gold - lost
            Sfx "miss"
            Banner mon + " ATTACK (" + _TRIM$(STR$(r)) + "): LIGHT WOUND!", "You drop " + _TRIM$(STR$(lost)) + " gold, retreat, and lose the turn.   [ press any key ]"
            CombatPause
            c.x = c.prev_x: c.y = c.prev_y
            steps_left = 0: need_roll = TRUE
        CASE 7, 8                                ' STUNNED
            lost = 500: IF lost > gold THEN lost = gold
            gold = gold - lost
            Sfx "miss"
            Banner mon + " ATTACK (" + _TRIM$(STR$(r)) + "): STUNNED!", "You drop " + _TRIM$(STR$(lost)) + " gold.   [ press any key ]"
            CombatPause
            c.x = c.prev_x: c.y = c.prev_y
        CASE ELSE                                ' 9+ MISSED
            Sfx "bump"
            Banner "The " + mon + " MISSES!  (" + _TRIM$(STR$(r)) + ")", "No harm done -- stand and fight again, or flee.   [ press any key ]"
            CombatPause
            c.x = c.prev_x: c.y = c.prev_y
    END SELECT
END SUB


' Award a slain room's treasure -- gold, or a special item card.
SUB ClaimTreasure (rm AS INTEGER, sm AS INTEGER)
    DIM slay AS STRING, line2 AS STRING, itm AS INTEGER, mon AS STRING, tname AS STRING, acb AS INTEGER
    DIM lvl AS INTEGER, goldbefore AS LONG, dfl AS STRING
    mon = _TRIM$(ROOMS(rm).monster): tname = _TRIM$(ROOMS(rm).treasure_name)
    lvl = ROOMS(rm).sec: goldbefore = gold                 ' chronicle this kill + its haul
    FX_MON = mon: FX_LEVEL = lvl: FX_TREASURE = tname      ' flavor context for the death line
    dfl = EventLine$(1, mon, 5)                            ' the monster's own death throes, if any
    IF LEN(dfl) > 0 THEN
        Sfx "treasure"
        Banner "The " + mon + " is slain!", dfl + "   [ press any key ]"
        CombatPause
    END IF
    IF lvl >= 1 AND lvl <= 9 THEN lvl_kills(lvl) = lvl_kills(lvl) + 1: lvl_reached(lvl) = TRUE
    char_xp = char_xp + XP_PER_KILL_LVL * lvl              ' XP scales with the monster's depth
    IF ROOMS(rm).is_boss THEN char_xp = char_xp + XP_PER_KILL_LVL * lvl   ' a boss is worth double
    IF opt_oldschool THEN
        slay = "You slay the " + mon + "!  (2d6 = " + _TRIM$(STR$(sm)) + ")"
    ELSE
        slay = "You slay the " + mon + "!  (felled in " + _TRIM$(STR$(sm)) + " rounds)"
    END IF
    itm = ROOMS(rm).treasure_item
    DIM newp AS INTEGER
    SELECT CASE itm
        CASE 1, 2                                ' Magic Sword -- every blade found is keener than the last
            IF player_class = 4 THEN             ' a Wizard cannot use a Magic Sword
                gold = gold + 500
                LogTreasure "Magic Sword (sold)", 500
                line2 = "A " + tname + " -- a Wizard can't wield it; you sell it for 500 gold."
            ELSE
                newp = itm                       ' a duplicate/weaker blade is reforged one step stronger
                IF newp <= item_sword THEN newp = item_sword + 1
                IF newp > 5 THEN newp = 5        ' +5 is the legendary cap
                IF newp > item_sword THEN
                    item_sword = newp
                    LogTreasure "Magic Sword +" + _TRIM$(STR$(item_sword)), 500 * item_sword
                    line2 = "You take up a finer blade -- your sword is now +" + _TRIM$(STR$(item_sword)) + " to attacks!"
                ELSE
                    gold = gold + 1000
                    LogTreasure "Magic Sword (sold)", 1000
                    line2 = "Your blade is already legendary (+5) -- you sell this one for 1000 gold."
                END IF
            END IF
        CASE 3                                    ' Secret Door Card
            item_secret_card = TRUE
            LogTreasure "Secret Door Card", 0
            line2 = "You find the SECRET DOOR CARD -- you now sense secret doors automatically!"
        CASE 4                                    ' ESP Medallion
            item_esp = TRUE
            LogTreasure "ESP Medallion", 0
            line2 = "You don the ESP MEDALLION -- you now foresee the monster beyond a door!"
        CASE 5                                    ' Crystal Ball
            item_crystal = TRUE
            LogTreasure "Crystal Ball", 0
            line2 = "You grasp the CRYSTAL BALL -- press [V] to scry the whole dungeon!"
        CASE 6                                    ' the LEVEL KEY (this game's key room)
            has_key = TRUE
            Sfx "key"
            gold = gold + ROOMS(rm).treasure
            IF ROOMS(rm).treasure > 0 THEN LogTreasure "Key Vault hoard", ROOMS(rm).treasure
            line2 = "You seize the LEVEL KEY! Now escape to the entrance with your gold to WIN."
        CASE 7, 8                                 ' Shield / Magic Armor -- each set finer than the last
            IF itm = 7 THEN acb = 2 ELSE acb = 3
            newp = acb                            ' a duplicate/weaker set is reforged one step stronger
            IF newp <= item_armor THEN newp = item_armor + 1
            IF newp > 6 THEN newp = 6             ' +6 AC is the cap
            IF newp > item_armor THEN
                item_armor = newp
                LogTreasure _TRIM$(tname) + " (+" + _TRIM$(STR$(item_armor)) + " AC)", 500 * item_armor
                line2 = "You don the " + tname + " -- your Armor Class rises to " + _TRIM$(STR$(player_ac + item_armor)) + "!"
            ELSE
                gold = gold + 1000
                LogTreasure "Armor (sold)", 1000
                line2 = "Your armor is already peerless (+6 AC) -- you sell this for 1000 gold."
            END IF
        CASE 9                                     ' Magic Bow (+2 to-hit, strikes from range)
            IF NOT item_bow THEN
                item_bow = TRUE
                LogTreasure "Magic Bow", 0
                line2 = "You take up the " + tname + " -- +2 to hit, striking before they close!"
            ELSE
                gold = gold + 500
                LogTreasure "Magic Bow (sold)", 500
                line2 = "Another " + tname + " -- you already carry one; +500 gold."
            END IF
        CASE 10                                    ' Elf Boots (+2 to the movement roll)
            IF NOT item_boots THEN
                item_boots = TRUE
                LogTreasure "Elf Boots", 0
                line2 = "You lace on the " + tname + " -- +2 to every movement roll!"
            ELSE
                gold = gold + 500
                LogTreasure "Elf Boots (sold)", 500
                line2 = "Another pair of " + tname + " -- you already run swift; +500 gold."
            END IF
        CASE 11                                    ' Teleport Scroll (consumable, [T])
            item_teleport = item_teleport + 1
            LogTreasure "Teleport Scroll", 0
            line2 = "You pocket a TELEPORT SCROLL (" + _TRIM$(STR$(item_teleport)) + " held) -- press [T] to whisk to START."
        CASE ELSE                                 ' plain gold treasure
            gold = gold + ROOMS(rm).treasure
            LogTreasure tname, ROOMS(rm).treasure
            line2 = "You claim the " + tname + " -- " + _TRIM$(STR$(ROOMS(rm).treasure)) + " GOLD!"
    END SELECT
    IF lvl >= 1 AND lvl <= 9 THEN lvl_gold(lvl) = lvl_gold(lvl) + (gold - goldbefore)
    Banner slay, line2 + "   [ press any key ]"
    CombatPause
    ' a real room's hoard may also hide a healing potion (1d8). Wanderers (scratch
    ' slot rm > ROOM_N) never drop one -- that would make them farmable.
    IF rm <= ROOM_N THEN
        IF RollDie(100) <= TREASURE_POTION_PCT THEN     ' occasional small potion in the hoard
            item_potion_small = item_potion_small + 1
            Sfx "treasure"
            Banner "Among the spoils glints a SMALL HEALING POTION!", "Press [H] in a fight to quaff it (heals 1d4).   [ press any key ]"
            CombatPause
        END IF
        ' clearing every room of a level: a healing cache + (D&D) a level-up
        IF lvl >= 1 AND lvl <= 9 THEN
            IF NOT lvl_cleared(lvl) THEN
                IF LevelFullyCleared(lvl) THEN GrantLevelClear lvl
            END IF
        END IF
        CurioChest rm                       ' a curio chest may reveal itself after the fight
    END IF
END SUB


' TRUE once every monster-bearing room of a dungeon level has been slain.
FUNCTION LevelFullyCleared% (lvl AS INTEGER)
    DIM r AS INTEGER
    LevelFullyCleared = FALSE
    FOR r = 1 TO ROOM_N
        IF ROOMS(r).sec = lvl AND LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN
            IF ROOMS(r).malive THEN EXIT FUNCTION      ' a lair still holds a live monster
        END IF
    NEXT r
    LevelFullyCleared = TRUE
END FUNCTION


' Reward for sweeping a whole floor: mark it cleared (now a safe zone), grant a
' healing cache (small potion always; a large one LEVELCLEAR_LARGE_PCT of the time),
' and in D&D mode advance the character a level -- rolling the class hit die for +HP.
SUB GrantLevelClear (lvl AS INTEGER)
    DIM hpgain AS INTEGER, got AS STRING
    lvl_cleared(lvl) = TRUE
    Sfx "win"
    Banner "The " + Ordinal$(lvl) + " level is CLEARED!", "Every lair on this floor lies empty -- it is a safe haven now.   [ press any key ]"
    CombatPause
    IF NOT opt_oldschool THEN                       ' D&D level-up: +1 level, roll the hit die for HP
        char_level = char_level + 1
        hpgain = GameRoll(1, CLASSES(player_class).hitdie, AbilMod(player_con), "LEVEL UP! roll your hit die")
        IF hpgain < 1 THEN hpgain = 1
        player_maxhp = player_maxhp + hpgain
        player_hp = player_maxhp                    ' fully restored on level-up
        Sfx "key"
        Banner "** LEVEL UP! **  You are now character level " + _TRIM$(STR$(char_level)) + ".", "+" + _TRIM$(STR$(hpgain)) + " max HP (now " + _TRIM$(STR$(player_maxhp)) + ") and fully rested.   [ press any key ]"
        CombatPause
    END IF
    item_potion_small = item_potion_small + 1
    got = "a SMALL HEALING POTION (1d4)"
    IF RollDie(100) <= LEVELCLEAR_LARGE_PCT THEN
        item_potion_large = item_potion_large + 1
        got = got + " and a LARGE one (1d8)"
    END IF
    Sfx "treasure"
    Banner "The cleared floor yields " + got + ".", "Press [H] in a fight to quaff a potion.   [ press any key ]"
    CombatPause
END SUB


' Quaff a healing potion. If the player holds both sizes, ask which; otherwise
' drink whatever is held. Heals the rolled amount (small 1d4 / large 1d8), capped
' at max HP. A free action in combat (no monster riposte). silentIfNone TRUE
' suppresses the "no potions" nag (used when [H] is pressed on the board).
SUB UsePotion (silentIfNone AS INTEGER)
    DIM which AS INTEGER, heal AS INTEGER
    IF item_potion_small <= 0 AND item_potion_large <= 0 THEN
        IF NOT silentIfNone THEN
            Banner "You have no healing potions.", "Slay monsters and clear floors to find them.   [ press any key ]"
            WaitKey
        END IF
        EXIT SUB
    END IF
    which = 0
    IF item_potion_small > 0 AND item_potion_large > 0 THEN
        which = AskPotionChoice
        IF which = 0 THEN EXIT SUB                  ' cancelled
    ELSEIF item_potion_large > 0 THEN
        which = 2
    ELSE
        which = 1
    END IF
    IF which = 1 THEN
        item_potion_small = item_potion_small - 1
        heal = GameRoll(1, POTION_SMALL_DIE, 0, "SMALL HEALING POTION")
    ELSE
        item_potion_large = item_potion_large - 1
        heal = GameRoll(1, POTION_LARGE_DIE, 0, "LARGE HEALING POTION")
    END IF
    IF heal < 1 THEN heal = 1
    player_hp = player_hp + heal
    IF player_hp > player_maxhp THEN player_hp = player_maxhp
    Sfx "treasure"
    Banner "You quaff the potion and recover " + _TRIM$(STR$(heal)) + " HP.", "Now at " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + " HP.   [ press any key ]"
    CombatPause
END SUB


' Prompt which potion to drink when the player holds both. Returns 1 small, 2 large, 0 cancel.
FUNCTION AskPotionChoice%
    DIM k AS STRING
    Banner "Which potion? [S] small (1d4, " + _TRIM$(STR$(item_potion_small)) + " held)   [L] large (1d8, " + _TRIM$(STR$(item_potion_large)) + " held)", "[ESC] cancel"
    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        IF k = "S" THEN AskPotionChoice = 1: EXIT FUNCTION
        IF k = "L" THEN AskPotionChoice = 2: EXIT FUNCTION
        IF k = CHR$(27) THEN AskPotionChoice = 0: EXIT FUNCTION
        _DISPLAY
    LOOP
END FUNCTION


' Record a named treasure in the active player's log (shown on the character sheet).
SUB LogTreasure (nm AS STRING, g AS LONG)
    IF cur_player < 1 OR cur_player > 4 THEN EXIT SUB
    IF LOOT_N(cur_player) >= UBOUND(LOOT_NAME, 2) THEN EXIT SUB
    LOOT_N(cur_player) = LOOT_N(cur_player) + 1
    LOOT_NAME(cur_player, LOOT_N(cur_player)) = nm
    LOOT_GOLD(cur_player, LOOT_N(cur_player)) = g
END SUB


' On death a champion drops EVERYTHING carried -- gold and all special cards. In
' multiplayer the loot is left IN the room (rm) for any player to recover; solo it
' is simply lost (recovering your own would void the death penalty).
SUB DropEverything (rm AS INTEGER)
    ' With Loot Recovery on, the spoils are LEFT in the room to reclaim (solo:
    ' trek back and re-clear it for revenge; multiplayer: any rival can grab it).
    ' Wanderer deaths (scratch slot rm > ROOM_N) have no room to mark -- lost.
    IF opt_lootrecovery >= 1 AND rm >= 1 AND rm <= ROOM_N THEN
        IF opt_lootrecovery = 2 THEN ClearAllDrops   ' SOULS-LIKE: only your most recent death's spoils survive
        ROOMS(rm).drop_gold = ROOMS(rm).drop_gold + gold
        IF item_sword > ROOMS(rm).drop_sword THEN ROOMS(rm).drop_sword = item_sword
        IF item_secret_card THEN ROOMS(rm).drop_secret = TRUE
        IF item_esp THEN ROOMS(rm).drop_esp = TRUE
        IF item_crystal THEN ROOMS(rm).drop_crystal = TRUE
    END IF
    gold = 0
    item_sword = 0
    item_secret_card = FALSE: item_esp = FALSE: item_crystal = FALSE
    item_armor = 0: item_bow = FALSE: item_boots = FALSE: item_teleport = 0
    item_potion_small = 0: item_potion_large = 0
    IF cur_player >= 1 AND cur_player <= 4 THEN LOOT_N(cur_player) = 0   ' the treasure log goes too
END SUB


' Wipe every room's recoverable drop -- SOULS-LIKE mode calls this on each death,
' so dying again before you reclaim your last hoard loses it forever.
SUB ClearAllDrops
    DIM r AS INTEGER
    FOR r = 1 TO ROOM_N
        ROOMS(r).drop_gold = 0: ROOMS(r).drop_sword = 0
        ROOMS(r).drop_secret = FALSE: ROOMS(r).drop_esp = FALSE: ROOMS(r).drop_crystal = FALSE
    NEXT r
END SUB


' TRUE if any room still holds a recoverable drop. Used at a SOULS-LIKE death to
' tell "first fall (a hoard to return for)" from "fell again -- it's lost forever".
FUNCTION AnyDropExists% ()
    DIM r AS INTEGER
    AnyDropExists = 0
    FOR r = 1 TO ROOM_N
        IF HasDrop(r) THEN AnyDropExists = -1: EXIT FUNCTION
    NEXT r
END FUNCTION


' Freeze the game so the player can step away (bio break). Halts the idle/real-time
' clock -- the caller resets idle_ticks on return. Any key resumes.
SUB PauseGame
    DIM k AS STRING
    Sfx "idle"
    Banner "-- PAUSED --", "Take your time.   [ press any key to resume ]"
    DO
        _LIMIT 30
        k = INKEY$
        _DISPLAY
    LOOP UNTIL k <> ""
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' TRUE if a room holds recoverable dropped loot.
FUNCTION HasDrop% (rm AS INTEGER)
    HasDrop = (ROOMS(rm).drop_gold > 0) OR (ROOMS(rm).drop_sword > 0) OR ROOMS(rm).drop_secret OR ROOMS(rm).drop_esp OR ROOMS(rm).drop_crystal
END FUNCTION


' Pick up whatever a fallen rival left in this room.
SUB CollectDrop (rm AS INTEGER)
    DIM got AS STRING
    IF NOT HasDrop(rm) THEN EXIT SUB
    got = ""
    IF ROOMS(rm).drop_gold > 0 THEN gold = gold + ROOMS(rm).drop_gold: got = _TRIM$(STR$(ROOMS(rm).drop_gold)) + " gold"
    IF ROOMS(rm).drop_sword > item_sword AND player_class <> 4 THEN item_sword = ROOMS(rm).drop_sword: got = got + "   a Magic Sword"
    IF ROOMS(rm).drop_secret THEN item_secret_card = TRUE: got = got + "   a Secret Door Card"
    IF ROOMS(rm).drop_esp THEN item_esp = TRUE: got = got + "   an ESP Medallion"
    IF ROOMS(rm).drop_crystal THEN item_crystal = TRUE: got = got + "   a Crystal Ball"
    ROOMS(rm).drop_gold = 0: ROOMS(rm).drop_sword = 0
    ROOMS(rm).drop_secret = FALSE: ROOMS(rm).drop_esp = FALSE: ROOMS(rm).drop_crystal = FALSE
    Sfx "treasure"
    IF NOT ROOMS(rm).player_died THEN
        Banner "You claim the treasure left waiting here.", _TRIM$(got) + "   [ press any key ]"   ' a curio left unopened, etc.
    ELSEIF num_players > 1 THEN
        Banner "You recover a fallen rival's spoils!", _TRIM$(got) + "   [ press any key ]"
    ELSE
        Banner "You reclaim the spoils you dropped here -- revenge is sweet!", _TRIM$(got) + "   [ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' ============================================================================
'  LINGERING -> WANDERING MONSTERS
'  Hanging about (searching the same spot, standing idle) has a cost: the `loiter`
'  meter rises, first with atmospheric omens, then a wandering monster of the
'  current level ambushes you. Moving to a new cell resets the meter.
' ============================================================================

' A random atmospheric omen. stage 1 = something stirs (distant); stage 2+ = it's
' close. Drawn as a brief flash so it sets mood without demanding a keypress.
FUNCTION LoiterOmen$ (stage AS INTEGER)
    IF stage <= 1 THEN
        SELECT CASE RollDie(8)
            CASE 1: LoiterOmen$ = "You hear faint scuffling somewhere in the dark."
            CASE 2: LoiterOmen$ = "A cold draft carries a distant, wet growl."
            CASE 3: LoiterOmen$ = "Loose grit trickles down from the ceiling."
            CASE 4: LoiterOmen$ = "Goosebumps prickle the back of your neck."
            CASE 5: LoiterOmen$ = "Your torchlight wavers, though there is no wind."
            CASE 6: LoiterOmen$ = "Something skitters past in the dark, then falls silent."
            CASE 7: LoiterOmen$ = "The shadows seem to lean in and watch you."
            CASE ELSE: LoiterOmen$ = "Far off, a door groans open on rusted hinges."
        END SELECT
    ELSE
        SELECT CASE RollDie(8)
            CASE 1: LoiterOmen$ = "Claws click on stone -- closer now."
            CASE 2: LoiterOmen$ = "A hiss echoes from just beyond the doorway."
            CASE 3: LoiterOmen$ = "The stench of something rank rolls over you."
            CASE 4: LoiterOmen$ = "Heavy, wet breathing rasps in the dark nearby."
            CASE 5: LoiterOmen$ = "Red eyes glint at the edge of your torchlight."
            CASE 6: LoiterOmen$ = "Gravel crunches under a weight that is not yours."
            CASE 7: LoiterOmen$ = "A low growl trembles in the floor beneath your boots."
            CASE ELSE: LoiterOmen$ = "Something is very near now -- move, before it finds you."
        END SELECT
    END IF
END FUNCTION


' TRUE when the player stands in a CLEARED room that holds a secret door -- a safe
' haven where no wandering monster will disturb them (secret-door room = sanctuary,
' once its own monster is slain).
FUNCTION InSanctuary%
    DIM rm AS INTEGER, i AS INTEGER, cx AS INTEGER, cy AS INTEGER
    InSanctuary = 0
    IF NOT InRoomNow THEN EXIT FUNCTION
    rm = ROOMAT(c.x \ CW, c.y \ CH)
    IF rm < 1 THEN EXIT FUNCTION
    IF ROOMS(rm).malive AND LEN(_TRIM$(ROOMS(rm).monster)) > 0 THEN EXIT FUNCTION   ' its monster still lurks
    cx = c.x \ CW: cy = c.y \ CH
    FOR i = 1 TO SD_N
        IF ABS(SD_X(i) - cx) <= 3 AND ABS(SD_Y(i) - cy) <= 3 THEN InSanctuary = -1: EXIT FUNCTION
    NEXT i
END FUNCTION


' Flash an omen briefly (no keypress), then restore the board.
SUB FlashOmen (stage AS INTEGER)
    Sfx "idle"
    Banner LoiterOmen$(stage), "-- best not to linger --"
    _DELAY 1.7
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' One "time passes" tick from lingering (a search, or a long hardcore idle). The early
' ticks flash an omen; once the meter is full there is an IDLE_ENCOUNTER_PCT chance the
' dungeon sends something after you (else a close omen and the meter stays hot). A level
' you have fully cleared is yours -- no lingering danger there at all.
SUB LoiterTick
    DIM sec AS INTEGER
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec >= 1 AND sec <= 9 THEN
        IF lvl_cleared(sec) THEN EXIT SUB          ' cleared this floor -- rest easy
    END IF
    IF InSanctuary THEN EXIT SUB                   ' a cleared secret-door room is a safe haven
    DIM encpct AS INTEGER
    loiter = loiter + 1
    IF loiter < LOITER_THRESHOLD THEN
        FlashOmen loiter                           ' building dread
    ELSE
        encpct = IDLE_ENCOUNTER_PCT
        IF siren_turns > 0 THEN encpct = encpct + SIREN_ENCOUNTER_BOOST   ' a siren makes it far worse
        IF RollDie(100) <= encpct THEN
            loiter = 0
            WanderEncounter                        ' the dungeon sends something after you
        ELSE
            FlashOmen 2                            ' a near miss -- danger persists, roll again next tick
        END IF
    END IF
END SUB


' Ambush by a wandering monster of the CURRENT dungeon level. Set up in a scratch
' ROOMS() slot (never mapped in ROOMAT, so it can't be walked into), then fought
' with the normal combat code. Wanderers travel light: modest gold, no cards, no key.
SUB WanderEncounter
    DIM AS INTEGER sec, w, m, t, res, cx, cy
    cx = c.x \ CW: cy = c.y \ CH
    IF ABS(cx - START_CX) <= 3 AND ABS(cy - START_CY) <= 3 THEN EXIT SUB   ' the entrance is safe
    sec = SECTOR.get_by_xy(c.x, c.y): IF sec < 1 THEN sec = 1
    IF sec >= 1 AND sec <= 9 THEN
        IF lvl_cleared(sec) THEN EXIT SUB   ' a cleared level holds no more wanderers
    END IF
    w = ROOM_N + 1: IF w > 400 THEN w = 400
    ROOMS(w).sec = sec
    m = RollDie(3)
    ROOMS(w).monster = MON_NAME(sec, m): ROOMS(w).mslot = m
    ROOMS(w).malive = TRUE: ROOMS(w).is_boss = FALSE
    ROOMS(w).monster_fought = FALSE: ROOMS(w).player_died = FALSE: ROOMS(w).looted = FALSE
    ROOMS(w).mhp = sec * 4 + RollDie(6) + 2: ROOMS(w).mhp_now = ROOMS(w).mhp
    ROOMS(w).mac = 9 + sec
    t = RollDie(3)
    ' wanderers carry only scraps -- you can't farm them for a quick win (WANDER_GOLD_DIV keeps it lean)
    ROOMS(w).treasure_name = TRE_NAME(sec, t): ROOMS(w).treasure = TRE_GOLD(sec, t) \ WANDER_GOLD_DIV
    ROOMS(w).treasure_item = 0
    ROOMS(w).drop_gold = 0: ROOMS(w).drop_sword = 0
    ROOMS(w).drop_secret = FALSE: ROOMS(w).drop_esp = FALSE: ROOMS(w).drop_crystal = FALSE
    c.prev_x = c.x: c.prev_y = c.y                ' fleeing a wanderer just leaves you put
    Sfx "trap"
    Banner "A WANDERING " + _TRIM$(ROOMS(w).monster) + " bursts from the shadows!", "Your lingering has drawn it to you.   [ press any key ]"
    WaitKey
    res = DoCombat(w)
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB

' ============================================================================
'  MODULES
' ============================================================================
'$INCLUDE:'include/DATA.bas'
'$INCLUDE:'include/SECTOR.bas'
'$INCLUDE:'include/BOARD.bas'
'$INCLUDE:'include/CURSOR.bas'
'$INCLUDE:'include/MENU.bas'
'$INCLUDE:'include/LORDS.bas'
'$INCLUDE:'include/PLAYERS.bas'
'$INCLUDE:'include/EFFECTS.bas'
'$INCLUDE:'include/CURIO.bas'
'$INCLUDE:'include/STATS.bas'
'$INCLUDE:'include/SAVEGAME.bas'
'$INCLUDE:'include/FLAVOR.bas'
'$INCLUDE:'include/CTEXT.bas'
'$INCLUDE:'include/MUSIC.bas'

'$INCLUDE:'include/DICE3D/_ALL.BM'      ' 3D dice implementation (bottom, per the module's contract)
'$INCLUDE:'include/DICE3D_GAME.bas'     ' dungeon<->DICE3D glue (LoadDiceSets, Show3DRoll)

'$INCLUDE:'include/Toolbox64/FileOps.bas'
'$INCLUDE:'include/Toolbox64/ANSIPrint.bas'
