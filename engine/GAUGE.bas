' ============================================================================
'  GAUGE.bas -- ENGINE composure gauge: the gesture model (game-agnostic).
'
'  Vendored from ~/git/qb64pe-lab/greywood (greywood.bas GestureLock%/SkillParams/
'  ResolveDamage&), whose design bible is greywood/gesture-combat-design.md. That
'  prototype is a PLAYTESTED implementation -- the constants below are its tuned
'  values, not guesses, so change them only with a playtest behind you.
'  See plans/TACTICAL-COMBAT.md for the build order and the decisions taken.
'
'  WHAT IT IS: a marker sweeps a bar on a sine; committing scores a zone --
'  2 crit (dead centre), 1 hit, 0 miss. Everything about the bar is a readout of
'  the actor: skill sets the zone widths and sweep speed, low HP shrinks the
'  windows and makes the hands tremble, willpower buys some of it back.
'
'  WHY IT IS SPLIT THIS WAY (the important part):
'  greywood's GestureLock% interleaved the math with the drawing and the input
'  polling. Here the MATH is separated into pure steps with no display at all:
'
'      GaugeKnobs   actor  -> zone widths / speed / roam / restore
'      GaugeBegin   seed one attempt (random phase, per-attempt speed jitter)
'      GaugeStep    advance ONE frame -> marker p, zone centre, effective widths
'      GaugeScore   score the CURRENT frame -> zone + quality
'      GaugeSample  random phase + one Step + Score = the same math, sampled
'      GaugeDamage  (attacker stat, zone, quality) -> damage. The shared seam.
'
'  That makes the design bible's principle #1 -- "one model, two presentations;
'  the area each zone occupies IS its probability" -- STRUCTURAL rather than a
'  promise. The interactive front-end (Phase D) is a loop of Step + draw + poll
'  + Score; the auto-resolve front-end is GaugeSample. Neither can drift from
'  the other, because there is only one copy of the arithmetic.
'
'  It also makes the whole model unit-testable with no display -- see
'  tests/TEST-GAUGE.bas, which asserts principle #2 (stats compress the RANGE)
'  as a property rather than an intention.
'
'  WYSIWYG IS SACRED (principle #3): a renderer must draw the zone using the
'  SAME k.zc / k.ecrit / k.ehit this module computed for that frame. Never
'  recompute or nudge them for display.
' ============================================================================

' Fill the derived knobs from the actor's condition. Called once per attempt,
' before GaugeBegin.
'
'   skill  0..2   the FELT stat. Higher = wider crit, wider hit, SLOWER bar,
'                 steadier sweep, and more window regrowth per willpower.
'   depth  1..9   deeper narrows the windows and quickens the sweep.
'   press  0..3   engaged enemies beyond the first. THIS is what makes 1-vs-4
'                 mechanically tenser than a duel rather than merely longer:
'                 more foes = faster sweep and a tighter crit.
SUB GaugeKnobs (k AS GAUGEK)
    DIM df AS SINGLE, pf AS SINGLE
    SELECT CASE k.skill
        CASE IS <= 0
            k.crit = 0.035: k.hit = 0.17: k.speed = 0.085: k.jitter = 0.55
            k.wander = 0.22: k.wprestore = 0.35: k.maxsweeps = 2
        CASE 1
            k.crit = 0.055: k.hit = 0.2: k.speed = 0.055: k.jitter = 0.28
            k.wander = 0.1: k.wprestore = 0.55: k.maxsweeps = 4
        CASE ELSE
            k.crit = 0.075: k.hit = 0.24: k.speed = 0.034: k.jitter = 0.05
            k.wander = 0: k.wprestore = 0.85: k.maxsweeps = 0      ' 0 = only the fuse bounds you
    END SELECT
    ' depth + crowd pressure. Both SHRINK the windows and SPEED the sweep, but the
    ' floors below matter: a zone can never close entirely, or perfect play would be
    ' impossible and the gesture would read as the game cheating (bible: "all variance
    ' must be visible and skill-reducible").
    df = (k.depth - 1) / 8: IF df < 0 THEN df = 0
    IF df > 1 THEN df = 1
    pf = k.press / 3: IF pf < 0 THEN pf = 0
    IF pf > 1 THEN pf = 1
    k.crit = k.crit * (1 - 0.35 * df) * (1 - 0.2 * pf)
    k.hit = k.hit * (1 - 0.25 * df) * (1 - 0.15 * pf)
    k.speed = k.speed * (1 + 0.35 * df + 0.3 * pf)
    IF k.crit < 0.012 THEN k.crit = 0.012        ' floor: always a real, if tiny, sweet spot
    IF k.hit < k.crit * 1.6 THEN k.hit = k.crit * 1.6   ' hit must stay wider than crit
END SUB

' Seed ONE attempt. Random start phase + a per-attempt speed jitter, which is the
' anti-rote pair: no metronome to memorise, and no fixed tempo to learn.
SUB GaugeBegin (k AS GAUGEK)
    DIM hpf AS SINGLE, ej AS SINGLE
    hpf = GaugeHpFrac!(k)
    k.phase = RND * 6.28318
    k.phase0 = k.phase
    k.wphase = RND * 6.28318
    k.sphase = RND * 6.28318
    k.steady = 0: k.focus = 0: k.jitoff = 0: k.frame = 0: k.sweeps = 0
    ' tempo raggedness: skill sets the base, being wounded makes it erratic, and any
    ' extra wobble (drink, etc.) loosens it further. You cannot will a ragged tempo
    ' away once the swing is underway -- grit is not training.
    ej = k.jitter + (1 - hpf) * 0.4 + k.wobble * 0.1
    IF ej > 0.95 THEN ej = 0.95
    k.swspeed = k.speed * (1 + (RND * 2 - 1) * ej)
    IF k.swspeed < 0.012 THEN k.swspeed = 0.012
    ' wounded hands tremble below half HP, worse near death
    k.shake = 0
    IF hpf < 0.5 THEN k.shake = 0.09 * (1 - hpf / 0.5)
    k.wspeed = 0.025 + (1 - hpf) * 0.025
END SUB

' Advance ONE frame of the model. Writes the three things a renderer needs and a
' scorer reads: k.p (marker), k.zc (zone centre), k.ecrit / k.ehit (widths).
SUB GaugeStep (k AS GAUGEK)
    DIM hpf AS SINGLE, wamp AS SINGLE, drift AS SINGLE, eshake AS SINGLE
    DIM panic AS SINGLE, shrink AS SINGLE, zmul AS SINGLE, margin AS SINGLE
    hpf = GaugeHpFrac!(k)
    k.frame = k.frame + 1
    ' willpower decays: steadiness bleeds off and the focus-slow eases back, so the
    ' player must keep spending WHILE aiming rather than banking it up front.
    k.steady = k.steady - 0.04: IF k.steady < 0 THEN k.steady = 0
    k.focus = k.focus - 0.018: IF k.focus < 0 THEN k.focus = 0

    k.phase = k.phase + k.swspeed * (1 - 0.55 * k.focus)   ' focus SLOWS the sweep
    k.p = (SIN(k.phase) + 1) / 2
    k.sweeps = INT((k.phase - k.phase0) / 6.28318)
    k.wphase = k.wphase + k.wspeed
    k.sphase = k.sphase + 0.4

    ' The sweet spot ROAMS (kills spatial memorisation). Skill sets the base wander;
    ' being wounded adds panic-roam -- and the panic part is exactly what willpower calms.
    wamp = k.wander + (1 - hpf) * 0.1 * (1 - k.steady) + k.wobble * 0.04
    drift = 0.5 + wamp * SIN(k.wphase)
    eshake = k.shake * (1 - k.steady)                       ' willpower damps the tremble
    panic = (1 - hpf) * 0.022 * (1 - k.steady)
    IF k.frame MOD 4 = 0 THEN k.jitoff = (RND * 2 - 1) * panic
    k.zc = drift + eshake * SIN(k.sphase) + k.jitoff

    ' Zone SIZE: low HP shrinks the windows (composure lost); willpower regrows them
    ' toward baseline, and MORE so at high skill -- so composure pays off in proportion
    ' to training. This is the bible's composure loop.
    shrink = (1 - hpf) * 0.4
    zmul = (1 - shrink) + k.steady * k.wprestore
    IF zmul > 1 THEN zmul = 1
    IF zmul < 0.4 THEN zmul = 0.4
    k.ecrit = k.crit * zmul
    k.ehit = k.hit * zmul
    ' keep the whole zone on the bar, or its outer edge would score off-screen
    margin = k.ehit + 0.04
    IF k.zc < margin THEN k.zc = margin
    IF k.zc > 1 - margin THEN k.zc = 1 - margin
END SUB

' Spend one willpower press: calms the tremble/roam, slows the sweep for about a
' second, and regrows the shrunken windows. Returns TRUE if a press was actually
' spent (the caller should only play the sound/flash when it was).
FUNCTION GaugeSteady% (k AS GAUGEK)
    GaugeSteady% = 0
    IF k.will <= 0 THEN EXIT FUNCTION
    k.will = k.will - 1
    k.steady = k.steady + 0.45: IF k.steady > 1 THEN k.steady = 1
    k.focus = 1
    GaugeSteady% = -1
END FUNCTION

' Score the CURRENT frame. Returns 2 crit / 1 hit / 0 miss, and sets q to how
' close to dead-centre the commit was (0..1) so callers can reward precision.
'
' A crit landed WHILE VULNERABLE (hands trembling) refills the willpower bank --
' the composure loop: clutch under pressure and your poise compounds; fail and you
' stay shook. Comeback and collapse both emerge here with zero narration.
FUNCTION GaugeScore% (k AS GAUGEK, q AS SINGLE)
    DIM d AS SINGLE
    d = ABS(k.p - k.zc)
    IF d <= k.ecrit THEN
        q = 1 - (d / k.ecrit)
        IF k.shake > 0 THEN k.will = k.willmax: k.clutch = -1
        GaugeScore% = 2
    ELSEIF d <= k.ehit THEN
        IF k.ehit > k.ecrit THEN q = 1 - ((d - k.ecrit) / (k.ehit - k.ecrit)) ELSE q = 0
        GaugeScore% = 1
    ELSE
        q = 0
        GaugeScore% = 0
    END IF
END FUNCTION

' THE SAMPLED TWIN. Same model, no display, no input: seed an attempt, advance one
' frame from a random phase, score it. Used for enemy turns, the auto-resolve
' accessibility tier, and the safe baseline of the opt-in gamble.
'
' Note WHY this is faithful rather than merely similar: the marker's position is
' p = (SIN(phase)+1)/2, so drawing `phase` uniformly reproduces the marker's true
' arcsine distribution -- it dwells near the ENDS of the bar and races through the
' CENTRE. A centred zone is therefore genuinely harder to hit by luck than an
' off-centre one of equal width, and the sampler inherits that for free. Sampling
' `p` uniformly instead would have quietly made auto-resolve easier than playing.
FUNCTION GaugeSample% (k AS GAUGEK, q AS SINGLE)
    GaugeBegin k
    GaugeStep k
    GaugeSample% = GaugeScore%(k, q)
END FUNCTION

' The shared damage seam -- every presentation funnels through this, so the
' interactive gesture and the sampled resolve can never pay out differently.
FUNCTION GaugeDamage& (strength AS INTEGER, zone AS INTEGER, q AS SINGLE)
    SELECT CASE zone
        CASE 2: GaugeDamage& = (strength + 4) * 2 + INT(q * 4)
        CASE 1: GaugeDamage& = strength + 2 + INT(q * 4)
        CASE ELSE: GaugeDamage& = 0
    END SELECT
END FUNCTION

' HP as a 0..1 fraction, guarding a zero/absent maxhp (a fresh or malformed actor
' would otherwise divide by zero and read as full-panic).
FUNCTION GaugeHpFrac! (k AS GAUGEK)
    IF k.maxhp <= 0 THEN GaugeHpFrac! = 1: EXIT FUNCTION
    IF k.hp <= 0 THEN GaugeHpFrac! = 0: EXIT FUNCTION
    IF k.hp >= k.maxhp THEN GaugeHpFrac! = 1: EXIT FUNCTION
    GaugeHpFrac! = k.hp / k.maxhp
END FUNCTION

' Has the attempt run out of sweeps? Low skill gets only a couple of passes to read
' the bar; high skill is bounded only by the enemy's fuse. Willpower-slowing stretches
' each sweep's TIME but not the COUNT, so composure buys a longer look inside a fixed
' budget -- a clean interaction rather than a special case.
FUNCTION GaugeOutOfSweeps% (k AS GAUGEK)
    GaugeOutOfSweeps% = 0
    IF k.maxsweeps > 0 AND k.sweeps >= k.maxsweeps THEN GaugeOutOfSweeps% = -1
END FUNCTION

' ============================================================================
'  The OPT-IN GAMBLE seam.
'
'  A plain attack does NOT play the gesture: it resolves at a safe baseline -- a guaranteed
'  middling hit, never a crit and never a whiff. Playing the gesture is then a CHOICE with a
'  higher ceiling and a real fail tail.
'
'  The design constraint that matters is DOMINANCE: if the gesture paid more on average than
'  the baseline regardless of how well it was played, nobody would ever take the plain attack
'  and the "choice" would be a chore tax. So the invariant is:
'
'      blind gesture play  <  baseline  <  well-played gesture
'
'  The left half is testable directly -- GaugeSample% IS blind play (it draws a random phase
'  and scores wherever the marker happened to be), so its expected damage must come out BELOW
'  the baseline. The right half follows because a human can SEE the bar, so any skill above
'  random beats random. Together that makes the gesture a variance choice for someone who can
'  play it and a genuine cost for someone who cannot -- rather than a free upgrade.
'
'  tests/TEST-GAUGE.bas asserts both halves as properties, because a tuning change to the zone
'  widths or the damage curve can flip the relation with no other symptom.
' ============================================================================

' (GAUGE_BASE_Q lives in ENGINE.BI -- body files declare nothing at file scope.)

' Damage for a plain, no-gesture attack. Always a hit, never a crit, never zero -- that
' reliability is the entire reason to offer it.
FUNCTION GaugeBaselineDamage& (strength AS INTEGER)
    GaugeBaselineDamage& = GaugeDamage&(strength, 1, GAUGE_BASE_Q)
END FUNCTION

' Expected damage from BLIND gesture play at this actor's knobs, over `trials` samples.
' Used by the dominance assertion, and available to a difficulty/balance dump.
FUNCTION GaugeBlindEV! (k AS GAUGEK, strength AS INTEGER, trials AS INTEGER)
    DIM i AS INTEGER, z AS INTEGER, total AS LONG, q AS SINGLE, kk AS GAUGEK
    IF trials < 1 THEN EXIT FUNCTION
    kk = k
    FOR i = 1 TO trials
        z = GaugeSample%(kk, q)
        total = total + GaugeDamage&(strength, z, q)
    NEXT i
    GaugeBlindEV! = total / trials
END FUNCTION
