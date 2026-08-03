' ============================================================================
'  DODGE.bas -- ARROW SLIT mini-game prototype (scratchpad)
'
'  PLANS.todo: "Arrow slits - gesture based - left, right, up, down - dodges".
'
'  A corridor lined with slits. Arrows fly ACROSS it, one volley at a time, and
'  you step out of the line of fire. DEX widens the window; each wave narrows it.
'
'  WHY PERPENDICULAR, NOT "PRESS THE KEY SHOWN"
'
'  The obvious version telegraphs a direction and asks you to press it. That is a
'  reaction test with nothing to learn -- after the second arrow it is muscle
'  memory, and it plays identically on wave one and wave ten.
'
'  Here the arrow's flight is the telegraph and the answer is a RULE: step
'  PERPENDICULAR to it. An arrow from the west flies east, so you go north or
'  south; either works. That is a rule you understand once and then execute under
'  pressure, which is the same shape as everything else in this game's combat --
'  and it means two of the four keys are right, so panic-mashing is punished
'  without the input feeling unfair.
'
'  This is NOT a second composure gauge. Per the design bible ("one composure
'  engine wearing many masks"), the timing half is a FUSE -- the same countdown
'  the luck prompt and the attack fuses use. The only new thing is the direction
'  rule, which is a pure function and is where the assertions go.
'
'  RUN:
'    qb64pe -w -x DODGE.bas -o DODGE.run
'    ./DODGE.run selftest    assertions (rule, window, volley shape)
'    ./DODGE.run shot        one frame -> dodge-shot.png
'    ./DODGE.run             play it
' ============================================================================
$CONSOLE
OPTION _EXPLICIT

CONST TRUE = -1, FALSE = NOT TRUE

'--- directions. The arrow's FROM side; the player's step. ---
CONST D_N = 1, D_E = 2, D_S = 3, D_W = 4

'--- outcome ---
CONST DG_CLEAN = 1                       ' every arrow dodged
CONST DG_HURT = 2                        ' took at least one
CONST DG_FLED = 3

DIM SHARED AS INTEGER SW, SH, CW, CH
SW = 132: SH = 51: CW = 8: CH = 16

DIM SHARED T_RUN AS INTEGER, T_BAD AS INTEGER

DIM cmd AS STRING
ON ERROR GOTO MgFatal          ' no modal dialogs -- see the handler below
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN DodgeSelfTest

SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)

IF INSTR(cmd, "SHOT") > 0 THEN
    DrawSlit D_W, 0.62, 2, 4, 1, "step out of the line"
    _SAVEIMAGE "dodge-shot.png"
    _DEST _CONSOLE
    PRINT "wrote dodge-shot.png"
    SYSTEM
END IF

DIM hits AS INTEGER, outcome AS INTEGER
outcome = PlayVolley(4, 12, hits)
_DEST _CONSOLE
PRINT "outcome ="; outcome; " hits taken ="; hits
SYSTEM


' ----------------------------------------------------------------------------
'  THE RULE -- a pure function, and the whole mechanic
' ----------------------------------------------------------------------------

' An arrow FROM `src` flies along that axis. Stepping along the same axis keeps
' you in the corridor it is travelling down; stepping across it does not. So a
' dodge is correct exactly when it is PERPENDICULAR to the arrow's axis.

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

FUNCTION DodgeCorrect% (src AS INTEGER, stepdir AS INTEGER)   ' `stepdir` -- STEP is reserved
    DodgeCorrect% = FALSE
    IF stepdir < D_N OR stepdir > D_W THEN EXIT FUNCTION   ' not a direction at all
    IF src < D_N OR src > D_W THEN EXIT FUNCTION
    DodgeCorrect% = (AxisOf%(src) <> AxisOf%(stepdir))
END FUNCTION

' 0 = the north/south axis, 1 = east/west.
FUNCTION AxisOf% (d AS INTEGER)
    IF d = D_N OR d = D_S THEN AxisOf% = 0 ELSE AxisOf% = 1
END FUNCTION

FUNCTION DirName$ (d AS INTEGER)
    SELECT CASE d
        CASE D_N: DirName$ = "north"
        CASE D_E: DirName$ = "east"
        CASE D_S: DirName$ = "south"
        CASE D_W: DirName$ = "west"
        CASE ELSE: DirName$ = "?"
    END SELECT
END FUNCTION


' ----------------------------------------------------------------------------
'  TIMING -- a fuse, not a gauge
' ----------------------------------------------------------------------------

FUNCTION AbilMod% (score AS INTEGER)
    AbilMod% = INT((score - 10) / 2)
END FUNCTION

' Seconds to answer arrow number `wave` (1-based) with this DEX.
'
' Shrinks per wave so a volley builds, and is FLOORED: past the floor the window
' stops being a test of reflex and becomes a coin flip, which is the point at
' which players stop believing the game is fair. DEX widens it, and a clumsy hero
' still gets the floor -- never less.
FUNCTION DodgeWindow! (dex AS INTEGER, wave AS INTEGER)
    CONST WIN_BASE = 1.15                 ' generous first arrow: it teaches the rule
    '                                       (`BASE` is reserved -- OPTION BASE)
    CONST STEP_DOWN = 0.11
    CONST FLOOR_S = 0.42                  ' below this it is a coin flip, not a reflex
    DIM w AS SINGLE
    w = WIN_BASE - (wave - 1) * STEP_DOWN + AbilMod%(dex) * 0.07
    IF w < FLOOR_S THEN w = FLOOR_S
    DodgeWindow! = w
END FUNCTION

' How many arrows a slit throws at a given dungeon depth. Deeper corridors are
' better defended; capped so a volley never outlasts the player's patience.
FUNCTION VolleySize% (depth AS INTEGER)
    DIM n AS INTEGER
    n = 2 + depth \ 3
    IF n < 2 THEN n = 2
    IF n > 6 THEN n = 6
    VolleySize% = n
END FUNCTION

FUNCTION RollDie% (sides AS INTEGER)
    IF sides < 1 THEN sides = 1
    RollDie% = INT(RND * sides) + 1
END FUNCTION


' ----------------------------------------------------------------------------
'  PLAY
' ----------------------------------------------------------------------------

FUNCTION PlayVolley% (n AS INTEGER, dex AS INTEGER, hits AS INTEGER)
    DIM i AS INTEGER, src AS INTEGER, win AS SINGLE, t0 AS DOUBLE, el AS SINGLE
    DIM k AS STRING, ext AS INTEGER, stepdir AS INTEGER, done AS INTEGER, msg AS STRING
    hits = 0
    FOR i = 1 TO n
        src = RollDie%(4)
        win = DodgeWindow!(dex, i)
        t0 = TIMER: done = FALSE: msg = "step out of the line"
        DO
            el = TIMER - t0
            IF el < 0 THEN el = el + 86400!
            IF el >= win THEN
                hits = hits + 1
                DrawSlit src, 0, i, n, hits, "The arrow finds you."
                _DELAY 0.6
                EXIT DO
            END IF
            DrawSlit src, 1 - el / win, i, n, hits, msg
            k = INKEY$: ext = 0: stepdir = 0
            IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
            IF k = CHR$(27) THEN PlayVolley% = DG_FLED: EXIT FUNCTION
            IF ext = 72 OR UCASE$(k) = "W" THEN stepdir = D_N
            IF ext = 80 OR UCASE$(k) = "S" THEN stepdir = D_S
            IF ext = 75 OR UCASE$(k) = "A" THEN stepdir = D_W
            IF ext = 77 OR UCASE$(k) = "D" THEN stepdir = D_E
            IF stepdir > 0 THEN
                IF DodgeCorrect%(src, stepdir) THEN
                    DrawSlit src, 1 - el / win, i, n, hits, "Clear."
                    _DELAY 0.35
                ELSE
                    hits = hits + 1
                    DrawSlit src, 1 - el / win, i, n, hits, "You step INTO it."
                    _DELAY 0.6
                END IF
                EXIT DO
            END IF
            _LIMIT 60
        LOOP
    NEXT i
    IF hits = 0 THEN PlayVolley% = DG_CLEAN ELSE PlayVolley% = DG_HURT
END FUNCTION


' ----------------------------------------------------------------------------
'  DRAW
' ----------------------------------------------------------------------------

SUB DrawSlit (src AS INTEGER, frac AS SINGLE, wave AS INTEGER, total AS INTEGER, hits AS INTEGER, msg AS STRING)
    DIM cx AS INTEGER, cy AS INTEGER, i AS INTEGER
    DIM lit AS _UNSIGNED LONG, dull AS _UNSIGNED LONG, danger AS _UNSIGNED LONG   ' `dull` -- DIM is reserved
    CLS , _RGB32(8, 6, 10)
    lit = _RGB32(&HFF, &HD2, &H50)
    dull = _RGB32(&H50, &H48, &H58)
    danger = _RGB32(&HE0, &H33, &H33)
    COLOR _RGB32(&HFF, &HE0, &H50), 0
    CenterText 3, "-=  A R R O W   S L I T S  =-"
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 5, msg

    cx = SW \ 2: cy = 22
    ' the corridor: four exits, the two SAFE ones lit
    COLOR dull, 0
    _PRINTSTRING ((cx - 1) * CW, (cy - 6) * CH), "^"
    _PRINTSTRING ((cx - 1) * CW, (cy + 6) * CH), "v"
    _PRINTSTRING ((cx - 9) * CW, cy * CH), "<"
    _PRINTSTRING ((cx + 9) * CW, cy * CH), ">"
    IF AxisOf%(src) = 1 THEN                       ' arrow travels east/west -> N and S are safe
        COLOR lit, 0
        _PRINTSTRING ((cx - 1) * CW, (cy - 6) * CH), "^"
        _PRINTSTRING ((cx - 1) * CW, (cy + 6) * CH), "v"
    ELSE
        COLOR lit, 0
        _PRINTSTRING ((cx - 9) * CW, cy * CH), "<"
        _PRINTSTRING ((cx + 9) * CW, cy * CH), ">"
    END IF
    ' you, and the slit the arrow comes from
    COLOR _RGB32(&H55, &HFF, &H55), 0
    _PRINTSTRING ((cx - 1) * CW, cy * CH), "@"
    COLOR danger, 0
    SELECT CASE src
        CASE D_W: _PRINTSTRING ((cx - 17) * CW, cy * CH), "))))>"   ' clear of the west exit marker at cx-9
        CASE D_E: _PRINTSTRING ((cx + 12) * CW, cy * CH), "<(((("
        CASE D_N: _PRINTSTRING ((cx - 1) * CW, (cy - 4) * CH), "v"
        CASE D_S: _PRINTSTRING ((cx - 1) * CW, (cy + 4) * CH), "^"
    END SELECT
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 30, "arrow " + _TRIM$(STR$(wave)) + " of " + _TRIM$(STR$(total)) + "     hit " + _TRIM$(STR$(hits)) + " time(s)"
    COLOR _RGB32(&H55, &HFF, &HFF), 0
    CenterText 32, "it comes from the " + DirName$(src) + " -- step ACROSS it"
    DrawFuse frac
    COLOR _RGB32(&H55, &HFF, &H55), 0
    CenterText 38, "[arrows/WASD] step     [ESC] back away"
    _DISPLAY
END SUB

' The same draining bar as the luck fuse and the gesture gauge, so all three read
' as one language.
SUB DrawFuse (frac AS SINGLE)
    DIM fx AS INTEGER, fw AS INTEGER, fy AS INTEGER, f AS SINGLE, kol AS _UNSIGNED LONG
    f = frac: IF f < 0 THEN f = 0
    IF f > 1 THEN f = 1
    fx = 26 * CW: fw = 80 * CW: fy = 35 * CH
    LINE (fx, fy)-(fx + fw, fy + CH - 4), _RGB32(40, 40, 46), BF
    IF f > 0.35 THEN kol = _RGB32(170, 150, 70) ELSE kol = _RGB32(220, 60, 50)
    LINE (fx, fy)-(fx + INT(fw * f), fy + CH - 4), kol, BF
END SUB

SUB CenterText (row AS INTEGER, s AS STRING)
    _PRINTSTRING (((SW - LEN(s)) \ 2) * CW, row * CH), s     ' parens: `*` binds tighter than `\`
END SUB


' ----------------------------------------------------------------------------
'  SELFTEST
' ----------------------------------------------------------------------------

SUB MgOk (label AS STRING, cond AS INTEGER)
    T_RUN = T_RUN + 1
    IF cond THEN PRINT "  ok   "; label ELSE PRINT "  FAIL "; label: T_BAD = T_BAD + 1
END SUB

SUB DodgeSelfTest
    ' NOTE: this prototype predates MG.bi and does not include the harness, so it
    ' cannot call MgQuiet. It is silent because it makes no sound at all -- it has
    ' no MgBeep and no SOUND. A MgQuiet line here would compile as a LABEL and do
    ' nothing, which is exactly what was sitting here before audit-quiet learned to
    ' check that the symbol RESOLVES rather than that the text is present.
    DIM d AS INTEGER, s AS INTEGER, good AS INTEGER, i AS INTEGER
    _DEST _CONSOLE
    PRINT "DODGE selftest"
    PRINT

    PRINT " the rule: step ACROSS the arrow, never along it"
    MgOk "from west  -> north dodges", DodgeCorrect%(D_W, D_N)
    MgOk "from west  -> south dodges", DodgeCorrect%(D_W, D_S)
    MgOk "from west  -> east does NOT", DodgeCorrect%(D_W, D_E) = FALSE
    MgOk "from west  -> west does NOT", DodgeCorrect%(D_W, D_W) = FALSE
    MgOk "from north -> east dodges", DodgeCorrect%(D_N, D_E)
    MgOk "from north -> west dodges", DodgeCorrect%(D_N, D_W)
    MgOk "from north -> south does NOT", DodgeCorrect%(D_N, D_S) = FALSE
    MgOk "from south -> north does NOT", DodgeCorrect%(D_S, D_N) = FALSE

    PRINT
    PRINT " every source has EXACTLY two answers (so panic-mashing is a coin flip, not a win)"
    good = TRUE
    FOR d = D_N TO D_W
        s = 0
        FOR i = D_N TO D_W
            IF DodgeCorrect%(d, i) THEN s = s + 1
        NEXT i
        IF s <> 2 THEN good = FALSE
    NEXT d
    MgOk "2 of 4 keys correct, from every source", good
    MgOk "garbage input is never a dodge", DodgeCorrect%(D_W, 0) = FALSE
    MgOk "out-of-range input is never a dodge", DodgeCorrect%(D_W, 99) = FALSE
    MgOk "a bad SOURCE never auto-passes", DodgeCorrect%(0, D_N) = FALSE

    PRINT
    PRINT " the window"
    MgOk "wave 2 is tighter than wave 1", DodgeWindow!(10, 2) < DodgeWindow!(10, 1)
    MgOk "DEX widens it", DodgeWindow!(18, 3) > DodgeWindow!(10, 3)
    MgOk "never below the floor, however deep", DodgeWindow!(3, 20) >= 0.42
    MgOk "first arrow is generous enough to teach the rule", DodgeWindow!(10, 1) >= 1.0

    PRINT
    PRINT " volley size by depth"
    MgOk "shallow corridors are short", VolleySize%(1) = 2
    MgOk "deeper is longer", VolleySize%(9) > VolleySize%(1)
    MgOk "capped so it never outstays its welcome", VolleySize%(99) = 6

    PRINT
    PRINT USING "  ### assertion(s), ### failed"; T_RUN; T_BAD
    IF T_BAD > 0 THEN SYSTEM 1
    PRINT "  ALL GREEN"
    SYSTEM
END SUB
