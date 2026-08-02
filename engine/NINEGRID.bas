$INCLUDEONCE
' ============================================================================
'  NINEGRID.bas -- ENGINE GDK: draw a UI box of ANY size from one small ANSI frame.
'
'  THE IDEA, and why it is worth a file: a framed panel drawn with LINE calls can only ever
'  look like a rectangle. A framed panel drawn from ART can look like anything -- carved stone,
'  riveted iron, a scroll -- and it can be redrawn in an ANSI editor by someone who has never
'  opened the source. This is the second thing.
'
'  THE FORMAT is deliberately the most obvious one possible:
'
'      Author a box that is (3 x TILEW) columns by (3 x TILEH) rows. The engine slices it into
'      a 3x3 grid and tiles the middle pieces to fill whatever size you ask for.
'
'  With the shipped 4x2 tiles that is a 12x6 ANSI box -- literally just draw a box at 12x6:
'
'          cols 0-3     cols 4-7     cols 8-11
'      rows 0-1   TL           T (repeats ->)     TR
'      rows 2-3   L (repeats)  CENTRE (fills)     R
'      rows 4-5   BL           B (repeats ->)     BR
'
'  The edge and centre tiles are CLIPPED when they do not divide evenly, so any box at least
'  (2 x TILEW) x (2 x TILEH) works. Tiles that read the same at any offset (a plain line, a flat
'  fill) clip invisibly; heavily patterned tiles will show the cut, which is a property of the
'  ART and is the author's to control.
'
'  Rendered at the UI's own CW x CH cell -- NOT through AnsiSprite&, which renders entity art on
'  an 8x8 cell. Sampling a frame at 8x8 and stretching it to 8x16 is exactly the blur this is
'  meant to avoid.
' ============================================================================

' Render a 9-grid frame ANSI to an image at the UI cell size, cached by path.
' Returns 0 if the file is missing or empty -- every caller treats that as "draw nothing".
FUNCTION NineGridLoad& (path AS STRING)
    DIM i AS INTEGER, img AS LONG, raw AS STRING, prevdest AS LONG
    DIM cols AS INTEGER, rows AS INTEGER
    NineGridLoad& = 0
    FOR i = 1 TO NG_N
        IF NG_PATH(i) = path THEN NineGridLoad& = NG_IMG(i): EXIT FUNCTION
    NEXT i
    IF LEN(path) = 0 THEN EXIT FUNCTION
    IF _FILEEXISTS(path) = 0 THEN EXIT FUNCTION
    raw = _READFILE$(path)
    IF LEN(raw) = 0 THEN EXIT FUNCTION
    AnsiArtDims raw, cols, rows
    IF cols < 2 OR rows < 2 THEN EXIT FUNCTION
    ' ONE ROW TALLER than the art, deliberately. With no line breaks the file relies on pure
    ' auto-wrap, and printing the last character of the last row advances the cursor to the row
    ' BELOW -- off the image, which SCROLLS it and silently loses row 0. The frame rendered with
    ' no top rail until this spare row existed.
    img = _NEWIMAGE(cols * CW, (rows + 1) * CH, 32)
    IF img >= -1 THEN EXIT FUNCTION
    prevdest = _DEST
    _DEST img
    _FONT CH                                    ' the UI cell, so the blit is 1:1 with the grid
    CLS , BLACK
    ' Render the art RAW -- do NOT put it through MaskNormalize$.
    '
    ' Normalisation injects ESC[0m before every SGR run so each cell is self-contained. That is
    ' exactly right for a MASK, where a cell must sample as precisely its painted colour and a
    ' sticky attribute bleeding forward is corruption. It is exactly WRONG for decorative art,
    ' which is authored assuming attributes persist: this frame sets ESC[1m (bold) as its own
    ' run and lets later ESC[31m inherit it to mean BRIGHT red. Reset before each run and the
    ' bold is gone -- the frame rendered dark red and grey instead of bright red and white.
    '
    ' Only the SAUCE is trimmed, because that genuinely is not art (see the CHR$(26) note in
    ' framegen: without this the renderer draws "!!IBM VGA" across the frame).
    IF INSTR(raw, CHR$(26)) > 0 THEN raw = LEFT$(raw, INSTR(raw, CHR$(26)) - 1)
    ANSI_Print (raw)
    _DEST prevdest
    IF NG_N < NG_MAX THEN
        NG_N = NG_N + 1
        NG_PATH(NG_N) = path: NG_IMG(NG_N) = img
    END IF
    NineGridLoad& = img
END FUNCTION

' Blit one source tile, clipped to a destination rect. `sc/sr` are the tile's grid coordinates
' (0..2). Clipping is what lets a box be any size rather than a multiple of the tile.
SUB NineGridTile (img AS LONG, tw AS INTEGER, th AS INTEGER, sc AS INTEGER, sr AS INTEGER, dx AS INTEGER, dy AS INTEGER, dw AS INTEGER, dh AS INTEGER)
    DIM sx AS INTEGER, sy AS INTEGER, w AS INTEGER, h AS INTEGER
    DIM ox AS INTEGER, oy AS INTEGER, pw AS INTEGER, ph AS INTEGER
    IF dw <= 0 OR dh <= 0 THEN EXIT SUB
    sx = sc * tw * CW: sy = sr * th * CH
    w = tw * CW: h = th * CH
    oy = 0
    DO WHILE oy < dh
        ph = h: IF oy + ph > dh THEN ph = dh - oy
        ox = 0
        DO WHILE ox < dw
            pw = w: IF ox + pw > dw THEN pw = dw - ox
            _PUTIMAGE (dx + ox, dy + oy)-(dx + ox + pw, dy + oy + ph), img, CANVAS, (sx, sy)-(sx + pw, sy + ph)
            ox = ox + pw
        LOOP
        oy = oy + ph
    LOOP
END SUB

' Draw the UI's current panel frame. FALSE if none is set or its art is missing, so every
' caller keeps its plain LINE box as the fallback and the game never requires the art.
FUNCTION UiPanel% (col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER)
    IF LEN(UI_FRAME_PATH) = 0 THEN EXIT FUNCTION
    UiPanel% = NineGridBox%(UI_FRAME_PATH, UI_FRAME_TW, UI_FRAME_TH, col, row, cols, rows)
END FUNCTION

' The content rect for the current frame -- or a 1-cell inset when there is no frame, which is
' what the old LINE boxes effectively used.
'
' Callers MUST ask rather than assume: this frame's border is 4 columns and 2 ROWS thick, so
' anything that hardcoded "+1" would draw its first line straight through the art.
SUB UiPanelInner (col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, icol AS INTEGER, irow AS INTEGER, icols AS INTEGER, irows AS INTEGER)
    IF LEN(UI_FRAME_PATH) = 0 THEN
        icol = col + 1: irow = row + 1: icols = cols - 2: irows = rows - 2
        IF icols < 0 THEN icols = 0
        IF irows < 0 THEN irows = 0
        EXIT SUB
    END IF
    NineGridInner UI_FRAME_TW, UI_FRAME_TH, col, row, cols, rows, icol, irow, icols, irows
END SUB

' Where the CONTENT goes -- the blue middle of the 9-grid, in CHARACTER cells.
'
' Every caller needs this and none of them should compute it: the inset is the CORNER size, so
' a frame with chunkier corners pushes its text further in automatically, and a caller that
' hardcoded "+1" would silently overlap the new art. Ask, do not assume.
'
' Returns the inner rect through icol/irow/icols/irows. irows/icols come back 0 if the box is
' too small to have an interior at all.
SUB NineGridInner (tw AS INTEGER, th AS INTEGER, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, icol AS INTEGER, irow AS INTEGER, icols AS INTEGER, irows AS INTEGER)
    icol = col + tw: irow = row + th
    icols = cols - 2 * tw: irows = rows - 2 * th
    IF icols < 0 THEN icols = 0
    IF irows < 0 THEN irows = 0
END SUB

' Draw a framed box at character coordinates (col,row) spanning cols x rows cells.
' TRUE if it drew; FALSE if the frame art is missing, so a caller can fall back to LINE boxes.
FUNCTION NineGridBox% (path AS STRING, tw AS INTEGER, th AS INTEGER, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER)
    DIM img AS LONG, x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER
    DIM cw2 AS INTEGER, ch2 AS INTEGER, midw AS INTEGER, midh AS INTEGER
    NineGridBox% = 0
    img = NineGridLoad&(path)
    IF img = 0 THEN EXIT FUNCTION
    IF cols < 2 * tw OR rows < 2 * th THEN EXIT FUNCTION   ' smaller than its own corners
    x = col * CW: y = row * CH
    w = cols * CW: h = rows * CH
    cw2 = tw * CW: ch2 = th * CH
    midw = w - 2 * cw2: midh = h - 2 * ch2
    _DEST CANVAS
    NineGridTile img, tw, th, 1, 1, x + cw2, y + ch2, midw, midh      ' centre first, under everything
    NineGridTile img, tw, th, 1, 0, x + cw2, y, midw, ch2             ' top
    NineGridTile img, tw, th, 1, 2, x + cw2, y + h - ch2, midw, ch2   ' bottom
    NineGridTile img, tw, th, 0, 1, x, y + ch2, cw2, midh             ' left
    NineGridTile img, tw, th, 2, 1, x + w - cw2, y + ch2, cw2, midh   ' right
    NineGridTile img, tw, th, 0, 0, x, y, cw2, ch2                    ' corners last -- they must
    NineGridTile img, tw, th, 2, 0, x + w - cw2, y, cw2, ch2          ' win over the edges they
    NineGridTile img, tw, th, 0, 2, x, y + h - ch2, cw2, ch2          ' meet, or a clipped edge
    NineGridTile img, tw, th, 2, 2, x + w - cw2, y + h - ch2, cw2, ch2 ' tile eats the corner
    NineGridBox% = -1
END FUNCTION
