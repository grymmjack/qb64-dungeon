$INCLUDEONCE
'' DICE3D_GAME.bas -- glue between the dungeon and the DICE3D module.
'  Loads the player + monster dice sets and rolls them inside a box overlaid on the
'  dungeon's CANVAS (which IS the screen -- SCREEN CANVAS). GameRoll routes here when
'  the active Dice Style is 3D; otherwise the font/pip dice are used. Included at the
'  bottom, after include/DICE3D/_ALL.BM (so the dice3d_* API exists).

' Load the player's and monster's 3D dice sets. Both default to assets/data/diceset.txt
' (the purple/green crystal set); a separate assets/data/diceset-monster.txt overrides
' the monster set if present. dice3d_ready gates 3D -- a missing/bad set falls back to
' the font dice so the game never breaks.
' Load the dice-numeral fonts listed in assets/fonts/dicefonts.txt (name | file | size).
' Entry 1 is always a built-in "Default" (handle 0). Others _LOADFONT their file.
SUB LoadDiceFonts
    DIM i AS INTEGER, fn AS STRING, px AS INTEGER
    DICEFONT_N = 0
    ReadDataFile AssetPath$("fonts", "dicefonts.txt")
    FOR i = 1 TO DLINE_N
        IF DICEFONT_N < UBOUND(DICEFONT_NAME) THEN
            DICEFONT_N = DICEFONT_N + 1
            DICEFONT_NAME(DICEFONT_N) = DField$(DLINE(i), 1)
            fn = DField$(DLINE(i), 2): px = VAL(DField$(DLINE(i), 3))
            DICEFONT_PX(DICEFONT_N) = px
            DICEFONT_H(DICEFONT_N) = 0
            IF fn <> "-" AND px > 0 THEN
                IF _FILEEXISTS(AssetPath$("fonts", fn)) THEN DICEFONT_H(DICEFONT_N) = _LOADFONT(AssetPath$("fonts", fn), px)
            END IF
        END IF
    NEXT i
    IF DICEFONT_N = 0 THEN
        DICEFONT_N = 1: DICEFONT_NAME(1) = "Default": DICEFONT_H(1) = 0: DICEFONT_PX(1) = 0
    END IF
    IF opt_dicefont < 1 OR opt_dicefont > DICEFONT_N THEN opt_dicefont = 1
END SUB

' Apply the selected numeral font (handle + size) to a config before its atlas is baked.
SUB SetDiceFont (cfg AS DICE3D_CONFIG)
    IF opt_dicefont >= 1 AND opt_dicefont <= DICEFONT_N THEN
        cfg.FONT_HANDLE = DICEFONT_H(opt_dicefont)
        IF DICEFONT_PX(opt_dicefont) > 0 THEN cfg.FONT_PX = DICEFONT_PX(opt_dicefont)
    END IF
END SUB

' Override a config's directional light from the SETTINGS "Dice Light" level (opt_dicelight).
' The light DIRECTION comes from the set/default (already seeded); this only sets the on/off
' + strength, so the player can tune shading in-game without editing set files.
SUB ApplyDiceLight (cfg AS DICE3D_CONFIG)
    SELECT CASE opt_dicelight
        CASE 0: cfg.LIGHT_ENABLED = 0                                          ' flat (no shading)
        CASE 1: cfg.LIGHT_ENABLED = -1: cfg.LIGHT_AMBIENT = 0.62: cfg.LIGHT_INTENSITY = 0.5 ' soft
        CASE 3: cfg.LIGHT_ENABLED = -1: cfg.LIGHT_AMBIENT = 0.38: cfg.LIGHT_INTENSITY = 1.0 ' strong
        CASE ELSE: cfg.LIGHT_ENABLED = -1: cfg.LIGHT_AMBIENT = 0.5: cfg.LIGHT_INTENSITY = 0.8 ' normal
    END SELECT
END SUB

' Read the dice-set manifest (assets/data/dicesets.txt): each line "display name | file".
SUB LoadDiceManifest
    DIM i AS INTEGER
    DSET_COUNT = 0
    ReadDataFile AssetPath$("data", "dicesets.txt")
    FOR i = 1 TO DLINE_N
        IF DSET_COUNT < UBOUND(DSET_NAME) THEN
            DSET_COUNT = DSET_COUNT + 1
            DSET_NAME(DSET_COUNT) = DField$(DLINE(i), 1)
            DSET_FILE(DSET_COUNT) = DField$(DLINE(i), 2)
        END IF
    NEXT i
END SUB

' Load the player's and monster's chosen 3D dice sets (by manifest index). Falls back to
' the single legacy assets/data/diceset.txt if the manifest is empty. dice3d_ready gates
' 3D -- a missing/bad set means the game quietly uses the font dice instead.
SUB LoadDiceSets
    DIM ok AS INTEGER
    LoadDiceManifest
    dice3d_ready = FALSE
    IF DSET_COUNT <= 0 THEN
        ok = dice3d_set_load%(DSET3D(), DataPath$(AssetPath$("data", "diceset.txt")))
        IF ok THEN dice3d_ready = -1: ok = dice3d_set_load%(MSET3D(), DataPath$(AssetPath$("data", "diceset.txt")))
        EXIT SUB
    END IF
    IF opt_dice3d_set < 1 OR opt_dice3d_set > DSET_COUNT THEN opt_dice3d_set = 1
    IF opt_mon_dice3d_set < 1 OR opt_mon_dice3d_set > DSET_COUNT THEN opt_mon_dice3d_set = 1
    ok = dice3d_set_load%(DSET3D(), DataPath$(AssetPath$("data", "dicesets/") + _TRIM$(DSET_FILE(opt_dice3d_set))))
    IF ok THEN dice3d_ready = -1
    ok = dice3d_set_load%(MSET3D(), DataPath$(AssetPath$("data", "dicesets/") + _TRIM$(DSET_FILE(opt_mon_dice3d_set))))
END SUB

' Roll n dice of `sides` sides as animated 3D dice and return the raw sum (no bonus --
' GameRoll adds that, matching the font/pip paths). `what` is the caption. Picks the
' monster set when dice3d_use_mon is set (Push/PopMonsterDice), else the player set.
CONST DICE3D_SS = 2          ' (settings preview only) supersample the static preview image

' GL projection calibration for a 1056x816 CANVAS at view depth Z (from x11grab tests):
' 1 model unit ~= 103 screen px at Z=-5, so 1 box-pixel ~= 1/103 GPU units. HW_S is derived
' from DIE_SIZE so a die renders at exactly its physics footprint.
CONST DICE3D_HW_ZBASE = -5.0
CONST DICE3D_HW_PXPERUNIT = 103.0
' How far the INVISIBLE physics box sits inside the drawn tray, in WINDOW pixels per side.
' Purely feel: bigger keeps the dice further from the painted border.
CONST DICE3D_BOX_INSET = 50
' EXTRA inset on the BOTTOM edge only. The running total is printed in its own lane immediately
' under the tray, and a die is drawn centred on its physics position -- so one resting on the box
' floor still extends below it and clipped the top of that text. Raising the floor keeps the dice
' clear of the lane without shrinking the tray they are drawn in. Window pixels, like the inset
' above, so it means the same amount of screen at any scale.
CONST DICE3D_BOX_INSET_BOT = 32

' droplow > 0 rolls N dice but keeps the top (N - droplow) -- e.g. Show3DRoll(4,6,0,1,..)
' is the classic 4d6-drop-lowest ability roll. The DICE3D module owns the mechanic: we
' just build the "4d6dl1" notation, and it animates all four, fades the lowest, and
' totals the kept three (dice3d_total%). droplow = 0 is an ordinary NdS roll.
' CANVAS pixels -> GL units, for the hardware layer.
'
' The GL layer addresses the WHOLE WINDOW, while the canvas is drawn into a centred, scaled
' sub-rect of it (letterboxed: a 1056x816 canvas is 1.29 aspect, a 16:9 display is 1.78, so
' there are bars either side). Treating the canvas centre as the window centre therefore puts
' everything off by the letterbox offset -- which is why the dice sat left of their labels.
'
' DICE3D_HW_PXPERUNIT is "px per model unit" calibrated at a 1056-wide window, and the
' projection is window-relative, so the real px-per-unit is PXPERUNIT * winW / (SW*CW).
FUNCTION GlUnitsPerCanvasPx! ()
    DIM ww AS LONG
    ww = _WIDTH(0)
    IF ww <= 0 OR pres_dw <= 0 THEN GlUnitsPerCanvasPx! = 1! / DICE3D_HW_PXPERUNIT: EXIT FUNCTION
    GlUnitsPerCanvasPx! = pres_dw / (DICE3D_HW_PXPERUNIT * ww)
END FUNCTION

' GL offset of a CANVAS x (or y), measured from the WINDOW centre, in model units.
FUNCTION GlX! (cx AS SINGLE)
    DIM ww AS LONG
    ww = _WIDTH(0)
    IF ww <= 0 OR pres_dw <= 0 THEN GlX! = (cx - SW * CW * 0.5) / DICE3D_HW_PXPERUNIT: EXIT FUNCTION
    GlX! = (pres_ox + cx * pres_scale - ww * 0.5) / (DICE3D_HW_PXPERUNIT * ww / (SW * CW))
END FUNCTION

FUNCTION GlY! (cy AS SINGLE)
    DIM wh AS LONG, ww AS LONG
    ww = _WIDTH(0): wh = _HEIGHT(0)
    IF ww <= 0 OR pres_dh <= 0 THEN GlY! = -(cy - SH * CH * 0.5) / DICE3D_HW_PXPERUNIT: EXIT FUNCTION
    GlY! = -(pres_oy + cy * pres_scale - wh * 0.5) / (DICE3D_HW_PXPERUNIT * ww / (SW * CW))
END FUNCTION

' Relative size of each die within a matched set. 1.0 is the baseline (triangular faces --
' d4/d8/d20 already agree with each other); the broader-faced solids come down to match.
FUNCTION DieSetScale! (sides AS INTEGER)
    SELECT CASE sides
        CASE 12: DieSetScale! = 0.90     ' pentagons fill the sphere hardest -- it out-bulked the d20
        CASE 10: DieSetScale! = 0.96     ' kites, between a pentagon and a triangle
        CASE 6: DieSetScale! = 0.94      ' squares
        CASE ELSE: DieSetScale! = 1!     ' triangular faces: the baseline
    END SELECT
END FUNCTION

FUNCTION Show3DRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, droplow AS INTEGER, what AS STRING)
    DIM cfg AS DICE3D_CONFIG, idx AS INTEGER, notation AS STRING, hdr AS STRING
    DIM AS INTEGER tw, th, tx, ty, hf, hbw, hbx
    DIM pxk AS SINGLE
    REDIM r(1 TO 1) AS INTEGER

    idx = dice3d_set_index%(sides): IF idx < 0 THEN idx = 0
    IF dice3d_use_mon THEN cfg = MSET3D(idx) ELSE cfg = DSET3D(idx)
    ApplyDiceLight cfg                              ' SETTINGS "Dice Light" overrides the set's LIGHT_*
    cfg.BEVEL = opt_diceround / 10                  ' SETTINGS "Dice Round" drives the edge roundness

    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF

    ' The tray (a software box on CANVAS) -- the 3D dice render on the GL layer over it.
    ' Roomy tray with its own wider caption header above; a royal-purple "dice box".
    DIM boxviolet AS _UNSIGNED LONG, boxedge AS _UNSIGNED LONG
    boxviolet = Thm~&("dice.tray.bg", _RGB32(&H34, &H22, &H7A))   ' plush violet-blue royal purple
    boxedge = Thm~&("dice.tray.edge", _RGB32(&H8A, &H6C, &HF2))   ' lighter violet border
    ' Die radius in box/screen px, SHAPE-CORRECTED.
    '
    ' Every mesh is built at unit circumradius, so a flat 28 makes them all the same SPHERE --
    ' not the same die. A dodecahedron's broad pentagons fill far more of that sphere than an
    ' icosahedron's narrow triangles, so at equal radius the d12 reads BIGGER than the d20,
    ' which no physical set does. The same correction the Blender set-render needed.
    '
    ' Applied per die type so a d12 roll and a d20 roll look like pieces from one set.
    cfg.DIE_SIZE = 28 * DieSetScale!(sides)
    ' A lively roll, not a frantic one and not a dead drop: 30 (module default) felt
    ' frantic, 7 barely tumbled ("just drops and bounces once"). ~15 spin + a real
    ' horizontal throw makes the dice skitter and wall-bounce like a genuine roll.
    cfg.SPIN_STRENGTH = 15                          ' tumble speed (deg/frame magnitude)
    cfg.THROW_STRENGTH = 13                         ' scatter velocity -- skitter across the tray
    cfg.RESTITUTION = 0.62                          ' a couple extra bounces before settling (0.55 default)
    tw = 150 + n * 84
    IF tw > SW * CW - 40 THEN tw = SW * CW - 40
    ' SNAPPED TO A WHOLE NUMBER OF TEXT ROWS. The running total is printed in a lane below the
    ' tray, and that lane can only start on a row boundary -- rrow = (ty + th) \ CH rounds DOWN.
    ' With an arbitrary height the tray therefore ended a few pixels INSIDE its own total lane and
    ' painted over the top of the text: at the character-generation offset, exactly 4px, which is
    ' the sliver taken off the top of every digit. Snapping th down to a multiple of CH makes the
    ' tray's bottom edge and the lane's top edge the same line.
    th = 132
    th = (th \ CH) * CH
    tx = (SW * CW - tw) \ 2
    ty = (12 + DICE3D_YOFF) * CH                    ' DICE3D_YOFF shifts the whole tray down (char-gen clears the stat sheet)
    ' PHYSICS BOX, inset from the DRAWN tray. The dice bounce off the box; the tray is only a
    ' picture. Insetting the box keeps the dice off the painted edge -- they used to settle
    ' half-over the border because the two were the same rectangle.
    '
    ' The inset is given in WINDOW pixels because that is what you actually see, and converted to
    ' canvas pixels here: at fullscreen the canvas is scaled up, so a fixed canvas inset would
    ' look bigger the larger the window got.
    '
    ' Floored so the box can never collapse: it must stay wide enough for the dice to have
    ' somewhere to go, or they pile up in the middle with nothing to bounce off.
    DIM inset AS INTEGER, botinset AS INTEGER, minw AS INTEGER, minh AS INTEGER
    inset = DICE3D_BOX_INSET / PresentScale!
    ' The floor has to clear the running-total lane by the DIE'S OWN HEIGHT, not by a flat number.
    ' A die is drawn centred on its physics position, so one resting on the floor extends roughly a
    ' collision radius BELOW it -- and the lane is printed immediately under the tray. A fixed 32px
    ' was simply less than a die is tall, so the dice still crossed into the text. Taking the die
    ' size into account means the clearance holds for any die size or window scale.
    ' via the accessor, not DICE3D_RADIUS_K -- that CONST lives in _PHYSICS.BM, which the roll-up
    ' includes AFTER this file, so naming it here is 'Variable not defined'. A FUNCTION resolves
    ' globally whatever the include order.
    botinset = dice3d_radius!(cfg) + DICE3D_BOX_INSET_BOT / PresentScale!
    minw = cfg.DIE_SIZE * 4: minh = cfg.DIE_SIZE * 3
    cfg.BOX_W = tw - inset * 2: IF cfg.BOX_W < minw THEN cfg.BOX_W = minw
    cfg.BOX_H = th - inset * 2 - botinset: IF cfg.BOX_H < minh THEN cfg.BOX_H = minh
    ' WHERE the box sits. The hardware path ignores these -- it places dice in GL space via
    ' DICE3D_HW_CX/CY -- so they were simply never set here, and the SOFTWARE renderer (which
    ' blits its box buffer to BOX_X/BOX_Y) drew the dice at a stale rect, nowhere near the tray.
    ' Invisible in play, since play is always hardware; `rollshot` is what made it visible.
    cfg.BOX_X = tx + inset
    ' ANCHOR THE BOX TO THE TRAY'S BOTTOM, not its top. The minimum-height clamp above regularly
    ' wins -- minh is 3 x DIE_SIZE (84px) against a 132px tray, so at most window scales the
    ' requested height is already below it -- and with the box hung from the TOP that clamp put
    ' the floor at or past the tray's bottom edge. Dice resting on it then spilled into the
    ' running-total lane printed underneath, and the bottom inset intended to prevent exactly
    ' that was silently given straight back. Hanging the box from the bottom instead means the
    ' floor is botinset above the tray edge whatever the clamp decides.
    cfg.BOX_Y = ty + th - botinset - cfg.BOX_H
    IF cfg.BOX_Y < ty THEN cfg.BOX_Y = ty          ' never above the tray itself
    ' What the dice can reach vs where the total is printed -- see roll_floor_y in ENGINE.BI.
    roll_floor_y = cfg.BOX_Y + cfg.BOX_H + dice3d_radius!(cfg)
    roll_sum_y = ((ty + th) \ CH) * CH
    roll_tray_bot = ty + th
    hbw = (LEN(hdr) + 4) * CW                      ' header box: caption width, its own
    IF hbw < tw THEN hbw = tw
    IF hbw > SW * CW - 20 THEN hbw = SW * CW - 20
    hbx = (SW * CW - hbw) \ 2

    ' Hardware (OpenGL) present: native-resolution, hardware-filtered = genuinely smooth,
    ' independent of the software-canvas fullscreen scaling.
    ' NOT scaled by PresentScale!. Tried that; the dice came out enormous.
    '
    ' The GL projection is already WINDOW-RELATIVE -- a model unit covers a fixed fraction of the
    ' window, so it grows with the window on its own. Multiplying by the present scale on top of
    ' that scales everything twice, and at 3840x2160 (scale 2.65) the d20s filled the corners of
    ' the screen. DICE3D_HW_PXPERUNIT already carries the whole conversion.
    pxk = GlUnitsPerCanvasPx!                       ' canvas px -> GL units, letterbox-aware
    IF dice3d_force_soft THEN DICE3D_HW = 0 ELSE DICE3D_HW = -1   ' dev: rollshot needs the capturable software path
    DICE3D_HWATLAS = 0
    DICE3D_HW_Z = DICE3D_HW_ZBASE
    DICE3D_HW_PXK = pxk
    DICE3D_HW_S = cfg.DIE_SIZE * pxk               ' render the die at its physics footprint
    DICE3D_HW_CX = GlX!(SW * CW * 0.5)             ' tray centred horizontally on the CANVAS
    ' Centre the GL dice on the PHYSICS BOX, not the tray. The two were identical while the box
    ' was inset evenly, so this read as "the tray row" and worked -- but the bottom inset moves
    ' the box centre up, and anchoring to the tray would leave the hardware dice sitting lower
    ' than the floor they are actually bouncing on.
    DICE3D_HW_CY = GlY!(cfg.BOX_Y + cfg.BOX_H * 0.5)
    DICE3D_UPRIGHT = -1                            ' show each die's result upright + readable

    ' Sound: a throw rattle now, then per-bounce BEEPS + a settle BOOP straight from the
    ' physics (tone fallback via DICE3D_SND_VOL) -- or real per-bounce clacks + settle thud
    ' if you drop assets/sfx/dice_edge.* / dice_settle.* files in.
    ' audio_muted, not just opt_sfx. The DICE3D physics emits its per-bounce clicks with a RAW
    ' `SOUND` statement (engine/DICE3D/_PHYSICS.BM), which never passes through Tone and so never
    ' sees the mute -- so every headless dev mode that rolls dice (rollshot, and anything reaching
    ' AnimatedRoll) blipped the PC speaker at whoever ran the gate. Muting has to happen HERE, at
    ' the layer that owns the setting; the vendored module only knows the flag it is handed.
    cfg.SOUND_ENABLED = opt_sfx AND NOT audio_muted
    cfg.SND_EDGE_H = SfxHandle("dice_edge")
    cfg.SND_SETTLE_H = SfxHandle("dice_settle")
    IF cfg.SOUND_ENABLED THEN DICE3D_SND_VOL = opt_sfxvol / 10 ELSE DICE3D_SND_VOL = 0
    DICE3D_ATLAS_DIE = 96                           ' bake a hi-res atlas so the numerals stay sharp
    SetDiceFont cfg                                 ' apply the chosen dice numeral font

    ' PHOTOGRAPH THE SCREEN FIRST. The roll draws a tray over whatever is up and has to take it
    ' away again afterwards -- and it used to do that by repainting the BOARD (cursor_erase /
    ' cursor_draw), which assumes a board is what is underneath. It is not, during character
    ' creation: the cleanup painted the dungeon's room labels and the play HUD straight over the
    ' creator, which is the "decoration layer flashes while rolling" report. Auto-roll made it
    ' constant, because each stat's roll cleaned up into the next one's box.
    '
    ' Restoring the actual pixels is both simpler and screen-agnostic -- the same argument as the
    ' dev console's snapshot. It also subsumes what cursor_draw was for: the player token is
    ' already in the photograph.
    ' In a ROLL SEQUENCE the snapshot is taken once and held by RollSeqEnd, so the tray survives
    ' between passes instead of being wiped and rebuilt (see rollseq_on). rollsnap stays 0 then,
    ' which is what tells the tail below to leave the tray standing.
    DIM rollsnap AS LONG
    IF rollseq_on THEN
        IF rollseq_snap = 0 THEN rollseq_snap = _COPYIMAGE(CANVAS, 32)
    ELSE
        rollsnap = _COPYIMAGE(CANVAS, 32)
    END IF

    ' Draw the framed royal-purple header (caption-width) + the roomy tray on CANVAS (crisp).
    _DEST CANVAS: _FONT CH
    LINE (hbx, (9 + DICE3D_YOFF) * CH)-(hbx + hbw, (12 + DICE3D_YOFF) * CH), boxviolet, BF
    LINE (hbx, (9 + DICE3D_YOFF) * CH)-(hbx + hbw, (12 + DICE3D_YOFF) * CH), boxedge, B
    LINE (tx, ty)-(tx + tw, ty + th), boxviolet, BF
    LINE (tx, ty)-(tx + tw, ty + th), boxedge, B
    COLOR YELLOWU, boxviolet: PrintCentered 10 + DICE3D_YOFF, hdr
    Present

    Sfx "diceroll"                                  ' AFTER any shake -- the rattle is the throw

    notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    IF droplow > 0 THEN notation = notation + "dl" + _TRIM$(STR$(droplow))   ' e.g. 4d6dl1
    ' HELD DICE (see ROLLHOLD in ENGINE.BI): pass the pins through so a partial re-roll leaves the
    ' kept dice lying where they are instead of clearing the tray. The module ignores a hold whose
    ' index the PREVIOUS roll had no die for, so this is safe to set unconditionally.
    DIM hi2 AS INTEGER
    dice3d_hold_clear
    IF ROLLHOLD_ON THEN
        FOR hi2 = 1 TO n
            IF RollHeld%(hi2) > 0 THEN dice3d_hold hi2, RollHeld%(hi2)
        NEXT hi2
    END IF
    dice3d_roll notation, cfg, r()                 ' animates on the GL layer, returns settled
    IF SfxHandle("dice_settle") = 0 THEN Sfx "diceland"

    ' Reveal the sum one beat at a time -- like the 2D font dice: each kept die appears
    ' in turn ("3 ... + 3 ... + 2"), then the bonus, then "= total", a rising tick per
    ' beat and a brighter ding on the total. This can't reuse RevealMath: the GL dice
    ' must be re-rendered EVERY frame (the hardware layer clears on each Present).
    DIM ri AS INTEGER, rrow AS INTEGER, dropstr AS STRING, kept AS INTEGER
    DIM keptv(1 TO 8) AS INTEGER
    DIM beat(1 TO 16) AS STRING, nb AS INTEGER, acc AS STRING, tail AS STRING
    DIM bi AS INTEGER, j AS INTEGER, skip AS INTEGER, natd20 AS INTEGER
    ' The vendored DICE3D module reads a d10 as 0..9 (percentile convention -- see
    ' _GEO.BM). The GAME uses the d10 as a 1..10 die (hit points etc.), so its "0"
    ' face means 10. Remap value + running sum here, matching the 2D font dice (which
    ' roll 1..10 and simply DRAW 10 as "0"). sum3d is the dice-only total after remap.
    DIM sum3d AS INTEGER, d10val AS INTEGER
    dropstr = "": kept = 0: sum3d = 0
    FOR ri = 1 TO dice3d_count%
        d10val = dice3d_value%(ri)
        IF sides = 10 AND d10val = 0 THEN d10val = 10
        IF dice3d_dropped%(ri) THEN                  ' a 4d6-drop-lowest die that didn't count
            IF LEN(dropstr) > 0 THEN dropstr = dropstr + " "
            dropstr = dropstr + _TRIM$(STR$(d10val))
        ELSE
            kept = kept + 1
            IF kept <= 8 THEN keptv(kept) = d10val
            sum3d = sum3d + d10val
        END IF
    NEXT
    ' Per-die faces, for callers that need the dice APART rather than summed (see DIE_FACE).
    ' The KEPT dice, in roll order -- a dropped die is not one of the results.
    PublishFaces keptv(), kept
    tail = "": IF LEN(dropstr) > 0 THEN tail = "   (drop " + dropstr + ")"

    ' Each beat is an accumulated snapshot of the running sum. But on a single d20
    ' showing 1 or 20 the math is moot (nat-1 = fumble, nat-20 = crit, whatever the
    ' modifier) -- show the face at once and skip the reveal, exactly like the 2D dice.
    natd20 = (sides = 20 AND n = 1 AND (sum3d = 1 OR sum3d = 20))
    nb = 0: acc = ""
    IF (kept <= 1 AND bonus = 0) OR natd20 THEN
        IF kept >= 1 THEN acc = "=  " + _TRIM$(STR$(keptv(1))) + "  ="   ' lone die / nat 1 or 20 -- the face says it all
        nb = 1: beat(1) = acc + tail
    ELSE
        FOR ri = 1 TO kept
            IF ri = 1 THEN acc = _TRIM$(STR$(keptv(ri))) ELSE acc = acc + "  +  " + _TRIM$(STR$(keptv(ri)))
            nb = nb + 1: beat(nb) = acc
        NEXT
        IF bonus > 0 THEN acc = acc + "  +  " + _TRIM$(STR$(bonus)): nb = nb + 1: beat(nb) = acc
        IF bonus < 0 THEN acc = acc + "  -  " + _TRIM$(STR$(-bonus)): nb = nb + 1: beat(nb) = acc
        acc = acc + "  =  " + _TRIM$(STR$(sum3d + bonus)): nb = nb + 1: beat(nb) = acc + tail
    END IF

    rrow = (ty + th) \ CH
    _DEST CANVAS: _FONT CH
    ' THREE rows, with the text on the MIDDLE one. At two rows the total was printed on the lane's
    ' FIRST row -- directly beneath the border drawn along its top edge, so the line sat on the
    ' digits with a blank row going to waste underneath. One clear row above and below instead.
    LINE (tx, rrow * CH)-(tx + tw, (rrow + 3) * CH), boxviolet, BF
    LINE (tx, rrow * CH)-(tx + tw, (rrow + 3) * CH), boxedge, B

    skip = FALSE
    _KEYCLEAR
    FOR bi = 1 TO nb
        _DEST CANVAS: _FONT CH
        LINE (tx + CW, rrow * CH)-(tx + tw - CW, (rrow + 3) * CH), boxviolet, BF   ' clear row (text re-centres each beat)
        COLOR WHITE, boxviolet: PrintCentered rrow + 1, beat(bi)
        dice3d_repost cfg
        IF opt_sfx THEN
            IF bi = nb THEN SfxOr "dice-math-2", 1100, 0.15 ELSE SfxOr "dice-math-1", 440 + bi * 120, 0.06  ' summing: ticks then total
        END IF
        IF NOT skip THEN
            FOR j = 1 TO 18                                                       ' ~0.3s of suspense per beat
                _LIMIT 60
                dice3d_repost cfg
                IF INKEY$ <> "" THEN skip = -1: EXIT FOR
            NEXT j
        END IF
    NEXT bi

    ' Hold on the fully-revealed result (still re-rendering the GL dice each frame).
    _KEYCLEAR
    FOR hf = 1 TO 70
        _LIMIT 60
        dice3d_repost cfg
        IF INKEY$ <> "" THEN EXIT FOR
    NEXT hf
    _KEYCLEAR

    RollShotSave                                    ' dev: capture the settled frame (rollshot)
    IF DICE3D_HWATLAS <> 0 THEN _FREEIMAGE DICE3D_HWATLAS: DICE3D_HWATLAS = 0
    DICE3D_HW = 0
    IF rollsnap <> 0 THEN                           ' put back EXACTLY what the tray covered
        _PUTIMAGE , rollsnap, CANVAS                ' (a sequence keeps its tray until RollSeqEnd)
        _FREEIMAGE rollsnap
    END IF
    ' NOTE: on its OWN line. `Game_RenderHUD: Present` parses the name as a LABEL, not a
    ' call, whenever that SUB is not defined -- it compiles clean and silently does nothing.
    Game_RenderHUD                                   ' game hook #5: refresh the live HUD readouts
    Present                                         ' (gold/HP/steps may have changed during the roll)
    Show3DRoll = sum3d
END FUNCTION


' -- SETTINGS preview: the SAME hardware (OpenGL) render as a roll, drawn live each frame --

' (Re)build the d20 mesh, a hardware atlas per side, and a posed die (showing 20 upright).
' PREV3D_P / PREV3D_M now hold HARDWARE atlas handles (not preview images).
SUB Build3DPreviews
    DIM pc AS DICE3D_CONFIG, a AS LONG, f AS INTEGER
    Free3DPreviews
    IF NOT dice3d_ready THEN EXIT SUB
    pc = DSET3D(dice3d_set_index%(20)): pc.DIE_SIZE = 96: SetDiceFont pc
    pc.BEVEL = opt_diceround / 10    ' SETTINGS "Dice Round" drives the preview roundness
    DICE3D_BEVEL = pc.BEVEL * 0.18   ' geometric edge-round for the preview d20
    dice3d_build 20
    a = dice3d_make_atlas&(pc, pc.BODY_KOLOR, 0): PREV3D_P = _COPYIMAGE(a, 33): _FREEIMAGE a
    pc = MSET3D(dice3d_set_index%(20)): pc.DIE_SIZE = 96: SetDiceFont pc
    a = dice3d_make_atlas&(pc, pc.BODY_KOLOR, 0): PREV3D_M = _COPYIMAGE(a, 33): _FREEIMAGE a
    REDIM DICE3D_DICE(0 TO 0) AS DICE3D_DIE
    DICE3D_DICE(0).SIDES = 20: DICE3D_DICE(0).FADE = 1: DICE3D_DICE(0).VALUE = 20
    f = DICE3D_VAL2FACE(20): IF f >= 0 AND f < DICE3D_NF THEN DICE3D_DICE(0).Q = DICE3D_FACE_Q(f)
END SUB

SUB Free3DPreviews
    IF PREV3D_P <> 0 THEN _FREEIMAGE PREV3D_P: PREV3D_P = 0
    IF PREV3D_M <> 0 THEN _FREEIMAGE PREV3D_M: PREV3D_M = 0
END SUB

' Render the cached posed d20 via the hardware path at settings column gxc, using the
' side's hardware atlas + its set cfg (for the camera angle). Called each settings frame,
' so the preview looks exactly like the smooth roll. DICE3D_HW is left off (we call the
' hardware renderer directly, without the software-present branch).
' `ccol` is the CENTRE column of the preview, not its left edge.
'
' That change is the fix, not a tidy-up. The 3D dice draw on the hardware GL layer, whose
' position is set as an OFFSET FROM SCREEN CENTRE (DICE3D_HW_CX), converted with a constant
' calibrated for a 1056x816 canvas. The software canvas is then SCALED into whatever window the
' player has -- but the GL layer is not scaled the same way, so the offset drifts, and the drift
' is PROPORTIONAL TO THE DISTANCE FROM CENTRE. A preview parked at the far left (its caption at
' column 4) drifted right off the screen.
'
' So: give the caller a centre to aim at, and place the two previews symmetrically and CLOSE to
' the middle. Near the centre the drift is small; symmetric means whatever is left of it is the
' same for both. Smaller dice, too -- 30px rather than 42 -- so the pair fits in the strip.
' THE CAPTION ONLY -- goes on the CANVAS, so it must be drawn in the canvas pass.
SUB DrawDice3DPreviewLabel (ccol AS INTEGER, lbl AS STRING, growy AS INTEGER)
    DIM gx AS INTEGER
    gx = ccol * CW - (LEN(lbl) * CW) \ 2
    IF gx < 0 THEN gx = 0
    _DEST CANVAS: _FONT CH
    COLOR GREY, BLACK: _PRINTSTRING (gx, (growy - 3) * CH), lbl
END SUB

' THE DIE ONLY -- goes on the GL layer, i.e. straight to the WINDOW.
'
' It must therefore be drawn AFTER the canvas has been put on screen and BEFORE the flip, or
' the present blits the canvas straight over it. That is why this is split from its caption:
' the two halves belong to different passes. Drawn in one call, the previews were invisible --
' the dice were rendered and then immediately painted over.
SUB DrawDice3DPreviewDie (ccol AS INTEGER, growy AS INTEGER, atlas AS LONG, setcfg AS DICE3D_CONFIG)
    DIM AS INTEGER gy, scx, scy
    DIM cfg AS DICE3D_CONFIG, pxk AS SINGLE
    gy = growy * CH
    scx = ccol * CW: scy = gy + 46                  ' screen centre of this preview
    IF atlas = 0 THEN EXIT SUB
    IF UBOUND(DICE3D_DICE) < LBOUND(DICE3D_DICE) THEN EXIT SUB
    cfg = setcfg
    ApplyDiceLight cfg                              ' preview reflects the SETTINGS "Dice Light" level
    cfg.BOX_W = 110: cfg.BOX_H = 110: cfg.DIE_SIZE = 30
    pxk = GlUnitsPerCanvasPx!
    DICE3D_HWATLAS = atlas
    DICE3D_HW_Z = DICE3D_HW_ZBASE: DICE3D_HW_PXK = pxk
    DICE3D_HW_S = cfg.DIE_SIZE * pxk
    DICE3D_HW_CX = GlX!(scx)
    DICE3D_HW_CY = GlY!(scy)
    DICE3D_DICE(0).PX = cfg.BOX_W * 0.5: DICE3D_DICE(0).PY = cfg.BOX_H * 0.5: DICE3D_DICE(0).PZ = 0
    dice3d_render_die_hw DICE3D_DICE(0), cfg
END SUB


' Re-present the dice during Show3DRoll's SUM REVEAL -- i.e. after dice3d_roll has returned.
'
' The hardware path must redraw every frame: its triangles go straight to the window, so anything
' not re-issued vanishes on the next flip. The SOFTWARE path is the opposite -- it composited the
' settled dice INTO the canvas, where they persist, and re-presenting would read the per-die atlas
' and box buffer that dice3d_roll already freed (Invalid handle, _RENDER.BM's _MAPTRIANGLE).
'
' So: redraw on hardware, leave the canvas alone on software. Only `rollshot` takes the software
' branch here, but the asymmetry is a property of the two renderers, not of the dev mode.
SUB dice3d_repost (cfg AS DICE3D_CONFIG)
    IF dice3d_force_soft THEN EXIT SUB
    dice3d_present cfg
END SUB
