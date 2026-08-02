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
' Load a 9-grid frame as an IMAGE, cached by path. ANSI or PIXEL ART -- the slicing does not
' care which, because it is pure rectangle arithmetic on whatever image comes back.
'
' A .png frame must be authored at (3 x tilew x CW) by (3 x tileh x CH) PIXELS, i.e. the same
' size the ANSI version occupies on screen, so one registry entry describes both and the two
' are interchangeable. That is the whole reason the registry measures tiles in CHARACTER cells
' rather than pixels: the cell is the common unit between the two art forms.
FUNCTION NineGridLoad& (path AS STRING)
    DIM i AS INTEGER, img AS LONG, raw AS STRING, prevdest AS LONG
    DIM cols AS INTEGER, rows AS INTEGER
    NineGridLoad& = 0
    FOR i = 1 TO NG_N
        IF NG_PATH(i) = path THEN NineGridLoad& = NG_IMG(i): EXIT FUNCTION
    NEXT i
    IF LEN(path) = 0 THEN EXIT FUNCTION
    IF _FILEEXISTS(path) = 0 THEN EXIT FUNCTION
    IF LCASE$(RIGHT$(path, 4)) <> ".ans" THEN            ' pixel art: already an image
        img = Sprite&(path)
        IF img = 0 THEN EXIT FUNCTION
        NineGridCache path, img, 0             ' 0: a Sprite& handle -- Sprite& owns it
        NineGridLoad& = img
        EXIT FUNCTION
    END IF
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
    NineGridCache path, img, -1                 ' -1: we rendered this image, so we may free it
    NineGridLoad& = img
END FUNCTION

' Put a rendered frame in the cache, EVICTING the oldest entry when full.
'
' The eviction is the point. Declining to cache once full -- and returning the image anyway --
' means every later redraw of that frame allocates another one, in a path that runs every
' displayed frame. `owned` says whether the image is ours to free: a .ans is rendered here and
' is ours; a .png comes from Sprite&, which owns its own cache, and freeing it would leave that
' cache holding a dangling handle.
SUB NineGridCache (path AS STRING, img AS LONG, owned AS INTEGER)
    DIM i AS INTEGER
    IF NG_N < NG_MAX THEN
        NG_N = NG_N + 1
        i = NG_N
    ELSE
        NG_EVICT = NG_EVICT + 1                 ' round-robin, so no entry is pinned forever
        IF NG_EVICT > NG_MAX THEN NG_EVICT = 1
        i = NG_EVICT
        IF NG_OWNED(i) AND NG_IMG(i) < -1 THEN _FREEIMAGE NG_IMG(i)
    END IF
    NG_PATH(i) = path: NG_IMG(i) = img: NG_OWNED(i) = owned
END SUB

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
            ' -1 on both rects: QB64's _PUTIMAGE corners are INCLUSIVE. Using (sx, sy)-(sx+pw,
            ' sy+ph) asks for one pixel column and row PAST the tile, and for the right/bottom
            ' tiles that is past the image itself -- an out-of-bounds read that showed up as an
            ' intermittent "corrupted double-linked list" abort rather than anything visible.
            _PUTIMAGE (dx + ox, dy + oy)-(dx + ox + pw - 1, dy + oy + ph - 1), img, CANVAS, (sx, sy)-(sx + pw - 1, sy + ph - 1)
            ox = ox + pw
        LOOP
        oy = oy + ph
    LOOP
END SUB

' Draw the UI's current panel frame. FALSE if none is set or its art is missing, so every
' caller keeps its plain LINE box as the fallback and the game never requires the art.
' Which slot actually supplies art -- the asked-for one, else the generic panel, else none.
' Every lookup goes through this so the fallback rule exists in exactly one place.
FUNCTION UiSlot% (slot AS INTEGER)
    UiSlot% = -1
    IF slot >= 0 AND slot < UIF_SLOTS THEN
        IF LEN(UI_FRAME_PATH(slot)) > 0 THEN UiSlot% = slot: EXIT FUNCTION
    END IF
    IF LEN(UI_FRAME_PATH(UIF_PANEL)) > 0 THEN UiSlot% = UIF_PANEL
END FUNCTION

' TRUE if this slot will draw art -- callers use it to decide _PRINTMODE, since text over a
' frame must not stamp its own background.
FUNCTION UiFramed% (slot AS INTEGER)
    UiFramed% = (UiSlot%(slot) >= 0)
END FUNCTION

FUNCTION UiPanel% (slot AS INTEGER, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER)
    DIM s AS INTEGER
    s = UiSlot%(slot): IF s < 0 THEN EXIT FUNCTION
    UiPanel% = NineGridBox%(UI_FRAME_PATH(s), UI_FRAME_TW(s), UI_FRAME_TH(s), col, row, cols, rows, UI_FRAME_FILL(s))
END FUNCTION

' The content rect for the current frame -- or a 1-cell inset when there is no frame, which is
' what the old LINE boxes effectively used.
'
' Callers MUST ask rather than assume: this frame's border is 4 columns and 2 ROWS thick, so
' anything that hardcoded "+1" would draw its first line straight through the art.
SUB UiPanelInner (slot AS INTEGER, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, icol AS INTEGER, irow AS INTEGER, icols AS INTEGER, irows AS INTEGER)
    DIM s AS INTEGER
    s = UiSlot%(slot)
    IF s < 0 THEN
        icol = col + 1: irow = row + 1: icols = cols - 2: irows = rows - 2
        IF icols < 0 THEN icols = 0
        IF irows < 0 THEN irows = 0
        EXIT SUB
    END IF
    NineGridInner UI_FRAME_TW(s), UI_FRAME_TH(s), col, row, cols, rows, icol, irow, icols, irows
END SUB

' The centre tile of a slot's frame, painted across a rect. This is how a caller WIPES part of
' a framed panel: filling with BOXBG would punch a hole through the artwork.
SUB UiPanelWipe (slot AS INTEGER, px AS INTEGER, py AS INTEGER, pw AS INTEGER, ph AS INTEGER)
    DIM s AS INTEGER
    s = UiSlot%(slot): IF s < 0 THEN EXIT SUB
    ' Must match what the panel was FILLED with, or wiping a strip leaves a patch that does not
    ' belong to the panel it sits in.
    IF UI_FRAME_FILL(s) = NGF_TILE THEN
        NineGridTile NineGridLoad&(UI_FRAME_PATH(s)), UI_FRAME_TW(s), UI_FRAME_TH(s), 1, 1, px, py, pw, ph
    ELSEIF UI_FRAME_FILL(s) = NGF_BOXBG THEN
        LINE (px, py)-(px + pw, py + ph), BOXBG, BF
    END IF
END SUB

' Grow a box so its CONTENT rect lands exactly where a one-cell-bordered box used to put it.
'
' This is the standard move for retrofitting a frame onto an existing panel. The alternative --
' moving the panel's contents inward -- means re-deriving every coordinate in its drawing code,
' which looks identical when done right and subtly broken when not. Growing outward leaves all
' of them untouched and correct.
'
' Caller must still bounds-check the result: a thick frame on a panel near the screen edge has
' nowhere to grow.
SUB FrameOutset (slot AS INTEGER, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, fcol AS INTEGER, frow AS INTEGER, fcols AS INTEGER, frows AS INTEGER)
    DIM s AS INTEGER
    fcol = col: frow = row: fcols = cols: frows = rows
    s = UiSlot%(slot): IF s < 0 THEN EXIT SUB
    fcol = col + 1 - UI_FRAME_TW(s): frow = row + 1 - UI_FRAME_TH(s)
    fcols = cols - 2 + 2 * UI_FRAME_TW(s): frows = rows - 2 + 2 * UI_FRAME_TH(s)
END SUB

' A small modal prompt panel (the luck fuse, the box-shake fuse). Grown outward like the rest,
' and it draws the LINE box itself when there is no art or no room -- so a caller is one IF, and
' the fallback cannot be forgotten at one of the two call sites.
FUNCTION PromptPanel% (col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, edge AS _UNSIGNED LONG)
    DIM fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER, ok AS INTEGER
    IF UiFramed%(UIF_PROMPT) THEN
        FrameOutset UIF_PROMPT, col, row, cols, rows, fx, fy, fw, fh
        IF fx >= 0 AND fy >= 0 AND fx + fw <= SW AND fy + fh <= SH THEN ok = UiPanel%(UIF_PROMPT, fx, fy, fw, fh)
    END IF
    IF ok = 0 THEN
        LINE (col * CW, row * CH)-((col + cols) * CW, (row + rows) * CH), BOXBG, BF
        LINE (col * CW, row * CH)-((col + cols) * CW, (row + rows) * CH), edge, B
    END IF
    PromptPanel% = ok
END FUNCTION

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
FUNCTION NineGridBox% (path AS STRING, tw AS INTEGER, th AS INTEGER, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, fmode AS INTEGER)
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
    ' The CONTENT fill, first, under everything. Not always the art's centre tile: a frame is
    ' often drawn with a MARKER colour in the middle to show where content goes, and painting
    ' that would put the marker on screen.
    SELECT CASE fmode
        CASE NGF_TILE: NineGridTile img, tw, th, 1, 1, x + cw2, y + ch2, midw, midh
        CASE NGF_NONE: ' leave it -- whatever is behind the panel shows through
        CASE ELSE: LINE (x + cw2, y + ch2)-(x + cw2 + midw, y + ch2 + midh), BOXBG, BF
    END SELECT
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
