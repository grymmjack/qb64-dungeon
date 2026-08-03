' ============================================================================
'  RPS.bas -- THE GOBLIN'S GAME (rock, paper, scissors)
'
'  Best of five against a goblin. Plain RPS is a coin flip with extra steps, so
'  the goblin is NOT random: each one has a TELL -- a habit in how it chooses --
'  and WIS lets you notice which. Reading the tell is the game; the hands are just
'  how you spend what you read.
'
'  The tells are deliberately exploitable but not deterministic: each goblin plays
'  its habit only PREDICT_PCT of the time and picks freely otherwise. That keeps a
'  read worth having without turning a spotted tell into a guaranteed win, which
'  would be as dull as the coin flip it replaced. Both halves are asserted.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST H_ROCK = 0, H_PAPER = 1, H_SCISSORS = 2
'--- goblin habits ---
CONST T_FAVOURS = 0        ' leans on one hand
CONST T_REPEATS = 1        ' plays whatever it just played
CONST T_CYCLES = 2         ' rock, paper, scissors, rock...
CONST T_BEATSLAST = 3      ' plays what would have beaten YOUR last hand
CONST TELLS = 4
CONST PREDICT_PCT = 70     ' how often it obeys its habit

DIM SHARED gob_tell AS INTEGER, gob_fav AS INTEGER, gob_last AS INTEGER, you_last AS INTEGER

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN RpsSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    gob_tell = T_REPEATS: gob_fav = H_ROCK
    DrawRps H_PAPER, H_ROCK, 2, 1, 3, TRUE, "you win the throw -- paper smothers rock"
    _SAVEIMAGE "rps-shot.png"
    _DEST _CONSOLE: PRINT "wrote rps-shot.png": SYSTEM
END IF
DIM r AS INTEGER
r = PlayRps(14)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

FUNCTION HandName$ (h AS INTEGER)
    SELECT CASE h
        CASE H_ROCK: HandName$ = "ROCK"
        CASE H_PAPER: HandName$ = "PAPER"
        CASE ELSE: HandName$ = "SCISSORS"
    END SELECT
END FUNCTION

FUNCTION TellName$ (t AS INTEGER)
    SELECT CASE t
        CASE T_FAVOURS: TellName$ = "it keeps going back to " + HandName$(gob_fav)
        CASE T_REPEATS: TellName$ = "it plays the same hand twice"
        CASE T_CYCLES: TellName$ = "it works through them in order"
        CASE ELSE: TellName$ = "it plays whatever would have beaten you last"
    END SELECT
END FUNCTION

' 1 you win, -1 you lose, 0 draw.
FUNCTION Beats% (you AS INTEGER, them AS INTEGER)
    IF you = them THEN Beats% = 0: EXIT FUNCTION
    IF (you = H_ROCK AND them = H_SCISSORS) OR (you = H_PAPER AND them = H_ROCK) OR (you = H_SCISSORS AND them = H_PAPER) THEN
        Beats% = 1
    ELSE
        Beats% = -1
    END IF
END FUNCTION

FUNCTION WhatBeats% (h AS INTEGER)
    WhatBeats% = (h + 1) MOD 3
END FUNCTION

SUB NewGoblin
    gob_tell = MgRoll%(TELLS) - 1
    gob_fav = MgRoll%(3) - 1
    gob_last = -1: you_last = -1
END SUB

' The goblin's next hand: its habit PREDICT_PCT of the time, free choice otherwise.
FUNCTION GoblinHand% ()
    DIM h AS INTEGER
    IF MgRoll%(100) > PREDICT_PCT OR gob_last < 0 THEN
        h = MgRoll%(3) - 1
        IF gob_tell = T_FAVOURS AND gob_last < 0 THEN h = gob_fav      ' open on the habit
    ELSE
        SELECT CASE gob_tell
            CASE T_FAVOURS: h = gob_fav
            CASE T_REPEATS: h = gob_last
            CASE T_CYCLES: h = (gob_last + 1) MOD 3
            CASE ELSE
                IF you_last < 0 THEN h = MgRoll%(3) - 1 ELSE h = WhatBeats%(you_last)
        END SELECT
    END IF
    GoblinHand% = h
END FUNCTION

' What a player who has READ the tell should throw next.
FUNCTION CounterPlay% ()
    DIM pred AS INTEGER
    SELECT CASE gob_tell
        CASE T_FAVOURS: pred = gob_fav
        CASE T_REPEATS: IF gob_last < 0 THEN pred = gob_fav ELSE pred = gob_last
        CASE T_CYCLES: IF gob_last < 0 THEN pred = gob_fav ELSE pred = (gob_last + 1) MOD 3
        CASE ELSE: IF you_last < 0 THEN pred = gob_fav ELSE pred = WhatBeats%(you_last)
    END SELECT
    CounterPlay% = WhatBeats%(pred)
END FUNCTION

FUNCTION ReadsTell% (wis AS INTEGER)
    ReadsTell% = (MgAbilMod%(wis) >= 1)
END FUNCTION

FUNCTION PlayRps% (wis AS INTEGER)
    DIM you AS INTEGER, them AS INTEGER, ws AS INTEGER, ls AS INTEGER, k AS STRING
    DIM res AS INTEGER, msg AS STRING, thrown AS INTEGER
    NewGoblin
    msg = "throw a hand"
    DO
        DrawRps -1, -1, ws, ls, thrown, ReadsTell%(wis), msg
        k = UCASE$(INKEY$)
        IF k = CHR$(27) THEN PlayRps% = MG_LEFT: EXIT FUNCTION
        you = -1
        IF k = "R" THEN you = H_ROCK
        IF k = "P" THEN you = H_PAPER
        IF k = "S" THEN you = H_SCISSORS
        IF you >= 0 THEN
            them = GoblinHand%
            res = Beats%(you, them)
            gob_last = them: you_last = you: thrown = thrown + 1
            IF res = 1 THEN ws = ws + 1: msg = "you take the throw"
            IF res = -1 THEN ls = ls + 1: msg = "it takes the throw"
            IF res = 0 THEN msg = "a draw -- throw again"
            DrawRps you, them, ws, ls, thrown, ReadsTell%(wis), msg
            _DELAY 1.1
            IF ws >= 3 THEN PlayRps% = MG_WON: EXIT FUNCTION
            IF ls >= 3 THEN PlayRps% = MG_LOST: EXIT FUNCTION
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

SUB DrawRps (you AS INTEGER, them AS INTEGER, ws AS INTEGER, ls AS INTEGER, thrown AS INTEGER, reads AS INTEGER, msg AS STRING)
    MgHeader "T H E   G O B L I N ' S   G A M E", "best of five -- it is not throwing at random"
    IF you >= 0 THEN
        COLOR C_TEXT, 0: MgCenter 13, "you: " + HandName$(you) + "      it: " + HandName$(them)
    ELSE
        COLOR C_DIM, 0: MgCenter 13, "waiting on your hand"
    END IF
    COLOR C_WARN, 0: MgCenter 17, "you " + _TRIM$(STR$(ws)) + "   --   it " + _TRIM$(STR$(ls)) + "        throw " + _TRIM$(STR$(thrown))
    IF reads THEN
        COLOR C_COOL, 0: MgCenter 21, "you have its measure: " + TellName$(gob_tell)
    ELSE
        COLOR _RGB32(&H70, &H70, &H70), 0: MgCenter 21, "it has a habit, but you cannot pick it out"
    END IF
    COLOR C_TEXT, 0: MgCenter 24, msg
    COLOR C_GOOD, 0: MgCenter 31, "[R]ock   [P]aper   [S]cissors      [ESC] walk away"
    _DISPLAY
END SUB

SUB RpsSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM t AS INTEGER, rate AS DOUBLE, blind AS DOUBLE
    _DEST _CONSOLE
    PRINT "RPS selftest"

    MgSection "the hands resolve correctly"
    MgOk "rock beats scissors", Beats%(H_ROCK, H_SCISSORS) = 1
    MgOk "paper beats rock", Beats%(H_PAPER, H_ROCK) = 1
    MgOk "scissors beats paper", Beats%(H_SCISSORS, H_PAPER) = 1
    MgOk "scissors loses to rock", Beats%(H_SCISSORS, H_ROCK) = -1
    MgOk "same hand draws", Beats%(H_ROCK, H_ROCK) = 0
    MgOk "WhatBeats is consistent with Beats", AllCountersWin%

    MgSection "reading the tell is worth something -- against every habit"
    FOR t = 0 TO TELLS - 1
        rate = ExploitRate#(t, 60000)
        PRINT USING "       tell # : counter-play wins #.### of decided throws"; t; rate
        MgOk "tell " + _TRIM$(STR$(t)) + " is exploitable above chance", rate > 0.6
    NEXT t

    MgSection "...but a spotted tell is not a certainty"
    FOR t = 0 TO TELLS - 1
        rate = ExploitRate#(t, 60000)
        MgOk "tell " + _TRIM$(STR$(t)) + " still loses sometimes", rate < 0.97
    NEXT t

    MgSection "blind play is a coin flip, as it should be"
    blind = BlindRate#(60000)
    PRINT USING "       random play wins #.### of decided throws"; blind
    MgOk "random play is near even", ABS(blind - 0.5) < 0.05

    MgDone
END SUB

FUNCTION AllCountersWin% ()
    DIM h AS INTEGER
    AllCountersWin% = TRUE
    FOR h = 0 TO 2
        IF Beats%(WhatBeats%(h), h) <> 1 THEN AllCountersWin% = FALSE
    NEXT h
END FUNCTION

' Win rate of counter-play against a given tell, over DECIDED throws (draws excluded
' -- a draw is neither side being right, and counting them buries the signal).
FUNCTION ExploitRate# (t AS INTEGER, n AS LONG)
    DIM i AS LONG, you AS INTEGER, them AS INTEGER, r AS INTEGER, w AS LONG, d AS LONG
    RANDOMIZE 7
    gob_tell = t: gob_fav = H_ROCK: gob_last = -1: you_last = -1
    FOR i = 1 TO n
        you = CounterPlay%
        them = GoblinHand%
        r = Beats%(you, them)
        gob_last = them: you_last = you
        IF r <> 0 THEN
            d = d + 1
            IF r = 1 THEN w = w + 1
        END IF
    NEXT i
    IF d = 0 THEN ExploitRate# = 0 ELSE ExploitRate# = w / d
END FUNCTION

FUNCTION BlindRate# (n AS LONG)
    DIM i AS LONG, you AS INTEGER, them AS INTEGER, r AS INTEGER, w AS LONG, d AS LONG
    RANDOMIZE 8
    gob_tell = T_CYCLES: gob_fav = H_ROCK: gob_last = -1: you_last = -1
    FOR i = 1 TO n
        you = MgRoll%(3) - 1
        them = GoblinHand%
        r = Beats%(you, them)
        gob_last = them: you_last = you
        IF r <> 0 THEN
            d = d + 1
            IF r = 1 THEN w = w + 1
        END IF
    NEXT i
    IF d = 0 THEN BlindRate# = 0 ELSE BlindRate# = w / d
END FUNCTION

'$INCLUDE:'MG.bas'
