' ============================================================================
'  SECTOR.bas -- sector geometry, monster/treasure/class data + randomiser
' ============================================================================

' Sector geometry + colours now live in assets/data/sectors.txt -- edit + F5, no
' code change. Thin wrapper over LoadSectors (matches InitMonsterTables' pattern).
SUB InitSectors
    LoadSectors                          ' id / label / colour (+ fallback rects) from the data file
    LoadSectorMask                       ' optional: geometry painted per-cell in assets/ansi/board-132x50-sector-mask.ans
END SUB

' Load the SECTOR MASK: a same-size ANSI where each cell is painted its level's colour
' (the sectors.txt colour). Fills SECTORAT(cx,cy) = sector id by matching each cell's colour
' to a sector's kolor -- so a level can be ANY shape, and geometry needs no coordinates.
' When present it drives SECTOR.get_by_xy; absent, the code falls back to the sectors.txt rects.
SUB LoadSectorMask
    DIM x AS INTEGER, y AS INTEGER
    FOR y = 0 TO 60: FOR x = 0 TO 131: SECTORAT(x, y) = 0: NEXT: NEXT
    SECTORMASK_ON = FALSE
    IF NOT _FILEEXISTS("assets/ansi/board-132x50-sector-mask.ans") THEN EXIT SUB
    DIM mb AS STRING, mimg AS LONG, olddest AS LONG, oldsrc AS LONG, cnt AS INTEGER
    mb = _READFILE$("assets/ansi/board-132x50-sector-mask.ans")
    IF LEN(mb) = 0 THEN EXIT SUB
    mimg = _NEWIMAGE(SW * CW, SH * CH, 32)
    olddest = _DEST: _DEST mimg: _FONT CH: CLS , BLACK
    ANSI_Print (mb)
    _DEST olddest
    oldsrc = _SOURCE: _SOURCE mimg
    cnt = 0
    FOR y = 0 TO SH - 1
        FOR x = 0 TO SW - 1
            SECTORAT(x, y) = SectorByColor%(MaskSample~&(x, y))
            IF SECTORAT(x, y) > 0 THEN cnt = cnt + 1
        NEXT x
    NEXT y
    _SOURCE oldsrc: _FREEIMAGE mimg
    IF cnt > 0 THEN SECTORMASK_ON = -1
END SUB

' Which sector (1-9) a colour belongs to (exact match to a sector's kolor). 0 = none.
FUNCTION SectorByColor% (col AS _UNSIGNED LONG)
    DIM id AS INTEGER
    SectorByColor = 0
    FOR id = 1 TO 9
        IF col = SECTORS(id).kolor THEN SectorByColor = id: EXIT FUNCTION
    NEXT id
END FUNCTION

SUB LoadSectors
    DIM i AS INTEGER, id AS INTEGER
    ReadDataFile "assets/data/sectors.txt"
    FOR i = 1 TO DLINE_N
        id = VAL(DField$(DLINE(i), 1))
        IF id >= 1 AND id <= 9 THEN
            SECTORS(id).label = DField$(DLINE(i), 2)
            SECTORS(id).start_x = VAL(DField$(DLINE(i), 3))
            SECTORS(id).start_y = VAL(DField$(DLINE(i), 4))
            SECTORS(id).end_x = VAL(DField$(DLINE(i), 5))
            SECTORS(id).end_y = VAL(DField$(DLINE(i), 6))
            SECTORS(id).kolor = HexRGB~&(DField$(DLINE(i), 7))
        END IF
    NEXT i
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
            ' hit-dice HP: a level-scaled range, not a fixed value. min = sec*4+1, and the
            ' die grows with depth (L1 rolls a d6, L9 a d22), so deeper monsters vary more.
            ROOMS(r).mhp = sec * 4 + RollDie(sec * 2 + 4): ROOMS(r).mhp_now = ROOMS(r).mhp
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
    BindSpecialRooms                             ' tie each named-room label to its nearest detected room (flavor crawl + art)
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

' Class balance now lives in assets/data/classes.txt -- edit + F5. Thin wrapper.
SUB InitClasses
    LoadClasses
END SUB

SUB LoadClasses
    DIM i AS INTEGER, id AS INTEGER
    ReadDataFile "assets/data/classes.txt"
    FOR i = 1 TO DLINE_N
        id = VAL(DField$(DLINE(i), 1))
        IF id >= 1 AND id <= 4 THEN
            CLASSES(id).name = DField$(DLINE(i), 2)
            CLASSES(id).gold_goal = VAL(DField$(DLINE(i), 3))
            CLASSES(id).combat_bonus = VAL(DField$(DLINE(i), 4))
            CLASSES(id).secret_bonus = VAL(DField$(DLINE(i), 5))
            CLASSES(id).hp = VAL(DField$(DLINE(i), 6))
            CLASSES(id).tohit = VAL(DField$(DLINE(i), 7))
            CLASSES(id).dmg = VAL(DField$(DLINE(i), 8))
            CLASSES(id).ac = VAL(DField$(DLINE(i), 9))
            CLASSES(id).hitdie = VAL(DField$(DLINE(i), 10))
            CLASSES(id).blurb = DField$(DLINE(i), 11)
        END IF
    NEXT i
END SUB


' Class-select screen reached from the menu's CREATE A CHARACTER option.
' Returns the chosen class index (1-4), or 0 if the player backs out.

FUNCTION SECTOR.get_by_xy% (x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER
    DIM s AS SECTOR
    DIM AS INTEGER sx, ex, sy, ey
    IF SECTORMASK_ON THEN                          ' sector mask: a straight per-cell lookup (0-based, no -1)
        DIM cx AS INTEGER, cy AS INTEGER
        cx = x \ CW: cy = y \ CH
        IF cx >= 0 AND cx <= 131 AND cy >= 0 AND cy <= 60 THEN SECTOR.get_by_xy = SECTORAT(cx, cy) ELSE SECTOR.get_by_xy = 0
        EXIT FUNCTION
    END IF
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
