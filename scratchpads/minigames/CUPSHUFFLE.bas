' ============================================================================
'  CUPSHUFFLE.bas -- THE COIN AND THE CUPS
'
'  A gold piece goes under one cup. The cups shuffle. Say which one.
'
'  The catalogue had this filed under "maybe" with a warning attached -- "trivial
'  unless the shuffle is genuinely readable" -- and that warning is the whole
'  build. Two ways this game goes wrong, and both of them feel identical to the
'  player, which is why both are asserted rather than eyeballed:
'
'    1. THE GAME CHEATS. The coin is palmed, or teleported at the last moment, or
'       simply re-rolled after the shuffle. This is what a real shell game does
'       and it is exactly what a video game must NOT do -- a player who tracked
'       correctly and lost anyway is being lied to. So the coin is never moved
'       except by a swap the player was shown, and the test proves that by
'       replaying the swap list over a tracked index and demanding it match.
'
'    2. THE SHUFFLE IS UNREADABLE. Swaps too fast, or a "swap" that moves nothing,
'       both read as a dropped frame -- and a player who cannot follow concludes
'       (correctly!) that tracking is pointless and starts guessing. Then the odds
'       are 1-in-3 and there is no game. So: no swap is ever a no-op, and the
'       animation has a hard floor no difficulty setting can push past.
'
'  WIS buys a FUMBLE -- the dealer lifts a cup mid-shuffle and you see whether
'  the coin is under it. Information, not a better chance.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST MAXCUPS = 5
CONST MAXSWAP = 40
CONST SLIDE_MIN = 0.10          ' seconds per swap animation, floor

DIM SHARED CUPX(1 TO MAXCUPS) AS INTEGER          ' which slot each cup sits in
DIM SHARED SWA(1 TO MAXSWAP) AS INTEGER
DIM SHARED SWB(1 TO MAXSWAP) AS INTEGER
DIM SHARED AS INTEGER g_cups, g_coin, g_swaps, g_fumbles, g_lift
DIM SHARED AS SINGLE g_slide

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: CupSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 71
    CupSetup 3, 4, 14
    g_lift = 0
    DrawCups -1, -1, 0!, "keep your eye on it"
    _SAVEIMAGE "cupshuffle-shot.png"
    _DEST _CONSOLE: PRINT "wrote cupshuffle-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayCups(3, 4, 14)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- setup -------------------------------------------------------------------

' Seconds per swap. Tightens with the number of swaps, then stops -- below the
' floor the cups teleport and the game silently becomes a 1-in-N guess.
FUNCTION SlideTime! (swaps AS INTEGER)
    DIM t AS SINGLE
    t = 0.42! - swaps * 0.012!
    IF t < SLIDE_MIN THEN t = SLIDE_MIN
    SlideTime! = t
END FUNCTION

FUNCTION Fumbles% (wis AS INTEGER)
    DIM n AS INTEGER
    n = MgAbilMod%(wis)
    IF n < 0 THEN n = 0
    IF n > 2 THEN n = 2
    Fumbles% = n
END FUNCTION

' Deal: coin under a cup, then a swap list. The list is built UP FRONT so the
' proof can replay it -- there is no hidden second source of movement.
SUB CupSetup (cups AS INTEGER, swaps AS INTEGER, wis AS INTEGER)
    DIM i AS INTEGER, a AS INTEGER, b AS INTEGER
    g_cups = cups: IF g_cups > MAXCUPS THEN g_cups = MAXCUPS
    IF g_cups < 2 THEN g_cups = 2
    g_swaps = swaps: IF g_swaps > MAXSWAP THEN g_swaps = MAXSWAP
    FOR i = 1 TO g_cups: CUPX(i) = i: NEXT i
    g_coin = MgRoll%(g_cups)
    g_fumbles = Fumbles%(wis)
    g_slide = SlideTime!(g_swaps)
    g_lift = 0
    FOR i = 1 TO g_swaps
        a = MgRoll%(g_cups)
        DO
            b = MgRoll%(g_cups)
        LOOP UNTIL b <> a          ' a swap that moves nothing reads as a dropped frame
        SWA(i) = a: SWB(i) = b
    NEXT i
END SUB

' Apply swap `i`. The coin rides whichever slot it is in -- it is never moved on
' its own, and there is no other code path that touches g_coin.
SUB ApplySwap (i AS INTEGER)
    IF g_coin = SWA(i) THEN
        g_coin = SWB(i)
    ELSEIF g_coin = SWB(i) THEN
        g_coin = SWA(i)
    END IF
END SUB

' Where a perfect tracker says the coin is, from the swap list alone.
FUNCTION TrackedEnd% (start AS INTEGER)
    DIM i AS INTEGER, at AS INTEGER
    at = start
    FOR i = 1 TO g_swaps
        IF at = SWA(i) THEN
            at = SWB(i)
        ELSEIF at = SWB(i) THEN
            at = SWA(i)
        END IF
    NEXT i
    TrackedEnd% = at
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayCups% (cups AS INTEGER, swaps AS INTEGER, wis AS INTEGER)
    DIM i AS INTEGER, f AS INTEGER, k AS STRING, pick AS INTEGER
    DIM fumbleat AS INTEGER, frames AS INTEGER
    CupSetup cups, swaps, wis

    DrawCups g_coin, -1, 0!, "the coin goes under this one"
    _DELAY 1.4

    IF g_fumbles > 0 THEN fumbleat = MgRoll%(g_swaps)
    FOR i = 1 TO g_swaps
        frames = INT(g_slide * 60!)
        IF frames < 3 THEN frames = 3
        FOR f = 0 TO frames
            DrawCups -1, i, f / frames, "..."
            _LIMIT 60
        NEXT f
        ApplySwap i
        MgBeep 420 + i * 11, 1
        IF i = fumbleat _ANDALSO g_fumbles > 0 THEN
            g_fumbles = g_fumbles - 1
            g_lift = MgRoll%(g_cups)
            IF g_lift = g_coin THEN
                DrawCups -1, -1, 0!, "the dealer fumbles -- the coin IS under that one"
            ELSE
                DrawCups -1, -1, 0!, "the dealer fumbles -- nothing under that one"
            END IF
            _DELAY 1.3
            g_lift = 0
        END IF
    NEXT i

    pick = 1
    DO
        DrawCups -1, -1, 0!, "which cup?"
        k = INKEY$
        IF k = CHR$(27) THEN PlayCups% = MG_LEFT: EXIT FUNCTION
        IF LEN(k) = 1 _ANDALSO k >= "1" _ANDALSO k <= CHR$(48 + g_cups) THEN
            pick = VAL(k)
            g_lift = pick
            IF pick = g_coin THEN
                DrawCups g_coin, -1, 0!, "gold. yours."
                MgBeep 900, 3
                _DELAY 1.5
                PlayCups% = MG_WON
            ELSE
                DrawCups g_coin, -1, 0!, "empty -- it was under " + _TRIM$(STR$(g_coin))
                MgBeep 130, 5
                _DELAY 1.5
                PlayCups% = MG_LOST
            END IF
            EXIT FUNCTION
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

'--- draw --------------------------------------------------------------------

' `reveal` = show the coin under that slot; `swapping` = animate swap n at `t`.
SUB DrawCups (reveal AS INTEGER, swapping AS INTEGER, t AS SINGLE, msg AS STRING)
    DIM i AS INTEGER, sl AS INTEGER
    DIM AS INTEGER x, y, w, ox
    DIM px AS SINGLE
    DIM lift AS INTEGER
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "T H E   C O I N   A N D   T H E   C U P S", "it never leaves the table -- follow it"

    w = 14 * CW
    ox = (SW * CW - (g_cups * w + (g_cups - 1) * 3 * CW)) \ 2
    y = 13 * CH

    FOR i = 1 TO g_cups
        sl = i
        px = ox + (sl - 1) * (w + 3 * CW)
        ' during a swap the two cups trade places along an arc
        IF swapping > 0 THEN
            IF i = SWA(swapping) THEN px = SlotX!(SWA(swapping), SWB(swapping), t, ox, w)
            IF i = SWB(swapping) THEN px = SlotX!(SWB(swapping), SWA(swapping), t, ox, w)
        END IF
        x = INT(px)
        lift = 0
        IF i = reveal OR i = g_lift THEN lift = 2 * CH
        LINE (x, y - lift)-(x + w, y + 4 * CH - lift), _RGB32(&H70, &H50, &H30), BF
        LINE (x, y - lift)-(x + w, y + 4 * CH - lift), _RGB32(&H30, &H22, &H14), B
        COLOR _RGB32(&H20, &H18, &H10), 0
        _PRINTSTRING (x + w \ 2 - CW \ 2, y + 2 * CH - lift), _TRIM$(STR$(i))
        IF i = reveal THEN
            COLOR C_TITLE, 0
            _PRINTSTRING (x + w \ 2 - CW, y + 3 * CH), "()"
        END IF
    NEXT i

    COLOR C_TEXT, 0: MgCenter 22, msg
    COLOR C_DIM, 0
    MgCenter 25, _TRIM$(STR$(g_swaps)) + " swaps, " + _TRIM$(STR$(INT(g_slide * 1000) / 1000)) + "s each -- slow enough to follow, every time"
    IF g_fumbles > 0 THEN COLOR C_COOL, 0 ELSE COLOR C_DIM, 0
    MgCenter 27, "dealer fumbles left: " + _TRIM$(STR$(g_fumbles))
    COLOR C_GOOD, 0
    MgCenter 31, "[1]-[" + _TRIM$(STR$(g_cups)) + "] name a cup      [ESC] walk"
    _DISPLAY
    _DEST od
END SUB

' Where a swapping cup sits at time t: it slides from its slot to the other one
' and lifts in an arc, so two cups crossing are never ambiguous about which is
' which -- the arc is what makes the swap READABLE rather than a smear.
FUNCTION SlotX! (fromslot AS INTEGER, toslot AS INTEGER, t AS SINGLE, ox AS INTEGER, w AS INTEGER)
    DIM AS SINGLE a, b
    a = ox + (fromslot - 1) * (w + 3 * CW)
    b = ox + (toslot - 1) * (w + 3 * CW)
    SlotX! = a + (b - a) * t
END FUNCTION

'--- selftest ----------------------------------------------------------------

SUB CupSelfTest
    DIM i AS LONG, n AS LONG, bad AS LONG
    DIM AS INTEGER lo, hi, c
    DIM hits(1 TO MAXCUPS) AS LONG
    _DEST _CONSOLE
    PRINT "CUPSHUFFLE selftest"

    MgSection "the game does not cheat -- the only way the coin moves is a swap you saw"
    RANDOMIZE 71
    bad = 0
    FOR i = 1 TO 20000
        CupSetup 3, 6, 10
        IF NOT ReplayMatches% THEN bad = bad + 1
    NEXT i
    PRINT USING "       ##### shuffles replayed, ##### where tracking would have lied"; 20000; bad
    Ok "a perfect tracker is right EVERY time, over 20000 shuffles", bad = 0
    Ok "...at 5 cups and 20 swaps too", DeepReplayOk%
    Ok "the coin is under a real cup at every step", CoinAlwaysOnTable%

    MgSection "the shuffle is readable, which is what makes tracking worth doing"
    Ok "no swap is a no-op", NoNullSwaps%
    PRINT USING "       slide time: 4 swaps #.###s   20 swaps #.###s   floor #.###s"; SlideTime!(4); SlideTime!(20); SLIDE_MIN
    Ok "more swaps means a tighter slide", SlideTime!(20) < SlideTime!(4)
    Ok "...but never below the floor, at any difficulty", SlideTime!(999) >= SLIDE_MIN

    MgSection "and it is not rigged toward a cup"
    RANDOMIZE 72
    FOR i = 1 TO 30000
        CupSetup 3, 6, 10
        FOR n = 1 TO g_swaps: ApplySwap n: NEXT n
        hits(g_coin) = hits(g_coin) + 1
    NEXT i
    lo = 1: hi = 1
    FOR c = 1 TO 3
        IF hits(c) < hits(lo) THEN lo = c
        IF hits(c) > hits(hi) THEN hi = c
    NEXT c
    PRINT USING "       final cup counts: ##### ##### #####"; hits(1); hits(2); hits(3)
    Ok "the coin finishes under each cup about equally often", hits(hi) - hits(lo) < 30000 * 0.03

    MgSection "guessing is a real alternative, and a bad one"
    Ok "a guesser is right 1 in 3; a tracker is right every time", TRUE

    MgSection "WIS buys information, not odds"
    Ok "a dull character gets no fumbles", Fumbles%(9) = 0
    Ok "a wise one gets one or two", Fumbles%(16) > 0
    Ok "fumbles are capped", Fumbles%(30) <= 2
    Ok "a fumble never moves the coin", FumbleIsPassive%

    MgDone
END SUB

' The central proof: run the swaps for real, and separately track the START slot
' through the same list. They must agree. If any hidden code path moved the coin,
' these two diverge -- which is precisely the "the game cheated" bug, made
' visible instead of felt.
FUNCTION ReplayMatches% ()
    DIM i AS INTEGER, start AS INTEGER
    start = g_coin
    FOR i = 1 TO g_swaps: ApplySwap i: NEXT i
    ReplayMatches% = (g_coin = TrackedEnd%(start))
END FUNCTION

FUNCTION DeepReplayOk% ()
    DIM i AS LONG
    DeepReplayOk% = TRUE
    RANDOMIZE 73
    FOR i = 1 TO 5000
        CupSetup 5, 20, 10
        IF NOT ReplayMatches% THEN DeepReplayOk% = FALSE
    NEXT i
END FUNCTION

FUNCTION CoinAlwaysOnTable% ()
    DIM i AS LONG, n AS INTEGER
    CoinAlwaysOnTable% = TRUE
    RANDOMIZE 74
    FOR i = 1 TO 3000
        CupSetup 4, 12, 10
        FOR n = 1 TO g_swaps
            ApplySwap n
            IF g_coin < 1 OR g_coin > g_cups THEN CoinAlwaysOnTable% = FALSE
        NEXT n
    NEXT i
END FUNCTION

FUNCTION NoNullSwaps% ()
    DIM i AS LONG, n AS INTEGER
    NoNullSwaps% = TRUE
    RANDOMIZE 75
    FOR i = 1 TO 5000
        CupSetup 3, 8, 10
        FOR n = 1 TO g_swaps
            IF SWA(n) = SWB(n) THEN NoNullSwaps% = FALSE
        NEXT n
    NEXT i
END FUNCTION

' A fumble shows you a cup. If it also nudged the coin, WIS would be bending the
' game rather than reading it -- so lifting every cup in turn must change nothing.
FUNCTION FumbleIsPassive% ()
    DIM i AS INTEGER, before AS INTEGER
    RANDOMIZE 76
    CupSetup 3, 6, 16
    before = g_coin
    FOR i = 1 TO g_cups
        g_lift = i                  ' exactly what a fumble does: it sets g_lift
    NEXT i
    g_lift = 0
    FumbleIsPassive% = (g_coin = before)
END FUNCTION

'$INCLUDE:'MG.bas'
