' ============================================================================
'  CHRONICLE.bas -- per-run stats, a single-line EVENT LOG, and the in-game
'  reference screens reached from the GAME MENU ([M]):
'      Game Summary   Event Log   Bestiary   Treasury   Rules   Character Sheet
'  All counters live in DUNGEON.BI and reset each run via ChronicleReset.
' ============================================================================

' short "trim STR$" helper
FUNCTION EvNum$ (v AS LONG)
    EvNum$ = _TRIM$(STR$(v))
END FUNCTION

' Reset all run stats + the event log, and seed the bestiary with the full roster
' (so monsters you haven't met yet still list, at 0). Call at the start of every run.
SUB ChronicleReset
    DIM i AS INTEGER, lv AS INTEGER, sl AS INTEGER, nm AS STRING, dummy AS INTEGER
    g_rooms_explored = 0: g_monsters_slain = 0: g_treasures_found = 0: start_heals = 0
    g_items_looted = 0: g_levels_completed = 0: g_secrets_found = 0
    g_crits = 0: g_fumbles = 0: g_wander_enc = 0: g_run_deaths = 0
    g_gold_found = 0: EVLOG_N = 0
    BEAST_N = 0
    FOR i = 1 TO MAXBEAST
        BEAST_NAME(i) = "": BEAST_ENC(i) = 0: BEAST_SLAIN(i) = 0: BEAST_FLED(i) = 0
        BEAST_KILLEDBY(i) = 0: BEAST_LOOTED(i) = 0
    NEXT
    FOR lv = 1 TO 9: FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lv, sl))
            IF LEN(nm) > 0 THEN dummy = BeastIdx%(nm)
    NEXT sl: NEXT lv
    TRE_STAT_N = 0
    FOR i = 1 TO MAXTRE: TRE_STATNAME(i) = "": TRE_FOUND(i) = 0: TRE_GP(i) = 0: NEXT
END SUB

' Look up (or register) a monster in the bestiary tally. 0 if the name is blank/full.
FUNCTION BeastIdx% (nm AS STRING)
    DIM i AS INTEGER, t AS STRING
    t = UCASE$(_TRIM$(nm)): IF t = "" THEN BeastIdx% = 0: EXIT FUNCTION
    FOR i = 1 TO BEAST_N
        IF UCASE$(_TRIM$(BEAST_NAME(i))) = t THEN BeastIdx% = i: EXIT FUNCTION
    NEXT
    IF BEAST_N >= MAXBEAST THEN BeastIdx% = 0: EXIT FUNCTION
    BEAST_N = BEAST_N + 1: BEAST_NAME(BEAST_N) = _TRIM$(nm): BeastIdx% = BEAST_N
END FUNCTION

FUNCTION TreIdx% (nm AS STRING)
    DIM i AS INTEGER, t AS STRING
    t = UCASE$(_TRIM$(nm)): IF t = "" THEN TreIdx% = 0: EXIT FUNCTION
    FOR i = 1 TO TRE_STAT_N
        IF UCASE$(_TRIM$(TRE_STATNAME(i))) = t THEN TreIdx% = i: EXIT FUNCTION
    NEXT
    IF TRE_STAT_N >= MAXTRE THEN TreIdx% = 0: EXIT FUNCTION
    TRE_STAT_N = TRE_STAT_N + 1: TRE_STATNAME(TRE_STAT_N) = _TRIM$(nm): TreIdx% = TRE_STAT_N
END FUNCTION

SUB LogEvent (s AS STRING)
    IF EVLOG_N >= MAXEVLOG THEN EXIT SUB
    EVLOG_N = EVLOG_N + 1: EVLOG(EVLOG_N) = s
END SUB

' -------- recording helpers (called from the game at the right moments) --------
SUB RecordEnterRoom
    g_rooms_explored = g_rooms_explored + 1
END SUB

SUB RecordEncounter (mon AS STRING)              ' first face-off with a room's monster
    DIM i AS INTEGER: i = BeastIdx%(mon): IF i > 0 THEN BEAST_ENC(i) = BEAST_ENC(i) + 1
END SUB

SUB RecordKill (lv AS INTEGER, rm AS INTEGER, mon AS STRING, rounds AS INTEGER, gp AS LONG, itm AS STRING)
    DIM i AS INTEGER, s AS STRING
    i = BeastIdx%(mon): IF i > 0 THEN BEAST_SLAIN(i) = BEAST_SLAIN(i) + 1
    g_monsters_slain = g_monsters_slain + 1
    s = _TRIM$(player_name) + " entered L" + EvNum$(lv) + "/R" + EvNum$(rm) + ", slew " + _TRIM$(mon) + " after " + EvNum$(rounds) + " round"
    IF rounds <> 1 THEN s = s + "s"
    IF gp > 0 THEN s = s + " -- found " + EvNum$(gp) + " GP"
    IF LEN(_TRIM$(itm)) > 0 THEN s = s + " + " + _TRIM$(itm)
    LogEvent s
END SUB

SUB RecordFled (mon AS STRING)
    DIM i AS INTEGER: i = BeastIdx%(mon): IF i > 0 THEN BEAST_FLED(i) = BEAST_FLED(i) + 1
    LogEvent _TRIM$(player_name) + " fled from " + _TRIM$(mon)
END SUB

SUB RecordDeath (lv AS INTEGER, rm AS INTEGER, mon AS STRING, rounds AS INTEGER, goldlost AS LONG)
    DIM i AS INTEGER, s AS STRING
    i = BeastIdx%(mon): IF i > 0 THEN BEAST_KILLEDBY(i) = BEAST_KILLEDBY(i) + 1
    g_run_deaths = g_run_deaths + 1
    s = _TRIM$(player_name) + " DIED fighting " + _TRIM$(mon) + " in L" + EvNum$(lv) + "/R" + EvNum$(rm) + " after " + EvNum$(rounds) + " round"
    IF rounds <> 1 THEN s = s + "s"
    IF goldlost > 0 THEN s = s + " -- dropped " + EvNum$(goldlost) + " GP"
    LogEvent s
END SUB

SUB RecordLootRescue (mon AS STRING)
    DIM i AS INTEGER: i = BeastIdx%(mon): IF i > 0 THEN BEAST_LOOTED(i) = BEAST_LOOTED(i) + 1
END SUB

SUB RecordTreasure (nm AS STRING, gp AS LONG)
    DIM i AS INTEGER
    g_treasures_found = g_treasures_found + 1: g_gold_found = g_gold_found + gp
    i = TreIdx%(nm)
    IF i > 0 THEN TRE_FOUND(i) = TRE_FOUND(i) + 1: TRE_GP(i) = gp
END SUB

SUB RecordItem (nm AS STRING)
    g_items_looted = g_items_looted + 1
    LogEvent _TRIM$(player_name) + " looted " + _TRIM$(nm)
END SUB

SUB RecordSecret (lv AS INTEGER, rm AS INTEGER, attempts AS INTEGER)
    g_secrets_found = g_secrets_found + 1
    LogEvent _TRIM$(player_name) + " found a SECRET DOOR in L" + EvNum$(lv) + " near R" + EvNum$(rm) + " after " + EvNum$(attempts) + " attempt(s)"
END SUB

SUB RecordWander (mon AS STRING, lv AS INTEGER)
    ' the BEAST_ENC tally is bumped by RecordEncounter inside DoCombat -- don't double-count here
    g_wander_enc = g_wander_enc + 1
    LogEvent _TRIM$(player_name) + " was ambushed by a wandering " + _TRIM$(mon) + " in L" + EvNum$(lv)
END SUB

SUB RecordCrit (mon AS STRING, dmg AS INTEGER)
    g_crits = g_crits + 1
    combat_crits = combat_crits + 1                ' this fight's tally -> CritPotionReward
    IF dmg > 0 THEN
        LogEvent _TRIM$(player_name) + " CRITICALLY hit " + _TRIM$(mon) + " for " + EvNum$(dmg) + " damage"
    ELSE
        LogEvent _TRIM$(player_name) + " CRITICALLY slew " + _TRIM$(mon) + " in one blow"
    END IF
END SUB

SUB RecordFumble (mon AS STRING, rno AS INTEGER)
    g_fumbles = g_fumbles + 1
    IF rno > 0 THEN
        LogEvent _TRIM$(player_name) + " FUMBLED against " + _TRIM$(mon) + " in round " + EvNum$(rno)
    ELSE
        LogEvent _TRIM$(player_name) + " FUMBLED against " + _TRIM$(mon)
    END IF
END SUB

SUB RecordLevelDone (lv AS INTEGER)
    g_levels_completed = g_levels_completed + 1
    LogEvent _TRIM$(player_name) + " cleared every room on Level " + EvNum$(lv)
END SUB

' A curio / random-event gain: feed the per-player manifest (LogTreasure, as before)
' AND the chronicle Treasury tally + the Event Log, so curio spoils show up in the
' Game Menu screens like combat loot does.
SUB CurioGain (nm AS STRING, g AS LONG)
    LogTreasure nm, g
    RecordTreasure nm, g
    IF g > 0 THEN
        LogEvent _TRIM$(player_name) + " found " + _TRIM$(nm) + " (" + EvNum$(g) + " GP)"
    ELSE
        LogEvent _TRIM$(player_name) + " found " + _TRIM$(nm)
    END IF
END SUB

' A curio appeared (the prop kind, e.g. "fountain"/"chest"); note it in the log.
SUB RecordCurio (nm AS STRING)
    LogEvent _TRIM$(player_name) + " came upon a " + _TRIM$(nm)
END SUB

' A trap sprung -- lv/rm for context, saved TRUE if the save throw succeeded.
SUB RecordTrap (nm AS STRING, saved AS INTEGER)
    IF saved THEN
        LogEvent _TRIM$(player_name) + " evaded a " + _TRIM$(nm)
    ELSE
        LogEvent _TRIM$(player_name) + " was caught by a " + _TRIM$(nm)
    END IF
END SUB

' ---------------------------------------------------------------------------
'  VIEWERS
' ---------------------------------------------------------------------------

' A framed panel helper: fills rows y1..y2 (cols x1..x2) + a centred title.
SUB ChroniclePanel (x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER, title AS STRING)
    _DEST CANVAS
    LINE (x1 * CW, y1 * CH)-(x2 * CW, y2 * CH), BOXBG, BF
    LINE (x1 * CW, y1 * CH)-(x2 * CW, y2 * CH), CYANU, B
    COLOR YELLOWU, BOXBG: PrintCentered y1 + 1, "-=  " + title + "  =-"
END SUB

SUB ChronicleClose
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB

' GAME SUMMARY -- the run at a glance.
SUB ShowGameSummary
    DIM y AS INTEGER, el AS LONG, tmr AS STRING
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    tmr = EvNum$(el \ 60) + "m " + EvNum$(el MOD 60) + "s"
    ChroniclePanel 20, 5, 112, 45, "G A M E   S U M M A R Y"
    y = 9
    COLOR WHITE, BOXBG: PrintCentered y, _TRIM$(player_name) + "  the  " + _TRIM$(class_name)
    y = y + 2: COLOR GREY, BOXBG: PrintCentered y, "Level " + EvNum$(char_level) + "    XP " + EvNum$(char_xp) + "    Gold " + EvNum$(gold) + " / " + EvNum$(target_gold)
    y = y + 3
    SumRow y, "Rooms explored", g_rooms_explored: y = y + 2
    SumRow y, "Monsters slain", g_monsters_slain: y = y + 2
    SumRow y, "Treasures found", g_treasures_found: y = y + 2
    SumRow y, "Gold recovered", g_gold_found: y = y + 2
    SumRow y, "Magic items looted", g_items_looted: y = y + 2
    SumRow y, "Secret doors found", g_secrets_found: y = y + 2
    SumRow y, "Levels completed", g_levels_completed: y = y + 2
    SumRow y, "Wandering ambushes", g_wander_enc: y = y + 2
    SumRow y, "Critical hits / fumbles", g_crits: COLOR WHITE, BOXBG: _PRINTSTRING (70 * CW, y * CH), EvNum$(g_crits) + "  /  " + EvNum$(g_fumbles): y = y + 2
    SumRow y, "Deaths this run", g_run_deaths: y = y + 2
    SumRow y, "Trips home to heal", start_heals: y = y + 2
    COLOR CYANU, BOXBG: _PRINTSTRING (30 * CW, y * CH), PadR$("Time played", 26): COLOR WHITE, BOXBG: _PRINTSTRING (70 * CW, y * CH), tmr
    COLOR YELLOWU, BOXBG: PrintCentered 43, "[ press any key ]"
    Present: WaitKey: ChronicleClose
END SUB
SUB SumRow (y AS INTEGER, lbl AS STRING, v AS LONG)
    COLOR CYANU, BOXBG: _PRINTSTRING (30 * CW, y * CH), PadR$(lbl, 26)
    COLOR WHITE, BOXBG: _PRINTSTRING (70 * CW, y * CH), EvNum$(v)
END SUB

' EVENT LOG -- newest last; scroll with the arrows / PgUp-PgDn, ESC to leave.
SUB ShowEventLog
    DIM top AS INTEGER, per AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, ext AS INTEGER
    per = 30
    top = EVLOG_N - per + 1: IF top < 1 THEN top = 1     ' start at the newest page
    DO
        ChroniclePanel 6, 3, 126, 47, "E V E N T   L O G   (" + EvNum$(EVLOG_N) + " events)"
        IF EVLOG_N = 0 THEN
            COLOR GREY, BOXBG: PrintCentered 24, "Nothing has happened yet. Go make history."
        ELSE
            FOR i = 0 TO per - 1
                IF top + i <= EVLOG_N THEN
                    y = 6 + i
                    COLOR GREY, BOXBG: _PRINTSTRING (8 * CW, y * CH), PadR$(EvNum$(top + i), 4)
                    COLOR WHITE, BOXBG: _PRINTSTRING (12 * CW, y * CH), LEFT$(EVLOG(top + i), 112)
                END IF
            NEXT
        END IF
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] scroll   [PgUp/PgDn] page   [ESC] back"
        Present
        k = "": ext = 0
        DO
            k = INKEY$: IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
            IF k <> "" THEN EXIT DO
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF ext = 72 THEN top = top - 1                    ' up
        IF ext = 80 THEN top = top + 1                    ' down
        IF ext = 73 THEN top = top - per                  ' page up
        IF ext = 81 THEN top = top + per                  ' page down
        IF top > EVLOG_N - per + 1 THEN top = EVLOG_N - per + 1
        IF top < 1 THEN top = 1
    LOOP
    ChronicleClose
END SUB

' BESTIARY -- lightbar list on the left, portrait + tallies on the right.
SUB ShowBestiary
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, ext AS INTEGER, sp AS STRING
    PlayCue "bestiary", -1                              ' bestiary music (restored to the level track on exit)
    sel = 1
    DO
        _DEST CANVAS: LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), BOXBG, BF
        LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  B E S T I A R Y  =-"
        '--- list ---
        FOR i = 1 TO BEAST_N
            y = 7 + (i - 1)
            IF i = sel THEN COLOR WHITE, REDU ELSE COLOR GREENU, BOXBG
            _PRINTSTRING (7 * CW, y * CH), PadR$("  " + _TRIM$(BEAST_NAME(i)), 24)
        NEXT
        '--- detail panel (right) ---
        IF sel >= 1 AND sel <= BEAST_N THEN
            sp = MonsterSprite$(BEAST_NAME(sel))
            IF LEN(sp) > 0 THEN CombatArtBox sp, 36, 34, 7, 17, "-= " + _TRIM$(BEAST_NAME(sel)) + " =-", REDU   ' no artstyle guard: ArtFile$ returns "" when the chosen style has no art for this subject
            y = 26
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), _TRIM$(BEAST_NAME(sel))
            y = y + 1: COLOR GREY, BOXBG: _PRINTSTRING (36 * CW, y * CH), "Haunts: " + BeastHaunts$(BEAST_NAME(sel))
            y = y + 3
            BeastRow y, "Encountered", BEAST_ENC(sel): y = y + 2
            BeastRow y, "Slain", BEAST_SLAIN(sel): y = y + 2
            BeastRow y, "Fled from", BEAST_FLED(sel): y = y + 2
            BeastRow y, "Killed you", BEAST_KILLEDBY(sel): y = y + 2
            BeastRow y, "Loot rescued from", BEAST_LOOTED(sel): y = y + 2
        END IF
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] browse   [ESC] back"
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$))
            IF k <> "" THEN EXIT DO
            AudioTick                           ' screen-cue crossfade must keep ramping here
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF k = "W" THEN sel = sel - 1
        IF k = "S" THEN sel = sel + 1
        IF sel < 1 THEN sel = BEAST_N
        IF sel > BEAST_N THEN sel = 1
    LOOP
    EndCue                                              ' bestiary done -> back to the level track
    ChronicleClose
END SUB
SUB BeastRow (y AS INTEGER, lbl AS STRING, v AS INTEGER)
    COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), PadR$(lbl, 22)
    COLOR WHITE, BOXBG: _PRINTSTRING (60 * CW, y * CH), EvNum$(v)
END SUB

' Which dungeon levels a monster appears on (from MON_NAME).
FUNCTION BeastHaunts$ (nm AS STRING)
    DIM lv AS INTEGER, sl AS INTEGER, s AS STRING, t AS STRING
    t = UCASE$(_TRIM$(nm))
    FOR lv = 1 TO 9: FOR sl = 1 TO 3
            IF UCASE$(_TRIM$(MON_NAME(lv, sl))) = t THEN
                IF INSTR(s, "L" + EvNum$(lv)) = 0 THEN s = s + "L" + EvNum$(lv) + " "
            END IF
    NEXT sl: NEXT lv
    IF LEN(s) = 0 THEN s = "wandering"
    BeastHaunts$ = _TRIM$(s)
END FUNCTION

' TREASURY -- what you've recovered this run. A browsable catalogue (like the
' Bestiary): a lightbar list on the left, a framed treasure IMAGE + tallies on the right.
SUB ShowTreasury
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, sp AS STRING
    IF TRE_STAT_N = 0 THEN
        ChroniclePanel 16, 4, 116, 46, "T R E A S U R Y"
        COLOR GREY, BOXBG: PrintCentered 24, "No treasure recovered yet. The hoard awaits."
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[ press any key ]"
        Present: WaitKey: ChronicleClose: EXIT SUB
    END IF
    PlayCue "treasury", -1                              ' treasury music (restored to the level track on exit)
    sel = 1
    DO
        _DEST CANVAS: LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), BOXBG, BF
        LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), YELLOWU, B
        COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  T R E A S U R Y  =-"
        '--- list (left) ---
        FOR i = 1 TO TRE_STAT_N
            y = 7 + (i - 1)
            IF y > 43 THEN EXIT FOR
            IF i = sel THEN COLOR WHITE, REDU ELSE COLOR GREENU, BOXBG
            _PRINTSTRING (7 * CW, y * CH), PadR$("  " + _TRIM$(TRE_STATNAME(i)), 26)
        NEXT
        '--- detail panel (right) ---
        IF sel >= 1 AND sel <= TRE_STAT_N THEN
            sp = TreasureSprite$(TRE_STATNAME(sel))
            IF LEN(sp) > 0 THEN CombatArtBox sp, 36, 34, 7, 17, "-= " + _TRIM$(TRE_STATNAME(sel)) + " =-", YELLOWU   ' no artstyle guard: ArtFile$ returns "" when the chosen style has no art for this subject
            y = 26
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), _TRIM$(TRE_STATNAME(sel))
            y = y + 3
            BeastRow y, "Times found", TRE_FOUND(sel): y = y + 2
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), PadR$("GP each", 22)
            COLOR WHITE, BOXBG: _PRINTSTRING (60 * CW, y * CH), EvNum$(TRE_GP(sel))
        END IF
        COLOR GREENU, BOXBG: PrintCentered 44, "Total: " + EvNum$(g_gold_found) + " GP across " + EvNum$(g_treasures_found) + " finds"
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] browse   [ESC] back"
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$))
            IF k <> "" THEN EXIT DO
            AudioTick                           ' screen-cue crossfade must keep ramping here
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF k = "W" THEN sel = sel - 1
        IF k = "S" THEN sel = sel + 1
        IF sel < 1 THEN sel = TRE_STAT_N
        IF sel > TRE_STAT_N THEN sel = 1
    LOOP
    EndCue                                              ' treasury done -> back to the level track
    ChronicleClose
END SUB

' -- The MARKDOWN reader moved to engine/MARKDOWN.bas (reusable). RulesConfigBlock$
'    + ShowRules below still drive it via global SUB resolution (game -> engine). --


' Generate a markdown "your game, right now" section from the live SETTINGS, so the
' rules screen reflects how THIS run is actually configured (mode, movement, FOV, etc.).
FUNCTION RulesConfigBlock$ ()
    DIM s AS STRING, nl AS STRING, cb AS STRING
    nl = CHR$(10)
    s = "# Your game, right now" + nl + nl
    s = s + "How this run is configured -- change any of it in SETTINGS." + nl + nl
    s = s + "| Setting | Value |" + nl + "|---|---|" + nl
    IF opt_oldschool THEN
        s = s + "| Mode | Classic Dungeon! (Oldschool) |" + nl
        s = s + "| Combat | one 2d6 roll vs the monster's number -- no HP or AC |" + nl
    ELSE
        s = s + "| Mode | D&D (Newschool) |" + nl
        s = s + "| Combat | multi-round: d20 + to-hit vs AC, with HP & damage dice |" + nl
    END IF
    IF opt_boardgame THEN
        s = s + "| Movement | up to 5 spaces per turn, your choice (Dungeon!) |" + nl
    ELSE
        s = s + "| Movement | free walk (computer-game style) |" + nl
    END IF
    IF opt_fov THEN s = s + "| Field of View | on -- line of sight only |" + nl ELSE s = s + "| Field of View | off -- whole map visible |" + nl
    IF NOT opt_oldschool THEN
        IF opt_heroicstats THEN cb = "4d6 drop-lowest" ELSE cb = "straight 3d6"
        IF opt_flexstats = 1 THEN
            cb = cb + " + assign where you want"
        ELSEIF opt_flexstats = 2 THEN
            cb = "point-buy (spend up from 3, max 18)"
        END IF
        s = s + "| Character build | " + cb + " |" + nl
    END IF
    SELECT CASE opt_lootrecovery
        CASE 0: s = s + "| Loot on death | lost forever |" + nl
        CASE 2: s = s + "| Loot on death | souls-like -- one chance to reclaim |" + nl
        CASE ELSE: s = s + "| Loot on death | reclaim it (trek back and kill for it) |" + nl
    END SELECT
    IF NOT opt_oldschool THEN
        s = s + "| Lives | " + _TRIM$(STR$(opt_maxdeaths)) + " before the run is forfeit |" + nl
        IF opt_gestures THEN s = s + "| Action gestures | on -- time the bar for second-wind / crit |" + nl ELSE s = s + "| Action gestures | off |" + nl
        IF opt_critfumble THEN s = s + "| Crits & fumbles | cinematic |" + nl ELSE s = s + "| Crits & fumbles | plain |" + nl
        IF opt_juice THEN s = s + "| Screen effects | on -- shake + blood + poison |" + nl ELSE s = s + "| Screen effects | off |" + nl
    END IF
    IF opt_hardcore THEN s = s + "| Idle danger | hardcore -- time passes while idle |" + nl ELSE s = s + "| Idle danger | casual -- idling is safe |" + nl
    IF opt_realdice THEN s = s + "| Dice | you roll real dice and type the result |" + nl ELSE s = s + "| Dice | the computer rolls |" + nl
    IF num_players > 1 THEN s = s + "| Players | " + _TRIM$(STR$(num_players)) + " (hot-seat) |" + nl ELSE s = s + "| Players | 1 (solo) |" + nl
    s = s + nl + "---" + nl + nl
    RulesConfigBlock$ = s
END FUNCTION

SUB ShowRules
    DIM whole AS STRING, rest AS STRING, one AS STRING, content AS STRING, p AS LONG
    DIM kblk AS INTEGER, W AS INTEGER, per AS INTEGER, top AS INTEGER, leftcol AS INTEGER, toprow AS INTEGER
    REDIM vis(1 TO 6000) AS STRING, sty(1 TO 6000) AS STRING, lnk(1 TO 6000) AS STRING, knd(1 TO 6000) AS INTEGER
    REDIM url(1 TO 400) AS STRING
    REDIM hx1(1 TO 400) AS INTEGER, hx2(1 TO 400) AS INTEGER, hy(1 TO 400) AS INTEGER, hu(1 TO 400) AS INTEGER
    DIM n AS INTEGER, nurl AS INTEGER, tvis AS STRING, tsty AS STRING, tlnk AS STRING
    DIM nhit AS INTEGER, hovid AS INTEGER, i AS INTEGER, j AS INTEGER, row AS INTEGER, dl AS INTEGER
    DIM yy AS INTEGER, basecol AS INTEGER, runStartIdx AS INTEGER, curlnk AS INTEGER, linkStartCol AS INTEGER
    DIM styb AS INTEGER, lnkb AS INTEGER, runcol AS _UNSIGNED LONG, cc AS _UNSIGNED LONG, runstr AS STRING
    DIM k AS STRING, ext AS INTEGER, mx AS INTEGER, my AS INTEGER, mcx AS INTEGER, mcy AS INTEGER
    DIM prevdown AS INTEGER, wheel AS INTEGER, statusmsg AS STRING, statustimer AS INTEGER
    REDIM tbl(1 TO 120) AS STRING: DIM ntbl AS INTEGER
    W = 116: leftcol = 6: toprow = 5: per = 40

    DIM rulesfile AS STRING
    IF opt_oldschool THEN rulesfile = "assets/reference/DUNGEON-RULES.md" ELSE rulesfile = "assets/reference/DND-RULES.md"
    whole = RulesConfigBlock$                             ' live "your game" section first
    IF _FILEEXISTS(rulesfile) THEN whole = whole + _READFILE$(rulesfile)
    IF LEN(_TRIM$(whole)) = 0 THEN whole = "# Rules" + CHR$(10) + "The rules scroll (" + rulesfile + ") is missing."
    '--- parse the whole document into wrapped, attributed display lines ---
    n = 0: nurl = 0: ntbl = 0: rest = whole
    DO WHILE LEN(rest) > 0
        IF n >= UBOUND(vis) - 4 THEN EXIT DO
        p = INSTR(rest, CHR$(10))
        IF p = 0 THEN one = rest: rest = "" ELSE one = LEFT$(rest, p - 1): rest = MID$(rest, p + 1)
        IF RIGHT$(one, 1) = CHR$(13) THEN one = LEFT$(one, LEN(one) - 1)
        one = Utf8ToAscii$(one)
        kblk = MdBlock%(one, content)
        IF kblk = 6 THEN                                   ' a table row -- buffer it for aligned layout
            IF ntbl < UBOUND(tbl) THEN ntbl = ntbl + 1: tbl(ntbl) = content
        ELSE
            IF ntbl > 0 THEN EmitTable tbl(), ntbl, url(), nurl, vis(), sty(), lnk(), knd(), n: ntbl = 0
            IF kblk = 5 THEN
                n = n + 1: vis(n) = "": sty(n) = "": lnk(n) = "": knd(n) = 5
            ELSE
                MdInline content, tvis, tsty, tlnk, url(), nurl
                WrapEmit tvis, tsty, tlnk, kblk, vis(), sty(), lnk(), knd(), n, W
            END IF
        END IF
    LOOP
    IF ntbl > 0 THEN EmitTable tbl(), ntbl, url(), nurl, vis(), sty(), lnk(), knd(), n   ' flush a trailing table

    top = 1: prevdown = 0: statustimer = 0: nhit = 0
    DO
        _LIMIT 60
        '--- mouse: hover-test against last frame's link rects ---
        wheel = 0
        DO WHILE _MOUSEINPUT: wheel = wheel + _MOUSEWHEEL: LOOP
        mx = _MOUSEX: my = _MOUSEY: mcx = mx \ CW: mcy = my \ CH
        hovid = 0
        FOR i = 1 TO nhit
            IF mcy = hy(i) AND mcx >= hx1(i) AND mcx <= hx2(i) THEN hovid = hu(i): EXIT FOR
        NEXT
        '--- input ---
        k = INKEY$: ext = 0: IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
        IF k = CHR$(27) THEN EXIT DO
        IF ext = 72 THEN top = top - 1
        IF ext = 80 THEN top = top + 1
        IF ext = 73 THEN top = top - per
        IF ext = 81 THEN top = top + per
        IF wheel <> 0 THEN top = top + wheel * 3   ' natural direction (wheel up scrolls up)
        IF _MOUSEBUTTON(1) THEN
            IF NOT prevdown AND hovid > 0 THEN
                MdOpenURL url(hovid): statusmsg = "Opening: " + url(hovid): statustimer = 150: Sfx "select"
            END IF
            prevdown = -1
        ELSE
            prevdown = 0
        END IF
        IF top > n - per + 1 THEN top = n - per + 1
        IF top < 1 THEN top = 1

        '--- render ---
        _DEST CANVAS: _FONT CH
        LINE (4 * CW, 2 * CH)-(128 * CW, 48 * CH), BOXBG, BF
        LINE (4 * CW, 2 * CH)-(128 * CW, 48 * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered 3, "-=  R U L E S   O F   T H E   D U N G E O N  =-"
        IF mcy >= 0 AND mcy <= 60 AND hovid > 0 THEN
            ' (cursor over a link -- the underline/colour already highlights it)
        END IF
        nhit = 0
        FOR row = 0 TO per - 1
            dl = top + row
            IF dl > n THEN EXIT FOR
            yy = toprow + row
            IF knd(dl) = 5 THEN
                LINE (leftcol * CW, yy * CH + CH \ 2)-(124 * CW, yy * CH + CH \ 2), GREY
            ELSE
                basecol = leftcol
                IF knd(dl) = 4 THEN COLOR YELLOWU, BOXBG: _PRINTSTRING (leftcol * CW, yy * CH), CHR$(249): basecol = leftcol + 2
                runstr = "": runStartIdx = 1: curlnk = 0: linkStartCol = 0
                FOR j = 1 TO LEN(vis(dl))
                    styb = ASC(MID$(sty(dl), j, 1)): lnkb = ASC(MID$(lnk(dl), j, 1))
                    cc = MdColor~&(knd(dl), styb, lnkb, hovid)
                    IF j = 1 THEN runcol = cc
                    IF cc <> runcol THEN
                        COLOR runcol, BOXBG: _PRINTSTRING ((basecol + runStartIdx - 1) * CW, yy * CH), runstr
                        runstr = "": runStartIdx = j: runcol = cc
                    END IF
                    runstr = runstr + MID$(vis(dl), j, 1)
                    IF lnkb <> curlnk THEN
                        IF curlnk > 0 THEN MdHit hx1(), hx2(), hy(), hu(), nhit, linkStartCol, basecol + j - 2, yy, curlnk, hovid
                        IF lnkb > 0 THEN linkStartCol = basecol + j - 1
                        curlnk = lnkb
                    END IF
                NEXT j
                IF LEN(runstr) > 0 THEN COLOR runcol, BOXBG: _PRINTSTRING ((basecol + runStartIdx - 1) * CW, yy * CH), runstr
                IF curlnk > 0 THEN MdHit hx1(), hx2(), hy(), hu(), nhit, linkStartCol, basecol + LEN(vis(dl)) - 1, yy, curlnk, hovid
            END IF
        NEXT row

        IF statustimer > 0 THEN
            COLOR GREENU, BOXBG: PrintCentered 46, LEFT$(_TRIM$(statusmsg), 116)
            statustimer = statustimer - 1
        ELSE
            COLOR YELLOWU, BOXBG: PrintCentered 46, "[Up/Dn] scroll   [wheel/PgUp/PgDn] page   click a link to open   [ESC] back   (" + EvNum$(top) + "/" + EvNum$(n) + ")"
        END IF
        Present
    LOOP
    ChronicleClose
END SUB

' ---------------------------------------------------------------------------
'  GAME MENU -- the in-run pause menu ([M]). Lists the chronicle screens.
' ---------------------------------------------------------------------------
SUB GameMenu
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING
    DIM lbl(1 TO 8) AS STRING
    lbl(1) = "Character Sheet"
    lbl(2) = "Game Summary"
    lbl(3) = "Event Log"
    lbl(4) = "Bestiary"
    lbl(5) = "Treasury"
    lbl(6) = "Rules"
    lbl(7) = "Controls"
    lbl(8) = "Resume Game"
    sel = 1
    DO
        ChroniclePanel 44, 12, 88, 33, "G A M E   M E N U"
        FOR i = 1 TO 8
            y = 15 + (i - 1) * 2
            IF i = sel THEN COLOR WHITE, REDU ELSE COLOR CYANU, BOXBG
            PrintCentered y, "   " + lbl(i) + "   "
        NEXT
        COLOR YELLOWU, BOXBG: PrintCentered 32, "[W/S] move   [ENTER] pick   [ESC] resume"
        Present
        AudioTick                             ' gamemenu cue crossfade / narration fade keeps ramping
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = 8
        IF k = "S" THEN sel = sel + 1: IF sel > 8 THEN sel = 1
        IF k = CHR$(27) THEN EXIT SUB
        IF k = " " OR k = CHR$(13) THEN
            SELECT CASE sel
                CASE 1: ShowCharSheet
                CASE 2: ShowGameSummary
                CASE 3: ShowEventLog
                CASE 4: ShowBestiary
                CASE 5: ShowTreasury
                CASE 6: ShowRules
                CASE 7: ShowKeys
                CASE 8: EXIT SUB
            END SELECT
        END IF
    LOOP
END SUB
