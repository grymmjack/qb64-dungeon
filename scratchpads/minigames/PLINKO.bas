' ============================================================================
'  PLINKO.bas -- FORTUNE SHRINE prototype
'
'  Drop a coin down a peg field. At each row it bounces left or right; where it
'  lands decides the payout. You choose the DROP CHANNEL, which is the whole
'  decision: centre is safe and dull, the edges are a long shot.
'
'  WHY THE PAYOUTS ARE COMPUTED, NOT CHOSEN
'
'  A plinko board's landing distribution is binomial, and binomial is savagely
'  peaked -- with 12 rows the centre slot is ~1,700 times more likely than an
'  edge. Payouts picked by eye are therefore always wrong by orders of magnitude,
'  in one direction or the other, and no amount of playtesting finds it because
'  the edges are the slots you almost never see.
'
'  So the payouts here are DERIVED: pay = round(target / P(slot)), which makes
'  every slot worth the same in expectation, and then the shrine's cut is applied
'  once, visibly. The selftest checks the exact distribution against Pascal's
'  triangle and the realised return against the intended edge.
'
'  RUN:  ./PLINKO.run selftest | shot | (play)
' ============================================================================
'$INCLUDE:'MG.bi'

CONST ROWS = 12                      ' peg rows; slots = ROWS + 1
CONST SLOTS = ROWS + 1
CONST SHRINE_CUT = 12                ' percent the shrine keeps, applied to the fair payout
CONST TARGET_MULT = 2                ' a fair slot pays this many times the stake, before the cut

CONST RISK_LOW = 0, RISK_MED = 1, RISK_HIGH = 2
' Columns per slot on screen. 6, not 4: the reckless board pays 277x and a 4-wide
' slot ran the multipliers into each other into an unreadable smear.
CONST SLOTW = 6

' Declared UP HERE, not down with the maths that uses them: a main-module DIM
' executes where it appears, so a declaration below the BuildPayouts call leaves
' the array at its implicit 0..10 default when it is written to -- and QB64 raises
' `Subscript out of range`, which without an error handler is a modal dialog.
DIM SHARED PAY(0 TO SLOTS - 1) AS LONG        ' payout x100, for display
DIM SHARED PAYX(0 TO SLOTS - 1) AS DOUBLE     ' exact payout multiplier

DIM cmd AS STRING
ON ERROR GOTO MgFatal          ' no modal dialogs -- see the handler below
MgInit
BuildPayouts RISK_MED
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN PlinkoSelfTest

MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    DIM px(0 TO ROWS) AS INTEGER, i AS INTEGER
    FOR i = 1 TO ROWS: px(i) = px(i - 1) + (i MOD 2): NEXT i
    DrawBoard px(), ROWS, RISK_HIGH, px(ROWS), 180, 20, "it clatters down the pegs"
    _SAVEIMAGE "plinko-shot.png"
    _DEST _CONSOLE: PRINT "wrote plinko-shot.png": SYSTEM
END IF

DIM purse AS LONG, r AS INTEGER
purse = 200
r = PlayPlinko(purse, 20)
_DEST _CONSOLE: PRINT "result ="; r; " purse ="; purse: SYSTEM


' ----------------------------------------------------------------------------
'  THE MATHS
'
'  Two earlier attempts got this wrong in ways worth recording, because both
'  produced a board that LOOKED fine and paid out wildly:
'
'   1. A drop that only ever stepped left. Not a distribution at all. +75% return.
'   2. Reflecting walls plus a per-channel drop choice. That is a bounded random
'      walk, and it FLATTENS the distribution -- every slot ends up roughly as
'      likely as every other, which kills the whole appeal (no slot is rare, so no
'      slot can pay big) and made the board return 3.4x whatever you staked.
'
'  So: classic plinko. The coin enters at the top centre and every peg is a fair
'  coin flip, giving an exact BINOMIAL over the slots -- the centre is 924 times
'  more likely than an edge, which is what makes an edge worth a fortune.
'
'  The decision moves to RISK. Three payout curves over the same distribution:
'  low risk is nearly flat, high risk is savage. All three are normalised to the
'  SAME house edge, so choosing risk chooses variance and nothing else -- which is
'  the honest version of the choice, and is exactly what the selftest asserts.
' ----------------------------------------------------------------------------

' C(ROWS, k), by addition. Factorials overflow long before 12! matters and would
' make the table silently wrong at precisely the edges nobody ever sees.

'--- FATAL ERROR TRAP -------------------------------------------------------
' Same reason dungeon.bas arms one: an unhandled QB64 error opens a MODAL dialog
' and waits for a click. Under xvfb -- every selftest, every shot -- nobody can
' click it, so the process just hangs with no clue why. These prototypes are dev
' tools with no human watching, so there is no "let them keep playing" case: print
' something greppable, exit non-zero, get out of the way.
MgFatal:
    _DEST _CONSOLE
    PRINT
    PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1
'----------------------------------------------------------------------------

FUNCTION PathsTo& (k AS INTEGER)
    DIM row(0 TO SLOTS) AS LONG, i AS INTEGER, j AS INTEGER
    IF k < 0 OR k > ROWS THEN PathsTo& = 0: EXIT FUNCTION
    row(0) = 1
    FOR i = 1 TO ROWS
        FOR j = i TO 1 STEP -1
            row(j) = row(j) + row(j - 1)
        NEXT j
    NEXT i
    PathsTo& = row(k)
END FUNCTION

FUNCTION TotalPaths& ()
    DIM i AS INTEGER, n AS LONG
    FOR i = 0 TO ROWS: n = n + PathsTo&(i): NEXT i
    TotalPaths& = n
END FUNCTION

FUNCTION SlotProb# (slot AS INTEGER)
    SlotProb# = PathsTo&(slot) / TotalPaths&
END FUNCTION

' Build the payout table for a risk level.
'
' Weight each slot by rarity, raised to a power: gamma 0 is a flat board (every
' slot pays the same), gamma 1 pays strictly in proportion to how rare the slot
' is. Then scale the whole curve so the expected return is exactly the intended
' one. Normalising LAST is what makes the three curves comparable -- the shrine's
' cut is a property of the board, not of how brave you are.
SUB BuildPayouts (risk AS INTEGER)
    DIM slot AS INTEGER, w(0 TO SLOTS - 1) AS DOUBLE, e AS DOUBLE, g AS DOUBLE, a AS DOUBLE
    SELECT CASE risk
        CASE RISK_LOW: g = 0.35
        CASE RISK_HIGH: g = 1#
        CASE ELSE: g = 0.65
    END SELECT
    FOR slot = 0 TO SLOTS - 1
        w(slot) = (1# / SlotProb#(slot)) ^ g
    NEXT slot
    e = 0#
    FOR slot = 0 TO SLOTS - 1: e = e + SlotProb#(slot) * w(slot): NEXT slot
    a = ((100 - SHRINE_CUT) / 100#) / e             ' scale so E[return] = 1 - cut
    FOR slot = 0 TO SLOTS - 1
        PAYX(slot) = a * w(slot)                     ' exact multiplier, kept as a real
        PAY(slot) = INT(PAYX(slot) * 100# + 0.5)     ' hundredths, for display and payout
    NEXT slot
END SUB

' Drop a coin: ROWS fair flips, slot = how many went right. Exactly binomial.
FUNCTION DropCoin% ()
    DIM i AS INTEGER, x AS INTEGER
    FOR i = 1 TO ROWS
        IF MgRoll%(2) = 1 THEN x = x + 1
    NEXT i
    DropCoin% = x
END FUNCTION

' What one unit staked returns under the current table.
FUNCTION ExpectedReturn# ()
    DIM slot AS INTEGER, e AS DOUBLE
    FOR slot = 0 TO SLOTS - 1: e = e + SlotProb#(slot) * PAYX(slot): NEXT slot
    ExpectedReturn# = e
END FUNCTION

' Spread of the payouts, as a standard deviation of the return. This is the number
' the risk choice is actually buying, so it is the number the test checks.
FUNCTION ReturnSpread# ()
    DIM slot AS INTEGER, m AS DOUBLE, v AS DOUBLE
    m = ExpectedReturn#
    FOR slot = 0 TO SLOTS - 1
        v = v + SlotProb#(slot) * (PAYX(slot) - m) ^ 2
    NEXT slot
    ReturnSpread# = SQR(v)
END FUNCTION

FUNCTION RiskName$ (risk AS INTEGER)
    SELECT CASE risk
        CASE RISK_LOW: RiskName$ = "steady"
        CASE RISK_HIGH: RiskName$ = "reckless"
        CASE ELSE: RiskName$ = "chancy"
    END SELECT
END FUNCTION

' ----------------------------------------------------------------------------
'  PLAY
' ----------------------------------------------------------------------------

FUNCTION PlayPlinko% (purse AS LONG, stake AS LONG)
    DIM risk AS INTEGER, k AS STRING, ext AS INTEGER, i AS INTEGER, slot AS INTEGER
    DIM px(0 TO ROWS) AS INTEGER, won AS LONG
    risk = RISK_MED
    BuildPayouts risk
    DO
        DrawBoard px(), -1, risk, -1, purse, stake, "pick your nerve, then drop"
        k = UCASE$(INKEY$): ext = 0
        IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
        IF k = CHR$(27) THEN PlayPlinko% = MG_LEFT: EXIT FUNCTION
        IF ext = 75 OR k = "A" THEN
            risk = risk - 1: IF risk < RISK_LOW THEN risk = RISK_HIGH
            BuildPayouts risk
        END IF
        IF ext = 77 OR k = "D" THEN
            risk = risk + 1: IF risk > RISK_HIGH THEN risk = RISK_LOW
            BuildPayouts risk
        END IF
        IF k = " " THEN
            IF purse < stake THEN PlayPlinko% = MG_LEFT: EXIT FUNCTION
            purse = purse - stake
            px(0) = 0
            FOR i = 1 TO ROWS
                px(i) = px(i - 1)
                IF MgRoll%(2) = 1 THEN px(i) = px(i) + 1
                DrawBoard px(), i, risk, -1, purse, stake, "it clatters down the pegs"
                _DELAY 0.08
            NEXT i
            slot = px(ROWS)
            won = (stake * PAY(slot)) \ 100
            purse = purse + won
            DrawBoard px(), ROWS, risk, slot, purse, stake, "slot " + _TRIM$(STR$(slot)) + " pays " + MultText$(slot) + " -- you take " + _TRIM$(STR$(won))
            _DELAY 2.2
            IF won >= stake THEN PlayPlinko% = MG_WON ELSE PlayPlinko% = MG_LOST
            EXIT FUNCTION
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

' A COMPACT multiplier: "277x", "23x", "4.2x", ".55x".
'
' The first version printed two decimals always, which is unreadable on a wall of
' thirteen slots -- 277.27x is seven characters and the neighbouring values ran
' straight into each other. Big numbers do not need decimals and small ones do not
' need a leading zero.
FUNCTION MultText$ (slot AS INTEGER)
    DIM v AS DOUBLE, t AS STRING
    v = PAY(slot) / 100#
    IF v >= 10# THEN
        t = _TRIM$(STR$(INT(v + 0.5)))
    ELSEIF v >= 1# THEN
        t = _TRIM$(STR$(INT(v * 10# + 0.5) / 10))
    ELSE
        t = _TRIM$(STR$(INT(v * 100# + 0.5) / 100))
        IF LEFT$(t, 2) = "0." THEN t = MID$(t, 2)      ' ".55" not "0.55"
    END IF
    MultText$ = t + "x"
END FUNCTION

' The coin walks a TRIANGLE: at row r it sits at one of r+1 positions, and the slot
' it lands in is how many times it went right. Drawing it on the same lattice as the
' pegs is what makes the binomial legible -- you can see that the middle is fed by
' many paths and the edges by exactly one.
SUB DrawBoard (px() AS INTEGER, upto AS INTEGER, risk AS INTEGER, land AS INTEGER, purse AS LONG, stake AS LONG, msg AS STRING)
    DIM r AS INTEGER, c AS INTEGER, ox AS INTEGER, oy AS INTEGER, i AS INTEGER
    MgHeader "T H E   F O R T U N E   S H R I N E", "the middle is crowded; the edges are where the gold is"
    ox = (SW - SLOTS * SLOTW) \ 2: oy = 9
    COLOR _RGB32(&H50, &H48, &H60), 0
    FOR r = 0 TO ROWS - 1
        FOR c = 0 TO r
            MgText ox + (ROWS - r) * (SLOTW \ 2) + c * SLOTW, oy + r, "o"
        NEXT c
    NEXT r
    IF upto >= 0 THEN
        COLOR C_WARN, 0
        FOR i = 0 TO upto
            MgText ox + (ROWS - i) * (SLOTW \ 2) + px(i) * SLOTW, oy + i, "*"
        NEXT i
    END IF
    ' the payout wall, two rows so a 4-char multiplier fits under each slot
    FOR c = 0 TO SLOTS - 1
        IF c = land THEN COLOR C_GOOD, 0 ELSE COLOR C_DIM, 0
        MgText ox + c * SLOTW, oy + ROWS + 1, RIGHT$(SPACE$(SLOTW) + MultText$(c), SLOTW)
    NEXT c
    COLOR C_COOL, 0
    MgCenter oy + ROWS + 4, "nerve:  " + UCASE$(RiskName$(risk)) + "      (left/right to change)"
    COLOR C_DIM, 0
    MgCenter oy + ROWS + 5, "the shrine keeps the same cut whichever you pick -- only the swing changes"
    COLOR C_WARN, 0: MgCenter oy + ROWS + 7, "purse " + _TRIM$(STR$(purse)) + "      stake " + _TRIM$(STR$(stake))
    COLOR C_TEXT, 0: MgCenter oy + ROWS + 9, msg
    COLOR C_GOOD, 0: MgCenter oy + ROWS + 11, "[left/right] nerve     [SPACE] drop     [ESC] leave"
    _DISPLAY
END SUB

' ----------------------------------------------------------------------------
'  SELFTEST
' ----------------------------------------------------------------------------

SUB PlinkoSelfTest
    DIM i AS LONG, n AS LONG, slot AS INTEGER, hit(0 TO SLOTS - 1) AS LONG
    DIM staked AS DOUBLE, back AS DOUBLE, ret AS DOUBLE, expct AS DOUBLE, c AS INTEGER
    DIM rk AS INTEGER, sp(0 TO 2) AS DOUBLE, e(0 TO 2) AS DOUBLE
    _DEST _CONSOLE
    PRINT "PLINKO selftest"

    MgSection "the distribution is exactly binomial (Pascal, built by addition)"
    Ok "one path to the far left", PathsTo&(0) = 1
    Ok "one path to the far right", PathsTo&(ROWS) = 1
    Ok "C(12,1) = 12", PathsTo&(1) = 12
    Ok "C(12,6) = 924 -- the crowded middle", PathsTo&(6) = 924
    Ok "2^12 = 4096 paths in total", TotalPaths& = 4096
    Ok "probabilities sum to 1", ABS(SumProbs# - 1#) < 0.000001
    Ok "the centre is ~924x more likely than an edge", SlotProb#(6) / SlotProb#(0) > 900

    MgSection "the three payout curves"
    FOR rk = RISK_LOW TO RISK_HIGH
        BuildPayouts rk
        e(rk) = ExpectedReturn#: sp(rk) = ReturnSpread#
        PRINT "       "; RIGHT$("        " + RiskName$(rk), 9); ":";
        FOR c = 0 TO SLOTS - 1: PRINT USING "#####.##"; PAYX(c);: NEXT c: PRINT
    NEXT rk
    PRINT USING "       return     low #.###   med #.###   high #.###"; e(0); e(1); e(2)
    PRINT USING "       swing      low #.###   med #.###   high #.###"; sp(0); sp(1); sp(2)

    expct = (100 - SHRINE_CUT) / 100#
    Ok "low risk returns the intended cut", ABS(e(RISK_LOW) - expct) < 0.001
    Ok "medium risk returns the SAME", ABS(e(RISK_MED) - expct) < 0.001
    Ok "high risk returns the SAME", ABS(e(RISK_HIGH) - expct) < 0.001
    ' If the three curves differed in return, "risk" would just be a better or worse
    ' bet wearing a brave name, and one setting would be strictly correct.
    Ok "so no nerve setting is the RIGHT answer", ABS(e(RISK_LOW) - e(RISK_HIGH)) < 0.001
    Ok "but high risk swings much harder", sp(RISK_HIGH) > sp(RISK_LOW) * 3
    Ok "high risk has a real jackpot", PAYX(0) > 40#
    Ok "low risk never pays nothing at all", LowRiskFloor# > 0.3

    MgSection "simulation agrees with the arithmetic"
    BuildPayouts RISK_MED
    n = 300000
    RANDOMIZE 6
    FOR i = 1 TO n
        slot = DropCoin%
        hit(slot) = hit(slot) + 1
        staked = staked + 1#
        back = back + PAYX(slot)
    NEXT i
    ret = back / staked
    PRINT USING "       simulated #.###   exact #.###"; ret; ExpectedReturn#
    Ok "simulated return matches the exact model", ABS(ret - ExpectedReturn#) < 0.05
    Ok "the centre really is the most common slot", MostCommonSlot%(hit()) = ROWS \ 2
    Ok "the far edge really is vanishingly rare", hit(0) < n / 500

    MgDone
END SUB

FUNCTION SumProbs# ()
    DIM i AS INTEGER, t AS DOUBLE
    FOR i = 0 TO SLOTS - 1: t = t + SlotProb#(i): NEXT i
    SumProbs# = t
END FUNCTION

' The worst slot on the steady board -- what a cautious player takes on a bad drop.
FUNCTION LowRiskFloor# ()
    DIM i AS INTEGER, lo AS DOUBLE
    BuildPayouts RISK_LOW
    lo = 999#
    FOR i = 0 TO SLOTS - 1: IF PAYX(i) < lo THEN lo = PAYX(i)
    NEXT i
    LowRiskFloor# = lo
END FUNCTION

FUNCTION MostCommonSlot% (hit() AS LONG)
    DIM i AS INTEGER, best AS INTEGER
    FOR i = 0 TO SLOTS - 1
        IF hit(i) > hit(best) THEN best = i
    NEXT i
    MostCommonSlot% = best
END FUNCTION

'$INCLUDE:'MG.bas'
