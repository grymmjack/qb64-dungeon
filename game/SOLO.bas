' ============================================================================
'  SOLO PLAY MODES  (single-player variants, straight from the DUNGEON! manual)
'    1 Time Limit  -- win before the clock runs out (30/25/20/15 min)
'    2 Item Search -- find a certain deep treasure; two deaths and you're out
'    3 Monster Prey-- a 6th-level monster hunts you (one step per your step,
'                     shortest path, uses even secret doors); win before it
'                     catches you, or turn and kill it (a fresh one then rises)
'  All three are single-player only (num_players = 1). SoloTick runs every frame
'  from the play loop; it may set solo_result = OUT_WIN / OUT_LOSE.
' ============================================================================

' Clear all solo state -- called at the very top of a run so nothing leaks between games.
SUB SoloReset
    solo_on = FALSE: solo_result = 0: solo_msg = ""
    solo_deaths = 0: solo_found = FALSE
    solo_item_room = 0: solo_item_name = "": solo_item_lvl = 0
    hunt_on = FALSE: hunt_lastmoves = -1
    hunt_cx = 0: hunt_cy = 0: hunt_mon = "": hunt_slot = 0: hunt_lvl = 6
END SUB

' Activate whichever solo mode is set, for a fresh single-player run. Called once at
' game start after the board + rooms are built (and after the intro narration).
SUB SoloBegin
    SoloReset
    IF num_players <> 1 THEN EXIT SUB          ' solo modes are single-player only
    IF opt_solomode <= 0 THEN EXIT SUB
    solo_on = TRUE
    SELECT CASE opt_solomode
        CASE SOLO_TIME
            Banner "SOLO CHALLENGE: RACE THE CLOCK", "Reach the entrance with the Key and " + _TRIM$(STR$(target_gold)) + " gold within " + _TRIM$(STR$(opt_solomins)) + " minutes!   [ press any key ]"
            WaitKey
        CASE SOLO_ITEM
            SoloPickQuest
            IF solo_item_room > 0 THEN
                Banner "SOLO CHALLENGE: TREASURE HUNT", "Seek the " + _TRIM$(solo_item_name) + " on the " + Ordinal$(solo_item_lvl) + " level. Two deaths and the hunt is over.   [ press any key ]"
            ELSE
                Banner "SOLO CHALLENGE: TREASURE HUNT", "Find a great treasure in the deep levels. Two deaths and the hunt is over.   [ press any key ]"
            END IF
            WaitKey
        CASE SOLO_PREY
            HunterSpawn
            IF hunt_on THEN
                Banner "SOLO CHALLENGE: THE HUNT", "A " + hunt_mon + " stalks you from the depths! Escape with the win before it runs you down -- it uses even secret doors.   [ press any key ]"
                WaitKey
            END IF
    END SELECT
END SUB

' Item Search: designate the deepest, richest plain-gold hoard as the quest treasure.
SUB SoloPickQuest
    DIM r AS INTEGER, best AS INTEGER, lv AS INTEGER
    DIM bestg AS LONG
    best = 0: bestg = -1
    FOR lv = 9 TO 5 STEP -1                     ' prefer the deepest levels that exist
        FOR r = 1 TO ROOM_N
            IF ROOMS(r).sec = lv THEN
                IF ROOMS(r).treasure_item = 0 AND NOT ROOMS(r).is_boss THEN
                    IF ROOMS(r).treasure > bestg THEN best = r: bestg = ROOMS(r).treasure
                END IF
            END IF
        NEXT r
        IF best > 0 THEN EXIT FOR
    NEXT lv
    IF best > 0 THEN
        solo_item_room = best
        solo_item_name = _TRIM$(ROOMS(best).treasure_name)
        solo_item_lvl = ROOMS(best).sec
    END IF
END SUB

' Place (or replace) the pursuing monster in a room on level 6 (fallback: any deeper level).
SUB HunterSpawn
    DIM r AS INTEGER, pick AS INTEGER, cnt AS INTEGER, lv AS INTEGER, want AS INTEGER
    pick = 0: hunt_lvl = 6
    FOR lv = 6 TO 9
        cnt = 0
        FOR r = 1 TO ROOM_N
            IF ROOMS(r).sec = lv THEN cnt = cnt + 1
        NEXT r
        IF cnt > 0 THEN
            want = RollDie(cnt): cnt = 0
            FOR r = 1 TO ROOM_N
                IF ROOMS(r).sec = lv THEN
                    cnt = cnt + 1
                    IF cnt = want THEN pick = r: EXIT FOR
                END IF
            NEXT r
        END IF
        IF pick > 0 THEN hunt_lvl = lv: EXIT FOR
    NEXT lv
    IF pick = 0 THEN EXIT SUB
    hunt_cx = EntityDrawX(pick): hunt_cy = EntityDrawY(pick)
    hunt_slot = RollDie(3)
    hunt_mon = _TRIM$(MON_NAME(hunt_lvl, hunt_slot))
    hunt_lastmoves = moves_made
    hunt_on = TRUE
END SUB

' Advance the hunter ONE cell toward the player along a BFS shortest path (secret doors
' passable, no corner cutting). Only steps once per player move. Returns TRUE if it lands
' on the player (caught).
FUNCTION HunterAdvance%
    HunterAdvance = 0
    IF NOT hunt_on THEN EXIT FUNCTION
    IF moves_made = hunt_lastmoves THEN EXIT FUNCTION   ' one hunter step per player step
    hunt_lastmoves = moves_made

    DIM px AS INTEGER, py AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM hd AS INTEGER, tl AS INTEGER, cxx AS INTEGER, cyy AS INTEGER, nx AS INTEGER, ny AS INTEGER, d AS INTEGER
    DIM bx AS INTEGER, by AS INTEGER, bd AS INTEGER, k AS INTEGER, okmove AS INTEGER
    DIM oldsrc AS LONG
    DIM dx8(0 TO 7) AS INTEGER, dy8(0 TO 7) AS INTEGER
    dx8(0) = 1: dx8(1) = -1: dx8(2) = 0: dx8(3) = 0: dx8(4) = 1: dx8(5) = 1: dx8(6) = -1: dx8(7) = -1
    dy8(0) = 0: dy8(1) = 0: dy8(2) = 1: dy8(3) = -1: dy8(4) = 1: dy8(5) = -1: dy8(6) = 1: dy8(7) = -1
    REDIM hqx(0 TO 8192) AS INTEGER, hqy(0 TO 8192) AS INTEGER   ' local BFS queue (NOT the shared static QX/QY -> avoids "Duplicate definition")

    px = c.x \ CW: py = c.y \ CH
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE          ' path over the PRISTINE collision board -> secret doors are passable
    FOR y = 0 TO 60: FOR x = 0 TO 131: HDIST(x, y) = -1: NEXT: NEXT
    HDIST(px, py) = 0: hqx(0) = px: hqy(0) = py: hd = 0: tl = 1
    DO WHILE hd < tl
        cxx = hqx(hd): cyy = hqy(hd): hd = hd + 1
        FOR d = 0 TO 3                              ' 4-way flood builds the distance field
            nx = cxx + dx8(d): ny = cyy + dy8(d)
            IF nx >= 0 AND nx <= 131 AND ny >= 0 AND ny <= 60 THEN
                IF HDIST(nx, ny) = -1 THEN
                    IF CellKind(nx, ny) >= 1 THEN
                        HDIST(nx, ny) = HDIST(cxx, cyy) + 1
                        IF tl <= 8191 THEN hqx(tl) = nx: hqy(tl) = ny: tl = tl + 1
                    END IF
                END IF
            END IF
        NEXT d
    LOOP

    ' step to the 8-neighbour with the smallest distance (diagonals need both orthogonals open)
    bd = HDIST(hunt_cx, hunt_cy): IF bd < 0 THEN bd = 999999
    bx = hunt_cx: by = hunt_cy
    FOR k = 0 TO 7
        nx = hunt_cx + dx8(k): ny = hunt_cy + dy8(k)
        IF nx >= 0 AND nx <= 131 AND ny >= 0 AND ny <= 60 THEN
            IF HDIST(nx, ny) >= 0 THEN
                okmove = -1
                IF dx8(k) <> 0 AND dy8(k) <> 0 THEN
                    IF CellKind(hunt_cx + dx8(k), hunt_cy) < 1 THEN okmove = 0
                    IF CellKind(hunt_cx, hunt_cy + dy8(k)) < 1 THEN okmove = 0
                END IF
                IF okmove THEN
                    IF HDIST(nx, ny) < bd THEN bd = HDIST(nx, ny): bx = nx: by = ny
                END IF
            END IF
        END IF
    NEXT k
    _SOURCE oldsrc
    hunt_cx = bx: hunt_cy = by
    IF hunt_cx = px AND hunt_cy = py THEN HunterAdvance = -1   ' caught the adventurer
END FUNCTION

' The player has stepped onto the hunter -- fight it. Kill it and a fresh hunter rises;
' fail to fell it and you give ground (bounce back a cell).
SUB HunterFight
    DIM w AS INTEGER, res AS INTEGER
    IF NOT hunt_on THEN EXIT SUB
    w = ROOM_N + 3: IF w > 400 THEN w = 400        ' scratch slot (chamber=+2, wander=+1)
    ROOMS(w).sec = hunt_lvl: ROOMS(w).monster = hunt_mon: ROOMS(w).mslot = hunt_slot
    ROOMS(w).malive = TRUE: ROOMS(w).is_boss = FALSE
    ROOMS(w).monster_fought = FALSE: ROOMS(w).player_died = FALSE: ROOMS(w).looted = FALSE
    ROOMS(w).mhp = hunt_lvl * 4 + RollDie(hunt_lvl * 2 + 4): ROOMS(w).mhp_now = ROOMS(w).mhp
    ROOMS(w).mac = 9 + hunt_lvl
    ROOMS(w).treasure = 0: ROOMS(w).treasure_item = 0: ROOMS(w).treasure_name = ""
    ClearRoomDrop w                                      ' scratch slot: no inherited stash
    ROOMS(w).is_chamber = TRUE                      ' the hunter guards no treasure
    Sfx "trap"
    Banner "You turn on the pursuing " + hunt_mon + "!", "Strike it down, or it will run you down.   [ press any key ]"
    WaitKey
    res = DoCombat(w)
    IF NOT ROOMS(w).malive THEN
        hunt_on = FALSE
        Sfx "levelup"
        Banner "The pursuing " + hunt_mon + " falls!", "...but you hear another stir in the depths.   [ press any key ]"
        WaitKey
        HunterSpawn                                 ' a fresh hunter from level 6
    ELSE
        c.x = c.prev_x: c.y = c.prev_y              ' failed to fell it -- fall back a step
        cursor_erase: cursor_draw: Present
    END IF
END SUB

' Runs every frame from the play loop. Checks the timer / death count / hunter and sets
' solo_result when the run is decided.
SUB SoloTick
    IF NOT solo_on THEN EXIT SUB
    IF solo_result <> 0 THEN EXIT SUB
    DIM px AS INTEGER, py AS INTEGER, el AS LONG
    px = c.x \ CW: py = c.y \ CH
    SELECT CASE opt_solomode
        CASE SOLO_TIME
            el = TIMER - game_start: IF el < 0 THEN el = el + 86400
            IF el >= opt_solomins * 60 THEN
                solo_result = OUT_LOSE
                solo_msg = "Time's up -- the dungeon keeps another too-slow adventurer."
            END IF
        CASE SOLO_ITEM
            IF deaths(1) >= 2 THEN
                solo_result = OUT_LOSE
                solo_msg = "Fallen twice -- your treasure hunt ends in the dark."
            END IF
        CASE SOLO_PREY
            IF hunt_on THEN
                IF px = hunt_cx AND py = hunt_cy THEN
                    HunterFight
                ELSE
                    IF HunterAdvance THEN
                        solo_result = OUT_LOSE
                        solo_msg = "The " + hunt_mon + " runs you down. There is no escape from the hunt."
                    END IF
                END IF
            END IF
    END SELECT
END SUB

' The pursuing monster token (Monster Prey). Drawn from cursor_draw, after the entities.
SUB DrawHunter
    IF NOT solo_on OR opt_solomode <> SOLO_PREY OR NOT hunt_on THEN EXIT SUB
    IF VIS(hunt_cx, hunt_cy) AND (NOT FovOn% OR LOS_SEEN(hunt_cx, hunt_cy)) THEN
        DIM px AS INTEGER, py AS INTEGER
        _DEST CANVAS
        px = hunt_cx * CW: py = hunt_cy * CH
        LINE (px, py)-(px + CW - 1, py + CH - 1), _RGB32(&H50, &H00, &H00), BF
        LINE (px + 1, py + 1)-(px + CW - 2, py + CH - 2), _RGB32(&HD0, &H20, &H20), BF
        COLOR _RGB32(&HFF, &HF0, &H30), _RGB32(&HD0, &H20, &H20)
        _PRINTSTRING (px, py), CHR$(21)             ' the section-sign monster glyph, in alarm red
        COLOR WHITE, BLACK
    END IF
END SUB

' Solo status ribbon across the top of the board (timer / quest / hunter distance).
SUB DrawSoloHUD
    IF NOT solo_on THEN EXIT SUB
    DIM s AS STRING, el AS LONG, remsec AS LONG, dcell AS INTEGER
    DIM fg AS _UNSIGNED LONG, bg AS _UNSIGNED LONG
    fg = _RGB32(&HFF, &HE0, &H50): bg = _RGB32(&H14, &H00, &H14)
    SELECT CASE opt_solomode
        CASE SOLO_TIME
            el = TIMER - game_start: IF el < 0 THEN el = el + 86400
            remsec = opt_solomins * 60 - el: IF remsec < 0 THEN remsec = 0
            s = "SOLO * TIME LEFT " + _TRIM$(STR$(remsec \ 60)) + ":" + RIGHT$("0" + _TRIM$(STR$(remsec MOD 60)), 2)
            IF remsec <= 60 THEN fg = _RGB32(&HFF, &H50, &H50)
        CASE SOLO_ITEM
            IF solo_item_room > 0 THEN
                s = "SOLO * SEEK: " + _TRIM$(solo_item_name) + " (" + Ordinal$(solo_item_lvl) + " lvl)   DEATHS " + _TRIM$(STR$(deaths(1))) + "/2"
            ELSE
                s = "SOLO * TREASURE HUNT   DEATHS " + _TRIM$(STR$(deaths(1))) + "/2"
            END IF
        CASE SOLO_PREY
            IF hunt_on THEN
                dcell = ABS(hunt_cx - c.x \ CW) + ABS(hunt_cy - c.y \ CH)
                s = "SOLO * HUNTED BY " + hunt_mon + "  (" + _TRIM$(STR$(dcell)) + " cells away)"
                IF dcell <= 4 THEN fg = _RGB32(&HFF, &H50, &H50)
            ELSE
                s = "SOLO * THE HUNT"
            END IF
    END SELECT
    _DEST CANVAS
    LINE (0, 0)-(SW * CW, CH - 1), bg, BF
    COLOR fg, bg
    _PRINTSTRING (CW, 0), s
    COLOR WHITE, BLACK
END SUB
