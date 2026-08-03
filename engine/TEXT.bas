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

' "RRGGBB" (plus AA when not opaque) for a packed colour. Lives in the ENGINE because the dev
' console's `dump theme` prints it too, and engine/ may not name a game symbol.
FUNCTION HexOf$ (kolor AS _UNSIGNED LONG)   ' `kolor` -- `c` is the shared CURSOR (audit-shadow)
    DIM s AS STRING
    s = HexPair$(_RED32(kolor)) + HexPair$(_GREEN32(kolor)) + HexPair$(_BLUE32(kolor))
    IF _ALPHA32(kolor) <> 255 THEN s = s + HexPair$(_ALPHA32(kolor))
    HexOf$ = s
END FUNCTION

FUNCTION HexPair$ (v AS INTEGER)
    HexPair$ = RIGHT$("0" + HEX$(v), 2)
END FUNCTION

' Is this directory marked NOT-A-PACK?
'
' A folder living under assets/<kind>/ is treated as a content pack, which is right for content
' and wrong for working files that happen to live there -- assets/music/bitwig is a Bitwig Studio
' project (the DAW the music is MADE in), not a music pack. Today it is skipped only because it
' holds no audio; render one loop into it mid-session and it silently becomes a selectable pack
' full of nothing.
'
' Dropping a `qb64-dungeon.ignore` file in a folder says so explicitly and permanently, whatever
' ends up inside it. Every pack scanner asks this.
'
' Lives in TEXT.bas -- the one engine file every unit suite includes -- because the scanners are
' spread across ARTPACK, DATA and MUSIC, and those are compiled IN ISOLATION by their suites.
' Putting a shared helper in any one of them breaks the others' builds (see also HexOf$).
FUNCTION PackIgnored% (dir AS STRING)
    DIM d AS STRING
    d = dir
    IF RIGHT$(d, 1) <> "/" THEN d = d + "/"
    PackIgnored% = _FILEEXISTS(d + PACK_IGNORE_FILE)
END FUNCTION

' The themed colour for `key`, or `fallback` when the theme says nothing about it.
' PURE: reads the table LoadTheme filled and nothing else. It deliberately does not lazy-load --
' that would tie every drawing module to the data reader, and the engine's modules are compiled IN
' ISOLATION by their unit suites (see PackIgnored%, HexOf$). Before LoadTheme runs, THM_N is 0 and
' every call returns its own fallback, which is exactly the no-theme-file answer.
FUNCTION Thm~& (nm AS STRING, fallback AS _UNSIGNED LONG)   ' `nm` -- KEY is reserved
    DIM i AS INTEGER, k AS STRING
    k = LCASE$(_TRIM$(nm))
    FOR i = 1 TO THM_N
        IF THM_KEY(i) = k THEN
            THM_HIT(i) = -1
            Thm~& = THM_VAL(i)
            EXIT FUNCTION
        END IF
    NEXT i
    Thm~& = fallback
END FUNCTION

' As Thm~&, but the ALPHA comes from the caller rather than the theme.
'
' The screen effects compute their own transparency every frame -- blood fades with your wounds,
' the poison wash pulses, the impact flash decays -- so only the RGB is a theme decision. Themeing
' the whole packed colour would freeze the animation at whatever alpha the file happened to name.
FUNCTION ThmA~& (nm AS STRING, fallback AS _UNSIGNED LONG, alpha AS INTEGER)
    DIM kolor AS _UNSIGNED LONG
    kolor = Thm~&(nm, fallback)
    ThmA~& = _RGBA32(_RED32(kolor), _GREEN32(kolor), _BLUE32(kolor), alpha)
END FUNCTION
