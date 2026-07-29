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
'  Scope: solo AND hot-seat (v5 adds the PLRS seat block). [G] saves in-game; a save is
'  offered on entering. Old saves still load -- every block added since v2 is tag-guarded
'  or version-gated, so v2..v4 files read back fine.
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
    OPEN SAVE_FILE FOR OUTPUT AS #f
    PRINT #f, "DUNGEONSAVE 5"
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
    ' HOT-SEAT SEATS (v5): every parked player, so a multiplayer game can be resumed.
    ' The ACTIVE player's state IS the working globals, and PLAYERS(cur_player) is only
    ' refreshed on a turn change -- so sync it here or the current player's seat saves stale.
    ' Names are written with spaces encoded as CHR$(1): the loader splits on whitespace, so a
    ' name like "Grognard the Fast" would otherwise become three tokens and desync the stream.
    ' PromptName$ only accepts ASCII 32..126, so CHR$(1) can never occur in a real name.
    ' This block sits BEFORE the SOLO block on purpose -- SOLO's trailing HMON field reads to
    ' the end of the stream, so anything appended after it would be swallowed.
    SaveActivePlayer cur_player
    PRINT #f, "PLRS "; num_players
    FOR i = 1 TO num_players
        PRINT #f, PLAYERS(i).active; PLAYERS(i).klass; PLAYERS(i).gold; PLAYERS(i).goal; PLAYERS(i).has_key;
        PRINT #f, PLAYERS(i).sword; PLAYERS(i).secret_card; PLAYERS(i).esp; PLAYERS(i).crystal;
        PRINT #f, PLAYERS(i).hp; PLAYERS(i).maxhp;
        PRINT #f, PLAYERS(i).sstr; PLAYERS(i).sint; PLAYERS(i).swis; PLAYERS(i).sdex; PLAYERS(i).scon; PLAYERS(i).scha;
        PRINT #f, PLAYERS(i).tohit; PLAYERS(i).ac; PLAYERS(i).dmgdie; PLAYERS(i).dmgbonus;
        PRINT #f, PLAYERS(i).cx; PLAYERS(i).cy; PLAYERS(i).kolor;
        PRINT #f, " " + StrSubst$(_TRIM$(PLAYERS(i).name), " ", CHR$(1))
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

    TokLoad SAVE_FILE
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

    ' HOT-SEAT SEATS (v5, tag-guarded -- v4 and older saves have no PLRS block and skip this).
    ' Read before SOLO, matching the write order. Names come back with CHR$(1) -> space.
    IF SVTOK_I <= SVTOK_N THEN
        IF SVTOK(SVTOK_I) = "PLRS" THEN
            tag = NextTok$                            ' "PLRS"
            rn = NextI                                ' saved seat count
            IF rn > UBOUND(PLAYERS) THEN rn = UBOUND(PLAYERS)
            FOR i = 1 TO rn
                PLAYERS(i).active = NextI: PLAYERS(i).klass = NextI
                PLAYERS(i).gold = NextL: PLAYERS(i).goal = NextL: PLAYERS(i).has_key = NextI
                PLAYERS(i).sword = NextI: PLAYERS(i).secret_card = NextI
                PLAYERS(i).esp = NextI: PLAYERS(i).crystal = NextI
                PLAYERS(i).hp = NextI: PLAYERS(i).maxhp = NextI
                PLAYERS(i).sstr = NextI: PLAYERS(i).sint = NextI: PLAYERS(i).swis = NextI
                PLAYERS(i).sdex = NextI: PLAYERS(i).scon = NextI: PLAYERS(i).scha = NextI
                PLAYERS(i).tohit = NextI: PLAYERS(i).ac = NextI
                PLAYERS(i).dmgdie = NextI: PLAYERS(i).dmgbonus = NextI
                PLAYERS(i).cx = NextI: PLAYERS(i).cy = NextI: PLAYERS(i).kolor = NextL
                PLAYERS(i).name = StrSubst$(NextTok$, CHR$(1), " ")
            NEXT i
            ' The working globals were already restored above for the ACTIVE seat, and
            ' SaveGame synced that seat before writing -- so the two agree and we must NOT
            ' call LoadActivePlayer here (the globals carry fields PLAYER has no room for:
            ' char_level/xp, potions, spells, status timers).
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


' ============================================================================
'  `dungeon.run savetest` -- full save/load ROUND-TRIP check, headless.
'
'  The save stream is POSITIONAL: every reader must consume exactly what the writer
'  wrote, or the rest of the file shifts by one and loads garbage. That has already
'  bitten once for real -- a v2 field whose STR$ had no leading space desynced the
'  stream and leaked save data into the champion's name. So the format deserves a
'  regression test, and the hot-seat PLRS block (v5) doubly so: it carries player
'  NAMES, which contain spaces the tokeniser would otherwise split.
'
'  Runs against SAVE_FILE pointed at a scratch path, so the player's real save is
'  never touched. Prints PASS/FAIL per field group and SYSTEMs 0/1.
' ============================================================================
SUB SaveRoundTripTest
    DIM i AS INTEGER, bad AS INTEGER, realpath AS STRING
    DIM wgold(1 TO 4) AS LONG, wname(1 TO 4) AS STRING, wklass(1 TO 4) AS INTEGER
    DIM whp(1 TO 4) AS INTEGER, wcx(1 TO 4) AS INTEGER, wkey(1 TO 4) AS INTEGER
    _DEST _CONSOLE
    PRINT "savetest: save/load round-trip (hot-seat PLRS block, save v5)"

    realpath = SAVE_FILE
    SAVE_FILE = "tests/tmp/savetest.dat"          ' never touch the player's real slot
    IF _DIREXISTS("tests/tmp") = 0 THEN MKDIR "tests/tmp"

    '--- build a synthetic 4-player run -------------------------------------
    num_players = 4: cur_player = 3
    run_seed = 123456789
    RANDOMIZE run_seed
    StartBoard
    RandomizeRooms
    FOR i = 1 TO 4
        wklass(i) = ((i - 1) MOD 4) + 1
        wgold(i) = 1000& * i + 7
        whp(i) = 10 + i
        wcx(i) = (40 + i * 3) * CW
        wkey(i) = (i MOD 2) * -1
        ' names WITH SPACES -- the case that desyncs a whitespace-tokenised stream
        wname(i) = "Player" + _TRIM$(STR$(i)) + " the Bold"
        PLAYERS(i).active = -1: PLAYERS(i).klass = wklass(i)
        PLAYERS(i).gold = wgold(i): PLAYERS(i).goal = 10000
        PLAYERS(i).has_key = wkey(i)
        PLAYERS(i).sword = i: PLAYERS(i).secret_card = 0: PLAYERS(i).esp = 0: PLAYERS(i).crystal = 0
        PLAYERS(i).hp = whp(i): PLAYERS(i).maxhp = 20 + i
        PLAYERS(i).sstr = 10 + i: PLAYERS(i).sint = 11: PLAYERS(i).swis = 12
        PLAYERS(i).sdex = 13: PLAYERS(i).scon = 14: PLAYERS(i).scha = 15
        PLAYERS(i).tohit = i: PLAYERS(i).ac = 10 + i
        PLAYERS(i).dmgdie = 6: PLAYERS(i).dmgbonus = i
        PLAYERS(i).cx = wcx(i): PLAYERS(i).cy = 24 * CH
        PLAYERS(i).kolor = PlayerColor~&(i)
        PLAYERS(i).name = wname(i)
    NEXT i
    ' the ACTIVE seat lives in the working globals -- SaveGame must sync it before writing
    LoadActivePlayer cur_player
    gold = wgold(cur_player)                      ' prove the sync path: mutate AFTER loading
    wgold(cur_player) = gold

    SaveGame
    _DEST _CONSOLE                                ' StartBoard/SaveGame retarget _DEST to CANVAS --
    '                                               without this every PRINT below draws on the
    '                                               board instead of the terminal (silent test)
    PRINT "  wrote " + SAVE_FILE + " (" + _TRIM$(STR$(LEN(_READFILE$(SAVE_FILE)))) + " bytes)"

    '--- clobber every seat, then load it back ------------------------------
    FOR i = 1 TO 4
        PLAYERS(i).active = 0: PLAYERS(i).klass = 0: PLAYERS(i).gold = 0
        PLAYERS(i).hp = 0: PLAYERS(i).cx = 0: PLAYERS(i).has_key = 0: PLAYERS(i).name = "WIPED"
    NEXT i
    num_players = 1: cur_player = 1
    LoadGameApply
    _DEST _CONSOLE                                ' LoadGameApply rebuilds the board -> _DEST moved again

    '--- compare -------------------------------------------------------------
    IF num_players <> 4 THEN PRINT "  FAIL num_players: got " + _TRIM$(STR$(num_players)) + " want 4": bad = -1
    IF cur_player <> 3 THEN PRINT "  FAIL cur_player: got " + _TRIM$(STR$(cur_player)) + " want 3": bad = -1
    FOR i = 1 TO 4
        IF PLAYERS(i).klass <> wklass(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " klass": bad = -1
        IF PLAYERS(i).gold <> wgold(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " gold: got " + _TRIM$(STR$(PLAYERS(i).gold)) + " want " + _TRIM$(STR$(wgold(i))): bad = -1
        IF PLAYERS(i).hp <> whp(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " hp": bad = -1
        IF PLAYERS(i).cx <> wcx(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " cx": bad = -1
        IF PLAYERS(i).has_key <> wkey(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " has_key": bad = -1
        IF _TRIM$(PLAYERS(i).name) <> wname(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " name: got [" + _TRIM$(PLAYERS(i).name) + "] want [" + wname(i) + "]": bad = -1
    NEXT i
    IF NOT bad THEN PRINT "  all 4 seats round-tripped (incl. names with spaces)"

    T_KillSave                                    ' tidy the scratch file

    '--- phase 2: BACKWARD COMPATIBILITY against the player's real save ------
    ' Every format bump risks orphaning an existing save. This copies the real slot to
    ' a scratch file and loads THAT -- read-only on the original, so a failure here can
    ' never cost the player their run. Silently skipped when there is no save.
    DIM raw AS STRING, cf AS INTEGER, ver AS STRING
    IF _FILEEXISTS(realpath) THEN
        raw = _READFILE$(realpath)
        SAVE_FILE = "tests/tmp/compat.dat"
        cf = FREEFILE: OPEN SAVE_FILE FOR OUTPUT AS #cf: PRINT #cf, raw;: CLOSE #cf
        ver = LEFT$(raw, INSTR(raw, CHR$(10)) - 1)
        _DEST _CONSOLE
        PRINT "  compat: loading the real save (" + _TRIM$(ver) + ") from a copy"
        LoadGameApply
        _DEST _CONSOLE
        IF num_players >= 1 AND player_class >= 1 AND player_class <= 4 AND player_maxhp > 0 THEN
            PRINT "    loaded OK -- players " + _TRIM$(STR$(num_players)) + ", class " + _TRIM$(STR$(player_class)) + ", hp " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + ", gold " + _TRIM$(STR$(gold))
        ELSE
            PRINT "    FAIL -- implausible values after load (format regression?)"
            bad = -1
        END IF
        T_KillSave
    ELSE
        _DEST _CONSOLE
        PRINT "  compat: no existing save to check (skipped)"
    END IF

    SAVE_FILE = realpath
    IF bad THEN PRINT "savetest: FAIL": SYSTEM 1
    PRINT "savetest: PASS": SYSTEM 0
END SUB

' Remove the scratch save (KILL on a missing file is a runtime error).
SUB T_KillSave
    IF _FILEEXISTS(SAVE_FILE) THEN KILL SAVE_FILE
END SUB
