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
        IF opt_juice THEN ImpactFX 5, 1          ' a green poison pulse courses through you
    END IF
    IF fire_turns > 0 THEN
        player_hp = player_hp - 1: IF player_hp < 1 THEN player_hp = 1
        fire_turns = fire_turns - 1
        Sfx "trap"
        IF opt_juice THEN ImpactFX 6, 2          ' an orange sear of lingering flame
    END IF
    IF siren_turns > 0 THEN siren_turns = siren_turns - 1
END SUB


' ============================================================================
'  CURIOS -- a small deck of surprises found after a room fight (CHEST_PCT) or,
'  more rarely, out on the paths while exploring. The roster (name / weight /
'  prompt) is DATA in assets/data/curios.txt; each `kind` is a mechanic below.
'  D&D-mode only (they lean on HP / potions / status).
' ============================================================================

' Load the curio roster from assets/data/curios.txt into CURIOS().
SUB LoadCurios
    DIM i AS INTEGER
    NCURIO = 0
    ReadDataFile "assets/data/curios.txt"
    FOR i = 1 TO DLINE_N
        IF NCURIO < UBOUND(CURIOS) THEN
            NCURIO = NCURIO + 1
            CURIOS(NCURIO).kind = DField$(DLINE(i), 1)
            CURIOS(NCURIO).nm = DField$(DLINE(i), 2)
            CURIOS(NCURIO).weight = VAL(DField$(DLINE(i), 3))
            CURIOS(NCURIO).prompt = DField$(DLINE(i), 4)
        END IF
    NEXT i
END SUB

' Roll for a curio; if one turns up, pick a weighted-random entry and run it.
' rm is the room (1..ROOM_N) or 0 out on a path.
SUB DoCurio (rm AS INTEGER)
    DIM sec AS INTEGER, i AS INTEGER, tot AS INTEGER, r AS INTEGER, pick AS INTEGER, kd AS STRING
    IF NCURIO <= 0 THEN EXIT SUB                        ' the caller decides IF a curio appears; we pick WHICH
    sec = SECTOR.get_by_xy(c.x, c.y): IF sec < 1 THEN sec = 1
    tot = 0
    FOR i = 1 TO NCURIO: tot = tot + CURIOS(i).weight: NEXT
    IF tot <= 0 THEN EXIT SUB
    r = RollDie(tot): pick = 1
    FOR i = 1 TO NCURIO
        r = r - CURIOS(i).weight
        IF r <= 0 THEN pick = i: EXIT FOR
    NEXT
    kd = _TRIM$(CURIOS(pick).kind)
    Sfx "treasure"
    DrawCurioArt kd, _TRIM$(CURIOS(pick).nm)            ' pixel-art: the curio's prop, framed top-left (persists behind the banner)
    Banner _TRIM$(CURIOS(pick).prompt), CurioHint$(kd)
    SELECT CASE kd
        CASE "chest": CurioChest rm, sec
        CASE "fountain": CurioFountain sec
        CASE "shrine": CurioShrine sec
        CASE "gamble": CurioGamble sec
        CASE "peddler": CurioPeddler sec
        CASE "idol": CurioIdol sec
        CASE "corpse": CurioCorpse rm, sec
        CASE "mushroom": CurioMushroom sec
        CASE "obelisk": CurioObelisk sec
        CASE "cache": CurioCache sec
        CASE "mimic": CurioMimic sec
    END SELECT
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB

' The interaction hint under each curio's prompt (per kind).
FUNCTION CurioHint$ (kd AS STRING)
    SELECT CASE kd
        CASE "chest", "mimic": CurioHint$ = "[O] open it     [L] leave it be"
        CASE "fountain": CurioHint$ = "[D] drink     [L] leave it"
        CASE "shrine": CurioHint$ = "[O] make an offering     [L] pass"
        CASE "gamble": CurioHint$ = "[W] wager gold     [L] walk away"
        CASE "peddler": CurioHint$ = "[B] buy a ware     [L] wave them off"
        CASE "idol": CurioHint$ = "[P] pry out the gem     [L] leave it"
        CASE "corpse": CurioHint$ = "[S] search the body     [L] pay respects"
        CASE "mushroom": CurioHint$ = "[E] eat one     [L] leave them"
        CASE "obelisk": CurioHint$ = "[T] touch it     [L] pass"
        CASE "cache": CurioHint$ = "[G] grab the gear     [L] leave it"
        CASE ELSE: CurioHint$ = "[ press any key ]"
    END SELECT
END FUNCTION

' Wait for the interact key (or ENTER) -> TRUE; L or ESC -> FALSE.
FUNCTION CurioChoose% (ky AS STRING)
    DIM k AS STRING
    DO
        _LIMIT 60: k = UCASE$(INKEY$)
        IF k = UCASE$(ky) OR k = CHR$(13) THEN CurioChoose% = -1: EXIT FUNCTION
        IF k = "L" OR k = CHR$(27) THEN CurioChoose% = 0: EXIT FUNCTION
        _DISPLAY
    LOOP
END FUNCTION

' Heal up to max; returns the amount actually restored.
FUNCTION CurioHeal% (amt AS INTEGER)
    DIM before AS INTEGER
    before = player_hp
    player_hp = player_hp + amt
    IF player_hp > player_maxhp THEN player_hp = player_maxhp
    CurioHeal% = player_hp - before
END FUNCTION

' Grant one useful thing the player doesn't already max out -- else a potion/scroll.
SUB GrantCurioItem (sec AS INTEGER, got AS STRING)
    DIM opt(1 TO 8) AS INTEGER, n AS INTEGER, pick AS INTEGER
    n = 0
    IF player_class <> 4 AND item_sword < 2 THEN n = n + 1: opt(n) = 1
    IF item_armor < 4 THEN n = n + 1: opt(n) = 2
    IF item_bow = 0 THEN n = n + 1: opt(n) = 3
    IF item_boots = 0 THEN n = n + 1: opt(n) = 4
    IF item_esp = 0 THEN n = n + 1: opt(n) = 5
    IF item_crystal = 0 THEN n = n + 1: opt(n) = 6
    n = n + 1: opt(n) = 7                               ' a healing potion -- always on offer
    n = n + 1: opt(n) = 8                               ' a teleport scroll -- always on offer
    pick = opt(RollDie(n))
    SELECT CASE pick
        CASE 1: item_sword = item_sword + 1: got = "a Magic Sword (+" + _TRIM$(STR$(item_sword)) + ")": LogTreasure "Magic Sword", 0
        CASE 2
            item_armor = item_armor + 2: IF item_armor > 6 THEN item_armor = 6
            got = "Magic Armor (+" + _TRIM$(STR$(item_armor)) + " AC)": LogTreasure "Magic Armor", 0
        CASE 3: item_bow = TRUE: got = "a Magic Bow (+2 hit)": LogTreasure "Magic Bow", 0
        CASE 4: item_boots = TRUE: got = "Elf Boots (+2 move, easy flee)": LogTreasure "Elf Boots", 0
        CASE 5: item_esp = TRUE: got = "an ESP Medallion": LogTreasure "ESP Medallion", 0
        CASE 6: item_crystal = TRUE: got = "a Crystal Ball": LogTreasure "Crystal Ball", 0
        CASE 7: item_potion_small = item_potion_small + 1: got = "a Healing Potion": LogTreasure "Healing Potion", 0
        CASE 8: item_teleport = item_teleport + 1: got = "a Teleport Scroll": LogTreasure "Teleport Scroll", 0
    END SELECT
END SUB

' --- the curio mechanics (one per `kind`) ---

' CHEST: open for depth-scaled gold + maybe a potion; 25% trapped. Leaving a room
' chest stashes its gold as a recoverable $ on the map.
SUB CurioChest (rm AS INTEGER, sec AS INTEGER)
    DIM g AS LONG
    IF NOT CurioChoose%("O") THEN
        g = (INT(RND * 4) + 2) * 100 * sec
        IF rm >= 1 AND rm <= ROOM_N THEN
            ROOMS(rm).drop_gold = ROOMS(rm).drop_gold + g
            Banner "You leave the chest for now -- a $ marks it on the map.", "Come back for it whenever you like.   [ press any key ]"
        ELSE
            Banner "You leave the chest and move on.", "[ press any key ]"
        END IF
        WaitKey: EXIT SUB
    END IF
    Sfx "chest": DramaticPause
    IF rm >= 1 AND RollDie(100) <= CHEST_TRAP_PCT THEN SpringTrap rm
    g = (RollDie(4) + 1) * 100 * sec: gold = gold + g: LogTreasure "Curio Chest", g
    Sfx "treasure": Banner "The chest holds " + _TRIM$(STR$(g)) + " gold!", "[ press any key ]": WaitKey
    IF RollDie(100) <= 30 THEN                        ' the chest may also hide a healing potion
        IF RollDie(100) <= TREASURE_LARGE_PCT THEN
            item_potion_large = item_potion_large + 1: Sfx "treasure"
            Banner "Tucked inside: a LARGE HEALING POTION!", "Heals 1d8+1 -- press [H] in a fight.   [ press any key ]": WaitKey
        ELSE
            item_potion_small = item_potion_small + 1: Sfx "treasure"
            Banner "Tucked inside: a SMALL HEALING POTION!", "Heals 1d4 -- press [H] in a fight.   [ press any key ]": WaitKey
        END IF
    END IF
END SUB

' FOUNTAIN: drink for a weighted outcome -- mostly good, sometimes foul.
SUB CurioFountain (sec AS INTEGER)
    DIM r AS INTEGER, n AS INTEGER
    IF NOT CurioChoose%("D") THEN Banner "You leave the still water alone.", "[ press any key ]": WaitKey: EXIT SUB
    Sfx "treasure": DramaticPause
    r = RollDie(100)
    IF r <= 45 THEN
        n = CurioHeal%(RollDie(8) + 2)
        IF n > 0 THEN
            Sfx "treasure"
            Banner "The water is cool and sweet -- vigour floods back!", "You heal " + _TRIM$(STR$(n)) + " HP.   [ press any key ]"
        ELSE                                          ' already at full vigour -- reward the drink instead of a hollow "heal 0"
            n = RollDie(3) * 25 * sec: gold = gold + n: LogTreasure "coins in the fountain", n: Sfx "treasure"
            Banner "The water is cool and sweet -- but you are already hale.", "You spot old coins on the basin floor: +" + _TRIM$(STR$(n)) + " gold.   [ press any key ]"
        END IF
    ELSEIF r <= 68 THEN
        n = RollDie(4) * 50 * sec: gold = gold + n: LogTreasure "coins in the fountain", n
        Banner "Old coins glint on the basin floor -- you scoop them up!", "+" + _TRIM$(STR$(n)) + " gold.   [ press any key ]"
    ELSEIF r <= 85 THEN
        Banner "The water is brackish and flat.", "Nothing happens.   [ press any key ]"
    ELSE
        poison_turns = poison_turns + RollDie(4) + 1: Sfx "bump"
        Banner "The water is foul -- your gut knots and burns!", "POISONED for " + _TRIM$(STR$(poison_turns)) + " turns.   [ press any key ]"
    END IF
    WaitKey
END SUB

' SHRINE: pay gold for a likely blessing (full heal + a potion), or cold silence.
SUB CurioShrine (sec AS INTEGER)
    DIM cost AS LONG, n AS INTEGER
    cost = 200 * sec
    IF gold < cost THEN Banner "The shrine hungers for " + _TRIM$(STR$(cost)) + " gold you don't have.", "You pass it by.   [ press any key ]": WaitKey: EXIT SUB
    IF NOT CurioChoose%("O") THEN Banner "You leave the old god to its silence.", "[ press any key ]": WaitKey: EXIT SUB
    gold = gold - cost: Sfx "chest": DramaticPause
    IF RollDie(100) <= 70 THEN
        n = CurioHeal%(player_maxhp): item_potion_small = item_potion_small + 1: Sfx "levelup"
        Banner "The god accepts your " + _TRIM$(STR$(cost)) + " gold -- warmth pours through you!", "Your wounds close and a HEALING POTION appears in your pack.   [ press any key ]"
    ELSE
        Sfx "bump"
        Banner "You offer " + _TRIM$(STR$(cost)) + " gold... the shrine stays cold and silent.", "The god was not listening.   [ press any key ]"
    END IF
    WaitKey
END SUB

' GAMBLE: wager depth-scaled gold on 2d6; 7+ doubles it, else it's gone.
SUB CurioGamble (sec AS INTEGER)
    DIM bet AS LONG, r AS INTEGER
    bet = 250 * sec: IF bet > gold THEN bet = gold
    IF bet <= 0 THEN Banner "The altar wants a wager, but your purse is empty.", "You walk away.   [ press any key ]": WaitKey: EXIT SUB
    IF NOT CurioChoose%("W") THEN Banner "You leave the bone dice unthrown.", "[ press any key ]": WaitKey: EXIT SUB
    r = GameRoll(2, 6, 0, "the ALTAR's wager -- 7+ doubles " + _TRIM$(STR$(bet)) + " gold")
    IF r >= 7 THEN
        gold = gold + bet: LogTreasure "altar winnings", bet: Sfx "levelup"
        Banner "The bones come up " + _TRIM$(STR$(r)) + " -- the altar DOUBLES your stake!", "+" + _TRIM$(STR$(bet)) + " gold.   [ press any key ]"
    ELSE
        gold = gold - bet: Sfx "lose"
        Banner "The bones come up " + _TRIM$(STR$(r)) + " -- the altar swallows your wager.", "-" + _TRIM$(STR$(bet)) + " gold.   [ press any key ]"
    END IF
    WaitKey
END SUB

' PEDDLER: buy a random useful item for depth-scaled gold.
SUB CurioPeddler (sec AS INTEGER)
    DIM cost AS LONG, got AS STRING
    cost = 300 * sec
    IF gold < cost THEN Banner "The peddler eyes your thin purse and melts away.", "(wants " + _TRIM$(STR$(cost)) + " gold)   [ press any key ]": WaitKey: EXIT SUB
    IF NOT CurioChoose%("B") THEN Banner "'Another time, then.' The peddler is gone.", "[ press any key ]": WaitKey: EXIT SUB
    gold = gold - cost: Sfx "treasure"
    GrantCurioItem sec, got
    Banner "You trade " + _TRIM$(STR$(cost)) + " gold for " + got + ".", "The peddler vanishes into the dark.   [ press any key ]"
    WaitKey
END SUB

' IDOL: pry a big gem for gold, but the theft usually wakes a guardian or a curse.
SUB CurioIdol (sec AS INTEGER)
    DIM g AS LONG, r AS INTEGER
    IF NOT CurioChoose%("P") THEN Banner "You leave the idol's ruby eye winking in the dark.", "[ press any key ]": WaitKey: EXIT SUB
    g = (RollDie(6) + 3) * 100 * sec: gold = gold + g: LogTreasure "the idol's ruby eye", g: Sfx "treasure"
    Banner "You pry the fat ruby free -- " + _TRIM$(STR$(g)) + " gold of gem!", "But the idol's gaze goes dark...   [ press any key ]": WaitKey
    r = RollDie(100)
    IF r <= 45 THEN
        frost_turns = frost_turns + RollDie(4): Sfx "bump"
        Banner "A curse sighs out of the stone -- your limbs seize with rime!", "FROZEN for " + _TRIM$(STR$(frost_turns)) + " turns.   [ press any key ]": WaitKey
    ELSEIF r <= 80 THEN
        Banner "Stone grinds behind you -- something wakes!", "A guardian rouses from its slumber.   [ press any key ]": WaitKey
        WanderEncounter
    ELSE
        Banner "The idol crumbles harmlessly to dust.", "You got away clean.   [ press any key ]": WaitKey
    END IF
END SUB

' CORPSE: loot a dead adventurer -- gold, maybe an item, a small chance their trap remains.
SUB CurioCorpse (rm AS INTEGER, sec AS INTEGER)
    DIM g AS LONG, got AS STRING
    IF NOT CurioChoose%("S") THEN Banner "You leave the dead delver to their rest.", "[ press any key ]": WaitKey: EXIT SUB
    Sfx "chest": DramaticPause
    IF rm >= 1 AND RollDie(100) <= 20 THEN SpringTrap rm
    g = (RollDie(4) + 1) * 75 * sec: gold = gold + g: LogTreasure "a dead adventurer's purse", g: Sfx "treasure"
    Banner "Their purse still holds " + _TRIM$(STR$(g)) + " gold.", "[ press any key ]": WaitKey
    IF RollDie(100) <= 40 THEN
        GrantCurioItem sec, got
        Banner "And clutched in a cold, curled hand: " + got + "!", "[ press any key ]": WaitKey
    END IF
END SUB

' MUSHROOM: eat one for a whimsical weighted outcome (heal / vision / nothing / poison).
SUB CurioMushroom (sec AS INTEGER)
    DIM r AS INTEGER, n AS INTEGER
    IF NOT CurioChoose%("E") THEN Banner "You step around the glowing ring.", "[ press any key ]": WaitKey: EXIT SUB
    Sfx "chest": DramaticPause
    r = RollDie(100)
    IF r <= 40 THEN
        n = CurioHeal%(RollDie(6) + 2): Sfx "treasure"
        Banner "Earthy and warm -- your wounds knit shut!", "You heal " + _TRIM$(STR$(n)) + " HP.   [ press any key ]": WaitKey
    ELSEIF r <= 65 THEN
        Banner "The dungeon blooms open behind your eyes...", "A vision! You glimpse what lies around you.   [ press any key ]": WaitKey
        ScryView
    ELSEIF r <= 82 THEN
        Banner "It tastes of dust and old rain.", "Nothing happens.   [ press any key ]": WaitKey
    ELSE
        poison_turns = poison_turns + RollDie(4): Sfx "bump"
        Banner "The world tilts and swims -- that one was poison!", "POISONED for " + _TRIM$(STR$(poison_turns)) + " turns.   [ press any key ]": WaitKey
    END IF
END SUB

' OBELISK: touch it for a utility gamble (scry / teleport home / nothing / backlash).
SUB CurioObelisk (sec AS INTEGER)
    DIM r AS INTEGER, dmg AS INTEGER
    IF NOT CurioChoose%("T") THEN Banner "You leave the humming stone untouched.", "[ press any key ]": WaitKey: EXIT SUB
    Sfx "chest": DramaticPause
    r = RollDie(100)
    IF r <= 40 THEN
        Banner "Runes flare white -- the dungeon unveils itself!", "[ press any key ]": WaitKey: ScryView
    ELSEIF r <= 70 THEN
        Sfx "key"
        Banner "Reality folds -- the stone hurls you across the dark!", "You reappear at the entrance.   [ press any key ]": WaitKey
        c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
        loiter = 0: StartTurnMove
    ELSEIF r <= 85 THEN
        Banner "The runes dim. Its power was spent an age ago.", "[ press any key ]": WaitKey
    ELSE
        dmg = RollDie(6): IF dmg >= player_hp THEN dmg = player_hp - 1
        IF dmg < 0 THEN dmg = 0
        player_hp = player_hp - dmg: Sfx "bump"
        Banner "Arcane backlash sears up your arm!", "You take " + _TRIM$(STR$(dmg)) + " damage.   [ press any key ]": WaitKey
    END IF
END SUB

' CACHE: a guaranteed gear find -- a random useful item.
SUB CurioCache (sec AS INTEGER)
    DIM got AS STRING
    IF NOT CurioChoose%("G") THEN Banner "You leave the cache half-buried.", "[ press any key ]": WaitKey: EXIT SUB
    Sfx "treasure": DramaticPause
    GrantCurioItem sec, got
    Banner "You work the cache free -- " + got + "!", "[ press any key ]": WaitKey
END SUB

' MIMIC: the greedy trap -- open it and the "loot" bites back.
' MIMIC: masquerades as an ordinary Curio Chest (see curios.txt -- same name, art
' and prompt as a real chest). Opening it springs the trap: you fight the MIMIC
' ITSELF, revealed only now (its own combat art shows via the events/ sprite).
' Declining reads exactly like leaving a chest, so it gives nothing away.
SUB CurioMimic (sec AS INTEGER)
    DIM w AS INTEGER, res AS INTEGER
    IF NOT CurioChoose%("O") THEN Banner "You leave the chest and move on.", "[ press any key ]": WaitKey: EXIT SUB
    w = ROOM_N + 1: IF w > 400 THEN w = 400              ' a scratch combat slot, like a wanderer
    ROOMS(w).sec = sec
    ROOMS(w).monster = "MIMIC": ROOMS(w).mslot = 2       ' borrows a mid monster's 2d6 kill number
    ROOMS(w).malive = TRUE: ROOMS(w).is_boss = FALSE
    ROOMS(w).monster_fought = FALSE: ROOMS(w).player_died = FALSE: ROOMS(w).looted = FALSE
    ROOMS(w).mhp = sec * 5 + RollDie(6) + 6: ROOMS(w).mhp_now = ROOMS(w).mhp   ' a beefy ambusher
    ROOMS(w).mac = 11 + sec
    ROOMS(w).treasure_name = "the mimic's hoard": ROOMS(w).treasure = (INT(RND * 4) + 3) * 100 * sec
    ROOMS(w).treasure_item = 0
    ROOMS(w).drop_gold = 0: ROOMS(w).drop_sword = 0
    ROOMS(w).drop_secret = FALSE: ROOMS(w).drop_esp = FALSE: ROOMS(w).drop_crystal = FALSE
    c.prev_x = c.x: c.prev_y = c.y                       ' no safe step-back from an ambush
    Sfx "bump"
    Banner "The lid gapes wide -- rows of teeth! It's a MIMIC!", "The chest was alive all along -- it lunges!   [ press any key ]": WaitKey
    res = DoCombat(w)
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
