' ============================================================================
'  DATALINT.bas -- `dungeon.run datalint`: validate the loaded CONTENT tables.
'
'  Everything about this game is data (assets/data/<pack>/*.txt), and a data-pack IS a
'  whole game -- so a content mistake is as real a bug as a code one, and far quieter.
'  It never crashes; the level just plays wrong. This checks the tables AFTER they load,
'  so it validates the ACTIVE data pack, not the files on disk.
'
'  Only OBJECTIVE errors are reported -- things that make data unreachable or malformed.
'  Balance ("is a Fire Ball scroll too strong for level 2?") is a design call and is
'  deliberately not linted.
'
'  The check that motivated this: items.txt used to OVERRIDE a treasure slot, and a room
'  rolls 1 of its level's 3 slots uniformly -- so a level whose 3 slots were all items could
'  NEVER yield a gold treasure card, and its treasures.txt rows were dead data. That had
'  silently happened to levels 5, 6 and 8. Items now live in a separate per-level POOL with
'  its own drop chance (ITEM_PCT_<n>), which removes that failure mode by construction; the
'  checks here cover the new ones -- a chance with no pool, a pool with no chance, a
'  zero-weight entry that can never be drawn, and a 100% chance that starves gold.
' ============================================================================

SUB DataLint
    DIM lvl AS INTEGER, slot AS INTEGER, nitem AS INTEGER, errs AS INTEGER, warns AS INTEGER
    DIM i AS INTEGER, nm AS STRING, code AS INTEGER, goldslots AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15datalint|07 -- validating the loaded content tables (data pack: |11" + _TRIM$(opt_datapack) + "|07)")
    PRINT

    '--- treasure slots + the magic-item POOL ---------------------------------
    ' Items no longer override a treasure slot, so every treasures.txt row is reachable by
    ' construction. What CAN go wrong now: a level with a drop chance but no pool to draw
    ' from (silently never yields an item), or a pool with no chance (dead rows).
    PRINT PipeCol$("|11item drop odds|07 (ITEM_PCT_<n> = how often; items.txt weight = which)")
    IF ITEMS_OLDFMT THEN
        PRINT PipeCol$("  |14!!|07 items.txt uses the LEGACY `lvl | slot | name | gold | type` layout.")
        PRINT PipeCol$("       It still loads (slot ignored, equal weights), but migrate to")
        PRINT PipeCol$("       `lvl | name | gold | type | weight` to control rarity.")
        warns = warns + 1
    END IF
    FOR lvl = 1 TO 9
        nitem = ITM_N(lvl)
        IF ITEM_PCT(lvl) > 0 AND nitem = 0 THEN
            PRINT PipeCol$("  |12!! level " + LTRIM$(STR$(lvl)) + "|07: ITEM_PCT is " + LTRIM$(STR$(ITEM_PCT(lvl))) + "% but the item pool is EMPTY -- it can never yield an item")
            errs = errs + 1
        ELSEIF ITEM_PCT(lvl) = 0 AND nitem > 0 THEN
            PRINT PipeCol$("  |14!! level " + LTRIM$(STR$(lvl)) + "|07: " + LTRIM$(STR$(nitem)) + " item(s) in the pool but ITEM_PCT is 0 -- those rows are dead")
            warns = warns + 1
        ELSEIF ITEM_PCT(lvl) >= 100 THEN
            PRINT PipeCol$("  |12!! level " + LTRIM$(STR$(lvl)) + "|07: ITEM_PCT is " + LTRIM$(STR$(ITEM_PCT(lvl))) + "% -- this level can never yield a GOLD treasure card")
            errs = errs + 1
        ELSE
            PRINT PipeCol$("  |10ok|07 level " + LTRIM$(STR$(lvl)) + ": " + LTRIM$(STR$(ITEM_PCT(lvl))) + "% item chance from a pool of " + LTRIM$(STR$(nitem)))
        END IF
        ' a pool entry that can never be drawn
        FOR slot = 1 TO nitem
            IF ITM_W(lvl, slot) <= 0 THEN
                PRINT PipeCol$("  |14!!|07 " + _TRIM$(ITM_NAME(lvl, slot)) + " (level " + LTRIM$(STR$(lvl)) + ") has weight 0 -- never drawn")
                warns = warns + 1
            END IF
            code = ITM_CODE(lvl, slot)
            ' 1..5, 7..13 are handled by ClaimTreasure; 6 (Level Key) is placed dynamically
            IF code < 1 OR code > 13 OR code = 6 THEN
                PRINT PipeCol$("  |12!!|07 " + _TRIM$(ITM_NAME(lvl, slot)) + " (level " + LTRIM$(STR$(lvl)) + ") has unhandled type code " + LTRIM$(STR$(code)))
                errs = errs + 1
            END IF
        NEXT slot
    NEXT lvl
    PRINT

    '--- every slot must actually be filled -----------------------------------
    PRINT PipeCol$("|11table completeness|07")
    FOR lvl = 1 TO 9
        FOR slot = 1 TO 3
            IF LEN(_TRIM$(TRE_NAME(lvl, slot))) = 0 THEN
                PRINT PipeCol$("  |12!!|07 treasure slot " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " has no name")
                errs = errs + 1
            END IF
            IF LEN(_TRIM$(MON_NAME(lvl, slot))) = 0 THEN
                PRINT PipeCol$("  |12!!|07 monster slot " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " has no name")
                errs = errs + 1
            END IF
        NEXT slot
    NEXT lvl

    '--- a gold slot worth 0 is a silent dud ----------------------------------
    FOR lvl = 1 TO 9
        FOR slot = 1 TO 3
            IF TRE_ITEM(lvl, slot) = 0 AND TRE_GOLD(lvl, slot) <= 0 THEN
                PRINT PipeCol$("  |14!!|07 treasure " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " (" + _TRIM$(TRE_NAME(lvl, slot)) + ") is worth 0 gold and is not an item")
                warns = warns + 1
            END IF
        NEXT slot
    NEXT lvl

    ' (item type codes are checked per POOL entry above -- treasure slots are always gold)

    '--- chamber event table --------------------------------------------------
    ' Mechanics are keyed by `kind`; a typo'd kind silently never fires (ChamberEventKind$
    ' returns it, the SELECT CASE has no branch, and you get a gauntlet instead).
    PRINT PipeCol$("|11chamber events|07")
    IF NCHMEV <= 0 THEN
        PRINT PipeCol$("  |14!!|07 no chamber-events.txt loaded -- chambers fall back to gauntlet-only")
        warns = warns + 1
    ELSE
        DIM gw AS INTEGER, tw AS INTEGER, kk AS STRING
        FOR i = 1 TO NCHMEV
            kk = _TRIM$(CHM_EV(i).kind)
            tw = tw + CHM_EV(i).weight
            IF kk = "gauntlet" THEN gw = gw + CHM_EV(i).weight
            SELECT CASE kk
                CASE "gauntlet", "shrine", "hazard", "boon", "lord"
                CASE ELSE
                    PRINT PipeCol$("  |12!!|07 event '" + kk + "' has no mechanic in code -- it would silently play as a gauntlet")
                    errs = errs + 1
            END SELECT
            IF CHM_EV(i).weight <= 0 THEN
                PRINT PipeCol$("  |14!!|07 event '" + kk + "' has weight " + LTRIM$(STR$(CHM_EV(i).weight)) + " -- it can never be drawn")
                warns = warns + 1
            END IF
            IF CHM_EV(i).maxlvl > 0 AND CHM_EV(i).minlvl > CHM_EV(i).maxlvl THEN
                PRINT PipeCol$("  |12!!|07 event '" + kk + "' has minlvl > maxlvl -- eligible at NO depth")
                errs = errs + 1
            END IF
        NEXT i
        IF gw <= 0 THEN
            PRINT PipeCol$("  |12!!|07 no 'gauntlet' entry with weight -- chambers would stop spawning monsters")
            errs = errs + 1
        ELSEIF tw > 0 THEN
            PRINT PipeCol$("  |10ok|07 " + LTRIM$(STR$(NCHMEV)) + " event(s); gauntlet is " + LTRIM$(STR$(gw * 100 / tw)) + "% of the weight")
        END IF
    END IF
    PRINT

    '--- classes -------------------------------------------------------------
    FOR i = 1 TO UBOUND(CLASSES)
        nm = _TRIM$(CLASSES(i).name)
        IF LEN(nm) = 0 THEN
            PRINT PipeCol$("  |12!!|07 class " + LTRIM$(STR$(i)) + " has no name")
            errs = errs + 1
        ELSEIF CLASSES(i).gold_goal <= 0 THEN
            PRINT PipeCol$("  |12!!|07 class " + nm + " has a win goal of " + LTRIM$(STR$(CLASSES(i).gold_goal)) + " -- unwinnable/instant-win")
            errs = errs + 1
        END IF
    NEXT i
    IF errs = 0 AND warns = 0 THEN PRINT PipeCol$("  |10ok|07 everything else checks out")
    PRINT

    IF errs > 0 THEN
        PRINT PipeCol$("|12datalint: " + LTRIM$(STR$(errs)) + " error(s)|07, " + LTRIM$(STR$(warns)) + " warning(s)")
        SYSTEM 1
    END IF
    PRINT PipeCol$("|10datalint: clean|07 (" + LTRIM$(STR$(warns)) + " warning(s))")
    SYSTEM 0
END SUB


' ============================================================================
'  `dungeon.run econdump` -- what does the gold economy actually look like?
'
'  Written because decoupling item drops from treasure slots CHANGED the economy's shape
'  (more gold treasure cards, fewer magic items, fewer duplicate-item sales), and the honest
'  answer to "did that break win pacing?" was "play twenty games and see". This computes it
'  instead, from the SAME tables and odds the game uses.
'
'  It reports EXPECTED values, not a simulation: expected gold per room on a level is
'    (1 - ITEM_PCT/100) * (average gold across that level's 3 treasure slots)
'  because a room rolls 1 of 3 slots uniformly and an ITEM_PCT fraction of rooms yield a
'  magic item instead. Items are counted separately and NOT as gold: taking one the first
'  time pays nothing (you get the item) -- only a duplicate sells. So the gold column is a
'  floor, and real runs land above it as duplicates accumulate.
'
'  Room counts come from the real board, so the numbers are for the actual map.
' ============================================================================
SUB EconDump
    DIM lvl AS INTEGER, slot AS INTEGER, r AS INTEGER
    DIM nroom(1 TO 9) AS INTEGER   ' NOT `rooms` -- that shadows the shared ROOMS() array
    DIM avgg(1 TO 9) AS DOUBLE, goldl(1 TO 9) AS DOUBLE, itemsl(1 TO 9) AS DOUBLE
    DIM tot AS DOUBLE, cum AS DOUBLE, totitems AS DOUBLE, sumg AS DOUBLE, ns AS INTEGER
    DIM hitHero AS INTEGER, hitSuper AS INTEGER, hitWiz AS INTEGER
    DIM ln AS STRING

    RANDOMIZE 20260729                             ' any seed: room COUNTS are map geometry, not RNG
    StartBoard
    RandomizeRooms
    _DEST _CONSOLE

    FOR r = 1 TO ROOM_N                            ' rooms that actually hold an encounter
        lvl = ROOMS(r).sec
        IF lvl >= 1 AND lvl <= 9 THEN
            IF LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN nroom(lvl) = nroom(lvl) + 1
        END IF
    NEXT r

    PRINT PipeCol$("|15econdump|07 -- expected gold economy (data pack: |11" + _TRIM$(opt_datapack) + "|07)")
    PRINT
    PRINT PipeCol$("|11  lvl  rooms  avg gold/slot  item%   exp. gold   exp. items|07")
    FOR lvl = 1 TO 9
        sumg = 0: ns = 0
        FOR slot = 1 TO 3
            sumg = sumg + TRE_GOLD(lvl, slot): ns = ns + 1
        NEXT slot
        IF ns > 0 THEN avgg(lvl) = sumg / ns
        goldl(lvl) = nroom(lvl) * avgg(lvl) * (100 - ITEM_PCT(lvl)) / 100
        itemsl(lvl) = nroom(lvl) * ITEM_PCT(lvl) / 100
        tot = tot + goldl(lvl): totitems = totitems + itemsl(lvl)
        ' built up in steps -- QB64's `_` line continuation mangles a long concatenation
        ln = RPad$(LTRIM$(STR$(lvl)), 5)
        ln = ln + RPad$(LTRIM$(STR$(nroom(lvl))), 7)
        ln = ln + RPad$(LTRIM$(STR$(INT(avgg(lvl)))), 15)
        ln = ln + RPad$(LTRIM$(STR$(ITEM_PCT(lvl))) + "%", 8)
        ln = ln + RPad$(LTRIM$(STR$(INT(goldl(lvl)))), 12)
        ln = ln + LTRIM$(STR$(INT(itemsl(lvl) * 10) / 10))
        PRINT PipeCol$("  " + ln)
    NEXT lvl
    PRINT
    PRINT PipeCol$("  total expected treasure gold on the whole board: |14" + LTRIM$(STR$(INT(tot))) + "|07")
    PRINT PipeCol$("  total expected magic items:                      |14" + LTRIM$(STR$(INT(totitems * 10) / 10)) + "|07")
    PRINT PipeCol$("  |08(gold is a FLOOR -- items pay nothing on first pickup, only duplicates sell)")
    PRINT

    ' Win pacing: how deep must you get to afford each class's target, clearing every
    ' room down to that depth? This is the number that actually matters after a rebalance.
    PRINT PipeCol$("|11win pacing|07 -- shallowest depth whose cumulative gold covers each target")
    cum = 0
    FOR lvl = 1 TO 9
        cum = cum + goldl(lvl)
        IF hitHero = 0 AND cum >= 10000 THEN hitHero = lvl
        IF hitSuper = 0 AND cum >= 20000 THEN hitSuper = lvl
        IF hitWiz = 0 AND cum >= 30000 THEN hitWiz = lvl
        PRINT PipeCol$("   through level " + LTRIM$(STR$(lvl)) + ": " + RIGHT$("          " + LTRIM$(STR$(INT(cum))), 10) + " gold")
    NEXT lvl
    PRINT
    EconTarget "HERO / ELF", 10000, hitHero
    EconTarget "SUPERHERO", 20000, hitSuper
    EconTarget "WIZARD", 30000, hitWiz
    PRINT
    PRINT PipeCol$("  |08Tune with tuning.txt ITEM_PCT_<n> (how often items drop) and treasures.txt")
    PRINT PipeCol$("  |08(gold values). Re-run this after any change -- no playthrough needed.")
    SYSTEM 0
END SUB

' One win-pacing line. depth 0 = the whole board cannot fund that target.
SUB EconTarget (who AS STRING, target AS LONG, depth AS INTEGER)
    IF depth = 0 THEN
        PRINT PipeCol$("   |12" + who + "|07 (" + LTRIM$(STR$(target)) + "): NOT reachable from treasure gold alone")
    ELSE
        PRINT PipeCol$("   |10" + who + "|07 (" + LTRIM$(STR$(target)) + "): affordable by clearing through level |14" + LTRIM$(STR$(depth)) + "|07")
    END IF
END SUB


' Left-justify s in a field of w characters (pads right). The mirror of engine TEXT.bas
' PadR$, kept local because this is console table layout, not a game/engine concern.
FUNCTION RPad$ (s AS STRING, w AS INTEGER)
    IF LEN(s) >= w THEN RPad$ = s + " " ELSE RPad$ = s + SPACE$(w - LEN(s))
END FUNCTION
