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

' UI / system strings from assets/data/strings.txt (key | text, split on the FIRST '|').
SUB LoadStrings
    DIM i AS INTEGER, ln AS STRING, p AS INTEGER
    STR_N = 0
    ReadDataFile "assets/data/strings.txt"
    FOR i = 1 TO DLINE_N
        ln = DLINE(i): p = INSTR(ln, "|")
        IF p > 0 AND STR_N < UBOUND(STR_KEY) THEN
            STR_N = STR_N + 1
            STR_KEY(STR_N) = _TRIM$(LEFT$(ln, p - 1))
            STR_TXT(STR_N) = _TRIM$(MID$(ln, p + 1))
        END IF
    NEXT i
END SUB

' Look up a UI string by key. Missing key -> the key itself (a visible "TODO" signal).
FUNCTION Say$ (k AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO STR_N
        IF STR_KEY(i) = k THEN Say$ = STR_TXT(i): EXIT FUNCTION
    NEXT i
    Say$ = k
END FUNCTION

' Gameplay TUNING knobs (potion/encounter/flee/XP/curio/loiter/move/siren) -- shipped
' defaults, then overridden by assets/data/tuning.txt (KEY | value). Call once at startup
' BEFORE any play (some, e.g. WANDER_GOLD_DIV, are divisors -- must never be left 0).
SUB LoadTuning
    POTION_SMALL_DIE = 4: POTION_LARGE_DIE = 8: POTION_LARGE_BONUS = 1
    TREASURE_POTION_PCT = 15: TREASURE_LARGE_PCT = 25: LEVELCLEAR_LARGE_PCT = 30
    IDLE_ENCOUNTER_PCT = 30: LOITER_THRESHOLD = 3: WANDER_GOLD_DIV = 6
    XP_PER_KILL_LVL = 10: CHEST_PCT = 20: CHEST_TRAP_PCT = 25
    CURIO_PATH_PCT = 3: CURIO_COOLDOWN = 16
    SIREN_ENCOUNTER_BOOST = 20: SIREN_MOVE_PCT = 15
    FLEE_FAIL_BASE = 15: FLEE_FAIL_STEP = 5: MOVE_MAX = 5
    DIM i AS INTEGER, k AS STRING, v AS INTEGER
    ReadDataFile "assets/data/tuning.txt"
    FOR i = 1 TO DLINE_N
        k = UCASE$(DField$(DLINE(i), 1)): v = VAL(DField$(DLINE(i), 2))
        SELECT CASE k
            CASE "POTION_SMALL_DIE": POTION_SMALL_DIE = v
            CASE "POTION_LARGE_DIE": POTION_LARGE_DIE = v
            CASE "POTION_LARGE_BONUS": POTION_LARGE_BONUS = v
            CASE "TREASURE_POTION_PCT": TREASURE_POTION_PCT = v
            CASE "TREASURE_LARGE_PCT": TREASURE_LARGE_PCT = v
            CASE "LEVELCLEAR_LARGE_PCT": LEVELCLEAR_LARGE_PCT = v
            CASE "IDLE_ENCOUNTER_PCT": IDLE_ENCOUNTER_PCT = v
            CASE "LOITER_THRESHOLD": LOITER_THRESHOLD = v
            CASE "WANDER_GOLD_DIV": IF v >= 1 THEN WANDER_GOLD_DIV = v    ' guard: it's a divisor
            CASE "XP_PER_KILL_LVL": XP_PER_KILL_LVL = v
            CASE "CHEST_PCT": CHEST_PCT = v
            CASE "CHEST_TRAP_PCT": CHEST_TRAP_PCT = v
            CASE "CURIO_PATH_PCT": CURIO_PATH_PCT = v
            CASE "CURIO_COOLDOWN": CURIO_COOLDOWN = v
            CASE "SIREN_ENCOUNTER_BOOST": SIREN_ENCOUNTER_BOOST = v
            CASE "SIREN_MOVE_PCT": SIREN_MOVE_PCT = v
            CASE "FLEE_FAIL_BASE": FLEE_FAIL_BASE = v
            CASE "FLEE_FAIL_STEP": FLEE_FAIL_STEP = v
            CASE "MOVE_MAX": IF v >= 1 THEN MOVE_MAX = v
        END SELECT
    NEXT i
END SUB

' Standard 16-colour VGA/CGA RGB -> ANSI foreground SGR code string (aixterm bright 90-97).
' Used to emit .ans starter masks whose colours ANSI_Print renders back to the exact palette.
FUNCTION SGRForColor$ (col AS _UNSIGNED LONG)
    SELECT CASE col
        CASE _RGB32(&H00, &H00, &H00): SGRForColor$ = "30"
        CASE _RGB32(&HAA, &H00, &H00): SGRForColor$ = "31"
        CASE _RGB32(&H00, &HAA, &H00): SGRForColor$ = "32"
        CASE _RGB32(&HAA, &H55, &H00): SGRForColor$ = "33"
        CASE _RGB32(&H00, &H00, &HAA): SGRForColor$ = "34"
        CASE _RGB32(&HAA, &H00, &HAA): SGRForColor$ = "35"
        CASE _RGB32(&H00, &HAA, &HAA): SGRForColor$ = "36"
        CASE _RGB32(&HAA, &HAA, &HAA): SGRForColor$ = "37"
        CASE _RGB32(&H55, &H55, &H55): SGRForColor$ = "90"
        CASE _RGB32(&HFF, &H55, &H55): SGRForColor$ = "91"
        CASE _RGB32(&H55, &HFF, &H55): SGRForColor$ = "92"
        CASE _RGB32(&HFF, &HFF, &H55): SGRForColor$ = "93"
        CASE _RGB32(&H55, &H55, &HFF): SGRForColor$ = "94"
        CASE _RGB32(&HFF, &H55, &HFF): SGRForColor$ = "95"
        CASE _RGB32(&H55, &HFF, &HFF): SGRForColor$ = "96"
        CASE ELSE: SGRForColor$ = "97"
    END SELECT
END FUNCTION

' Same palette -> ANSI BACKGROUND SGR (iCE colors: blink bit 5 = bright bg). A bg+space
' cell fills the WHOLE 8x16 cell solidly (no block-glyph sliver), matching how the masks
' are hand-painted -- and the vendored ANSIPrint renders 5;4x as a bright background.
FUNCTION SGRBgForColor$ (col AS _UNSIGNED LONG)
    DIM f AS INTEGER
    f = VAL(SGRForColor$(col))
    IF f >= 90 THEN SGRBgForColor$ = "5;" + _TRIM$(STR$(f - 90 + 40)) ELSE SGRBgForColor$ = _TRIM$(STR$(f + 10))
END FUNCTION

' Build a 128-byte SAUCE record (Character/ANSi, IBM VGA font) for an ANSI of cols x rows,
' where datalen = the byte length of the art before the 0x1A EOF marker.
FUNCTION SauceRecord$ (title AS STRING, cols AS INTEGER, rows AS INTEGER, datalen AS LONG)
    DIM s AS STRING
    s = "SAUCE" + "00"
    s = s + PadR$(title, 35) + PadR$("grymmjack", 20) + PadR$("", 20)
    s = s + MID$(DATE$, 7, 4) + MID$(DATE$, 1, 2) + MID$(DATE$, 4, 2)   ' Date CCYYMMDD
    s = s + MKL$(datalen) + CHR$(1) + CHR$(1)                            ' FileSize, DataType Char, FileType ANSi
    s = s + MKI$(cols) + MKI$(rows) + MKI$(0) + MKI$(0)                  ' TInfo1..4
    s = s + CHR$(0) + CHR$(0) + "IBM VGA" + STRING$(15, 0)               ' Comments, TFlags, font
    SauceRecord$ = s
END FUNCTION

' Parse a "RRGGBB" (or "#RRGGBB") hex colour string to _RGB32. Black on a bad value.
FUNCTION HexRGB~& (h AS STRING)
    DIM s AS STRING
    s = _TRIM$(h): IF LEFT$(s, 1) = "#" THEN s = MID$(s, 2)
    IF LEN(s) < 6 THEN HexRGB~& = _RGB32(0, 0, 0): EXIT FUNCTION
    HexRGB~& = _RGB32(VAL("&H" + MID$(s, 1, 2)), VAL("&H" + MID$(s, 3, 2)), VAL("&H" + MID$(s, 5, 2)))
END FUNCTION

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
