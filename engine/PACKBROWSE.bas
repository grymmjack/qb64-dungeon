' ============================================================================
'  engine/PACKBROWSE.bas -- the PACK BROWSER.
'
'      dungeon.run packbrowse        (or [B] from SETTINGS)
'
'  A content pack can be offered as a NAME and nothing else, which means picking
'  one is picking a word, restarting, and finding out. This shows what is in
'  them: the art drawn, the roster coverage as a bar, the files listed, and [P]
'  to hear one.
'
'  ENGINE, because "what packs exist and what is in them" is not a question about
'  DUNGEON!. The KINDS come from the asset registry -- every tree declared with
'  AssetKindPacked is browsable, so a host that declares a seventh gets it for
'  free and the browser carries no list of its own.
'
'  THE DETAIL THAT MAKES IT HONEST: previews resolve inside ONE directory, never
'  through the normal resolver. The resolver's whole job is to fall back to
'  `default` per file, which is right for playing and a lie in a browser -- every
'  pack, including an empty one, would preview as complete.
'
'  Four things only the host knows, and they are hooks:
'    Game_PackSelected$   which pack of this kind is live
'    Game_PackSelect      make this one live (and re-apply it)
'    Game_PackSample$     a sprite worth previewing, by slot
'    Game_PackRoster$     what a pack of this kind ought to ship ("" = unknown)
' ============================================================================

'--- the browsable kinds are the PACKED kinds, in declaration order ---
FUNCTION PackTypeName$ (t AS INTEGER)
    PackTypeName$ = UCASE$(AssetPackedName$(t))
END FUNCTION

FUNCTION PackKindOf$ (t AS INTEGER)
    PackKindOf$ = AssetPackedName$(t)
END FUNCTION

FUNCTION PackTypeCount%
    PackTypeCount% = AssetPackedCount%
END FUNCTION

'--- the packs of a kind, cached per kind so the directory is walked once ---
SUB PackScan (t AS INTEGER)
    DIM lst AS STRING, i AS INTEGER, p AS INTEGER
    IF PB_SCANNED = t THEN EXIT SUB
    PB_SCANNED = t
    PB_N = 0
    lst = AssetPackList$(PackKindOf$(t)) + " "
    p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            IF i > p _ANDALSO PB_N < UBOUND(PB_PACK) THEN
                PB_N = PB_N + 1
                PB_PACK(PB_N) = MID$(lst, p, i - p)
            END IF
            p = i + 1
        END IF
    NEXT i
END SUB

FUNCTION PackCount% (t AS INTEGER)
    PackScan t
    PackCount% = PB_N
END FUNCTION

FUNCTION PackNameAt$ (t AS INTEGER, i AS INTEGER)
    PackScan t
    IF i >= 1 _ANDALSO i <= PB_N THEN PackNameAt$ = PB_PACK(i)
END FUNCTION

FUNCTION PackDir$ (t AS INTEGER, i AS INTEGER)
    PackDir$ = AssetPackDir$(PackKindOf$(t), PackNameAt$(t, i))
END FUNCTION

'--- which one is live right now, so the list can say so ---
FUNCTION PackSelIndex% (t AS INTEGER)
    DIM i AS INTEGER, cur AS STRING
    cur = _TRIM$(Game_PackSelected$(PackKindOf$(t)))
    PackSelIndex% = 1
    FOR i = 1 TO PackCount%(t)
        IF LCASE$(PackNameAt$(t, i)) = LCASE$(cur) THEN PackSelIndex% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

SUB PackApply
    Game_PackSelect PackKindOf$(PB_TYPE), PackNameAt$(PB_TYPE, PB_SEL)
END SUB

'--- how much of what a pack of this kind OUGHT to ship, it does. An empty
'    roster means the host does not define one, and the bar is skipped. ---
FUNCTION PackCoverage% (t AS INTEGER, d AS STRING, tot AS INTEGER)
    DIM lst AS STRING, i AS INTEGER, p AS INTEGER, nm AS STRING, have AS INTEGER
    lst = _TRIM$(Game_PackRoster$(PackKindOf$(t)))
    tot = 0
    IF LEN(lst) = 0 THEN EXIT FUNCTION
    lst = lst + " ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN
                tot = tot + 1
                IF LEN(FirstAudioFile$(d + nm)) > 0 THEN have = have + 1
            END IF
        END IF
    NEXT i
    PackCoverage% = have
END FUNCTION

FUNCTION PackSampleSfx$ (t AS INTEGER, d AS STRING)
    DIM lst AS STRING, i AS INTEGER, p AS INTEGER, nm AS STRING
    lst = _TRIM$(Game_PackRoster$(PackKindOf$(t)))
    IF LEN(lst) = 0 THEN EXIT FUNCTION
    lst = lst + " ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN
                IF LEN(FirstAudioFile$(d + nm)) > 0 THEN PackSampleSfx$ = nm: EXIT FUNCTION
            END IF
        END IF
    NEXT i
END FUNCTION

SUB PackBrowse
    DIM k AS STRING, quit AS INTEGER, snap AS LONG, live AS INTEGER

    live = screen_shown
    IF live THEN
        snap = _NEWIMAGE(SW * CW, SH * CH, 32)
        _PUTIMAGE (0, 0), CANVAS, snap
    END IF

    PB_SCANNED = 0
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
                CASE 75: PB_TYPE = PB_TYPE - 1: PB_SEL = 1: PB_SCANNED = 0
                CASE 77: PB_TYPE = PB_TYPE + 1: PB_SEL = 1: PB_SCANNED = 0
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            SELECT CASE LCASE$(k)
                CASE CHR$(9): PB_TYPE = PB_TYPE + 1: PB_SEL = 1: PB_SCANNED = 0
                CASE "p": PackAudition
                CASE CHR$(13): PackApply
                CASE CHR$(27): quit = TRUE
            END SELECT
        END IF

        IF PB_TYPE < 1 THEN PB_TYPE = PackTypeCount%
        IF PB_TYPE > PackTypeCount% THEN PB_TYPE = 1
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

    IF LEN(Game_PackSample$(PackKindOf$(t), 1)) > 0 THEN
        PackArtPreview t, d, x, y + 4
    ELSEIF LEN(_TRIM$(Game_PackRoster$(PackKindOf$(t)))) > 0 THEN
        have = PackCoverage%(t, d, tot)
        PackBar x + 2, y + 4, have, tot, "entries"
        COLOR _RGB32(&HA5, &HAF, &HBE), _RGB32(&H10, &H14, &H1E)
        _PRINTSTRING ((x + 2) * CW, (y + 7) * CH), "anything it does not ship falls back to the default pack,"
        _PRINTSTRING ((x + 2) * CW, (y + 8) * CH), "per file -- a partial pack is a legitimate pack."
        _PRINTSTRING ((x + 2) * CW, (y + 10) * CH), "[P] plays one of ITS entries, not the live pack's."
    ELSE
        PackListFiles d, x + 2, y + 4, 14
    END IF
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


SUB PackAudition
    DIM p AS STRING, d AS STRING, e AS STRING, n AS INTEGER

    IF audio_muted THEN PB_MSG = "audio is muted": EXIT SUB
    d = PackDir$(PB_TYPE, PB_SEL)

    '--- a kind with a ROSTER auditions a named effect from it; any other kind
    '    plays whatever audio it has. A kind with no audio at all says so. ---
    IF LEN(_TRIM$(Game_PackRoster$(PackKindOf$(PB_TYPE)))) > 0 THEN
        p = FirstAudioFile$(d + PackSampleSfx$(PB_TYPE, d))
    ELSE
        p = PackFirstAudioIn$(d)
    END IF
    IF LEN(p) = 0 THEN PB_MSG = "nothing to hear in a " + PackTypeName$(PB_TYPE) + " pack": EXIT SUB

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


SUB RetireWind
    IF PB_SND > 0 THEN RetireSound PB_SND: PB_SND = 0
END SUB


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


FUNCTION PackArtDirect$ (d AS STRING, subpath AS STRING)
    DIM p AS STRING
    p = d + subpath + ".png"
    IF _FILEEXISTS(p) THEN PackArtDirect$ = p
END FUNCTION


SUB PackBrowseShot (t AS INTEGER, i AS INTEGER, outp AS STRING)
    DIM d AS LONG
    PB_SCANNED = 0
    PB_TYPE = t
    PB_SEL = i
    PackBrowsePaint
    _SAVEIMAGE outp, CANVAS
    d = _DEST: _DEST _CONSOLE
    PRINT PipeCol$("|15packbrowse|07 -- " + PackTypeName$(t) + " pack |14" + LTRIM$(STR$(i)) + _
                   "|07 (" + PackNameAt$(t, i) + ") -> |10" + outp + "|07")
    _DEST d
END SUB


SUB PackArtPreview (t AS INTEGER, d AS STRING, x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER, p AS STRING, h AS LONG, px AS INTEGER, py AS INTEGER
    DIM sub4(1 TO 4) AS STRING, nm(1 TO 4) AS STRING

    '--- one from each category the eye reads differently ---
    '--- the HOST picks what is worth looking at: four sprites this game has, in
    '    categories the eye reads differently. A different game names four of
    '    its own and the panel is unchanged. ---
    FOR i = 1 TO 4
        sub4(i) = Game_PackSample$(PackKindOf$(t), i)
        nm(i) = Game_PackSampleName$(PackKindOf$(t), i)
    NEXT i

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


