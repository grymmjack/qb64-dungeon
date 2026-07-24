' ============================================================================
'  PLAYERS.bas -- hot-seat multiplayer (up to 4). The ACTIVE player's state
'  lives in the working globals (gold, c, player_hp, items, ...); PLAYERS(1..4)
'  parks each player's state between turns. Load/Save swap at turn boundaries so
'  every other routine keeps operating on "the current player" unchanged.
' ============================================================================

' Distinct board-token colour per player (semi-transparent).
FUNCTION PlayerColor~& (p AS INTEGER)
    SELECT CASE p
        CASE 1: PlayerColor = _RGB32(&HFF, &H30, &H30, &HDD)     ' red
        CASE 2: PlayerColor = _RGB32(&H30, &HC0, &HFF, &HDD)     ' cyan
        CASE 3: PlayerColor = _RGB32(&H50, &HFF, &H50, &HDD)     ' green
        CASE ELSE: PlayerColor = _RGB32(&HFF, &HD0, &H30, &HDD)  ' gold
    END SELECT
END FUNCTION


' Copy parked player p into the working globals (make them the active player).
SUB LoadActivePlayer (p AS INTEGER)
    player_class = PLAYERS(p).klass
    class_name = CLASSES(player_class).name
    player_name = _TRIM$(PLAYERS(p).name)
    gold = PLAYERS(p).gold: target_gold = PLAYERS(p).goal
    has_key = PLAYERS(p).has_key
    item_sword = PLAYERS(p).sword: item_secret_card = PLAYERS(p).secret_card
    item_esp = PLAYERS(p).esp: item_crystal = PLAYERS(p).crystal
    player_hp = PLAYERS(p).hp: player_maxhp = PLAYERS(p).maxhp
    player_str = PLAYERS(p).sstr: player_int = PLAYERS(p).sint: player_wis = PLAYERS(p).swis
    player_dex = PLAYERS(p).sdex: player_con = PLAYERS(p).scon: player_cha = PLAYERS(p).scha
    player_tohit = PLAYERS(p).tohit: player_ac = PLAYERS(p).ac
    player_dmgdie = PLAYERS(p).dmgdie: player_dmgbonus = PLAYERS(p).dmgbonus
    c.x = PLAYERS(p).cx: c.y = PLAYERS(p).cy: c.prev_x = c.x: c.prev_y = c.y
    c.cursor_color = PLAYERS(p).kolor
END SUB


' Copy the working globals back into parked player p.
SUB SaveActivePlayer (p AS INTEGER)
    PLAYERS(p).klass = player_class
    PLAYERS(p).name = player_name
    PLAYERS(p).gold = gold: PLAYERS(p).goal = target_gold
    PLAYERS(p).has_key = has_key
    PLAYERS(p).sword = item_sword: PLAYERS(p).secret_card = item_secret_card
    PLAYERS(p).esp = item_esp: PLAYERS(p).crystal = item_crystal
    PLAYERS(p).hp = player_hp: PLAYERS(p).maxhp = player_maxhp
    PLAYERS(p).sstr = player_str: PLAYERS(p).sint = player_int: PLAYERS(p).swis = player_wis
    PLAYERS(p).sdex = player_dex: PLAYERS(p).scon = player_con: PLAYERS(p).scha = player_cha
    PLAYERS(p).tohit = player_tohit: PLAYERS(p).ac = player_ac
    PLAYERS(p).dmgdie = player_dmgdie: PLAYERS(p).dmgbonus = player_dmgbonus
    PLAYERS(p).cx = c.x: PLAYERS(p).cy = c.y
END SUB


' Simple name entry for a hot-seat player.
FUNCTION PromptName$ (prompt AS STRING)
    DIM nm AS STRING, k AS STRING, chcode AS INTEGER
    nm = ""
    DO
        _LIMIT 60
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 18, prompt
        COLOR GREENU, BLACK: PrintCentered 22, "> " + nm + "_"
        COLOR CYANU, BLACK: PrintCentered 26, "[ENTER] confirm"
        _DISPLAY
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                EXIT DO
            ELSEIF k = CHR$(8) THEN
                IF LEN(nm) > 0 THEN nm = LEFT$(nm, LEN(nm) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                IF chcode >= 32 AND chcode <= 126 AND LEN(nm) < 14 THEN nm = nm + k
            END IF
        END IF
    LOOP
    IF _TRIM$(nm) = "" THEN nm = "PLAYER"
    PromptName$ = nm
END FUNCTION


' Build every player. Solo reuses the character already set from the menu;
' multiplayer walks each player through class-select, a 3d6 roll-up, and a name.
SUB SetupPlayers
    DIM p AS INTEGER, klass AS INTEGER, nm AS STRING
    FOR p = 1 TO num_players
        IF num_players > 1 THEN
            Banner "PLAYER " + _TRIM$(STR$(p)) + " -- choose your champion", "[ press any key ]"
            WaitKey
            klass = SelectClass
            IF klass < 1 THEN klass = 1
            player_class = klass
            RollCharacter klass                       ' rolls stats into the working globals
            nm = PromptName$("PLAYER " + _TRIM$(STR$(p)) + " -- name your champion")
        ELSE
            klass = player_class                      ' set by the menu's CREATE (or default)
            IF player_maxhp <= 0 THEN InitDefaultChar klass
            nm = player_name
        END IF
        ' capture the working character into PLAYERS(p) with a fresh run state
        PLAYERS(p).active = TRUE
        PLAYERS(p).klass = klass
        PLAYERS(p).name = nm
        PLAYERS(p).goal = CLASSES(klass).gold_goal
        PLAYERS(p).gold = 0
        PLAYERS(p).has_key = FALSE
        PLAYERS(p).sword = 0: PLAYERS(p).secret_card = FALSE
        PLAYERS(p).esp = FALSE: PLAYERS(p).crystal = FALSE
        PLAYERS(p).maxhp = player_maxhp: PLAYERS(p).hp = player_maxhp
        PLAYERS(p).sstr = player_str: PLAYERS(p).sint = player_int: PLAYERS(p).swis = player_wis
        PLAYERS(p).sdex = player_dex: PLAYERS(p).scon = player_con: PLAYERS(p).scha = player_cha
        PLAYERS(p).tohit = player_tohit: PLAYERS(p).ac = player_ac
        PLAYERS(p).dmgdie = player_dmgdie: PLAYERS(p).dmgbonus = player_dmgbonus
        PLAYERS(p).cx = START_CX * CW: PLAYERS(p).cy = START_CY * CH
        PLAYERS(p).kolor = PlayerColor(p)
        LOOT_N(p) = 0                             ' fresh treasure log
    NEXT p
END SUB


' Index of the next still-in-the-game player after `from` (wraps around).
FUNCTION NextActivePlayer% (from AS INTEGER)
    DIM n AS INTEGER, i AS INTEGER
    n = from
    FOR i = 1 TO num_players
        n = n + 1: IF n > num_players THEN n = 1
        IF PLAYERS(n).active THEN NextActivePlayer = n: EXIT FUNCTION
    NEXT i
    NextActivePlayer = from
END FUNCTION


' Multiplayer: announce whose turn it is (solo is a no-op).
SUB AnnounceTurn (p AS INTEGER)
    IF num_players <= 1 THEN EXIT SUB
    cursor_erase: cursor_draw
    Banner "PLAYER " + _TRIM$(STR$(p)) + "  --  " + _TRIM$(PLAYERS(p).name) + " the " + CLASSES(PLAYERS(p).klass).name, "your turn!   [SPACE] roll the movement dice"
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' End the active player's turn: solo just re-rolls; multiplayer hands the seat
' to the next player and announces it.
SUB EndPlayerTurn
    IF num_players > 1 THEN
        SaveActivePlayer cur_player
        cur_player = NextActivePlayer(cur_player)
        LoadActivePlayer cur_player
        cursor_erase: cursor_draw
        AnnounceTurn cur_player
    END IF
    need_roll = TRUE
END SUB
