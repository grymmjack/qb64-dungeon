' ============================================================================
'  LORDS.bas -- persistent hall of fame + character load (dungeon-lords.dat)
' ============================================================================

' Append a victorious champion to the hall-of-fame file.
SUB SaveLord (nm AS STRING, klass AS STRING, gld AS LONG, secs AS LONG)
    DIM f AS INTEGER
    f = FREEFILE
    OPEN "dungeon-lords.dat" FOR APPEND AS #f
    PRINT #f, CHR$(34); nm; CHR$(34); ","; CHR$(34); klass; CHR$(34); ","; gld; ","; secs
    CLOSE #f
END SUB


' Load the hall of fame into the passed arrays, sorted by gold (desc). Returns count.
FUNCTION ReadLords% (nm() AS STRING, klass() AS STRING, gld() AS LONG, secs() AS LONG)
    DIM f AS INTEGER, n AS INTEGER, i AS INTEGER, j AS INTEGER
    DIM tn AS STRING, tc AS STRING, tg AS LONG, ts AS LONG
    n = 0
    IF NOT _FILEEXISTS("dungeon-lords.dat") THEN ReadLords = 0: EXIT FUNCTION
    f = FREEFILE
    OPEN "dungeon-lords.dat" FOR INPUT AS #f
    DO WHILE NOT EOF(f)
        IF n >= UBOUND(nm) THEN EXIT DO
        INPUT #f, tn, tc, tg, ts
        n = n + 1
        nm(n) = tn: klass(n) = tc: gld(n) = tg: secs(n) = ts
    LOOP
    CLOSE #f
    FOR i = 1 TO n - 1
        FOR j = 1 TO n - i
            IF gld(j) < gld(j + 1) THEN
                SWAP nm(j), nm(j + 1): SWAP klass(j), klass(j + 1)
                SWAP gld(j), gld(j + 1): SWAP secs(j), secs(j + 1)
            END IF
        NEXT j
    NEXT i
    ReadLords = n
END FUNCTION


' Pad a string on the right to width w (for simple table columns).
FUNCTION PadR$ (s AS STRING, w AS INTEGER)
    IF LEN(s) >= w THEN PadR$ = LEFT$(s, w) ELSE PadR$ = s + SPACE$(w - LEN(s))
END FUNCTION


' Seconds -> mm:ss.
FUNCTION MMSS$ (secs AS LONG)
    MMSS$ = _TRIM$(STR$(secs \ 60)) + ":" + RIGHT$("0" + _TRIM$(STR$(secs MOD 60)), 2)
END FUNCTION


' Class name -> CLASSES index (1..4), default HERO.
FUNCTION ClassIndex% (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO 4
        IF UCASE$(nm) = UCASE$(CLASSES(i).name) THEN ClassIndex = i: EXIT FUNCTION
    NEXT i
    ClassIndex = 1
END FUNCTION


' LEGENDARY LORDS screen (menu option 4): the hall of fame.
SUB ShowLords
    DIM nm(1 TO 200) AS STRING, klass(1 TO 200) AS STRING, gld(1 TO 200) AS LONG, secs(1 TO 200) AS LONG
    DIM n AS INTEGER, i AS INTEGER, y AS INTEGER
    n = ReadLords(nm(), klass(), gld(), secs())
    _DEST CANVAS: _FONT CH: CLS , BLACK
    COLOR YELLOWU, BLACK: PrintCentered 5, "-=  L E G E N D A R Y   L O R D S  =-"
    IF n = 0 THEN
        COLOR GREY, BLACK: PrintCentered 20, "No champions yet -- be the first to escape the dungeon alive!"
    ELSE
        COLOR CYANU, BLACK
        _PRINTSTRING (34 * CW, 8 * CH), "#   " + PadR$("NAME", 16) + PadR$("CLASS", 12) + PadR$("GOLD", 8) + "TIME"
        FOR i = 1 TO n
            IF i > 14 THEN EXIT FOR
            y = 9 + i
            IF i = 1 THEN COLOR YELLOWU, BLACK ELSE COLOR WHITE, BLACK
            _PRINTSTRING (34 * CW, y * CH), PadR$(_TRIM$(STR$(i)) + ".", 4) + PadR$(nm(i), 16) + PadR$(klass(i), 12) + PadR$(_TRIM$(STR$(gld(i))), 8) + MMSS$(secs(i))
        NEXT i
    END IF
    COLOR YELLOWU, BLACK: PrintCentered 46, "[ press any key ]"
    _DISPLAY
    WaitKey
END SUB


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
        _DISPLAY
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
        _DISPLAY
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                EXIT DO
            ELSEIF k = CHR$(8) THEN
                IF LEN(nm) > 0 THEN nm = LEFT$(nm, LEN(nm) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                IF chcode >= 32 AND chcode <= 126 AND LEN(nm) < 14 THEN nm = nm + k
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
    OPEN "dungeon-settings.dat" FOR OUTPUT AS #f
    PRINT #f, "music " + _TRIM$(STR$(opt_music))
    PRINT #f, "sfx " + _TRIM$(STR$(opt_sfx))
    PRINT #f, "voice " + _TRIM$(STR$(opt_voice))
    PRINT #f, "showdice " + _TRIM$(STR$(opt_showdice))
    PRINT #f, "fullscreen " + _TRIM$(STR$(opt_fullscreen))
    PRINT #f, "musicvol " + _TRIM$(STR$(opt_musicvol))
    PRINT #f, "sfxvol " + _TRIM$(STR$(opt_sfxvol))
    PRINT #f, "voicevol " + _TRIM$(STR$(opt_voicevol))
    PRINT #f, "realdice " + _TRIM$(STR$(opt_realdice))
    PRINT #f, "dicemath " + _TRIM$(STR$(opt_dicemath))
    PRINT #f, "oldschool " + _TRIM$(STR$(opt_oldschool))
    PRINT #f, "heroicstats " + _TRIM$(STR$(opt_heroicstats))
    PRINT #f, "boardgame " + _TRIM$(STR$(opt_boardgame))
    PRINT #f, "fov " + _TRIM$(STR$(opt_fov))
    PRINT #f, "players " + _TRIM$(STR$(num_players))
    PRINT #f, "dicecolor " + _TRIM$(STR$(opt_dicecolor))
    PRINT #f, "dicesolid " + _TRIM$(STR$(opt_dicesolid))
    PRINT #f, "d6pips " + _TRIM$(STR$(opt_d6pips))
    PRINT #f, "dicespeed " + _TRIM$(STR$(opt_dicespeed))
    PRINT #f, "smooth " + _TRIM$(STR$(opt_smooth))
    PRINT #f, "combatspeed " + _TRIM$(STR$(opt_combatspeed))
    CLOSE #f
END SUB


SUB LoadSettings
    DIM f AS INTEGER, ln AS STRING, k AS STRING, v AS INTEGER, sp AS INTEGER
    IF NOT _FILEEXISTS("dungeon-settings.dat") THEN EXIT SUB
    f = FREEFILE
    OPEN "dungeon-settings.dat" FOR INPUT AS #f
    DO WHILE NOT EOF(f)
        LINE INPUT #f, ln
        sp = INSTR(ln, " ")
        IF sp > 0 THEN
            k = LEFT$(ln, sp - 1): v = VAL(MID$(ln, sp + 1))
            SELECT CASE k
                CASE "music": opt_music = v
                CASE "sfx": opt_sfx = v
                CASE "voice": opt_voice = v
                CASE "showdice": opt_showdice = v
                CASE "fullscreen": opt_fullscreen = v
                CASE "musicvol": opt_musicvol = v
                CASE "sfxvol": opt_sfxvol = v
                CASE "voicevol": opt_voicevol = v
                CASE "realdice": opt_realdice = v
                CASE "dicemath": opt_dicemath = v
                CASE "oldschool": opt_oldschool = v
                CASE "heroicstats": opt_heroicstats = v
                CASE "boardgame": opt_boardgame = v
                CASE "fov": opt_fov = v
                CASE "players": num_players = v
                CASE "dicecolor": opt_dicecolor = v
                CASE "dicesolid": opt_dicesolid = v
                CASE "d6pips": opt_d6pips = v
                CASE "dicespeed": opt_dicespeed = v
                CASE "smooth": opt_smooth = v
                CASE "combatspeed": opt_combatspeed = v
            END SELECT
        END IF
    LOOP
    CLOSE #f
    ' sanity clamps
    IF num_players < 1 THEN num_players = 1
    IF num_players > 4 THEN num_players = 4
    opt_musicvol = Clamp10(opt_musicvol)
    opt_sfxvol = Clamp10(opt_sfxvol)
    opt_voicevol = Clamp10(opt_voicevol)
    IF opt_dicecolor < 0 OR opt_dicecolor > 5 THEN opt_dicecolor = 1
    IF opt_dicespeed < 0 OR opt_dicespeed > 3 THEN opt_dicespeed = 1
    IF opt_combatspeed < 0 OR opt_combatspeed > 3 THEN opt_combatspeed = 1
    IF num_players > 1 THEN opt_boardgame = TRUE   ' multiplayer requires it
END SUB
