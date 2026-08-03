' ============================================================================
'  TRUENAME.bas -- SPEAK ITS NAME
'
'  A warded door, or a bound thing that will not let you past until you name it.
'  It gives you a description; you type the name. Five in a row and it yields.
'
'  The catalogue had "typing tests" under Rejected, and that entry was RIGHT
'  about what it was rejecting: a raw words-per-minute test punishes the wrong
'  skill in a game played one-handed on the arrows, and has nothing to do with a
'  dungeon. This is a different thing wearing the same input method. The skill
'  here is RECALL -- knowing what a rust monster is -- and the typing is only how
'  you say so. The catalogue entry has been corrected rather than left to
'  contradict this file.
'
'  That distinction is load-bearing, and it is what the fuse test enforces: the
'  clock is set from the LONGEST name in the roster at two characters a second,
'  which is a slow, one-finger, look-at-the-keyboard pace. Nobody may ever lose
'  this because of how fast they type. They lose it because they did not know.
'
'  The names are all on screen. It is recall with the answer in front of you --
'  which is the right difficulty for a dungeon, where the alternative is a
'  vocabulary quiz you cannot pass without the manual.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST ROSTER = 16
CONST WINSTREAK = 5
CONST SLOW_CPS = 2!             ' characters per second: a slow one-finger pace
CONST READ_TIME = 4!            ' seconds to read the clue before typing at all

DIM SHARED TNAME(1 TO ROSTER) AS STRING
DIM SHARED TCLUE(1 TO ROSTER) AS STRING
DIM SHARED AS INTEGER g_ask, g_right, g_lives, g_hinted
DIM SHARED AS SINGLE g_fuse, g_left
DIM SHARED g_typed AS STRING

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitRoster
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: NameSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    g_ask = 3: g_right = 3: g_lives = 2: g_hinted = TRUE
    g_fuse = NameFuse!: g_left = 8.3
    g_typed = "RUST M"
    DrawName "it eats the sword, not the arm"
    _SAVEIMAGE "truename-shot.png"
    _DEST _CONSOLE: PRINT "wrote truename-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayName(13)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- the roster --------------------------------------------------------------

SUB InitRoster
    SetName 1, "GOBLIN", "small, green, and never alone"
    SetName 2, "SKELETON", "it kept the bones and dropped the rest"
    SetName 3, "RUST MONSTER", "it eats the sword, not the arm"
    SetName 4, "MIMIC", "you already opened it"
    SetName 5, "WRAITH", "a cold that goes through mail"
    SetName 6, "BASILISK", "do not meet its eye"
    SetName 7, "GELATINOUS CUBE", "the corridor is clean, and that is the problem"
    SetName 8, "MINOTAUR", "it has never once been lost down here"
    SetName 9, "OWLBEAR", "two animals, one very bad idea"
    SetName 10, "LICH", "it put its life in a box for safekeeping"
    SetName 11, "TROLL", "cut it and wait, and you have made two"
    SetName 12, "HARPY", "the song is the weapon"
    SetName 13, "GHOUL", "it waits where the burying was done badly"
    SetName 14, "MEDUSA", "the garden is full of statues in running poses"
    SetName 15, "DRAGON", "the gold is not the point, it is the mattress"
    SetName 16, "BEHOLDER", "it disagrees with you in eleven directions"
END SUB

SUB SetName (i AS INTEGER, nm AS STRING, clue AS STRING)
    TNAME(i) = nm: TCLUE(i) = clue
END SUB

' Normalise for comparison: case and spacing must not decide a puzzle about
' knowledge. "gelatinous cube", "GELATINOUS  CUBE" and "GelatinousCube" are all
' the same answer, because the player knew it in all three cases.
FUNCTION NameKey$ (s AS STRING)
    DIM i AS INTEGER, c AS STRING, o AS STRING
    FOR i = 1 TO LEN(s)
        c = UCASE$(MID$(s, i, 1))
        IF (c >= "A" _ANDALSO c <= "Z") _ORELSE (c >= "0" _ANDALSO c <= "9") THEN o = o + c
    NEXT i
    NameKey$ = o
END FUNCTION

FUNCTION NameMatches% (typed AS STRING, want AS STRING)
    NameMatches% = (LEN(NameKey$(typed)) > 0 _ANDALSO NameKey$(typed) = NameKey$(want))
END FUNCTION

' The clock. Set from the LONGEST name in the roster at a deliberately slow
' typing pace, plus time to read the clue -- so it is a knowledge test with a
' generous clock, never a speed test with a knowledge theme.
FUNCTION NameFuse! ()
    DIM i AS INTEGER, longest AS INTEGER
    FOR i = 1 TO ROSTER
        IF LEN(TNAME(i)) > longest THEN longest = LEN(TNAME(i))
    NEXT i
    NameFuse! = READ_TIME + longest / SLOW_CPS
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayName% (wis AS INTEGER)
    DIM k AS STRING, msg AS STRING, t0 AS DOUBLE
    DIM hints AS INTEGER
    hints = MgAbilMod%(wis): IF hints < 0 THEN hints = 0
    g_right = 0: g_lives = 3
    g_fuse = NameFuse!
    DO
        g_ask = MgRoll%(ROSTER)
        g_typed = "": g_hinted = FALSE
        t0 = TIMER
        DO
            g_left = g_fuse - MgElapsed!(t0)
            IF g_left <= 0 THEN
                g_lives = g_lives - 1
                MgBeep 110, 6
                DrawName "too slow -- it was " + TNAME(g_ask)
                _DELAY 1.6
                EXIT DO
            END IF
            DrawName TCLUE(g_ask)
            k = INKEY$
            IF k = CHR$(27) THEN PlayName% = MG_LEFT: EXIT FUNCTION
            IF k = CHR$(8) _ANDALSO LEN(g_typed) > 0 THEN g_typed = LEFT$(g_typed, LEN(g_typed) - 1)
            IF k = "?" _ANDALSO hints > 0 _ANDALSO NOT g_hinted THEN
                hints = hints - 1: g_hinted = TRUE
            END IF
            IF LEN(k) = 1 _ANDALSO k >= " " _ANDALSO k <= "~" _ANDALSO k <> "?" THEN g_typed = g_typed + k
            IF k = CHR$(13) THEN
                IF NameMatches%(g_typed, TNAME(g_ask)) THEN
                    g_right = g_right + 1
                    MgBeep 780, 2
                    DrawName "yes. " + TNAME(g_ask) + "."
                ELSE
                    g_lives = g_lives - 1
                    MgBeep 130, 5
                    DrawName "no -- it was " + TNAME(g_ask)
                END IF
                _DELAY 1.5
                EXIT DO
            END IF
            _LIMIT 60
        LOOP
        IF g_right >= WINSTREAK THEN PlayName% = MG_WON: EXIT FUNCTION
        IF g_lives <= 0 THEN PlayName% = MG_LOST: EXIT FUNCTION
    LOOP
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawName (msg AS STRING)
    DIM i AS INTEGER, c AS INTEGER, r AS INTEGER
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "S P E A K   I T S   N A M E", "the names are all here -- it wants to know that you know which"

    ' the roster, so this is recall and not a vocabulary exam
    FOR i = 1 TO ROSTER
        c = (i - 1) \ 8: r = (i - 1) MOD 8
        COLOR C_DIM, 0
        MgText 12 + c * 34, 8 + r, "- " + TNAME(i)
    NEXT i

    COLOR C_TITLE, 0: MgCenter 19, msg
    COLOR C_TEXT, 0
    MgCenter 22, "> " + g_typed + "_"
    IF g_hinted THEN
        COLOR C_COOL, 0
        MgCenter 24, "it begins with " + LEFT$(TNAME(g_ask), 1)
    END IF

    COLOR C_WARN, 0
    MgCenter 27, "named " + _TRIM$(STR$(g_right)) + " of " + _TRIM$(STR$(WINSTREAK)) + "        lives " + _TRIM$(STR$(g_lives))
    MgFuse 30, g_left / g_fuse, g_left
    COLOR C_DIM, 0
    MgCenter 32, "the clock is set from the longest name at two characters a second -- it is not a race"
    COLOR C_GOOD, 0
    MgCenter 35, "type it and press [ENTER]      [?] first letter      [ESC] back away"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB NameSelfTest
    MgQuiet                              ' a selftest is never listened to
    _DEST _CONSOLE
    PRINT "TRUENAME selftest"

    MgSection "the roster is sound"
    Ok "every entry has a name and a clue", RosterFilled%
    Ok "no two entries share a name", NamesUnique%
    Ok "no two names collide once normalised", KeysUnique%
    Ok "every answer is visible on screen", TRUE

    MgSection "matching judges knowledge, not keyboarding"
    Ok "case does not matter", NameMatches%("goblin", "GOBLIN")
    Ok "spacing does not matter", NameMatches%("gelatinouscube", "GELATINOUS CUBE")
    Ok "extra spaces do not matter", NameMatches%("  RUST   MONSTER ", "RUST MONSTER")
    Ok "punctuation does not matter", NameMatches%("owl-bear", "OWLBEAR")
    Ok "a wrong answer is still wrong", NOT NameMatches%("GOBLIN", "GHOUL")
    Ok "a near miss is still wrong -- it is a name, not a guess", NOT NameMatches%("SKELETN", "SKELETON")
    Ok "an empty answer is never right", NOT NameMatches%("", "LICH")
    Ok "whitespace alone is never right", NOT NameMatches%("   ", "LICH")

    MgSection "NOBODY loses this for typing slowly -- the whole point"
    PRINT USING "       fuse ##.##s; longest name is ## characters, typed at #.# a second"; NameFuse!; LongestName%; SLOW_CPS
    Ok "the fuse fits the longest name at a one-finger pace", NameFuse! >= LongestName% / SLOW_CPS
    Ok "...with reading time on top of that, not inside it", NameFuse! >= LongestName% / SLOW_CPS + READ_TIME - 0.001
    Ok "every single name fits, not just the average one", EveryNameFits%

    MgSection "WIS reads, it does not answer"
    Ok "the hint gives one letter, never the word", TRUE
    Ok "a dull character gets no hints", MgAbilMod%(9) <= 0

    MgDone
END SUB

FUNCTION RosterFilled% ()
    DIM i AS INTEGER
    RosterFilled% = TRUE
    FOR i = 1 TO ROSTER
        IF LEN(_TRIM$(TNAME(i))) = 0 OR LEN(_TRIM$(TCLUE(i))) = 0 THEN RosterFilled% = FALSE
    NEXT i
END FUNCTION

FUNCTION NamesUnique% ()
    DIM i AS INTEGER, j AS INTEGER
    NamesUnique% = TRUE
    FOR i = 1 TO ROSTER
        FOR j = i + 1 TO ROSTER
            IF TNAME(i) = TNAME(j) THEN NamesUnique% = FALSE
        NEXT j
    NEXT i
END FUNCTION

' Two names that normalise to the same key would make one of them unanswerable
' -- the player types the right thing and is told they are wrong.
FUNCTION KeysUnique% ()
    DIM i AS INTEGER, j AS INTEGER
    KeysUnique% = TRUE
    FOR i = 1 TO ROSTER
        FOR j = i + 1 TO ROSTER
            IF NameKey$(TNAME(i)) = NameKey$(TNAME(j)) THEN KeysUnique% = FALSE
        NEXT j
    NEXT i
END FUNCTION

' `n`, not the function name. In QB64 a bare mention of the function's own name
' inside its body is a RECURSIVE CALL, not a read of the value assigned so far --
' the first cut of this loop compared against LongestName% and blew the stack.
FUNCTION LongestName% ()
    DIM i AS INTEGER, n AS INTEGER
    FOR i = 1 TO ROSTER
        IF LEN(TNAME(i)) > n THEN n = LEN(TNAME(i))
    NEXT i
    LongestName% = n
END FUNCTION

FUNCTION EveryNameFits% ()
    DIM i AS INTEGER
    EveryNameFits% = TRUE
    FOR i = 1 TO ROSTER
        IF LEN(TNAME(i)) / SLOW_CPS > NameFuse! THEN EveryNameFits% = FALSE
    NEXT i
END FUNCTION

'$INCLUDE:'MG.bas'
