' ============================================================================
'  STATUS.bas -- ENGINE per-actor status effects + stances. PURE MODEL, NO DRAWING.
'
'  Poison, bleed, frost, stun -- the engine tracks DURATION and pays out DAMAGE OVER TIME; what
'  a label MEANS is entirely the game's business. Same split as the generic stat rows in
'  FIGHT.bas, and the same reason this can be unit-tested with no display (tests/TEST-STATUS.bas).
'
'  THE BUG THIS FILE EXISTS TO PREVENT: at 60fps a 2-damage-per-second poison deals 0.0333 per
'  frame. `INT(0.0333)` is ZERO. The obvious implementation therefore ticks happily forever and
'  never removes a single hit point -- no crash, no warning, and in play it just looks like poison
'  is weak. Every effect carries a fractional accumulator (FS_ACC) and pays out whole points, so
'  the total delivered depends on the DURATION and never on the frame rate.
'
'  Durations are SECONDS, not turns. The tactical fight is real-time -- the fuses are seconds and
'  the player can sit in the menu indefinitely -- so a status measured in "turns" would have no
'  defined length.
'
'  STANCES are mechanical, not cosmetic: small integers with one lookup for their modifiers, so a
'  stance can never be set to a string that nothing checks for.
' ============================================================================

'--- lifecycle -------------------------------------------------------------

' Drop every effect on one actor. Called on death, and when an encounter ends.
SUB StatusClear (a AS INTEGER)
    DIM i AS INTEGER
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FOR i = 1 TO FSTAT_MAX
        FS_KIND(a, i) = "": FS_SECS(a, i) = 0: FS_DPS(a, i) = 0
        FS_ACC(a, i) = 0: FS_MOD(a, i) = 0
    NEXT i
    FA_STANCE(a) = STANCE_READY
END SUB

SUB StatusClearAll
    DIM a AS INTEGER
    FOR a = 0 TO FIGHT_MAXFOE
        StatusClear a
    NEXT a
END SUB

' Slot index of an existing effect of this kind on this actor, or 0.
' Matching is case-insensitive and trimmed, because the kind comes from data tables where a
' stray space or capital is easy and would otherwise silently create a duplicate effect.
FUNCTION StatusSlot% (a AS INTEGER, kind AS STRING)
    DIM i AS INTEGER, t AS STRING
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    t = UCASE$(_TRIM$(kind))
    FOR i = 1 TO FSTAT_MAX
        IF FS_SECS(a, i) > 0 AND UCASE$(_TRIM$(FS_KIND(a, i))) = t THEN StatusSlot% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' Apply (or refresh) an effect. Returns the slot used, or 0 if it could not be placed.
'
' REFRESH RATHER THAN STACK: a second dose of the same kind extends the duration to whichever is
' longer and keeps the STRONGER dps/modifier -- it does not add a second poison. Stacking is what
' turns two weak hits into an instant kill, and with four foes attacking in parallel it is very
' easy to hit an actor twice in the same second.
'
' When every slot is full, the effect with the LEAST time remaining is displaced, so a fresh
' threat is never silently ignored just because four trivial ones are running.
FUNCTION StatusApply% (a AS INTEGER, kind AS STRING, secs AS SINGLE, dps AS SINGLE, modifier AS INTEGER)
    DIM i AS INTEGER, slot AS INTEGER, worst AS INTEGER, worstsecs AS SINGLE
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    IF LEN(_TRIM$(kind)) = 0 OR secs <= 0 THEN EXIT FUNCTION
    ' A dead actor takes no new effects -- otherwise a corpse accumulates poison that would
    ' come back with it if it were ever revived.
    IF FA_USED(a) = 0 OR FA_ALIVE(a) = 0 THEN EXIT FUNCTION

    slot = StatusSlot%(a, kind)
    IF slot > 0 THEN
        IF secs > FS_SECS(a, slot) THEN FS_SECS(a, slot) = secs
        IF dps > FS_DPS(a, slot) THEN FS_DPS(a, slot) = dps
        IF ABS(modifier) > ABS(FS_MOD(a, slot)) THEN FS_MOD(a, slot) = modifier
        StatusApply% = slot
        EXIT FUNCTION
    END IF

    FOR i = 1 TO FSTAT_MAX
        IF FS_SECS(a, i) <= 0 THEN slot = i: EXIT FOR
    NEXT i
    IF slot = 0 THEN
        worst = 1: worstsecs = FS_SECS(a, 1)
        FOR i = 2 TO FSTAT_MAX
            IF FS_SECS(a, i) < worstsecs THEN worstsecs = FS_SECS(a, i): worst = i
        NEXT i
        slot = worst
    END IF
    FS_KIND(a, slot) = _TRIM$(kind)
    FS_SECS(a, slot) = secs
    FS_DPS(a, slot) = dps
    FS_MOD(a, slot) = modifier
    FS_ACC(a, slot) = 0
    StatusApply% = slot
END FUNCTION

' Remove one kind from an actor (a cure). TRUE if something was actually removed.
FUNCTION StatusRemove% (a AS INTEGER, kind AS STRING)
    DIM slot AS INTEGER
    slot = StatusSlot%(a, kind)
    IF slot = 0 THEN EXIT FUNCTION
    FS_KIND(a, slot) = "": FS_SECS(a, slot) = 0: FS_DPS(a, slot) = 0
    FS_ACC(a, slot) = 0: FS_MOD(a, slot) = 0
    StatusRemove% = -1
END FUNCTION

'--- ticking ---------------------------------------------------------------

' Advance one actor's effects by `dt` seconds and return the WHOLE damage owed this tick.
'
' The caller applies the damage (the engine does not know how an actor takes damage), so this is
' the one place the fractional carry matters -- see the header note. A dead or empty actor ticks
' to nothing, so a corpse is never poisoned.
FUNCTION StatusTick& (a AS INTEGER, dt AS SINGLE)
    DIM i AS INTEGER, whole AS LONG, total AS LONG
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    IF dt <= 0 THEN EXIT FUNCTION
    IF FA_USED(a) = 0 OR FA_ALIVE(a) = 0 THEN EXIT FUNCTION
    FOR i = 1 TO FSTAT_MAX
        IF FS_SECS(a, i) > 0 THEN
            ' Never bill more time than the effect has left, or a single long frame would
            ' deliver damage from after the effect had already expired.
            DIM used AS SINGLE
            used = dt
            IF used > FS_SECS(a, i) THEN used = FS_SECS(a, i)
            IF FS_DPS(a, i) > 0 THEN
                FS_ACC(a, i) = FS_ACC(a, i) + FS_DPS(a, i) * used
                whole = INT(FS_ACC(a, i))
                IF whole > 0 THEN
                    FS_ACC(a, i) = FS_ACC(a, i) - whole
                    total = total + whole
                END IF
            END IF
            FS_SECS(a, i) = FS_SECS(a, i) - dt
            IF FS_SECS(a, i) <= 0 THEN
                ' PAY THE REMAINDER. The total owed is dps x duration, but summing dps*dt in
                ' SINGLE precision lands a hair under that (2 dps over 3s at 200fps accumulates
                ' to 5.9999), so INT() has banked only 5 and ~0.9999 is still sitting in the
                ' carry. Discarding it makes an effect deliver LESS the finer time is sliced --
                ' the frame-rate dependency this whole mechanism exists to avoid. Rounding the
                ' leftover settles the debt exactly.
                whole = INT(FS_ACC(a, i) + 0.5)
                IF whole > 0 THEN total = total + whole
                FS_KIND(a, i) = "": FS_SECS(a, i) = 0: FS_DPS(a, i) = 0
                FS_ACC(a, i) = 0: FS_MOD(a, i) = 0
            END IF
        END IF
    NEXT i
    StatusTick& = total
END FUNCTION

'--- queries ---------------------------------------------------------------

FUNCTION StatusHas% (a AS INTEGER, kind AS STRING)
    IF StatusSlot%(a, kind) > 0 THEN StatusHas% = -1
END FUNCTION

' How many effects are running on this actor.
FUNCTION StatusCount% (a AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    FOR i = 1 TO FSTAT_MAX
        IF FS_SECS(a, i) > 0 THEN n = n + 1
    NEXT i
    StatusCount% = n
END FUNCTION

' Seconds left on one kind (0 if absent).
FUNCTION StatusSecs! (a AS INTEGER, kind AS STRING)
    DIM slot AS INTEGER
    slot = StatusSlot%(a, kind)
    IF slot > 0 THEN StatusSecs! = FS_SECS(a, slot)
END FUNCTION

' Net effectiveness modifier from every running effect, summed.
FUNCTION StatusMod% (a AS INTEGER)
    DIM i AS INTEGER, m AS INTEGER
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    FOR i = 1 TO FSTAT_MAX
        IF FS_SECS(a, i) > 0 THEN m = m + FS_MOD(a, i)
    NEXT i
    StatusMod% = m
END FUNCTION

' One line for the EFFECT: row -- the longest-running effect and its countdown, or "" for none.
' Shows ONE rather than a list because the row is a single line inside a 32-column panel; a
' truncated list would hide the effect that matters.
FUNCTION StatusText$ (a AS INTEGER)
    DIM i AS INTEGER, best AS INTEGER, bestsecs AS SINGLE, r AS STRING
    ' NOTE the local `r`: QB64 cannot READ a FUNCTION's own return value -- `StatusText$ =
    ' StatusText$ + x` parses the right-hand side as a recursive CALL with no arguments and
    ' fails to compile. Accumulate in a local and assign once.
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    FOR i = 1 TO FSTAT_MAX
        IF FS_SECS(a, i) > bestsecs THEN bestsecs = FS_SECS(a, i): best = i
    NEXT i
    IF best = 0 THEN EXIT FUNCTION
    r = UCASE$(_TRIM$(FS_KIND(a, best))) + " " + FmtSecs$(FS_SECS(a, best))
    IF StatusCount%(a) > 1 THEN r = r + " +" + LTRIM$(STR$(StatusCount%(a) - 1))
    StatusText$ = r
END FUNCTION

'--- stances ---------------------------------------------------------------

' A stance's name, for the STANCE: row.
FUNCTION StanceName$ (st AS INTEGER)
    SELECT CASE st
        CASE STANCE_ATTACK: StanceName$ = "ATTACKING"
        CASE STANCE_GUARD: StanceName$ = "GUARDING"
        CASE STANCE_STAGGER: StanceName$ = "STAGGERED"
        CASE ELSE: StanceName$ = "READY"
    END SELECT
END FUNCTION

' Percent scaling applied to damage this actor DEALS, by stance. Committed attack hits harder,
' guarding trades offence for safety, staggered barely connects.
FUNCTION StanceOutPct% (st AS INTEGER)
    SELECT CASE st
        CASE STANCE_ATTACK: StanceOutPct% = 125
        CASE STANCE_GUARD: StanceOutPct% = 65
        CASE STANCE_STAGGER: StanceOutPct% = 50
        CASE ELSE: StanceOutPct% = 100
    END SELECT
END FUNCTION

' Percent scaling applied to damage this actor TAKES. Attacking leaves you open, guarding covers
' you, staggered is the punish window -- which is what makes staggering a foe worth doing, beyond
' throwing away its wind-up.
FUNCTION StanceInPct% (st AS INTEGER)
    SELECT CASE st
        CASE STANCE_ATTACK: StanceInPct% = 125
        CASE STANCE_GUARD: StanceInPct% = 50
        CASE STANCE_STAGGER: StanceInPct% = 160
        CASE ELSE: StanceInPct% = 100
    END SELECT
END FUNCTION

' Scale damage by a percentage, never rounding a real hit down to nothing -- a blow that
' connected should always cost at least one point, or a guarded actor looks invulnerable.
FUNCTION ScaleDmg& (dmg AS LONG, pct AS INTEGER)
    DIM v AS LONG
    IF dmg <= 0 THEN EXIT FUNCTION
    v = (dmg * pct) \ 100
    IF v < 1 THEN v = 1
    ScaleDmg& = v
END FUNCTION

' Put an actor off balance for `secs`. Modelled as a STATUS so it expires on its own through the
' normal tick, rather than as a flag someone has to remember to clear.
SUB StaggerActor (a AS INTEGER, secs AS SINGLE)
    IF StatusApply%(a, "stagger", secs, 0, -1) = 0 THEN EXIT SUB
    FA_STANCE(a) = STANCE_STAGGER
END SUB

' Reconcile stance with the effects actually running. Call after ticking: a stagger that has
' expired must not leave the actor permanently STAGGERED, which is the flag-style bug this
' avoids -- and it is invisible except as a foe that never recovers.
SUB StanceSync (a AS INTEGER)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    IF StatusHas%(a, "stagger") THEN
        FA_STANCE(a) = STANCE_STAGGER
    ELSEIF FA_STANCE(a) = STANCE_STAGGER THEN
        FA_STANCE(a) = STANCE_READY
    END IF
END SUB
