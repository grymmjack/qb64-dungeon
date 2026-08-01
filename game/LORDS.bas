' ============================================================================
'  LORDS.bas -- persistent hall of fame + character load (dungeon-lords.dat)
' ============================================================================

' Path to a champion's end-of-run board snapshot. Kept in a subdirectory (not the
' repo root) -- ShowEnd creates the folder before saving. One helper for all 3 sites.
FUNCTION LordsMapPath$ (mapkey AS STRING)
    LordsMapPath$ = "gameplay-data-saves/dungeon-lords-maps/" + _TRIM$(mapkey) + ".png"
END FUNCTION

' Append a victorious champion to the hall of fame, v2 pipe-delimited record:
'   name|class|gold|secs|deepest|k1..k9|g1..g9|STR INT WIS DEX CON CHA HP
' The per-level chronicle + ability scores come straight from the run's globals.
SUB SaveLord (nm AS STRING, klass AS STRING, gld AS LONG, secs AS LONG, mapid AS LONG)
    DIM f AS INTEGER, i AS INTEGER, deep AS INTEGER, ks AS STRING, gs AS STRING, ab AS STRING, evs AS STRING, e0 AS INTEGER
    deep = 0
    FOR i = 1 TO 9
        IF lvl_reached(i) THEN deep = i
    NEXT i
    ks = "": gs = ""
    FOR i = 1 TO 9
        ks = ks + _TRIM$(STR$(lvl_kills(i))): IF i < 9 THEN ks = ks + " "
        gs = gs + _TRIM$(STR$(lvl_gold(i))): IF i < 9 THEN gs = gs + " "
    NEXT i
    ab = _TRIM$(STR$(player_str)) + " " + _TRIM$(STR$(player_int)) + " " + _TRIM$(STR$(player_wis)) + " " + _TRIM$(STR$(player_dex)) + " " + _TRIM$(STR$(player_con)) + " " + _TRIM$(STR$(player_cha)) + " " + _TRIM$(STR$(player_maxhp))
    ' v3 adds: mapid (its snapshot PNG) + the event log (last ~180 events, joined by ~~)
    e0 = EVLOG_N - 180: IF e0 < 1 THEN e0 = 1
    evs = ""
    FOR i = e0 TO EVLOG_N: evs = evs + EVLOG(i): IF i < EVLOG_N THEN evs = evs + " ~~ "
    NEXT
    f = FREEFILE
    OPEN "gameplay-data-saves/dungeon-lords.dat" FOR APPEND AS #f
    PRINT #f, nm + "|" + klass + "|" + _TRIM$(STR$(gld)) + "|" + _TRIM$(STR$(secs)) + "|" + _TRIM$(STR$(deep)) + "|" + ks + "|" + gs + "|" + ab + "|" + _TRIM$(STR$(mapid)) + "|" + evs
    CLOSE #f
END SUB


' Return the idx-th (1-based) `delim`-separated field of s ("" if out of range).
' NthField$ moved to engine/TEXT.bas (reusable; resolved globally).


' Load the hall of fame, sorted by gold (desc). Fills the base arrays and parks
' each lord's raw v2 record in LORD_DETAIL for the chronicle screen. Tolerates the
' old v1 CSV rows ("name","class",gold,secs) -- those just have no chronicle.
FUNCTION ReadLords% (nm() AS STRING, klass() AS STRING, gld() AS LONG, secs() AS LONG)
    DIM n AS INTEGER, i AS INTEGER, j AS INTEGER, ln AS STRING, whole AS STRING
    DIM a AS INTEGER, b AS INTEGER, rest AS STRING, p AS LONG, nl AS LONG
    n = 0
    IF NOT _FILEEXISTS("gameplay-data-saves/dungeon-lords.dat") THEN ReadLords = 0: EXIT FUNCTION
    ' read the whole file and split on newlines ourselves -- dodges QB64's flaky
    ' EOF/LINE INPUT interaction ("Input past end of file") on the last line.
    whole = _READFILE$("gameplay-data-saves/dungeon-lords.dat")
    p = 1
    DO WHILE p <= LEN(whole)
        IF n >= UBOUND(nm) THEN EXIT DO
        nl = INSTR(p, whole, CHR$(10))
        IF nl = 0 THEN
            ln = MID$(whole, p): p = LEN(whole) + 1
        ELSE
            ln = MID$(whole, p, nl - p): p = nl + 1
        END IF
        IF RIGHT$(ln, 1) = CHR$(13) THEN ln = LEFT$(ln, LEN(ln) - 1)   ' strip CR
        IF LEN(_TRIM$(ln)) > 0 THEN
            n = n + 1
            IF INSTR(ln, "|") > 0 THEN                 ' v2 record
                nm(n) = _TRIM$(NthField$(ln, "|", 1))
                klass(n) = _TRIM$(NthField$(ln, "|", 2))
                gld(n) = VAL(NthField$(ln, "|", 3))
                secs(n) = VAL(NthField$(ln, "|", 4))
                LORD_DETAIL(n) = ln
            ELSE                                        ' v1 CSV: "name","class", gold , secs
                a = INSTR(ln, CHR$(34)): b = INSTR(a + 1, ln, CHR$(34))
                nm(n) = MID$(ln, a + 1, b - a - 1)
                a = INSTR(b + 1, ln, CHR$(34)): b = INSTR(a + 1, ln, CHR$(34))
                klass(n) = MID$(ln, a + 1, b - a - 1)
                rest = MID$(ln, b + 1)                  ' " , gold , secs"
                gld(n) = VAL(NthField$(rest, ",", 2))
                secs(n) = VAL(NthField$(rest, ",", 3))
                LORD_DETAIL(n) = ""
            END IF
        END IF
    LOOP
    FOR i = 1 TO n - 1
        FOR j = 1 TO n - i
            IF gld(j) < gld(j + 1) THEN
                SWAP nm(j), nm(j + 1): SWAP klass(j), klass(j + 1)
                SWAP gld(j), gld(j + 1): SWAP secs(j), secs(j + 1)
                SWAP LORD_DETAIL(j), LORD_DETAIL(j + 1)
            END IF
        NEXT j
    NEXT i
    ReadLords = n
END FUNCTION


' Pad a string on the right to width w (for simple table columns).
' PadR$ and MMSS$ moved to engine/TEXT.bas (reusable; resolved globally).


' Class name -> CLASSES index (1..4), default HERO.
FUNCTION ClassIndex% (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO 4
        IF UCASE$(nm) = UCASE$(CLASSES(i).name) THEN ClassIndex = i: EXIT FUNCTION
    NEXT i
    ClassIndex = 1
END FUNCTION


' The deepest level a lord reached, for the list ("--" for old v1 rows).
FUNCTION DeepestLabel$ (detail AS STRING)
    IF LEN(detail) = 0 THEN DeepestLabel$ = "--" ELSE DeepestLabel$ = Ordinal$(VAL(NthField$(detail, "|", 5)))
END FUNCTION


' LEGENDARY LORDS screen (menu option 4): the hall of fame -- now selectable, with
' a per-level chronicle + character sheet behind [ENTER].
SUB ShowLords
    DIM nm(1 TO 200) AS STRING, klass(1 TO 200) AS STRING, gld(1 TO 200) AS LONG, secs(1 TO 200) AS LONG
    DIM n AS INTEGER, i AS INTEGER, y AS INTEGER, sel AS INTEGER, k AS STRING
    n = ReadLords(nm(), klass(), gld(), secs())
    IF n = 0 THEN
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 5, "-=  L E G E N D A R Y   L O R D S  =-"
        COLOR GREY, BLACK: PrintCentered 20, "No champions yet -- be the first to escape the dungeon alive!"
        COLOR YELLOWU, BLACK: PrintCentered 46, "[ press any key ]"
        Present: WaitKey: EXIT SUB
    END IF
    PlayCue "lords", -1                                 ' hall-of-fame music (restored to menu/level track on exit)
    sel = 1
    DO
        _LIMIT 60
        AudioTick                             ' lords-screen cue crossfade keeps ramping
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN
            sel = sel - 1: IF sel < 1 THEN sel = n
            Sfx "select"
        END IF
        IF k = "S" THEN
            sel = sel + 1: IF sel > n THEN sel = 1
            Sfx "select"
        END IF
        IF k = CHR$(27) THEN EndCue: EXIT SUB
        IF k = CHR$(13) THEN
            Sfx "select"
            ShowLordDetail sel, nm(sel), klass(sel), gld(sel), secs(sel)
        END IF
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 4, "-=  L E G E N D A R Y   L O R D S  =-"
        COLOR CYANU, BLACK
        _PRINTSTRING (26 * CW, 7 * CH), "#   " + PadR$("NAME", 26) + PadR$("CLASS", 12) + PadR$("GOLD", 8) + PadR$("TIME", 8) + "DEEPEST"
        FOR i = 1 TO n
            IF i > 30 THEN EXIT FOR
            y = 8 + i
            IF i = sel THEN
                COLOR WHITE, REDU
            ELSEIF i = 1 THEN
                COLOR YELLOWU, BLACK
            ELSE
                COLOR WHITE, BLACK
            END IF
            _PRINTSTRING (26 * CW, y * CH), PadR$(_TRIM$(STR$(i)) + ".", 4) + PadR$(nm(i), 26) + PadR$(klass(i), 12) + PadR$(_TRIM$(STR$(gld(i))), 8) + PadR$(MMSS$(secs(i)), 8) + DeepestLabel$(LORD_DETAIL(i))
        NEXT i
        COLOR CYANU, BLACK: PrintCentered 45, "[W/S] pick    [ENTER] view chronicle    [ESC] back"
        Present
    LOOP
END SUB


' A single lord's chronicle: ability scores + a per-level table of kills and gold,
' with hotkeys to the persisted event log ([E]) and the map at escape ([M]) when the
' record carries them (v3+).
SUB ShowLordDetail (idx AS INTEGER, nm AS STRING, klass AS STRING, gld AS LONG, secs AS LONG)
    DIM detail AS STRING, i AS INTEGER, y AS INTEGER, deep AS INTEGER
    DIM kk(1 TO 9) AS INTEGER, gg(1 TO 9) AS LONG, ab AS STRING, ks AS STRING, gs AS STRING
    DIM k AS STRING, mapkey AS STRING, evfield AS STRING, hasmap AS INTEGER, hasev AS INTEGER, foot AS STRING, handled AS INTEGER
    detail = LORD_DETAIL(idx)
    mapkey = _TRIM$(NthField$(detail, "|", 9))
    evfield = NthField$(detail, "|", 10)
    hasmap = 0: IF LEN(mapkey) > 0 THEN IF _FILEEXISTS(LordsMapPath$(mapkey)) THEN hasmap = -1
    hasev = 0: IF LEN(_TRIM$(evfield)) > 0 THEN hasev = -1
    DO
        _DEST CANVAS: _FONT CH: CLS , BLACK
        LINE (20 * CW, 3 * CH)-(112 * CW, 48 * CH), BOXBG, BF
        LINE (20 * CW, 3 * CH)-(112 * CW, 48 * CH), REDU, B
        COLOR YELLOWU, BOXBG: PrintCentered 5, "-=  " + _TRIM$(nm) + " the " + _TRIM$(klass) + "  =-"
        COLOR WHITE, BOXBG: PrintCentered 7, _TRIM$(STR$(gld)) + " gold escaped in " + MMSS$(secs)
        IF LEN(detail) = 0 THEN
            COLOR GREY, BOXBG: PrintCentered 24, "(an elder record -- no per-level chronicle was kept)"
        ELSE
            deep = VAL(NthField$(detail, "|", 5))
            ks = NthField$(detail, "|", 6): gs = NthField$(detail, "|", 7): ab = NthField$(detail, "|", 8)
            FOR i = 1 TO 9: kk(i) = VAL(NthField$(ks, " ", i)): gg(i) = VAL(NthField$(gs, " ", i)): NEXT i
            COLOR CYANU, BOXBG
            PrintCentered 9, "STR " + NthField$(ab, " ", 1) + "   INT " + NthField$(ab, " ", 2) + "   WIS " + NthField$(ab, " ", 3) + "   DEX " + NthField$(ab, " ", 4) + "   CON " + NthField$(ab, " ", 5) + "   CHA " + NthField$(ab, " ", 6) + "   HP " + NthField$(ab, " ", 7)
            COLOR YELLOWU, BOXBG: PrintCentered 11, "delved to the " + Ordinal$(deep) + " level"
            COLOR CYANU, BOXBG: _PRINTSTRING (44 * CW, 14 * CH), "LEVEL      KILLS       GOLD"
            FOR i = 1 TO 9
                y = 15 + (i - 1) * 2
                IF i <= deep THEN COLOR WHITE, BOXBG ELSE COLOR GREY, BOXBG
                _PRINTSTRING (44 * CW, y * CH), PadR$(Ordinal$(i), 10) + PadR$(_TRIM$(STR$(kk(i))), 12) + _TRIM$(STR$(gg(i)))
            NEXT i
        END IF
        foot = "[C] character sheet     "
        IF hasev THEN foot = foot + "[E] chronicle log     "
        IF hasmap THEN foot = foot + "[M] map at escape     "
        foot = foot + "[ESC] back"
        COLOR YELLOWU, BOXBG: PrintCentered 46, foot
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$)): _LIMIT 60
        LOOP WHILE k = ""
        handled = 0
        IF k = "C" THEN ShowLordSheet nm, klass, gld, secs, detail: handled = -1
        IF k = "E" AND hasev THEN ShowLordLog nm, evfield: handled = -1
        IF k = "M" AND hasmap THEN ShowLordMap nm, mapkey: handled = -1
        IF NOT handled THEN EXIT DO
    LOOP
END SUB


' Scrollable replay of a lord's persisted event log (events joined by " ~~ " in the record).
SUB ShowLordLog (nm AS STRING, evfield AS STRING)
    DIM n AS INTEGER, i AS INTEGER, top AS INTEGER, per AS INTEGER, y AS INTEGER, k AS STRING, cur AS STRING, q AS INTEGER
    REDIM ev(1 TO 400) AS STRING
    '--- split the " ~~ "-joined field back into individual lines ---
    n = 0: cur = evfield
    DO
        q = INSTR(cur, " ~~ ")
        n = n + 1: IF n > 400 THEN n = 400: EXIT DO
        IF q = 0 THEN ev(n) = cur: EXIT DO
        ev(n) = LEFT$(cur, q - 1): cur = MID$(cur, q + 4)
    LOOP
    per = 36: top = 1
    DO
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 3, "-=  " + _TRIM$(nm) + " -- Chronicle Log  =-"
        FOR i = 0 TO per - 1
            IF top + i > n THEN EXIT FOR
            y = 6 + i
            COLOR GREY, BLACK: _PRINTSTRING (10 * CW, y * CH), PadR$(_TRIM$(STR$(top + i)) + ".", 5)
            COLOR WHITE, BLACK: _PRINTSTRING (15 * CW, y * CH), ev(top + i)
        NEXT
        COLOR CYANU, BLACK: PrintCentered 46, "[W/S] [PgUp/PgDn] scroll     [ESC] back      (" + _TRIM$(STR$(top)) + "-" + _TRIM$(STR$(top + per - 1)) + " of " + _TRIM$(STR$(n)) + ")"
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$)): _LIMIT 60
        LOOP WHILE k = ""
        IF k = CHR$(27) THEN EXIT SUB
        IF k = "W" THEN top = top - 1
        IF k = "S" THEN top = top + 1
        IF k = "NE" THEN top = top - per        ' PgUp (NormKey$ maps it to NE)
        IF k = "SE" THEN top = top + per        ' PgDn (NormKey$ maps it to SE)
        IF top > n - per + 1 THEN top = n - per + 1
        IF top < 1 THEN top = 1
    LOOP
END SUB


' Show a lord's map-at-escape PNG snapshot. The map is saved at the full screen
' resolution, so blit it 1:1 (no scaling) -- a fractional _PUTIMAGE stretch is
' nearest-neighbour and drops rows/cols unevenly ("crunched" text/lines). The title
' and footer just overlay the map's outer frame (their black text-cells cover almost
' nothing). If a record's map is some other size, centre it 1:1 rather than distort.
SUB ShowLordMap (nm AS STRING, mapkey AS STRING)
    DIM img AS LONG, iw AS INTEGER, ih AS INTEGER, ox AS INTEGER, oy AS INTEGER
    img = _LOADIMAGE(LordsMapPath$(mapkey), 32)
    _DEST CANVAS: _FONT CH: CLS , BLACK
    IF img >= -1 THEN                              ' load failed (-1); valid handles are < -1
        COLOR GREY, BLACK: PrintCentered 24, "(the map for this record could not be found)"
    ELSE
        iw = _WIDTH(img): ih = _HEIGHT(img)
        ox = (SW * CW - iw) \ 2: oy = (SH * CH - ih) \ 2   ' centre; 0,0 when it's screen-sized
        _PUTIMAGE (ox, oy), img, CANVAS                    ' 1:1 -- crisp, no crunch
        _FREEIMAGE img
        COLOR YELLOWU, BLACK: PrintCentered 1, "-=  " + _TRIM$(nm) + " -- Map at Escape  =-"
    END IF
    COLOR CYANU, BLACK: PrintCentered 49, "[ press any key ]"
    Present
    WaitKey
END SUB


' A lord's CHARACTER SHEET ([C] from the detail screen): class portrait + ability
' scores with modifiers + the derived combat baseline + the class goal, reconstructed
' from the stored record.
SUB ShowLordSheet (nm AS STRING, klass AS STRING, gld AS LONG, secs AS LONG, detail AS STRING)
    DIM pc AS INTEGER, ab AS STRING, deep AS INTEGER, csp AS STRING, ddrew AS INTEGER
    DIM hp AS INTEGER, dxm AS INTEGER
    pc = ClassIndex%(klass)
    deep = 0: IF LEN(detail) > 0 THEN deep = VAL(NthField$(detail, "|", 5))
    _DEST CANVAS: _FONT CH: CLS , BLACK
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), BOXBG, BF
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), REDU, B
    IF TRUE THEN                                                   ' class portrait, top-right
        '  no artstyle guard: ClassSprite$ -> ArtFile$ already returns "" when the chosen
        '  style has no art, so ANSI mode now gets a portrait instead of a blank corner
        csp = ClassSprite$(pc)
        IF LEN(csp) > 0 THEN
            IF _FILEEXISTS(csp) THEN
                LINE (92 * CW - 3, 5 * CH - 3)-(108 * CW + 3, 21 * CH + 3), _RGB32(&H10, &H08, &H10), BF
                LINE (92 * CW - 3, 5 * CH - 3)-(108 * CW + 3, 21 * CH + 3), REDU, B
                ddrew = DrawSpriteFit%(csp, 92 * CW, 5 * CH, 16 * CW, 16 * CH)
            END IF
        END IF
    END IF
    COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  C H A R A C T E R   S H E E T  =-"
    COLOR WHITE, BOXBG: PrintCentered 6, _TRIM$(nm) + " the " + _TRIM$(klass)
    COLOR YELLOWU, BOXBG: PrintCentered 7, _TRIM$(STR$(gld)) + " gold escaped in " + MMSS$(secs) + "   --   delved to the " + Ordinal$(deep) + " level"
    IF LEN(detail) = 0 THEN
        COLOR GREY, BOXBG: PrintCentered 22, "(an elder record -- no ability scores were kept)"
    ELSE
        ab = NthField$(detail, "|", 8)
        hp = VAL(NthField$(ab, " ", 7))
        dxm = AbilMod%(VAL(NthField$(ab, " ", 4)))
        COLOR CYANU, BOXBG
        PrintCentered 10, "STR " + AbLine$(ab, 1) + "      INT " + AbLine$(ab, 2) + "      WIS " + AbLine$(ab, 3)
        PrintCentered 12, "DEX " + AbLine$(ab, 4) + "      CON " + AbLine$(ab, 5) + "      CHA " + AbLine$(ab, 6)
        COLOR GREENU, BOXBG: PrintCentered 15, "HP " + _TRIM$(STR$(hp)) + "         AC " + _TRIM$(STR$(10 + dxm)) + " (base, unarmoured)"
        COLOR GREY, BOXBG: PrintCentered 17, ClassSpecial$(pc)
        COLOR YELLOWU, BOXBG: PrintCentered 19, "Class goal: " + _TRIM$(STR$(CLASSES(pc).gold_goal)) + " gold to win"
    END IF
    COLOR YELLOWU, BOXBG: PrintCentered 46, "[ press any key ]"
    Present: WaitKey
END SUB

' "13 (+1)" -- an ability score with its modifier, from the space-joined ability string.
FUNCTION AbLine$ (ab AS STRING, idx AS INTEGER)
    DIM v AS INTEGER
    v = VAL(NthField$(ab, " ", idx))
    AbLine$ = _TRIM$(STR$(v)) + " (" + ModStr$(AbilMod%(v)) + ")"
END FUNCTION


' LOAD A CHARACTER screen (menu option 3): pick a past champion to play as.
SUB LoadCharacter
    DIM nm(1 TO 200) AS STRING, klass(1 TO 200) AS STRING, gld(1 TO 200) AS LONG, secs(1 TO 200) AS LONG
    DIM n AS INTEGER, sel AS INTEGER, k AS STRING, i AS INTEGER, y AS INTEGER
    n = ReadLords(nm(), klass(), gld(), secs())
    IF n = 0 THEN
        Banner "No saved champions to load.", "Win a game to enshrine one!   [ press any key ]"
        WaitKey
        EXIT SUB
    END IF
    sel = 1
    DO
        _LIMIT 60
        AudioTick                             ' lords-screen cue crossfade keeps ramping
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = n
        IF k = "S" THEN sel = sel + 1: IF sel > n THEN sel = 1
        IF k = "W" OR k = "S" THEN Sfx "select"
        IF k = CHR$(27) THEN EXIT SUB
        IF k = CHR$(13) THEN
            player_name = nm(sel)
            player_class = ClassIndex(klass(sel))
            InitDefaultChar player_class          ' baseline stats (ability scores aren't saved)
            Sfx "select"
            EXIT SUB
        END IF
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 6, "L O A D   A   C H A M P I O N"
        FOR i = 1 TO n
            IF i > 14 THEN EXIT FOR
            y = 9 + i
            IF i = sel THEN COLOR WHITE, REDU ELSE COLOR GREY, BLACK
            PrintCentered y, PadR$(nm(i), 16) + PadR$(klass(i), 11) + _TRIM$(STR$(gld(i))) + " gold"
        NEXT i
        COLOR CYANU, BLACK: PrintCentered 46, "[W/S] pick    [ENTER] play as them    [ESC] back"
        Present
    LOOP
END SUB


' Name-entry prompt shown on victory, before enshrining the champion.
FUNCTION EnterName$
    DIM nm AS STRING, k AS STRING, chcode AS INTEGER   ' NOT "ch" -- would shadow the CH font handle
    nm = player_name
    DO
        _LIMIT 60
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR GREENU, BLACK: PrintCentered 16, "V I C T O R Y !"
        COLOR WHITE, BLACK: PrintCentered 20, "You escape with " + _TRIM$(STR$(gold)) + " gold and the Level Key."
        PrintCentered 24, "Name yourself for the Legendary Lords:"
        COLOR YELLOWU, BLACK: PrintCentered 27, nm + "_"
        COLOR CYANU, BLACK: PrintCentered 32, "[ENTER] to be enshrined"
        Present
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                EXIT DO
            ELSEIF k = CHR$(8) THEN
                IF LEN(nm) > 0 THEN nm = LEFT$(nm, LEN(nm) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                IF chcode >= 32 AND chcode <= 126 AND LEN(nm) < 38 THEN nm = nm + k   ' 38 fits the long random names (PLAYER.name is 40)
            END IF
        END IF
    LOOP
    IF _TRIM$(nm) = "" THEN nm = class_name
    EnterName$ = nm
END FUNCTION


' ============================================================================
'  SETTINGS PERSISTENCE (dungeon-settings.dat) -- remembers the player's prefs
' ============================================================================

SUB SaveSettings
    DIM f AS INTEGER
    f = FREEFILE
    OPEN "gameplay-data-saves/dungeon-settings.dat" FOR OUTPUT AS #f
    PRINT #f, "music " + _TRIM$(STR$(opt_music))
    PRINT #f, "sfx " + _TRIM$(STR$(opt_sfx))
    PRINT #f, "voice " + _TRIM$(STR$(opt_voice))
    PRINT #f, "showdice " + _TRIM$(STR$(opt_showdice))
    PRINT #f, "fullscreen " + _TRIM$(STR$(opt_fullscreen))
    PRINT #f, "musicvol " + _TRIM$(STR$(opt_musicvol))
    PRINT #f, "sfxvol " + _TRIM$(STR$(opt_sfxvol))
    PRINT #f, "voicevol " + _TRIM$(STR$(opt_voicevol))
    PRINT #f, "duckamt " + _TRIM$(STR$(opt_duckamt))
    PRINT #f, "realdice " + _TRIM$(STR$(opt_realdice))
    PRINT #f, "dicemath " + _TRIM$(STR$(opt_dicemath))
    PRINT #f, "oldschool " + _TRIM$(STR$(opt_oldschool))
    PRINT #f, "tactical " + _TRIM$(STR$(opt_tactical))
    PRINT #f, "audiopref " + _TRIM$(STR$(opt_audiopref))
    PRINT #f, "heroicstats " + _TRIM$(STR$(opt_heroicstats))
    PRINT #f, "flexstats " + _TRIM$(STR$(opt_flexstats))
    PRINT #f, "boardgame " + _TRIM$(STR$(opt_boardgame))
    PRINT #f, "movedice " + _TRIM$(STR$(opt_movedice))
    PRINT #f, "artstyle " + _TRIM$(STR$(opt_artstyle))
    PRINT #f, "gestures " + _TRIM$(STR$(opt_gestures))
    PRINT #f, "juice " + _TRIM$(STR$(opt_juice))
    PRINT #f, "fov " + _TRIM$(STR$(opt_fov))
    PRINT #f, "players " + _TRIM$(STR$(num_players))
    PRINT #f, "dicecolor " + _TRIM$(STR$(opt_dicecolor))
    PRINT #f, "dicesolid " + _TRIM$(STR$(opt_dicesolid))
    PRINT #f, "d6pips " + _TRIM$(STR$(opt_d6pips))
    PRINT #f, "dicespeed " + _TRIM$(STR$(opt_dicespeed))
    PRINT #f, "dicelight " + _TRIM$(STR$(opt_dicelight))
    PRINT #f, "diceround " + _TRIM$(STR$(opt_diceround))
    PRINT #f, "bloodstrength " + _TRIM$(STR$(opt_bloodstrength))
    PRINT #f, "smoothamt " + _TRIM$(STR$(opt_smoothamt))
    PRINT #f, "combatspeed " + _TRIM$(STR$(opt_combatspeed))
    PRINT #f, "msgdelay " + _TRIM$(STR$(opt_msgdelay))
    PRINT #f, "hardcore " + _TRIM$(STR$(opt_hardcore))
    PRINT #f, "critfumble " + _TRIM$(STR$(opt_critfumble))
    PRINT #f, "lootrecovery " + _TRIM$(STR$(opt_lootrecovery))
    PRINT #f, "maxdeaths " + _TRIM$(STR$(opt_maxdeaths))
    PRINT #f, "mondicecolor " + _TRIM$(STR$(opt_mon_dicecolor))
    PRINT #f, "mondicesolid " + _TRIM$(STR$(opt_mon_dicesolid))
    PRINT #f, "mond6pips " + _TRIM$(STR$(opt_mon_d6pips))
    PRINT #f, "mondicespeed " + _TRIM$(STR$(opt_mon_dicespeed))
    PRINT #f, "dice3d " + _TRIM$(STR$(opt_dice3d))
    PRINT #f, "mondice3d " + _TRIM$(STR$(opt_mon_dice3d))
    PRINT #f, "dice3dset " + _TRIM$(STR$(opt_dice3d_set))
    PRINT #f, "mondice3dset " + _TRIM$(STR$(opt_mon_dice3d_set))
    PRINT #f, "dicefont " + _TRIM$(STR$(opt_dicefont))
    PRINT #f, "solomode " + _TRIM$(STR$(opt_solomode))
    PRINT #f, "solomins " + _TRIM$(STR$(opt_solomins))
    PRINT #f, "sfxpack " + opt_sfxpack             ' audio pack subdir names ("" = flat main dir)
    PRINT #f, "musicpack " + opt_musicpack
    PRINT #f, "narration " + _TRIM$(STR$(opt_narration))
    PRINT #f, "narrationpack " + opt_narrationpack
    PRINT #f, "narrfreq " + _TRIM$(STR$(opt_narrfreq))
    PRINT #f, "artpack " + opt_artpack
    PRINT #f, "ansipack " + opt_ansipack
    PRINT #f, "datapack " + opt_datapack
    CLOSE #f
END SUB


SUB LoadSettings
    DIM f AS INTEGER, ln AS STRING, k AS STRING, v AS INTEGER, sp AS INTEGER, vs AS STRING
    IF NOT _FILEEXISTS("gameplay-data-saves/dungeon-settings.dat") THEN EXIT SUB
    f = FREEFILE
    OPEN "gameplay-data-saves/dungeon-settings.dat" FOR INPUT AS #f
    DO WHILE NOT EOF(f)
        LINE INPUT #f, ln
        sp = INSTR(ln, " ")
        IF sp > 0 THEN
            k = LEFT$(ln, sp - 1): v = VAL(MID$(ln, sp + 1)): vs = _TRIM$(MID$(ln, sp + 1))
            SELECT CASE k
                CASE "music": opt_music = v
                CASE "sfx": opt_sfx = v
                CASE "voice": opt_voice = v
                CASE "showdice": opt_showdice = v
                CASE "fullscreen": opt_fullscreen = v
                CASE "musicvol": opt_musicvol = v
                CASE "sfxvol": opt_sfxvol = v
                CASE "voicevol": opt_voicevol = v
                CASE "duckamt": opt_duckamt = v
                CASE "realdice": opt_realdice = v
                CASE "dicemath": opt_dicemath = v
                CASE "oldschool": opt_oldschool = v
                CASE "tactical": opt_tactical = v
                CASE "audiopref": opt_audiopref = v
                CASE "heroicstats": opt_heroicstats = v
                CASE "flexstats": opt_flexstats = v
                CASE "boardgame": opt_boardgame = v
                CASE "movedice": opt_movedice = v
                CASE "artstyle": opt_artstyle = v
                CASE "gestures": opt_gestures = v
                CASE "juice": opt_juice = v
                CASE "fov": opt_fov = v
                CASE "players": num_players = v
                CASE "dicecolor": opt_dicecolor = v
                CASE "dicesolid": opt_dicesolid = v
                CASE "d6pips": opt_d6pips = v
                CASE "dicespeed": opt_dicespeed = v
                CASE "dicelight": opt_dicelight = v
                CASE "diceround": opt_diceround = v
                CASE "bloodstrength": opt_bloodstrength = v
                CASE "smoothamt": opt_smoothamt = v
                ' pre-0-3 files stored a BOOLEAN "smooth" -- carry it over as medium rather
                ' than silently dropping the player's preference
                CASE "smooth": IF v <> 0 THEN opt_smoothamt = 2 ELSE opt_smoothamt = 0
                CASE "combatspeed": opt_combatspeed = v
                CASE "msgdelay": opt_msgdelay = v
                CASE "hardcore": opt_hardcore = v
                CASE "critfumble": opt_critfumble = v
                CASE "lootrecovery": opt_lootrecovery = v
                CASE "maxdeaths": opt_maxdeaths = v
                CASE "mondicecolor": opt_mon_dicecolor = v
                CASE "mondicesolid": opt_mon_dicesolid = v
                CASE "mond6pips": opt_mon_d6pips = v
                CASE "mondicespeed": opt_mon_dicespeed = v
                CASE "dice3d": opt_dice3d = v
                CASE "mondice3d": opt_mon_dice3d = v
                CASE "dice3dset": opt_dice3d_set = v
                CASE "mondice3dset": opt_mon_dice3d_set = v
                CASE "dicefont": opt_dicefont = v
                CASE "solomode": opt_solomode = v
                CASE "solomins": opt_solomins = v
                CASE "sfxpack": opt_sfxpack = vs        ' string value (subdir name; validated in ScanAllPacks)
                CASE "musicpack": opt_musicpack = vs
                CASE "narration": opt_narration = v
                CASE "narrationpack": opt_narrationpack = vs
                CASE "narrfreq": opt_narrfreq = v
                CASE "artpack": opt_artpack = vs
                CASE "ansipack": opt_ansipack = vs
                CASE "datapack": opt_datapack = vs
            END SELECT
        END IF
    LOOP
    CLOSE #f
    ' sanity clamps
    IF num_players < 1 THEN num_players = 1
    IF num_players > 4 THEN num_players = 4
    IF opt_maxdeaths < 1 THEN opt_maxdeaths = 3
    IF opt_maxdeaths > 9 THEN opt_maxdeaths = 9
    opt_musicvol = Clamp10(opt_musicvol)
    opt_sfxvol = Clamp10(opt_sfxvol)
    opt_voicevol = Clamp10(opt_voicevol)
    IF opt_dicecolor < 0 OR opt_dicecolor > 5 THEN opt_dicecolor = 1
    IF opt_dicespeed < 0 OR opt_dicespeed > 3 THEN opt_dicespeed = 1
    IF opt_dicelight < 0 OR opt_dicelight > 3 THEN opt_dicelight = 2
    IF opt_diceround < 0 OR opt_diceround > 10 THEN opt_diceround = 6
    IF opt_bloodstrength < 0 OR opt_bloodstrength > 10 THEN opt_bloodstrength = 10
    IF opt_combatspeed < 0 OR opt_combatspeed > 3 THEN opt_combatspeed = 1
    IF num_players > 1 THEN opt_boardgame = TRUE   ' multiplayer requires it
END SUB
