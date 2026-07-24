' ============================================================================
'  FLAVOR.bas -- atmospheric room + combat flavor, loaded from EDITABLE files
'
'  assets/flavor/regular.txt : ordinary-room one-liners, "<level>|<text>"
'  assets/flavor/special.txt : named-room deep flavor,   "<ROOM KEY>|<text>"
'  assets/flavor/maxhit.txt  : max-damage combat lines   (plain text, one per line)
'
'  Edit those files freely -- no recompile needed to change the words (the game
'  re-reads them at launch). Add/remove lines; keep the "<key>|" prefix. RoomFlavor
'  fires the first time you ENTER a room; MaxHitSaying$ feeds combat on a max roll.
' ============================================================================

SUB InitFlavor
    DIM i AS INTEGER
    FOR i = 1 TO 9: REG_N(i) = 0: NEXT i
    SP_N = 0: MAXHIT_N = 0: FORFEIT_N = 0
    ' Named-room anchors: the board-label cell (see render_room_labels) + the key
    ' that must match assets/flavor/special.txt. Detection = the label cell (or a
    ' neighbour) belongs to the room you just entered.
    AddSpecial "MAIN GALLERY", 57, 25
    AddSpecial "ARMORY", 14, 10
    AddSpecial "THE CRYPT", 47, 7
    AddSpecial "WIZ'S LAB", 84, 10
    AddSpecial "WIZ'S TREASURE", 93, 7
    AddSpecial "KITCHEN", 3, 26
    AddSpecial "GUARD ROOM", 18, 23
    AddSpecial "STORE ROOM", 18, 41
    AddSpecial "TORTURE CHAMBER", 49, 39
    AddSpecial "QUEEN'S ANNEX", 88, 42
    AddSpecial "QUEEN'S TREASURE", 87, 34
    AddSpecial "KING'S LIBRARY", 90, 27
    AddSpecial "KING'S TREASURE", 104, 21
    ParseFlavorFile "assets/flavor/regular.txt", 1
    ParseFlavorFile "assets/flavor/special.txt", 2
    ParseFlavorFile "assets/flavor/maxhit.txt", 3
    ParseFlavorFile "assets/flavor/forfeit.txt", 4
END SUB

SUB AddSpecial (ky AS STRING, cx AS INTEGER, cy AS INTEGER)
    IF SP_N >= UBOUND(SP_KEY) THEN EXIT SUB
    SP_N = SP_N + 1
    SP_KEY(SP_N) = ky: SP_X(SP_N) = cx: SP_Y(SP_N) = cy: SP_FN(SP_N) = 0
END SUB

' Read a flavor file and add each line. mode: 1 regular, 2 special, 3 maxhit.
SUB ParseFlavorFile (path AS STRING, mode AS INTEGER)
    DIM raw AS STRING, i AS INTEGER, ch2 AS STRING, ln AS STRING
    IF _FILEEXISTS(path) = 0 THEN EXIT SUB
    raw = _READFILE$(path)
    ln = ""
    FOR i = 1 TO LEN(raw)
        ch2 = MID$(raw, i, 1)
        IF ch2 = CHR$(10) OR ch2 = CHR$(13) THEN
            AddFlavorLine ln, mode: ln = ""
        ELSE
            ln = ln + ch2
        END IF
    NEXT i
    AddFlavorLine ln, mode
END SUB

SUB AddFlavorLine (ln AS STRING, mode AS INTEGER)
    DIM p AS INTEGER, keypart AS STRING, txt AS STRING, lvl AS INTEGER, si AS INTEGER
    IF LEN(_TRIM$(ln)) = 0 THEN EXIT SUB
    IF LEFT$(_TRIM$(ln), 1) = "#" THEN EXIT SUB            ' comment
    IF mode = 3 THEN                                       ' maxhit: whole line is the text
        IF MAXHIT_N < UBOUND(MAXHIT) THEN MAXHIT_N = MAXHIT_N + 1: MAXHIT(MAXHIT_N) = _TRIM$(ln)
        EXIT SUB
    END IF
    IF mode = 4 THEN                                       ' forfeit epitaph: whole line is the text
        IF FORFEIT_N < UBOUND(FORFEIT_FLAV) THEN FORFEIT_N = FORFEIT_N + 1: FORFEIT_FLAV(FORFEIT_N) = _TRIM$(ln)
        EXIT SUB
    END IF
    p = INSTR(ln, "|")
    IF p <= 0 THEN EXIT SUB
    keypart = _TRIM$(LEFT$(ln, p - 1))
    txt = _TRIM$(MID$(ln, p + 1))
    IF LEN(txt) = 0 THEN EXIT SUB
    IF mode = 1 THEN
        lvl = VAL(keypart)
        IF lvl >= 1 AND lvl <= 9 THEN
            IF REG_N(lvl) < UBOUND(REG_FLAV, 2) THEN REG_N(lvl) = REG_N(lvl) + 1: REG_FLAV(lvl, REG_N(lvl)) = txt
        END IF
    ELSE
        si = SpecialIndex(UCASE$(keypart))
        IF si > 0 THEN
            IF SP_FN(si) < UBOUND(SP_FLAV, 2) THEN SP_FN(si) = SP_FN(si) + 1: SP_FLAV(si, SP_FN(si)) = txt
        END IF
    END IF
END SUB

FUNCTION SpecialIndex% (ky AS STRING)
    DIM i AS INTEGER
    SpecialIndex = 0
    FOR i = 1 TO SP_N
        IF UCASE$(_TRIM$(SP_KEY(i))) = ky THEN SpecialIndex = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' TRUE if special anchor si's label (a small window around it) sits in room rm.
FUNCTION LabelInRoom% (si AS INTEGER, rm AS INTEGER)
    DIM ddx AS INTEGER, ddy AS INTEGER, nx AS INTEGER, ny AS INTEGER
    LabelInRoom = 0
    FOR ddy = -1 TO 2
        FOR ddx = 0 TO 8
            nx = SP_X(si) + ddx: ny = SP_Y(si) + ddy
            IF nx >= 0 AND nx <= 131 AND ny >= 0 AND ny <= 60 THEN
                IF ROOMAT(nx, ny) = rm THEN LabelInRoom = -1: EXIT FUNCTION
            END IF
        NEXT ddx
    NEXT ddy
END FUNCTION

' First-entry atmosphere for room rm: a named room gets a deep windowed
' description; an ordinary room a one-line typewriter subtitle for its level.
SUB RoomFlavor (rm AS INTEGER)
    DIM i AS INTEGER, si AS INTEGER, lvl AS INTEGER, deep AS INTEGER
    IF rm < 1 OR rm > ROOM_N THEN EXIT SUB
    si = 0
    FOR i = 1 TO SP_N
        IF LabelInRoom(i, rm) THEN si = i: EXIT FOR
    NEXT i
    ' NOTE: BASIC's AND does not short-circuit -- SP_FN(si) must be read INSIDE
    ' IF si > 0, never as "si > 0 AND SP_FN(si)" (that indexes SP_FN(0) -> crash).
    deep = FALSE
    IF si > 0 THEN IF SP_FN(si) > 0 THEN deep = -1
    IF deep THEN
        ScrollText _TRIM$(SP_KEY(si)), SP_FLAV(si, RollDie(SP_FN(si)))
        cursor_erase: cursor_draw: DrawHUD: _DISPLAY
    ELSE
        lvl = ROOMS(rm).sec: IF lvl < 1 OR lvl > 9 THEN lvl = 1
        IF REG_N(lvl) > 0 THEN FlavorLine REG_FLAV(lvl, RollDie(REG_N(lvl)))
    END IF
END SUB

' Type a one-line subtitle across the top of the screen, with voice blips, then
' hold briefly. Any key skips the typing / hold. The board redraws it away later.
SUB FlavorLine (txt AS STRING)
    DIM i AS INTEGER, k AS STRING, shown AS STRING, skip AS INTEGER, h AS INTEGER
    skip = FALSE
    _DEST CANVAS
    FOR i = 1 TO LEN(txt)
        shown = LEFT$(txt, i)
        LINE (0, 1 * CH)-(SW * CW, 2 * CH), BLACK, BF
        COLOR CYANU, BLACK: PrintCentered 1, shown
        _DISPLAY
        IF NOT skip THEN
            IF opt_voice THEN VoiceBlip 480 + (ASC(MID$(txt, i, 1)) MOD 220)
            _DELAY 0.016
            k = INKEY$: IF k <> "" THEN skip = -1
        END IF
    NEXT i
    FOR h = 1 TO 90                                        ' ~1.5s hold, skippable
        _LIMIT 60
        IF INKEY$ <> "" THEN EXIT FOR
        _DISPLAY
    NEXT h
END SUB

' A random sad epitaph for the FORFEIT screen (all lives spent). Falls back to a
' built-in line if assets/flavor/forfeit.txt is missing.
FUNCTION ForfeitEpitaph$ ()
    IF FORFEIT_N <= 0 THEN ForfeitEpitaph$ = "The dungeon claims another soul, and the dark closes over your name.": EXIT FUNCTION
    ForfeitEpitaph$ = FORFEIT_FLAV(RollDie(FORFEIT_N))
END FUNCTION


' A random 'brutal hit' line for a max-damage roll ({mon}/{weapon} substituted).
' Empty string if no maxhit flavor is loaded (caller then skips it).
FUNCTION MaxHitSaying$ (mon AS STRING, weap AS STRING)
    DIM s AS STRING
    IF MAXHIT_N <= 0 THEN MaxHitSaying$ = "": EXIT FUNCTION
    s = MAXHIT(RollDie(MAXHIT_N))
    s = StrSubst$(s, "{mon}", mon)
    s = StrSubst$(s, "{weapon}", weap)
    MaxHitSaying$ = s
END FUNCTION
