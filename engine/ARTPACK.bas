' ============================================================================
'  ARTPACK.bas -- ENGINE pixel-art layer: load/cache/fit sprites + ART-PACK
'  resolution (game-agnostic).
'
'  Extracted from SPRITES.bas. Loads transparent PNGs on demand, caches hits AND
'  misses, blits scaled-to-fit, resolves a subpath through the selected art pack
'  (pack dir first, then flat main), scans packs, and draws a framed art box.
'  Everything is gated by opt_artstyle and graceful when a file is absent.
'  No game symbols -- the game's entity->sprite mapping lives in game/SPRITES.bas.
' ============================================================================

' Cached image handle for a pixel-art file, loaded once. 0 = missing / failed
' (the miss is cached too, so a missing file isn't re-probed every frame).
FUNCTION Sprite& (path AS STRING)
    DIM i AS INTEGER, h AS LONG
    FOR i = 1 TO SPR_N
        IF SPR_PATH(i) = path THEN Sprite& = SPR_H(i): EXIT FUNCTION
    NEXT
    IF SPR_N >= UBOUND(SPR_H) THEN Sprite& = 0: EXIT FUNCTION
    h = 0
    IF _FILEEXISTS(path) THEN
        h = _LOADIMAGE(path, 32)                  ' 32-bit keeps the alpha channel
        IF h = -1 THEN h = 0                       ' -1 = load failed
    END IF
    SPR_N = SPR_N + 1: SPR_PATH(SPR_N) = path: SPR_H(SPR_N) = h
    Sprite& = h
END FUNCTION

' Blit a sprite scaled to fit inside a px box, centred, aspect preserved.
' Returns TRUE if something was drawn (i.e. the sprite exists).
FUNCTION DrawSpriteFit% (path AS STRING, bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER)
    DIM h AS LONG, iw AS INTEGER, ih AS INTEGER, sc AS SINGLE, dw AS INTEGER, dh AS INTEGER, dx AS INTEGER, dy AS INTEGER
    DrawSpriteFit% = 0
    ' A path may now be EITHER form -- ArtFile$ decides which, per opt_artstyle. ANSI art is
    ' rendered at its authored character size and then scaled here like any other image.
    IF LCASE$(RIGHT$(path, 4)) = ".ans" THEN h = AnsiSprite&(path) ELSE h = Sprite&(path)
    IF h = 0 THEN EXIT FUNCTION
    iw = _WIDTH(h): ih = _HEIGHT(h)
    IF iw < 1 OR ih < 1 THEN EXIT FUNCTION
    sc = bw / iw
    IF bh / ih < sc THEN sc = bh / ih
    dw = INT(iw * sc): dh = INT(ih * sc)
    IF dw < 1 THEN dw = 1
    IF dh < 1 THEN dh = 1
    dx = bx + (bw - dw) \ 2: dy = by + (bh - dh) \ 2
    _PUTIMAGE (dx, dy)-(dx + dw, dy + dh), h, CANVAS
    LogImageDrawn path                          ' asset telemetry: "which art is on screen right now"
    DrawSpriteFit% = -1
END FUNCTION

' Where DrawSpriteFit% will ACTUALLY put a sprite inside a box.
'
' Fitting preserves aspect, so a tall narrow sprite in a wide box is drawn far narrower than the
' box -- meaning anything laid out against the BOX (a caption, text carved onto a gravestone)
' lines up with nothing. Callers that need to place things relative to the IMAGE have to ask.
' Returns 0 if the sprite will not load, in which case dx/dy/dw/dh are the box itself, so a
' fallback drawing still has sane bounds.
FUNCTION SpriteFitRect% (path AS STRING, bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER, dx AS INTEGER, dy AS INTEGER, dw AS INTEGER, dh AS INTEGER)
    DIM h AS LONG, iw AS INTEGER, ih AS INTEGER, sc AS SINGLE
    dx = bx: dy = by: dw = bw: dh = bh
    SpriteFitRect% = 0
    IF LCASE$(RIGHT$(path, 4)) = ".ans" THEN h = AnsiSprite&(path) ELSE h = Sprite&(path)
    IF h = 0 THEN EXIT FUNCTION
    iw = _WIDTH(h): ih = _HEIGHT(h)
    IF iw < 1 OR ih < 1 THEN EXIT FUNCTION
    sc = bw / iw
    IF bh / ih < sc THEN sc = bh / ih
    dw = INT(iw * sc): dh = INT(ih * sc)
    IF dw < 1 THEN dw = 1
    IF dh < 1 THEN dh = 1
    dx = bx + (bw - dw) \ 2: dy = by + (bh - dh) \ 2
    SpriteFitRect% = -1
END FUNCTION

' Resolve a pixel-art file under assets/pixel-art/ with ART-PACK support: try the selected
' pack subdir first (assets/pixel-art/<pack>/<subpath>), then the flat main dir. "" if neither
' exists. `subpath` is e.g. "monsters/undead/skeleton.png". A partial pack overrides only the
' sprites it ships; everything else falls back to the main art.
FUNCTION ArtFile$ (subpath AS STRING)
    DIM px AS STRING, an AS STRING
    px = PixelArtFile$(subpath)
    SELECT CASE opt_artstyle
        CASE ARTSTYLE_PIXEL
            ArtFile$ = px
        CASE ARTSTYLE_ANSI
            ArtFile$ = AnsiArtFile$(subpath)
        CASE ELSE                                   ' HYBRID: the richer form, then the other one
            IF LEN(px) > 0 THEN ArtFile$ = px ELSE ArtFile$ = AnsiArtFile$(subpath)
    END SELECT
END FUNCTION

' The PIXEL half of ArtFile$: selected art pack, then the default pack, per file.
FUNCTION PixelArtFile$ (subpath AS STRING)
    DIM p AS STRING
    IF LEN(opt_artpack) > 0 THEN
        p = "assets/pixel-art/" + opt_artpack + "/" + subpath
        IF _FILEEXISTS(p) THEN PixelArtFile$ = p: EXIT FUNCTION
    END IF
    p = "assets/pixel-art/default/" + subpath       ' fall back to the DEFAULT pack (every pack is a named subfolder)
    IF _FILEEXISTS(p) THEN PixelArtFile$ = p ELSE PixelArtFile$ = ""
END FUNCTION

' The ANSI half: same subpath with .png swapped for .ans, under assets/ansi-art/<pack>/.
' Same per-file pack-then-default fallback, so a partial ANSI pack behaves like a partial
' pixel one.
FUNCTION AnsiArtFile$ (subpath AS STRING)
    DIM sp AS STRING, p AS STRING, dot AS INTEGER
    sp = subpath
    dot = _INSTRREV(sp, ".")
    IF dot > 0 THEN sp = LEFT$(sp, dot - 1)
    sp = sp + ".ans"
    IF LEN(opt_ansipack) > 0 THEN
        p = "assets/ansi-art/" + opt_ansipack + "/" + sp
        IF _FILEEXISTS(p) THEN AnsiArtFile$ = p: EXIT FUNCTION
    END IF
    p = "assets/ansi-art/default/" + sp
    IF _FILEEXISTS(p) THEN AnsiArtFile$ = p ELSE AnsiArtFile$ = ""
END FUNCTION

' Render a .ans entity sprite into a cached image AT ITS AUTHORED CHARACTER SIZE.
'
' The size is not negotiable: ANSI_Print auto-wraps at the destination image's width, so
' rendering 18-column art into a wider image does not scale it, it REFLOWS it into garbage.
' The authored size comes from the file's own SAUCE record (ansimon writes one); 18x12 is the
' fallback, which is what assets/data/art-prompts.txt asks the generator for.
'
' Cached by path, like FightAnsiTile& -- ANSI_Print walks the whole byte stream, and doing that
' per frame for a portrait that never changes would dominate the frame.
FUNCTION AnsiSprite& (path AS STRING)
    DIM i AS INTEGER, img AS LONG, raw AS STRING, prevdest AS LONG
    DIM cols AS INTEGER, rows AS INTEGER
    AnsiSprite& = 0
    FOR i = 1 TO ASPR_N
        IF ASPR_PATH(i) = path THEN AnsiSprite& = ASPR_IMG(i): EXIT FUNCTION
    NEXT i
    IF LEN(path) = 0 THEN EXIT FUNCTION
    IF _FILEEXISTS(path) = 0 THEN EXIT FUNCTION
    raw = _READFILE$(path)
    IF LEN(raw) = 0 THEN EXIT FUNCTION
    AnsiArtDims raw, cols, rows
    img = _NEWIMAGE(cols * 8, rows * 8, 32)
    IF img >= -1 THEN EXIT FUNCTION                 ' _NEWIMAGE failure -- no art rather than a crash
    prevdest = _DEST
    _DEST img
    _FONT 8                                         ' entity art is authored on an 8x8 cell
    CLS , BLACK
    ANSI_Print (raw)
    _DEST prevdest
    IF ASPR_N < ASPR_MAX THEN
        ASPR_N = ASPR_N + 1
        ASPR_PATH(ASPR_N) = path: ASPR_IMG(ASPR_N) = img
    END IF
    AnsiSprite& = img
END FUNCTION

' Authored character dimensions of a .ans, from its SAUCE record. Falls back to 18x12 -- the
' size art-prompts.txt asks for -- when there is no SAUCE or it reports nonsense.
SUB AnsiArtDims (raw AS STRING, cols AS INTEGER, rows AS INTEGER)
    DIM soff AS LONG
    cols = 18: rows = 12
    IF LEN(raw) < 128 THEN EXIT SUB
    soff = LEN(raw) - 128
    IF MID$(raw, soff + 1, 7) <> "SAUCE00" THEN EXIT SUB
    ' `sc`/`sr`, not `c`/`r` -- `c` is the shared CURSOR and QB64 identifiers are
    ' case-insensitive. tests/audit-shadow.sh catches exactly this.
    DIM sc AS INTEGER, sr AS INTEGER
    sc = ASC(raw, soff + 97) + ASC(raw, soff + 98) * 256
    sr = ASC(raw, soff + 99) + ASC(raw, soff + 100) * 256
    IF sc >= 1 AND sc <= 200 THEN cols = sc
    IF sr >= 1 AND sr <= 200 THEN rows = sr
END SUB

' Drop every cached ANSI sprite. Call when the art pack or art style changes -- otherwise a
' switch keeps showing the previous pack's art, and the handles leak.
SUB FreeAnsiSprites
    DIM i AS INTEGER
    FOR i = 1 TO ASPR_N
        IF ASPR_IMG(i) < -1 THEN _FREEIMAGE ASPR_IMG(i)
        ASPR_PATH(i) = "": ASPR_IMG(i) = 0
    NEXT i
    ASPR_N = 0
END SUB

' Fill ARTPACKS() with EVERY subfolder of assets/pixel-art/ -- each one is a pack (including
' "default"). No flat "main" and no category special-casing: the folder list IS the pack list.
' 1..N = pack names. A saved pack that has vanished falls back to "default".
SUB ScanArtPacks
    DIM e AS STRING, nm AS STRING
    ARTPACK_N = 0
    IF _DIREXISTS("assets/pixel-art/") THEN
        e = _FILES$("assets/pixel-art/")
        DO WHILE LEN(e) > 0
            IF RIGHT$(e, 1) = "/" THEN
                nm = LEFT$(e, LEN(e) - 1)
                IF nm <> "." AND nm <> ".." AND ARTPACK_N < UBOUND(ARTPACKS) THEN ARTPACK_N = ARTPACK_N + 1: ARTPACKS(ARTPACK_N) = nm
            END IF
            e = _FILES$
        LOOP
    END IF
    IF PackIndex%(ARTPACKS(), ARTPACK_N, opt_artpack) = 0 THEN opt_artpack = "default"
END SUB

' Cycle the art pack by delta (sprites resolve on demand, so nothing to reload). Packs are
' 1..N (there is no "(main)" 0-slot -- "default" is a normal pack in the list).
SUB CycleArtPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(ARTPACKS(), ARTPACK_N, opt_artpack) + delta
    IF idx < 1 THEN idx = ARTPACK_N
    IF idx > ARTPACK_N THEN idx = 1
    opt_artpack = ARTPACKS(idx)
    Sfx "select"
END SUB

' Resolve an ANSI-art file under assets/ansi-art/ with pack support: selected pack first
' (assets/ansi-art/<pack>/<subpath>), then the "default" pack. "" if neither exists. Note the
' .ans set INCLUDES the board (which is ALSO the collision map) + the sector/secret masks, so an
' ANSI pack is a full total-conversion -- a pack must keep the board's wall/floor/door palette.
FUNCTION AnsiFile$ (subpath AS STRING)
    DIM p AS STRING
    IF LEN(opt_ansipack) > 0 THEN
        p = "assets/ansi-art/" + opt_ansipack + "/" + subpath
        IF _FILEEXISTS(p) THEN AnsiFile$ = p: EXIT FUNCTION
    END IF
    p = "assets/ansi-art/default/" + subpath
    IF _FILEEXISTS(p) THEN AnsiFile$ = p ELSE AnsiFile$ = ""
END FUNCTION

' Where a NEW ansi-art file should be WRITTEN. AnsiFile$ is a reader -- it returns "" for a
' path that does not exist yet, which is exactly wrong for a generator's output (it silently
' hands back an empty filename). This builds the path in the selected pack instead, so a pack
' gets its own generated layers rather than writing them into default/.
FUNCTION AnsiOutPath$ (subpath AS STRING)
    IF LEN(opt_ansipack) > 0 THEN
        AnsiOutPath$ = "assets/ansi-art/" + opt_ansipack + "/" + subpath
    ELSE
        AnsiOutPath$ = "assets/ansi-art/default/" + subpath
    END IF
END FUNCTION

' Fill ANSIPACKS() with every subfolder of assets/ansi-art/ (each is a pack, incl "default").
' Same model as ScanArtPacks: the folder list IS the pack list; a vanished pick -> "default".
SUB ScanAnsiPacks
    DIM e AS STRING, nm AS STRING
    ANSIPACK_N = 0
    IF _DIREXISTS("assets/ansi-art/") THEN
        e = _FILES$("assets/ansi-art/")
        DO WHILE LEN(e) > 0
            IF RIGHT$(e, 1) = "/" THEN
                nm = LEFT$(e, LEN(e) - 1)
                IF nm <> "." AND nm <> ".." AND ANSIPACK_N < UBOUND(ANSIPACKS) THEN ANSIPACK_N = ANSIPACK_N + 1: ANSIPACKS(ANSIPACK_N) = nm
            END IF
            e = _FILES$
        LOOP
    END IF
    IF PackIndex%(ANSIPACKS(), ANSIPACK_N, opt_ansipack) = 0 THEN opt_ansipack = "default"
END SUB

' Cycle the ANSI-art pack by delta. The MENU art re-reads next time the menu opens, but the
' BOARD is loaded once at startup -- so a board change from a new pack fully applies on restart.
SUB CycleAnsiPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(ANSIPACKS(), ANSIPACK_N, opt_ansipack) + delta
    IF idx < 1 THEN idx = ANSIPACK_N
    IF idx > ANSIPACK_N THEN idx = 1
    opt_ansipack = ANSIPACKS(idx)
    Sfx "select"
END SUB

' TRUE if any space-separated word of `words` occurs in `hay` (hay pre-padded/uppercased).
FUNCTION InStrAny% (hay AS STRING, words AS STRING)
    DIM rest AS STRING, w AS STRING, sp AS INTEGER
    rest = _TRIM$(words)
    DO WHILE LEN(rest) > 0
        sp = INSTR(rest, " ")
        IF sp = 0 THEN w = rest: rest = "" ELSE w = LEFT$(rest, sp - 1): rest = _TRIM$(MID$(rest, sp + 1))
        IF LEN(w) > 0 THEN IF INSTR(hay, w) > 0 THEN InStrAny% = -1: EXIT FUNCTION
    LOOP
    InStrAny% = 0
END FUNCTION

' Draw one framed art box with a caption bar anchored to a character-cell rect;
' the art is fit inside and the caption centred in a bar just above the frame.
SUB CombatArtBox (path AS STRING, col AS INTEGER, cols AS INTEGER, row AS INTEGER, rows AS INTEGER, caption AS STRING, edge AS _UNSIGNED LONG)
    CombatArtBoxOff path, col, cols, row, rows, caption, edge, 0, 0
END SUB

' As CombatArtBox, but the SPRITE is nudged (dxp, dyp) pixels inside its frame while the frame
' itself stays put. That is what makes a lunge read as the creature moving rather than the whole
' panel sliding: the box is repainted every frame anyway, so the nudge costs nothing extra.
SUB CombatArtBoxOff (path AS STRING, col AS INTEGER, cols AS INTEGER, row AS INTEGER, rows AS INTEGER, caption AS STRING, edge AS _UNSIGNED LONG, dxp AS INTEGER, dyp AS INTEGER)
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER
    DIM capx AS INTEGER, capy AS INTEGER, cap AS STRING
    bx = col * CW: by = row * CH: bw = cols * CW: bh = rows * CH
    _DEST CANVAS
    ' caption bar: one text row above the frame, same width
    capy = by - 4 - CH
    LINE (bx - 4, capy - 2)-(bx + bw + 4, by - 4), BOXBG, BF
    LINE (bx - 4, capy - 2)-(bx + bw + 4, by - 4), edge, B
    ' The art box. Framed if art is available -- and INSET rather than outset, unlike every
    ' other panel: these two boxes are anchored to the screen EDGES (the monster at column 1,
    ' the location hard against the right), so there is no room to grow a border outward. The
    ' sprite shrinks into the frame's content rect instead, which is the correct trade for a
    ' portrait: it stays a portrait, just a smaller one inside a nicer box.
    DIM abx AS INTEGER, aby AS INTEGER, abw AS INTEGER, abh AS INTEGER, aframed AS INTEGER
    DIM ic AS INTEGER, ir AS INTEGER, iw AS INTEGER, ih AS INTEGER
    abx = bx: aby = by: abw = bw: abh = bh
    IF UiFramed%(UIF_PANEL) THEN
        aframed = UiPanel%(UIF_PANEL, col, row, cols, rows)
        IF aframed THEN
            UiPanelInner UIF_PANEL, col, row, cols, rows, ic, ir, iw, ih
            abx = ic * CW: aby = ir * CH: abw = iw * CW: abh = ih * CH
        END IF
    END IF
    IF NOT aframed THEN
        LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), BOXBG, BF
        LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), edge, B
    END IF
    IF abw <= 0 OR abh <= 0 THEN EXIT SUB          ' frame bigger than the box: nothing to draw into
    IF DrawSpriteFit%(path, abx + dxp, aby + dyp, abw, abh) THEN
        cap = caption
        IF LEN(cap) > cols + 2 THEN cap = LEFT$(cap, cols + 2)   ' never spill the bar
        capx = bx + (bw - LEN(cap) * CW) \ 2
        IF capx < bx - 4 THEN capx = bx - 4
        COLOR edge, BOXBG: _PRINTSTRING (capx, capy), cap
    END IF
END SUB
