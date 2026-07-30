' ============================================================================
'  LOADERS.bas -- GAME-side data-table loaders.
'
'  These fill DUNGEON!-specific tables (tuning knobs, monster/treasure/item/boss
'  pools, crit-fumble effects, curio traps) from the pipe-delimited files under
'  assets/data/. They are thin: each just drives the ENGINE reader
'  (ReadDataFile / DField$ in engine/DATA.bas) and hands rows to the game setters
'  (Mob / SetTreSlot / SetItem / AddFX, or fills a game global directly).
'
'  Moved out of engine/DATA.bas so that module stays game-free (a pure reader +
'  ANSI/SGR/SAUCE utilities). Coupling is one-directional: game -> engine.
' ============================================================================

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


' Load the CHAMBER EVENT table (assets/data/<pack>/chamber-events.txt):
'   kind | name | weight | minlvl | maxlvl | text
' Mechanics stay in code keyed by `kind`; everything else is data. A missing/empty file
' leaves NCHMEV = 0, and ChamberEvent$ then falls back to "gauntlet" -- i.e. exactly the
' pre-table behaviour, so a data pack that ships no events still plays correctly.
SUB LoadChamberEvents
    DIM i AS INTEGER, kd AS STRING
    NCHMEV = 0
    ReadDataFile "assets/data/chamber-events.txt"
    FOR i = 1 TO DLINE_N
        kd = DField$(DLINE(i), 1)
        IF LEN(kd) > 0 AND NCHMEV < UBOUND(CHM_EV) THEN
            NCHMEV = NCHMEV + 1
            CHM_EV(NCHMEV).kind = kd
            CHM_EV(NCHMEV).nm = DField$(DLINE(i), 2)
            CHM_EV(NCHMEV).weight = VAL(DField$(DLINE(i), 3))
            CHM_EV(NCHMEV).minlvl = VAL(DField$(DLINE(i), 4))
            CHM_EV(NCHMEV).maxlvl = VAL(DField$(DLINE(i), 5))
            CHM_EV(NCHMEV).text = DField$(DLINE(i), 6)
        END IF
    NEXT i
END SUB
