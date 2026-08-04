' ============================================================================
'  CUTPARSE.bas -- .cut source  ->  opcode array.
'
'  Compiled ONCE, at load. The runtime never looks at text again, which is
'  what makes hot-reload honest: [R] in the player re-reads the file and
'  recompiles from scratch, so what you watch is what the parser actually
'  produced, not a patched-up version of the last run.
'
'  TWO DESIGN CALLS WORTH KNOWING ABOUT
'  -----------------------------------
'  1. MODIFIERS ARE KEYWORD-SCANNED, NOT POSITIONAL. After a command's fixed
'     arguments, the rest of the line is searched for `fade`, `over`, `at`,
'     `ease` and friends wherever they appear. So these are all the same line:
'
'         show bg "crypt.png" fade 1.0 at 0.5,0.5 scale 1.2
'         show bg "crypt.png" at 0.5,0.5 scale 1.2 fade 1.0
'
'     An author writing prose-like script lines should not have to remember an
'     argument order, and a positional parser turns a reordering into a silent
'     wrong-value bug rather than an error.
'
'  2. CONDITIONS ARE STORED AS TEXT AND EVALUATED AT RUNTIME. `if gold >= 5000
'     and class == wizard` is kept verbatim in the string pool and parsed each
'     time it is reached. That sounds wasteful and is not: a scene evaluates a
'     handful of conditions in its whole life, while a compiled condition tree
'     would need its own node array, its own bounds checks and its own bugs.
'     The linter runs the SAME evaluator in validate-only mode, so a typo is
'     still caught before the scene ever plays.
' ============================================================================

' ----------------------------------------------------------------------------
'  Diagnostics
' ----------------------------------------------------------------------------
SUB CutErrAdd (sev AS INTEGER, ln AS INTEGER, msg AS STRING)
    IF CUT_NERR > CUT_MAXERR - 1 THEN EXIT SUB
    CUT_NERR = CUT_NERR + 1
    CUT_ERR(CUT_NERR) = msg
    CUT_ERRLINE(CUT_NERR) = ln
    CUT_ERRSEV(CUT_NERR) = sev
    IF sev = 2 THEN CUT_NFATAL = CUT_NFATAL + 1
END SUB

' ----------------------------------------------------------------------------
'  String pool. Index 0 is reserved as "no string", so a zeroed op is inert.
' ----------------------------------------------------------------------------
FUNCTION CutStr& (s AS STRING)
    IF LEN(s) = 0 THEN CutStr& = CUT_NOSTR: EXIT FUNCTION
    CUT_NSPOOL = CUT_NSPOOL + 1
    REDIM _PRESERVE CUT_SPOOL(0 TO CUT_NSPOOL) AS STRING
    CUT_SPOOL(CUT_NSPOOL) = s
    CutStr& = CUT_NSPOOL
END FUNCTION

FUNCTION CutStrGet$ (ix AS LONG)
    IF ix <= CUT_NOSTR THEN CutStrGet$ = "": EXIT FUNCTION
    IF ix > CUT_NSPOOL THEN CutStrGet$ = "": EXIT FUNCTION
    CutStrGet$ = CUT_SPOOL(ix)
END FUNCTION

' ----------------------------------------------------------------------------
'  Small text helpers. Deliberately local rather than reaching for engine/TEXT
'  -- this module has to compile in isolation for the selftest.
' ----------------------------------------------------------------------------
FUNCTION CutLow$ (s AS STRING)
    CutLow$ = LCASE$(_TRIM$(s))
END FUNCTION

FUNCTION CutIsNum% (s AS STRING)
    DIM i AS INTEGER, chcode AS INTEGER, digits AS INTEGER, dots AS INTEGER
    IF LEN(s) = 0 THEN CutIsNum% = FALSE: EXIT FUNCTION
    FOR i = 1 TO LEN(s)
        chcode = ASC(s, i)
        IF chcode >= 48 THEN
            IF chcode <= 57 THEN digits = digits + 1: _CONTINUE
        END IF
        IF chcode = 46 THEN dots = dots + 1: _CONTINUE
        IF chcode = 45 THEN
            IF i = 1 THEN _CONTINUE
        END IF
        IF chcode = 43 THEN
            IF i = 1 THEN _CONTINUE
        END IF
        CutIsNum% = FALSE: EXIT FUNCTION
    NEXT i
    IF digits = 0 THEN CutIsNum% = FALSE: EXIT FUNCTION
    IF dots > 1 THEN CutIsNum% = FALSE: EXIT FUNCTION
    CutIsNum% = TRUE
END FUNCTION

'--- VAL is a reserved word here, so every numeric read goes through this. ---
FUNCTION CutNum! (s AS STRING)
    IF CutIsNum%(s) THEN
        CutNum! = VAL(s)
    ELSE
        CutNum! = 0
    END IF
END FUNCTION

' ----------------------------------------------------------------------------
'  Tokeniser.
'
'  Splits one line into CUT_TK(). Quoted runs stay whole and are flagged in
'  CUT_TKQ so `say "fade 2.0"` cannot be mistaken for a modifier. Commas are
'  whitespace, which is what lets a point be written `0.5,0.8` or `0.5 0.8`
'  interchangeably.
' ----------------------------------------------------------------------------
SUB CutTokenize (rawln AS STRING)
    DIM ln AS STRING, i AS INTEGER, chcode AS INTEGER
    DIM cur AS STRING, inq AS INTEGER, quoted AS INTEGER

    CUT_NTK = 0
    ln = rawln
    cur = "": inq = FALSE: quoted = FALSE

    FOR i = 1 TO LEN(ln)
        chcode = ASC(ln, i)

        IF inq THEN
            IF chcode = 34 THEN
                inq = FALSE
                CutPushTok cur, TRUE
                cur = "": quoted = FALSE
            ELSE
                cur = cur + CHR$(chcode)
            END IF
            _CONTINUE
        END IF

        '--- an apostrophe outside quotes starts a comment ---
        IF chcode = 39 THEN EXIT FOR
        IF chcode = 35 THEN
            IF LEN(cur) = 0 THEN
                IF CUT_NTK = 0 THEN EXIT FOR
            END IF
        END IF

        IF chcode = 34 THEN
            IF LEN(cur) > 0 THEN CutPushTok cur, FALSE: cur = ""
            inq = TRUE
            quoted = TRUE
            _CONTINUE
        END IF

        '--- space, tab and comma all separate ---
        IF chcode = 32 _ORELSE chcode = 9 _ORELSE chcode = 44 THEN
            IF LEN(cur) > 0 THEN CutPushTok cur, FALSE: cur = ""
            _CONTINUE
        END IF

        '--- Comparison characters separate, and emit THEMSELVES -- so
        '    `set x = 1` and `set x=1` compile to the same three tokens.
        '
        '    The RUN matters: consuming them one at a time turned `==` into two
        '    `=` tokens, and rejoining a condition for storage then produced
        '    `class = = wizard`, which the evaluator rightly refused. Take the
        '    whole run, so `==`, `>=`, `<=` and `<>` survive as one token. ---
        '--- `->` first: `>` is a comparison character, so without this the
        '    arrow in `option "Open it" -> open_it` would split into `-` and
        '    `>` and the option would resolve to no label at all. ---
        IF chcode = 45 THEN
            IF i < LEN(ln) THEN
                IF ASC(ln, i + 1) = 62 THEN
                    IF LEN(cur) > 0 THEN CutPushTok cur, FALSE: cur = ""
                    CutPushTok "->", FALSE
                    i = i + 1
                    _CONTINUE
                END IF
            END IF
        END IF

        IF CutIsCmpChar%(chcode) THEN
            IF LEN(cur) > 0 THEN CutPushTok cur, FALSE: cur = ""
            DO WHILE i <= LEN(ln)
                IF CutIsCmpChar%(ASC(ln, i)) = 0 THEN EXIT DO
                cur = cur + CHR$(ASC(ln, i))
                i = i + 1
            LOOP
            i = i - 1
            CutPushTok cur, FALSE
            cur = ""
            _CONTINUE
        END IF

        cur = cur + CHR$(chcode)
    NEXT i

    IF LEN(cur) > 0 THEN CutPushTok cur, inq
    IF inq THEN CutErrAdd 1, 0, "unterminated quote"
END SUB

SUB CutPushTok (t AS STRING, wasq AS INTEGER)
    DIM s AS STRING, p AS INTEGER, a AS STRING, b AS STRING
    s = t
    IF LEN(s) = 0 THEN
        IF NOT wasq THEN EXIT SUB
    END IF

    '--- `1600x1200` is one token to the splitter but two numbers to a human.
    '    Only split when BOTH sides are numeric, so a path like `fx/box2x.png`
    '    survives. ---
    IF NOT wasq THEN
        p = INSTR(LCASE$(s), "x")
        IF p > 1 THEN
            a = LEFT$(s, p - 1)
            b = MID$(s, p + 1)
            IF CutIsNum%(a) THEN
                IF CutIsNum%(b) THEN
                    CutPushTok a, FALSE
                    CutPushTok b, FALSE
                    EXIT SUB
                END IF
            END IF
        END IF
    END IF

    IF CUT_NTK >= CUT_MAXTOK THEN EXIT SUB
    CUT_NTK = CUT_NTK + 1
    CUT_TK(CUT_NTK) = s
    CUT_TKQ(CUT_NTK) = wasq
END SUB

'--- token accessors that never go out of range: a truncated line should
'    produce a diagnostic, not a subscript error. ---
FUNCTION CutTok$ (i AS INTEGER)
    IF i < 1 _ORELSE i > CUT_NTK THEN CutTok$ = "": EXIT FUNCTION
    CutTok$ = CUT_TK(i)
END FUNCTION

FUNCTION CutTokL$ (i AS INTEGER)
    CutTokL$ = LCASE$(CutTok$(i))
END FUNCTION

'--- find a bare (unquoted) keyword anywhere after the fixed args ---
FUNCTION CutKw% (kw AS STRING, startat AS INTEGER)
    DIM i AS INTEGER
    FOR i = startat TO CUT_NTK
        IF CUT_TKQ(i) = 0 THEN
            IF LCASE$(CUT_TK(i)) = kw THEN CutKw% = i: EXIT FUNCTION
        END IF
    NEXT i
    CutKw% = -1
END FUNCTION

'--- value of the token AFTER a keyword, or a default if the keyword is absent ---
FUNCTION CutKwNum! (kw AS STRING, startat AS INTEGER, dflt AS SINGLE)
    DIM p AS INTEGER
    p = CutKw%(kw, startat)
    IF p < 0 THEN CutKwNum! = dflt: EXIT FUNCTION
    CutKwNum! = CutNum!(CutTok$(p + 1))
END FUNCTION

FUNCTION CutKwStr$ (kw AS STRING, startat AS INTEGER, dflt AS STRING)
    DIM p AS INTEGER
    p = CutKw%(kw, startat)
    IF p < 0 THEN CutKwStr$ = dflt: EXIT FUNCTION
    CutKwStr$ = CutTok$(p + 1)
END FUNCTION

FUNCTION CutHasKw% (kw AS STRING, startat AS INTEGER)
    IF CutKw%(kw, startat) >= 0 THEN CutHasKw% = TRUE ELSE CutHasKw% = FALSE
END FUNCTION

' ----------------------------------------------------------------------------
'  Enum decoders
' ----------------------------------------------------------------------------
FUNCTION CutEaseCode% (s AS STRING)
    SELECT CASE CutLow$(s)
        CASE "linear", "": CutEaseCode% = EASE_LINEAR
        CASE "in": CutEaseCode% = EASE_IN
        CASE "out": CutEaseCode% = EASE_OUT
        CASE "inout": CutEaseCode% = EASE_INOUT
        CASE "incubic": CutEaseCode% = EASE_INCUBIC
        CASE "outcubic": CutEaseCode% = EASE_OUTCUBIC
        CASE "inoutcubic", "smooth": CutEaseCode% = EASE_INOUTCUBIC
        CASE "back": CutEaseCode% = EASE_BACK
        CASE "bounce": CutEaseCode% = EASE_BOUNCE
        CASE ELSE: CutEaseCode% = -1
    END SELECT
END FUNCTION

FUNCTION CutDirCode% (s AS STRING)
    SELECT CASE CutLow$(s)
        CASE "left", "l": CutDirCode% = DIR_L
        CASE "right", "r": CutDirCode% = DIR_R
        CASE "up", "u": CutDirCode% = DIR_U
        CASE "down", "d": CutDirCode% = DIR_D
        CASE ELSE: CutDirCode% = -1
    END SELECT
END FUNCTION

FUNCTION CutAnchorCode% (s AS STRING)
    SELECT CASE CutLow$(s)
        CASE "l", "left": CutAnchorCode% = ANC_L
        CASE "r", "right": CutAnchorCode% = ANC_R
        CASE ELSE: CutAnchorCode% = ANC_C
    END SELECT
END FUNCTION

'--- Named colours. A cut-scene names a colour the way the theme system does,
'    so a pack can restyle later; `#RRGGBB` is the escape hatch. Unknown names
'    return the fallback rather than failing, which is the same "missing means
'    unchanged" rule Thm~& and Say$ use. ---
FUNCTION CutColor~& (k AS STRING, fallback AS _UNSIGNED LONG)
    DIM s AS STRING, h AS STRING, r AS LONG, g AS LONG, b AS LONG
    s = CutLow$(k)
    IF LEN(s) = 0 THEN CutColor~& = fallback: EXIT FUNCTION

    IF LEFT$(s, 1) = "#" THEN
        h = MID$(s, 2)
        IF LEN(h) = 6 THEN
            r = VAL("&H" + MID$(h, 1, 2))
            g = VAL("&H" + MID$(h, 3, 2))
            b = VAL("&H" + MID$(h, 5, 2))
            CutColor~& = _RGB32(r, g, b)
            EXIT FUNCTION
        END IF
        CutColor~& = fallback
        EXIT FUNCTION
    END IF

    SELECT CASE s
        CASE "black": CutColor~& = _RGB32(0, 0, 0)
        CASE "white": CutColor~& = _RGB32(255, 255, 255)
        CASE "red": CutColor~& = _RGB32(200, 40, 40)
        CASE "blood": CutColor~& = _RGB32(120, 12, 12)
        CASE "green": CutColor~& = _RGB32(60, 200, 90)
        CASE "blue": CutColor~& = _RGB32(60, 110, 220)
        CASE "cyan": CutColor~& = _RGB32(80, 220, 220)
        CASE "magenta": CutColor~& = _RGB32(210, 80, 210)
        CASE "yellow": CutColor~& = _RGB32(240, 220, 90)
        CASE "gold": CutColor~& = _RGB32(220, 170, 60)
        CASE "orange": CutColor~& = _RGB32(230, 130, 50)
        CASE "grey", "gray", "dim": CutColor~& = _RGB32(130, 130, 140)
        CASE "bone": CutColor~& = _RGB32(226, 218, 196)
        CASE ELSE: CutColor~& = fallback
    END SELECT
END FUNCTION

' ----------------------------------------------------------------------------
'  Emit
' ----------------------------------------------------------------------------
FUNCTION CutEmit% (cmd AS INTEGER, s1 AS LONG, s2 AS LONG, n1 AS SINGLE, n2 AS SINGLE, n3 AS SINGLE, n4 AS SINGLE, ln AS INTEGER, isasync AS INTEGER)
    IF CUT_NOP >= CUT_MAXOP THEN
        CutErrAdd 2, ln, "scene too long (max" + STR$(CUT_MAXOP) + " instructions)"
        CutEmit% = CUT_NOP
        EXIT FUNCTION
    END IF
    CUT_NOP = CUT_NOP + 1
    CUT_OPS(CUT_NOP).cmd = cmd
    CUT_OPS(CUT_NOP).s1 = s1
    CUT_OPS(CUT_NOP).s2 = s2
    CUT_OPS(CUT_NOP).n1 = n1
    CUT_OPS(CUT_NOP).n2 = n2
    CUT_OPS(CUT_NOP).n3 = n3
    CUT_OPS(CUT_NOP).n4 = n4
    CUT_OPS(CUT_NOP).srcline = ln
    CUT_OPS(CUT_NOP).async = isasync
    CutEmit% = CUT_NOP
END FUNCTION

' ----------------------------------------------------------------------------
'  Source loading, with `include`.
'
'  Every line keeps its ORIGINAL file and line number, so an error inside an
'  included file reports where the author actually typed it rather than an
'  offset into a concatenation they never see.
' ----------------------------------------------------------------------------
SUB CutLoadSource (path AS STRING, depth AS INTEGER)
    DIM raw AS STRING, i AS LONG, ln AS STRING, lineno AS INTEGER
    DIM chunk AS STRING, p AS LONG, t AS STRING

    IF depth > CUT_MAXINC THEN
        CutErrAdd 2, 0, "include nested too deep: " + path
        EXIT SUB
    END IF
    IF NOT _FILEEXISTS(path) THEN
        CutErrAdd 2, 0, "cannot open " + path
        EXIT SUB
    END IF

    raw = _READFILE$(path)
    lineno = 0
    p = 1
    DO WHILE p <= LEN(raw)
        i = INSTR(p, raw, CHR$(10))
        IF i = 0 THEN i = LEN(raw) + 1
        chunk = MID$(raw, p, i - p)
        IF RIGHT$(chunk, 1) = CHR$(13) THEN chunk = LEFT$(chunk, LEN(chunk) - 1)
        p = i + 1
        lineno = lineno + 1

        ln = _TRIM$(chunk)
        IF LEN(ln) = 0 THEN _CONTINUE
        IF LEFT$(ln, 1) = "'" THEN _CONTINUE
        IF LEFT$(ln, 1) = "#" THEN _CONTINUE

        '--- an include is spliced in place, so a scene reads top to bottom ---
        IF LCASE$(LEFT$(ln, 8)) = "include " THEN
            CutTokenize ln
            t = CutTok$(2)
            IF LEN(t) > 0 THEN
                IF INSTR(t, "/") = 0 THEN t = CutDirOf$(path) + t
                CutLoadSource t, depth + 1
            ELSE
                CutErrAdd 2, lineno, "include needs a file name"
            END IF
            _CONTINUE
        END IF

        IF CUT_NSRC >= CUT_MAXLINE THEN
            CutErrAdd 2, lineno, "source too long"
            EXIT SUB
        END IF
        CUT_NSRC = CUT_NSRC + 1
        REDIM _PRESERVE CUT_SRC(0 TO CUT_NSRC) AS STRING
        REDIM _PRESERVE CUT_SRCFILE(0 TO CUT_NSRC) AS STRING
        CUT_SRC(CUT_NSRC) = ln
        CUT_SRCLN(CUT_NSRC) = lineno
        CUT_SRCFILE(CUT_NSRC) = path
    LOOP
END SUB

FUNCTION CutDirOf$ (path AS STRING)
    DIM i AS INTEGER
    FOR i = LEN(path) TO 1 STEP -1
        IF MID$(path, i, 1) = "/" THEN CutDirOf$ = LEFT$(path, i): EXIT FUNCTION
        IF MID$(path, i, 1) = "\" THEN CutDirOf$ = LEFT$(path, i): EXIT FUNCTION
    NEXT i
    CutDirOf$ = ""
END FUNCTION

' ----------------------------------------------------------------------------
'  Labels
' ----------------------------------------------------------------------------
SUB CutAddLabel (nm AS STRING, opix AS INTEGER, ln AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NLBL
        IF LCASE$(_TRIM$(CUT_LBLNAME(i))) = LCASE$(nm) THEN
            CutErrAdd 2, ln, "duplicate label '" + nm + "'"
            EXIT SUB
        END IF
    NEXT i
    IF CUT_NLBL >= CUT_MAXLABEL THEN
        CutErrAdd 2, ln, "too many labels"
        EXIT SUB
    END IF
    CUT_NLBL = CUT_NLBL + 1
    CUT_LBLNAME(CUT_NLBL) = nm
    CUT_LBLOP(CUT_NLBL) = opix
END SUB

FUNCTION CutFindLabel% (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NLBL
        IF LCASE$(_TRIM$(CUT_LBLNAME(i))) = LCASE$(_TRIM$(nm)) THEN
            CutFindLabel% = CUT_LBLOP(i)
            EXIT FUNCTION
        END IF
    NEXT i
    CutFindLabel% = -1
END FUNCTION
