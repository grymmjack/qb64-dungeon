' ============================================================================
'  RIDDLE.bas -- MAGIC MOUTH mini-game prototype (scratchpad)
'
'  PLANS.todo: "Magic mouths - save WIS - mini-game riddles".
'
'  A face in the stone poses a riddle. You type an answer. WIS buys you patience:
'  the modifier adds attempts, and a good WIS save turns your last wrong answer
'  into a hint instead of a failure.
'
'  WHY IT IS SHAPED THIS WAY
'
'  The hard part of a riddle game is NOT the riddle, it is deciding whether the
'  player got it right. "a shadow", "Shadow", "shadows" and "the shadow." are the
'  same answer, and a game that rejects any of them feels broken and unfair in a
'  way no amount of good writing survives. So RiddleMatch% is the real mechanic
'  and the thing this prototype tests hardest -- everything else is presentation.
'
'  RUN:
'    qb64pe -w -x RIDDLE.bas -o RIDDLE.run
'    ./RIDDLE.run selftest     assertions, stdout, exit code (headless-safe)
'    ./RIDDLE.run              play it
'
'  INTEGRATION NOTE: nothing here touches the game. When this moves in, the
'  matcher and the loader go to game/ as-is; the draw code becomes a Chronicle-
'  style panel and the reward/penalty routes through CurioGain / RecordCurio.
' ============================================================================
$CONSOLE
OPTION _EXPLICIT

CONST TRUE = -1, FALSE = NOT TRUE
CONST MAXRIDDLE = 200

DIM SHARED RID_ANSWER(1 TO MAXRIDDLE) AS STRING
DIM SHARED RID_TEXT(1 TO MAXRIDDLE) AS STRING
DIM SHARED RID_N AS INTEGER

'--- the outcome of one encounter (what the game will act on) ---
CONST RID_SOLVED = 1
CONST RID_FAILED = 2
CONST RID_FLED = 3

DIM SHARED AS INTEGER SW, SH, CW, CH
SW = 132: SH = 51: CW = 8: CH = 16

DIM cmd AS STRING
ON ERROR GOTO MgFatal          ' no modal dialogs -- see the handler below
cmd = UCASE$(COMMAND$)

LoadRiddles "data/riddles.txt"

IF INSTR(cmd, "SELFTEST") > 0 THEN RiddleSelfTest

'--- interactive: a real screen ---
SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)

' `shot` -- render one frame and save it. A mini-game that passes its logic tests and draws
' nothing is still broken, and only a picture catches that.
IF INSTR(cmd, "SHOT") > 0 THEN
    DrawRiddle 1, 2, "Wrong. One guess left.", TRUE
    DrawGuess "a shadow"
    _SAVEIMAGE "riddle-shot.png"
    _DEST _CONSOLE
    PRINT "wrote riddle-shot.png"
    SYSTEM
END IF

DIM outcome AS INTEGER
outcome = PlayRiddle(RollDie(RID_N), 12)          ' WIS 12 = no modifier
_DEST _CONSOLE
PRINT "outcome ="; outcome
SYSTEM


' ----------------------------------------------------------------------------
'  DATA
' ----------------------------------------------------------------------------


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

SUB LoadRiddles (path AS STRING)
    DIM f AS INTEGER, ln AS STRING, bar AS INTEGER
    RID_N = 0
    IF NOT _FILEEXISTS(path) THEN EXIT SUB
    f = FREEFILE
    OPEN path FOR INPUT AS #f
    DO UNTIL EOF(f)
        LINE INPUT #f, ln
        ln = _TRIM$(ln)
        IF LEN(ln) > 0 AND LEFT$(ln, 1) <> "#" THEN
            bar = INSTR(ln, "|")
            IF bar > 0 AND RID_N < MAXRIDDLE THEN
                RID_N = RID_N + 1
                RID_ANSWER(RID_N) = _TRIM$(LEFT$(ln, bar - 1))
                RID_TEXT(RID_N) = _TRIM$(MID$(ln, bar + 1))
            END IF
        END IF
    LOOP
    CLOSE #f
END SUB


' ----------------------------------------------------------------------------
'  THE MATCHER -- the actual mechanic
' ----------------------------------------------------------------------------

' Reduce an answer to the letters that carry meaning: lowercase, drop anything
' that is not a letter or a digit, and drop a leading article. Trailing "s" is
' NOT stripped here -- RiddleMatch% tries both forms instead, so "bones" can be
' the canonical answer without "bone" silently becoming a different word.
FUNCTION RiddleNorm$ (s AS STRING)
    DIM o AS STRING, i AS INTEGER, c AS INTEGER, ch AS STRING
    FOR i = 1 TO LEN(s)
        c = ASC(s, i)
        IF c >= 65 AND c <= 90 THEN c = c + 32          ' upper -> lower
        IF (c >= 97 AND c <= 122) OR (c >= 48 AND c <= 57) THEN o = o + CHR$(c)
    NEXT i
    ' leading article: "ashadow" -> "shadow", "theriver" -> "river"
    IF LEN(o) > 3 THEN
        IF LEFT$(o, 3) = "the" THEN o = MID$(o, 4)
    END IF
    IF LEN(o) > 2 THEN
        IF LEFT$(o, 2) = "an" THEN o = MID$(o, 3)
    END IF
    IF LEN(o) > 1 THEN
        IF LEFT$(o, 1) = "a" THEN
            ' only when what follows is still a word -- "a" alone, or "ash", must survive
            IF LEN(o) > 3 THEN o = MID$(o, 2)
        END IF
    END IF
    RiddleNorm$ = o
END FUNCTION

' Is `guess` an acceptable answer to `answer` (which may be slash-separated
' alternates)? Singular/plural are treated as the same word.
FUNCTION RiddleMatch% (guess AS STRING, answer AS STRING)
    DIM g AS STRING, rest AS STRING, one AS STRING, p AS INTEGER
    RiddleMatch% = FALSE
    g = RiddleNorm$(guess)
    IF LEN(g) = 0 THEN EXIT FUNCTION
    rest = answer
    DO
        p = INSTR(rest, "/")
        IF p > 0 THEN
            one = LEFT$(rest, p - 1): rest = MID$(rest, p + 1)
        ELSE
            one = rest: rest = ""
        END IF
        one = RiddleNorm$(one)
        IF LEN(one) > 0 THEN
            IF g = one THEN RiddleMatch% = TRUE: EXIT FUNCTION
            IF g = one + "s" THEN RiddleMatch% = TRUE: EXIT FUNCTION
            IF one = g + "s" THEN RiddleMatch% = TRUE: EXIT FUNCTION
        END IF
    LOOP WHILE LEN(rest) > 0
END FUNCTION


' ----------------------------------------------------------------------------
'  RULES
' ----------------------------------------------------------------------------

FUNCTION AbilMod% (score AS INTEGER)
    AbilMod% = INT((score - 10) / 2)
END FUNCTION

' How many guesses WIS buys. Floor of 1 -- a dull-witted hero still gets to try
' once, because a mini-game you cannot attempt is just a damage roll with extra
' steps.
FUNCTION RiddleTries% (wis AS INTEGER)
    DIM t AS INTEGER
    t = 2 + AbilMod%(wis)
    IF t < 1 THEN t = 1
    IF t > 5 THEN t = 5
    RiddleTries% = t
END FUNCTION

' The hint: the answer with all but the first letter masked, lengths preserved,
' so "magic mouth" reads "m____ m____". Spaces stay visible -- knowing it is two
' words is most of the help.
FUNCTION RiddleHint$ (answer AS STRING)
    DIM a AS STRING, o AS STRING, i AS INTEGER, ch AS STRING, fresh AS INTEGER
    DIM p AS INTEGER
    a = answer
    p = INSTR(a, "/"): IF p > 0 THEN a = LEFT$(a, p - 1)   ' hint from the FIRST alternate
    fresh = TRUE
    FOR i = 1 TO LEN(a)
        ch = MID$(a, i, 1)
        IF ch = " " THEN
            o = o + " ": fresh = TRUE
        ELSEIF fresh THEN
            o = o + ch: fresh = FALSE
        ELSE
            o = o + "_"
        END IF
    NEXT i
    RiddleHint$ = o
END FUNCTION

FUNCTION RollDie% (sides AS INTEGER)
    IF sides < 1 THEN sides = 1
    RollDie% = INT(RND * sides) + 1
END FUNCTION


' ----------------------------------------------------------------------------
'  PLAY
' ----------------------------------------------------------------------------

FUNCTION PlayRiddle% (idx AS INTEGER, wis AS INTEGER)
    DIM tries AS INTEGER, used AS INTEGER, guess AS STRING, k AS STRING
    DIM chcode AS INTEGER, hinted AS INTEGER, msg AS STRING
    IF idx < 1 OR idx > RID_N THEN PlayRiddle% = RID_FAILED: EXIT FUNCTION
    tries = RiddleTries%(wis)
    msg = "The mouth waits."
    DO
        DrawRiddle idx, tries - used, msg, hinted
        k = INKEY$
        IF LEN(k) = 1 THEN
            chcode = ASC(k)
            IF chcode = 27 THEN PlayRiddle% = RID_FLED: EXIT FUNCTION
            IF chcode = 13 THEN
                IF RiddleMatch%(guess, RID_ANSWER(idx)) THEN
                    DrawRiddle idx, tries - used, "The stone grinds into a smile. '" + _TRIM$(guess) + "' it says. Correct.", hinted
                    _DELAY 2
                    PlayRiddle% = RID_SOLVED: EXIT FUNCTION
                END IF
                used = used + 1
                IF used >= tries THEN
                    DrawRiddle idx, 0, "The mouth closes. The answer was " + CHR$(34) + FirstAnswer$(RID_ANSWER(idx)) + CHR$(34) + ".", hinted
                    _DELAY 2
                    PlayRiddle% = RID_FAILED: EXIT FUNCTION
                END IF
                ' the WIS save: on the LAST remaining try, a good save spends it on a hint
                IF used = tries - 1 AND NOT hinted THEN
                    IF RollDie%(20) + AbilMod%(wis) >= 11 THEN
                        hinted = TRUE
                        msg = "Something in you catches the shape of it."
                    ELSE
                        msg = "Wrong. One guess left."
                    END IF
                ELSE
                    msg = "Wrong."
                END IF
                guess = ""
            ELSEIF chcode = 8 THEN
                IF LEN(guess) > 0 THEN guess = LEFT$(guess, LEN(guess) - 1)
            ELSEIF chcode >= 32 AND chcode <= 126 AND LEN(guess) < 40 THEN
                guess = guess + k
            END IF
        END IF
        DrawGuess guess
        _LIMIT 60
    LOOP
END FUNCTION

FUNCTION FirstAnswer$ (answer AS STRING)
    DIM p AS INTEGER
    p = INSTR(answer, "/")
    IF p > 0 THEN FirstAnswer$ = _TRIM$(LEFT$(answer, p - 1)) ELSE FirstAnswer$ = _TRIM$(answer)
END FUNCTION

SUB DrawRiddle (idx AS INTEGER, left AS INTEGER, msg AS STRING, hinted AS INTEGER)
    DIM y AS INTEGER
    CLS , _RGB32(10, 8, 14)
    COLOR _RGB32(&HFF, &HE0, &H50), 0
    CenterText 6, "-=  A  M A G I C   M O U T H  =-"
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 8, "The wall opens an eyeless mouth and speaks."
    COLOR _RGB32(&HFF, &HFF, &HFF), 0
    WrapText RID_TEXT(idx), 12, 90
    IF hinted THEN
        COLOR _RGB32(&H55, &HFF, &HFF), 0
        CenterText 20, "it begins:   " + RiddleHint$(RID_ANSWER(idx))
    END IF
    COLOR _RGB32(&HAA, &HAA, &HAA), 0
    CenterText 24, msg
    COLOR _RGB32(&HFF, &HC0, &H40), 0
    CenterText 26, "guesses left: " + _TRIM$(STR$(left))
    COLOR _RGB32(&H55, &HFF, &H55), 0
    CenterText 34, "[ENTER] answer     [ESC] walk away"
END SUB

SUB DrawGuess (guess AS STRING)
    COLOR _RGB32(&HEC, &HE8, &HDC), 0
    CenterText 30, "> " + guess + "_" + SPACE$(8)
    _DISPLAY
END SUB

SUB CenterText (row AS INTEGER, s AS STRING)
    ' PARENTHESISE THE DIVISION. In BASIC `*` binds tighter than `\`, so
    '   (SW - LEN(s)) \ 2 * CW     is    (SW - LEN(s)) \ (2 * CW)
    ' -- which for a 31-char line on a 132-col screen is 6 pixels, not 404. Every line
    ' rendered flush against the left edge and still looked like plausible output.
    _PRINTSTRING (((SW - LEN(s)) \ 2) * CW, row * CH), s
END SUB

' Word-wrap `s` into centred lines of at most `w` chars, starting at `row`.
SUB WrapText (s AS STRING, row AS INTEGER, w AS INTEGER)
    DIM rest AS STRING, ln AS STRING, sp AS INTEGER, y AS INTEGER
    rest = s: y = row
    DO WHILE LEN(rest) > 0
        IF LEN(rest) <= w THEN
            CenterText y, rest: EXIT DO
        END IF
        sp = w
        DO WHILE sp > 1 AND MID$(rest, sp, 1) <> " ": sp = sp - 1: LOOP
        IF sp <= 1 THEN sp = w
        ln = LEFT$(rest, sp - 1)
        CenterText y, ln
        rest = _TRIM$(MID$(rest, sp + 1))
        y = y + 2
    LOOP
END SUB


' ----------------------------------------------------------------------------
'  SELFTEST -- the matcher is the mechanic, so it gets the assertions
' ----------------------------------------------------------------------------

DIM SHARED T_RUN AS INTEGER, T_BAD AS INTEGER

SUB Ok (label AS STRING, cond AS INTEGER)
    T_RUN = T_RUN + 1
    IF cond THEN
        PRINT "  ok   "; label
    ELSE
        PRINT "  FAIL "; label: T_BAD = T_BAD + 1
    END IF
END SUB

SUB RiddleSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM i AS INTEGER, dup AS INTEGER, j AS INTEGER
    _DEST _CONSOLE
    PRINT "RIDDLE selftest"
    PRINT

    PRINT " data"
    Ok "riddles loaded", RID_N > 0
    Ok "every riddle has an answer AND text", AllRiddlesPopulated%
    Ok "no duplicate answers", NoDuplicateAnswers%
    Ok "every riddle fits the panel (<200 chars)", AllRiddlesFit%

    PRINT
    PRINT " matcher -- the forms a player actually types"
    Ok "exact", RiddleMatch%("shadow", "shadow")
    Ok "case", RiddleMatch%("SHADOW", "shadow")
    Ok "leading article 'a'", RiddleMatch%("a shadow", "shadow")
    Ok "leading article 'the'", RiddleMatch%("the shadow", "shadow")
    Ok "leading article 'an'", RiddleMatch%("an echo", "echo")
    Ok "trailing punctuation", RiddleMatch%("shadow.", "shadow")
    Ok "surrounding spaces", RiddleMatch%("   shadow  ", "shadow")
    Ok "plural given, singular wanted", RiddleMatch%("shadows", "shadow")
    Ok "singular given, plural wanted", RiddleMatch%("bone", "bones")
    Ok "two words keep both", RiddleMatch%("your name", "your name")
    Ok "alternate answer accepted", RiddleMatch%("torch", "candle/torch")
    Ok "first alternate accepted", RiddleMatch%("candle", "candle/torch")

    PRINT
    PRINT " matcher -- must NOT be fooled"
    Ok "empty guess rejected", RiddleMatch%("", "shadow") = FALSE
    Ok "spaces-only guess rejected", RiddleMatch%("   ", "shadow") = FALSE
    Ok "wrong word rejected", RiddleMatch%("light", "shadow") = FALSE
    Ok "substring is not a match", RiddleMatch%("shad", "shadow") = FALSE
    Ok "superstring is not a match", RiddleMatch%("shadowy", "shadow") = FALSE
    ' 'a' as a whole answer must survive the article strip
    Ok "short word not eaten by article strip", RiddleNorm$("ash") = "ash"

    PRINT
    PRINT " tries from WIS"
    Ok "WIS 10 -> 2 tries", RiddleTries%(10) = 2
    Ok "WIS 18 -> 6 clamped to 5", RiddleTries%(18) = 5
    Ok "WIS 3 -> floor of 1, never 0", RiddleTries%(3) = 1

    PRINT
    PRINT " hint masking"
    Ok "keeps first letter", LEFT$(RiddleHint$("shadow"), 1) = "s"
    Ok "masks the rest", RiddleHint$("shadow") = "s_____"
    Ok "preserves word count", RiddleHint$("your name") = "y___ n___"
    Ok "hints from the first alternate only", RiddleHint$("candle/torch") = "c_____"
    Ok "hint is never the answer", RiddleHint$("shadow") <> "shadow"

    PRINT
    PRINT " every shipped riddle is solvable by its own answer"
    Ok "answer matches itself, all rows", AllAnswersSelfMatch%

    PRINT
    PRINT USING "  ### assertion(s), ### failed"; T_RUN; T_BAD
    IF T_BAD > 0 THEN SYSTEM 1
    PRINT "  ALL GREEN"
    SYSTEM
END SUB

FUNCTION AllRiddlesPopulated%
    DIM i AS INTEGER
    AllRiddlesPopulated% = TRUE
    FOR i = 1 TO RID_N
        IF LEN(_TRIM$(RID_ANSWER(i))) = 0 OR LEN(_TRIM$(RID_TEXT(i))) = 0 THEN AllRiddlesPopulated% = FALSE
    NEXT i
END FUNCTION

FUNCTION AllRiddlesFit%
    DIM i AS INTEGER
    AllRiddlesFit% = TRUE
    FOR i = 1 TO RID_N
        IF LEN(RID_TEXT(i)) > 200 THEN AllRiddlesFit% = FALSE
    NEXT i
END FUNCTION

' A duplicate answer means two riddles a player can solve by guessing the same
' word, which reads as the game repeating itself.
FUNCTION NoDuplicateAnswers%
    DIM i AS INTEGER, j AS INTEGER
    NoDuplicateAnswers% = TRUE
    FOR i = 1 TO RID_N - 1
        FOR j = i + 1 TO RID_N
            IF RiddleNorm$(FirstAnswer$(RID_ANSWER(i))) = RiddleNorm$(FirstAnswer$(RID_ANSWER(j))) THEN NoDuplicateAnswers% = FALSE
        NEXT j
    NEXT i
END FUNCTION

' The one that would actually ship a broken riddle: an answer the matcher itself
' rejects (a stray character in the data, an empty alternate).
FUNCTION AllAnswersSelfMatch%
    DIM i AS INTEGER
    AllAnswersSelfMatch% = TRUE
    FOR i = 1 TO RID_N
        IF NOT RiddleMatch%(FirstAnswer$(RID_ANSWER(i)), RID_ANSWER(i)) THEN
            PRINT "       row"; i; "answer does not match itself: "; RID_ANSWER(i)
            AllAnswersSelfMatch% = FALSE
        END IF
    NEXT i
END FUNCTION
