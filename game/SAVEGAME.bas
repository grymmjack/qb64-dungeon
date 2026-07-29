' ============================================================================
'  SAVEGAME.bas -- GAME payload for single-slot mid-run save/load
'                  (dungeon-save.dat, git-ignored).
'
'  The dungeon layout is DETERMINISTIC given its seed: PlayGame captures run_seed
'  and RANDOMIZEs with it before StartBoard + RandomizeRooms. So the save file
'  stores only the SEED plus the mutable deltas (player state, per-room kill/loot
'  flags, revealed secret doors, broken doors, chronicle, status). On load we
'  re-seed and rebuild the identical dungeon, then overlay those deltas.
'
'  The generic file plumbing it rides on (HasSave / DeleteSave / AskContinue /
'  TokLoad / NextTok$ / NextI% / NextL&) lives in engine/SAVEIO.bas.
'  Format: whitespace-separated tokens, consumed in a fixed order.
'  Scope: single-player. [G] saves in-game; a save is offered on entering.
' ============================================================================

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
    OPEN "gameplay-data-saves/dungeon-save.dat" FOR OUTPUT AS #f
    PRINT #f, "DUNGEONSAVE 4"
    PRINT #f, run_seed
    PRINT #f, num_players; cur_player
    PRINT #f, el
    PRINT #f, player_class; " "; gold; " "; target_gold; " "; has_key; " "; key_room; " "; key_level
    PRINT #f, char_level; " "; char_xp; " "; player_hp; " "; player_maxhp
    PRINT #f, player_str; player_int; player_wis; player_dex; player_con; player_cha
    PRINT #f, player_tohit; player_ac; player_dmgdie; player_dmgbonus
    PRINT #f, item_sword; item_secret_card; item_esp; item_crystal; item_armor; item_bow; item_boots; item_teleport; item_potion_small; item_potion_large; item_shield; spell_fire; spell_bolt
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
    ' solo challenge (single-player variants) -- so a saved timed / item-hunt / monster-prey
    ' run RESUMES in the same mode (else Continue dropped back to normal play: no timer/hunter)
    PRINT #f, "SOLO "; solo_on; opt_solomode; opt_solomins; solo_item_room; solo_item_lvl; solo_found; hunt_on; hunt_cx; hunt_cy; hunt_slot; hunt_lvl
    PRINT #f, "SITEM " + _TRIM$(solo_item_name)
    PRINT #f, "HMON " + _TRIM$(hunt_mon)
    CLOSE #f
END SUB


' Read dungeon-save.dat, rebuild the identical dungeon from its seed, then overlay
' the saved state. One sequential pass -- the token cursor is untouched by the
' board rebuild, so SD/DB/ROOMS are read AFTER StartBoard/RandomizeRooms.
' Assumes the caller (PlayGame) enters the loop afterwards.
SUB LoadGameApply
    DIM i AS INTEGER, rn AS INTEGER, el AS DOUBLE, tag AS STRING, nm AS STRING, sver AS INTEGER
    DIM scx AS INTEGER, scy AS INTEGER, spx AS INTEGER, spy AS INTEGER

    TokLoad "gameplay-data-saves/dungeon-save.dat"
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
    IF sver >= 3 THEN item_shield = NextI            ' shield is its own slot as of v3 (old saves had it folded into item_armor)
    IF sver >= 4 THEN spell_fire = NextI: spell_bolt = NextI  ' Wizard spell charges (v4)
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

    ' solo challenge state (optional -- old saves lack it, so tag-guard). Default: no solo.
    solo_on = FALSE
    IF SVTOK_I <= SVTOK_N THEN
        IF SVTOK(SVTOK_I) = "SOLO" THEN
            tag = NextTok$                            ' "SOLO"
            solo_on = NextI: opt_solomode = NextI: opt_solomins = NextI
            solo_item_room = NextI: solo_item_lvl = NextI: solo_found = NextI
            hunt_on = NextI: hunt_cx = NextI: hunt_cy = NextI: hunt_slot = NextI: hunt_lvl = NextI
            ' SITEM whole-line (quest treasure name -- may contain spaces), read until HMON
            IF SVTOK_I <= SVTOK_N THEN
                IF SVTOK(SVTOK_I) = "SITEM" THEN
                    tag = NextTok$: nm = ""
                    DO
                        IF SVTOK_I > SVTOK_N THEN EXIT DO
                        IF SVTOK(SVTOK_I) = "HMON" THEN EXIT DO
                        IF nm = "" THEN nm = SVTOK(SVTOK_I) ELSE nm = nm + " " + SVTOK(SVTOK_I)
                        SVTOK_I = SVTOK_I + 1
                    LOOP
                    solo_item_name = nm
                END IF
            END IF
            ' HMON whole-line (hunter monster name), read to end
            IF SVTOK_I <= SVTOK_N THEN
                IF SVTOK(SVTOK_I) = "HMON" THEN
                    tag = NextTok$: nm = ""
                    DO
                        IF SVTOK_I > SVTOK_N THEN EXIT DO
                        IF nm = "" THEN nm = SVTOK(SVTOK_I) ELSE nm = nm + " " + SVTOK(SVTOK_I)
                        SVTOK_I = SVTOK_I + 1
                    LOOP
                    hunt_mon = nm
                END IF
            END IF
            solo_result = 0                           ' a fresh continue never starts already-lost
            hunt_lastmoves = moves_made               ' the hunter doesn't jump on the first post-load frame
        END IF
    END IF

    game_start = TIMER - el                          ' restore the elapsed run timer
    IF game_start > TIMER THEN game_start = TIMER
END SUB
