' ============================================================================
'  game/PACKBROWSE.bas -- the PACK BROWSER.
'
'      dungeon.run packbrowse      or  SETTINGS -> [B]
'
'  There are six kinds of content pack here (art, sfx, music, narration, data,
'  ansi art) and SETTINGS offers each of them as a row you cycle with the arrow
'  keys. That row can tell you a pack's NAME and nothing else -- so choosing one
'  means picking a name, restarting, and finding out.
'
'  This shows what is actually in them:
'
'    ART       four sprites drawn FROM THAT PACK, plus how many files it ships
'    SFX       how much of the effect roster it covers, and [P] plays one
'    MUSIC     its tracks, and [P] plays one
'    the rest  what it ships and therefore what it overrides
'
'  THE IMPORTANT DETAIL: previews resolve inside ONE pack, never through the
'  normal resolver. The resolver's whole job is to fall back to default/ per
'  file, which is right for playing the game and a lie in a browser -- every
'  pack would preview as complete, including an empty one. PackArtDirect$ and
'  FirstAudioFile$ are pointed at a single directory on purpose.
'
'  Lives in game/ rather than engine/ because what counts as coverage is this
'  game's roster (Game_SfxNames$) and the four sample sprites are this game's
'  categories. A different game would want its own four.
' ============================================================================

CONST PB_TYPES = 6

SUB PackBrowse
    DIM k AS STRING, quit AS INTEGER, snap AS LONG, live AS INTEGER

    live = screen_shown
    IF live THEN
        snap = _NEWIMAGE(SW * CW, SH * CH, 32)
        _PUTIMAGE (0, 0), CANVAS, snap
    END IF

    ScanAllPacks
    ScanArtPacks
    ScanDataPacks
    ScanAnsiPacks
    IF PB_TYPE < 1 THEN PB_TYPE = 1
    PB_SEL = PackSelIndex%(PB_TYPE)

    DO
        PackBrowsePaint
        Present

        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: PB_SEL = PB_SEL - 1
                CASE 80: PB_SEL = PB_SEL + 1
                CASE 75: PB_TYPE = PB_TYPE - 1: PB_SEL = 1
                CASE 77: PB_TYPE = PB_TYPE + 1: PB_SEL = 1
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            SELECT CASE LCASE$(k)
                CASE CHR$(9): PB_TYPE = PB_TYPE + 1: PB_SEL = 1
                CASE "p": PackAudition
                CASE CHR$(13): PackApply
                CASE CHR$(27): quit = TRUE
            END SELECT
        END IF

        IF PB_TYPE < 1 THEN PB_TYPE = PB_TYPES
        IF PB_TYPE > PB_TYPES THEN PB_TYPE = 1
        IF PB_SEL < 1 THEN PB_SEL = PackCount%(PB_TYPE)
        IF PB_SEL > PackCount%(PB_TYPE) THEN PB_SEL = 1
        IF quit THEN EXIT DO
        _LIMIT 30
    LOOP

    RetireWind                                  ' an audition must not outlive the screen
    IF live THEN
        _PUTIMAGE (0, 0), snap, CANVAS
        _FREEIMAGE snap
    END IF
END SUB

' ----------------------------------------------------------------------------
'  The six pack kinds, behind one interface so the screen has one shape
' ----------------------------------------------------------------------------
FUNCTION PackTypeName$ (t AS INTEGER)
    SELECT CASE t
        CASE 1: PackTypeName$ = "ART"
        CASE 2: PackTypeName$ = "SFX"
        CASE 3: PackTypeName$ = "MUSIC"
        CASE 4: PackTypeName$ = "NARRATION"
        CASE 5: PackTypeName$ = "DATA"
        CASE ELSE: PackTypeName$ = "ANSI ART"
    END SELECT
END FUNCTION

FUNCTION PackCount% (t AS INTEGER)
    SELECT CASE t
        CASE 1: PackCount% = ARTPACK_N
        CASE 2: PackCount% = SFXPACK_N
        CASE 3: PackCount% = MUSICPACK_N
        CASE 4: PackCount% = NARRPACK_N
        CASE 5: PackCount% = DATAPACK_N
        CASE ELSE: PackCount% = ANSIPACK_N
    END SELECT
END FUNCTION

FUNCTION PackNameAt$ (t AS INTEGER, i AS INTEGER)
    SELECT CASE t
        CASE 1: PackNameAt$ = _TRIM$(ARTPACKS(i))
        CASE 2: PackNameAt$ = _TRIM$(SFXPACKS(i))
        CASE 3: PackNameAt$ = _TRIM$(MUSICPACKS(i))
        CASE 4: PackNameAt$ = _TRIM$(NARRPACKS(i))
        CASE 5: PackNameAt$ = _TRIM$(DATAPACKS(i))
        CASE ELSE: PackNameAt$ = _TRIM$(ANSIPACKS(i))
    END SELECT
END FUNCTION

'--- the directory a pack's files live in ---
FUNCTION PackDir$ (t AS INTEGER, i AS INTEGER)
    DIM nm AS STRING
    nm = PackNameAt$(t, i)
    IF LEN(nm) = 0 THEN nm = "default"
    SELECT CASE t
        CASE 1: PackDir$ = "assets/pixel-art/" + nm + "/"
        CASE 2: PackDir$ = "assets/sfx/" + nm + "/"
        CASE 3: PackDir$ = "assets/music/" + nm + "/"
        CASE 4: PackDir$ = "assets/narration/" + nm + "/"
        CASE 5: PackDir$ = "assets/data/" + nm + "/"
        CASE ELSE: PackDir$ = "assets/ansi-art/" + nm + "/"
    END SELECT
END FUNCTION

'--- which one is live right now, so the list can say so ---
FUNCTION PackSelIndex% (t AS INTEGER)
    DIM i AS INTEGER, cur AS STRING
    SELECT CASE t
        CASE 1: cur = _TRIM$(opt_artpack)
        CASE 2: cur = _TRIM$(opt_sfxpack)
        CASE 3: cur = _TRIM$(opt_musicpack)
        CASE 4: cur = _TRIM$(opt_narrationpack)
        CASE 5: cur = _TRIM$(opt_datapack)
        CASE ELSE: cur = _TRIM$(opt_ansipack)
    END SELECT
    PackSelIndex% = 1
    FOR i = 1 TO PackCount%(t)
        IF LCASE$(PackNameAt$(t, i)) = LCASE$(cur) THEN PackSelIndex% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

'--- Selecting takes effect where that pack type takes effect: audio and art
'    reload now, data and ansi art are read once at startup and so cannot. Say
'    which, rather than pretending they are the same. ---
SUB PackApply
    DIM nm AS STRING
    nm = PackNameAt$(PB_TYPE, PB_SEL)
    IF LEN(nm) = 0 THEN nm = "default"
    SELECT CASE PB_TYPE
        CASE 1: opt_artpack = nm: PB_MSG = "art pack: " + nm
        CASE 2: opt_sfxpack = nm: ReloadSfxPack: PB_MSG = "sfx pack: " + nm
        CASE 3: opt_musicpack = nm: PlayLevelMusic PlayerLevel%: PB_MSG = "music pack: " + nm
        CASE 4: opt_narrationpack = nm: PB_MSG = "narration pack: " + nm
        CASE 5: opt_datapack = nm: PB_MSG = "data pack: " + nm + "  (applies on next launch)"
        CASE ELSE: opt_ansipack = nm: PB_MSG = "ansi art pack: " + nm + "  (applies on next launch)"
    END SELECT
    SaveSettings
END SUB

' ----------------------------------------------------------------------------
'  Auditioning -- open the file in THIS pack and play it
'
'  Opened directly rather than through Sfx, which would resolve through the
'  SELECTED pack and play the wrong thing: the entire question here is what the
'  pack under the cursor sounds like, not the one already chosen.
' ----------------------------------------------------------------------------
SUB PackAudition
    DIM p AS STRING, d AS STRING, e AS STRING, n AS INTEGER

    IF audio_muted THEN PB_MSG = "audio is muted": EXIT SUB
    d = PackDir$(PB_TYPE, PB_SEL)

    SELECT CASE PB_TYPE
        CASE 2: p = FirstAudioFile$(d + PackSampleSfx$(d))
        CASE 3, 4: p = PackFirstAudioIn$(d)
        CASE ELSE: PB_MSG = "nothing to hear in a " + PackTypeName$(PB_TYPE) + " pack": EXIT SUB
    END SELECT

    IF LEN(p) = 0 THEN PB_MSG = "nothing to play in " + d: EXIT SUB

    RetireWind
    PB_SND = _SNDOPEN(p)
    IF PB_SND > 0 THEN
        _SNDVOL PB_SND, opt_sfxvol / 10
        _SNDPLAY PB_SND
        PB_MSG = "playing " + p
    ELSE
        PB_MSG = "could not open " + p
    END IF
END SUB

'--- park the audition handle. Never _SNDCLOSE here: RetireSound is the only
'    safe way to let go of a handle the mixer thread may still be reading. ---
SUB RetireWind
    IF PB_SND > 0 THEN RetireSound PB_SND: PB_SND = 0
END SUB

'--- the first roster effect this pack actually ships, so the audition is never
'    a file that does not exist ---
FUNCTION PackSampleSfx$ (d AS STRING)
    DIM lst AS STRING, i AS INTEGER, p AS INTEGER, nm AS STRING
    lst = Game_SfxNames$ + " ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN
                IF LEN(FirstAudioFile$(d + nm)) > 0 THEN PackSampleSfx$ = nm: EXIT FUNCTION
            END IF
        END IF
    NEXT i
END FUNCTION

FUNCTION PackFirstAudioIn$ (d AS STRING)
    DIM e AS STRING
    IF _DIREXISTS(d) = 0 THEN EXIT FUNCTION
    e = _FILES$(d)
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) <> "/" THEN
            IF IsAudioExt%(e) THEN PackFirstAudioIn$ = d + e: EXIT FUNCTION
        END IF
        e = _FILES$
    LOOP
END FUNCTION

' ----------------------------------------------------------------------------
'  Counting -- how much of the roster a pack covers
' ----------------------------------------------------------------------------
FUNCTION PackSfxCoverage% (d AS STRING, tot AS INTEGER)
    DIM lst AS STRING, i AS INTEGER, p AS INTEGER, nm AS STRING, have AS INTEGER
    lst = Game_SfxNames$ + " ": p = 1
    tot = 0
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN
                tot = tot + 1
                IF LEN(FirstAudioFile$(d + nm)) > 0 THEN have = have + 1
            END IF
        END IF
    NEXT i
    PackSfxCoverage% = have
END FUNCTION

'--- how many files a directory holds, recursing one level (art packs mirror
'    the category layout, so everything real is one level down) ---
FUNCTION PackFileCount% (d AS STRING)
    DIM e AS STRING, n AS INTEGER, subs(1 TO 64) AS STRING, ns AS INTEGER, i AS INTEGER
    IF _DIREXISTS(d) = 0 THEN EXIT FUNCTION
    e = _FILES$(d)
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) = "/" THEN
            IF e <> "./" _ANDALSO e <> "../" _ANDALSO ns < 64 THEN ns = ns + 1: subs(ns) = e
        ELSE
            n = n + 1
        END IF
        e = _FILES$
    LOOP
    '--- the walk cannot be re-entered while it is running, which is why the
    '    subdirectories are collected first and descended afterwards ---
    FOR i = 1 TO ns
        e = _FILES$(d + subs(i))
        DO WHILE LEN(e) > 0
            IF RIGHT$(e, 1) <> "/" THEN n = n + 1
            e = _FILES$
        LOOP
    NEXT i
    PackFileCount% = n
END FUNCTION

'--- Resolve a sprite INSIDE one pack, with no fallback. The normal resolver
'    falls back to default/ per file, which would make every pack -- including
'    an empty one -- preview as complete. ---
FUNCTION PackArtDirect$ (d AS STRING, subpath AS STRING)
    DIM p AS STRING
    p = d + subpath + ".png"
    IF _FILEEXISTS(p) THEN PackArtDirect$ = p
END FUNCTION

' ----------------------------------------------------------------------------
'  Drawing
' ----------------------------------------------------------------------------
SUB PackBrowsePaint
    DIM i AS INTEGER, y AS INTEGER, nm AS STRING, cur AS INTEGER
    DIM bg AS _UNSIGNED LONG, t AS INTEGER

    bg = _RGB32(&H08, &H0A, &H14)
    _DEST CANVAS
    CLS , bg

    t = PB_TYPE
    cur = PackSelIndex%(t)

    COLOR Thm~&("ui.cyan", _RGB32(&H55, &HFF, &HFF)), bg
    _PRINTSTRING (2 * CW, CH), "-=  P A C K   B R O W S E R  =-"
    COLOR Thm~&("ui.yellow", _RGB32(&HFF, &HFF, &H55)), bg
    _PRINTSTRING (40 * CW, CH), "[TAB / left-right]  " + PackTypeName$(t) + "  (" + LTRIM$(STR$(PackCount%(t))) + " packs)"

    '--- the list ---
    '--- from 1: index 0 is the legacy flat-directory slot from before every pack
    '    became a named folder (`default` included). Listing it shows a second
    '    row also called "default" that resolves to the same files. ---
    FOR i = 1 TO PackCount%(t)
        y = 3 + i
        IF y > SH - 6 THEN EXIT FOR
        nm = PackNameAt$(t, i)
        IF LEN(nm) = 0 THEN nm = "default"
        IF i = PB_SEL THEN
            LINE (2 * CW, y * CH)-(34 * CW, y * CH + CH - 1), _RGB32(&H1E, &H2C, &H46), BF
            COLOR _RGB32(&HFF, &HFF, &HD2), bg
            _PRINTSTRING (2 * CW, y * CH), CHR$(16) + " " + nm
        ELSE
            COLOR _RGB32(&HA5, &HAF, &HBE), bg
            _PRINTSTRING (4 * CW, y * CH), nm
        END IF
        IF i = cur THEN
            COLOR Thm~&("ui.green", _RGB32(&H55, &HFF, &H55)), bg
            _PRINTSTRING (30 * CW, y * CH), "LIVE"
        END IF
    NEXT i

    PackPreviewPaint t, PB_SEL

    '--- status ---
    LINE (0, (SH - 3) * CH)-(SW * CW - 1, SH * CH - 1), _RGB32(&H12, &H16, &H20), BF
    COLOR Thm~&("ui.yellow", _RGB32(&HFF, &HFF, &H55)), _RGB32(&H12, &H16, &H20)
    IF LEN(PB_MSG) > 0 THEN _PRINTSTRING (2 * CW, (SH - 3) * CH), PB_MSG
    COLOR _RGB32(&H82, &H8C, &HA0), _RGB32(&H12, &H16, &H20)
    _PRINTSTRING (2 * CW, (SH - 2) * CH), "[up/down] pack   [TAB] kind   [P] hear it   [ENTER] use this pack   [ESC] back"
END SUB

SUB PackPreviewPaint (t AS INTEGER, i AS INTEGER)
    DIM d AS STRING, n AS INTEGER, have AS INTEGER, tot AS INTEGER
    DIM bg AS _UNSIGNED LONG, x AS INTEGER, y AS INTEGER

    bg = _RGB32(&H08, &H0A, &H14)
    d = PackDir$(t, i)
    x = 38: y = 4

    LINE (x * CW, y * CH)-((SW - 3) * CW, (SH - 5) * CH), _RGB32(&H10, &H14, &H1E), BF
    LINE (x * CW, y * CH)-((SW - 3) * CW, (SH - 5) * CH), _RGB32(&H2A, &H3A, &H52), B

    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H10, &H14, &H1E)
    _PRINTSTRING ((x + 2) * CW, (y + 1) * CH), d
    n = PackFileCount%(d)
    COLOR _RGB32(&HA5, &HAF, &HBE), _RGB32(&H10, &H14, &H1E)
    _PRINTSTRING ((x + 2) * CW, (y + 2) * CH), LTRIM$(STR$(n)) + " file(s)"

    SELECT CASE t
        CASE 1: PackArtPreview d, x, y + 4
        CASE 2
            have = PackSfxCoverage%(d, tot)
            PackBar x + 2, y + 4, have, tot, "effects"
            COLOR _RGB32(&HA5, &HAF, &HBE), _RGB32(&H10, &H14, &H1E)
            _PRINTSTRING ((x + 2) * CW, (y + 7) * CH), "anything it does not ship falls back to default/,"
            _PRINTSTRING ((x + 2) * CW, (y + 8) * CH), "per file -- a partial pack is a legitimate pack."
            _PRINTSTRING ((x + 2) * CW, (y + 10) * CH), "[P] plays one of ITS sounds, not the live pack's."
        CASE 3, 4
            COLOR _RGB32(&HA5, &HAF, &HBE), _RGB32(&H10, &H14, &H1E)
            _PRINTSTRING ((x + 2) * CW, (y + 4) * CH), "[P] plays the first track in this pack."
            PackListFiles d, x + 2, y + 6, 12
        CASE ELSE
            PackListFiles d, x + 2, y + 4, 14
    END SELECT
END SUB

'--- Four sprites, drawn from THIS pack only. A pack that ships none of them
'    shows four empty frames, which is the honest answer and the one the normal
'    resolver could never give. ---
SUB PackArtPreview (d AS STRING, x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER, p AS STRING, h AS LONG, px AS INTEGER, py AS INTEGER
    DIM sub4(1 TO 4) AS STRING, nm(1 TO 4) AS STRING

    '--- one from each category the eye reads differently ---
    sub4(1) = "monsters/humanoids/evil-wizard": nm(1) = "monster"
    sub4(2) = "treasures/crown-of-gems": nm(2) = "treasure"
    sub4(3) = "classes/hero": nm(3) = "class"
    sub4(4) = "items/sword": nm(4) = "item"

    FOR i = 1 TO 4
        px = x + 2 + ((i - 1) MOD 2) * 22
        py = y + ((i - 1) \ 2) * 12

        LINE (px * CW, py * CH)-((px + 18) * CW, (py + 10) * CH), _RGB32(&H18, &H1E, &H2A), BF
        LINE (px * CW, py * CH)-((px + 18) * CW, (py + 10) * CH), _RGB32(&H2A, &H3A, &H52), B

        p = PackArtDirect$(d, sub4(i))
        IF LEN(p) > 0 THEN
            h = _LOADIMAGE(p, 32)
            IF h < -1 THEN
                _PUTIMAGE ((px + 1) * CW, (py + 1) * CH)-((px + 17) * CW, (py + 9) * CH), h, CANVAS
                _FREEIMAGE h
            END IF
            COLOR _RGB32(&H55, &HFF, &H55), _RGB32(&H10, &H14, &H1E)
        ELSE
            COLOR _RGB32(&H60, &H66, &H76), _RGB32(&H18, &H1E, &H2A)
            _PRINTSTRING ((px + 6) * CW, (py + 5) * CH), "(default)"
            COLOR _RGB32(&H60, &H66, &H76), _RGB32(&H10, &H14, &H1E)
        END IF
        _PRINTSTRING (px * CW, (py + 10) * CH), nm(i)
    NEXT i
END SUB

SUB PackBar (x AS INTEGER, y AS INTEGER, have AS INTEGER, tot AS INTEGER, what AS STRING)
    DIM w AS INTEGER, f AS INTEGER, bg AS _UNSIGNED LONG
    bg = _RGB32(&H10, &H14, &H1E)
    w = 40
    IF tot > 0 THEN f = (have * w) \ tot
    LINE (x * CW, y * CH)-((x + w) * CW, y * CH + CH - 1), _RGB32(&H22, &H28, &H36), BF
    IF f > 0 THEN LINE (x * CW, y * CH)-((x + f) * CW, y * CH + CH - 1), _RGB32(&H3C, &HB0, &H70), BF
    COLOR _RGB32(&HFF, &HFF, &HFF), bg
    _PRINTSTRING (x * CW, (y + 2) * CH), LTRIM$(STR$(have)) + " of " + LTRIM$(STR$(tot)) + " " + what
END SUB

SUB PackListFiles (d AS STRING, x AS INTEGER, y AS INTEGER, maxn AS INTEGER)
    DIM e AS STRING, n AS INTEGER, bg AS _UNSIGNED LONG
    bg = _RGB32(&H10, &H14, &H1E)
    COLOR _RGB32(&HA5, &HAF, &HBE), bg
    IF _DIREXISTS(d) = 0 THEN _PRINTSTRING (x * CW, y * CH), "(no such directory)": EXIT SUB
    e = _FILES$(d)
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) <> "/" THEN
            IF n < maxn THEN
                _PRINTSTRING (x * CW, (y + n) * CH), LEFT$(e, 60)
                n = n + 1
            END IF
        END IF
        e = _FILES$
    LOOP
    IF n = 0 THEN _PRINTSTRING (x * CW, y * CH), "(empty)"
END SUB

'--- headless: one frame of a chosen kind, so the browser can be checked ---
SUB PackBrowseShot (t AS INTEGER, i AS INTEGER, outp AS STRING)
    DIM d AS LONG
    ScanAllPacks
    ScanArtPacks
    ScanDataPacks
    ScanAnsiPacks
    PB_TYPE = t
    PB_SEL = i
    PackBrowsePaint
    _SAVEIMAGE outp, CANVAS
    d = _DEST: _DEST _CONSOLE
    PRINT PipeCol$("|15packbrowse|07 -- " + PackTypeName$(t) + " pack |14" + LTRIM$(STR$(i)) + _
                   "|07 (" + PackNameAt$(t, i) + ") -> |10" + outp + "|07")
    _DEST d
END SUB
