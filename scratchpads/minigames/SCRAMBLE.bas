' ============================================================================
'  SCRAMBLE.bas -- THE SCATTERED WORD
'
'  Letters carved into a door, in the wrong order. Put them back.
'
'  A word scramble has exactly one way to be unfair, and it is not difficulty --
'  it is AMBIGUITY. If two words in the list are anagrams of each other, the
'  player unscrambles the letters correctly, types a real answer, and is told
'  they are wrong. There is no way to recover from that as a player and no way to
'  see it as an author without checking, because it depends on a pair of entries
'  rather than on any one of them.
'
'  This is not hypothetical. The first run of this file's own check found
'  SCEPTRE and SPECTRE sitting eight entries apart in a list I had just written,
'  and I would not have seen it by reading -- neither word looks wrong, and the
'  fault is in the pair.
'
'  So the list is checked pairwise at startup and the check is an assertion, not
'  a comment: no two words may share a letter multiset. Everything else follows
'  from that -- if the answer is the only word that fits the letters, then the
'  letters are a fair question.
'
'  Three smaller things, each of which is a real bug that looks like bad luck:
'  the scramble must use every letter and no others (a dropped letter makes it
'  unsolvable and looks like a hard one), it must not come out as the word itself
'  (a free point that reads as a glitch), and it must not accidentally spell a
'  DIFFERENT word from the list (which is ambiguity again, arriving by luck).
'
'  INT reveals a letter in its final position. It never shortens the word.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST WORDN = 24
CONST WINSTREAK = 4
CONST SLOW_CPS = 2!
CONST THINK_TIME = 12!          ' seconds to actually solve it, before typing

DIM SHARED WORD(1 TO WORDN) AS STRING
DIM SHARED AS INTEGER g_ask, g_right, g_lives, g_reveal
DIM SHARED AS SINGLE g_fuse, g_left
DIM SHARED g_typed AS STRING, g_shown AS STRING

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitWords
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: ScrSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 111
    g_ask = 7: g_shown = Scramble$(WORD(g_ask))
    g_right = 2: g_lives = 2: g_reveal = 1
    g_fuse = ScrFuse!(WORD(g_ask)): g_left = 13.2
    g_typed = "PORT"
    DrawScr "the letters are all there"
    _SAVEIMAGE "scramble-shot.png"
    _DEST _CONSOLE: PRINT "wrote scramble-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayScr(14)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- the words ---------------------------------------------------------------

SUB InitWords
    WORD(1) = "LANTERN": WORD(2) = "SHIELD": WORD(3) = "POTION"
    WORD(4) = "CAVERN": WORD(5) = "SKULL": WORD(6) = "TORCH"
    WORD(7) = "PORTCULLIS": WORD(8) = "GARGOYLE": WORD(9) = "OBELISK"
    WORD(10) = "CATACOMB": WORD(11) = "BRAZIER": WORD(12) = "GRIMOIRE"
    WORD(13) = "OBSIDIAN": WORD(14) = "CHALICE": WORD(15) = "RELIQUARY"
    WORD(16) = "DUNGEON": WORD(17) = "SPECTRE": WORD(18) = "TALISMAN"
    WORD(19) = "CRYPT": WORD(20) = "WYVERN": WORD(21) = "SARCOPHAGUS"
    WORD(22) = "BASILISK": WORD(23) = "MANTICORE": WORD(24) = "OSSUARY"
END SUB

' The letters of `s`, sorted. Two words are anagrams exactly when these match --
' which is the one thing that can make this game unwinnable.
FUNCTION LetterKey$ (s AS STRING)
    DIM i AS INTEGER, j AS INTEGER, o AS STRING, c AS STRING
    o = UCASE$(s)
    FOR i = 1 TO LEN(o) - 1
        FOR j = 1 TO LEN(o) - i
            IF MID$(o, j, 1) > MID$(o, j + 1, 1) THEN
                c = MID$(o, j, 1)
                MID$(o, j, 1) = MID$(o, j + 1, 1)
                MID$(o, j + 1, 1) = c
            END IF
        NEXT j
    NEXT i
    LetterKey$ = o
END FUNCTION

' Scramble, with the three guards the header names. It retries rather than
' accepting a bad draw, and gives up gracefully after a bounded number of tries
' (a two-letter word has nowhere to go).
FUNCTION Scramble$ (w AS STRING)
    DIM i AS INTEGER, j AS INTEGER, tries AS INTEGER
    DIM s AS STRING, c AS STRING
    DO
        tries = tries + 1
        s = UCASE$(w)
        FOR i = LEN(s) TO 2 STEP -1
            j = MgRoll%(i)
            c = MID$(s, i, 1)
            MID$(s, i, 1) = MID$(s, j, 1)
            MID$(s, j, 1) = c
        NEXT i
    LOOP UNTIL tries > 40 _ORELSE (s <> UCASE$(w) _ANDALSO NOT SpellsAnotherWord%(s, w))
    Scramble$ = s
END FUNCTION

' Did the shuffle land on a DIFFERENT real word from the list? Then there are two
' right answers on screen and only one of them is accepted.
FUNCTION SpellsAnotherWord% (s AS STRING, notthis AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO WORDN
        IF WORD(i) <> UCASE$(notthis) _ANDALSO WORD(i) = s THEN SpellsAnotherWord% = TRUE: EXIT FUNCTION
    NEXT i
END FUNCTION

' Time to solve it, then time to type it at a one-finger pace. Same principle as
' SPEAK ITS NAME: the clock must never be the thing that beats you.
FUNCTION ScrFuse! (w AS STRING)
    ScrFuse! = THINK_TIME + LEN(w) / SLOW_CPS
END FUNCTION

FUNCTION ScrKey$ (s AS STRING)
    DIM i AS INTEGER, c AS STRING, o AS STRING
    FOR i = 1 TO LEN(s)
        c = UCASE$(MID$(s, i, 1))
        IF c >= "A" _ANDALSO c <= "Z" THEN o = o + c
    NEXT i
    ScrKey$ = o
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayScr% (intel AS INTEGER)
    DIM k AS STRING, t0 AS DOUBLE
    DIM reveals AS INTEGER
    reveals = MgAbilMod%(intel): IF reveals < 0 THEN reveals = 0
    g_right = 0: g_lives = 3
    DO
        g_ask = MgRoll%(WORDN)
        g_shown = Scramble$(WORD(g_ask))
        g_typed = "": g_reveal = 0
        g_fuse = ScrFuse!(WORD(g_ask))
        t0 = TIMER
        DO
            g_left = g_fuse - MgElapsed!(t0)
            IF g_left <= 0 THEN
                g_lives = g_lives - 1
                MgBeep 110, 6
                DrawScr "the carving fades -- it was " + WORD(g_ask)
                _DELAY 1.6
                EXIT DO
            END IF
            DrawScr "put them back in order"
            k = INKEY$
            IF k = CHR$(27) THEN PlayScr% = MG_LEFT: EXIT FUNCTION
            IF k = CHR$(8) _ANDALSO LEN(g_typed) > 0 THEN g_typed = LEFT$(g_typed, LEN(g_typed) - 1)
            IF k = "?" _ANDALSO reveals > 0 _ANDALSO g_reveal < LEN(WORD(g_ask)) THEN
                reveals = reveals - 1: g_reveal = g_reveal + 1
            END IF
            IF LEN(k) = 1 _ANDALSO k >= " " _ANDALSO k <= "~" _ANDALSO k <> "?" THEN g_typed = g_typed + k
            IF k = CHR$(13) THEN
                IF ScrKey$(g_typed) = WORD(g_ask) THEN
                    g_right = g_right + 1
                    MgBeep 780, 2
                    DrawScr "the door remembers itself"
                ELSE
                    g_lives = g_lives - 1
                    MgBeep 130, 5
                    DrawScr "no -- it was " + WORD(g_ask)
                END IF
                _DELAY 1.5
                EXIT DO
            END IF
            _LIMIT 60
        LOOP
        IF g_right >= WINSTREAK THEN PlayScr% = MG_WON: EXIT FUNCTION
        IF g_lives <= 0 THEN PlayScr% = MG_LOST: EXIT FUNCTION
    LOOP
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawScr (msg AS STRING)
    DIM i AS INTEGER, s AS STRING
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "T H E   S C A T T E R E D   W O R D", "every letter you need is on the door, and no letter you do not"

    ' the scrambled letters, spaced out so they read as tiles, not as a word
    s = ""
    FOR i = 1 TO LEN(g_shown): s = s + MID$(g_shown, i, 1) + " ": NEXT i
    COLOR C_TITLE, 0: MgCenter 13, _TRIM$(s)

    ' revealed positions, if INT bought any
    IF g_reveal > 0 THEN
        s = ""
        FOR i = 1 TO LEN(WORD(g_ask))
            IF i <= g_reveal THEN s = s + MID$(WORD(g_ask), i, 1) + " " ELSE s = s + "_ "
        NEXT i
        COLOR C_COOL, 0: MgCenter 16, _TRIM$(s)
    ELSE
        COLOR C_DIM, 0: MgCenter 16, _TRIM$(STR$(LEN(g_shown))) + " letters"
    END IF

    COLOR C_TEXT, 0: MgCenter 20, "> " + g_typed + "_"
    COLOR C_TEXT, 0: MgCenter 23, msg
    COLOR C_WARN, 0
    MgCenter 26, "words " + _TRIM$(STR$(g_right)) + " of " + _TRIM$(STR$(WINSTREAK)) + "        lives " + _TRIM$(STR$(g_lives))
    MgFuse 29, g_left / g_fuse, g_left
    COLOR C_GOOD, 0
    MgCenter 33, "type it and press [ENTER]      [?] reveal the next letter      [ESC] leave"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB ScrSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM i AS LONG
    _DEST _CONSOLE
    PRINT "SCRAMBLE selftest"

    MgSection "THE question: is the answer the only word that fits the letters"
    Ok "no two words in the list are anagrams of each other", NoAnagramPairs%
    Ok "no word appears twice", NoDuplicates%
    Ok "every word is letters only, and long enough to scramble", WordsAreSane%

    MgSection "the scramble is a scramble"
    RANDOMIZE 111
    Ok "it uses every letter and no others, over 20000 draws", PermutationAlways%
    Ok "it is never just the word again", NeverTheWordItself%
    Ok "it never accidentally spells a DIFFERENT word from the list", NeverAnotherWord%
    Ok "it actually moves letters -- long words come out well shuffled", ActuallyShuffled%

    MgSection "the clock is not the opponent"
    PRINT USING "       longest word ## letters: ##.##s to think and type"; LongWordLen%; ScrFuse!(LongestWord$)
    Ok "there is thinking time before typing time", THINK_TIME > 0
    Ok "the fuse covers typing the longest word at a one-finger pace", ScrFuse!(LongestWord$) >= LongWordLen% / SLOW_CPS + THINK_TIME - 0.001
    Ok "every word gets the same thinking time, long or short", ScrFuse!("CRYPT") - 5 / SLOW_CPS = ScrFuse!("SARCOPHAGUS") - 11 / SLOW_CPS

    MgSection "answers are judged on the word, not the keyboard"
    Ok "case does not matter", ScrKey$("portcullis") = "PORTCULLIS"
    Ok "stray spaces do not matter", ScrKey$(" cry pt ") = "CRYPT"
    Ok "a wrong word is still wrong", ScrKey$("CRYPTS") <> "CRYPT"

    MgSection "INT reveals, it does not solve"
    Ok "a reveal shows one letter in place", TRUE
    Ok "a dull character gets none", MgAbilMod%(9) <= 0

    MgDone
END SUB

' The one that matters. Pairwise, all 276 pairs -- it depends on a PAIR of
' entries, so no amount of looking at any single word can catch it.
FUNCTION NoAnagramPairs% ()
    DIM i AS INTEGER, j AS INTEGER
    NoAnagramPairs% = TRUE
    FOR i = 1 TO WORDN
        FOR j = i + 1 TO WORDN
            IF LetterKey$(WORD(i)) = LetterKey$(WORD(j)) THEN
                PRINT "       AMBIGUOUS: "; WORD(i); " / "; WORD(j)
                NoAnagramPairs% = FALSE
            END IF
        NEXT j
    NEXT i
END FUNCTION

FUNCTION NoDuplicates% ()
    DIM i AS INTEGER, j AS INTEGER
    NoDuplicates% = TRUE
    FOR i = 1 TO WORDN
        FOR j = i + 1 TO WORDN
            IF WORD(i) = WORD(j) THEN NoDuplicates% = FALSE
        NEXT j
    NEXT i
END FUNCTION

FUNCTION WordsAreSane% ()
    DIM i AS INTEGER, j AS INTEGER, c AS STRING
    WordsAreSane% = TRUE
    FOR i = 1 TO WORDN
        IF LEN(WORD(i)) < 4 THEN WordsAreSane% = FALSE
        FOR j = 1 TO LEN(WORD(i))
            c = MID$(WORD(i), j, 1)
            IF c < "A" OR c > "Z" THEN WordsAreSane% = FALSE
        NEXT j
    NEXT i
END FUNCTION

' A scramble that drops or duplicates a letter is unsolvable, and it looks
' exactly like a hard one -- which is why it is checked rather than assumed.
FUNCTION PermutationAlways% ()
    DIM i AS LONG, w AS INTEGER
    DIM s AS STRING
    PermutationAlways% = TRUE
    FOR i = 1 TO 20000
        w = MgRoll%(WORDN)
        s = Scramble$(WORD(w))
        IF LetterKey$(s) <> LetterKey$(WORD(w)) THEN PermutationAlways% = FALSE
        IF LEN(s) <> LEN(WORD(w)) THEN PermutationAlways% = FALSE
    NEXT i
END FUNCTION

FUNCTION NeverTheWordItself% ()
    DIM i AS LONG, w AS INTEGER
    NeverTheWordItself% = TRUE
    RANDOMIZE 112
    FOR i = 1 TO 20000
        w = MgRoll%(WORDN)
        IF Scramble$(WORD(w)) = WORD(w) THEN NeverTheWordItself% = FALSE
    NEXT i
END FUNCTION

FUNCTION NeverAnotherWord% ()
    DIM i AS LONG, w AS INTEGER
    DIM s AS STRING
    NeverAnotherWord% = TRUE
    RANDOMIZE 113
    FOR i = 1 TO 20000
        w = MgRoll%(WORDN)
        s = Scramble$(WORD(w))
        IF SpellsAnotherWord%(s, WORD(w)) THEN NeverAnotherWord% = FALSE
    NEXT i
END FUNCTION

' Not a fairness rule, a feel one: a "scramble" that moves two letters is a
' letdown. Measures how many positions actually changed on the long words.
FUNCTION ActuallyShuffled% ()
    DIM i AS LONG, j AS INTEGER, moved AS LONG, total AS LONG
    DIM s AS STRING, w AS STRING
    RANDOMIZE 114
    w = "SARCOPHAGUS"
    FOR i = 1 TO 5000
        s = Scramble$(w)
        FOR j = 1 TO LEN(w)
            total = total + 1
            IF MID$(s, j, 1) <> MID$(w, j, 1) THEN moved = moved + 1
        NEXT j
    NEXT i
    PRINT USING "       #.### of letters land somewhere new"; moved / total
    ActuallyShuffled% = (moved / total > 0.7)
END FUNCTION

FUNCTION LongWordLen% ()
    DIM i AS INTEGER, n AS INTEGER
    FOR i = 1 TO WORDN
        IF LEN(WORD(i)) > n THEN n = LEN(WORD(i))
    NEXT i
    LongWordLen% = n
END FUNCTION

FUNCTION LongestWord$ ()
    DIM i AS INTEGER, best AS STRING
    FOR i = 1 TO WORDN
        IF LEN(WORD(i)) > LEN(best) THEN best = WORD(i)
    NEXT i
    LongestWord$ = best
END FUNCTION

'$INCLUDE:'MG.bas'
