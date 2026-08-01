' ============================================================================
'  COMBAT.bas -- GAME combat + treasure system (extracted from dungeon.bas).
'
'  The DUNGEON! rules: flee odds, revive/forfeit on death, turn structure, ESP
'  peek, the Wizard spell helpers + cast, both combat systems (2d6 DoCombat and
'  D&D DoCombatDnD), the combat panel, the Monster Attack Table, ClaimTreasure
'  (the item deck + Level Key), level-clear rewards, potions, and the treasure
'  log. Rides the engine (dice/Banner/Sfx/render) + game data (ROOMS/SECTORS).
' ============================================================================

' Append one fight's outcome to the stats CSV. dlevel = dungeon level, roomid = ROOMS()
' index, outcome = "killed"/"fled"/"died", dealt/taken = HP totals over the fight.
'
' The GAME owns this schema -- which columns exist and what they mean is a DUNGEON!
' concern (class, char level, XP, gold, oldschool-vs-D&D). The engine only appends the
' strings (engine/STATS.bas StatAppend), so it names none of that. Header and row must
' stay in the same order.
SUB StatLog (dlevel AS INTEGER, roomid AS INTEGER, mon AS STRING, boss AS INTEGER, wander AS INTEGER, outcome AS STRING, rounds AS INTEGER, dealt AS INTEGER, taken AS INTEGER)
    DIM mode AS STRING, hdr AS STRING, row AS STRING
    IF opt_oldschool THEN mode = "oldschool" ELSE mode = "dnd"
    hdr = "date,time,hero,class,mode,char_level,xp,dungeon_level,room,monster,boss,wandering,outcome,rounds,dmg_dealt,dmg_taken,hp_after,maxhp,gold_after"
    row = DATE$ + "," + TIME$ + "," + CsvCell$(player_name) + "," + CsvCell$(class_name) + "," + mode + "," + _TRIM$(STR$(char_level)) + "," + _TRIM$(STR$(char_xp)) + "," + _TRIM$(STR$(dlevel)) + "," + _TRIM$(STR$(roomid)) + "," + CsvCell$(mon) + "," + Bit$(boss) + "," + Bit$(wander) + "," + outcome + "," + _TRIM$(STR$(rounds)) + "," + _TRIM$(STR$(dealt)) + "," + _TRIM$(STR$(taken)) + "," + _TRIM$(STR$(player_hp)) + "," + _TRIM$(STR$(player_maxhp)) + "," + _TRIM$(STR$(gold))
    StatAppend "gameplay-data-saves/dungeon-stats.csv", hdr, row
END SUB

' A flee attempt fails (the monster grabs you and drags you back) with a chance
' that climbs the deeper you are: FLEE_FAIL_BASE on level 1, +FLEE_FAIL_STEP per
' level below (level 9 = 55%). TRUE = you are caught; combat continues.
FUNCTION FleeFails% (lvl AS INTEGER)
    DIM pct AS INTEGER, dl AS INTEGER
    dl = lvl: IF dl < 1 THEN dl = 1
    pct = FLEE_FAIL_BASE + (dl - 1) * FLEE_FAIL_STEP
    IF item_boots THEN pct = pct - 25            ' Elf Boots: nimble feet slip away far more reliably (useful even in free-move)
    IF pct < 0 THEN pct = 0
    IF pct > 95 THEN pct = 95
    FleeFails = (RollDie(100) <= pct)
END FUNCTION


' The '[H] HEAL (n)' tail for a combat prompt -- shown only when you actually hold
' a healing potion, with the current count (empty string otherwise).
FUNCTION HealSuffix$
    DIM n AS INTEGER
    n = item_potion_small + item_potion_large
    IF n > 0 THEN HealSuffix$ = "   [H] HEAL (" + _TRIM$(STR$(n)) + ")" ELSE HealSuffix$ = ""
END FUNCTION


' Gods' favour: a fallen adventurer on their LAST life, come back to reclaim spoils
' they never recovered, may (50%) be blessed -- tipping every combat die by +1 per
' death they have already suffered, so sheer persistence can finally win through.
FUNCTION GodsFavor% ()
    DIM d AS INTEGER
    GodsFavor = 0
    IF cur_player >= 1 AND cur_player <= 4 THEN d = deaths(cur_player) ELSE d = deaths(1)
    IF d < 1 THEN EXIT FUNCTION                        ' no boost until you have actually died
    IF d < opt_maxdeaths - 1 THEN EXIT FUNCTION        ' only when this is your final life
    IF NOT AnyDropExists THEN EXIT FUNCTION            ' only while spoils still await reclaiming
    IF RollDie(100) <= 50 THEN GodsFavor = d           ' 50%: the gods tip the dice +d
END FUNCTION


' After a death's flavor banner (caller has already WaitKey'd), run the after-death
' transition. If the fallen adventurer has spent their LAST life they FORFEIT -- a
' grey darkness falls to a sad epitaph and player_out is set so PlayGame ends their
' run. Otherwise they revive at START with a rally naming how many chances remain.
SUB ReviveOrForfeit (rm AS INTEGER)
    DIM diedcount AS INTEGER, chances AS INTEGER
    IF cur_player >= 1 AND cur_player <= 4 THEN diedcount = deaths(cur_player) ELSE diedcount = deaths(1)
    chances = opt_maxdeaths - diedcount           ' resurrections still to come after THIS death
    IF chances <= 0 THEN                           ' out of lives -- the run is over
        ForfeitScreen
        player_out = -1
        EXIT SUB
    END IF
    BloodDrip                                      ' the red death wipe -> black
    c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
    player_hp = player_maxhp                        ' revived, made whole again, at the entrance
    start_heal_locked = TRUE                        ' the resurrection IS the heal -- don't re-grant it on the next step
    cursor_erase: cursor_draw: FadeInCurrent        ' the dungeon fades back in at START
    Sfx "levelup"
    IF chances = 1 THEN
        Banner "You have perished -- but ONE last chance remains.", "Make it count... better luck this time!   [ press any key ]"
    ELSE
        Banner "You have perished -- but you still have " + _TRIM$(STR$(chances)) + " chances left.", "Rise and delve again... better luck this time!   [ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' The end of a run: a grey darkness (not blood) falls down the screen, then a random
' sad epitaph lingers over the black until a key is pressed.
SUB ForfeitScreen
    DIM ep AS STRING, kk AS STRING
    Sfx "lose"
    DarknessFall                                   ' grey/black cousin of the blood drip
    ep = ForfeitEpitaph$
    _DEST CANVAS: _FONT CH
    COLOR GREY, BLACK: PrintCentered 22, ep
    COLOR _RGB32(&H88, &H88, &H88), BLACK: PrintCentered 25, "Your tale ends here, in the dark."
    COLOR _RGB32(&H55, &H55, &H55), BLACK: PrintCentered 28, "[ press any key ]"
    Present
    _KEYCLEAR
    DO: _LIMIT 30: kk = INKEY$: Present: LOOP UNTIL kk <> ""
END SUB


' React to a set player_out flag. Returns TRUE if the whole game is over (solo, or
' the last player standing forfeited). In multiplayer, marks the fallen player out
' of the game and passes the seat to a survivor.
FUNCTION HandleForfeit% ()
    DIM i AS INTEGER, alive AS INTEGER
    HandleForfeit = 0
    player_out = 0
    IF num_players <= 1 THEN HandleForfeit = -1: EXIT FUNCTION    ' solo: game over
    IF cur_player >= 1 AND cur_player <= 4 THEN PLAYERS(cur_player).active = FALSE
    alive = 0
    FOR i = 1 TO num_players
        IF PLAYERS(i).active THEN alive = alive + 1
    NEXT i
    IF alive <= 0 THEN HandleForfeit = -1: EXIT FUNCTION          ' nobody left -- game over
    Banner "PLAYER " + _TRIM$(STR$(cur_player)) + " is out of lives!", _TRIM$(player_name) + " the " + class_name + " is lost to the dungeon forever.   [ press any key ]"
    WaitKey
    SaveActivePlayer cur_player                    ' park the (now inactive) fallen player
    cur_player = NextActivePlayer(cur_player)
    LoadActivePlayer cur_player
    cursor_erase: cursor_draw
    AnnounceTurn cur_player
    StartTurnMove
END FUNCTION


' Set the movement budget for a fresh turn, per the movement settings:
'   free walk (Boardgame OFF)          -> no roll, no step limit
'   Boardgame ON  -> the DUNGEON! rule: start each turn with MOVE_MAX (5) steps, move up to them,
'                    and SPACE ends the turn early (you choose how far -- there is no movement die)
'   Boardgame OFF -> free walk (single-player computer-game style)
SUB StartTurnMove
    IF NOT opt_boardgame THEN
        need_roll = FALSE: steps_left = 0
    ELSE
        need_roll = FALSE
        steps_left = MOVE_MAX
        IF item_boots THEN steps_left = steps_left + 2   ' Elf Boots add to the move
        turn_num = turn_num + 1                           ' no roll to advance the count -- bump it here
    END IF
END SUB


' ESP Medallion: foresee the monster guarding a room and choose whether to enter.
' Returns TRUE to fight, FALSE to heed the warning and back away.
FUNCTION EspEnter% (rm AS INTEGER)
    DIM k AS STRING, lead AS STRING
    IF ROOMS(rm).is_boss THEN lead = "the BOSS " + _TRIM$(ROOMS(rm).monster) ELSE lead = "a " + _TRIM$(ROOMS(rm).monster)
    Sfx "idle"
    Banner "Your ESP MEDALLION tingles -- " + lead + " lurks beyond this door!", "[Y] enter and fight   [N] back away"
    _KEYCLEAR            ' drain buffered movement keys so Y/N register at once
    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        IF k = "Y" OR k = CHR$(13) OR k = " " THEN EspEnter = -1: EXIT FUNCTION
        IF k = "N" OR k = CHR$(27) THEN EspEnter = 0: EXIT FUNCTION
        Present
    LOOP
END FUNCTION


' ---- WIZARD SPELLS (Fire Ball / Lightning Bolt; Teleport reuses item_teleport) ----------------

' TRUE if the active player is a Wizard -- the only class that casts spells.
FUNCTION IsWizard%
    IsWizard% = (player_class = 4)
END FUNCTION

' TRUE if the active player is an Elf -- the only class trained to the bow.
FUNCTION IsElf%
    IsElf% = (player_class = 2)
END FUNCTION

' TRUE if `mon` shrugs off a spell element ("fire"/"lightning"). Thematic: fiery/infernal things
' are immune to fire, constructs/metal/storm things to lightning -- so when one element fizzles,
' the Wizard casts the OTHER. Loose name match; edit the word lists to taste.
FUNCTION MonsterImmune% (mon AS STRING, elem AS STRING)
    DIM u AS STRING
    u = " " + UCASE$(_TRIM$(mon)) + " "
    MonsterImmune% = 0
    IF elem = "fire" THEN
        IF InStrAny%(u, "DRAGON FIRE FLAME SALAMANDER DEMON DEVIL EFREET HELL HELLHOUND MAGMA LAVA PHOENIX IMP") THEN MonsterImmune% = -1
    ELSEIF elem = "lightning" THEN
        IF InStrAny%(u, "ELEMENTAL GOLEM IRON METAL STORM THUNDER DJINN GARGOYLE STATUE WISP SPARK STORMCLOUD") THEN MonsterImmune% = -1
    END IF
END FUNCTION

FUNCTION SpellLabel$ (elem AS STRING)
    IF elem = "fire" THEN SpellLabel$ = "FIRE BALL" ELSE SpellLabel$ = "LIGHTNING BOLT"
END FUNCTION
FUNCTION SpellSfx$ (elem AS STRING)
    IF elem = "fire" THEN SpellSfx$ = "fireball" ELSE SpellSfx$ = "lightning-bolt"
END FUNCTION

' The extra combat-prompt line a Wizard sees when spells are available this fight.
FUNCTION WizSpellPrompt$
    DIM s AS STRING
    IF NOT IsWizard% THEN EXIT FUNCTION
    IF spell_fire > 0 THEN s = s + "   [F] Fire Ball(" + _TRIM$(STR$(spell_fire)) + ")"
    IF spell_bolt > 0 THEN s = s + "   [L] Lightning(" + _TRIM$(STR$(spell_bolt)) + ")"
    WizSpellPrompt$ = s
END FUNCTION

' A Wizard casts an offensive spell in OLDSCHOOL (2d6) combat: an instant SLAY unless the monster
' is immune to that element (then the spell fizzles and the monster gets a free swing). Either way
' the charge is spent and the turn ends -- the caller EXIT DOs afterwards.
SUB WizardCastOldschool (rm AS INTEGER, elem AS STRING)
    DIM sec AS INTEGER, mon AS STRING
    sec = ROOMS(rm).sec: mon = _TRIM$(ROOMS(rm).monster)
    IF elem = "fire" THEN spell_fire = spell_fire - 1 ELSE spell_bolt = spell_bolt - 1
    Sfx SpellSfx$(elem)
    IF MonsterImmune%(mon, elem) THEN
        Banner "You hurl a " + SpellLabel$(elem) + "!", "The " + mon + " is IMMUNE to " + elem + " -- the spell fizzles!   [ press any key ]"
        CombatPause
        MonsterAttack rm                          ' a wasted cast still spends your turn
    ELSE
        ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
        Banner "You loose a " + SpellLabel$(elem) + "!", "The " + mon + " is blasted apart!   [ press any key ]"
        CombatPause
        ClaimTreasure rm, 12                       ' a clean magical kill (ClaimTreasure records the kill + death sfx)
        StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "killed", 1, 0, 0
    END IF
END SUB

FUNCTION DoCombat% (rm AS INTEGER)
    DIM k AS STRING, mon AS STRING
    DIM AS INTEGER sec, sm, need, target, unbeatable, god_favor
    DIM lead AS STRING, p2 AS STRING, whatguards AS STRING
    DoCombat = 0
    sec = ROOMS(rm).sec                            ' the room's dungeon level (label + kill numbers)
    mon = _TRIM$(ROOMS(rm).monster)
    ROOMS(rm).monster_fought = TRUE
    combat_crits = 0                               ' per-fight crit tally -> the post-fight potion reward
    RecordEncounter mon                            ' bestiary: # times faced
    NarrateNamed "mon." + NarrSlug$(mon), "combat.encounter", NARR_COMBAT   ' "GOBLINS." then the line
    ' TACTICAL SCREEN. Branched HERE because DoCombat% is the single funnel every encounter goes
    ' through -- room monsters, chamber monsters, wandering monsters, and a curio that turns out to
    ' be a MIMIC. One branch covers all of them; wiring each call site separately would guarantee
    ' one gets missed.
    IF opt_tactical THEN
        DIM tres AS INTEGER
        combat_active = -1
        tres = RunFightRoom%(rm, 0)
        combat_active = 0
        EndCue
        _FONT CH                                   ' the fight screen ran 8x8; the board needs CH back
        cursor_erase: cursor_draw: DrawHUD: Present
        IF tres = OUT_WIN THEN
            ' ClaimTreasure does the RecordKill itself (bestiary + grave + haul), so do NOT also
            ' call RecordKill here -- that double-counts, the same trap RecordWander has.
            ClaimTreasure rm, ROOMS(rm).mslot
        ELSEIF tres = OUT_LOSE THEN
            DoCombat = 1                           ' the caller handles death exactly as in 2d6 mode
        END IF
        EXIT FUNCTION
    END IF
    IF NOT opt_oldschool THEN                      ' D&D d20/HP combat instead of 2d6-vs-target
        combat_active = -1                          ' keep the combat panel constant through rolls/banners
        DoCombatDnD rm
        combat_active = 0                           ' (cleared here so ALL of DoCombatDnD's exits are covered)
        EndCue                                       ' return from combat music to the level track (no-op if none)
        cursor_erase: cursor_draw: Present
        EXIT FUNCTION
    END IF
    ' the kill number depends on the ACTIVE player's class (matters in hot-seat)
    IF ROOMS(rm).is_boss THEN
        SELECT CASE player_class
            CASE 1, 2: need = 13
            CASE 3: need = 11
            CASE ELSE: need = 12
        END SELECT
    ELSE
        need = MON_N(sec, ROOMS(rm).mslot, player_class)
    END IF
    god_favor = GodsFavor                     ' desperate last-life spoils-rescue may earn a divine boost
    target = need - item_sword - god_favor    ' the raw 2d6 the player must roll (Magic Sword + the gods help)
    unbeatable = (target > 12)                ' "-" on the card: needs a stronger blade
    IF target < 2 THEN target = 2

    IF ROOMS(rm).is_boss THEN
        lead = "The BOSS " + mon
    ELSEIF MonPlural%(mon) THEN
        lead = mon                                     ' "GIANT RATS guard...", no "A"
    ELSE
        lead = "A " + mon
    END IF
    ' the treasure is face-down under the monster -- unless the ESP Medallion peeks it
    whatguards = " " + MonVerb$(mon, "guards", "guard") + " the " + SECTORS(sec).label + "!"
    IF item_esp THEN whatguards = " " + MonVerb$(mon, "guards", "guard") + " a " + _TRIM$(ROOMS(rm).treasure_name) + "!"
    IF unbeatable THEN
        p2 = "Only a Magic Sword can harm it -- [ESC] FLEE"
    ELSE
        p2 = "Roll " + _TRIM$(STR$(target)) + "+ on 2d6 to slay it   [SPACE] ATTACK   [ESC] FLEE"
    END IF
    p2 = p2 + WizSpellPrompt$                       ' Wizard: [F]/[L] cast options -- and the ONLY way past a "-" monster
    IF god_favor > 0 THEN                          ' the desperate are watched over -- tell them
        Sfx "levelup"
        Banner "THE GODS FAVOUR THE DESPERATE!", "Fortune lowers the roll you need by " + _TRIM$(STR$(god_favor)) + " this fight.   [ press any key ]"
        WaitKey
    END IF
    DrawCombatArt mon, sec                          ' pixel-art: monster (left) + location (right); persists behind the centre banner/dice
    Banner lead + whatguards, p2 + HealSuffix$

    DO
        _LIMIT 60
        AudioTick                            ' keep combat narration fade + music crossfade ramping while idle
        k = INKEY$
        IF k = CHR$(27) THEN
            IF FleeFails(sec) THEN               ' the deeper you are, the likelier it grabs you
                Sfx "bump"
                Banner "The " + mon + " " + MonVerb$(mon, "lunges and drags", "lunge and drag") + " you back!", "You cannot flee!   [ press any key ]"
                CombatPause
                NarrateT "combat.reface", NARR_COMBAT        ' spoken "you still face it" (Combat tier)
                Banner lead + whatguards, p2 + HealSuffix$   ' re-show the fight prompt
            ELSE
                c.x = c.prev_x: c.y = c.prev_y  ' back out the way you came
                StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "fled", 0, 0, 0
                RecordFled mon
                NarrateT "combat.flee", NARR_COMBAT          ' spoken "you slip away" (Combat tier)
                Banner "You slip away from the " + mon + ".", MonVerb$(mon, "It still guards", "They still guard") + " the " + _TRIM$(SECTORS(sec).label) + " -- return to finish " + MonVerb$(mon, "it", "them") + ".   [ press any key ]"
                CombatPause
                EXIT DO
            END IF
        ELSEIF k = "H" OR k = "h" THEN           ' quaff a potion -- this IS your action; the monster then strikes
            IF item_potion_small + item_potion_large > 0 THEN
                UsePotion FALSE
                MonsterAttack rm                 ' healing spends your turn, so the monster gets its swing
                EXIT DO
            END IF
        ELSEIF (k = "F" OR k = "f") AND IsWizard% AND spell_fire > 0 THEN
            WizardCastOldschool rm, "fire": EXIT DO      ' slay unless fire-immune (then it fizzles)
        ELSEIF (k = "L" OR k = "l") AND IsWizard% AND spell_bolt > 0 THEN
            WizardCastOldschool rm, "lightning": EXIT DO
        ELSEIF k = " " AND NOT unbeatable THEN
            sm = DoRoll(2, item_sword, "attacking the " + mon)
            IF last_raw = 12 THEN
                ' natural 12 -- CRITICAL HIT, always slays
                ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                RecordCrit mon, 0
                Sfx "crit"
                IF opt_critfumble THEN
                    DoCrit rm, mon, WeaponName$, 0     ' cinematic + a heroic heal on the killing blow
                ELSE
                    Banner "** CRITICAL HIT! **  (natural 12)", "You cleave the " + mon + " in a single blow!   [ press any key ]"
                    CombatPause
                END IF
                ClaimTreasure rm, sm
                StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "killed", 1, 0, 0
                EXIT DO
            ELSEIF last_raw = 2 THEN
                ' natural 2 -- CRITICAL FUMBLE
                RecordFumble mon, 0
                IF opt_critfumble THEN
                    DoFumble rm, mon, WeaponName$
                ELSE
                    Sfx "fumble"
                    Banner "** CRITICAL FUMBLE! **  (snake eyes)", "Your blade slips -- the " + mon + " gets a free strike!   [ press any key ]"
                    CombatPause
                END IF
                MonsterAttack rm
                EXIT DO
            ELSEIF sm >= need THEN
                ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                Sfx "treasure"
                ClaimTreasure rm, sm
                StatLog sec, rm, mon, ROOMS(rm).is_boss, (rm > ROOM_N), "killed", 1, 0, 0
                EXIT DO
            ELSE
                MonsterAttack rm                ' failed -- roll on the Monster Attack Table
                EXIT DO
            END IF
        END IF
        Present
    LOOP

    cursor_erase
    cursor_draw
    Present
END FUNCTION


' ===========================================================================
'  D&D-STYLE COMBAT (Oldschool Mode OFF)
'  Multi-round: player rolls d20 + to-hit vs the monster's AC; on a hit, roll
'  the class damage die (+ Magic Sword) off the monster's HP. The monster then
'  strikes back (computer rolls its d20) against the player's AC and HP. Repeat
'  until the monster drops (win + treasure) or the player is downed (lose gold,
'  dragged back to START and revived). ESC flees; wounds persist if you return.
' ===========================================================================
SUB DoCombatDnD (rm AS INTEGER)
    DIM k AS STRING, mon AS STRING, lead AS STRING, mhs AS STRING, cdf AS STRING
    DIM AS INTEGER sec, lvl, mtohit, atk, dmg, rounds, matk, mdmg, thb, isboss
    DIM AS INTEGER tot_dealt, tot_taken, wander, vanished, god_favor, acted, did_attack, saved
    DIM spell_elem AS STRING, spell_dcnt AS INTEGER   ' Wizard cast: element + damage-dice count
    DIM lost AS LONG
    wander = (rm > ROOM_N)                       ' TRUE for a wandering-monster scratch slot
    sec = ROOMS(rm).sec
    mon = _TRIM$(ROOMS(rm).monster)
    isboss = ROOMS(rm).is_boss
    lvl = sec                                   ' sector index doubles as dungeon level 1..9
    PlayCue CombatCueName$(lvl, isboss), TRUE   ' combat music by intensity (no-op if the cue file is absent)
    ' The room's own is_boss flag covers BOTH the boss lair and a chamber LORD, and they want
    ' different bonuses -- ROOMS().is_chamber tells them apart. Capped by MON_TOHIT_MAX.
    IF isboss THEN
        IF ROOMS(rm).is_chamber THEN mtohit = MonsterToHit%(lvl, MK_LORD) ELSE mtohit = MonsterToHit%(lvl, MK_BOSS)
    ELSE
        mtohit = MonsterToHit%(lvl, MK_ROOM)
    END IF
    thb = player_tohit                          ' final to-hit incl. ability modifier
    IF item_sword > 0 THEN thb = thb + item_sword   ' a Magic Sword +N sharpens the SWING as well as the wound (+N hit AND +N dmg)
    ' Magic Bow: +2 to-hit, stacking with the blade. ELF ONLY -- ClaimTreasure sells it to any
    ' other class, so a non-Elf can never be holding one here.
    '
    ' This is the game's first MISSILE weapon, and deliberately a thin one: right now it is a
    ' to-hit bonus plus the SHOOT action in tactical combat. The plan is a top-down perspective
    ' where missile weapons complement melee properly -- so when that lands, this is the seam to
    ' widen, not a special case to work around.
    IF curse_turns > 0 THEN thb = thb - 1        ' cursed: your aim is fouled
    IF item_bow THEN thb = thb + 2
    god_favor = GodsFavor                       ' desperate last-life spoils-rescue may earn a divine dice boost
    IF god_favor > 0 THEN thb = thb + god_favor
    ROOMS(rm).mhp_now = ROOMS(rm).mhp   ' fresh fight: monster recovers to full between encounters (ROUND 1 always opens at 100%)
    rounds = 0: combat_round = 1
    IF isboss THEN lead = "The BOSS " + mon ELSE lead = "The " + mon
    FX_MON = mon: FX_LEVEL = sec: FX_ROOM = _TRIM$(SECTORS(sec).label)   ' flavor context for {tokens}
    combat_rm = rm: combat_mon = mon: combat_lead = lead                  ' so DrawHUD can keep the panel painted

    DIM dirty AS INTEGER
    dirty = -1                                   ' clear any lingering pre-combat banner on entry
    IF god_favor > 0 THEN                         ' the desperate are watched over -- tell them
        Sfx "levelup"
        Banner "THE GODS FAVOUR THE DESPERATE!", "Fortune guides your hand: +" + _TRIM$(STR$(god_favor)) + " to every strike this fight.   [ press any key ]"
        WaitKey
    END IF
    DO
        _LIMIT 60
        AudioTick                            ' keep combat narration fade + music crossfade ramping while idle
        ' Once an action's banners are done, wipe the message/dice area and redraw
        ' the board so ONLY the combat panel shows -- makes it obvious it's your turn.
        IF dirty THEN cursor_erase: cursor_draw: dirty = 0
        DrawHUD                              ' row-50 stats + the panel (via combat_active hook); the board redraw above wipes the HUD line otherwise
        k = INKEY$
        acted = 0: did_attack = 0
        IF k = CHR$(27) THEN                     ' attempt to flee
            ' AMBUSHED: they chose the moment, so there is no slipping away from it. The flee
            ' key still does something -- it tells you WHY it did nothing, which is better than
            ' a key that silently ignores you.
            IF door_ambush THEN
                Sfx "bump"
                Banner "AMBUSHED -- there is no retreat!", "They picked this moment; you are off balance and boxed in.   [ press any key ]"
                CombatPause
                dirty = -1
            ELSEIF FleeFails(lvl) THEN           ' the deeper you are, the likelier it grabs you
                Sfx "bump"
                Banner "The " + mon + " " + MonVerb$(mon, "lunges and drags", "lunge and drag") + " you back!", "You cannot flee!   [ press any key ]"
                CombatPause
                NarrateT "combat.reface", NARR_COMBAT   ' spoken "you still face it" (Combat tier)
                dirty = -1                       ' clear the banner, redraw the panel next loop
            ELSE
                c.x = c.prev_x: c.y = c.prev_y   ' back out the way you came
                StatLog sec, rm, mon, isboss, wander, "fled", rounds, tot_dealt, tot_taken
                RecordFled mon
                NarrateT "combat.flee", NARR_COMBAT     ' spoken "you slip away" (Combat tier)
                Banner "You slip away from the " + mon + ".", MonVerb$(mon, "It still guards", "They still guard") + " the " + _TRIM$(SECTORS(sec).label) + " -- return to finish " + MonVerb$(mon, "it", "them") + ".   [ press any key ]"
                CombatPause
                EXIT SUB
            END IF
        ELSEIF k = "H" OR k = "h" THEN           ' quaff a potion -- this IS your action; the monster still swings
            IF item_potion_small + item_potion_large > 0 THEN
                UsePotion FALSE
                acted = -1
                cursor_erase: cursor_draw: DrawHUD: Present   ' show the healed HP bar at once, before the monster swings
            END IF
            dirty = -1
        ELSEIF IsWizard% AND (((k = "F" OR k = "f") AND spell_fire > 0) OR ((k = "L" OR k = "l") AND spell_bolt > 0)) THEN
            ' ---------- Wizard casts a spell (dice damage; the monster still swings after) ----------
            IF k = "F" OR k = "f" THEN spell_elem = "fire": spell_dcnt = 3: spell_fire = spell_fire - 1 ELSE spell_elem = "lightning": spell_dcnt = 4: spell_bolt = spell_bolt - 1
            acted = -1: did_attack = -1: rounds = rounds + 1: combat_round = rounds: dirty = -1
            Sfx SpellSfx$(spell_elem)
            IF MonsterImmune%(mon, spell_elem) THEN
                Banner "You cast " + SpellLabel$(spell_elem) + "!", "The " + mon + " is IMMUNE to " + spell_elem + " -- it fizzles!   [ press any key ]"
                CombatPause
            ELSE
                dmg = GameRoll(spell_dcnt, 6, 0, SpellLabel$(spell_elem) + " on the " + mon)
                IF dmg < 1 THEN dmg = 1
                ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - dmg
                IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
                tot_dealt = tot_dealt + dmg
                IF ROOMS(rm).mhp_now > 0 THEN Sfx "monster-pain"
                DrawCombatPanel rm, mon, lead     ' drain the HP bar before the banner
                IF opt_juice THEN ImpactFX ShakeMag(dmg) * 0.6, 0
                Banner "You cast " + SpellLabel$(spell_elem) + "!  " + _TRIM$(STR$(spell_dcnt)) + "d6 = " + _TRIM$(STR$(dmg)), SpellLabel$(spell_elem) + " engulfs the " + mon + "!   [ press any key ]"
                CombatPause
                IF ROOMS(rm).mhp_now <= 0 THEN     ' slain by the blast
                    ROOMS(rm).mhp_now = 0: ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                    Sfx "treasure": ClaimTreasure rm, rounds
                    StatLog sec, rm, mon, isboss, wander, "killed", rounds, tot_dealt, tot_taken
                    EXIT SUB
                END IF
            END IF
        ELSEIF k = " " THEN
            acted = -1: did_attack = -1
            rounds = rounds + 1: combat_round = rounds
            dirty = -1                           ' this round's banners will need clearing next loop
            ' ---------- player attacks ----------
            atk = LuckyRoll%(1, 20, thb, "to hit the " + mon)   ' luck may buy a second d20
            IF last_raw = 20 THEN                 ' natural 20: crit, auto-hit, double dice
                dmg = LuckyRoll%(2, player_dmgdie, player_dmgbonus + item_sword - CurseDmgPenalty%, "CRITICAL damage on the " + mon)
                IF dmg < 1 THEN dmg = 1
                IF opt_gestures THEN dmg = dmg + CritFlourish(mon, sec, SkillTier%)   ' Action Gestures: time the gauge for +0/1/2 bonus dice
                ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - dmg
                IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
                tot_dealt = tot_dealt + dmg
                ' A crit that FINISHES the monster earns the killcrit aftermath text rather than
                ' the quiet death line. Read here, consumed by ClaimTreasure.
                IF ROOMS(rm).mhp_now <= 0 THEN fx_critkill = TRUE
                IF ROOMS(rm).mhp_now > 0 THEN Sfx "monster-pain"   ' wounded (not slain) -> a cry
                RecordCrit mon, dmg
                Sfx "crit"
                DrawCombatPanel rm, mon, lead     ' drain the monster's HP bar before the banner
                IF opt_juice THEN CritBoom dmg    ' BOOM: the huge damage number drops in with a volcanic shake
                IF opt_critfumble THEN
                    DoCrit rm, mon, WeaponName$, dmg    ' cinematic: smash-saying -> pause -> bonus event
                    DrawCombatPanel rm, mon, lead
                ELSE
                    FX_DMG = dmg
                    EventBanner "** CRITICAL HIT! **  (natural 20)", 2, class_name, 3, "You savage the " + mon + " for " + _TRIM$(STR$(dmg)) + " damage!"
                    CombatPause
                END IF
            ELSEIF last_raw = 1 THEN              ' natural 1: auto-miss (and maybe a mishap)
                RecordFumble mon, rounds
                IF opt_critfumble THEN
                    DoFumble rm, mon, WeaponName$
                    DrawCombatPanel rm, mon, lead
                ELSE
                    Sfx "fumble"
                    FX_DMG = 0
                    EventBanner "** FUMBLE! **  (natural 1)", 2, class_name, 4, "Your attack goes wide of the " + mon + "."
                    CombatPause
                END IF
            ELSEIF atk >= ROOMS(rm).mac THEN      ' hit
                dmg = LuckyRoll%(1, player_dmgdie, player_dmgbonus + item_sword - CurseDmgPenalty%, "your DAMAGE on the " + mon)
                IF dmg < 1 THEN dmg = 1
                ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - dmg
                IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
                tot_dealt = tot_dealt + dmg
                IF ROOMS(rm).mhp_now > 0 THEN Sfx "monster-pain"   ' wounded (not slain) -> a cry
                Sfx "hit"
                DrawCombatPanel rm, mon, lead     ' drain the monster's HP bar before the banner
                IF opt_juice THEN ImpactFX ShakeMag(dmg) * 0.45, 0   ' a lighter thump when you connect
                FX_DMG = dmg
                EventBanner "You HIT!  (d20+" + _TRIM$(STR$(thb)) + " = " + _TRIM$(STR$(atk)) + " vs AC " + _TRIM$(STR$(ROOMS(rm).mac)) + ")", 2, class_name, 1, "You deal " + _TRIM$(STR$(dmg)) + " damage."
                CombatPause
                IF last_raw = player_dmgdie THEN            ' MAX on the damage die -- brutal flavor (even without a crit)
                    mhs = MaxHitSaying$(mon, WeaponName$)
                    IF LEN(mhs) > 0 THEN
                        Sfx "maxhit"
                        Banner "** A CRUSHING BLOW! **  (max damage)", mhs + "   [ press any key ]"
                        CombatPause
                    END IF
                END IF
            ELSE                                  ' miss
                Sfx "miss"
                FX_DMG = 0
                EventBanner "You MISS.  (d20+" + _TRIM$(STR$(thb)) + " = " + _TRIM$(STR$(atk)) + " vs AC " + _TRIM$(STR$(ROOMS(rm).mac)) + ")", 2, class_name, 2, "The " + mon + " " + MonVerb$(mon, "dodges", "dodge") + " your blow."
                CombatPause
            END IF

            IF ROOMS(rm).mhp_now <= 0 THEN        ' monster slain
                ROOMS(rm).mhp_now = 0
                ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                Sfx "treasure"
                ClaimTreasure rm, rounds
                StatLog sec, rm, mon, isboss, wander, "killed", rounds, tot_dealt, tot_taken
                EXIT SUB
            END IF
        END IF

        IF acted THEN                             ' attacked OR healed -> the monster takes its turn
            IF NOT did_attack THEN rounds = rounds + 1: combat_round = rounds   ' a heal spends a round too

            ' ---------- monster strikes back (you roll its dice in Real-Dice mode, else shown) ----------
            PushMonsterDice: matk = GameRoll(1, 20, mtohit, "the " + mon + "'s ATTACK -- roll ITS d20"): PopMonsterDice
            IF opt_critfumble AND last_raw = 1 THEN     ' the monster fumbles: hurts itself or reels
                DoMonsterFumble rm, mon
                IF ROOMS(rm).mhp_now <= 0 THEN          ' it may have slain itself
                    ROOMS(rm).mhp_now = 0
                    ROOMS(rm).malive = FALSE: ROOMS(rm).looted = TRUE
                    Sfx "treasure"
                    ClaimTreasure rm, rounds
                    EXIT SUB
                END IF
            ELSEIF last_raw = 20 THEN             ' monster natural 20: crit, auto-hit, DOUBLE damage dice
                PushMonsterDice: mdmg = GameRoll(2, 6, lvl \ 3, "the " + mon + "'s CRITICAL damage -- roll ITS 2d6"): PopMonsterDice
                IF isboss THEN mdmg = mdmg + 3
                IF mdmg < 1 THEN mdmg = 1
                player_hp = player_hp - mdmg
                IF player_hp < 0 THEN player_hp = 0
                tot_taken = tot_taken + mdmg
                IF player_hp > 0 THEN Sfx "player-pain"   ' hurt but standing -> a cry
                Sfx "crit"
                DrawCombatPanel rm, mon, lead     ' drain YOUR HP bar before the banner
                IF opt_juice THEN ImpactFX ShakeMag(mdmg) * 1.25, 0   ' a brutal crit really rattles the frame
                FX_DMG = mdmg
                EventBanner "** the " + mon + " " + MonVerb$(mon, "CRITS", "CRIT") + " you! **  (natural 20)", 1, mon, 3, "A savage blow lands for " + _TRIM$(STR$(mdmg)) + " damage!"
                CombatPause
                MonsterEffectStrike mon        ' a crit lands its elemental effect too
            ELSEIF matk >= player_ac + item_armor + item_shield THEN
                PushMonsterDice: mdmg = GameRoll(1, 6, lvl \ 3, "the " + mon + "'s DAMAGE -- roll ITS d6"): PopMonsterDice
                IF isboss THEN mdmg = mdmg + 3
                player_hp = player_hp - mdmg
                IF player_hp < 0 THEN player_hp = 0
                tot_taken = tot_taken + mdmg
                IF player_hp > 0 THEN Sfx "player-pain"   ' hurt but standing -> a cry
                Sfx "bump"
                DrawCombatPanel rm, mon, lead     ' drain YOUR HP bar before the banner
                IF opt_juice THEN ImpactFX ShakeMag(mdmg), 0         ' you take a hit -- the frame lurches
                FX_DMG = mdmg
                NarrateT "combat.hurt", NARR_COMBAT   ' spoken "it wounds you" (Combat tier)
                EventBanner "The " + mon + " " + MonVerb$(mon, "HITS", "HIT") + " you!  (d20+" + _TRIM$(STR$(mtohit)) + " = " + _TRIM$(STR$(matk)) + " vs AC " + _TRIM$(STR$(player_ac + item_armor + item_shield)) + ")", 1, mon, 1, "You take " + _TRIM$(STR$(mdmg)) + " damage."
                MonsterEffectStrike mon        ' venom / blight / curse / acid, if this one carries any
                CombatPause
            ELSE
                FX_DMG = 0
                EventBanner "The " + mon + " " + MonVerb$(mon, "misses", "miss") + " you.  (d20+" + _TRIM$(STR$(mtohit)) + " = " + _TRIM$(STR$(matk)) + ")", 1, mon, 2, "You weather the assault."
                CombatPause
            END IF

            IF player_hp <= 0 THEN                ' downed
                ' Action Gestures: one clutch attempt to rise. Nail the crit zone and you
                ' claw back with 1d6 HP in place -- keep your gold, no life spent, fight on.
                saved = 0
                IF opt_gestures THEN saved = SecondWind%(mon, sec, SkillTier%)
                IF saved THEN
                    dirty = -1                    ' rose where you stand; the fight continues
                ELSE
                    player_hp = 0
                    ROOMS(rm).player_died = TRUE
                    Sfx "death"
                    NarrateT "combat.downed", NARR_COMBAT   ' spoken "you fall" (Combat tier)
                    IF cur_player >= 1 AND cur_player <= 4 THEN deaths(cur_player) = deaths(cur_player) + 1
                    DrawCombatPanel rm, mon, lead
                    FX_MON = mon: FX_DMG = mdmg        ' your class's own death cry, if it has one
                    cdf = EventLine$(2, class_name, 5)
                    IF LEN(cdf) > 0 THEN Banner "YOU ARE SLAIN!", cdf + "   [ press any key ]": WaitKey
                    lost = gold
                    vanished = FALSE                  ' SOULS-LIKE: dying again forfeits a hoard you never reclaimed
                    IF opt_lootrecovery = 2 THEN vanished = AnyDropExists
                    StatLog sec, rm, mon, isboss, wander, "died", rounds, tot_dealt, tot_taken
                    DropEverything rm                 ' drop gold AND the special cards (in the room, MP)
                    Sfx "lose"
                    IF vanished THEN
                        Banner "You clutch your bloody fist to your chest and reach for the loot you had hoped to reclaim,", "as it vanishes before your very eyes -- and the world fades to black.   [ press any key ]"
                    ELSEIF opt_lootrecovery >= 1 THEN
                        IF wander THEN
                            Banner "YOU ARE DOWNED by the " + mon + "!", "Your spoils (" + _TRIM$(STR$(lost)) + " gold + magic) lie where you fell -- return for revenge!   [ press any key ]"
                        ELSE
                            Banner "YOU ARE DOWNED by the " + mon + "!", "Your spoils (" + _TRIM$(STR$(lost)) + " gold + magic) lie in the " + _TRIM$(SECTORS(sec).label) + " -- return for revenge!   [ press any key ]"
                        END IF
                    ELSE
                        Banner "YOU ARE DOWNED by the " + mon + "!", "You lose your treasure (" + _TRIM$(STR$(lost)) + " gold) and all magic, dragged back to START.   [ press any key ]"
                    END IF
                    WaitKey                           ' let the death sink in before the transition
                    ReviveOrForfeit rm                ' blood (or grey forfeit) -> revive with a rally, or end the run
                    EXIT SUB
                END IF
            END IF
        END IF
        Present
    LOOP
END SUB


' Draw the D&D combat panel: monster + player HP bars and the action prompt.
SUB DrawCombatPanel (rm AS INTEGER, mon AS STRING, lead AS STRING)
    DIM AS INTEGER bx, by, bw, bh
    bx = 16: by = 39: bw = 100: bh = 10
    _DEST CANVAS
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), REDU, B
    ' WHO you are and WHAT you are swinging, bookending the panel. Drawn BEFORE the text so a
    ' long line overlaps the art rather than the art punching a hole through the words -- and
    ' both are silently skipped when the selected art style has nothing for them.
    PanelArt ClassSprite$(player_class), bx + 1, 13, by + 2, 7, _TRIM$(class_name), GREENU
    PanelArt WeaponSprite$, bx + bw - 14, 13, by + 2, 7, WeaponLabel$, CYANU
    UIFontOn UIF_COMBAT                          ' configurable combat font (loaded MONOSPACE so the HP bars stay even)
    COLOR YELLOWU, BOXBG
    IF combat_round > 1 THEN                      ' between rounds -- the fight is on-going; prompt to act again
        PrintCentered by + 1, "You still face " + LCASE$(LEFT$(_TRIM$(lead), 1)) + MID$(_TRIM$(lead), 2) + " -- choose your action!"
    ELSE                                          ' first look -- the encounter opens
        PrintCentered by + 1, _TRIM$(lead) + " " + MonVerb$(mon, "blocks", "block") + " your path!"
    END IF
    COLOR CYANU, BOXBG: _PRINTSTRING ((bx + 2) * CW, (by + 1) * CH), "LEVEL" + STR$(ROOMS(rm).sec)
    COLOR REDU, BOXBG: _PRINTSTRING ((bx + bw - 12) * CW, (by + 1) * CH), "ROUND:" + STR$(combat_round)
    COLOR REDU, BOXBG
    PrintCentered by + 3, mon + "   " + HpBar$(ROOMS(rm).mhp_now, ROOMS(rm).mhp, 22) + "  " + _TRIM$(STR$(ROOMS(rm).mhp_now)) + "/" + _TRIM$(STR$(ROOMS(rm).mhp)) + " HP   AC " + _TRIM$(STR$(ROOMS(rm).mac))
    COLOR GREENU, BOXBG
    PrintCentered by + 5, class_name + " (you)   " + HpBar$(player_hp, player_maxhp, 22) + "  " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + " HP   AC " + _TRIM$(STR$(player_ac + item_armor + item_shield))
    COLOR CYANU, BOXBG
    IF item_potion_small > 0 OR item_potion_large > 0 THEN
        PrintCentered by + 8, "[SPACE] attack    [H] potion (" + _TRIM$(STR$(item_potion_small + item_potion_large)) + ")    [ESC] flee"
    ELSE
        PrintCentered by + 8, "[SPACE] attack       [ESC] flee"
    END IF
    IF IsWizard% AND (spell_fire > 0 OR spell_bolt > 0) THEN   ' Wizard-only cast options
        DIM sph AS STRING
        sph = "SPELLS:"
        IF spell_fire > 0 THEN sph = sph + "   [F] Fire Ball x" + _TRIM$(STR$(spell_fire))
        IF spell_bolt > 0 THEN sph = sph + "   [L] Lightning x" + _TRIM$(STR$(spell_bolt))
        COLOR _RGB32(&HFF, &H88, &HFF), BOXBG
        PrintCentered by + 9, sph
    END IF
    UIFontOff                                   ' restore the grid font before the pixel-art + present
    DrawCombatArt mon, ROOMS(rm).sec            ' pixel-art: monster (left) + location (right) framed above the panel
    Present
END SUB


' A textual HP bar, e.g. "[##########----------]".
FUNCTION HpBar$ (cur AS INTEGER, mx AS INTEGER, width AS INTEGER)
    DIM AS INTEGER filled, i
    DIM s AS STRING
    IF mx <= 0 THEN mx = 1
    filled = INT((cur * width) / mx + 0.5)
    IF filled < 0 THEN filled = 0
    IF filled > width THEN filled = width
    s = "["
    FOR i = 1 TO width
        IF i <= filled THEN s = s + "#" ELSE s = s + "-"
    NEXT i
    HpBar$ = s + "]"
END FUNCTION


' Authentic DUNGEON! MONSTER ATTACK TABLE: when your attack fails, the monster
' strikes back -- roll 2d6 and apply the result.
SUB MonsterAttack (rm AS INTEGER)
    DIM r AS INTEGER, mon AS STRING, lost AS LONG, vanished AS INTEGER
    mon = _TRIM$(ROOMS(rm).monster)
    PushMonsterDice: r = DoRoll(2, 0, "the " + mon + "'s ATTACK -- roll ITS 2d6"): PopMonsterDice   ' Real Dice: you roll for the monster
    SELECT CASE r
        CASE 2                                  ' ADVENTURER KILLED!
            lost = gold
            ROOMS(rm).player_died = TRUE
            IF cur_player >= 1 AND cur_player <= 4 THEN deaths(cur_player) = deaths(cur_player) + 1
            vanished = FALSE                    ' SOULS-LIKE: a second fall forfeits an unreclaimed hoard
            IF opt_lootrecovery = 2 THEN vanished = AnyDropExists
            DropEverything rm                   ' killed = drop gold AND all special cards (in the room, MP)
            Sfx "lose"
            NarrateT "combat.downed", NARR_COMBAT   ' spoken "you fall" (Combat tier)
            IF vanished THEN
                Banner "You clutch your bloody fist to your chest and reach for the loot you had hoped to reclaim,", "as it vanishes before your very eyes -- and the world fades to black.   [ press any key ]"
            ELSEIF opt_lootrecovery >= 1 THEN
                IF rm <= ROOM_N THEN
                    Banner mon + " ATTACK (2): ADVENTURER KILLED!", "Your spoils (" + _TRIM$(STR$(lost)) + " gold + magic) lie in the " + _TRIM$(SECTORS(ROOMS(rm).sec).label) + " -- return for revenge!   [ press any key ]"
                ELSE
                    Banner mon + " ATTACK (2): ADVENTURER KILLED!", "Your spoils (" + _TRIM$(STR$(lost)) + " gold + magic) lie where you fell -- return for revenge!   [ press any key ]"
                END IF
            ELSE
                Banner mon + " ATTACK (2): ADVENTURER KILLED!", "You lose your treasure (" + _TRIM$(STR$(lost)) + " gold) and all magic, then crawl back to START.   [ press any key ]"
            END IF
            WaitKey                             ' let the death sink in before the transition
            ReviveOrForfeit rm                  ' blood (or grey forfeit) -> revive with a rally, or end the run
        CASE 3                                   ' SERIOUS WOUND
            lost = gold \ 2: gold = gold - lost
            Sfx "trap"
            NarrateT "combat.hurt", NARR_COMBAT     ' spoken "it wounds you" (Combat tier)
            Banner mon + " ATTACK (3): SERIOUS WOUND!", "You drop half your treasure (" + _TRIM$(STR$(lost)) + ") and retreat to START.   [ press any key ]"
            CombatPause
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
            start_heal_locked = TRUE             ' dragged home wounded -- the entrance does not patch that up
        CASE 4, 5, 6                             ' LIGHT WOUND
            lost = 1000: IF lost > gold THEN lost = gold
            gold = gold - lost
            Sfx "miss"
            Banner mon + " ATTACK (" + _TRIM$(STR$(r)) + "): LIGHT WOUND!", "You drop " + _TRIM$(STR$(lost)) + " gold, retreat, and lose the turn.   [ press any key ]"
            CombatPause
            c.x = c.prev_x: c.y = c.prev_y
            StartTurnMove
        CASE 7, 8                                ' STUNNED
            lost = 500: IF lost > gold THEN lost = gold
            gold = gold - lost
            Sfx "miss"
            Banner mon + " ATTACK (" + _TRIM$(STR$(r)) + "): STUNNED!", "You drop " + _TRIM$(STR$(lost)) + " gold.   [ press any key ]"
            CombatPause
            c.x = c.prev_x: c.y = c.prev_y
        CASE ELSE                                ' 9+ MISSED
            Sfx "bump"
            Banner "The " + mon + " " + MonVerb$(mon, "MISSES", "MISS") + "!  (" + _TRIM$(STR$(r)) + ")", "No harm done -- stand and fight again, or flee.   [ press any key ]"
            CombatPause
            c.x = c.prev_x: c.y = c.prev_y
    END SELECT
END SUB


' Award a slain room's treasure -- gold, or a special item card.
SUB ClaimTreasure (rm AS INTEGER, sm AS INTEGER)
    DIM slay AS STRING, line2 AS STRING, itm AS INTEGER, mon AS STRING, tname AS STRING, acb AS INTEGER
    DIM lvl AS INTEGER, goldbefore AS LONG, dfl AS STRING
    mon = _TRIM$(ROOMS(rm).monster): tname = _TRIM$(ROOMS(rm).treasure_name)
    lvl = ROOMS(rm).sec: goldbefore = gold                 ' chronicle this kill + its haul
    FX_MON = mon: FX_LEVEL = lvl: FX_TREASURE = tname      ' flavor context for the death line
    Sfx "monster-death"                                    ' the monster falls -- every slay funnels through here
    ' A crit that KILLS gets its own aftermath text -- the ordinary death line reads as a
    ' quiet expiry, which is the wrong note right after you have opened something up.
    IF fx_critkill THEN dfl = EventLine$(1, mon, 6) ELSE dfl = ""
    IF LEN(dfl) = 0 THEN dfl = EventLine$(1, mon, 5)        ' the monster's own death throes, if any
    fx_critkill = FALSE                                    ' consumed -- one kill, one aftermath
    IF LEN(dfl) > 0 THEN
        Sfx "treasure"
        Banner "The " + mon + " " + MonVerb$(mon, "is", "are") + " slain!", dfl + "   [ press any key ]"
        CombatPause
    END IF
    IF lvl >= 1 AND lvl <= 9 THEN lvl_kills(lvl) = lvl_kills(lvl) + 1: lvl_reached(lvl) = TRUE
    IF NOT opt_oldschool THEN                             ' Dungeon! has no XP and no levels -- D&D mode only
        char_xp = char_xp + XP_PER_KILL_LVL * lvl          ' XP scales with the monster's depth
        IF ROOMS(rm).is_boss THEN char_xp = char_xp + XP_PER_KILL_LVL * lvl   ' a boss is worth double
    END IF
    IF opt_oldschool THEN
        slay = "You slay the " + mon + "!  (2d6 = " + _TRIM$(STR$(sm)) + ")"
    ELSE
        slay = "You slay the " + mon + "!  (felled in " + _TRIM$(STR$(sm)) + " rounds)"
    END IF
    itm = ROOMS(rm).treasure_item
    IF ROOMS(rm).is_chamber THEN                           ' a CHAMBER monster guards NO treasure (board-game rule)
        RecordKill lvl, rm, mon, sm, 0, ""                 ' the kill still counts (bestiary + the grave)
        Sfx "treasure"
        Banner slay, "The chamber holds no treasure -- only more monsters.   [ press any key ]"
        CombatPause
        EXIT SUB
    END IF
    DIM newp AS INTEGER
    SELECT CASE itm
        CASE 1, 2                                ' Magic Sword
            IF player_class = 4 THEN             ' a Wizard cannot use a Magic Sword (rulebook: must return it)
                gold = gold + SellPrice&(500)
                LogTreasure "Magic Sword (sold)", 500
                line2 = "A " + tname + " -- a Wizard can't wield it; you sell it for 500 gold."
            ELSEIF opt_oldschool THEN            ' Dungeon!: one Magic Sword (+1) at a time -- no upgrading
                IF item_sword = 0 THEN
                    item_sword = 1
                    LogTreasure "Magic Sword", 500
                    line2 = "You take up the " + tname + " -- +1 to your attack rolls, and it can slay even a '-' monster!"
                ELSE
                    gold = gold + SellPrice&(500)
                    LogTreasure "Magic Sword (sold)", 500
                    line2 = "You already wield a Magic Sword (only one at a time) -- you sell this for 500 gold."
                END IF
            ELSE
                newp = itm                       ' D&D mode: a duplicate/weaker blade is reforged one step stronger
                IF newp <= item_sword THEN newp = item_sword + 1
                IF newp > 5 THEN newp = 5        ' +5 is the legendary cap
                IF newp > item_sword THEN
                    item_sword = newp
                    LogTreasure "Magic Sword +" + _TRIM$(STR$(item_sword)), 500 * item_sword
                    line2 = "You take up a finer blade -- your sword is now +" + _TRIM$(STR$(item_sword)) + " to attacks!"
                ELSE
                    gold = gold + SellPrice&(1000)
                    LogTreasure "Magic Sword (sold)", 1000
                    line2 = "Your blade is already legendary (+5) -- you sell this one for 1000 gold."
                END IF
            END IF
        CASE 3                                    ' Secret Door Card (binary -- unique; a spare is pack loot)
            IF item_secret_card THEN
                gold = gold + 250
                LogTreasure "Secret Door Card (spare)", 250
                line2 = "You already carry the Secret Door Card -- you shove the spare in your pack to sell in town (+250 gold)."
            ELSE
                item_secret_card = TRUE
                LogTreasure "Secret Door Card", 0
                line2 = "You find the SECRET DOOR CARD -- you now sense secret doors automatically!"
            END IF
        CASE 4                                    ' ESP Medallion (binary -- unique; a spare is pack loot)
            IF item_esp THEN
                gold = gold + SellPrice&(500)
                LogTreasure "ESP Medallion (spare)", 500
                line2 = "You already wear an ESP Medallion -- you stash the spare in your pack to sell in town (+500 gold)."
            ELSE
                item_esp = TRUE
                LogTreasure "ESP Medallion", 0
                line2 = "You don the ESP MEDALLION -- you now foresee the monster beyond a door!"
            END IF
        CASE 5                                    ' Crystal Ball (binary -- unique; a spare is pack loot)
            IF item_crystal THEN
                gold = gold + SellPrice&(1000)
                LogTreasure "Crystal Ball (spare)", 1000
                line2 = "You already keep a Crystal Ball -- you tuck the spare in your pack to sell in town (+1000 gold)."
            ELSE
                item_crystal = TRUE
                LogTreasure "Crystal Ball", 0
                line2 = "You grasp the CRYSTAL BALL -- press [V] to scry the whole dungeon!"
            END IF
        CASE 6                                    ' the LEVEL KEY (this game's key room)
            has_key = TRUE
            Sfx "key"
            gold = gold + ROOMS(rm).treasure
            IF ROOMS(rm).treasure > 0 THEN LogTreasure "Key Vault hoard", ROOMS(rm).treasure
            line2 = "You seize the LEVEL KEY! Now escape to the entrance with your gold to WIN."
        CASE 7, 8                                 ' Shield / Magic Armor -- an ARMOR CLASS item (D&D mode only)
            IF opt_oldschool THEN                  ' Dungeon! has no Armor Class -- it's simply loot to sell
                acb = 500 * lvl: IF acb < 500 THEN acb = 500
                gold = gold + acb
                LogTreasure _TRIM$(tname) + " (sold)", acb
                line2 = "The " + tname + " is fine work -- but there's no armour class to raise here; you sell it for " + _TRIM$(STR$(acb)) + " gold."
            ELSEIF itm = 7 THEN                   ' a SHIELD -- its own slot (adds to body armor)
                IF item_shield < 2 THEN
                    item_shield = 2
                    LogTreasure _TRIM$(tname) + " (+2 AC)", 1000
                    line2 = "You take up the " + tname + " -- +2 AC (now " + _TRIM$(STR$(player_ac + item_armor + item_shield)) + ")."
                ELSE
                    gold = gold + SellPrice&(500)
                    LogTreasure "Shield (spare)", 500
                    line2 = "You already carry a shield -- you sling the spare in your pack to sell in town (+500 gold)."
                END IF
            ELSE                                  ' BODY ARMOR -- its own slot
                IF item_armor < 3 THEN
                    item_armor = 3
                    LogTreasure _TRIM$(tname) + " (+3 AC)", 1500
                    line2 = "You don the " + tname + " -- +3 AC (now " + _TRIM$(STR$(player_ac + item_armor + item_shield)) + ")."
                ELSE
                    gold = gold + SellPrice&(750)
                    LogTreasure "Armor (spare)", 750
                    line2 = "You already wear good armor -- the spare set goes in your pack to sell in town (+750 gold)."
                END IF
            END IF
        CASE 9                                     ' Magic Bow (+2 to-hit) -- an ELF item, D&D mode
            IF NOT IsElf% THEN                      ' only the Elf is trained to the bow
                gold = gold + SellPrice&(500)
                LogTreasure _TRIM$(tname) + " (sold)", 500
                line2 = "A fine " + tname + " -- but only an Elf is trained to it; you sell it for 500 gold."
            ELSEIF opt_oldschool THEN               ' 2d6 combat has no to-hit bonus -- sell it
                gold = gold + SellPrice&(500)
                LogTreasure _TRIM$(tname) + " (sold)", 500
                line2 = "A fine " + tname + " -- but it lends no edge to a 2d6 fight; you sell it for 500 gold."
            ELSEIF NOT item_bow THEN
                item_bow = TRUE
                LogTreasure "Magic Bow", 0
                line2 = "You take up the " + tname + " -- +2 to hit, striking before they close!"
            ELSE
                gold = gold + SellPrice&(500)
                LogTreasure "Magic Bow (spare)", 500
                line2 = "You already carry a " + tname + " -- you sling the spare in your pack to sell in town (+500 gold)."
            END IF
        CASE 10                                    ' Elf Boots (+2 to the movement roll)
            IF NOT item_boots THEN
                item_boots = TRUE
                LogTreasure "Elf Boots", 0
                line2 = "You lace on the " + tname + " -- +2 to movement, and you slip away from fights far more easily!"
            ELSE
                gold = gold + SellPrice&(500)
                LogTreasure "Elf Boots (spare)", 500
                line2 = "You already run swift in your " + tname + " -- the spare pair goes in your pack to sell in town (+500 gold)."
            END IF
        CASE 11                                    ' Teleport Scroll (consumable, [T])
            item_teleport = item_teleport + 1
            LogTreasure "Teleport Scroll", 0
            line2 = "You pocket a TELEPORT SCROLL (" + _TRIM$(STR$(item_teleport)) + " held) -- press [T] to whisk to START."
        CASE 12                                    ' Fire Ball spell card (Wizard scribes it; any other class sells the scroll)
            IF player_class = 4 THEN
                spell_fire = spell_fire + 2
                LogTreasure "Fire Ball spell", 0
                line2 = "You inscribe the FIRE BALL into your spellbook (" + _TRIM$(STR$(spell_fire)) + " charges) -- press [F] in a fight to hurl it!"
            ELSE
                gold = gold + SellPrice&(500)
                LogTreasure _TRIM$(tname) + " (sold)", 500
                line2 = "The " + tname + " is written in arcane runes only a Wizard can read -- you sell it for 500 gold."
            END IF
        CASE 13                                    ' Lightning Bolt spell card (Wizard scribes it; any other class sells the scroll)
            IF player_class = 4 THEN
                spell_bolt = spell_bolt + 2
                LogTreasure "Lightning Bolt spell", 0
                line2 = "You inscribe the LIGHTNING BOLT into your spellbook (" + _TRIM$(STR$(spell_bolt)) + " charges) -- press [L] in a fight to loose it!"
            ELSE
                gold = gold + SellPrice&(500)
                LogTreasure _TRIM$(tname) + " (sold)", 500
                line2 = "The " + tname + " is written in arcane runes only a Wizard can read -- you sell it for 500 gold."
            END IF
        CASE ELSE                                 ' plain gold treasure
            gold = gold + ROOMS(rm).treasure
            LogTreasure tname, ROOMS(rm).treasure
            line2 = "You claim the " + tname + " -- " + _TRIM$(STR$(ROOMS(rm).treasure)) + " GOLD!"
    END SELECT
    IF lvl >= 1 AND lvl <= 9 THEN lvl_gold(lvl) = lvl_gold(lvl) + (gold - goldbefore)
    IF solo_on THEN                                        ' Item Search: claiming the quest treasure wins the solo run
        IF opt_solomode = SOLO_ITEM AND rm = solo_item_room THEN
            solo_found = TRUE
            Sfx "levelup"
            Banner "YOU FOUND IT -- the " + _TRIM$(solo_item_name) + "!", "Your solo treasure hunt is WON!   [ press any key ]"
            solo_result = OUT_WIN
        END IF
    END IF
    '--- chronicle the kill + its haul for the Game Menu screens ---
    DIM haulitem AS STRING
    IF itm >= 1 AND itm <= 13 THEN haulitem = tname: g_items_looted = g_items_looted + 1
    IF itm = 0 THEN RecordTreasure tname, ROOMS(rm).treasure
    RecordKill lvl, rm, mon, sm, gold - goldbefore, haulitem
    IF itm = 6 THEN                                        ' THE LEVEL KEY -- make the win-item unmissable
        PopArt "Level Key", "*  THE LEVEL KEY -- NOW ESCAPE!  *"
    ELSE
        PopArt tname, _TRIM$(tname)                        ' flash the treasure/item art you just claimed
    END IF
    NarrateNamed "mon." + NarrSlug$(mon), "combat.slay", NARR_COMBAT        ' the name, then "you slay it"
    Banner slay, line2 + "   [ press any key ]"
    CombatPause
    CritPotionReward                                        ' crits you landed pay out in healing (any fight)
    ' a real room's hoard may also hide a healing potion (1d8). Wanderers (scratch
    ' slot rm > ROOM_N) never drop one -- that would make them farmable.
    IF rm <= ROOM_N THEN
        IF NOT opt_oldschool THEN                       ' Dungeon! has no hit points -- no healing potions
            IF RollDie(100) <= TREASURE_POTION_PCT THEN ' occasional potion in the hoard
                IF RollDie(100) <= TREASURE_LARGE_PCT THEN   ' now and then it's the good stuff
                    item_potion_large = item_potion_large + 1
                    Sfx "treasure"
                    Banner "Among the spoils gleams a LARGE HEALING POTION!", "Press [H] in a fight to quaff it (heals 1d8+1).   [ press any key ]"
                ELSE
                    item_potion_small = item_potion_small + 1
                    Sfx "treasure"
                    Banner "Among the spoils glints a SMALL HEALING POTION!", "Press [H] in a fight to quaff it (heals 1d4).   [ press any key ]"
                END IF
                CombatPause
            END IF
        END IF
        ' clearing every room of a level: a healing cache + (D&D) a level-up
        IF lvl >= 1 AND lvl <= 9 THEN
            IF NOT lvl_cleared(lvl) THEN
                IF LevelFullyCleared(lvl) THEN GrantLevelClear lvl
            END IF
        END IF
        ' Curio chests spring HP-damaging traps and drop healing potions -- neither exists
        ' in Dungeon!, so they're a D&D-mode feature only.
        IF NOT opt_oldschool AND RollDie(100) <= CHEST_PCT THEN DoCurio rm   ' a curio may turn up after the fight
    END IF
END SUB


' FIGHTING WELL PAYS FOR ITSELF: every critical hit you land in a fight improves the odds that
' its spoils include a healing potion, and that the potion is the LARGE kind.
'
'   chance of a potion at all : 20% per crit, capped at 80%   (1 crit 20, 2 40, 3 60, 4+ 80)
'   chance it is a LARGE one  : 50% at one crit, +10% each further crit, capped at 80%
'
' This is deliberately separate from the room hoard's own TREASURE_POTION_PCT roll (which only
' a real room can yield): the reward here is earned by HOW you fought, not by what the monster
' was guarding, so it pays out on chamber guardians and wandering ambushes too. No crits, no
' roll -- so it cannot be farmed by grinding easy fights, only by landing natural 20s.
SUB CritPotionReward
    DIM pct AS INTEGER, lgpct AS INTEGER
    IF opt_oldschool THEN EXIT SUB                 ' Dungeon! has no hit points, so no potions
    IF combat_crits <= 0 THEN EXIT SUB
    pct = 20 * combat_crits: IF pct > 80 THEN pct = 80
    IF NOT PctChance%(pct) THEN EXIT SUB
    lgpct = 40 + 10 * combat_crits: IF lgpct > 80 THEN lgpct = 80
    Sfx "treasure"
    IF PctChance%(lgpct) THEN
        item_potion_large = item_potion_large + 1
        CurioGain "Large Healing Potion", 0
        Banner "Your killing strokes were clean -- and the spoils generous.", "A LARGE HEALING POTION (1d8+1). Press [H] in a fight.   [ press any key ]"
    ELSE
        item_potion_small = item_potion_small + 1
        CurioGain "Small Healing Potion", 0
        Banner "Your killing strokes were clean -- and the spoils generous.", "A SMALL HEALING POTION (1d4). Press [H] in a fight.   [ press any key ]"
    END IF
    CombatPause
END SUB


' TRUE once every monster-bearing room of a dungeon level has been slain.
FUNCTION LevelFullyCleared% (lvl AS INTEGER)
    DIM r AS INTEGER
    LevelFullyCleared = FALSE
    FOR r = 1 TO ROOM_N
        IF ROOMS(r).sec = lvl AND LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN
            IF ROOMS(r).malive THEN EXIT FUNCTION      ' a lair still holds a live monster
        END IF
    NEXT r
    LevelFullyCleared = TRUE
END FUNCTION


' Reward for sweeping a whole floor: mark it cleared (now a safe zone), grant a
' healing cache (small potion always; a large one LEVELCLEAR_LARGE_PCT of the time),
' and in D&D mode advance the character a level -- rolling the class hit die for +HP.
SUB GrantLevelClear (lvl AS INTEGER)
    DIM hpgain AS INTEGER, got AS STRING
    lvl_cleared(lvl) = TRUE
    RecordLevelDone lvl                             ' chronicle: levels completed
    Sfx "win"
    Banner "The " + Ordinal$(lvl) + " level is CLEARED!", "Every lair on this floor lies empty -- it is a safe haven now.   [ press any key ]"
    CombatPause
    IF NOT opt_oldschool THEN                       ' D&D level-up: +1 level, roll the hit die for HP
        char_level = char_level + 1
        hpgain = GameRoll(1, CLASSES(player_class).hitdie, AbilMod(player_con), "LEVEL UP! roll your hit die")
        IF hpgain < 1 THEN hpgain = 1
        player_maxhp = player_maxhp + hpgain
        player_hp = player_maxhp                    ' fully restored on level-up
        Sfx "key"
        DIM lusay AS STRING
        lusay = LevelUpSaying$
        DIM lukey AS STRING
        lukey = FX_NARRKEY                          ' captured before anything else picks a line
        IF LEN(lusay) > 0 THEN lusay = lusay + "   " ELSE lusay = ""
        IF LEN(lukey) > 0 THEN Narrate lukey
        Banner "** LEVEL UP! **  You are now character level " + _TRIM$(STR$(char_level)) + ".", lusay + "+" + _TRIM$(STR$(hpgain)) + " max HP (now " + _TRIM$(STR$(player_maxhp)) + ") and fully rested.   [ press any key ]"
        CombatPause
        LuckRefill                                  ' luck refills every level -- BEFORE the stat
        LevelUpStatPoint                            ' point, so raising CHA pays out next level
        LuckRefill                                  ' ...and again, in case that point WAS CHA
        cursor_erase: cursor_draw: DrawHUD: Present ' the picker painted over the board
    END IF
    IF NOT opt_oldschool THEN                       ' no HP in Dungeon! -- no healing cache either
        item_potion_small = item_potion_small + 1
        got = "a SMALL HEALING POTION (1d4)"
        IF RollDie(100) <= LEVELCLEAR_LARGE_PCT THEN
            item_potion_large = item_potion_large + 1
            got = got + " and a LARGE one (1d8+1)"
        END IF
        Sfx "treasure"
        Banner "The cleared floor yields " + got + ".", "Press [H] in a fight to quaff a potion.   [ press any key ]"
        CombatPause
    END IF
END SUB


' Quaff a healing potion. If the player holds both sizes, ask which; otherwise
' drink whatever is held. Heals the rolled amount (small 1d4 / large 1d8), capped
' at max HP. A free action in combat (no monster riposte). silentIfNone TRUE
' suppresses the "no potions" nag (used when [H] is pressed on the board).
SUB UsePotion (silentIfNone AS INTEGER)
    DIM which AS INTEGER, heal AS INTEGER
    IF item_potion_small <= 0 AND item_potion_large <= 0 THEN
        IF NOT silentIfNone THEN
            Banner "You have no healing potions.", "Slay monsters and clear floors to find them.   [ press any key ]"
            WaitKey
        END IF
        EXIT SUB
    END IF
    IF player_hp >= player_maxhp THEN               ' already full -- don't waste a potion
        Banner "The darkness chills your exposed skin and you reach for a swig of your potion,", "but realize before drinking that you are fully healthy -- you put it away for later.   [ press any key ]"
        WaitKey
        EXIT SUB
    END IF
    which = 0
    IF item_potion_small > 0 AND item_potion_large > 0 THEN
        which = AskPotionChoice
        IF which = 0 THEN EXIT SUB                  ' cancelled
    ELSEIF item_potion_large > 0 THEN
        which = 2
    ELSE
        which = 1
    END IF
    IF which = 1 THEN
        item_potion_small = item_potion_small - 1
        heal = GameRoll(1, POTION_SMALL_DIE, 0, "SMALL HEALING POTION")
    ELSE
        item_potion_large = item_potion_large - 1
        heal = GameRoll(1, POTION_LARGE_DIE, POTION_LARGE_BONUS, "LARGE HEALING POTION")
    END IF
    IF heal < 1 THEN heal = 1
    player_hp = player_hp + heal
    IF player_hp > player_maxhp THEN player_hp = player_maxhp
    Sfx "treasure"
    Banner "You quaff the potion and recover " + _TRIM$(STR$(heal)) + " HP.", "Now at " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + " HP.   [ press any key ]"
    CombatPause
END SUB


' Prompt which potion to drink when the player holds both. Returns 1 small, 2 large, 0 cancel.
FUNCTION AskPotionChoice%
    DIM k AS STRING
    Banner "Which potion? [S] small (1d4, " + _TRIM$(STR$(item_potion_small)) + " held)   [L] large (1d8, " + _TRIM$(STR$(item_potion_large)) + " held)", "[ESC] cancel"
    DO
        _LIMIT 60
        k = UCASE$(INKEY$)
        IF k = "S" THEN AskPotionChoice = 1: EXIT FUNCTION
        IF k = "L" THEN AskPotionChoice = 2: EXIT FUNCTION
        IF k = CHR$(27) THEN AskPotionChoice = 0: EXIT FUNCTION
        Present
    LOOP
END FUNCTION


' Record a named treasure in the active player's log (shown on the character sheet).
SUB LogTreasure (nm AS STRING, g AS LONG)
    IF cur_player < 1 OR cur_player > 4 THEN EXIT SUB
    IF LOOT_N(cur_player) >= UBOUND(LOOT_NAME, 2) THEN EXIT SUB
    LOOT_N(cur_player) = LOOT_N(cur_player) + 1
    LOOT_NAME(cur_player, LOOT_N(cur_player)) = nm
    LOOT_GOLD(cur_player, LOOT_N(cur_player)) = g
END SUB


' A small framed art tile INSIDE the combat panel, with its caption on the bottom edge of the
' frame (CombatArtBox puts the caption ABOVE, which here would land outside the panel).
' Silent when the path is empty -- ArtFile$ returns "" whenever the selected art style has no
' art for the subject, so no art style needs a special case here.
SUB PanelArt (path AS STRING, col AS INTEGER, cols AS INTEGER, row AS INTEGER, rows AS INTEGER, caption AS STRING, edge AS _UNSIGNED LONG)
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER, cap AS STRING, capx AS INTEGER
    IF LEN(path) = 0 THEN EXIT SUB
    bx = col * CW: by = row * CH: bw = cols * CW: bh = rows * CH
    _DEST CANVAS
    LINE (bx, by)-(bx + bw, by + bh), edge, B
    IF DrawSpriteFit%(path, bx + 1, by + 1, bw - 2, bh - 2) = 0 THEN EXIT SUB
    cap = caption
    IF LEN(cap) > cols THEN cap = LEFT$(cap, cols)
    capx = bx + (bw - LEN(cap) * CW) \ 2
    COLOR edge, BOXBG
    _PRINTSTRING (capx, by + bh - CH \ 2), cap
END SUB

' WeaponName$ is written for prose ("your +1 blade"), which reads oddly as a label under a
' picture. Same weapon, named for a caption.
FUNCTION WeaponLabel$
    IF item_sword > 0 THEN WeaponLabel$ = "+" + _TRIM$(STR$(item_sword)) + " BLADE": EXIT FUNCTION
    SELECT CASE player_class
        CASE 4: WeaponLabel$ = "STAFF"
        CASE 2: WeaponLabel$ = "ELVEN BLADE"
        CASE ELSE: WeaponLabel$ = "SWORD"
    END SELECT
END FUNCTION


' ============================================================================
'  LUCK -- CHA-funded re-rolls.
'
'  Rick's spec: offered on combat rolls and saving throws, natural 1s included; the re-roll is
'  PERMANENT whatever it brings; a re-roll can never itself be re-rolled; the count refills on
'  every level-up; and the prompt is a 2-second fuse showing "X/Y Use Luck [R]e-Roll?" over a
'  countdown bar, like the flourish gauge.
' ============================================================================

' Refill to the CHA modifier. Called at character creation and on every level-up.
' A CHA modifier of 0 or less simply means no luck -- the feature is off for that character
' rather than special-cased, which is what makes raising CHA at level-up worth something.
SUB LuckRefill
    luck_max = AbilMod(player_cha)
    IF luck_max < 0 THEN luck_max = 0
    luck_left = luck_max
END SUB

' Roll, then offer to spend luck on the result. Returns the FINAL value.
'
' Use this instead of GameRoll at the sites that matter (attack, damage, saves). Everywhere
' else keeps calling GameRoll, which is what stops luck turning into a prompt on every step.
FUNCTION LuckyRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, label AS STRING)
    DIM v AS INTEGER, raw AS INTEGER
    v = GameRoll(n, sides, bonus, label)
    IF NOT LuckAvailable% THEN LuckyRoll% = v: EXIT FUNCTION
    raw = last_raw                                  ' preserved: the re-roll overwrites it
    IF NOT LuckPrompt%(v, raw, sides) THEN LuckyRoll% = v: EXIT FUNCTION
    luck_left = luck_left - 1
    luck_rerolling = TRUE                           ' the second roll gets no second chance
    v = GameRoll(n, sides, bonus, label + "  (LUCK re-roll)")
    luck_rerolling = FALSE
    Sfx "levelup"
    LogEvent _TRIM$(player_name) + " spent luck: " + _TRIM$(STR$(raw)) + " -> " + _TRIM$(STR$(last_raw))
    LuckyRoll% = v
END FUNCTION

' Is a luck re-roll possible right now?
FUNCTION LuckAvailable%
    LuckAvailable% = 0
    IF NOT opt_luck THEN EXIT FUNCTION
    IF opt_oldschool THEN EXIT FUNCTION             ' 2d6 Dungeon! has no ability scores to fund it
    IF luck_rerolling THEN EXIT FUNCTION            ' cannot re-roll a re-roll
    IF luck_left <= 0 THEN EXIT FUNCTION
    LuckAvailable% = -1
END FUNCTION

' The fuse prompt. TRUE if the player spent a luck point before the fuse ran out.
FUNCTION LuckPrompt% (total AS INTEGER, raw AS INTEGER, sides AS INTEGER)
    DIM t0 AS DOUBLE, el AS DOUBLE, frac AS SINGLE, k AS STRING, saveimg AS LONG
    LuckPrompt% = 0
    saveimg = _NEWIMAGE(SW * CW, SH * CH, 32)       ' the prompt is transient -- put the screen back
    _PUTIMAGE (0, 0), CANVAS, saveimg
    t0 = TIMER
    DO
        el = TIMER - t0
        IF el < 0 THEN el = el + 86400#             ' TIMER wraps at midnight
        frac = 1 - (el / LUCK_FUSE_SEC)
        IF frac <= 0 THEN EXIT DO
        DrawLuckPrompt total, raw, sides, frac
        Present
        k = UCASE$(INKEY$)
        IF k = "R" THEN LuckPrompt% = -1: EXIT DO
        IF k = CHR$(27) OR k = " " THEN EXIT DO     ' decline early rather than wait it out
        _LIMIT 60
    LOOP
    _PUTIMAGE (0, 0), saveimg, CANVAS
    _FREEIMAGE saveimg
END FUNCTION

' "3/4  Use Luck [R]e-Roll?  ====== " over a draining bar, matching the flourish fuse.
SUB DrawLuckPrompt (total AS INTEGER, raw AS INTEGER, sides AS INTEGER, frac AS SINGLE)
    DIM bx AS INTEGER, bw AS INTEGER, by AS INTEGER, bh AS INTEGER
    DIM fx AS INTEGER, fw AS INTEGER, fcol AS _UNSIGNED LONG, lbl AS STRING
    bx = 40: bw = 52: by = 32: bh = 5
    _DEST CANVAS
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
    LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), YELLOWU, B
    lbl = _TRIM$(STR$(luck_left)) + "/" + _TRIM$(STR$(luck_max)) + "   Use Luck [R]e-Roll?"
    COLOR YELLOWU, BOXBG: PrintCentered by + 1, lbl
    COLOR GREY, BOXBG: PrintCentered by + 2, "you rolled " + _TRIM$(STR$(raw)) + " of " + _TRIM$(STR$(sides)) + "  (total " + _TRIM$(STR$(total)) + ")"
    ' the fuse: same colours and the same "turns red near the end" cue as the gesture gauge,
    ' so the two prompts read as one language rather than two unrelated widgets
    fx = (bx + 3) * CW: fw = (bw - 6) * CW
    LINE (fx, (by + 3) * CH)-(fx + fw, (by + 4) * CH - 4), _RGB32(40, 40, 46), BF
    IF frac > 0.35 THEN fcol = _RGB32(170, 150, 70) ELSE fcol = _RGB32(220, 60, 50)
    LINE (fx, (by + 3) * CH)-(fx + INT(fw * frac), (by + 4) * CH - 4), fcol, BF
END SUB


' ============================================================================
'  BARTER -- CHA decides what you get for a sale, and what you pay for a purchase.
'
'  Every "you sell the spare" in ClaimTreasure and every priced curio goes through these, so
'  the modifier lives in ONE place rather than at a dozen call sites where it would drift.
'
'  +/-8% per point of CHA modifier, clamped to +/-40%: enough to feel, never enough to make
'  selling spares a better living than adventuring.
' ============================================================================

' What you actually receive for something worth `base`.
FUNCTION SellPrice& (amt AS LONG)   ' `amt`, not `base`: BASE is reserved (OPTION BASE)
    DIM pct AS INTEGER
    SellPrice& = amt
    IF opt_oldschool THEN EXIT FUNCTION          ' no ability scores in Dungeon! mode
    pct = 8 * AbilMod(player_cha)
    IF pct < -40 THEN pct = -40
    IF pct > 40 THEN pct = 40
    DIM v AS LONG
    v = amt + (amt * pct) \ 100
    IF v < 1 THEN v = 1                          ' a local, not the return slot: QB64 reads a bare
    SellPrice& = v                               ' `SellPrice&` in an expression as a CALL
END FUNCTION

' What something priced `amt` actually costs you. The sign is inverted: charm makes you PAY
' less, where it makes you RECEIVE more.
FUNCTION BuyPrice& (amt AS LONG)
    DIM pct AS INTEGER
    BuyPrice& = amt
    IF opt_oldschool THEN EXIT FUNCTION
    pct = 8 * AbilMod(player_cha)
    IF pct < -40 THEN pct = -40
    IF pct > 40 THEN pct = 40
    DIM w AS LONG
    w = amt - (amt * pct) \ 100
    IF w < 1 THEN w = 1
    BuyPrice& = w
END FUNCTION


' A curse costs you a point of damage as well as a point of to-hit -- "-1 to attack and damage"
' is the whole effect, and applying only half of it would make curses read as a rounding error.
FUNCTION CurseDmgPenalty%
    IF curse_turns > 0 THEN CurseDmgPenalty% = 1 ELSE CurseDmgPenalty% = 0
END FUNCTION
