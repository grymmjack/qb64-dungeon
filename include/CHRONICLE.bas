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

' TREASURY -- what you've recovered this run. A browsable catalogue (like the
' Bestiary): a lightbar list on the left, a framed treasure IMAGE + tallies on the right.
SUB ShowTreasury
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, sp AS STRING
    IF TRE_STAT_N = 0 THEN
        ChroniclePanel 16, 4, 116, 46, "T R E A S U R Y"
        COLOR GREY, BOXBG: PrintCentered 24, "No treasure recovered yet. The hoard awaits."
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[ press any key ]"
        _DISPLAY: WaitKey: ChronicleClose: EXIT SUB
    END IF
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
            IF LEN(sp) > 0 AND opt_artstyle <> 0 THEN CombatArtBox sp, 36, 34, 7, 17, "-= " + _TRIM$(TRE_STATNAME(sel)) + " =-", YELLOWU
            y = 26
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), _TRIM$(TRE_STATNAME(sel))
            y = y + 3
            BeastRow y, "Times found", TRE_FOUND(sel): y = y + 2
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), PadR$("GP each", 22)
            COLOR WHITE, BOXBG: _PRINTSTRING (60 * CW, y * CH), EvNum$(TRE_GP(sel))
        END IF
        COLOR GREENU, BOXBG: PrintCentered 44, "Total: " + EvNum$(g_gold_found) + " GP across " + EvNum$(g_treasures_found) + " finds"
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
        IF sel < 1 THEN sel = TRE_STAT_N
        IF sel > TRE_STAT_N THEN sel = 1
    LOOP
    ChronicleClose
END SUB

' ============================================================================
'  MARKDOWN reader -- renders DUNGEON-RULES.md with real formatting: coloured
'  headings, **bold**, `code`, - bullets, --- rules, and CLICKABLE links
'  ([text](url) and <url>). Each raw line is parsed into three parallel strings --
'  vis (the visible text), sty (a per-char style byte: 0 normal / 1 bold / 2 code),
'  and lnk (a per-char link id, 0 = none) -- then word-wrapped carrying all three,
'  so styling survives wrapping. Links are hit-tested against the mouse each frame.
' ============================================================================

' Open a URL in the system browser (Linux xdg-open; the game targets Linux).
SUB MdOpenURL (url AS STRING)
    DIM u AS STRING: u = _TRIM$(url)
    IF LEN(u) = 0 THEN EXIT SUB
    SHELL _DONTWAIT "xdg-open " + CHR$(34) + u + CHR$(34)
END SUB

' Style byte for the current inline state (code beats bold if somehow both).
FUNCTION StyOf% (bold AS INTEGER, code AS INTEGER)
    IF code THEN StyOf% = 2: EXIT FUNCTION
    IF bold THEN StyOf% = 1: EXIT FUNCTION
    StyOf% = 0
END FUNCTION

' Register a link URL, returning its id (1-based). Caps at the array bound.
FUNCTION AddURL% (u AS STRING, url() AS STRING, nurl AS INTEGER)
    IF nurl >= UBOUND(url) THEN AddURL% = 0: EXIT FUNCTION
    nurl = nurl + 1: url(nurl) = _TRIM$(u): AddURL% = nurl
END FUNCTION

' Append one char to the three parallel attribute strings.
SUB EmitCh (vis AS STRING, sty AS STRING, lnk AS STRING, ch AS STRING, styb AS INTEGER, lnkid AS INTEGER)
    vis = vis + ch: sty = sty + CHR$(styb): lnk = lnk + CHR$(lnkid)
END SUB

' Colour for a character given its block kind + style byte + whether it's the hovered link.
FUNCTION MdColor~& (knd AS INTEGER, styb AS INTEGER, lnkb AS INTEGER, hovid AS INTEGER)
    IF lnkb > 0 THEN
        IF lnkb = hovid THEN MdColor~& = _RGB32(255, 255, 130) ELSE MdColor~& = _RGB32(120, 200, 255)
        EXIT FUNCTION
    END IF
    IF styb = 2 THEN MdColor~& = _RGB32(130, 235, 130): EXIT FUNCTION   ' `code`
    IF styb = 1 THEN MdColor~& = _RGB32(255, 255, 255): EXIT FUNCTION   ' **bold**
    SELECT CASE knd
        CASE 1: MdColor~& = _RGB32(255, 220, 80)      ' # heading
        CASE 2: MdColor~& = _RGB32(120, 220, 255)     ' ## heading
        CASE 3: MdColor~& = _RGB32(150, 235, 150)     ' ### heading
        CASE 8: MdColor~& = _RGB32(170, 170, 190)     ' > quote
        CASE ELSE: MdColor~& = _RGB32(210, 205, 190)  ' body
    END SELECT
END FUNCTION

' Classify one raw line -> block kind, and set `content` to the marker-stripped text.
' kinds: 1-3 heading, 4 list, 5 rule, 6 table, 7 blank, 8 quote, 0 normal.
FUNCTION MdBlock% (raw AS STRING, content AS STRING)
    DIM t AS STRING, tt AS STRING, h AS INTEGER, ii AS INTEGER, allh AS INTEGER
    t = raw: tt = _TRIM$(t)
    IF LEN(tt) = 0 THEN content = "": MdBlock% = 7: EXIT FUNCTION
    IF LEN(tt) >= 3 THEN                                  ' horizontal rule (all dashes)
        allh = -1
        FOR ii = 1 TO LEN(tt): IF MID$(tt, ii, 1) <> "-" THEN allh = 0
        NEXT
        IF allh THEN content = "": MdBlock% = 5: EXIT FUNCTION
    END IF
    IF LEFT$(t, 1) = "#" THEN                             ' heading
        h = 0
        DO WHILE MID$(t, h + 1, 1) = "#": h = h + 1: LOOP
        content = _TRIM$(MID$(t, h + 1)): IF h > 3 THEN h = 3
        MdBlock% = h: EXIT FUNCTION
    END IF
    IF LEFT$(t, 2) = "- " OR LEFT$(t, 2) = "* " THEN content = _TRIM$(MID$(t, 3)): MdBlock% = 4: EXIT FUNCTION
    IF LEFT$(tt, 1) = "|" THEN content = tt: MdBlock% = 6: EXIT FUNCTION
    IF LEFT$(t, 2) = "> " THEN content = _TRIM$(MID$(t, 3)): MdBlock% = 8: EXIT FUNCTION
    content = t: MdBlock% = 0
END FUNCTION

' Parse inline markdown of `raw` into the three parallel attribute strings, collecting
' link URLs. Handles **bold**, `code`, [text](url), and <url> autolinks.
SUB MdInline (raw AS STRING, vis AS STRING, sty AS STRING, lnk AS STRING, url() AS STRING, nurl AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER, c AS STRING, c2 AS STRING, bold AS INTEGER, code AS INTEGER
    DIM j AS INTEGER, k2 AS INTEGER, txt AS STRING, u AS STRING, id AS INTEGER, m AS INTEGER
    vis = "": sty = "": lnk = "": bold = 0: code = 0
    n = LEN(raw): i = 1
    DO WHILE i <= n
        c = MID$(raw, i, 1): c2 = MID$(raw, i + 1, 1)
        IF c = "*" AND c2 = "*" THEN
            bold = NOT bold: i = i + 2
        ELSEIF c = "`" THEN
            code = NOT code: i = i + 1
        ELSEIF c = "[" THEN
            j = INSTR(i, raw, "]")
            IF j > 0 AND MID$(raw, j + 1, 1) = "(" THEN
                k2 = INSTR(j + 2, raw, ")")
                IF k2 > 0 THEN
                    txt = MID$(raw, i + 1, j - i - 1): u = MID$(raw, j + 2, k2 - j - 2)
                    id = AddURL%(u, url(), nurl)
                    FOR m = 1 TO LEN(txt): EmitCh vis, sty, lnk, MID$(txt, m, 1), 0, id: NEXT
                    i = k2 + 1
                ELSE
                    EmitCh vis, sty, lnk, c, StyOf%(bold, code), 0: i = i + 1
                END IF
            ELSE
                EmitCh vis, sty, lnk, c, StyOf%(bold, code), 0: i = i + 1
            END IF
        ELSEIF c = "<" AND (MID$(raw, i, 6) = "<http:" OR MID$(raw, i, 7) = "<https") THEN
            j = INSTR(i, raw, ">")
            IF j > 0 THEN
                u = MID$(raw, i + 1, j - i - 1): id = AddURL%(u, url(), nurl)
                FOR m = 1 TO LEN(u): EmitCh vis, sty, lnk, MID$(u, m, 1), 0, id: NEXT
                i = j + 1
            ELSE
                EmitCh vis, sty, lnk, c, StyOf%(bold, code), 0: i = i + 1
            END IF
        ELSE
            EmitCh vis, sty, lnk, c, StyOf%(bold, code), 0: i = i + 1
        END IF
    LOOP
END SUB

' Word-wrap the attribute triplet to width W, appending each display line (with its
' block kind) to the doc arrays. A blank input still emits one line (spacing).
SUB WrapEmit (tvis AS STRING, tsty AS STRING, tlnk AS STRING, knd AS INTEGER, vis() AS STRING, sty() AS STRING, lnk() AS STRING, kind() AS INTEGER, n AS INTEGER, W AS INTEGER)
    DIM cut AS INTEGER, ii AS INTEGER
    IF LEN(tvis) = 0 THEN
        IF n < UBOUND(vis) THEN n = n + 1: vis(n) = "": sty(n) = "": lnk(n) = "": kind(n) = knd
        EXIT SUB
    END IF
    DO WHILE LEN(tvis) > 0
        IF n >= UBOUND(vis) THEN EXIT SUB
        IF knd = 6 OR LEN(tvis) <= W THEN                 ' don't wrap table rows
            cut = LEN(tvis)
        ELSE
            cut = 0
            FOR ii = W TO 1 STEP -1
                IF MID$(tvis, ii, 1) = " " THEN cut = ii: EXIT FOR
            NEXT
            IF cut = 0 THEN cut = W
        END IF
        n = n + 1
        vis(n) = LEFT$(tvis, cut): sty(n) = LEFT$(tsty, cut): lnk(n) = LEFT$(tlnk, cut): kind(n) = knd
        tvis = MID$(tvis, cut + 1): tsty = MID$(tsty, cut + 1): tlnk = MID$(tlnk, cut + 1)
        IF LEN(tvis) > 0 THEN
            IF LEFT$(tvis, 1) = " " THEN tvis = MID$(tvis, 2): tsty = MID$(tsty, 2): tlnk = MID$(tlnk, 2)
        END IF
    LOOP
END SUB

' Record a clickable link rect (cell cols c1..c2 on row r -> url id uid) + underline it.
SUB MdHit (x1() AS INTEGER, x2() AS INTEGER, yr() AS INTEGER, uu() AS INTEGER, nh AS INTEGER, c1 AS INTEGER, c2 AS INTEGER, r AS INTEGER, uid AS INTEGER, hovid AS INTEGER)
    IF nh >= UBOUND(x1) THEN EXIT SUB
    nh = nh + 1: x1(nh) = c1: x2(nh) = c2: yr(nh) = r: uu(nh) = uid
    DIM ul AS _UNSIGNED LONG
    IF uid = hovid THEN ul = _RGB32(255, 255, 130) ELSE ul = _RGB32(120, 200, 255)
    LINE (c1 * CW, (r + 1) * CH - 2)-((c2 + 1) * CW - 1, (r + 1) * CH - 2), ul
END SUB

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
    W = 116: leftcol = 6: toprow = 5: per = 40

    whole = ""
    IF _FILEEXISTS("DUNGEON-RULES.md") THEN whole = _READFILE$("DUNGEON-RULES.md")
    IF LEN(whole) = 0 THEN whole = "# Rules" + CHR$(10) + "The rules scroll is missing (DUNGEON-RULES.md)."
    '--- parse the whole document into wrapped, attributed display lines ---
    n = 0: nurl = 0: rest = whole
    DO WHILE LEN(rest) > 0
        IF n >= UBOUND(vis) - 4 THEN EXIT DO
        p = INSTR(rest, CHR$(10))
        IF p = 0 THEN one = rest: rest = "" ELSE one = LEFT$(rest, p - 1): rest = MID$(rest, p + 1)
        IF RIGHT$(one, 1) = CHR$(13) THEN one = LEFT$(one, LEN(one) - 1)
        one = Utf8ToAscii$(one)
        kblk = MdBlock%(one, content)
        IF kblk = 5 THEN
            n = n + 1: vis(n) = "": sty(n) = "": lnk(n) = "": knd(n) = 5
        ELSE
            MdInline content, tvis, tsty, tlnk, url(), nurl
            WrapEmit tvis, tsty, tlnk, kblk, vis(), sty(), lnk(), knd(), n, W
        END IF
    LOOP

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
        IF wheel <> 0 THEN top = top - wheel * 3
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
        _DISPLAY
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
