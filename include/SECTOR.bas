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
    ' --- monsters: name + the exact per-class 2d6 kill numbers from the cards ---
    '     Mob lvl, slot, name, Hero, Elf, Superhero, Wizard   (13 = "-" can't kill barehanded)
    Mob 1, 1, "GIANT RATS", 4, 5, 3, 3
    Mob 1, 2, "GIANT LIZARD", 4, 5, 2, 5
    Mob 1, 3, "GOBLINS", 4, 3, 2, 5
    Mob 2, 1, "SKELETON", 4, 5, 3, 6
    Mob 2, 2, "HOBGOBLINS", 5, 4, 3, 6
    Mob 2, 3, "GIANT SPIDER", 6, 6, 4, 5
    Mob 3, 1, "GHOULS", 6, 5, 4, 6
    Mob 3, 2, "GARGOYLE", 6, 7, 5, 6
    Mob 3, 3, "EVIL HERO", 7, 8, 5, 6
    Mob 4, 1, "EVIL HERO", 7, 8, 5, 6
    Mob 4, 2, "GIANT SNAKE", 8, 10, 6, 9
    Mob 4, 3, "GHOULS", 6, 5, 4, 6
    Mob 5, 1, "WEREWOLF", 9, 9, 7, 7
    Mob 5, 2, "OGRE", 9, 8, 6, 8
    Mob 5, 3, "GIANT SNAKE", 8, 10, 6, 9
    Mob 6, 1, "MUMMY", 10, 11, 8, 8
    Mob 6, 2, "TROLL", 10, 9, 8, 8
    Mob 6, 3, "VAMPIRE", 10, 12, 8, 9
    Mob 7, 1, "GIANT", 11, 10, 9, 10
    Mob 7, 2, "WITCH", 11, 11, 9, 5
    Mob 7, 3, "GREEN SLIME", 11, 13, 10, 11
    Mob 8, 1, "PURPLE WORM", 11, 12, 10, 12
    Mob 8, 2, "BLACK PUDDING", 12, 13, 12, 12
    Mob 8, 3, "MUMMY", 10, 11, 8, 8
    Mob 9, 1, "EVIL WIZARD", 12, 13, 11, 7
    Mob 9, 2, "RED DRAGON", 13, 13, 11, 12
    Mob 9, 3, "BLUE DRAGON", 12, 13, 10, 12

    ' --- treasures: real card names + gold-piece values, richer the deeper you go ---
    SetTre 1, "SILVER CUP", 1000, "SACK OF GOLD", 1000, "SILVER RING", 2000
    SetTre 2, "SILVER RING", 2000, "GOLD CUP", 2500, "GOLD RING", 3000
    SetTre 3, "GOLD RING", 3000, "GOLD CUP", 2500, "SILVER COFFER", 4000
    SetTre 4, "SILVER COFFER", 4000, "JADE IDOL", 5000, "HUGE EMERALD", 5000
    SetTre 5, "HUGE EMERALD", 5000, "JADE IDOL", 5000, "HUGE SAPPHIRE", 6000
    SetTre 6, "HUGE SAPPHIRE", 6000, "SILVER NECKLACE", 7000, "HUGE RUBY", 8000
    SetTre 7, "SILVER NECKLACE", 7000, "HUGE RUBY", 8000, "GOLD NECKLACE", 9000
    SetTre 8, "GOLD NECKLACE", 9000, "HUGE RUBY", 8000, "HUGE DIAMOND", 10000
    SetTre 9, "HUGE DIAMOND", 10000, "GOLD NECKLACE", 9000, "HUGE SAPPHIRE", 6000

    ' special treasure cards seeded into the pools (real cards from the deck).
    ' TRE_ITEM: 1=Sword+1 2=Sword+2 3=SecretDoorCard 4=ESP Medallion 5=Crystal Ball
    TRE_NAME(2, 3) = "MAGIC SWORD +1": TRE_GOLD(2, 3) = 500: TRE_ITEM(2, 3) = 1
    TRE_NAME(3, 3) = "ESP MEDALLION": TRE_GOLD(3, 3) = 500: TRE_ITEM(3, 3) = 4
    TRE_NAME(4, 3) = "SECRET DOOR CARD": TRE_GOLD(4, 3) = 0: TRE_ITEM(4, 3) = 3
    TRE_NAME(5, 3) = "CRYSTAL BALL": TRE_GOLD(5, 3) = 1000: TRE_ITEM(5, 3) = 5
    TRE_NAME(6, 3) = "MAGIC SWORD +2": TRE_GOLD(6, 3) = 500: TRE_ITEM(6, 3) = 2

    BOSS_NAME(1) = "RED DRAGON": BOSS_NAME(2) = "BLUE DRAGON"
    BOSS_NAME(3) = "EVIL WIZARD": BOSS_NAME(4) = "BLACK PUDDING"
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


' Roll fresh room contents: each level's room (sector) gets a random monster +
' treasure from that level's pool; one deep room becomes the boss lair.

SUB RandomizeRooms
    DIM i AS INTEGER, m AS INTEGER, t AS INTEGER, bossroom AS INTEGER
    FOR i = 1 TO 9
        SECTORS(i).monster = "": SECTORS(i).malive = FALSE: SECTORS(i).is_boss = FALSE
        SECTORS(i).looted = FALSE: SECTORS(i).treasure = 0: SECTORS(i).treasure_name = "": SECTORS(i).treasure_item = 0
        SECTORS(i).monster_fought = FALSE: SECTORS(i).player_died = FALSE
    NEXT i
    ' sectors 2..9 correspond to levels 2..9; store the number for THIS player's class
    FOR i = 2 TO 9
        m = RollDie(3): t = RollDie(3)
        SECTORS(i).monster = MON_NAME(i, m): SECTORS(i).mnum = MON_N(i, m, player_class)
        SECTORS(i).malive = TRUE
        SECTORS(i).treasure_name = TRE_NAME(i, t): SECTORS(i).treasure = TRE_GOLD(i, t)
        SECTORS(i).treasure_item = TRE_ITEM(i, t)
        ' D&D-mode stats scale with the level: deeper monsters are tougher and harder to hit
        SECTORS(i).mhp = i * 4 + RollDie(6) + 2: SECTORS(i).mhp_now = SECTORS(i).mhp
        SECTORS(i).mac = 9 + i
    NEXT i
    ' one deep room (levels 6-9) holds the boss + a great hoard. Bosses are "-"
    ' for Hero/Elf (need a Magic Sword) and merely brutal for Superhero/Wizard.
    bossroom = RollDie(4) + 5
    SECTORS(bossroom).is_boss = TRUE
    SECTORS(bossroom).monster = BOSS_NAME(RollDie(4))
    SELECT CASE player_class
        CASE 1, 2: SECTORS(bossroom).mnum = 13
        CASE 3: SECTORS(bossroom).mnum = 11
        CASE ELSE: SECTORS(bossroom).mnum = 12
    END SELECT
    SECTORS(bossroom).treasure_name = "DRAGON'S HOARD"
    SECTORS(bossroom).treasure = SECTORS(bossroom).treasure + 6000
    SECTORS(bossroom).treasure_item = 0
    ' the boss is a brutal D&D fight: fat HP pool, hard to hit
    SECTORS(bossroom).mhp = 45 + bossroom * 3 + RollDie(10): SECTORS(bossroom).mhp_now = SECTORS(bossroom).mhp
    SECTORS(bossroom).mac = 19
END SUB


' Authentic DUNGEON! win totals: Hero/Elf 10k, Superhero 20k, Wizard 30k.

SUB InitClasses
    ' Oldschool fields: combat_bonus/secret_bonus.  D&D fields: hp / tohit / dmg (die sides) / ac.
    ' --- tune the D&D balance here ---
    CLASSES(1).name = "HERO": CLASSES(1).gold_goal = 10000
    CLASSES(1).combat_bonus = 0: CLASSES(1).secret_bonus = 0
    CLASSES(1).blurb = "Solid fighter. Finds secret doors on a 1-2. Needs 10,000 gold."
    CLASSES(1).hp = 24: CLASSES(1).tohit = 4: CLASSES(1).dmg = 8: CLASSES(1).ac = 15: CLASSES(1).hitdie = 10

    CLASSES(2).name = "ELF": CLASSES(2).gold_goal = 10000
    CLASSES(2).combat_bonus = -1: CLASSES(2).secret_bonus = 2
    CLASSES(2).blurb = "Weakest fighter, but finds secret doors on a 1-4. Needs 10,000."
    CLASSES(2).hp = 16: CLASSES(2).tohit = 3: CLASSES(2).dmg = 6: CLASSES(2).ac = 13: CLASSES(2).hitdie = 8

    CLASSES(3).name = "SUPERHERO": CLASSES(3).gold_goal = 20000
    CLASSES(3).combat_bonus = 0: CLASSES(3).secret_bonus = 0
    CLASSES(3).blurb = "The deadliest warrior -- slays monsters on low rolls. Needs 20,000 gold."
    CLASSES(3).hp = 32: CLASSES(3).tohit = 6: CLASSES(3).dmg = 10: CLASSES(3).ac = 17: CLASSES(3).hitdie = 12

    CLASSES(4).name = "WIZARD": CLASSES(4).gold_goal = 30000
    CLASSES(4).combat_bonus = 0: CLASSES(4).secret_bonus = 1
    CLASSES(4).blurb = "Slays with spells; can't use Magic Swords. Needs 30,000 gold."
    CLASSES(4).hp = 14: CLASSES(4).tohit = 5: CLASSES(4).dmg = 10: CLASSES(4).ac = 12: CLASSES(4).hitdie = 6
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
