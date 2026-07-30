' ============================================================================
'  FUSE.bas -- ENGINE parallel attack fuses + target selection. PURE MODEL, NO DRAWING.
'
'  This is the tactical layer. Every foe runs its own countdown SIMULTANEOUSLY, and the player
'  triages under time pressure: drop the one about to fire, or race it to kill the dangerous one
'  first. The fuses advance WHILE THE PLAYER DELIBERATES -- stand in the menu reading options and
'  something takes the opening. That is deliberate, and it is the only real source of pressure in
'  a 1-vs-4; a turn-based version of the same fight has no tension at all.
'
'  Split out of FIGHT.bas on purpose: FIGHT.bas needs CANVAS and ANSI_Print, so anything living
'  there cannot be unit-tested headlessly. Everything here is arithmetic over shared arrays, so
'  tests/TEST-FUSE.bas can assert the mechanics with no display -- the same reason GAUGE.bas was
'  separated from its renderer.
'
'  Slot 0 is the player, 1..FIGHT_MAXFOE the foes (same indexing as FIGHT.bas). The player's fuse
'  is their COMMIT DEADLINE while a gesture is up, so "ran out of time" is one mechanism for both
'  sides rather than two that can disagree.
'
'  FUSE_NONE (-1) means "no slot", NOT 0 -- 0 is the player, a real slot. Returning 0 for "none"
'  would silently mean "the player fired".
' ============================================================================

' --- tuning accessors. Each returns the DATA value when set, else the built-in default, so the
' engine works with or without a game that loads tuning.txt (examples/minimal does not).
FUNCTION FuseMinSecs!
    IF TUNE_FUSE_MIN_MS > 0 THEN FuseMinSecs! = TUNE_FUSE_MIN_MS / 1000! ELSE FuseMinSecs! = FUSE_MIN
END FUNCTION

FUNCTION GestureSecs!
    IF TUNE_GESTURE_MS > 0 THEN GestureSecs! = TUNE_GESTURE_MS / 1000! ELSE GestureSecs! = GESTURE_FUSE
END FUNCTION

FUNCTION DodgeSecs!
    IF TUNE_DODGE_MS > 0 THEN DodgeSecs! = TUNE_DODGE_MS / 1000! ELSE DodgeSecs! = DODGE_WINDOW
END FUNCTION

' Clear every fuse. Called when an encounter starts.
SUB FuseReset
    DIM a AS INTEGER
    FOR a = 0 TO FIGHT_MAXFOE
        FF_T(a) = 0: FF_DUR(a) = 0: FF_ARMED(a) = 0: FF_PEND(a) = 0
        FA_FUSE(a) = 0
    NEXT a
END SUB

' How long a fuse runs, in seconds, for a foe of `tier` menace (0 = slow/lumbering, 1 = normal,
' 2 = fast) at dungeon `depth` 1..9.
'
' Deeper is faster, and a faster tier is faster, but the result is FLOORED at FUSE_MIN so there
' is always a reaction window. Without that floor, level 9 would eventually produce fuses shorter
' than a human reaction time -- an unavoidable hit, which players read as a bug rather than as
' difficulty, and which no amount of skill could answer.
FUNCTION FuseDur! (tier AS INTEGER, depth AS INTEGER)
    DIM d AS SINGLE, tt AS INTEGER, dp AS INTEGER
    tt = tier
    IF tt < 0 THEN tt = 0
    IF tt > 2 THEN tt = 2
    dp = depth
    IF dp < 1 THEN dp = 1
    IF dp > 9 THEN dp = 9
    ' Data-tuned (assets/data/tuning.txt), defaulting to 4.2s at tier 0 / depth 1, less 0.55s per
    ' menace tier and 0.18s per level -- then floored so a reaction window always exists.
    DIM bas AS SINGLE, per AS SINGLE, dep AS SINGLE   ' `bas`, not `base` -- BASE is reserved
    IF TUNE_FUSE_BASE_MS > 0 THEN bas = TUNE_FUSE_BASE_MS / 1000! ELSE bas = 4.2
    IF TUNE_FUSE_TIER_MS > 0 THEN per = TUNE_FUSE_TIER_MS / 1000! ELSE per = 0.55
    IF TUNE_FUSE_DEPTH_MS > 0 THEN dep = TUNE_FUSE_DEPTH_MS / 1000! ELSE dep = 0.18
    d = bas - per * tt - dep * (dp - 1)
    IF d < FuseMinSecs! THEN d = FuseMinSecs!
    FuseDur! = d
END FUNCTION

' Start a slot's fuse for `secs` seconds. Re-arming resets it from zero -- which is what makes
' killing or staggering a foe worth doing: its wind-up is thrown away, not merely paused.
SUB FuseArm (a AS INTEGER, secs AS SINGLE)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FF_DUR(a) = secs
    IF FF_DUR(a) < FuseMinSecs! THEN FF_DUR(a) = FuseMinSecs!
    FF_T(a) = 0: FF_ARMED(a) = -1: FF_PEND(a) = 0
    FA_FUSE(a) = 0
END SUB

' Arm a foe from its tier and the dungeon depth -- the usual entry point.
SUB FuseArmFoe (a AS INTEGER, tier AS INTEGER, depth AS INTEGER)
    FuseArm a, FuseDur!(tier, depth)
END SUB

' Stop a slot's fuse and discard any pending attack. Used when a foe dies or is staggered.
SUB FuseDisarm (a AS INTEGER)
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT SUB
    FF_ARMED(a) = 0: FF_PEND(a) = 0: FF_T(a) = 0
    FA_FUSE(a) = 0
END SUB

' Advance every armed fuse by `dt` seconds and return the slot that FIRED, or FUSE_NONE.
'
' Two fuses can complete in the same frame, and losing one of them would silently drop an attack.
' So a completed fuse becomes PENDING and stays pending until taken: this call returns the most
' OVERDUE pending slot (largest overshoot), and the rest queue for subsequent calls. Most-overdue
' rather than lowest-index so the order is fair and explainable -- with lowest-index, foe 1 would
' always pre-empt foe 4 even when foe 4's fuse completed first.
'
' A dead or unused slot never advances, so a corpse cannot attack.
FUNCTION FuseStep% (dt AS SINGLE)
    DIM a AS INTEGER, best AS INTEGER, bestover AS SINGLE, over AS SINGLE
    best = FUSE_NONE: bestover = -1
    FOR a = 0 TO FIGHT_MAXFOE
        ' A slot only runs if it is occupied AND alive. Slot 0 is exempt from the FA_USED check
        ' only in the sense that the caller always fills it; the same rule applies.
        IF FF_ARMED(a) AND FA_USED(a) AND FA_ALIVE(a) THEN
            FF_T(a) = FF_T(a) + dt
            IF FF_T(a) >= FF_DUR(a) THEN
                FF_ARMED(a) = 0
                FF_PEND(a) = -1
            END IF
        END IF
        ' FF_T is deliberately NOT clamped -- the amount it exceeds FF_DUR by IS the overshoot,
        ' and the queue below needs it. Only the RENDER value clamps, so the bar cannot overfill.
        IF FF_DUR(a) > 0 THEN
            FA_FUSE(a) = FF_T(a) / FF_DUR(a)
            IF FA_FUSE(a) > 1 THEN FA_FUSE(a) = 1
        ELSE
            FA_FUSE(a) = 0
        END IF
    NEXT a
    ' Pick the most overdue pending slot: the one whose FF_T has run furthest past its FF_DUR.
    ' That is genuinely "whose fuse completed first", independent of slot order.
    FOR a = 0 TO FIGHT_MAXFOE
        IF FF_PEND(a) THEN
            over = FF_T(a) - FF_DUR(a)
            IF over > bestover THEN bestover = over: best = a
        END IF
    NEXT a
    IF best <> FUSE_NONE THEN FF_PEND(best) = 0
    FuseStep% = best
END FUNCTION

' Pop the next queued attack without advancing time, or FUSE_NONE. Lets a caller drain a frame
' in which several fuses completed, one resolution at a time.
FUNCTION FuseTakePending%
    DIM a AS INTEGER
    FuseTakePending% = FUSE_NONE
    FOR a = 0 TO FIGHT_MAXFOE
        IF FF_PEND(a) THEN FF_PEND(a) = 0: FuseTakePending% = a: EXIT FUNCTION
    NEXT a
END FUNCTION

' Which slot fires SOONEST -- the "INITIATIVE" readout on the mockup.
'
' Initiative here is EMERGENT, not a rolled order: it is whoever is closest to acting right now,
' which is the single most useful thing the player can know while triaging. It changes as fuses
' advance and as foes are staggered, which a fixed turn order could never express.
FUNCTION FuseNextActor%
    DIM a AS INTEGER, best AS INTEGER, bestleft AS SINGLE, remain AS SINGLE
    best = FUSE_NONE: bestleft = 0
    FOR a = 0 TO FIGHT_MAXFOE
        IF FF_ARMED(a) AND FA_USED(a) AND FA_ALIVE(a) THEN
            remain = FF_DUR(a) - FF_T(a)
            IF remain < 0 THEN remain = 0
            IF best = FUSE_NONE OR remain < bestleft THEN bestleft = remain: best = a
        END IF
    NEXT a
    FuseNextActor% = best
END FUNCTION

' Seconds until that slot fires (0 if it is not running).
FUNCTION FuseRemaining! (a AS INTEGER)
    DIM remain AS SINGLE
    IF a < 0 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    IF FF_ARMED(a) = 0 THEN EXIT FUNCTION
    remain = FF_DUR(a) - FF_T(a)
    IF remain < 0 THEN remain = 0
    FuseRemaining! = remain
END FUNCTION

' Is any fuse running at all? FALSE means nothing is pressuring the player, so a caller can stop
' burning frames on the tactical loop.
FUNCTION FuseAnyArmed%
    DIM a AS INTEGER
    FOR a = 0 TO FIGHT_MAXFOE
        IF FF_ARMED(a) AND FA_USED(a) AND FA_ALIVE(a) THEN FuseAnyArmed% = -1: EXIT FUNCTION
    NEXT a
END FUNCTION

'--- target selection ------------------------------------------------------

' Is this slot a legal attack target? Foes only, occupied and alive -- the player (slot 0) is
' never targetable by the player's own selector.
FUNCTION TargetOk% (a AS INTEGER)
    IF a < 1 OR a > FIGHT_MAXFOE THEN EXIT FUNCTION
    IF FA_USED(a) = 0 THEN EXIT FUNCTION
    IF FA_ALIVE(a) = 0 THEN EXIT FUNCTION
    TargetOk% = -1
END FUNCTION

' The first legal target, or 0 if the fight is over.
FUNCTION TargetFirst%
    DIM a AS INTEGER
    FOR a = 1 TO FIGHT_MAXFOE
        IF TargetOk%(a) THEN TargetFirst% = a: EXIT FUNCTION
    NEXT a
END FUNCTION

' Move the selection `delta` steps (+1 right / -1 left) over LIVING foes only, wrapping.
'
' Skipping the dead is the point: with four columns and corpses left in place, cycling onto a
' corpse would let the player aim at something they cannot hit, and the mis-aim is only visible
' as an attack that does nothing.
SUB TargetCycle (delta AS INTEGER)
    DIM a AS INTEGER, n AS INTEGER, stp AS INTEGER   ' `stp`, not `step` -- STEP is reserved
    IF TargetFirst% = 0 THEN FA_TARGET = 0: EXIT SUB      ' nothing alive to aim at
    IF delta >= 0 THEN stp = 1 ELSE stp = -1
    a = FA_TARGET
    IF TargetOk%(a) = 0 THEN a = TargetFirst%: FA_TARGET = a: IF delta = 0 THEN EXIT SUB
    ' At most FIGHT_MAXFOE hops are ever needed; the bound also guarantees termination if every
    ' foe died between the TargetFirst% check and here.
    FOR n = 1 TO FIGHT_MAXFOE
        a = a + stp
        IF a > FIGHT_MAXFOE THEN a = 1
        IF a < 1 THEN a = FIGHT_MAXFOE
        IF TargetOk%(a) THEN FA_TARGET = a: EXIT SUB
    NEXT n
END SUB

' Keep FA_TARGET legal. Call after any damage: if the selected foe just died, the selection must
' move on its own, or the next attack silently aims at a corpse.
SUB TargetValidate
    IF TargetOk%(FA_TARGET) THEN EXIT SUB
    FA_TARGET = TargetFirst%
END SUB

' Set the FIGHT_INIT display string from the live fuse state: who acts next and in how long.
'
' Lives here rather than in FIGHT.bas because the KNOWLEDGE is here -- the renderer should not
' have to understand fuses to label a ribbon. Keeping it in one place also stops the real fight
' loop and the `fightshot` dev mode from formatting it two slightly different ways.
SUB FuseSyncInitiative
    DIM a AS INTEGER
    a = FuseNextActor%
    IF a = FUSE_NONE THEN FIGHT_INIT = "": EXIT SUB
    FIGHT_INIT = _TRIM$(FA_NAME(a)) + " (" + FmtSecs$(FuseRemaining!(a)) + ")"
END SUB

' Seconds to one decimal, e.g. "1.4s". Small enough to inline, but the fight ribbon, the gauge
' caption and the log all want the identical format.
FUNCTION FmtSecs$ (secs AS SINGLE)
    DIM whole AS INTEGER, tenth AS INTEGER, v AS SINGLE
    v = secs
    IF v < 0 THEN v = 0
    whole = INT(v)
    tenth = INT((v - whole) * 10 + 0.5)
    IF tenth >= 10 THEN whole = whole + 1: tenth = 0
    FmtSecs$ = LTRIM$(STR$(whole)) + "." + LTRIM$(STR$(tenth)) + "s"
END FUNCTION
