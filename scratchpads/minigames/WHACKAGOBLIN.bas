' ============================================================================
'  WHACKAGOBLIN.bas -- WHACK-A-GOBLIN
'
'  Things come up out of nine holes in the cellar floor. You have a shovel.
'
'  House rule 1 says "a decision, not a roll", and a straight whack-a-mole is
'  neither -- it is a reflex test, which punishes the wrong thing in a game
'  played one-handed on the arrow keys. So this one is a GO / NO-GO task: about a
'  third of what comes up should not be hit. The kobold pup is asleep. The mimic
'  hits back. The pack mule is yours. The decision is per-target and it is made
'  under time pressure, which is a different and much better problem than "be
'  fast" -- being fast is worthless here if you are fast at the wrong hole.
'
'  That gives the thing an actual fairness question, and it is the one asserted:
'  a player who whacks EVERYTHING must lose, or the discrimination is decorative.
'  Three simulated players run against the same generated round -- indiscriminate,
'  sloppy-but-careful, and perfect -- and the target score has to sit above the
'  first and below the second.
'
'  DEX buys time on the clock for each target, so a slower hand gets longer to
'  decide. It never auto-hits and never changes what comes up.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST HOLES = 9
CONST MAXPOP = 60
CONST UP_FLOOR = 0.55           ' seconds a target is up, minimum, at any depth
CONST REACTION = 0.3            ' the human budget the floor is measured against

'--- what comes up ---
CONST K_GOBLIN = 1
CONST K_PUP = 2                 ' asleep. leave it.
CONST K_MIMIC = 3               ' hits back
CONST K_MULE = 4                ' yours
CONST KINDS = 4

CONST HIT_GOOD = 1
CONST HIT_BAD = -2
CONST N_FOES = 20                 ' goblins per round, exactly
CONST N_DECOYS = 10               ' things that are not, exactly
CONST TARGET = 12               ' set from the sloppy-player simulation, not by feel: at 14
                                ' an attentive player still failed 1 round in 3

DIM SHARED POPT(1 TO MAXPOP) AS SINGLE       ' when it rises
DIM SHARED POPD(1 TO MAXPOP) AS SINGLE       ' how long it stays
DIM SHARED POPH(1 TO MAXPOP) AS INTEGER      ' which hole
DIM SHARED POPK(1 TO MAXPOP) AS INTEGER      ' what it is
DIM SHARED POPDONE(1 TO MAXPOP) AS INTEGER   ' already whacked
DIM SHARED KINDNAME(1 TO KINDS) AS STRING
DIM SHARED KINDCOL(1 TO KINDS) AS _UNSIGNED LONG
DIM SHARED AS INTEGER g_pops, g_score, g_hits, g_slips
DIM SHARED AS SINGLE g_len

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitKinds
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: WhackSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 81
    WhackSetup 12
    g_score = 9: g_hits = 11: g_slips = 1
    DrawCellar 6.2!, "swing"
    _SAVEIMAGE "whackagoblin-shot.png"
    _DEST _CONSOLE: PRINT "wrote whackagoblin-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayWhack(12)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- setup -------------------------------------------------------------------

SUB InitKinds
    KINDNAME(K_GOBLIN) = "GOBLIN": KINDCOL(K_GOBLIN) = _RGB32(&H60, &HD0, &H60)
    KINDNAME(K_PUP) = "pup": KINDCOL(K_PUP) = _RGB32(&HC0, &HA0, &H70)
    KINDNAME(K_MIMIC) = "MIMIC": KINDCOL(K_MIMIC) = _RGB32(&HE0, &H70, &HC0)
    KINDNAME(K_MULE) = "mule": KINDCOL(K_MULE) = _RGB32(&HB0, &HB0, &HC0)
END SUB

FUNCTION IsFoe% (kind AS INTEGER)
    IsFoe% = (kind = K_GOBLIN)
END FUNCTION

' How long a target stays up. DEX buys thinking time -- and the floor is set
' well above human reaction time, because a target that cannot be REACHED in
' time is not difficulty, it is a coin flip you are blamed for losing.
FUNCTION UpTime! (dex AS INTEGER)
    DIM t AS SINGLE
    t = 0.75! + MgAbilMod%(dex) * 0.07!
    IF t < UP_FLOOR THEN t = UP_FLOOR
    UpTime! = t
END FUNCTION

' The whole round, generated up front. Same trick as the cup shuffle: if the
' schedule is a list, the fairness claims are computable instead of arguable.
SUB WhackSetup (dex AS INTEGER)
    DIM i AS INTEGER, j AS INTEGER, t AS INTEGER, h AS INTEGER, guard AS INTEGER
    DIM tt AS SINGLE, gap AS SINGLE
    g_pops = N_FOES + N_DECOYS
    g_score = 0: g_hits = 0: g_slips = 0
    ' EXACTLY this many foes and this many decoys, then shuffled. Rolling the
    ' mix per target instead was the first cut, and the spread it produced (12 to
    ' 26 goblins in a 30-target round) meant a lucky round could be won by
    ' swinging at everything and an unlucky one could not be won at all. The
    ' selftest failed all three claims at once; a fixed mix makes them exact.
    FOR i = 1 TO N_FOES: POPK(i) = K_GOBLIN: NEXT i
    FOR i = N_FOES + 1 TO g_pops: POPK(i) = 1 + MgRoll%(KINDS - 1): NEXT i
    FOR i = g_pops TO 2 STEP -1
        j = MgRoll%(i): t = POPK(i): POPK(i) = POPK(j): POPK(j) = t
    NEXT i

    tt = 1!
    FOR i = 1 TO g_pops
        POPT(i) = tt
        POPD(i) = UpTime!(dex)
        ' never two things in one hole at once -- that is unresolvable, not hard
        guard = 0
        DO
            h = MgRoll%(HOLES): guard = guard + 1
        LOOP UNTIL guard > 30 _ORELSE HoleFree%(i, h)
        POPH(i) = h
        POPDONE(i) = FALSE
        gap = 0.55! + MgRoll%(5) / 10!
        tt = tt + gap
    NEXT i
    g_len = tt + 1!
END SUB

' Is hole `h` clear for the whole life of pop `i`? Checks against pops already
' placed (1..i-1), which is all of them, since they are laid down in time order.
FUNCTION HoleFree% (i AS INTEGER, h AS INTEGER)
    DIM j AS INTEGER
    HoleFree% = TRUE
    FOR j = 1 TO i - 1
        IF POPH(j) = h THEN
            IF POPT(i) < POPT(j) + POPD(j) _ANDALSO POPT(j) < POPT(i) + POPD(i) THEN
                HoleFree% = FALSE: EXIT FUNCTION
            END IF
        END IF
    NEXT j
END FUNCTION

' Which pop is up in hole `h` at time `now`, or 0.
FUNCTION UpAt% (h AS INTEGER, now AS SINGLE)
    DIM i AS INTEGER
    FOR i = 1 TO g_pops
        IF POPH(i) = h _ANDALSO POPDONE(i) = 0 THEN
            IF now >= POPT(i) _ANDALSO now < POPT(i) + POPD(i) THEN UpAt% = i: EXIT FUNCTION
        END IF
    NEXT i
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayWhack% (dex AS INTEGER)
    DIM t0 AS DOUBLE, now AS SINGLE
    DIM k AS STRING, h AS INTEGER, p AS INTEGER, msg AS STRING
    WhackSetup dex
    t0 = TIMER
    msg = "swing"
    DO
        now = MgElapsed!(t0)
        IF now >= g_len THEN EXIT DO
        DrawCellar now, msg
        k = INKEY$
        IF k = CHR$(27) THEN PlayWhack% = MG_LEFT: EXIT FUNCTION
        IF LEN(k) = 1 _ANDALSO k >= "1" _ANDALSO k <= "9" THEN
            h = VAL(k)
            p = UpAt%(h, now)
            IF p > 0 THEN
                POPDONE(p) = TRUE
                IF IsFoe%(POPK(p)) THEN
                    g_score = g_score + HIT_GOOD: g_hits = g_hits + 1
                    MgBeep 520, 2: msg = "thump"
                ELSE
                    g_score = g_score + HIT_BAD: g_slips = g_slips + 1
                    MgBeep 140, 5: msg = "that was a " + KINDNAME(POPK(p)) + " -- " + _TRIM$(STR$(HIT_BAD))
                END IF
            ELSE
                MgBeep 200, 1: msg = "you hit the floor"
            END IF
        END IF
        _LIMIT 60
    LOOP
    IF g_score >= TARGET THEN PlayWhack% = MG_WON ELSE PlayWhack% = MG_LOST
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawCellar (now AS SINGLE, msg AS STRING)
    DIM i AS INTEGER, p AS INTEGER, c AS INTEGER, r AS INTEGER
    DIM AS INTEGER x, y, w, h, ox, oy
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "W H A C K - A - G O B L I N", "not everything down there deserves the shovel"

    w = 13 * CW: h = 5 * CH
    ox = (SW * CW - (3 * w + 2 * 3 * CW)) \ 2
    oy = 9 * CH
    FOR i = 1 TO HOLES
        c = (i - 1) MOD 3: r = (i - 1) \ 3
        x = ox + c * (w + 3 * CW): y = oy + r * (h + 1 * CH)
        LINE (x, y)-(x + w, y + h), _RGB32(24, 20, 26), BF
        LINE (x, y)-(x + w, y + h), _RGB32(50, 44, 54), B
        COLOR C_DIM, 0
        _PRINTSTRING (x + CW, y + CH \ 2), "[" + _TRIM$(STR$(i)) + "]"
        p = UpAt%(i, now)
        IF p > 0 THEN
            COLOR KINDCOL(POPK(p)), 0
            _PRINTSTRING (x + (w - LEN(KINDNAME(POPK(p))) * CW) \ 2, y + h \ 2), KINDNAME(POPK(p))
        END IF
    NEXT i

    COLOR C_TITLE, 0
    MgCenter 28, "score " + _TRIM$(STR$(g_score)) + " of " + _TRIM$(STR$(TARGET)) + "     goblins " + _TRIM$(STR$(g_hits)) + "     wrong swings " + _TRIM$(STR$(g_slips))
    COLOR C_TEXT, 0: MgCenter 30, msg
    MgFuse 33, 1! - now / g_len, g_len - now
    COLOR C_GOOD, 0
    MgCenter 36, "[1]-[9] swing at a hole      GOBLIN only -- a pup, a mimic or the mule costs you 2"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB WhackSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM i AS LONG
    DIM AS INTEGER allsc, persc, slopsc, worstall, bestall
    DIM AS LONG bad
    _DEST _CONSOLE
    PRINT "WHACKAGOBLIN selftest"

    MgSection "the cellar is resolvable"
    RANDOMIZE 81
    bad = 0
    FOR i = 1 TO 3000
        WhackSetup 10
        IF NOT NoDoubleOccupancy% THEN bad = bad + 1
    NEXT i
    Ok "no hole ever holds two things at once", bad = 0
    Ok "every target is reachable within human reaction time", UpTime!(3) > REACTION
    PRINT USING "       target is up #.##s at DEX 3, #.##s at DEX 18; reaction budget #.##s"; UpTime!(3); UpTime!(18); REACTION
    Ok "the floor holds even for the clumsiest character", UpTime!(1) >= UP_FLOOR
    Ok "DEX buys thinking time", UpTime!(18) > UpTime!(6)

    MgSection "whacking everything MUST lose -- or the choosing is decorative"
    RANDOMIZE 82
    worstall = 999: bestall = -999
    FOR i = 1 TO 3000
        WhackSetup 10
        allsc = ScoreIndiscriminate%
        IF allsc < worstall THEN worstall = allsc
        IF allsc > bestall THEN bestall = allsc
    NEXT i
    PRINT USING "       hit-everything scores ### to ###; target is ###"; worstall; bestall; TARGET
    Ok "a player who swings at everything never reaches the target", bestall < TARGET

    MgSection "...and choosing well MUST win, or it is not winnable"
    RANDOMIZE 83
    bad = 0
    FOR i = 1 TO 3000
        WhackSetup 10
        IF ScorePerfect% < TARGET THEN bad = bad + 1
    NEXT i
    Ok "perfect discrimination clears the target on every round", bad = 0

    MgSection "and a good-but-human player wins too"
    RANDOMIZE 84
    bad = 0
    FOR i = 1 TO 3000
        WhackSetup 10
        IF ScoreSloppy% < TARGET THEN bad = bad + 1
    NEXT i
    PRINT USING "       missing 1 goblin in 6 and mis-hitting 1 decoy in 10 fails ####/3000 rounds"; bad
    Ok "a player who is mostly right still gets there", bad < 3000 * 0.25

    MgSection "the mix is honest"
    Ok "only the goblin is a legal target", IsFoe%(K_GOBLIN) _ANDALSO NOT IsFoe%(K_PUP) _ANDALSO NOT IsFoe%(K_MIMIC) _ANDALSO NOT IsFoe%(K_MULE)
    Ok "decoys are common enough to matter, rare enough to be a game", DecoyRateSane%

    MgDone
END SUB

FUNCTION NoDoubleOccupancy% ()
    DIM i AS INTEGER, j AS INTEGER
    NoDoubleOccupancy% = TRUE
    FOR i = 1 TO g_pops
        FOR j = i + 1 TO g_pops
            IF POPH(i) = POPH(j) THEN
                IF POPT(i) < POPT(j) + POPD(j) _ANDALSO POPT(j) < POPT(i) + POPD(i) THEN
                    NoDoubleOccupancy% = FALSE: EXIT FUNCTION
                END IF
            END IF
        NEXT j
    NEXT i
END FUNCTION

' The three simulated players. All three see the SAME generated round, so the
' comparison is about judgement and nothing else.
FUNCTION ScoreIndiscriminate% ()
    DIM i AS INTEGER, s AS INTEGER
    FOR i = 1 TO g_pops
        IF IsFoe%(POPK(i)) THEN s = s + HIT_GOOD ELSE s = s + HIT_BAD
    NEXT i
    ScoreIndiscriminate% = s
END FUNCTION

FUNCTION ScorePerfect% ()
    DIM i AS INTEGER, s AS INTEGER
    FOR i = 1 TO g_pops
        IF IsFoe%(POPK(i)) _ANDALSO POPD(i) >= REACTION THEN s = s + HIT_GOOD
    NEXT i
    ScorePerfect% = s
END FUNCTION

' Misses one goblin in six, and swings at one decoy in ten. That is roughly what
' attentive play looks like, and it has to be enough.
FUNCTION ScoreSloppy% ()
    DIM i AS INTEGER, s AS INTEGER
    FOR i = 1 TO g_pops
        IF IsFoe%(POPK(i)) THEN
            IF MgRoll%(6) > 1 THEN s = s + HIT_GOOD
        ELSE
            IF MgRoll%(10) = 1 THEN s = s + HIT_BAD
        END IF
    NEXT i
    ScoreSloppy% = s
END FUNCTION

FUNCTION DecoyRateSane% ()
    DIM i AS LONG, j AS INTEGER
    DIM AS LONG foes, decoys
    RANDOMIZE 85
    FOR i = 1 TO 2000
        WhackSetup 10
        FOR j = 1 TO g_pops
            IF IsFoe%(POPK(j)) THEN foes = foes + 1 ELSE decoys = decoys + 1
        NEXT j
    NEXT i
    PRINT USING "       #.### of what comes up must NOT be hit"; decoys / (foes + decoys)
    DecoyRateSane% = (decoys / (foes + decoys) > 0.2 _ANDALSO decoys / (foes + decoys) < 0.45)
END FUNCTION

'$INCLUDE:'MG.bas'
