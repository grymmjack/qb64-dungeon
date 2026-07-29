' ============================================================================
'  SAVEIO.bas -- ENGINE save-file plumbing (game-agnostic).
'
'  The generic half of the old SAVEGAME.bas: does a save file exist / delete it,
'  the "continue or new?" dialog, and the whitespace token-stream reader that any
'  game's load routine consumes. The GAME payload (what actually gets written and
'  read back) lives in game/SAVEGAME.bas and drives these.
'
'  Minor debt: the fixed filename "gameplay-data-saves/dungeon-save.dat" is game-chosen; a fully
'  separable engine would take it as a parameter. No game *symbols* are referenced.
' ============================================================================

FUNCTION HasSave%
    HasSave = (_FILEEXISTS("gameplay-data-saves/dungeon-save.dat") <> 0)
END FUNCTION

' Remove the save (called when a run ends -- winning -- so a stale continue can't resume it).
SUB DeleteSave
    IF _FILEEXISTS("gameplay-data-saves/dungeon-save.dat") THEN KILL "gameplay-data-saves/dungeon-save.dat"
END SUB


' Offered when entering the dungeon and a save exists: continue it or start fresh.
FUNCTION AskContinue%
    DIM k AS STRING
    _DEST CANVAS: CLS , BLACK
    COLOR YELLOWU, BLACK: PrintCentered 22, "A saved delve awaits you."
    COLOR CYANU, BLACK: PrintCentered 24, "[C] CONTINUE saved game        [N] start a NEW game"
    _DISPLAY
    DO
        _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
        IF k = "C" OR k = CHR$(13) THEN AskContinue = -1: EXIT FUNCTION
        IF k = "N" OR k = CHR$(27) THEN AskContinue = 0: EXIT FUNCTION
    LOOP
END FUNCTION


' -- token-stream reader (split a save file once, then consume tokens in order) --
SUB TokLoad (path AS STRING)
    DIM raw AS STRING, i AS INTEGER, cur AS STRING, ch2 AS STRING
    SVTOK_N = 0: SVTOK_I = 1
    ' _READFILE$ on a missing file is a RUNTIME ERROR, not an empty string. The game
    ' happens to gate this behind HasSave%, but an engine other games build on must not
    ' depend on every caller remembering -- an absent save is "no tokens", and the
    ' Next* readers already degrade to ""/0 from there.
    IF _FILEEXISTS(path) = 0 THEN EXIT SUB
    raw = _READFILE$(path)
    cur = ""
    FOR i = 1 TO LEN(raw)
        ch2 = MID$(raw, i, 1)
        IF ch2 = " " OR ch2 = CHR$(9) OR ch2 = CHR$(10) OR ch2 = CHR$(13) THEN
            IF LEN(cur) > 0 THEN
                IF SVTOK_N < UBOUND(SVTOK) THEN SVTOK_N = SVTOK_N + 1: SVTOK(SVTOK_N) = cur
                cur = ""
            END IF
        ELSE
            cur = cur + ch2
        END IF
    NEXT i
    IF LEN(cur) > 0 AND SVTOK_N < UBOUND(SVTOK) THEN SVTOK_N = SVTOK_N + 1: SVTOK(SVTOK_N) = cur
END SUB

FUNCTION NextTok$
    IF SVTOK_I > SVTOK_N THEN NextTok$ = "": EXIT FUNCTION
    NextTok$ = SVTOK(SVTOK_I): SVTOK_I = SVTOK_I + 1
END FUNCTION

FUNCTION NextI%
    NextI = VAL(NextTok$)
END FUNCTION

FUNCTION NextL&
    NextL = VAL(NextTok$)
END FUNCTION
