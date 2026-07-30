$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/FUSE.bas -- parallel attack fuses + target selection.
'
'  The fuse model was split out of the renderer precisely so it could be asserted here with
'  no display. What makes that worth doing is the FAILURE MODE of everything in this file:
'  every bug in a parallel-fuse system looks like "an attack that just didn't happen" or
'  "an attack from the wrong monster" -- events a player experiences as jank and a
'  maintainer cannot reproduce on demand. None of it throws, and none of it is visible in
'  a screenshot.
'
'  The four properties that matter most, and why each is easy to get wrong:
'
'    #1 SIMULTANEITY. Fuses must all advance on the same step. The obvious implementation
'       (advance the current actor's fuse) yields a turn-based fight wearing a real-time
'       costume, and no test of a single fuse would notice.
'    #2 NO DROPPED ATTACKS. Two fuses CAN complete in one frame. A function that returns
'       "the slot that fired" silently discards the second one. So completion queues, and
'       the queue is asserted to drain completely.
'    #3 FAIRNESS OF ORDER. When two complete together, resolving by slot index makes foe 1
'       permanently pre-empt foe 4. Order must follow whose fuse actually finished first.
'    #4 CORPSES DO NOT ACT, AND CANNOT BE AIMED AT. Foes stay on screen after dying, so
'       "dead" is a flag rather than a removal -- which means every fuse and target path has
'       to check it. Missing the check gives attacks from corpses and attacks aimed at them.
'
'  Time is passed in explicitly (dt), never read from TIMER, so every assertion is exact and
'  the suite cannot flake.
' ============================================================================

T_Begin "engine/FUSE.bas"

DIM a AS INTEGER, i AS INTEGER, n AS INTEGER, bad AS INTEGER, fired AS INTEGER
DIM d1 AS SINGLE, d2 AS SINGLE

' Seat `cnt` living foes plus the player. FIGHT.bas owns FA_*; this suite sets them directly
' rather than pull in the renderer, which needs CANVAS.
SUB SeatFoes (cnt AS INTEGER)
    DIM k AS INTEGER
    FuseReset
    FOR k = 0 TO FIGHT_MAXFOE
        FA_USED(k) = 0: FA_ALIVE(k) = 0
    NEXT k
    FA_USED(0) = -1: FA_ALIVE(0) = -1                  ' the player
    FOR k = 1 TO cnt
        FA_USED(k) = -1: FA_ALIVE(k) = -1
    NEXT k
    FA_TARGET = 0
END SUB

T_Group "FuseDur! -- deeper and faster squeeze, but a floor guarantees a reaction window"
T_True "tier 2 is faster than tier 0", FuseDur!(2, 1) < FuseDur!(0, 1)
T_True "depth 9 is faster than depth 1", FuseDur!(1, 9) < FuseDur!(1, 1)
T_True "the worst case still leaves the floor", FuseDur!(2, 9) >= FUSE_MIN
T_True "  and the floor is a real window, not a token", FUSE_MIN >= 0.5
T_True "the easiest case is a generous window", FuseDur!(0, 1) > 3
T_EqI "tier is clamped, not wrapped (99 == 2)", INT(FuseDur!(99, 1) * 100), INT(FuseDur!(2, 1) * 100)
T_EqI "depth is clamped low (0 == 1)", INT(FuseDur!(1, 0) * 100), INT(FuseDur!(1, 1) * 100)
T_EqI "depth is clamped high (99 == 9)", INT(FuseDur!(1, 99) * 100), INT(FuseDur!(1, 9) * 100)

T_Group "tuning OVERRIDES, and zero means DEFAULT (examples/minimal never loads tuning.txt)"
' The engine must work with no game attached. If these read the tuning globals directly, a game
' that never calls LoadTuning gets a 0-second reaction window and every fuse fires instantly.
TUNE_FUSE_MIN_MS = 0: TUNE_GESTURE_MS = 0: TUNE_DODGE_MS = 0
T_EqI "unset fuse floor falls back to the built-in", INT(FuseMinSecs! * 1000), INT(FUSE_MIN * 1000)
T_EqI "unset gesture window falls back", INT(GestureSecs! * 1000), INT(GESTURE_FUSE * 1000)
T_EqI "unset dodge window falls back", INT(DodgeSecs! * 1000), INT(DODGE_WINDOW * 1000)
TUNE_FUSE_MIN_MS = 1500: TUNE_GESTURE_MS = 2500: TUNE_DODGE_MS = 400
T_EqI "a set fuse floor is used (ms -> s)", INT(FuseMinSecs! * 1000), 1500
T_EqI "  gesture window", INT(GestureSecs! * 1000), 2500
T_EqI "  dodge window", INT(DodgeSecs! * 1000), 400
' The floor must actually FLOOR, using the tuned value.
T_True "the tuned floor bounds the worst case", FuseDur!(2, 9) >= 1.5
SeatFoes 1
FuseArm 1, 0.1
T_True "arming below the tuned floor is raised to it", FF_DUR(1) >= 1.5
TUNE_FUSE_BASE_MS = 9000: TUNE_FUSE_TIER_MS = 0: TUNE_FUSE_DEPTH_MS = 0
T_EqI "a tuned base length is used", INT(FuseDur!(0, 1) * 1000), 9000
TUNE_FUSE_MIN_MS = 0: TUNE_GESTURE_MS = 0: TUNE_DODGE_MS = 0
TUNE_FUSE_BASE_MS = 0: TUNE_FUSE_TIER_MS = 0: TUNE_FUSE_DEPTH_MS = 0
' Rounded, not truncated: 4.2 is not exactly representable in SINGLE (4.19999...), so INT()
' of it * 100 is 419. Comparing truncated floats asserts the float format, not the value.
T_EqI "cleared again, back to the default base", INT(FuseDur!(0, 1) * 100 + 0.5), 420

T_Group "FuseArm -- arming resets from zero, and never below the floor"
SeatFoes 4
FuseArm 1, 3
T_EqI "fuse starts empty", INT(FA_FUSE(1) * 100), 0
T_True "  and armed", FF_ARMED(1)
fired = FuseStep%(1.5)
T_EqI "halfway after 1.5s of a 3s fuse", INT(FA_FUSE(1) * 100), 50
FuseArm 1, 3
T_EqI "re-arming throws the wind-up away", INT(FA_FUSE(1) * 100), 0
FuseArm 2, 0.01
T_True "a fuse shorter than the floor is raised to it", FF_DUR(2) >= FUSE_MIN

T_Group "principle #1: fuses advance in PARALLEL, not in turn"
SeatFoes 4
FOR a = 1 TO 4: FuseArm a, 4: NEXT a
fired = FuseStep%(1)
bad = 0
FOR a = 1 TO 4
    IF INT(FA_FUSE(a) * 100) <> 25 THEN bad = -1
NEXT a
T_False "one 1s step advanced ALL FOUR fuses equally", bad
T_EqI "  and nothing fired yet", fired, FUSE_NONE

T_Group "a fuse fires exactly when it completes"
SeatFoes 1
FuseArm 1, 2
T_EqI "1.9s of a 2s fuse: not yet", FuseStep%(1.9), FUSE_NONE
T_EqI "the remaining 0.1s fires it", FuseStep%(0.1), 1
T_EqI "  the bar reads full", INT(FA_FUSE(1) * 100), 100
T_False "  and it is no longer armed (fires once, not every frame)", FF_ARMED(1)
T_EqI "  a further step fires nothing", FuseStep%(1), FUSE_NONE

T_Group "the render value clamps even though the model keeps the overshoot"
SeatFoes 1
FuseArm 1, 2
fired = FuseStep%(10)                                  ' massively overshoot
T_EqI "bar is clamped to full, never past it", INT(FA_FUSE(1) * 100), 100
T_True "  but the model kept the overshoot (needed for ordering)", FF_T(1) > FF_DUR(1)

T_Group "principle #2: simultaneous completions QUEUE -- no attack is dropped"
SeatFoes 4
FOR a = 1 TO 4: FuseArm a, 2: NEXT a
fired = FuseStep%(2)                                   ' all four complete on the same step
T_True "one of them fired", fired >= 1
n = 1
FOR i = 1 TO 8
    a = FuseTakePending%
    IF a <> FUSE_NONE THEN n = n + 1
NEXT i
T_EqI "all FOUR attacks were delivered, not one", n, 4
T_EqI "  and the queue is then empty", FuseTakePending%, FUSE_NONE

T_Group "principle #3: order follows whose fuse finished FIRST, not slot index"
' Foe 4 is given a much shorter fuse, so on a big step it overshoots by more -- it must
' resolve before foe 1. With naive lowest-index ordering, foe 1 would always win.
SeatFoes 4
FuseArm 1, 3.0
FuseArm 4, 1.0
fired = FuseStep%(3.0)
T_EqI "the foe whose fuse completed earliest fires first", fired, 4
T_EqI "  the other is still queued, not lost", FuseTakePending%, 1

T_Group "principle #4: a corpse never acts"
SeatFoes 2
FuseArm 1, 2: FuseArm 2, 2
FA_ALIVE(1) = 0                                        ' foe 1 dies mid wind-up
fired = FuseStep%(2)
T_EqI "only the living foe fired", fired, 2
T_EqI "  the dead one's fuse never advanced", INT(FA_FUSE(1) * 100), 0
T_EqI "  and it is not queued", FuseTakePending%, FUSE_NONE
' An UNUSED slot must be just as inert -- an empty seat is not a silent attacker.
SeatFoes 1
FuseArm 2, 1                                           ' slot 2 armed but never seated
T_EqI "an unused slot never fires", FuseStep%(5), FUSE_NONE

T_Group "the attacker's IDENTITY survives the queue (the dodge must name who swung)"
' Phase C's contract with the dodge UI: whoever the incoming attack belongs to has to come back
' correctly, or the player is told to dodge the wrong monster -- which reads as the game lying,
' and is indistinguishable from a targeting bug while playing.
SeatFoes 4
FA_NAME(1) = "GNOLL": FA_NAME(2) = "OGRE": FA_NAME(3) = "WRAITH": FA_NAME(4) = "RAT"
FuseArm 1, 3.0                     ' completes with the largest overshoot -> resolves 1st
FuseArm 2, 3.4
FuseArm 3, 3.8
FuseArm 4, 9.0                     ' does not complete at all
fired = FuseStep%(4.0)
T_EqI "the earliest-completing foe is the attacker", fired, 1
T_EqS "  and it can be named", _TRIM$(FA_NAME(fired)), "GNOLL"
a = FuseTakePending%
T_EqI "next queued attacker", a, 2
T_EqS "  named correctly", _TRIM$(FA_NAME(a)), "OGRE"
a = FuseTakePending%
T_EqI "third queued attacker", a, 3
T_EqS "  named correctly", _TRIM$(FA_NAME(a)), "WRAITH"
T_EqI "the foe whose fuse never completed did NOT attack", FuseTakePending%, FUSE_NONE
T_True "  and it is still winding up", FF_ARMED(4)

T_Group "FuseDisarm -- staggering a foe throws its wind-up away"
SeatFoes 2
FuseArm 1, 3
fired = FuseStep%(2.9)
T_True "nearly full", FA_FUSE(1) > 0.9
FuseDisarm 1
T_EqI "disarmed reads empty", INT(FA_FUSE(1) * 100), 0
T_EqI "  and cannot fire", FuseStep%(10), FUSE_NONE

T_Group "FuseNextActor% -- initiative is EMERGENT: whoever is closest to acting"
SeatFoes 3
FuseArm 1, 4: FuseArm 2, 4: FuseArm 3, 4
fired = FuseStep%(1)
T_EqI "equal fuses: the first is nominated", FuseNextActor%, 1
FuseArm 3, 1.2                                         ' foe 3 winds up fast
T_EqI "the soonest to fire takes initiative", FuseNextActor%, 3
' ...and it must CHANGE as the fight moves, which a rolled order could not express.
FuseDisarm 3
T_EqI "removing it hands initiative back", FuseNextActor%, 1
SeatFoes 2
T_EqI "nothing armed = no initiative (FUSE_NONE, not slot 0)", FuseNextActor%, FUSE_NONE

T_Group "FuseRemaining! / FuseAnyArmed%"
SeatFoes 2
T_False "nothing armed yet", FuseAnyArmed%
FuseArm 1, 3
T_True "armed", FuseAnyArmed%
fired = FuseStep%(1)
T_EqI "2s left of a 3s fuse", INT(FuseRemaining!(1) * 10), 20
T_EqI "an unarmed slot has no time left", INT(FuseRemaining!(2) * 10), 0
fired = FuseStep%(5)
T_False "after firing, nothing is armed", FuseAnyArmed%
T_EqI "  and remaining reads 0, never negative", INT(FuseRemaining!(1) * 10), 0
FA_ALIVE(1) = 0: FuseArm 1, 3
T_False "a dead foe does not count as armed pressure", FuseAnyArmed%

' ============================================================================
'  Target selection. The failure here is aiming at a corpse: the attack resolves against
'  something already dead, so it appears to do nothing at all.
' ============================================================================
T_Group "TargetOk% -- only living, seated FOES are legal"
SeatFoes 3
T_True "a living foe", TargetOk%(1)
T_False "the player (slot 0) is never a target", TargetOk%(0)
T_False "an unseated slot", TargetOk%(4)
T_False "out of range high", TargetOk%(99)
T_False "out of range low", TargetOk%(-1)
FA_ALIVE(2) = 0
T_False "a corpse", TargetOk%(2)

T_Group "TargetCycle -- steps over LIVING foes and wraps"
SeatFoes 4
FA_TARGET = 1
TargetCycle 1: T_EqI "right: 1 -> 2", FA_TARGET, 2
TargetCycle 1: T_EqI "right: 2 -> 3", FA_TARGET, 3
TargetCycle 1: T_EqI "right: 3 -> 4", FA_TARGET, 4
TargetCycle 1: T_EqI "right wraps: 4 -> 1", FA_TARGET, 1
TargetCycle -1: T_EqI "left wraps: 1 -> 4", FA_TARGET, 4
TargetCycle -1: T_EqI "left: 4 -> 3", FA_TARGET, 3

T_Group "TargetCycle -- the DEAD are skipped, not landed on"
SeatFoes 4
FA_ALIVE(2) = 0: FA_ALIVE(3) = 0                       ' 2 and 3 are corpses
FA_TARGET = 1
TargetCycle 1
T_EqI "1 -> 4, skipping both corpses", FA_TARGET, 4
TargetCycle 1
T_EqI "4 wraps to 1, still skipping", FA_TARGET, 1
TargetCycle -1
T_EqI "leftward also skips", FA_TARGET, 4

T_Group "TargetCycle -- degenerate cases terminate"
SeatFoes 4
FOR a = 2 TO 4: FA_ALIVE(a) = 0: NEXT a                ' only foe 1 alive
FA_TARGET = 1
TargetCycle 1
T_EqI "a lone survivor stays selected", FA_TARGET, 1
TargetCycle -1
T_EqI "  in both directions", FA_TARGET, 1
SeatFoes 4
FOR a = 1 TO 4: FA_ALIVE(a) = 0: NEXT a                ' everyone dead
FA_TARGET = 2
TargetCycle 1
T_EqI "no living foe leaves no target", FA_TARGET, 0

T_Group "TargetValidate -- the selection must move itself off a corpse"
' Called after damage. Without it, the next attack aims at a dead foe and appears to whiff.
SeatFoes 3
FA_TARGET = 2
TargetValidate
T_EqI "a valid target is left alone", FA_TARGET, 2
FA_ALIVE(2) = 0
TargetValidate
T_True "a dead target is replaced by a living one", TargetOk%(FA_TARGET)
FOR a = 1 TO 3: FA_ALIVE(a) = 0: NEXT a
TargetValidate
T_EqI "with nothing alive it clears to 0", FA_TARGET, 0
SeatFoes 3
FA_TARGET = 0
TargetValidate
T_True "an unset target is initialised to a real foe", TargetOk%(FA_TARGET)

T_Group "FmtSecs$ / FuseSyncInitiative -- the ribbon reads off the live fuse state"
T_EqS "whole seconds", FmtSecs$(2), "2.0s"
T_EqS "one decimal", FmtSecs$(1.44), "1.4s"
T_EqS "rounds to nearest tenth", FmtSecs$(1.46), "1.5s"
T_EqS "carries into the whole", FmtSecs$(1.96), "2.0s"
T_EqS "negative reads as zero", FmtSecs$(-3), "0.0s"
SeatFoes 3
FA_NAME(1) = "GNOLL": FA_NAME(2) = "OGRE": FA_NAME(3) = "WRAITH"
FuseSyncInitiative
T_EqS "nothing armed leaves the ribbon empty", FIGHT_INIT, ""
FuseArm 2, 4: FuseArm 3, 2
FuseSyncInitiative
T_EqS "names the soonest actor and its countdown", FIGHT_INIT, "WRAITH (2.0s)"
fired = FuseStep%(0.5)
FuseSyncInitiative
T_EqS "the countdown ticks down with it", FIGHT_INIT, "WRAITH (1.5s)"
FuseDisarm 3
FuseSyncInitiative
T_EqS "removing it hands the ribbon to the next", FIGHT_INIT, "OGRE (3.5s)"

T_Group "the pacing rule: DELIBERATION drains the fuses"
' The design point of the whole module -- if the player reads the menu instead of acting,
' something takes the opening. Asserted as: repeated steps with NO player action eventually
' fire every foe.
SeatFoes 4
FOR a = 1 TO 4: FuseArmFoe a, 1, 5: NEXT a
n = 0
FOR i = 1 TO 400                                       ' 400 x 50ms = 20 simulated seconds
    IF FuseStep%(0.05) <> FUSE_NONE THEN n = n + 1
    DO
        a = FuseTakePending%
        IF a = FUSE_NONE THEN EXIT DO
        n = n + 1
    LOOP
NEXT i
T_EqI "20s of standing still cost the player all four attacks", n, 4
T_False "  and nothing is left armed", FuseAnyArmed%

T_Done

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/FUSE.bas'
