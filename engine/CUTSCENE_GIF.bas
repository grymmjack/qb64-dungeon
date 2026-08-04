' ============================================================================
'  CUTSCENE_GIF.bas -- an animated-GIF decoder, in BASIC, with no dependencies.
'
'  WHY THIS EXISTS
'  ---------------
'  `_LOADIMAGE` will happily open a .gif -- and hand back only the FIRST FRAME.
'  That is the worst possible failure for an animation: the file loads, the
'  handle is valid, every "does it exist" check passes, and the picture simply
'  never moves. Nothing downstream can tell that apart from a still image the
'  author meant to be still.
'
'  So an animated GIF is decoded here, whole: every frame, every delay, the
'  disposal method between them, and per-frame transparency.
'
'  WHAT A GIF ACTUALLY IS
'  ----------------------
'      "GIF89a"                     6 bytes
'      logical screen descriptor    w, h, packed, bg, aspect
'      [global colour table]        3 * 2^(n+1) bytes
'      ... blocks ...
'        0x21 extension
'             0xF9 graphic control  delay + transparent index + disposal
'             else                  skipped (comment, application, plain text)
'        0x2C image descriptor      x, y, w, h, packed, [local colour table]
'                                   LZW minimum code size, then sub-blocks
'        0x3B trailer
'
'  FRAMES ARE CUMULATIVE, WHICH IS THE PART THAT BITES. A GIF frame is a PATCH
'  applied to a running canvas, not a picture: most encoders emit a small dirty
'  rectangle and rely on the previous frame showing through. Decoding each
'  frame in isolation produces a stack of tiny fragments on black. So this
'  keeps a canvas, composites each patch onto it, snapshots the WHOLE canvas as
'  the frame, and only then applies the disposal method for the next one.
' ============================================================================

CONST GIF_DISP_NONE = 0     ' leave the canvas as it is
CONST GIF_DISP_KEEP = 1     ' same, explicitly
CONST GIF_DISP_BG = 2       ' clear the frame's rect back to transparent
CONST GIF_DISP_PREV = 3     ' restore what was there before this frame

' ----------------------------------------------------------------------------
'  Load every frame of `path` into layer L. Returns the frame count, or 0.
' ----------------------------------------------------------------------------
FUNCTION GifLoadInto% (L AS INTEGER, path AS STRING)
    DIM raw AS STRING, p AS LONG
    DIM gifw AS INTEGER, gifh AS INTEGER, packed AS INTEGER
    DIM gctn AS INTEGER, gct AS LONG
    DIM b AS INTEGER, nfr AS INTEGER
    DIM cnv AS LONG, prev AS LONG, snap AS LONG
    DIM delay AS SINGLE, transp AS INTEGER, disposal AS INTEGER
    DIM fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER
    DIM lctn AS INTEGER, interlace AS INTEGER, i AS INTEGER
    DIM olddest AS LONG

    GifLoadInto% = 0
    raw = _READFILE$(path)
    IF LEN(raw) < 14 THEN EXIT FUNCTION
    IF LEFT$(raw, 3) <> "GIF" THEN EXIT FUNCTION

    p = 7                                        ' past "GIF87a" / "GIF89a"
    gifw = GifU16%(raw, p): p = p + 2
    gifh = GifU16%(raw, p): p = p + 2
    packed = ASC(raw, p): p = p + 1
    p = p + 2                                    ' background index, aspect ratio
    IF gifw < 1 _ORELSE gifh < 1 THEN EXIT FUNCTION

    '--- global colour table ---
    GIF_NGCT = 0
    IF (packed AND 128) <> 0 THEN
        gctn = 2 ^ ((packed AND 7) + 1)
        GifReadPalette raw, p, gctn, TRUE
        p = p + gctn * 3
    END IF

    cnv = _NEWIMAGE(gifw, gifh, 32)
    IF cnv >= -1 THEN EXIT FUNCTION
    prev = _NEWIMAGE(gifw, gifh, 32)
    olddest = _DEST
    _DEST cnv
    CLS , _RGBA32(0, 0, 0, 0)
    _DEST olddest

    delay = 0.1: transp = -1: disposal = GIF_DISP_NONE

    DO
        IF p > LEN(raw) THEN EXIT DO
        b = ASC(raw, p): p = p + 1

        IF b = &H3B THEN EXIT DO                 ' trailer

        IF b = &H21 THEN                         ' extension
            DIM ext AS INTEGER
            ext = ASC(raw, p): p = p + 1
            IF ext = &HF9 THEN
                '--- graphic control: the only extension that means anything here ---
                DIM bs AS INTEGER, gpk AS INTEGER
                bs = ASC(raw, p): p = p + 1
                gpk = ASC(raw, p)
                disposal = (gpk \ 4) AND 7
                '--- delay is in HUNDREDTHS. A great many GIFs say 0 or 1,
                '    meaning "as fast as you can"; browsers clamp that to
                '    100ms and so does this, or the animation strobes. ---
                delay = GifU16%(raw, p + 1) / 100
                IF delay < 0.02 THEN delay = 0.1
                IF (gpk AND 1) <> 0 THEN transp = ASC(raw, p + 3) ELSE transp = -1
                '--- bs data bytes AND the block terminator, in one step. Do NOT
                '    also call GifSkipSubBlocks here: the terminator is already
                '    consumed, so it would read the NEXT byte -- 0x2C, the image
                '    descriptor -- as a 44-byte sub-block and skip the frame.
                '    The parser then resynced on a later 0x2C, which is why the
                '    FIRST frame decoded perfectly and none of the others existed. ---
                p = p + bs + 1
            ELSE
                p = GifSkipSubBlocks&(raw, p)
            END IF
            _CONTINUE
        END IF

        IF b <> &H2C THEN _CONTINUE              ' not an image descriptor; resync

        '--- image descriptor ---
        fx = GifU16%(raw, p): p = p + 2
        fy = GifU16%(raw, p): p = p + 2
        fw = GifU16%(raw, p): p = p + 2
        fh = GifU16%(raw, p): p = p + 2
        packed = ASC(raw, p): p = p + 1
        interlace = ((packed AND 64) <> 0)

        IF (packed AND 128) <> 0 THEN            ' local colour table wins for this frame
            lctn = 2 ^ ((packed AND 7) + 1)
            GifReadPalette raw, p, lctn, FALSE
            p = p + lctn * 3
        ELSE
            GifUseGlobalPalette
        END IF

        '--- remember the canvas if the next disposal will want it back ---
        IF disposal = GIF_DISP_PREV THEN
            _DEST prev
            CLS , _RGBA32(0, 0, 0, 0)
            _PUTIMAGE (0, 0), cnv, prev
            _DEST olddest
        END IF

        p = GifDecodeFrame&(raw, p, cnv, fx, fy, fw, fh, interlace, transp)

        '--- snapshot the WHOLE canvas: a frame is a patch, not a picture ---
        IF nfr < CUT_MAXGIF THEN
            snap = _COPYIMAGE(cnv, 32)
            IF snap < -1 THEN
                nfr = nfr + 1
                CUT_GIFIMG(L, nfr) = snap
                CUT_GIFDELAY(L, nfr) = delay
            END IF
        END IF

        '--- ...then dispose, for the frame after this one ---
        SELECT CASE disposal
            CASE GIF_DISP_BG
                _DEST cnv
                LINE (fx, fy)-(fx + fw - 1, fy + fh - 1), _RGBA32(0, 0, 0, 0), BF
                _DEST olddest
            CASE GIF_DISP_PREV
                _DEST cnv
                CLS , _RGBA32(0, 0, 0, 0)
                _PUTIMAGE (0, 0), prev, cnv
                _DEST olddest
        END SELECT

        delay = 0.1: transp = -1: disposal = GIF_DISP_NONE
    LOOP

    _FREEIMAGE cnv
    _FREEIMAGE prev
    GifLoadInto% = nfr
END FUNCTION

' ----------------------------------------------------------------------------
'  Helpers
' ----------------------------------------------------------------------------
FUNCTION GifU16% (raw AS STRING, p AS LONG)
    IF p + 1 > LEN(raw) THEN GifU16% = 0: EXIT FUNCTION
    GifU16% = ASC(raw, p) + ASC(raw, p + 1) * 256
END FUNCTION

SUB GifReadPalette (raw AS STRING, p AS LONG, n AS INTEGER, isglobal AS INTEGER)
    DIM i AS INTEGER, o AS LONG
    FOR i = 0 TO n - 1
        o = p + i * 3
        IF o + 2 <= LEN(raw) THEN
            GIF_PAL(i) = _RGB32(ASC(raw, o), ASC(raw, o + 1), ASC(raw, o + 2))
            IF isglobal THEN GIF_GCT(i) = GIF_PAL(i)
        END IF
    NEXT i
    GIF_NPAL = n
    IF isglobal THEN GIF_NGCT = n
END SUB

'--- a frame with no local table falls back to the global one, which must be
'    RESTORED rather than assumed still present: the previous frame may have
'    overwritten GIF_PAL with a local table of its own. ---
SUB GifUseGlobalPalette
    DIM i AS INTEGER
    FOR i = 0 TO GIF_NGCT - 1
        GIF_PAL(i) = GIF_GCT(i)
    NEXT i
    GIF_NPAL = GIF_NGCT
END SUB

'--- walk past a chain of length-prefixed sub-blocks, terminated by a zero ---
FUNCTION GifSkipSubBlocks& (raw AS STRING, startp AS LONG)
    DIM p AS LONG, n AS INTEGER
    p = startp
    DO
        IF p > LEN(raw) THEN EXIT DO
        n = ASC(raw, p): p = p + 1
        IF n = 0 THEN EXIT DO
        p = p + n
    LOOP
    GifSkipSubBlocks& = p
END FUNCTION

'--- gather the LZW sub-blocks into one string, so the bit reader does not have
'    to know that the data arrives in <=255-byte chunks ---
FUNCTION GifGatherData$ (raw AS STRING, startp AS LONG, endp AS LONG)
    DIM p AS LONG, n AS INTEGER, s AS STRING
    p = startp
    DO
        IF p > LEN(raw) THEN EXIT DO
        n = ASC(raw, p): p = p + 1
        IF n = 0 THEN EXIT DO
        s = s + MID$(raw, p, n)
        p = p + n
    LOOP
    endp = p
    GifGatherData$ = s
END FUNCTION

' ----------------------------------------------------------------------------
'  LZW, and the frame it paints.
'
'  Variable-width codes, 2..12 bits. `clear` resets the dictionary and the code
'  width; `eoi` ends the stream. Every entry is a PREFIX code plus one suffix
'  byte, so a string is walked backwards and then emitted in reverse -- which
'  is why the output goes through a small stack rather than straight to the
'  canvas.
' ----------------------------------------------------------------------------
FUNCTION GifDecodeFrame& (raw AS STRING, startp AS LONG, cnv AS LONG, fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER, interlace AS INTEGER, transp AS INTEGER)
    DIM minsz AS INTEGER, p AS LONG, dat AS STRING, endp AS LONG
    DIM clearc AS LONG, eoi AS LONG, nextc AS LONG, codesz AS INTEGER
    DIM prefix(0 TO 4095) AS LONG, suffix(0 TO 4095) AS INTEGER
    DIM stk(0 TO 4096) AS INTEGER, sp AS INTEGER
    DIM bitpos AS LONG, nbits AS LONG, code AS LONG, oldc AS LONG, firstb AS INTEGER
    DIM px AS INTEGER, py AS INTEGER, pass AS INTEGER, ystep AS INTEGER
    DIM i AS INTEGER, olddest AS LONG, cur AS LONG

    minsz = ASC(raw, startp)
    p = startp + 1
    dat = GifGatherData$(raw, p, endp)
    GifDecodeFrame& = endp

    IF minsz < 1 _ORELSE minsz > 11 THEN EXIT FUNCTION
    IF LEN(dat) = 0 THEN EXIT FUNCTION

    clearc = 2 ^ minsz
    eoi = clearc + 1
    nextc = clearc + 2
    codesz = minsz + 1

    FOR i = 0 TO clearc - 1
        prefix(i) = -1
        suffix(i) = i
    NEXT i

    nbits = CLNG(LEN(dat)) * 8
    bitpos = 0
    oldc = -1
    px = 0: py = 0: pass = 0: ystep = 8

    olddest = _DEST
    _DEST cnv

    DO
        IF bitpos + codesz > nbits THEN EXIT DO
        code = GifBits&(dat, bitpos, codesz)
        bitpos = bitpos + codesz

        IF code = eoi THEN EXIT DO

        IF code = clearc THEN
            codesz = minsz + 1
            nextc = clearc + 2
            oldc = -1
            _CONTINUE
        END IF

        IF oldc = -1 THEN
            '--- first code after a clear is a literal, and seeds `first` ---
            IF code < clearc THEN
                sp = 0
                stk(sp) = suffix(code): sp = sp + 1
                firstb = suffix(code)
                oldc = code
                GifEmit stk(), sp, cnv, fx, fy, fw, fh, interlace, transp, px, py, pass, ystep
            END IF
            _CONTINUE
        END IF

        sp = 0
        cur = code
        IF cur >= nextc THEN
            '--- the KwKwK case: a code the dictionary has not learned yet, which
            '    is legal and means "previous string plus its own first byte" ---
            stk(sp) = firstb: sp = sp + 1
            cur = oldc
        END IF

        DO WHILE cur >= clearc
            IF sp > 4095 THEN EXIT DO
            stk(sp) = suffix(cur): sp = sp + 1
            cur = prefix(cur)
            IF cur < 0 THEN EXIT DO
        LOOP
        IF cur >= 0 THEN
            stk(sp) = suffix(cur): sp = sp + 1
            firstb = suffix(cur)
        END IF

        GifEmit stk(), sp, cnv, fx, fy, fw, fh, interlace, transp, px, py, pass, ystep

        IF nextc < 4096 THEN
            prefix(nextc) = oldc
            suffix(nextc) = firstb
            nextc = nextc + 1
            IF nextc < 4096 THEN
                IF (nextc AND (nextc - 1)) = 0 THEN
                    IF codesz < 12 THEN codesz = codesz + 1
                END IF
            END IF
        END IF
        oldc = code
    LOOP

    _DEST olddest
END FUNCTION

'--- read `n` bits, least-significant-bit first, which is GIF's order ---
FUNCTION GifBits& (dat AS STRING, bitpos AS LONG, n AS INTEGER)
    DIM v AS LONG, i AS INTEGER, bp AS LONG, byi AS LONG, bi AS INTEGER
    v = 0
    FOR i = 0 TO n - 1
        bp = bitpos + i
        byi = bp \ 8
        bi = bp AND 7
        IF byi + 1 <= LEN(dat) THEN
            IF (ASC(dat, byi + 1) AND (2 ^ bi)) <> 0 THEN v = v OR (2 ^ i)
        END IF
    NEXT i
    GifBits& = v
END FUNCTION

'--- the decode stack holds the string BACKWARDS, so it is drained from the top ---
SUB GifEmit (stk() AS INTEGER, sp AS INTEGER, cnv AS LONG, fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER, interlace AS INTEGER, transp AS INTEGER, px AS INTEGER, py AS INTEGER, pass AS INTEGER, ystep AS INTEGER)
    DIM i AS INTEGER, idx AS INTEGER

    FOR i = sp - 1 TO 0 STEP -1
        idx = stk(i)
        IF py < fh THEN
            IF idx <> transp THEN
                IF idx < GIF_NPAL THEN
                    PSET (fx + px, fy + py), GIF_PAL(idx)
                END IF
            END IF
        END IF
        px = px + 1
        IF px >= fw THEN
            px = 0
            IF interlace THEN
                '--- 8,8 / 4,8 / 2,4 / 1,2. Skipping this leaves the picture in
                '    horizontal bands, which reads as a corrupt file. ---
                py = py + ystep
                DO WHILE py >= fh
                    pass = pass + 1
                    SELECT CASE pass
                        CASE 1: py = 4: ystep = 8
                        CASE 2: py = 2: ystep = 4
                        CASE 3: py = 1: ystep = 2
                        CASE ELSE: py = fh: EXIT DO
                    END SELECT
                LOOP
            ELSE
                py = py + 1
            END IF
        END IF
    NEXT i
END SUB

'--- free every frame a layer is holding ---
SUB GifFreeLayer (L AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_MAXGIF
        IF CUT_GIFIMG(L, i) < -1 THEN _FREEIMAGE CUT_GIFIMG(L, i)
        CUT_GIFIMG(L, i) = 0
        CUT_GIFDELAY(L, i) = 0
    NEXT i
END SUB

FUNCTION CutIsGif% (path AS STRING)
    IF RIGHT$(LCASE$(_TRIM$(path)), 4) = ".gif" THEN CutIsGif% = TRUE ELSE CutIsGif% = FALSE
END FUNCTION
