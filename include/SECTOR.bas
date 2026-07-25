' ============================================================================
'  SECTOR.bas -- sector geometry, monster/treasure/class data + randomiser
' ============================================================================

SUB InitSectors
    SECTORS(1).kolor = _RGB32(&H55, &HFF, &H55): SECTORS(1).label = "LEVEL 1 - MAIN GALLERY"
    SECTORS(1).start_x = 41: SECTORS(1).start_y = 17: SECTORS(1).end_x = 79: SECTORS(1).end_y = 32

    SECTORS(2).kolor = _RGB32(&H00, &HAA, &H00): SECTORS(2).label = "LEVEL 2 - GUARD ROOM"
    SECTORS(2).start_x = 1: SECTORS(2).start_y = 17: SECTORS(2).end_x = 40: SECTORS(2).end_y = 33

    SECTORS(3).kolor = _RGB32(&HAA, &H00, &H00): SECTORS(3).label = "LEVEL 3 - ARMORY"
    SECTORS(3).start_x = 1: SECTORS(3).start_y = 1: SECTORS(3).end_x = 34: SECTORS(3).end_y = 16

    SECTORS(4).kolor = _RGB32(&HFF, &H55, &H55): SECTORS(4).label = "LEVEL 4 - STORE ROOM"
    SECTORS(4).start_x = 1: SECTORS(4).start_y = 34: SECTORS(4).end_x = 40: SECTORS(4).end_y = 50

    SECTORS(5).kolor = _RGB32(&HFF, &H55, &HFF): SECTORS(5).label = "LEVEL 5 - TORTURE CHAMBER"
    SECTORS(5).start_x = 41: SECTORS(5).start_y = 33: SECTORS(5).end_x = 80: SECTORS(5).end_y = 50

    SECTORS(6).kolor = _RGB32(&H00, &HAA, &HAA): SECTORS(6).label = "LEVEL 6 - KING'S QUARTERS"
    SECTORS(6).start_x = 80: SECTORS(6).start_y = 17: SECTORS(6).end_x = 117: SECTORS(6).end_y = 32

    SECTORS(7).kolor = _RGB32(&H55, &HFF, &HFF): SECTORS(7).label = "LEVEL 7 - WIZ'S QUARTERS"
    SECTORS(7).start_x = 79: SECTORS(7).start_y = 1: SECTORS(7).end_x = 117: SECTORS(7).end_y = 16

    SECTORS(8).kolor = _RGB32(&H55, &H55, &H55): SECTORS(8).label = "LEVEL 8 - QUEEN'S QUARTERS"
    SECTORS(8).start_x = 81: SECTORS(8).start_y = 33: SECTORS(8).end_x = 117: SECTORS(8).end_y = 50

    SECTORS(9).kolor = _RGB32(&HAA, &H00, &HAA): SECTORS(9).label = "LEVEL 9 - THE CRYPT"
    SECTORS(9).start_x = 35: SECTORS(9).start_y = 1: SECTORS(9).end_x = 78: SECTORS(9).end_y = 16
END SUB


' Authentic Dungeon! monster roster + treasures, scaled across the 9 levels.
' Values approximate the board game (exact card numbers live on the cards).

SUB InitMonsterTables
    ' The bestiary, treasure pools, magic items and boss names now live in the
    ' editable files under assets/data/ -- edit those and press F5. LoadTreasures
    ' fills every slot; LoadItems then overrides slots that hold a magic-item card.
    LoadMonsters
    LoadTreasures
    LoadItems
    LoadBosses
END SUB



SUB Mob (lvl AS INTEGER, slot AS INTEGER, nm AS STRING, hh AS INTEGER, ee AS INTEGER, ss AS INTEGER, ww AS INTEGER)
    MON_NAME(lvl, slot) = nm
    MON_N(lvl, slot, 1) = hh: MON_N(lvl, slot, 2) = ee
    MON_N(lvl, slot, 3) = ss: MON_N(lvl, slot, 4) = ww
END SUB



SUB SetTre (lvl AS INTEGER, n1 AS STRING, g1 AS INTEGER, n2 AS STRING, g2 AS INTEGER, n3 AS STRING, g3 AS INTEGER)
    TRE_NAME(lvl, 1) = n1: TRE_GOLD(lvl, 1) = g1
    TRE_NAME(lvl, 2) = n2: TRE_GOLD(lvl, 2) = g2
    TRE_NAME(lvl, 3) = n3: TRE_GOLD(lvl, 3) = g3
END SUB


' Set one treasure slot (used by LoadTreasures reading assets/data/treasures.txt).
SUB SetTreSlot (lvl AS INTEGER, slot AS INTEGER, nm AS STRING, gold AS INTEGER)
    IF lvl < 1 OR lvl > 9 OR slot < 1 OR slot > 3 THEN EXIT SUB
    TRE_NAME(lvl, slot) = nm: TRE_GOLD(lvl, slot) = gold: TRE_ITEM(lvl, slot) = 0
END SUB


' Seed a magic-item card into one treasure slot of a level (name, sell/gold value, item code).
SUB SetItem (lvl AS INTEGER, slot AS INTEGER, nm AS STRING, gold AS INTEGER, code AS INTEGER)
    TRE_NAME(lvl, slot) = nm: TRE_GOLD(lvl, slot) = gold: TRE_ITEM(lvl, slot) = code
END SUB


' Roll fresh room contents: each level's room (sector) gets a random monster +
' treasure from that level's pool; one deep room becomes the boss lair.

SUB RandomizeRooms
    ' EVERY detected room gets its own monster + treasure from its level's pool.
    ' (Call DetectRooms first -- done in StartBoard/InitFog -- so ROOMS is populated.)
    DIM r AS INTEGER, sec AS INTEGER, m AS INTEGER, t AS INTEGER, startroom AS INTEGER
    DIM bossroom AS INTEGER, ndeep AS INTEGER, sl AS INTEGER
    DIM deeproom(1 TO 400) AS INTEGER
    DIM used(1 TO 9, 1 TO 3) AS INTEGER         ' D&D variety: how often each level's monster has been placed
    CONST MIN_ROOM = 4                          ' blocks smaller than this are labels, not rooms
    startroom = ROOMAT(START_CX, START_CY)      ' the entrance chamber stays safe
    ndeep = 0
    FOR r = 1 TO ROOM_N
        sec = ROOMS(r).sec
        ROOMS(r).monster_fought = FALSE: ROOMS(r).player_died = FALSE
        ROOMS(r).looted = FALSE: ROOMS(r).is_boss = FALSE: ROOMS(r).seen = FALSE
        ROOMS(r).drop_gold = 0: ROOMS(r).drop_sword = 0
        ROOMS(r).drop_secret = FALSE: ROOMS(r).drop_esp = FALSE: ROOMS(r).drop_crystal = FALSE
        IF r = startroom OR ROOMS(r).cells < MIN_ROOM THEN
            ROOMS(r).monster = "": ROOMS(r).malive = FALSE
            ROOMS(r).treasure = 0: ROOMS(r).treasure_name = "": ROOMS(r).treasure_item = 0
        ELSE
            t = RollDie(3)
            IF opt_oldschool THEN
                m = RollDie(3)                          ' faithful Dungeon!: this level's own 3 monsters only
                ROOMS(r).monster = MON_NAME(sec, m): ROOMS(r).mslot = m
            ELSE
                PickVariedMonster sec, used(), sl, m    ' D&D: widen the roster + spread it so no monster dominates
                ROOMS(r).monster = MON_NAME(sl, m): ROOMS(r).mslot = m
            END IF
            ROOMS(r).malive = TRUE
            ROOMS(r).treasure_name = TRE_NAME(sec, t): ROOMS(r).treasure = TRE_GOLD(sec, t)
            ROOMS(r).treasure_item = TRE_ITEM(sec, t)
            ROOMS(r).mhp = sec * 4 + RollDie(6) + 2: ROOMS(r).mhp_now = ROOMS(r).mhp
            ROOMS(r).mac = 9 + sec
            IF sec >= 6 THEN ndeep = ndeep + 1: deeproom(ndeep) = r
        END IF
    NEXT r
    ' one deep room becomes the boss lair (a brutal fight + a great hoard)
    IF ndeep > 0 THEN
        bossroom = deeproom(RollDie(ndeep))
        sec = ROOMS(bossroom).sec
        ROOMS(bossroom).is_boss = TRUE
        ROOMS(bossroom).monster = BOSS_NAME(RollDie(4))
        ROOMS(bossroom).treasure_name = "DRAGON'S HOARD"
        ROOMS(bossroom).treasure = ROOMS(bossroom).treasure + 6000
        ROOMS(bossroom).treasure_item = 0
        ROOMS(bossroom).mhp = 45 + sec * 3 + RollDie(10): ROOMS(bossroom).mhp_now = ROOMS(bossroom).mhp
        ROOMS(bossroom).mac = 19
    END IF

    ' -- the LEVEL KEY: the prize of one random room on a DEEP level (never the
    ' entrance level 1, never the boss), so winning requires descending. Its exact
    ' room is pinpointed by the Crystal Ball; otherwise only its level is hinted.
    DIM kcand(1 TO 400) AS INTEGER, nk AS INTEGER
    key_room = 0: key_level = 0: nk = 0
    FOR r = 1 TO ROOM_N
        IF ROOMS(r).malive AND ROOMS(r).sec >= 2 AND NOT ROOMS(r).is_boss THEN nk = nk + 1: kcand(nk) = r
    NEXT r
    IF nk = 0 THEN                               ' fallback: any live monster room that isn't the boss
        FOR r = 1 TO ROOM_N
            IF ROOMS(r).malive AND NOT ROOMS(r).is_boss THEN nk = nk + 1: kcand(nk) = r
        NEXT r
    END IF
    IF nk > 0 THEN
        key_room = kcand(RollDie(nk))
        key_level = ROOMS(key_room).sec
        ROOMS(key_room).treasure_item = 6        ' 6 = Level Key (see ClaimTreasure)
        ROOMS(key_room).treasure_name = "THE LEVEL KEY"
    END IF
END SUB


' D&D-mode monster variety. Difficulty in D&D comes from level-scaled HP/AC, not the
' 2d6 card number, so the monster NAME is free to vary -- unlike Oldschool, which must
' keep name and kill-number in lockstep. Draws mostly from THIS level, occasionally one
' level away (an off-level face), and prefers the least-used slot so a floor doesn't turn
' into "all goblins". slOut/mOut return the chosen level + slot (index into MON_NAME).
SUB PickVariedMonster (sec AS INTEGER, used() AS INTEGER, slOut AS INTEGER, mOut AS INTEGER)
    DIM sl AS INTEGER, s AS INTEGER, best AS INTEGER, bestu AS INTEGER, ties AS INTEGER, pick AS INTEGER
    sl = sec
    IF RollDie(100) <= 30 THEN                    ' 30%: reach one level away for variety
        IF RollDie(2) = 1 THEN sl = sec - 1 ELSE sl = sec + 1
        IF sl < 1 THEN sl = 1
        IF sl > 9 THEN sl = 9
    END IF
    ' least-used of that level's 3 slots, random tie-break, so usage spreads evenly
    bestu = 32767
    FOR s = 1 TO 3
        IF used(sl, s) < bestu THEN bestu = used(sl, s)
    NEXT
    ties = 0
    FOR s = 1 TO 3
        IF used(sl, s) = bestu THEN ties = ties + 1
    NEXT
    pick = RollDie(ties): ties = 0: best = 1
    FOR s = 1 TO 3
        IF used(sl, s) = bestu THEN
            ties = ties + 1
            IF ties = pick THEN best = s: EXIT FOR
        END IF
    NEXT
    used(sl, best) = used(sl, best) + 1
    slOut = sl: mOut = best
END SUB


' 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th" ... (for the key-level hint).
FUNCTION Ordinal$ (n AS INTEGER)
    DIM suf AS STRING
    SELECT CASE n MOD 100
        CASE 11, 12, 13: suf = "th"
        CASE ELSE
            SELECT CASE n MOD 10
                CASE 1: suf = "st"
                CASE 2: suf = "nd"
                CASE 3: suf = "rd"
                CASE ELSE: suf = "th"
            END SELECT
    END SELECT
    Ordinal$ = _TRIM$(STR$(n)) + suf
END FUNCTION


' Authentic DUNGEON! win totals: Hero/Elf 10k, Superhero 20k, Wizard 30k.

SUB InitClasses
    ' Oldschool fields: combat_bonus/secret_bonus.  D&D fields: hp / tohit / dmg (die sides) / ac.
    ' --- tune the D&D balance here ---
    CLASSES(1).name = "HERO": CLASSES(1).gold_goal = 10000
    CLASSES(1).combat_bonus = 0: CLASSES(1).secret_bonus = 0
    CLASSES(1).blurb = "Solid fighter. Finds secret doors on a 1-2. Needs 10,000 gold."
    CLASSES(1).hp = 24: CLASSES(1).tohit = 2: CLASSES(1).dmg = 8: CLASSES(1).ac = 15: CLASSES(1).hitdie = 10

    CLASSES(2).name = "ELF": CLASSES(2).gold_goal = 10000
    CLASSES(2).combat_bonus = -1: CLASSES(2).secret_bonus = 2
    CLASSES(2).blurb = "Weakest fighter, but finds secret doors on a 1-4. Needs 10,000."
    CLASSES(2).hp = 16: CLASSES(2).tohit = 1: CLASSES(2).dmg = 6: CLASSES(2).ac = 13: CLASSES(2).hitdie = 8

    CLASSES(3).name = "SUPERHERO": CLASSES(3).gold_goal = 20000
    CLASSES(3).combat_bonus = 0: CLASSES(3).secret_bonus = 0
    CLASSES(3).blurb = "The deadliest warrior -- slays monsters on low rolls. Needs 20,000 gold."
    CLASSES(3).hp = 32: CLASSES(3).tohit = 3: CLASSES(3).dmg = 10: CLASSES(3).ac = 17: CLASSES(3).hitdie = 12

    CLASSES(4).name = "WIZARD": CLASSES(4).gold_goal = 30000
    CLASSES(4).combat_bonus = 0: CLASSES(4).secret_bonus = 1
    CLASSES(4).blurb = "Slays with spells; can't use Magic Swords. Needs 30,000 gold."
    CLASSES(4).hp = 14: CLASSES(4).tohit = 2: CLASSES(4).dmg = 10: CLASSES(4).ac = 12: CLASSES(4).hitdie = 6
END SUB


' Class-select screen reached from the menu's CREATE A CHARACTER option.
' Returns the chosen class index (1-4), or 0 if the player backs out.

FUNCTION SECTOR.get_by_xy% (x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER
    DIM s AS SECTOR
    DIM AS INTEGER sx, ex, sy, ey
    FOR i = 1 TO 9
        s = SECTORS(i)
        sx = (s.start_x - 1) * CW
        ex = (s.end_x - 1) * CW
        sy = (s.start_y - 1) * CH
        ey = (s.end_y - 1) * CH
        IF x >= sx AND x <= ex AND y >= sy AND y <= ey THEN
            SECTOR.get_by_xy = i
            EXIT FUNCTION
        END IF
    NEXT i
    SECTOR.get_by_xy = 0
END FUNCTION


' ============================================================================
'  HUD + UI HELPERS
' ============================================================================
