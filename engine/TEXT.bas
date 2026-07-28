' ============================================================================
'  TEXT.bas -- ENGINE string / formatting utilities (game-agnostic).
'
'  Small reusable helpers extracted from LORDS.bas so engine modules don't have
'  to reach into a game file for them (PadR$ alone is used in ~5 files). No game
'  symbols. (NthField$ overlaps DField$ in engine/DATA.bas -- candidates to unify
'  in a later util-consolidation pass.)
' ============================================================================

FUNCTION NthField$ (s AS STRING, delim AS STRING, idx AS INTEGER)
    DIM cur AS STRING, q AS INTEGER, i AS INTEGER
    cur = s: i = 1
    DO
        q = INSTR(cur, delim)
        IF q = 0 THEN
            IF i = idx THEN NthField$ = cur
            EXIT FUNCTION
        END IF
        IF i = idx THEN NthField$ = LEFT$(cur, q - 1): EXIT FUNCTION
        cur = MID$(cur, q + LEN(delim)): i = i + 1
    LOOP
END FUNCTION

' fixed width w; when truncating a too-long value keep a trailing space so it
' never butts up against the next column
FUNCTION PadR$ (s AS STRING, w AS INTEGER)
    IF LEN(s) >= w THEN PadR$ = LEFT$(s, w - 1) + " " ELSE PadR$ = s + SPACE$(w - LEN(s))
END FUNCTION

' Seconds -> mm:ss.
FUNCTION MMSS$ (secs AS LONG)
    MMSS$ = _TRIM$(STR$(secs \ 60)) + ":" + RIGHT$("0" + _TRIM$(STR$(secs MOD 60)), 2)
END FUNCTION
