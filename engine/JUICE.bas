' ============================================================================
'  JUICE.bas -- optional combat "juice" (SETTINGS "Screen Effects", default ON).
'
'  * ImpactFX -- a screen SHAKE with a colour wash + a spray of splatters, fired
'    when a big blow lands (dealt OR taken). Blood (red), poison (green), fire
'    (orange). Snapshots the live CANVAS into FX_BUF, then blits it back jittered
'    for a few frames -- the same trick Greywood's HitReact uses.
'  * DrawWounds -- a persistent near-death overlay: a soft dark VIGNETTE that
'    closes in from the edges (and PULSES near death) plus dried BLOOD grime
'    spattered round the frame, both intensifying as HP drops.
'  * DrawPoison -- a persistent POISON overlay at a given intensity (0..1): sickly-green
'    veins/branches creeping in from the rim (pre-baked once, like the blood grime),
'    slime pools, and ooze drips, throbbing with a slow queasy pulse.
'
'  All gated by opt_juice. Snapshot/vignette/poison read the screen surface, so
'  nothing changes when the toggle is off.
' ============================================================================

' Fill a solid disc (a blood/poison blob) at (cx,cy).
SUB FillDisc (cx AS INTEGER, cy AS INTEGER, r AS INTEGER, col AS _UNSIGNED LONG)
    DIM y AS INTEGER, dx AS INTEGER
    IF r < 1 THEN r = 1
    FOR y = -r TO r
        dx = INT(SQR(r * r - y * y))
        LINE (cx - dx, cy + y)-(cx + dx, cy + y), col, BF
    NEXT
END SUB

' A splatter: a main blob + a scatter of droplets (impact spray only -- uses RND,
' so never call it for the persistent grime or the droplets would flicker).
SUB SplatBlob (cx AS INTEGER, cy AS INTEGER, r AS INTEGER, col AS _UNSIGNED LONG)
    DIM j AS INTEGER, ox AS INTEGER, oy AS INTEGER
    FillDisc cx, cy, r, col
    FOR j = 1 TO 4
        ox = cx + INT((RND * 2 - 1) * r * 2.4)
        oy = cy + INT((RND * 2 - 1) * r * 2.4)
        FillDisc ox, oy, INT(RND * (r * 0.5)) + 1, col
    NEXT
END SUB

' Seed the fixed blood-grime pattern (biased to the frame's rim) + the shake buffer.
SUB InitJuice
    DIM i AS INTEGER, edge AS INTEGER
    FX_BUF = _NEWIMAGE(SW * CW, SH * CH, 32)
    InitVignette
    FOR i = 1 TO NBLOOD
        edge = INT(RND * 4)
        SELECT CASE edge
            CASE 0: BLOOD_X(i) = INT(RND * SW * CW): BLOOD_Y(i) = INT(RND * SH * CH * 0.22)
            CASE 1: BLOOD_X(i) = INT(RND * SW * CW): BLOOD_Y(i) = SH * CH - INT(RND * SH * CH * 0.22)
            CASE 2: BLOOD_X(i) = INT(RND * SW * CW * 0.18): BLOOD_Y(i) = INT(RND * SH * CH)
            CASE ELSE: BLOOD_X(i) = SW * CW - INT(RND * SW * CW * 0.18): BLOOD_Y(i) = INT(RND * SH * CH)
        END SELECT
        BLOOD_R(i) = INT(RND * 12) + 4
    NEXT
    '--- drips run down from the top edge: a random x, length, and thickness each ---
    FOR i = 1 TO NDRIP
        DRIP_X(i) = INT(RND * (SW * CW - 8)) + 4
        DRIP_LEN(i) = INT(RND * (SH * CH * 0.5)) + INT(SH * CH * 0.06)
        DRIP_W(i) = INT(RND * 3) + 2
    NEXT
    InitPoison
END SUB

' Grow the fixed poison-vein pattern (tendrils creeping in from the edges, each with a
' couple of child branches) + slime pools + ooze drips. RND is used ONCE here so the
' pattern is stable frame-to-frame (like the blood grime); DrawPoison just fades it in.
SUB InitPoison
    DIM AS INTEGER v, s, nb, b, i, edge, tseg, bseg
    DIM AS SINGLE vx, vy, va, ln, bx, by, ba
    VEIN_N = 0
    FOR v = 1 TO NVEIN
        edge = INT(RND * 4)
        SELECT CASE edge                              ' anchor on a rim, aim inward
            CASE 0: vx = INT(RND * SW * CW): vy = 0: va = 1.5708
            CASE 1: vx = INT(RND * SW * CW): vy = SH * CH: va = -1.5708
            CASE 2: vx = 0: vy = INT(RND * SH * CH): va = 0
            CASE ELSE: vx = SW * CW: vy = INT(RND * SH * CH): va = 3.14159
        END SELECT
        va = va + (RND * 2 - 1) * 0.5
        ln = 14 + RND * 10
        tseg = 5 + INT(RND * 4)
        FOR s = 1 TO tseg                             ' the trunk, wandering inward
            AddVein vx, vy, vx + COS(va) * ln, vy + SIN(va) * ln, 0
            vx = vx + COS(va) * ln: vy = vy + SIN(va) * ln
            va = va + (RND * 2 - 1) * 0.6
            IF RND < 0.6 THEN                         ' spawn a child branch off this joint
                ba = va + (RND * 2 - 1) * 1.0: bx = vx: by = vy
                bseg = 2 + INT(RND * 3)
                FOR b = 1 TO bseg
                    AddVein bx, by, bx + COS(ba) * ln * 0.72, by + SIN(ba) * ln * 0.72, 1
                    bx = bx + COS(ba) * ln * 0.72: by = by + SIN(ba) * ln * 0.72
                    ba = ba + (RND * 2 - 1) * 0.7
                NEXT
            END IF
        NEXT
    NEXT
    '--- slime blobs: biased to the bottom + the two sides (it pools + runs down) ---
    FOR i = 1 TO NSLIME
        edge = INT(RND * 3)
        SELECT CASE edge
            CASE 0: SLIME_X(i) = INT(RND * SW * CW): SLIME_Y(i) = SH * CH - INT(RND * SH * CH * 0.30)
            CASE 1: SLIME_X(i) = INT(RND * SW * CW * 0.16): SLIME_Y(i) = INT(RND * SH * CH)
            CASE ELSE: SLIME_X(i) = SW * CW - INT(RND * SW * CW * 0.16): SLIME_Y(i) = INT(RND * SH * CH)
        END SELECT
        SLIME_R(i) = INT(RND * 14) + 5
    NEXT
    '--- ooze drips from the top edge: fatter + longer than blood (gooier) ---
    FOR i = 1 TO NOOZE
        OOZE_X(i) = INT(RND * (SW * CW - 10)) + 5
        OOZE_LEN(i) = INT(RND * (SH * CH * 0.55)) + INT(SH * CH * 0.08)
        OOZE_W(i) = INT(RND * 4) + 3
    NEXT
END SUB

' Append one poison-vein segment (gen 0 = trunk, 1 = branch) if room remains.
SUB AddVein (x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE, gen AS INTEGER)
    IF VEIN_N >= NVEINSEG THEN EXIT SUB
    VEIN_N = VEIN_N + 1
    VEIN_X1(VEIN_N) = INT(x1): VEIN_Y1(VEIN_N) = INT(y1)
    VEIN_X2(VEIN_N) = INT(x2): VEIN_Y2(VEIN_N) = INT(y2)
    VEIN_GEN(VEIN_N) = gen
END SUB

' The persistent POISON overlay -- drawn every frame at `intensity` (0..1) > 0, right
' after DrawWounds (board -> blood -> poison -> text). A sickly-green rim, veins
' creeping inward, slime pools, and ooze drips, all throbbing with a slow queasy pulse
' that deepens the longer the poison lingers. Sits UNDER the labels/HUD like the blood.
SUB DrawPoison (intensity AS SINGLE)
    IF NOT opt_juice THEN EXIT SUB
    IF intensity <= 0 THEN EXIT SUB                    ' 0 = not poisoned (game supplies the level via Game_PoisonLevel!)
    DIM AS INTEGER i, aV, aSl, aO, aE, aW
    DIM AS SINGLE p, pulse
    p = intensity: IF p > 1 THEN p = 1
    IF p < 0.4 THEN p = 0.4                            ' always clearly sick while poisoned
    pulse = 0.6 + 0.4 * ((SIN(TIMER * 2.1) + 1) / 2)   ' slow nauseous throb
    _DEST CANVAS
    '--- a faint overall sickly cast + a green rim fading inward ---
    aW = INT(20 * p * pulse)
    IF aW > 0 THEN LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(35, 120, 25, aW), BF
    FOR i = 0 TO 33 STEP 3
        aE = INT((95 * p * pulse) * (1 - i / 33))
        IF aE > 0 THEN LINE (i, i)-(SW * CW - 1 - i, SH * CH - 1 - i), _RGB32(45, 140, 35, aE), B
    NEXT
    '--- the veins (trunks thicker + darker with a nodule at each tip; branches thin) ---
    aV = INT(195 * p * pulse)
    FOR i = 1 TO VEIN_N
        IF VEIN_GEN(i) = 0 THEN                         ' trunk: 3px, brighter, nodule at the tip
            LINE (VEIN_X1(i), VEIN_Y1(i) - 1)-(VEIN_X2(i), VEIN_Y2(i) - 1), _RGB32(50, 130, 38, INT(aV * 0.7))
            LINE (VEIN_X1(i), VEIN_Y1(i))-(VEIN_X2(i), VEIN_Y2(i)), _RGB32(85, 185, 60, aV)
            LINE (VEIN_X1(i), VEIN_Y1(i) + 1)-(VEIN_X2(i), VEIN_Y2(i) + 1), _RGB32(50, 130, 38, aV)
            FillDisc VEIN_X2(i), VEIN_Y2(i), 3, _RGB32(80, 175, 55, aV)
        ELSE                                            ' branch: 2px, bright sickly green
            LINE (VEIN_X1(i), VEIN_Y1(i))-(VEIN_X2(i), VEIN_Y2(i)), _RGB32(115, 205, 80, aV)
            LINE (VEIN_X1(i), VEIN_Y1(i) + 1)-(VEIN_X2(i), VEIN_Y2(i) + 1), _RGB32(70, 150, 48, INT(aV * 0.7))
            FillDisc VEIN_X2(i), VEIN_Y2(i), 2, _RGB32(120, 210, 85, INT(aV * 0.9))
        END IF
    NEXT
    '--- slime blobs with a brighter sheen on top (wet look) ---
    aSl = INT(150 * p * pulse)
    FOR i = 1 TO NSLIME
        FillDisc SLIME_X(i), SLIME_Y(i), SLIME_R(i), _RGB32(70, 175, 55, aSl)
        FillDisc SLIME_X(i), SLIME_Y(i) - SLIME_R(i) \ 3, SLIME_R(i) \ 2, _RGB32(130, 215, 95, INT(aSl * 0.65))
    NEXT
    '--- ooze drips: a green streak with a fat droplet at the tip ---
    aO = INT(165 * p * pulse)
    FOR i = 1 TO NOOZE
        LINE (OOZE_X(i) - OOZE_W(i) \ 2, 0)-(OOZE_X(i) + OOZE_W(i) \ 2, OOZE_LEN(i)), _RGB32(55, 150, 42, aO), BF
        FillDisc OOZE_X(i), OOZE_LEN(i), OOZE_W(i) + 2, _RGB32(95, 195, 70, aO)
    NEXT
END SUB

' Pre-bake NVIG soft RADIAL vignette overlays (black with a smooth distance-from-centre alpha
' falloff -- a gaussian-ish "closing darkness"), a low-res ramp from faint+wide to dark+tight.
' DrawWounds picks one by near-death level each frame and stretch-blits it (cheap + smooth),
' instead of the old rectangular edge bands. Baked once at startup via _MEM for speed.
SUB InitVignette
    DIM AS INTEGER lv, x, y, aa, vw, vh
    DIM AS SINGLE inner, maxA, cx, cy, maxD, nd, tt
    DIM AS _MEM m
    vw = 200: vh = 154 '                low-res; the vignette is low-frequency so the stretch is invisible
    cx = vw / 2: cy = vh / 2: maxD = SQR(cx * cx + cy * cy)
    FOR lv = 0 TO NVIG - 1
        inner = 0.60 - 0.50 * (lv / (NVIG - 1)) '   clear centre 0.60 -> 0.10: closes in tight near death
        maxA = 90 + 145 * (lv / (NVIG - 1)) '        edge darkness 90 -> 235: heavier, more obvious
        VIG(lv) = _NEWIMAGE(vw, vh, 32)
        m = _MEMIMAGE(VIG(lv))
        FOR y = 0 TO vh - 1
            FOR x = 0 TO vw - 1
                nd = SQR((x - cx) * (x - cx) + (y - cy) * (y - cy)) / maxD
                aa = 0
                IF nd > inner THEN
                    tt = (nd - inner) / (1 - inner): IF tt > 1 THEN tt = 1
                    aa = INT((tt ^ 1.6) * maxA) '   ^1.6 = soft gaussian-ish ramp
                    IF aa > 255 THEN aa = 255
                END IF
                _MEMPUT m, m.OFFSET + (y * vw + x) * 4, _RGBA32(0, 0, 0, aa) AS _UNSIGNED LONG
            NEXT
        NEXT
        _MEMFREE m
    NEXT
END SUB

' The impact: shake the frame, wash it, spray splatters. mag scales with the blow;
' kind 0 = blood (red), 1 = poison (green), 2 = fire (orange).
SUB ImpactFX (mag AS SINGLE, kind AS INTEGER)
    IF NOT opt_juice THEN EXIT SUB
    IF FX_BUF = 0 THEN EXIT SUB
    DIM i AS INTEGER, frames AS INTEGER, fr AS SINGLE, ox AS SINGLE, oy AS SINGLE, a AS INTEGER
    DIM r AS INTEGER, g AS INTEGER, b AS INTEGER, ns AS INTEGER, j AS INTEGER
    DIM sx(1 TO 24) AS INTEGER, sy(1 TO 24) AS INTEGER, sr(1 TO 24) AS INTEGER
    SELECT CASE kind
        CASE 1: r = 70: g = 200: b = 80
        CASE 2: r = 240: g = 130: b = 40
        CASE ELSE: r = 210: g = 40: b = 40
    END SELECT
    ns = 3 + INT(mag / 3): IF ns > 24 THEN ns = 24
    FOR j = 1 TO ns
        sx(j) = INT(RND * SW * CW): sy(j) = INT(RND * SH * CH): sr(j) = INT(RND * 9) + 4
    NEXT
    _PUTIMAGE (0, 0), CANVAS, FX_BUF                 ' snapshot the live frame
    frames = INT(5 + mag * 0.28)                     ' small taps stay snappy; big blows linger
    IF frames > 13 THEN frames = 13
    IF frames < 4 THEN frames = 4
    FOR i = frames TO 0 STEP -1
        fr = i / frames
        _DEST CANVAS: CLS , BLACK
        ox = (RND * 2 - 1) * mag * fr
        oy = (RND * 2 - 1) * mag * fr
        _PUTIMAGE (ox, oy), FX_BUF, CANVAS
        a = INT(235 * fr)                            ' the splatter spray, fading with the shake
        FOR j = 1 TO ns
            SplatBlob sx(j), sy(j), sr(j), _RGB32(r, g, b, a)
        NEXT
        a = INT(120 * fr)                            ' the colour wash
        IF a > 0 THEN LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(r, g, b, a), BF
        _DISPLAY
        _LIMIT 60
    NEXT
    _DEST CANVAS: CLS , BLACK: _PUTIMAGE (0, 0), FX_BUF, CANVAS   ' leave a clean frame for the caller
END SUB

' The persistent near-death overlay -- drawn every frame (HUD + combat panel). Dark
' vignette closing in from the rim (pulsing near death) + blood grime; both ramp as HP
' falls below half. Cheap: a few dozen alpha lines + fixed discs.
SUB DrawWounds
    IF NOT opt_juice THEN EXIT SUB
    IF opt_oldschool THEN EXIT SUB
    IF player_maxhp <= 0 THEN EXIT SUB
    DIM hpFrac AS SINGLE, wound AS SINGLE, pulse AS SINGLE, band AS INTEGER, i AS INTEGER, a AS INTEGER
    hpFrac = player_hp / player_maxhp
    IF hpFrac >= 0.5 THEN EXIT SUB
    wound = (0.5 - hpFrac) / 0.5
    IF wound > 1 THEN wound = 1
    pulse = 1
    IF hpFrac < 0.25 THEN pulse = 0.6 + 0.4 * ((SIN(TIMER * 4.5) + 1) / 2)   ' a quickening heartbeat near death
    _DEST CANVAS
    '--- soft RADIAL vignette: pick the near-death level and stretch-blit the pre-baked gaussian
    '    overlay (smooth "closing darkness" from the rim, replacing the old rectangular bands) ---
    band = INT(wound * pulse * (NVIG - 1) + 0.5)
    IF band < 0 THEN band = 0
    IF band > NVIG - 1 THEN band = NVIG - 1
    IF VIG(band) <> 0 THEN _PUTIMAGE (0, 0)-(SW * CW - 1, SH * CH - 1), VIG(band), CANVAS
    a = INT(BLOOD_ALPHA_MAX * (opt_bloodstrength / 10) * wound * pulse)  ' SETTINGS "Blood" scales the grime (sits UNDER the text)
    IF a > 6 THEN
        FOR i = 1 TO NBLOOD
            FillDisc BLOOD_X(i), BLOOD_Y(i), BLOOD_R(i), _RGB32(110, 8, 10, a)
        NEXT
        '--- drips run down from the top edge: a dark streak with a brighter drop at the tip ---
        FOR i = 1 TO NDRIP
            LINE (DRIP_X(i) - DRIP_W(i) \ 2, 0)-(DRIP_X(i) + DRIP_W(i) \ 2, DRIP_LEN(i)), _RGB32(95, 6, 8, a), BF
            FillDisc DRIP_X(i), DRIP_LEN(i), DRIP_W(i) + 2, _RGB32(140, 14, 16, a)
        NEXT
    END IF
END SUB

' CRIT BOOM -- the money shot. A HUGE damage number plummets from above, SLAMS into
' the upper-centre with a thump + a molten flash, and the whole frame erupts in a
' volcanic screen-shake that lingers and decays. Called on a player critical hit.
SUB CritBoom (dmg AS INTEGER)
    IF NOT opt_juice THEN EXIT SUB
    IF FX_BUF = 0 THEN EXIT SUB
    DIM s AS STRING, i AS INTEGER, dx AS INTEGER, dy AS INTEGER
    DIM numimg AS LONG, nw AS INTEGER, nh AS INTEGER, frames AS INTEGER, cxp AS INTEGER
    DIM t AS SINGLE, tImp AS SINGLE, dropT AS SINGLE, settleT AS SINGLE
    DIM yTop AS SINGLE, yLand AS SINGLE, yNow AS SINGLE, sc AS SINGLE, mag AS SINGLE
    DIM ox AS SINGLE, oy AS SINGLE, dw AS INTEGER, dh AS INTEGER, a AS INTEGER, thumped AS INTEGER
    s = _TRIM$(STR$(dmg))
    '--- pre-render the number once with a heavy dark outline, then stretch it huge ---
    nw = LEN(s) * CW + 8: nh = CH + 8
    numimg = _NEWIMAGE(nw, nh, 32)
    _DEST numimg: CLS , _RGBA32(0, 0, 0, 0): _FONT CH
    FOR dy = -2 TO 2
        FOR dx = -2 TO 2
            IF dx <> 0 OR dy <> 0 THEN COLOR _RGB32(25, 5, 0), _RGBA32(0, 0, 0, 0): _PRINTSTRING (4 + dx, 4 + dy), s
        NEXT
    NEXT
    COLOR _RGB32(255, 205, 45), _RGBA32(0, 0, 0, 0): _PRINTSTRING (4, 4), s
    _DEST CANVAS
    _PUTIMAGE (0, 0), CANVAS, FX_BUF                    ' snapshot the drained-panel frame
    frames = 42: tImp = 0.4
    cxp = SW * CW \ 2: yTop = -nh * 8: yLand = SH * CH * 0.42: thumped = 0
    FOR i = 0 TO frames
        t = i / frames
        settleT = 0
        IF t <= tImp THEN
            dropT = t / tImp
            yNow = yTop + (yLand - yTop) * (dropT * dropT)    ' accelerate downward
            sc = 3 + 8 * dropT                                 ' rush toward the camera
            mag = 5 + 26 * dropT                               ' shake builds as it falls
        ELSE
            settleT = (t - tImp) / (1 - tImp)
            yNow = yLand
            sc = 11 + 3 * COS(settleT * 9) * (1 - settleT)     ' overshoot bounce, settling to 11
            mag = 34 * EXP(-3 * settleT)                       ' VOLCANIC: erupts, then decays
            IF NOT thumped THEN Sfx "boom": thumped = -1       ' the THUMP on landing
        END IF
        _DEST CANVAS: CLS , BLACK
        ox = (RND * 2 - 1) * mag: oy = (RND * 2 - 1) * mag
        _PUTIMAGE (ox, oy), FX_BUF, CANVAS                     ' the jittered board + panel
        IF settleT > 0 AND settleT < 0.35 THEN                 ' molten flash right at impact
            a = INT(150 * (1 - settleT / 0.35))
            LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(255, 120, 30, a), BF
        END IF
        dw = INT(nw * sc): dh = INT(nh * sc)
        _PUTIMAGE (cxp - dw \ 2, INT(yNow) - dh \ 2)-(cxp + dw \ 2, INT(yNow) + dh \ 2), numimg, CANVAS
        _DISPLAY: _LIMIT 60
    NEXT
    _DEST CANVAS: CLS , BLACK: _PUTIMAGE (0, 0), FX_BUF, CANVAS ' leave a clean frame for the caller
    _FREEIMAGE numimg
END SUB

' Damage -> shake magnitude. Small taps barely nudge; big blows really lurch.
FUNCTION ShakeMag! (dmg AS INTEGER)
    DIM m AS SINGLE
    m = 3 + dmg * 1.6
    IF m > 28 THEN m = 28
    ShakeMag! = m
END FUNCTION
