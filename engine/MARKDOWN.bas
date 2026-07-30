' ============================================================================
'  MARKDOWN.bas -- ENGINE markdown -> text-mode renderer (game-agnostic).
'
'  Extracted from CHRONICLE.bas. Renders a markdown string onto the CP437 grid
'  with coloured headings, **bold**, `code`, - bullets, --- rules, tables, and
'  CLICKABLE links (mouse hit-tested each frame). Includes the text helpers
'  RulesStrip$ / Utf8ToAscii$ (typographic UTF-8 -> ASCII folding). SubstAll$ is in TEXT.bas.
'  The game's rules screen (ShowRules, in game/CHRONICLE.bas) drives this.
'  No game symbols -- reusable by any text-mode game.
' ============================================================================

' Open a URL in the system browser (Linux xdg-open; the game targets Linux).
SUB MdOpenURL (url AS STRING)
    DIM u AS STRING: u = _TRIM$(url)
    IF LEN(u) = 0 THEN EXIT SUB
    SHELL _DONTWAIT "xdg-open " + CHR$(34) + u + CHR$(34)
END SUB

' Style byte for the current inline state (code beats bold if somehow both).
FUNCTION StyOf% (bold AS INTEGER, code AS INTEGER)
    IF code THEN StyOf% = 2: EXIT FUNCTION
    IF bold THEN StyOf% = 1: EXIT FUNCTION
    StyOf% = 0
END FUNCTION

' Register a link URL, returning its id (1-based). Caps at the array bound.
FUNCTION AddURL% (u AS STRING, url() AS STRING, nurl AS INTEGER)
    IF nurl >= UBOUND(url) THEN AddURL% = 0: EXIT FUNCTION
    nurl = nurl + 1: url(nurl) = _TRIM$(u): AddURL% = nurl
END FUNCTION

' Append one char to the three parallel attribute strings.
SUB EmitCh (vis AS STRING, sty AS STRING, lnk AS STRING, chx AS STRING, styb AS INTEGER, lnkid AS INTEGER)
    vis = vis + chx: sty = sty + CHR$(styb): lnk = lnk + CHR$(lnkid)
END SUB

' Colour for a character given its block kind + style byte + whether it's the hovered link.
FUNCTION MdColor~& (knd AS INTEGER, styb AS INTEGER, lnkb AS INTEGER, hovid AS INTEGER)
    IF lnkb > 0 THEN
        IF lnkb = hovid THEN MdColor~& = _RGB32(255, 255, 130) ELSE MdColor~& = _RGB32(120, 200, 255)
        EXIT FUNCTION
    END IF
    IF styb = 2 THEN MdColor~& = _RGB32(130, 235, 130): EXIT FUNCTION   ' `code`
    IF styb = 3 THEN MdColor~& = _RGB32(90, 140, 180): EXIT FUNCTION    ' table borders/rules
    IF styb = 1 THEN MdColor~& = _RGB32(255, 255, 255): EXIT FUNCTION   ' **bold**
    SELECT CASE knd
        CASE 1: MdColor~& = _RGB32(255, 220, 80)      ' # heading
        CASE 2: MdColor~& = _RGB32(120, 220, 255)     ' ## heading
        CASE 3: MdColor~& = _RGB32(150, 235, 150)     ' ### heading
        CASE 8: MdColor~& = _RGB32(170, 170, 190)     ' > quote
        CASE ELSE: MdColor~& = _RGB32(210, 205, 190)  ' body
    END SELECT
END FUNCTION

' Classify one raw line -> block kind, and set `content` to the marker-stripped text.
' kinds: 1-3 heading, 4 list, 5 rule, 6 table, 7 blank, 8 quote, 0 normal.
FUNCTION MdBlock% (raw AS STRING, content AS STRING)
    DIM t AS STRING, tt AS STRING, h AS INTEGER, ii AS INTEGER, allh AS INTEGER
    t = raw: tt = _TRIM$(t)
    IF LEN(tt) = 0 THEN content = "": MdBlock% = 7: EXIT FUNCTION
    IF LEN(tt) >= 3 THEN                                  ' horizontal rule (all dashes)
        allh = -1
        FOR ii = 1 TO LEN(tt): IF MID$(tt, ii, 1) <> "-" THEN allh = 0
        NEXT
        IF allh THEN content = "": MdBlock% = 5: EXIT FUNCTION
    END IF
    IF LEFT$(t, 1) = "#" THEN                             ' heading
        h = 0
        DO WHILE MID$(t, h + 1, 1) = "#": h = h + 1: LOOP
        content = _TRIM$(MID$(t, h + 1)): IF h > 3 THEN h = 3
        MdBlock% = h: EXIT FUNCTION
    END IF
    IF LEFT$(t, 2) = "- " OR LEFT$(t, 2) = "* " THEN content = _TRIM$(MID$(t, 3)): MdBlock% = 4: EXIT FUNCTION
    IF LEFT$(tt, 1) = "|" THEN content = tt: MdBlock% = 6: EXIT FUNCTION
    IF LEFT$(t, 2) = "> " THEN content = _TRIM$(MID$(t, 3)): MdBlock% = 8: EXIT FUNCTION
    content = t: MdBlock% = 0
END FUNCTION

' Parse inline markdown of `raw` into the three parallel attribute strings, collecting
' link URLs. Handles **bold**, `code`, [text](url), and <url> autolinks.
SUB MdInline (raw AS STRING, vis AS STRING, sty AS STRING, lnk AS STRING, url() AS STRING, nurl AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER, chx AS STRING, c2 AS STRING, bold AS INTEGER, code AS INTEGER
    DIM j AS INTEGER, k2 AS INTEGER, txt AS STRING, u AS STRING, id AS INTEGER, m AS INTEGER
    vis = "": sty = "": lnk = "": bold = 0: code = 0
    n = LEN(raw): i = 1
    DO WHILE i <= n
        chx = MID$(raw, i, 1): c2 = MID$(raw, i + 1, 1)
        IF chx = "*" AND c2 = "*" THEN
            bold = NOT bold: i = i + 2
        ELSEIF chx = "`" THEN
            code = NOT code: i = i + 1
        ELSEIF chx = "[" THEN
            j = INSTR(i, raw, "]")
            IF j > 0 AND MID$(raw, j + 1, 1) = "(" THEN
                k2 = INSTR(j + 2, raw, ")")
                IF k2 > 0 THEN
                    txt = MID$(raw, i + 1, j - i - 1): u = MID$(raw, j + 2, k2 - j - 2)
                    id = AddURL%(u, url(), nurl)
                    FOR m = 1 TO LEN(txt): EmitCh vis, sty, lnk, MID$(txt, m, 1), 0, id: NEXT
                    i = k2 + 1
                ELSE
                    EmitCh vis, sty, lnk, chx, StyOf%(bold, code), 0: i = i + 1
                END IF
            ELSE
                EmitCh vis, sty, lnk, chx, StyOf%(bold, code), 0: i = i + 1
            END IF
        ELSEIF chx = "<" AND MID$(raw, i, 5) = "<http" THEN   ' <http://...> or <https://...> autolink
            j = INSTR(i, raw, ">")
            IF j > 0 THEN
                u = MID$(raw, i + 1, j - i - 1): id = AddURL%(u, url(), nurl)
                FOR m = 1 TO LEN(u): EmitCh vis, sty, lnk, MID$(u, m, 1), 0, id: NEXT
                i = j + 1
            ELSE
                EmitCh vis, sty, lnk, chx, StyOf%(bold, code), 0: i = i + 1
            END IF
        ELSE
            EmitCh vis, sty, lnk, chx, StyOf%(bold, code), 0: i = i + 1
        END IF
    LOOP
END SUB

' Word-wrap the attribute triplet to width W, appending each display line (with its
' block kind) to the doc arrays. A blank input still emits one line (spacing).
SUB WrapEmit (tvis AS STRING, tsty AS STRING, tlnk AS STRING, knd AS INTEGER, vis() AS STRING, sty() AS STRING, lnk() AS STRING, kind() AS INTEGER, n AS INTEGER, W AS INTEGER)
    DIM cut AS INTEGER, ii AS INTEGER
    IF LEN(tvis) = 0 THEN
        IF n < UBOUND(vis) THEN n = n + 1: vis(n) = "": sty(n) = "": lnk(n) = "": kind(n) = knd
        EXIT SUB
    END IF
    DO WHILE LEN(tvis) > 0
        IF n >= UBOUND(vis) THEN EXIT SUB
        IF knd = 6 OR LEN(tvis) <= W THEN                 ' don't wrap table rows
            cut = LEN(tvis)
        ELSE
            cut = 0
            FOR ii = W TO 1 STEP -1
                IF MID$(tvis, ii, 1) = " " THEN cut = ii: EXIT FOR
            NEXT
            IF cut = 0 THEN cut = W
        END IF
        n = n + 1
        vis(n) = LEFT$(tvis, cut): sty(n) = LEFT$(tsty, cut): lnk(n) = LEFT$(tlnk, cut): kind(n) = knd
        tvis = MID$(tvis, cut + 1): tsty = MID$(tsty, cut + 1): tlnk = MID$(tlnk, cut + 1)
        IF LEN(tvis) > 0 THEN
            IF LEFT$(tvis, 1) = " " THEN tvis = MID$(tvis, 2): tsty = MID$(tsty, 2): tlnk = MID$(tlnk, 2)
        END IF
    LOOP
END SUB

' Record a clickable link rect (cell cols c1..c2 on row r -> url id uid) + underline it.
SUB MdHit (x1() AS INTEGER, x2() AS INTEGER, yr() AS INTEGER, uu() AS INTEGER, nh AS INTEGER, c1 AS INTEGER, c2 AS INTEGER, r AS INTEGER, uid AS INTEGER, hovid AS INTEGER)
    IF nh >= UBOUND(x1) THEN EXIT SUB
    nh = nh + 1: x1(nh) = c1: x2(nh) = c2: yr(nh) = r: uu(nh) = uid
    DIM ul AS _UNSIGNED LONG
    IF uid = hovid THEN ul = _RGB32(255, 255, 130) ELSE ul = _RGB32(120, 200, 255)
    LINE (c1 * CW, (r + 1) * CH - 2)-((c2 + 1) * CW - 1, (r + 1) * CH - 2), ul
END SUB

' TRUE if a table cell is a separator cell (only dashes / colons / spaces, at least one dash).
FUNCTION IsDashes% (s AS STRING)
    DIM i AS INTEGER, chx AS STRING, hasdash AS INTEGER
    IF LEN(_TRIM$(s)) = 0 THEN IsDashes% = 0: EXIT FUNCTION
    hasdash = 0
    FOR i = 1 TO LEN(s)
        chx = MID$(s, i, 1)
        IF chx = "-" THEN hasdash = -1 ELSE IF chx <> ":" AND chx <> " " THEN IsDashes% = 0: EXIT FUNCTION
    NEXT
    IsDashes% = hasdash
END FUNCTION

' Render a buffered block of markdown table rows (each "| a | b |") as aligned columns:
' cells padded to the widest in their column, joined by " | " borders, with the |---|
' separator row drawn as a --+-- rule and the header row bolded. Emits ready-to-draw
' attributed display lines into the doc arrays.
SUB EmitTable (tbl() AS STRING, ntbl AS INTEGER, url() AS STRING, nurl AS INTEGER, vis() AS STRING, sty() AS STRING, lnk() AS STRING, kind() AS INTEGER, n AS INTEGER)
    CONST MAXC = 8
    DIM r AS INTEGER, col AS INTEGER, ncols AS INTEGER, raw AS STRING, part AS STRING, p2 AS INTEGER
    DIM tv AS STRING, ts AS STRING, tl AS STRING, lv AS STRING, ls AS STRING, ll AS STRING, pad AS INTEGER
    REDIM cvis(1 TO ntbl, 1 TO MAXC) AS STRING, csty(1 TO ntbl, 1 TO MAXC) AS STRING, clnk(1 TO ntbl, 1 TO MAXC) AS STRING
    REDIM ncell(1 TO ntbl) AS INTEGER, issep(1 TO ntbl) AS INTEGER, colw(1 TO MAXC) AS INTEGER
    ncols = 0
    FOR r = 1 TO ntbl                                     ' split every row into attributed cells
        raw = _TRIM$(tbl(r))
        IF LEFT$(raw, 1) = "|" THEN raw = MID$(raw, 2)
        IF RIGHT$(raw, 1) = "|" THEN raw = LEFT$(raw, LEN(raw) - 1)
        issep(r) = -1: col = 0
        DO
            p2 = INSTR(raw, "|")
            IF p2 = 0 THEN part = raw ELSE part = LEFT$(raw, p2 - 1)
            col = col + 1: IF col > MAXC THEN col = MAXC: EXIT DO
            IF NOT IsDashes%(part) THEN issep(r) = 0
            MdInline _TRIM$(part), tv, ts, tl, url(), nurl
            cvis(r, col) = tv: csty(r, col) = ts: clnk(r, col) = tl
            IF LEN(tv) > colw(col) THEN colw(col) = LEN(tv)
            IF p2 = 0 THEN EXIT DO
            raw = MID$(raw, p2 + 1)
        LOOP
        ncell(r) = col: IF col > ncols THEN ncols = col
    NEXT r
    FOR r = 1 TO ntbl                                     ' build each display line
        lv = "  ": ls = STRING$(2, CHR$(0)): ll = STRING$(2, CHR$(0))   ' small indent
        IF issep(r) THEN
            FOR col = 1 TO ncols
                IF col > 1 THEN lv = lv + CHR$(196) + CHR$(197) + CHR$(196): ls = ls + STRING$(3, CHR$(3)): ll = ll + STRING$(3, CHR$(0))
                lv = lv + STRING$(colw(col), CHR$(196)): ls = ls + STRING$(colw(col), CHR$(3)): ll = ll + STRING$(colw(col), CHR$(0))
            NEXT
        ELSE
            FOR col = 1 TO ncols
                IF col > 1 THEN lv = lv + " " + CHR$(179) + " ": ls = ls + CHR$(0) + CHR$(3) + CHR$(0): ll = ll + STRING$(3, CHR$(0))
                tv = cvis(r, col): ts = csty(r, col): tl = clnk(r, col)
                IF r = 1 THEN ts = STRING$(LEN(tv), CHR$(1))   ' header row: bold every cell
                pad = colw(col) - LEN(tv): IF pad < 0 THEN pad = 0
                lv = lv + tv + SPACE$(pad): ls = ls + ts + STRING$(pad, CHR$(0)): ll = ll + tl + STRING$(pad, CHR$(0))
            NEXT
        END IF
        IF n < UBOUND(vis) THEN n = n + 1: vis(n) = lv: sty(n) = ls: lnk(n) = ll: kind(n) = 0
    NEXT r
END SUB

FUNCTION RulesStrip$ (s AS STRING)
    DIM t AS STRING
    t = Utf8ToAscii$(s)                                    ' typographic UTF-8 -> ASCII (the grid font is CP437)
    DO WHILE LEFT$(t, 1) = "#": t = MID$(t, 2): LOOP        ' drop leading heading hashes
    t = SubstAll$(t, "**", "")                             ' drop **bold** and `code` markdown so it reads as plain prose
    t = SubstAll$(t, "`", "")
    RulesStrip$ = _TRIM$(t)
END FUNCTION


' Fold the typographic UTF-8 characters that appear in DUNGEON-RULES.md down to
' plain ASCII, so the CP437 grid font (which renders each UTF-8 byte as its own DOS
' glyph -- the 3 bytes of an em-dash become 3 garbage glyphs) shows clean punctuation
' instead of mojibake. Only the five sequences the file actually uses; sequences are
' built via CHR$ so the source stays pure ASCII.
FUNCTION Utf8ToAscii$ (s AS STRING)
    DIM t AS STRING
    t = s
    t = SubstAll$(t, CHR$(226) + CHR$(128) + CHR$(148), "--")   ' U+2014 em dash
    t = SubstAll$(t, CHR$(226) + CHR$(128) + CHR$(147), "-")    ' U+2013 en dash
    t = SubstAll$(t, CHR$(226) + CHR$(134) + CHR$(146), "->")   ' U+2192 rightwards arrow
    t = SubstAll$(t, CHR$(226) + CHR$(128) + CHR$(166), "...")  ' U+2026 ellipsis
    t = SubstAll$(t, CHR$(194) + CHR$(169), "(c)")              ' U+00A9 copyright
    Utf8ToAscii$ = t
END FUNCTION
