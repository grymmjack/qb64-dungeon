' ============================================================================
'  PLINKO.bas -- THE FORTUNE SHRINE
'
'  A rectangular field of iron studs. You slide the coin along the lip at the top,
'  pick your spot, and let go. It clatters down and lands in a slot.
'
'  ---------------------------------------------------------------------------
'  FOUR VERSIONS, AND WHY EACH PREVIOUS ONE WAS WRONG
'
'   1. A drop that only ever stepped left. Not a distribution at all. +75% return
'      to the player, and it looked completely normal on screen.
'   2. Reflecting walls plus a per-channel choice, still on a step model. That is
'      a bounded random walk, which FLATTENS the distribution -- every slot ends
'      up roughly as likely as the next, so no slot is rare, so no slot can pay
'      big. Returned 3.4x the stake.
'   3. Classic triangular plinko, exact binomial, payouts from Pascal's triangle.
'      Correct, and provably so -- but the coin was a coin flip per row wearing an
'      animation. Nothing was actually falling.
'   4. THIS ONE: real physics. Gravity, a rectangular grid of square studs, proper
'      circle-vs-box collision, restitution, walls, and a coin you place yourself.
'
'  ---------------------------------------------------------------------------
'  WHAT REAL PHYSICS COSTS, AND HOW IT IS PAID
'
'  Version 3 could DERIVE its payouts, because a triangular peg field with fair
'  bounces is exactly binomial and Pascal's triangle gives P(slot) in closed form.
'  A bouncing rigid body in a rectangular field with walls has no closed form at
'  all. So the payouts here are MEASURED: the physics is simulated thousands of
'  times at startup, the landing distribution is counted, and the payouts are
'  computed from what the board actually does.
'
'  That is not a compromise, it is the stronger version -- the payout table cannot
'  drift away from the board, because it is derived FROM the board. Change a peg
'  spacing, the bounciness, the ball size, anything, and the table follows.
'
'  ---------------------------------------------------------------------------
'  PLACING THE COIN IS A REAL DECISION, AND IT CANNOT BEAT THE HOUSE
'
'  Where you release it changes where it tends to land -- that is the whole point
'  of letting you place it, and it is asserted rather than assumed (a placement
'  that does not move the distribution is a fake decision, and it would look
'  exactly like this one).
'
'  Which raises the obvious problem: if placement matters, some spot is best, and
'  a player who finds it might beat the shrine. So the payouts are normalised
'  against the BEST placement rather than the average one. The optimal release
'  point returns exactly the advertised edge; every other point returns less. That
'  makes skill real (playing well is worth something) without making the shrine a
'  losing proposition, and it is asserted over EVERY placement, not sampled.
' ============================================================================
'$INCLUDE:'MG.bi'

'--- the board, in pixels ---
CONST BW = 480, BH = 470                ' playfield size
CONST BOX_X = 288, BOX_Y = 112          ' where it sits on screen
CONST PEGROWS = 11, PEGCOLS = 14        ' spans 0..BW inclusive -- see PegX!
CONST PEG_HALF = 4!                     ' studs are SQUARE -- half-width in pixels
CONST BALL_R = 5!
CONST PEG_TOP = 70!                     ' clear air above the first stud row
CONST PEG_BOT = 60!                     ' and below the last, before the slots

CONST GRAV = 900!                       ' pixels per second squared
CONST DT = 1! / 120!
CONST BOUNCE = 0.52                     ' restitution off a stud
CONST WALLBOUNCE = 0.62                 ' lively enough to send a coin back into play
CONST DRAG = 0.999
CONST KICK = 26!                        ' tangential scatter per stud hit -- see below
CONST REST_V = 40!                      ' below this, a contact is resting rather than bouncing
CONST TOPPLE = 55!                      ' how decisively a resting coin falls off a stud
CONST RELEASE_JITTER = 22!              ' a hand is not a clamp -- see ResetBall
CONST MAXSTEP = 3000

CONST SLOTS = 9
CONST DROPN = 25                        ' placements along the lip
CONST SHRINE_CUT = 12                   ' percent the shrine keeps, off the BEST placement
CONST RISK_LOW = 0, RISK_MED = 1, RISK_HIGH = 2

'--- measured from the physics at startup ---
DIM SHARED PSLOT(0 TO DROPN - 1, 0 TO SLOTS - 1) AS DOUBLE   ' P(slot | placement)
DIM SHARED PMARG(0 TO SLOTS - 1) AS DOUBLE                   ' P(slot), over all placements
DIM SHARED PAYX(0 TO SLOTS - 1) AS DOUBLE                    ' payout multiplier
DIM SHARED AS INTEGER g_risk, g_drop, g_slot, g_hits
DIM SHARED AS SINGLE bx, by, vx, vy                          ' the coin
DIM SHARED AS SINGLE g_lastimpact
DIM SHARED g_clacked AS DOUBLE
DIM SHARED g_touching AS INTEGER

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
cmd = UCASE$(COMMAND$)
RANDOMIZE 4242
' Ten thousand real drops through the real physics, to price the board. Silenced
' explicitly: this runs on every launch including a normal one, and every stud
' hit inside it asks for a sound.
MgQuiet
MeasureBoard 400
MgLoud
BuildPayouts RISK_MED

IF INSTR(cmd, "TRACE") > 0 THEN
    DIM tn AS INTEGER
    ResetBall 7
    _DEST _CONSOLE
    PRINT "step        bx        by        vx        vy  hits"
    FOR tn = 1 TO 400
        IF StepBall% = 0 THEN PRINT "LANDED slot"; g_slot; " hits"; g_hits: SYSTEM
        IF tn MOD 20 = 0 THEN PRINT USING "####  ######.# ######.# ######.# ######.#  ####"; tn; bx; by; vx; vy; g_hits
    NEXT tn
    PRINT "NEVER LANDED  by="; by; " hits="; g_hits
    PRINT "peg sx="; PegSX!; " sy="; PegSY!; " first peg y="; PegY!(0)
    SYSTEM
END IF
IF INSTR(cmd, "SELFTEST") > 0 THEN PlinkoSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    g_drop = 7: g_risk = RISK_HIGH: BuildPayouts g_risk
    ResetBall g_drop
    DIM n AS INTEGER
    FOR n = 1 TO 150: IF StepBall% = 0 THEN EXIT FOR
    NEXT n
    DrawShrine 40, "it clatters down the studs"
    _SAVEIMAGE "plinko-shot.png"
    _DEST _CONSOLE: PRINT "wrote plinko-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayPlinko(200)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'============================================================================
'  THE PHYSICS
'============================================================================

' Spacing such that column 0 sits ON the left wall and the last sits ON the right.
FUNCTION PegSX! ()
    PegSX! = BW / (PEGCOLS - 1)
END FUNCTION

FUNCTION PegSY! ()
    PegSY! = (BH - PEG_TOP - PEG_BOT) / (PEGROWS - 1)
END FUNCTION

' Stud centres. The field is a RECTANGLE -- every row spans the full width, which
' is what makes the walls part of the game instead of decoration. Odd rows are
' offset half a spacing so a coin falling straight down always meets a stud
' rather than threading a clean vertical channel all the way to the floor.
'
' The grid must reach the WALLS, and getting that wrong took two goes. With the
' original spacing the offset rows stopped 55 pixels short of the right edge,
' leaving a clear channel from the lip to the floor: a coin that found it fell
' the whole way without touching anything, which is why one drop in two hundred
' recorded zero bounces and why the rightmost slot collected 21.5% of everything.
' Adding a column narrowed the channel to 34 pixels and did not close it -- still
' wider than the coin. The fix is to span 0..BW INCLUSIVE, so even rows put a
' stud ON each wall, half-buried in the case. Those half studs are drawn, because
' a stud the coin can hit but the player cannot see is the board lying.
FUNCTION PegX! (rw AS INTEGER, cl AS INTEGER)
    PegX! = PegSX! * cl - (rw MOD 2) * PegSX! * 0.5
END FUNCTION

FUNCTION PegY! (rw AS INTEGER)
    PegY! = PEG_TOP + rw * PegSY!
END FUNCTION

FUNCTION DropX! (d AS INTEGER)
    DropX! = BALL_R * 3! + (BW - BALL_R * 6!) * d / (DROPN - 1)
END FUNCTION

SUB ResetBall (d AS INTEGER)
    bx = DropX!(d): by = 12!
    ' A hand does not release a coin perfectly still, and it must not: a release
    ' point sitting exactly above a stud drops dead onto its centre and balances
    ' there for the best part of a second before toppling. The jitter is small
    ' enough to be invisible and large enough that the coin always arrives at a
    ' stud slightly off-centre, which is what a coin does.
    vx = (RND - 0.5!) * RELEASE_JITTER
    vy = 0!
    g_hits = 0: g_slot = -1: g_lastimpact = 0!: g_touching = 0
END SUB

' One physics step. Returns 0 once the coin has landed.
'
' Only the studs NEAR the coin are tested -- three rows by three columns. The
' whole-field version was 132 box tests per step, and the startup measurement
' runs ten thousand drops of six hundred steps each, so that is the difference
' between a shrine that opens instantly and one that hangs for a minute.
FUNCTION StepBall% ()
    DIM AS INTEGER rw, cl, r0, c0, dr, dc
    DIM AS SINGLE px, py, nx, ny, qx, qy, vn, tx, ty, sp, lean
    DIM touched AS INTEGER

    IF g_slot >= 0 THEN StepBall% = 0: EXIT FUNCTION

    vy = vy + GRAV * DT
    vx = vx * DRAG
    bx = bx + vx * DT
    by = by + vy * DT

    ' walls
    ' A wall bounce is a bounce. Not counting it made a coin that hugged the case
    ' all the way down report ZERO impacts, which is what made "it actually
    ' bounces off things" fail on a drop that was bouncing the whole way.
    IF bx < BALL_R THEN
        bx = BALL_R: vx = -vx * WALLBOUNCE
        touched = TRUE: Clack ABS(vx)
    END IF
    IF bx > BW - BALL_R THEN
        bx = BW - BALL_R: vx = -vx * WALLBOUNCE
        touched = TRUE: Clack ABS(vx)
    END IF

    ' studs near the coin
    r0 = INT((by - PEG_TOP) / PegSY!)
    FOR dr = -1 TO 1
        rw = r0 + dr
        IF rw >= 0 _ANDALSO rw < PEGROWS THEN
            py = PegY!(rw)
            c0 = INT(bx / PegSX!) - 1              ' column 0 is at x=0, so no +1 here
            FOR dc = 0 TO 2
                cl = c0 + dc
                IF cl >= 0 _ANDALSO cl < PEGCOLS THEN
                    px = PegX!(rw, cl)
                    IF HitPeg%(px, py, nx, ny, qx, qy) THEN
                        ' Push the coin out along the normal FROM THE CONTACT
                        ' POINT, not from the stud's centre.
                        '
                        ' Correcting against the centre was the whole bug: it
                        ' rewrote the coin's position to a fixed offset every
                        ' step, so a coin that came to rest on a stud was
                        ' teleported back to dead-centre on top of it forever. It
                        ' sat at (147.7, 61.0) for three thousand steps, taking
                        ' 288 bounces, and never fell. Ninety-five per cent of
                        ' drops never reached the floor -- and because the
                        ' measurement only counted the ones that DID, the board
                        ' still produced a plausible-looking distribution out of
                        ' the survivors rather than obviously breaking.
                        bx = qx + nx * (BALL_R + 0.02!)
                        by = qy + ny * (BALL_R + 0.02!)
                        vn = vx * nx + vy * ny
                        IF vn > 0! THEN vn = 0!      ' already separating; do not re-reflect
                        vx = (vx - 2! * vn * nx) * BOUNCE
                        vy = (vy - 2! * vn * ny) * BOUNCE
                        ' A stud is not a frictionless sphere and a coin is not
                        ' balanced. Without this a coin landing dead-centre on a
                        ' stud sits there forever, and every drop from the same
                        ' spot gives the identical slot -- one memorised release
                        ' point would win the jackpot every time.
                        tx = -ny: ty = nx
                        sp = (RND - 0.5!) * KICK
                        vx = vx + tx * sp
                        vy = vy + ty * sp

                        ' RESTING CONTACT. Once the coin has spent its energy it
                        ' sits on top of a stud and the bounce maths has nothing
                        ' left to work with -- it hovered there for a hundred
                        ' steps, taking a hundred contacts, which reads as jitter
                        ' rather than as a coin. A real one topples off the side
                        ' it is leaning toward, so that is what it does here, and
                        ' if it is balanced to within half a pixel the lean is
                        ' decided by a coin flip rather than by the sign of a
                        ' rounding error.
                        IF ABS(vn) < REST_V THEN
                            lean = bx - px
                            IF ABS(lean) < 0.5! THEN lean = RND - 0.5!
                            vx = vx + SGN2!(lean) * TOPPLE
                        END IF

                        touched = TRUE
                        Clack ABS(vn)
                    END IF
                END IF
            NEXT dc
        END IF
    NEXT dr

    ' COUNT DISTINCT CONTACTS, not frames of contact and not hard impacts.
    '
    ' Gating on impact speed missed a coin rolling gently down the studs -- it
    ' reported ZERO bounces on a drop that was in contact almost the whole way.
    ' Counting every frame instead inflated a single resting contact into
    ' hundreds. A contact begins when the coin was clear last step and is not
    ' clear now, which is the thing the word "bounce" actually means.
    IF touched _ANDALSO g_touching = 0 THEN g_hits = g_hits + 1
    g_touching = touched

    IF by >= BH - BALL_R THEN
        by = BH - BALL_R
        g_slot = INT(bx / (BW / SLOTS))
        IF g_slot < 0 THEN g_slot = 0
        IF g_slot > SLOTS - 1 THEN g_slot = SLOTS - 1
        StepBall% = 0
        EXIT FUNCTION
    END IF
    StepBall% = -1
END FUNCTION

FUNCTION SGN2! (d AS SINGLE)
    IF d < 0! THEN SGN2! = -1! ELSE SGN2! = 1!
END FUNCTION

' Circle against an axis-aligned SQUARE stud. The closest point on the box to the
' coin's centre gives both the test and the collision normal in one step, and it
' handles corner hits correctly -- which matters, because on a square stud the
' corners are where most of the interesting scatter comes from.
' Circle against an axis-aligned SQUARE stud.
'
' Returns the contact point (qx, qy) as well as the normal, because the caller
' needs to push the coin out from the CONTACT, not from the stud -- see the note
' at the call site for what happens when it does not.
FUNCTION HitPeg% (px AS SINGLE, py AS SINGLE, nx AS SINGLE, ny AS SINGLE, qx AS SINGLE, qy AS SINGLE)
    DIM AS SINGLE dx, dy, dist
    qx = bx: IF qx < px - PEG_HALF THEN qx = px - PEG_HALF
    IF qx > px + PEG_HALF THEN qx = px + PEG_HALF
    qy = by: IF qy < py - PEG_HALF THEN qy = py - PEG_HALF
    IF qy > py + PEG_HALF THEN qy = py + PEG_HALF
    dx = bx - qx: dy = by - qy
    dist = SQR(dx * dx + dy * dy)
    IF dist >= BALL_R THEN HitPeg% = 0: EXIT FUNCTION
    IF dist < 0.0001! THEN
        ' The coin's centre is inside the stud -- no normal exists. Push it out
        ' through the nearest face instead of dividing by zero.
        IF ABS(bx - px) > ABS(by - py) THEN
            nx = SGN2!(bx - px): ny = 0!
            qx = px + nx * PEG_HALF: qy = by
        ELSE
            nx = 0!: ny = SGN2!(by - py)
            qx = bx: qy = py + ny * PEG_HALF
        END IF
    ELSE
        nx = dx / dist: ny = dy / dist
    END IF
    HitPeg% = -1
END FUNCTION

' Every stud hit makes a noise, pitched by how hard it was struck. Muted in
' selftest and shot -- see MgBeep.
' A clack per stud hit, pitched by how hard it was struck.
'
' The physics runs at 120 steps a second and a busy drop can hit two studs in one
' step, so this is throttled at the source as well as in MgBeep. Belt and braces
' on purpose: MgBeep's queue guard is the backstop that must never be needed, and
' a backstop you rely on routinely is not a backstop.
SUB Clack (speed AS SINGLE)
    DIM f AS SINGLE
    IF MG_QUIET THEN EXIT SUB
    IF MG_SILENT > 0 THEN EXIT SUB
    IF speed < 12! THEN EXIT SUB              ' a graze is not a clack
    IF MgElapsed!(g_clacked) < 0.045 THEN EXIT SUB
    g_clacked = TIMER
    f = 300! + speed * 1.4!
    IF f > 1400! THEN f = 1400!
    g_lastimpact = speed
    MgBeep f, 0.5
END SUB

' Run a whole drop with no drawing. This is what the payout measurement uses, and
' it is the SAME StepBall% the animation calls -- there is no second physics.
FUNCTION SimDrop% (d AS INTEGER)
    DIM n AS LONG
    ResetBall d
    DO
        n = n + 1
        IF n > MAXSTEP THEN EXIT DO
    LOOP WHILE StepBall%
    SimDrop% = g_slot
END FUNCTION

'============================================================================
'  THE MEASUREMENT, AND THE PAYOUTS THAT COME OUT OF IT
'============================================================================

' Drop `per` coins from every placement and count where they land.
SUB MeasureBoard (per AS LONG)
    DIM d AS INTEGER, sl AS INTEGER
    DIM i AS LONG, tot AS LONG
    FOR d = 0 TO DROPN - 1
        FOR sl = 0 TO SLOTS - 1: PSLOT(d, sl) = 0: NEXT sl
        FOR i = 1 TO per
            sl = SimDrop%(d)
            IF sl >= 0 THEN PSLOT(d, sl) = PSLOT(d, sl) + 1
        NEXT i
        FOR sl = 0 TO SLOTS - 1: PSLOT(d, sl) = PSLOT(d, sl) / per: NEXT sl
    NEXT d
    FOR sl = 0 TO SLOTS - 1
        PMARG(sl) = 0
        FOR d = 0 TO DROPN - 1: PMARG(sl) = PMARG(sl) + PSLOT(d, sl): NEXT d
        PMARG(sl) = PMARG(sl) / DROPN
    NEXT sl

    ' The payouts are DERIVED from this measurement, so a new measurement makes
    ' the old table stale by definition. Rebuilding here rather than trusting
    ' every caller to remember: the selftest re-measures to prove the board is
    ' stable, and that alone was enough to leave the advertised edge at 87.8%
    ' when it claimed 88.0% -- the table was priced off a board that no longer
    ' existed.
    BuildPayouts g_risk
END SUB

' The risk curve. All three run over the SAME measured distribution: risk buys
' variance, never expectation, because the normalisation below removes any
' expectation difference by construction.
FUNCTION RiskShape# (sl AS INTEGER, risk AS INTEGER)
    ' `ctr`/`dist`/`pw` -- not `mid`/`off`/`k`. MID is reserved (MID$) and OFF is
    ' reserved too; QB64 rejects the DIM with a bare "Caused by" and no hint.
    DIM AS DOUBLE ctr, dist, pw
    ctr = (SLOTS - 1) / 2!
    dist = ABS(sl - ctr) / ctr                ' 0 centre, 1 at an edge
    SELECT CASE risk
        CASE RISK_LOW: pw = 0.35
        CASE RISK_HIGH: pw = 2.6
        CASE ELSE: pw = 1!
    END SELECT
    RiskShape# = (0.15 + dist) ^ pw
END FUNCTION

' Payouts, from the measured board.
'
' The normalisation is against the BEST placement, not the average one. That is
' what makes "place the coin" a skill that is worth learning and still cannot
' beat the shrine: the optimal release returns exactly (100 - SHRINE_CUT) per
' cent, and every other release returns less.
SUB BuildPayouts (risk AS INTEGER)
    DIM sl AS INTEGER, d AS INTEGER
    DIM AS DOUBLE ev, best, scale
    g_risk = risk

    FOR sl = 0 TO SLOTS - 1
        IF PMARG(sl) > 0 THEN
            PAYX(sl) = RiskShape#(sl, risk) / PMARG(sl)
        ELSE
            PAYX(sl) = 0                       ' unreachable slot pays nothing, and
        END IF                                 ' the selftest refuses to allow one
    NEXT sl

    best = 0
    FOR d = 0 TO DROPN - 1
        ev = 0
        FOR sl = 0 TO SLOTS - 1: ev = ev + PSLOT(d, sl) * PAYX(sl): NEXT sl
        IF ev > best THEN best = ev
    NEXT d

    IF best > 0 THEN
        scale = (1! - SHRINE_CUT / 100!) / best
        FOR sl = 0 TO SLOTS - 1: PAYX(sl) = PAYX(sl) * scale: NEXT sl
    END IF
END SUB

FUNCTION EVAt# (d AS INTEGER)
    DIM sl AS INTEGER
    DIM ev AS DOUBLE
    FOR sl = 0 TO SLOTS - 1: ev = ev + PSLOT(d, sl) * PAYX(sl): NEXT sl
    EVAt# = ev
END FUNCTION

FUNCTION RiskName$ (risk AS INTEGER)
    SELECT CASE risk
        CASE RISK_LOW: RiskName$ = "STEADY"
        CASE RISK_HIGH: RiskName$ = "RECKLESS"
        CASE ELSE: RiskName$ = "EVEN"
    END SELECT
END FUNCTION

'============================================================================
'  PLAY
'============================================================================

FUNCTION PlayPlinko% (startpurse AS LONG)
    DIM k AS STRING, u AS STRING, msg AS STRING
    DIM AS LONG purse, stake, won
    DIM n AS INTEGER, nextrisk AS INTEGER
    purse = startpurse: stake = 10
    g_drop = DROPN \ 2
    msg = "slide the coin along the lip, then let go"
    DO
        IF purse < stake THEN PlayPlinko% = MG_LOST: EXIT FUNCTION
        IF purse >= startpurse * 3 THEN PlayPlinko% = MG_WON: EXIT FUNCTION
        g_slot = -1
        DrawShrine -1, msg
        k = INKEY$: u = UCASE$(k)
        IF k = CHR$(27) THEN PlayPlinko% = MG_LEFT: EXIT FUNCTION
        IF u = "A" OR k = CHR$(0) + "K" THEN IF g_drop > 0 THEN g_drop = g_drop - 1
        IF u = "D" OR k = CHR$(0) + "M" THEN IF g_drop < DROPN - 1 THEN g_drop = g_drop + 1
        IF u = "R" THEN nextrisk = (g_risk + 1) MOD 3: BuildPayouts nextrisk
        IF k = " " OR k = CHR$(13) THEN
            purse = purse - stake
            ResetBall g_drop
            n = 0
            DO
                n = n + 1
                DrawShrine n, "..."
                _LIMIT 60
            LOOP WHILE StepBall% _ANDALSO n < MAXSTEP
            MgBeep 180, 4
            won = INT(stake * PAYX(g_slot) + 0.5)
            purse = purse + won
            msg = "slot " + _TRIM$(STR$(g_slot + 1)) + " -- " + _TRIM$(STR$(won)) + " back on " + _TRIM$(STR$(stake))
            DrawShrine n, msg
            _DELAY 1.6
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

'============================================================================
'  DRAW
'============================================================================

SUB DrawShrine (frame AS INTEGER, msg AS STRING)
    DIM AS INTEGER rw, cl, sl, i
    DIM AS SINGLE px, py
    DIM AS INTEGER x, y, w
    DIM od AS LONG
    DIM s AS STRING
    od = _DEST: _DEST 0

    MgHeader "T H E   F O R T U N E   S H R I N E", "iron studs, a heavy coin, and no closed form at all"

    ' the case
    LINE (BOX_X - 3, BOX_Y - 3)-(BOX_X + BW + 3, BOX_Y + BH + 3), _RGB32(60, 54, 68), B
    LINE (BOX_X, BOX_Y)-(BOX_X + BW, BOX_Y + BH), _RGB32(16, 14, 20), BF

    ' the studs -- SQUARE, in a full-width rectangular grid
    FOR rw = 0 TO PEGROWS - 1
        FOR cl = 0 TO PEGCOLS - 1
            px = PegX!(rw, cl): py = PegY!(rw)
            ' drawn even where they are half-buried in the case: a stud the coin
            ' can hit but the player cannot see is the board lying about itself
            LINE (BOX_X + px - PEG_HALF, BOX_Y + py - PEG_HALF)-(BOX_X + px + PEG_HALF, BOX_Y + py + PEG_HALF), _RGB32(&H90, &H98, &HA8), BF
            LINE (BOX_X + px - PEG_HALF, BOX_Y + py - PEG_HALF)-(BOX_X + px + PEG_HALF, BOX_Y + py - PEG_HALF + 1), _RGB32(&HD8, &HE0, &HF0), BF
        NEXT cl
    NEXT rw

    ' slot dividers and payouts
    w = BW / SLOTS
    FOR sl = 0 TO SLOTS - 1
        x = BOX_X + sl * w
        LINE (x, BOX_Y + BH - 40)-(x, BOX_Y + BH), _RGB32(70, 64, 78)
        IF sl = g_slot THEN COLOR C_TITLE, 0 ELSE COLOR C_DIM, 0
        s = _TRIM$(STR$(INT(PAYX(sl) * 10 + 0.5) / 10)) + "x"
        _PRINTSTRING (x + (w - LEN(s) * CW) \ 2, BOX_Y + BH - 26), s
    NEXT sl
    LINE (BOX_X, BOX_Y + BH - 40)-(BOX_X + BW, BOX_Y + BH - 40), _RGB32(70, 64, 78)

    ' the lip, and where the coin is being held
    COLOR C_COOL, 0
    px = DropX!(g_drop)
    LINE (BOX_X + px - 8, BOX_Y + 2)-(BOX_X + px + 8, BOX_Y + 5), _RGB32(&H50, &HB0, &HD0), BF
    IF frame < 0 THEN
        CIRCLE (BOX_X + px, BOX_Y + 12), BALL_R, _RGB32(&HFF, &HD8, &H60)
        PAINT (BOX_X + px, BOX_Y + 12), _RGB32(&HFF, &HD8, &H60), _RGB32(&HFF, &HD8, &H60)
    ELSE
        CIRCLE (BOX_X + bx, BOX_Y + by), BALL_R, _RGB32(&HFF, &HD8, &H60)
        PAINT (BOX_X + bx, BOX_Y + by), _RGB32(&HFF, &HD8, &H60), _RGB32(&HFF, &HD8, &H60)
    END IF

    ' the odds, written out, because a measured board still owes the player its numbers
    COLOR C_DIM, 0
    MgText 2, 8, "slot   lands   pays"
    FOR sl = 0 TO SLOTS - 1
        IF sl = g_slot THEN COLOR C_TITLE, 0 ELSE COLOR C_DIM, 0
        MgText 2, 9 + sl, RIGHT$("  " + _TRIM$(STR$(sl + 1)), 3) + "   " + RIGHT$("    " + _TRIM$(STR$(INT(PMARG(sl) * 1000) / 10)), 5) + "%  " + _TRIM$(STR$(INT(PAYX(sl) * 100 + 0.5) / 100)) + "x"
    NEXT sl

    COLOR C_WARN, 0
    MgText 2, 21, "risk: " + RiskName$(g_risk)
    MgText 2, 22, "shrine keeps " + _TRIM$(STR$(SHRINE_CUT)) + "%"
    COLOR C_DIM, 0
    MgText 2, 24, "this spot"
    MgText 2, 25, "returns " + _TRIM$(STR$(INT(EVAt#(g_drop) * 1000) / 10)) + "%"
    MgText 2, 27, "the best spot"
    MgText 2, 28, "returns " + _TRIM$(STR$(INT((100 - SHRINE_CUT)))) + "%"

    COLOR C_TEXT, 0: MgCenter 38, msg
    COLOR C_GOOD, 0
    MgCenter 40, "[A]/[D] slide the coin   [SPACE] let go   [R] risk   [ESC] leave"
    _DISPLAY
    _DEST od
END SUB

'============================================================================
'  SELFTEST
'============================================================================

SUB PlinkoSelfTest
    MgQuiet                     ' nothing in here is being watched
    DIM sl AS INTEGER, d AS INTEGER
    ' `topev`, not `bestev`: identifiers are case-insensitive and FUNCTION BestEV#
    ' already owns that name.
    DIM AS DOUBLE ev, worst, topev
    _DEST _CONSOLE
    PRINT "PLINKO selftest  (physics measured, not derived)"

    MgSection "the coin always finishes, in a real slot"
    MgOk "every drop lands, from every placement", AlwaysLands%
    MgOk "the coin never escapes the case", NeverEscapes%
    MgOk "it actually bounces off things on the way down", ActuallyBounces%

    MgSection "the measured distribution is stable enough to price"
    MgOk "two independent measurements agree", MeasurementIsStable%
    MgOk "every slot is reachable -- no painted-on lie", AllSlotsReachable%
    PRINT "       marginal landing chance per slot:"
    s_PrintDist

    MgSection "placing the coin MATTERS -- otherwise it is a fake decision"
    MgOk "the far-left and far-right placements land differently", PlacementMatters%
    MgOk "...and the difference is large, not a rounding artefact", PlacementSpread# > 0.15
    PRINT USING "       biggest shift in landing chance across placements: #.###"; PlacementSpread#

    MgSection "...but it cannot beat the shrine, from ANY placement"
    FOR d = 0 TO DROPN - 1
        ev = EVAt#(d)
        IF ev > topev THEN topev = ev
        IF worst = 0 OR ev < worst THEN worst = ev
    NEXT d
    PRINT USING "       return by placement: worst ###.#%  best ###.#%  (advertised ###.#%)"; worst * 100; topev * 100; 100 - SHRINE_CUT
    MgOk "no placement returns more than the advertised edge", topev <= (1 - SHRINE_CUT / 100!) + 0.0001
    MgOk "the BEST placement hits it exactly -- so skill is worth the maximum", ABS(topev - (1 - SHRINE_CUT / 100!)) < 0.0001
    MgOk "a careless placement really is worse", worst < topev - 0.02

    MgSection "risk buys variance, never expectation"
    MgOk "all three curves keep the same house edge", EdgeSameAcrossRisk%
    MgOk "reckless has a far wider spread of payouts", SpreadOf#(RISK_HIGH) > SpreadOf#(RISK_LOW) * 3
    PRINT USING "       payout spread: steady #.##   even #.##   reckless #.##"; SpreadOf#(RISK_LOW); SpreadOf#(RISK_MED); SpreadOf#(RISK_HIGH)

    MgSection "and the shrine really does keep its cut, when actually played"
    MgOk "ten thousand real drops return close to the advertised figure", RealisedReturnOk%

    MgLoud
    MgDone
END SUB

SUB s_PrintDist
    DIM sl AS INTEGER
    DIM s AS STRING
    FOR sl = 0 TO SLOTS - 1
        s = "       slot" + STR$(sl + 1) + " " + _TRIM$(STR$(INT(PMARG(sl) * 1000) / 10)) + "%"
        PRINT s; TAB(28); STRING$(INT(PMARG(sl) * 200), "#")
    NEXT sl
END SUB

FUNCTION AlwaysLands% ()
    DIM d AS INTEGER, i AS INTEGER
    AlwaysLands% = TRUE
    FOR d = 0 TO DROPN - 1
        FOR i = 1 TO 12
            IF SimDrop%(d) < 0 THEN AlwaysLands% = FALSE
        NEXT i
    NEXT d
END FUNCTION

' A tunnelling bug puts the coin outside the case, where it falls forever or
' lands in a slot that does not exist. It looks like a rare freeze.
FUNCTION NeverEscapes% ()
    DIM d AS INTEGER, i AS INTEGER, n AS LONG
    NeverEscapes% = TRUE
    FOR d = 0 TO DROPN - 1
        FOR i = 1 TO 8
            ResetBall d
            n = 0
            DO
                n = n + 1
                IF bx < -1! OR bx > BW + 1! THEN NeverEscapes% = FALSE
                IF by < -20! OR by > BH + 2! THEN NeverEscapes% = FALSE
                IF n > MAXSTEP THEN EXIT DO
            LOOP WHILE StepBall%
        NEXT i
    NEXT d
END FUNCTION

' A coin that reaches the floor without touching a stud has fallen down a clean
' channel, and the whole board is decoration.
FUNCTION ActuallyBounces% ()
    DIM d AS INTEGER, i AS INTEGER
    DIM AS LONG drops, tot, worstn, zero
    worstn = 9999
    FOR d = 0 TO DROPN - 1
        FOR i = 1 TO 8
            IF SimDrop%(d) >= 0 THEN
                drops = drops + 1: tot = tot + g_hits
                IF g_hits = 0 THEN zero = zero + 1
                IF g_hits < worstn THEN worstn = g_hits
            END IF
        NEXT i
    NEXT d
    PRINT USING "       contacts per drop: ##.# average, ## at the very least; #### of #### drops touched nothing"; tot / drops; worstn; zero; drops
    ActuallyBounces% = (zero = 0 _ANDALSO tot / drops >= 6)
END FUNCTION

' If two independent measurements of the same board disagree, the payouts are
' priced off noise and the advertised edge is fiction.
FUNCTION MeasurementIsStable% ()
    DIM sl AS INTEGER
    DIM a(0 TO SLOTS - 1) AS DOUBLE
    DIM AS DOUBLE gap, worstgap
    FOR sl = 0 TO SLOTS - 1: a(sl) = PMARG(sl): NEXT sl
    MeasureBoard 400
    FOR sl = 0 TO SLOTS - 1
        gap = ABS(a(sl) - PMARG(sl))
        IF gap > worstgap THEN worstgap = gap
    NEXT sl
    PRINT USING "       biggest disagreement between two measurements: #.####"; worstgap
    MeasurementIsStable% = (worstgap < 0.02)
END FUNCTION

FUNCTION AllSlotsReachable% ()
    DIM sl AS INTEGER
    AllSlotsReachable% = TRUE
    FOR sl = 0 TO SLOTS - 1
        IF PMARG(sl) <= 0 THEN
            PRINT "       UNREACHABLE: slot"; sl + 1
            AllSlotsReachable% = FALSE
        END IF
    NEXT sl
END FUNCTION

FUNCTION PlacementMatters% ()
    PlacementMatters% = (PlacementSpread# > 0.05)
END FUNCTION

' The biggest difference any single slot's chance shows across placements. If
' this is ~0, sliding the coin does nothing and the control is a lie.
FUNCTION PlacementSpread# ()
    DIM sl AS INTEGER, d AS INTEGER
    DIM AS DOUBLE lo, hi, spread
    FOR sl = 0 TO SLOTS - 1
        lo = 9: hi = -1
        FOR d = 0 TO DROPN - 1
            IF PSLOT(d, sl) < lo THEN lo = PSLOT(d, sl)
            IF PSLOT(d, sl) > hi THEN hi = PSLOT(d, sl)
        NEXT d
        IF hi - lo > spread THEN spread = hi - lo
    NEXT sl
    PlacementSpread# = spread
END FUNCTION

FUNCTION EdgeSameAcrossRisk% ()
    DIM AS DOUBLE a, b, c
    BuildPayouts RISK_LOW: a = BestEV#
    BuildPayouts RISK_MED: b = BestEV#
    BuildPayouts RISK_HIGH: c = BestEV#
    BuildPayouts RISK_MED
    EdgeSameAcrossRisk% = (ABS(a - b) < 0.0001 _ANDALSO ABS(b - c) < 0.0001)
END FUNCTION

FUNCTION BestEV# ()
    DIM d AS INTEGER
    DIM AS DOUBLE ev, best
    FOR d = 0 TO DROPN - 1
        ev = EVAt#(d)
        IF ev > best THEN best = ev
    NEXT d
    BestEV# = best
END FUNCTION

' Ratio of the biggest payout to the smallest. That IS variance, in the only
' form the player can see.
FUNCTION SpreadOf# (risk AS INTEGER)
    DIM sl AS INTEGER
    DIM AS DOUBLE lo, hi
    BuildPayouts risk
    lo = 1E+09
    FOR sl = 0 TO SLOTS - 1
        IF PAYX(sl) < lo THEN lo = PAYX(sl)
        IF PAYX(sl) > hi THEN hi = PAYX(sl)
    NEXT sl
    BuildPayouts RISK_MED
    IF lo <= 0 THEN SpreadOf# = 0 ELSE SpreadOf# = hi / lo
END FUNCTION

' The table says one thing; actually playing has to agree. Drops from random
' placements, which is what a real session looks like.
FUNCTION RealisedReturnOk% ()
    DIM i AS LONG, d AS INTEGER, sl AS INTEGER
    DIM AS DOUBLE staked, back, lo, hi
    FOR i = 1 TO 10000
        d = MgRoll%(DROPN) - 1
        sl = SimDrop%(d)
        staked = staked + 1
        IF sl >= 0 THEN back = back + PAYX(sl)
    NEXT i
    ' Random placement is not optimal placement, so the realised figure SHOULD
    ' sit below the advertised edge -- that gap IS the value of playing well. The
    ' meaningful claim is that actually playing lands between the worst placement
    ' and the best, which is what says the table and the board agree.
    lo = 9: hi = 0
    FOR d = 0 TO DROPN - 1
        IF EVAt#(d) < lo THEN lo = EVAt#(d)
        IF EVAt#(d) > hi THEN hi = EVAt#(d)
    NEXT d
    PRINT USING "       ten thousand drops returned ###.#% -- placements span ###.#% to ###.#%"; back / staked * 100; lo * 100; hi * 100
    RealisedReturnOk% = (back / staked >= lo - 0.02 _ANDALSO back / staked <= hi + 0.02)
END FUNCTION

'$INCLUDE:'MG.bas'
