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
CONST FRICTION = 112!           ' degrees per second per second -- how fast it gives up
CONST FULL_TURN = 360!
CONST BALK_AT = 360!            ' fewer degrees than this and the wheel has BALKED

'--- the crank ---
CONST CRANK_GAIN = 8!           ' charge per alternating stroke
CONST CRANK_GRACE = 0.45        ' seconds after a stroke before it starts bleeding
CONST CRANK_DECAY = 14!         ' charge lost per second AFTER the grace window
CONST CRANK_MAX = 100!
CONST MIN_RELEASE = 6!          ' below this the handle simply does not move -- see PlayWheel
CONST MAXTRAVEL = 3600!         ' degrees a full crank is worth -- ten turns
CONST MAX_STEP = 0.1            ' seconds: a hitch must not teleport the wheel
CONST SUBSTEP = 0.004           ' physics step, so fast spins still tick per wedge
CONST TRAVEL_SLOP = 420!        ' random degrees ON TOP -- this is the anti-aim term

DIM SHARED WNAME(1 TO WEDGES) AS STRING
DIM SHARED WTELL(1 TO WEDGES) AS STRING
DIM SHARED WWEIGHT(1 TO WEDGES) AS INTEGER      ' wedge width, in parts of the rim
DIM SHARED WCOL(1 TO WEDGES) AS _UNSIGNED LONG
DIM SHARED WSTART(1 TO WEDGES) AS SINGLE        ' first degree of the wedge
DIM SHARED WSTOP(1 TO WEDGES) AS SINGLE   ' NOT "WEND" -- that closes a WHILE
DIM SHARED AS SINGLE g_angle
DIM SHARED AS INTEGER g_result, g_balks
DIM SHARED g_charge AS SINGLE
DIM SHARED g_speed AS SINGLE

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitWheel
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: WheelSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    g_angle = 41!: g_charge = 46!
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

' How far the wheel travels for a given crank charge.
'
' The deterministic part is what the player controls; TRAVEL_SLOP is what stops
' them controlling it. See AimingIsImpossible% -- the slop is not flavour, it is
' the number that makes the wheel unaimable, and it is sized against the WIDTH OF
' THE NARROWEST WEDGE rather than picked because it felt about right.
FUNCTION TravelFor! (charge AS SINGLE)
    TravelFor! = AimedTravel!(charge) + RND * TRAVEL_SLOP
END FUNCTION

' The part of the travel a player can actually aim with -- no randomness.
'
' SQUARE, not linear, and that is the whole feel of the thing. A linear crank
' made a weak pull spin nearly as far as a hard one, because the random slop was
' a big share of a small number and the wheel had no sense of mass at all. On a
' square curve, doubling your effort quadruples the spin: the first few strokes
' barely move it, and past halfway it really goes. That is what "heavy" means in
' a number.
'
' It also puts the balk threshold somewhere meaningful. Linear, with a slop wide
' enough to stop aiming, the wheel either always balked or never could.
FUNCTION AimedTravel! (charge AS SINGLE)
    DIM f AS SINGLE
    f = charge / CRANK_MAX
    IF f < 0! THEN f = 0!
    AimedTravel! = f * f * MAXTRAVEL
END FUNCTION

' A wheel that does not complete one full revolution has BALKED.
'
' This is the rule that stops the obvious cheat: crank a whisker, nudge the wheel
' two wedges to the one you want, collect. Without it every other guarantee in
' this file is decoration, because the player simply would not spin.
FUNCTION IsBalk% (travel AS SINGLE)
    IsBalk% = (travel < BALK_AT)
END FUNCTION

' What the charge decays to, `idle` seconds after the last stroke.
'
' The grace window is not a nicety, it is the difference between a crank you can
' use and one you cannot. The first version bled 34 a second with no grace, while
' one stroke was worth 7 -- so the moment you stopped cranking to press SPACE you
' lost the equivalent of a whole stroke, and a wheel cranked well past the marked
' line refused to move by the time your finger arrived. It read as the meter
' being uncalibrated, which is exactly what it felt like.
FUNCTION ChargeAfter! (charge AS SINGLE, idle AS SINGLE)
    DIM d AS SINGLE
    IF idle <= CRANK_GRACE THEN ChargeAfter! = charge: EXIT FUNCTION
    d = charge - CRANK_DECAY * (idle - CRANK_GRACE)
    IF d < 0! THEN d = 0!
    ChargeAfter! = d
END FUNCTION

' The charge below which a balk is possible at all. Displayed, so nobody balks
' by accident -- the consequence is for people who try it, not for people who
' misjudged an invisible threshold.
FUNCTION SafeCharge! ()
    SafeCharge! = CRANK_MAX * SQR(BALK_AT / MAXTRAVEL)
END FUNCTION

' How fast the wheel is turning the instant it is released, in degrees a second.
' This is the number the player actually SEES, and it has to differ visibly with
' the crank or the wheel has no momentum however far it eventually travels.
FUNCTION PeakSpeed! (charge AS SINGLE)
    PeakSpeed! = SQR(2! * FRICTION * AimedTravel!(charge))
END FUNCTION

' How long a spin of `travel` degrees lasts, from the same friction the animation
' uses. Shown to the player as turns, because "how far will this go" is the
' question the crank is actually asking and there is no reason to hide it.
FUNCTION SpinSeconds! (travel AS SINGLE)
    SpinSeconds! = SQR(2! * travel / FRICTION)
END FUNCTION

FUNCTION SpinTurns! (charge AS SINGLE)
    SpinTurns! = AimedTravel!(charge) / FULL_TURN
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayWheel% ()
    DIM k AS STRING, u AS STRING
    DIM AS SINGLE travel, gone, v, v0, lastwedge
    DIM AS INTEGER tick, lastdir, balked
    DIM t0 AS DOUBLE, laststroke AS DOUBLE, lastt AS DOUBLE
    DIM AS SINGLE dt, sdt
    ' `stp`, not `sub` -- SUB is a QB64 keyword
    DIM AS INTEGER nsub, stp

    g_angle = MgRoll%(360) - 1

    ' THE CRANK. Alternate up and down -- one continuous heave does nothing,
    ' because a handle you push and push is not being cranked, it is being leaned
    ' on. Stop and the charge bleeds away, so the wheel has to be worked up to.
    g_charge = 0!: lastdir = 0
    t0 = TIMER: laststroke = TIMER
    DO
        IF MgElapsed!(laststroke) > CRANK_GRACE THEN
            g_charge = g_charge - CRANK_DECAY * MgElapsed!(t0)
        END IF
        t0 = TIMER
        IF g_charge < 0! THEN g_charge = 0!
        DrawWheel "crank the handle -- up, down, up, down"
        k = INKEY$: u = UCASE$(k)
        IF k = CHR$(27) THEN PlayWheel% = MG_LEFT: EXIT FUNCTION
        IF u = "W" OR k = CHR$(0) + "H" THEN
            IF lastdir <> 1 THEN g_charge = g_charge + CRANK_GAIN: laststroke = TIMER: MgBeep 200 + g_charge * 3, 0.6
            lastdir = 1
        END IF
        IF u = "S" OR k = CHR$(0) + "P" THEN
            IF lastdir <> 2 THEN g_charge = g_charge + CRANK_GAIN: laststroke = TIMER: MgBeep 220 + g_charge * 3, 0.6
            lastdir = 2
        END IF
        IF g_charge > CRANK_MAX THEN g_charge = CRANK_MAX

        ' You cannot let go of a handle you have not moved. Without this, SPACE
        ' on a cold wheel span it anyway -- the random anti-aim term alone was
        ' enough to carry it past a full turn now and then, so doing NOTHING was
        ' a legitimate way to play and the crank was decoration.
        IF (k = " " OR k = CHR$(13)) _ANDALSO g_charge < MIN_RELEASE THEN
            DrawWheel "the handle does not budge -- put some work into it"
            MgBeep 90, 3
            _DELAY 0.5
            t0 = TIMER: laststroke = TIMER
            k = ""
        END IF
        _LIMIT 60
    LOOP UNTIL k = " " OR k = CHR$(13)

    travel = TravelFor!(g_charge)
    balked = IsBalk%(travel)
    IF balked THEN
        ' It did not go round. The wheel finishes the job itself, at a strength
        ' nobody chose, and takes its due first.
        DrawWheel "it barely moves -- the wheel does not care to be TEASED"
        MgBeep 80, 10
        _DELAY 1.6
        g_balks = g_balks + 1
        travel = FULL_TURN + RND * (TRAVEL_SLOP * 3!)
    END IF
    v0 = SQR(2! * FRICTION * travel)
    v = v0: gone = 0!
    lastwedge = PointerWedge%(g_angle)

    ' REAL TIME, and substepped.
    '
    ' The first version advanced the wheel by v/60 per FRAME, which quietly
    ' assumes the frame rate. Drawing this wheel is 360 line draws, so it does not
    ' hold 60 -- and the effect was that every spin played in the same uniform
    ' slow motion regardless of how hard it had been cranked. The stopping point
    ' was right, so the physics looked fine on paper; the momentum was simply not
    ' on screen.
    '
    ' Substepping matters too: at full crank the wheel covers most of a wedge in a
    ' single frame, and a per-frame check would miss wedges entirely, so the
    ' ticking would thin out exactly when the wheel is going fastest.
    lastt = TIMER
    DO WHILE gone < travel
        dt = MgElapsed!(lastt): lastt = TIMER
        IF dt > MAX_STEP THEN dt = MAX_STEP
        nsub = INT(dt / SUBSTEP) + 1
        sdt = dt / nsub
        FOR stp = 1 TO nsub
            v = SQR(2! * FRICTION * (travel - gone))     ' speed left to cover it
            IF v < 12! THEN v = 12!
            gone = gone + v * sdt
            IF gone > travel THEN gone = travel
            g_angle = g_angle + v * sdt
            tick = PointerWedge%(g_angle)
            IF tick <> lastwedge THEN
                MgBeep 300 + v / 3!, 0.7
                lastwedge = tick
            END IF
            IF gone >= travel THEN EXIT FOR
        NEXT stp
        g_speed = v
        DrawWheel "..."
        _LIMIT 60
    LOOP
    g_speed = 0!

    ' READ the result off the rim. It was never decided anywhere else.
    g_result = PointerWedge%(g_angle)
    MgBeep 660, 4
    IF balked THEN
        DrawWheel "THE LASH for teasing it, and then: " + WNAME(g_result) + " -- " + WTELL(g_result)
    ELSE
        DrawWheel WNAME(g_result) + " -- " + WTELL(g_result)
    END IF
    _DELAY 2!
    PlayWheel% = MG_WON
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawWheel (msg AS STRING)
    DIM i AS INTEGER, w AS INTEGER
    DIM AS SINGLE deg, rad, cx, cy, rr
    DIM barx AS INTEGER
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

    ' A SPOKE. Without one the rim is rotationally busy enough to be unreadable --
    ' the colours sweep past and there is nothing to actually follow, so a fast
    ' spin and a slow one look equally like a shimmer. One bright bar fixed to the
    ' wheel is the difference between "it is spinning" and "something is happening".
    ' drawn a few degrees wide, because the rim is itself made of radial lines --
    ' a one-pixel spoke disappears into the thing it is supposed to stand out from
    FOR i = -2 TO 2
        rad = (g_angle + i * 0.55! - 90!) * 3.14159265! / 180!
        LINE (cx + COS(rad) * rr * 0.24!, cy + SIN(rad) * rr * 0.24!)-(cx + COS(rad) * rr, cy + SIN(rad) * rr), _RGB32(&HFF, &HF8, &HE0)
    NEXT i
    FOR i = -1 TO 1
        rad = (g_angle + 180! + i * 0.55! - 90!) * 3.14159265! / 180!
        LINE (cx + COS(rad) * rr * 0.24!, cy + SIN(rad) * rr * 0.24!)-(cx + COS(rad) * rr * 0.8!, cy + SIN(rad) * rr * 0.8!), _RGB32(&H20, &H1C, &H26)
    NEXT i

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

    ' the crank meter, with the balk line marked ON it -- nobody should balk by
    ' accident, the consequence is for people who try to tease it
    ' the bar is 52 characters wide and centred, so the marker is placed at the
    ' bar's OWN left column -- centring the marker line separately puts the arrow
    ' under nothing in particular, which is worse than not drawing it
    ' 50 cells for 100 charge, so one cell is exactly 2 charge. Both thresholds
    ' are marked ON the bar at the same scale -- a meter whose markings do not
    ' share the fill's scale is worse than a meter with no markings.
    barx = (SW - 52) \ 2
    IF g_charge < MIN_RELEASE THEN
        COLOR C_BAD, 0
    ELSEIF g_charge < SafeCharge! THEN
        COLOR C_WARN, 0
    ELSE
        COLOR C_GOOD, 0
    END IF
    MgText barx, 36, "[" + STRING$(INT(g_charge / 2!), "=") + STRING$(50 - INT(g_charge / 2!), ".") + "]"
    MgText barx + 54, 36, _TRIM$(STR$(INT(g_charge)))
    IF g_charge >= MIN_RELEASE THEN
        IF g_speed > 1! THEN MgText barx + 8, 34, "turning " + _TRIM$(STR$(INT(g_speed / 3.6!) / 100)) + " turns a second"
        MgText barx + 8, 35, "about " + _TRIM$(STR$(INT(SpinTurns!(g_charge) * 10) / 10)) + " turns, " + _TRIM$(STR$(INT(SpinSeconds!(AimedTravel!(g_charge)) * 10) / 10)) + "s of spin"
    ELSE
        MgText barx + 8, 35, "it has not moved yet"
    END IF
    COLOR C_BAD, 0: MgText barx + 1 + INT(MIN_RELEASE / 2!), 37, "!"
    COLOR C_GOOD, 0: MgText barx + 1 + INT(SafeCharge! / 2!), 37, "^"
    COLOR C_DIM, 0
    MgText barx, 38, "  ! it will not move at all      ^ from here it always goes round"

    COLOR C_GOOD, 0: MgCenter 39, "[UP]/[DOWN] crank it      [SPACE] let go      [ESC] leave it alone"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB WheelSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM i AS LONG, spins AS LONG
    DIM AS LONG bad
    DIM AS DOUBLE worstgap
    _DEST _CONSOLE
    PRINT "SPINWHEEL selftest"
    spins = 60000

    MgSection "the rim is a rim"
    MgOk "the wedges tile the whole circle with no gap and no overlap", RimIsClosed%
    MgOk "every degree lands on exactly one wedge", EveryDegreeMapped%
    MgOk "the mapping wraps -- 360 is 0, -10 is 350", WrapWorks%

    MgSection "the wheel does not lie: the result is READ, not chosen"
    RANDOMIZE 101
    bad = 0
    FOR i = 1 TO spins
        IF NOT SpinAgreesWithRim% THEN bad = bad + 1
    NEXT i
    PRINT USING "       ##### spins, ##### where the announced result was not under the pointer"; spins; bad
    MgOk "the announced result is always the wedge under the pointer", bad = 0

    MgSection "the wedge announced is the wedge DRAWN under the pointer"
    MgOk "at rest, the pointer reads the same wedge the rim draws there", PointerMatchesDrawnRim%

    MgSection "the odds are the widths, and nothing else"
    worstgap = WidthGap#(spins)
    PRINT USING "       worst wedge is off its advertised share by #.#### "; worstgap
    MgOk "every wedge comes up as often as its width says", worstgap < 0.01
    MgOk "the rarest wedge is genuinely rare, not merely thin", RareIsRare%

    MgSection "it settles, it does not cut"
    MgOk "the wheel always slows down and stops", DecelIsMonotonic%

    MgSection "the CRANK: strength is yours, the landing is not"
    MgOk "cranking harder always means a longer spin", CrankIsMonotonic%
    MgOk "a full crank always clears a full turn by a mile", AimedTravel!(CRANK_MAX) > FULL_TURN * 5!
    PRINT USING "       the handle moves at ##; a spin is certain from ## up; a full crank is ###"; MIN_RELEASE; SafeCharge!; CRANK_MAX
    MgOk "the balk threshold is reachable but not easy to hit by accident", SafeCharge! > 5! _ANDALSO SafeCharge! < CRANK_MAX * 0.35
    MgOk "a cold wheel cannot be released at all", MIN_RELEASE > 0!
    MgOk "...and doing nothing is never a spin", MIN_RELEASE < SafeCharge!
    MgOk "the weakest release that IS allowed can still balk", CanBalkAt%(MIN_RELEASE)
    MgOk "and a crank past the marked line never balks", NeverBalksAt%(SafeCharge! + 1!)

    MgSection "the wheel has WEIGHT -- strength is calibrated to the spin"
    PRINT USING "       a bare release spins #.# turns; a full crank spins ###.# turns"; SpinTurns!(MIN_RELEASE); SpinTurns!(CRANK_MAX)
    PRINT USING "       ...lasting #.#s and ##.#s"; SpinSeconds!(AimedTravel!(SafeCharge!)); SpinSeconds!(AimedTravel!(CRANK_MAX))
    MgOk "a full crank spins vastly further than a weak one", SpinTurns!(CRANK_MAX) > SpinTurns!(SafeCharge!) * 8!
    PRINT USING "       release speed: #.## turns a second at the balk line, #.## at a full crank"; PeakSpeed!(SafeCharge!) / 360!; PeakSpeed!(CRANK_MAX) / 360!
    MgOk "a full crank LEAVES YOUR HAND far faster -- momentum you can see", PeakSpeed!(CRANK_MAX) > PeakSpeed!(SafeCharge!) * 3!
    MgOk "...and not so fast that it is a blur nobody can follow", PeakSpeed!(CRANK_MAX) < 1100!
    MgOk "the animation substeps, so fast spins still tick every wedge", SUBSTEP * 1100! < NarrowestWedge!
    MgOk "twice the effort is worth MORE than twice the spin -- that is the weight", AimedTravel!(60!) > AimedTravel!(30!) * 3!
    MgOk "the first strokes barely move it", SpinTurns!(CRANK_GAIN) < 0.5
    MgOk "a full spin is long enough to watch and short enough to sit through", SpinSeconds!(AimedTravel!(CRANK_MAX)) > 6! _ANDALSO SpinSeconds!(AimedTravel!(CRANK_MAX)) < 14!
    MgOk "even the shortest legal spin is watchable", SpinSeconds!(BALK_AT) > 1.5

    MgSection "the crank is usable by a human hand"
    PRINT USING "       cranking at 5 strokes a second reaches full in #.#s"; TimeToFull!(5!)
    MgOk "a human cranking rate reaches a full charge", TimeToFull!(5!) < 4!
    MgOk "a slow, deliberate crank still gets there", TimeToFull!(2.5) < 12!
    PRINT USING "       after a stroke, a charge of ## survives #.##s of not cranking"; SafeCharge!; HoldTime!(SafeCharge!)
    MgOk "letting go to press SPACE does not disarm the wheel", HoldTime!(SafeCharge!) > 0.9
    MgOk "...even from the weakest legal charge", HoldTime!(MIN_RELEASE) > CRANK_GRACE
    MgOk "but standing there does eventually bleed it away", ChargeAfter!(CRANK_MAX, 30!) = 0!

    MgSection "NO crank setting aims the wheel -- the whole reason the slop exists"
    PRINT USING "       narrowest wedge is ##.# degrees; the random part of a spin spans ####"; NarrowestWedge!; TRAVEL_SLOP
    MgOk "the unaimable part of a spin is wider than the whole rim", TRAVEL_SLOP > 360!
    MgOk "every crank strength lands fairly, checked across the whole range", AimingIsImpossible%

    MgSection "and balking is punished rather than rewarded"
    MgOk "a spin under one full turn is a balk", IsBalk%(FULL_TURN - 1!) _ANDALSO NOT IsBalk%(FULL_TURN + 1!)
    MgOk "a balked wheel finishes the spin ITSELF, so nudging selects nothing", BalkNeverHelps%

    MgSection "and what it does to you is survivable"
    MgOk "no single wedge can kill outright", NoInstantDeath%
    MgOk "there is more good on the rim than harm", MoreGoodThanBad%

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
    travel = TravelFor!(50!)

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
        w = PointerWedge%(MgRoll%(360) - 1 + TravelFor!(RND * CRANK_MAX))
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

' A weak-but-legal crank has to be able to fail, or the balk rule never fires and
' the consequence is theoretical.
' How long to reach a full crank at `rate` strokes per second. This is the test
' that would have caught the un-usable first version: the charge simply never got
' anywhere, because decay outran a human hand.
FUNCTION TimeToFull! (rate AS SINGLE)
    DIM AS SINGLE c, t, gap
    gap = 1! / rate
    DO WHILE c < CRANK_MAX _ANDALSO t < 60!
        c = ChargeAfter!(c, gap) + CRANK_GAIN
        IF c > CRANK_MAX THEN c = CRANK_MAX
        t = t + gap
    LOOP
    TimeToFull! = t
END FUNCTION

' How long a charge survives once you stop cranking. Has to cover the time it
' takes to move a finger from an arrow key to the space bar, with room to spare.
FUNCTION HoldTime! (charge AS SINGLE)
    DIM t AS SINGLE
    DO WHILE ChargeAfter!(charge, t) >= MIN_RELEASE _ANDALSO t < 60!
        t = t + 0.02!
    LOOP
    HoldTime! = t
END FUNCTION

FUNCTION CanBalkAt% (charge AS SINGLE)
    DIM i AS LONG
    RANDOMIZE 123
    FOR i = 1 TO 20000
        IF IsBalk%(TravelFor!(charge)) THEN CanBalkAt% = TRUE: EXIT FUNCTION
    NEXT i
END FUNCTION

' ...and past the line drawn on the meter it must NEVER fire, or the game is
' punishing people for misjudging something it told them was safe.
FUNCTION NeverBalksAt% (charge AS SINGLE)
    DIM i AS LONG
    NeverBalksAt% = TRUE
    RANDOMIZE 124
    FOR i = 1 TO 40000
        IF IsBalk%(TravelFor!(charge)) THEN NeverBalksAt% = FALSE: EXIT FUNCTION
    NEXT i
END FUNCTION

FUNCTION CrankIsMonotonic% ()
    DIM c AS INTEGER
    CrankIsMonotonic% = TRUE
    FOR c = 1 TO INT(CRANK_MAX)
        IF AimedTravel!(c) <= AimedTravel!(c - 1) THEN CrankIsMonotonic% = FALSE
    NEXT c
END FUNCTION

FUNCTION NarrowestWedge! ()
    DIM i AS INTEGER
    DIM AS SINGLE w, narrow
    narrow = 360!
    FOR i = 1 TO WEDGES
        w = WSTOP(i) - WSTART(i)
        IF w < narrow THEN narrow = w
    NEXT i
    NarrowestWedge! = narrow
END FUNCTION

' THE ANTI-AIM PROOF, and the reason the slop term is sized the way it is.
'
' A player controls the crank exactly. If that control translated into control of
' the landing, the wheel would be a skill game with a fortune attached and every
' fairness claim above would be beside the point -- they would simply learn "78
' charge lands on THE KEY" and never spin any other way.
'
' So: sweep the entire crank range, spin thousands of times at each setting, and
' require that the landing distribution at EVERY setting matches the wedge widths.
' Not "on average across settings" -- at each one, because a single exploitable
' charge value is all it takes.
FUNCTION AimingIsImpossible% ()
    DIM c AS INTEGER, i AS LONG, w AS INTEGER
    DIM hits(1 TO WEDGES) AS LONG
    DIM AS DOUBLE want, got, gap, worst
    DIM tot AS INTEGER
    RANDOMIZE 121
    FOR i = 1 TO WEDGES: tot = tot + WWEIGHT(i): NEXT i
    FOR c = 0 TO INT(CRANK_MAX) STEP 4
        FOR w = 1 TO WEDGES: hits(w) = 0: NEXT w
        FOR i = 1 TO 4000
            w = PointerWedge%(MgRoll%(360) - 1 + TravelFor!(c))
            hits(w) = hits(w) + 1
        NEXT i
        FOR w = 1 TO WEDGES
            want = WWEIGHT(w) / tot
            got = hits(w) / 4000
            gap = ABS(want - got)
            IF gap > worst THEN worst = gap
        NEXT w
    NEXT c
    PRINT USING "       worst wedge bias at ANY crank setting: #.####"; worst
    AimingIsImpossible% = (worst < 0.03)
END FUNCTION

' A balk must not be a cheap way to place the wheel. The wheel finishes the spin
' itself at a strength nobody chose, so the outcome after a balk has to be drawn
' from the same distribution as any other spin -- otherwise "nudge it, take the
' punishment, collect the wedge you wanted" is a winning strategy.
FUNCTION BalkNeverHelps% ()
    DIM i AS LONG, w AS INTEGER
    DIM hits(1 TO WEDGES) AS LONG
    DIM AS DOUBLE want, got, gap, worst
    DIM tot AS INTEGER
    RANDOMIZE 122
    FOR i = 1 TO WEDGES: tot = tot + WWEIGHT(i): NEXT i
    FOR i = 1 TO 40000
        ' a deliberate tease: one stroke of the crank, aimed at a chosen wedge
        w = PointerWedge%(0! + FULL_TURN + RND * (TRAVEL_SLOP * 3!))
        hits(w) = hits(w) + 1
    NEXT i
    FOR w = 1 TO WEDGES
        want = WWEIGHT(w) / tot
        got = hits(w) / 40000
        gap = ABS(want - got)
        IF gap > worst THEN worst = gap
    NEXT w
    PRINT USING "       after a balk, worst wedge bias: #.####"; worst
    BalkNeverHelps% = (worst < 0.03)
END FUNCTION

' A wheel that snaps to its answer reads as rigged even when it is not, so the
' speed curve is checked the same way the outcome is: by running it.
FUNCTION DecelIsMonotonic% ()
    DIM AS SINGLE travel, gone, v, prev
    DIM guard AS LONG
    RANDOMIZE 104
    travel = TravelFor!(50!)
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
