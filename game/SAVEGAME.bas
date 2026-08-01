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
'  Scope: solo AND hot-seat. v5 added the PLRS seat block; v6 added the rest of each seat's
'  kit (potions/spells/XP/status), which had been shared globals. [G] saves in-game; a save is
'  offered on entering. Old saves still load -- every block added since v2 is tag-guarded or
'  version-gated, so v2..v5 files read back fine (a pre-v6 file has no per-seat kit, so the
'  active seat is re-synced FROM the globals after load).
' ============================================================================

' [G] in-game: save + a brief confirmation, then back to the board.
SUB SaveAndToast
    SaveGame
    Sfx "key"
    Banner "-- GAME SAVED --", "Choose CONTINUE next time you enter the dungeon.   [ press any key ]"
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' Write the whole run to dungeon-save.dat.
SUB SaveGame
    DIM f AS INTEGER, i AS INTEGER, s AS STRING, el AS DOUBLE
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    f = FREEFILE
    OPEN SAVE_FILE FOR OUTPUT AS #f
    PRINT #f, "DUNGEONSAVE 8"
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
        ' v8 appends the REST of the dropped kit (armour/shield/bow/boots/scrolls/potions);
        ' before that a death destroyed them outright so there was nothing to store.
        PRINT #f, ROOMS(i).malive; ROOMS(i).mhp_now; ROOMS(i).looted; ROOMS(i).monster_fought; ROOMS(i).player_died; ROOMS(i).seen; ROOMS(i).drop_gold; ROOMS(i).drop_sword; ROOMS(i).drop_secret; ROOMS(i).drop_esp; ROOMS(i).drop_crystal; ROOMS(i).mhp;
        PRINT #f, ROOMS(i).drop_armor; ROOMS(i).drop_shield; ROOMS(i).drop_bow; ROOMS(i).drop_boots; ROOMS(i).drop_teleport; ROOMS(i).drop_pot_sm; ROOMS(i).drop_pot_lg
    NEXT i
    ' loose drops -- spoils left where a fall happened on the open paths
    PRINT #f, "LOOSE "; UBOUND(LOOSE)
    FOR i = 1 TO UBOUND(LOOSE)
        PRINT #f, LOOSE(i).active; LOOSE(i).cx; LOOSE(i).cy; LOOSE(i).gold; LOOSE(i).sword; LOOSE(i).secret; LOOSE(i).esp; LOOSE(i).crystal;
        PRINT #f, LOOSE(i).armor; LOOSE(i).shield; LOOSE(i).bow; LOOSE(i).boots; LOOSE(i).teleport; LOOSE(i).pot_sm; LOOSE(i).pot_lg
    NEXT i
    ' CHAMBER progress (v7). CHM_DEAD was never saved at all, so loading a game reset every
    ' named hall to zero graves and you had to re-fight all three guardians -- and the
    ' headstones DrawChamberGraves paints vanished with it. CHM_EVDONE rides along so a
    ' chamber's one special event cannot be re-farmed across a save/load either.
    PRINT #f, "CHM "; NCHAMBER
    FOR i = 1 TO NCHAMBER
        PRINT #f, CHM_DEAD(i); CHM_EVDONE(i); CHM_SEEN(i);      ' v8 adds CHM_SEEN (arrival crawl already played)
    NEXT i
    PRINT #f, ""

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
        ' v6: the rest of the seat's kit (was shared between hot-seat players before)
        PRINT #f, PLAYERS(i).armor; PLAYERS(i).shield; PLAYERS(i).bow; PLAYERS(i).boots; PLAYERS(i).teleport;
        PRINT #f, PLAYERS(i).pot_sm; PLAYERS(i).pot_lg; PLAYERS(i).sp_fire; PLAYERS(i).sp_bolt;
        PRINT #f, PLAYERS(i).clevel; PLAYERS(i).cxp;
        PRINT #f, PLAYERS(i).t_poison; PLAYERS(i).t_fire; PLAYERS(i).t_frost; PLAYERS(i).t_siren;
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
        ' v8+: the rest of the dropped kit. A v7 file simply has none of it, and the fields are
        ' already zero -- so an older save loads with a gold-and-cards hoard, exactly what it stored.
        IF sver >= 8 THEN
            ROOMS(i).drop_armor = NextI: ROOMS(i).drop_shield = NextI
            ROOMS(i).drop_bow = NextI: ROOMS(i).drop_boots = NextI
            ROOMS(i).drop_teleport = NextI: ROOMS(i).drop_pot_sm = NextI: ROOMS(i).drop_pot_lg = NextI
        END IF
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
                IF sver >= 8 THEN                          ' v8: the rest of the fallen kit
                    LOOSE(i).armor = NextI: LOOSE(i).shield = NextI: LOOSE(i).bow = NextI: LOOSE(i).boots = NextI
                    LOOSE(i).teleport = NextI: LOOSE(i).pot_sm = NextI: LOOSE(i).pot_lg = NextI
                END IF
            NEXT i
        END IF
    END IF

    ' CHAMBER progress (v7, tag-guarded -- v6 and older have no CHM block and keep 0 graves,
    ' which is the same state they saved, so nothing is lost that was ever stored).
    IF SVTOK_I <= SVTOK_N THEN
        IF SVTOK(SVTOK_I) = "CHM" THEN
            tag = NextTok$                            ' "CHM"
            rn = NextI                                ' saved chamber count
            IF rn > MAXCHAMBER THEN rn = MAXCHAMBER
            FOR i = 1 TO rn
                CHM_DEAD(i) = NextI: CHM_EVDONE(i) = NextI
                ' v8: whether the hall's arrival crawl has played. A v7 file has no such token,
                ' so seed it from CHM_DEAD -- a hall with graves has obviously been entered, and
                ' one without has not, which is the best reconstruction the older format allows.
                IF sver >= 8 THEN
                    CHM_SEEN(i) = NextI
                ELSE
                    CHM_SEEN(i) = (CHM_DEAD(i) > 0)
                END IF
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
                IF sver >= 6 THEN                    ' v6 added the rest of the seat's kit
                    PLAYERS(i).armor = NextI: PLAYERS(i).shield = NextI
                    PLAYERS(i).bow = NextI: PLAYERS(i).boots = NextI: PLAYERS(i).teleport = NextI
                    PLAYERS(i).pot_sm = NextI: PLAYERS(i).pot_lg = NextI
                    PLAYERS(i).sp_fire = NextI: PLAYERS(i).sp_bolt = NextI
                    PLAYERS(i).clevel = NextI: PLAYERS(i).cxp = NextL
                    PLAYERS(i).t_poison = NextI: PLAYERS(i).t_fire = NextI
                    PLAYERS(i).t_frost = NextI: PLAYERS(i).t_siren = NextI
                END IF
                PLAYERS(i).name = StrSubst$(NextTok$, CHR$(1), " ")
            NEXT i
            ' The working globals were already restored above for the ACTIVE seat, so do NOT
            ' call LoadActivePlayer here -- for a PRE-v6 save the seat's kit fields are absent
            ' (they read as 0) while the globals hold the real values, and loading the seat
            ' would silently wipe that player's potions/spells/XP. Sync the other way instead:
            ' push the authoritative globals INTO the active seat. For v6 the two already
            ' agree (SaveGame synced before writing), so this is a harmless no-op.
            SaveActivePlayer cur_player
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
    DIM wpot(1 TO 4) AS INTEGER, wfire(1 TO 4) AS INTEGER, wxp(1 TO 4) AS LONG
    DIM wpois(1 TO 4) AS INTEGER, wtel(1 TO 4) AS INTEGER
    _DEST _CONSOLE
    PRINT "savetest: hot-seat seat isolation + save/load round-trip (save v8)"

    realpath = SAVE_FILE
    SAVE_FILE = "tests/tmp/savetest.dat"          ' never touch the player's real slot
    IF _DIREXISTS("tests/tmp") = 0 THEN MKDIR "tests/tmp"

    '--- phase 0: SEAT ISOLATION -------------------------------------------------
    ' The actual bug this fixes: the per-seat kit used to be plain globals with no home in
    ' the PLAYER record, so passing the turn did NOT swap potions / spell charges / XP /
    ' status timers -- every hot-seat player shared one inventory. Park and restore two
    ' seats with distinct kit and prove each keeps its own.
    num_players = 2
    PLAYERS(1).klass = 1: PLAYERS(1).maxhp = 20: PLAYERS(1).hp = 20: PLAYERS(1).goal = 10000
    PLAYERS(1).pot_sm = 3: PLAYERS(1).sp_fire = 0: PLAYERS(1).cxp = 100: PLAYERS(1).clevel = 2
    PLAYERS(1).t_poison = 0: PLAYERS(1).teleport = 0: PLAYERS(1).name = "Seat One"
    PLAYERS(2).klass = 4: PLAYERS(2).maxhp = 14: PLAYERS(2).hp = 14: PLAYERS(2).goal = 30000
    PLAYERS(2).pot_sm = 0: PLAYERS(2).sp_fire = 3: PLAYERS(2).cxp = 900: PLAYERS(2).clevel = 5
    PLAYERS(2).t_poison = 4: PLAYERS(2).teleport = 2: PLAYERS(2).name = "Seat Two"

    cur_player = 1: LoadActivePlayer 1
    IF item_potion_small <> 3 THEN PRINT "  FAIL seat1 potions not restored": bad = -1
    IF spell_fire <> 0 THEN PRINT "  FAIL seat1 should have no spells": bad = -1
    IF char_xp <> 100 THEN PRINT "  FAIL seat1 xp": bad = -1

    item_potion_small = 1                         ' seat 1 drinks two potions on its turn
    char_xp = 175
    SaveActivePlayer 1                            ' end of turn: park seat 1

    cur_player = 2: LoadActivePlayer 2
    IF item_potion_small <> 0 THEN PRINT "  FAIL LEAK: seat2 sees seat1's potions (" + _TRIM$(STR$(item_potion_small)) + ")": bad = -1
    IF spell_fire <> 3 THEN PRINT "  FAIL seat2 Wizard spellbook missing": bad = -1
    IF char_xp <> 900 THEN PRINT "  FAIL LEAK: seat2 sees seat1's xp (" + _TRIM$(STR$(char_xp)) + ")": bad = -1
    IF poison_turns <> 4 THEN PRINT "  FAIL seat2 poison timer": bad = -1
    IF item_teleport <> 2 THEN PRINT "  FAIL seat2 teleport charges": bad = -1

    spell_fire = 1                                ' seat 2 casts two Fire Balls
    SaveActivePlayer 2

    cur_player = 1: LoadActivePlayer 1            ' back to seat 1 -- its own state must persist
    IF item_potion_small <> 1 THEN PRINT "  FAIL seat1 potion spend did not persist": bad = -1
    IF char_xp <> 175 THEN PRINT "  FAIL seat1 xp gain did not persist": bad = -1
    IF spell_fire <> 0 THEN PRINT "  FAIL LEAK: seat1 sees seat2's spell charges": bad = -1
    IF poison_turns <> 0 THEN PRINT "  FAIL LEAK: seat1 caught seat2's poison": bad = -1
    IF NOT bad THEN PRINT "  seat isolation OK -- potions/spells/XP/status/teleport swap per seat"
    _DEST _CONSOLE

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
        ' v6 per-seat kit -- DISTINCT per player, which is the whole point: before v6 these
        ' were shared globals, so every seat saw player 1's potions/spells/XP/poison.
        wpot(i) = i: wfire(i) = 5 - i: wxp(i) = 250& * i: wpois(i) = i * 2: wtel(i) = i + 1
        PLAYERS(i).pot_sm = wpot(i): PLAYERS(i).pot_lg = i + 1
        PLAYERS(i).sp_fire = wfire(i): PLAYERS(i).sp_bolt = i
        PLAYERS(i).clevel = i: PLAYERS(i).cxp = wxp(i)
        PLAYERS(i).t_poison = wpois(i): PLAYERS(i).t_fire = 0
        PLAYERS(i).t_frost = 0: PLAYERS(i).t_siren = 0
        PLAYERS(i).armor = i: PLAYERS(i).shield = 1: PLAYERS(i).bow = -1
        PLAYERS(i).boots = 0: PLAYERS(i).teleport = wtel(i)
    NEXT i
    ' chamber progress (v7) -- CHM_DEAD used to be dropped entirely on save.
    ' v8 adds CHM_SEEN (the one-time arrival crawl), which must survive too or every hall
    ' re-introduces itself after a Continue.
    DIM wdead(1 TO 4) AS INTEGER, wev(1 TO 4) AS INTEGER, wseen(1 TO 4) AS INTEGER
    FOR i = 1 TO 4
        IF i <= NCHAMBER THEN
            wdead(i) = i MOD 4: wev(i) = -(i MOD 2): wseen(i) = -((i + 1) MOD 2)
            CHM_DEAD(i) = wdead(i): CHM_EVDONE(i) = wev(i): CHM_SEEN(i) = wseen(i)
        END IF
    NEXT i

    ' v8 DROPPED KIT. The bug this guards: a death used to stash only gold + sword/secret/
    ' esp/crystal while clearing the WHOLE inventory, so armour, shield, bow, boots, teleport
    ' scrolls and potions were destroyed and the hoard you walked back for was a fraction of
    ' what you lost. Seed a room hoard AND a corridor fall with a full kit and prove both
    ' survive the round-trip -- a positional stream drops silently when a field is forgotten.
    IF ROOM_N >= 1 THEN
        ROOMS(1).drop_gold = 4321: ROOMS(1).drop_sword = 2
        ROOMS(1).drop_secret = -1: ROOMS(1).drop_esp = 0: ROOMS(1).drop_crystal = -1
        ROOMS(1).drop_armor = 3: ROOMS(1).drop_shield = 2
        ROOMS(1).drop_bow = -1: ROOMS(1).drop_boots = -1
        ROOMS(1).drop_teleport = 4: ROOMS(1).drop_pot_sm = 5: ROOMS(1).drop_pot_lg = 6
    END IF
    LOOSE(1).active = -1: LOOSE(1).cx = 61: LOOSE(1).cy = 27: LOOSE(1).gold = 999
    LOOSE(1).sword = 1: LOOSE(1).secret = 0: LOOSE(1).esp = -1: LOOSE(1).crystal = 0
    LOOSE(1).armor = 1: LOOSE(1).shield = 2: LOOSE(1).bow = 0: LOOSE(1).boots = -1
    LOOSE(1).teleport = 3: LOOSE(1).pot_sm = 7: LOOSE(1).pot_lg = 8

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
    IF ROOM_N >= 1 THEN ClearRoomDrop 1
    ClearLooseSlot 1
    FOR i = 1 TO 4
        IF i <= NCHAMBER THEN CHM_DEAD(i) = 0: CHM_EVDONE(i) = 0: CHM_SEEN(i) = 0
        PLAYERS(i).active = 0: PLAYERS(i).klass = 0: PLAYERS(i).gold = 0
        PLAYERS(i).hp = 0: PLAYERS(i).cx = 0: PLAYERS(i).has_key = 0: PLAYERS(i).name = "WIPED"
        PLAYERS(i).pot_sm = 0: PLAYERS(i).sp_fire = 0: PLAYERS(i).cxp = 0
        PLAYERS(i).t_poison = 0: PLAYERS(i).teleport = 0: PLAYERS(i).clevel = 0
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
        IF PLAYERS(i).pot_sm <> wpot(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " potions": bad = -1
        IF PLAYERS(i).sp_fire <> wfire(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " fireball charges": bad = -1
        IF PLAYERS(i).cxp <> wxp(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " xp": bad = -1
        IF PLAYERS(i).clevel <> i THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " char level": bad = -1
        IF PLAYERS(i).t_poison <> wpois(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " poison timer": bad = -1
        IF PLAYERS(i).teleport <> wtel(i) THEN PRINT "  FAIL p" + _TRIM$(STR$(i)) + " teleport charges": bad = -1
    NEXT i
    FOR i = 1 TO 4
        IF i <= NCHAMBER THEN
            IF CHM_DEAD(i) <> wdead(i) THEN PRINT "  FAIL chamber " + _TRIM$(STR$(i)) + " graves: got " + _TRIM$(STR$(CHM_DEAD(i))) + " want " + _TRIM$(STR$(wdead(i))): bad = -1
            IF CHM_EVDONE(i) <> wev(i) THEN PRINT "  FAIL chamber " + _TRIM$(STR$(i)) + " event flag": bad = -1
            IF CHM_SEEN(i) <> wseen(i) THEN PRINT "  FAIL chamber " + _TRIM$(STR$(i)) + " arrival-seen flag": bad = -1
        END IF
    NEXT i
    IF NOT bad THEN PRINT "  chamber progress round-tripped (graves + one-shot event + arrival flags)"

    '--- v8: the DROPPED KIT, room hoard and corridor fall ---------------------
    IF ROOM_N >= 1 THEN
        IF ROOMS(1).drop_gold <> 4321 THEN PRINT "  FAIL room drop gold": bad = -1
        IF ROOMS(1).drop_sword <> 2 THEN PRINT "  FAIL room drop sword": bad = -1
        IF ROOMS(1).drop_secret = 0 THEN PRINT "  FAIL room drop secret card": bad = -1
        IF ROOMS(1).drop_crystal = 0 THEN PRINT "  FAIL room drop crystal ball": bad = -1
        IF ROOMS(1).drop_armor <> 3 THEN PRINT "  FAIL room drop armor": bad = -1
        IF ROOMS(1).drop_shield <> 2 THEN PRINT "  FAIL room drop shield": bad = -1
        IF ROOMS(1).drop_bow = 0 THEN PRINT "  FAIL room drop bow": bad = -1
        IF ROOMS(1).drop_boots = 0 THEN PRINT "  FAIL room drop boots": bad = -1
        IF ROOMS(1).drop_teleport <> 4 THEN PRINT "  FAIL room drop teleport": bad = -1
        IF ROOMS(1).drop_pot_sm <> 5 THEN PRINT "  FAIL room drop small potions": bad = -1
        IF ROOMS(1).drop_pot_lg <> 6 THEN PRINT "  FAIL room drop large potions": bad = -1
        IF NOT HasDrop(1) THEN PRINT "  FAIL HasDrop blind to a restored hoard": bad = -1
    END IF
    IF LOOSE(1).active = 0 THEN PRINT "  FAIL loose drop lost": bad = -1
    IF LOOSE(1).gold <> 999 THEN PRINT "  FAIL loose drop gold": bad = -1
    IF LOOSE(1).armor <> 1 THEN PRINT "  FAIL loose drop armor": bad = -1
    IF LOOSE(1).shield <> 2 THEN PRINT "  FAIL loose drop shield": bad = -1
    IF LOOSE(1).boots = 0 THEN PRINT "  FAIL loose drop boots": bad = -1
    IF LOOSE(1).teleport <> 3 THEN PRINT "  FAIL loose drop teleport": bad = -1
    IF LOOSE(1).pot_sm <> 7 THEN PRINT "  FAIL loose drop small potions": bad = -1
    IF LOOSE(1).pot_lg <> 8 THEN PRINT "  FAIL loose drop large potions": bad = -1
    IF NOT bad THEN PRINT "  dropped kit round-tripped (room hoard + corridor fall: armour/shield/bow/boots/scrolls/potions)"
    IF NOT bad THEN PRINT "  all 4 seats round-tripped (names with spaces + per-seat kit: potions/spells/XP/status)"

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
