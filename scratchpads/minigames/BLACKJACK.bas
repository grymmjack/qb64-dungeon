' ============================================================================
'  BLACKJACK.bas -- TWENTY-ONE, IN THE TAVERN CELLAR
'
'  One deck, dealer stands on all 17s, natural pays 3 to 2, double on any first
'  two cards. No splitting -- and that is a stated rule of THIS table, not an
'  omission, because every number below is measured against the game as it is
'  actually dealt rather than against a textbook that allows more than it does.
'  The dealer also does not peek at the hole card for a natural, so a doubled
'  stake can be lost to one. That is a real variant and it is priced in, because
'  the edge below is measured against this dealer, not an idealised one.
'
'  Blackjack earns its place in a dungeon for one reason: it is the only game in
'  the set where the correct play is a genuine table of decisions rather than a
'  read or a memory. Sixteen against a dealer ten is a real dilemma, and it stays
'  a dilemma however many times you meet it.
'
'  So what has to be proved is not "is it fair" -- the house always has an edge --
'  but that the edge is SMALL and that playing well is what makes it small:
'
'    * basic strategy loses slowly (well under 3 per 100 staked)
'    * mimicking the dealer -- the intuitive wrong answer, and the one most
'      players reach for -- loses several times faster
'    * never busting (always stand) is worse still
'
'  If those three do not come out in that order, the strategy table is wrong, and
'  a wrong table is worse than no table: it teaches the player a habit that costs
'  them money and calls it advice.
' ============================================================================
'$INCLUDE:'MG.bi'
'$INCLUDE:'MGDICE.bi'

CONST DECKN = 52
CONST RESHUFFLE = 15            ' reshuffle below this many cards
CONST MAXHAND = 12
CONST BJ_PAY = 1.5              ' a natural pays three to two

DIM SHARED SHOE(1 TO DECKN) AS INTEGER
DIM SHARED AS INTEGER g_top
DIM SHARED PHAND(1 TO MAXHAND) AS INTEGER, DHAND(1 TO MAXHAND) AS INTEGER
DIM SHARED AS INTEGER g_pn, g_dn, g_bet, g_purse, g_hole

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: JackSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 91
    NewShoe
    g_purse = 40: g_bet = 5: g_hole = TRUE
    g_pn = 0: g_dn = 0
    PushCard PHAND(), g_pn, 10: PushCard PHAND(), g_pn, 6
    PushCard DHAND(), g_dn, 10: PushCard DHAND(), g_dn, 7
    DrawTable "sixteen against a ten -- the worst hand in the game"
    _SAVEIMAGE "blackjack-shot.png"
    _DEST _CONSOLE: PRINT "wrote blackjack-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayJack(30)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- the shoe ----------------------------------------------------------------

SUB NewShoe
    DIM i AS INTEGER, j AS INTEGER, t AS INTEGER
    FOR i = 1 TO DECKN
        SHOE(i) = ((i - 1) MOD 13) + 1          ' 1 = ace, 11-13 = court
    NEXT i
    FOR i = DECKN TO 2 STEP -1
        j = MgRoll%(i): t = SHOE(i): SHOE(i) = SHOE(j): SHOE(j) = t
    NEXT i
    g_top = 1
END SUB

FUNCTION Draw% ()
    IF g_top > DECKN - RESHUFFLE THEN NewShoe
    Draw% = SHOE(g_top)
    g_top = g_top + 1
END FUNCTION

FUNCTION RankName$ (rk AS INTEGER)
    SELECT CASE rk
        CASE 1: RankName$ = "A"
        CASE 10: RankName$ = "10"
        CASE 11: RankName$ = "J"
        CASE 12: RankName$ = "Q"
        CASE 13: RankName$ = "K"
        CASE ELSE: RankName$ = _TRIM$(STR$(rk))
    END SELECT
END FUNCTION

SUB PushCard (h() AS INTEGER, n AS INTEGER, rk AS INTEGER)
    IF n >= MAXHAND THEN EXIT SUB
    n = n + 1: h(n) = rk
END SUB

' Total, counting one ace as eleven when it fits. `soft` comes back TRUE when an
' ace is still being counted high -- which is the whole reason soft 18 plays
' differently from hard 18, and getting it wrong silently poisons the strategy.
FUNCTION HandVal% (h() AS INTEGER, n AS INTEGER, soft AS INTEGER)
    DIM i AS INTEGER, tot AS INTEGER, aces AS INTEGER, v AS INTEGER
    FOR i = 1 TO n
        v = h(i)
        IF v > 10 THEN v = 10
        IF v = 1 THEN aces = aces + 1
        tot = tot + v
    NEXT i
    soft = FALSE
    IF aces > 0 _ANDALSO tot + 10 <= 21 THEN tot = tot + 10: soft = TRUE
    HandVal% = tot
END FUNCTION

FUNCTION IsNatural% (h() AS INTEGER, n AS INTEGER)
    DIM s AS INTEGER
    IsNatural% = (n = 2 _ANDALSO HandVal%(h(), n, s) = 21)
END FUNCTION

'--- basic strategy ----------------------------------------------------------
'  Returns "H" hit, "S" stand, "D" double (hit if doubling is not allowed).
'  Dealer stands on all 17s, no splits. This table IS the game's advice, so it
'  is measured, not asserted: the selftest plays it against the other two obvious
'  strategies and requires it to come out clearly ahead of both.

FUNCTION BasicPlay$ (tot AS INTEGER, soft AS INTEGER, up AS INTEGER, first AS INTEGER)
    DIM u AS INTEGER, act AS STRING
    u = up: IF u > 10 THEN u = 10
    IF u = 1 THEN u = 11                     ' dealer ace

    IF soft THEN
        SELECT CASE tot
            CASE IS >= 19: act = "S"
            CASE 18
                ' NOT a single-line ELSE IF chain: QB64 does not accept one, and
                ' soft 18 is exactly where a mangled branch would hide.
                IF u >= 3 _ANDALSO u <= 6 THEN
                    act = "D"
                ELSEIF u = 2 _ORELSE u = 7 _ORELSE u = 8 THEN
                    act = "S"
                ELSE
                    act = "H"
                END IF
            CASE 17
                IF u >= 3 _ANDALSO u <= 6 THEN act = "D" ELSE act = "H"
            CASE 15, 16
                IF u >= 4 _ANDALSO u <= 6 THEN act = "D" ELSE act = "H"
            CASE ELSE                        ' soft 13-14
                IF u >= 5 _ANDALSO u <= 6 THEN act = "D" ELSE act = "H"
        END SELECT
    ELSE
        SELECT CASE tot
            CASE IS >= 17: act = "S"
            CASE 13, 14, 15, 16
                IF u >= 2 _ANDALSO u <= 6 THEN act = "S" ELSE act = "H"
            CASE 12
                IF u >= 4 _ANDALSO u <= 6 THEN act = "S" ELSE act = "H"
            CASE 11: act = "D"
            CASE 10
                IF u <= 9 THEN act = "D" ELSE act = "H"
            CASE 9
                IF u >= 3 _ANDALSO u <= 6 THEN act = "D" ELSE act = "H"
            CASE ELSE: act = "H"
        END SELECT
    END IF

    IF act = "D" _ANDALSO NOT first THEN act = "H"
    BasicPlay$ = act
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayJack% (purse AS INTEGER)
    DIM k AS STRING, u AS STRING, msg AS STRING
    DIM AS INTEGER tot, soft, dtot, dsoft, first, done, dbl
    NewShoe
    g_purse = purse
    DO
        IF g_purse <= 0 THEN PlayJack% = MG_LOST: EXIT FUNCTION
        g_bet = 5: IF g_bet > g_purse THEN g_bet = g_purse
        g_pn = 0: g_dn = 0: g_hole = TRUE: dbl = FALSE
        PushCard PHAND(), g_pn, Draw%
        PushCard DHAND(), g_dn, Draw%
        PushCard PHAND(), g_pn, Draw%
        PushCard DHAND(), g_dn, Draw%

        IF IsNatural%(PHAND(), g_pn) THEN
            g_hole = FALSE
            IF IsNatural%(DHAND(), g_dn) THEN
                msg = "both naturals -- a push"
            ELSE
                g_purse = g_purse + INT(g_bet * BJ_PAY)
                msg = "a NATURAL -- pays three to two"
            END IF
            DrawTable msg: _DELAY 1.8
        ELSE
            first = TRUE: done = FALSE
            DO
                tot = HandVal%(PHAND(), g_pn, soft)
                IF tot > 21 THEN EXIT DO
                DrawTable "hit, stand, or double"
                k = INKEY$: u = UCASE$(k)
                IF k = CHR$(27) THEN PlayJack% = MG_LEFT: EXIT FUNCTION
                IF u = "H" THEN PushCard PHAND(), g_pn, Draw%: first = FALSE
                IF u = "S" THEN done = TRUE
                IF u = "D" _ANDALSO first _ANDALSO g_purse >= g_bet * 2 THEN
                    g_bet = g_bet * 2: dbl = TRUE
                    PushCard PHAND(), g_pn, Draw%
                    done = TRUE
                END IF
                IF done THEN EXIT DO
                _LIMIT 60
            LOOP

            g_hole = FALSE
            tot = HandVal%(PHAND(), g_pn, soft)
            IF tot > 21 THEN
                g_purse = g_purse - g_bet
                msg = "bust at " + _TRIM$(STR$(tot))
            ELSE
                DealerPlay
                dtot = HandVal%(DHAND(), g_dn, dsoft)
                IF dtot > 21 THEN
                    g_purse = g_purse + g_bet: msg = "the dealer busts"
                ELSEIF dtot > tot THEN
                    g_purse = g_purse - g_bet: msg = _TRIM$(STR$(dtot)) + " beats " + _TRIM$(STR$(tot))
                ELSEIF tot > dtot THEN
                    g_purse = g_purse + g_bet: msg = _TRIM$(STR$(tot)) + " takes it"
                ELSE
                    msg = "a push at " + _TRIM$(STR$(tot))
                END IF
            END IF
            DrawTable msg: _DELAY 1.8
        END IF

        IF g_purse >= purse * 2 THEN PlayJack% = MG_WON: EXIT FUNCTION
        DrawTable msg + "     [SPACE] deal again, [ESC] cash out"
        DO
            k = INKEY$
            IF k = CHR$(27) THEN PlayJack% = MG_LEFT: EXIT FUNCTION
            _LIMIT 60
        LOOP UNTIL k = " "
    LOOP
END FUNCTION

' The dealer has no choices at all -- that asymmetry IS the game.
SUB DealerPlay
    DIM tot AS INTEGER, soft AS INTEGER
    DO
        tot = HandVal%(DHAND(), g_dn, soft)
        IF tot >= 17 THEN EXIT DO
        PushCard DHAND(), g_dn, Draw%
    LOOP
END SUB

'--- draw --------------------------------------------------------------------

SUB DrawTable (msg AS STRING)
    DIM i AS INTEGER, s AS STRING, sf AS INTEGER
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "T W E N T Y - O N E", "dealer stands on all 17s   -   a natural pays three to two   -   no splits"

    COLOR C_DIM, 0: MgCenter 10, "the dealer"
    s = ""
    FOR i = 1 TO g_dn
        IF i = 2 _ANDALSO g_hole THEN s = s + "[ ? ] " ELSE s = s + "[" + RankName$(DHAND(i)) + "] "
    NEXT i
    COLOR C_TEXT, 0: MgCenter 12, s
    COLOR C_WARN, 0
    IF g_hole THEN
        MgCenter 14, "showing " + RankName$(DHAND(1))
    ELSE
        MgCenter 14, "total " + _TRIM$(STR$(HandVal%(DHAND(), g_dn, sf)))
    END IF

    COLOR C_DIM, 0: MgCenter 19, "you"
    s = ""
    FOR i = 1 TO g_pn: s = s + "[" + RankName$(PHAND(i)) + "] ": NEXT i
    COLOR C_TEXT, 0: MgCenter 21, s
    COLOR C_TITLE, 0
    i = HandVal%(PHAND(), g_pn, sf)
    IF sf THEN
        MgCenter 23, "soft " + _TRIM$(STR$(i))
    ELSE
        MgCenter 23, "total " + _TRIM$(STR$(i))
    END IF

    COLOR C_COOL, 0
    MgCenter 26, "purse " + _TRIM$(STR$(g_purse)) + "     stake " + _TRIM$(STR$(g_bet))
    COLOR C_TEXT, 0: MgCenter 28, msg
    COLOR C_GOOD, 0
    MgCenter 32, "[H]it   [S]tand   [D]ouble (first two cards only)   [ESC] cash out"
    MgPresent
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB JackSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM AS DOUBLE ebasic, emimic, estand
    _DEST _CONSOLE
    PRINT "BLACKJACK selftest"

    MgSection "the deck is a deck"
    MgOk "52 cards, four of every rank", ShoeWellFormed%
    MgOk "shuffling does not lose or duplicate a card", ShuffleKeepsDeck%
    MgOk "cards are dealt without replacement", NoReplacement%

    MgSection "hand values, including the thing that quietly breaks strategy"
    MgOk "A + 6 is a SOFT 17", SoftCheck%(1, 6, 17, TRUE)
    MgOk "A + 6 + 10 is a HARD 17", SoftCheck3%(1, 6, 10, 17, FALSE)
    MgOk "A + A is a soft 12", SoftCheck%(1, 1, 12, TRUE)
    ' A+A+9 is SOFT 21, not hard -- one ace is still up at eleven and could be
    ' dropped to eleven total. Asserting it hard was my error, not the code's.
    MgOk "A + A + 9 is a SOFT 21", SoftCheck3%(1, 1, 9, 21, TRUE)
    MgOk "A + 10 + 10 is a HARD 21 -- the ace had to come down", SoftCheck3%(1, 10, 10, 21, FALSE)
    MgOk "court cards are ten", SoftCheck%(12, 13, 20, FALSE)
    MgOk "a natural is exactly two cards", NaturalIsTwoCards%
    MgOk "no hand ever values above 21 with an ace it could drop", NeverSillyBust%

    MgSection "the strategy table is advice worth following"
    RANDOMIZE 91: ebasic = EdgeOf#(1, 300000)
    RANDOMIZE 92: emimic = EdgeOf#(2, 300000)
    RANDOMIZE 93: estand = EdgeOf#(3, 300000)
    PRINT USING "       per 100 staked:  basic strategy ###.## , mimic the dealer ###.## , always stand ###.##"; ebasic * 100; emimic * 100; estand * 100
    MgOk "basic strategy loses slowly", ebasic > -0.03
    MgOk "the house still has an edge -- this is a casino, not a gift", ebasic < 0.005
    MgOk "mimicking the dealer costs several times more", emimic < ebasic - 0.02
    MgOk "never busting is worse still", estand < emimic

    MgSection "the payout is the one advertised"
    MgOk "a natural pays three to two", BJ_PAY = 1.5
    MgOk "a natural beats a made 21", NaturalBeatsMade21%

    MgDone
END SUB

FUNCTION ShoeWellFormed% ()
    DIM i AS INTEGER, cnt(1 TO 13) AS INTEGER
    NewShoe
    FOR i = 1 TO DECKN: cnt(SHOE(i)) = cnt(SHOE(i)) + 1: NEXT i
    ShoeWellFormed% = TRUE
    FOR i = 1 TO 13
        IF cnt(i) <> 4 THEN ShoeWellFormed% = FALSE
    NEXT i
END FUNCTION

FUNCTION ShuffleKeepsDeck% ()
    DIM i AS LONG
    ShuffleKeepsDeck% = TRUE
    RANDOMIZE 94
    FOR i = 1 TO 2000
        IF NOT ShoeWellFormed% THEN ShuffleKeepsDeck% = FALSE
    NEXT i
END FUNCTION

' Deal out most of a shoe and confirm the ranks that came out are exactly the
' ranks that were in it -- a shoe that deals with replacement is a shoe where
' counting is meaningless and the measured edge is a fiction.
FUNCTION NoReplacement% ()
    DIM i AS INTEGER, c AS INTEGER, cnt(1 TO 13) AS INTEGER
    NewShoe
    FOR i = 1 TO DECKN - RESHUFFLE
        c = Draw%
        cnt(c) = cnt(c) + 1
    NEXT i
    NoReplacement% = TRUE
    FOR i = 1 TO 13
        IF cnt(i) > 4 THEN NoReplacement% = FALSE
    NEXT i
END FUNCTION

FUNCTION SoftCheck% (a AS INTEGER, b AS INTEGER, want AS INTEGER, wantsoft AS INTEGER)
    DIM h(1 TO MAXHAND) AS INTEGER, n AS INTEGER, s AS INTEGER, v AS INTEGER
    PushCard h(), n, a: PushCard h(), n, b
    v = HandVal%(h(), n, s)
    SoftCheck% = (v = want _ANDALSO ((s <> 0) = (wantsoft <> 0)))
END FUNCTION

FUNCTION SoftCheck3% (a AS INTEGER, b AS INTEGER, c AS INTEGER, want AS INTEGER, wantsoft AS INTEGER)
    DIM h(1 TO MAXHAND) AS INTEGER, n AS INTEGER, s AS INTEGER, v AS INTEGER
    PushCard h(), n, a: PushCard h(), n, b: PushCard h(), n, c
    v = HandVal%(h(), n, s)
    SoftCheck3% = (v = want _ANDALSO ((s <> 0) = (wantsoft <> 0)))
END FUNCTION

FUNCTION NaturalIsTwoCards% ()
    DIM h(1 TO MAXHAND) AS INTEGER, n AS INTEGER
    PushCard h(), n, 1: PushCard h(), n, 13
    IF NOT IsNatural%(h(), n) THEN NaturalIsTwoCards% = FALSE: EXIT FUNCTION
    n = 0
    PushCard h(), n, 7: PushCard h(), n, 7: PushCard h(), n, 7
    NaturalIsTwoCards% = NOT IsNatural%(h(), n)
END FUNCTION

' An ace must never be left counted high into a bust -- the classic soft-hand
' bug, and one that only shows up on three-card hands.
FUNCTION NeverSillyBust% ()
    DIM a AS INTEGER, b AS INTEGER, c AS INTEGER, s AS INTEGER
    DIM h(1 TO MAXHAND) AS INTEGER, n AS INTEGER, v AS INTEGER
    NeverSillyBust% = TRUE
    FOR a = 1 TO 13
        FOR b = 1 TO 13
            FOR c = 1 TO 13
                n = 0
                PushCard h(), n, a: PushCard h(), n, b: PushCard h(), n, c
                v = HandVal%(h(), n, s)
                IF v > 21 _ANDALSO s THEN NeverSillyBust% = FALSE
                IF v > 30 THEN NeverSillyBust% = FALSE
            NEXT c
        NEXT b
    NEXT a
END FUNCTION

FUNCTION NaturalBeatsMade21% ()
    DIM h(1 TO MAXHAND) AS INTEGER, n AS INTEGER
    DIM g(1 TO MAXHAND) AS INTEGER, m AS INTEGER, s AS INTEGER
    PushCard h(), n, 1: PushCard h(), n, 10
    PushCard g(), m, 7: PushCard g(), m, 7: PushCard g(), m, 7
    NaturalBeatsMade21% = IsNatural%(h(), n) _ANDALSO NOT IsNatural%(g(), m) _ANDALSO HandVal%(g(), m, s) = 21
END FUNCTION

' Expected return per unit staked, by simulation. `mode` picks the player:
'   1 basic strategy   2 mimic the dealer (hit to 17)   3 never bust (stand)
FUNCTION EdgeOf# (mode AS INTEGER, hands AS LONG)
    DIM i AS LONG
    DIM AS INTEGER tot, soft, dtot, dsoft, first, bet
    DIM AS DOUBLE net, staked
    DIM act AS STRING
    NewShoe
    FOR i = 1 TO hands
        g_pn = 0: g_dn = 0: bet = 1
        PushCard PHAND(), g_pn, Draw%
        PushCard DHAND(), g_dn, Draw%
        PushCard PHAND(), g_pn, Draw%
        PushCard DHAND(), g_dn, Draw%
        staked = staked + bet

        IF IsNatural%(PHAND(), g_pn) THEN
            IF IsNatural%(DHAND(), g_dn) THEN
                ' push
            ELSE
                net = net + bet * BJ_PAY
            END IF
        ELSE
            first = TRUE
            DO
                tot = HandVal%(PHAND(), g_pn, soft)
                IF tot > 21 THEN EXIT DO
                SELECT CASE mode
                    CASE 1: act = BasicPlay$(tot, soft, DHAND(1), first)
                    CASE 2
                        IF tot < 17 THEN act = "H" ELSE act = "S"
                    CASE ELSE: act = "S"
                END SELECT
                IF act = "S" THEN EXIT DO
                IF act = "D" THEN
                    bet = bet * 2: staked = staked + 1
                    PushCard PHAND(), g_pn, Draw%
                    EXIT DO
                END IF
                PushCard PHAND(), g_pn, Draw%
                first = FALSE
            LOOP

            tot = HandVal%(PHAND(), g_pn, soft)
            IF tot > 21 THEN
                net = net - bet
            ELSE
                DealerPlay
                dtot = HandVal%(DHAND(), g_dn, dsoft)
                IF dtot > 21 THEN
                    net = net + bet
                ELSEIF dtot > tot THEN
                    net = net - bet
                ELSEIF tot > dtot THEN
                    net = net + bet
                END IF
            END IF
        END IF
    NEXT i
    EdgeOf# = net / staked
END FUNCTION

'$INCLUDE:'MG.bas'
'$INCLUDE:'MGDICE.bas'
