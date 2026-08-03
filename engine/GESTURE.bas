' ============================================================================
'  GESTURE.bas -- optional ACTION-GESTURE mini-game (SETTINGS "Action Gestures").
'
'  A Greywood-style timing gauge: a marker sweeps a bar; press SPACE to lock it. Where it lands
'  scores a ZONE -- crit (purple centre), hit (green band), miss (dark). A TIGHT fuse counts down;
'  let it run out and the attempt is forfeit.
'
'  THE MATH IS engine/GAUGE.bas -- the same unit-tested model the tactical fight screen and the
'  auto-resolve twin GaugeSample% run on. This file is one of its two PRESENTATIONS (the framed
'  box overlay); engine/FIGHT.bas draws the other (the inline bar). It used to carry its own
'  private width/speed math, which meant a tuning change to GAUGE.bas silently did not reach
'  SECOND WIND -- and that wounds and crowd pressure narrowed one gauge but not the other.
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

' Run the timing gauge. title/prompt frame it; depth (1-9) narrows the zones. Returns
' the zone locked: 2 crit, 1 hit, 0 miss, -1 fuse expired (no lock). Sets gauge_quality
' (0..1 = closeness to dead-centre) for callers that want to reward precision.
FUNCTION GaugeLock% (title AS STRING, prompt AS STRING, swMode AS INTEGER, depth AS INTEGER, skill AS INTEGER)
    DIM k AS GAUGEK, kk AS STRING, z AS INTEGER, q AS SINGLE
    DIM t0 AS SINGLE, fuseLeft AS SINGLE, fl AS SINGLE, gsecs AS SINGLE

    ' ONE MODEL, TWO PRESENTATIONS. The zone widths, the sweep and the marker all come from
    ' engine/GAUGE.bas now -- the same unit-tested math the tactical screen and the auto-resolve
    ' twin GaugeSample% use. This function is purely the BOX presentation: it owns the framed
    ' overlay, the result freeze and the sounds.
    '
    ' What changed by unifying: WOUNDS and CROWD now narrow this gauge too (GaugeKnobs reads
    ' hp/maxhp and press), and SKILL widens it with character level. Previously the widths came
    ' only from `depth`, so a dying hero read the bar exactly as well as a healthy one. The
    ' feel is close but no longer identical -- that is the point of sharing the model.
    ' `skill` is passed IN, not derived here: it comes from the game's character level, and
    ' char_level is a GAME symbol -- engine/ naming it broke examples/minimal (which drives the
    ' engine with no game at all) and tripped tests/audit-boundary.sh.
    k.skill = skill
    IF k.skill < 0 THEN k.skill = 0
    IF k.skill > 2 THEN k.skill = 2
    k.hp = player_hp: k.maxhp = player_maxhp
    k.willmax = 0: k.will = 0          ' no willpower spend in the board-game overlay
    k.wobble = 0: k.press = 0
    k.depth = depth
    GaugeKnobs k
    GaugeBegin k

    ' REAL DICE: the bar does not sweep and there is no fuse. A gesture is a test of TIMING,
    ' and a player rolling a physical d20 has no timing to test -- the old behaviour asked them
    ' to watch a sweeping marker while reaching for dice, which is two things at once and
    ' neither of them the game. Instead the bar stands still with the d20 faces mapped along
    ' it, they roll, they type it, and the marker lands where that face falls.
    IF opt_realdice THEN
        GaugeLock% = GaugeLockDice%(title, prompt, swMode, k)
        EXIT FUNCTION
    END IF

    gsecs = GestureSecs!
    t0 = TIMER: gauge_quality = 0
    _KEYCLEAR                          ' drop the SPACE that opened this so it cannot instant-lock
    Sfx "diceroll"
    DO
        fuseLeft = gsecs - (TIMER - t0)
        ' TIMER wraps at midnight; without this the fuse would read as expired instantly.
        IF TIMER - t0 < 0 THEN t0 = TIMER: fuseLeft = gsecs
        IF fuseLeft <= 0 THEN GaugeLock% = -1: EXIT FUNCTION
        GaugeStep k
        ' Draw at EXACTLY the numbers GaugeScore% will read -- WYSIWYG, so the zone can never
        ' score somewhere the player cannot see. k is passed WHOLE (not p/ecrit/ehit picked out)
        ' precisely so k.zc cannot be forgotten again -- see the note on DrawGauge.
        DrawGauge title, prompt, swMode, k, fuseLeft / gsecs
        Present
        _LIMIT 60
        kk = INKEY$
        IF kk = CHR$(27) THEN GaugeLock% = 0: EXIT FUNCTION      ' ESC forfeits (counts as a miss)
        IF kk = " " OR kk = CHR$(13) THEN
            z = GaugeScore%(k, q)
            gauge_quality = q
            IF z = 2 THEN
                Sfx "crit"
            ELSEIF z = 1 THEN
                Sfx "hit"
            ELSE
                Sfx "bump"
            END IF
            ' freeze a beat on the locked marker so the result reads
            fl = TIMER
            DO
                DrawGauge title, GaugeResult$(z, swMode), swMode, k, fuseLeft / gsecs
                DrawGaugeLock k.p, z
                Present: _LIMIT 60
            LOOP UNTIL TIMER - fl >= 0.6 OR TIMER - fl < 0
            GaugeLock% = z
            EXIT FUNCTION
        END IF
    LOOP
END FUNCTION

' The REAL-DICE gesture: a static bar with the 20 d20 faces laid along it, each shaded by the
' zone it would score. The player rolls their own d20 and types it; the marker goes to that
' face and the attempt is scored exactly as a timed lock would be.
'
' No fuse. The fuse exists to make hesitation cost something on a TIMING test; here there is
' nothing to hesitate about, and a countdown would only punish someone for the time it takes
' to pick dice up off a table.
FUNCTION GaugeLockDice% (title AS STRING, prompt AS STRING, swMode AS INTEGER, k AS GAUGEK)
    DIM entry AS STRING, kk AS STRING, chcode AS INTEGER, v AS INTEGER
    DIM z AS INTEGER, q AS SINGLE, msg AS STRING, fl AS SINGLE
    gauge_quality = 0
    _KEYCLEAR                              ' drop the SPACE that opened this
    entry = "": msg = ""
    DO
        _LIMIT 60
        ' Live preview: the marker follows what has been TYPED, so a mistyped 1 shows itself
        ' before ENTER commits it. v = 0 while the entry is empty or out of range -> no marker.
        v = VAL(entry)
        IF v >= 1 AND v <= 20 THEN k.p = GaugeDieP!(v, 20)
        DrawGaugeEx title, prompt, swMode, k, 1, 0, (v >= 1 AND v <= 20)
        DrawGaugeDiceStrip k, entry, msg
        Present
        kk = INKEY$
        IF kk = CHR$(27) THEN GaugeLockDice% = 0: EXIT FUNCTION      ' ESC forfeits (a miss)
        IF kk = CHR$(13) THEN
            IF LEN(entry) > 0 THEN
                v = VAL(entry)
                IF v >= 1 AND v <= 20 THEN
                    k.p = GaugeDieP!(v, 20)
                    z = GaugeScore%(k, q)
                    gauge_quality = q
                    IF z = 2 THEN
                        Sfx "crit"
                    ELSEIF z = 1 THEN
                        Sfx "hit"
                    ELSE
                        Sfx "bump"
                    END IF
                    fl = TIMER                                        ' freeze on the result, as the timed gauge does
                    DO
                        DrawGaugeEx title, GaugeResult$(z, swMode), swMode, k, 1, 0, -1
                        DrawGaugeDiceStrip k, entry, ""
                        DrawGaugeLock k.p, z
                        Present: _LIMIT 60
                    LOOP UNTIL TIMER - fl >= 0.9 OR TIMER - fl < 0
                    GaugeLockDice% = z
                    EXIT FUNCTION
                ELSE
                    msg = "A d20 rolls 1 to 20.": entry = ""
                END IF
            END IF
        ELSEIF kk = CHR$(8) THEN
            IF LEN(entry) > 0 THEN entry = LEFT$(entry, LEN(entry) - 1)
        ELSEIF LEN(kk) = 1 THEN
            chcode = ASC(kk)
            IF chcode >= 48 AND chcode <= 57 AND LEN(entry) < 2 THEN entry = entry + kk
        END IF
    LOOP
END FUNCTION

' The d20 face strip under the bar: twenty cells in the bar's own coordinates, each shaded
' by the zone that face scores, with the numeric ranges spelled out underneath.
'
' It has to be drawn in the SAME gx/gw the bar uses, or the promise the strip makes ("roll a
' 12 and you land in the purple") is a lie -- the WYSIWYG rule that governs the zones governs
' this too.
SUB DrawGaugeDiceStrip (k AS GAUGEK, entry AS STRING, msg AS STRING)
    DIM bx AS INTEGER, bw AS INTEGER, by AS INTEGER
    DIM gx AS INTEGER, gw AS INTEGER, sy AS INTEGER, striph AS INTEGER
    DIM f AS INTEGER, zn AS INTEGER, x1 AS INTEGER, x2 AS INTEGER
    DIM kol AS _UNSIGNED LONG, lbl AS STRING
    bx = 18: bw = 96: by = 16
    gx = (bx + 6) * CW: gw = (bw - 12) * CW
    sy = (by + 15) * CH: striph = CH - 2                     ' just under the bar (bar ends at by+14)
    _DEST CANVAS
    ' This draws AFTER DrawGaugeEx has restored the fill mode, so it has to opt in again or its
    ' four text lines stamp dark cells across the panel art the gauge is sitting on.
    IF UiFramed%(UIF_GAUGE) THEN _PRINTMODE _KEEPBACKGROUND
    FOR f = 1 TO 20
        x1 = gx + INT(((f - 1) / 20) * gw)
        x2 = gx + INT((f / 20) * gw) - 2
        zn = GaugeZoneAt%(k, GaugeDieP!(f, 20))
        SELECT CASE zn
            CASE 2: kol = Thm~&("gauge.zone.crit", _RGB32(&HA6, &H66, &HCE))
            CASE 1: kol = Thm~&("gauge.zone.hit", _RGB32(&H2E, &HA0, &H55))
            CASE ELSE: kol = Thm~&("gauge.zone.miss", _RGB32(&H33, &H3B, &H33))
        END SELECT
        LINE (x1, sy)-(x2, sy + striph), kol, BF
    NEXT f
    ' Spell the ranges out as text as well as colour: at 20 cells across a 84-column bar each
    ' face is ~4 pixels, which is enough to see a band and not enough to count to fourteen.
    ' Where the fuse bar would be in the timed form. Same box geometry on purpose -- the two
    ' presentations should read as one widget -- so the space is explained rather than left blank.
    COLOR CYANU, BOXBG: PrintCentered by + 5, "the bar is STILL -- your roll decides where the marker lands"
    COLOR GREY, BOXBG: PrintCentered by + 17, "your d20:   " + GaugeRangeText$(k)
    COLOR YELLOWU, BOXBG: PrintCentered by + 20, "roll it and type the number:  " + entry + "_"
    IF LEN(msg) > 0 THEN
        COLOR REDU, BOXBG: PrintCentered by + 21, msg
    ELSE
        COLOR BOXBG, BOXBG: PrintCentered by + 21, SPACE$(44)
    END IF
    _PRINTMODE _FILLBACKGROUND
END SUB

' "CRIT 10-11   HIT 8-13   else MISS" -- built by WALKING the faces rather than by inverting
' the zone arithmetic, so it cannot disagree with the strip drawn directly above it.
FUNCTION GaugeRangeText$ (k AS GAUGEK)
    DIM f AS INTEGER, zn AS INTEGER
    DIM clo AS INTEGER, chi AS INTEGER, hlo AS INTEGER, hhi AS INTEGER
    FOR f = 1 TO 20
        zn = GaugeZoneAt%(k, GaugeDieP!(f, 20))
        IF zn = 2 THEN
            IF clo = 0 THEN clo = f
            chi = f
        END IF
        IF zn >= 1 THEN
            IF hlo = 0 THEN hlo = f
            hhi = f
        END IF
    NEXT f
    DIM o AS STRING
    IF clo > 0 THEN o = "CRIT " + RangeStr$(clo, chi)
    IF hlo > 0 AND (hlo < clo OR hhi > chi) THEN
        IF LEN(o) > 0 THEN o = o + "    "
        o = o + "HIT " + RangeStr$(hlo, hhi)
    END IF
    IF LEN(o) = 0 THEN o = "no zone -- any roll misses" ELSE o = o + "    else MISS"
    GaugeRangeText$ = o
END FUNCTION

FUNCTION RangeStr$ (lo AS INTEGER, hi AS INTEGER)
    IF lo = hi THEN RangeStr$ = _TRIM$(STR$(lo)) ELSE RangeStr$ = _TRIM$(STR$(lo)) + "-" + _TRIM$(STR$(hi))
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
'
' WYSIWYG IS SACRED (GAUGE.bas principle #3): the bands MUST be centred on k.zc, the
' roaming zone centre GaugeScore% measures against -- not on the middle of the bar.
' This drew them at a fixed 0.5 for a long time, which meant SECOND WIND and CRIT
' FLOURISH scored against a sweet spot that was somewhere else entirely: landing dead
' centre in the drawn purple usually resolved as a plain hit or an outright miss. It
' takes the whole GAUGEK now (as FightDrawGauge already did) so no caller can pick out
' the widths and silently leave the centre behind again.
SUB DrawGauge (title AS STRING, prompt AS STRING, swMode AS INTEGER, k AS GAUGEK, fuseFrac AS SINGLE)
    DrawGaugeEx title, prompt, swMode, k, fuseFrac, -1, -1
END SUB

' As DrawGauge, but the fuse bar and the marker can each be suppressed.
'
' The real-dice gauge needs both off: there is no fuse to show, and drawing a full one implies
' a countdown that is not running; and before a roll is typed there is no marker position to
' show -- leaving the sweep's last one there points at a number the player did not choose.
SUB DrawGaugeEx (title AS STRING, prompt AS STRING, swMode AS INTEGER, k AS GAUGEK, fuseFrac AS SINGLE, showfuse AS INTEGER, showmarker AS INTEGER)
    DIM bx AS INTEGER, bw AS INTEGER, by AS INTEGER, bh AS INTEGER
    DIM gx AS INTEGER, gw AS INTEGER, gy AS INTEGER, gh AS INTEGER, mxp AS INTEGER
    DIM fx AS INTEGER, fw AS INTEGER, fcol AS _UNSIGNED LONG
    bx = 18: bw = 96: by = 16: bh = 22
    _DEST CANVAS
    ' Grown outward, like every other retrofitted panel: the gauge's whole body (the fuse bar,
    ' the zone bar, the legend, the prompt) is laid out against `by + N` and must not move.
    DIM gfx AS INTEGER, gfy AS INTEGER, gfw AS INTEGER, gfh AS INTEGER, gframed AS INTEGER
    IF UiFramed%(UIF_GAUGE) THEN
        FrameOutset UIF_GAUGE, bx, by, bw, bh, gfx, gfy, gfw, gfh
        IF gfx >= 0 AND gfy >= 0 AND gfx + gfw <= SW AND gfy + gfh <= SH THEN gframed = UiPanel%(UIF_GAUGE, gfx, gfy, gfw, gfh)
    END IF
    IF NOT gframed THEN
        LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
        LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), REDU, B
    END IF
    IF gframed THEN _PRINTMODE _KEEPBACKGROUND
    COLOR YELLOWU, BOXBG: PrintCentered by + 2, "-=  " + title + "  =-"
    ' fuse countdown
    IF showfuse THEN
        fx = (bx + 6) * CW: fw = (bw - 12) * CW
        LINE (fx, (by + 5) * CH)-(fx + fw, (by + 6) * CH - 4), Thm~&("fuse.track", _RGB32(40, 40, 46)), BF
        IF fuseFrac > 0.35 THEN fcol = Thm~&("fuse.ok", _RGB32(170, 150, 70)) ELSE fcol = Thm~&("fuse.urgent", _RGB32(220, 60, 50))
        LINE (fx, (by + 5) * CH)-(fx + INT(fw * fuseFrac), (by + 6) * CH - 4), fcol, BF
    END IF
    ' the gauge bar with layered zones, centred on the LIVE zone centre k.zc
    gx = (bx + 6) * CW: gw = (bw - 12) * CW: gy = (by + 11) * CH: gh = 3 * CH
    LINE (gx, gy)-(gx + gw, gy + gh), Thm~&("gauge.zone.miss", _RGB32(&H33, &H3B, &H33)), BF                                  ' dark = miss/fall
    IF swMode = 0 THEN LINE (gx + INT((k.zc - k.ehit) * gw), gy)-(gx + INT((k.zc + k.ehit) * gw), gy + gh), Thm~&("gauge.zone.hit", _RGB32(&H2E, &HA0, &H55)), BF   ' green = hit (crit flourish only)
    LINE (gx + INT((k.zc - k.ecrit) * gw), gy)-(gx + INT((k.zc + k.ecrit) * gw), gy + gh), Thm~&("gauge.zone.crit", _RGB32(&HA6, &H66, &HCE)), BF ' purple = crit / second wind
    ' the sweeping marker
    IF showmarker THEN
        mxp = gx + INT(k.p * gw)
        LINE (mxp - 1, gy - 8)-(mxp + 2, gy + gh + 8), Thm~&("gauge.marker", _RGB32(&HF0, &HEC, &HD0)), BF
    END IF
    DIM leg AS STRING
    ' The legend must state the SAME mapping CritFlourish% pays out (crit 2 / hit 1 / miss 0).
    IF swMode THEN leg = "purple = SECOND WIND" ELSE leg = "purple (centre) = +2 dice     green = +1 die     dark = +0"
    COLOR GREY, BOXBG: PrintCentered by + 16, leg
    COLOR CYANU, BOXBG: PrintCentered by + 18, prompt
    _PRINTMODE _FILLBACKGROUND                   ' the strip/lock overlays draw after this
END SUB

' Overlay a coloured band at the locked position during the result freeze.
SUB DrawGaugeLock (p AS SINGLE, z AS INTEGER)
    DIM gx AS INTEGER, gw AS INTEGER, gy AS INTEGER, gh AS INTEGER, mxp AS INTEGER, col AS _UNSIGNED LONG
    gx = 24 * CW: gw = 84 * CW: gy = 27 * CH: gh = 3 * CH
    mxp = gx + INT(p * gw)
    col = Thm~&("gauge.tick.miss", _RGB32(&H70, &H80, &H5C))
    IF z = 2 THEN col = Thm~&("gauge.tick.crit", _RGB32(&HFF, &HD2, &H50))
    IF z = 1 THEN col = Thm~&("gauge.tick.hit", _RGB32(&HEB, &HF0, &HF5))
    LINE (mxp - 2, gy - 10)-(mxp + 3, gy + gh + 10), col, BF
END SUB

' SECOND WIND: one clutch attempt on a downing blow. Nail the CRIT zone -> rise in
' place with 1d6 HP. Anything else (or the fuse) -> the save fails. Returns TRUE on the
' rise (player_hp is set); the caller then simply keeps fighting.
FUNCTION SecondWind% (mon AS STRING, depth AS INTEGER, skill AS INTEGER)
    DIM z AS INTEGER, hp AS INTEGER
    z = GaugeLock%("FIGHT FOR YOUR LIFE", "SPACE in the PURPLE to rise -- one chance!", -1, depth, skill)
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
FUNCTION CritFlourish% (mon AS STRING, depth AS INTEGER, skill AS INTEGER)
    DIM z AS INTEGER, xn AS INTEGER
    z = GaugeLock%("CRITICAL FLOURISH!", "SPACE to land the follow-through", 0, depth, skill)
    xn = 0
    IF z = 2 THEN xn = 2
    IF z = 1 THEN xn = 1
    CritFlourish% = 0
    IF xn > 0 THEN CritFlourish% = GameRoll(xn, player_dmgdie, 0, "CRIT FLOURISH -- +" + _TRIM$(STR$(xn)) + " dice")
END FUNCTION


' ENDURE: a monster has landed the biggest blow its die allows. Nail the CRIT zone and you
' brace into it for HALF damage; anything else and you take it whole.
'
' Offered ONLY to a character with a CON bonus, which is the point -- this is the moment CON
' stops being "a few more HP per level" and becomes a thing you DO. A frail character simply
' never sees this prompt, and that asymmetry is the reward.
'
' Returns the damage to actually apply.
FUNCTION EndureDamage% (mon AS STRING, dmg AS INTEGER, depth AS INTEGER, skill AS INTEGER)
    DIM z AS INTEGER, half AS INTEGER
    EndureDamage% = dmg
    z = GaugeLock%("BRACE!", "SPACE in the PURPLE to take it on your guard", -1, depth, skill)
    IF z <> 2 THEN
        Banner "It lands full force.", "You had no answer for that one.   [ press any key ]"
        WaitKey
        EXIT FUNCTION
    END IF
    half = dmg \ 2
    IF half < 1 THEN half = 1                    ' braced or not, a maximum blow still hurts
    Sfx "saveok"
    Banner "** BRACED! **", "You turn your shoulder into it -- " + _TRIM$(STR$(dmg)) + " becomes " + _TRIM$(STR$(half)) + ".   [ press any key ]"
    WaitKey
    EndureDamage% = half
END FUNCTION


' MAGIC FLOURISH: the same gesture as a crit follow-through, shaping a spell instead of a
' swing. Crit zone = +2 dice, hit = +1, miss/timeout = +0 -- deliberately the SAME payout as
' CritFlourish, so the player learns one gauge rather than two similar ones.
'
' The bonus dice are d6, matching how spells roll, not the weapon die: a Wizard shaping a
' fireball is making the FIRE bigger, not swinging harder.
FUNCTION MagicFlourish% (mon AS STRING, depth AS INTEGER, skill AS INTEGER, elem AS STRING)
    DIM z AS INTEGER, xn AS INTEGER
    z = GaugeLock%("SHAPE THE " + UCASE$(elem) + "!", "SPACE to pour more into it", 0, depth, skill)
    xn = 0
    IF z = 2 THEN xn = 2
    IF z = 1 THEN xn = 1
    MagicFlourish% = 0
    IF xn > 0 THEN MagicFlourish% = GameRoll(xn, 6, 0, "MAGIC FLOURISH -- +" + _TRIM$(STR$(xn)) + "d6")
END FUNCTION


' CONFIRM: a maximum-damage blow that was NOT a natural 20. Nail the crit zone and it is
' upgraded to a critical -- the damage doubles.
'
' Confirmed crits get NO flourish (the plan is explicit): only a real natural 20 earns the
' follow-through. Otherwise max damage would be strictly better than a nat 20, which is
' backwards -- this is a consolation prize, not a second jackpot.
'
' Returns the damage to apply.
FUNCTION ConfirmCrit% (mon AS STRING, dmg AS INTEGER, depth AS INTEGER, skill AS INTEGER)
    DIM z AS INTEGER
    ConfirmCrit% = dmg
    z = GaugeLock%("CONFIRM THE CRIT!", "SPACE in the PURPLE -- turn it into a critical", -1, depth, skill)
    IF z <> 2 THEN EXIT FUNCTION
    Sfx "crit"
    ConfirmCrit% = dmg * 2
END FUNCTION
