' ============================================================================
'  DATA.bas -- central content loaders for the editable assets/data/*.txt files
'
'  Everything the game rolls on -- the bestiary, treasure pools, magic items,
'  boss names, curio traps, and crit/fumble lines -- lives in plain pipe-delimited
'  text files under assets/data/. Edit those, press F5, and the change is live; no
'  code edit needed. This module reads them and fills the same shared tables the
'  old hard-coded Init* routines used (via the Mob / SetTre / SetItem / AddFX
'  helpers), so the rest of the game is unchanged.
'
'  Format: one record per line, fields separated by '|' and individually TRIMMED
'  (so you may pad with spaces to align columns). Lines beginning with '#' and
'  blank lines are ignored.
' ============================================================================

' UI / system strings from assets/data/strings.txt (key | text, split on the FIRST '|').
SUB LoadStrings
    DIM i AS INTEGER, ln AS STRING, p AS INTEGER
    STR_N = 0
    ReadDataFile "assets/data/strings.txt"
    FOR i = 1 TO DLINE_N
        ln = DLINE(i): p = INSTR(ln, "|")
        IF p > 0 AND STR_N < UBOUND(STR_KEY) THEN
            STR_N = STR_N + 1
            STR_KEY(STR_N) = _TRIM$(LEFT$(ln, p - 1))
            STR_TXT(STR_N) = _TRIM$(MID$(ln, p + 1))
        END IF
    NEXT i
END SUB

' Look up a UI string by key. Missing key -> the key itself (a visible "TODO" signal).
FUNCTION Say$ (k AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO STR_N
        IF STR_KEY(i) = k THEN Say$ = STR_TXT(i): EXIT FUNCTION
    NEXT i
    Say$ = k
END FUNCTION

' Gameplay TUNING knobs (potion/encounter/flee/XP/curio/loiter/move/siren) -- shipped
' defaults, then overridden by assets/data/tuning.txt (KEY | value). Call once at startup
' BEFORE any play (some, e.g. WANDER_GOLD_DIV, are divisors -- must never be left 0).
' Standard 16-colour VGA/CGA RGB -> ANSI foreground SGR code string (aixterm bright 90-97).
' Used to emit .ans starter masks whose colours ANSI_Print renders back to the exact palette.
FUNCTION SGRForColor$ (col AS _UNSIGNED LONG)
    SELECT CASE col
        CASE _RGB32(&H00, &H00, &H00): SGRForColor$ = "30"
        CASE _RGB32(&HAA, &H00, &H00): SGRForColor$ = "31"
        CASE _RGB32(&H00, &HAA, &H00): SGRForColor$ = "32"
        CASE _RGB32(&HAA, &H55, &H00): SGRForColor$ = "33"
        CASE _RGB32(&H00, &H00, &HAA): SGRForColor$ = "34"
        CASE _RGB32(&HAA, &H00, &HAA): SGRForColor$ = "35"
        CASE _RGB32(&H00, &HAA, &HAA): SGRForColor$ = "36"
        CASE _RGB32(&HAA, &HAA, &HAA): SGRForColor$ = "37"
        CASE _RGB32(&H55, &H55, &H55): SGRForColor$ = "90"
        CASE _RGB32(&HFF, &H55, &H55): SGRForColor$ = "91"
        CASE _RGB32(&H55, &HFF, &H55): SGRForColor$ = "92"
        CASE _RGB32(&HFF, &HFF, &H55): SGRForColor$ = "93"
        CASE _RGB32(&H55, &H55, &HFF): SGRForColor$ = "94"
        CASE _RGB32(&HFF, &H55, &HFF): SGRForColor$ = "95"
        CASE _RGB32(&H55, &HFF, &HFF): SGRForColor$ = "96"
        CASE ELSE: SGRForColor$ = "97"
    END SELECT
END FUNCTION

' Same palette -> ANSI BACKGROUND SGR (iCE colors: blink bit 5 = bright bg). A bg+space
' cell fills the WHOLE 8x16 cell solidly (no block-glyph sliver), matching how the masks
' are hand-painted -- and the vendored ANSIPrint renders 5;4x as a bright background.
FUNCTION SGRBgForColor$ (col AS _UNSIGNED LONG)
    DIM f AS INTEGER
    f = VAL(SGRForColor$(col))
    IF f >= 90 THEN SGRBgForColor$ = "5;" + _TRIM$(STR$(f - 90 + 40)) ELSE SGRBgForColor$ = _TRIM$(STR$(f + 10))
END FUNCTION

' Normalise a MASK ANSI for pixel-exact, per-cell colour sampling. Masks are art-as-data:
' every cell must read as EXACTLY its own painted colour. Two things an ANSI editor emits
' break that (see `dungeon.run ansilint`):
'   (1) CRLF line endings -- a canvas-width (132-col) row auto-wraps, then the CRLF advances
'       AGAIN, leaving a blank row between every painted row ("black bands"). Strip CR/LF so
'       the full-width rows just auto-wrap (the working masks have no line breaks at all).
'   (2) sticky SGR attributes -- e.g. a bright iCE background ([5;42m) sets the blink bit, and
'       a following [46m changes only the colour, so the bright bit LEAKS and teal renders as
'       bright cyan. Inject a reset (ESC[0m) before every SGR run so each cell is self-contained.
' Also stop at the 0x1A EOF so a trailing SAUCE record is never rendered as art.
FUNCTION MaskNormalize$ (raw AS STRING)
    DIM nrm AS STRING, i AS INTEGER, b AS INTEGER
    DIM RST AS STRING: RST = CHR$(27) + "[0m"
    FOR i = 1 TO LEN(raw)
        b = ASC(raw, i)
        IF b = 26 THEN EXIT FOR                          ' 0x1A EOF -- SAUCE follows, not art
        IF b = 13 OR b = 10 THEN _CONTINUE               ' drop CR/LF -> rows auto-wrap, no double-advance
        IF b = 27 THEN nrm = nrm + RST                   ' reset before each ESC[ run -> no attribute leak
        nrm = nrm + CHR$(b)
    NEXT i
    MaskNormalize$ = nrm
END FUNCTION

' ============================================================================
'  ANSI <-> CELL GRID.  Read an .ans back into the CHARACTERS and COLOURS that made it, and
'  write a grid back out as .ans.
'
'  Everything else in this engine samples the RENDERED PIXELS, because that is what collision
'  needs. That is the wrong tool for splitting or editing art: from pixels you can tell a cell
'  is white-on-magenta, but not that it is the letter "s" -- you would be reduced to OCR against
'  the CP437 font. The characters are right there in the source file, so read the source.
'
'  Deliberately narrow: the board art is a plain SGR + printable stream with no cursor motion,
'  so this handles SGR (m) and skips any other CSI rather than pretending to be a terminal.
'  Rows AUTO-WRAP at SW columns (the board files carry no line breaks at all) and CR/LF are
'  honoured when present, so a hand-edited file with line endings still reads correctly.
' ============================================================================

' Parse `raw` into per-cell character + palette INDEX (0-15) arrays. Cells the file never
' writes are left as space on black. Stops at the 0x1A EOF so SAUCE is never parsed as art.
SUB AnsiToCells (raw AS STRING, chOut() AS INTEGER, fgOut() AS INTEGER, bgOut() AS INTEGER)
    DIM i AS LONG, b AS INTEGER, cx AS INTEGER, cy AS INTEGER
    DIM fg AS INTEGER, bg AS INTEGER, bold AS INTEGER, blink AS INTEGER
    DIM prm AS STRING, fin AS STRING, n AS INTEGER, p AS INTEGER, v AS INTEGER
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1: chOut(cx, cy) = 32: fgOut(cx, cy) = 7: bgOut(cx, cy) = 0: NEXT cx
    NEXT cy
    fg = 7: bg = 0: bold = 0: blink = 0: cx = 0: cy = 0
    i = 1
    DO WHILE i <= LEN(raw)
        b = ASC(raw, i)
        IF b = 26 THEN EXIT DO                             ' 0x1A -- SAUCE follows, not art
        IF b = 27 AND i < LEN(raw) THEN
            IF MID$(raw, i + 1, 1) = "[" THEN
                ' gather the parameter bytes, then the final letter
                prm = "": i = i + 2
                DO WHILE i <= LEN(raw)
                    fin = MID$(raw, i, 1)
                    IF fin >= "0" AND fin <= "9" THEN
                        prm = prm + fin
                    ELSEIF fin = ";" THEN
                        prm = prm + ";"
                    ELSE
                        EXIT DO
                    END IF
                    i = i + 1
                LOOP
                IF i <= LEN(raw) THEN fin = MID$(raw, i, 1) ELSE fin = ""
                IF fin = "m" THEN
                    IF LEN(prm) = 0 THEN prm = "0"
                    p = 1
                    DO WHILE p <= LEN(prm)
                        n = INSTR(p, prm, ";"): IF n = 0 THEN n = LEN(prm) + 1
                        v = VAL(MID$(prm, p, n - p))
                        SELECT CASE v
                            CASE 0: fg = 7: bg = 0: bold = 0: blink = 0
                            CASE 1: bold = -1
                            CASE 5: blink = -1
                            CASE 22: bold = 0
                            CASE 25: blink = 0
                            CASE 30 TO 37: fg = v - 30
                            CASE 40 TO 47: bg = v - 40
                            CASE 90 TO 97: fg = v - 90: bold = -1
                            CASE 100 TO 107: bg = v - 100: blink = -1
                        END SELECT
                        p = n + 1
                    LOOP
                END IF
                i = i + 1
                _CONTINUE                                   ' any other CSI: consumed, ignored
            END IF
        END IF
        i = i + 1
        IF b = 10 THEN cx = 0: cy = cy + 1: _CONTINUE
        IF b = 13 THEN cx = 0: _CONTINUE
        IF b = 27 THEN _CONTINUE                            ' a bare ESC we did not understand
        IF cx >= 0 AND cx <= SW - 1 AND cy >= 0 AND cy <= SH - 1 THEN
            chOut(cx, cy) = b
            ' NOT `fg + 8 * (bold <> 0)`: BASIC TRUE is -1, so that SUBTRACTS 8 and hands back
            ' a negative palette index. Every bright cell then matched nothing.
            IF bold THEN fgOut(cx, cy) = fg + 8 ELSE fgOut(cx, cy) = fg
            IF blink THEN bgOut(cx, cy) = bg + 8 ELSE bgOut(cx, cy) = bg
        END IF
        cx = cx + 1
        IF cx >= SW THEN cx = 0: cy = cy + 1                ' auto-wrap, exactly as ANSI_Print does
    LOOP
END SUB

' Emit a cell grid as .ans. Writes a full SGR (with a leading reset) only when the attribute
' actually changes -- the reset is what stops the sticky-attribute leak MaskNormalize$ exists
' to repair, so a file written here is already clean. No line breaks: rows auto-wrap at SW,
' which is how the working board art is stored.
FUNCTION CellsToAnsi$ (chIn() AS INTEGER, fgIn() AS INTEGER, bgIn() AS INTEGER, rows AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER, s AS STRING, lastf AS INTEGER, lastb AS INTEGER
    lastf = -1: lastb = -1
    FOR cy = 0 TO rows - 1
        FOR cx = 0 TO SW - 1
            IF fgIn(cx, cy) <> lastf OR bgIn(cx, cy) <> lastb THEN
                s = s + CHR$(27) + "[0;" + SgrPair$(fgIn(cx, cy), bgIn(cx, cy)) + "m"
                lastf = fgIn(cx, cy): lastb = bgIn(cx, cy)
            END IF
            s = s + CHR$(chIn(cx, cy))
        NEXT cx
    NEXT cy
    CellsToAnsi$ = s
END FUNCTION

' fg/bg palette indexes (0-15) -> the SGR parameter list, iCE style: bold for bright ink,
' the blink bit for a bright background (which is how the vendored ANSIPrint reads them).
FUNCTION SgrPair$ (f AS INTEGER, b AS INTEGER)
    DIM s AS STRING
    IF f >= 8 THEN s = "1;" + _TRIM$(STR$(30 + f - 8)) ELSE s = _TRIM$(STR$(30 + f))
    IF b >= 8 THEN s = s + ";5;" + _TRIM$(STR$(40 + b - 8)) ELSE s = s + ";" + _TRIM$(STR$(40 + b))
    SgrPair$ = s
END FUNCTION

' Mystic-BBS-style PIPE COLOURS for console (CLI-mode) output -> ANSI SGR. Self-contained (no
' QB64_GJ_LIB dependency) so the game still builds from a plain checkout, and using the same
' |NN notation as QB64_GJ_LIB/PIPEPRINT: |00-|15 foreground (|10 bright green = OK, |12 bright
' red = BAD, |14 yellow = WARN, |07 grey = reset-ish), |16-|23 background, |PI = a literal '|'.
' Honours CLI_COLOR (off -> the codes are stripped, leaving plain text -- e.g. NO_COLOR or a
' non-terminal). A reset is appended so colour never bleeds past the string.
FUNCTION PipeCol$ (s AS STRING)
    DIM r AS STRING, i AS INTEGER, code AS STRING, sgr AS STRING
    i = 1
    DO WHILE i <= LEN(s)
        IF MID$(s, i, 1) = "|" AND i + 2 <= LEN(s) THEN
            code = MID$(s, i, 3)
            IF code = "|PI" THEN
                r = r + "|": i = i + 3
            ELSE
                sgr = PipeSGR$(code)
                IF LEN(sgr) > 0 THEN
                    IF CLI_COLOR THEN r = r + CHR$(27) + "[" + sgr + "m"
                    i = i + 3
                ELSE
                    r = r + MID$(s, i, 1): i = i + 1
                END IF
            END IF
        ELSE
            r = r + MID$(s, i, 1): i = i + 1
        END IF
    LOOP
    IF CLI_COLOR THEN r = r + CHR$(27) + "[0m"
    PipeCol$ = r
END FUNCTION

' A pipe colour code (|00..|23) -> the ANSI SGR parameter, or "" if not a colour code.
FUNCTION PipeSGR$ (code AS STRING)
    SELECT CASE code
        CASE "|00": PipeSGR$ = "30"          '  0 black
        CASE "|01": PipeSGR$ = "34"          '  1 blue
        CASE "|02": PipeSGR$ = "32"          '  2 green
        CASE "|03": PipeSGR$ = "36"          '  3 cyan
        CASE "|04": PipeSGR$ = "31"          '  4 red
        CASE "|05": PipeSGR$ = "35"          '  5 magenta
        CASE "|06": PipeSGR$ = "33"          '  6 brown/yellow
        CASE "|07": PipeSGR$ = "37"          '  7 light grey
        CASE "|08": PipeSGR$ = "90"          '  8 dark grey
        CASE "|09": PipeSGR$ = "94"          '  9 bright blue
        CASE "|10": PipeSGR$ = "92"          ' 10 bright green   (OK)
        CASE "|11": PipeSGR$ = "96"          ' 11 bright cyan
        CASE "|12": PipeSGR$ = "91"          ' 12 bright red     (BAD)
        CASE "|13": PipeSGR$ = "95"          ' 13 bright magenta
        CASE "|14": PipeSGR$ = "93"          ' 14 yellow         (WARN)
        CASE "|15": PipeSGR$ = "97"          ' 15 white
        CASE "|16": PipeSGR$ = "40"          ' 16-23 backgrounds
        CASE "|17": PipeSGR$ = "44"
        CASE "|18": PipeSGR$ = "42"
        CASE "|19": PipeSGR$ = "46"
        CASE "|20": PipeSGR$ = "41"
        CASE "|21": PipeSGR$ = "45"
        CASE "|22": PipeSGR$ = "43"
        CASE "|23": PipeSGR$ = "47"
    END SELECT
END FUNCTION

' Build a 128-byte SAUCE record (Character/ANSi, IBM VGA font) for an ANSI of cols x rows,
' where datalen = the byte length of the art before the 0x1A EOF marker.
FUNCTION SauceRecord$ (title AS STRING, cols AS INTEGER, rows AS INTEGER, datalen AS LONG)
    DIM s AS STRING
    s = "SAUCE" + "00"
    s = s + PadR$(title, 35) + PadR$("grymmjack", 20) + PadR$("", 20)
    s = s + MID$(DATE$, 7, 4) + MID$(DATE$, 1, 2) + MID$(DATE$, 4, 2)   ' Date CCYYMMDD
    s = s + MKL$(datalen) + CHR$(1) + CHR$(1)                            ' FileSize, DataType Char, FileType ANSi
    s = s + MKI$(cols) + MKI$(rows) + MKI$(0) + MKI$(0)                  ' TInfo1..4
    ' TFlags &H13: bit 0 = iCE COLOURS, bits 1-2 = 8-pixel font, bits 3-4 = square pixels.
    ' Bit 0 is not optional here -- this art paints bright BACKGROUNDS, and a bright background
    ' is spelled with the blink bit. An editor told "iCE off" honours that literally: it drops
    ' the bit and renders every bright background as its dim twin, so the yellow halls read as
    ' brown. Leaving TFlags at 0 made every generator quietly strip the flag off hand-fixed art.
    s = s + CHR$(0) + CHR$(&H13) + "IBM VGA" + STRING$(15, 0)            ' Comments, TFlags, font
    SauceRecord$ = s
END FUNCTION

' Parse a "RRGGBB" (or "#RRGGBB") hex colour string to _RGB32. Black on a bad value.
FUNCTION HexRGB~& (h AS STRING)
    DIM s AS STRING
    s = _TRIM$(h): IF LEFT$(s, 1) = "#" THEN s = MID$(s, 2)
    IF LEN(s) < 6 THEN HexRGB~& = _RGB32(0, 0, 0): EXIT FUNCTION
    HexRGB~& = _RGB32(VAL("&H" + MID$(s, 1, 2)), VAL("&H" + MID$(s, 3, 2)), VAL("&H" + MID$(s, 5, 2)))
END FUNCTION

' Field n (1-based) of a pipe-delimited line, trimmed. "" if there aren't that many.
FUNCTION DField$ (ln AS STRING, n AS INTEGER)
    DIM s AS STRING, p AS INTEGER, i AS INTEGER
    s = ln
    FOR i = 1 TO n - 1
        p = INSTR(s, "|")
        IF p = 0 THEN DField$ = "": EXIT FUNCTION
        s = MID$(s, p + 1)
    NEXT i
    p = INSTR(s, "|")
    IF p > 0 THEN s = LEFT$(s, p - 1)
    DField$ = _TRIM$(s)
END FUNCTION

' Read a data file into DLINE()/DLINE_N, dropping comments and blank lines. A whole
' -file read (_READFILE$) side-steps QB64's line-input EOF quirk; CR and LF both end
' a line. DLINE is a shared scratch buffer -- consume it before the next ReadDataFile.
' Route an "assets/data/<f>" or "assets/flavor/<f>" path through the selected DATA PACK.
' Every data/flavor file now lives under a named pack subfolder (default = "assets/data/default/").
' The chosen pack is tried first per-file; anything it doesn't ship falls back to the "default"
' pack -- so a partial pack overrides only the tables/flavor it replaces. A pack IS a whole game:
' swap monsters/treasures/tuning/classes/strings/flavor and you have a different DUNGEON!.
' Non-data paths pass through untouched. Applies on next launch (data loads once at startup).
FUNCTION DataPath$ (p AS STRING)
    DIM pfx AS STRING, rest AS STRING, pk AS STRING, cand AS STRING
    IF LEFT$(p, 12) = "assets/data/" THEN
        pfx = "assets/data/": rest = MID$(p, 13)
    ELSEIF LEFT$(p, 14) = "assets/flavor/" THEN
        pfx = "assets/flavor/": rest = MID$(p, 15)
    ELSE
        DataPath$ = p: EXIT FUNCTION
    END IF
    pk = _TRIM$(opt_datapack)
    IF pk = "" THEN pk = "default"
    IF pk <> "default" THEN
        cand = pfx + pk + "/" + rest
        IF _FILEEXISTS(cand) THEN DataPath$ = cand: EXIT FUNCTION
    END IF
    DataPath$ = pfx + "default/" + rest
END FUNCTION

' Fill DATAPACKS() with every subfolder of assets/data/ (each is a data pack, incl "default").
' A data pack bundles the game's content -- monsters/treasures/items/tuning/classes/strings + the
' assets/flavor/<same-name>/ prose -- so the folder list IS the list of installable "games".
' Same model as ScanAnsiPacks: a vanished saved pick falls back to "default".
SUB ScanDataPacks
    DIM e AS STRING, nm AS STRING
    DATAPACK_N = 0
    IF _DIREXISTS("assets/data/") THEN
        e = _FILES$("assets/data/")
        DO WHILE LEN(e) > 0
            IF RIGHT$(e, 1) = "/" THEN
                nm = LEFT$(e, LEN(e) - 1)
                IF nm <> "." AND nm <> ".." AND DATAPACK_N < UBOUND(DATAPACKS) THEN DATAPACK_N = DATAPACK_N + 1: DATAPACKS(DATAPACK_N) = nm
            END IF
            e = _FILES$
        LOOP
    END IF
    IF PackIndex%(DATAPACKS(), DATAPACK_N, opt_datapack) = 0 THEN opt_datapack = "default"
END SUB

' Cycle the data pack by delta. Data is loaded ONCE at startup (tables + flavor + strings), so a
' pack change fully applies on the NEXT launch -- same as the ANSI board pack. The pick is saved now.
SUB CycleDataPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(DATAPACKS(), DATAPACK_N, opt_datapack) + delta
    IF idx < 1 THEN idx = DATAPACK_N
    IF idx > DATAPACK_N THEN idx = 1
    opt_datapack = DATAPACKS(idx)
    Sfx "select"
END SUB

SUB ReadDataFile (path AS STRING)
    DIM raw AS STRING, i AS INTEGER, ch2 AS STRING, ln AS STRING, rp AS STRING
    DLINE_N = 0
    rp = DataPath$(path)                              ' route through the selected data pack (default fallback)
    IF _FILEEXISTS(rp) = 0 THEN EXIT SUB
    raw = _READFILE$(rp)
    ln = ""
    FOR i = 1 TO LEN(raw)
        ch2 = MID$(raw, i, 1)
        IF ch2 = CHR$(10) OR ch2 = CHR$(13) THEN
            AddDataLine ln: ln = ""
        ELSE
            ln = ln + ch2
        END IF
    NEXT i
    AddDataLine ln
END SUB

SUB AddDataLine (ln AS STRING)
    IF LEN(_TRIM$(ln)) = 0 THEN EXIT SUB
    IF LEFT$(_TRIM$(ln), 1) = "#" THEN EXIT SUB
    IF DLINE_N >= UBOUND(DLINE) THEN EXIT SUB
    DLINE_N = DLINE_N + 1: DLINE(DLINE_N) = ln
END SUB

' NOTE: the DUNGEON!-specific data loaders (LoadTuning / LoadMonsters /
' LoadTreasures / LoadItems / LoadBosses / LoadEffects / LoadTraps) moved to
' game/LOADERS.bas so this module stays game-free (a pure reader + ANSI/SGR/
' SAUCE utilities). They still drive ReadDataFile / DField$ above (game -> engine).
