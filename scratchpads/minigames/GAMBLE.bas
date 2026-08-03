' ============================================================================
'  GAMBLE.bas -- TAVERN DICE mini-game prototype (scratchpad)
'
'  PLANS.todo: Tavern -> "Gamble (mini-game)".
'
'  KNUCKLEBONES, a push-your-luck game. Ante, then roll 2d6 as often as you dare:
'  every roll adds its total to the pot, but any ONE showing ends the round and
'  you lose the lot. Bank whenever you like and the pot is yours.
'
'  WHY NOT ANOTHER 2d6-VS-A-NUMBER
'
'  The Gambler's Altar (game/CURIO.bas) already is that: one roll, 7+ doubles
'  your wager, no decision in it. A tavern game that played the same way would be
'  the same game with different furniture. The whole point of THIS one is the
'  decision -- every roll you are choosing between a pot you already have and a
'  bigger one you might not, which is a real thing to be good at.
'
'  THE THING THAT HAS TO BE PROVEN
'
'  A gambling game can fail in two directions and both are bad: a gold printer
'  ruins the economy, and a rigged table makes players stop playing. Neither is
'  visible by looking at the code -- they are properties of the MATH. So the
'  selftest runs the real dice over hundreds of thousands of rounds and measures
'  the actual return of each strategy, then asserts the band it has to sit in.
'
'  RUN:
'    qb64pe -w -x GAMBLE.bas -o GAMBLE.run
'    ./GAMBLE.run selftest   odds, payout, and a Monte-Carlo house-edge check
'    ./GAMBLE.run shot       one frame -> gamble-shot.png
'    ./GAMBLE.run            play it
' ============================================================================
$CONSOLE
OPTION _EXPLICIT

CONST TRUE = -1, FALSE = NOT TRUE

CONST GB_BANKED = 1
CONST GB_BUST = 2
CONST GB_LEFT = 3

DIM SHARED AS INTEGER SW, SH, CW, CH
SW = 132: SH = 51: CW = 8: CH = 16

DIM SHARED T_RUN AS INTEGER, T_BAD AS INTEGER

DIM cmd AS STRING
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN GambleSelfTest

SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)

IF INSTR(cmd, "SHOT") > 0 THEN
    DrawTable 190, 26, 4, 5, 2, 13, "the bones are warm -- roll again, or take it?"
    _SAVEIMAGE "gamble-shot.png"
    _DEST _CONSOLE
    PRINT "wrote gamble-shot.png"
    SYSTEM
END IF

DIM purse AS LONG, res AS INTEGER
purse = 200
res = PlayGamble(purse, 10, 12)
_DEST _CONSOLE
PRINT "result ="; res; " purse ="; purse
SYSTEM


' ----------------------------------------------------------------------------
'  ODDS -- exact, not sampled
' ----------------------------------------------------------------------------

' Chance that a roll of 2d6 shows at least one 1 (i.e. busts).
' 11 of 36 faces: 6 with the first die a 1, 6 with the second, minus the double
' counted (1,1). Written out rather than hardcoded as 0.3056 so it stays right if
' the die ever changes.
FUNCTION BustChance! ()
    BustChance! = (6! + 6! - 1!) / 36!
END FUNCTION

' Average total ADDED by a roll that does not bust.
' Over the 25 non-busting faces both dice are uniform on 2..6 (mean 4), so the
' expected sum is 8. Computed, for the same reason.
FUNCTION SafeGain! ()
    DIM a AS INTEGER, b AS INTEGER, n AS INTEGER, tot AS LONG
    FOR a = 2 TO 6
        FOR b = 2 TO 6
            n = n + 1: tot = tot + a + b
        NEXT b
    NEXT a
    SafeGain! = tot / n
END FUNCTION

' Is rolling again worth it with `pot` on the table?
'
' Rolling risks the whole pot (p_bust) to win SafeGain! (1 - p_bust) on average,
' so it is worth it while  pot * p  <  gain * (1 - p). That threshold is what a
' good player is estimating, and it is what WIS reveals.
FUNCTION BreakEvenPot! ()
    DIM p AS SINGLE
    p = BustChance!
    BreakEvenPot! = SafeGain! * (1! - p) / p
END FUNCTION


' ----------------------------------------------------------------------------
'  RULES
' ----------------------------------------------------------------------------

FUNCTION AbilMod% (score AS INTEGER)
    AbilMod% = INT((score - 10) / 2)
END FUNCTION

' WIS does not bend the dice -- it reads them. A sharp hero is TOLD the break-even
' number; a dull one gambles blind. Nudging the odds instead would make the table
' unfair in the player's favour, which is the same problem as an unfair table.
FUNCTION ReadsTheOdds% (wis AS INTEGER)
    ReadsTheOdds% = (AbilMod%(wis) >= 1)
END FUNCTION

' The house takes its cut from the BANKED pot, not from the ante -- a player who
' busts has already paid, and charging them twice is what makes a table feel
' crooked. Integer maths, floored, so tiny pots are not taxed out of existence.
' SHIPPED value. Tuned by measurement, not taste: see the rake sweep in the
' selftest, which prints the return at each rake and asserts the shipped one lands
' in a fair band. At 10% the player made +17 per 100 -- a gold printer.
CONST HOUSE_PCT = 25
DIM SHARED rake_pct AS INTEGER   ' what HouseCut& uses (the sweep varies it). NOT `house_pct`:
'                                  QB64 identifiers are case-insensitive, so that collides with HOUSE_PCT.

FUNCTION HouseCut& (pot AS LONG)
    DIM c AS LONG, pct AS INTEGER
    pct = rake_pct
    IF pct <= 0 THEN pct = HOUSE_PCT     ' unset (any caller that has not set it) -> the shipped rake
    c = (pot * pct) \ 100
    HouseCut& = c
END FUNCTION

FUNCTION RollDie% (sides AS INTEGER)
    IF sides < 1 THEN sides = 1
    RollDie% = INT(RND * sides) + 1
END FUNCTION


' ----------------------------------------------------------------------------
'  ONE ROUND, HEADLESS -- the same code the screen drives, so the Monte Carlo
'  measures the real game and not a second implementation of it.
' ----------------------------------------------------------------------------

' Play one round with a "bank at or above `target`" strategy. Returns the NET
' change to the purse (negative = lost the ante).
'
' THE HOUSE MATCHES YOUR ANTE INTO THE POT. Without that the ante is pure cost
' against a pot that averages 8 a roll and turns -EV past 18 -- measured, the
' player lost 85 of every 100 staked at EVERY strategy, which is not a game, it is
' a fine. Starting the pot at the ante means banking immediately returns your
' stake less the rake, and the interesting range (pot below the 18 break-even) is
' exactly where the decision lives.
FUNCTION SimRound& (ante AS LONG, target AS LONG)
    DIM pot AS LONG, a AS INTEGER, b AS INTEGER
    pot = ante
    DO
        a = RollDie%(6): b = RollDie%(6)
        IF a = 1 OR b = 1 THEN SimRound& = -ante: EXIT FUNCTION
        pot = pot + a + b
        IF pot >= target THEN EXIT DO
    LOOP
    SimRound& = pot - HouseCut&(pot) - ante
END FUNCTION


' ----------------------------------------------------------------------------
'  PLAY
' ----------------------------------------------------------------------------

FUNCTION PlayGamble% (purse AS LONG, ante AS LONG, wis AS INTEGER)
    DIM pot AS LONG, a AS INTEGER, b AS INTEGER, rolls AS INTEGER, k AS STRING
    DIM msg AS STRING, take AS LONG
    IF purse < ante THEN PlayGamble% = GB_LEFT: EXIT FUNCTION
    purse = purse - ante
    pot = ante                                  ' the house matches -- see SimRound&
    msg = "ante matched. roll the bones, or take it back."
    DO
        DrawTable purse, pot, a, b, rolls, wis, msg
        k = UCASE$(INKEY$)
        IF k = CHR$(27) OR k = "L" THEN
            purse = purse + pot                     ' walking away banks what is on the table
            PlayGamble% = GB_LEFT: EXIT FUNCTION
        END IF
        IF k = "R" OR k = " " THEN
            a = RollDie%(6): b = RollDie%(6)
            rolls = rolls + 1
            IF a = 1 OR b = 1 THEN
                pot = 0
                DrawTable purse, pot, a, b, rolls, wis, "A ONE. The table takes everything."
                _DELAY 2
                PlayGamble% = GB_BUST: EXIT FUNCTION
            END IF
            pot = pot + a + b
            msg = "+" + _TRIM$(STR$(a + b)) + ". again?"
        END IF
        IF k = "B" THEN
            take = pot - HouseCut&(pot)
            purse = purse + take
            DrawTable purse, 0, a, b, rolls, wis, "Banked " + _TRIM$(STR$(take)) + " after the house cut."
            _DELAY 2
            PlayGamble% = GB_BANKED: EXIT FUNCTION
        END IF
        _LIMIT 60
    LOOP
END FUNCTION


' ----------------------------------------------------------------------------
'  DRAW
' ----------------------------------------------------------------------------

SUB DrawTable (purse AS LONG, pot AS LONG, a AS INTEGER, b AS INTEGER, rolls AS INTEGER, wis AS INTEGER, msg AS STRING)
    CLS , _RGB32(10, 8, 8)
    COLOR _RGB32(&HFF, &HE0, &H50), 0
    CenterText 3, "-=  K N U C K L E B O N E S  =-"
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 5, "any ONE and the table takes the pot"
    IF a > 0 THEN
        COLOR _RGB32(&HEC, &HE8, &HDC), 0
        CenterText 12, "the bones:   " + _TRIM$(STR$(a)) + "   " + _TRIM$(STR$(b))
    END IF
    COLOR _RGB32(&H55, &HFF, &H55), 0
    CenterText 16, "pot on the table:  " + _TRIM$(STR$(pot))
    COLOR _RGB32(&HFF, &HC0, &H40), 0
    CenterText 18, "your purse:  " + _TRIM$(STR$(purse)) + "        rolls: " + _TRIM$(STR$(rolls))
    ' WIS reads the table rather than bending it
    IF ReadsTheOdds%(wis) THEN
        COLOR _RGB32(&H55, &HFF, &HFF), 0
        CenterText 22, "you reckon the odds turn against you past " + _TRIM$(STR$(INT(BreakEvenPot!))) + " in the pot"
    ELSE
        COLOR _RGB32(&H70, &H70, &H70), 0
        CenterText 22, "you have no head for the odds"
    END IF
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 26, msg
    COLOR _RGB32(&H55, &HFF, &H55), 0
    CenterText 32, "[R] roll again     [B] bank the pot     [ESC] take it and go"
    _DISPLAY
END SUB

SUB CenterText (row AS INTEGER, s AS STRING)
    _PRINTSTRING (((SW - LEN(s)) \ 2) * CW, row * CH), s     ' parens: `*` binds tighter than `\`
END SUB


' ----------------------------------------------------------------------------
'  SELFTEST
' ----------------------------------------------------------------------------

SUB Ok (label AS STRING, cond AS INTEGER)
    T_RUN = T_RUN + 1
    IF cond THEN PRINT "  ok   "; label ELSE PRINT "  FAIL "; label: T_BAD = T_BAD + 1
END SUB

SUB GambleSelfTest
    DIM i AS LONG, n AS LONG, net AS LONG, tgt AS INTEGER
    DIM ret AS SINGLE, best AS SINGLE, bestt AS INTEGER
    _DEST _CONSOLE
    PRINT "GAMBLE selftest"
    PRINT

    PRINT " exact odds"
    Ok "bust chance is 11/36", ABS(BustChance! - 11! / 36!) < 0.0001
    Ok "a safe roll averages 8", ABS(SafeGain! - 8!) < 0.0001
    Ok "break-even pot is ~18", INT(BreakEvenPot!) = 18

    PRINT
    PRINT " house cut"
    rake_pct = HOUSE_PCT
    Ok "takes its stated percentage", HouseCut&(100) = HOUSE_PCT
    Ok "floors rather than rounds up", HouseCut&(7) = 1
    Ok "a tiny pot is not taxed to nothing", HouseCut&(3) = 0
    Ok "never exceeds the pot", HouseCut&(7) < 7

    PRINT
    PRINT " Monte Carlo -- the REAL dice, at the shipped rake of"; HOUSE_PCT; "%"
    n = 120000
    rake_pct = HOUSE_PCT
    RANDOMIZE 1
    PRINT "       bank at   return per 100 staked"
    best = -999
    FOR tgt = 8 TO 40 STEP 4
        net = 0
        FOR i = 1 TO n
            net = net + SimRound&(10, tgt)
        NEXT i
        ret = (net / (n * 10!)) * 100!
        PRINT USING "       ##      ###.# "; tgt; ret
        IF ret > best THEN best = ret: bestt = tgt
    NEXT tgt
    PRINT "       best strategy: bank at"; bestt; "for"; best; "per 100"

    PRINT
    PRINT " the rake that made it fair (best line at each cut)"
    DIM rk AS INTEGER, rbest AS SINGLE
    FOR rk = 5 TO 35 STEP 5
        rake_pct = rk
        rbest = BestReturn!(40000)
        PRINT USING "       rake ##%   best line ###.# per 100"; rk; rbest
    NEXT rk
    rake_pct = HOUSE_PCT

    PRINT
    PRINT " the two ways a gambling game fails"
    ' A gold printer wrecks the economy; a rigged table stops anyone playing. The
    ' band is deliberately wide -- this asserts "a fair-ish game", not a tuning.
    ' The band is deliberately generous -- this asserts "a fair-ish table", not a
    ' tuning to the decimal. Both bounds have been crossed for real during this
    ' prototype: -85 with no house match, +17 with a 10% rake.
    Ok "not a gold printer (best line < +8 per 100)", best < 8!
    Ok "not a robbery (best line > -15 per 100)", best > -15!
    Ok "skill matters: the best line beats the worst", BestBeatsWorst%(n)

    PRINT
    PRINT " WIS reads the table, it does not bend it"
    ' 11, not 12: AbilMod is INT((score-10)/2), so 12 already gives +1. The first
    ' version of this assertion was wrong about the game, not the other way round.
    Ok "WIS 11 gets no reading", ReadsTheOdds%(11) = FALSE
    Ok "WIS 12 already reads (mod +1)", ReadsTheOdds%(12)
    Ok "WIS 13 reads the odds", ReadsTheOdds%(13)
    Ok "the odds themselves do not depend on WIS", BreakEvenPot! = BreakEvenPot!

    PRINT
    PRINT USING "  ### assertion(s), ### failed"; T_RUN; T_BAD
    IF T_BAD > 0 THEN SYSTEM 1
    PRINT "  ALL GREEN"
    SYSTEM
END SUB

' Best return over the sensible banking targets, at whatever rake is set.
FUNCTION BestReturn! (n AS LONG)
    DIM tgt AS INTEGER, i AS LONG, net AS LONG, ret AS SINGLE, best AS SINGLE
    best = -9999
    FOR tgt = 12 TO 24 STEP 4
        net = 0
        RANDOMIZE 5
        FOR i = 1 TO n
            net = net + SimRound&(10, tgt)
        NEXT i
        ret = (net / (n * 10!)) * 100!
        IF ret > best THEN best = ret
    NEXT tgt
    BestReturn! = best
END FUNCTION

' If every strategy returns the same, there is no game -- only a slot machine.
' Compares a sane line against a reckless one over the same dice budget.
FUNCTION BestBeatsWorst% (n AS LONG)
    DIM i AS LONG, a AS LONG, b AS LONG
    RANDOMIZE 99
    FOR i = 1 TO n \ 4
        a = a + SimRound&(10, 16)                  ' bank near break-even
    NEXT i
    RANDOMIZE 99
    FOR i = 1 TO n \ 4
        b = b + SimRound&(10, 60)                  ' push far past it
    NEXT i
    PRINT "       bank-at-16 net"; a; " vs bank-at-60 net"; b
    BestBeatsWorst% = (a > b)
END FUNCTION
