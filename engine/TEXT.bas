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

' Replace every occurrence of `finds` in `s` with `repl`. (Was in game/EFFECTS.bas;
' engine/UI.bas reaches for it when re-labelling a banner, so it belongs here.)
FUNCTION StrSubst$ (s AS STRING, finds AS STRING, repl AS STRING)
    DIM buf AS STRING, p AS INTEGER
    buf = s
    p = INSTR(buf, finds)
    DO WHILE p > 0
        buf = LEFT$(buf, p - 1) + repl + MID$(buf, p + LEN(finds))
        p = INSTR(p + LEN(repl), buf, finds)
    LOOP
    StrSubst$ = buf
END FUNCTION


' Index of `want` in packs(1..cnt), or 0 if absent. A generic array search -- it lived in
' MUSIC.bas but DATA, MUSIC and ARTPACK all use it for pack resolution, so it belongs here
' with the other reusable helpers (and lets those modules be unit-tested without a stub).
' Index of name within packs(0..cnt), or 0 (the main dir) if not present.
FUNCTION PackIndex% (packs() AS STRING, cnt AS INTEGER, want AS STRING)
    DIM i AS INTEGER
    PackIndex = 0
    FOR i = 1 TO cnt
        IF packs(i) = want THEN PackIndex = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' Replace EVERY occurrence of finds with repl. A generic string utility -- it lived in
' MARKDOWN.bas because the markdown renderer was its first caller, but LAYOUT.bas needs it
' too (LayN$ substitutes '#' for a panel index), and reaching into the markdown renderer for
' one substitution would have made every layout consumer depend on the whole md->text stack.
' An empty needle returns the input unchanged rather than looping forever.
FUNCTION SubstAll$ (s AS STRING, finds AS STRING, repl AS STRING)
    DIM acc AS STRING, rest AS STRING, p AS LONG
    IF LEN(finds) = 0 THEN SubstAll$ = s: EXIT FUNCTION
    rest = s: acc = ""
    DO
        p = INSTR(rest, finds)
        IF p = 0 THEN acc = acc + rest: EXIT DO
        acc = acc + LEFT$(rest, p - 1) + repl
        rest = MID$(rest, p + LEN(finds))
    LOOP
    SubstAll$ = acc
END FUNCTION
