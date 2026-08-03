' ============================================================================
'  LOCKPICK.bas -- THE PICK AND THE PINS
'
'  Three pins, each with one angle on a 24-notch dial that will set it. You feel
'  for it: the lock reports how close you are (DEAD / FAINT / CLOSE / GIVING),
'  and when it is GIVING it also tells you which way. Find it, set it, next pin.
'
'  Why it is not a quick-time event. The catalogue rejected "press the key when
'  the bar is in the zone" outright -- that is the composure gauge with a lock
'  drawn on it, and the design bible's one-engine-many-masks rule kills it. So
'  the verb here is SEARCH, not TIME: you are never asked to be fast with your
'  fingers, only efficient with your moves.
'
'  The pressure comes from the fuse, and the fuse is what makes the search a real
'  decision: a full sweep of the dial ALWAYS finds the pin and ALWAYS costs more
'  time than you have for three of them. You have to jump coarse and then close
'  fine, and knowing when to switch is the skill.
'
'  The fairness question, then, is exactly one thing: can a player who searches
'  well always beat the fuse? That is proved EXHAUSTIVELY -- every start notch
'  against every pin angle, not a sample -- rather than playtested.
'
'  THE CLOCK DRAINS TWO WAYS, and that is deliberate. It runs down in real time
'  like any fuse, AND every turn of the pick takes a fixed bite out of it on top.
'  The first cut had only the second half -- standing still was free, so a patient
'  player could sit and think forever and the "fuse" was really just a move
'  budget wearing a bar.
'
'  Keeping BOTH is what makes the two mistakes distinct:
'
'    * dithering costs you real seconds
'    * flailing costs you move-seconds, several at a time
'
'  ...so being quick does not save you from being wasteful, and being efficient
'  does not save you from being slow. Neither alone is enough, which is the
'  point.
'
'  It is still not a reflex game. The budget is derived, not felt: worst-case
'  efficient play needs 10.35s of move cost and at most 24 decisions, and a
'  decision is allowed THINK_PER_MOVE seconds of staring at the screen. The fuse
'  has to cover the sum of those, and the selftest computes it rather than
'  trusting that 50 seconds "feels about right".
'
'  DEX buys seconds on the fuse. It does not shorten the search, move the pin,
'  or forgive a bad set.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST NOTCHES = 24
CONST PINS = 3
CONST JUMP = 4                  ' the coarse step

'--- what each move costs off the fuse. The whole balance lives in these four
'    numbers, so they are named once and the proof reads them. ---
CONST T_FINE = 0.75             ' raised when the fuse grew: see the brute-force assertion
CONST T_JUMP = 0.5
CONST T_SET = 0.6
CONST T_MISS = 1.5              ' a set on the wrong notch -- the pick slips
CONST THINK_PER_MOVE = 1.2      ' real seconds a player is allowed to spend DECIDING each move

'--- feel bands, by distance in notches ---
CONST B_GIVING = 0
CONST B_CLOSE = 1
CONST B_FAINT = 2
CONST B_DEAD = 3

DIM SHARED PINAT(1 TO PINS) AS INTEGER
DIM SHARED PINSET(1 TO PINS) AS INTEGER
DIM SHARED AS INTEGER g_at, g_pin, g_slips
DIM SHARED AS SINGLE g_fuse, g_left, g_spent
DIM SHARED g_t0 AS DOUBLE

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: LockSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 31
    LockSetup 13
    PINSET(1) = TRUE: g_pin = 2: g_at = 9: g_slips = 1
    g_spent = 14.25: g_t0 = TIMER - 12.4: FuseTick
    DrawLock "the pin shifts -- something is close"
    _SAVEIMAGE "lockpick-shot.png"
    _DEST _CONSOLE: PRINT "wrote lockpick-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayLock(13)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- the lock ----------------------------------------------------------------

' Shortest way round the dial. A lock is a circle: notch 23 is one step from 0,
' and forgetting that makes the far side of the dial feel dead when it is not.
FUNCTION Ring% (a AS INTEGER, b AS INTEGER)
    DIM d AS INTEGER
    d = ABS(a - b) MOD NOTCHES
    IF d > NOTCHES \ 2 THEN d = NOTCHES - d
    Ring% = d
END FUNCTION

FUNCTION Band% (dist AS INTEGER)
    IF dist = 0 THEN Band% = B_GIVING: EXIT FUNCTION
    IF dist <= 2 THEN Band% = B_CLOSE: EXIT FUNCTION
    IF dist <= 5 THEN Band% = B_FAINT: EXIT FUNCTION
    Band% = B_DEAD
END FUNCTION

FUNCTION BandText$ (b AS INTEGER)
    SELECT CASE b
        CASE B_GIVING: BandText$ = "the pin GIVES -- set it"
        CASE B_CLOSE: BandText$ = "it shifts, very close"
        CASE B_FAINT: BandText$ = "a faint catch somewhere near"
        CASE ELSE: BandText$ = "dead metal"
    END SELECT
END FUNCTION

' Which way to turn, but only from CLOSE range. Offered at distance 1-2 and not
' before, so the coarse sweep stays a real search instead of an arrow to follow.
FUNCTION Hint$ (at AS INTEGER, target AS INTEGER)
    DIM up AS INTEGER
    IF Ring%(at, target) = 0 OR Ring%(at, target) > 2 THEN Hint$ = "": EXIT FUNCTION
    up = ((target - at + NOTCHES) MOD NOTCHES) <= NOTCHES \ 2
    IF up THEN Hint$ = "  (clockwise)" ELSE Hint$ = "  (widdershins)"
END FUNCTION

' Fuse seconds. DEX buys time -- the only thing it buys.
'
' 50 is not a feel number. It has to cover worst-case move cost (10.35s) PLUS a
' human's thinking time for the worst-case number of decisions (24 x 1.2s), and
' the selftest checks that sum rather than the constant. Move the costs or the
' strategy and the assertion moves with them.
FUNCTION LockFuse! (dex AS INTEGER)
    DIM f AS SINGLE
    f = 50! + MgAbilMod%(dex) * 2!
    IF f < 44! THEN f = 44!
    LockFuse! = f
END FUNCTION

SUB LockSetup (dex AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO PINS
        PINAT(i) = MgRoll%(NOTCHES) - 1
        PINSET(i) = FALSE
    NEXT i
    g_at = MgRoll%(NOTCHES) - 1
    g_pin = 1: g_slips = 0
    g_fuse = LockFuse!(dex): g_left = g_fuse
    g_spent = 0!: g_t0 = TIMER
END SUB

'--- play --------------------------------------------------------------------

FUNCTION PlayLock% (dex AS INTEGER)
    DIM k AS STRING, u AS STRING, msg AS STRING, d AS INTEGER
    DIM lasttick AS INTEGER
    LockSetup dex
    lasttick = 99
    DO
        d = Ring%(g_at, PINAT(g_pin))
        msg = BandText$(Band%(d)) + Hint$(g_at, PINAT(g_pin))
        FuseTick
        DrawLock msg
        IF g_left <= 0 THEN
            DrawLock "the pick shears off in the lock"
            MgBeep 90, 8
            _DELAY 1.4
            PlayLock% = MG_LOST: EXIT FUNCTION
        END IF
        ' the last five seconds tick, once a second -- a fuse you can only see is
        ' a fuse you forget about while you are staring at the dial
        IF g_left <= 5! _ANDALSO INT(g_left) <> lasttick THEN
            lasttick = INT(g_left)
            MgBeep 240, 1
        END IF
        k = INKEY$: u = UCASE$(k)
        IF k = CHR$(27) THEN PlayLock% = MG_LEFT: EXIT FUNCTION
        IF u = "A" OR k = CHR$(0) + "K" THEN Turn -1, T_FINE
        IF u = "D" OR k = CHR$(0) + "M" THEN Turn 1, T_FINE
        IF u = "Q" OR k = CHR$(0) + "H" THEN Turn -JUMP, T_JUMP
        IF u = "E" OR k = CHR$(0) + "P" THEN Turn JUMP, T_JUMP
        IF k = " " OR k = CHR$(13) THEN
            IF g_at = PINAT(g_pin) THEN
                g_spent = g_spent + T_SET
                PINSET(g_pin) = TRUE
                MgBeep 880, 2
                g_pin = g_pin + 1
                IF g_pin > PINS THEN PlayLock% = MG_WON: EXIT FUNCTION
                DrawLock "the pin sets with a click"
                Pause 0.6
            ELSE
                g_spent = g_spent + T_MISS
                g_slips = g_slips + 1
                MgBeep 120, 4
                DrawLock "the pick slips -- " + _TRIM$(STR$(T_MISS)) + "s gone"
                Pause 0.5
            END IF
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

SUB Turn (by AS INTEGER, cost AS SINGLE)
    g_at = (g_at + by + NOTCHES * 2) MOD NOTCHES
    g_spent = g_spent + cost
    MgBeep 300 + g_at * 6, 0.6
END SUB

' What is left: the fuse, minus real seconds elapsed, minus what the moves cost.
' Both drains are separately visible in `g_spent`, which is what lets the display
' show a player WHY their time went.
SUB FuseTick
    g_left = g_fuse - MgElapsed!(g_t0) - g_spent
END SUB

' A scripted pause -- the click of a pin setting, the slip of the pick. The
' player is not deciding anything during these, so the wall clock must not
' charge for them, or the game punishes you for its own animations.
SUB Pause (secs AS SINGLE)
    _DELAY secs
    g_t0 = g_t0 + secs
END SUB

'--- draw --------------------------------------------------------------------

SUB DrawLock (msg AS STRING)
    DIM i AS INTEGER, dial AS STRING, ox AS INTEGER
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "T H E   P I C K   A N D   T H E   P I N S", "feel for the notch that sets the pin -- the dial does not lie"

    ' the dial, laid flat. It IS a ring, so the ends wrap; the marker rides it.
    dial = ""
    FOR i = 0 TO NOTCHES - 1
        IF i MOD JUMP = 0 THEN dial = dial + "|" ELSE dial = dial + "."
    NEXT i
    ox = (SW - NOTCHES * 2) \ 2
    COLOR C_DIM, 0
    FOR i = 0 TO NOTCHES - 1
        MgText ox + i * 2, 13, MID$(dial, i + 1, 1)
    NEXT i
    COLOR C_COOL, 0
    MgText ox + g_at * 2, 12, "V"
    MgText ox + g_at * 2, 14, _TRIM$(STR$(g_at))
    COLOR C_DIM, 0
    MgCenter 16, "notch 0 and notch " + _TRIM$(STR$(NOTCHES - 1)) + " are neighbours -- it is a ring"

    ' pins
    COLOR C_TEXT, 0
    FOR i = 1 TO PINS
        IF PINSET(i) THEN
            COLOR C_GOOD, 0
            MgText 54 + (i - 1) * 8, 19, "[SET]"
        ELSEIF i = g_pin THEN
            COLOR C_WARN, 0
            MgText 54 + (i - 1) * 8, 19, "[ >< ]"
        ELSE
            COLOR C_DIM, 0
            MgText 54 + (i - 1) * 8, 19, "[  ]"
        END IF
    NEXT i

    COLOR C_TEXT, 0: MgCenter 22, msg
    MgFuse 26, g_left / g_fuse, g_left
    COLOR C_DIM, 0
    MgCenter 28, "slips: " + _TRIM$(STR$(g_slips)) + "   -- a set on the wrong notch costs " + _TRIM$(STR$(T_MISS)) + "s"
    MgCenter 29, "the fuse burns on its own AND every move takes a bite -- " + _TRIM$(STR$(INT(g_spent * 10) / 10)) + "s spent turning"
    COLOR C_GOOD, 0
    MgCenter 31, "[A]/[D] turn one notch   [Q]/[E] jump " + _TRIM$(STR$(JUMP)) + "   [SPACE] set   [ESC] give up"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB LockSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM AS SINGLE worst, best, budget, think
    DIM AS INTEGER dumb
    _DEST _CONSOLE
    PRINT "LOCKPICK selftest"

    MgSection "the dial is a ring, and the feel is honest"
    Ok "0 and 23 are one notch apart", Ring%(0, NOTCHES - 1) = 1
    Ok "the far side is half a turn away", Ring%(0, NOTCHES \ 2) = NOTCHES \ 2
    Ok "distance is symmetric", RingSymmetric%
    Ok "only the exact notch reads GIVING", Band%(0) = B_GIVING _ANDALSO Band%(1) <> B_GIVING
    Ok "the bands never go backwards as you get further", BandsMonotonic%
    Ok "the direction hint is only offered inside CLOSE range", HintOnlyWhenClose%
    Ok "...and when offered, it points the SHORT way round", HintPointsShortWay%

    MgSection "an efficient search always beats the fuse -- every start, every pin"
    worst = WorstSearchCost!
    best = BestSearchCost!
    budget = LockFuse!(10)
    think = WorstMoveCount% * THINK_PER_MOVE
    PRINT USING "       three pins cost ##.##s at worst, ##.##s at best; fuse ##.##s"; worst; best; budget
    PRINT USING "       plus ## decisions at #.#s of thinking each = ##.##s"; WorstMoveCount%; THINK_PER_MOVE; think
    PRINT USING "       so a good picker needs ##.##s of a ##.##s fuse"; worst + think; budget
    Ok "the worst case for a good picker fits inside the fuse", worst < budget
    Ok "checked EXHAUSTIVELY, not sampled", ExhaustiveCount& = NOTCHES * NOTCHES

    MgSection "...and it fits with REAL thinking time on top, now that the fuse burns by itself"
    Ok "move cost plus a human's thinking time still fits", worst + think < budget
    Ok "...with enough margin to be human once", budget - (worst + think) >= T_MISS
    Ok "even the clumsiest character has room to think", WorstSearchCost! + think < LockFuse!(3)
    Ok "a scripted pause is not charged as dithering", PausesAreFree%

    MgSection "...but brute force does not, which is what makes it a search"
    dumb = TRUE
    IF SweepEveryNotchCost! + SweepMoveCount% * THINK_PER_MOVE < budget THEN dumb = FALSE
    PRINT USING "       walking the whole dial for each pin: ##.##s of moves + ###.##s of thinking"; SweepEveryNotchCost!; SweepMoveCount% * THINK_PER_MOVE
    Ok "turning one notch at a time until it gives runs out the fuse", dumb
    ' On move cost ALONE, so a player who mashes the key without thinking cannot
    ' beat it either. This is the assertion that broke when the fuse grew to 50s
    ' -- brute force suddenly fit, which would have made the whole search optional
    ' -- and T_FINE went from 0.35 to 0.75 to put it back.
    Ok "...and it runs out on move cost ALONE, even for a player thinking instantly", SweepEveryNotchCost! > budget

    MgSection "DEX buys time and nothing else"
    Ok "a clumsy hand gets less fuse", LockFuse!(6) < LockFuse!(16)
    Ok "even the clumsiest still gets a winnable fuse", WorstSearchCost! + WorstMoveCount% * THINK_PER_MOVE < LockFuse!(3)
    Ok "DEX never moves a pin", PinsIgnoreDex%

    MgDone
END SUB

FUNCTION RingSymmetric% ()
    DIM a AS INTEGER, b AS INTEGER
    RingSymmetric% = TRUE
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            IF Ring%(a, b) <> Ring%(b, a) THEN RingSymmetric% = FALSE
        NEXT b
    NEXT a
END FUNCTION

FUNCTION BandsMonotonic% ()
    DIM d AS INTEGER
    BandsMonotonic% = TRUE
    FOR d = 1 TO NOTCHES \ 2
        IF Band%(d) < Band%(d - 1) THEN BandsMonotonic% = FALSE
    NEXT d
END FUNCTION

FUNCTION HintOnlyWhenClose% ()
    DIM a AS INTEGER, b AS INTEGER
    HintOnlyWhenClose% = TRUE
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            IF Ring%(a, b) > 2 _ANDALSO LEN(Hint$(a, b)) > 0 THEN HintOnlyWhenClose% = FALSE
            IF Ring%(a, b) = 0 _ANDALSO LEN(Hint$(a, b)) > 0 THEN HintOnlyWhenClose% = FALSE
        NEXT b
    NEXT a
END FUNCTION

' A hint that points the long way round is worse than no hint: the player follows
' it, the band gets worse, and the lock looks like it is lying.
FUNCTION HintPointsShortWay% ()
    DIM a AS INTEGER, b AS INTEGER, nxt AS INTEGER, h AS STRING
    HintPointsShortWay% = TRUE
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            h = Hint$(a, b)
            IF LEN(h) > 0 THEN
                IF INSTR(h, "clockwise") > 0 THEN nxt = (a + 1) MOD NOTCHES ELSE nxt = (a - 1 + NOTCHES) MOD NOTCHES
                IF Ring%(nxt, b) >= Ring%(a, b) THEN HintPointsShortWay% = FALSE
            END IF
        NEXT b
    NEXT a
END FUNCTION

' THE STRATEGY THE PROOF ASSUMES, and it is one a player can actually follow:
'   1. jump by JUMP until the feel is CLOSE or better
'   2. then step one notch at a time, in the direction the lock hands you
'   3. set
' Nothing here needs reflexes or memory -- only that you stop sweeping coarse
' once the metal answers. That is the skill the fuse is pricing.
FUNCTION SearchCost! (start AS INTEGER, target AS INTEGER)
    DIM at AS INTEGER, guard AS INTEGER
    DIM c AS SINGLE
    at = start
    DO WHILE Band%(Ring%(at, target)) > B_CLOSE _ANDALSO guard < NOTCHES
        at = (at + JUMP) MOD NOTCHES
        c = c + T_JUMP: guard = guard + 1
    LOOP
    guard = 0
    DO WHILE at <> target _ANDALSO guard < NOTCHES
        IF INSTR(Hint$(at, target), "clockwise") > 0 THEN at = (at + 1) MOD NOTCHES ELSE at = (at - 1 + NOTCHES) MOD NOTCHES
        c = c + T_FINE: guard = guard + 1
    LOOP
    SearchCost! = c + T_SET
END FUNCTION

' How many DECISIONS the worst case takes, as opposed to how many seconds of move
' cost. These are different numbers and the fuse has to pay for both: a jump costs
' 0.5s of pick-turning AND however long the player took to decide to jump.
FUNCTION SearchMoves% (start AS INTEGER, target AS INTEGER)
    DIM at AS INTEGER, guard AS INTEGER, n AS INTEGER
    at = start
    DO WHILE Band%(Ring%(at, target)) > B_CLOSE _ANDALSO guard < NOTCHES
        at = (at + JUMP) MOD NOTCHES
        n = n + 1: guard = guard + 1
    LOOP
    guard = 0
    DO WHILE at <> target _ANDALSO guard < NOTCHES
        IF INSTR(Hint$(at, target), "clockwise") > 0 THEN at = (at + 1) MOD NOTCHES ELSE at = (at - 1 + NOTCHES) MOD NOTCHES
        n = n + 1: guard = guard + 1
    LOOP
    SearchMoves% = n + 1                 ' the set is a decision too
END FUNCTION

FUNCTION WorstMoveCount% ()
    DIM a AS INTEGER, b AS INTEGER, n AS INTEGER, worstn AS INTEGER
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            n = SearchMoves%(a, b)
            IF n > worstn THEN worstn = n
        NEXT b
    NEXT a
    WorstMoveCount% = worstn * PINS
END FUNCTION

FUNCTION SweepMoveCount% ()
    SweepMoveCount% = NOTCHES * PINS
END FUNCTION

' The scripted pauses -- a pin clicking home, the pick slipping -- push the clock
' origin forward by exactly as long as they take, so the wall clock cannot charge
' a player for the game's own animations.
FUNCTION PausesAreFree% ()
    DIM before AS SINGLE, after AS SINGLE
    LockSetup 10
    FuseTick: before = g_left
    Pause 0.35!
    FuseTick: after = g_left
    PRINT USING "       across a 0.35s scripted pause the fuse moved #.####s"; ABS(before - after)
    PausesAreFree% = (ABS(before - after) < 0.08!)
END FUNCTION

' Worst case over EVERY start notch and EVERY pin angle. The dial is 24 notches,
' so the whole space is 576 pairs -- there is no reason to sample it.
FUNCTION WorstSearchCost! ()
    DIM a AS INTEGER, b AS INTEGER
    DIM AS SINGLE c, worst
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            c = SearchCost!(a, b)
            IF c > worst THEN worst = c
        NEXT b
    NEXT a
    WorstSearchCost! = worst * PINS
END FUNCTION

FUNCTION BestSearchCost! ()
    DIM a AS INTEGER, b AS INTEGER
    DIM AS SINGLE c, best
    best = 9999!
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            c = SearchCost!(a, b)
            IF c < best THEN best = c
        NEXT b
    NEXT a
    BestSearchCost! = best * PINS
END FUNCTION

FUNCTION ExhaustiveCount& ()
    DIM a AS INTEGER, b AS INTEGER
    DIM n AS LONG
    FOR a = 0 TO NOTCHES - 1
        FOR b = 0 TO NOTCHES - 1
            IF SearchCost!(a, b) > 0 THEN n = n + 1
        NEXT b
    NEXT a
    ExhaustiveCount& = n
END FUNCTION

' The control: no strategy at all, just turn one notch at a time until the pin
' gives. It always WORKS -- that is the point -- it just never works in time.
FUNCTION SweepEveryNotchCost! ()
    SweepEveryNotchCost! = ((NOTCHES - 1) * T_FINE + T_SET) * PINS
END FUNCTION

' "DEX does not move the pins" cannot be shown by dealing the same seed twice --
' QB64's RANDOMIZE does not reset the stream when handed the same value again,
' so the second deal starts one draw late and every pin looks different. The
' honest claim is distributional anyway: over 24000 pins, a clumsy character and
' a nimble one see the SAME uniform spread of angles.
FUNCTION PinsIgnoreDex% ()
    DIM AS SINGLE ma, mb
    DIM AS INTEGER lowa, lowb
    PinsIgnoreDex% = TRUE
    PinSpread 4, ma, lowa
    PinSpread 18, mb, lowb
    PRINT USING "       pin angle: mean ##.## (DEX 4) vs ##.## (DEX 18), rarest notch ####/####"; ma; mb; lowa; lowb
    IF ABS(ma - mb) > 0.35 THEN PinsIgnoreDex% = FALSE
    IF lowa < 700 OR lowb < 700 THEN PinsIgnoreDex% = FALSE      ' expected 1000 each
END FUNCTION

SUB PinSpread (dex AS INTEGER, mean AS SINGLE, rarest AS INTEGER)
    DIM i AS LONG, j AS INTEGER, n AS LONG
    DIM tot AS DOUBLE
    DIM hits(0 TO NOTCHES - 1) AS LONG
    FOR i = 1 TO 8000
        LockSetup dex
        FOR j = 1 TO PINS
            hits(PINAT(j)) = hits(PINAT(j)) + 1
            tot = tot + PINAT(j): n = n + 1
        NEXT j
    NEXT i
    mean = tot / n
    rarest = 32767
    FOR j = 0 TO NOTCHES - 1
        IF hits(j) < rarest THEN rarest = hits(j)
    NEXT j
END SUB

'$INCLUDE:'MG.bas'
