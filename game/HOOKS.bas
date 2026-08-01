' ============================================================================
'  HOOKS.bas -- the GAME side of the engine<->game contract.
'
'  QB64 compiles as one translation unit, so a "hook" is just a well-named SUB/
'  FUNCTION the ENGINE calls and the GAME implements here. This file holds the
'  play-loop + juice hooks; the render hooks live in game/OVERLAYS.bas and the
'  board-population hook (#8) in game/SECTOR.bas. See engine/ENGINE.md for the full
'  contract, the debt ledger, and the audit script that keeps them honest.
'
'  Shape rule: a hook answers "should I?" / "how much?" -- never "what mode are you
'  in?". Returning game STATE just relocates the coupling; returning a DECISION is
'  what lets the engine be lifted out.
' ============================================================================

' Game hook -- "win-ready": the player has enough gold AND holds the Level Key.
' Shared by the win check (Game_WinReached%) and the HUD "RETURN TO START" hint,
' so the rule lives in ONE place. Both operands are pure reads (safe under QB64's
' non-short-circuiting AND).
FUNCTION Game_WinReady%
    Game_WinReady% = 0
    IF gold >= target_gold AND has_key THEN Game_WinReady% = -1
END FUNCTION

' Game hook -- the win condition: win-ready AND standing on (or next to) the
' entrance chamber. Pure read of the working globals + the live cursor.
FUNCTION Game_WinReached%
    Game_WinReached% = 0
    IF NOT Game_WinReady% THEN EXIT FUNCTION
    IF ABS((c.x \ CW) - START_CX) <= 1 AND ABS((c.y \ CH) - START_CY) <= 1 THEN Game_WinReached% = -1
END FUNCTION

' Game hook -- the player just stepped onto cell (cx,cy). Runs every game
' consequence of arriving there and returns OUT_WIN if the run is now won, else 0
' (continue). The engine play loop calls this once after a successful move; it
' owns "where the player is", the game owns "what that means".
'   consequences: entrance heal (D&D) -> room encounter (ESP-gated) / drop
'   reclaim -> chamber encounter -> loose-loot pickup -> win check.
FUNCTION Game_OnEnterCell% (cx AS INTEGER, cy AS INTEGER)
    Game_OnEnterCell% = 0
    DIM sec AS INTEGER, res AS INTEGER, chnow AS INTEGER, atstart AS INTEGER
    ' Returning to the entrance patches you up (D&D mode) -- but only when you WALKED home.
    ' start_heal_locked is set by anything that teleports/drags you here (see GAME.BI), and
    ' clears the moment you leave the entrance zone, so the heal is earned once per trip.
    atstart = 0
    IF ABS(cx - START_CX) <= 1 AND ABS(cy - START_CY) <= 1 THEN atstart = -1
    IF atstart THEN
        ' The entrance restores exactly what you STARTED with -- 15 max HP at creation means 15
        ' HP back, every time, forever. It used to heal to FULL, which made walking home a free
        ' reset that only got stronger as max HP grew; a fixed amount does the opposite.
        '
        ' Gated: you must be alive (1+ HP -- the entrance patches you up, it does not raise the
        ' dead) and actually hurt (under 75% of max), so topping off a scratch is not worth the
        ' trip. start_heals counts it, which is what makes the abuse visible in the summary.
        ' A save written before this existed, or a champion loaded from the hall of fame, has
        ' no captured starting HP. Derive it once rather than bump the save format -- the worst
        ' case is a returning hero whose "starting" HP is their current max, which is exactly
        ' the old behaviour they were already playing with.
        IF hp_start_amount <= 0 THEN hp_start_amount = player_maxhp
        IF opt_startheal AND NOT start_heal_locked THEN
            IF player_hp >= 1 AND player_hp < (player_maxhp * 3) \ 4 THEN
                DIM healed AS INTEGER
                healed = player_hp
                player_hp = player_hp + hp_start_amount
                IF player_hp > player_maxhp THEN player_hp = player_maxhp
                healed = player_hp - healed        ' what the rest ACTUALLY restored, after the cap
                start_heals = start_heals + 1
                start_heal_locked = TRUE           ' one heal per trip out; leaving clears it
                LogEvent "The entrance restores you (" + _TRIM$(STR$(healed)) + " HP)."
                RestAtEntrance healed              ' the set piece: white wash, art, narration, sfx
            END IF
        END IF
    ELSE
        start_heal_locked = FALSE                  ' out in the dungeon again -- the walk home counts
    END IF
    ' THE CRYPT (level 9) forces line of sight. Its darkness is a property of the place, not a
    ' display preference, so it overrides the setting -- but through fov_forced, never by writing
    ' opt_fov, which is the player's saved config and must come back unchanged when they leave.
    ' A WIZARD is exempt: light is the one thing they can always make.
    DIM wantfov AS INTEGER
    wantfov = 0
    IF PlayerLevel% = 9 THEN IF NOT IsWizard% THEN wantfov = -1   ' nested: QB64's AND never short-circuits
    IF wantfov <> fov_forced THEN
        fov_forced = wantfov
        ' Switching sight on mid-run needs the masks built, or the first frame blacks the board
        ' with nothing marked seen. Switching it off just stops consulting them.
        IF fov_forced AND NOT opt_fov THEN InitFOV
        IF fov_forced THEN
            Banner "The dark of THE CRYPT closes in.", "You can see only what your light reaches.   [ press any key ]"
            WaitKey
        END IF
        display_dirty = 1
    END IF
    IF InRoomNow THEN
        sec = ROOMAT(cx, cy)                       ' which room block are we standing in?
        IF sec >= 1 THEN
            IF NOT ROOMS(sec).seen THEN
                ROOMS(sec).seen = TRUE             ' entering reveals this room's monster on the board
                RecordEnterRoom                    ' chronicle: rooms explored
                RoomFlavor sec                     ' first-entry atmosphere (special or level one-liner)
            END IF
            ' a monster guards this room's treasure?
            IF ROOMS(sec).malive AND LEN(_TRIM$(ROOMS(sec).monster)) > 0 THEN
                ' ESP Medallion (ONLY if held): foresee the monster; [N] backs off.
                ' NOTE: BASIC's AND does not short-circuit, so EspEnter must be called
                ' inside its own IF item_esp -- not as "item_esp AND EspEnter(...)".
                IF item_esp THEN
                    IF EspEnter(sec) THEN
                        res = DoCombat(sec)
                        IF opt_boardgame THEN steps_left = 0   ' combat ends your turn
                    ELSE
                        c.x = c.prev_x: c.y = c.prev_y         ' heed the warning, step back out
                        cursor_erase: cursor_draw
                    END IF
                ELSE
                    res = DoCombat(sec)
                    IF opt_boardgame THEN steps_left = 0       ' no ESP -- straight into the fight
                END IF
            END IF
            ' Reclaim dropped loot once the room is clear (your own, solo; a rival's, MP).
            ' At the ENTRANCE, only if you actually fell there: a revive puts you back at
            ' START, and picking a hoard up on arrival would read as "you recovered
            ' everything" for spoils that are still lying where you really died.
            IF NOT ROOMS(sec).malive AND HasDrop(sec) THEN
                IF NOT atstart THEN
                    CollectDrop sec
                ELSEIF ROOMS(sec).player_died THEN
                    CollectDrop sec
                END IF
            END IF
        END IF
    END IF
    ' Reclaim loose spoils left where a fall happened (corridors, and CHAMBERS -- a chamber
    ' death has no room to stash in, so it drops here). This runs BEFORE the chamber trigger
    ' below on purpose: stepping onto your own body inside a hall used to wake the next
    ' guardian FIRST, so you had to survive a fresh fight before you were allowed to pick your
    ' own spoils back up -- and dying in it put a second body on top of the first.
    IF LooseAt%(cx, cy) > 0 THEN CollectLooseAt cx, cy
    ' CHAMBERS: stepping into a fresh (uncleared) chamber wakes ONE of its 3 monsters;
    ' leave and re-enter for the next until three graves stand. Fire only on ENTRY
    ' (cur_chamber transition) and never on a coloured room block (rooms handle their own).
    chnow = CHAMBERAT(cx, cy)
    IF ROOMAT(cx, cy) <> 0 THEN chnow = 0
    IF chnow <> cur_chamber THEN
        cur_chamber = chnow
        IF chnow > 0 THEN
            ChamberEncounter chnow
            IF opt_boardgame THEN steps_left = 0     ' a chamber fight ends your turn
        END IF
    END IF
    ' victory: enough gold, hold the Level Key, and back at the entrance
    IF Game_WinReached% THEN
        DeleteSave                                   ' the run is won -- clear any stale save
        Game_OnEnterCell% = OUT_WIN
    END IF
END FUNCTION

' Game hook -- the POISON overlay intensity (0 = none .. 1 = full), derived from the
' DUNGEON! poison-dart timer. The engine's DrawPoison takes this as a pure parameter, so
' engine/JUICE.bas names no game state (clears the JUICE<-poison boundary-debt line).
FUNCTION Game_PoisonLevel!
    DIM lvl AS SINGLE
    lvl = 0
    IF poison_turns > 0 THEN
        lvl = poison_turns / 8
        IF lvl > 1 THEN lvl = 1
    END IF
    Game_PoisonLevel! = lvl
END FUNCTION

' Game hook -- may the engine draw the near-death blood/vignette? Only rulesets that
' actually track hit points qualify: classic DUNGEON! resolves a fight on one 2d6 roll,
' so there is no "wounded" state to bleed for. Keeps `opt_oldschool` out of engine/JUICE.bas.
FUNCTION Game_ShowWounds%
    IF opt_oldschool THEN Game_ShowWounds% = 0 ELSE Game_ShowWounds% = -1
END FUNCTION

' Game hook -- the ROOM-FLOOR colour in force at pixel (px,py), or 0 for "none here".
'
' The engine's pixel-colour collision (CellKind / CanMove / InRoomNow) needs to know which
' colour counts as walkable room floor at a position. It used to derive that itself via
' SECTOR.get_by_xy + SECTORS().kolor -- i.e. the engine asked "which dungeon LEVEL is this?",
' a question only this game has. Now it asks "what colour is floor here?" and compares; the
' mapping from position to level to colour stays entirely game-side.
'
' 0 is a safe "no floor colour" sentinel: every real colour is _RGB32(...) with alpha 255
' (&HFF......), so none of them can be 0.
' Reads the CELL'S OWN COLOUR from the current _SOURCE and returns it if the game recognises
' it as room floor (one of the nine level colours), else 0.
'
' It used to ask geometry -- "which sector covers this pixel, what colour is that sector" --
' and that is what stranded the LOST ROOMS: where the art painted a room in level 5's colour
' but the sector mask claimed the cell for level 1, the answer came back level 1's colour, the
' whole-cell test failed, and a visible, door-connected room was unreachable forever.
'
' The art is the map, so the cell states its own level. CanMove only reaches this for a cell it
' has already failed to match against path/door/secret, so "is this pixel a floor colour" is
' the entire question. Geometry (SECTOR.get_by_xy / PlayerLevel%) still answers the different
' question of which level a CORRIDOR belongs to, where no colour says.
'
' _SOURCE must be a COLLISION image (FULL_COLLIDE or COLLIDE_BOARD) -- never a display image,
' or layer-1 decoration would read as terrain.
FUNCTION Game_FloorColorAt~& (px AS INTEGER, py AS INTEGER)
    DIM sx AS INTEGER, sy AS INTEGER, col AS _UNSIGNED LONG
    Game_FloorColorAt~& = 0
    ' SCAN THE CELL, do not just probe its centre.
    '
    ' A DOORWAY is half room floor and half door colour, and on plenty of them the centre pixel
    ' lands on the BROWN half. Probing only the centre therefore answered "no floor here", the
    ' room-floor branch of CanMove never ran, and the player could not walk through their own
    ' doors -- every doorway into a room, which is most of them.
    '
    ' The question this hook answers is "is any part of this cell room floor, and which level's",
    ' so it has to look at more than one pixel. First match wins; step 2 to stay cheap.
    FOR sy = 1 TO CH - 1 STEP 2
        FOR sx = 1 TO CW - 1 STEP 2
            col = POINT(px + sx, py + sy)
            IF SectorByColor%(col) >= 1 THEN Game_FloorColorAt~& = col: EXIT FUNCTION
        NEXT sx
    NEXT sy
END FUNCTION

' Game hooks -- ZONE identity, for the engine's mask linter (`dungeon.run ansilint`).
' The linter checks a painted mask's colours against whatever zones the game defines; in
' DUNGEON! a zone is a dungeon level. Keeps SectorByColor%/SECTORS out of engine/BOARD.bas
' and lets the linter's wording stay generic.
FUNCTION Game_ZoneByColor% (col AS _UNSIGNED LONG)
    Game_ZoneByColor% = SectorByColor%(col)
END FUNCTION

FUNCTION Game_ZoneName$ (id AS INTEGER)
    IF id >= 1 AND id <= UBOUND(SECTORS) THEN Game_ZoneName$ = _TRIM$(SECTORS(id).label)
END FUNCTION

FUNCTION Game_ZoneCount%
    Game_ZoneCount% = UBOUND(SECTORS)
END FUNCTION

' Game hook (#5) -- repaint the game's HUD layer.
'
' The engine repaints the BOARD after an overlay closes (cursor_erase/cursor_draw), but
' what sits on top of it -- gold, HP, the turn/steps readout, the combat panel -- is the
' game's. The 3D dice roller needs this: after wiping its dice box off the board it must
' restore the HUD, or the combat panel and the "you still face..." prompt come back
' half-erased. Was a direct DrawHUD call from engine/DICE3D_GAME.bas.
SUB Game_RenderHUD
    DrawHUD
END SUB
