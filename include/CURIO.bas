' ============================================================================
'  CURIO.bas -- curio chests, traps, saving throws, and status effects
'
'  The first "curio event": after a room fight there's a CHEST_PCT chance a chest
'  appears. Open it for gold (and maybe a potion) -- but CHEST_TRAP_PCT of chests
'  are trapped (poison darts / bomb / frost bomb / magic siren). Every trap offers
'  a saving throw (50% base + 10% per relevant ability modifier). Failing inflicts
'  a status effect that ticks down as turns (steps) pass -- see TickStatus, and the
'  frost/siren hooks in PlayGame.
' ============================================================================

' Saving throw, rolled ON SCREEN as a d20 (Real-Dice players roll their own).
' Math: roll d20 + (ability modifier * 2), save on DC 11 -- which reproduces the
' old "50% base, +/-10% per ability point" odds exactly (each point = +2 = +10%).
' Natural 20 always saves, natural 1 always fails. Plays a success/fail sound.
' `what` is shown in the roll caption. TRUE = the danger is avoided.
FUNCTION SaveThrow% (abmod AS INTEGER, what AS STRING)
    DIM tot AS INTEGER, bonus AS INTEGER, saved AS INTEGER, dc AS INTEGER
    dc = 11
    bonus = abmod * 2
    tot = GameRoll(1, 20, bonus, "SAVE vs " + what + " -- need " + _TRIM$(STR$(dc)) + "+ to save")
    IF last_raw = 20 THEN
        saved = -1                         ' natural 20 always saves
    ELSEIF last_raw = 1 THEN
        saved = 0                          ' natural 1 always fails
    ELSE
        saved = (tot >= dc)
    END IF
    IF saved THEN Sfx "saveok" ELSE Sfx "savebad"
    SaveThrow = saved
END FUNCTION


' One turn's worth of status ticks (called after each step). Poison + fire each
' cost 1 HP and count down; the siren winds down. DoT is capped non-fatal (a trap
' can leave you at 1 HP but not kill you outright).
SUB TickStatus
    IF poison_turns > 0 THEN
        player_hp = player_hp - 1: IF player_hp < 1 THEN player_hp = 1
        poison_turns = poison_turns - 1
        Sfx "trap"
    END IF
    IF fire_turns > 0 THEN
        player_hp = player_hp - 1: IF player_hp < 1 THEN player_hp = 1
        fire_turns = fire_turns - 1
        Sfx "trap"
    END IF
    IF siren_turns > 0 THEN siren_turns = siren_turns - 1
END SUB


' A curio chest may appear after clearing a room (CHEST_PCT). Open it for gold and
' maybe a potion; a trapped one (CHEST_TRAP_PCT) springs first.
SUB CurioChest (rm AS INTEGER)
    DIM k AS STRING, sec AS INTEGER, g AS LONG
    IF rm < 1 OR rm > ROOM_N THEN EXIT SUB          ' room chests only (never wanderers)
    IF RollDie(100) > CHEST_PCT THEN EXIT SUB
    sec = ROOMS(rm).sec: IF sec < 1 THEN sec = 1
    Sfx "treasure"
    Banner "A CURIO CHEST sits half-buried in the rubble!", "[O] open it    [L] leave it be"
    DO
        _LIMIT 60: k = UCASE$(INKEY$)
        IF k = "O" OR k = CHR$(13) OR k = " " THEN EXIT DO
        IF k = "L" OR k = CHR$(27) THEN cursor_erase: cursor_draw: DrawHUD: _DISPLAY: EXIT SUB
        _DISPLAY
    LOOP
    Sfx "chest"                                     ' the lid creaks open...
    DramaticPause                                   ' . . . the suspense
    ' 25% trapped -- the trap springs on open, before the loot
    IF RollDie(100) <= CHEST_TRAP_PCT THEN SpringTrap rm
    ' the reward -- gold scaled by depth
    g = (RollDie(4) + 1) * 100 * sec
    gold = gold + g
    LogTreasure "Curio Chest", g
    Sfx "treasure"
    Banner "The chest holds " + _TRIM$(STR$(g)) + " gold!", "[ press any key ]"
    WaitKey
    IF RollDie(100) <= 30 THEN                       ' sometimes a potion too
        item_potion_small = item_potion_small + 1
        Sfx "treasure"
        Banner "Tucked inside: a SMALL HEALING POTION!", "[ press any key ]"
        WaitKey
    END IF
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' Spring one trap from assets/data/traps.txt: roll a random loaded trap, take its
' saving throw, and on a failure run its mechanic (kind). Trap NAMES, save stats,
' sounds, dice and messages are all editable in the data file; the four mechanics
' (poison DoT / bomb / frost / siren) stay in code, keyed by the row's `kind`.
SUB SpringTrap (rm AS INTEGER)
    DIM tt AS INTEGER, dmg AS INTEGER, amod AS INTEGER, ln AS STRING
    DIM tname AS STRING, tsave AS STRING, tword AS STRING
    DIM ftit AS STRING, fbod AS STRING
    IF NTRAP <= 0 THEN EXIT SUB                     ' no traps loaded -- nothing to spring
    tt = RollDie(NTRAP)
    tname = _TRIM$(TRAPS(tt).name): tsave = _TRIM$(TRAPS(tt).save): tword = _TRIM$(TRAPS(tt).word)
    ftit = _TRIM$(TRAPS(tt).ftit): fbod = _TRIM$(TRAPS(tt).fbod)
    IF LEN(tword) = 0 THEN tword = "SAVE"
    SELECT CASE tsave                               ' which ability the save uses
        CASE "DEX": amod = AbilMod(player_dex)
        CASE "WIS": amod = AbilMod(player_wis)
        CASE ELSE: amod = AbilMod(player_con)
    END SELECT

    Sfx _TRIM$(TRAPS(tt).sfx)
    Banner _TRIM$(TRAPS(tt).trig), "Roll to " + tword + "!"
    CombatPause
    IF SaveThrow(amod, tname + " (" + tsave + ")") THEN
        Banner _TRIM$(TRAPS(tt).smsg), tword + "D!   [ press any key ]"
    ELSE
        SELECT CASE TRAPS(tt).kind
            CASE 1                                  ' POISON -- damage over time
                poison_turns = poison_turns + RollDie(TRAPS(tt).die)
                Banner ftit, StrSubst$(fbod, "{n}", _TRIM$(STR$(poison_turns))) + "   [ press any key ]"
            CASE 2                                  ' BOMB -- damage, maybe catch fire
                dmg = RollDie(TRAPS(tt).die)
                player_hp = player_hp - dmg: IF player_hp < 1 THEN player_hp = 1
                ln = StrSubst$(fbod, "{n}", _TRIM$(STR$(dmg)))
                IF RollDie(100) <= 25 THEN
                    fire_turns = fire_turns + RollDie(4)
                    ln = ln + " You are set ALIGHT (-1 HP/turn)!"
                END IF
                Banner ftit, ln + "   [ press any key ]"
            CASE 3                                  ' FROST -- freeze (multiplayer) or cold damage (solo)
                IF num_players > 1 THEN
                    frost_turns = frost_turns + RollDie(TRAPS(tt).die)
                    Banner "You are frozen solid!", "FROZEN: you cannot move for " + _TRIM$(STR$(frost_turns)) + " turns.   [ press any key ]"
                ELSE
                    dmg = RollDie(TRAPS(tt).die)
                    player_hp = player_hp - dmg: IF player_hp < 1 THEN player_hp = 1
                    Banner ftit, StrSubst$(fbod, "{n}", _TRIM$(STR$(dmg))) + "   [ press any key ]"
                END IF
            CASE ELSE                               ' SIREN -- raise the wandering-monster rate
                siren_turns = siren_turns + RollDie(TRAPS(tt).die)
                Banner ftit, StrSubst$(fbod, "{n}", _TRIM$(STR$(siren_turns))) + "   [ press any key ]"
        END SELECT
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB
