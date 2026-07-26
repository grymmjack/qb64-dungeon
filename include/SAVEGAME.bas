' ============================================================================
'  SAVEGAME.bas -- single-slot mid-run save/load (dungeon-save.dat, git-ignored)
'
'  The dungeon layout is DETERMINISTIC given its seed: PlayGame captures run_seed
'  and RANDOMIZEs with it before StartBoard + RandomizeRooms. So the save file
'  stores only the SEED plus the mutable deltas (player state, per-room kill/loot
'  flags, revealed secret doors, broken doors, chronicle, status). On load we
'  re-seed and rebuild the identical dungeon, then overlay those deltas.
'
'  Format: whitespace-separated tokens, consumed in a fixed order. Reading uses
'  _READFILE$ + a manual split (QB64's EOF/LINE INPUT is unreliable here).
'  Scope: single-player. [G] saves in-game; a save is offered on entering.
' ============================================================================

FUNCTION HasSave%
    HasSave = (_FILEEXISTS("dungeon-save.dat") <> 0)
END FUNCTION

' Remove the save (called when a run ends -- winning -- so a stale continue can't resume it).
SUB DeleteSave
    IF _FILEEXISTS("dungeon-save.dat") THEN KILL "dungeon-save.dat"
END SUB


' Offered when entering the dungeon and a save exists: continue it or start fresh.
FUNCTION AskContinue%
    DIM k AS STRING
    _DEST CANVAS: CLS , BLACK
    COLOR YELLOWU, BLACK: PrintCentered 22, "A saved delve awaits you."
    COLOR CYANU, BLACK: PrintCentered 24, "[C] CONTINUE saved game        [N] start a NEW game"
    _DISPLAY
    DO
        _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
        IF k = "C" OR k = CHR$(13) THEN AskContinue = -1: EXIT FUNCTION
        IF k = "N" OR k = CHR$(27) THEN AskContinue = 0: EXIT FUNCTION
    LOOP
END FUNCTION


' [G] in-game: save + a brief confirmation, then back to the board.
SUB SaveAndToast
    SaveGame
    Sfx "key"
    Banner "-- GAME SAVED --", "Choose CONTINUE next time you enter the dungeon.   [ press any key ]"
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' Write the whole run to dungeon-save.dat.
SUB SaveGame
    DIM f AS INTEGER, i AS INTEGER, s AS STRING, el AS DOUBLE
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    f = FREEFILE
    OPEN "dungeon-save.dat" FOR OUTPUT AS #f
    PRINT #f, "DUNGEONSAVE 3"
    PRINT #f, run_seed
    PRINT #f, num_players; cur_player
    PRINT #f, el
    PRINT #f, player_class; " "; gold; " "; target_gold; " "; has_key; " "; key_room; " "; key_level
    PRINT #f, char_level; " "; char_xp; " "; player_hp; " "; player_maxhp
    PRINT #f, player_str; player_int; player_wis; player_dex; player_con; player_cha
    PRINT #f, player_tohit; player_ac; player_dmgdie; player_dmgbonus
    PRINT #f, item_sword; item_secret_card; item_esp; item_crystal; item_armor; item_bow; item_boots; item_teleport; item_potion_small; item_potion_large
    PRINT #f, poison_turns; fire_turns; frost_turns; siren_turns
    PRINT #f, c.x; c.y; c.prev_x; c.prev_y
    PRINT #f, moves_made; turn_num; steps_left; need_roll; loiter
    ' NOTE: separate every value with a SPACE. STR$ of a negative has no leading space,
    ' so `s + STR$(-1) + STR$(-1)` ran together as "-1-1" and desynced the token stream
    ' (booleans are -1). Space-join keeps each value its own token.
    s = ""
    FOR i = 1 TO 9: s = s + " " + _TRIM$(STR$(lvl_kills(i))): NEXT i: PRINT #f, s
    s = ""
    FOR i = 1 TO 9: s = s + " " + _TRIM$(STR$(lvl_gold(i))): NEXT i: PRINT #f, s
    s = ""
    FOR i = 1 TO 9: s = s + " " + _TRIM$(STR$(lvl_reached(i))): NEXT i: PRINT #f, s
    s = ""
    FOR i = 1 TO 9: s = s + " " + _TRIM$(STR$(lvl_cleared(i))): NEXT i: PRINT #f, s
    s = ""
    FOR i = 1 TO 4: s = s + " " + _TRIM$(STR$(deaths(i))): NEXT i: PRINT #f, s
    ' the champion name on its own line so spaces survive (read as a whole line marker)
    PRINT #f, "NAME " + _TRIM$(player_name)
    ' revealed secret doors + broken doors (index lists)
    s = ""
    FOR i = 1 TO SD_N: IF SD_FOUND(i) THEN s = s + STR$(i)
    NEXT i
    PRINT #f, "SD" + s
    s = ""
    FOR i = 1 TO DOOR_N: IF DOOR_BROKEN(i) THEN s = s + STR$(i)
    NEXT i
    PRINT #f, "DB" + s
    ' per-room mutable state
    PRINT #f, "ROOMS "; ROOM_N
    FOR i = 1 TO ROOM_N
        PRINT #f, ROOMS(i).malive; ROOMS(i).mhp_now; ROOMS(i).looted; ROOMS(i).monster_fought; ROOMS(i).player_died; ROOMS(i).seen; ROOMS(i).drop_gold; ROOMS(i).drop_sword; ROOMS(i).drop_secret; ROOMS(i).drop_esp; ROOMS(i).drop_crystal; ROOMS(i).mhp
    NEXT i
    ' loose drops -- spoils left where a fall happened on the open paths
    PRINT #f, "LOOSE "; UBOUND(LOOSE)
    FOR i = 1 TO UBOUND(LOOSE)
        PRINT #f, LOOSE(i).active; LOOSE(i).cx; LOOSE(i).cy; LOOSE(i).gold; LOOSE(i).sword; LOOSE(i).secret; LOOSE(i).esp; LOOSE(i).crystal
    NEXT i
    CLOSE #f
END SUB


' -- token-stream reader (split the save file once, then consume in order) --
SUB TokLoad (path AS STRING)
    DIM raw AS STRING, i AS INTEGER, cur AS STRING, ch2 AS STRING
    raw = _READFILE$(path)
    SVTOK_N = 0: SVTOK_I = 1
    cur = ""
    FOR i = 1 TO LEN(raw)
        ch2 = MID$(raw, i, 1)
        IF ch2 = " " OR ch2 = CHR$(9) OR ch2 = CHR$(10) OR ch2 = CHR$(13) THEN
            IF LEN(cur) > 0 THEN
                IF SVTOK_N < UBOUND(SVTOK) THEN SVTOK_N = SVTOK_N + 1: SVTOK(SVTOK_N) = cur
                cur = ""
            END IF
        ELSE
            cur = cur + ch2
        END IF
    NEXT i
    IF LEN(cur) > 0 AND SVTOK_N < UBOUND(SVTOK) THEN SVTOK_N = SVTOK_N + 1: SVTOK(SVTOK_N) = cur
END SUB

FUNCTION NextTok$
    IF SVTOK_I > SVTOK_N THEN NextTok$ = "": EXIT FUNCTION
    NextTok$ = SVTOK(SVTOK_I): SVTOK_I = SVTOK_I + 1
END FUNCTION

FUNCTION NextI%
    NextI = VAL(NextTok$)
END FUNCTION

FUNCTION NextL&
    NextL = VAL(NextTok$)
END FUNCTION


' Read dungeon-save.dat, rebuild the identical dungeon from its seed, then overlay
' the saved state. One sequential pass -- the token cursor is untouched by the
' board rebuild, so SD/DB/ROOMS are read AFTER StartBoard/RandomizeRooms.
' Assumes the caller (PlayGame) enters the loop afterwards.
SUB LoadGameApply
    DIM i AS INTEGER, rn AS INTEGER, el AS DOUBLE, tag AS STRING, nm AS STRING, sver AS INTEGER
    DIM scx AS INTEGER, scy AS INTEGER, spx AS INTEGER, spy AS INTEGER

    TokLoad "dungeon-save.dat"
    tag = NextTok$                                  ' "DUNGEONSAVE"
    sver = NextI                                    ' save format version (3 = per-room mhp is stored, not reproduced)
    run_seed = VAL(NextTok$)
    num_players = NextI: cur_player = NextI
    IF num_players < 1 THEN num_players = 1
    el = VAL(NextTok$)
    player_class = NextI: gold = NextL: target_gold = NextL: has_key = NextI: key_room = NextI: key_level = NextI
    char_level = NextI: char_xp = NextL: player_hp = NextI: player_maxhp = NextI
    player_str = NextI: player_int = NextI: player_wis = NextI: player_dex = NextI: player_con = NextI: player_cha = NextI
    player_tohit = NextI: player_ac = NextI: player_dmgdie = NextI: player_dmgbonus = NextI
    item_sword = NextI: item_secret_card = NextI: item_esp = NextI: item_crystal = NextI
    item_armor = NextI: item_bow = NextI: item_boots = NextI: item_teleport = NextI
    item_potion_small = NextI: item_potion_large = NextI
    poison_turns = NextI: fire_turns = NextI: frost_turns = NextI: siren_turns = NextI
    scx = NextI: scy = NextI: spx = NextI: spy = NextI       ' restored AFTER StartBoard (which resets it)
    moves_made = NextI: turn_num = NextI: steps_left = NextI: need_roll = NextI: loiter = NextI
    FOR i = 1 TO 9: lvl_kills(i) = NextI: NEXT i
    FOR i = 1 TO 9: lvl_gold(i) = NextL: NEXT i
    FOR i = 1 TO 9: lvl_reached(i) = NextI: NEXT i
    FOR i = 1 TO 9: lvl_cleared(i) = NextI: NEXT i
    FOR i = 1 TO 4: deaths(i) = NextI: NEXT i

    class_name = _TRIM$(CLASSES(player_class).name)

    ' NAME line: consume "NAME", then gather name tokens until the "SD" section
    tag = NextTok$                                  ' "NAME"
    nm = ""
    DO
        IF SVTOK_I > SVTOK_N THEN EXIT DO
        IF LEFT$(SVTOK(SVTOK_I), 2) = "SD" THEN EXIT DO
        IF nm = "" THEN nm = SVTOK(SVTOK_I) ELSE nm = nm + " " + SVTOK(SVTOK_I)
        SVTOK_I = SVTOK_I + 1
    LOOP
    player_name = nm

    ' rebuild the identical dungeon (does NOT touch the token cursor)
    RANDOMIZE run_seed
    StartBoard                                      ' board + fog + detect rooms (resets cursor to START)
    RandomizeRooms                                  ' reproduce monsters/treasure/key/boss identically
    c.x = scx: c.y = scy: c.prev_x = spx: c.prev_y = spy   ' restore the saved position over StartBoard's reset

    ' revealed secret doors: "SD" then indices until "DB"
    tag = NextTok$                                  ' "SD"
    FOR i = 1 TO SD_N: SD_FOUND(i) = FALSE: NEXT i
    DO
        IF SVTOK_I > SVTOK_N THEN EXIT DO
        IF SVTOK(SVTOK_I) = "DB" THEN EXIT DO
        rn = VAL(NextTok$)
        IF rn >= 1 AND rn <= SD_N THEN SD_FOUND(rn) = TRUE: RevealRegionFromDoor rn
    LOOP
    ' broken doors: "DB" then indices until "ROOMS"
    tag = NextTok$                                  ' "DB"
    DO
        IF SVTOK_I > SVTOK_N THEN EXIT DO
        IF SVTOK(SVTOK_I) = "ROOMS" THEN EXIT DO
        rn = VAL(NextTok$)
        IF rn >= 1 AND rn <= DOOR_N THEN DOOR_BROKEN(rn) = TRUE
    LOOP
    ' per-room mutable state
    tag = NextTok$                                  ' "ROOMS"
    rn = NextI                                       ' saved ROOM_N (should equal the reproduced ROOM_N)
    IF rn > ROOM_N THEN rn = ROOM_N
    FOR i = 1 TO rn
        ROOMS(i).malive = NextI: ROOMS(i).mhp_now = NextI: ROOMS(i).looted = NextI
        ROOMS(i).monster_fought = NextI: ROOMS(i).player_died = NextI: ROOMS(i).seen = NextI
        ROOMS(i).drop_gold = NextL: ROOMS(i).drop_sword = NextI: ROOMS(i).drop_secret = NextI
        ROOMS(i).drop_esp = NextI: ROOMS(i).drop_crystal = NextI
        ' v3+: mhp is STORED, not reproduced -- RandomizeRooms' RNG can shift between builds,
        ' which desynced the re-rolled mhp from the saved mhp_now (monsters showing 20/15 etc.)
        IF sver >= 3 THEN ROOMS(i).mhp = NextL
    NEXT i
    ' Safety net for older saves (and any residual desync): a monster can never have more
    ' current HP than its maximum -- clamp so the panel can't read "20/15".
    FOR i = 1 TO ROOM_N
        IF ROOMS(i).mhp_now > ROOMS(i).mhp THEN ROOMS(i).mhp_now = ROOMS(i).mhp
    NEXT i

    ' loose drops (spoils on the open paths). Older saves lack this section -- the tag
    ' won't match, so they just load with no loose drops. Clear first either way.
    FOR i = 1 TO UBOUND(LOOSE): LOOSE(i).active = 0: NEXT i
    IF SVTOK_I <= SVTOK_N THEN
        IF SVTOK(SVTOK_I) = "LOOSE" THEN
            tag = NextTok$                            ' "LOOSE"
            rn = NextI                                ' saved slot count
            IF rn > UBOUND(LOOSE) THEN rn = UBOUND(LOOSE)
            FOR i = 1 TO rn
                LOOSE(i).active = NextI: LOOSE(i).cx = NextI: LOOSE(i).cy = NextI: LOOSE(i).gold = NextL
                LOOSE(i).sword = NextI: LOOSE(i).secret = NextI: LOOSE(i).esp = NextI: LOOSE(i).crystal = NextI
            NEXT i
        END IF
    END IF

    game_start = TIMER - el                          ' restore the elapsed run timer
    IF game_start > TIMER THEN game_start = TIMER
END SUB
