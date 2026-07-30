$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/STATUS.bas -- per-actor status effects (durations + damage over time) and stances.
'
'  THE BUG THIS SUITE EXISTS FOR: at 60fps a 2-damage-per-second poison owes 0.0333 damage per
'  frame, and INT(0.0333) is ZERO. The obvious implementation therefore ticks happily forever and
'  never removes a single hit point. Nothing crashes, nothing warns, and in play it just looks
'  like poison is a bit weak -- so it survives playtesting. The assertion that matters most here
'  is "total delivered depends on the DURATION, not on the frame rate", checked at three
'  different step sizes.
'
'  The others are the same family of silent failure:
'    * an effect that never expires (a foe poisoned for the rest of the run)
'    * a DOT billed for time AFTER the effect ended (one long frame overpays)
'    * stacking, so two weak hits in the same second become an instant kill
'    * a corpse still being poisoned, or a stagger that never wears off
'
'  Time is passed in explicitly, never read from TIMER, so every total is exact.
' ============================================================================

T_Begin "engine/STATUS.bas"

DIM a AS INTEGER, i AS INTEGER, n AS INTEGER, bad AS INTEGER
DIM total AS LONG, dmg AS LONG

' Seat the player plus `cnt` living foes. STATUS.bas reads FIGHT.bas's FA_* to decide who is
' alive; this sets them directly rather than pull in the renderer, which needs CANVAS.
SUB Seat (cnt AS INTEGER)
    DIM k AS INTEGER
    FOR k = 0 TO FIGHT_MAXFOE
        FA_USED(k) = 0: FA_ALIVE(k) = 0
        StatusClear k
    NEXT k
    FA_USED(0) = -1: FA_ALIVE(0) = -1
    FOR k = 1 TO cnt
        FA_USED(k) = -1: FA_ALIVE(k) = -1
    NEXT k
END SUB

' Run an effect to completion in fixed steps and total the damage paid out.
FUNCTION RunOut& (a AS INTEGER, dt AS SINGLE, steps AS INTEGER)
    DIM i AS INTEGER, t AS LONG
    FOR i = 1 TO steps
        t = t + StatusTick&(a, dt)
    NEXT i
    RunOut& = t
END FUNCTION

T_Group "StatusApply% -- placement, and what it refuses"
Seat 2
T_True "applies to a living actor", StatusApply%(1, "poison", 3, 2, 0) > 0
T_EqI "  and is found by kind", StatusSlot%(1, "poison"), 1
T_True "  case-insensitive lookup", StatusHas%(1, "POISON")
T_True "  and whitespace-tolerant", StatusHas%(1, "  poison  ")
T_EqI "zero duration is refused", StatusApply%(1, "bleed", 0, 1, 0), 0
T_EqI "negative duration is refused", StatusApply%(1, "bleed", -5, 1, 0), 0
T_EqI "an empty kind is refused", StatusApply%(1, "", 3, 1, 0), 0
T_EqI "an out-of-range actor is refused", StatusApply%(99, "poison", 3, 1, 0), 0
FA_ALIVE(2) = 0
T_EqI "a CORPSE takes no new effects", StatusApply%(2, "poison", 3, 2, 0), 0
T_EqI "an unseated slot takes none either", StatusApply%(4, "poison", 3, 2, 0), 0

T_Group "REFRESH, not stack -- two doses are not two poisons"
' With four foes attacking in parallel it is easy to be hit twice in one second. Stacking is what
' turns that into an instant kill.
Seat 1
n = StatusApply%(0, "poison", 3, 2, 0)
T_EqI "one effect running", StatusCount%(0), 1
n = StatusApply%(0, "poison", 3, 2, 0)
T_EqI "a second identical dose does NOT add a slot", StatusCount%(0), 1
T_EqI "  duration is not doubled", INT(StatusSecs!(0, "poison") * 10), 30
n = StatusApply%(0, "poison", 5, 1, 0)
T_EqI "a LONGER dose extends", INT(StatusSecs!(0, "poison") * 10), 50
n = StatusApply%(0, "poison", 2, 9, 0)
T_EqI "  a shorter dose does not shorten it", INT(StatusSecs!(0, "poison") * 10), 50
T_EqI "  but the STRONGER dps is kept", INT(FS_DPS(0, StatusSlot%(0, "poison"))), 9

T_Group "slots are finite, and a fresh threat displaces the most nearly-expired"
Seat 1
n = StatusApply%(0, "aaa", 9, 0, 0)
n = StatusApply%(0, "bbb", 8, 0, 0)
n = StatusApply%(0, "ccc", 7, 0, 0)
n = StatusApply%(0, "ddd", 1, 0, 0)          ' the weakest hold on a slot
T_EqI "all four slots used", StatusCount%(0), FSTAT_MAX
n = StatusApply%(0, "eee", 6, 0, 0)
T_True "a fifth effect still lands", StatusHas%(0, "eee")
T_False "  by displacing the one with least time left", StatusHas%(0, "ddd")
T_True "  the long ones survive", StatusHas%(0, "aaa")
T_EqI "  and the count is still capped", StatusCount%(0), FSTAT_MAX

T_Group "THE FRACTIONAL BUG: total damage depends on DURATION, not frame rate"
' 2 dps for 3 seconds = 6, however finely time is sliced. A naive INT() per frame yields 0.
Seat 1
n = StatusApply%(0, "poison", 3, 2, 0)
total = RunOut&(0, 1! / 60!, 400)
T_EqI "at 60fps: 2dps x 3s = 6", total, 6
Seat 1
n = StatusApply%(0, "poison", 3, 2, 0)
total = RunOut&(0, 1! / 200!, 1200)
T_EqI "at 200fps: same 6", total, 6
Seat 1
n = StatusApply%(0, "poison", 3, 2, 0)
total = RunOut&(0, 0.5, 20)
T_EqI "in half-second steps: same 6", total, 6
Seat 1
n = StatusApply%(0, "poison", 3, 2, 0)
T_EqI "in ONE giant step: still 6, not 6x the step", StatusTick&(0, 99), 6

T_Group "  ...and a sub-1-dps effect still eventually bites"
' The case a naive implementation loses entirely: less than one damage per second.
Seat 1
n = StatusApply%(0, "chill", 10, 0.5, 0)
total = RunOut&(0, 1! / 60!, 1000)
T_EqI "0.5dps x 10s = 5", total, 5

T_Group "effects EXPIRE, on their own, exactly on time"
Seat 1
n = StatusApply%(0, "poison", 2, 1, 0)
dmg = StatusTick&(0, 1.9)
T_True "still running at 1.9s of 2s", StatusHas%(0, "poison")
dmg = StatusTick&(0, 0.2)
T_False "gone at 2.1s", StatusHas%(0, "poison")
T_EqI "  and the slot is empty", StatusCount%(0), 0
T_EqI "  ticking afterwards costs nothing", StatusTick&(0, 10), 0

T_Group "a long frame is not billed for time after the effect ended"
' 5 dps but only 1 second left: a single 10-second step must pay 5, not 50.
Seat 1
n = StatusApply%(0, "burn", 1, 5, 0)
T_EqI "pays only for the second it had", StatusTick&(0, 10), 5
T_False "  and is gone", StatusHas%(0, "burn")

T_Group "a corpse is never ticked"
Seat 1
n = StatusApply%(0, "poison", 5, 4, 0)
FA_ALIVE(0) = 0
T_EqI "dead actor takes no DOT", StatusTick&(0, 5), 0
T_True "  the effect is untouched, not silently drained", StatusHas%(0, "poison")

T_Group "StatusRemove% -- a cure"
Seat 1
n = StatusApply%(0, "poison", 5, 2, 0)
n = StatusApply%(0, "bleed", 5, 1, 0)
T_True "removes the named kind", StatusRemove%(0, "poison")
T_False "  it is gone", StatusHas%(0, "poison")
T_True "  the other survives", StatusHas%(0, "bleed")
T_False "removing an absent kind reports nothing done", StatusRemove%(0, "poison")

T_Group "StatusMod% -- modifiers sum, and vanish with their effect"
Seat 1
T_EqI "no effects, no modifier", StatusMod%(0), 0
n = StatusApply%(0, "weak", 5, 0, -2)
n = StatusApply%(0, "blind", 5, 0, -1)
T_EqI "two penalties sum", StatusMod%(0), -3
n = StatusApply%(0, "bless", 5, 0, 3)
T_EqI "a bonus offsets them", StatusMod%(0), 0
dmg = StatusTick&(0, 6)
T_EqI "expired effects contribute nothing", StatusMod%(0), 0

T_Group "StatusText$ -- one line for the EFFECT: row"
Seat 1
T_EqS "nothing running reads empty", StatusText$(0), ""
n = StatusApply%(0, "poison", 3, 2, 0)
T_EqS "kind + countdown", StatusText$(0), "POISON 3.0s"
n = StatusApply%(0, "bleed", 1, 1, 0)
T_EqS "shows the LONGEST, and counts the rest", StatusText$(0), "POISON 3.0s +1"

T_Group "StatusClear / StatusClearAll"
Seat 2
n = StatusApply%(0, "poison", 5, 2, 0)
n = StatusApply%(1, "bleed", 5, 2, 0)
StatusClear 0
T_EqI "one actor cleared", StatusCount%(0), 0
T_EqI "  the other untouched", StatusCount%(1), 1
StatusClearAll
T_EqI "all cleared", StatusCount%(1), 0

' ============================================================================
'  Stances. A stance is MECHANICAL: it scales damage dealt and taken.
' ============================================================================
T_Group "stance modifiers -- committing is a trade, not a free bonus"
T_True "attacking deals MORE than ready", StanceOutPct%(STANCE_ATTACK) > StanceOutPct%(STANCE_READY)
T_True "  and TAKES more (that is the trade)", StanceInPct%(STANCE_ATTACK) > StanceInPct%(STANCE_READY)
T_True "guarding takes LESS", StanceInPct%(STANCE_GUARD) < StanceInPct%(STANCE_READY)
T_True "  and deals less", StanceOutPct%(STANCE_GUARD) < StanceOutPct%(STANCE_READY)
T_True "staggered is the punish window -- takes the most", StanceInPct%(STANCE_STAGGER) > StanceInPct%(STANCE_ATTACK)
T_True "  and deals the least", StanceOutPct%(STANCE_STAGGER) <= StanceOutPct%(STANCE_GUARD)
T_EqI "ready is the neutral 100%% out", StanceOutPct%(STANCE_READY), 100
T_EqI "ready is the neutral 100%% in", StanceInPct%(STANCE_READY), 100
T_EqS "unknown stance names as READY", StanceName$(99), "READY"

T_Group "ScaleDmg& -- a blow that connected always costs at least 1"
T_EqI "no damage stays none", ScaleDmg&(0, 50), 0
T_EqI "half of 10", ScaleDmg&(10, 50), 5
T_EqI "125%% of 8", ScaleDmg&(8, 125), 10
' Without the floor, a guarded 1-damage hit rounds to 0 and a guarding actor looks invulnerable.
T_EqI "1 damage halved is still 1, never 0", ScaleDmg&(1, 50), 1
T_EqI "  even at 10%%", ScaleDmg&(1, 10), 1

T_Group "TunePct% -- zero means DEFAULT, not zero percent"
' A genuine 0%% stance would make an actor deal literally no damage. An unset config value must
' never mean that, or a game that skips tuning.txt silently disables combat.
T_EqI "unset uses the default", TunePct%(0, 125), 125
T_EqI "set wins", TunePct%(80, 125), 80
T_EqI "negative is treated as unset", TunePct%(-5, 125), 125
TUNE_ST_ATK_OUT = 0: TUNE_ST_GRD_IN = 0
T_EqI "unset ATTACK-out is the built-in 125", StanceOutPct%(STANCE_ATTACK), 125
T_EqI "unset GUARD-in is the built-in 50", StanceInPct%(STANCE_GUARD), 50
TUNE_ST_ATK_OUT = 200: TUNE_ST_GRD_IN = 10
T_EqI "tuned ATTACK-out is used", StanceOutPct%(STANCE_ATTACK), 200
T_EqI "tuned GUARD-in is used", StanceInPct%(STANCE_GUARD), 10
T_EqI "  and still floors a connected blow at 1", ScaleDmg&(5, 10), 1
TUNE_ST_ATK_OUT = 0: TUNE_ST_GRD_IN = 0

T_Group "StaggerActor / StanceSync -- a stagger wears off by itself"
' Modelled as a STATUS rather than a flag, so it expires through the normal tick. As a flag it
' would need clearing by hand, and a missed clear leaves a foe permanently STAGGERED -- invisible
' except as an enemy that never recovers.
Seat 1
StaggerActor 1, 2
T_EqI "staggered", FA_STANCE(1), STANCE_STAGGER
T_True "  and it is a real effect, not a flag", StatusHas%(1, "stagger")
dmg = StatusTick&(1, 1)
StanceSync 1
T_EqI "still staggered at 1s of 2s", FA_STANCE(1), STANCE_STAGGER
dmg = StatusTick&(1, 1.5)
StanceSync 1
T_EqI "recovered once it expired", FA_STANCE(1), STANCE_READY
' And StanceSync must not stomp a stance the game set deliberately.
FA_STANCE(1) = STANCE_GUARD
StanceSync 1
T_EqI "a deliberate stance is left alone", FA_STANCE(1), STANCE_GUARD

T_Done

' --- stubbed collaborator ---------------------------------------------------
' StatusText$ formats its countdown with FmtSecs$, which lives in engine/FUSE.bas. Including
' FUSE.bas whole would drag the fuse model into a status test; this is the one function needed.
FUNCTION FmtSecs$ (secs AS SINGLE)
    DIM whole AS INTEGER, tenth AS INTEGER, v AS SINGLE
    v = secs
    IF v < 0 THEN v = 0
    whole = INT(v)
    tenth = INT((v - whole) * 10 + 0.5)
    IF tenth >= 10 THEN whole = whole + 1: tenth = 0
    FmtSecs$ = LTRIM$(STR$(whole)) + "." + LTRIM$(STR$(tenth)) + "s"
END FUNCTION

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/STATUS.bas'
