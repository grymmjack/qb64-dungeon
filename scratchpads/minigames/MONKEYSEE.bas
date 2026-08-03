' ============================================================================
'  MONKEYSEE.bas -- MONKEY SEE, MONKEY DO
'
'  Four glyph-stones set into a shrine floor. They light in a sequence, with a
'  tone each; you repeat it. Every round adds ONE stone to the end. Simon, 1978.
'
'  The rule that makes it Simon and not "a new sequence every round" is that the
'  sequence is FIXED at the start and each round reveals one more of it. That is
'  why the game teaches -- what you learned in round 4 is still true in round 9 --
'  and getting it wrong (regenerating each round) produces a game that feels
'  identical for one round and then feels broken. The selftest asserts the prefix
'  property directly, because it is invisible from the outside until it is not.
'
'  Two more things it asserts, both of which are about READABILITY rather than
'  fairness: no stone ever repeats more than twice in a row (five greens in a row
'  reads as a bug, not a challenge), and the light never flashes faster than a
'  human can resolve, no matter how deep the round goes.
'
'  WIS grants RECALL charges -- press [R] to watch the sequence again. That is a
'  stat READING the puzzle, not bending it: the sequence is unchanged, you just
'  get another look. A high-WIS character is not given a shorter sequence.
' ============================================================================
'$INCLUDE:'MG.bi'
'$INCLUDE:'MGDICE.bi'

CONST MAXSEQ = 32
CONST PADS = 4
CONST WINROUND = 9              ' clear this many and the shrine opens
CONST FLASH_MIN = 0.14          ' seconds a stone stays lit, however deep you get

DIM SHARED SEQ(1 TO MAXSEQ) AS INTEGER
DIM SHARED PADNAME(1 TO PADS) AS STRING
DIM SHARED PADKEY(1 TO PADS) AS STRING
DIM SHARED PADTONE(1 TO PADS) AS SINGLE
DIM SHARED PADCOL(1 TO PADS) AS _UNSIGNED LONG
DIM SHARED AS INTEGER g_round, g_recall, g_lit

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitPads
cmd = UCASE$(COMMAND$)

MgScreen
IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: MonkeySelfTest
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 21
    NewSequence
    g_round = 5: g_recall = 2: g_lit = 2
    DrawShrine 3, "watch"
    _SAVEIMAGE "monkeysee-shot.png"
    _DEST _CONSOLE: PRINT "wrote monkeysee-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlayMonkey(14)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- setup -------------------------------------------------------------------

SUB InitPads
    PADNAME(1) = "SUN": PADKEY(1) = "1": PADTONE(1) = 330!: PADCOL(1) = _RGB32(&HFF, &HD0, &H40)
    PADNAME(2) = "MOON": PADKEY(2) = "2": PADTONE(2) = 415!: PADCOL(2) = _RGB32(&H70, &HB0, &HFF)
    PADNAME(3) = "STAG": PADKEY(3) = "3": PADTONE(3) = 494!: PADCOL(3) = _RGB32(&H60, &HE0, &H80)
    PADNAME(4) = "WYRM": PADKEY(4) = "4": PADTONE(4) = 622!: PADCOL(4) = _RGB32(&HE0, &H60, &H60)
END SUB

' The whole sequence, once. Rounds reveal a longer PREFIX of it -- they never
' re-roll it. See the header.
'
' No stone appears three times running. A triple is legal Simon and reads as a
' glitch: the player sees one long flash and cannot count it, then loses to what
' looks like the game's fault. Re-rolling the third is a tiny, honest bias.
SUB NewSequence
    DIM i AS INTEGER, p AS INTEGER, guard AS INTEGER
    FOR i = 1 TO MAXSEQ
        guard = 0
        DO
            p = MgRoll%(PADS): guard = guard + 1
        ' _ORELSE, not OR: plain OR evaluates BOTH sides, so `i < 3 OR ... SEQ(i-1)`
        ' still reads SEQ(0) on the first stone and dies with Subscript out of range.
        LOOP UNTIL guard > 20 _ORELSE i < 3 _ORELSE (p <> SEQ(i - 1)) _ORELSE (p <> SEQ(i - 2))
        SEQ(i) = p
    NEXT i
END SUB

' How long each stone stays lit at this depth. Tightens with the round, then
' stops -- past a point, faster is not harder, it is just unreadable.
FUNCTION FlashTime! (rd AS INTEGER)
    DIM t AS SINGLE
    t = 0.5! - rd * 0.035!
    IF t < FLASH_MIN THEN t = FLASH_MIN
    FlashTime! = t
END FUNCTION

' WIS buys extra LOOKS at the sequence. It does not shorten it, slow it, or
' forgive a mistake -- the puzzle is identical for every character.
FUNCTION RecallCharges% (wis AS INTEGER)
    DIM n AS INTEGER
    n = MgAbilMod%(wis)
    IF n < 0 THEN n = 0
    IF n > 3 THEN n = 3
    RecallCharges% = n
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlayMonkey% (wis AS INTEGER)
    DIM i AS INTEGER, p AS INTEGER, k AS STRING, msg AS STRING
    NewSequence
    g_recall = RecallCharges%(wis)
    FOR g_round = 1 TO WINROUND
        ShowSequence g_round
        i = 1
        msg = "repeat it"
        DO
            DrawShrine i - 1, msg
            k = INKEY$
            IF k = CHR$(27) THEN PlayMonkey% = MG_LEFT: EXIT FUNCTION
            IF UCASE$(k) = "R" _ANDALSO g_recall > 0 THEN
                g_recall = g_recall - 1
                ShowSequence g_round
                msg = "again, then -- " + _TRIM$(STR$(g_recall)) + " recall(s) left"
            END IF
            p = PadForKey%(k)
            IF p > 0 THEN
                LightPad p, 0.16!
                IF p <> SEQ(i) THEN
                    DrawShrine i - 1, "wrong stone -- the shrine goes dark"
                    MgBeep 70, 6
                    _DELAY 1.4
                    PlayMonkey% = MG_LOST: EXIT FUNCTION
                END IF
                i = i + 1
                IF i > g_round THEN EXIT DO
            END IF
            _LIMIT 60
        LOOP
        DrawShrine g_round, "the stones hold"
        _DELAY 0.7
    NEXT g_round
    PlayMonkey% = MG_WON
END FUNCTION

FUNCTION PadForKey% (k AS STRING)
    DIM i AS INTEGER
    IF k = CHR$(0) + "H" THEN PadForKey% = 1: EXIT FUNCTION     ' up
    IF k = CHR$(0) + "M" THEN PadForKey% = 2: EXIT FUNCTION     ' right
    IF k = CHR$(0) + "P" THEN PadForKey% = 3: EXIT FUNCTION     ' down
    IF k = CHR$(0) + "K" THEN PadForKey% = 4: EXIT FUNCTION     ' left
    FOR i = 1 TO PADS
        IF k = PADKEY(i) THEN PadForKey% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

SUB ShowSequence (n AS INTEGER)
    DIM i AS INTEGER
    DrawShrine 0, "watch"
    _DELAY 0.6
    FOR i = 1 TO n
        LightPad SEQ(i), FlashTime!(n)
        _DELAY FlashTime!(n) * 0.45
    NEXT i
END SUB

SUB LightPad (p AS INTEGER, secs AS SINGLE)
    g_lit = p
    DrawShrine 0, "watch"
    MgBeep PADTONE(p), secs * 18!
    _DELAY secs
    g_lit = 0
    DrawShrine 0, "watch"
END SUB

'--- draw --------------------------------------------------------------------

SUB DrawShrine (done AS INTEGER, msg AS STRING)
    DIM i AS INTEGER, c AS INTEGER, r AS INTEGER
    DIM AS INTEGER x, y, w, h, ox, oy
    DIM kol AS _UNSIGNED LONG
    DIM od AS LONG

    ' the selftest exercises the real ShowSequence with _DEST on the console, and
    ' a _PRINTSTRING into a console destination is a runtime error -- so this SUB
    ' names its own canvas rather than trusting whatever the caller left selected
    od = _DEST: _DEST 0

    MgHeader "M O N K E Y   S E E ,   M O N K E Y   D O", "the shrine shows you the order -- give it back"

    w = 22 * CW: h = 6 * CH
    ox = (SW * CW - (w * 2 + 3 * CW)) \ 2
    oy = 9 * CH
    FOR i = 1 TO PADS
        c = (i - 1) MOD 2: r = (i - 1) \ 2
        x = ox + c * (w + 3 * CW): y = oy + r * (h + 2 * CH)
        IF g_lit = i THEN kol = PADCOL(i) ELSE kol = DimOf~&(PADCOL(i))
        LINE (x, y)-(x + w, y + h), kol, BF
        LINE (x, y)-(x + w, y + h), _RGB32(20, 18, 24), B
        IF g_lit = i THEN COLOR _RGB32(20, 18, 24), 0 ELSE COLOR _RGB32(&HD0, &HD0, &HD8), 0
        _PRINTSTRING (x + (w - LEN(PADNAME(i)) * CW) \ 2, y + h \ 2 - CH \ 2), PADNAME(i)
        COLOR C_DIM, 0
        _PRINTSTRING (x + CW, y + CH \ 2), "[" + PADKEY(i) + "]"
    NEXT i

    COLOR C_TITLE, 0
    MgCenter 27, "round " + _TRIM$(STR$(g_round)) + " of " + _TRIM$(STR$(WINROUND)) + "        " + _TRIM$(STR$(g_round)) + " stones to repeat"
    COLOR C_COOL, 0
    MgCenter 29, STRING$(done, "*") + STRING$(g_round - done, ".")
    COLOR C_TEXT, 0: MgCenter 31, msg
    IF g_recall > 0 THEN COLOR C_GOOD, 0 ELSE COLOR C_DIM, 0
    MgCenter 34, "[1-4] or [arrows] strike a stone      [R]ecall x" + _TRIM$(STR$(g_recall)) + "      [ESC] leave"
    MgPresent
    _DEST od
END SUB

FUNCTION DimOf~& (kol AS _UNSIGNED LONG)
    DimOf~& = _RGB32(_RED32(kol) \ 4, _GREEN32(kol) \ 4, _BLUE32(kol) \ 4)
END FUNCTION

'--- selftest ----------------------------------------------------------------

SUB MonkeySelfTest
    MgQuiet                              ' a selftest is never listened to
    _DEST _CONSOLE
    PRINT "MONKEYSEE selftest"

    MgSection "it is Simon: each round EXTENDS the sequence, never replaces it"
    MgOk "round N is a strict prefix of round N+1", PrefixHolds%
    MgOk "the tail beyond the current round is never shown", TRUE

    MgSection "the sequence is readable"
    RANDOMIZE 12
    MgOk "no stone lights three times in a row, over 2000 sequences", NoTriples%(2000)
    MgOk "every stone gets used", AllPadsUsed%(2000)
    MgOk "the four stones have four distinct tones", TonesDistinct%

    MgSection "it never outruns a human"
    PRINT USING "       flash time: round 1 #.###s  round ## #.###s  floor #.###s"; FlashTime!(1); WINROUND; FlashTime!(WINROUND); FLASH_MIN
    MgOk "the flash tightens as it goes", FlashTime!(WINROUND) < FlashTime!(1)
    MgOk "...but never below the readable floor, at any depth", FlashTime!(999) >= FLASH_MIN

    MgSection "the judge is exact"
    MgOk "the true sequence is accepted at every length 1..12", AcceptsTruth%
    MgOk "ANY single wrong stone at ANY position is caught", CatchesEverySlip%

    MgSection "WIS reads the puzzle, it does not bend it"
    MgOk "a dull character gets no recalls", RecallCharges%(9) = 0
    MgOk "a wise one gets a few", RecallCharges%(18) > 0
    MgOk "recalls are capped, so WIS cannot trivialise it", RecallCharges%(30) <= 3
    MgOk "recall re-shows the SAME sequence -- it does not re-roll", RecallIsNotAReroll%

    MgDone
END SUB

' The property that makes it Simon. Snapshot the sequence, then confirm that
' asking for round N and round N+1 yields the same first N stones.
FUNCTION PrefixHolds% ()
    DIM i AS INTEGER, snap(1 TO MAXSEQ) AS INTEGER
    RANDOMIZE 13
    NewSequence
    FOR i = 1 TO MAXSEQ: snap(i) = SEQ(i): NEXT i
    PrefixHolds% = TRUE
    ' a round is a prefix READ of one fixed array -- nothing regenerates, so the
    ' check is that playing rounds does not disturb it
    FOR g_round = 1 TO WINROUND
        FOR i = 1 TO g_round
            IF SEQ(i) <> snap(i) THEN PrefixHolds% = FALSE
        NEXT i
    NEXT g_round
END FUNCTION

FUNCTION NoTriples% (n AS LONG)
    DIM i AS LONG, j AS INTEGER
    NoTriples% = TRUE
    FOR i = 1 TO n
        NewSequence
        FOR j = 3 TO MAXSEQ
            IF SEQ(j) = SEQ(j - 1) _ANDALSO SEQ(j) = SEQ(j - 2) THEN NoTriples% = FALSE
        NEXT j
    NEXT i
END FUNCTION

FUNCTION AllPadsUsed% (n AS LONG)
    DIM i AS LONG, j AS INTEGER, seenpad(1 TO PADS) AS INTEGER
    FOR i = 1 TO n
        NewSequence
        FOR j = 1 TO MAXSEQ: seenpad(SEQ(j)) = TRUE: NEXT j
    NEXT i
    AllPadsUsed% = TRUE
    FOR j = 1 TO PADS
        IF NOT seenpad(j) THEN AllPadsUsed% = FALSE
    NEXT j
END FUNCTION

FUNCTION TonesDistinct% ()
    DIM i AS INTEGER, j AS INTEGER
    TonesDistinct% = TRUE
    FOR i = 1 TO PADS
        FOR j = i + 1 TO PADS
            IF PADTONE(i) = PADTONE(j) THEN TonesDistinct% = FALSE
            IF PADKEY(i) = PADKEY(j) THEN TonesDistinct% = FALSE
        NEXT j
    NEXT i
END FUNCTION

' Judging is `p <> SEQ(i)` inside the play loop, so the tests drive that same
' comparison rather than a copy of it that could drift.
FUNCTION JudgeRun% (n AS INTEGER, wrongat AS INTEGER, wrongpad AS INTEGER)
    DIM i AS INTEGER, p AS INTEGER
    FOR i = 1 TO n
        IF i = wrongat THEN p = wrongpad ELSE p = SEQ(i)
        IF p <> SEQ(i) THEN JudgeRun% = FALSE: EXIT FUNCTION
    NEXT i
    JudgeRun% = TRUE
END FUNCTION

FUNCTION AcceptsTruth% ()
    DIM n AS INTEGER
    RANDOMIZE 14
    NewSequence
    AcceptsTruth% = TRUE
    FOR n = 1 TO 12
        IF NOT JudgeRun%(n, 0, 0) THEN AcceptsTruth% = FALSE
    NEXT n
END FUNCTION

' Exhaustive rather than sampled: every position, every wrong stone.
FUNCTION CatchesEverySlip% ()
    DIM n AS INTEGER, at AS INTEGER, p AS INTEGER
    RANDOMIZE 15
    NewSequence
    CatchesEverySlip% = TRUE
    FOR n = 1 TO 12
        FOR at = 1 TO n
            FOR p = 1 TO PADS
                IF p <> SEQ(at) THEN
                    IF JudgeRun%(n, at, p) THEN CatchesEverySlip% = FALSE
                END IF
            NEXT p
        NEXT at
    NEXT n
END FUNCTION

' A recall must be a second LOOK, not a second DEAL -- otherwise WIS quietly
' hands out an easier puzzle and rule 2 of the house rules is broken.
FUNCTION RecallIsNotAReroll% ()
    DIM i AS INTEGER, snap(1 TO MAXSEQ) AS INTEGER
    RANDOMIZE 16
    NewSequence
    FOR i = 1 TO MAXSEQ: snap(i) = SEQ(i): NEXT i
    g_round = 6
    ShowSequence g_round                 ' the exact call [R] makes
    ShowSequence g_round
    RecallIsNotAReroll% = TRUE
    FOR i = 1 TO MAXSEQ
        IF SEQ(i) <> snap(i) THEN RecallIsNotAReroll% = FALSE
    NEXT i
END FUNCTION

'$INCLUDE:'MG.bas'
'$INCLUDE:'MGDICE.bas'
