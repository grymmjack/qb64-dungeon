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
'  The check that motivated this: items.txt OVERRIDES a treasure slot, and a room rolls
'  1 of its level's 3 slots uniformly (RollDie(3) in RandomizeRooms). So if all 3 slots
'  of a level hold magic items, that level can NEVER yield a gold treasure card and its
'  treasures.txt rows are dead data. That had happened to levels 5, 6 and 8 -- the deck
'  grew until it saturated them, silently, against items.txt's own documented intent
'  ("an item in slot 3 turns up in ~1/3 of that level's rooms").
' ============================================================================

SUB DataLint
    DIM lvl AS INTEGER, slot AS INTEGER, nitem AS INTEGER, errs AS INTEGER, warns AS INTEGER
    DIM i AS INTEGER, nm AS STRING, code AS INTEGER, goldslots AS INTEGER
    _DEST _CONSOLE
    PRINT PipeCol$("|15datalint|07 -- validating the loaded content tables (data pack: |11" + _TRIM$(opt_datapack) + "|07)")
    PRINT

    '--- treasure slots vs magic-item overrides -------------------------------
    PRINT PipeCol$("|11treasure slots|07 (a room rolls 1 of 3 uniformly; items override a slot)")
    FOR lvl = 1 TO 9
        nitem = 0: goldslots = 0
        FOR slot = 1 TO 3
            IF TRE_ITEM(lvl, slot) <> 0 THEN nitem = nitem + 1 ELSE goldslots = goldslots + 1
        NEXT slot
        IF goldslots = 0 THEN
            PRINT PipeCol$("  |12!! level " + LTRIM$(STR$(lvl)) + "|07: all 3 slots are magic ITEMS -- this level can never yield a gold")
            PRINT PipeCol$("       treasure card, and its treasures.txt rows are unreachable. Free at least one slot.")
            errs = errs + 1
        ELSE
            PRINT PipeCol$("  |10ok|07 level " + LTRIM$(STR$(lvl)) + ": " + LTRIM$(STR$(nitem)) + " item slot(s), " + LTRIM$(STR$(goldslots)) + " gold slot(s)  (item chance " + LTRIM$(STR$(INT(nitem * 100 / 3))) + "%)")
        END IF
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

    '--- item type codes the game actually implements --------------------------
    FOR lvl = 1 TO 9
        FOR slot = 1 TO 3
            code = TRE_ITEM(lvl, slot)
            IF code <> 0 THEN
                ' 1..5, 7..13 are handled by ClaimTreasure; 6 (Level Key) is placed dynamically
                IF code < 1 OR code > 13 OR code = 6 THEN
                    PRINT PipeCol$("  |12!!|07 item " + LTRIM$(STR$(lvl)) + "/" + LTRIM$(STR$(slot)) + " (" + _TRIM$(TRE_NAME(lvl, slot)) + ") has unhandled type code " + LTRIM$(STR$(code)))
                    errs = errs + 1
                END IF
            END IF
        NEXT slot
    NEXT lvl

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
