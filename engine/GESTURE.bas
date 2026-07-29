' ============================================================================
'  GESTURE.bas -- optional ACTION-GESTURE mini-game (SETTINGS "Action Gestures").
'
'  A Greywood-style timing gauge (grymmjack's qb64pe-lab/greywood): a marker sweeps
'  a bar on a sine wave; press SPACE to lock it. Where it lands scores a ZONE --
'  crit (purple centre), hit (green band), miss (dark). A TIGHT fuse counts down; let
'  it run out and the attempt is forfeit. The sweet spot NARROWS as you descend.
'
'  Two moments use it (D&D mode only; both lean on hit points):
'    * SECOND WIND -- on a downing blow, one clutch attempt: nail the CRIT zone to
'      rise in place with 1d6 HP (keep your gold, no life spent). Miss = real death.
'    * CRIT FLOURISH -- on a natural-20 crit, the gauge grants +0/+1/+2 EXTRA damage
'      dice (miss/hit/crit zone), rolled normally on top of the doubled crit.
'
'  NOTE: this module does NOT read opt_gestures itself -- its game-side CALLERS gate on
'  it (the toggle is a game ruleset switch and lives in GAME.BI). The old comment here
'  claimed "all gated by opt_gestures", which read as if the gate were internal.
' ============================================================================

CONST GESTURE_FUSE = 1.7          ' seconds on the countdown -- tight: about one good sweep

' Run the timing gauge. title/prompt frame it; depth (1-9) narrows the zones. Returns
' the zone locked: 2 crit, 1 hit, 0 miss, -1 fuse expired (no lock). Sets gauge_quality
' (0..1 = closeness to dead-centre) for callers that want to reward precision.
FUNCTION GaugeLock% (title AS STRING, prompt AS STRING, swMode AS INTEGER, depth AS INTEGER)
    DIM phase AS SINGLE, p AS SINGLE, d AS SINGLE, spd AS SINGLE, df AS SINGLE
    DIM critHW AS SINGLE, hitHW AS SINGLE, t0 AS SINGLE, fuseLeft AS SINGLE
    DIM k AS STRING, z AS INTEGER, locked AS INTEGER, lockP AS SINGLE, fl AS SINGLE
    df = (depth - 1) / 8: IF df < 0 THEN df = 0
    IF df > 1 THEN df = 1
    critHW = 0.07 - 0.035 * df                   ' sweet spot: 14% of the bar up top, 7% at the bottom
    hitHW = 0.24 - 0.11 * df
    spd = 0.055 + 0.02 * df                       ' and the sweep quickens a touch deeper down
    phase = RND * 6.28318                         ' random start phase -- no metronome
    t0 = TIMER: gauge_quality = 0
    _KEYCLEAR                                      ' drop the SPACE that opened this so it can't instant-lock
    Sfx "diceroll"
    DO
        fuseLeft = GESTURE_FUSE - (TIMER - t0)
        IF fuseLeft <= 0 THEN GaugeLock% = -1: EXIT FUNCTION
        phase = phase + spd
        p = (SIN(phase) + 1) / 2
        DrawGauge title, prompt, swMode, p, critHW, hitHW, fuseLeft / GESTURE_FUSE
        _DISPLAY
        _LIMIT 60
        k = INKEY$
        IF k = CHR$(27) THEN GaugeLock% = 0: EXIT FUNCTION      ' ESC forfeits (counts as a miss)
        IF k = " " OR k = CHR$(13) THEN
            d = ABS(p - 0.5)
            IF d <= critHW THEN
                z = 2: gauge_quality = 1 - d / critHW
            ELSEIF d <= hitHW THEN
                z = 1: gauge_quality = 1 - (d - critHW) / (hitHW - critHW)
            ELSE
                z = 0: gauge_quality = 0
            END IF
            ' freeze a beat on the locked marker so the result reads
            IF z = 2 THEN
                Sfx "crit"
            ELSEIF z = 1 THEN
                Sfx "hit"
            ELSE
                Sfx "bump"
            END IF
            fl = TIMER
            DO
                DrawGauge title, GaugeResult$(z, swMode), swMode, p, critHW, hitHW, fuseLeft / GESTURE_FUSE
                DrawGaugeLock p, z
                _DISPLAY: _LIMIT 60
            LOOP UNTIL TIMER - fl >= 0.6
            GaugeLock% = z
            EXIT FUNCTION
        END IF
    LOOP
END FUNCTION

FUNCTION GaugeResult$ (z AS INTEGER, swMode AS INTEGER)
    IF swMode THEN                                ' SECOND WIND: purple = rise, anything else = you fall
        IF z = 2 THEN GaugeResult$ = "** RISE! **" ELSE GaugeResult$ = "TOO SLOW..."
    ELSE
        SELECT CASE z
            CASE 2: GaugeResult$ = "** CRIT! **"
            CASE 1: GaugeResult$ = "-- HIT --"
            CASE ELSE: GaugeResult$ = "MISS"
        END SELECT
    END IF
END FUNCTION

' Paint the gauge: a framed panel with the fuse bar, the layered zones (dark miss /
' green hit / purple crit), the sweeping marker, and the caption/labels.
SUB DrawGauge (title AS STRING, prompt AS STRING, swMode AS INTEGER, p AS SINGLE, critHW AS SINGLE, hitHW AS SINGLE, fuseFrac AS SINGLE)
    DIM bx AS INTEGER, bw AS INTEGER, by AS INTEGER, bh AS INTEGER
    DIM gx AS INTEGER, gw AS INTEGER, gy AS INTEGER, gh AS INTEGER, mxp AS INTEGER
    DIM fx AS INTEGER, fw AS INTEGER, fcol AS _UNSIGNED LONG
    bx = 18: bw = 96: by = 16: bh = 22
    _DEST CANVAS
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered by + 2, "-=  " + title + "  =-"
    ' fuse countdown
    fx = (bx + 6) * CW: fw = (bw - 12) * CW
    LINE (fx, (by + 5) * CH)-(fx + fw, (by + 6) * CH - 4), _RGB32(40, 40, 46), BF
    IF fuseFrac > 0.35 THEN fcol = _RGB32(170, 150, 70) ELSE fcol = _RGB32(220, 60, 50)
    LINE (fx, (by + 5) * CH)-(fx + INT(fw * fuseFrac), (by + 6) * CH - 4), fcol, BF
    ' the gauge bar with layered zones
    gx = (bx + 6) * CW: gw = (bw - 12) * CW: gy = (by + 11) * CH: gh = 3 * CH
    LINE (gx, gy)-(gx + gw, gy + gh), _RGB32(&H33, &H3B, &H33), BF                                  ' dark = miss/fall
    IF swMode = 0 THEN LINE (gx + INT((0.5 - hitHW) * gw), gy)-(gx + INT((0.5 + hitHW) * gw), gy + gh), _RGB32(&H2E, &HA0, &H55), BF   ' green = hit (crit flourish only)
    LINE (gx + INT((0.5 - critHW) * gw), gy)-(gx + INT((0.5 + critHW) * gw), gy + gh), _RGB32(&HA6, &H66, &HCE), BF ' purple = crit / second wind
    ' the sweeping marker
    mxp = gx + INT(p * gw)
    LINE (mxp - 1, gy - 8)-(mxp + 2, gy + gh + 8), _RGB32(&HF0, &HEC, &HD0), BF
    DIM leg AS STRING
    IF swMode THEN leg = "purple = SECOND WIND" ELSE leg = "purple = +2 dice     green = +1     dark = +0"
    COLOR GREY, BOXBG: PrintCentered by + 16, leg
    COLOR CYANU, BOXBG: PrintCentered by + 18, prompt
END SUB

' Overlay a coloured band at the locked position during the result freeze.
SUB DrawGaugeLock (p AS SINGLE, z AS INTEGER)
    DIM gx AS INTEGER, gw AS INTEGER, gy AS INTEGER, gh AS INTEGER, mxp AS INTEGER, col AS _UNSIGNED LONG
    gx = 24 * CW: gw = 84 * CW: gy = 27 * CH: gh = 3 * CH
    mxp = gx + INT(p * gw)
    col = _RGB32(&H70, &H80, &H5C)
    IF z = 2 THEN col = _RGB32(&HFF, &HD2, &H50)
    IF z = 1 THEN col = _RGB32(&HEB, &HF0, &HF5)
    LINE (mxp - 2, gy - 10)-(mxp + 3, gy + gh + 10), col, BF
END SUB

' SECOND WIND: one clutch attempt on a downing blow. Nail the CRIT zone -> rise in
' place with 1d6 HP. Anything else (or the fuse) -> the save fails. Returns TRUE on the
' rise (player_hp is set); the caller then simply keeps fighting.
FUNCTION SecondWind% (mon AS STRING, depth AS INTEGER)
    DIM z AS INTEGER, hp AS INTEGER
    z = GaugeLock%("FIGHT FOR YOUR LIFE", "SPACE in the PURPLE to rise -- one chance!", -1, depth)
    IF z = 2 THEN
        hp = RollDie(6): player_hp = hp
        Sfx "levelup"
        Banner "** SECOND WIND! **", "You claw back from the brink with " + _TRIM$(STR$(hp)) + " HP -- fight on!   [ press any key ]"
        WaitKey
        SecondWind% = -1
    ELSE
        SecondWind% = 0
    END IF
END FUNCTION

' CRIT FLOURISH: the gauge on a natural-20 crit. Crit zone = +2 bonus damage dice, hit
' zone = +1, miss/timeout = +0. The bonus dice roll through the normal dice system (so
' Real Dice / 3D dice all apply). Returns the extra damage to add to the crit.
FUNCTION CritFlourish% (mon AS STRING, depth AS INTEGER)
    DIM z AS INTEGER, xn AS INTEGER
    z = GaugeLock%("CRITICAL FLOURISH!", "SPACE to land the follow-through", 0, depth)
    xn = 0
    IF z = 2 THEN xn = 2
    IF z = 1 THEN xn = 1
    CritFlourish% = 0
    IF xn > 0 THEN CritFlourish% = GameRoll(xn, player_dmgdie, 0, "CRIT FLOURISH -- +" + _TRIM$(STR$(xn)) + " dice")
END FUNCTION
