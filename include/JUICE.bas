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
'
'  All gated by opt_juice (D&D mode; oldschool has no HP). Snapshot/vignette read
'  the screen surface, so nothing changes when the toggle is off.
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
    FOR i = 1 TO NBLOOD
        edge = INT(RND * 4)
        SELECT CASE edge
            CASE 0: BLOOD_X(i) = INT(RND * SW * CW): BLOOD_Y(i) = INT(RND * SH * CH * 0.22)
            CASE 1: BLOOD_X(i) = INT(RND * SW * CW): BLOOD_Y(i) = SH * CH - INT(RND * SH * CH * 0.22)
            CASE 2: BLOOD_X(i) = INT(RND * SW * CW * 0.18): BLOOD_Y(i) = INT(RND * SH * CH)
            CASE ELSE: BLOOD_X(i) = SW * CW - INT(RND * SW * CW * 0.18): BLOOD_Y(i) = INT(RND * SH * CH)
        END SELECT
        BLOOD_R(i) = INT(RND * 9) + 3
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
    band = INT(40 + 90 * wound)                       ' how far the darkness reaches inward (kept near the rim)
    FOR i = 0 TO band STEP 2
        a = INT(95 * wound * pulse * (band - i) / band)   ' lighter, so the map/labels stay readable beneath
        IF a > 3 THEN
            LINE (0, i)-(SW * CW, i), _RGB32(0, 0, 0, a)
            LINE (0, SH * CH - 1 - i)-(SW * CW, SH * CH - 1 - i), _RGB32(0, 0, 0, a)
            LINE (i, 0)-(i, SH * CH), _RGB32(0, 0, 0, a)
            LINE (SW * CW - 1 - i, 0)-(SW * CW - 1 - i, SH * CH), _RGB32(0, 0, 0, a)
        END IF
    NEXT
    a = INT(60 * wound * pulse)                        ' dried blood spattered round the frame -- semi-transparent
    IF a > 6 THEN
        FOR i = 1 TO NBLOOD
            FillDisc BLOOD_X(i), BLOOD_Y(i), BLOOD_R(i), _RGB32(110, 8, 10, a)
        NEXT
    END IF
END SUB

' Damage -> shake magnitude. Small taps barely nudge; big blows really lurch.
FUNCTION ShakeMag! (dmg AS INTEGER)
    DIM m AS SINGLE
    m = 3 + dmg * 1.6
    IF m > 28 THEN m = 28
    ShakeMag! = m
END FUNCTION
