' ============================================================================
'  engine/DATAEDIT.bas -- the DATA EDITOR: the content tables as a grid.
'
'      dungeon.run dataedit
'
'  Every balance knob, monster, treasure, class and string in this game is a
'  pipe-delimited .txt file under assets/data/<pack>/. Editing one in a text
'  editor works, and will keep working -- that is the whole point of the format.
'  What a text editor cannot do is tell you which column you are in when a row
'  has eleven of them, or that the file you just saved now has a row with the
'  wrong field count.
'
'  So this is a grid over the SAME files, and it is deliberately conservative
'  about them:
'
'    * The file is held as its RAW LINES. Comments, blank lines, banner art and
'      the column-header comment are never touched -- only the single line
'      under the cursor is rewritten when you commit an edit. Those comments
'      are the documentation for the format; an editor that "re-serialises the
'      model" would helpfully delete all of it on the first save.
'
'    * A rewritten line is re-padded to the column widths already in the file,
'      so an edited row still lines up with its neighbours.
'
'    * Some files split on the FIRST pipe only -- strings.txt values legitimately
'      CONTAIN pipes, because that is how a pipe colour is spelled (|10). Naively
'      splitting every row on every pipe and rejoining it would silently shred
'      every coloured string in the game. DeMaxCols% mirrors each loader's own
'      rule, and the last column keeps its remainder verbatim.
'
'    * Saving backs the original up to <file>.bak first, and only ever on an
'      explicit [S]. Nothing here writes on exit.
' ============================================================================

CONST DE_MAXRAW = 4000
CONST DE_MAXCOL = 24

'--- how many fields does THIS file really have? Mirrors the loader, because a
'    loader that splits on the first pipe only is the loader whose values are
'    allowed to contain pipes. 0 = split on every pipe. ---
FUNCTION DeMaxCols% (path AS STRING)
    DIM b AS STRING
    b = LCASE$(path)
    IF INSTR(b, "strings.txt") > 0 THEN DeMaxCols% = 2: EXIT FUNCTION
    DeMaxCols% = 0
END FUNCTION

' ----------------------------------------------------------------------------
'  Loading -- raw lines in, grid derived from them
' ----------------------------------------------------------------------------
SUB DeLoad (path AS STRING)
    DIM whole AS STRING, ln AS STRING, i AS LONG, p AS LONG
    DIM col AS INTEGER, n AS INTEGER, lastcom AS INTEGER

    DE_PATH = path
    DE_NRAW = 0
    DE_NROW = 0
    DE_NCOL = 0
    DE_DIRTY = 0
    DE_TOP = 1: DE_CUR = 1: DE_CCOL = 1: DE_LEFT = 1
    FOR col = 1 TO DE_MAXCOL: DE_HEAD(col) = "": DE_W(col) = 0: NEXT col

    IF _FILEEXISTS(path) = 0 THEN DE_MSG = "no such file: " + path: EXIT SUB
    whole = _READFILE$(path)

    '--- split on LF, tolerating CRLF; every line kept verbatim ---
    p = 1
    DO WHILE p <= LEN(whole)
        i = INSTR(p, whole, CHR$(10))
        IF i = 0 THEN i = LEN(whole) + 1
        ln = MID$(whole, p, i - p)
        IF RIGHT$(ln, 1) = CHR$(13) THEN ln = LEFT$(ln, LEN(ln) - 1)
        IF DE_NRAW < DE_MAXRAW THEN DE_NRAW = DE_NRAW + 1: DE_RAW(DE_NRAW) = ln
        p = i + 1
    LOOP

    '--- which raw lines are DATA, and where the header comment is ---
    lastcom = 0
    FOR i = 1 TO DE_NRAW
        ln = _TRIM$(DE_RAW(i))
        IF LEN(ln) = 0 THEN
            ' blank: skipped by every loader here
        ELSEIF LEFT$(ln, 1) = "#" THEN
            lastcom = i
        ELSE
            DE_NROW = DE_NROW + 1
            DE_ROWMAP(DE_NROW) = i
            n = DeCount%(DE_RAW(i), path)
            IF n > DE_NCOL THEN DE_NCOL = n
            IF DE_NROW = 1 THEN DE_HDRAW = lastcom
        END IF
    NEXT i
    IF DE_NCOL > DE_MAXCOL THEN DE_NCOL = DE_MAXCOL

    '--- column widths, so a rewritten row keeps the file's own alignment ---
    FOR i = 1 TO DE_NROW
        FOR col = 1 TO DE_NCOL
            n = LEN(DeField$(i, col))
            IF n > DE_W(col) THEN DE_W(col) = n
        NEXT col
    NEXT i

    '--- headings from the comment line just above the first data row, when it
    '    is itself pipe-delimited ("# lvl | slot | name | HERO | ...") ---
    IF DE_HDRAW > 0 THEN
        ln = _TRIM$(DE_RAW(DE_HDRAW))
        IF LEFT$(ln, 1) = "#" THEN ln = _TRIM$(MID$(ln, 2))
        IF INSTR(ln, "|") > 0 THEN
            FOR col = 1 TO DE_NCOL
                DE_HEAD(col) = DeSplit$(ln, col, 0)
            NEXT col
        END IF
    END IF
    FOR col = 1 TO DE_NCOL
        IF LEN(DE_HEAD(col)) = 0 THEN DE_HEAD(col) = "f" + LTRIM$(STR$(col))
        IF LEN(DE_HEAD(col)) > DE_W(col) THEN DE_W(col) = LEN(DE_HEAD(col))
        IF DE_W(col) > 28 THEN DE_W(col) = 28
        IF DE_W(col) < 3 THEN DE_W(col) = 3
    NEXT col

    DE_MSG = LTRIM$(STR$(DE_NROW)) + " rows x " + LTRIM$(STR$(DE_NCOL)) + " cols"
END SUB

'--- field n of an arbitrary line, honouring the file's split rule ---
FUNCTION DeSplit$ (ln AS STRING, n AS INTEGER, cap AS INTEGER)
    DIM i AS INTEGER, p AS LONG, q AS LONG
    p = 1
    FOR i = 1 TO n - 1
        IF cap > 0 _ANDALSO i >= cap THEN DeSplit$ = "": EXIT FUNCTION
        q = INSTR(p, ln, "|")
        IF q = 0 THEN DeSplit$ = "": EXIT FUNCTION
        p = q + 1
    NEXT i
    IF cap > 0 _ANDALSO n >= cap THEN
        DeSplit$ = _TRIM$(MID$(ln, p))
    ELSE
        q = INSTR(p, ln, "|")
        IF q = 0 THEN q = LEN(ln) + 1
        DeSplit$ = _TRIM$(MID$(ln, p, q - p))
    END IF
END FUNCTION

FUNCTION DeCount% (ln AS STRING, path AS STRING)
    DIM i AS LONG, n AS INTEGER, cap AS INTEGER
    n = 1
    FOR i = 1 TO LEN(ln)
        IF MID$(ln, i, 1) = "|" THEN n = n + 1
    NEXT i
    cap = DeMaxCols%(path)
    IF cap > 0 _ANDALSO n > cap THEN n = cap
    DeCount% = n
END FUNCTION

FUNCTION DeField$ (row AS INTEGER, col AS INTEGER)
    IF row < 1 _ORELSE row > DE_NROW THEN DeField$ = "": EXIT FUNCTION
    DeField$ = DeSplit$(DE_RAW(DE_ROWMAP(row)), col, DeMaxCols%(DE_PATH))
END FUNCTION

'--- rewrite ONE raw line with one field replaced, re-padded to the file's own
'    column widths so the row still lines up with the ones around it ---
SUB DeSetField (row AS INTEGER, col AS INTEGER, v AS STRING)
    DIM i AS INTEGER, n AS INTEGER, res AS STRING, f AS STRING
    IF row < 1 _ORELSE row > DE_NROW THEN EXIT SUB
    '--- the ROW's own field count, not the file's widest. Padding a short row
    '    out to the table's maximum would invent empty columns in a ragged file
    '    (many of these tables have optional trailing fields), and the loader
    '    would then read "" where it used to read a default. ---
    n = DeCount%(DE_RAW(DE_ROWMAP(row)), DE_PATH)
    IF col > n THEN n = col
    FOR i = 1 TO n
        IF i = col THEN f = _TRIM$(v) ELSE f = DeField$(row, i)
        IF i > 1 THEN res = res + " | "
        IF i < n THEN
            res = res + f + SPACE$(DeMax%(0, DE_W(i) - LEN(f)))
        ELSE
            res = res + f
        END IF
    NEXT i
    DE_RAW(DE_ROWMAP(row)) = RTRIM$(res)
    DE_DIRTY = -1
END SUB

'--- how many pipes in this line are NOT followed by a space? An inline pipe
'    colour is spelled |10, so this number must survive a rewrite. ---
FUNCTION DeTightPipes% (ln AS STRING)
    DIM i AS LONG, n AS INTEGER
    FOR i = 1 TO LEN(ln)
        IF MID$(ln, i, 1) = "|" THEN
            IF i = LEN(ln) THEN
                n = n + 1
            ELSEIF MID$(ln, i + 1, 1) <> " " THEN
                n = n + 1
            END IF
        END IF
    NEXT i
    DeTightPipes% = n
END FUNCTION

FUNCTION DeMax% (a AS INTEGER, b AS INTEGER)
    IF a > b THEN DeMax% = a ELSE DeMax% = b
END FUNCTION

' ----------------------------------------------------------------------------
'  Saving -- backup, then the raw lines exactly as held
' ----------------------------------------------------------------------------
SUB DeSave
    DIM i AS INTEGER, f AS INTEGER, whole AS STRING
    IF DE_NRAW = 0 THEN DE_MSG = "nothing loaded": EXIT SUB

    '--- the backup is the safety net for a format the game reads at launch ---
    IF _FILEEXISTS(DE_PATH) THEN
        whole = _READFILE$(DE_PATH)
        f = FREEFILE
        OPEN DE_PATH + ".bak" FOR OUTPUT AS #f
        PRINT #f, whole;
        CLOSE #f
    END IF

    whole = ""
    FOR i = 1 TO DE_NRAW
        whole = whole + DE_RAW(i) + CHR$(10)
    NEXT i
    f = FREEFILE
    OPEN DE_PATH FOR OUTPUT AS #f
    PRINT #f, whole;
    CLOSE #f

    DE_DIRTY = 0
    DE_MSG = "saved (backup: " + DE_PATH + ".bak)"
END SUB

' ----------------------------------------------------------------------------
'  The file list
' ----------------------------------------------------------------------------
SUB DeScanFiles (dir AS STRING)
    DIM e AS STRING
    DE_NFILE = 0
    IF _DIREXISTS(dir) = 0 THEN EXIT SUB
    e = _FILES$(dir + "*.txt")
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) <> "/" THEN
            IF DE_NFILE < UBOUND(DE_FILE) THEN DE_NFILE = DE_NFILE + 1: DE_FILE(DE_NFILE) = e
        END IF
        e = _FILES$
    LOOP
    DeSortFiles
END SUB

SUB DeSortFiles
    DIM i AS INTEGER, j AS INTEGER, t AS STRING
    FOR i = 1 TO DE_NFILE - 1
        FOR j = i + 1 TO DE_NFILE
            IF LCASE$(DE_FILE(j)) < LCASE$(DE_FILE(i)) THEN
                t = DE_FILE(i): DE_FILE(i) = DE_FILE(j): DE_FILE(j) = t
            END IF
        NEXT j
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Drawing
' ----------------------------------------------------------------------------
SUB DeDrawGrid
    DIM r AS INTEGER, col AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM rows AS INTEGER, s AS STRING, w AS INTEGER

    _DEST CANVAS
    CLS , _RGB32(10, 12, 18)

    rows = SH - 6

    '--- title ---
    COLOR _RGB32(160, 210, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (CW, 0), "DATA EDIT  " + DE_PATH
    IF DE_DIRTY THEN
        COLOR _RGB32(255, 170, 70), _RGBA32(0, 0, 0, 0)
        _PRINTSTRING ((SW - 10) * CW, 0), "*MODIFIED*"
    END IF

    '--- headings ---
    x = 5
    COLOR _RGB32(120, 240, 180), _RGBA32(0, 0, 0, 0)
    FOR col = DE_LEFT TO DE_NCOL
        w = DE_W(col)
        IF x + w > SW - 1 THEN EXIT FOR
        _PRINTSTRING (x * CW, 2 * CH), LEFT$(DE_HEAD(col) + SPACE$(w), w)
        x = x + w + 1
    NEXT col
    LINE (0, 3 * CH - 2)-(SW * CW - 1, 3 * CH - 1), _RGB32(60, 80, 100), BF

    '--- rows ---
    FOR r = 0 TO rows - 1
        IF DE_TOP + r > DE_NROW THEN EXIT FOR
        y = 3 + r
        IF DE_TOP + r = DE_CUR THEN
            LINE (0, y * CH)-(SW * CW - 1, y * CH + CH - 1), _RGB32(28, 40, 62), BF
        END IF
        COLOR _RGB32(90, 100, 120), _RGBA32(0, 0, 0, 0)
        _PRINTSTRING (0, y * CH), RIGHT$("   " + LTRIM$(STR$(DE_TOP + r)), 4)
        x = 5
        FOR col = DE_LEFT TO DE_NCOL
            w = DE_W(col)
            IF x + w > SW - 1 THEN EXIT FOR
            s = DeField$(DE_TOP + r, col)
            IF LEN(s) > w THEN s = LEFT$(s, w - 1) + CHR$(26)
            IF DE_TOP + r = DE_CUR _ANDALSO col = DE_CCOL THEN
                LINE (x * CW - 2, y * CH)-((x + w) * CW - 2, y * CH + CH - 1), _RGB32(70, 110, 170), BF
                COLOR _RGB32(255, 255, 210), _RGBA32(0, 0, 0, 0)
            ELSEIF DE_TOP + r = DE_CUR THEN
                COLOR _RGB32(220, 230, 240), _RGBA32(0, 0, 0, 0)
            ELSE
                COLOR _RGB32(165, 175, 190), _RGBA32(0, 0, 0, 0)
            END IF
            _PRINTSTRING (x * CW, y * CH), s
            x = x + w + 1
        NEXT col
    NEXT r

    '--- status ---
    LINE (0, (SH - 2) * CH)-(SW * CW - 1, SH * CH - 1), _RGB32(18, 22, 32), BF
    COLOR _RGB32(255, 225, 150), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (CW, (SH - 2) * CH), "col " + DE_HEAD(DE_CCOL) + " = " + DeField$(DE_CUR, DE_CCOL) + "    " + DE_MSG
    COLOR _RGB32(130, 140, 160), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (CW, (SH - 1) * CH), "[arrows] cell  [ENTER] edit  [I] insert row  [X] delete row  [S] save  [R] reload  [TAB] files  [ESC] quit"
END SUB

SUB DeDrawFiles (dir AS STRING, sel AS INTEGER)
    DIM i AS INTEGER, y AS INTEGER
    _DEST CANVAS
    CLS , _RGB32(10, 12, 18)
    COLOR _RGB32(160, 210, 255), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (CW, 0), "DATA EDIT -- " + dir
    FOR i = 1 TO DE_NFILE
        y = 2 + ((i - 1) MOD (SH - 5))
        IF i = sel THEN
            COLOR _RGB32(255, 255, 210), _RGBA32(0, 0, 0, 0)
            _PRINTSTRING ((2 + 34 * ((i - 1) \ (SH - 5))) * CW, y * CH), CHR$(16) + " " + DE_FILE(i)
        ELSE
            COLOR _RGB32(160, 172, 190), _RGBA32(0, 0, 0, 0)
            _PRINTSTRING ((4 + 34 * ((i - 1) \ (SH - 5))) * CW, y * CH), DE_FILE(i)
        END IF
    NEXT i
    COLOR _RGB32(130, 140, 160), _RGBA32(0, 0, 0, 0)
    _PRINTSTRING (CW, (SH - 1) * CH), "[arrows] pick  [ENTER] open  [ESC] quit"
END SUB

' ----------------------------------------------------------------------------
'  Inline cell entry
' ----------------------------------------------------------------------------
SUB DeEditCell
    DIM v AS STRING, k AS STRING, done AS INTEGER, y AS INTEGER
    v = DeField$(DE_CUR, DE_CCOL)
    DO
        DeDrawGrid
        _DEST CANVAS
        y = SH - 4
        LINE (0, y * CH)-(SW * CW - 1, y * CH + CH - 1), _RGB32(60, 40, 90), BF
        COLOR _RGB32(255, 255, 255), _RGBA32(0, 0, 0, 0)
        _PRINTSTRING (CW, y * CH), DE_HEAD(DE_CCOL) + ": " + v + CHR$(219)
        Present
        k = INKEY$
        DO WHILE LEN(k) = 0
            Present
            _LIMIT 60
            k = INKEY$
        LOOP
        IF LEN(k) = 1 THEN
            SELECT CASE ASC(k)
                CASE 13: DeSetField DE_CUR, DE_CCOL, v: DE_MSG = "edited row " + LTRIM$(STR$(DE_CUR)): done = -1
                CASE 27: DE_MSG = "cancelled": done = -1
                CASE 8: IF LEN(v) > 0 THEN v = LEFT$(v, LEN(v) - 1)
                CASE ELSE
                    '--- a pipe would invent a column; the grid is how you add one ---
                    IF ASC(k) >= 32 _ANDALSO k <> "|" THEN v = v + k
            END SELECT
        END IF
    LOOP UNTIL done
END SUB

' ----------------------------------------------------------------------------
'  Rows
' ----------------------------------------------------------------------------
SUB DeInsertRow
    DIM at AS INTEGER, i AS INTEGER, blank AS STRING, col AS INTEGER
    IF DE_NRAW >= DE_MAXRAW THEN DE_MSG = "file is full": EXIT SUB
    IF DE_NROW = 0 THEN at = DE_NRAW + 1 ELSE at = DE_ROWMAP(DE_CUR) + 1

    FOR col = 1 TO DE_NCOL
        IF col > 1 THEN blank = blank + " | "
        blank = blank + SPACE$(DE_W(col))
    NEXT col
    blank = RTRIM$(blank)
    IF LEN(_TRIM$(blank)) = 0 THEN blank = "|"

    FOR i = DE_NRAW TO at STEP -1
        DE_RAW(i + 1) = DE_RAW(i)
    NEXT i
    DE_RAW(at) = blank
    DE_NRAW = DE_NRAW + 1
    DeRemap
    DE_CUR = DeRowAtRaw%(at)
    DE_DIRTY = -1
    DE_MSG = "inserted a row"
END SUB

SUB DeDeleteRow
    DIM at AS INTEGER, i AS INTEGER
    IF DE_NROW = 0 THEN EXIT SUB
    at = DE_ROWMAP(DE_CUR)
    FOR i = at TO DE_NRAW - 1
        DE_RAW(i) = DE_RAW(i + 1)
    NEXT i
    DE_NRAW = DE_NRAW - 1
    DeRemap
    IF DE_CUR > DE_NROW THEN DE_CUR = DE_NROW
    IF DE_CUR < 1 THEN DE_CUR = 1
    DE_DIRTY = -1
    DE_MSG = "deleted a row"
END SUB

'--- the grid is a VIEW of the raw lines, so any structural change rebuilds the
'    map rather than trying to patch it ---
SUB DeRemap
    DIM i AS INTEGER, ln AS STRING
    DE_NROW = 0
    FOR i = 1 TO DE_NRAW
        ln = _TRIM$(DE_RAW(i))
        IF LEN(ln) > 0 _ANDALSO LEFT$(ln, 1) <> "#" THEN
            DE_NROW = DE_NROW + 1
            DE_ROWMAP(DE_NROW) = i
        END IF
    NEXT i
END SUB

FUNCTION DeRowAtRaw% (raw AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO DE_NROW
        IF DE_ROWMAP(i) = raw THEN DeRowAtRaw% = i: EXIT FUNCTION
    NEXT i
    DeRowAtRaw% = 1
END FUNCTION

' ----------------------------------------------------------------------------
'  The editor proper
' ----------------------------------------------------------------------------
SUB DataEditor (dir AS STRING)
    DIM k AS STRING, sel AS INTEGER, quit AS INTEGER, ingrid AS INTEGER
    DIM rows AS INTEGER

    DeScanFiles dir
    IF DE_NFILE = 0 THEN
        _DEST CANVAS
        CLS , _RGB32(10, 12, 18)
        COLOR _RGB32(255, 120, 120), _RGBA32(0, 0, 0, 0)
        _PRINTSTRING (CW, CH), "no .txt files in " + dir
        Present
        DO: _LIMIT 30: LOOP UNTIL LEN(INKEY$) > 0
        EXIT SUB
    END IF
    sel = 1

    DO
        IF ingrid THEN DeDrawGrid ELSE DeDrawFiles dir, sel
        Present

        k = INKEY$
        IF LEN(k) = 2 THEN
            SELECT CASE ASC(RIGHT$(k, 1))
                CASE 72: IF ingrid THEN DE_CUR = DE_CUR - 1 ELSE sel = sel - 1
                CASE 80: IF ingrid THEN DE_CUR = DE_CUR + 1 ELSE sel = sel + 1
                CASE 75: IF ingrid THEN DE_CCOL = DE_CCOL - 1 ELSE sel = sel - (SH - 5)
                CASE 77: IF ingrid THEN DE_CCOL = DE_CCOL + 1 ELSE sel = sel + (SH - 5)
                CASE 73: IF ingrid THEN DE_CUR = DE_CUR - (SH - 8)
                CASE 81: IF ingrid THEN DE_CUR = DE_CUR + (SH - 8)
                CASE 71: IF ingrid THEN DE_CUR = 1
                CASE 79: IF ingrid THEN DE_CUR = DE_NROW
            END SELECT
        ELSEIF LEN(k) = 1 THEN
            SELECT CASE ASC(k)
                CASE 27
                    IF ingrid THEN ingrid = 0 ELSE quit = -1
                CASE 13
                    IF ingrid THEN
                        DeEditCell
                    ELSE
                        DeLoad dir + DE_FILE(sel): ingrid = -1
                    END IF
                CASE 9
                    IF ingrid THEN ingrid = 0
                CASE ELSE
                    IF ingrid THEN
                        SELECT CASE LCASE$(k)
                            CASE "s": DeSave
                            CASE "r": DeLoad DE_PATH
                            CASE "i": DeInsertRow
                            CASE "x": DeDeleteRow
                        END SELECT
                    END IF
            END SELECT
        END IF

        '--- clamp ---
        IF sel < 1 THEN sel = 1
        IF sel > DE_NFILE THEN sel = DE_NFILE
        IF DE_CUR < 1 THEN DE_CUR = 1
        IF DE_CUR > DE_NROW THEN DE_CUR = DE_NROW
        IF DE_CCOL < 1 THEN DE_CCOL = 1
        IF DE_CCOL > DE_NCOL THEN DE_CCOL = DE_NCOL
        rows = SH - 6
        IF DE_CUR < DE_TOP THEN DE_TOP = DE_CUR
        IF DE_CUR > DE_TOP + rows - 1 THEN DE_TOP = DE_CUR - rows + 1
        IF DE_TOP < 1 THEN DE_TOP = 1
        IF DE_CCOL < DE_LEFT THEN DE_LEFT = DE_CCOL
        IF DE_CCOL > DE_LEFT + 5 THEN DE_LEFT = DE_CCOL - 5

        _LIMIT 60
    LOOP UNTIL quit
END SUB

'--- headless: one frame of the grid, for the gate. Never saves. ---
SUB DataEditorShot (path AS STRING, outp AS STRING)
    DeLoad path
    DeDrawGrid
    _SAVEIMAGE outp, CANVAS
END SUB

'--- pick a command-line argument by EXTENSION, so the two arguments can be
'    given in either order and neither needs a flag ---
FUNCTION DeArg$ (dflt AS STRING, ext AS STRING)
    DIM i AS INTEGER, a AS STRING
    DeArg$ = dflt
    FOR i = 1 TO _COMMANDCOUNT
        a = COMMAND$(i)
        IF INSTR(LCASE$(a), LCASE$(ext)) > 0 THEN DeArg$ = a
    NEXT i
END FUNCTION

' ----------------------------------------------------------------------------
'  Round-trip proof -- the only claim that actually matters here
'
'  Two things must be true of an editor pointed at the files the game reads at
'  launch, and neither is visible by looking at the screen:
'
'    1. Load then save with NO edits must give back the file byte for byte.
'       Comments, blank lines, banner art, alignment -- all of it. If that is
'       not true, merely opening a file and pressing [S] is destructive.
'    2. Rewriting one field must leave every OTHER field on that row identical.
'       This is where a naive splitter shreds strings.txt, whose values contain
'       pipes because that is how a pipe colour is spelled.
'
'  So this rewrites EVERY field of EVERY row of EVERY table with its own current
'  value -- the harshest version of (2) -- and checks the whole row survived.
' ----------------------------------------------------------------------------
FUNCTION DataEditSelfTest% (dir AS STRING)
    DIM fi AS INTEGER, r AS INTEGER, col AS INTEGER, bad AS INTEGER
    DIM before AS STRING, after AS STRING, path AS STRING
    DIM keep(1 TO 24) AS STRING, fail AS INTEGER, tight AS INTEGER, nc AS INTEGER

    _DEST _CONSOLE                    ' DeLoad/DeDrawGrid retarget _DEST to CANVAS
    DeScanFiles dir
    PRINT PipeCol$("|15dataedit round-trip |07-- |14" + LTRIM$(STR$(DE_NFILE)) + "|07 table(s) in " + dir)

    FOR fi = 1 TO DE_NFILE
        path = dir + DE_FILE(fi)
        before = _READFILE$(path)
        DeLoad path

        '--- (1) an untouched save must reproduce the file exactly ---
        after = ""
        FOR r = 1 TO DE_NRAW
            after = after + DE_RAW(r) + CHR$(10)
        NEXT r
        bad = 0
        IF after <> before THEN
            '--- a file with no trailing newline is the one legal difference ---
            IF after <> before + CHR$(10) THEN bad = 1
        END IF

        '--- (2) rewrite every field with itself; the row must not change.
        '    (3) and no rewrite may put a SPACE after a pipe that did not have
        '    one. That check is rule-free -- it does not consult DeMaxCols% --
        '    which is the point: (2) splits and rejoins with the same rule, so
        '    it agrees with itself even when the rule is wrong for the file.
        '    "|10" turning into "| 10" is exactly how a wrong rule shreds an
        '    inline pipe colour, and (3) sees it where (2) cannot. ---
        FOR r = 1 TO DE_NROW
            '--- only the columns this row actually HAS: writing past them is a
            '    legitimate way to add a field, not something to round-trip ---
            nc = DeCount%(DE_RAW(DE_ROWMAP(r)), path)
            IF nc > DE_NCOL THEN nc = DE_NCOL
            FOR col = 1 TO nc: keep(col) = DeField$(r, col): NEXT col
            tight = DeTightPipes%(DE_RAW(DE_ROWMAP(r)))
            FOR col = 1 TO nc
                DeSetField r, col, keep(col)
            NEXT col
            FOR col = 1 TO nc
                IF DeField$(r, col) <> keep(col) THEN bad = bad + 2: EXIT FOR
            NEXT col
            IF bad >= 2 THEN EXIT FOR
            IF DeTightPipes%(DE_RAW(DE_ROWMAP(r))) <> tight THEN bad = bad + 4: EXIT FOR
        NEXT r

        _DEST _CONSOLE
        IF bad = 0 THEN
            PRINT PipeCol$("  |10ok  |07" + DE_FILE(fi) + " (" + LTRIM$(STR$(DE_NROW)) + "x" + LTRIM$(STR$(DE_NCOL)) + ")")
        ELSE
            fail = fail + 1
            IF bad = 1 THEN
                PRINT PipeCol$("  |12BAD |07" + DE_FILE(fi) + " -- untouched save would change the file")
            ELSEIF bad >= 4 THEN
                PRINT PipeCol$("  |12BAD |07" + DE_FILE(fi) + " -- rewriting row " + LTRIM$(STR$(r)) + " broke a |PI-tight pipe (inline colour?)")
            ELSE
                PRINT PipeCol$("  |12BAD |07" + DE_FILE(fi) + " -- rewriting row " + LTRIM$(STR$(r)) + " lost a field")
            END IF
        END IF
    NEXT fi

    DataEditSelfTest% = fail
END FUNCTION
