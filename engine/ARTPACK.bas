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
    h = Sprite&(path)
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
    DrawSpriteFit% = -1
END FUNCTION

' Resolve a pixel-art file under assets/pixel-art/ with ART-PACK support: try the selected
' pack subdir first (assets/pixel-art/<pack>/<subpath>), then the flat main dir. "" if neither
' exists. `subpath` is e.g. "monsters/undead/skeleton.png". A partial pack overrides only the
' sprites it ships; everything else falls back to the main art.
FUNCTION ArtFile$ (subpath AS STRING)
    DIM p AS STRING
    IF LEN(opt_artpack) > 0 THEN
        p = "assets/pixel-art/" + opt_artpack + "/" + subpath
        IF _FILEEXISTS(p) THEN ArtFile$ = p: EXIT FUNCTION
    END IF
    p = "assets/pixel-art/" + subpath
    IF _FILEEXISTS(p) THEN ArtFile$ = p ELSE ArtFile$ = ""
END FUNCTION

' TRUE if `nm` is a known category folder (so it is NOT a pack). Anything else under
' assets/pixel-art/ is treated as an art pack (a themed override, mirroring the layout).
FUNCTION IsArtCategory% (nm AS STRING)
    SELECT CASE LCASE$(_TRIM$(nm))
        CASE "monsters", "treasures", "items", "classes", "rooms", "events", "markers": IsArtCategory% = -1
        CASE ELSE: IsArtCategory% = 0
    END SELECT
END FUNCTION

' Fill ARTPACKS() with the pack subdirs under assets/pixel-art/ (every subdir that isn't a
' category). ARTPACKS(0) = "" ("(main)"); 1..N = pack names. A saved pack that has vanished
' falls back to main.
SUB ScanArtPacks
    DIM e AS STRING, nm AS STRING
    ARTPACK_N = 0: ARTPACKS(0) = ""
    IF _DIREXISTS("assets/pixel-art/") THEN
        e = _FILES$("assets/pixel-art/")
        DO WHILE LEN(e) > 0
            IF RIGHT$(e, 1) = "/" THEN
                nm = LEFT$(e, LEN(e) - 1)
                IF nm <> "." AND nm <> ".." AND NOT IsArtCategory%(nm) AND ARTPACK_N < UBOUND(ARTPACKS) THEN ARTPACK_N = ARTPACK_N + 1: ARTPACKS(ARTPACK_N) = nm
            END IF
            e = _FILES$
        LOOP
    END IF
    IF LEN(opt_artpack) > 0 AND PackIndex%(ARTPACKS(), ARTPACK_N, opt_artpack) = 0 THEN opt_artpack = ""
END SUB

' Cycle the art pack by delta (sprites resolve on demand, so nothing to reload).
SUB CycleArtPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(ARTPACKS(), ARTPACK_N, opt_artpack) + delta
    IF idx < 0 THEN idx = ARTPACK_N
    IF idx > ARTPACK_N THEN idx = 0
    opt_artpack = ARTPACKS(idx)
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
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER
    DIM capx AS INTEGER, capy AS INTEGER, cap AS STRING
    bx = col * CW: by = row * CH: bw = cols * CW: bh = rows * CH
    _DEST CANVAS
    ' caption bar: one text row above the frame, same width
    capy = by - 4 - CH
    LINE (bx - 4, capy - 2)-(bx + bw + 4, by - 4), BOXBG, BF
    LINE (bx - 4, capy - 2)-(bx + bw + 4, by - 4), edge, B
    ' the framed art box
    LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), BOXBG, BF
    LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), edge, B
    IF DrawSpriteFit%(path, bx, by, bw, bh) THEN
        cap = caption
        IF LEN(cap) > cols + 2 THEN cap = LEFT$(cap, cols + 2)   ' never spill the bar
        capx = bx + (bw - LEN(cap) * CW) \ 2
        IF capx < bx - 4 THEN capx = bx - 4
        COLOR edge, BOXBG: _PRINTSTRING (capx, capy), cap
    END IF
END SUB
