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
    AMB_SECS_MIN = 18: AMB_SECS_MAX = 45          ' seconds between ambient noises (MIN 0 = off)
    DOORNOISE_PCT = 25: DOORNOISE_CLEAR_PCT = 5   ' racket at a reinforced door: +% per attempt, and on a cleared floor
    XP_PER_KILL_LVL = 10: CHEST_PCT = 20: CHEST_TRAP_PCT = 25
    CURIO_PATH_PCT = 3: CURIO_COOLDOWN = 16
    SIREN_ENCOUNTER_BOOST = 20: SIREN_MOVE_PCT = 15
    ' item-drop odds per level; defaults ramp with depth (level 1 stays plain gold)
    DIM tl AS INTEGER
    ITEM_PCT(1) = 0
    FOR tl = 2 TO 9: ITEM_PCT(tl) = 8 + tl * 3: NEXT tl
    FLEE_FAIL_BASE = 15: FLEE_FAIL_STEP = 5: MOVE_MAX = 5
    ' monster scaling (see GAME.BI). Defaults reproduce the old hard-coded formulas EXCEPT the
    ' chamber LORD (was 150% HP / +2 to-hit) and the new AC/to-hit caps -- that combination is
    ' what produced a 70 HP, AC 18, +10-to-hit guardian on level 8.
    MON_HP_PER_LVL = 4: MON_HP_DIE_BASE = 4: MON_HP_DIE_STEP = 2
    MON_AC_BASE = 9: MON_AC_MAX = 17: MON_TOHIT_MAX = 8
    BOSS_HP_BASE = 45: BOSS_HP_PER_LVL = 3: BOSS_AC = 19: BOSS_TOHIT_BONUS = 2
    LORD_HP_PCT = 130: LORD_AC_BONUS = 1: LORD_TOHIT_BONUS = 1
    WANDER_AC_BONUS = 0
    MIMIC_HP_PER_LVL = 5: MIMIC_AC_BASE = 11
    DIM i AS INTEGER, k AS STRING, v AS INTEGER, lv AS INTEGER
    ReadDataFile "assets/data/tuning.txt"
    FOR i = 1 TO DLINE_N
        k = UCASE$(DField$(DLINE(i), 1)): v = VAL(DField$(DLINE(i), 2))
        SELECT CASE k
            ' --- tactical combat (engine/FUSE.bas, STATUS.bas). Sub-second values are in ms. ---
            CASE "FUSE_MIN_MS": TUNE_FUSE_MIN_MS = v
            CASE "GESTURE_MS": TUNE_GESTURE_MS = v
            CASE "DODGE_MS": TUNE_DODGE_MS = v
            CASE "FUSE_BASE_MS": TUNE_FUSE_BASE_MS = v
            CASE "FUSE_TIER_MS": TUNE_FUSE_TIER_MS = v
            CASE "FUSE_DEPTH_MS": TUNE_FUSE_DEPTH_MS = v
            CASE "STANCE_ATTACK_OUT_PCT": TUNE_ST_ATK_OUT = v
            CASE "STANCE_ATTACK_IN_PCT": TUNE_ST_ATK_IN = v
            CASE "STANCE_GUARD_OUT_PCT": TUNE_ST_GRD_OUT = v
            CASE "STANCE_GUARD_IN_PCT": TUNE_ST_GRD_IN = v
            CASE "STANCE_STAGGER_OUT_PCT": TUNE_ST_STG_OUT = v
            CASE "STANCE_STAGGER_IN_PCT": TUNE_ST_STG_IN = v
            CASE "HP_GRAZED_PCT": TUNE_HP_GRAZED = v
            CASE "HP_WOUNDED_PCT": TUNE_HP_WOUNDED = v
            CASE "HP_BLOODIED_PCT": TUNE_HP_BLOODIED = v
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
            CASE "AMB_SECS_MIN": IF v >= 0 THEN AMB_SECS_MIN = v          ' 0 = ambience off
            CASE "AMB_SECS_MAX": IF v >= 1 THEN AMB_SECS_MAX = v
            CASE "DOORNOISE_PCT": IF v >= 0 THEN DOORNOISE_PCT = v
            CASE "DOORNOISE_CLEAR_PCT": IF v >= 0 THEN DOORNOISE_CLEAR_PCT = v
            CASE "CHEST_PCT": CHEST_PCT = v
            CASE "CHEST_TRAP_PCT": CHEST_TRAP_PCT = v
            CASE "CURIO_PATH_PCT": CURIO_PATH_PCT = v
            CASE "CURIO_COOLDOWN": CURIO_COOLDOWN = v
            CASE "SIREN_ENCOUNTER_BOOST": SIREN_ENCOUNTER_BOOST = v
            CASE "SIREN_MOVE_PCT": SIREN_MOVE_PCT = v
            CASE "FLEE_FAIL_BASE": FLEE_FAIL_BASE = v
            CASE "FLEE_FAIL_STEP": FLEE_FAIL_STEP = v
            CASE "MOVE_MAX": IF v >= 1 THEN MOVE_MAX = v
            ' monster scaling. Guards where a zero/negative would be nonsense rather than a
            ' meaningful "off": a 0-sided HP die or a 0% LORD multiplier makes a 0 HP monster.
            CASE "MON_HP_PER_LVL": IF v >= 0 THEN MON_HP_PER_LVL = v
            CASE "MON_HP_DIE_BASE": IF v >= 1 THEN MON_HP_DIE_BASE = v
            CASE "MON_HP_DIE_STEP": IF v >= 0 THEN MON_HP_DIE_STEP = v
            CASE "MON_AC_BASE": MON_AC_BASE = v
            CASE "MON_AC_MAX": IF v >= 1 THEN MON_AC_MAX = v
            CASE "MON_TOHIT_MAX": IF v >= 0 THEN MON_TOHIT_MAX = v
            CASE "BOSS_HP_BASE": IF v >= 1 THEN BOSS_HP_BASE = v
            CASE "BOSS_HP_PER_LVL": IF v >= 0 THEN BOSS_HP_PER_LVL = v
            CASE "BOSS_AC": IF v >= 1 THEN BOSS_AC = v
            CASE "BOSS_TOHIT_BONUS": BOSS_TOHIT_BONUS = v
            CASE "LORD_HP_PCT": IF v >= 100 THEN LORD_HP_PCT = v
            CASE "LORD_AC_BONUS": LORD_AC_BONUS = v
            CASE "LORD_TOHIT_BONUS": LORD_TOHIT_BONUS = v
            CASE "WANDER_AC_BONUS": WANDER_AC_BONUS = v
            CASE "MIMIC_HP_PER_LVL": IF v >= 0 THEN MIMIC_HP_PER_LVL = v
            CASE "MIMIC_AC_BASE": MIMIC_AC_BASE = v
            CASE ELSE
                ' ITEM_PCT_<n> -- per-level magic-item drop chance (see items.txt).
                ' Keyed rather than positional so a pack can override one level only.
                IF LEFT$(k, 9) = "ITEM_PCT_" THEN
                    lv = VAL(MID$(k, 10))
                    IF lv >= 1 AND lv <= 9 THEN
                        IF v < 0 THEN v = 0
                        IF v > 100 THEN v = 100
                        ITEM_PCT(lv) = v
                    END IF
                END IF
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
    DIM i AS INTEGER, lvl AS INTEGER, f2 AS STRING, nm AS STRING
    DIM g AS INTEGER, code AS INTEGER, wt AS INTEGER, old AS INTEGER
    FOR lvl = 1 TO 9: ITM_N(lvl) = 0: NEXT lvl
    ITEMS_OLDFMT = FALSE
    ReadDataFile "assets/data/items.txt"
    FOR i = 1 TO DLINE_N
        lvl = VAL(DField$(DLINE(i), 1))
        f2 = DField$(DLINE(i), 2)
        ' Two accepted layouts, told apart by whether field 2 is a bare NUMBER:
        '   LEGACY: lvl | slot | name | gold | type      (slot encoded the frequency)
        '   CURRENT: lvl | name | gold | type | weight
        ' A legacy pack still loads -- its slot is simply ignored and every item gets an
        ' equal weight, since a slot no longer means anything. datalint flags the format.
        old = IsAllDigits%(f2)
        IF old THEN
            ITEMS_OLDFMT = TRUE
            nm = DField$(DLINE(i), 3): g = VAL(DField$(DLINE(i), 4))
            code = VAL(DField$(DLINE(i), 5)): wt = 10
        ELSE
            nm = f2: g = VAL(DField$(DLINE(i), 3))
            code = VAL(DField$(DLINE(i), 4)): wt = VAL(DField$(DLINE(i), 5))
            IF wt <= 0 THEN wt = 10                     ' omitted weight = ordinary rarity
        END IF
        IF lvl >= 1 AND lvl <= 9 AND LEN(nm) > 0 THEN
            IF ITM_N(lvl) < MAXITEMPL THEN
                ITM_N(lvl) = ITM_N(lvl) + 1
                ITM_NAME(lvl, ITM_N(lvl)) = nm
                ITM_GOLD(lvl, ITM_N(lvl)) = g
                ITM_CODE(lvl, ITM_N(lvl)) = code
                ITM_W(lvl, ITM_N(lvl)) = wt
            END IF
        END IF
    NEXT i
END SUB

' TRUE if s is non-empty and all digits -- how LoadItems tells the legacy `slot` column
' (a bare 1..3) from a current-format item NAME.
FUNCTION IsAllDigits% (s AS STRING)
    DIM i AS INTEGER, t AS STRING, ch2 AS STRING
    t = _TRIM$(s)
    IsAllDigits% = 0
    IF LEN(t) = 0 THEN EXIT FUNCTION
    FOR i = 1 TO LEN(t)
        ch2 = MID$(t, i, 1)
        IF ch2 < "0" OR ch2 > "9" THEN EXIT FUNCTION
    NEXT i
    IsAllDigits% = -1
END FUNCTION

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
' Load the AMBIENCE table: which distant noises each dungeon level makes, and how often.
' Rows are `level | sfx | weight`, level 0 = any level. See assets/data/<pack>/ambience.txt.
SUB LoadAmbience
    DIM i AS INTEGER, lv AS INTEGER, w AS INTEGER
    AMB_N = 0
    ReadDataFile "assets/data/ambience.txt"
    FOR i = 1 TO DLINE_N
        lv = VAL(DField$(DLINE(i), 1))
        w = VAL(DField$(DLINE(i), 3))
        IF w < 1 THEN w = 1
        IF lv >= 0 AND lv <= 9 THEN
            IF AMB_N < UBOUND(AMB_LVL) THEN
                AMB_N = AMB_N + 1
                AMB_LVL(AMB_N) = lv: AMB_NAME(AMB_N) = DField$(DLINE(i), 2): AMB_W(AMB_N) = w
            END IF
        END IF
    NEXT i
END SUB


' Load the ability-score help table (assets/data/<pack>/stats.txt).
SUB LoadStatHelp
    DIM i AS INTEGER, nm AS STRING, ix AS INTEGER
    SH_N = 0
    ReadDataFile "assets/data/stats.txt"
    FOR i = 1 TO DLINE_N
        nm = UCASE$(DField$(DLINE(i), 1))
        ix = 0
        SELECT CASE nm
            CASE "STR": ix = 1
            CASE "INT": ix = 2
            CASE "WIS": ix = 3
            CASE "DEX": ix = 4
            CASE "CON": ix = 5
            CASE "CHA": ix = 6
        END SELECT
        IF ix > 0 AND SH_N < UBOUND(SH_STAT) THEN
            SH_N = SH_N + 1
            SH_STAT(SH_N) = ix
            SH_LIVE(SH_N) = (VAL(DField$(DLINE(i), 2)) <> 0)
            SH_TEXT(SH_N) = DField$(DLINE(i), 3)
        END IF
    NEXT i
END SUB


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
