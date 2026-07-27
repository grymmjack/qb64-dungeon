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
    LoadChamberFlavor
END SUB

' Load the per-chamber descriptions (assets/flavor/chambers.txt: NAME | description).
SUB LoadChamberFlavor
    DIM i AS INTEGER
    CHM_FLAV_N = 0
    ReadDataFile "assets/flavor/chambers.txt"
    FOR i = 1 TO DLINE_N
        IF CHM_FLAV_N < UBOUND(CHM_FLAV_NAME) THEN
            CHM_FLAV_N = CHM_FLAV_N + 1
            CHM_FLAV_NAME(CHM_FLAV_N) = UCASE$(_TRIM$(DField$(DLINE(i), 1)))
            CHM_FLAV_TXT(CHM_FLAV_N) = DField$(DLINE(i), 2)
        END IF
    NEXT i
END SUB

' The description for a chamber name (case-insensitive), or "" if none is on file.
FUNCTION ChamberDesc$ (nm AS STRING)
    DIM i AS INTEGER, want AS STRING
    want = UCASE$(_TRIM$(nm))
    FOR i = 1 TO CHM_FLAV_N
        IF _TRIM$(CHM_FLAV_NAME(i)) = want THEN ChamberDesc$ = CHM_FLAV_TXT(i): EXIT FUNCTION
    NEXT i
    ChamberDesc$ = ""
END FUNCTION

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

' Bind each named-room label to ITS chamber, once the board's rooms exist (called at
' the end of RandomizeRooms). A label sits on the path just outside its chamber, often
' with small side rooms just as close -- so "nearest room cell" picked the wrong one and
' the crawl fired in a side room. Instead, tally the room cells in a window around the
' label and take the DOMINANT room: the big chamber the label names wins over a small
' neighbour that merely sits closer. SP_ROOM(si) = that room (0 = none found).
SUB BindSpecialRooms
    DIM si AS INTEGER, dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER, rm AS INTEGER, r AS INTEGER
    DIM tally(1 TO 400) AS INTEGER, best AS INTEGER, bestn AS INTEGER, secOf AS INTEGER
    FOR si = 1 TO SP_N
        secOf = SECTOR.get_by_xy(SP_X(si) * CW, SP_Y(si) * CH)   ' the label's own LEVEL -- stay on it
        FOR r = 1 TO ROOM_N: tally(r) = 0: NEXT
        ' window biased right + down: labels sit at the top-left of their chamber
        FOR dy = -3 TO 11
            FOR dx = -7 TO 13
                nx = SP_X(si) + dx: ny = SP_Y(si) + dy
                IF nx >= 0 AND nx <= 131 AND ny >= 0 AND ny <= 60 THEN
                    rm = ROOMAT(nx, ny)
                    IF rm >= 1 AND rm <= ROOM_N THEN
                        IF ROOMS(rm).cells >= 4 THEN IF secOf = 0 OR ROOMS(rm).sec = secOf THEN tally(rm) = tally(rm) + 1
                    END IF
                END IF
            NEXT
        NEXT
        best = 0: bestn = 0
        FOR r = 1 TO ROOM_N
            IF tally(r) > bestn THEN bestn = tally(r): best = r
        NEXT
        SP_ROOM(si) = best
    NEXT si
END SUB

' First-entry atmosphere for room rm: a named room gets a deep windowed description
' (with its location art, if any); an ordinary room a one-line typewriter subtitle.
SUB RoomFlavor (rm AS INTEGER)
    DIM i AS INTEGER, si AS INTEGER, lvl AS INTEGER, deep AS INTEGER, ri AS INTEGER
    IF rm < 1 OR rm > ROOM_N THEN EXIT SUB
    si = 0
    FOR i = 1 TO SP_N
        IF SP_ROOM(i) = rm THEN si = i: EXIT FOR       ' this room was bound to a named label
    NEXT i
    ' NOTE: BASIC's AND does not short-circuit -- SP_FN(si) must be read INSIDE
    ' IF si > 0, never as "si > 0 AND SP_FN(si)" (that indexes SP_FN(0) -> crash).
    deep = FALSE
    IF si > 0 THEN IF SP_FN(si) > 0 THEN deep = -1
    IF deep THEN
        Sfx "key"                                          ' a chime marks a named/special room
        ScrollTextArt _TRIM$(SP_KEY(si)), SP_FLAV(si, RollDie(SP_FN(si))), SpecialSprite$(SP_KEY(si))
        cursor_erase: cursor_draw: DrawHUD: _DISPLAY
    ELSE
        lvl = ROOMS(rm).sec: IF lvl < 1 OR lvl > 9 THEN lvl = 1
        IF REG_N(lvl) > 0 THEN
            ri = RollDie(REG_N(lvl))                        ' narratable per line: regular.<lvl>.<index>
            FlavorLineVO REG_FLAV(lvl, ri), "regular." + _TRIM$(STR$(lvl)) + "." + _TRIM$(STR$(ri))
        END IF
    END IF
END SUB

' Type a one-line subtitle across the top of the screen, then hold briefly. Any key skips.
' If narration is on and a voice file exists for narrkey, the spoken line plays and the
' per-glyph blips are muted (the voice covers it); otherwise it blips per glyph as before.
SUB FlavorLineVO (txt AS STRING, narrkey AS STRING)
    DIM i AS INTEGER, k AS STRING, shown AS STRING, skip AS INTEGER, h AS INTEGER, narrating AS INTEGER
    skip = FALSE
    narrating = HasNarration%(narrkey)
    IF narrating THEN Narrate narrkey
    _DEST CANVAS
    FOR i = 1 TO LEN(txt)
        shown = LEFT$(txt, i)
        LINE (0, 1 * CH)-(SW * CW, 2 * CH), BLACK, BF
        COLOR CYANU, BLACK: PrintCentered 1, shown
        _DISPLAY
        IF NOT skip THEN
            IF opt_voice AND NOT narrating THEN VoiceBlip 480 + (ASC(MID$(txt, i, 1)) MOD 220)
            _DELAY 0.016
            k = INKEY$: IF k <> "" THEN skip = -1
        END IF
    NEXT i
    FOR h = 1 TO 90                                        ' ~1.5s hold, skippable
        _LIMIT 60
        IF INKEY$ <> "" THEN EXIT FOR
        _DISPLAY
    NEXT h
    ' Do NOT NarrateStop here: this is an AMBIENT one-liner, so let the spoken line finish in
    ' the background while the player carries on (the next Narrate / room / event stops it).
    ' Stopping at the fixed hold truncated any voice line longer than the crawl.
END SUB

' No-narration ambient one-liner (per-glyph blips) -- the plain entry point.
SUB FlavorLine (txt AS STRING)
    FlavorLineVO txt, ""
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
