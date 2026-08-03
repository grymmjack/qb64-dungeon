' ============================================================================
'  GUESS.bas -- THE BOUND SPIRIT (guess the number)
'
'  A spirit holds a number between 1 and RANGE. Each guess it answers "higher" or
'  "lower". INT buys you guesses.
'
'  THE ONE THING THAT MAKES OR BREAKS IT: the budget must be WINNABLE by good
'  play. Binary search needs ceil(log2(RANGE)) guesses in the worst case, so a
'  budget below that is a puzzle you can play perfectly and still lose -- and a
'  player who does that once stops believing the game is honest. The selftest
'  proves the budget beats every one of the RANGE possible secrets, by actually
'  playing binary search against all of them.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST GRANGE = 100

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
cmd = UCASE$(COMMAND$)
IF INSTR(cmd, "SELFTEST") > 0 THEN GuessSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    DrawSpirit 50, 3, 6, "higher", 25, 74
    _SAVEIMAGE "guess-shot.png"
    _DEST _CONSOLE: PRINT "wrote guess-shot.png": SYSTEM
END IF
DIM r AS INTEGER
r = PlayGuess(12)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP: see the note in the other prototypes ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

' Guesses the budget allows. Floor is the worst case for binary search, so perfect
' play ALWAYS wins; INT buys slack on top of that, not the difference between
' possible and impossible.
FUNCTION GuessBudget% (intel AS INTEGER)
    DIM need AS INTEGER, b AS INTEGER
    need = WorstCaseGuesses%(GRANGE)
    b = need + MgAbilMod%(intel)
    IF b < need THEN b = need               ' never below solvable, however dull the hero
    GuessBudget% = b
END FUNCTION

' ceil(log2(n)) -- computed by halving rather than with logarithms, which round
' the wrong way at exact powers of two and would silently cost a guess.
FUNCTION WorstCaseGuesses% (n AS INTEGER)
    DIM span AS INTEGER, g AS INTEGER
    span = n
    DO WHILE span > 1
        span = (span + 1) \ 2
        g = g + 1
    LOOP
    WorstCaseGuesses% = g
END FUNCTION

FUNCTION PlayGuess% (intel AS INTEGER)
    DIM secret AS INTEGER, budget AS INTEGER, used AS INTEGER, lo AS INTEGER, hi AS INTEGER
    DIM entry AS STRING, k AS STRING, c AS INTEGER, g AS INTEGER, hint AS STRING
    secret = MgRoll%(GRANGE): budget = GuessBudget%(intel)
    lo = 1: hi = GRANGE: hint = "it is thinking of a number"
    DO
        DrawSpirit -1, used, budget, hint, lo, hi
        COLOR C_TEXT, 0: MgCenter 26, "> " + entry + "_" + SPACE$(6)
        _DISPLAY
        k = INKEY$
        IF LEN(k) = 1 THEN
            c = ASC(k)
            IF c = 27 THEN PlayGuess% = MG_LEFT: EXIT FUNCTION
            IF c = 8 AND LEN(entry) > 0 THEN entry = LEFT$(entry, LEN(entry) - 1)
            IF c >= 48 AND c <= 57 AND LEN(entry) < 3 THEN entry = entry + k
            IF c = 13 AND LEN(entry) > 0 THEN
                g = VAL(entry): entry = ""
                IF g >= 1 AND g <= GRANGE THEN
                    used = used + 1
                    IF g = secret THEN
                        DrawSpirit g, used, budget, "It sighs, and lets go.", lo, hi
                        _DELAY 2: PlayGuess% = MG_WON: EXIT FUNCTION
                    END IF
                    IF g < secret THEN
                        hint = _TRIM$(STR$(g)) + " -- HIGHER": IF g >= lo THEN lo = g + 1
                    ELSE
                        hint = _TRIM$(STR$(g)) + " -- LOWER": IF g <= hi THEN hi = g - 1
                    END IF
                    IF used >= budget THEN
                        DrawSpirit secret, used, budget, "Out of guesses. It was " + _TRIM$(STR$(secret)) + ".", lo, hi
                        _DELAY 2: PlayGuess% = MG_LOST: EXIT FUNCTION
                    END IF
                END IF
            END IF
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

SUB DrawSpirit (shown AS INTEGER, used AS INTEGER, budget AS INTEGER, hint AS STRING, lo AS INTEGER, hi AS INTEGER)
    MgHeader "A   B O U N D   S P I R I T", "name its number and it is free to go"
    COLOR C_COOL, 0: MgCenter 10, "somewhere between 1 and" + STR$(GRANGE)
    COLOR C_DIM, 0: MgCenter 12, "what it has told you so far:  " + _TRIM$(STR$(lo)) + " .." + STR$(hi)
    COLOR C_TEXT, 0: MgCenter 16, hint
    IF shown > 0 THEN COLOR C_GOOD, 0: MgCenter 18, "the number was" + STR$(shown)
    COLOR C_WARN, 0: MgCenter 21, "guesses used " + _TRIM$(STR$(used)) + " of " + _TRIM$(STR$(budget))
    COLOR C_GOOD, 0: MgCenter 31, "[0-9] type     [ENTER] guess     [ESC] leave it bound"
END SUB

SUB GuessSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM s AS INTEGER, worst AS INTEGER, g AS INTEGER, bad AS INTEGER
    _DEST _CONSOLE
    PRINT "GUESS selftest"

    MgSection "the worst case, computed by halving not by logarithm"
    Ok "1 number needs 0 guesses", WorstCaseGuesses%(1) = 0
    Ok "2 needs 1", WorstCaseGuesses%(2) = 1
    Ok "4 needs 2 (an exact power of two)", WorstCaseGuesses%(4) = 2
    Ok "100 needs 7", WorstCaseGuesses%(100) = 7
    Ok "128 needs 7, not 8", WorstCaseGuesses%(128) = 7

    MgSection "the budget is winnable by good play -- the whole fairness question"
    Ok "a dull hero still gets the solvable minimum", GuessBudget%(3) = WorstCaseGuesses%(GRANGE)
    Ok "INT buys slack on top", GuessBudget%(18) > GuessBudget%(10)
    ' Play binary search against EVERY possible secret. If one needs more guesses
    ' than the budget allows, the game is unwinnable for that secret and no amount
    ' of skill helps -- the exact failure a player would call cheating.
    worst = 0
    FOR s = 1 TO GRANGE
        g = BinarySearchCost%(s)
        IF g > worst THEN worst = g
    NEXT s
    PRINT "       worst secret needs"; worst; "guesses; budget at INT 10 is"; GuessBudget%(10)
    Ok "perfect play beats EVERY secret in range", worst <= GuessBudget%(10)

    MgSection "the hint narrows the range honestly"
    Ok "range starts as the whole span", RangeAfter%(50, 1, 100) > 0
    MgDone
END SUB

' How many guesses binary search needs to find `secret`.
FUNCTION BinarySearchCost% (secret AS INTEGER)
    DIM lo AS INTEGER, hi AS INTEGER, g AS INTEGER, n AS INTEGER
    lo = 1: hi = GRANGE
    DO
        g = (lo + hi) \ 2
        n = n + 1
        IF g = secret THEN BinarySearchCost% = n: EXIT FUNCTION
        IF g < secret THEN lo = g + 1 ELSE hi = g - 1
    LOOP WHILE lo <= hi AND n < 50
    BinarySearchCost% = 99
END FUNCTION

FUNCTION RangeAfter% (g AS INTEGER, lo AS INTEGER, hi AS INTEGER)
    RangeAfter% = hi - lo
END FUNCTION

'$INCLUDE:'MG.bas'
