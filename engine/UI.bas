' ============================================================================
'  UI.bas -- ENGINE presentation layer (game-agnostic).
'
'  Extracted from MENU.bas. The reusable text-mode runtime any game draws with:
'  screen fades (FadeInCurrent/FadeOut/BloodDrip/DarknessFall), UI primitives
'  (Banner, PrintCentered, UI-font on/off, WaitKey, FlashPrompt, CombatPause),
'  the sound dispatcher (RollDie%/Tone/Sfx/SfxOr/DiceAnimSfx/VoiceBlip) + text
'  crawl (ScrollText/ScrollTextVO), and the full DICE subsystem (pip + polyhedral
'  tumbler, GameRoll/DoRoll/RollPips, ShowRollText, real-dice PromptRoll, 3D-dice
'  colour/timing helpers). No game symbols -- game screens live in game/MENU.bas.
' ============================================================================

' ============================================================================
'  SCREEN FADES
' ============================================================================

' Fade whatever is currently composed on CANVAS in from black.
SUB FadeInCurrent
    DIM scene AS LONG, a AS INTEGER
    scene = _NEWIMAGE(SW * CW, SH * CH, 32)
    _PUTIMAGE (0, 0), CANVAS, scene              ' snapshot the composed screen
    _DEST CANVAS
    FOR a = 255 TO 0 STEP -20
        _PUTIMAGE (0, 0), scene, CANVAS
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), ThmA~&("ui.fade", _RGB32(&H00, &H00, &H00), a), BF
        Present
        _LIMIT 60
    NEXT a
    _PUTIMAGE (0, 0), scene, CANVAS
    Present
    _FREEIMAGE scene
END SUB

' Fade the current screen out to black (cumulative darkening -- no buffer needed).
SUB FadeOut
    DIM i AS INTEGER
    _DEST CANVAS
    FOR i = 1 TO 14
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), ThmA~&("ui.fade", _RGB32(&H00, &H00, &H00), &H2C), BF
        Present
        _LIMIT 60
    NEXT i
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    Present
END SUB


' Wash the screen to WHITE and back. Used for the passage of time -- black reads as "you lost
' consciousness", white reads as "days went by", which is the difference between dying and
' resting. `hold` is the seconds spent fully white.
SUB FlashWhite (hold AS SINGLE)
    DIM scene AS LONG, a AS INTEGER
    scene = _NEWIMAGE(SW * CW, SH * CH, 32)
    _PUTIMAGE (0, 0), CANVAS, scene
    _DEST CANVAS
    FOR a = 0 TO 255 STEP 24                     ' up to white
        _PUTIMAGE (0, 0), scene, CANVAS
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), ThmA~&("ui.flash", _RGB32(&HFF, &HFF, &HFF), a), BF
        Present
        _LIMIT 60
    NEXT a
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(&HFF, &HFF, &HFF), BF
    Present
    IF hold > 0 THEN _DELAY hold
    FOR a = 255 TO 0 STEP -24                    ' ...and back down to the scene
        _PUTIMAGE (0, 0), scene, CANVAS
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), ThmA~&("ui.flash", _RGB32(&HFF, &HFF, &HFF), a), BF
        Present
        _LIMIT 60
    NEXT a
    _PUTIMAGE (0, 0), scene, CANVAS
    Present
    _FREEIMAGE scene
END SUB


' Death transition: adjacent vertical strips of blood each run down on their own
' stagger + speed, piling up strip by strip until the whole screen is red -- then
' it slowly fades to black. (No sweeping rectangle -- the strips do the filling.)
SUB BloodDrip
    DIM strw AS INTEGER, ns AS INTEGER, i AS INTEGER, f AS INTEGER, px AS INTEGER, allfull AS INTEGER
    DIM slen(1 TO 220) AS INTEGER, sdelay(1 TO 220) AS INTEGER, ssp(1 TO 220) AS INTEGER
    DIM darkred AS _UNSIGNED LONG, brightred AS _UNSIGNED LONG
    darkred = Thm~&("ui.gore.dark", _RGB32(&H90, &H00, &H00)): brightred = Thm~&("ui.gore", _RGB32(&HDA, &H24, &H24))
    strw = 8                                     ' strip width (tile the full width -- no gaps)
    ns = (SW * CW) \ strw + 1
    IF ns > 220 THEN ns = 220
    FOR i = 1 TO ns
        sdelay(i) = INT(RND * 42)                ' each strip starts at its own moment
        ssp(i) = 13 + INT(RND * 22)              ' ...and runs at its own speed
        slen(i) = 0
    NEXT i
    _DEST CANVAS
    f = 0
    DO
        f = f + 1
        allfull = -1
        FOR i = 1 TO ns
            IF f >= sdelay(i) THEN
                slen(i) = slen(i) + ssp(i)
                IF slen(i) > SH * CH THEN slen(i) = SH * CH
                px = (i - 1) * strw
                LINE (px, 0)-(px + strw - 1, slen(i)), darkred, BF          ' the strip so far
                IF slen(i) < SH * CH THEN
                    LINE (px, slen(i) - 12)-(px + strw - 1, slen(i) + 4), brightred, BF   ' its running head
                    allfull = 0
                END IF
            ELSE
                allfull = 0
            END IF
        NEXT i
        Present
        _LIMIT 60
    LOOP UNTIL allfull OR f > 220
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), darkred, BF   ' guarantee fully solid
    Present
    _DELAY 0.35                                          ' hold the blood-soaked screen a beat
    ' slow fade from red to black
    FOR f = 1 TO 48
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), ThmA~&("ui.fade", _RGB32(&H00, &H00, &H00), &H0E), BF
        Present
        _LIMIT 60
    NEXT f
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    Present
END SUB


' Forfeit transition: the same falling-strips effect as BloodDrip, but drained of
' colour -- grey strips run down and pile into black. Used when a run ends for good
' (all lives spent). The user asked for "darkness fading down like blood but grey".
SUB DarknessFall
    DIM strw AS INTEGER, ns AS INTEGER, i AS INTEGER, f AS INTEGER, px AS INTEGER, allfull AS INTEGER
    DIM slen(1 TO 220) AS INTEGER, sdelay(1 TO 220) AS INTEGER, ssp(1 TO 220) AS INTEGER
    DIM darkgrey AS _UNSIGNED LONG, litegrey AS _UNSIGNED LONG
    darkgrey = Thm~&("ui.scroll.track", _RGB32(&H1E, &H1E, &H1E)): litegrey = Thm~&("ui.scroll.thumb", _RGB32(&H55, &H55, &H55))
    strw = 8
    ns = (SW * CW) \ strw + 1
    IF ns > 220 THEN ns = 220
    FOR i = 1 TO ns
        sdelay(i) = INT(RND * 42)
        ssp(i) = 13 + INT(RND * 22)
        slen(i) = 0
    NEXT i
    _DEST CANVAS
    f = 0
    DO
        f = f + 1
        allfull = -1
        FOR i = 1 TO ns
            IF f >= sdelay(i) THEN
                slen(i) = slen(i) + ssp(i)
                IF slen(i) > SH * CH THEN slen(i) = SH * CH
                px = (i - 1) * strw
                LINE (px, 0)-(px + strw - 1, slen(i)), darkgrey, BF          ' the strip so far
                IF slen(i) < SH * CH THEN
                    LINE (px, slen(i) - 12)-(px + strw - 1, slen(i) + 4), litegrey, BF   ' its running head
                    allfull = 0
                END IF
            ELSE
                allfull = 0
            END IF
        NEXT i
        Present
        _LIMIT 60
    LOOP UNTIL allfull OR f > 220
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), darkgrey, BF   ' guarantee fully solid grey
    Present
    _DELAY 0.35                                            ' hold the ashen screen a beat
    FOR f = 1 TO 48                                        ' slow fade from grey to black
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), ThmA~&("ui.fade", _RGB32(&H00, &H00, &H00), &H0E), BF
        Present
        _LIMIT 60
    NEXT f
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    Present
END SUB

SUB Banner (l1 AS STRING, l2 AS STRING)
    DIM w AS INTEGER, bx1 AS INTEGER, bx2 AS INTEGER, pw AS INTEGER
    _DEST CANVAS
    UIFontOn UIF_MSG                               ' configurable message/narration font
    ' auto-size the box to the widest line's PIXEL width (so a proportional font never spills
    ' past the border), converted to cells + padding; min = the classic 96 cols, capped to screen
    pw = _PRINTWIDTH(l1): IF _PRINTWIDTH(l2) > pw THEN pw = _PRINTWIDTH(l2)
    w = (pw \ CW) + 6
    IF w < 96 THEN w = 96
    IF w > 130 THEN w = 130
    bx1 = (SW - w) \ 2: bx2 = bx1 + w
    ' The framed panel if the game has published one, else the plain box it always drew.
    DIM ic AS INTEGER, ir AS INTEGER, iw AS INTEGER, ih AS INTEGER, r1 AS INTEGER, r2 AS INTEGER
    IF UiPanel%(UIF_BANNER, bx1, BNR_ROW, w, BNR_ROWS) = 0 THEN
        LINE (bx1 * CW, BNR_ROW * CH)-(bx2 * CW, (BNR_ROW + BNR_ROWS) * CH), BOXBG, BF
        LINE (bx1 * CW, BNR_ROW * CH)-(bx2 * CW, (BNR_ROW + BNR_ROWS) * CH), REDU, B
    END IF
    ' Place the two lines inside the REPORTED content rect. This used to be rows 24 and 27,
    ' which sat one cell inside a one-cell border; the framed panel's border is 2 ROWS deep, so
    ' hardcoded rows would print through the art. Centred in the interior instead, so a frame
    ' with thicker or thinner edges moves the text rather than breaking it.
    UiPanelInner UIF_BANNER, bx1, BNR_ROW, w, BNR_ROWS, ic, ir, iw, ih
    IF ih < 2 THEN ih = 2
    r1 = ir + (ih \ 2) - 1
    r2 = r1 + 2
    IF r2 > ir + ih - 1 THEN r2 = ir + ih - 1
    ' Over a FRAME, print the text ONTO the art: the panel's centre tile is the background the
    ' artist drew, and stamping BOXBG cells behind every glyph punches dark rectangles through
    ' it. With no frame there is no art to preserve and the opaque fill is what clears the old
    ' message, so the mode follows the frame rather than being chosen once.
    IF UiFramed%(UIF_BANNER) THEN _PRINTMODE _KEEPBACKGROUND
    COLOR WHITE, BOXBG: PrintCentered r1, l1
    COLOR YELLOWU, BOXBG: PrintCentered r2, l2
    _PRINTMODE _FILLBACKGROUND
    UIFontOff
    bnr_l2 = l2: bnr_bx1 = bx1: bnr_bx2 = bx2      ' remembered so a keypress can flash the prompt
    bnr_l2row = r2                                 ' ...and WHERE it went: the prompt row now comes
    '                                                from the frame's content rect, so the two places
    '                                                that rewrite that line must be told, not guess
    Present
END SUB



' Wipe the banner's prompt row so a new prompt can be written over it.
'
' With a frame that means REDRAWING the frame's own centre tile across that strip -- a BOXBG bar
' would punch a dark rectangle through the artwork. Without one, the bar IS the correct wipe.
SUB BannerClearPromptRow
    IF UiFramed%(UIF_BANNER) THEN
        UiPanelWipe UIF_BANNER, (bnr_bx1 + 1) * CW, bnr_l2row * CH, (bnr_bx2 - bnr_bx1 - 2) * CW, CH
    ELSE
        LINE ((bnr_bx1 + 1) * CW, bnr_l2row * CH)-((bnr_bx2 - 1) * CW, (bnr_l2row + 1) * CH), BOXBG, BF
    END IF
END SUB

SUB PrintCentered (row AS INTEGER, t AS STRING)
    DIM px AS INTEGER
    '--- centre by PIXEL width so it works with a proportional UI font too; for the built-in
    '    8x16 grid font _PRINTWIDTH = LEN*8, so grid text lands exactly where it always did ---
    px = (SW * CW - _PRINTWIDTH(t)) \ 2
    IF px < 0 THEN px = 0
    _PRINTSTRING (px, row * CH), t
END SUB

' Centre within a COLUMN SPAN rather than the whole screen -- for text inside a panel, or
' beside something (a portrait) that owns part of the row.
'
' The span is a HARD limit, not a hint. Clamping the start position alone was not enough: a
' line wider than the span still ran off the right-hand end, and on the character sheet that
' meant the stat-derivation line printing straight over the class portrait. A helper whose job
' is "fit this inside x1..x2" must not be able to draw outside it, so an over-long line is cut
' to the span. Callers that must not lose text should wrap instead -- see PrintWrappedIn%.
SUB PrintCenteredIn (row AS INTEGER, x1 AS INTEGER, x2 AS INTEGER, t AS STRING)
    DIM px AS INTEGER, wide AS INTEGER, cols AS INTEGER, s AS STRING
    cols = x2 - x1
    IF cols < 1 THEN cols = 1
    s = t
    IF _PRINTWIDTH(s) > cols * CW THEN s = LEFT$(s, cols)      ' grid font: 1 cell per char
    wide = cols * CW
    px = x1 * CW + (wide - _PRINTWIDTH(s)) \ 2
    IF px < x1 * CW THEN px = x1 * CW
    _PRINTSTRING (px, row * CH), s
END SUB


' Word-wrap `t` into the span and print it centred, at most `maxrows` rows starting at `row`.
' Returns the LAST row used, so a caller can lay out what follows without assuming a height.
' This is the no-data-lost counterpart to PrintCenteredIn's hard cut.
FUNCTION PrintWrappedIn% (row AS INTEGER, x1 AS INTEGER, x2 AS INTEGER, maxrows AS INTEGER, t AS STRING)
    DIM w AS STRING, p AS LONG, nl AS LONG, r AS INTEGER
    r = row
    ' If it already fits, print it VERBATIM. WrapLines$ collapses runs of spaces (callers pad
    ' columns with them), which is right when a line must be re-flowed but destroys deliberate
    ' spacing when it did not need to be -- the character sheet's derivation line is three
    ' space-separated groups and reads as mush single-spaced.
    IF _PRINTWIDTH(t) <= (x2 - x1) * CW THEN
        PrintCenteredIn r, x1, x2, t
        PrintWrappedIn% = r
        EXIT FUNCTION
    END IF
    w = WrapLines$(t, x2 - x1, maxrows)
    p = 1
    DO WHILE p <= LEN(w)
        nl = INSTR(p, w, CHR$(10))
        IF nl = 0 THEN nl = LEN(w) + 1
        PrintCenteredIn r, x1, x2, MID$(w, p, nl - p)
        p = nl + 1
        IF p <= LEN(w) THEN r = r + 1
    LOOP
    PrintWrappedIn% = r
END FUNCTION

' Greedy word-wrap into at most `maxlines` lines of `cols` columns, returned CHR$(10)-joined.
' Breaks on spaces; a single word longer than the span is hard-cut rather than allowed to
' overflow. Anything past maxlines is dropped with a trailing "..." on the last line, so a
' caller can lay out a fixed number of rows and never paint outside them.
FUNCTION WrapLines$ (t AS STRING, cols AS INTEGER, maxlines AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER, wd AS STRING, acc AS STRING, wl AS STRING, c1 AS STRING, src AS STRING
    IF cols < 1 OR maxlines < 1 THEN EXIT FUNCTION
    src = _TRIM$(t) + " "
    n = 1
    FOR i = 1 TO LEN(src)
        c1 = MID$(src, i, 1)
        IF c1 = " " THEN
            IF LEN(wd) = 0 THEN
                ' collapse runs of spaces (callers pad columns with them)
            ELSEIF LEN(acc) = 0 THEN
                acc = wd
            ELSEIF LEN(acc) + 1 + LEN(wd) <= cols THEN
                acc = acc + " " + wd
            ELSE
                IF n >= maxlines THEN
                    IF LEN(acc) + 4 <= cols THEN acc = acc + " ..." ELSE acc = LEFT$(acc, cols - 4) + " ..."
                    wl = wl + acc: acc = "": wd = "": EXIT FOR
                END IF
                wl = wl + acc + CHR$(10): n = n + 1: acc = wd
            END IF
            IF LEN(wd) > cols THEN acc = LEFT$(wd, cols)     ' a single over-long word
            wd = ""
        ELSE
            wd = wd + c1
        END IF
    NEXT i
    IF LEN(acc) > 0 THEN wl = wl + acc
    WrapLines$ = wl
END FUNCTION

' Load the per-region UI fonts from assets/data/ui-fonts.txt into the UIF_* handles.
' region | fontfile (in assets/fonts/ui/) | size ; blank file or size 0 = built-in grid font.
SUB LoadUIFonts
    DIM f AS INTEGER, ln AS STRING, p1 AS INTEGER, p2 AS INTEGER
    DIM region AS STRING, file AS STRING, sz AS INTEGER, h AS LONG, path AS STRING
    DIM uf AS STRING: uf = DataPath$(AssetPath$("data", "ui-fonts.txt"))   ' data-pack aware
    IF _FILEEXISTS(uf) = 0 THEN EXIT SUB
    f = FREEFILE
    OPEN uf FOR INPUT AS #f
    DO WHILE NOT EOF(f)
        LINE INPUT #f, ln
        ln = _TRIM$(ln)
        IF ln <> "" AND LEFT$(ln, 1) <> "#" THEN
            p1 = INSTR(ln, "|"): p2 = INSTR(p1 + 1, ln, "|")
            IF p1 > 0 AND p2 > 0 THEN
                region = LCASE$(_TRIM$(LEFT$(ln, p1 - 1)))
                file = _TRIM$(MID$(ln, p1 + 1, p2 - p1 - 1))
                sz = VAL(_TRIM$(MID$(ln, p2 + 1)))
                h = 0
                IF LEN(file) > 0 AND sz > 0 THEN
                    path = AssetPath$("fonts", "ui/") + file
                    '--- combat/hud carry bars + aligned columns, so force MONOSPACE (even cells);
                    '    prose regions (label/message/menu) stay proportional for a natural flow ---
                    DIM style AS STRING
                    IF region = "combat" OR region = "hud" THEN style = "MONOSPACE" ELSE style = ""
                    IF _FILEEXISTS(path) THEN h = _LOADFONT(path, sz, style)
                END IF
                SELECT CASE region
                    CASE "label": UIF_LABEL = h
                    CASE "message": UIF_MSG = h
                    CASE "combat": UIF_COMBAT = h
                    CASE "menu": UIF_MENU = h
                    CASE "hud": UIF_HUD = h
                END SELECT
            END IF
        END IF
    LOOP
    CLOSE #f
END SUB

' Wrap a block of text drawing: UIFontOn sets a region font (0 = keep the grid font),
' UIFontOff restores the built-in 8x16 grid font (handle CH). Always pair them.
SUB UIFontOn (h AS LONG)
    IF h <> 0 THEN _FONT h ELSE _FONT CH
    _DONTBLEND                                     ' hard-edged glyphs (no antialias fringe) -- crisper pixel fonts
END SUB
SUB UIFontOff
    _BLEND                                         ' restore normal blending (the vignette + sprites need it)
    _FONT CH
END SUB



SUB WaitKey
    DIM k AS STRING, t0 AS SINGLE
    _KEYCLEAR              ' drain buffered keys
    t0 = TIMER
    DO
        _LIMIT 60: AudioTick: k = INKEY$: Present   ' Present handles resize
        ' Unattended advance. WaitKey is used for the moments too important to auto-skip during
        ' NORMAL play (a death, a level-up), which is exactly why the timeout is opt-in state
        ' rather than a global pacing setting -- nothing changes unless something asked for it.
        IF ui_autoadvance > 0 THEN
            IF TIMER - t0 >= ui_autoadvance OR TIMER - t0 < 0 THEN EXIT DO
        END IF
    LOOP UNTIL k <> ""
    FlashPrompt
END SUB


' ============================================================================
'  PRESENT -- put the finished frame on screen. THE one place scaling is decided.
'
'  This replaces every bare Present. The reason is the whole reason windowed resize was
'  broken: the game used to do `SCREEN CANVAS`, making the 132x51 character grid BE the
'  window surface, and left `$RESIZE:STRETCH` to scale it to whatever size the window
'  manager handed us. A character grid does not survive a fractional stretch -- 1056x816
'  into (say) 3840x2093 is 3.64x horizontally and 2.56x vertically, and glyphs and panel
'  edges land wherever the rounding puts them. Parts of the UI appear to vanish.
'
'  DRAW hit exactly the same thing and solved it by owning the window surface instead of
'  letting the metacommand own it (see ~/git/DRAW OUTPUT/SCREEN.BM SCREEN_render, which
'  ends `_PUTIMAGE (0,0)-(_WIDTH(0)-1,_HEIGHT(0)-1), SCRN.CANVAS&, 0`). So now: CANVAS is
'  an OFFSCREEN render target at exactly SW*CW x SH*CH, screen 0 is a real window-sized
'  surface, and this blits one to the other at an INTEGER scale, centred, with black bars.
'  Integer-only is the point -- it is the only way every cell keeps the same pixel size.
'
'  Below one full canvas the window is too small for an integer scale, so it degrades to a
'  fitted stretch: ugly, but showing everything beats cropping.
' ============================================================================
SUB Present
    DIM olddest AS LONG, sw0 AS LONG, sh0 AS LONG, sc AS INTEGER
    DIM dw AS LONG, dh AS LONG, ox AS LONG, oy AS LONG
    olddest = _DEST
    ' THE RESIZE IS HANDLED HERE, not in a loop.
    '
    ' DRAW checks _RESIZE once per frame in its ONE main loop (DRAW.BAS:340). This game has no
    ' single frame loop -- it is ~40 nested blocking loops (WaitKey, Banner, the dice tumble,
    ' fades, the gauge, every menu), each owning the screen for a while. Putting the check in
    ' "the loop" therefore means putting it in forty of them, and the first attempt did exactly
    ' two (the play loop and WaitKey): resize while sitting in SETTINGS and nothing consumed the
    ' event, so the window grew while screen 0 stayed 1056x816, anchored top-left.
    '
    ' The present IS this game's once-per-frame chokepoint. Handling it here reaches every loop
    ' by construction, including ones written later.
    '
    ' TWO GUARDS, both learned from DRAW (DRAW.BAS:340 + SCREEN.BM SCREEN_DEFERRED_RESIZE%), and
    ' the screen strobes horribly without either:
    '
    '   SELF-EVENTS. Our own SCREEN _NEWIMAGE raises a _RESIZE. Acting on that recreates the
    '   screen again, which raises another... a feedback loop that reads as the display having a
    '   fit. pres_deferred counts the echoes we caused and swallows exactly that many.
    '
    '   SETTLE. Dragging an edge fires an event every frame. Recreating the GL surface each one
    '   is both slow and visibly flickery, so arm a countdown instead and act once the events
    '   STOP -- a drag re-arms it every frame, so the resize happens once at the end.
    IF _RESIZE THEN
        rsz_w = _RESIZEWIDTH: rsz_h = _RESIZEHEIGHT       ' reading these clears the event
        IF pres_deferred > 0 THEN
            pres_deferred = pres_deferred - 1             ' our own resize echoing back -- ignore it
        ELSE
            TakeWindowSize rsz_w, rsz_h                   ' act NOW; the guards below stop the loop
        END IF
        rsz_settle = 6                                    ' ...and arm the corrective watcher
    ELSEIF rsz_settle > 0 THEN
        ' CORRECTIVE pass, not the main path: some window managers drop or lag the last _RESIZE
        ' of a drag (and of a maximize), leaving the window a different size from the surface.
        ' A few frames after the events stop, check and fix it.
        rsz_settle = rsz_settle - 1
        IF rsz_settle = 0 THEN
            IF pres_deferred > 0 THEN
                pres_deferred = pres_deferred - 1
            ELSE
                TakeWindowSize rsz_w, rsz_h
            END IF
        END IF
    END IF
    sw0 = _WIDTH(0): sh0 = _HEIGHT(0)
    IF sw0 < 1 OR sh0 < 1 THEN _DISPLAY: EXIT SUB
    ' HOW the canvas fills the window is the player's call, via SETTINGS "Window Scaling":
    '
    '   integer (opt_smoothamt 0) -- INTEGER scale only. Every character cell keeps exactly the
    '           same pixel size. The cost is black bars: a 2600x1400 window only allows 1x,
    '           because 816*2 = 1632 does not fit in 1400.
    '   fit     (opt_smoothamt 1+) -- largest scale that FITS, fractions allowed. Fills the window
    '           at any aspect, at the cost of unevenly-sized cells.
    '
    ' NEITHER IS FILTERED, and do not add a comment claiming otherwise: QB64's _PUTIMAGE does
    ' nearest-neighbour sampling for software images, always. Measured -- a 1.71x scale of this
    ' canvas comes out with the SAME 7 distinct colours as the unscaled original, where any
    ' interpolation would have produced hundreds of blended values at the glyph edges. Real
    ' filtering needs a hardware image (_COPYIMAGE ..., 33) and the GL compositor, which is why
    ' opt_smoothamt ALSO selects _FULLSCREEN _SMOOTH -- that path is scaled by the driver.
    '
    ' Either way the ASPECT is preserved and the whole canvas is drawn -- _PUTIMAGE maps the
    ' entire source into the destination rectangle, so unlike $RESIZE:STRETCH nothing can be
    ' cropped or dropped no matter how odd the window shape is.
    IF opt_smoothamt > 0 THEN
        dw = sw0: dh = CLNG(sw0) * (SH * CH) / (SW * CW)          ' fit to width...
        IF dh > sh0 THEN dh = sh0: dw = CLNG(sh0) * (SW * CW) / (SH * CH)   ' ...or to height
    ELSE
        sc = sw0 \ (SW * CW)
        IF sh0 \ (SH * CH) < sc THEN sc = sh0 \ (SH * CH)
        IF sc < 1 THEN
            dw = sw0: dh = CLNG(sw0) * (SH * CH) / (SW * CW)      ' below 1x: fit, never crop
            IF dh > sh0 THEN dh = sh0: dw = CLNG(sh0) * (SW * CW) / (SH * CH)
        ELSE
            dw = CLNG(SW) * CW * sc: dh = CLNG(SH) * CH * sc
        END IF
    END IF
    ox = (sw0 - dw) \ 2: oy = (sh0 - dh) \ 2
    ' Publish how far the canvas was scaled to reach the window. The GL layer draws in WINDOW
    ' pixels and cannot see this, so anything composited over the canvas has to be told -- see
    ' PresentScale!.
    IF SW * CW > 0 THEN pres_scale = dw / (SW * CW)
    pres_ox = ox: pres_oy = oy: pres_dw = dw: pres_dh = dh
    _DEST 0
    ' Repaint the letterbox bars only when the geometry CHANGES. A full CLS every frame at
    ' 4K is real work for pixels that never change.
    IF dw <> pres_lastw OR dh <> pres_lasth OR sw0 <> pres_winw OR sh0 <> pres_winh THEN
        CLS , BLACK
        pres_lastw = dw: pres_lasth = dh: pres_winw = sw0: pres_winh = sh0
    END IF
    ' SMOOTH windowed scaling needs the GPU, and the GPU is only reachable via a HARDWARE image
    ' (_COPYIMAGE ..., 33) drawn with _MAPTRIANGLE ..., _SMOOTH ("applies linear filtering").
    ' Neither half of that is optional -- measured on a 10.9x upscale of the same source:
    '   _PUTIMAGE, software           -> hard stair-stepped edges
    '   _MAPTRIANGLE _SMOOTH, software-> hard stair-stepped edges (the flag is ignored)
    '   _MAPTRIANGLE _SMOOTH, HARDWARE-> clean filtered curves
    ' Fullscreen does not come through here: ApplyDisplay sizes screen 0 to the canvas so
    ' _FULLSCREEN _SMOOTH does that scaling in the driver.
    DIM wantsmooth AS INTEGER, pre AS INTEGER, ifac AS INTEGER
    DIM srcimg AS LONG, sw2 AS INTEGER, sh2 AS INTEGER
    wantsmooth = 0
    IF opt_smoothamt > 0 THEN
        IF dw <> SW * CW THEN                       ' 1:1 needs no filtering (fullscreen IS 1:1 here)
            IF pres_nohw = 0 THEN wantsmooth = -1   ' ...and the GPU has not already refused
        END IF
    END IF
    IF wantsmooth THEN
        ' STRENGTH, via how much of the scale is done CRISPLY first. Linear filtering blurs over
        ' one SOURCE texel, so the finer the source, the less blur survives -- prescale the canvas
        ' by a whole number with nearest-neighbour (perfectly sharp), then let the GPU filter only
        ' the leftover fraction. This is the emulator trick, and it is the only real "amount"
        ' control there is: GL filtering itself is binary, nearest or linear, with nothing between.
        ifac = dw \ (SW * CW): IF ifac < 1 THEN ifac = 1
        SELECT CASE opt_smoothamt
            CASE 1: pre = ifac                      ' LIGHT  -- crisp as far as possible
            CASE 2: pre = (ifac + 1) \ 2            ' MEDIUM -- half crisp, half filtered
            CASE ELSE: pre = 1                      ' FULL   -- straight linear, softest
        END SELECT
        IF pre > 4 THEN pre = 4                     ' cap the intermediate's memory (4x = 54 MB)
        IF pre > 1 THEN
            IF pres_pre_scale <> pre THEN
                IF pres_pre <> 0 THEN _FREEIMAGE pres_pre
                pres_pre = _NEWIMAGE(SW * CW * pre, SH * CH * pre, 32)
                pres_pre_scale = pre
            END IF
            _PUTIMAGE (0, 0)-(SW * CW * pre - 1, SH * CH * pre - 1), CANVAS, pres_pre   ' nearest = sharp
            srcimg = pres_pre
        ELSE
            srcimg = CANVAS
        END IF
        IF pres_hw <> 0 THEN _FREEIMAGE pres_hw
        pres_hw = _COPYIMAGE(srcimg, 33)            ' a fresh GPU texture of this frame
        ' A hardware image needs a working GL context. It is not guaranteed -- a software-only
        ' rasteriser, a remote X session without GLX, or a headless run can all refuse (this
        ' returns "Invalid handle" under $SCREENHIDE, which is how it was found). Latch the
        ' refusal so we stop asking 60 times a second, and fall through to the crisp path.
        IF pres_hw >= -1 THEN pres_hw = 0: pres_nohw = -1
    ELSE
        ' MUST release these. Left alive, the branch below would keep re-drawing the last texture
        ' it held -- so turning smoothing off, or sizing the window back to 1:1, would freeze the
        ' picture on whatever frame was showing when that happened.
        IF pres_hw <> 0 THEN _FREEIMAGE pres_hw: pres_hw = 0
        IF pres_pre <> 0 THEN _FREEIMAGE pres_pre: pres_pre = 0: pres_pre_scale = 0
    END IF
    IF pres_hw < -1 THEN
        ' Two triangles cover the destination rect. Source coords are the SOURCE image's pixels,
        ' which is the prescaled intermediate when one is in use -- not the canvas.
        sw2 = _WIDTH(pres_hw) - 1: sh2 = _HEIGHT(pres_hw) - 1
        _MAPTRIANGLE (0, 0)-(sw2, 0)-(0, sh2), pres_hw TO (ox, oy)-(ox + dw - 1, oy)-(ox, oy + dh - 1), , _SMOOTH
        _MAPTRIANGLE (sw2, 0)-(sw2, sh2)-(0, sh2), pres_hw TO (ox + dw - 1, oy)-(ox + dw - 1, oy + dh - 1)-(ox, oy + dh - 1), , _SMOOTH
    ELSE
        _PUTIMAGE (ox, oy)-(ox + dw - 1, oy + dh - 1), CANVAS, 0
    END IF
    _DEST olddest
    IF NOT pres_noflip THEN _DISPLAY
    ' THE DEV CONSOLE HOTKEY LIVES HERE for exactly the reason the resize does (see above): this
    ' is the only thing all ~40 loops call every frame, so [`] works in menus, dialogs, the dice
    ' tumble and mid-fade without any of them knowing about it. _KEYDOWN reads keyboard STATE, so
    ' the poll never steals a keypress from whatever loop owns the screen.
    ConsoleHotkeyTick
END SUB

' Put the canvas on screen WITHOUT flipping, so a caller can draw ON TOP and flip itself.
'
' The hardware dice need exactly this. They draw GL triangles straight to screen 0 and call
' _DISPLAY themselves -- which was fine when the game did SCREEN CANVAS and the canvas WAS the
' window. Once the present step became a BLIT into a separate window surface, anything that
' flips without going through Present shows the window with no canvas on it: the dice appeared
' correctly over a black screen, with their tray, header and caption missing entirely.
' How many WINDOW pixels one CANVAS pixel currently occupies.
'
' The GL dice are positioned with a constant calibrated for a 1056x816 canvas presented 1:1.
' In fullscreen the canvas is scaled up, but the GL projection is not -- so the dice keep their
' original spread while the tray drawn on the canvas grows around them, and they stop matching
' the box they are supposed to be rolling in.
'
' 1 until the first present, so anything that asks before a frame has been shown gets the
' unscaled answer rather than zero.
FUNCTION PresentScale! ()
    IF pres_scale <= 0 THEN PresentScale! = 1! ELSE PresentScale! = pres_scale
END FUNCTION

SUB PresentNoFlip
    pres_noflip = -1
    Present
    pres_noflip = 0
END SUB


' Recreate the window surface at (w,h) -- the only place that does. Every guard against the
' resize feedback loop lives here so no caller can forget one:
'   * a zero/absurd size (some WMs report one mid-drag) is ignored
'   * a NO-OP resize is ignored: asking for the size we already are still raises a _RESIZE,
'     and acting on that raises another -- that alone is enough to strobe the display
'   * pres_deferred is bumped FIRST, so the echo this call is about to cause gets swallowed
SUB TakeWindowSize (w AS LONG, h AS LONG)
    IF w < 64 OR h < 64 THEN EXIT SUB
    IF w = _WIDTH(0) AND h = _HEIGHT(0) THEN EXIT SUB
    pres_deferred = pres_deferred + 1
    SCREEN _NEWIMAGE(w, h, 32)
    pres_lastw = -1                                       ' geometry changed: repaint the letterbox bars
    display_dirty = -1                                    ' and let loops that track it redraw
END SUB




' Acknowledge a keypress at a '[ press any key ]' prompt: a soft click + a quick
' light-up of the last banner's prompt line (which the next redraw then clears).
SUB FlashPrompt
    DIM ff AS INTEGER
    Sfx "select"
    IF LEN(_TRIM$(bnr_l2)) = 0 THEN EXIT SUB
    _DEST CANVAS: _FONT CH
    FOR ff = 1 TO 4
        BannerClearPromptRow
        IF ff MOD 2 = 1 THEN COLOR WHITE, REDU ELSE COLOR YELLOWU, BOXBG
        IF UiFramed%(UIF_BANNER) THEN _PRINTMODE _KEEPBACKGROUND
        PrintCentered bnr_l2row, bnr_l2
        _PRINTMODE _FILLBACKGROUND
        Present
        _LIMIT 30
    NEXT ff
    bnr_l2 = ""     ' one-shot: a banner flashes once, never again (no stale redraws elsewhere)
END SUB


' Pause after a combat action so the result is readable. Slow/Normal/Fast wait a
' fixed beat (a held key can't blow through, which is what made combat feel too
' fast); Wait-for-key falls back to WaitKey. Keys pressed during a timed pause are
' drained afterwards so they don't spill into the next prompt or trigger a round.
' The dice tray, framed. Takes PIXEL bounds because both roll renderers work in pixels (the
' dice bounce off the walls), and converts to cells for the 9-grid.
'
' Note it does NOT restore _PRINTMODE: the tray is redrawn every animation frame and the text on
' it is drawn immediately after, so the caller's own loop owns the restore.
' DEV hook: save the SETTLED roll frame if `dungeon.run rollshot` armed roll_shot, then disarm
' so one armed shot captures exactly one roll. Called from each of the three dice paths (pips /
' font polyhedra / 3D) at the moment the dice have landed and the sum is on screen.
'
' It saves CANVAS, not the window -- so it sees whatever the roll drew ON the canvas. That is a
' real limitation worth knowing: the 3D dice's HARDWARE path draws to the WINDOW after Present,
' so it is invisible here. `rollshot` forces DICE3D_HW = 0 (the software renderer, which draws to
' the canvas) for exactly this reason. See the hardware-GL note in DICE3D/_RENDER.BM.
SUB RollShotSave
    IF LEN(roll_shot) = 0 THEN EXIT SUB
    _SAVEIMAGE roll_shot, CANVAS
    roll_shot = ""
END SUB


FUNCTION RollTray% (px1 AS INTEGER, py1 AS INTEGER, px2 AS INTEGER, py2 AS INTEGER)
    DIM c1 AS INTEGER, r1 AS INTEGER, cw2 AS INTEGER, rh AS INTEGER
    DIM fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER, ok AS INTEGER
    c1 = px1 \ CW: r1 = py1 \ CH
    cw2 = (px2 - px1) \ CW: rh = (py2 - py1) \ CH
    IF UiFramed%(UIF_ROLL) THEN
        FrameOutset UIF_ROLL, c1, r1, cw2, rh, fx, fy, fw, fh
        IF fx >= 0 AND fy >= 0 AND fx + fw <= SW AND fy + fh <= SH THEN ok = UiPanel%(UIF_ROLL, fx, fy, fw, fh)
    END IF
    IF ok = 0 THEN
        LINE (px1, py1)-(px2, py2), BOXBG, BF
        LINE (px1, py1)-(px2, py2), REDU, B
    END IF
    RollTray% = ok
END FUNCTION

SUB CombatPause
    DIM f AS INTEGER, maxf AS INTEGER
    ' NOTE: do NOT drain the buffer up front -- a key you pressed while the dice
    ' were still rolling should advance THIS prompt (draining it here made every
    ' '[ press any key ]' need a second press). We only drain AFTER advancing so
    ' the advance key can't spill into the next attack.
    IF opt_msgdelay <= 0 THEN                       ' 0 = wait for a keypress (manual)
        DO: _LIMIT 60: AudioTick: Present: LOOP UNTIL INKEY$ <> ""
        FlashPrompt: _KEYCLEAR: EXIT SUB
    END IF
    ' TIMED: this prompt will auto-advance, so '[ press any key ]' is misleading.
    ' Rewrite just the prompt line of the already-drawn banner to '[ press to skip ]'
    ' (same length -> the auto-sized box still fits). WaitKey prompts never call this,
    ' so their honest 'press any key' stays put.
    IF INSTR(bnr_l2, "[ press any key ]") > 0 THEN
        DIM l2s AS STRING
        l2s = StrSubst$(bnr_l2, "[ press any key ]", "[ press to skip ]")
        _DEST CANVAS: _FONT CH
        BannerClearPromptRow
        IF UiFramed%(UIF_BANNER) THEN _PRINTMODE _KEEPBACKGROUND
        COLOR YELLOWU, BOXBG: PrintCentered bnr_l2row, l2s
        _PRINTMODE _FILLBACKGROUND
        bnr_l2 = l2s
        Present
    END IF
    maxf = opt_msgdelay * 60                        ' else auto-advance after the delay...
    FOR f = 1 TO maxf
        _LIMIT 60
        AudioTick
        IF INKEY$ <> "" THEN FlashPrompt: EXIT FOR  ' ...or ANY key advances early (with feedback)
        Present
    NEXT f
    _KEYCLEAR                      ' drain the advance key so it can't trigger the next round
END SUB



FUNCTION RollDie% (sides AS INTEGER)
    RollDie = INT(RND * sides) + 1
END FUNCTION


' One tone at the current SFX volume.  All effects route through here so the
' SFX Vol slider (opt_sfxvol, 0..10) scales every sound at once.
SUB Tone (freq AS INTEGER, dur AS SINGLE)
    IF audio_muted THEN EXIT SUB                 ' dev/headless runs stay silent -- see audio_muted
    SOUND freq, dur, opt_sfxvol / 10
END SUB


' Named sound effects (SOUND queues in the background, so short sequences play out).

SUB Sfx (kind AS STRING)
    IF audio_muted THEN EXIT SUB
    IF NOT opt_sfx THEN EXIT SUB
    DIM h AS LONG
    h = SfxHandle(kind)                         ' a real audio file for this effect?
    LogSfxPlayed kind, SfxPathFor$(kind)        ' asset telemetry -- logs the BEEPER case too, which is the
    IF h > 0 THEN _SNDPLAYCOPY h, opt_sfxvol / 10 * chgain_sfx: EXIT SUB   ' one you most want to see ("why is this a bleep?")
    SELECT CASE kind                            ' otherwise fall back to the tone beeper
        CASE "move": Tone 350, 0.08
        CASE "bump": Tone 170, 0.12
        CASE "door": Tone 300, 0.06: Tone 520, 0.09
        CASE "strongdoor": Tone 120, 0.14: Tone 85, 0.12       ' heavy thud on a reinforced door
        CASE "breakdoor": Tone 300, 0.04: Tone 180, 0.05: Tone 500, 0.04: Tone 70, 0.22  ' splintering crash
        CASE "secret": Tone 700, 0.05: Tone 950, 0.05: Tone 1250, 0.12
        CASE "secretpass": Tone 1100, 0.04: Tone 820, 0.04: Tone 1300, 0.09
        CASE "key": Tone 660, 0.06: Tone 880, 0.06: Tone 1174, 0.06: Tone 1568, 0.18
        CASE "idle": Tone 130, 0.1: Tone 98, 0.16
        CASE "treasure": Tone 820, 0.05: Tone 1040, 0.05: Tone 1320, 0.12
        CASE "chamber-enter": Tone 160, 0.16: Tone 120, 0.20: Tone 90, 0.28   ' a big room opening up
        CASE "monster-appear": Tone 900, 0.05: Tone 1300, 0.05: Tone 220, 0.22 ' shriek, then the weight of it
        CASE "stairs": Tone 200, 0.07: Tone 180, 0.07: Tone 160, 0.07: Tone 140, 0.12  ' four falls, descending
        CASE "trap": Tone 240, 0.1: Tone 150, 0.14: Tone 90, 0.22
        CASE "hit": Tone 620, 0.05: Tone 320, 0.12
        CASE "miss": Tone 200, 0.14
        CASE "crit": Tone 700, 0.05: Tone 950, 0.05: Tone 1200, 0.05: Tone 1600, 0.14
        CASE "fumble": Tone 320, 0.08: Tone 210, 0.1: Tone 120, 0.18
        CASE "search": Tone 300, 0.05: Tone 260, 0.05
        CASE "win": Tone 523, 0.12: Tone 659, 0.12: Tone 784, 0.12: Tone 1046, 0.28
        CASE "lose": Tone 300, 0.16: Tone 220, 0.16: Tone 130, 0.34
        CASE "saveok": Tone 784, 0.07: Tone 1046, 0.07: Tone 1318, 0.18   ' bright rising -- saved!
        CASE "savebad": Tone 392, 0.12: Tone 294, 0.14: Tone 196, 0.28    ' sad descending -- failed
        CASE "chest": Tone 240, 0.05: Tone 190, 0.06: Tone 320, 0.05: Tone 150, 0.18   ' creak + clunk (lid opens)
        CASE "boom": Tone 130, 0.05: Tone 90, 0.10: Tone 60, 0.24         ' bomb -- low blast
        CASE "hiss": Tone 2000, 0.04: Tone 1700, 0.04: Tone 1450, 0.05: Tone 1200, 0.08   ' darts -- hiss
        CASE "fizzle": Tone 1000, 0.03: Tone 1300, 0.03: Tone 800, 0.03: Tone 1100, 0.03: Tone 700, 0.06   ' frost -- crackle
        CASE "alarm": Tone 800, 0.1: Tone 1050, 0.1: Tone 800, 0.1: Tone 1050, 0.16   ' siren -- wail
        CASE "select": Tone 220, 0.06
        CASE "diceroll": Tone 260, 0.02: Tone 330, 0.02: Tone 240, 0.02: Tone 300, 0.03   ' dice thrown -- a quick rattle
        CASE "diceland": Tone 380, 0.03: Tone 210, 0.06                                    ' dice come to rest -- a click/thud
        CASE "monster-pain": Tone 300, 0.05: Tone 180, 0.09                                ' a monster is wounded
        CASE "player-pain": Tone 200, 0.06: Tone 130, 0.12                                 ' you are wounded
        CASE "death": Tone 200, 0.12: Tone 150, 0.14: Tone 90, 0.3                         ' a life ends
        CASE "poison-proc": Tone 400, 0.04: Tone 320, 0.05: Tone 260, 0.09                 ' poison gnaws
        CASE "frost-proc": Tone 900, 0.03: Tone 1100, 0.03: Tone 700, 0.07                 ' frost bites
        CASE "teleport": Tone 600, 0.04: Tone 900, 0.04: Tone 1300, 0.05: Tone 1800, 0.1   ' scroll whisks you away
        CASE "fireball": Tone 200, 0.05: Tone 300, 0.05: Tone 150, 0.13                     ' spell: fire
        CASE "lightning-bolt": Tone 1800, 0.02: Tone 1400, 0.03: Tone 900, 0.05: Tone 300, 0.1  ' spell: lightning
        CASE "monster-death": Tone 300, 0.05: Tone 200, 0.06: Tone 120, 0.22                ' a monster falls
        CASE "maxhit": Tone 700, 0.04: Tone 500, 0.05: Tone 260, 0.16                       ' a crushing MAX-damage blow
        CASE "heartbeat": Tone 90, 0.09: Tone 70, 0.13                                      ' near-death: a low double-thud
        CASE "curio": Tone 620, 0.05: Tone 780, 0.05: Tone 990, 0.1                         ' a curio reveals itself
    END SELECT
END SUB

' Play effect nm if a file is loaded for it, else a procedural Tone freq,dur. Lets an
' animation keep its hand-tuned beep as the fallback while a pack SAMPLE can override it.
SUB SfxOr (nm AS STRING, freq AS INTEGER, dur AS SINGLE)
    IF NOT opt_sfx THEN EXIT SUB
    IF SfxHandle&(nm) > 0 THEN Sfx nm ELSE Tone freq, dur
END SUB

' Dice-tumble audio for frame f of an animation that settles on frame `settle`. The throw
' (f=1) and the landing (f=settle) go through Sfx -- themeable diceroll / diceland (with the
' beeper as fallback); the per-frame rattle `texfreq` is a procedural texture used ONLY when
' no diceroll sample is loaded, so a pack's roll sample isn't buried under beeps.
SUB DiceAnimSfx (f AS INTEGER, settle AS INTEGER, texfreq AS INTEGER, texdur AS SINGLE)
    IF NOT opt_sfx THEN EXIT SUB
    IF f = settle THEN Sfx "diceland": EXIT SUB
    IF f = 1 THEN Sfx "diceroll": EXIT SUB
    IF SfxHandle&("diceroll") = 0 THEN Tone texfreq, texdur
END SUB


' A single "voice" blip for the typewriter text window, at the Voice volume.
SUB VoiceBlip (freq AS INTEGER)
    IF audio_muted THEN EXIT SUB                   ' dev/headless: the fallback below is a RAW SOUND,
    IF NOT opt_voice THEN EXIT SUB                 ' which does not go through Tone and so never saw the mute
    DIM h AS LONG
    h = SfxHandle&("voice")                        ' pack/flat assets/sfx/voice.* if present
    IF h > 0 THEN
        _SNDPLAYCOPY h, opt_voicevol / 10 * 0.4    ' a copy per glyph so rapid blips overlap
    ELSE
        SOUND freq, 0.03, opt_voicevol / 10 * 0.4  ' PC-speaker fallback -- per-glyph typewriter blip, kept quiet vs the slider
    END IF
END SUB


' Scrolling text window: type `body` out one character at a time (word-wrapped)
' inside a framed box, blipping the voice per glyph.  A keypress fast-forwards
' the reveal; another dismisses it.  Great for lore / narration.
' Text crawl with optional NARRATION. If narration is on and a voice file exists for narrkey,
' the spoken line plays and the per-glyph blips are SUPPRESSED (the voice covers the crawl);
' otherwise it blips per glyph as before. ScrollText (below) is the no-narration wrapper.
SUB ScrollTextVO (title AS STRING, body AS STRING, narrkey AS STRING)
    DIM AS INTEGER bx, by, bw, bh, i, maxcols, skip, ln, p, nl, narrating
    DIM word AS STRING, acc AS STRING, wrapped AS STRING, c1 AS STRING, k AS STRING
    DIM shown AS STRING, piece AS STRING
    narrating = 0
    IF opt_narration AND LEN(narrkey) > 0 THEN IF LEN(NarratePath$(narrkey)) > 0 THEN narrating = -1
    IF narrating THEN Narrate narrkey               ' the spoken crawl -- one line, over the typing
    bx = 20: by = 12: bw = 92: bh = 26
    maxcols = bw - 8
    ' greedy word-wrap into `wrapped` with CHR$(10) line breaks
    acc = "": wrapped = "": word = ""
    DIM src AS STRING: src = body + " "
    FOR i = 1 TO LEN(src)
        c1 = MID$(src, i, 1)
        IF c1 = " " THEN
            IF LEN(acc) + LEN(word) + 1 > maxcols THEN
                wrapped = wrapped + acc + CHR$(10): acc = word
            ELSEIF LEN(acc) = 0 THEN
                acc = word
            ELSE
                acc = acc + " " + word
            END IF
            word = ""
        ELSE
            word = word + c1
        END IF
    NEXT i
    IF LEN(acc) > 0 THEN wrapped = wrapped + acc

    skip = FALSE
    FOR i = 1 TO LEN(wrapped)
        c1 = MID$(wrapped, i, 1)
        _DEST CANVAS
        LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
        LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered by + 2, "-=  " + title + "  =-"
        ' draw everything revealed so far, split on the wrap breaks
        shown = LEFT$(wrapped, i)
        ln = 0: p = 1
        COLOR WHITE, BOXBG
        DO
            nl = INSTR(p, shown, CHR$(10))
            IF nl = 0 THEN piece = MID$(shown, p) ELSE piece = MID$(shown, p, nl - p)
            _PRINTSTRING ((bx + 4) * CW, (by + 5 + ln) * CH), piece
            IF nl = 0 THEN EXIT DO
            p = nl + 1: ln = ln + 1
        LOOP
        COLOR CYANU, BOXBG: PrintCentered by + bh - 2, "[ any key to continue ]"
        Present
        AudioTick                                   ' keep the narration fade-in ramping while the crawl types
        IF NOT narrating THEN IF c1 <> CHR$(10) AND c1 <> " " THEN VoiceBlip 380 + (ASC(c1) MOD 12) * 40
        IF NOT skip THEN
            k = INKEY$
            IF k <> "" THEN skip = TRUE
            _LIMIT 45
        END IF
    NEXT i
    ' hold on the fully-revealed text
    _KEYCLEAR
    DO: _LIMIT 60: AudioTick: k = INKEY$: Present: LOOP UNTIL k <> ""
    IF narrating THEN NarrateStop                   ' cut the voice when the crawl is dismissed
END SUB

' No-narration text crawl (per-glyph voice blips only) -- the plain entry point.
SUB ScrollText (title AS STRING, body AS STRING)
    ScrollTextVO title, body, ""
END SUB


' A single square pip.

SUB Pip (x AS INTEGER, y AS INTEGER, r AS INTEGER, col AS _UNSIGNED LONG)
    LINE (x - r, y - r)-(x + r, y + r), col, BF
END SUB


' Draw one d6 face (value 1-6) as an sz x sz die at pixel (px,py).

SUB DrawDie (px AS INTEGER, py AS INTEGER, sz AS INTEGER, pips AS INTEGER)
    DIM AS INTEGER x2, y2, r, cxl, cxm, cxr, cyt, cym, cyb
    DIM AS _UNSIGNED LONG face, edge, pipc
    face = Thm~&("die.pip.face", _RGB32(&HF0, &HF0, &HE6)): edge = Thm~&("die.pip.edge", _RGB32(&H78, &H78, &H70)): pipc = Thm~&("die.pip.dot", _RGB32(&H18, &H10, &H10))
    x2 = px + sz: y2 = py + sz
    LINE (px + 5, py + 5)-(x2 + 5, y2 + 5), _RGB32(&H00, &H00, &H00), BF   ' drop shadow
    LINE (px, py)-(x2, y2), face, BF
    LINE (px, py)-(x2, y2), edge, B
    r = sz \ 11
    cxl = px + sz \ 4: cxm = px + sz \ 2: cxr = x2 - sz \ 4
    cyt = py + sz \ 4: cym = py + sz \ 2: cyb = y2 - sz \ 4
    IF pips = 1 OR pips = 3 OR pips = 5 THEN Pip cxm, cym, r, pipc
    IF pips >= 2 THEN
        Pip cxl, cyt, r, pipc
        Pip cxr, cyb, r, pipc
    END IF
    IF pips >= 4 THEN
        Pip cxr, cyt, r, pipc
        Pip cxl, cyb, r, pipc
    END IF
    IF pips = 6 THEN
        Pip cxl, cym, r, pipc
        Pip cxr, cym, r, pipc
    END IF
END SUB


' Tumble n d6 on screen (with a rolling sound), settle on the result, and
' return the total. The individual faces land in die_a / die_b.

FUNCTION RollDiceShow% (n AS INTEGER)
    RollDiceShow = RollPips(n, FALSE, 0, "")
END FUNCTION


' The line drawn beneath a settled roll. With a modifier it spells out the maths
' so the player sees where the final number comes from ("5 + 3 = 8", "17 + 7 = 24");
' without one it's the plain "sum" of a multi-die roll, or nothing for a lone die.
' `dropped` prefixes the 4d6-drop-lowest note.
FUNCTION RollLineText$ (roll AS INTEGER, bonus AS INTEGER, ndice AS INTEGER, dropped AS INTEGER)
    DIM s AS STRING, bt AS STRING
    IF bonus > 0 THEN
        bt = " + " + _TRIM$(STR$(bonus))
    ELSEIF bonus < 0 THEN
        bt = " - " + _TRIM$(STR$(-bonus))
    END IF
    IF bonus <> 0 THEN
        s = _TRIM$(STR$(roll)) + bt + " = " + _TRIM$(STR$(roll + bonus))
    ELSEIF ndice > 1 THEN
        s = "sum  " + _TRIM$(STR$(roll))
    ELSE
        RollLineText$ = "": EXIT FUNCTION
    END IF
    IF dropped THEN s = "drop lowest -- " + s
    RollLineText$ = s
END FUNCTION


' Reveal the roll math one beat at a time inside the dice box -- roll ... + ...
' bonus ... = ... total -- with a rising tick per beat and a bright ding on the
' total. Builds tension. Any key skips the remaining delays. bx1/bx2 = box cols,
' mrow = the math row. Nothing to reveal for a single die with no bonus.
SUB RevealMath (bx1 AS INTEGER, bx2 AS INTEGER, mrow AS INTEGER, roll AS INTEGER, bonus AS INTEGER, ndice AS INTEGER, dropped AS INTEGER)
    DIM parts(1 TO 6) AS STRING, np AS INTEGER, i AS INTEGER, j AS INTEGER, acc AS STRING, skip AS INTEGER
    np = 0
    IF bonus <> 0 THEN
        np = 5
        parts(1) = _TRIM$(STR$(roll))
        IF bonus > 0 THEN parts(2) = "  +" ELSE parts(2) = "  -"
        parts(3) = "  " + _TRIM$(STR$(ABS(bonus)))
        parts(4) = "  ="
        parts(5) = "  " + _TRIM$(STR$(roll + bonus))
    ELSEIF ndice > 1 THEN
        np = 2
        parts(1) = "sum"
        parts(2) = "  " + _TRIM$(STR$(roll))
    ELSE
        EXIT SUB
    END IF
    acc = "": IF dropped THEN acc = "drop lowest -- "
    skip = FALSE
    _DEST CANVAS: _FONT CH
    FOR i = 1 TO np
        acc = acc + parts(i)
        LINE ((bx1 + 1) * CW, mrow * CH)-((bx2 - 1) * CW, (mrow + 1) * CH), BOXBG, BF
        COLOR YELLOWU, BOXBG: PrintCentered mrow, acc
        Present
        IF opt_sfx THEN
            IF i = np THEN SfxOr "dice-math-2", 1100, 0.15 ELSE SfxOr "dice-math-1", 440 + i * 130, 0.06  ' summing: ticks then total
        END IF
        IF NOT skip THEN
            FOR j = 1 TO 22                                       ' ~0.36s of suspense per beat
                _LIMIT 60
                IF INKEY$ <> "" THEN skip = -1: EXIT FOR
                Present
            NEXT j
        END IF
    NEXT i
END SUB


' Tumble n pip d6 and return the total. `caption` (e.g. "attacking the GOBLINS")
' is shown atop the box so the player knows WHAT the roll is for. With `droplow`
' set, the lowest die is greyed out where it lands and left OUT of the total --
' exactly the 4d6-drop-lowest ability roll, shown honestly, not as a bare number.
FUNCTION RollPips% (n AS INTEGER, droplow AS INTEGER, bonus AS INTEGER, caption AS STRING)
    DIM AS INTEGER sz, gap, diceW, bx, by, f, j, tot, lo, drop
    DIM v(1 TO 8) AS INTEGER
    DIM frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE
    DIM cx AS INTEGER, boxw AS INTEGER, contentw AS INTEGER, textw AS INTEGER
    DIM x1 AS INTEGER, x2 AS INTEGER, ytop AS INTEGER, ybot AS INTEGER, hdr AS STRING, rln AS STRING
    DIM ff AS INTEGER, av AS INTEGER, dxp AS INTEGER
    IF n < 1 THEN n = 1
    IF n > 8 THEN n = 8
    sz = 52: gap = 18
    IF n > 3 THEN sz = 40: gap = 12          ' shrink so four dice still sit comfortably
    diceW = n * sz + (n - 1) * gap

    tot = 0
    FOR j = 1 TO n
        v(j) = RollHeld%(j)                        ' pinned by RollHoldSet? keep its face...
        IF v(j) = 0 THEN v(j) = RollDie(6)         ' ...otherwise throw it
        tot = tot + v(j)
    NEXT j
    drop = 0
    IF droplow AND n > 1 THEN
        lo = v(1): drop = 1
        FOR j = 2 TO n
            IF v(j) < lo THEN lo = v(j): drop = j
        NEXT j
        tot = tot - lo
    END IF
    die_a = v(1): die_b = 0
    IF n >= 2 THEN die_b = v(2)
    PublishFaces v(), n
    rln = RollLineText$(tot, bonus, n, drop > 0)     ' "5 + 3 = 8", "sum 12", or ""

    IF opt_showdice THEN
        ' box sized to the wider of the dice row and the caption / result lines
        hdr = ""
        IF LEN(_TRIM$(caption)) > 0 THEN hdr = "-= " + _TRIM$(caption) + " =-"
        textw = LEN(hdr) * CW
        IF LEN(rln) * CW > textw THEN textw = LEN(rln) * CW
        contentw = diceW
        IF textw > contentw THEN contentw = textw
        boxw = contentw + 6 * CW
        cx = SW * CW \ 2
        x1 = cx - boxw \ 2: x2 = cx + boxw \ 2
        bx = cx - diceW \ 2                   ' dice centred within the box
        by = 33 * CH                          ' the row the dice settle into
        ytop = by - 9 * CH: ybot = by + sz + 2 * CH   ' tall box -- room to bounce

        ' physics: pip dice fall + bounce off the walls/floor, then ease into the row
        DIM px(1 TO 8) AS SINGLE, py(1 TO 8) AS SINGLE, vx(1 TO 8) AS SINGLE, vy(1 TO 8) AS SINGLE
        DIM sxp(1 TO 8) AS SINGLE, syp(1 TO 8) AS SINGLE, tt AS SINGLE
        DIM leftw AS INTEGER, rightw AS INTEGER, floory AS INTEGER
        leftw = x1 + 2 * CW: rightw = x2 - 2 * CW: floory = by
        FOR j = 1 TO n
            IF RollHeld%(j) > 0 THEN
                ' A HELD die never leaves the table: seat it in its final row slot from frame one,
                ' with no velocity. The tumble loop skips it, so it simply lies there showing its
                ' face while the others fall around it.
                px(j) = bx + (j - 1) * (sz + gap): py(j) = by
                vx(j) = 0: vy(j) = 0
            ELSE
                px(j) = leftw + RND * (rightw - leftw - sz)
                py(j) = ytop + 2 * CH + RND * CH
                vx(j) = (RND - 0.5) * 11: vy(j) = RND * 2
            END IF
        NEXT j

        DiceTiming frames, rate, settle, hold
        FOR f = 1 TO frames
            _DEST CANVAS
            IF RollTray%(x1, ytop, x2, ybot) THEN _PRINTMODE _KEEPBACKGROUND
            IF LEN(hdr) > 0 THEN
                _FONT CH
                COLOR CYANU, BOXBG: PrintCentered ytop \ CH + 1, hdr
            END IF
            IF f = settle THEN
                FOR j = 1 TO n: sxp(j) = px(j): syp(j) = py(j): NEXT j
            END IF
            FOR j = 1 TO n
                IF RollHeld%(j) > 0 THEN
                    DrawDie px(j), py(j), sz, v(j)   ' pinned: no physics, no tumble, real face
                ELSEIF f < settle THEN
                    vy(j) = vy(j) + 0.7
                    px(j) = px(j) + vx(j): py(j) = py(j) + vy(j)
                    IF px(j) < leftw THEN px(j) = leftw: vx(j) = -vx(j) * 0.6
                    IF px(j) > rightw - sz THEN px(j) = rightw - sz: vx(j) = -vx(j) * 0.6
                    IF py(j) > floory THEN py(j) = floory: vy(j) = -vy(j) * 0.55: vx(j) = vx(j) * 0.85
                    DrawDie px(j), py(j), sz, RollDie(6)
                ELSE
                    tt = (f - settle) / (frames - settle): IF tt > 1 THEN tt = 1
                    DrawDie sxp(j) + (bx + (j - 1) * (sz + gap) - sxp(j)) * tt, syp(j) + (by - syp(j)) * tt, sz, v(j)
                END IF
            NEXT j
            IF opt_sfx THEN
                DiceAnimSfx f, settle, 300 + (f MOD 5) * 40, 0.04
            END IF
            Present
            AudioTick
            _LIMIT rate
        NEXT f
        ' fade the discarded die out -- it dissolves into the box, then the result
        ' line (with that die dropped) is revealed
        IF drop > 0 THEN
            dxp = bx + (drop - 1) * (sz + gap)
            FOR ff = 0 TO 12
                DrawDie dxp, by, sz, v(drop)
                av = ff * 22: IF av > 255 THEN av = 255
                LINE (dxp - 4, by - 4)-(dxp + sz + 9, by + sz + 9), _RGBA32(&H20, &H00, &H00, av), BF
                IF opt_sfx AND ff = 5 THEN Tone 170, 0.06
                Present
                _LIMIT 40
            NEXT ff
            LINE (dxp - 4, by - 4)-(dxp + sz + 9, by + sz + 9), BOXBG, BF
            Present
        END IF
        RevealMath x1 \ CW, x2 \ CW, ybot \ CH - 1, tot, bonus, n, drop > 0   ' slow, tense math reveal
        RollShotSave                 ' dev: capture the settled frame (rollshot)
        _DELAY hold                  ' hold so the settled dice are readable
    END IF

    RollPips = tot
END FUNCTION


' Unified roll: n d6 plus a modifier. In Real-Dice mode the player rolls their
' own dice and types the result (and, per the Dice-Math setting, either adds the
' modifier themselves or lets the game add it). Otherwise the game rolls on screen.
FUNCTION DoRoll% (n AS INTEGER, bonus AS INTEGER, what AS STRING)
    DoRoll = GameRoll(n, 6, bonus, what)
END FUNCTION


' Record the faces of the roll just animated, for callers that need the dice APART rather than
' summed (see DIE_FACE in ENGINE.BI). Every renderer calls this, so a caller can rely on it
' without caring which of the four the player has selected.
SUB PublishFaces (v() AS INTEGER, n AS INTEGER)
    DIM i AS INTEGER
    DIE_FACE_N = 0
    FOR i = 1 TO n
        IF i <= UBOUND(DIE_FACE) THEN DIE_FACE(i) = v(i): DIE_FACE_N = i
    NEXT i
END SUB

' Begin a multi-pass roll: every roll until RollSeqEnd shares ONE tray, so the box does not
' blink out and rebuild between passes. See rollseq_on in ENGINE.BI.
SUB RollSeqBegin
    rollseq_on = -1
END SUB

' End it, putting back the screen the tray was covering.
SUB RollSeqEnd
    rollseq_on = 0
    IF rollseq_snap <> 0 THEN
        _DEST CANVAS
        _PUTIMAGE , rollseq_snap, CANVAS
        _FREEIMAGE rollseq_snap: rollseq_snap = 0
        Present
    END IF
END SUB

' Pin die `i` at face `f` for the next animated roll -- see ROLLHOLD in ENGINE.BI.
SUB RollHoldSet (i AS INTEGER, f AS INTEGER)
    IF i < 1 OR i > UBOUND(ROLLHOLD) THEN EXIT SUB
    IF f < 1 THEN EXIT SUB
    ROLLHOLD(i) = f: ROLLHOLD_ON = -1
END SUB

SUB RollHoldClear
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(ROLLHOLD): ROLLHOLD(i) = 0: NEXT i
    ROLLHOLD_ON = 0
END SUB

' The face die `i` is pinned at, or 0 if it rolls freely.
FUNCTION RollHeld% (i AS INTEGER)
    RollHeld% = 0
    IF ROLLHOLD_ON = 0 THEN EXIT FUNCTION
    IF i >= 1 AND i <= UBOUND(ROLLHOLD) THEN RollHeld% = ROLLHOLD(i)
END FUNCTION

' Face of die `i` from the last animated roll, or 0 if it published none (Real Dice).
FUNCTION DieFace% (i AS INTEGER)
    DieFace% = 0
    IF i >= 1 AND i <= DIE_FACE_N THEN DieFace% = DIE_FACE(i)
END FUNCTION

' Generalised roll: n dice of any size (d6 shows pips, others show a number
' tumbler) plus a modifier -- honouring Real-Dice / Dice-Math exactly like DoRoll.
' Used by D&D-mode combat for d20 to-hit and weapon damage dice.
FUNCTION GameRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM raw AS INTEGER, t AS INTEGER
    IF opt_realdice THEN
        raw = PromptRoll(n, sides, bonus, what)
        die_a = 0: die_b = 0: DIE_FACE_N = 0        ' physical dice -- the game never saw the faces
        IF opt_dicemath THEN
            GameRoll = raw: last_raw = raw - bonus
        ELSE
            GameRoll = raw + bonus: last_raw = raw
        END IF
        EXIT FUNCTION
    END IF
    t = AnimatedRoll%(n, sides, bonus, what)
    GameRoll = t + bonus: last_raw = t
END FUNCTION


' Draw and animate one roll with whichever renderer the player's settings select.
' Returns the raw total (no modifier) -- the bonus is passed through only so each
' renderer can show it in its own sum line.
FUNCTION AnimatedRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    IF opt_dice3d AND dice3d_ready THEN
        AnimatedRoll% = Show3DRoll(n, sides, bonus, 0, what)  ' animated 3D polyhedra (DICE3D module)
    ELSEIF sides = 6 AND opt_d6pips THEN
        AnimatedRoll% = RollPips(n, FALSE, bonus, what)       ' hand-drawn pip dice
    ELSE
        AnimatedRoll% = ShowRollText(n, sides, bonus, what)   ' polyhedra from the DPoly die fonts
    END IF
    ' Holds are consumed by the roll they were set for, and cleared HERE rather than in each
    ' renderer -- so a renderer that ignores them cannot leave them armed for the next roll.
    RollHoldClear
END FUNCTION


' ============================================================================
'  POLYHEDRON DICE -- rendered from the DPoly OTF dice fonts (assets/fonts/dpoly)
'
'  Every glyph in these fonts IS a die face, so a d20 showing 17 is literally the
'  character 'Q' printed in the d20 font. Two variants share each face:
'      UPPERCASE 'A'+n  -> the SOLID die (filled body, number knocked out)
'      lowercase 'a'+n  -> the OUTLINE die (hollow body, solid number)
'  Printing the solid variant in a body colour and then the outline variant on
'  top in an ink colour (with _PRINTMODE _KEEPBACKGROUND, so pass 2 doesn't erase
'  pass 1) gives a filled die with a CONTRASTING number -- which neither variant
'  produces on its own. See DrawFontDie.
'
'  NOTE: the fonts' own d6 is a numbered square, so d6 rolls default to the
'  hand-drawn pip dice (DrawDie) instead -- toggled by the D6 Style setting.
' ============================================================================

' Load the six DPoly die fonts. A handle of 0 means the font is missing, and the
' roll silently falls back to the number tumbler -- never a crash.
'
' Deliberately NOT loaded "monospace": that flag squeezes every glyph into a fixed
' cell narrower than the point size (d20 @56pt -> a 49px cell), which CLIPS the
' left and right points off the polyhedra. Proportional loading keeps each die
' whole; DieWidth measures the real advance with _PRINTWIDTH.
SUB InitDice
    
    CONST PT = 56
    '--- resolved from the declared tree, not a CONST: a CONST cannot call a
    '    function, and the whole point is that the engine does not know where a
    '    host keeps its fonts ---
    DIM FP AS STRING: FP = AssetPath$("fonts", "dpoly/")
    DFONT(4) = _LOADFONT(FP + "DPoly Four-Sider.otf", PT)
    DFONT(6) = _LOADFONT(FP + "DPoly Six-Sider.otf", PT)
    DFONT(8) = _LOADFONT(FP + "DPoly Eight-Sider.otf", PT)
    DFONT(10) = _LOADFONT(FP + "DPoly Ten-Sider.otf", PT)
    DFONT(12) = _LOADFONT(FP + "DPoly Twelve-Sider.otf", PT)
    DFONT(20) = _LOADFONT(FP + "DPoly Twenty-Sider.otf", PT)
    DFROT = _NEWIMAGE(DFROT_W, DFROT_H, 32)      ' scratch for the tumble-spin rotation
END SUB


' Render a font die into the DFROT scratch image (transparent background), centred,
' so it can be rotate-blitted while it tumbles. Mirrors DrawFontDie's two-pass look.
SUB RenderDieToScratch (sides AS INTEGER, face AS INTEGER)
    DIM fh AS LONG, code AS INTEGER, body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG
    DIM od AS LONG, ox AS INTEGER, oy AS INTEGER, dw AS INTEGER
    IF sides < 1 OR sides > 20 THEN EXIT SUB
    fh = DFONT(sides): IF fh <= 0 THEN EXIT SUB
    IF DFROT = 0 THEN EXIT SUB
    DiceColors body, ink
    code = DieGlyphCode(sides, face)
    dw = DieWidth(sides): IF dw < 8 THEN dw = 56
    od = _DEST
    _DEST DFROT
    CLS , _RGBA32(0, 0, 0, 0)                     ' transparent
    _FONT fh
    _PRINTMODE _KEEPBACKGROUND
    ox = (DFROT_W - dw) \ 2
    oy = (DFROT_H - _FONTHEIGHT(fh)) \ 2 + _FONTHEIGHT(fh) \ 4   ' nudge down (top vertex draws above pen)
    IF opt_dicesolid THEN
        COLOR body, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(65 + code)
        COLOR ink, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(97 + code)
    ELSE
        COLOR body, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(97 + code)
    END IF
    _PRINTMODE _FILLBACKGROUND
    _FONT CH
    _DEST od
END SUB


' Rotate the WxH image `src` around its own centre by `ang` radians and draw it
' centred at (cx,cy) on `dst`. Two _MAPTRIANGLEs = one textured quad (nearest-
' neighbour, so the die stays crisp/pixelated to match the ANSI art).
SUB RotoBlit (src AS LONG, w AS INTEGER, h AS INTEGER, cx AS SINGLE, cy AS SINGLE, ang AS SINGLE, dst AS LONG)
    DIM ca AS SINGLE, sa AS SINGLE, hw AS SINGLE, hh AS SINGLE, od AS LONG
    DIM x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE
    DIM x3 AS SINGLE, y3 AS SINGLE, x4 AS SINGLE, y4 AS SINGLE
    ca = COS(ang): sa = SIN(ang)
    hw = w / 2: hh = h / 2
    x1 = cx + (-hw) * ca - (-hh) * sa: y1 = cy + (-hw) * sa + (-hh) * ca   ' TL
    x2 = cx + (hw) * ca - (-hh) * sa: y2 = cy + (hw) * sa + (-hh) * ca     ' TR
    x3 = cx + (hw) * ca - (hh) * sa: y3 = cy + (hw) * sa + (hh) * ca       ' BR
    x4 = cx + (-hw) * ca - (hh) * sa: y4 = cy + (-hw) * sa + (hh) * ca     ' BL
    od = _DEST: _DEST dst
    _MAPTRIANGLE (0, 0)-(w - 1, 0)-(w - 1, h - 1), src TO (x1, y1)-(x2, y2)-(x3, y3)
    _MAPTRIANGLE (0, 0)-(w - 1, h - 1)-(0, h - 1), src TO (x1, y1)-(x3, y3)-(x4, y4)
    _DEST od
END SUB


' Actual on-screen width of one die face in `sides`' font (proportional fonts
' report _FONTWIDTH = 0, so the glyph has to be measured instead). Uses the
' Unicode metric to match _UPRINTSTRING, which is what DrawFontDie renders with.
FUNCTION DieWidth% (sides AS INTEGER)
    DIM fh AS LONG, w AS INTEGER
    DieWidth = 0
    IF sides < 1 OR sides > 20 THEN EXIT FUNCTION
    fh = DFONT(sides)
    IF fh <= 0 THEN EXIT FUNCTION
    _DEST CANVAS
    _FONT fh
    w = _UPRINTWIDTH("A")
    _FONT CH
    DieWidth = w
END FUNCTION


' Tumble pacing for the player's Dice Speed setting: how many frames the dice
' flicker, how fast those frames run, and how long the result is held.
' `settle` is the frame at which the dice stop being random and show the result.
SUB DiceTiming (frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE)
    SELECT CASE opt_dicespeed
        CASE 0: frames = 30: rate = 14: hold = 1.2      ' Slow -- watch them tumble
        CASE 2: frames = 11: rate = 36: hold = 0.45     ' Fast
        CASE 3: frames = 2: rate = 60: hold = 0.25      ' Instant -- barely a flicker
        CASE ELSE: frames = 17: rate = 22: hold = 0.7   ' Normal
    END SELECT
    settle = frames - 3
    IF settle < 1 THEN settle = 1
END SUB







' Which glyph slot (0-based, 0 = 'A'/'a') shows `face` on a `sides`-sided die.
' Every die starts at face 1 in slot 0 -- EXCEPT the d10, whose first glyph is the
' 0 face, so a rolled 10 draws that 0 exactly like a real ten-sider.
FUNCTION DieGlyphCode% (sides AS INTEGER, face AS INTEGER)
    IF sides = 10 THEN
        IF face >= 10 THEN DieGlyphCode = 0 ELSE DieGlyphCode = face
    ELSE
        DieGlyphCode = face - 1
    END IF
END FUNCTION


' The player's chosen dice palette: `body` fills the die, `ink` draws its number.
' Swap the working dice config to the MONSTER's look for the duration of a monster
' roll, then restore. Wrap each monster GameRoll/DoRoll in a Push/Pop pair so the
' player's dice look is never left swapped (even if combat exits mid-roll).
SUB PushMonsterDice
    sav_dicecolor = opt_dicecolor: sav_dicesolid = opt_dicesolid
    sav_d6pips = opt_d6pips: sav_dicespeed = opt_dicespeed
    opt_dicecolor = opt_mon_dicecolor: opt_dicesolid = opt_mon_dicesolid
    opt_d6pips = opt_mon_d6pips: opt_dicespeed = opt_mon_dicespeed
    sav_dice3d = opt_dice3d: opt_dice3d = opt_mon_dice3d: dice3d_use_mon = -1   ' 3D: use the monster set/flag
END SUB
SUB PopMonsterDice
    opt_dicecolor = sav_dicecolor: opt_dicesolid = sav_dicesolid
    opt_d6pips = sav_d6pips: opt_dicespeed = sav_dicespeed
    opt_dice3d = sav_dice3d: dice3d_use_mon = 0
END SUB


' Dice palettes now live in assets/data/dice-colors.txt (loaded by LoadDiceColors).
SUB DiceColors (body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG)
    DIM i AS INTEGER
    i = opt_dicecolor: IF i < 0 OR i > 5 THEN i = 5
    body = DICE_BODY(i): ink = DICE_INK(i)
END SUB

SUB LoadDiceColors
    DIM i AS INTEGER, id AS INTEGER
    ReadDataFile AssetPath$("data", "dice-colors.txt")
    FOR i = 1 TO DLINE_N
        id = VAL(DField$(DLINE(i), 1))
        IF id >= 0 AND id <= 5 THEN
            DICE_CNAME(id) = DField$(DLINE(i), 2)
            DICE_BODY(id) = HexRGB~&(DField$(DLINE(i), 3))
            DICE_INK(id) = HexRGB~&(DField$(DLINE(i), 4))
        END IF
    NEXT i
END SUB


FUNCTION ColorName$ (idx AS INTEGER)
    DIM i AS INTEGER
    i = idx: IF i < 0 OR i > 5 THEN i = 5
    ColorName$ = DICE_CNAME(i)
END FUNCTION

FUNCTION DiceColorName$ ()
    DiceColorName$ = ColorName$(opt_dicecolor)
END FUNCTION


' Draw one polyhedron at pixel (px,py) showing `face`. Solid finish = two passes
' (body then ink); outline finish = the hollow variant in the body colour.
SUB DrawFontDie (px AS INTEGER, py AS INTEGER, sides AS INTEGER, face AS INTEGER)
    DIM fh AS LONG, code AS INTEGER
    DIM body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG
    IF sides < 1 OR sides > 20 THEN EXIT SUB
    fh = DFONT(sides)
    IF fh <= 0 THEN EXIT SUB
    DiceColors body, ink
    code = DieGlyphCode(sides, face)
    _DEST CANVAS
    _FONT fh
    _PRINTMODE _KEEPBACKGROUND          ' vital: pass 2 must not blank pass 1
    ' _UPRINTSTRING, not _PRINTSTRING: _PRINTSTRING clips each glyph to the font
    ' CELL, and these dice draw their top vertex ABOVE the cell -- so the point
    ' gets sliced flat. The Unicode printer renders the whole glyph, point intact.
    IF opt_dicesolid THEN
        COLOR body, BOXBG
        _UPRINTSTRING (px, py), CHR$(65 + code)      ' filled body
        COLOR ink, BOXBG
        _UPRINTSTRING (px, py), CHR$(97 + code)      ' outline + number over it
    ELSE
        COLOR body, BOXBG
        _UPRINTSTRING (px, py), CHR$(97 + code)      ' hollow die only
    END IF
    _PRINTMODE _FILLBACKGROUND
    _FONT CH                            ' back to the 8x16 game font
END SUB


' Tumble n polyhedra, settle on their rolled values, and return the sum.
FUNCTION ShowRollText% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    ShowRollText = ShowRollTextEx(n, sides, FALSE, bonus, what)
END FUNCTION


' As ShowRollText, but with `droplow` the lowest die FADES away after landing and
' is left OUT of the total -- the font-dice twin of RollPips' drop-lowest display,
' so 4d6-drop-lowest animates properly whichever D6 Style the player picked.
FUNCTION ShowRollTextEx% (n AS INTEGER, sides AS INTEGER, droplow AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM v(1 TO 12) AS INTEGER, i AS INTEGER, total AS INTEGER, f AS INTEGER, shown AS INTEGER, av AS INTEGER
    DIM fh AS LONG, dw AS INTEGER, dh AS INTEGER, gap AS INTEGER, rowW AS INTEGER
    DIM dx AS INTEGER, dy AS INTEGER, x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER
    DIM frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE
    DIM lo AS INTEGER, drop AS INTEGER, dxi AS INTEGER
    DIM hdr AS STRING, textw AS INTEGER, contentw AS INTEGER, boxw AS INTEGER, cx AS INTEGER, rln AS STRING
    IF n > 12 THEN n = 12
    total = 0
    FOR i = 1 TO n
        v(i) = RollHeld%(i)                        ' pinned by RollHoldSet? keep its face...
        IF v(i) = 0 THEN v(i) = RollDie(sides)     ' ...otherwise throw it
        total = total + v(i)
    NEXT i
    drop = 0
    IF droplow AND n > 1 THEN
        lo = v(1): drop = 1
        FOR i = 2 TO n
            IF v(i) < lo THEN lo = v(i): drop = i
        NEXT i
        total = total - lo
    END IF
    rln = RollLineText$(total, bonus, n, drop > 0)     ' "5 + 3 = 8", "sum 12", or ""
    PublishFaces v(), n
    IF NOT opt_showdice THEN ShowRollTextEx = total: EXIT FUNCTION

    fh = 0
    IF sides >= 1 AND sides <= 20 THEN fh = DFONT(sides)
    IF fh <= 0 THEN                     ' no die font this size -- plain number tumbler
        ShowRollTextEx = ShowRollValue(total, n * sides, "rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)))
        EXIT FUNCTION
    END IF

    dw = DieWidth(sides): dh = _FONTHEIGHT(fh)
    IF dw < 8 THEN dw = 56
    gap = 14
    rowW = n * dw + (n - 1) * gap
    ' Caption: WHAT the roll is for (e.g. "to hit the GOBLINS"), falling back to
    ' the dice notation when no purpose was given. The box has to fit its widest
    ' TEXT line -- caption or result line -- else a single narrow die leaves the
    ' header spilling out both sides of the box.
    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF
    textw = LEN(hdr) * CW
    IF LEN(rln) * CW > textw THEN textw = LEN(rln) * CW
    contentw = rowW
    IF textw > contentw THEN contentw = textw
    boxw = contentw + 6 * CW                 ' ~24px breathing room each side
    cx = SW * CW \ 2
    x1 = cx - boxw \ 2: x2 = cx + boxw \ 2
    dx = cx - rowW \ 2                        ' dice centred within the box
    dy = 33 * CH                              ' the row the dice settle into
    y1 = dy - 9 * CH: y2 = dy + dh + 2 * CH    ' tall box -- room to bounce down into the row

    ' physics: each die falls under gravity and bounces off the box walls/floor
    ' with damping, flashing random faces, then eases into its neat row slot.
    DIM px(1 TO 12) AS SINGLE, py(1 TO 12) AS SINGLE, vx(1 TO 12) AS SINGLE, vy(1 TO 12) AS SINGLE
    DIM sxp(1 TO 12) AS SINGLE, syp(1 TO 12) AS SINGLE, tt AS SINGLE
    DIM ang(1 TO 12) AS SINGLE, spin(1 TO 12) AS SINGLE
    DIM leftw AS INTEGER, rightw AS INTEGER, floory AS INTEGER
    leftw = x1 + 2 * CW: rightw = x2 - 2 * CW: floory = dy
    FOR i = 1 TO n
        px(i) = leftw + RND * (rightw - leftw - dw)
        py(i) = y1 + 2 * CH + RND * CH
        vx(i) = (RND - 0.5) * 11: vy(i) = RND * 2
        ang(i) = RND * 6.2832: spin(i) = (RND - 0.5) * 0.5   ' random start angle + spin (rad/frame)
    NEXT i

    DiceTiming frames, rate, settle, hold
    FOR f = 1 TO frames
        _DEST CANVAS
        ' The dice tray is drawn from PIXEL coords (the dice bounce in pixels), so the frame is
        ' asked for in cells derived from them. Falls back to the LINE box as everywhere else.
        IF RollTray%(x1, y1, x2, y2) THEN _PRINTMODE _KEEPBACKGROUND
        _FONT CH
        COLOR CYANU, BOXBG: PrintCentered y1 \ CH + 1, hdr
        IF f = settle THEN
            FOR i = 1 TO n: sxp(i) = px(i): syp(i) = py(i): NEXT i   ' freeze the bounce for the ease
        END IF
        FOR i = 1 TO n
            IF f < settle THEN
                vy(i) = vy(i) + 0.7                                  ' gravity
                px(i) = px(i) + vx(i): py(i) = py(i) + vy(i)
                IF px(i) < leftw THEN px(i) = leftw: vx(i) = -vx(i) * 0.6: spin(i) = -spin(i)
                IF px(i) > rightw - dw THEN px(i) = rightw - dw: vx(i) = -vx(i) * 0.6: spin(i) = -spin(i)
                IF py(i) > floory THEN py(i) = floory: vy(i) = -vy(i) * 0.55: vx(i) = vx(i) * 0.85
                ang(i) = ang(i) + spin(i)                            ' spin as it tumbles; walls reverse it
                RenderDieToScratch sides, RollDie(sides)
                RotoBlit DFROT, DFROT_W, DFROT_H, px(i) + dw \ 2, py(i) + dh \ 2, ang(i), CANVAS
            ELSE
                tt = (f - settle) / (frames - settle): IF tt > 1 THEN tt = 1
                dxi = dx + (i - 1) * (dw + gap)
                DrawFontDie sxp(i) + (dxi - sxp(i)) * tt, syp(i) + (dy - syp(i)) * tt, sides, v(i)
            END IF
        NEXT i
        IF opt_sfx THEN
            DiceAnimSfx f, settle, 300 + (f MOD 5) * 40, 0.04
        END IF
        Present
        AudioTick
        _LIMIT rate
    NEXT f
    ' fade the discarded die out -- it dissolves into the box, then the result
    ' line (with that die dropped) is revealed
    IF drop > 0 THEN
        dxi = dx + (drop - 1) * (dw + gap)
        FOR f = 0 TO 12
            DrawFontDie dxi, dy, sides, v(drop)
            av = f * 22: IF av > 255 THEN av = 255
            LINE (dxi - 4, dy - CH)-(dxi + dw + 4, dy + dh + 4), _RGBA32(&H20, &H00, &H00, av), BF
            IF opt_sfx AND f = 5 THEN Tone 170, 0.06
            Present
            _LIMIT 40
        NEXT f
        LINE (dxi - 4, dy - CH)-(dxi + dw + 4, dy + dh + 4), BOXBG, BF
        Present
    END IF
    ' On a single d20 showing 1 or 20 the math is moot (nat-1 = fumble, nat-20 =
    ' crit, whatever the modifier) -- skip the reveal and let combat proceed.
    IF sides = 20 AND n = 1 AND (total = 1 OR total = 20) THEN
        ' no math -- the die face says it all
    ELSE
        RevealMath x1 \ CW, x2 \ CW, y2 \ CH - 1, total, bonus, n, drop > 0   ' slow, tense math reveal
    END IF
    RollShotSave                                  ' dev: capture the settled frame (rollshot)
    _DELAY hold
    ShowRollTextEx = total
END FUNCTION


' Animate a number tumbler that flickers random values (1..hi) then settles on a
' KNOWN total -- lets callers (e.g. 4d6-drop-lowest) control what is summed.
FUNCTION ShowRollValue% (total AS INTEGER, hi AS INTEGER, caption AS STRING)
    DIM AS INTEGER f, bx, by, bw, shown
    DIM frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE
    IF opt_showdice THEN
        bw = 46
        bx = (SW - bw) \ 2: by = 32
        DiceTiming frames, rate, settle, hold
        FOR f = 1 TO frames
            IF f < settle THEN shown = INT(RND * hi) + 1 ELSE shown = total
            _DEST CANVAS
            LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + 6) * CH), BOXBG, BF
            LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + 6) * CH), REDU, B
            COLOR CYANU, BOXBG: PrintCentered by + 1, "-= " + caption + " =-"
            COLOR YELLOWU, BOXBG: PrintCentered by + 3, "[  " + _TRIM$(STR$(shown)) + "  ]"
            IF opt_sfx THEN
                DiceAnimSfx f, settle, 380 + f * 28, 0.05
            END IF
            Present
            AudioTick
            _LIMIT rate
        NEXT f
        _DELAY hold
    END IF
    ShowRollValue = total
END FUNCTION


' Roll one ability score by the Stat-Roll METHOD: straight 3d6, 4d6-drop-lowest, or 3d6
' re-rolling 1s and 2s. Respects Real Dice + Show Dice.
' Chances a low die gets, as an actual loop bound. The setting's 0 means "unlimited", which in a
' game loop has to become a real number -- RR_PASS_CAP. It terminates with probability 1, but
' "probability 1" is not a guarantee worth having with no way out.
CONST RR_PASS_CAP = 16
FUNCTION RerollTries% ()
    IF opt_rerolltries >= 1 AND opt_rerolltries <= REROLL_TRIES_MAX THEN
        RerollTries% = opt_rerolltries
    ELSE
        RerollTries% = RR_PASS_CAP
    END IF
END FUNCTION

FUNCTION RerollTriesName$ ()
    IF opt_rerolltries >= 1 AND opt_rerolltries <= REROLL_TRIES_MAX THEN
        RerollTriesName$ = _TRIM$(STR$(opt_rerolltries)) + " per die"
    ELSE
        RerollTriesName$ = "unlimited"
    END IF
END FUNCTION

' Faces at or below this are thrown again (0 = the method does not re-roll).
FUNCTION RerollFloor% ()
    SELECT CASE opt_statmethod
        CASE STAT_3D6RR1: RerollFloor% = 1
        CASE STAT_3D6RR2: RerollFloor% = 2
        CASE ELSE: RerollFloor% = 0
    END SELECT
END FUNCTION

' Build the SETTINGS presentation order once. Kept apart from the ids so the row can read
' sensibly (plain, heroic, then the two re-rolls, gentlest first) without the stored numbers
' having to agree with that ordering.
SUB InitStatMethods
    STATORD(1) = STAT_3D6
    STATORD(2) = STAT_4D6DL
    STATORD(3) = STAT_3D6RR1
    STATORD(4) = STAT_3D6RR2
END SUB

' Step the Stat Roll row by delta, through STATORD rather than through the raw ids.
SUB CycleStatMethod (delta AS INTEGER)
    DIM i AS INTEGER, at AS INTEGER
    IF STATORD(1) = 0 AND STATORD(4) = 0 THEN InitStatMethods   ' first use (also covers a fresh run)
    at = 1
    FOR i = 1 TO STATMETHOD_N
        IF STATORD(i) = opt_statmethod THEN at = i
    NEXT i
    at = at + delta
    IF at < 1 THEN at = STATMETHOD_N
    IF at > STATMETHOD_N THEN at = 1
    opt_statmethod = STATORD(at)
END SUB

FUNCTION RollAbility% ()
    SELECT CASE opt_statmethod
        CASE STAT_4D6DL
            IF opt_realdice THEN
                RollAbility = PromptRoll(3, 6, 0, "roll 4d6, DROP lowest, enter top 3")
            ELSEIF opt_dice3d AND dice3d_ready THEN
                RollAbility = Show3DRoll(4, 6, 0, 1, "4d6 drop lowest")   ' 3D: roll four, drop lowest (API's dl1)
            ELSEIF opt_d6pips THEN
                RollAbility = RollPips(4, TRUE, 0, "roll 4d6, drop lowest")   ' four pip dice, lowest discarded
            ELSE
                RollAbility = ShowRollTextEx(4, 6, TRUE, 0, "4d6 drop lowest")   ' same, on the font d6
            END IF
        CASE STAT_3D6RR1, STAT_3D6RR2
            IF opt_realdice THEN
                RollAbility = PromptRoll(3, 6, 0, "roll 3d6, RE-ROLL any " + RerollWord$ + ", enter total")
            ELSE
                RollAbility = RollRerollLow%(3, 6, RerollFloor%, "3d6 -- re-roll " + RerollWord$)
            END IF
        CASE ELSE
            RollAbility = GameRoll(3, 6, 0, "ability score")
    END SELECT
END FUNCTION

' Roll n dice of `sides`, throwing again any die at or below `floorv`, until none are, and return
' the total. floorv = 0 is a plain roll.
'
' Rolled the way the rule READS, and SHOWN that way: all n dice stay on the table for every pass,
' the ones keeping their number lie still, and only the low ones are picked up and thrown again
' (RollHoldSet -> the renderers' held-dice path), all inside ONE tray (RollSeqBegin/End).
'
' Two earlier versions got this wrong in instructive ways. The first substituted 3d4+6 --
' mathematically exact (a d6 re-rolling 1s and 2s forever IS a uniform 3..6, i.e. a d4+2) and
' visibly nonsense: you watched three d4s and never saw the mechanic. The second rolled the low
' dice alone in a fresh tray: right maths, still the wrong picture, because the kept dice vanished.
'
' Reads the dice apart through DIE_FACE (PublishFaces), which every renderer fills. If a renderer
' publishes nothing -- or fewer faces than asked for -- the throw total is taken as-is rather than
' inventing dice, so a renderer that forgets to publish degrades to a plain roll.
'
' floorv is clamped below `sides`: a floor at or above the die would re-roll every possible face
' and never terminate. Also capped at RR_MAX_PASSES -- the loop ends with probability 1, which is
' not a guarantee worth having inside a game loop with no way out.
FUNCTION RollRerollLow% (n AS INTEGER, sides AS INTEGER, floorv AS INTEGER, caption AS STRING)
    DIM v(1 TO 12) AS INTEGER
    DIM i AS INTEGER, nlow AS INTEGER, pass AS INTEGER, t AS INTEGER, thrown AS INTEGER
    DIM fl AS INTEGER, cap AS STRING
    fl = floorv
    IF fl >= sides THEN fl = sides - 1            ' or every face is a re-roll and it never ends
    IF n < 1 THEN n = 1
    IF n > 12 THEN n = 12
    RollHoldClear
    RollSeqBegin                                  ' every pass below shares ONE tray
    thrown = AnimatedRoll%(n, sides, 0, caption)
    IF DIE_FACE_N < n OR fl < 1 THEN RollSeqEnd: RollRerollLow% = thrown: EXIT FUNCTION
    FOR i = 1 TO n: v(i) = DieFace%(i): NEXT i
    DO
        nlow = 0
        FOR i = 1 TO n
            IF v(i) <= fl THEN nlow = nlow + 1
        NEXT i
        IF nlow = 0 THEN EXIT DO
        pass = pass + 1
        ' One PASS re-throws every die still low, so after N passes each die has had at most N
        ' chances -- which is what the setting promises, per die rather than per roll.
        IF pass > RerollTries% THEN EXIT DO
        ' Pin every die KEEPING its number; the rest are thrown again. The roll is still the full
        ' set -- that is what keeps them all on the table and in their seats.
        RollHoldClear
        FOR i = 1 TO n
            IF v(i) > fl THEN RollHoldSet i, v(i)
        NEXT i
        IF nlow = 1 THEN cap = "re-rolling 1 low die" ELSE cap = "re-rolling " + _TRIM$(STR$(nlow)) + " low dice"
        thrown = AnimatedRoll%(n, sides, 0, cap)
        IF DIE_FACE_N < n THEN EXIT DO            ' keep what we have rather than guess
        FOR i = 1 TO n: v(i) = DieFace%(i): NEXT i
    LOOP
    RollHoldClear
    RollSeqEnd                                    ' one tray for the whole sequence -- take it down
    t = 0
    FOR i = 1 TO n: t = t + v(i): NEXT i
    RollRerollLow% = t
END FUNCTION

' Roll one ability score with NO dice animation and no waiting -- the [Shift-R] fast re-roll.
' Same distributions as RollAbility%, straight off the RNG: a player who wants to churn re-rolls
' until they like the spread should not have to sit through six dice animations each time.
FUNCTION RollAbilityFast% ()
    DIM j AS INTEGER, t AS INTEGER, v AS INTEGER, lo AS INTEGER, tries AS INTEGER
    SELECT CASE opt_statmethod
        CASE STAT_4D6DL
            t = 0: lo = 7
            FOR j = 1 TO 4
                v = RollDie(6): t = t + v
                IF v < lo THEN lo = v
            NEXT j
            RollAbilityFast% = t - lo
        CASE STAT_3D6RR1, STAT_3D6RR2
            t = 0
            FOR j = 1 TO 3                                    ' same rule as RollRerollLow%,
                v = RollDie(6)                                ' just without the animation
                tries = 0
                DO WHILE v <= RerollFloor% _ANDALSO tries < RerollTries%
                    v = RollDie(6): tries = tries + 1
                LOOP
                t = t + v
            NEXT j
            RollAbilityFast% = t
        CASE ELSE
            t = 0
            FOR j = 1 TO 3: t = t + RollDie(6): NEXT j
            RollAbilityFast% = t
    END SELECT
END FUNCTION

' Human-readable name of the current ability-roll method (SETTINGS row + the rules screen).
FUNCTION StatMethodName$ ()
    SELECT CASE opt_statmethod
        CASE STAT_4D6DL: StatMethodName$ = "4d6 drop-low"
        CASE STAT_3D6RR1: StatMethodName$ = "3d6 re-roll 1s"
        CASE STAT_3D6RR2: StatMethodName$ = "3d6 re-roll 1s & 2s"
        CASE ELSE: StatMethodName$ = "straight 3d6"
    END SELECT
END FUNCTION

' "1s" / "1s and 2s" -- the phrase the roll captions and the Real Dice prompt share, so the
' player is told the same rule wherever it is stated.
FUNCTION RerollWord$ ()
    IF RerollFloor% >= 2 THEN RerollWord$ = "1s and 2s" ELSE RerollWord$ = "1s"
END FUNCTION


' Ask the player what they physically rolled; validates against the possible range.
FUNCTION PromptRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM entry AS STRING, k AS STRING, chcode AS INTEGER, v AS INTEGER   ' NOT "ch" -- shadows CH
    DIM spec AS STRING, l1 AS STRING, msg AS STRING, lo AS INTEGER, hi AS INTEGER
    spec = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    IF bonus > 0 AND opt_dicemath THEN
        l1 = "Roll " + spec + ", add +" + _TRIM$(STR$(bonus)) + ", and enter the TOTAL:"
        lo = n + bonus: hi = n * sides + bonus
    ELSEIF bonus > 0 THEN
        l1 = "Roll " + spec + " (the game adds +" + _TRIM$(STR$(bonus)) + ") -- enter your DICE:"
        lo = n: hi = n * sides
    ELSE
        l1 = "Roll " + spec + " and enter the result:"
        lo = n: hi = n * sides
    END IF
    entry = "": msg = ""
    DO
        _LIMIT 60
        _DEST CANVAS
        LINE (24 * CW, 19 * CH)-(108 * CW, 31 * CH), BOXBG, BF
        LINE (24 * CW, 19 * CH)-(108 * CW, 31 * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered 21, "-=  R E A L   D I C E  =-"
        COLOR CYANU, BOXBG: PrintCentered 22, "(" + what + ")"
        COLOR WHITE, BOXBG: PrintCentered 25, l1
        COLOR GREENU, BOXBG: PrintCentered 28, "> " + entry + "_"
        IF LEN(msg) > 0 THEN COLOR REDU, BOXBG: PrintCentered 30, msg
        Present
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                IF LEN(entry) > 0 THEN
                    v = VAL(entry)
                    IF sides = 10 AND n = 1 AND v = 0 THEN v = 10   ' a lone d10 shows "0" for 10 -- accept it
                    IF v >= lo AND v <= hi THEN
                        PromptRoll = v: EXIT FUNCTION
                    ELSE
                        msg = "That's not possible -- enter " + _TRIM$(STR$(lo)) + " to " + _TRIM$(STR$(hi)): entry = ""
                    END IF
                END IF
            ELSEIF k = CHR$(8) THEN
                IF LEN(entry) > 0 THEN entry = LEFT$(entry, LEN(entry) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                IF chcode >= 48 AND chcode <= 57 AND LEN(entry) < 3 THEN entry = entry + k
            END IF
        END IF
    LOOP
END FUNCTION




' The "continue or new?" dialog. It lived in SAVEIO.bas beside the token reader, but it is a
' SCREEN -- it draws and waits on a key -- so it belongs with the other UI primitives. Moving
' it leaves engine/SAVEIO.bas genuinely pure file plumbing (and stub-free to unit-test).
' Offered when entering the dungeon and a save exists: continue it or start fresh.
FUNCTION AskContinue%
    DIM k AS STRING
    _DEST CANVAS: CLS , BLACK
    COLOR YELLOWU, BLACK: PrintCentered 22, "A saved delve awaits you."
    COLOR CYANU, BLACK: PrintCentered 24, "[C] CONTINUE saved game        [N] start a NEW game"
    Present
    DO
        _LIMIT 60: k = UCASE$(INKEY$): Present
        IF k = "C" OR k = CHR$(13) THEN AskContinue = -1: EXIT FUNCTION
        IF k = "N" OR k = CHR$(27) THEN AskContinue = 0: EXIT FUNCTION
    LOOP
END FUNCTION


' Apply the display SETTINGS (the one place the _FULLSCREEN calls route through).
' Moved from game/MENU.bas: it reads only opt_fullscreen / opt_smoothamt, both ENGINE.BI
' globals, and touches nothing game-specific. Those two options showed up as
' "declared in ENGINE.BI but never used by engine/" purely because their one consumer
' sat on the game side -- here the global was right and the CODE was misfiled.
' Apply the fullscreen + pixel-smoothing preferences to the display. _SMOOTH gives
' bilinear-filtered scaling (soft, and it makes the tumbling dice shimmer); without
' it the canvas is pixel-doubled crisp -- better suited to the ANSI/text art.
' Apply the Full Screen + Pixel Smoothing settings.
'
' THE SIZE OF SCREEN 0 IS THE WHOLE TRICK. Per the wiki, `_FULLSCREEN [_STRETCH|_SQUAREPIXELS]
' [, _SMOOTH]` scales THE SCREEN IMAGE to the monitor, and _SMOOTH "applies antialiasing to the
' stretched screen" -- so _SMOOTH only does anything to the extent _FULLSCREEN is actually
' scaling something.
'
' Since screen 0 became the WINDOW surface (so windowed resize could work at all), a player who
' had resized or maximised first went fullscreen with screen 0 already near monitor size. There
' was then almost nothing left for _FULLSCREEN to scale, so _SMOOTH had nothing to antialias --
' and Present had already blitted the canvas up to that size with nearest-neighbour sampling,
' mangling the grid before the driver ever saw it. Fullscreen looked unfiltered because it was.
'
' So: entering fullscreen puts screen 0 back to EXACTLY the canvas size. Present's blit is then
' 1:1 and lossless, and _FULLSCREEN performs the one and only scale, antialiased by the driver.
' Leaving fullscreen restores the windowed size the player had.
SUB ApplyDisplay
    ' Entering or leaving fullscreen raises a _RESIZE just like a drag does. Present must not
    ' mistake it for the player resizing the window and "correct" us back to the old size --
    ' so book the echo before making the change. (Same guard TakeWindowSize uses.)
    pres_deferred = pres_deferred + 1
    pres_lastw = -1                  ' geometry changes either way -> repaint the letterbox bars
    IF opt_fullscreen THEN
        IF _WIDTH(0) <> SW * CW OR _HEIGHT(0) <> SH * CH THEN
            IF _WIDTH(0) > 0 THEN pres_winsave_w = _WIDTH(0): pres_winsave_h = _HEIGHT(0)
            pres_deferred = pres_deferred + 1
            SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)   ' 1:1 with the canvas -- give the driver the whole scale
            _DEST CANVAS
        END IF
        IF opt_smoothamt > 0 THEN
            _FULLSCREEN _SQUAREPIXELS, _SMOOTH       ' square pixels, antialiased by the GPU
        ELSE
            _FULLSCREEN _SQUAREPIXELS                ' square pixels, no filtering
        END IF
    ELSE
        _FULLSCREEN _OFF
        ' Back to the window the player had before fullscreen (first run: leave it alone).
        IF pres_winsave_w > 0 THEN
            IF _WIDTH(0) <> pres_winsave_w OR _HEIGHT(0) <> pres_winsave_h THEN
                pres_deferred = pres_deferred + 1
                SCREEN _NEWIMAGE(pres_winsave_w, pres_winsave_h, 32)
                _DEST CANVAS
            END IF
        END IF
    END IF
END SUB
