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
    DIM sec AS INTEGER, res AS INTEGER, chnow AS INTEGER
    ' returning to the entrance patches you up (D&D mode)
    IF ABS(cx - START_CX) <= 1 AND ABS(cy - START_CY) <= 1 THEN player_hp = player_maxhp
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
            ' reclaim dropped loot once the room is clear (your own, solo; a rival's, MP)
            IF NOT ROOMS(sec).malive AND HasDrop(sec) THEN CollectDrop sec
        END IF
    END IF
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
    ' reclaim loose spoils left on the paths where a fall happened (rooms OR corridors)
    IF LooseAt%(cx, cy) > 0 THEN CollectLooseAt cx, cy
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
FUNCTION Game_FloorColorAt~& (px AS INTEGER, py AS INTEGER)
    DIM sec AS INTEGER
    sec = SECTOR.get_by_xy(px, py)
    IF sec >= 1 THEN Game_FloorColorAt~& = SECTORS(sec).kolor ELSE Game_FloorColorAt~& = 0
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
