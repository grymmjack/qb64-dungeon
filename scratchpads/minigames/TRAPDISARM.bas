' ============================================================================
'  TRAPDISARM.bas -- FIVE WIRES AND A SET OF NOTES
'
'  Five wires run into the mechanism. There is exactly one order in which they
'  can be cut. Scratched into the plate beside them are notes left by whoever
'  built it -- "the copper is cut before the sinew", "the bone is not last" --
'  and those notes, together, name that order and no other.
'
'  This is a deduction game, so the ONLY thing that makes it fair is that the
'  clues are sufficient. A puzzle whose clues admit two orders is not hard, it
'  is broken: the player deduces correctly, cuts, and dies. So generation works
'  backwards -- pick the answer, write every true note about it, then throw notes
'  away one at a time for as long as the answer stays UNIQUE. Uniqueness is
'  checked by brute force over all 120 permutations, every time, which is cheap
'  enough that there is no excuse for guessing about it.
'
'  Two properties follow and both are asserted: every puzzle has exactly one
'  solution, and every note in it is load-bearing (drop any one and the answer
'  stops being unique). The second is what stops the plate filling with true but
'  useless notes, which is how a deduction puzzle turns into a reading exercise.
'
'  INT hands you EXTRA notes beyond the minimum -- true ones, about the same
'  unchanged order. It is a stat reading the puzzle, not softening it.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST WIRES = 5
CONST PERMS = 120
CONST MAXCLUE = 40

'--- note kinds ---
CONST CL_BEFORE = 1             ' a is cut before b
CONST CL_ADJ = 2                ' a is cut immediately before b
CONST CL_NOTAT = 3              ' a is not the p'th cut
CONST CL_AT = 4                 ' a IS the p'th cut

TYPE CLUE
    kind AS INTEGER
    a AS INTEGER
    b AS INTEGER
    p AS INTEGER
    live AS INTEGER             ' still on the plate
END TYPE

DIM SHARED WIRENAME(1 TO WIRES) AS STRING
DIM SHARED WIRECOL(1 TO WIRES) AS _UNSIGNED LONG
DIM SHARED ANSWER(1 TO WIRES) AS INTEGER      ' ANSWER(step) = wire id
DIM SHARED NOTE(1 TO MAXCLUE) AS CLUE
DIM SHARED PERM(1 TO PERMS, 1 TO WIRES) AS INTEGER
DIM SHARED AS INTEGER g_notes, g_step, g_strikes, g_cut(1 TO WIRES), g_permn

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitWires
BuildPerms
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: TrapSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 51
    TrapSetup 14
    g_cut(ANSWER(1)) = TRUE: g_step = 2
    DrawTrap 2, "one down -- the mechanism has not moved"
    _SAVEIMAGE "trapdisarm-shot.png"
    _DEST _CONSOLE: PRINT "wrote trapdisarm-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayTrap(14)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- setup -------------------------------------------------------------------

SUB InitWires
    WIRENAME(1) = "COPPER": WIRECOL(1) = _RGB32(&HD0, &H80, &H40)
    WIRENAME(2) = "SINEW": WIRECOL(2) = _RGB32(&HD8, &HC8, &HA0)
    WIRENAME(3) = "BONE": WIRECOL(3) = _RGB32(&HE8, &HE8, &HE0)
    WIRENAME(4) = "IRON": WIRECOL(4) = _RGB32(&H90, &H98, &HA8)
    WIRENAME(5) = "SILVER": WIRECOL(5) = _RGB32(&HB0, &HD8, &HF0)
END SUB

' All 120 orderings, once at startup. Uniqueness is then a scan, and a scan that
' costs nothing is a scan that gets run on every single generated puzzle.
SUB BuildPerms
    DIM AS INTEGER a, b, c, d, e, i
    g_permn = 0
    FOR a = 1 TO WIRES: FOR b = 1 TO WIRES: FOR c = 1 TO WIRES
    FOR d = 1 TO WIRES: FOR e = 1 TO WIRES
        IF a <> b THEN
            IF c <> a _ANDALSO c <> b THEN
                IF d <> a _ANDALSO d <> b _ANDALSO d <> c THEN
                    IF e <> a _ANDALSO e <> b _ANDALSO e <> c _ANDALSO e <> d THEN
                        g_permn = g_permn + 1
                        PERM(g_permn, 1) = a: PERM(g_permn, 2) = b: PERM(g_permn, 3) = c
                        PERM(g_permn, 4) = d: PERM(g_permn, 5) = e
                    END IF
                END IF
            END IF
        END IF
    NEXT e: NEXT d: NEXT c: NEXT b: NEXT a
END SUB

FUNCTION PosIn% (pi AS INTEGER, wire AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO WIRES
        IF PERM(pi, i) = wire THEN PosIn% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' Does permutation `pi` satisfy note `n`? One function, used by generation, by
' the uniqueness proof and by the minimality proof -- so there is no second copy
' of the rules to drift out of step with the first.
FUNCTION Holds% (n AS INTEGER, pi AS INTEGER)
    DIM pa AS INTEGER, pb AS INTEGER
    pa = PosIn%(pi, NOTE(n).a)
    pb = PosIn%(pi, NOTE(n).b)
    SELECT CASE NOTE(n).kind
        CASE CL_BEFORE: Holds% = (pa < pb)
        CASE CL_ADJ: Holds% = (pb = pa + 1)
        CASE CL_NOTAT: Holds% = (pa <> NOTE(n).p)
        CASE CL_AT: Holds% = (pa = NOTE(n).p)
        CASE ELSE: Holds% = TRUE
    END SELECT
END FUNCTION

' How many orderings satisfy every LIVE note. 1 = a fair puzzle.
FUNCTION SolutionCount% ()
    DIM pi AS INTEGER, n AS INTEGER, good AS INTEGER, cnt AS INTEGER
    FOR pi = 1 TO g_permn
        good = TRUE
        FOR n = 1 TO g_notes
            IF NOTE(n).live THEN
                IF NOT Holds%(n, pi) THEN good = FALSE: EXIT FOR
            END IF
        NEXT n
        IF good THEN cnt = cnt + 1
    NEXT pi
    SolutionCount% = cnt
END FUNCTION

' How many extra true notes INT leaves on the plate on top of the minimal set.
FUNCTION BonusNotes% (intel AS INTEGER)
    DIM n AS INTEGER
    n = MgAbilMod%(intel)
    IF n < 0 THEN n = 0
    IF n > 3 THEN n = 3
    BonusNotes% = n
END FUNCTION

' Generate a puzzle: pick the order, write every true note about it, shuffle the
' notes, then drop them one by one for as long as the answer stays unique. What
' survives is a minimal set -- every note left is one the player needs.
SUB TrapSetup (intel AS INTEGER)
    DIM AS INTEGER i, j, t, n, bonus, dropped
    DIM ap AS INTEGER

    ' the answer
    FOR i = 1 TO WIRES: ANSWER(i) = i: NEXT i
    FOR i = WIRES TO 2 STEP -1
        j = MgRoll%(i): t = ANSWER(i): ANSWER(i) = ANSWER(j): ANSWER(j) = t
    NEXT i
    ap = AnswerPerm%

    ' every true note about it
    g_notes = 0
    FOR i = 1 TO WIRES
        FOR j = 1 TO WIRES
            IF i <> j THEN
                IF PosIn%(ap, i) < PosIn%(ap, j) THEN AddNote CL_BEFORE, i, j, 0
                IF PosIn%(ap, j) = PosIn%(ap, i) + 1 THEN AddNote CL_ADJ, i, j, 0
            END IF
        NEXT j
        FOR j = 1 TO WIRES
            IF PosIn%(ap, i) <> j THEN AddNote CL_NOTAT, i, i, j
        NEXT j
        AddNote CL_AT, i, i, PosIn%(ap, i)
    NEXT i

    ' shuffle, so the surviving set is not always the same shape
    FOR i = g_notes TO 2 STEP -1
        j = MgRoll%(i)
        SwapNotes i, j
    NEXT i

    ' thin it to a minimal set
    bonus = BonusNotes%(intel)
    FOR n = 1 TO g_notes
        NOTE(n).live = FALSE
        IF SolutionCount% <> 1 THEN NOTE(n).live = TRUE
    NEXT n

    ' ...then hand INT back that many notes. They are TRUE notes about the same
    ' unchanged order -- the puzzle is not easier, the reading is.
    FOR n = 1 TO g_notes
        IF bonus <= 0 THEN EXIT FOR
        IF NOT NOTE(n).live THEN
            NOTE(n).live = TRUE: bonus = bonus - 1
        END IF
    NEXT n

    Compact
    g_step = 1: g_strikes = 0
    FOR i = 1 TO WIRES: g_cut(i) = FALSE: NEXT i
END SUB

SUB AddNote (kind AS INTEGER, a AS INTEGER, b AS INTEGER, p AS INTEGER)
    IF g_notes >= MAXCLUE THEN EXIT SUB
    g_notes = g_notes + 1
    NOTE(g_notes).kind = kind: NOTE(g_notes).a = a
    NOTE(g_notes).b = b: NOTE(g_notes).p = p: NOTE(g_notes).live = TRUE
END SUB

SUB SwapNotes (i AS INTEGER, j AS INTEGER)
    DIM t AS CLUE
    t = NOTE(i): NOTE(i) = NOTE(j): NOTE(j) = t
END SUB

' Drop the dead notes so the plate is just the notes in play.
SUB Compact
    DIM i AS INTEGER, n AS INTEGER
    n = 0
    FOR i = 1 TO g_notes
        IF NOTE(i).live THEN
            n = n + 1: NOTE(n) = NOTE(i)
        END IF
    NEXT i
    g_notes = n
END SUB

FUNCTION AnswerPerm% ()
    DIM pi AS INTEGER, i AS INTEGER, good AS INTEGER
    FOR pi = 1 TO g_permn
        good = TRUE
        FOR i = 1 TO WIRES
            IF PERM(pi, i) <> ANSWER(i) THEN good = FALSE: EXIT FOR
        NEXT i
        IF good THEN AnswerPerm% = pi: EXIT FUNCTION
    NEXT pi
END FUNCTION

FUNCTION NoteText$ (n AS INTEGER)
    DIM s AS STRING
    SELECT CASE NOTE(n).kind
        CASE CL_BEFORE: s = WIRENAME(NOTE(n).a) + " is cut before " + WIRENAME(NOTE(n).b)
        CASE CL_ADJ: s = WIRENAME(NOTE(n).b) + " is cut straight after " + WIRENAME(NOTE(n).a)
        CASE CL_NOTAT: s = WIRENAME(NOTE(n).a) + " is NOT cut " + Nth$(NOTE(n).p)
        CASE CL_AT: s = WIRENAME(NOTE(n).a) + " is cut " + Nth$(NOTE(n).p)
    END SELECT
    NoteText$ = s
END FUNCTION

FUNCTION Nth$ (p AS INTEGER)
    SELECT CASE p
        CASE 1: Nth$ = "first"
        CASE 2: Nth$ = "second"
        CASE 3: Nth$ = "third"
        CASE 4: Nth$ = "fourth"
        CASE ELSE: Nth$ = "last"
    END SELECT
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayTrap% (intel AS INTEGER)
    DIM sel AS INTEGER, k AS STRING, u AS STRING, msg AS STRING
    TrapSetup intel
    sel = 1
    msg = "read the plate, then cut"
    DO
        DrawTrap sel, msg
        k = INKEY$: u = UCASE$(k)
        IF k = CHR$(27) THEN PlayTrap% = MG_LEFT: EXIT FUNCTION
        IF u = "W" OR k = CHR$(0) + "H" THEN sel = WrapSel%(sel - 1)
        IF u = "S" OR k = CHR$(0) + "P" THEN sel = WrapSel%(sel + 1)
        IF k = " " OR k = CHR$(13) THEN
            IF NOT g_cut(sel) THEN
                IF sel = ANSWER(g_step) THEN
                    g_cut(sel) = TRUE: g_step = g_step + 1
                    MgBeep 700, 2
                    IF g_step > WIRES THEN PlayTrap% = MG_WON: EXIT FUNCTION
                    msg = "the wire parts cleanly"
                ELSE
                    g_strikes = g_strikes + 1
                    MgBeep 110, 6
                    IF g_strikes >= 2 THEN
                        DrawTrap sel, "the mechanism releases"
                        _DELAY 1.4
                        PlayTrap% = MG_LOST: EXIT FUNCTION
                    END IF
                    msg = "something inside SNAPS -- one more and it goes off"
                END IF
            END IF
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

FUNCTION WrapSel% (s AS INTEGER)
    DIM n AS INTEGER
    n = s
    IF n < 1 THEN n = WIRES
    IF n > WIRES THEN n = 1
    WrapSel% = n
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawTrap (sel AS INTEGER, msg AS STRING)
    DIM i AS INTEGER, y AS INTEGER
    DIM od AS LONG
    od = _DEST: _DEST 0

    MgHeader "F I V E   W I R E S   A N D   A   S E T   O F   N O T E S", "the notes name one order and only one -- work it out before you cut"

    FOR i = 1 TO WIRES
        y = 9 + (i - 1) * 2
        IF g_cut(i) THEN
            COLOR C_DIM, 0
            MgText 14, y, "  " + LEFT$(WIRENAME(i) + "        ", 8) + " --  x  -- cut"
        ELSE
            COLOR WIRECOL(i), 0
            MgText 14, y, "  " + LEFT$(WIRENAME(i) + "        ", 8) + " ==========="
        END IF
        IF i = sel THEN
            COLOR C_COOL, 0: MgText 11, y, ">>"
        END IF
    NEXT i

    COLOR C_TITLE, 0
    MgText 48, 7, "scratched into the plate:"
    FOR i = 1 TO g_notes
        COLOR C_TEXT, 0
        MgText 48, 9 + (i - 1), "- " + NoteText$(i)
    NEXT i

    COLOR C_WARN, 0
    MgCenter 24, "cut " + _TRIM$(STR$(g_step - 1)) + " of " + _TRIM$(STR$(WIRES)) + "        strikes " + _TRIM$(STR$(g_strikes)) + " of 2"
    COLOR C_TEXT, 0: MgCenter 26, msg
    COLOR C_DIM, 0: MgCenter 28, "there is no timer -- the trap waits as long as you do"
    COLOR C_GOOD, 0: MgCenter 31, "[W]/[S] or [arrows] choose a wire   [SPACE] cut   [ESC] back away"
    _DISPLAY
    _DEST od
END SUB

'--- selftest ----------------------------------------------------------------

SUB TrapSelfTest
    DIM i AS LONG, gens AS LONG
    DIM AS INTEGER minn, maxn, bad
    _DEST _CONSOLE
    PRINT "TRAPDISARM selftest"
    gens = 1500

    MgSection "the permutation table is the whole space"
    Ok "all 120 orderings, no duplicates", g_permn = PERMS _ANDALSO PermsDistinct%
    Ok "every wire appears once in every ordering", PermsAreOrderings%

    MgSection "EVERY puzzle has exactly one answer -- the only thing that makes it fair"
    RANDOMIZE 61
    bad = 0
    FOR i = 1 TO gens
        TrapSetup 10
        IF SolutionCount% <> 1 THEN bad = bad + 1
    NEXT i
    PRINT USING "       ####  puzzles generated, #### with more or fewer than one answer"; gens; bad
    Ok "no puzzle is ambiguous, over 1500 generations", bad = 0
    Ok "and the one answer is the order that was dealt", AnswerIsTheSolution%

    MgSection "every note is load-bearing"
    RANDOMIZE 62
    bad = 0
    FOR i = 1 TO 400
        TrapSetup 10
        IF NOT EveryNoteMatters% THEN bad = bad + 1
    NEXT i
    Ok "dropping ANY single note makes the answer ambiguous", bad = 0

    MgSection "the plate is readable"
    RANDOMIZE 63
    minn = 99: maxn = 0
    FOR i = 1 TO gens
        TrapSetup 10
        IF g_notes < minn THEN minn = g_notes
        IF g_notes > maxn THEN maxn = g_notes
    NEXT i
    PRINT USING "       notes on the plate: ## to ##"; minn; maxn
    Ok "never so few that it is guesswork", minn >= 3
    Ok "never so many that it does not fit the plate", maxn <= 12

    MgSection "INT reads the plate, it does not move the wires"
    Ok "a dull character gets the bare minimum", BonusNotes%(8) = 0
    Ok "a clever one gets extra notes", BonusNotes%(18) > 0
    Ok "extra notes are capped", BonusNotes%(30) <= 3
    Ok "more INT never means FEWER notes", NotesRiseWithInt%
    Ok "every extra note is TRUE of the same unchanged order", BonusNotesAreTrue%
    Ok "...so the answer is still unique with them on", StillUniqueWithBonus%

    MgDone
END SUB

FUNCTION PermsDistinct% ()
    DIM a AS INTEGER, b AS INTEGER, i AS INTEGER, same AS INTEGER
    PermsDistinct% = TRUE
    FOR a = 1 TO g_permn
        FOR b = a + 1 TO g_permn
            same = TRUE
            FOR i = 1 TO WIRES
                IF PERM(a, i) <> PERM(b, i) THEN same = FALSE: EXIT FOR
            NEXT i
            IF same THEN PermsDistinct% = FALSE
        NEXT b
    NEXT a
END FUNCTION

FUNCTION PermsAreOrderings% ()
    DIM pi AS INTEGER, i AS INTEGER, w AS INTEGER, n AS INTEGER
    PermsAreOrderings% = TRUE
    FOR pi = 1 TO g_permn
        FOR w = 1 TO WIRES
            n = 0
            FOR i = 1 TO WIRES
                IF PERM(pi, i) = w THEN n = n + 1
            NEXT i
            IF n <> 1 THEN PermsAreOrderings% = FALSE
        NEXT w
    NEXT pi
END FUNCTION

' Unique is not enough on its own -- it has to be unique AND be the order the
' player is actually graded against, or they deduce a consistent answer and die.
FUNCTION AnswerIsTheSolution% ()
    DIM i AS LONG, pi AS INTEGER, n AS INTEGER, good AS INTEGER
    AnswerIsTheSolution% = TRUE
    RANDOMIZE 64
    FOR i = 1 TO 300
        TrapSetup 10
        FOR pi = 1 TO g_permn
            good = TRUE
            FOR n = 1 TO g_notes
                IF NOT Holds%(n, pi) THEN good = FALSE: EXIT FOR
            NEXT n
            IF good _ANDALSO pi <> AnswerPerm% THEN AnswerIsTheSolution% = FALSE
        NEXT pi
    NEXT i
END FUNCTION

' Minimality, checked the only way that means anything: switch each note off in
' turn and confirm the answer stops being unique.
FUNCTION EveryNoteMatters% ()
    DIM n AS INTEGER
    EveryNoteMatters% = TRUE
    FOR n = 1 TO g_notes
        NOTE(n).live = FALSE
        IF SolutionCount% = 1 THEN EveryNoteMatters% = FALSE
        NOTE(n).live = TRUE
    NEXT n
END FUNCTION

FUNCTION NotesRiseWithInt% ()
    DIM i AS LONG, lo AS LONG, hi AS LONG
    RANDOMIZE 65
    FOR i = 1 TO 300: TrapSetup 8: lo = lo + g_notes: NEXT i
    FOR i = 1 TO 300: TrapSetup 18: hi = hi + g_notes: NEXT i
    NotesRiseWithInt% = (hi > lo)
END FUNCTION

FUNCTION BonusNotesAreTrue% ()
    DIM i AS LONG, n AS INTEGER
    BonusNotesAreTrue% = TRUE
    RANDOMIZE 66
    FOR i = 1 TO 300
        TrapSetup 18
        FOR n = 1 TO g_notes
            IF NOT Holds%(n, AnswerPerm%) THEN BonusNotesAreTrue% = FALSE
        NEXT n
    NEXT i
END FUNCTION

FUNCTION StillUniqueWithBonus% ()
    DIM i AS LONG
    StillUniqueWithBonus% = TRUE
    RANDOMIZE 67
    FOR i = 1 TO 300
        TrapSetup 18
        IF SolutionCount% <> 1 THEN StillUniqueWithBonus% = FALSE
    NEXT i
END FUNCTION

'$INCLUDE:'MG.bas'
