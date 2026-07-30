' ============================================================================
'  FIGHTPLAY.bas -- the GAME's interactive tactical-combat loop.
'
'  Everything engine-side is already in place: engine/FIGHT.bas holds the actors and the
'  renderer, engine/FUSE.bas the parallel countdowns and target selection, engine/GAUGE.bas
'  the resolution model. This file is what makes them a playable fight: it seeds the actors
'  from DUNGEON! content, runs the frame loop, reads input, and resolves outcomes.
'
'  WHY THIS IS IN game/ AND NOT engine/: per engine/ENGINE.md's hook-design lesson -- "not
'  every leak wants a hook, check who calls it first." The loop names MON_NAME, CLASSES,
'  player_*, Sfx and the flavor tables. It is called only from dungeon.bas, the CLI dev mode,
'  and the [0] cheat panel -- all game-side. Putting it here costs ZERO new contract surface.
'  If a second game ever wants a tactical loop, extract it THEN, against real requirements,
'  rather than inventing hooks now for a caller that does not exist.
'
'  THE PACING RULE: FuseStep is called every frame, unconditionally -- including while the
'  player sits in the menu. That is the whole design (greywood's fix): deliberation costs
'  time, and standing still gets you hit. It is not a bug that the menu does not pause.
'
'  D.0 SCOPE: resolution is the SAFE BASELINE (GaugeBaselineDamage&) for both sides -- no
'  gestures yet. That makes the screen playable and inspectable before the interactive gauge
'  and the dodge QTE go in (Phase D.1), so those can be built against a fight that already
'  runs rather than against a static mock.
' ============================================================================

' Menu slots. Numbered rather than named-string-compared so a typo cannot silently pick the
' wrong action.
CONST FACT_ATTACK = 1
CONST FACT_GUARD = 2
CONST FACT_CAST = 3
CONST FACT_USE = 4
CONST FACT_FLEE = 5
CONST FACT_FLOURISH = 6
CONST FACT_SHOOT = 7

' The player's effective "strength" for the shared damage seam.
'
' GaugeDamage& expects a small 0..9 magnitude, but player_str is a 3d6 ability score (3..18) --
' feeding it in raw would deal ~22 per swing. So the ability MOD carries it, plus a slow level
' term. Provisional tuning: this wants to move to assets/data/tuning.txt once the fight is
' balanced against real encounters rather than synthetic ones.
FUNCTION FightPlayerStrength%
    DIM v AS INTEGER
    v = 3 + AbilMod(player_str) + char_level \ 2
    IF v < 0 THEN v = 0
    IF v > 9 THEN v = 9
    FightPlayerStrength% = v
END FUNCTION

' A monster's menace TIER for FuseDur! (0 slow / 1 normal / 2 fast). Derived from its slot in
' the level's pool -- slot 1 is the level's weakest, slot 3 its nastiest -- so a level's fast
' monster genuinely winds up faster without a new data column.
FUNCTION FightFoeTier% (slot AS INTEGER)
    IF slot <= 1 THEN
        FightFoeTier% = 0
    ELSEIF slot = 2 THEN
        FightFoeTier% = 1
    ELSE
        FightFoeTier% = 2
    END IF
END FUNCTION

' Seat the player and `nfoes` monsters drawn from level `lvl`'s pool, and arm every fuse.
SUB SeedFight (lvl AS INTEGER, nfoes AS INTEGER)
    DIM a AS INTEGER, slot AS INTEGER, nm AS STRING, cnt AS INTEGER, mhp AS INTEGER

    FightReset
    FuseReset
    StatusClearAll

    '--- the player, slot 0 -------------------------------------------------
    nm = _TRIM$(CLASSES(player_class).name)
    FightSetActor 0, _TRIM$(player_name), OrdLevel$(char_level) + " " + nm, _
                  "classes/" + SpriteBase$(nm), player_hp, player_maxhp
    FightSetStat 0, 1, "MELEE:", SgnStr$(player_tohit)
    FightSetStat 0, 2, "DAMAGE:", "d" + LTRIM$(STR$(player_dmgdie)) + SgnStr$(player_dmgbonus)
    FightSetStat 0, 3, "ARMOR:", "AC" + LTRIM$(STR$(player_ac))
    FightSetStatus 0, 2, "STANCE:", "READY"
    ' The general class portrait, as the fallback when no fight-sized art exists yet.
    FightSetArtFallback 0, ClassSprite$(player_class)   ' takes a class INDEX, not a name

    '--- the foes ----------------------------------------------------------
    cnt = nfoes
    IF cnt < 1 THEN cnt = 1
    IF cnt > FIGHT_MAXFOE THEN cnt = FIGHT_MAXFOE
    FOR a = 1 TO cnt
        slot = ((a - 1) MOD 3) + 1
        nm = _TRIM$(MON_NAME(lvl, slot))
        IF LEN(nm) = 0 THEN nm = "SOMETHING"
        ' Provisional HP curve -- deeper and nastier hits harder. Real encounters will carry
        ' this from the room's ROOMS().mhp once the fight is wired into the board.
        mhp = 5 + lvl * 2 + slot * 2
        FightSetActor a, nm, "", "monsters/" + SpriteBase$(nm), mhp, mhp
        FightSetStat a, 1, "MELEE:", SgnStr$(lvl + slot)
        FightSetStat a, 3, "ARMOR:", "AC" + LTRIM$(STR$(6 + slot))
        FightSetStatus a, 2, "STANCE:", "CIRCLING"
        ' MonsterSprite$ knows the category subfolders (monsters/beasts/...) and the mimic
        ' event-prop fallback -- knowledge the engine deliberately does not have.
        FightSetArtFallback a, MonsterSprite$(nm)
        FuseArmFoe a, FightFoeTier%(slot), lvl
    NEXT a

    FA_TARGET = TargetFirst%
    FIGHT_ROUND = 1
    FuseSyncInitiative
    FightMenuRoot
END SUB

' "+3" / "-1" / "+0" -- a signed modifier always shows its sign, so a bonus never reads as a
' bare number the player has to guess the meaning of.
FUNCTION SgnStr$ (v AS INTEGER)
    IF v >= 0 THEN SgnStr$ = "+" + LTRIM$(STR$(v)) ELSE SgnStr$ = LTRIM$(STR$(v))
END FUNCTION

' "1st" / "2nd" / "3rd" / "4th" ... for the class line under the portrait.
FUNCTION OrdLevel$ (n AS INTEGER)
    DIM v AS INTEGER, ord AS STRING   ' NOT `sfx` -- that collides with the Sfx SUB
    v = n
    IF v < 1 THEN v = 1
    ord = "th"
    IF (v MOD 100) < 11 OR (v MOD 100) > 13 THEN
        SELECT CASE v MOD 10
            CASE 1: ord = "st"
            CASE 2: ord = "nd"
            CASE 3: ord = "rd"
        END SELECT
    END IF
    OrdLevel$ = LTRIM$(STR$(v)) + ord
END FUNCTION

' Load the root action menu + the hint line.
SUB FightMenuRoot
    FMENU_N = 5
    FMENU(FACT_ATTACK) = "ATTACK"
    FMENU(FACT_GUARD) = "GUARD"
    FMENU(FACT_CAST) = "CAST"
    FMENU(FACT_USE) = "USE"
    FMENU(FACT_FLEE) = "FLEE"
    ' FLOURISH is the OPT-IN GAMBLE: a played gesture with a higher ceiling and a real fail
    ' tail, against ATTACK's guaranteed middling hit. Only offered when the player has Action
    ' Gestures on -- the same ruleset toggle SECOND WIND and CRIT FLOURISH already gate on, so
    ' someone who does not want timing mini-games never sees one.
    IF opt_gestures THEN
        FMENU_N = 6
        FMENU(FACT_FLOURISH) = "FLOURISH"
    END IF
    ' SHOOT needs the Magic Bow, per DUNGEON!'s rules -- so the row appears only when the player
    ' actually holds it, rather than being offered and then refused.
    IF item_bow THEN
        FMENU_N = 7
        FMENU(FACT_SHOOT) = "SHOOT"
    END IF
    IF FMENU_SEL < 1 OR FMENU_SEL > FMENU_N THEN FMENU_SEL = FACT_ATTACK
    FMENU_SUBN = 0
    ' Arrows do two different jobs, so the hint names both -- with four foe columns, a player
    ' who does not know left/right retargets will attack the wrong one and blame the game.
    FMENU_HINT = "UP/DOWN action   LEFT/RIGHT target   ENTER commit   ESC flee"
END SUB

' Refresh the per-frame status text that changes as the fight moves.
' Tick every actor's status effects and apply the damage owed. Returns TRUE if the player died
' of it -- a poison kill has to end the fight exactly like a blow does, and forgetting that is how
' an actor ends up at 0 HP still taking turns.
FUNCTION FightTickStatus% (dt AS SINGLE)
    DIM a AS INTEGER, d AS LONG
    FOR a = 0 TO FIGHT_MAXFOE
        IF FA_USED(a) THEN
            d = StatusTick&(a, dt)
            IF d > 0 THEN
                IF a = 0 THEN
                    player_hp = player_hp - d
                    IF player_hp < 0 THEN player_hp = 0
                    FightSetHp 0, player_hp
                ELSE
                    FightSetHp a, FA_HP(a) - d
                    IF FA_ALIVE(a) = 0 THEN
                        FightLog "!", _TRIM$(FA_NAME(a)) + " succumbs."
                        FuseDisarm a
                        StatusClear a
                        TargetValidate
                    END IF
                END IF
            END IF
            StanceSync a
        END IF
    NEXT a
    IF player_hp <= 0 THEN FightTickStatus% = -1
END FUNCTION

SUB FightSyncStatus
    DIM a AS INTEGER
    FightSetStatus 0, 1, "HEALTH:", HealthWord$(player_hp, player_maxhp)
    FightSetStat 0, 2, "DAMAGE:", "d" + LTRIM$(STR$(player_dmgdie)) + SgnStr$(player_dmgbonus)
    FightSetStatus 0, 3, "EFFECT:", StatusText$(0)
    FOR a = 1 TO FIGHT_MAXFOE
        IF FA_USED(a) THEN
            FightSetStatus a, 1, "HEALTH:", HealthWord$(FA_HP(a), FA_MAXHP(a))
            IF FA_ALIVE(a) = 0 THEN
                FightSetStatus a, 2, "STANCE:", "SLAIN"
                FightSetStatus a, 3, "EFFECT:", ""
            ELSE
                IF FA_STANCE(a) = STANCE_STAGGER THEN
                    FightSetStatus a, 2, "STANCE:", "STAGGERED"
                ELSEIF a = FA_TARGET THEN
                    FightSetStatus a, 2, "STANCE:", "TARGETED"
                ELSE
                    FightSetStatus a, 2, "STANCE:", StanceName$(FA_STANCE(a))
                END IF
                FightSetStatus a, 3, "EFFECT:", StatusText$(a)
            END IF
        END IF
    NEXT a
    FuseSyncInitiative
END SUB

' HP as a WORD, not a number. The bar already carries the magnitude; a word carries the feeling,
' and it is what the mockup's HEALTH: row shows.
FUNCTION HealthWord$ (hp AS INTEGER, mx AS INTEGER)
    DIM f AS SINGLE
    IF mx <= 0 THEN HealthWord$ = "--": EXIT FUNCTION
    IF hp <= 0 THEN HealthWord$ = "SLAIN": EXIT FUNCTION
    ' Thresholds are data (tuning.txt), defaulting to 60/35/15%. Compared as whole percent so the
    ' tuning file reads in the same units the designer thinks in.
    f = (hp * 100) / mx
    IF hp >= mx THEN
        HealthWord$ = "UNHURT"
    ELSEIF f > TunePct%(TUNE_HP_GRAZED, 60) THEN
        HealthWord$ = "GRAZED"
    ELSEIF f > TunePct%(TUNE_HP_WOUNDED, 35) THEN
        HealthWord$ = "WOUNDED"
    ELSEIF f > TunePct%(TUNE_HP_BLOODIED, 15) THEN
        HealthWord$ = "BLOODIED"
    ELSE
        HealthWord$ = "NEAR DEATH"
    END IF
END FUNCTION

' Fill a GAUGEK from the player's actual condition. Everything the composure model needs is
' derived here rather than stored, so it always reflects the CURRENT fight: wounds narrow the
' window, and `press` is the live-foe crowd squeeze that makes 1-vs-4 harder than 1-vs-1.
' The player's felt SKILL TIER (0..2) from their character level. Game-side, because character
' level is a DUNGEON! concept -- the engine takes the tier as a number and never asks how it was
' derived. Shared by the fight screen and the board's SECOND WIND / CRIT FLOURISH.
FUNCTION SkillTier%
    IF char_level <= 1 THEN
        SkillTier% = 0
    ELSEIF char_level >= 5 THEN
        SkillTier% = 2
    ELSE
        SkillTier% = 1
    END IF
END FUNCTION

SUB FightBuildGauge (k AS GAUGEK, depth AS INTEGER)
    DIM lf AS INTEGER
    k.skill = SkillTier%
    k.hp = player_hp: k.maxhp = player_maxhp
    k.willmax = 3: k.will = 3
    k.wobble = 0
    lf = FightLiveFoes% - 1
    IF lf < 0 THEN lf = 0
    IF lf > 3 THEN lf = 3
    k.press = lf
    k.depth = depth
    GaugeKnobs k
END SUB

' The FLOURISH: play the gesture instead of taking the safe hit.
'
' A forfeited attempt (deadline passed with no commit) is NOT a miss -- it is worse, because the
' swing never happened and the foe fuses advanced the whole time. That distinction matters: it is
' what stops "open the gesture and wait" from being a free way to stall.
SUB FightFlourish (depth AS INTEGER)
    DIM k AS GAUGEK, z AS INTEGER, q AS SINGLE, dmg AS LONG, a AS INTEGER
    a = FA_TARGET
    IF TargetOk%(a) = 0 THEN FightLog "", "Nothing there to strike.": EXIT SUB
    FightBuildGauge k, depth
    z = FightGaugeRun%(k, GestureSecs!, q)
    IF z = FUSE_NONE THEN
        FightLog "!", "You hesitate -- the moment is gone."
        Sfx "miss"
        EXIT SUB
    END IF
    dmg = GaugeDamage&(FightPlayerStrength%, z, q)
    IF dmg > 0 THEN
        dmg = ScaleDmg&(dmg, StanceOutPct%(FA_STANCE(0)))
        dmg = ScaleDmg&(dmg, StanceInPct%(FA_STANCE(a)))
    END IF
    IF dmg <= 0 THEN
        FightLog "", "Your flourish goes wide."
        Sfx "miss"
        EXIT SUB
    END IF
    FightSetHp a, FA_HP(a) - dmg
    IF z = 2 THEN
        FIGHT_BANNER = "BONUS DAMAGE!"
        FightLog "C", "FLOURISH -- you open " + _TRIM$(FA_NAME(a)) + " for " + LTRIM$(STR$(dmg)) + "!"
        Sfx "crit"
        CritBoom dmg
        ' A crit STAGGERS: it throws the foe's wind-up away AND opens the punish window, which is
        ' what makes nailing the gesture worth the risk beyond the raw damage.
        IF FA_ALIVE(a) THEN
            StaggerActor a, 2.5
            FuseArmFoe a, FightFoeTier%(((a - 1) MOD 3) + 1), depth
        END IF
    ELSE
        FightLog "*", "You strike " + _TRIM$(FA_NAME(a)) + " for " + LTRIM$(STR$(dmg)) + "."
        Sfx "hit"
    END IF
    IF FA_ALIVE(a) = 0 THEN
        FightLog "!", _TRIM$(FA_NAME(a)) + " falls."
        Sfx "monster-death"
        FuseDisarm a
        TargetValidate
    END IF
END SUB

'--- resolution ------------------------------------------------------------

' The player's plain attack on the current target: the SAFE BASELINE, no gesture. Phase D.1 adds
' the opt-in gauge alongside this, and this stays as the reliable alternative.
SUB FightPlayerAttack
    DIM dmg AS LONG, a AS INTEGER
    a = FA_TARGET
    IF TargetOk%(a) = 0 THEN FightLog "", "Nothing there to strike.": EXIT SUB
    dmg = GaugeBaselineDamage&(FightPlayerStrength%)
    ' Stance is mechanical on BOTH sides: what the attacker's posture adds, and what the
    ' defender's posture absorbs. A staggered foe is the punish window.
    dmg = ScaleDmg&(dmg, StanceOutPct%(FA_STANCE(0)))
    dmg = ScaleDmg&(dmg, StanceInPct%(FA_STANCE(a)))
    FightSetHp a, FA_HP(a) - dmg
    ImpactFX ShakeMag!(dmg), 0
    Sfx "hit"
    FightLog "*", "You strike " + _TRIM$(FA_NAME(a)) + " for " + LTRIM$(STR$(dmg)) + "."
    IF FA_ALIVE(a) = 0 THEN
        FightLog "!", _TRIM$(FA_NAME(a)) + " falls."
        Sfx "monster-death"
        FuseDisarm a                       ' a corpse has no wind-up
        TargetValidate                     ' and must not stay selected
    END IF
END SUB

' A foe's fuse completed: it swings. `a` is the attacker, so the log (and later the dodge
' prompt) can NAME it -- being told to dodge the wrong monster reads as the game lying.
'
' There is no "current level" global -- the game derives the level from position on demand
' (SECTOR.get_by_xy) -- so the depth is passed in rather than read from a global that would
' have to be kept in sync.
SUB FightFoeAttack (a AS INTEGER, depth AS INTEGER, guarding AS INTEGER)
    DIM dmg AS LONG, lvl AS INTEGER
    IF FA_USED(a) = 0 OR FA_ALIVE(a) = 0 THEN EXIT SUB
    lvl = depth
    IF lvl < 1 THEN lvl = 1
    dmg = GaugeBaselineDamage&(2 + lvl \ 2)
    IF guarding THEN
        ' GUARD is the SAFE defensive choice: halve it, no reflex check. The dodge is the
        ' gamble -- all or nothing -- so the two mirror ATTACK vs FLOURISH on the offence.
        dmg = dmg \ 2
        IF dmg < 1 THEN dmg = 1
    ELSEIF opt_gestures THEN
        IF FightDodgeRun%(a, DodgeSecs!) THEN
            FightLog "+", "You slip aside -- " + _TRIM$(FA_NAME(a)) + " hits nothing."
            Sfx "miss"
            EXIT SUB
        END IF
    END IF
    dmg = ScaleDmg&(dmg, StanceOutPct%(FA_STANCE(a)))
    dmg = ScaleDmg&(dmg, StanceInPct%(FA_STANCE(0)))
    player_hp = player_hp - dmg
    IF player_hp < 0 THEN player_hp = 0
    FightSetHp 0, player_hp
    Sfx "player-pain"
    ImpactFX ShakeMag!(dmg), 1
    ' A deep level's foes leave a poison bite. Data-driven trap/curio effects can layer on top.
    IF depth >= 6 AND RND < 0.25 THEN
        IF StatusApply%(0, "poison", 4, 1, 0) > 0 THEN FightLog "M", "Its bite burns -- POISON."
    END IF
    IF guarding THEN
        FightLog "M", _TRIM$(FA_NAME(a)) + " hits your guard for " + LTRIM$(STR$(dmg)) + "."
    ELSE
        FightLog "M", _TRIM$(FA_NAME(a)) + " strikes you for " + LTRIM$(STR$(dmg)) + "."
    END IF
END SUB

' ARCHERY. Less damage than a melee swing, but it leaves the player in READY rather than ATTACK
' stance -- so it does not open the 125%-incoming window a committed swing does.
'
' That is the whole tactical point: with four foes on staggered fuses there are moments when
' chipping safely beats swinging hard, and this is the action for them. It is NOT strictly worse
' than ATTACK and NOT strictly better -- the trade is damage for exposure, decided by how close
' the nearest fuse is.
'
' The Magic Bow's +2 to-hit becomes +1 damage here, since the tactical screen has no to-hit roll.
SUB FightShoot (depth AS INTEGER)
    DIM dmg AS LONG, a AS INTEGER
    a = FA_TARGET
    IF TargetOk%(a) = 0 THEN FightLog "", "Nothing there to shoot.": EXIT SUB
    IF item_bow = 0 THEN FightLog "", "You have no bow.": EXIT SUB
    FA_STANCE(0) = STANCE_READY                       ' shooting does not expose you
    dmg = GaugeBaselineDamage&(FightPlayerStrength%)
    dmg = ScaleDmg&(dmg, 70)                          ' the cost of staying safe
    dmg = dmg + 1                                     ' the bow's bonus
    dmg = ScaleDmg&(dmg, StanceInPct%(FA_STANCE(a)))  ' a staggered foe is still a soft target
    FightSetHp a, FA_HP(a) - dmg
    Sfx "hit"
    ImpactFX ShakeMag!(dmg), 0
    FightLog "*", "Your arrow takes " + _TRIM$(FA_NAME(a)) + " for " + LTRIM$(STR$(dmg)) + "."
    IF FA_ALIVE(a) = 0 THEN
        FightLog "!", _TRIM$(FA_NAME(a)) + " falls."
        Sfx "monster-death"
        FuseDisarm a
        StatusClear a
        TargetValidate
    END IF
END SUB

' THE TACTICAL DEATH-SAVE. One clutch gesture when the player would drop -- nail the crit band and
' rise with 1d6 HP instead of losing the fight.
'
' ONCE PER ENCOUNTER, tracked by the caller: a repeatable save is not a save, it is immortality,
' and with parallel fuses the player would be offered one every few seconds. The window is
' deliberately tighter than a normal FLOURISH.
'
' Gated on Action Gestures like every other gesture: with them off the blow simply kills, which is
' the plain-rules outcome rather than a silent free life.
FUNCTION FightDeathSave% (depth AS INTEGER)
    DIM k AS GAUGEK, z AS INTEGER, q AS SINGLE, hp AS INTEGER
    IF NOT opt_gestures THEN EXIT FUNCTION
    FIGHT_BANNER = "FIGHT FOR YOUR LIFE"
    FightLog "!", "You are going down -- one chance!"
    Sfx "heartbeat"
    FightBuildGauge k, depth
    ' The crit band only: a hit is not enough to cheat death.
    z = FightGaugeRun%(k, GestureSecs! * 0.8, q)   ' tighter than a normal flourish
    IF z = 2 THEN
        hp = RollDie(6)
        player_hp = hp
        FightSetHp 0, hp
        FA_STANCE(0) = STANCE_READY
        StatusClear 0                                 ' the brush with death burns off what was on you
        FIGHT_BANNER = "** SECOND WIND! **"
        FightLog "+", "You claw back with " + LTRIM$(STR$(hp)) + " HP -- fight on!"
        Sfx "levelup"
        FightDeathSave% = -1
    ELSE
        FIGHT_BANNER = "YOU FALL"
        Sfx "death"
    END IF
END FUNCTION

'--- the loop --------------------------------------------------------------

' Run a tactical fight to a conclusion. Returns OUT_WIN / OUT_LOSE / OUT_FLEE.
'
' `lvl` is the dungeon level (drives the monster pool and the fuse speeds), `nfoes` 1..4.
FUNCTION RunFight% (lvl AS INTEGER, nfoes AS INTEGER)
    DIM k AS STRING, nk AS STRING, a AS INTEGER
    DIM tprev AS DOUBLE, dt AS SINGLE
    DIM guarding AS INTEGER, outcome AS INTEGER, banner_t AS SINGLE, saved AS INTEGER

    IF FIGHT_LAYOUT_OK = 0 THEN
        IF FightInit%("assets/data/ui-fight-layout.txt") = 0 THEN RunFight% = OUT_FLEE: EXIT FUNCTION
    END IF

    SeedFight lvl, nfoes
    FightLog "", "You are set upon on " + _TRIM$(SECTORS(lvl).label) + "."
    PlayCue CombatCueName$(lvl, 0), TRUE      ' loops for the length of the fight
    tprev = TIMER
    outcome = 0

    DO
        _LIMIT 60
        AudioTick                       ' music crossfade + narration fade are frame-ticked

        '--- time ----------------------------------------------------------
        dt = TIMER - tprev
        tprev = TIMER
        ' TIMER wraps at midnight, which would otherwise hand FuseStep a huge negative dt and
        ' either freeze every fuse or fire them all at once.
        IF dt < 0 OR dt > 1 THEN dt = 0

        '--- the fuses advance WHETHER OR NOT THE PLAYER ACTED -------------
        a = FuseStep%(dt)
        DO WHILE a <> FUSE_NONE
            IF a > 0 THEN
                FightFoeAttack a, lvl, guarding
                guarding = 0                                   ' a guard covers one blow
                IF FA_ALIVE(a) THEN FuseArmFoe a, FightFoeTier%(((a - 1) MOD 3) + 1), lvl
            END IF
            a = FuseTakePending%
        LOOP

        '--- input ---------------------------------------------------------
        k = UCASE$(INKEY$)
        IF LEN(k) > 0 THEN
            nk = NormKey$(k)
            SELECT CASE nk
                CASE "A": TargetCycle -1
                CASE "D": TargetCycle 1
                CASE "W"
                    FMENU_SEL = FMENU_SEL - 1
                    IF FMENU_SEL < 1 THEN FMENU_SEL = FMENU_N
                CASE "S"
                    FMENU_SEL = FMENU_SEL + 1
                    IF FMENU_SEL > FMENU_N THEN FMENU_SEL = 1
            END SELECT
            IF k = CHR$(13) THEN
                SELECT CASE FMENU_SEL
                    CASE FACT_ATTACK
                        FA_STANCE(0) = STANCE_ATTACK
                        FightPlayerAttack
                        FIGHT_ROUND = FIGHT_ROUND + 1
                    CASE FACT_GUARD
                        guarding = -1
                        FA_STANCE(0) = STANCE_GUARD
                        FightSetStatus 0, 2, "STANCE:", "GUARDING"
                        FightLog "", "You raise your guard."
                        Sfx "select"
                    CASE FACT_CAST
                        FightLog "", "(spells come with Phase D)"
                    CASE FACT_USE
                        FightLog "", "(items come with Phase D)"
                    CASE FACT_FLOURISH
                        FA_STANCE(0) = STANCE_ATTACK
                        FightFlourish lvl
                        FIGHT_ROUND = FIGHT_ROUND + 1
                        ' A gesture takes real time, so foes may have fired during it. Resolve
                        ' those NOW rather than letting them pile up into the next frame.
                        a = FuseTakePending%
                        DO WHILE a <> FUSE_NONE
                            IF a > 0 THEN
                                FightFoeAttack a, lvl, guarding
                                guarding = 0
                                IF FA_ALIVE(a) THEN FuseArmFoe a, FightFoeTier%(((a - 1) MOD 3) + 1), lvl
                            END IF
                            a = FuseTakePending%
                        LOOP
                        tprev = TIMER                     ' do not bill the gesture as one frame
                    CASE FACT_SHOOT
                        FightShoot lvl
                        FIGHT_ROUND = FIGHT_ROUND + 1
                    CASE FACT_FLEE
                        outcome = OUT_FLEE
                END SELECT
            END IF
            IF k = CHR$(27) THEN outcome = OUT_FLEE
        END IF

        '--- status effects tick with the clock, like the fuses --------------
        IF FightTickStatus%(dt) THEN outcome = OUT_LOSE

        '--- end conditions ------------------------------------------------
        ' The death-save is offered ONCE, and only when something actually dropped the player --
        ' checked here rather than inside each damage path, so no source of damage can forget it.
        IF player_hp <= 0 AND saved = 0 THEN
            saved = -1
            IF FightDeathSave%(lvl) THEN tprev = TIMER
        END IF
        IF player_hp <= 0 THEN outcome = OUT_LOSE
        IF FightLiveFoes% = 0 THEN outcome = OUT_WIN

        '--- draw ----------------------------------------------------------
        FightSyncStatus
        IF guarding THEN FightSetStatus 0, 2, "STANCE:", "GUARDING"
        FightRender
        ' Health TIERS, visible rather than merely named: the same blood + vignette the board uses,
        ' so "NEAR DEATH" is felt at a glance instead of read off a row. Drawn after the screen and
        ' before the flip, matching the board's board -> blood -> text order.
        FightBeginDraw
        DrawWounds
        FightEndDraw
        _DISPLAY
    LOOP UNTIL outcome <> 0

    '--- outro ---------------------------------------------------------------
    SELECT CASE outcome
        CASE OUT_WIN
            FIGHT_BANNER = "THE WAY IS CLEAR": Sfx "win"
        CASE OUT_LOSE
            FIGHT_BANNER = "YOU FALL": Sfx "death"
        CASE ELSE
            FIGHT_BANNER = "YOU BREAK AWAY": Sfx "miss"
    END SELECT
    FightSyncStatus
    FightRender
    _DISPLAY
    ' Hold the result on screen long enough to read, but let a keypress skip it.
    banner_t = TIMER
    DO
        _LIMIT 60
        AudioTick
        IF LEN(INKEY$) > 0 THEN EXIT DO
        IF TIMER - banner_t > 2.5 OR TIMER - banner_t < 0 THEN EXIT DO
    LOOP

    EndCue
    StatusClearAll        ' effects must not survive the encounter
    FightFreeTiles                      ' drop the portrait cache; the next fight re-renders
    RunFight% = outcome
END FUNCTION
