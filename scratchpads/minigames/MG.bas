' ============================================================================
'  MG.bas -- shared bodies for the mini-game prototypes. See MG.bi.
' ============================================================================

' Set up the screen and the palette. Every prototype calls this first.
SUB MgInit
    SW = 132: SH = 51: CW = 8: CH = 16
    C_BG = _RGB32(10, 8, 12)
    C_TITLE = _RGB32(&HFF, &HE0, &H50)
    C_TEXT = _RGB32(&HEC, &HE8, &HDC)
    C_DIM = _RGB32(&H8A, &H8A, &H92)
    C_GOOD = _RGB32(&H55, &HFF, &H55)
    C_WARN = _RGB32(&HFF, &HC0, &H40)
    C_BAD = _RGB32(&HE0, &H33, &H33)
    C_COOL = _RGB32(&H55, &HFF, &HFF)
END SUB

SUB MgScreen
    SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)
END SUB

' Centred text on a character row.
'
' THE PARENTHESES ARE LOAD-BEARING: `*` binds tighter than `\` in BASIC, so
'     (SW - LEN(s)) \ 2 * CW    is    (SW - LEN(s)) \ (2 * CW)
' which for a 31-char line on a 132-column screen is 6 pixels, not 404. Every
' line renders hard against the left edge and still looks like plausible output,
' which is why it survived a full passing selftest the first time it happened.
SUB MgCenter (row AS INTEGER, s AS STRING)
    _PRINTSTRING (((SW - LEN(s)) \ 2) * CW, row * CH), s
END SUB

' Left-aligned text at a character cell.
SUB MgText (col AS INTEGER, row AS INTEGER, s AS STRING)
    _PRINTSTRING (col * CW, row * CH), s
END SUB

' The standard header every prototype wears.
SUB MgHeader (title AS STRING, sub1 AS STRING)
    CLS , C_BG
    COLOR C_TITLE, 0: MgCenter 3, "-=  " + title + "  =-"
    COLOR C_DIM, 0: MgCenter 5, sub1
END SUB

' The draining fuse bar -- the same widget language as the game's luck prompt and
' composure gauge, so all of these read as one family rather than N gadgets.
' `frac` 1..0. Shows the seconds too: a bar says you are running out, a number
' says whether the slow option is still affordable.
SUB MgFuse (row AS INTEGER, frac AS SINGLE, secs AS SINGLE)
    DIM fx AS INTEGER, fw AS INTEGER, f AS SINGLE, kol AS _UNSIGNED LONG
    f = frac: IF f < 0 THEN f = 0
    IF f > 1 THEN f = 1
    fx = 26 * CW: fw = 80 * CW
    LINE (fx, row * CH)-(fx + fw, row * CH + CH - 4), _RGB32(40, 40, 46), BF
    IF f > 0.35 THEN kol = _RGB32(170, 150, 70) ELSE kol = _RGB32(220, 60, 50)
    LINE (fx, row * CH)-(fx + INT(fw * f), row * CH + CH - 4), kol, BF
    IF secs > 0 THEN
        IF secs <= 3 THEN COLOR C_BAD, 0 ELSE COLOR C_WARN, 0
        MgCenter row - 1, _TRIM$(STR$(INT(secs * 10) / 10)) + "s"
    END IF
END SUB

' Word-wrap `s` into centred lines of at most `w` characters, from `row` down.
SUB MgWrap (s AS STRING, row AS INTEGER, w AS INTEGER)
    DIM rest AS STRING, ln AS STRING, sp AS INTEGER, y AS INTEGER
    rest = _TRIM$(s): y = row
    DO WHILE LEN(rest) > 0
        IF LEN(rest) <= w THEN MgCenter y, rest: EXIT DO
        sp = w
        DO WHILE sp > 1 AND MID$(rest, sp, 1) <> " ": sp = sp - 1: LOOP
        IF sp <= 1 THEN sp = w
        ln = LEFT$(rest, sp - 1)
        MgCenter y, ln
        rest = _TRIM$(MID$(rest, sp + 1))
        y = y + 1
    LOOP
END SUB

'--- dice + stats ------------------------------------------------------------

FUNCTION MgRoll% (sides AS INTEGER)
    DIM n AS INTEGER
    n = sides: IF n < 1 THEN n = 1
    MgRoll% = INT(RND * n) + 1
END FUNCTION

FUNCTION MgAbilMod% (score AS INTEGER)
    MgAbilMod% = INT((score - 10) / 2)
END FUNCTION

' Seconds elapsed since `t0`, safe across midnight (TIMER wraps at 86400).
'
' A SMALL negative is not midnight. It is clock jitter, or -- the case that found
' this -- a caller that pushed `t0` forward to discount a scripted pause and
' overshot by a hundredth of a second because _DELAY does not sleep to the
' microsecond. Treating that as a rollover reported 86399.98 seconds elapsed and
' instantly emptied a fuse. Only a swing of more than half a day is a real wrap.
FUNCTION MgElapsed! (t0 AS DOUBLE)
    DIM e AS SINGLE
    e = TIMER - t0
    IF e < -43200! THEN e = e + 86400!
    IF e < 0! THEN e = 0!
    MgElapsed! = e
END FUNCTION

'--- sound -------------------------------------------------------------------

' Every tone in a prototype goes through here. The PC speaker ignores every mute
' flag the game has, so the ONLY thing standing between a headless selftest and
' an unwanted chirp is this one gate -- which is why no prototype calls SOUND.
SUB MgBeep (freq AS SINGLE, dur AS SINGLE)
    IF MG_QUIET THEN EXIT SUB
    SOUND freq, dur
END SUB

'--- selftest ----------------------------------------------------------------

SUB Ok (label AS STRING, cond AS INTEGER)
    T_RUN = T_RUN + 1
    IF cond THEN PRINT "  ok   "; label ELSE PRINT "  FAIL "; label: T_BAD = T_BAD + 1
END SUB

SUB MgSection (s AS STRING)
    PRINT
    PRINT " "; s
END SUB

' Print the tally and exit with a code the shell can act on.
SUB MgDone
    PRINT
    PRINT USING "  ### assertion(s), ### failed"; T_RUN; T_BAD
    IF T_BAD > 0 THEN SYSTEM 1
    PRINT "  ALL GREEN"
    SYSTEM
END SUB
