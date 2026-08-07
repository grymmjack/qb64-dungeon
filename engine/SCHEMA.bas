' ============================================================================
'  engine/SCHEMA.bas -- WHAT A TABLE IS. The engine's data-table registry.
'
'  The engine already owned the READER (ReadDataFile / DField$) and the pack
'  model. What it did not own was the knowledge of what a table IS -- and that
'  knowledge lived in three places that could disagree:
'
'    the file's own header comment   # lvl | slot | name | HERO | ELF | SUP | WIZ
'    DeMaxCols% in the data editor   an IF chain naming files by name
'    each loader                     DField$(ln, 4) -- the columns again, implied
'
'  They DID disagree. monster_events.txt documents three columns and its header
'  comment says three; LoadEventText reads FOUR, the last being the narration
'  key. The data editor believed the comment, so editing the text column would
'  have swallowed that key into the line the player reads. Nothing was wrong
'  with any one of the three copies -- there were simply three.
'
'  So the game declares each table once:
'
'      DataTable "monsters.txt", "lvl|slot|name|HERO|ELF|SUP|WIZ"
'      DataTableSplit "strings.txt", "key|text", 2   ' values contain pipes
'
'  and four tools stop guessing: the editor gets its columns and its split rule,
'  the lints check arity generically instead of per-table by hand, the manifests
'  know what exists, and a new game inherits the toolchain by declaring its own.
'
'  THE SPLIT RULE IS THE SHARP EDGE. Some loaders split on the FIRST pipe only,
'  because their values legitimately contain pipes -- that is how an inline
'  colour is spelled (|10). A tool that splits those on every pipe and rejoins
'  them silently shreds every coloured string in the game.
'
'  An UNDECLARED table is not an error: it reads as "no schema known", every
'  tool falls back to what it did before, and `schemalint` says so out loud. A
'  registry that broke a host for not having filled it in yet would just not get
'  filled in.
' ============================================================================

'--- Declare a table: its file name and its columns, in order. ---
SUB DataTable (f AS STRING, cols AS STRING)
    DataTableSplit f, cols, 0
END SUB

'--- ...and its split rule. `cap` 0 = split on every pipe (the usual case);
'    `cap` n = split on the first n-1 pipes only, so field n keeps the rest of
'    the line verbatim, pipes and all. ---
SUB DataTableSplit (f AS STRING, cols AS STRING, cap AS INTEGER)
    DIM i AS INTEGER, k AS STRING
    k = SchemaKey$(f)
    IF LEN(k) = 0 THEN EXIT SUB
    FOR i = 1 TO DT_N
        IF DT_FILE(i) = k THEN
            DT_COLS(i) = cols: DT_NCOL(i) = SchemaCount%(cols): DT_SPLIT(i) = cap
            EXIT SUB
        END IF
    NEXT i
    IF DT_N >= DT_MAX THEN EXIT SUB
    DT_N = DT_N + 1
    DT_FILE(DT_N) = k
    DT_COLS(DT_N) = cols
    DT_NCOL(DT_N) = SchemaCount%(cols)
    DT_SPLIT(DT_N) = cap
END SUB

'--- Tables are declared and looked up by FILE NAME, never by full path: the
'    same table resolves to a different path per pack, and the schema is a
'    property of the table, not of which copy of it you happened to open. ---
FUNCTION SchemaKey$ (p AS STRING)
    DIM s AS STRING, i AS INTEGER
    s = _TRIM$(p)
    i = _INSTRREV(s, "/")
    IF i > 0 THEN s = MID$(s, i + 1)
    '--- keep one directory of context where a name is ambiguous: flavor and
    '    data both ship a chambers.txt and they agree about nothing ---
    IF INSTR(LCASE$(p), "flavor") > 0 THEN s = "flavor/" + s
    IF INSTR(LCASE$(p), "theme/") > 0 THEN s = "theme/" + s
    SchemaKey$ = LCASE$(s)
END FUNCTION

FUNCTION SchemaIndex% (p AS STRING)
    DIM i AS INTEGER, k AS STRING
    k = SchemaKey$(p)
    FOR i = 1 TO DT_N
        IF DT_FILE(i) = k THEN SchemaIndex% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

'--- how many columns this table has; 0 = undeclared ---
FUNCTION TableCols% (p AS STRING)
    DIM i AS INTEGER
    i = SchemaIndex%(p)
    IF i > 0 THEN TableCols% = DT_NCOL(i)
END FUNCTION

'--- the name of column n, or "" ---
FUNCTION TableColName$ (p AS STRING, n AS INTEGER)
    DIM i AS INTEGER
    i = SchemaIndex%(p)
    IF i > 0 THEN TableColName$ = SchemaField$(DT_COLS(i), n)
END FUNCTION

'--- the split rule: 0 = every pipe, n = the first n-1 only ---
FUNCTION TableSplit% (p AS STRING)
    DIM i AS INTEGER
    i = SchemaIndex%(p)
    IF i > 0 THEN TableSplit% = DT_SPLIT(i)
END FUNCTION

FUNCTION TableDeclared% (p AS STRING)
    TableDeclared% = (SchemaIndex%(p) > 0)
END FUNCTION

' ----------------------------------------------------------------------------
'  Tiny string helpers -- kept local so this part depends on nothing
' ----------------------------------------------------------------------------
FUNCTION SchemaCount% (cols AS STRING)
    DIM i AS LONG, n AS INTEGER
    IF LEN(_TRIM$(cols)) = 0 THEN EXIT FUNCTION
    n = 1
    FOR i = 1 TO LEN(cols)
        IF MID$(cols, i, 1) = "|" THEN n = n + 1
    NEXT i
    SchemaCount% = n
END FUNCTION

FUNCTION SchemaField$ (cols AS STRING, n AS INTEGER)
    DIM i AS INTEGER, p AS LONG, q AS LONG
    p = 1
    FOR i = 1 TO n - 1
        q = INSTR(p, cols, "|")
        IF q = 0 THEN EXIT FUNCTION
        p = q + 1
    NEXT i
    q = INSTR(p, cols, "|")
    IF q = 0 THEN q = LEN(cols) + 1
    SchemaField$ = _TRIM$(MID$(cols, p, q - p))
END FUNCTION

'--- for schemalint and `dump schema` ---
FUNCTION SchemaList$
    DIM i AS INTEGER, s AS STRING, sp AS STRING
    FOR i = 1 TO DT_N
        sp = ""
        IF DT_SPLIT(i) > 0 THEN sp = "   [split " + LTRIM$(STR$(DT_SPLIT(i))) + "]"
        IF LEN(s) > 0 THEN s = s + CHR$(10)
        s = s + DT_FILE(i) + "  (" + LTRIM$(STR$(DT_NCOL(i))) + ")  " + DT_COLS(i) + sp
    NEXT i
    SchemaList$ = s
END FUNCTION
