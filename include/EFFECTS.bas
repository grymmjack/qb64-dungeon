' ============================================================================
'  EFFECTS.bas -- the crit / fumble effects engine (data-driven)
'
'  All the dramatic swings live in three data tables (CRITFX / PFUMBLE / MFUMBLE)
'  built by InitEffects. Each row is a saying template + a mechanical `kind`:
'    0 flavor-only   1 heal player   2 extra dmg to foe
'    3 self-damage   4 lose turn     5 drop gold
'  Combat calls DoCrit / DoFumble / DoMonsterFumble, which pick a random row,
'  narrate it (with a dramatic pause), and apply the effect. The whole engine is
'  gated at the call sites by opt_critfumble, so "plain" combat skips it.
' ============================================================================

SUB InitEffects
    ' The crit/fumble lines now live in assets/data/effects.txt -- edit + F5.
    NCRIT = 0: NPFUM = 0: NMFUM = 0
    LoadEffects
END SUB


' Append a row to one of the three effect tables (1 crit, 2 player fumble, 3 monster fumble).
SUB AddFX (which AS INTEGER, sy AS STRING, kd AS INTEGER, dd AS INTEGER)
    SELECT CASE which
        CASE 1
            IF NCRIT >= UBOUND(CRITFX) THEN EXIT SUB
            NCRIT = NCRIT + 1: CRITFX(NCRIT).say = sy: CRITFX(NCRIT).kind = kd: CRITFX(NCRIT).die = dd
        CASE 2
            IF NPFUM >= UBOUND(PFUMBLE) THEN EXIT SUB
            NPFUM = NPFUM + 1: PFUMBLE(NPFUM).say = sy: PFUMBLE(NPFUM).kind = kd: PFUMBLE(NPFUM).die = dd
        CASE 3
            IF NMFUM >= UBOUND(MFUMBLE) THEN EXIT SUB
            NMFUM = NMFUM + 1: MFUMBLE(NMFUM).say = sy: MFUMBLE(NMFUM).kind = kd: MFUMBLE(NMFUM).die = dd
    END SELECT
END SUB


' Replace every occurrence of `finds` in `s` with `repl`.
FUNCTION StrSubst$ (s AS STRING, finds AS STRING, repl AS STRING)
    DIM buf AS STRING, p AS INTEGER
    buf = s
    p = INSTR(buf, finds)
    DO WHILE p > 0
        buf = LEFT$(buf, p - 1) + repl + MID$(buf, p + LEN(finds))
        p = INSTR(p + LEN(repl), buf, finds)
    LOOP
    StrSubst$ = buf
END FUNCTION


' Fill a saying template's {weapon}/{mon}/{n} tokens.
FUNCTION ResolveFX$ (tmpl AS STRING, weap AS STRING, mon AS STRING, n AS INTEGER)
    DIM s AS STRING
    s = _TRIM$(tmpl)
    s = StrSubst$(s, "{weapon}", weap)
    s = StrSubst$(s, "{mon}", mon)
    s = StrSubst$(s, "{n}", _TRIM$(STR$(n)))
    ResolveFX$ = s
END FUNCTION


' The player's weapon, named for the flavor text.
FUNCTION WeaponName$
    IF item_sword > 0 THEN WeaponName$ = "your +" + _TRIM$(STR$(item_sword)) + " blade": EXIT FUNCTION
    SELECT CASE player_class
        CASE 4: WeaponName$ = "your staff"
        CASE 2: WeaponName$ = "your elven blade"
        CASE ELSE: WeaponName$ = "your sword"
    END SELECT
END FUNCTION


' "... . . . ." -- a few beats of suspense before the payoff line.
SUB DramaticPause
    DIM i AS INTEGER, dots AS STRING
    dots = ""
    FOR i = 1 TO 4
        dots = dots + " ."
        Banner dots, ""
        Sfx "idle"
        _DELAY 0.8
    NEXT i
END SUB


' CRITICAL HIT cinematic: a random smash-saying, a dramatic pause, then the bonus
' event (a heroic heal, or a savage extra blow). Base double-damage is applied by
' the caller; this adds the flourish on top. Only called when opt_critfumble is on.
SUB DoCrit (rm AS INTEGER, mon AS STRING, weap AS STRING, dmg AS INTEGER)
    DIM i AS INTEGER, amt AS INTEGER
    i = RollDie(NCRIT)
    Sfx "crit"
    Banner ResolveFX$(CRITFX(i).say, weap, mon, dmg), "-- a CRITICAL blow! --"
    _DELAY 2.2
    DramaticPause
    SELECT CASE CRITFX(i).kind
        CASE 1                                     ' heroic heal
            amt = RollDie(CRITFX(i).die): IF amt < 1 THEN amt = 1
            player_hp = player_hp + amt
            IF player_hp > player_maxhp THEN player_hp = player_maxhp
            Banner "You feel overwhelming courage and pride!", "You heal " + _TRIM$(STR$(amt)) + " HP  (now " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + ").   [ press any key ]"
        CASE 2                                     ' savage extra damage
            amt = RollDie(CRITFX(i).die): IF amt < 1 THEN amt = 1
            ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - amt
            IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
            Banner "You press the advantage!", "A savage follow-through rends the " + mon + " for " + _TRIM$(STR$(amt)) + " more!   [ press any key ]"
        CASE ELSE                                  ' pure flourish
            Banner "A flawless strike!", "The " + mon + " reels from the blow.   [ press any key ]"
    END SELECT
    CombatPause
END SUB


' Player FUMBLE: a random pratfall + its penalty (self-damage never fatal, a
' dropped turn, or spilled gold). Only called when opt_critfumble is on.
SUB DoFumble (rm AS INTEGER, mon AS STRING, weap AS STRING)
    DIM i AS INTEGER, amt AS INTEGER, lost AS LONG
    i = RollDie(NPFUM)
    Sfx "fumble"
    Banner ResolveFX$(PFUMBLE(i).say, weap, mon, 0), "-- a FUMBLE! --"
    _DELAY 2.2
    SELECT CASE PFUMBLE(i).kind
        CASE 3                                     ' self-damage (never fatal)
            amt = RollDie(PFUMBLE(i).die): IF amt < 1 THEN amt = 1
            IF amt >= player_hp THEN amt = player_hp - 1
            IF amt < 0 THEN amt = 0
            player_hp = player_hp - amt
            Banner "Clumsy!", "You hurt yourself for " + _TRIM$(STR$(amt)) + " damage.   [ press any key ]"
        CASE 5                                     ' spill gold
            lost = RollDie(PFUMBLE(i).die) * 100
            IF lost > gold THEN lost = gold
            gold = gold - lost
            Banner "Butterfingers!", "You spill " + _TRIM$(STR$(lost)) + " gold in the scuffle.   [ press any key ]"
        CASE ELSE                                  ' lose the turn / flavor
            Banner "You are off-balance.", "Your strike is wasted -- best recover fast.   [ press any key ]"
    END SELECT
    CombatPause
END SUB


' Monster natural-1 fumble: it wounds itself or wastes its turn. Only called when
' opt_critfumble is on. The caller checks for the monster dying of self-harm.
SUB DoMonsterFumble (rm AS INTEGER, mon AS STRING)
    DIM i AS INTEGER, amt AS INTEGER
    i = RollDie(NMFUM)
    Sfx "fumble"
    Banner "** the " + mon + " FUMBLES! **  (natural 1)", ResolveFX$(MFUMBLE(i).say, "", mon, 0)
    _DELAY 2.0
    SELECT CASE MFUMBLE(i).kind
        CASE 3                                     ' self-damage
            amt = RollDie(MFUMBLE(i).die): IF amt < 1 THEN amt = 1
            ROOMS(rm).mhp_now = ROOMS(rm).mhp_now - amt
            IF ROOMS(rm).mhp_now < 0 THEN ROOMS(rm).mhp_now = 0
            Banner "The " + mon + " wounds ITSELF!", "It takes " + _TRIM$(STR$(amt)) + " damage.   [ press any key ]"
        CASE ELSE                                  ' lose the turn
            Banner "The " + mon + " reels and loses its footing!", "Its attack is wasted.   [ press any key ]"
    END SELECT
    CombatPause
END SUB
