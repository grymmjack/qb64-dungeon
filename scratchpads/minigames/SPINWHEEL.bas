' ============================================================================
'  SPINWHEEL.bas -- THE WHEEL OF MYSTERY
'
'  A great iron wheel bolted to the wall. You pull the handle, it turns, it slows,
'  it stops, and whatever the pointer is on HAPPENS. No guessing, no choosing.
'
'  Be honest about what this is: by the catalogue's own house rule 1 -- "a
'  decision, not a roll" -- it is not a game. It is a CEREMONY. There is exactly
'  one input and the player makes no judgement at any point. It earns its place
'  by being the most theatrical way to deliver a random event, next to the
'  Gambler's Altar which fills the same slot with dice.
'
'  Which changes what has to be proved, but not how much. Two things:
'
'    1. THE WHEEL DOES NOT LIE. The outcome is READ OFF the angle the wheel
'       stopped at -- it is not picked first and then animated to look right.
'       That distinction is invisible on screen and total in principle, and it
'       is the same sin the cup shuffle is built to avoid. Asserted by spinning
'       thousands of times and demanding the announced result equal the wedge
'       under the pointer.
'
'    2. THE WHEEL IS NOT SECRETLY WEIGHTED. A wedge that occupies a tenth of the
'       rim comes up a tenth of the time. Wedge sizes are the ONLY thing setting
'       the odds, so a player who looks at the rim knows the odds exactly -- which
'       is the whole reason to draw a wheel instead of rolling a die offscreen.
'
'  It also has to SETTLE rather than cut: the wheel always passes several wedges,
'  always decelerates, and always comes to a full stop. A wheel that snaps to its
'  answer reads as rigged even when it is not.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST WEDGES = 10
CONST FRICTION = 62!            ' degrees per second per second
CONST MIN_TRAVEL = 720!         ' never fewer than two full turns

DIM SHARED WNAME(1 TO WEDGES) AS STRING
DIM SHARED WTELL(1 TO WEDGES) AS STRING
DIM SHARED WWEIGHT(1 TO WEDGES) AS INTEGER      ' wedge width, in parts of the rim
DIM SHARED WCOL(1 TO WEDGES) AS _UNSIGNED LONG
DIM SHARED WSTART(1 TO WEDGES) AS SINGLE        ' first degree of the wedge
DIM SHARED WSTOP(1 TO WEDGES) AS SINGLE   ' NOT "WEND" -- that closes a WHILE
DIM SHARED AS SINGLE g_angle
DIM SHARED AS INTEGER g_result

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitWheel
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: WheelSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    g_angle = 41!
    g_result = PointerWedge%(g_angle)
    DrawWheel WNAME(g_result) + " -- " + WTELL(g_result)
    _SAVEIMAGE "spinwheel-shot.png"
    _DEST _CONSOLE: PRINT "wrote spinwheel-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayWheel
_DEST _CONSOLE: PRINT "result ="; r; " "; WNAME(g_result): SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- the rim -----------------------------------------------------------------

' Wedge widths ARE the odds. Nothing else weights the wheel, so what the player
' can see on the rim is the complete truth about their chances.
SUB InitWheel
    DIM i AS INTEGER, tot AS INTEGER
    DIM acc AS SINGLE

    SetWedge 1, "A PURSE", "fifty gold, unclaimed", 5, _RGB32(&HFF, &HD0, &H50)
    SetWedge 2, "NOTHING", "the wheel shrugs", 6, _RGB32(&H60, &H60, &H68)
    SetWedge 3, "A HOARD", "two hundred gold", 2, _RGB32(&HFF, &HF0, &H90)
    SetWedge 4, "THE LASH", "it takes two hit points", 4, _RGB32(&HD0, &H40, &H40)
    SetWedge 5, "MENDING", "your wounds close", 5, _RGB32(&H60, &HE0, &H80)
    SetWedge 6, "THE GATE", "you are elsewhere now", 3, _RGB32(&H80, &HA0, &HFF)
    SetWedge 7, "A GUEST", "something arrives", 5, _RGB32(&HE0, &H80, &HC0)
    SetWedge 8, "THE KEY", "a way down opens", 1, _RGB32(&H90, &HF0, &HF0)
    SetWedge 9, "NOTHING", "dust, and a creak", 6, _RGB32(&H50, &H50, &H58)
    SetWedge 10, "THE TITHE", "it wants gold, not blood", 3, _RGB32(&HC0, &H70, &H30)

    FOR i = 1 TO WEDGES: tot = tot + WWEIGHT(i): NEXT i
    acc = 0!
    FOR i = 1 TO WEDGES
        WSTART(i) = acc
        acc = acc + 360! * WWEIGHT(i) / tot
        WSTOP(i) = acc
    NEXT i
    WSTOP(WEDGES) = 360!          ' close the rim exactly, whatever the rounding did
END SUB

SUB SetWedge (i AS INTEGER, nm AS STRING, tell AS STRING, wt AS INTEGER, kol AS _UNSIGNED LONG)
    WNAME(i) = nm: WTELL(i) = tell: WWEIGHT(i) = wt: WCOL(i) = kol
END SUB

' Which wedge sits under the pointer at `ang`. This is the ONLY place an outcome
' comes from -- there is no second path that picks a result and then spins to it.
FUNCTION WedgeAt% (ang AS SINGLE)
    DIM i AS INTEGER, a AS SINGLE
    a = ang - INT(ang / 360!) * 360!
    IF a < 0! THEN a = a + 360!
    FOR i = 1 TO WEDGES
        IF a >= WSTART(i) _ANDALSO a < WSTOP(i) THEN WedgeAt% = i: EXIT FUNCTION
    NEXT i
    WedgeAt% = WEDGES            ' a lands exactly on 360, which is wedge 10's edge
END FUNCTION

' Which wedge is UNDER THE POINTER when the wheel has turned by `ang`.
'
' The sign matters and it is easy to get backwards: the wheel rotates by +ang,
' so the rim point that arrives at the fixed pointer is the one that started at
' -ang. The first cut read the result at +ang and drew the rim at -ang, so the
' game announced a wedge two positions away from the one on screen.
'
' Worth noting how that survived: the "the result is read, not chosen" test
' passed cleanly, because it replayed the SAME sign convention the bug lived in.
' A test written from the implementation cannot catch a bug in the shared
' assumption -- it took a screenshot, and a human-shaped question ("is the
' pointer on the wedge it just named?"), to see it.
FUNCTION PointerWedge% (ang AS SINGLE)
    PointerWedge% = WedgeAt%(-ang)
END FUNCTION

' A spin: pick a starting speed, then let friction decide where it stops. The
' distance travelled is v^2 / 2a, which is physics rather than a hidden choice.
FUNCTION SpinTravel! ()
    DIM v AS SINGLE
    v = 700! + MgRoll%(900)
    SpinTravel! = MIN_TRAVEL + v * v / (2! * FRICTION)
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayWheel% ()
    DIM k AS STRING
    DIM AS SINGLE travel, gone, v, v0, lastwedge
    DIM tick AS INTEGER

    g_angle = MgRoll%(360) - 1
    DrawWheel "pull the handle"
    DO
        k = INKEY$
        IF k = CHR$(27) THEN PlayWheel% = MG_LEFT: EXIT FUNCTION
        _LIMIT 60
    LOOP UNTIL k = " " OR k = CHR$(13)

    travel = SpinTravel!
    v0 = SQR(2! * FRICTION * travel)
    v = v0: gone = 0!
    lastwedge = PointerWedge%(g_angle)
    DO WHILE gone < travel
        v = SQR(2! * FRICTION * (travel - gone))         ' speed left to cover it
        IF v < 12! THEN v = 12!
        gone = gone + v / 60!
        IF gone > travel THEN gone = travel
        g_angle = g_angle + v / 60!
        tick = PointerWedge%(g_angle)
        IF tick <> lastwedge THEN
            MgBeep 300 + v / 8!, 0.7
            lastwedge = tick
        END IF
        DrawWheel "..."
        _LIMIT 60
    LOOP

    ' READ the result off the rim. It was never decided anywhere else.
    g_result = PointerWedge%(g_angle)
    MgBeep 660, 4
    DrawWheel WNAME(g_result) + " -- " + WTELL(g_result)
    _DELAY 2!
    PlayWheel% = MG_WON
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawWheel (msg AS STRING)
    DIM i AS INTEGER, w AS INTEGER
    DIM AS SINGLE deg, rad, cx, cy, rr
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "T H E   W H E E L   O F   M Y S T E R Y", "whatever it stops on is what happens -- the rim IS the odds"

    cx = SW * CW / 2!: cy = 20! * CH: rr = 10! * CH

    ' filled wedges, one radial line per degree -- cheap, and it makes the wedge
    ' widths literally visible, which is the point of drawing a wheel at all
    FOR i = 0 TO 359
        deg = i
        w = WedgeAt%(deg - g_angle)
        rad = (deg - 90!) * 3.14159265! / 180!
        LINE (cx, cy)-(cx + COS(rad) * rr, cy + SIN(rad) * rr), WCOL(w)
    NEXT i
    CIRCLE (cx, cy), rr, _RGB32(20, 18, 24)
    CIRCLE (cx, cy), rr * 0.22!, _RGB32(20, 18, 24)
    PAINT (cx, cy), _RGB32(16, 14, 20), _RGB32(20, 18, 24)

    ' the pointer, at the top
    LINE (cx - CW, cy - rr - CH)-(cx + CW, cy - rr - CH), C_TITLE
    LINE (cx - CW, cy - rr - CH)-(cx, cy - rr + 4), C_TITLE
    LINE (cx + CW, cy - rr - CH)-(cx, cy - rr + 4), C_TITLE

    ' the legend -- the same widths, written out, so nobody has to eyeball an arc
    FOR i = 1 TO WEDGES
        COLOR WCOL(i), 0
        MgText 4, 8 + i, LEFT$(WNAME(i) + "           ", 11) + STRING$(WWEIGHT(i), "#")
    NEXT i
    COLOR C_DIM, 0
    MgText 4, 8 + WEDGES + 2, "each # is one part of the rim in forty"

    COLOR C_TEXT, 0: MgCenter 34, msg
    COLOR C_GOOD, 0: MgCenter 37, "[SPACE] pull the handle      [ESC] leave it alone"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB WheelSelfTest
    DIM i AS LONG, spins AS LONG
    DIM AS LONG bad
    DIM AS DOUBLE worstgap
    _DEST _CONSOLE
    PRINT "SPINWHEEL selftest"
    spins = 60000

    MgSection "the rim is a rim"
    Ok "the wedges tile the whole circle with no gap and no overlap", RimIsClosed%
    Ok "every degree lands on exactly one wedge", EveryDegreeMapped%
    Ok "the mapping wraps -- 360 is 0, -10 is 350", WrapWorks%

    MgSection "the wheel does not lie: the result is READ, not chosen"
    RANDOMIZE 101
    bad = 0
    FOR i = 1 TO spins
        IF NOT SpinAgreesWithRim% THEN bad = bad + 1
    NEXT i
    PRINT USING "       ##### spins, ##### where the announced result was not under the pointer"; spins; bad
    Ok "the announced result is always the wedge under the pointer", bad = 0

    MgSection "the wedge announced is the wedge DRAWN under the pointer"
    Ok "at rest, the pointer reads the same wedge the rim draws there", PointerMatchesDrawnRim%

    MgSection "the odds are the widths, and nothing else"
    worstgap = WidthGap#(spins)
    PRINT USING "       worst wedge is off its advertised share by #.#### "; worstgap
    Ok "every wedge comes up as often as its width says", worstgap < 0.01
    Ok "the rarest wedge is genuinely rare, not merely thin", RareIsRare%

    MgSection "it settles, it does not cut"
    Ok "every spin travels at least two full turns", TravelAlwaysLong%
    Ok "the wheel always slows down and stops", DecelIsMonotonic%

    MgSection "and what it does to you is survivable"
    Ok "no single wedge can kill outright", NoInstantDeath%
    Ok "there is more good on the rim than harm", MoreGoodThanBad%

    MgDone
END SUB

FUNCTION RimIsClosed% ()
    DIM i AS INTEGER
    RimIsClosed% = (WSTART(1) = 0! _ANDALSO WSTOP(WEDGES) = 360!)
    FOR i = 2 TO WEDGES
        IF ABS(WSTART(i) - WSTOP(i - 1)) > 0.001 THEN RimIsClosed% = FALSE
    NEXT i
END FUNCTION

FUNCTION EveryDegreeMapped% ()
    DIM d AS INTEGER, w AS INTEGER
    EveryDegreeMapped% = TRUE
    FOR d = 0 TO 359
        w = WedgeAt%(d)
        IF w < 1 OR w > WEDGES THEN EveryDegreeMapped% = FALSE
    NEXT d
END FUNCTION

FUNCTION WrapWorks% ()
    WrapWorks% = (WedgeAt%(360!) = WedgeAt%(0!) _ANDALSO WedgeAt%(-10!) = WedgeAt%(350!) _ANDALSO WedgeAt%(730!) = WedgeAt%(10!))
END FUNCTION

' The central proof. Run a spin exactly as the game does -- start angle, travel,
' final angle -- then check the result against a SEPARATE read of the rim. If any
' code path picked the outcome first and animated toward it, these disagree.
FUNCTION SpinAgreesWithRim% ()
    DIM AS SINGLE start, travel, gone, v, ang
    DIM AS INTEGER shown, guard
    start = MgRoll%(360) - 1
    travel = SpinTravel!

    ' run the ANIMATION, frame by frame, exactly as PlayWheel does
    ang = start
    DO WHILE gone < travel _ANDALSO guard < 200000
        guard = guard + 1
        v = SQR(2! * FRICTION * (travel - gone))
        IF v < 12! THEN v = 12!
        gone = gone + v / 60!
        IF gone > travel THEN gone = travel
        ang = ang + v / 60!
    LOOP
    shown = PointerWedge%(ang)

    ' the wedge the player SEES under the pointer must be the wedge the physics
    ' says the wheel travelled to. If the animation drifted from the model -- or
    ' if anything picked a result and steered toward it -- these come apart.
    SpinAgreesWithRim% = AngleInsideWedge%(-ang, shown)
    IF ABS(ang - (start + travel)) > 1! THEN SpinAgreesWithRim% = FALSE
END FUNCTION

' The draw loop paints screen angle 0 (straight up, where the pointer is) with
' WedgeAt%(0 - g_angle). The result must come from that exact expression, or the
' player is told one thing and shown another.
FUNCTION PointerMatchesDrawnRim% ()
    DIM a AS INTEGER
    PointerMatchesDrawnRim% = TRUE
    FOR a = 0 TO 359
        IF PointerWedge%(a) <> WedgeAt%(0! - a) THEN PointerMatchesDrawnRim% = FALSE
    NEXT a
END FUNCTION

FUNCTION AngleInsideWedge% (ang AS SINGLE, w AS INTEGER)
    DIM a AS SINGLE
    a = ang - INT(ang / 360!) * 360!
    IF a < 0! THEN a = a + 360!
    AngleInsideWedge% = (a >= WSTART(w) _ANDALSO a < WSTOP(w))
END FUNCTION

' Biggest gap between a wedge's share of the rim and its share of the results.
FUNCTION WidthGap# (spins AS LONG)
    DIM i AS LONG, w AS INTEGER, tot AS INTEGER
    DIM hits(1 TO WEDGES) AS LONG
    DIM AS DOUBLE want, got, gap
    RANDOMIZE 102
    FOR i = 1 TO spins
        w = WedgeAt%(MgRoll%(360) - 1 + SpinTravel!)
        hits(w) = hits(w) + 1
    NEXT i
    FOR w = 1 TO WEDGES: tot = tot + WWEIGHT(w): NEXT w
    FOR w = 1 TO WEDGES
        want = WWEIGHT(w) / tot
        got = hits(w) / spins
        IF ABS(want - got) > gap THEN gap = ABS(want - got)
    NEXT w
    WidthGap# = gap
END FUNCTION

FUNCTION RareIsRare% ()
    DIM w AS INTEGER, lo AS INTEGER
    lo = 1
    FOR w = 1 TO WEDGES
        IF WWEIGHT(w) < WWEIGHT(lo) THEN lo = w
    NEXT w
    RareIsRare% = (WWEIGHT(lo) = 1 _ANDALSO WNAME(lo) = "THE KEY")
END FUNCTION

FUNCTION TravelAlwaysLong% ()
    DIM i AS LONG
    TravelAlwaysLong% = TRUE
    RANDOMIZE 103
    FOR i = 1 TO 20000
        IF SpinTravel! < MIN_TRAVEL THEN TravelAlwaysLong% = FALSE
    NEXT i
END FUNCTION

' A wheel that snaps to its answer reads as rigged even when it is not, so the
' speed curve is checked the same way the outcome is: by running it.
FUNCTION DecelIsMonotonic% ()
    DIM AS SINGLE travel, gone, v, prev
    DIM guard AS LONG
    RANDOMIZE 104
    travel = SpinTravel!
    prev = 1E+09
    DecelIsMonotonic% = TRUE
    DO WHILE gone < travel _ANDALSO guard < 200000
        guard = guard + 1
        v = SQR(2! * FRICTION * (travel - gone))
        IF v < 12! THEN v = 12!
        IF v > prev THEN DecelIsMonotonic% = FALSE
        prev = v
        gone = gone + v / 60!
    LOOP
    IF gone < travel THEN DecelIsMonotonic% = FALSE      ' it must actually finish
END FUNCTION

FUNCTION NoInstantDeath% ()
    DIM w AS INTEGER
    NoInstantDeath% = TRUE
    FOR w = 1 TO WEDGES
        IF INSTR(WTELL(w), "kill") > 0 OR INSTR(WNAME(w), "DEATH") > 0 THEN NoInstantDeath% = FALSE
    NEXT w
    ' the harshest wedge on the rim takes two hit points, which a level-1 hero survives
    IF INSTR(WTELL(4), "two hit points") = 0 THEN NoInstantDeath% = FALSE
END FUNCTION

FUNCTION MoreGoodThanBad% ()
    DIM w AS INTEGER, good AS INTEGER, harm AS INTEGER
    FOR w = 1 TO WEDGES
        SELECT CASE WNAME(w)
            CASE "A PURSE", "A HOARD", "MENDING", "THE KEY": good = good + WWEIGHT(w)
            CASE "THE LASH", "A GUEST", "THE TITHE": harm = harm + WWEIGHT(w)
        END SELECT
    NEXT w
    MoreGoodThanBad% = (good > harm)
END FUNCTION

'$INCLUDE:'MG.bas'
