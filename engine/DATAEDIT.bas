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
    '--- The DECLARED split rule (engine/SCHEMA.bas). This used to be an IF
    '    chain naming files -- strings.txt, *_events.txt -- which is the editor
    '    keeping its own third copy of what a table is, and it disagreed with
    '    the loader about monster_events.txt. An undeclared table answers 0,
    '    "split on every pipe", which is what this did before any of them were
    '    named. ---
    DeMaxCols% = TableSplit%(path)
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
        '--- remember the ending PER LINE. A file with mixed endings is
        '    pathological, but normalising one on save would rewrite every line
        '    of somebody's file as a side effect of opening it -- which is
        '    exactly what this editor exists not to do. ---
        IF DE_NRAW < DE_MAXRAW THEN
            DE_NRAW = DE_NRAW + 1
            IF RIGHT$(ln, 1) = CHR$(13) THEN
                DE_CRLF(DE_NRAW) = -1
                ln = LEFT$(ln, LEN(ln) - 1)
            ELSE
                DE_CRLF(DE_NRAW) = 0
            END IF
            DE_RAW(DE_NRAW) = ln
        END IF
        p = i + 1
    LOOP

    '--- which raw lines are DATA, and where the header comment is ---
    lastcom = 0
    FOR i = 1 TO DE_NRAW
        ln = _TRIM$(DE_RAW(i))
        IF LEN(ln) = 0 THEN
            ' blank: skipped by every loader here
        ELSEIF LEFT$(ln, 1) = "#" THEN
            '--- remember the last PIPE-SHAPED comment, not merely the last one.
            '    These files carry section banners ("# --- the monster HITS you")
            '    right above the rows, so "the comment just before the data" is
            '    usually prose. The column header is the last comment that looks
            '    like a row -- which is also what makes the headings useful. ---
            IF DeCount%(ln, path) >= 2 THEN lastcom = i
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
    '--- DECLARED names win over the file's own header comment: the comment is
    '    documentation and can go stale, the declaration is what the loader
    '    actually reads. Where a table is undeclared the comment still serves. ---
    FOR col = 1 TO DE_NCOL
        IF LEN(TableColName$(DE_PATH, col)) > 0 THEN DE_HEAD(col) = TableColName$(DE_PATH, col)
        IF LEN(DE_HEAD(col)) = 0 THEN DE_HEAD(col) = "f" + LTRIM$(STR$(col))
        IF LEN(DE_HEAD(col)) > DE_W(col) THEN DE_W(col) = LEN(DE_HEAD(col))
        IF DE_W(col) > 28 THEN DE_W(col) = 28
        IF DE_W(col) < 3 THEN DE_W(col) = 3
    NEXT col

    '--- the LAST column of these tables is nearly always the prose one -- a
    '    flavor line, a description, a string. Cutting it at 28 like the key
    '    columns makes the file unreadable in the one tool meant to read it, so
    '    it gets whatever width is left on screen. ---
    n = 5
    FOR col = 1 TO DE_NCOL - 1: n = n + DE_W(col) + 1: NEXT col
    IF DE_NCOL >= 1 THEN
        IF SW - 2 - n > DE_W(DE_NCOL) THEN DE_W(DE_NCOL) = SW - 2 - n
    END IF

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

'--- Replace ONE field by SPLICING the raw line, not by rebuilding it.
'
'    Rebuilding meant re-joining every field with " | ", which quietly
'    reformatted every row it touched: assets/flavor/regular.txt is written
'    "1|Dust motes drift..." with no space after the pipe, and a rebuild turned
'    that into "1 | Dust motes...". Harmless to the loader, which trims -- and
'    exactly the kind of whole-file churn that makes a diff unreadable and an
'    editor untrustworthy. The round-trip gate's rule-free check caught it.
'
'    So: keep the line, replace the slice between the two separators, and hold
'    on to that slice's own leading and trailing spaces. A shorter value is
'    padded back out to the width it had, which is what preserves the column
'    alignment in the hand-aligned tables; a longer one just makes the row
'    longer, the same as typing into it. ---
SUB DeSetField (row AS INTEGER, col AS INTEGER, v AS STRING)
    DIM ln AS STRING, slice AS STRING, lead AS INTEGER, trail AS INTEGER
    DIM oldt AS STRING, newt AS STRING, pad AS INTEGER
    DIM p AS LONG, q AS LONG

    IF row < 1 _ORELSE row > DE_NROW THEN EXIT SUB
    ln = DE_RAW(DE_ROWMAP(row))
    IF DeFieldSpan%(ln, col, DeMaxCols%(DE_PATH), p, q) = 0 THEN EXIT SUB

    slice = MID$(ln, p, q - p)
    oldt = _TRIM$(slice)
    newt = _TRIM$(v)

    lead = 0
    DO WHILE lead < LEN(slice)
        IF MID$(slice, lead + 1, 1) <> " " THEN EXIT DO
        lead = lead + 1
    LOOP
    trail = 0
    DO WHILE trail < LEN(slice) - lead
        IF MID$(slice, LEN(slice) - trail, 1) <> " " THEN EXIT DO
        trail = trail + 1
    LOOP

    pad = LEN(oldt) - LEN(newt)
    IF pad < 0 THEN pad = 0

    DE_RAW(DE_ROWMAP(row)) = LEFT$(ln, p - 1) + SPACE$(lead) + newt + SPACE$(pad + trail) + MID$(ln, q)
    DE_DIRTY = -1
END SUB

'--- character span of field n in ln: p is its first character, q one PAST its
'    last. Honours the file's split rule, so the last field of a capped file
'    runs to the end of the line, pipes and all. ---
FUNCTION DeFieldSpan% (ln AS STRING, n AS INTEGER, cap AS INTEGER, p AS LONG, q AS LONG)
    DIM i AS INTEGER, r AS LONG
    p = 1
    FOR i = 1 TO n - 1
        IF cap > 0 _ANDALSO i >= cap THEN DeFieldSpan% = 0: EXIT FUNCTION
        r = INSTR(p, ln, "|")
        IF r = 0 THEN DeFieldSpan% = 0: EXIT FUNCTION
        p = r + 1
    NEXT i
    IF cap > 0 _ANDALSO n >= cap THEN
        q = LEN(ln) + 1
    ELSE
        q = INSTR(p, ln, "|")
        IF q = 0 THEN q = LEN(ln) + 1
    END IF
    DeFieldSpan% = -1
END FUNCTION

'--- how many pipes in this line are NOT followed by a space? An inline pipe
'    colour is spelled |10, and a flavor line is spelled 1|text -- both must
'    survive a rewrite, and this counts them without consulting any split rule. ---
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
        IF DE_CRLF(i) THEN whole = whole + DE_RAW(i) + CHR$(13) + CHR$(10) ELSE whole = whole + DE_RAW(i) + CHR$(10)
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
'--- every editable table the pack owns, not just assets/data/<pack>/. The
'    FLAVOR prose and the THEME colours are the same kind of file with the same
'    kind of typo in them, and a tool that covers two thirds of the tables
'    quietly teaches you to go back to the text editor for all of them. ---
SUB DeScanFiles (dir AS STRING)
    DE_NFILE = 0
    DeScanOne dir
    DeScanOne dir + "theme/"
    DeScanOne DeFlavorDir$(dir)
    DeSortFiles
END SUB

'--- assets/data/<pack>/ -> assets/flavor/<pack>/ ---
FUNCTION DeFlavorDir$ (dir AS STRING)
    DIM d AS STRING
    d = dir
    '--- both trees come from the registry: the editor covers whichever
    '    directories the host declared, and knows the name of neither ---
    IF INSTR(d, AssetDir$("data")) = 1 THEN
        DeFlavorDir$ = AssetDir$("flavor") + MID$(d, LEN(AssetDir$("data")) + 1)
    ELSE
        DeFlavorDir$ = ""
    END IF
END FUNCTION

SUB DeScanOne (dir AS STRING)
    DIM e AS STRING
    IF LEN(dir) = 0 THEN EXIT SUB
    IF _DIREXISTS(dir) = 0 THEN EXIT SUB
    e = _FILES$(dir + "*.txt")
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) <> "/" THEN
            IF DE_NFILE < UBOUND(DE_FILE) THEN DE_NFILE = DE_NFILE + 1: DE_FILE(DE_NFILE) = dir + e
        END IF
        e = _FILES$
    LOOP
END SUB

'--- the list shows where a file came from, since three directories are now
'    mixed into one list and two of them hold a chambers.txt ---
FUNCTION DeLabel$ (path AS STRING)
    DIM p AS STRING
    p = path
    IF INSTR(p, AssetDir$("flavor")) = 1 THEN
        DeLabel$ = "flavor/" + MID$(p, _INSTRREV(p, "/") + 1)
    ELSEIF INSTR(p, "/theme/") > 0 THEN
        DeLabel$ = "theme/" + MID$(p, _INSTRREV(p, "/") + 1)
    ELSE
        DeLabel$ = MID$(p, _INSTRREV(p, "/") + 1)
    END IF
END FUNCTION

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
            _PRINTSTRING ((2 + 34 * ((i - 1) \ (SH - 5))) * CW, y * CH), CHR$(16) + " " + DeLabel$(DE_FILE(i))
        ELSE
            COLOR _RGB32(160, 172, 190), _RGBA32(0, 0, 0, 0)
            _PRINTSTRING ((4 + 34 * ((i - 1) \ (SH - 5))) * CW, y * CH), DeLabel$(DE_FILE(i))
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
        DE_CRLF(i + 1) = DE_CRLF(i)
    NEXT i
    DE_RAW(at) = blank
    IF at > 1 THEN DE_CRLF(at) = DE_CRLF(at - 1) ELSE DE_CRLF(at) = 0
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
        DE_CRLF(i) = DE_CRLF(i + 1)
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
                        DeLoad DE_FILE(sel): ingrid = -1
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
        path = DE_FILE(fi)
        before = _READFILE$(path)
        DeLoad path

        '--- (1) an untouched save must reproduce the file exactly ---
        after = ""
        FOR r = 1 TO DE_NRAW
            IF DE_CRLF(r) THEN after = after + DE_RAW(r) + CHR$(13) + CHR$(10) ELSE after = after + DE_RAW(r) + CHR$(10)
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
            PRINT PipeCol$("  |10ok  |07" + DeLabel$(DE_FILE(fi)) + " (" + LTRIM$(STR$(DE_NROW)) + "x" + LTRIM$(STR$(DE_NCOL)) + ")")
        ELSE
            fail = fail + 1
            IF bad = 1 THEN
                PRINT PipeCol$("  |12BAD |07" + DeLabel$(DE_FILE(fi)) + " -- untouched save would change the file")
            ELSEIF bad >= 4 THEN
                PRINT PipeCol$("  |12BAD |07" + DeLabel$(DE_FILE(fi)) + " -- rewriting row " + LTRIM$(STR$(r)) + " broke a |PI-tight pipe (inline colour?)")
            ELSE
                PRINT PipeCol$("  |12BAD |07" + DeLabel$(DE_FILE(fi)) + " -- rewriting row " + LTRIM$(STR$(r)) + " lost a field")
            END IF
        END IF
    NEXT fi

    DataEditSelfTest% = fail
END FUNCTION


' ============================================================================
'  `dungeon.run schemalint` -- do the three copies still agree?
'
'  A table's shape is written down in three places and only one of them is
'  authoritative:
'
'    the DECLARATION   what the loader actually reads   -- authoritative
'    the FILE          how many columns its rows have   -- the data itself
'    the COMMENT       what a modder reads              -- documentation
'
'  This compares all three. A declaration narrower than the widest row means a
'  tool will drop a column; a stale comment means the person editing the file is
'  being told the wrong thing, which is how monster_events.txt lost its
'  narration key in the first place. Neither shows up as a crash.
' ============================================================================
FUNCTION SchemaLint% (dir AS STRING)
    DIM fi AS INTEGER, r AS INTEGER, wid AS INTEGER, n AS INTEGER
    DIM dec AS INTEGER, bad AS INTEGER, warn AS INTEGER, undecl AS INTEGER
    DIM hdr AS STRING, hn AS INTEGER, lbl AS STRING, d AS LONG

    d = _DEST: _DEST _CONSOLE
    PRINT PipeCol$("|15schemalint|07 -- declared columns vs the file vs its own comment")
    PRINT

    DeScanFiles dir
    FOR fi = 1 TO DE_NFILE
        DeLoad DE_FILE(fi)
        lbl = DeLabel$(DE_FILE(fi))
        dec = TableCols%(DE_FILE(fi))

        '--- the widest row the file actually has, under the DECLARED split rule ---
        wid = 0
        FOR r = 1 TO DE_NROW
            n = DeCount%(DE_RAW(DE_ROWMAP(r)), DE_FILE(fi))
            IF n > wid THEN wid = n
        NEXT r

        _DEST _CONSOLE
        IF dec = 0 THEN
            undecl = undecl + 1
            PRINT PipeCol$("  |14--  |07" + lbl + "  |08undeclared (tools fall back to splitting on every pipe)")
        ELSEIF wid > dec THEN
            bad = bad + 1
            PRINT PipeCol$("  |12BAD |07" + lbl + "  declared " + LTRIM$(STR$(dec)) + " columns, the file has rows with " + LTRIM$(STR$(wid)))
        ELSE
            '--- Does the file DOCUMENT its shape anywhere? Not "is the last
            '    pipe-shaped comment right" -- these files carry value lists
            '    ("kind  poison | blight | curse | acid") and section banners
            '    that are pipe-shaped and are not headers, so that question has
            '    false answers in both directions. The useful one is whether
            '    ANY comment states the real arity; if none does, a modder
            '    reading the file is being told the wrong thing. ---
            hn = 0
            FOR r = 1 TO DE_NRAW
                hdr = _TRIM$(DE_RAW(r))
                IF LEFT$(hdr, 1) <> "#" THEN _CONTINUE
                hdr = _TRIM$(MID$(hdr, 2))
                IF INSTR(hdr, "|") = 0 THEN _CONTINUE
                n = DeCount%(hdr, DE_FILE(fi))
                IF n = dec THEN hn = dec: EXIT FOR
                IF n > hn THEN hn = n
            NEXT r
            IF hn > 0 _ANDALSO hn <> dec THEN
                warn = warn + 1
                PRINT PipeCol$("  |14warn|07 " + lbl + "  declared " + LTRIM$(STR$(dec)) + ", but no comment in the file documents more than " + LTRIM$(STR$(hn)) + " -- the docs are stale")
            ELSE
                PRINT PipeCol$("  |10ok  |07" + lbl + "  " + LTRIM$(STR$(dec)) + " columns")
            END IF
        END IF
    NEXT fi

    PRINT
    PRINT PipeCol$("|07  declared |14" + LTRIM$(STR$(DT_N)) + "|07 table(s); |14" + LTRIM$(STR$(undecl)) + "|07 file(s) undeclared, |14" + LTRIM$(STR$(warn)) + "|07 stale comment(s)")
    IF bad > 0 THEN
        PRINT PipeCol$("|12" + LTRIM$(STR$(bad)) + " table(s) would LOSE a column -- a tool reading them drops data")
    ELSE
        PRINT PipeCol$("|10no declared table is narrower than its own data")
    END IF
    _DEST d
    SchemaLint% = bad
END FUNCTION
