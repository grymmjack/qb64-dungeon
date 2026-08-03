' ============================================================================
'  PLAYERS.bas -- GAME hot-seat seats (up to 4): park/restore each player's state
'  between turns, and pass the seat.
'
'  Moved from engine/: the active player's state IS the working globals, and those
'  globals are DUNGEON! (class, gold, Level Key, sword/ESP/crystal/secret card,
'  ability scores). Load/SaveActivePlayer copy that whole record in and out, so this
'  is game state management, not engine machinery -- "N players take turns" is the
'  only generic part, and it is a handful of lines. No engine module calls anything
'  here; dungeon.bas and game/ do.
' ============================================================================

' Distinct board-token colour per player (semi-transparent).
FUNCTION PlayerColor~& (p AS INTEGER)
    SELECT CASE p
        CASE 1: PlayerColor = ThmA~&("player.1", _RGB32(&HFF, &H30, &H30), &HDD)     ' red
        CASE 2: PlayerColor = ThmA~&("player.2", _RGB32(&H30, &HC0, &HFF), &HDD)     ' cyan
        CASE 3: PlayerColor = ThmA~&("player.3", _RGB32(&H50, &HFF, &H50), &HDD)     ' green
        CASE ELSE: PlayerColor = ThmA~&("player.4", _RGB32(&HFF, &HD0, &H30), &HDD)  ' gold
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
    ' the rest of the seat's kit -- without these, hot-seat players shared one inventory
    item_armor = PLAYERS(p).armor: item_shield = PLAYERS(p).shield
    item_bow = PLAYERS(p).bow: item_boots = PLAYERS(p).boots
    item_teleport = PLAYERS(p).teleport
    item_potion_small = PLAYERS(p).pot_sm: item_potion_large = PLAYERS(p).pot_lg
    spell_fire = PLAYERS(p).sp_fire: spell_bolt = PLAYERS(p).sp_bolt
    char_level = PLAYERS(p).clevel: char_xp = PLAYERS(p).cxp
    poison_turns = PLAYERS(p).t_poison: fire_turns = PLAYERS(p).t_fire
    curse_turns = PLAYERS(p).t_curse
    frost_turns = PLAYERS(p).t_frost: siren_turns = PLAYERS(p).t_siren
    ' Re-seed the STICKY level from THIS seat's position (see PlayerLevel%). Without it, a seat
    ' standing in an unclaimed corridor would inherit the previous player's depth -- pass the
    ' turn from someone on level 9 and player 2 would meet level 9 wanderers in a level 1 hall.
    ' Not saved: it self-heals from position on the next turn change or the next claimed cell.
    SeedPlayerLevel c.x, c.y
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
    PLAYERS(p).armor = item_armor: PLAYERS(p).shield = item_shield
    PLAYERS(p).bow = item_bow: PLAYERS(p).boots = item_boots
    PLAYERS(p).teleport = item_teleport
    PLAYERS(p).pot_sm = item_potion_small: PLAYERS(p).pot_lg = item_potion_large
    PLAYERS(p).sp_fire = spell_fire: PLAYERS(p).sp_bolt = spell_bolt
    PLAYERS(p).clevel = char_level: PLAYERS(p).cxp = char_xp
    PLAYERS(p).t_poison = poison_turns: PLAYERS(p).t_fire = fire_turns
    PLAYERS(p).t_curse = curse_turns
    PLAYERS(p).t_frost = frost_turns: PLAYERS(p).t_siren = siren_turns
END SUB


' Simple name entry for a hot-seat player.
FUNCTION PromptName$ (prompt AS STRING)
    PromptName$ = PromptNameSeed$(prompt, "")
END FUNCTION

' As PromptName$, but the field starts holding `seed` -- so RENAMING is editing what you already
' have rather than retyping it from an empty box. [ESC] abandons the edit and keeps the seed,
' which only means anything when there IS one; from an empty field it behaves as before.
FUNCTION PromptNameSeed$ (prompt AS STRING, seed AS STRING)
    DIM nm AS STRING, k AS STRING, chcode AS INTEGER
    nm = _TRIM$(seed)
    DO
        _LIMIT 60
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 18, prompt
        COLOR GREENU, BLACK: PrintCentered 22, "> " + nm + "_"
        IF LEN(_TRIM$(seed)) > 0 THEN
            COLOR CYANU, BLACK: PrintCentered 26, "[ENTER] confirm    [BACKSPACE] edit    [ESC] keep " + CHR$(34) + _TRIM$(seed) + CHR$(34)
        ELSE
            COLOR CYANU, BLACK: PrintCentered 26, "[ENTER] confirm"
        END IF
        COLOR GREY, BLACK: PrintCentered 24, _TRIM$(STR$(NAME_MAX - LEN(nm))) + " characters left
        Present
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                EXIT DO
            ELSEIF k = CHR$(27) AND LEN(_TRIM$(seed)) > 0 THEN
                PromptNameSeed$ = _TRIM$(seed): EXIT FUNCTION      ' abandoned -- keep the old name
            ELSEIF k = CHR$(8) THEN
                IF LEN(nm) > 0 THEN nm = LEFT$(nm, LEN(nm) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                ' NAME_MAX, not 14 -- see the note there. `|` is excluded because it is the field
                ' separator in dungeon-lords.dat, and a name containing one would split its own
                ' record in half.
                IF chcode >= 32 AND chcode <= 126 AND chcode <> 124 AND LEN(nm) < NAME_MAX THEN nm = nm + k
            END IF
        END IF
    LOOP
    IF _TRIM$(nm) = "" THEN nm = _TRIM$(seed)
    IF _TRIM$(nm) = "" THEN nm = "PLAYER"
    PromptNameSeed$ = nm
END FUNCTION

' [E] in the character creator: type a name instead of cycling random ones. The creator could
' only ever re-roll a RANDOM name ([N]), so a player who wanted their own had no way to enter it.
SUB RenameChampion
    player_name = PromptNameSeed$("NAME YOUR CHAMPION", player_name)
    Sfx "select"
END SUB


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
        ' fresh per-seat kit. This is where the Wizard's spellbook is granted -- it used to
        ' be set once on the working globals AFTER SetupPlayers, so only whoever happened to
        ' be active at init (player 1) ever got one; a Wizard in seat 2 started empty.
        PLAYERS(p).armor = 0: PLAYERS(p).shield = 0
        PLAYERS(p).bow = FALSE: PLAYERS(p).boots = FALSE
        PLAYERS(p).pot_sm = 0: PLAYERS(p).pot_lg = 0
        PLAYERS(p).clevel = 1: PLAYERS(p).cxp = 0
        PLAYERS(p).t_poison = 0: PLAYERS(p).t_fire = 0
        PLAYERS(p).t_curse = 0
        PLAYERS(p).t_frost = 0: PLAYERS(p).t_siren = 0
        IF klass = 4 THEN
            ' INT -- "how many spells you can carry". 3/3/2 is the baseline (INT 10-11); every
            ' +2 INT is one more of each attack spell. Teleport is left flat: it is an escape,
            ' and scaling it would make a clever Wizard simply un-killable.
            PLAYERS(p).sp_fire = 3 + AbilMod(PLAYERS(p).sint)
            PLAYERS(p).sp_bolt = 3 + AbilMod(PLAYERS(p).sint)
            IF PLAYERS(p).sp_fire < 1 THEN PLAYERS(p).sp_fire = 1
            IF PLAYERS(p).sp_bolt < 1 THEN PLAYERS(p).sp_bolt = 1
            PLAYERS(p).teleport = 2
        ELSE
            PLAYERS(p).sp_fire = 0: PLAYERS(p).sp_bolt = 0: PLAYERS(p).teleport = 0
        END IF
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
    cursor_erase: cursor_draw: DrawHUD: Present
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
    StartTurnMove
END SUB
