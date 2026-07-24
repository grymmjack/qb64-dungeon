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

' Saving throw: 50% base, +/-10% per point of the relevant ability modifier,
' clamped to 5..95%. TRUE = the danger is avoided.
FUNCTION SaveThrow% (abmod AS INTEGER)
    DIM pct AS INTEGER
    pct = 50 + abmod * 10
    IF pct < 5 THEN pct = 5
    IF pct > 95 THEN pct = 95
    SaveThrow = (RollDie(100) <= pct)
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


' Spring one of four traps, each with its own saving throw and effect.
SUB SpringTrap (rm AS INTEGER)
    DIM tt AS INTEGER, dmg AS INTEGER, sec AS INTEGER, ln AS STRING
    sec = ROOMS(rm).sec: IF sec < 1 THEN sec = 1
    tt = RollDie(4)                                 ' 1 darts, 2 bomb, 3 frost, 4 siren
    SELECT CASE tt
        CASE 1                                      ' POISON DARTS -- save vs poison (CON)
            Sfx "trap"
            Banner "CLICK -- POISON DARTS hiss from the chest!", "Save vs poison (CON)..."
            _DELAY 1.8
            IF SaveThrow(AbilMod(player_con)) THEN
                Banner "You twist aside -- the darts clatter past!", "Saved!   [ press any key ]"
            ELSE
                poison_turns = poison_turns + RollDie(4)
                Banner "A dart pricks you -- venom burns in your veins!", "POISONED: -1 HP for " + _TRIM$(STR$(poison_turns)) + " turns.   [ press any key ]"
            END IF
        CASE 2                                      ' BOMB -- dodge (DEX), maybe catch fire
            Sfx "trap"
            Banner "TICK TICK -- a BOMB tumbles out of the chest!", "Dodge (DEX)..."
            _DELAY 1.8
            IF SaveThrow(AbilMod(player_dex)) THEN
                Banner "You dive clear as it bursts!", "Dodged!   [ press any key ]"
            ELSE
                dmg = RollDie(6)
                player_hp = player_hp - dmg: IF player_hp < 1 THEN player_hp = 1
                ln = "The blast rocks you for " + _TRIM$(STR$(dmg)) + " damage!"
                IF RollDie(100) <= 25 THEN
                    fire_turns = fire_turns + RollDie(4)
                    ln = ln + " You are set ALIGHT (-1 HP/turn)!"
                END IF
                Banner "BOOM!", ln + "   [ press any key ]"
            END IF
        CASE 3                                      ' FROST BOMB -- save vs frost (CON)
            Sfx "trap"
            Banner "A FROST BOMB shatters in a burst of rime!", "Save vs frost (CON)..."
            _DELAY 1.8
            IF SaveThrow(AbilMod(player_con)) THEN
                Banner "You shrug off the freezing blast!", "Saved!   [ press any key ]"
            ELSEIF num_players > 1 THEN              ' multiplayer: frozen in place, no damage
                frost_turns = frost_turns + RollDie(4)
                Banner "You are frozen solid!", "FROZEN: you cannot move for " + _TRIM$(STR$(frost_turns)) + " turns.   [ press any key ]"
            ELSE                                     ' solo: straight cold damage
                dmg = RollDie(4)
                player_hp = player_hp - dmg: IF player_hp < 1 THEN player_hp = 1
                Banner "Frost sears your skin!", "You take " + _TRIM$(STR$(dmg)) + " cold damage.   [ press any key ]"
            END IF
        CASE ELSE                                   ' MAGIC SIREN -- save vs magic (WIS)
            Sfx "trap"
            Banner "A MAGIC SIREN wails up out of the chest!", "Save vs magic (WIS)..."
            _DELAY 1.8
            IF SaveThrow(AbilMod(player_wis)) THEN
                Banner "You clap the lid shut before it carries!", "Saved!   [ press any key ]"
            ELSE
                siren_turns = siren_turns + RollDie(4)
                Banner "The alarm shrieks through the halls!", "For " + _TRIM$(STR$(siren_turns)) + " turns, wandering monsters hunt you!   [ press any key ]"
            END IF
    END SELECT
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB
