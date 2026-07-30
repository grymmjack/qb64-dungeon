' ============================================================================
'  FIGHT.bas -- ENGINE tactical-combat SCREEN: actors in, pixels out.
'
'  This module holds the actor state and the renderer. It holds NO combat rules: nothing
'  here decides what a hit does, what a monster is, or who wins. The game fills the actor
'  slots and calls FightRender; the resolution model lives in engine/GAUGE.bas and the
'  DUNGEON!-specific mapping lives in game/. That split is what lets a different game reuse
'  a 1-vs-4 tactical screen without inheriting DUNGEON!'s combat.
'
'  EVERY coordinate comes from assets/data/ui-fight-layout.txt through engine/LAYOUT.bas.
'  There is not one hardcoded column in this file. Move a box in that text file and the
'  renderer follows, which is the only reason placement can be iterated against art that is
'  still being drawn.
'
'  SLOT 0 IS THE PLAYER, 1..FIGHT_MAXFOE are the foes. `FaRgn$` turns a slot into a region
'  name -- 0 -> "player.hpbar", 3 -> "enemy3.hpbar" -- so one loop paints all five actors and
'  the player is not a special case with its own duplicated draw code. Add a sixth actor slot
'  and only the layout file changes.
'
'  THE FONT TRAP: the board runs an 8x16 cell (CH) and this screen runs 8x8. Every text draw
'  here needs `_FONT 8`, and it MUST be restored to `_FONT CH` on the way out -- otherwise the
'  board, HUD and menus all render at half height afterwards with no error to explain it. That
'  is why the font switch is bracketed in FightRender rather than left to callers.
' ============================================================================

' Turn an actor slot into a layout region name. The player's regions are "player.*" and each
' foe's are "enemy<n>.*" -- the naming convention IS the dispatch.
FUNCTION FaRgn$ (a AS INTEGER, suffix AS STRING)
    IF a = 0 THEN
        FaRgn$ = "player." + suffix
    ELSE
        FaRgn$ = "enemy" + LTRIM$(STR$(a)) + "." + suffix
    END IF
END FUNCTION

' Load the fight layout. Returns TRUE if the screen can be drawn at all. Call once at startup;
' FightRender is a no-op until it succeeds, so a data pack shipping no layout degrades to "no
' tactical screen" instead of drawing garbage at (0,0).
FUNCTION FightInit% (path AS STRING)
    IF LoadLayout%(path, 8, 8) > 0 AND LayHas%("screen") THEN
        FIGHT_LAYOUT_OK = -1
    ELSE
        FIGHT_LAYOUT_OK = 0
    END IF
    FightInit% = FIGHT_LAYOUT_OK
END FUNCTION

'--- actor state -------------------------------------------------------------

' Empty every slot and the log. Called at the start of an encounter.
SUB FightReset
    DIM a AS INTEGER, r AS INTEGER
    FOR a = 0 TO FIGHT_MAXFOE
        FA_USED(a) = 0: FA_ALIVE(a) = 0
        FA_NAME(a) = "": FA_SUB(a) = "": FA_ART(a) = ""
        FA_HP(a) = 0: FA_MAXHP(a) = 0: FA_FUSE(a) = 0
        FA_ART2(a) = ""
        FOR r = 1 TO FIGHT_STATROWS
            FA_LAB(a, r) = "": FA_VAL(a, r) = ""
            FA_SLAB(a, r) = "": FA_SVAL(a, r) = ""
        NEXT r
    NEXT a
    FA_TARGET = 0: FIGHT_ROUND = 1: FIGHT_INIT = "": FIGHT_BANNER = ""
    FLOG_N = 0
END SUB

' Fill one actor slot. `artbase` is a path fragment under the strategic-combat art folders
' ("monsters/goblin") -- NOT a resolved filename, so the pack layers still get to resolve it.
SUB FightSetActor (a AS INTEGER, nm AS STRING, subt AS STRING, artbase AS STRING, hp AS INTEGER, mx AS INTEGER)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FA_USED(a) = -1
    FA_NAME(a) = nm: FA_SUB(a) = subt: FA_ART(a) = artbase
    FA_HP(a) = hp: FA_MAXHP(a) = mx
    IF hp > 0 THEN FA_ALIVE(a) = -1 ELSE FA_ALIVE(a) = 0
END SUB

' Supply an already-resolved fallback image for a slot, used when no fight-sized art exists.
' Pass a real path (what MonsterSprite$ etc. return), not a basename -- the engine does not know
' the game's category layout and must not have to guess it.
SUB FightSetArtFallback (a AS INTEGER, path AS STRING)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FA_ART2(a) = path
END SUB

' One of the three generic stat rows (DUNGEON! uses MELEE / RANGED / ARMOR).
SUB FightSetStat (a AS INTEGER, row AS INTEGER, lab AS STRING, vtext AS STRING)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    IF row < 1 OR row > FIGHT_STATROWS THEN EXIT SUB
    FA_LAB(a, row) = lab: FA_VAL(a, row) = vtext
END SUB

' One of the three generic status rows (DUNGEON! uses HEALTH / STANCE / EFFECT).
SUB FightSetStatus (a AS INTEGER, row AS INTEGER, lab AS STRING, vtext AS STRING)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    IF row < 1 OR row > FIGHT_STATROWS THEN EXIT SUB
    FA_SLAB(a, row) = lab: FA_SVAL(a, row) = vtext
END SUB

' Apply damage/healing and keep FA_ALIVE consistent. Clamped both ends so a renderer can never
' be handed a negative or over-max bar to draw.
SUB FightSetHp (a AS INTEGER, hp AS INTEGER)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FA_HP(a) = hp
    IF FA_HP(a) < 0 THEN FA_HP(a) = 0
    IF FA_MAXHP(a) > 0 AND FA_HP(a) > FA_MAXHP(a) THEN FA_HP(a) = FA_MAXHP(a)
    IF FA_HP(a) > 0 THEN FA_ALIVE(a) = -1 ELSE FA_ALIVE(a) = 0
END SUB

' 0..1 fill for an actor's gauge/fuse bar, clamped.
SUB FightSetFuse (a AS INTEGER, frac AS SINGLE)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FA_FUSE(a) = frac
    IF FA_FUSE(a) < 0 THEN FA_FUSE(a) = 0
    IF FA_FUSE(a) > 1 THEN FA_FUSE(a) = 1
END SUB

' How many foe slots still have a living occupant -- the "is the fight over" question, and
' also the crowd-pressure input GaugeKnobs wants (press = live foes - 1).
FUNCTION FightLiveFoes%
    DIM a AS INTEGER, n AS INTEGER
    FOR a = 1 TO FIGHT_MAXFOE
        IF FA_USED(a) AND FA_ALIVE(a) THEN n = n + 1
    NEXT a
    FightLiveFoes% = n
END FUNCTION

' Append a log line. `mark` is the one-character gutter tag the mockup shows (M / C / ...);
' pass "" for none. The log is a scrolling ring: once full, the oldest line drops.
SUB FightLog (mark AS STRING, s AS STRING)
    DIM i AS INTEGER
    IF FLOG_N >= FIGHT_LOGMAX THEN
        FOR i = 1 TO FIGHT_LOGMAX - 1
            FLOG(i) = FLOG(i + 1): FLOG_MARK(i) = FLOG_MARK(i + 1)
        NEXT i
        FLOG_N = FIGHT_LOGMAX - 1
    END IF
    FLOG_N = FLOG_N + 1
    FLOG(FLOG_N) = s: FLOG_MARK(FLOG_N) = LEFT$(mark, 1)
END SUB

'--- art -------------------------------------------------------------------

' Resolve an actor's portrait and hand back a ready-to-blit image at the region's exact pixel
' size, or 0 if there is no art for it yet.
'
' Resolution order, each step already falling back pack -> default per file (AnsiFile$/ArtFile$):
'   1. strategic-combat/<name>.ans   fight-sized ANSI -- blits 1:1, no resampling
'   2. strategic-combat/<name>.png   fight-sized pixel art
'   3. <name>.png                    the general art the game already ships, stretched
' ANSI leads because this screen IS text-mode art. Step 3 is what keeps the screen looking
' finished while a fight-sized pack is still mostly unmade.
FUNCTION FightPortrait& (artbase AS STRING, resolved AS STRING, pxw AS INTEGER, pxh AS INTEGER)
    DIM p AS STRING, b AS STRING
    FightPortrait& = 0
    b = _TRIM$(artbase)
    IF LEN(b) = 0 AND LEN(_TRIM$(resolved)) = 0 THEN EXIT FUNCTION
    IF LEN(b) = 0 THEN GOTO tryResolved

    ' 1. FIGHT-SIZED ANSI. Authored at exactly the region size, so it blits 1:1 with no
    '    resampling -- the best case, and why ANSI is preferred on a text-mode screen.
    p = AnsiFile$("strategic-combat/" + b + ".ans")
    IF LEN(p) > 0 THEN FightPortrait& = FightAnsiTile&(p, pxw, pxh): EXIT FUNCTION

    ' 2. FIGHT-SIZED PIXEL ART, same subfolder.
    p = ArtFile$("strategic-combat/" + b + ".png")
    IF LEN(p) > 0 THEN FightPortrait& = Sprite&(p): EXIT FUNCTION

    ' 3. THE GENERAL ART THE GAME ALREADY SHIPS, resolved BY the game (FightSetArtFallback) and
    '    stretched into the box. This is the fallback that matters: a fight-sized pack will be
    '    incomplete for a long time -- most of it wants to be hand-drawn -- while every category
    '    already has general art. A slightly stretched real goblin beats "[ no art ]".
    tryResolved:
    p = _TRIM$(resolved)
    IF LEN(p) > 0 THEN
        IF _FILEEXISTS(p) THEN FightPortrait& = Sprite&(p): EXIT FUNCTION
    END IF

    ' NOT tried: the general ANSI art ("monsters/goblin.ans"). Those are authored at other
    ' character sizes (18x12 for the combat panel), and ANSI_Print auto-wraps at the target
    ' image's width -- so rendering 18-column art into a 33-column tile does not scale it, it
    ' REFLOWS it into garbage. Pixel art stretches cleanly and covers the same entities, so it
    ' is the honest fallback. A fight-sized .ans has to be authored as one.
END FUNCTION

' Render a .ans into a cached image of exactly (pxw x pxh) pixels. Cached by path: ANSI_Print
' walks the whole byte stream, so doing this per frame for five portraits would dominate the
' frame time for output that never changes.
FUNCTION FightAnsiTile& (path AS STRING, pxw AS INTEGER, pxh AS INTEGER)
    DIM i AS INTEGER, img AS LONG, raw AS STRING, prevdest AS LONG
    FightAnsiTile& = 0
    FOR i = 1 TO FTILE_N
        IF FTILE_PATH(i) = path THEN FightAnsiTile& = FTILE_IMG(i): EXIT FUNCTION
    NEXT i
    IF _FILEEXISTS(path) = 0 THEN EXIT FUNCTION
    raw = _READFILE$(path)
    IF LEN(raw) = 0 THEN EXIT FUNCTION
    IF pxw < 1 OR pxh < 1 THEN EXIT FUNCTION
    img = _NEWIMAGE(pxw, pxh, 32)
    IF img >= -1 THEN EXIT FUNCTION                   ' _NEWIMAGE failure -- no art rather than a crash
    prevdest = _DEST
    _DEST img
    _FONT 8                                           ' the art is authored on an 8x8 cell
    CLS , BLACK
    ANSI_Print (raw)
    _DEST prevdest
    IF FTILE_N < FTILE_MAX THEN
        FTILE_N = FTILE_N + 1
        FTILE_PATH(FTILE_N) = path: FTILE_IMG(FTILE_N) = img
    END IF
    FightAnsiTile& = img
END FUNCTION

' Drop every cached ANSI tile. Call when a fight ends or the art pack changes -- otherwise a
' pack switch would keep showing the previous pack's portraits, and the handles would leak.
SUB FightFreeTiles
    DIM i AS INTEGER
    FOR i = 1 TO FTILE_N
        IF FTILE_IMG(i) < -1 THEN _FREEIMAGE FTILE_IMG(i)
        FTILE_IMG(i) = 0: FTILE_PATH(i) = ""
    NEXT i
    FTILE_N = 0
END SUB

'--- primitives, all region-addressed --------------------------------------

' Print one line inside a named region, `dy` text rows down from its top. Clipped to the
' region's width so a long name can never spill into the neighbouring panel -- with four
' 33-column panels side by side, an unclipped name is a visible bug every time.
SUB FightText (rgn AS STRING, dy AS INTEGER, s AS STRING, kol AS _UNSIGNED LONG)
    DIM t AS STRING, wide AS INTEGER
    IF LayHas%(rgn) = 0 THEN EXIT SUB
    wide = LayCols%(rgn)
    IF wide < 1 THEN EXIT SUB
    t = s
    IF LEN(t) > wide THEN t = LEFT$(t, wide)
    COLOR kol, BLACK
    _PRINTSTRING (LayPX%(rgn), LayPY%(rgn) + dy * 8), t
END SUB

' A "LABEL: value" row, label left and value right-aligned in the region.
' NOTE the parameter is `vtext`, not `val` -- VAL is a QB64 reserved word and using it as a
' parameter name fails to compile with "Name already in use", which never says "error" -- the mockup's
' `ARMOR:` / `AC8` pattern. Value wins when the two would collide, since the value is the
' information and the label is the decoration.
SUB FightStatRow (rgn AS STRING, dy AS INTEGER, lab AS STRING, vtext AS STRING, kol AS _UNSIGNED LONG)
    DIM wide AS INTEGER, vx AS INTEGER
    IF LayHas%(rgn) = 0 THEN EXIT SUB
    IF LEN(_TRIM$(lab)) = 0 AND LEN(_TRIM$(vtext)) = 0 THEN EXIT SUB
    wide = LayCols%(rgn)
    FightText rgn, dy, lab, GREY
    vx = wide - LEN(vtext)
    IF vx < LEN(lab) + 1 THEN vx = LEN(lab) + 1
    IF vx < wide THEN
        COLOR kol, BLACK
        _PRINTSTRING (LayPX%(rgn) + vx * 8, LayPY%(rgn) + dy * 8), vtext
    END IF
END SUB

' A horizontal fill bar across a named region. Drawn in pixels, not characters, so a 32-cell
' bar still moves smoothly at 1/256th steps instead of jumping a whole glyph at a time.
SUB FightBar (rgn AS STRING, frac AS SINGLE, kol AS _UNSIGNED LONG)
    DIM px AS INTEGER, py AS INTEGER, wide AS INTEGER, high AS INTEGER, filled AS INTEGER, f AS SINGLE
    IF LayHas%(rgn) = 0 THEN EXIT SUB
    px = LayPX%(rgn): py = LayPY%(rgn): wide = LayPW%(rgn): high = LayPH%(rgn)
    IF wide < 2 OR high < 2 THEN EXIT SUB
    f = frac
    IF f < 0 THEN f = 0
    IF f > 1 THEN f = 1
    LINE (px, py)-(px + wide - 1, py + high - 1), BOXBG, BF
    filled = INT((wide - 2) * f)
    IF filled > 0 THEN LINE (px + 1, py + 1)-(px + filled, py + high - 2), kol, BF
    LINE (px, py)-(px + wide - 1, py + high - 1), GREY, B
END SUB

' Outline a named region. Used for panel frames and the target highlight.
SUB FightFrame (rgn AS STRING, kol AS _UNSIGNED LONG)
    IF LayHas%(rgn) = 0 THEN EXIT SUB
    LINE (LayPX%(rgn), LayPY%(rgn))-(LayPX%(rgn) + LayPW%(rgn) - 1, LayPY%(rgn) + LayPH%(rgn) - 1), kol, B
END SUB

' Fuse colour: cool while there is time, yellow at the halfway mark, red when it is about to
' fire. The whole tactical read is "which of these four is imminent" -- four bars in one colour
' forces the player to compare LENGTHS across 33 columns, which is slow enough that the fuse
' fires while they are still reading. Colour makes it a glance.
FUNCTION FightFuseColor~& (frac AS SINGLE)
    IF frac >= 0.85 THEN
        FightFuseColor~& = REDU
    ELSEIF frac >= 0.5 THEN
        FightFuseColor~& = YELLOWU
    ELSE
        FightFuseColor~& = CYANU
    END IF
END FUNCTION

' Health colour: green -> yellow -> red as it drains. The renderer reads health as a COLOUR
' as well as a length, so a glance at four foes ranks them without reading four numbers.
FUNCTION FightHpColor~& (frac AS SINGLE)
    IF frac > 0.5 THEN
        FightHpColor~& = GREENU
    ELSEIF frac > 0.25 THEN
        FightHpColor~& = YELLOWU
    ELSE
        FightHpColor~& = REDU
    END IF
END FUNCTION

'--- the renderer ----------------------------------------------------------

' Paint the whole tactical screen onto CANVAS from the current actor state.
'
' Brackets the 8x8 font switch (see the FONT TRAP note at the top) and restores _FONT CH and
' the previous _DEST on the way out, so a caller cannot forget and leave the board at half
' height. Safe to call every frame.
SUB FightRender
    DIM a AS INTEGER, prevdest AS LONG, frame AS LONG, p AS STRING
    IF FIGHT_LAYOUT_OK = 0 THEN EXIT SUB
    prevdest = _DEST
    _DEST CANVAS
    _FONT 8
    CLS , BLACK

    ' The authored chrome, if the art exists yet. Until then FightDrawChrome outlines every
    ' panel so the screen is usable while the art is still being generated -- without it the
    ' four foe columns run together into one dark band with no visible boundary.
    FIGHT_CHROME = 0
    p = AnsiFile$("strategic-combat/frame.ans")
    IF LEN(p) > 0 THEN
        frame = FightAnsiTile&(p, LayPW%("screen"), LayPH%("screen"))
        IF frame < -1 THEN
            _PUTIMAGE (LayPX%("screen"), LayPY%("screen")), frame, CANVAS
            FIGHT_CHROME = -1
        END IF
    END IF
    IF FIGHT_CHROME = 0 THEN FightDrawChrome

    FightDrawTop
    FOR a = 0 TO FIGHT_MAXFOE
        IF FA_USED(a) THEN FightDrawActor a
    NEXT a
    FightDrawLog
    FightDrawMenu
    FightDrawDivider "rule.mid"
    FightDrawDivider "rule.split"

    IF LEN(_TRIM$(FIGHT_BANNER)) > 0 THEN FightText "banner", 0, _TRIM$(FIGHT_BANNER), YELLOWU

    _FONT CH                                          ' MUST restore, or the board halves
    _DEST prevdest
END SUB

SUB FightDrawTop
    FightText "top.round", 0, "ROUND" + STR$(FIGHT_ROUND), WHITE
    IF LEN(_TRIM$(FIGHT_INIT)) > 0 THEN FightText "top.init", 0, "INITIATIVE: " + _TRIM$(FIGHT_INIT), CYANU
END SUB

' Fill a `box` region solidly -- the mockup's horizontal and vertical rules.
SUB FightDrawDivider (rgn AS STRING)
    IF LayHas%(rgn) = 0 THEN EXIT SUB
    LINE (LayPX%(rgn), LayPY%(rgn))-(LayPX%(rgn) + LayPW%(rgn) - 1, LayPY%(rgn) + LayPH%(rgn) - 1), GREY, BF
END SUB

' One actor's whole column: portrait, name, health, stats, status, fuse. Identical code for
' the player and all four foes -- only FaRgn$ differs, which is the point of slot 0.
SUB FightDrawActor (a AS INTEGER)
    DIM art AS STRING, nmr AS STRING, r AS INTEGER, img AS LONG
    DIM px AS INTEGER, py AS INTEGER, pxw AS INTEGER, pxh AS INTEGER
    DIM frac AS SINGLE, kol AS _UNSIGNED LONG

    art = FaRgn$(a, "art")
    IF LayHas%(art) THEN
        px = LayPX%(art): py = LayPY%(art): pxw = LayPW%(art): pxh = LayPH%(art)
        img = FightPortrait&(FA_ART(a), FA_ART2(a), pxw, pxh)
        IF img < -1 THEN
            FightBlitFit img, px, py, pxw, pxh
        ELSE
            LINE (px, py)-(px + pxw - 1, py + pxh - 1), BOXBG, BF          ' placeholder: no art yet
        END IF
        ' A dead actor is dimmed rather than removed, so the column keeps its place and the
        ' player can still read what they killed.
        IF FA_ALIVE(a) = 0 THEN FightDimBox px, py, pxw, pxh
        ' The "no art" label goes on LAST, after any dim -- scanline-dimming text turns it into
        ' unreadable stripes, and this label exists precisely to be read while art is missing.
        IF img >= -1 THEN FightText art, pxh \ 16, "  [ no art: " + _TRIM$(FA_ART(a)) + " ]", GREY
        ' The selected target gets a bright frame -- with four columns this is the only thing
        ' telling the player where an attack will land.
        IF a > 0 AND a = FA_TARGET THEN FightFrame art, YELLOWU
    END IF

    nmr = FaRgn$(a, "name")
    IF FA_ALIVE(a) THEN kol = WHITE ELSE kol = GREY
    FightText nmr, 0, _TRIM$(FA_NAME(a)), kol
    IF LayHas%(FaRgn$(a, "class")) THEN FightText FaRgn$(a, "class"), 0, _TRIM$(FA_SUB(a)), GREY

    IF FA_MAXHP(a) > 0 THEN frac = FA_HP(a) / FA_MAXHP(a) ELSE frac = 0
    FightBar FaRgn$(a, "hpbar"), frac, FightHpColor~&(frac)

    FOR r = 1 TO FIGHT_STATROWS
        FightStatRow FaRgn$(a, "stats"), r - 1, _TRIM$(FA_LAB(a, r)), _TRIM$(FA_VAL(a, r)), WHITE
        FightStatRow FaRgn$(a, "status"), r - 1, _TRIM$(FA_SLAB(a, r)), _TRIM$(FA_SVAL(a, r)), CYANU
    NEXT r

    IF FA_FUSE(a) > 0 THEN FightBar FaRgn$(a, "gauge"), FA_FUSE(a), FightFuseColor~&(FA_FUSE(a))
END SUB

' Darken a box by drawing scanlines through it. Every other row rather than a translucent
' overlay, because a semi-transparent _COPYIMAGE(,33) tile renders INVISIBLE on some GL
' drivers (the same trap that forced DICE3D's lighting into opaque atlas columns).
SUB FightDimBox (px AS INTEGER, py AS INTEGER, pxw AS INTEGER, pxh AS INTEGER)
    DIM y AS INTEGER
    FOR y = py TO py + pxh - 1 STEP 2
        LINE (px, y)-(px + pxw - 1, y), BLACK
    NEXT y
END SUB

' The combat log, newest at the bottom, with the mockup's one-character gutter column.
SUB FightDrawLog
    DIM rows AS INTEGER, first AS INTEGER, i AS INTEGER, dy AS INTEGER
    IF LayHas%("log.body") = 0 THEN EXIT SUB
    rows = LayRows%("log.body")
    IF rows < 1 THEN EXIT SUB
    first = FLOG_N - rows + 1
    IF first < 1 THEN first = 1
    dy = 0
    FOR i = first TO FLOG_N
        IF LEN(FLOG_MARK(i)) > 0 THEN FightText "log.gutter", dy, FLOG_MARK(i), YELLOWU
        ' Indent past the gutter so a marker and its line never overlap.
        COLOR GREY, BLACK
        _PRINTSTRING (LayPX%("log.body") + 16, LayPY%("log.body") + dy * 8), LEFT$(FLOG(i), LayCols%("log.body") - 2)
        dy = dy + 1
    NEXT i
END SUB

' Draw panel outlines when there is no authored frame.ans yet. Purely a scaffold: four 33-col
' columns of dark portrait boxes with no boundary between them read as one band, which makes it
' impossible to tell whether the renderer placed anything correctly. The moment real chrome art
' exists this is skipped entirely (FIGHT_CHROME), so it costs the finished screen nothing.
SUB FightDrawChrome
    DIM a AS INTEGER
    FOR a = 1 TO FIGHT_MAXFOE
        IF LayHas%(FaRgn$(a, "panel")) THEN FightFrame FaRgn$(a, "panel"), BOXBG
    NEXT a
    IF LayHas%("log.panel") THEN FightFrame "log.panel", BOXBG
    IF LayHas%("dice.tray") THEN FightFrame "dice.tray", BOXBG
    IF LayHas%("menu.sub") THEN FightFrame "menu.sub", BOXBG
END SUB

' The action menu + hint line. Labels are whatever the game put in FMENU(); the selected one is
' bracketed AND recoloured, because on a CP437 grid at 8x8 a colour change alone is easy to miss
' against four bright foe panels competing for attention.
SUB FightDrawMenu
    DIM i AS INTEGER, x AS INTEGER, lbl AS STRING, wide AS INTEGER, row AS INTEGER
    IF LEN(_TRIM$(FMENU_HINT)) > 0 THEN FightText "hint.bar", 0, _TRIM$(FMENU_HINT), GREY
    IF FMENU_N < 1 THEN EXIT SUB
    IF LayHas%("menu.root") = 0 THEN EXIT SUB
    wide = LayCols%("menu.root")
    x = 0
    row = 0
    FOR i = 1 TO FMENU_N
        lbl = _TRIM$(FMENU(i))
        IF i = FMENU_SEL THEN lbl = "[" + lbl + "]" ELSE lbl = " " + lbl + " "
        ' WRAP rather than clip. Seven actions total ~49 columns and the region is 34 wide, so a
        ' stop-at-the-edge loop silently DROPPED the last two -- and a menu that hides an action
        ' the player can still select with the arrows is worse than an ugly one. Bounded to
        ' MENU_ROWS so it can never run down over the portrait below.
        IF x + LEN(lbl) > wide THEN
            row = row + 1
            x = 0
            IF row >= MENU_ROWS THEN EXIT FOR          ' genuinely out of room; reported below
        END IF
        IF i = FMENU_SEL THEN
            COLOR YELLOWU, BLACK
        ELSE
            COLOR GREY, BLACK
        END IF
        _PRINTSTRING (LayPX%("menu.root") + x * 8, LayPY%("menu.root") + row * 8), lbl
        x = x + LEN(lbl)
    NEXT i
    ' If the loop ran to completion, i is FMENU_N + 1. Anything less means EXIT FOR fired and there
    ' are actions the player cannot see -- say so on screen rather than leaving them invisible; it
    ' is a layout bug and should look like one. (Do NOT `EXIT FOR` on the last item to "finish
    ' early": that leaves i AT FMENU_N and makes this warning fire on every single draw.)
    IF i <= FMENU_N THEN
        COLOR REDU, BLACK
        _PRINTSTRING (LayPX%("menu.root"), LayPY%("menu.root") + (MENU_ROWS - 1) * 8), "!! " + LTRIM$(STR$(FMENU_N - i + 1)) + " action(s) do not fit"
    END IF
    ' The submenu, one label per row.
    IF FMENU_SUBN < 1 OR LayHas%("menu.sub") = 0 THEN EXIT SUB
    FOR i = 1 TO FMENU_SUBN
        IF i > LayRows%("menu.sub") THEN EXIT FOR
        FightText "menu.sub", i - 1, _TRIM$(FMENU_SUB(i)), GREY
    NEXT i
END SUB

' Bracket the CANVAS target + 8x8 font for a caller that needs to draw its own extras on top of
' FightRender. Pairs with FightEndDraw -- which restores _FONT CH, the thing that must not be
' forgotten (see the FONT TRAP note at the top of this file).
SUB FightBeginDraw
    _DEST CANVAS
    _FONT 8
END SUB

SUB FightEndDraw
    _FONT CH
END SUB

' ============================================================================
'  The INTERACTIVE gesture, on the tactical screen.
'
'  ONE MODEL, TWO PRESENTATIONS. The math is engine/GAUGE.bas -- unit-tested, and shared with
'  the auto-resolve twin GaugeSample% -- so the played gesture and the sampled one can never
'  drift apart. This file only DRAWS it and reads the keyboard.
'
'  (Existing debt, not introduced here: engine/GESTURE.bas's GaugeLock% is a SECOND interactive
'  gauge with its own private math, shipping for SECOND WIND and CRIT FLOURISH. Migrating those
'  onto the GAUGE.bas model would leave one model and two presentations, which is the intent --
'  but it changes the feel of two live features, so it is a deliberate decision rather than a
'  drive-by. Recorded in engine/ENGINE.md.)
'
'  WHY THE FOE FUSES KEEP RUNNING: the gesture is not a modal pause. FuseStep is still called
'  every frame while the bar sweeps, so taking a long careful aim is exactly as expensive as
'  standing in the menu -- a foe can land a blow mid-swing. Freezing the world here would make
'  the gesture strictly better than the plain attack no matter how it was tuned, which is the
'  dominance failure GAUGE.bas's baseline exists to prevent.
'
'  The visual language matches GESTURE.bas so the two read as the same mechanic: dark = miss,
'  green = hit, purple = crit, a pale sweeping marker.
' ============================================================================

' Draw the composure bar into a named region from live GAUGEK state.
' WYSIWYG is sacred: the bands are drawn at EXACTLY k.zc/k.ecrit/k.ehit, because those are the
' same numbers GaugeScore% reads. Drawing them anywhere else would score somewhere the player
' cannot see, which reads as the game cheating.
SUB FightDrawGauge (rgn AS STRING, k AS GAUGEK)
    DIM px AS INTEGER, py AS INTEGER, wide AS INTEGER, high AS INTEGER, mxp AS INTEGER
    IF LayHas%(rgn) = 0 THEN EXIT SUB
    px = LayPX%(rgn): py = LayPY%(rgn): wide = LayPW%(rgn): high = LayPH%(rgn)
    IF wide < 8 OR high < 2 THEN EXIT SUB
    LINE (px, py)-(px + wide - 1, py + high - 1), _RGB32(&H33, &H3B, &H33), BF          ' miss
    LINE (px + INT((k.zc - k.ehit) * wide), py)-(px + INT((k.zc + k.ehit) * wide), py + high - 1), _RGB32(&H2E, &HA0, &H55), BF
    LINE (px + INT((k.zc - k.ecrit) * wide), py)-(px + INT((k.zc + k.ecrit) * wide), py + high - 1), _RGB32(&HA6, &H66, &HCE), BF
    mxp = px + INT(k.p * wide)
    LINE (mxp - 1, py - 2)-(mxp + 1, py + high + 1), _RGB32(&HF0, &HEC, &HD0), BF
    LINE (px, py)-(px + wide - 1, py + high - 1), GREY, B
END SUB

' Run the player's gesture inline on the fight screen.
'
' `depth` narrows the zones, `press` is the crowd squeeze (live foes beyond the first), and
' `secs` is the commit deadline. Returns the zone locked -- 2 crit / 1 hit / 0 miss -- or
' FUSE_NONE if the deadline passed with no commit (a forfeited swing, not a miss).
' `q` comes back as the 0..1 closeness to dead centre.
'
' The caller must pass a callback-free loop body, so this owns the frame loop: it ticks the
' fuses itself via FightGestureTick, which is set up by the game before the call. Foe attacks
' that land mid-gesture are queued and resolved by the caller afterwards.
FUNCTION FightGaugeRun% (k AS GAUGEK, secs AS SINGLE, q AS SINGLE)
    DIM tprev AS DOUBLE, dt AS SINGLE, left AS SINGLE
    DIM kk AS STRING, z AS INTEGER, locked AS INTEGER
    FightGaugeRun% = FUSE_NONE
    q = 0
    GaugeBegin k
    FuseArm 0, secs                          ' slot 0 IS the player: one mechanism for both sides
    tprev = TIMER
    locked = 0
    DO
        _LIMIT 60
        AudioTick
        dt = TIMER - tprev: tprev = TIMER
        IF dt < 0 OR dt > 1 THEN dt = 0      ' TIMER wraps at midnight

        GaugeStep k
        ' The world does NOT pause. Foe fuses advance; anything that fires is left PENDING for
        ' the caller to resolve, so a blow landing mid-swing still costs the player.
        FightGestureFuseTick dt

        left = FuseRemaining!(0)
        IF FF_ARMED(0) = 0 THEN EXIT DO      ' the commit deadline ran out

        FightRender
        FightBeginDraw
        FightDrawGauge "player.gauge", k
        FightText "hint.bar", 0, "SPACE to strike   " + FmtSecs$(left) + " left" + FightSteadyHint$(k), YELLOWU
        FightEndDraw
        _DISPLAY

        kk = INKEY$
        IF kk = " " THEN locked = -1: EXIT DO
        ' Spend willpower to steady the bar -- finite, and it regrows the window.
        IF UCASE$(kk) = "Z" THEN
            IF GaugeSteady%(k) THEN Sfx "select"
        END IF
    LOOP

    FuseDisarm 0
    IF locked = 0 THEN EXIT FUNCTION         ' forfeited: FUSE_NONE, distinct from a miss
    FightGaugeRun% = GaugeScore%(k, q)
END FUNCTION

' The willpower prompt, only shown while there is any to spend.
FUNCTION FightSteadyHint$ (k AS GAUGEK)
    IF k.will > 0 THEN FightSteadyHint$ = "   [Z] steady x" + LTRIM$(STR$(k.will))
END FUNCTION

' Advance the foe fuses during a gesture, leaving completions PENDING for the caller.
' Separate from FuseStep% only so the intent is explicit at the call site: this deliberately
' does NOT consume the result.
SUB FightGestureFuseTick (dt AS SINGLE)
    DIM a AS INTEGER
    a = FuseStep%(dt)
    IF a <> FUSE_NONE THEN FF_PEND(a) = -1   ' put it back; the caller drains the queue
END SUB

' ============================================================================
'  The DODGE -- a one-key directional reflex check when a foe's blow lands.
'
'  greywood used arrow keys guitar-hero style for blocks: a direction chosen at random and a
'  short window to hit it. That is what this is, deliberately kept to ONE arrow: with up to four
'  foes on staggered fuses, a multi-key sequence would fire while the previous one was still
'  being entered. One arrow is readable at speed and stays fair when three land at once.
'
'  It NAMES ITS ATTACKER. Being told to dodge and not knowing who swung is indistinguishable
'  from the game lying, which is why engine/FUSE.bas preserves attacker identity through the
'  pending queue.
' ============================================================================

' Returns TRUE if the player answered with the right arrow inside `secs`.
' `attacker` is the foe slot, used only to name it on screen.
FUNCTION FightDodgeRun% (attacker AS INTEGER, secs AS SINGLE)
    DIM want AS INTEGER, wantk AS STRING, shown AS STRING
    DIM tprev AS DOUBLE, dt AS SINGLE, left AS SINGLE, kk AS STRING, nk AS STRING
    FightDodgeRun% = 0
    want = INT(RND * 4)
    SELECT CASE want
        CASE 0: wantk = "W": shown = "UP"
        CASE 1: wantk = "S": shown = "DOWN"
        CASE 2: wantk = "A": shown = "LEFT"
        CASE ELSE: wantk = "D": shown = "RIGHT"
    END SELECT
    FuseArm 0, secs
    tprev = TIMER
    DO
        _LIMIT 60
        AudioTick
        dt = TIMER - tprev: tprev = TIMER
        IF dt < 0 OR dt > 1 THEN dt = 0
        ' Other foes keep winding up during a dodge too -- the same no-free-pause rule.
        FightGestureFuseTick dt
        left = FuseRemaining!(0)
        IF FF_ARMED(0) = 0 THEN EXIT DO

        FightRender
        FightBeginDraw
        FightBar "player.gauge", left / secs, REDU
        FightText "hint.bar", 0, _TRIM$(FA_NAME(attacker)) + " strikes!  press " + shown + "  (" + FmtSecs$(left) + ")", REDU
        FightEndDraw
        _DISPLAY

        kk = UCASE$(INKEY$)
        IF LEN(kk) > 0 THEN
            nk = NormKey$(kk)
            IF nk = wantk THEN FightDodgeRun% = -1: EXIT DO
            ' A WRONG arrow ends it immediately -- mashing must not beat reading.
            IF nk = "W" OR nk = "S" OR nk = "A" OR nk = "D" THEN EXIT DO
        END IF
    LOOP
    FuseDisarm 0
END FUNCTION

' Blit an image into a box. 1:1 when it already matches the box exactly (an ANSI tile authored at
' the region size), otherwise SCALED TO FIT and centred -- never stretched to fill.
'
' The generators produce SQUARE sprites and the portrait box is 33x25 cells (1.32:1), so a
' stretch-to-fill would visibly distort every pixel-art portrait. Fitting letterboxes instead,
' which is why the manifest asks for a square pixel source rather than a 264x200 one.
SUB FightBlitFit (img AS LONG, px AS INTEGER, py AS INTEGER, pxw AS INTEGER, pxh AS INTEGER)
    DIM iw AS INTEGER, ih AS INTEGER, sc AS SINGLE, dw AS INTEGER, dh AS INTEGER
    IF img >= -1 THEN EXIT SUB
    iw = _WIDTH(img): ih = _HEIGHT(img)
    IF iw < 1 OR ih < 1 THEN EXIT SUB
    IF iw = pxw AND ih = pxh THEN _PUTIMAGE (px, py), img, CANVAS: EXIT SUB
    sc = pxw / iw
    IF pxh / ih < sc THEN sc = pxh / ih
    dw = INT(iw * sc): dh = INT(ih * sc)
    IF dw < 1 THEN dw = 1
    IF dh < 1 THEN dh = 1
    _PUTIMAGE (px + (pxw - dw) \ 2, py + (pxh - dh) \ 2)-STEP(dw - 1, dh - 1), img, CANVAS
END SUB
