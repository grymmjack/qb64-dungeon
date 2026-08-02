' ============================================================================
'  REST AT THE ENTRANCE -- the scripted version of going home to heal.
'
'  The MECHANIC already existed (Game_OnEnterCell restores hp_start_amount once per trip). This
'  is the presentation Rick asked for: a wash to white for the passage of days, an image, the
'  scrawling text, narration and the sounds of somewhere safe.
'
'  Deliberately NOT factored together with the in-dungeon [R]est -- Rick called them two
'  separate features, and they are: this one is a set piece at a fixed place, that one is an
'  ordinary action with its own risk.
'
'  White, not black: black reads as "you passed out", white reads as "days went by". That is
'  exactly the difference between dying and resting, and the transition should say which.
' ============================================================================
SUB RestAtEntrance (healed AS INTEGER)
    DIM body AS STRING
    Sfx "rest-water"                             ' somewhere with clean running water
    FlashWhite 0.35                              ' the days pass
    Sfx "rest-breath"                            ' ...and you can finally breathe out
    body = "Having sustained wounds you rest at the entrance to heal and recuperate."
    body = body + "  You are healed after a few days."
    IF healed > 0 THEN body = body + "  (+" + _TRIM$(STR$(healed)) + " HP, now " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + ")"
    ScrollTextArtKey "R E S T", body, ArtFile$("events/rest.png"), "rest.entrance"
    Sfx "rest-gold"                              ' the light on your hoard, before you go back down
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB



' ============================================================================
'  AMBIENCE -- a distant noise every so often, chosen by which level you are on.
'
'  Called once per play-loop frame. It is deliberately NOT wired into combat,
'  menus or banners: a scream landing on top of a combat banner reads as a bug,
'  and the point of ambience is the quiet between events.
'
'  Ambience never falls back to the tone beeper. Sfx would happily beep a missing
'  effect, but a PC-speaker blip is a UI sound -- a distant noise that is not
'  there should be SILENCE, not a chirp. So this checks SfxHandle& first.
' ============================================================================
SUB AmbienceTick
    DIM i AS INTEGER, tot AS LONG, pick AS LONG, lvl AS INTEGER, span AS INTEGER
    IF AMB_SECS_MIN <= 0 THEN EXIT SUB                 ' tuning.txt: ambience switched off
    IF NOT opt_sfx THEN EXIT SUB
    IF AMB_N <= 0 THEN EXIT SUB
    IF amb_ticks > 0 THEN amb_ticks = amb_ticks - 1: EXIT SUB
    span = AMB_SECS_MAX - AMB_SECS_MIN
    IF span < 1 THEN span = 1
    amb_ticks = (AMB_SECS_MIN + RollDie(span)) * 60&    ' _LIMIT 60, so a frame is 1/60s
    lvl = PlayerLevel%
    ' Weighted pick across this level's rows PLUS the level-0 "any level" rows. Two passes:
    ' total the weights, then walk them again -- with no live sound file the row is skipped, so
    ' a pack that ships half the ambience still picks fairly among what it actually has.
    tot = 0
    FOR i = 1 TO AMB_N
        IF AMB_LVL(i) = 0 OR AMB_LVL(i) = lvl THEN
            IF SfxHandle&(AMB_NAME(i)) > 0 THEN tot = tot + AMB_W(i)
        END IF
    NEXT i
    IF tot <= 0 THEN EXIT SUB                          ' nothing audible for this level -- stay quiet
    pick = RollDie(tot)
    FOR i = 1 TO AMB_N
        IF AMB_LVL(i) = 0 OR AMB_LVL(i) = lvl THEN
            IF SfxHandle&(AMB_NAME(i)) > 0 THEN
                pick = pick - AMB_W(i)
                IF pick <= 0 THEN Sfx AMB_NAME(i): EXIT SUB
            END IF
        END IF
    NEXT i
END SUB

' ============================================================================
'  PLAY.bas -- GAME play-loop support (extracted from dungeon.bas).
'
'  Loot drops (a fallen champion's spoils, per-room + loose-on-the-paths),
'  lingering-danger / loiter omens, the wandering-monster + chamber encounters,
'  and the pause overlay. Called by the play loop and the movement hook.
' ============================================================================

' On death a champion drops EVERYTHING carried -- gold and all special cards. In
' multiplayer the loot is left IN the room (rm) for any player to recover; solo it
' is simply lost (recovering your own would void the death penalty).
SUB DropEverything (rm AS INTEGER)
    ' With Loot Recovery on, the spoils are LEFT to reclaim (solo: trek back for
    ' revenge; multiplayer: any rival can grab it). A ROOM death stashes them in the
    ' room; a PATH/wander death (scratch slot rm > ROOM_N) has no room, so it drops a
    ' LOOSE marker on the exact cell where you fell -- reclaimable all the same.
    ' EVERYTHING carried goes into the stash, not just gold + the three cards. The wipe
    ' below clears the WHOLE kit, so anything not stashed here is destroyed outright and
    ' the walk back rewards you with a fraction of what you lost.
    IF opt_lootrecovery >= 1 THEN
        IF opt_lootrecovery = 2 THEN ClearAllDrops: ClearLooseDrops   ' SOULS-LIKE: only your most recent death's spoils survive
        IF rm >= 1 AND rm <= ROOM_N THEN
            ROOMS(rm).drop_gold = ROOMS(rm).drop_gold + gold
            IF item_sword > ROOMS(rm).drop_sword THEN ROOMS(rm).drop_sword = item_sword
            IF item_secret_card THEN ROOMS(rm).drop_secret = TRUE
            IF item_esp THEN ROOMS(rm).drop_esp = TRUE
            IF item_crystal THEN ROOMS(rm).drop_crystal = TRUE
            IF item_armor > ROOMS(rm).drop_armor THEN ROOMS(rm).drop_armor = item_armor
            IF item_shield > ROOMS(rm).drop_shield THEN ROOMS(rm).drop_shield = item_shield
            IF item_bow THEN ROOMS(rm).drop_bow = TRUE
            IF item_boots THEN ROOMS(rm).drop_boots = TRUE
            ROOMS(rm).drop_teleport = ROOMS(rm).drop_teleport + item_teleport
            ROOMS(rm).drop_pot_sm = ROOMS(rm).drop_pot_sm + item_potion_small
            ROOMS(rm).drop_pot_lg = ROOMS(rm).drop_pot_lg + item_potion_large
        ELSEIF CarryingAnything% THEN
            AddLooseDrop c.x \ CW, c.y \ CH          ' fell out on the paths -- spoils lie where you dropped
        END IF
    END IF
    DIM dlvl AS INTEGER                              ' chronicle the death (Game Menu / Event Log)
    IF rm >= 1 AND rm <= ROOM_N THEN dlvl = ROOMS(rm).sec ELSE dlvl = PlayerLevel%
    RecordDeath dlvl, rm, combat_mon, combat_round, gold
    gold = 0
    item_sword = 0
    item_secret_card = FALSE: item_esp = FALSE: item_crystal = FALSE
    item_armor = 0: item_shield = 0: item_bow = FALSE: item_boots = FALSE: item_teleport = 0
    item_potion_small = 0: item_potion_large = 0
    IF cur_player >= 1 AND cur_player <= 4 THEN LOOT_N(cur_player) = 0   ' the treasure log goes too
END SUB


' TRUE if the player carries anything a death could leave behind. Used to decide whether a
' path/wander fall is worth a loose marker at all -- it must test the SAME set DropEverything
' stashes, or a hero carrying only (say) potions and boots would lose them with no marker.
FUNCTION CarryingAnything% ()
    CarryingAnything% = 0
    IF gold > 0 THEN CarryingAnything% = -1: EXIT FUNCTION
    IF item_sword > 0 OR item_armor > 0 OR item_shield > 0 THEN CarryingAnything% = -1: EXIT FUNCTION
    IF item_secret_card OR item_esp OR item_crystal THEN CarryingAnything% = -1: EXIT FUNCTION
    IF item_bow OR item_boots THEN CarryingAnything% = -1: EXIT FUNCTION
    IF item_teleport > 0 OR item_potion_small > 0 OR item_potion_large > 0 THEN CarryingAnything% = -1
END FUNCTION


' Wipe every room's recoverable drop -- SOULS-LIKE mode calls this on each death,
' so dying again before you reclaim your last hoard loses it forever.
SUB ClearAllDrops
    DIM r AS INTEGER
    FOR r = 1 TO ROOM_N
        ClearRoomDrop r
    NEXT r
END SUB


' Zero one room's whole drop record. Every site that used to spell the five fields out by
' hand now calls this, so adding a carried item to the stash cannot leave a stale value
' behind in a scratch slot that a later fight reuses.
SUB ClearRoomDrop (r AS INTEGER)
    IF r < 1 OR r > UBOUND(ROOMS) THEN EXIT SUB
    ROOMS(r).drop_gold = 0: ROOMS(r).drop_sword = 0
    ROOMS(r).drop_secret = FALSE: ROOMS(r).drop_esp = FALSE: ROOMS(r).drop_crystal = FALSE
    ROOMS(r).drop_armor = 0: ROOMS(r).drop_shield = 0
    ROOMS(r).drop_bow = FALSE: ROOMS(r).drop_boots = FALSE
    ROOMS(r).drop_teleport = 0: ROOMS(r).drop_pot_sm = 0: ROOMS(r).drop_pot_lg = 0
END SUB


' --- LOOSE DROPS: spoils left where a fall happened out on the open paths --------
' A room death uses the room's own drop_* fields; a path/wander death has no room,
' so it drops here, keyed to the exact board cell. Painted as a blood-red body by
' DrawEntities and reclaimed by stepping onto the cell (checked in the move loop).

' Record the player's current gold + magic at a board CELL. Merges into an existing
' drop on the same cell; else takes a free slot, else overwrites the oldest.
SUB AddLooseDrop (cx AS INTEGER, cy AS INTEGER)
    DIM i AS INTEGER, slot AS INTEGER
    slot = 0
    FOR i = 1 TO UBOUND(LOOSE)                        ' reuse a drop already on this cell
        IF LOOSE(i).active AND LOOSE(i).cx = cx THEN IF LOOSE(i).cy = cy THEN slot = i: EXIT FOR
    NEXT
    IF slot = 0 THEN
        FOR i = 1 TO UBOUND(LOOSE)                    ' first free slot
            IF NOT LOOSE(i).active THEN slot = i: EXIT FOR
        NEXT
    END IF
    IF slot = 0 THEN slot = 1                         ' all full -- overwrite the oldest
    LOOSE(slot).active = -1: LOOSE(slot).cx = cx: LOOSE(slot).cy = cy
    LOOSE(slot).gold = LOOSE(slot).gold + gold
    IF item_sword > LOOSE(slot).sword THEN LOOSE(slot).sword = item_sword
    IF item_secret_card THEN LOOSE(slot).secret = -1
    IF item_esp THEN LOOSE(slot).esp = -1
    IF item_crystal THEN LOOSE(slot).crystal = -1
    IF item_armor > LOOSE(slot).armor THEN LOOSE(slot).armor = item_armor
    IF item_shield > LOOSE(slot).shield THEN LOOSE(slot).shield = item_shield
    IF item_bow THEN LOOSE(slot).bow = -1
    IF item_boots THEN LOOSE(slot).boots = -1
    LOOSE(slot).teleport = LOOSE(slot).teleport + item_teleport
    LOOSE(slot).pot_sm = LOOSE(slot).pot_sm + item_potion_small
    LOOSE(slot).pot_lg = LOOSE(slot).pot_lg + item_potion_large
END SUB

' Index of an active loose drop on a cell (0 if none).
FUNCTION LooseAt% (cx AS INTEGER, cy AS INTEGER)
    DIM i AS INTEGER
    LooseAt% = 0
    FOR i = 1 TO UBOUND(LOOSE)
        IF LOOSE(i).active AND LOOSE(i).cx = cx THEN IF LOOSE(i).cy = cy THEN LooseAt% = i: EXIT FUNCTION
    NEXT
END FUNCTION

' Reclaim the loose drop on a cell (called when the player steps onto it).
SUB CollectLooseAt (cx AS INTEGER, cy AS INTEGER)
    DIM i AS INTEGER, got AS STRING
    i = LooseAt%(cx, cy): IF i = 0 THEN EXIT SUB
    got = ""
    IF LOOSE(i).gold > 0 THEN gold = gold + LOOSE(i).gold: got = _TRIM$(STR$(LOOSE(i).gold)) + " gold"
    ' The magic goes through the SAME granter the room hoard uses, so a fall in a corridor
    ' and a fall in a room can never hand back different halves of the same kit.
    GrantDropKit got, LOOSE(i).sword, LOOSE(i).secret, LOOSE(i).esp, LOOSE(i).crystal, LOOSE(i).armor, LOOSE(i).shield, LOOSE(i).bow, LOOSE(i).boots, LOOSE(i).teleport, LOOSE(i).pot_sm, LOOSE(i).pot_lg
    ClearLooseSlot i
    Sfx "treasure"
    Banner "You recover the spoils from where you fell.", _TRIM$(got) + "   [ press any key ]"
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB

' Grant one stash's magic to the player and append what was actually taken to `got`.
' Shared by the room hoard (CollectDrop) and the corridor fall (CollectLooseAt), so the two
' can never hand back different halves of the same kit.
'
' Note the Magic Sword rule: a Wizard cannot wield one, and a WORSE blade than the one you
' already carry is left behind -- so a sword can legitimately go unclaimed. Everything else
' is strictly additive, which is why potions/scrolls ACCUMULATE rather than take a maximum.
' Nested IFs on the sword, not `AND`: QB64 evaluates both sides of an AND.
SUB GrantDropKit (got AS STRING, sword AS INTEGER, secret AS INTEGER, esp AS INTEGER, crystal AS INTEGER, armr AS INTEGER, shld AS INTEGER, bw AS INTEGER, bts AS INTEGER, tport AS INTEGER, potsm AS INTEGER, potlg AS INTEGER)
    IF sword > item_sword THEN
        IF player_class <> 4 THEN item_sword = sword: got = got + "   a Magic Sword +" + _TRIM$(STR$(sword))
    END IF
    IF secret THEN item_secret_card = TRUE: got = got + "   a Secret Door Card"
    IF esp THEN item_esp = TRUE: got = got + "   an ESP Medallion"
    IF crystal THEN item_crystal = TRUE: got = got + "   a Crystal Ball"
    IF armr > item_armor THEN item_armor = armr: got = got + "   Armor +" + _TRIM$(STR$(armr)) + " AC"
    IF shld > item_shield THEN item_shield = shld: got = got + "   a Shield +" + _TRIM$(STR$(shld)) + " AC"
    IF bw THEN item_bow = TRUE: got = got + "   a Magic Bow"
    IF bts THEN item_boots = TRUE: got = got + "   Elf Boots"
    IF tport > 0 THEN item_teleport = item_teleport + tport: got = got + "   Teleport x" + _TRIM$(STR$(tport))
    IF potsm > 0 THEN item_potion_small = item_potion_small + potsm: got = got + "   Sm Potion x" + _TRIM$(STR$(potsm))
    IF potlg > 0 THEN item_potion_large = item_potion_large + potlg: got = got + "   Lg Potion x" + _TRIM$(STR$(potlg))
END SUB


' Zero one loose slot (all fields), so a reused slot can't inherit a previous fall's kit.
SUB ClearLooseSlot (i AS INTEGER)
    IF i < 1 OR i > UBOUND(LOOSE) THEN EXIT SUB
    LOOSE(i).active = 0: LOOSE(i).gold = 0: LOOSE(i).sword = 0
    LOOSE(i).secret = 0: LOOSE(i).esp = 0: LOOSE(i).crystal = 0
    LOOSE(i).armor = 0: LOOSE(i).shield = 0: LOOSE(i).bow = 0: LOOSE(i).boots = 0
    LOOSE(i).teleport = 0: LOOSE(i).pot_sm = 0: LOOSE(i).pot_lg = 0
END SUB


' Wipe every loose drop (SOULS-LIKE death forfeits an unreclaimed fall, like ClearAllDrops).
SUB ClearLooseDrops
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(LOOSE)
        ClearLooseSlot i
    NEXT
END SUB


' TRUE if any room OR loose cell still holds a recoverable drop. Used at a SOULS-LIKE
' death to tell "first fall (a hoard to return for)" from "fell again -- lost forever".
FUNCTION AnyDropExists% ()
    DIM r AS INTEGER
    AnyDropExists = 0
    FOR r = 1 TO ROOM_N
        IF HasDrop(r) THEN AnyDropExists = -1: EXIT FUNCTION
    NEXT r
    FOR r = 1 TO UBOUND(LOOSE)
        IF LOOSE(r).active THEN AnyDropExists = -1: EXIT FUNCTION
    NEXT r
END FUNCTION


' Freeze the game so the player can step away (bio break). Halts the idle/real-time
' clock -- the caller resets idle_ticks on return. Any key resumes.
SUB PauseGame
    DIM k AS STRING
    Sfx "idle"
    Banner "-- PAUSED --", "Take your time.   [ press any key to resume ]"
    DO
        _LIMIT 30
        k = INKEY$
        Present
    LOOP UNTIL k <> ""
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' TRUE if a room holds recoverable dropped loot. Must test EVERY drop_* field: a hoard of
' nothing but (say) potions and boots would otherwise be invisible to the pickup check and
' to the board's $ marker, and would sit there forever.
FUNCTION HasDrop% (rm AS INTEGER)
    HasDrop = 0
    IF rm < 1 OR rm > UBOUND(ROOMS) THEN EXIT FUNCTION
    IF ROOMS(rm).drop_gold > 0 THEN HasDrop = -1: EXIT FUNCTION
    IF ROOMS(rm).drop_sword > 0 OR ROOMS(rm).drop_armor > 0 OR ROOMS(rm).drop_shield > 0 THEN HasDrop = -1: EXIT FUNCTION
    IF ROOMS(rm).drop_secret OR ROOMS(rm).drop_esp OR ROOMS(rm).drop_crystal THEN HasDrop = -1: EXIT FUNCTION
    IF ROOMS(rm).drop_bow OR ROOMS(rm).drop_boots THEN HasDrop = -1: EXIT FUNCTION
    IF ROOMS(rm).drop_teleport > 0 OR ROOMS(rm).drop_pot_sm > 0 OR ROOMS(rm).drop_pot_lg > 0 THEN HasDrop = -1
END FUNCTION


' Pick up whatever a fallen rival left in this room.
SUB CollectDrop (rm AS INTEGER)
    DIM got AS STRING
    IF NOT HasDrop(rm) THEN EXIT SUB
    got = ""
    IF ROOMS(rm).drop_gold > 0 THEN gold = gold + ROOMS(rm).drop_gold: got = _TRIM$(STR$(ROOMS(rm).drop_gold)) + " gold"
    GrantDropKit got, ROOMS(rm).drop_sword, ROOMS(rm).drop_secret, ROOMS(rm).drop_esp, ROOMS(rm).drop_crystal, ROOMS(rm).drop_armor, ROOMS(rm).drop_shield, ROOMS(rm).drop_bow, ROOMS(rm).drop_boots, ROOMS(rm).drop_teleport, ROOMS(rm).drop_pot_sm, ROOMS(rm).drop_pot_lg
    ClearRoomDrop rm
    IF ROOMS(rm).player_died THEN RecordLootRescue _TRIM$(ROOMS(rm).monster)   ' chronicle: hoard reclaimed after a death
    Sfx "treasure"
    IF NOT ROOMS(rm).player_died THEN
        Banner "You claim the treasure left waiting here.", _TRIM$(got) + "   [ press any key ]"   ' a curio left unopened, etc.
    ELSEIF num_players > 1 THEN
        Banner "You recover a fallen rival's spoils!", _TRIM$(got) + "   [ press any key ]"
    ELSE
        Banner "You reclaim the spoils you dropped here -- revenge is sweet!", _TRIM$(got) + "   [ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' ============================================================================
'  LINGERING -> WANDERING MONSTERS
'  Hanging about (searching the same spot, standing idle) has a cost: the `loiter`
'  meter rises, first with atmospheric omens, then a wandering monster of the
'  current level ambushes you. Moving to a new cell resets the meter.
' ============================================================================

' A random atmospheric omen. stage 1 = something stirs (distant); stage 2+ = it's
' close. Drawn as a brief flash so it sets mood without demanding a keypress.
FUNCTION LoiterOmen$ (stage AS INTEGER)
    IF stage <= 1 THEN
        SELECT CASE RollDie(8)
            CASE 1: LoiterOmen$ = "You hear faint scuffling somewhere in the dark."
            CASE 2: LoiterOmen$ = "A cold draft carries a distant, wet growl."
            CASE 3: LoiterOmen$ = "Loose grit trickles down from the ceiling."
            CASE 4: LoiterOmen$ = "Goosebumps prickle the back of your neck."
            CASE 5: LoiterOmen$ = "Your torchlight wavers, though there is no wind."
            CASE 6: LoiterOmen$ = "Something skitters past in the dark, then falls silent."
            CASE 7: LoiterOmen$ = "The shadows seem to lean in and watch you."
            CASE ELSE: LoiterOmen$ = "Far off, a door groans open on rusted hinges."
        END SELECT
    ELSE
        SELECT CASE RollDie(8)
            CASE 1: LoiterOmen$ = "Claws click on stone -- closer now."
            CASE 2: LoiterOmen$ = "A hiss echoes from just beyond the doorway."
            CASE 3: LoiterOmen$ = "The stench of something rank rolls over you."
            CASE 4: LoiterOmen$ = "Heavy, wet breathing rasps in the dark nearby."
            CASE 5: LoiterOmen$ = "Red eyes glint at the edge of your torchlight."
            CASE 6: LoiterOmen$ = "Gravel crunches under a weight that is not yours."
            CASE 7: LoiterOmen$ = "A low growl trembles in the floor beneath your boots."
            CASE ELSE: LoiterOmen$ = "Something is very near now -- move, before it finds you."
        END SELECT
    END IF
END FUNCTION


' TRUE when the player stands in a CLEARED room that holds a secret door -- a safe
' haven where no wandering monster will disturb them (secret-door room = sanctuary,
' once its own monster is slain).
FUNCTION InSanctuary%
    DIM rm AS INTEGER, i AS INTEGER, cx AS INTEGER, cy AS INTEGER
    InSanctuary = 0
    IF NOT InRoomNow THEN EXIT FUNCTION
    rm = ROOMAT(c.x \ CW, c.y \ CH)
    IF rm < 1 THEN EXIT FUNCTION
    IF ROOMS(rm).malive AND LEN(_TRIM$(ROOMS(rm).monster)) > 0 THEN EXIT FUNCTION   ' its monster still lurks
    cx = c.x \ CW: cy = c.y \ CH
    FOR i = 1 TO SD_N
        IF ABS(SD_X(i) - cx) <= 3 AND ABS(SD_Y(i) - cy) <= 3 THEN InSanctuary = -1: EXIT FUNCTION
    NEXT i
END FUNCTION


' Flash an omen briefly (no keypress), then restore the board.
SUB FlashOmen (stage AS INTEGER)
    Sfx "idle"
    Banner LoiterOmen$(stage), "-- best not to linger --"
    _DELAY 1.7
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' One "time passes" tick from lingering (a search, or a long hardcore idle). The early
' ticks flash an omen; once the meter is full there is an IDLE_ENCOUNTER_PCT chance the
' dungeon sends something after you (else a close omen and the meter stays hot). A level
' you have fully cleared is yours -- no lingering danger there at all.
SUB LoiterTick
    DIM sec AS INTEGER
    sec = PlayerLevel%
    IF sec >= 1 AND sec <= 9 THEN
        IF lvl_cleared(sec) THEN EXIT SUB          ' cleared this floor -- rest easy
    END IF
    IF InSanctuary THEN EXIT SUB                   ' a cleared secret-door room is a safe haven
    DIM encpct AS INTEGER
    loiter = loiter + 1
    IF loiter < LOITER_THRESHOLD THEN
        FlashOmen loiter                           ' building dread
    ELSE
        encpct = IDLE_ENCOUNTER_PCT
        IF siren_turns > 0 THEN encpct = encpct + SIREN_ENCOUNTER_BOOST   ' a siren makes it far worse
        IF RollDie(100) <= encpct THEN
            loiter = 0
            WanderEncounter                        ' the dungeon sends something after you
        ELSE
            FlashOmen 2                            ' a near miss -- danger persists, roll again next tick
        END IF
    END IF
END SUB


' Ambush by a wandering monster of the CURRENT dungeon level. Set up in a scratch
' ROOMS() slot (never mapped in ROOMAT, so it can't be walked into), then fought
' with the normal combat code. Wanderers travel light: modest gold, no cards, no key.
SUB WanderEncounter
    DIM AS INTEGER sec, w, m, t, res, cx, cy
    cx = c.x \ CW: cy = c.y \ CH
    IF ABS(cx - START_CX) <= 3 AND ABS(cy - START_CY) <= 3 THEN EXIT SUB   ' the entrance is safe
    sec = PlayerLevel%
    IF sec >= 1 AND sec <= 9 THEN
        IF lvl_cleared(sec) THEN EXIT SUB   ' a cleared level holds no more wanderers
    END IF
    w = ROOM_N + 1: IF w > 400 THEN w = 400
    ROOMS(w).sec = sec
    m = RollDie(3)
    ROOMS(w).monster = MON_NAME(sec, m): ROOMS(w).mslot = m
    ROOMS(w).malive = TRUE: ROOMS(w).is_boss = FALSE
    ' Give the ambush a REAL cell and mark it seen, so DrawEntities paints its § where it
    ' jumped you. Without this a wanderer you fled simply vanished from the board -- still
    ' alive in its slot, still waiting, but with nothing on the map to say so.
    ROOMS(w).cx = cx: ROOMS(w).cy = cy: ROOMS(w).seen = TRUE
    ROOMS(w).monster_fought = FALSE: ROOMS(w).player_died = FALSE: ROOMS(w).looted = FALSE
    MonsterStats sec, MK_WANDER, ROOMS(w).mhp, ROOMS(w).mac   ' same funnel as a lair monster
    ROOMS(w).mhp_now = ROOMS(w).mhp
    t = RollDie(3)
    ' wanderers carry only scraps -- you can't farm them for a quick win (WANDER_GOLD_DIV keeps it lean)
    ROOMS(w).treasure_name = TRE_NAME(sec, t): ROOMS(w).treasure = TRE_GOLD(sec, t) \ WANDER_GOLD_DIV
    ROOMS(w).treasure_item = 0
    ClearRoomDrop w                                      ' scratch slot: no inherited stash
    c.prev_x = c.x: c.prev_y = c.y                ' fleeing a wanderer just leaves you put
    Sfx "trap"
    DIM wm AS STRING: wm = _TRIM$(ROOMS(w).monster)
    RecordWander wm, sec                          ' chronicle: wandering ambush
    IF door_ambush THEN
        Banner MonVerb$(wm, "The " + wm + " was WAITING", "The " + wm + " were WAITING") + " behind the door!", "You are still off balance -- " + MonVerb$(wm, "it strikes", "they strike") + " first.   [ press any key ]"
    ELSE
        Banner MonVerb$(wm, "A WANDERING " + wm + " bursts", "WANDERING " + wm + " burst") + " from the shadows!", "Your lingering has drawn " + MonVerb$(wm, "it", "them") + " to you.   [ press any key ]"
    END IF
    WaitKey
    ' AMBUSH: "extra monster attack to start combat". Landed here rather than inside DoCombat's
    ' round loop, because a free strike is a thing that happens BEFORE the fight, not a special
    ' case threaded through every round -- and the loop is the last place that wants another flag.
    IF door_ambush THEN AmbushFirstBlow w, wm, sec
    res = DoCombat(w)
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB

' A CHAMBER (the big named halls) holds THREE monsters and NO treasure. Each time the
' player steps into an uncleared chamber, ONE fresh monster of that level rises to fight;
' leave and re-enter for the next, until three graves stand (CHM_DEAD = 3). The Main
' Gallery / entrance is always safe. Uses a scratch ROOMS() slot (never mapped in ROOMAT,
' so it can't be walked into), fought with the normal combat code; treasure suppressed via
' the is_chamber flag in ClaimTreasure.
SUB ChamberEncounter (cid AS INTEGER)
    DIM AS INTEGER sec, w, m, res, isLord
    DIM mon AS STRING, kind AS STRING
    IF cid < 1 OR cid > NCHAMBER THEN EXIT SUB
    IF CHAMBERAT(START_CX, START_CY) = cid THEN EXIT SUB   ' the Main Gallery / entrance never spawns
    IF CHM_DEAD(cid) >= 3 THEN EXIT SUB                    ' three graves already -- the chamber is cleared
    sec = CHM_SEC(cid): IF sec < 1 THEN sec = 1

    ' ARRIVAL FIRST, always. The hall's description + narration used to be an ELSE branch of
    ' the encounter below, so it only played when that entry happened to roll a plain gauntlet
    ' fight -- a first entry that rolled a shrine / hazard / boon / lord EXITed before ever
    ' reaching it, and you met the Torture Chamber with no idea you had arrived. It also rode
    ' on CHM_DEAD = 0, so a hall you fled and came back to introduced itself twice. Own flag,
    ' own moment, before anything else can return.
    ChamberArrival cid

    ' What happens on THIS entry? A non-combat event fires instead of a fight, at most once
    ' per chamber per run -- the chamber still needs its three kills to clear, so a special
    ' event adds variety without touching the board-game rule or letting you farm boons.
    kind = ChamberEventKind$(cid, sec)
    SELECT CASE kind
        CASE "shrine"
            CHM_EVDONE(cid) = TRUE
            ChamberEventBanner cid, kind
            DoCurio 0                                      ' the curio deck IS the shrine's risk/reward
            cursor_erase: cursor_draw: DrawHUD: Present
            EXIT SUB
        CASE "hazard"
            CHM_EVDONE(cid) = TRUE
            ChamberEventBanner cid, kind
            SpringTrap 0                                   ' traps.txt supplies the mechanic + prose
            cursor_erase: cursor_draw: DrawHUD: Present
            EXIT SUB
        CASE "boon"
            CHM_EVDONE(cid) = TRUE
            ChamberEventBanner cid, kind
            ChamberBoon sec
            cursor_erase: cursor_draw: DrawHUD: Present
            EXIT SUB
        CASE "lord"
            CHM_EVDONE(cid) = TRUE
            isLord = TRUE                                  ' a boss-flagged guardian; DOES count as a grave
    END SELECT
    w = ROOM_N + 2: IF w > 400 THEN w = 400                ' scratch slot (WanderEncounter uses ROOM_N+1)
    m = RollDie(3): mon = _TRIM$(MON_NAME(sec, m))
    ROOMS(w).sec = sec: ROOMS(w).monster = mon: ROOMS(w).mslot = m
    ROOMS(w).malive = TRUE: ROOMS(w).is_boss = isLord      ' a LORD event flags the guardian as a boss
    ROOMS(w).cx = c.x \ CW: ROOMS(w).cy = c.y \ CH: ROOMS(w).seen = TRUE   ' a real cell, so DrawEntities can paint it
    ROOMS(w).monster_fought = FALSE: ROOMS(w).player_died = FALSE: ROOMS(w).looted = FALSE
    ' A LORD is a mini-boss, not a second boss: MonsterStats applies LORD_HP_PCT / LORD_AC_BONUS
    ' and the AC cap, so the three separate multipliers that used to stack here (+50% HP, +1 AC,
    ' and is_boss quietly adding +2 to-hit in DoCombatDnD) can no longer compound unwatched.
    IF isLord THEN
        MonsterStats sec, MK_LORD, ROOMS(w).mhp, ROOMS(w).mac
    ELSE
        MonsterStats sec, MK_ROOM, ROOMS(w).mhp, ROOMS(w).mac
    END IF
    ROOMS(w).mhp_now = ROOMS(w).mhp
    ROOMS(w).treasure = 0: ROOMS(w).treasure_item = 0: ROOMS(w).treasure_name = ""
    ClearRoomDrop w                                      ' scratch slot: no inherited stash
    ROOMS(w).is_chamber = TRUE                             ' tells ClaimTreasure to grant no treasure
    Sfx "trap"
    DIM cname AS STRING, cdesc AS STRING
    cname = _TRIM$(CHM_NAME(cid))
    IF isLord THEN
        Sfx "alarm"
        Banner "THE LORD OF THE " + UCASE$(cname) + " RISES!", MonVerb$(mon, "A great " + mon + " claims this hall", "Great " + mon + " claim this hall") + " -- stronger than its kin.   [ press any key ]"
        WaitKey
    ELSEIF CHM_DEAD(cid) = 0 THEN                          ' no graves yet -- the first guardian
        Banner MonVerb$(mon, "A " + mon + " stalks the " + cname, mon + " stalk the " + cname) + "!", "Three guard this hall, and it holds no treasure.   [ press any key ]"
        WaitKey
    ELSE
        Banner MonVerb$(mon, "Another " + mon + " stalks", "More " + mon + " stalk") + " the " + cname + "!", "Chamber monster " + _TRIM$(STR$(CHM_DEAD(cid) + 1)) + " of 3.   [ press any key ]"
        WaitKey
    END IF
    res = DoCombat(w)
    IF NOT ROOMS(w).malive THEN CHM_DEAD(cid) = CHM_DEAD(cid) + 1   ' slain -> one more grave (up to 3)
    ROOMS(w).is_chamber = FALSE
    IF CHM_DEAD(cid) >= 3 THEN
        RecordChamberCleared
        Sfx "levelup"
        Banner "The " + _TRIM$(CHM_NAME(cid)) + " is cleared!", "Three graves mark your victory here.   [ press any key ]"
        WaitKey
    END IF
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' --- [F] SEARCH for secret doors (moved from engine/BOARD.bas) ----------------
' The ENGINE owns the doors (SD_*) and revealing what one opens (RevealRegionFromDoor);
' the RULE is all DUNGEON!: roll low on a d6, the Elf's secret_bonus widens the band,
' the Secret Door Card never fails, and lingering to search draws danger closer.
SUB DoSearch
    DIM i AS INTEGER, ccx AS INTEGER, ccy AS INTEGER, roll AS INTEGER, thresh AS INTEGER
    DIM found_any AS INTEGER, near_hidden AS INTEGER
    ccx = c.x \ CW: ccy = c.y \ CH
    ' DUNGEON! convention: roll LOW to find a secret door -- Hero on 1-2, Elf on 1-4
    ' (double odds), Wizard on 1-3. secret_bonus widens the winning band by that much.
    roll = DoRoll(1, 0, "SEARCHING for secret doors")   ' a raw d6, shown honestly
    thresh = 2 + CLASSES(player_class).secret_bonus
    ' WIS -- "bonus to finding hidden things". A perceptive character widens the band the same
    ' way the Elf's class bonus does; capped at 5 so it can never become the Secret Door Card,
    ' which is the item whose whole selling point is that it NEVER fails.
    IF NOT opt_oldschool THEN
        thresh = thresh + AbilMod(player_wis)
        IF thresh < 1 THEN thresh = 1            ' a dolt still has a chance
        IF thresh > 5 THEN thresh = 5
    END IF
    IF item_secret_card THEN thresh = 6          ' the Secret Door Card never fails (any roll finds)
    found_any = FALSE: near_hidden = FALSE
    g_secret_tries = g_secret_tries + 1              ' chronicle: count searches toward the next find
    FOR i = 1 TO SD_N
        IF NOT SD_FOUND(i) THEN
            IF ABS(SD_X(i) - ccx) <= 2 AND ABS(SD_Y(i) - ccy) <= 2 THEN
                near_hidden = TRUE
                IF roll <= thresh THEN
                    SD_FOUND(i) = TRUE
                    RevealRegionFromDoor i    ' reveal door + the area it connects to
                    found_any = TRUE
                END IF
            END IF
        END IF
    NEXT

    IF found_any THEN
        RecordSecret PlayerLevel%, ROOMAT(ccx, ccy), g_secret_tries
        g_secret_tries = 0
        Sfx "secret"
        Banner "A SECRET DOOR grinds open before you!", "A hidden passage is revealed -- explore what it hides.   [ press any key ]"
    ELSEIF near_hidden THEN
        Sfx "search"
        Banner "Your fingers trace a faint seam in the stone...", "Something is hidden nearby -- keep searching!   [ press any key ]"
    ELSE
        Sfx "search"
        Banner "You search the walls but find no secrets here.", "[ press any key ]"
    END IF
    WaitKey
    cursor_erase: cursor_draw: Present
    LoiterTick                                     ' lingering to search draws danger closer
END SUB

' --- bumping a REINFORCED door (moved from engine/BOARD.bas) -------------------
' Engine owns DOOR_BROKEN and which door is ahead (StrongDoorAhead); the STR check
' against DC 13 is a game rule reading the character's ability scores.
FUNCTION BreakDoorAttempt% (idx AS INTEGER)
    DIM roll AS INTEGER, m AS INTEGER, tag AS STRING, pct AS INTEGER, lvl AS INTEGER, breached AS INTEGER
    Sfx "strongdoor"
    ' Throwing yourself at a reinforced door is the loudest thing you can do down here, and the
    ' racket compounds: each attempt on the SAME door adds DOORNOISE_PCT. Switch doors and the
    ' count restarts -- it is this door's noise, not a running penalty on you.
    IF idx <> door_noise_idx THEN door_noise_idx = idx: door_noise_tries = 0
    door_noise_tries = door_noise_tries + 1
    m = AbilMod(player_str)
    roll = RollDie(20) + m
    tag = "  (STR d20" + ModStr$(m) + " = " + _TRIM$(STR$(roll)) + " vs 13)"
    IF roll >= 13 THEN
        DOOR_BROKEN(idx) = 1
        Sfx "breakdoor"
        Banner "You SMASH through the reinforced door!" + tag, "It bursts off its hinges.   [ press any key ]"
        BreakDoorAttempt = TRUE
        breached = TRUE                          ' check for a trap AFTER the noise roll below
    ELSE
        Banner "A REINFORCED DOOR resists your shoulder!" + tag, "It holds firm -- hurl yourself at it again.   [ press any key ]"
        BreakDoorAttempt = FALSE
    END IF
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
    ' Did anything hear it? On a floor you have already swept there is almost nothing left to
    ' come, so the odds collapse to a flat DOORNOISE_CLEAR_PCT instead of climbing.
    lvl = PlayerLevel%
    IF lvl >= 1 THEN
        IF LevelFullyCleared%(lvl) THEN pct = DOORNOISE_CLEAR_PCT ELSE pct = DOORNOISE_PCT * door_noise_tries
    ELSE
        pct = DOORNOISE_PCT * door_noise_tries
    END IF
    IF pct > 100 THEN pct = 100
    IF breached THEN DoorTrapCheck idx           ' a door that took two shoves may have been rigged
    IF pct > 0 AND RollDie(100) <= pct THEN
        door_noise_tries = 0                       ' the noise was answered -- the tally is spent
        LogEvent "The racket at the door drew something."
        Banner "Something HEARD you.", "The noise carries down the corridor -- and it is answered.   [ press any key ]"
        WaitKey
        WanderEncounter
    END IF
END FUNCTION

' The ONE-TIME arrival at a named hall: its establishing shot, its description typed out, and
' its narration if the pack has one -- the same treatment RoomFlavor gives a named ROOM, which
' chambers never got. Fires before any encounter or event, exactly once per hall per run.
'
' The art and the narration key both come from the hall's NAME, so a chamber whose name matches
' a named room (they all do -- ARMORY, THE CRYPT, ...) reuses that room's establishing shot;
' ChamberDesc$ reads assets/flavor/<pack>/chambers.txt and falls back to a generic line, so a
' hall is never silent.
SUB ChamberArrival (cid AS INTEGER)
    DIM cname AS STRING, cdesc AS STRING
    IF cid < 1 OR cid > MAXCHAMBER THEN EXIT SUB
    IF CHM_SEEN(cid) THEN EXIT SUB
    CHM_SEEN(cid) = TRUE
    cname = _TRIM$(CHM_NAME(cid))
    cdesc = ChamberDesc$(cname)
    IF LEN(cdesc) = 0 THEN cdesc = "You step into the " + cname + " -- three guard this hall, and it holds no treasure."
    Sfx "key"                                          ' the same chime a named room's crawl opens on
    ScrollTextArtKey cname, cdesc, SpecialSprite$(cname), "chamber." + NarrSlug$(cname)
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' --- CHAMBER EVENTS (assets/data/<pack>/chamber-events.txt) --------------------
' Which event fires on this entry? A weighted, depth-gated draw over the loaded table
' using the engine primitive (engine/TABLE.bas). Returns "gauntlet" -- the classic
' one-monster-per-entry behaviour -- whenever a special event should NOT happen:
'   * the table is missing/empty (a pack that ships no events plays as before)
'   * this chamber already had its one special event (CHM_EVDONE -- no boon farming)
'   * nothing in the table is eligible at this depth
FUNCTION ChamberEventKind$ (cid AS INTEGER, lvl AS INTEGER)
    DIM i AS INTEGER, pick AS INTEGER
    ChamberEventKind$ = "gauntlet"
    IF NCHMEV <= 0 THEN EXIT FUNCTION
    IF cid >= 1 AND cid <= MAXCHAMBER THEN
        IF CHM_EVDONE(cid) THEN EXIT FUNCTION
    END IF
    REDIM w(1 TO NCHMEV) AS INTEGER, lo(1 TO NCHMEV) AS INTEGER, hi(1 TO NCHMEV) AS INTEGER
    FOR i = 1 TO NCHMEV
        w(i) = CHM_EV(i).weight: lo(i) = CHM_EV(i).minlvl: hi(i) = CHM_EV(i).maxlvl
    NEXT i
    pick = WeightPickLvl%(w(), lo(), hi(), NCHMEV, lvl)
    IF pick >= 1 THEN ChamberEventKind$ = _TRIM$(CHM_EV(pick).kind)
END FUNCTION

' Announce a chamber event using the table's own name + prose (data, not hardcoded).
SUB ChamberEventBanner (cid AS INTEGER, kind AS STRING)
    DIM i AS INTEGER, nm AS STRING, tx AS STRING
    FOR i = 1 TO NCHMEV
        IF _TRIM$(CHM_EV(i).kind) = kind THEN nm = _TRIM$(CHM_EV(i).nm): tx = _TRIM$(CHM_EV(i).text): EXIT FOR
    NEXT i
    IF LEN(nm) = 0 THEN nm = "Something stirs"
    Sfx "secret"
    Banner _TRIM$(CHM_NAME(cid)) + " -- " + nm, tx + "   [ press any key ]"
    WaitKey
END SUB

' A cache: a healing potion, or gold scaled to the chamber's depth. Routed through
' CurioGain so it lands in the Treasury + Event Log like every other windfall.
SUB ChamberBoon (lvl AS INTEGER)
    DIM g AS LONG
    IF PctChance%(45) THEN
        IF PctChance%(TREASURE_LARGE_PCT) THEN
            item_potion_large = item_potion_large + 1
            CurioGain "Large Healing Potion", 0
            Banner "A sealed flask, still whole.", "You pocket a LARGE healing potion.   [ press any key ]"
        ELSE
            item_potion_small = item_potion_small + 1
            CurioGain "Small Healing Potion", 0
            Banner "A small vial, waxed shut.", "You pocket a SMALL healing potion.   [ press any key ]"
        END IF
    ELSE
        g = 40& * lvl + RollDie(30 * lvl)
        CurioGain "Chamber cache", g
        Banner "Coin, tucked away and forgotten.", "You gather " + _TRIM$(STR$(g)) + " gold.   [ press any key ]"
    END IF
    WaitKey
END SUB


' ============================================================================
'  DOOR TRAPS -- a door that fought back once may be rigged.
'
'  Per the plan: only when it takes MORE THAN ONE attempt to get through, and then
'  20% swamp gas (CON), 20% arrow (DEX), 10% ambush, 50% nothing.
'
'  The gate on door_noise_tries is the whole design: a door that opens first shove is
'  just a door. It is the one you had to hit twice that was braced, wired, or watched --
'  so the trap is the cost of a fight you already lost once.
'
'  Both saves go through SaveThrow%, the same routine curios and monster elemental
'  effects use, so "save vs poison" means exactly one thing everywhere in the game.
' ============================================================================
SUB DoorTrapCheck (idx AS INTEGER)
    DIM r AS INTEGER, dmg AS INTEGER
    IF opt_oldschool THEN EXIT SUB               ' no HP, no saves, no traps
    IF door_noise_tries <= 1 THEN EXIT SUB       ' opened first try -- it was only ever a door
    r = RollDie(100)
    IF r <= 20 THEN
        ' SWAMP GAS -- the cheap one: a fixed, survivable bite
        IF SaveThrow%(AbilMod(player_con), "SWAMP GAS from the broken door") THEN
            Banner "Foul gas billows from the shattered frame.", "You hold your breath and push through.   [ press any key ]"
        ELSE
            player_hp = player_hp - 2
            IF player_hp < 0 THEN player_hp = 0
            Sfx "poison-proc"
            Banner "** SWAMP GAS! **", "The stench sears your lungs -- you lose 2 HP.   [ press any key ]"
            LogEvent _TRIM$(player_name) + " breathed swamp gas forcing a door"
        END IF
        WaitKey
    ELSEIF r <= 40 THEN
        ' ARROW -- the dangerous one: a real damage die
        IF SaveThrow%(AbilMod(player_dex), "an ARROW TRAP in the door frame") THEN
            Banner "A bowstring snaps somewhere in the frame.", "The shaft buries itself in the wall beside your head.   [ press any key ]"
        ELSE
            dmg = RollDie(6)
            player_hp = player_hp - dmg
            IF player_hp < 0 THEN player_hp = 0
            Sfx "hit"
            IF opt_juice THEN ImpactFX ShakeMag(dmg), 0
            Banner "** ARROW TRAP! **", "A shaft takes you as the door gives -- " + _TRIM$(STR$(dmg)) + " damage.   [ press any key ]"
            LogEvent _TRIM$(player_name) + " was shot forcing a door (" + _TRIM$(STR$(dmg)) + ")"
        END IF
        WaitKey
    ELSEIF r <= 50 THEN
        ' AMBUSH -- no save. Something was waiting for exactly this, and it gets the first
        ' word: WanderEncounter with the surprised flag set, so fleeing is off the table.
        Sfx "alarm"
        Banner "** AMBUSH! **", "They were waiting for the door to give -- and you are still off balance.   [ press any key ]"
        WaitKey
        door_ambush = TRUE                       ' consumed by DoCombat: no flee, monster strikes first
        WanderEncounter
        door_ambush = FALSE
    END IF
    ' 50%: nothing. The door was just a door after all.
    IF player_hp <= 0 THEN DoTDeath "a door trap"
END SUB


' The free blow an ambusher gets for choosing the moment. Automatic -- no to-hit roll: you were
' not defending, and rolling to hit a target that cannot dodge is theatre.
SUB AmbushFirstBlow (w AS INTEGER, wm AS STRING, sec AS INTEGER)
    DIM mdmg AS INTEGER
    IF opt_oldschool THEN EXIT SUB               ' 2d6 combat has no HP to take a free blow off
    PushMonsterDice
    mdmg = GameRoll(1, 6, sec \ 3, "the " + wm + "'s AMBUSH blow -- roll ITS d6")
    PopMonsterDice
    IF mdmg < 1 THEN mdmg = 1
    player_hp = player_hp - mdmg
    IF player_hp < 0 THEN player_hp = 0
    Sfx "player-pain"
    IF opt_juice THEN ImpactFX ShakeMag(mdmg) * 1.1, 0
    Banner "** AMBUSHED! **", MonVerb$(wm, "It catches", "They catch") + " you flat-footed for " + _TRIM$(STR$(mdmg)) + " damage.   [ press any key ]"
    WaitKey
    LogEvent _TRIM$(player_name) + " was ambushed forcing a door (" + _TRIM$(STR$(mdmg)) + ")"
    IF player_hp <= 0 THEN DoTDeath "an ambush at a broken door"
END SUB


' ============================================================================
'  [R]EST -- one HP at a time, and the dungeon gets a vote.
'
'  Press R, heal 1 HP, roll for an encounter. That is the whole loop, and it is a real
'  decision because the cost is time and time is what draws monsters: a hero who rests
'  20 HP back has rolled 20 times for company.
'
'  Deliberately NOT shared with the entrance rest (Rick's call, recorded in DAY-NOTES):
'  that one is a scripted set piece at a fixed safe place; this is an ordinary action you
'  can take anywhere, and it should feel like pushing your luck rather than like a cutscene.
'
'  An encounter here is never a curio -- a wishing fountain is not what interrupts a nap --
'  and never a boss, because dragging a boss out of its lair by resting in a corridor turns
'  a set-piece fight into an accident.
' ============================================================================
SUB DoRest
    DIM lvl AS INTEGER, pct AS INTEGER
    IF opt_oldschool THEN EXIT SUB               ' Dungeon! has no HP to rest back
    IF NOT opt_rest THEN
        Banner "You have no time to rest.", "(Resting is switched off in SETTINGS.)   [ press any key ]"
        WaitKey: cursor_erase: cursor_draw: DrawHUD: Present
        EXIT SUB
    END IF
    IF player_hp >= player_maxhp THEN
        Banner "You are already whole.", "There is nothing to rest off.   [ press any key ]"
        WaitKey: cursor_erase: cursor_draw: DrawHUD: Present
        EXIT SUB
    END IF
    lvl = PlayerLevel%
    IF lvl < 1 THEN lvl = 1
    ' The odds RISE with depth: catching your breath on level 1 is a different proposition
    ' from doing it on the 9th, and a flat chance would say otherwise.
    pct = REST_ENC_PCT + REST_ENC_PER_LVL * (lvl - 1)
    IF pct > 60 THEN pct = 60
    IF RollDie(100) <= pct THEN
        Sfx "trap"                               ' no heal: something found you first
        Banner "You settle down to rest -- and something finds you.", "No respite here.   [ press any key ]"
        WaitKey
        ' No boss guard needed: WanderEncounter always sets is_boss = FALSE, so a wanderer is
        ' never a boss by construction. Dragging a boss out of its lair by napping in a
        ' corridor would turn a set-piece fight into an accident -- it simply cannot happen.
        WanderEncounter
    ELSE
        HealPlayer 1
        Sfx "levelup"
        g_rests = g_rests + 1
    END IF
    LoiterTick                                   ' resting IS lingering -- danger keeps building
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB
