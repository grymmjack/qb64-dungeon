' ============================================================================
'  SECTOR.bas -- sector geometry, monster/treasure/class data + randomiser
' ============================================================================

' Sector geometry + colours now live in assets/data/sectors.txt -- edit + F5, no
' code change. Thin wrapper over LoadSectors (matches InitMonsterTables' pattern).
SUB InitSectors
    LoadSectors                          ' id / label / colour from the data file -- geometry is DERIVED
END SUB

' Derive every level's rectangle FROM THE BOARD ART.
'
' This replaces two AUTHORED files: the sectors.txt rectangles and the hand-painted
' board-132x50-sector-mask.ans. Both said where a level is; the art already says it, and keeping
' a second copy is what let them DISAGREE -- 12 rooms the art painted at level 5/6 sat under a
' mask claiming level 1, and simply never existed.
'
' Two passes:
'   1. TIGHT box -- the bounding box of every cell painted uniformly in that level's colour.
'   2. EXPAND    -- grow each box a row or column at a time in each direction, stopping when the
'                   next step would touch another level's box or leave the board. This is what
'                   claims the CORRIDORS, which state no colour of their own.
'
' The tight boxes provably never overlap (`dungeon.run sectorauto`), but only when read from the
' COLLISION layer: over the whole picture the logo, legend and frame all paint in level colours
' and the derivation fails 15 ways. So this samples FULL_COLLIDE, never the display board.
'
' The art stays the authority: after the boxes are laid down, any cell actually painted a level
' colour is reassigned to that level. The boxes only fill the silence between the paint.
SUB DeriveSectors
    DIM cx AS INTEGER, cy AS INTEGER, sk AS INTEGER, oldsrc AS LONG, grew AS INTEGER
    DIM bx1(1 TO 9) AS INTEGER, by1(1 TO 9) AS INTEGER, bx2(1 TO 9) AS INTEGER, by2(1 TO 9) AS INTEGER
    DIM cnt(1 TO 9) AS INTEGER
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE
    FOR sk = 1 TO 9: bx1(sk) = 9999: by1(sk) = 9999: bx2(sk) = -1: by2(sk) = -1: cnt(sk) = 0: NEXT sk

    ' 1) tight box per level
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            sk = CellSolidSector%(cx, cy)
            IF sk >= 1 THEN
                IF cx < bx1(sk) THEN bx1(sk) = cx
                IF cy < by1(sk) THEN by1(sk) = cy
                IF cx > bx2(sk) THEN bx2(sk) = cx
                IF cy > by2(sk) THEN by2(sk) = cy
                cnt(sk) = cnt(sk) + 1
            END IF
        NEXT cx
    NEXT cy

    ' 2) expand one step at a time, all levels in lockstep, until nothing can grow. Stepwise and
    '    round-robin so no level can race ahead and swallow ground a neighbour would have reached.
    DO
        grew = 0
        FOR sk = 1 TO 9
            IF cnt(sk) > 0 THEN
                IF bx1(sk) > 0 THEN
                    IF NOT StripHitsOther%(sk, bx1(sk) - 1, by1(sk), bx1(sk) - 1, by2(sk), bx1(), by1(), bx2(), by2(), cnt()) THEN bx1(sk) = bx1(sk) - 1: grew = -1
                END IF
                IF bx2(sk) < SW - 1 THEN
                    IF NOT StripHitsOther%(sk, bx2(sk) + 1, by1(sk), bx2(sk) + 1, by2(sk), bx1(), by1(), bx2(), by2(), cnt()) THEN bx2(sk) = bx2(sk) + 1: grew = -1
                END IF
                IF by1(sk) > 0 THEN
                    IF NOT StripHitsOther%(sk, bx1(sk), by1(sk) - 1, bx2(sk), by1(sk) - 1, bx1(), by1(), bx2(), by2(), cnt()) THEN by1(sk) = by1(sk) - 1: grew = -1
                END IF
                IF by2(sk) < SH - 1 THEN
                    IF NOT StripHitsOther%(sk, bx1(sk), by2(sk) + 1, bx2(sk), by2(sk) + 1, bx1(), by1(), bx2(), by2(), cnt()) THEN by2(sk) = by2(sk) + 1: grew = -1
                END IF
            END IF
        NEXT sk
    LOOP WHILE grew

    ' 3) paint the cell map from the boxes, then let the ART override it
    FOR cy = 0 TO 60: FOR cx = 0 TO 131: SECTORAT(cx, cy) = 0: NEXT cx: NEXT cy
    FOR sk = 1 TO 9
        IF cnt(sk) > 0 THEN
            SECTORS(sk).start_x = bx1(sk): SECTORS(sk).start_y = by1(sk)
            SECTORS(sk).end_x = bx2(sk): SECTORS(sk).end_y = by2(sk)
            FOR cy = by1(sk) TO by2(sk)
                FOR cx = bx1(sk) TO bx2(sk): SECTORAT(cx, cy) = sk: NEXT cx
            NEXT cy
        END IF
    NEXT sk
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            sk = SectorByColor%(POINT(cx * CW + CW \ 2, cy * CH + CH \ 2))
            IF sk >= 1 THEN SECTORAT(cx, cy) = sk
        NEXT cx
    NEXT cy
    _SOURCE oldsrc
    SECTORMASK_ON = -1                   ' geometry is per-cell now, however it was arrived at
END SUB

' Would growing level `me` onto this strip land on any OTHER level's box?
FUNCTION StripHitsOther% (me AS INTEGER, sx AS INTEGER, sy AS INTEGER, ex AS INTEGER, ey AS INTEGER, bx1() AS INTEGER, by1() AS INTEGER, bx2() AS INTEGER, by2() AS INTEGER, cnt() AS INTEGER)
    DIM o AS INTEGER
    StripHitsOther% = 0
    FOR o = 1 TO 9
        IF o <> me AND cnt(o) > 0 THEN
            IF sx <= bx2(o) AND bx1(o) <= ex THEN
                IF sy <= by2(o) AND by1(o) <= ey THEN StripHitsOther% = -1: EXIT FUNCTION
            END IF
        END IF
    NEXT o
END FUNCTION

' Is this cell UNIFORMLY one level's floor colour? That is what makes it evidence of where a
' level IS -- a half-painted lip or a doorway is not. (Was in DATALINT; it is production now.)
FUNCTION CellSolidSector% (cx AS INTEGER, cy AS INTEGER)
    DIM s AS INTEGER
    CellSolidSector% = 0
    s = SectorByColor%(POINT(cx * CW + CW \ 2, cy * CH + CH \ 2))
    IF s < 1 THEN EXIT FUNCTION
    IF CellRoomKind%(cx, cy, SECTORS(s).kolor) = CRK_FLOOR THEN CellSolidSector% = s
END FUNCTION

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
            ' Fields 3-6 (the rectangle) are IGNORED -- DeriveSectors computes the geometry
            ' from the board art and overwrites these. They stay in the file format so existing
            ' data packs still parse; only the id, label and colour are read.
            SECTORS(id).start_x = 0: SECTORS(id).start_y = 0
            SECTORS(id).end_x = 0: SECTORS(id).end_y = 0
            SECTORS(id).kolor = HexRGB~&(DField$(DLINE(i), 7))
        END IF
    NEXT i
END SUB


' Authentic Dungeon! monster roster + treasures, scaled across the 9 levels.
' Values approximate the board game (exact card numbers live on the cards).

SUB InitMonsterTables
    ' The bestiary, treasure pools, magic items and boss names now live in the
    ' editable files under assets/data/ -- edit those and press F5. LoadTreasures
    ' fills the 3 gold slots per level; LoadItems fills each level's separate weighted
    ' ITEM POOL (items no longer override a slot -- see items.txt / tuning.txt ITEM_PCT_n).
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


' ============================================================================
'  MONSTER SCALING -- one funnel for every spawn (D&D mode).
'
'  The HP / AC / to-hit formulas were duplicated as bare literals at five spawn sites: the
'  room monster and the boss lair here, the wandering ambush and the chamber guardian in
'  game/PLAY.bas, and the mimic in game/CURIO.bas. Nothing tied them together, so a level-8
'  chamber LORD quietly compounded three separate multipliers into a 70 HP / AC 18 / +10
'  monster that no single site looked unreasonable on its own.
'
'  Now every spawn asks here, every number is a tuning.txt knob, and there are CAPS -- because
'  the failure mode that matters is not "a hard monster", it is a monster whose AC or to-hit
'  has outrun what any hero at that depth can answer, which reads as the game cheating.
'
'  `kind`: MK_ROOM ordinary lair | MK_BOSS the one boss | MK_LORD a chamber lord |
'          MK_WANDER a wandering ambush | MK_MIMIC a curio that bites back.
' ============================================================================

' Roll this monster's hit points and armour class. Rolls exactly ONE die (or two for a boss),
' so the seeded RNG sequence a save/load rebuild depends on stays predictable per call.
SUB MonsterStats (lvl AS INTEGER, kind AS INTEGER, hpOut AS INTEGER, acOut AS INTEGER)
    DIM lv AS INTEGER, hp AS INTEGER, ac AS INTEGER, sides AS INTEGER
    lv = lvl: IF lv < 1 THEN lv = 1
    IF lv > 9 THEN lv = 9
    IF kind = MK_BOSS THEN
        hp = BOSS_HP_BASE + lv * BOSS_HP_PER_LVL + RollDie(10)
        ac = BOSS_AC
        hpOut = hp: acOut = ac
        EXIT SUB                                  ' the boss's AC is exempt from MON_AC_MAX: it IS the wall
    END IF
    sides = MON_HP_DIE_BASE + lv * MON_HP_DIE_STEP: IF sides < 1 THEN sides = 1
    hp = lv * MON_HP_PER_LVL + RollDie(sides)
    ac = MON_AC_BASE + lv
    SELECT CASE kind
        CASE MK_LORD
            hp = hp * LORD_HP_PCT \ 100
            ac = ac + LORD_AC_BONUS
        CASE MK_WANDER
            ac = ac + WANDER_AC_BONUS
        CASE MK_MIMIC
            hp = lv * MIMIC_HP_PER_LVL + RollDie(6) + 6   ' a beefy ambusher, its own curve
            ac = MIMIC_AC_BASE + lv
    END SELECT
    IF hp < 1 THEN hp = 1
    IF ac > MON_AC_MAX THEN ac = MON_AC_MAX
    hpOut = hp: acOut = ac
END SUB

' The monster's bonus on its d20 attack roll. Capped for the same reason AC is: past a point
' the player's own AC stops mattering at all and every round is a coin flip armour cannot answer.
FUNCTION MonsterToHit% (lvl AS INTEGER, kind AS INTEGER)
    DIM t AS INTEGER, lv AS INTEGER
    lv = lvl: IF lv < 1 THEN lv = 1
    IF lv > 9 THEN lv = 9
    t = lv
    IF kind = MK_BOSS THEN t = t + BOSS_TOHIT_BONUS
    IF kind = MK_LORD THEN t = t + LORD_TOHIT_BONUS
    IF t > MON_TOHIT_MAX THEN t = MON_TOHIT_MAX
    MonsterToHit% = t
END FUNCTION


' Roll fresh room contents: each level's room (sector) gets a random monster +
' treasure from that level's pool; one deep room becomes the boss lair.

SUB RandomizeRooms
    DIM ip AS INTEGER, ipick AS INTEGER          ' item-pool draw (see the treasure block below)
    ' EVERY detected room gets its own monster + treasure from its level's pool.
    ' (Call DetectRooms first -- done in StartBoard/InitFog -- so ROOMS is populated.)
    DIM r AS INTEGER, sec AS INTEGER, m AS INTEGER, t AS INTEGER, startroom AS INTEGER
    DIM bossroom AS INTEGER, ndeep AS INTEGER, sl AS INTEGER
    DIM deeproom(1 TO 400) AS INTEGER
    DIM used(1 TO 9, 1 TO 3) AS INTEGER         ' D&D variety: how often each level's monster has been placed
    ' (There is no size gate any more. `cells < 4` used to stand in for "this block is a label,
    ' not a room" -- a proxy that was wrong in both directions: it emptied genuine 3-cell rooms
    ' and waved through every 4-cell level plaque. DropDecorRooms now decides room-ness properly,
    ' by whether the block has anywhere to STAND, and it does it at detection -- so by the time
    ' we get here every entry in ROOMS() is a real room and every one of them gets a monster.)
    startroom = ROOMAT(START_CX, START_CY)      ' the entrance chamber stays safe
    ndeep = 0
    FOR r = 1 TO ROOM_N
        sec = ROOMS(r).sec
        ROOMS(r).monster_fought = FALSE: ROOMS(r).player_died = FALSE
        ROOMS(r).looted = FALSE: ROOMS(r).is_boss = FALSE: ROOMS(r).seen = FALSE
        ClearRoomDrop r
        ' The ONLY room without an encounter is the entrance -- everything else in ROOMS() is a
        ' real room and gets a monster. DropDecorRooms has already discarded the level plaques,
        ' and RoomIsDecor% here is a belt-and-braces guard for a board where it somehow did not
        ' run. A "room" with nothing in it is a dead end for the player, so there are none.
        IF r = startroom OR RoomIsDecor%(r) THEN
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
            ' Gold treasure by default; a magic ITEM instead with ITEM_PCT(sec) chance,
            ' drawn from that level's weighted pool. HOW OFTEN (tuning.txt ITEM_PCT_<n>) and
            ' WHICH (the item's `weight` in items.txt) are now independent knobs -- items used
            ' to OVERRIDE a treasure slot, so frequency was a slot POSITION: only 0/33/66/100%
            ' was expressible, and a level with 3 item slots could never yield gold at all.
            ' Nested IFs, not `AND`: QB64's AND does not short-circuit, and PctChance% consumes
            ' a die roll -- inside an AND it would burn one even when the pool is empty, which
            ' would shift the seeded RNG sequence that save/load relies on to rebuild the board.
            ROOMS(r).treasure_name = TRE_NAME(sec, t): ROOMS(r).treasure = TRE_GOLD(sec, t)
            ROOMS(r).treasure_item = 0
            IF ITM_N(sec) > 0 THEN
                IF PctChance%(ITEM_PCT(sec)) THEN
                    REDIM iw(1 TO ITM_N(sec)) AS INTEGER
                    FOR ip = 1 TO ITM_N(sec): iw(ip) = ITM_W(sec, ip): NEXT ip
                    ipick = WeightPick%(iw(), ITM_N(sec))
                    IF ipick >= 1 THEN
                        ROOMS(r).treasure_name = ITM_NAME(sec, ipick)
                        ROOMS(r).treasure = ITM_GOLD(sec, ipick)
                        ROOMS(r).treasure_item = ITM_CODE(sec, ipick)
                    END IF
                END IF
            END IF
            ' hit-dice HP: a level-scaled range, not a fixed value. The die grows with depth
            ' (L1 rolls a d6, L9 a d22 at the shipped knobs), so deeper monsters vary more.
            MonsterStats sec, MK_ROOM, ROOMS(r).mhp, ROOMS(r).mac
            ROOMS(r).mhp_now = ROOMS(r).mhp
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
        MonsterStats sec, MK_BOSS, ROOMS(bossroom).mhp, ROOMS(bossroom).mac
        ROOMS(bossroom).mhp_now = ROOMS(bossroom).mhp
    END IF

    ' -- the LEVEL KEY: the prize of one random room on a DEEP level (never the
    ' entrance level 1, never the boss), so winning requires descending. Its exact
    ' room is pinpointed by the Crystal Ball; otherwise only its level is hinted.
    DIM kcand(1 TO 400) AS INTEGER, nk AS INTEGER
    key_room = 0: key_level = 0: nk = 0
    ' REACHABILITY GUARD. Killing the monster in key_room is the ONLY way to get the key
    ' (ClaimTreasure code 6 -- DoSearch does not grant it), so a key in an unreachable room
    ' makes the run unwinnable with no feedback. A room can be unreachable if it sits in a
    ' hand-painted secret REGION that no secret door opens; the mask is art, so an edit can
    ' orphan a region silently. `dungeon.run fogdump` reports any such region.
    FOR r = 1 TO ROOM_N
        IF ROOMS(r).malive AND ROOMS(r).sec >= 2 AND NOT ROOMS(r).is_boss THEN
            IF RoomReachable%(r) THEN nk = nk + 1: kcand(nk) = r
        END IF
    NEXT r
    IF nk = 0 THEN                               ' relax the depth rule, keep the reachability rule
        FOR r = 1 TO ROOM_N
            IF ROOMS(r).malive AND NOT ROOMS(r).is_boss THEN
                IF RoomReachable%(r) THEN nk = nk + 1: kcand(nk) = r
            END IF
        NEXT r
    END IF
    IF nk = 0 THEN                               ' last resort: any live room at all, reachable or not
        FOR r = 1 TO ROOM_N                      ' (better an awkward key than no key placed)
            IF ROOMS(r).malive THEN nk = nk + 1: kcand(nk) = r
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

' Which level owns this pixel? A straight per-cell lookup into SECTORAT, which DeriveSectors
' fills from the board art. There is no rectangle fallback any more and no mask file: both were
' AUTHORED copies of what the art already states, and the copies could disagree with it.
'
' Stays PURE -- the board build, the FOV caster and the debug mouse readout all ask it about
' arbitrary cells with no player in existence. The stickiness that covers an unclaimed corridor
' lives in PlayerLevel%, never here.
FUNCTION SECTOR.get_by_xy% (x AS INTEGER, y AS INTEGER)
    DIM cx AS INTEGER, cy AS INTEGER
    SECTOR.get_by_xy = 0
    cx = x \ CW: cy = y \ CH
    IF cx < 0 OR cx > 131 OR cy < 0 OR cy > 60 THEN EXIT FUNCTION
    SECTOR.get_by_xy = SECTORAT(cx, cy)
END FUNCTION


' ============================================================================
'  HUD + UI HELPERS
' ============================================================================

' Game hook (#8) -- the game claims its regions on the freshly-painted board. The engine's
' board setup calls this ONE hook and stays out of "what a region is"; the game owns both of
' its region kinds:
'   ROOMS    -- flood-fill each sector-colour block (DetectRooms, below); monster + treasure.
'   CHAMBERS -- the big named halls (game/CHAMBERS.bas); 3 monsters, no treasure.
' Both were once inlined in engine/BOARD.bas, which meant the engine wrote the game's
' ROOMS/CHAMBERAT arrays directly. Order matters: rooms first (chambers read SECTOR/label state).
SUB Game_PopulateBoard
    DeriveSectors                        ' level geometry from the art -- must precede DetectChambers
    DetectRooms
    DetectChambers
END SUB

SUB DetectRooms
    DIM cx AS INTEGER, cy AS INTEGER, sec AS INTEGER
    DIM oldsrc AS LONG
    ROOM_N = 0
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1: ROOMAT(cx, cy) = 0: NEXT cx
    NEXT cy
    oldsrc = _SOURCE: _SOURCE FULL_COLLIDE
    FOR cy = 1 TO SH - 2
        FOR cx = 1 TO SW - 1
            IF ROOMAT(cx, cy) = 0 THEN
                ' The ART states the level: seed wherever a cell is painted one of the nine
                ' level colours, and take the level FROM that colour. Asking geometry first
                ' ("which sector covers this cell?") and demanding the paint agree is what
                ' stranded the LOST ROOMS -- where the two disagreed, the room simply never
                ' existed. Geometry is still the answer for CORRIDORS, which state no colour.
                sec = SectorByColor%(POINT(cx * CW + CW \ 2, cy * CH + CH \ 2))
                IF sec >= 1 THEN
                    IF ROOM_N < UBOUND(ROOMS) THEN
                        ROOM_N = ROOM_N + 1
                        FloodRoom cx, cy, sec, ROOM_N
                    END IF
                END IF
            END IF
        NEXT cx
    NEXT cy
    ' Every block is flooded now, so the whole-cell colour tests can run once and seat each
    ' room's marker on real interior floor (see PlaceRoomMarkers). Then discard the blocks that
    ' turned out to be decoration, so ROOMS() holds nothing but real rooms.
    PlaceRoomMarkers
    DropDecorRooms
    _SOURCE oldsrc
END SUB


' Enqueue one room cell if it is unclaimed and the right colour.
' (Was left behind in engine/BOARD.bas when DetectRooms/FloodRoom moved here -- it writes
' ROOMAT, so it is game code and belongs beside its only caller.)
SUB RoomVisit (x AS INTEGER, y AS INTEGER, sec AS INTEGER, rid AS INTEGER, kol AS _UNSIGNED LONG, tail AS INTEGER)
    IF x < 0 OR x > SW - 1 OR y < 0 OR y > SH - 1 THEN EXIT SUB
    IF ROOMAT(x, y) <> 0 THEN EXIT SUB
    IF POINT(x * CW + CW \ 2, y * CH + CH \ 2) <> kol THEN EXIT SUB
    ' No sector test: the block's COLOUR defines it. Requiring the geometry to agree also split
    ' single painted rooms in two wherever a sector boundary happened to cross them.
    ROOMAT(x, y) = rid
    QX(tail) = x: QY(tail) = y: tail = tail + 1
END SUB

' BFS one room block (same sector + colour, 4-connected); record its centre cell.
SUB FloodRoom (sx AS INTEGER, sy AS INTEGER, sec AS INTEGER, rid AS INTEGER)
    DIM head AS INTEGER, tail AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM minx AS INTEGER, maxx AS INTEGER, miny AS INTEGER, maxy AS INTEGER
    DIM kol AS _UNSIGNED LONG
    kol = SECTORS(sec).kolor
    head = 0: tail = 0
    QX(0) = sx: QY(0) = sy: ROOMAT(sx, sy) = rid: tail = 1
    minx = sx: maxx = sx: miny = sy: maxy = sy
    DO WHILE head < tail
        x = QX(head): y = QY(head): head = head + 1
        IF x < minx THEN minx = x
        IF x > maxx THEN maxx = x
        IF y < miny THEN miny = y
        IF y > maxy THEN maxy = y
        RoomVisit x - 1, y, sec, rid, kol, tail
        RoomVisit x + 1, y, sec, rid, kol, tail
        RoomVisit x, y - 1, sec, rid, kol, tail
        RoomVisit x, y + 1, sec, rid, kol, tail
    LOOP
    ROOMS(rid).sec = sec
    ROOMS(rid).cells = tail                 ' block size (tail = cells enqueued)
    ' Provisional marker: the enqueued cell nearest the bbox centre. The bounding-box centre
    ' itself can land on a WALL for an L-shaped block, so snap to a real cell of the block.
    ' PlaceRoomMarkers (called once after every block is flooded) then REPLACES this with an
    ' interior plain-floor cell -- this one is only the centre reference it aims for.
    DIM ccx AS INTEGER, ccy AS INTEGER, bi AS INTEGER, qi AS INTEGER
    DIM bestd AS LONG, dd AS LONG
    ccx = (minx + maxx) \ 2: ccy = (miny + maxy) \ 2
    bi = 0: bestd = 2147483647
    FOR qi = 0 TO tail - 1
        dd = (QX(qi) - ccx) * (QX(qi) - ccx) + (QY(qi) - ccy) * (QY(qi) - ccy)
        IF dd < bestd THEN bestd = dd: bi = qi
    NEXT qi
    ROOMS(rid).cx = QX(bi): ROOMS(rid).cy = QY(bi)
END SUB


' ============================================================================
'  Seat every room's MARKER (where its monster glyph and its headstone are drawn) and record
'  how much PLAIN FLOOR each block really has. Runs once, after DetectRooms has flooded every
'  block, because it needs whole-cell colour tests and those are far too slow to repeat.
'
'  WHY THE OLD CHOICE WAS WRONG. FloodRoom picked "the enqueued cell nearest the bbox centre",
'  believing every enqueued cell was walkable floor. It is not: the flood enqueues a cell whose
'  CENTRE PIXEL is the floor colour, while movement demands the WHOLE cell be floor. The board
'  art draws room lips with half-block glyphs and prints the level plaques ("4th", "5th") as
'  letters on a block of level colour -- both of which pass the centre-pixel test and fail the
'  whole-cell one. So the "centre" cell could be:
'
'    * a decorative half-block lip -> the monster sat somewhere nothing can stand, so the room
'      never fired an encounter and never grew a headstone (rooms 45, 81, 93 ...)
'    * a DOORWAY -> walkable, but the grave then sits in the door rather than in the room
'      (rooms 40, 56, 71, 80 ...)
'
'  The fix is to score candidates instead of taking the nearest: only PLAIN FLOOR qualifies,
'  the most enclosed cell wins (which is what "inside the room" means), and closeness to the
'  block's centre is only the tie-break. A block with no plain floor at all keeps its
'  provisional marker for the debug overlays and is failed by RoomIsDecor%.
' ============================================================================
SUB PlaceRoomMarkers
    DIM cx AS INTEGER, cy AS INTEGER, r AS INTEGER, sc AS LONG
    DIM bestsc(1 TO 400) AS LONG, bestx(1 TO 400) AS INTEGER, besty(1 TO 400) AS INTEGER
    DIM refx(1 TO 400) AS INTEGER, refy(1 TO 400) AS INTEGER
    FOR r = 1 TO ROOM_N
        bestsc(r) = -1
        refx(r) = ROOMS(r).cx: refy(r) = ROOMS(r).cy    ' FloodRoom's centre-most cell
        ROOMS(r).floor_cells = 0
    NEXT r
    '--- classify every room cell once ---------------------------------------
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            ROOMKIND(cx, cy) = CRK_NONE
            r = ROOMAT(cx, cy)
            IF r >= 1 AND r <= ROOM_N THEN
                IF ROOMS(r).sec >= 1 THEN ROOMKIND(cx, cy) = CellRoomKind%(cx, cy, SECTORS(ROOMS(r).sec).kolor)
            END IF
        NEXT cx
    NEXT cy
    '--- count plain floor + score each candidate ----------------------------
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            IF ROOMKIND(cx, cy) = CRK_FLOOR THEN
                r = ROOMAT(cx, cy)
                IF r >= 1 AND r <= ROOM_N THEN
                    ROOMS(r).floor_cells = ROOMS(r).floor_cells + 1
                    sc = MarkerScore&(cx, cy, r, refx(r), refy(r))
                    IF sc > bestsc(r) THEN bestsc(r) = sc: bestx(r) = cx: besty(r) = cy
                END IF
            END IF
        NEXT cx
    NEXT cy
    FOR r = 1 TO ROOM_N
        IF bestsc(r) >= 0 THEN ROOMS(r).cx = bestx(r): ROOMS(r).cy = besty(r)
    NEXT r
END SUB


' How good a marker cell is (cx,cy) for room r? Enclosure dominates and distance from the
' block's centre only breaks ties -- an edge or doorway-adjacent cell loses to a cell with
' floor on all sides, which is exactly "move it inward". refx/refy is the block's centre-most
' cell; the 10000 multiplier keeps enclosure above any distance a 132x51 board can produce.
FUNCTION MarkerScore& (cx AS INTEGER, cy AS INTEGER, r AS INTEGER, refx AS INTEGER, refy AS INTEGER)
    DIM dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER, encl AS INTEGER, dd AS LONG
    FOR dy = -1 TO 1
        FOR dx = -1 TO 1
            IF dx <> 0 OR dy <> 0 THEN
                nx = cx + dx: ny = cy + dy
                IF nx >= 0 AND nx <= SW - 1 AND ny >= 0 AND ny <= SH - 1 THEN
                    IF ROOMAT(nx, ny) = r THEN
                        IF ROOMKIND(nx, ny) = CRK_FLOOR THEN encl = encl + 1
                    END IF
                END IF
            END IF
        NEXT dx
    NEXT dy
    dd = (cx - refx) * (cx - refx) + (cy - refy) * (cy - refy)
    MarkerScore& = encl * 10000& - dd
END FUNCTION


' TRUE if a block is DECORATION rather than a room: it has no plain-floor cell, so there is
' nowhere in it to stand. The level plaques are exactly this -- a block of level colour with
' "4th" printed on it -- and they used to be handed a monster and a hoard like any other room,
' quietly parking that content where nobody could ever reach it. `cells` cannot see this: a
' plaque is 4 cells, comfortably over MIN_ROOM.
FUNCTION RoomIsDecor% (r AS INTEGER)
    RoomIsDecor% = 0
    IF r < 1 OR r > ROOM_N THEN EXIT FUNCTION
    IF ROOMS(r).floor_cells < 1 THEN RoomIsDecor% = -1
END FUNCTION


' Throw the DECORATION blocks out of ROOMS() entirely and renumber what is left.
'
' Merely refusing to give them a monster was not enough: they stayed in ROOMS(), stayed in
' ROOMAT(), and stayed in ROOM_N, so every "for each room" loop in the game carried eleven
' entries that were not rooms -- inert, but real enough to be counted, drawn over, chosen from,
' and to make "rooms holding no monster: 11" a true statement. A block with nowhere to stand is
' not a room, so it should not be one. After this, EVERY entry in ROOMS() is a real room and
' every real room gets a monster.
'
' Must run AFTER PlaceRoomMarkers (which computes floor_cells) and BEFORE RandomizeRooms.
SUB DropDecorRooms
    DIM r AS INTEGER, keep AS INTEGER, cx AS INTEGER, cy AS INTEGER, old AS INTEGER
    DIM remap(0 TO 400) AS INTEGER
    DECOR_N = 0
    keep = 0
    remap(0) = 0
    FOR r = 1 TO ROOM_N
        IF RoomIsDecor%(r) THEN
            remap(r) = 0                     ' its cells become plain board again
            DECOR_N = DECOR_N + 1
        ELSE
            keep = keep + 1
            remap(r) = keep
            IF keep <> r THEN ROOMS(keep) = ROOMS(r)   ' UDT copy: the whole record moves down
        END IF
    NEXT r
    IF DECOR_N = 0 THEN EXIT SUB             ' nothing dropped -- leave ROOMAT untouched
    FOR cy = 0 TO SH - 1
        FOR cx = 0 TO SW - 1
            old = ROOMAT(cx, cy)
            IF old >= 1 AND old <= ROOM_N THEN ROOMAT(cx, cy) = remap(old)
        NEXT cx
    NEXT cy
    FOR r = keep + 1 TO ROOM_N               ' clear the tail so a stale record cannot be read
        ROOMS(r).sec = 0: ROOMS(r).cells = 0: ROOMS(r).floor_cells = 0
        ROOMS(r).monster = "": ROOMS(r).malive = FALSE
        ROOMS(r).treasure = 0: ROOMS(r).treasure_name = "": ROOMS(r).treasure_item = 0
    NEXT r
    ROOM_N = keep
END SUB


' ============================================================================
'  WHICH LEVEL IS THE PLAYER ON? -- the sticky answer.
'
'  SECTOR.get_by_xy is a PURE question about a position, and it must stay that way: the board
'  build, the FOV caster and the debug mouse readout all ask it about arbitrary cells, with no
'  player in existence. So the stickiness lives HERE, at the player, and never inside the
'  lookup itself.
'
'  A coloured room cell states its own level. A yellow CORRIDOR cell does not -- it only has a
'  level if the sector mask paints one under it or a sectors.txt rect covers it, and 96 of the
'  board's 3156 walkable cells satisfy neither (`dungeon.run sectorauto` measures it). Those
'  cells used to answer 0, which is not a level: the HUD read "LEVEL 0", PlayLevelMusic had no
'  track to switch to, and WanderEncounter clamped an ambush there to level 1 regardless of how
'  deep the player actually was.
'
'  The rule: resolve normally, and whenever that succeeds, REMEMBER it. When it fails, you are
'  in an unclaimed corridor -- so you are still on the level you walked in from. The mask and
'  the rects stay exactly as authoritative as they were; this only fills their gaps.
'
'  Consequence worth knowing: walk out of level 9 into an unclaimed corridor and a wandering
'  monster there is a LEVEL 9 monster, not a level 1 one. You dragged the depth out with you.
FUNCTION PlayerLevel% ()
    DIM s AS INTEGER
    s = SECTOR.get_by_xy(c.x, c.y)
    IF s >= 1 THEN cur_level = s                  ' a claimed cell -- this is now the known level
    IF cur_level < 1 THEN cur_level = 1           ' never resolved yet (a run starting in a gap)
    PlayerLevel% = cur_level
END FUNCTION


' Re-seed the sticky level from a position. Called when a seat takes over in hot-seat play, so
' player 2 does not inherit player 1's depth: each seat's level comes from where IT stands.
SUB SeedPlayerLevel (px AS INTEGER, py AS INTEGER)
    DIM s AS INTEGER
    s = SECTOR.get_by_xy(px, py)
    IF s >= 1 THEN cur_level = s ELSE cur_level = 0    ' 0 = unknown; PlayerLevel% floors it at 1
END SUB


' Can the player actually get to this room? A room in the PUBLIC area always yes. A room
' inside a hand-painted secret REGION needs some secret door to open that region -- if the
' mask paints a region no door touches, nothing in it is ever reachable.
' Only meaningful when the secret MASK is in use; with the flood fallback every sealed cell
' is door-connected by construction, so everything is reachable.
FUNCTION RoomReachable% (r AS INTEGER)
    DIM reg AS INTEGER
    RoomReachable% = -1
    IF NOT MASK_ON THEN EXIT FUNCTION
    IF r < 1 OR r > ROOM_N THEN EXIT FUNCTION
    reg = MASKREG(ROOMS(r).cx, ROOMS(r).cy)
    IF reg <= 0 THEN EXIT FUNCTION                    ' public area
    IF NOT RegionHasDoor%(reg) THEN RoomReachable% = 0
END FUNCTION

' Does any detected secret door open region `reg`? (DOOR_REGION is filled by InitFog.)
FUNCTION RegionHasDoor% (reg AS INTEGER)
    DIM i AS INTEGER
    RegionHasDoor% = 0
    FOR i = 1 TO SD_N
        IF DOOR_REGION(i) = reg THEN RegionHasDoor% = -1: EXIT FUNCTION
    NEXT i
END FUNCTION
