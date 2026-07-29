$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/SAVEIO.bas -- the save-file token stream.
'
'  game/SAVEGAME.bas writes a whitespace-separated save and reads it back with
'  NextTok$/NextI%/NextL&. The stream is POSITIONAL: every reader must consume
'  exactly as many tokens as the writer wrote, or the entire rest of the save
'  shifts by one and silently loads garbage (a wrong gold total, a monster in the
'  wrong room). So the two behaviours that matter are that tokenising is exact,
'  and that reading PAST the end degrades to ""/0 rather than running away.
' ============================================================================

DIM SHARED TMP AS STRING
TMP = "tests/tmp"

T_Begin "engine/SAVEIO.bas"
IF _DIREXISTS(TMP) = 0 THEN MKDIR TMP        ' MKDIR on an existing dir is a runtime error

DIM P AS STRING
P = TMP + "/tok.dat"

' Write a save-shaped file: mixed separators, blank lines, trailing newline.
SUB WriteTok (path AS STRING, body AS STRING)
    DIM f AS INTEGER
    f = FREEFILE: OPEN path FOR OUTPUT AS #f
    PRINT #f, body;
    CLOSE #f
END SUB

T_Group "TokLoad / NextTok$"
WriteTok P, "GOLD 1200 KEY 1"
TokLoad P
T_EqI "token count", SVTOK_N, 4
T_EqS "1st", NextTok$, "GOLD"
T_EqI "2nd as int", NextI%, 1200
T_EqS "3rd", NextTok$, "KEY"
T_EqI "4th as int", NextI%, 1

T_Group "separators: spaces, tabs, CR, LF all split"
WriteTok P, "a" + CHR$(9) + "b" + CHR$(13) + CHR$(10) + "c  d" + CHR$(10)
TokLoad P
T_EqI "four tokens despite mixed separators", SVTOK_N, 4
T_EqS "a", NextTok$, "a"
T_EqS "b", NextTok$, "b"
T_EqS "c", NextTok$, "c"
T_EqS "d", NextTok$, "d"

T_Group "runs of whitespace collapse (no empty tokens)"
WriteTok P, "   x" + CHR$(10) + CHR$(10) + CHR$(10) + "   y   "
TokLoad P
T_EqI "leading/blank/trailing runs produce no empties", SVTOK_N, 2
T_EqS "x", NextTok$, "x"
T_EqS "y", NextTok$, "y"

T_Group "final token with no trailing newline is not dropped"
WriteTok P, "one two three"
TokLoad P
T_EqI "three tokens", SVTOK_N, 3
T_EqS "last survives", SVTOK(3), "three"

T_Group "reading past the end degrades safely"
WriteTok P, "5"
TokLoad P
T_EqI "the one value", NextI%, 5
T_EqS "past-end string is empty", NextTok$, ""
T_EqI "past-end int is 0", NextI%, 0
T_EqI "past-end long is 0", NextL&, 0
T_EqS "and stays empty (no runaway)", NextTok$, ""

T_Group "empty / missing file"
WriteTok P, ""
TokLoad P
T_EqI "empty file -> no tokens", SVTOK_N, 0
T_EqS "reading it is empty, not a crash", NextTok$, ""
T_Rm P
TokLoad P
T_EqI "missing file -> no tokens", SVTOK_N, 0

T_Group "NextL& handles values beyond INTEGER range"
WriteTok P, "100000 -70000"
TokLoad P
T_EqI "large positive", NextL&, 100000
T_EqI "large negative", NextL&, -70000

T_Group "HasSave% / DeleteSave"
T_Rm P
T_False "no file -> HasSave is false for that path", _FILEEXISTS(P)
WriteTok P, "x"
T_True "file present", _FILEEXISTS(P)

T_Rm P
T_Done

' No stubs needed: engine/SAVEIO.bas is pure file plumbing. (It used to need a
' PrintCentered stub because AskContinue% -- a SCREEN -- shared the file with the
' token reader; that dialog now lives in engine/UI.bas where it belongs.)

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/TEXT.bas'
'$INCLUDE:'../engine/SAVEIO.bas'
