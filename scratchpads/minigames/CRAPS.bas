' ============================================================================
'  CRAPS.bas -- tavern craps (pass line) prototype
'
'  Real craps, pass-line only. COME-OUT roll: 7 or 11 wins, 2/3/12 is craps and
'  loses, anything else becomes your POINT. Then you roll until the point comes
'  again (win) or a 7 arrives first (lose).
'
'  WHY THIS ONE IS WORTH BUILDING EVEN THOUGH IT HAS NO DECISION
'
'  Pass-line craps genuinely has no choice in it -- and that is the point of
'  having it next to Knucklebones. Knucklebones is the game you can be good at;
'  craps is the one the room plays, loud and fast, where the only judgement is
'  whether to step up at all. Two gambling games with the SAME decision would be
'  one game twice.
'
'  It also has something no invented game has: a house edge that is a known,
'  published number. Pass line is 1.414% -- 244/495 wins against 251/495 losses.
'  So the selftest does not assert a made-up band, it asserts the REAL figure,
'  which makes it a check on the dice and the resolution logic rather than on my
'  taste.
'
'  RUN:  ./CRAPS.run selftest | shot | (play)
' ============================================================================
'$INCLUDE:'MG.bi'

'--- phase ---
CONST CR_COMEOUT = 0
CONST CR_POINT = 1

DIM cmd AS STRING
ON ERROR GOTO MgFatal          ' no modal dialogs -- see the handler below
MgInit
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN CrapsSelfTest

MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    DrawCraps 4, 5, 6, CR_POINT, 120, 20, "the point is 6 -- roll it again before a 7"
    _SAVEIMAGE "craps-shot.png"
    _DEST _CONSOLE: PRINT "wrote craps-shot.png": SYSTEM
END IF

DIM purse AS LONG, r AS INTEGER
purse = 200
r = PlayCraps(purse, 20)
_DEST _CONSOLE: PRINT "result ="; r; " purse ="; purse: SYSTEM


' ----------------------------------------------------------------------------
'  RULES -- pure, and where the assertions go
' ----------------------------------------------------------------------------

' Resolve a COME-OUT roll: 1 win, -1 lose, 0 = this total becomes the point.

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

FUNCTION ComeOut% (total AS INTEGER)
    SELECT CASE total
        CASE 7, 11: ComeOut% = 1                  ' a natural
        CASE 2, 3, 12: ComeOut% = -1              ' craps
        CASE ELSE: ComeOut% = 0                   ' 4 5 6 8 9 10 -- the point
    END SELECT
END FUNCTION

' Resolve a roll while chasing `pnt` (the point): 1 win, -1 lose (a seven-out), 0 keep rolling.
FUNCTION PointRoll% (total AS INTEGER, pnt AS INTEGER)
    IF total = pnt THEN PointRoll% = 1: EXIT FUNCTION
    IF total = 7 THEN PointRoll% = -1: EXIT FUNCTION
    PointRoll% = 0
END FUNCTION

' 2d6 for the Monte Carlo. NOT a die the player rolls -- this runs hundreds of
' thousands of times with nobody watching, so it must never route through
' GameRoll% and must never be able to prompt. See audit-dice.sh.
FUNCTION SimRoll2% ()
    SimRoll2% = MgRoll%(6) + MgRoll%(6)   ' not a die: headless Monte Carlo
END FUNCTION

' Play one full hand headlessly. 1 = pass, -1 = don't. Same resolution the screen
' drives, so the Monte Carlo measures the real game.
FUNCTION SimHand% ()
    DIM t AS INTEGER, p AS INTEGER, res AS INTEGER
    t = SimRoll2%                      ' not a die the player rolls -- see below
    res = ComeOut%(t)
    IF res <> 0 THEN SimHand% = res: EXIT FUNCTION
    p = t
    DO
        t = SimRoll2%
        res = PointRoll%(t, p)
        IF res <> 0 THEN SimHand% = res: EXIT FUNCTION
    LOOP
END FUNCTION

' The exact probability of winning a pass-line bet, worked from the definition
' rather than quoted: 244/495. Kept as a function so the test compares the
' simulation against arithmetic, not against a number I typed in.
FUNCTION PassWinProb# ()
    DIM t AS INTEGER, w AS DOUBLE, pt AS DOUBLE, pp AS DOUBLE
    ' naturals on the come-out
    w = (WaysFor%(7) + WaysFor%(11)) / 36#
    ' each point: P(establish it) * P(repeat it before a 7)
    FOR t = 4 TO 10
        IF t <> 7 THEN
            pt = WaysFor%(t) / 36#
            pp = WaysFor%(t) / (WaysFor%(t) + WaysFor%(7))
            w = w + pt * pp
        END IF
    NEXT t
    PassWinProb# = w
END FUNCTION

' How many of the 36 faces of 2d6 make `total`.
FUNCTION WaysFor% (total AS INTEGER)
    DIM a AS INTEGER, b AS INTEGER, n AS INTEGER
    FOR a = 1 TO 6
        FOR b = 1 TO 6
            IF a + b = total THEN n = n + 1
        NEXT b
    NEXT a
    WaysFor% = n
END FUNCTION


' ----------------------------------------------------------------------------
'  PLAY
' ----------------------------------------------------------------------------

FUNCTION PlayCraps% (purse AS LONG, bet AS LONG)
    DIM a AS INTEGER, b AS INTEGER, t AS INTEGER, pnt AS INTEGER
    DIM phase AS INTEGER, res AS INTEGER, k AS STRING, msg AS STRING
    IF purse < bet THEN PlayCraps% = MG_LEFT: EXIT FUNCTION
    purse = purse - bet
    phase = CR_COMEOUT: msg = "come-out roll -- 7 or 11 wins, 2/3/12 craps out"
    DO
        DrawCraps a, b, pnt, phase, purse, bet, msg
        k = UCASE$(INKEY$)
        IF k = CHR$(27) THEN purse = purse + bet: PlayCraps% = MG_LEFT: EXIT FUNCTION
        IF k = " " OR k = "R" THEN
            ' 2d6 as ONE roll: pass-line resolves entirely on the TOTAL, so Real
            ' Dice can ask for the total and the game needs nothing else. The two
            ' faces are only for the picture, and DieFace% honestly reports none
            ' when the player rolled physical dice.
            t = GameRoll%(2, 6, 0, "the come-out")
            a = DieFace%(1): b = DieFace%(2)
            IF phase = CR_COMEOUT THEN
                res = ComeOut%(t)
                IF res = 1 THEN
                    purse = purse + bet * 2
                    DrawCraps a, b, pnt, phase, purse, bet, "A natural -- " + _TRIM$(STR$(t)) + ". You double your stake."
                    _DELAY 2: PlayCraps% = MG_WON: EXIT FUNCTION
                ELSEIF res = -1 THEN
                    DrawCraps a, b, pnt, phase, purse, bet, "Craps -- " + _TRIM$(STR$(t)) + ". The table takes it."
                    _DELAY 2: PlayCraps% = MG_LOST: EXIT FUNCTION
                ELSE
                    pnt = t: phase = CR_POINT
                    msg = "the point is " + _TRIM$(STR$(pnt)) + " -- roll it again before a 7"
                END IF
            ELSE
                res = PointRoll%(t, pnt)
                IF res = 1 THEN
                    purse = purse + bet * 2
                    DrawCraps a, b, pnt, phase, purse, bet, "You made the point. Double."
                    _DELAY 2: PlayCraps% = MG_WON: EXIT FUNCTION
                ELSEIF res = -1 THEN
                    DrawCraps a, b, pnt, phase, purse, bet, "Seven out. The table takes it."
                    _DELAY 2: PlayCraps% = MG_LOST: EXIT FUNCTION
                ELSE
                    msg = _TRIM$(STR$(t)) + ". Again -- still chasing " + _TRIM$(STR$(pnt)) + "."
                END IF
            END IF
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

SUB DrawCraps (a AS INTEGER, b AS INTEGER, pnt AS INTEGER, phase AS INTEGER, purse AS LONG, bet AS LONG, msg AS STRING)
    MgHeader "C R A P S", "the table is loud and nobody here is patient"
    IF a > 0 THEN
        COLOR C_TEXT, 0: MgCenter 12, "the bones:   " + _TRIM$(STR$(a)) + "   " + _TRIM$(STR$(b)) + "      =" + STR$(a + b)
    END IF
    IF phase = CR_POINT THEN
        COLOR C_COOL, 0: MgCenter 15, "THE POINT:  " + _TRIM$(STR$(pnt))
        COLOR C_DIM, 0: MgCenter 17, "roll " + _TRIM$(STR$(pnt)) + " to win  ---  roll 7 and it is over"
    ELSE
        COLOR C_COOL, 0: MgCenter 15, "COME-OUT"
        COLOR C_DIM, 0: MgCenter 17, "7 or 11 wins  ---  2, 3 or 12 craps out"
    END IF
    COLOR C_WARN, 0: MgCenter 21, "purse " + _TRIM$(STR$(purse)) + "      staked " + _TRIM$(STR$(bet))
    COLOR C_TEXT, 0: MgCenter 25, msg
    COLOR C_GOOD, 0: MgCenter 31, "[SPACE] roll     [ESC] step away"
    _DISPLAY
END SUB


' ----------------------------------------------------------------------------
'  SELFTEST
' ----------------------------------------------------------------------------

SUB CrapsSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM i AS LONG, n AS LONG, w AS LONG, p AS DOUBLE, sim AS DOUBLE, edge AS DOUBLE
    _DEST _CONSOLE
    PRINT "CRAPS selftest"

    ' AFTER _DEST _CONSOLE: an Ok before that prints to the graphics page, and
    ' eight assertions ran invisibly the first time this was wired up.
    MgDiceSelfTest

    MgSection "the come-out"
    Ok "7 is a natural", ComeOut%(7) = 1
    Ok "11 is a natural", ComeOut%(11) = 1
    Ok "2 craps out", ComeOut%(2) = -1
    Ok "3 craps out", ComeOut%(3) = -1
    Ok "12 craps out", ComeOut%(12) = -1
    Ok "4 becomes a pnt", ComeOut%(4) = 0
    Ok "6 becomes a pnt", ComeOut%(6) = 0
    Ok "10 becomes a pnt", ComeOut%(10) = 0

    MgSection "chasing the point"
    Ok "hitting the point wins", PointRoll%(6, 6) = 1
    Ok "a seven loses", PointRoll%(7, 6) = -1
    Ok "anything else rolls on", PointRoll%(5, 6) = 0
    Ok "11 does NOT win once a pnt is set", PointRoll%(11, 6) = 0
    Ok "2 does NOT lose once a pnt is set", PointRoll%(2, 6) = 0

    MgSection "the 2d6 distribution"
    Ok "6 ways to make 7", WaysFor%(7) = 6
    Ok "1 way to make 2", WaysFor%(2) = 1
    Ok "5 ways to make 6", WaysFor%(6) = 5
    Ok "36 faces in total", TotalWays% = 36

    MgSection "the house edge is a KNOWN number, not one I chose"
    p = PassWinProb#
    PRINT USING "       exact pass-line win probability  #.#####"; p
    PRINT USING "       published figure  244/495     =  #.#####"; 244# / 495#
    Ok "matches 244/495 exactly", ABS(p - 244# / 495#) < 0.000001
    edge = (1# - p) - p
    PRINT USING "       house edge  #.###%"; edge * 100#
    Ok "house edge is the published 1.414%", ABS(edge * 100# - 1.414#) < 0.01

    MgSection "and the SIMULATION agrees with the arithmetic"
    n = 400000
    RANDOMIZE 11
    FOR i = 1 TO n
        IF SimHand% = 1 THEN w = w + 1
    NEXT i
    sim = w / n
    PRINT USING "       simulated over ####### hands   #.#####"; n; sim
    ' 400k hands puts the standard error near 0.0008, so 0.004 is ~5 sigma: wide
    ' enough never to flake, tight enough to catch a real resolution bug.
    Ok "simulated win rate matches the exact probability", ABS(sim - p) < 0.004

    MgDone
END SUB

FUNCTION TotalWays% ()
    DIM t AS INTEGER, n AS INTEGER
    FOR t = 2 TO 12: n = n + WaysFor%(t): NEXT t
    TotalWays% = n
END FUNCTION

'$INCLUDE:'MG.bas'
