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
    g_rooms_explored = 0: g_monsters_slain = 0: g_treasures_found = 0
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
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
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
    COLOR CYANU, BOXBG: _PRINTSTRING (30 * CW, y * CH), PadR$("Time played", 26): COLOR WHITE, BOXBG: _PRINTSTRING (70 * CW, y * CH), tmr
    COLOR YELLOWU, BOXBG: PrintCentered 43, "[ press any key ]"
    _DISPLAY: WaitKey: ChronicleClose
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
        _DISPLAY
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
            IF LEN(sp) > 0 AND opt_artstyle <> 0 THEN CombatArtBox sp, 36, 34, 7, 17, "-= " + _TRIM$(BEAST_NAME(sel)) + " =-", REDU
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
        _DISPLAY
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$))
            IF k <> "" THEN EXIT DO
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF k = "W" THEN sel = sel - 1
        IF k = "S" THEN sel = sel + 1
        IF sel < 1 THEN sel = BEAST_N
        IF sel > BEAST_N THEN sel = 1
    LOOP
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

' TREASURY -- what you've recovered this run.
SUB ShowTreasury
    DIM i AS INTEGER, y AS INTEGER
    ChroniclePanel 16, 4, 116, 46, "T R E A S U R Y"
    IF TRE_STAT_N = 0 THEN
        COLOR GREY, BOXBG: PrintCentered 24, "No treasure recovered yet. The hoard awaits."
    ELSE
        COLOR CYANU, BOXBG: _PRINTSTRING (22 * CW, 7 * CH), PadR$("TREASURE", 34) + PadR$("FOUND", 8) + "GP EACH"
        FOR i = 1 TO TRE_STAT_N
            y = 9 + (i - 1)
            IF y > 43 THEN EXIT FOR
            COLOR WHITE, BOXBG: _PRINTSTRING (22 * CW, y * CH), PadR$(_TRIM$(TRE_STATNAME(i)), 34) + PadR$(EvNum$(TRE_FOUND(i)), 8) + EvNum$(TRE_GP(i))
        NEXT
    END IF
    COLOR GREENU, BOXBG: PrintCentered 44, "Total recovered: " + EvNum$(g_gold_found) + " GP across " + EvNum$(g_treasures_found) + " finds"
    COLOR YELLOWU, BOXBG: PrintCentered 45, "[ press any key ]"
    _DISPLAY: WaitKey: ChronicleClose
END SUB

' RULES -- a paged reader of DUNGEON-RULES.md.
SUB ShowRules
    DIM whole AS STRING, per AS INTEGER, top AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, ext AS INTEGER
    REDIM ln(1 TO 4000) AS STRING
    DIM n AS INTEGER, p AS INTEGER, rest AS STRING, one AS STRING
    IF _FILEEXISTS("DUNGEON-RULES.md") THEN whole = _READFILE$("DUNGEON-RULES.md")
    IF LEN(whole) = 0 THEN whole = "The rules scroll is missing (DUNGEON-RULES.md)."
    '--- split into lines, strip a little markdown, wrap long lines to ~110 cols ---
    n = 0: rest = whole
    DO WHILE LEN(rest) > 0
        p = INSTR(rest, CHR$(10))
        IF p = 0 THEN one = rest: rest = "" ELSE one = LEFT$(rest, p - 1): rest = MID$(rest, p + 1)
        one = RulesStrip$(one)
        DO
            IF n >= UBOUND(ln) THEN EXIT DO
            n = n + 1
            IF LEN(one) <= 112 THEN ln(n) = one: one = "" ELSE ln(n) = LEFT$(one, 112): one = MID$(one, 113)
            IF LEN(one) = 0 THEN EXIT DO
        LOOP
    LOOP
    per = 38: top = 1
    DO
        ChroniclePanel 6, 3, 126, 47, "R U L E S   O F   T H E   D U N G E O N"
        FOR i = 0 TO per - 1
            IF top + i <= n THEN
                y = 6 + i: COLOR WHITE, BOXBG: _PRINTSTRING (9 * CW, y * CH), ln(top + i)
            END IF
        NEXT
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] scroll   [PgUp/PgDn] page   [ESC] back   (" + EvNum$(top) + "/" + EvNum$(n) + ")"
        _DISPLAY
        k = "": ext = 0
        DO
            k = INKEY$: IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
            IF k <> "" THEN EXIT DO
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF ext = 72 THEN top = top - 1
        IF ext = 80 THEN top = top + 1
        IF ext = 73 THEN top = top - per
        IF ext = 81 THEN top = top + per
        IF top > n - per + 1 THEN top = n - per + 1
        IF top < 1 THEN top = 1
    LOOP
    ChronicleClose
END SUB
FUNCTION RulesStrip$ (s AS STRING)
    DIM t AS STRING
    t = Utf8ToAscii$(s)                                    ' typographic UTF-8 -> ASCII (the grid font is CP437)
    DO WHILE LEFT$(t, 1) = "#": t = MID$(t, 2): LOOP        ' drop leading heading hashes
    t = SubstAll$(t, "**", "")                             ' drop **bold** and `code` markdown so it reads as plain prose
    t = SubstAll$(t, "`", "")
    RulesStrip$ = _TRIM$(t)
END FUNCTION

' Replace every occurrence of `finds` in `s` with `repl` (QB64 has no built-in).
FUNCTION SubstAll$ (s AS STRING, finds AS STRING, repl AS STRING)
    DIM acc AS STRING, rest AS STRING, p AS LONG
    IF LEN(finds) = 0 THEN SubstAll$ = s: EXIT FUNCTION
    rest = s: acc = ""
    DO
        p = INSTR(rest, finds)
        IF p = 0 THEN acc = acc + rest: EXIT DO
        acc = acc + LEFT$(rest, p - 1) + repl
        rest = MID$(rest, p + LEN(finds))
    LOOP
    SubstAll$ = acc
END FUNCTION

' Fold the typographic UTF-8 characters that appear in DUNGEON-RULES.md down to
' plain ASCII, so the CP437 grid font (which renders each UTF-8 byte as its own DOS
' glyph -- the 3 bytes of an em-dash become 3 garbage glyphs) shows clean punctuation
' instead of mojibake. Only the five sequences the file actually uses; sequences are
' built via CHR$ so the source stays pure ASCII.
FUNCTION Utf8ToAscii$ (s AS STRING)
    DIM t AS STRING
    t = s
    t = SubstAll$(t, CHR$(226) + CHR$(128) + CHR$(148), "--")   ' U+2014 em dash
    t = SubstAll$(t, CHR$(226) + CHR$(128) + CHR$(147), "-")    ' U+2013 en dash
    t = SubstAll$(t, CHR$(226) + CHR$(134) + CHR$(146), "->")   ' U+2192 rightwards arrow
    t = SubstAll$(t, CHR$(226) + CHR$(128) + CHR$(166), "...")  ' U+2026 ellipsis
    t = SubstAll$(t, CHR$(194) + CHR$(169), "(c)")              ' U+00A9 copyright
    Utf8ToAscii$ = t
END FUNCTION

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
        _DISPLAY
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
