' ============================================================================
'  DATA.bas -- central content loaders for the editable assets/data/*.txt files
'
'  Everything the game rolls on -- the bestiary, treasure pools, magic items,
'  boss names, curio traps, and crit/fumble lines -- lives in plain pipe-delimited
'  text files under assets/data/. Edit those, press F5, and the change is live; no
'  code edit needed. This module reads them and fills the same shared tables the
'  old hard-coded Init* routines used (via the Mob / SetTre / SetItem / AddFX
'  helpers), so the rest of the game is unchanged.
'
'  Format: one record per line, fields separated by '|' and individually TRIMMED
'  (so you may pad with spaces to align columns). Lines beginning with '#' and
'  blank lines are ignored.
' ============================================================================

' Field n (1-based) of a pipe-delimited line, trimmed. "" if there aren't that many.
FUNCTION DField$ (ln AS STRING, n AS INTEGER)
    DIM s AS STRING, p AS INTEGER, i AS INTEGER
    s = ln
    FOR i = 1 TO n - 1
        p = INSTR(s, "|")
        IF p = 0 THEN DField$ = "": EXIT FUNCTION
        s = MID$(s, p + 1)
    NEXT i
    p = INSTR(s, "|")
    IF p > 0 THEN s = LEFT$(s, p - 1)
    DField$ = _TRIM$(s)
END FUNCTION

' Read a data file into DLINE()/DLINE_N, dropping comments and blank lines. A whole
' -file read (_READFILE$) side-steps QB64's line-input EOF quirk; CR and LF both end
' a line. DLINE is a shared scratch buffer -- consume it before the next ReadDataFile.
SUB ReadDataFile (path AS STRING)
    DIM raw AS STRING, i AS INTEGER, ch2 AS STRING, ln AS STRING
    DLINE_N = 0
    IF _FILEEXISTS(path) = 0 THEN EXIT SUB
    raw = _READFILE$(path)
    ln = ""
    FOR i = 1 TO LEN(raw)
        ch2 = MID$(raw, i, 1)
        IF ch2 = CHR$(10) OR ch2 = CHR$(13) THEN
            AddDataLine ln: ln = ""
        ELSE
            ln = ln + ch2
        END IF
    NEXT i
    AddDataLine ln
END SUB

SUB AddDataLine (ln AS STRING)
    IF LEN(_TRIM$(ln)) = 0 THEN EXIT SUB
    IF LEFT$(_TRIM$(ln), 1) = "#" THEN EXIT SUB
    IF DLINE_N >= UBOUND(DLINE) THEN EXIT SUB
    DLINE_N = DLINE_N + 1: DLINE(DLINE_N) = ln
END SUB


' -- the bestiary: lvl | slot | name | HERO | ELF | SUP | WIZ --
SUB LoadMonsters
    DIM i AS INTEGER
    ReadDataFile "assets/data/monsters.txt"
    FOR i = 1 TO DLINE_N
        Mob VAL(DField$(DLINE(i), 1)), VAL(DField$(DLINE(i), 2)), DField$(DLINE(i), 3), VAL(DField$(DLINE(i), 4)), VAL(DField$(DLINE(i), 5)), VAL(DField$(DLINE(i), 6)), VAL(DField$(DLINE(i), 7))
    NEXT i
END SUB

' -- treasure pools: lvl | slot | name | gold --
SUB LoadTreasures
    DIM i AS INTEGER
    ReadDataFile "assets/data/treasures.txt"
    FOR i = 1 TO DLINE_N
        SetTreSlot VAL(DField$(DLINE(i), 1)), VAL(DField$(DLINE(i), 2)), DField$(DLINE(i), 3), VAL(DField$(DLINE(i), 4))
    NEXT i
END SUB

' -- magic items (override a treasure slot): lvl | slot | name | gold | type --
SUB LoadItems
    DIM i AS INTEGER
    ReadDataFile "assets/data/items.txt"
    FOR i = 1 TO DLINE_N
        SetItem VAL(DField$(DLINE(i), 1)), VAL(DField$(DLINE(i), 2)), DField$(DLINE(i), 3), VAL(DField$(DLINE(i), 4)), VAL(DField$(DLINE(i), 5))
    NEXT i
END SUB

' -- boss lair names: slot (1-4) | name --
SUB LoadBosses
    DIM i AS INTEGER, sl AS INTEGER
    ReadDataFile "assets/data/bosses.txt"
    FOR i = 1 TO DLINE_N
        sl = VAL(DField$(DLINE(i), 1))
        IF sl >= 1 AND sl <= 4 THEN BOSS_NAME(sl) = DField$(DLINE(i), 2)
    NEXT i
END SUB

' -- crit/fumble lines: table (1 crit / 2 you-fumble / 3 mon-fumble) | kind | die | text --
SUB LoadEffects
    DIM i AS INTEGER
    ReadDataFile "assets/data/effects.txt"
    FOR i = 1 TO DLINE_N
        AddFX VAL(DField$(DLINE(i), 1)), DField$(DLINE(i), 4), VAL(DField$(DLINE(i), 2)), VAL(DField$(DLINE(i), 3))
    NEXT i
END SUB

' -- curio traps: kind | name | save | word | sfx | die | trigger | savemsg | failtitle | failbody --
SUB LoadTraps
    DIM i AS INTEGER
    NTRAP = 0
    ReadDataFile "assets/data/traps.txt"
    FOR i = 1 TO DLINE_N
        IF NTRAP >= UBOUND(TRAPS) THEN EXIT FOR
        NTRAP = NTRAP + 1
        TRAPS(NTRAP).kind = VAL(DField$(DLINE(i), 1))
        TRAPS(NTRAP).name = DField$(DLINE(i), 2)
        TRAPS(NTRAP).save = DField$(DLINE(i), 3)
        TRAPS(NTRAP).word = DField$(DLINE(i), 4)
        TRAPS(NTRAP).sfx = DField$(DLINE(i), 5)
        TRAPS(NTRAP).die = VAL(DField$(DLINE(i), 6))
        TRAPS(NTRAP).trig = DField$(DLINE(i), 7)
        TRAPS(NTRAP).smsg = DField$(DLINE(i), 8)
        TRAPS(NTRAP).ftit = DField$(DLINE(i), 9)
        TRAPS(NTRAP).fbod = DField$(DLINE(i), 10)
    NEXT i
END SUB
