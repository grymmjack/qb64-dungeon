$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/GAUGE.bas -- the composure gesture model.
'
'  The whole reason the math was split out of greywood's draw+poll loop is that it
'  becomes testable with NO display. So this suite does not check "does the bar look
'  right" -- it checks the DESIGN PRINCIPLES from greywood/gesture-combat-design.md
'  as properties, which is the only way they stay true after future tuning:
'
'    #1 one model, two presentations -- the sampled twin must use the same math,
'       so its outcomes must obey the same bounds and its odds must track zone area.
'    #2 stats compress the RANGE, they do not shift it -- a low-skill actor's zones
'       must be strictly TIGHTER (low ceiling), a high-skill actor's strictly WIDER
'       (high floor). This is the assertion that matters most: it is easy to
'       accidentally write "skill shifts the odds" instead, and no play-test would
'       obviously reveal it.
'    #3 WYSIWYG -- the zone must always be fully ON the bar, or its outer edge would
'       score somewhere the renderer cannot draw.
'
'  Being random, the statistical assertions use wide bands so they cannot flake;
'  they are checking ORDERING and BOUNDS, not exact rates.
' ============================================================================

T_Begin "engine/GAUGE.bas"
RANDOMIZE 8675309                              ' deterministic run

DIM k AS GAUGEK, lo AS GAUGEK, hi AS GAUGEK
DIM i AS INTEGER, z AS INTEGER, bad AS INTEGER, n AS LONG
DIM q AS SINGLE
DIM crits AS LONG, hits AS LONG, misses AS LONG

'--- a healthy mid-skill actor at depth 1 -------------------------------------
SUB FreshK (kk AS GAUGEK, sk AS INTEGER, dep AS INTEGER)
    kk.skill = sk: kk.depth = dep: kk.press = 0: kk.wobble = 0
    kk.hp = 20: kk.maxhp = 20: kk.will = 3: kk.willmax = 3
    GaugeKnobs kk
END SUB

T_Group "GaugeKnobs -- principle #2: skill sets the BAND"
FreshK lo, 0, 1
FreshK k, 1, 1
FreshK hi, 2, 1
T_True "low skill crit is tighter than mid", lo.crit < k.crit
T_True "mid skill crit is tighter than high", k.crit < hi.crit
T_True "low skill hit is tighter than high", lo.hit < hi.hit
T_True "high skill sweeps SLOWER (easier to read)", hi.speed < lo.speed
T_True "high skill roams less", hi.wander <= lo.wander
T_True "high skill regrows more window per willpower", hi.wprestore > lo.wprestore
T_True "hit band is always wider than crit (low)", lo.hit > lo.crit
T_True "hit band is always wider than crit (high)", hi.hit > hi.crit

T_Group "GaugeKnobs -- depth and crowd both squeeze, with a floor"
FreshK k, 1, 1
FreshK lo, 1, 9
T_True "depth 9 crit is tighter than depth 1", lo.crit < k.crit
T_True "depth 9 sweeps faster", lo.speed > k.speed
FreshK k, 1, 5
hi = k
hi.press = 3: GaugeKnobs hi
T_True "3 extra foes tighten the crit (the 1-vs-4 squeeze)", hi.crit < k.crit
T_True "3 extra foes speed the sweep", hi.speed > k.speed
' the floor exists so perfect play is never impossible -- "variance must be skill-reducible"
FreshK lo, 0, 9
lo.press = 3: GaugeKnobs lo
T_True "worst case still leaves a real crit window", lo.crit >= 0.012
T_True "worst case keeps hit wider than crit", lo.hit > lo.crit

T_Group "GaugeHpFrac! -- guards a malformed actor"
FreshK k, 1, 1
k.maxhp = 0: T_EqI "maxhp 0 reads as FULL, not divide-by-zero", INT(GaugeHpFrac!(k) * 100), 100
k.maxhp = 20: k.hp = 0: T_EqI "hp 0 reads as empty", INT(GaugeHpFrac!(k) * 100), 0
k.hp = 30: T_EqI "hp above max clamps to full", INT(GaugeHpFrac!(k) * 100), 100
k.hp = 10: T_EqI "half hp", INT(GaugeHpFrac!(k) * 100), 50

T_Group "GaugeStep -- principle #3: the zone stays ON the bar"
FreshK k, 0, 9                                 ' worst case: widest roam + tremble
k.hp = 2                                       ' near death -> max panic/tremble
GaugeBegin k
bad = 0
FOR i = 1 TO 3000
    GaugeStep k
    IF k.p < 0 OR k.p > 1 THEN bad = -1
    IF k.zc - k.ehit < 0 THEN bad = -1
    IF k.zc + k.ehit > 1 THEN bad = -1
    IF k.ecrit > k.ehit THEN bad = -1
NEXT i
T_False "3000 frames: marker in range, zone fully on the bar, crit inside hit", bad

T_Group "GaugeStep -- low HP shrinks the window (composure lost)"
FreshK k, 1, 1
k.hp = 20: GaugeBegin k: GaugeStep k
DIM healthyCrit AS SINGLE: healthyCrit = k.ecrit
FreshK k, 1, 1
k.hp = 2: GaugeBegin k: GaugeStep k
T_True "wounded crit window is smaller than healthy", k.ecrit < healthyCrit

T_Group "GaugeSteady% -- willpower is finite and regrows the window"
FreshK k, 1, 1
k.hp = 4: k.will = 2: GaugeBegin k: GaugeStep k
DIM shookCrit AS SINGLE: shookCrit = k.ecrit
T_True "first press spends", GaugeSteady%(k)
T_EqI "  will decremented", k.will, 1
T_True "second press spends", GaugeSteady%(k)
T_EqI "  will exhausted", k.will, 0
T_False "third press refused at 0 will", GaugeSteady%(k)
GaugeStep k
T_True "steadying regrew the crit window", k.ecrit > shookCrit

T_Group "GaugeScore% -- zones score by distance from centre"
FreshK k, 1, 1
GaugeBegin k: GaugeStep k
k.zc = 0.5: k.ecrit = 0.05: k.ehit = 0.2
k.p = 0.5: T_EqI "dead centre = crit", GaugeScore%(k, q), 2
T_EqI "  dead centre quality is max", INT(q * 100), 100
k.p = 0.5 + 0.04: T_EqI "inside crit band = crit", GaugeScore%(k, q), 2
k.p = 0.5 + 0.10: T_EqI "between crit and hit = hit", GaugeScore%(k, q), 1
k.p = 0.5 - 0.10: T_EqI "hit band is symmetric", GaugeScore%(k, q), 1
k.p = 0.5 + 0.30: T_EqI "outside hit = miss", GaugeScore%(k, q), 0
T_EqI "  miss quality is 0", INT(q * 100), 0
k.p = 0.5 + 0.199: T_EqI "just inside the hit edge still hits", GaugeScore%(k, q), 1

T_Group "GaugeScore% -- the composure loop: clutch crit refills willpower"
FreshK k, 1, 1
k.hp = 2: k.will = 0: k.willmax = 3                  ' vulnerable and out of composure
GaugeBegin k: GaugeStep k
k.zc = 0.5: k.ecrit = 0.05: k.ehit = 0.2: k.p = 0.5
T_EqI "crit while trembling", GaugeScore%(k, q), 2
T_EqI "  willpower bank refilled to max", k.will, 3
T_True "  clutch flagged for the renderer", k.clutch
FreshK k, 1, 1
k.hp = 20: k.will = 0: k.willmax = 3                 ' healthy: not vulnerable
GaugeBegin k: GaugeStep k
k.zc = 0.5: k.ecrit = 0.05: k.ehit = 0.2: k.p = 0.5
T_EqI "crit while healthy", GaugeScore%(k, q), 2
T_EqI "  no refill when not vulnerable", k.will, 0

T_Group "GaugeSample% -- principle #1: the sampled twin obeys the same bounds"
FreshK k, 1, 5
bad = 0
FOR i = 1 TO 4000
    z = GaugeSample%(k, q)
    IF z < 0 OR z > 2 THEN bad = -1
    IF q < 0 OR q > 1 THEN bad = -1
    IF z = 0 AND q <> 0 THEN bad = -1
NEXT i
T_False "4000 samples: zone in 0..2, quality in 0..1, a miss has 0 quality", bad

T_Group "GaugeSample% -- odds track the BAND, so skill raises the floor"
n = 3000
crits = 0: hits = 0: misses = 0
FreshK lo, 0, 5
FOR i = 1 TO n
    z = GaugeSample%(lo, q)
    IF z = 2 THEN crits = crits + 1
    IF z = 1 THEN hits = hits + 1
    IF z = 0 THEN misses = misses + 1
NEXT i
DIM loLand AS LONG: loLand = crits + hits
DIM loCrit AS LONG: loCrit = crits
crits = 0: hits = 0: misses = 0
FreshK hi, 2, 5
FOR i = 1 TO n
    z = GaugeSample%(hi, q)
    IF z = 2 THEN crits = crits + 1
    IF z = 1 THEN hits = hits + 1
    IF z = 0 THEN misses = misses + 1
NEXT i
T_True "high skill lands more often than low (" + _TRIM$(STR$(loLand * 100 \ n)) + "% -> " + _TRIM$(STR$((crits + hits) * 100 \ n)) + "%)", (crits + hits) > loLand
T_True "high skill crits more often than low (" + _TRIM$(STR$(loCrit * 100 \ n)) + "% -> " + _TRIM$(STR$(crits * 100 \ n)) + "%)", crits > loCrit
T_True "even high skill still misses sometimes (no free win)", misses > 0
T_True "even low skill sometimes lands (no dead end)", loLand > 0

T_Group "GaugeSample% -- a closed crit window can never crit"
FreshK k, 1, 1
GaugeBegin k
k.crit = 0: k.hit = 0.2
bad = 0
FOR i = 1 TO 500
    GaugeBegin k
    GaugeStep k
    k.ecrit = 0: k.ehit = 0.2                  ' force it after Step, which would rescale
    IF GaugeScore%(k, q) = 2 THEN bad = -1
NEXT i
T_False "zero-width crit never scores a crit", bad

T_Group "GaugeDamage& -- the shared seam"
T_EqI "a miss deals nothing", GaugeDamage&(5, 0, 1), 0
T_EqI "a hit scales with strength", GaugeDamage&(5, 1, 0), 7
T_EqI "a crit roughly doubles a hit", GaugeDamage&(5, 2, 0), 18
T_True "a crit always beats a hit at equal quality", GaugeDamage&(5, 2, 0.5) > GaugeDamage&(5, 1, 0.5)
T_True "quality adds damage within a zone", GaugeDamage&(5, 1, 1) > GaugeDamage&(5, 1, 0)
T_EqI "strength 0 still deals a hit", GaugeDamage&(0, 1, 0), 2
T_True "more strength = more damage", GaugeDamage&(9, 1, 0) > GaugeDamage&(3, 1, 0)

T_Group "the OPT-IN GAMBLE: baseline vs gesture must not be dominated either way"
' The relation that has to hold:  blind gesture play  <  baseline  <  well-played gesture.
' A tuning change to zone widths or the damage curve can flip it with NO other symptom --
' the gesture silently becomes either a free upgrade or a trap, and only long play reveals it.
DIM baseDmg AS LONG, blindEV AS SINGLE, critDmg AS LONG
baseDmg = GaugeBaselineDamage&(5)
T_True "the baseline always deals damage (never a whiff -- that is the point)", baseDmg > 0
T_EqI "  a plain attack is a mid-quality HIT, not a crit", baseDmg, GaugeDamage&(5, 1, GAUGE_BASE_Q)
T_True "  and it is strictly worse than a crit", baseDmg < GaugeDamage&(5, 2, 0)
critDmg = GaugeDamage&(5, 2, 1)
T_True "a well-played crit pays MEANINGFULLY more (>1.5x baseline), so the gamble is worth taking", critDmg > baseDmg * 1.5

FreshK k, 1, 5                                 ' average skill, mid depth
blindEV = GaugeBlindEV!(k, 5, 4000)
T_True "blind gesture play (EV " + _TRIM$(STR$(INT(blindEV * 10) / 10)) + ") is WORSE than the baseline (" + _TRIM$(STR$(baseDmg)) + ")", blindEV < baseDmg
T_True "  but not worthless -- it still lands sometimes", blindEV > 0
' Skill must move that EV, or the gesture is a coin-flip dressed as a skill check.
FreshK lo, 0, 5
FreshK hi, 2, 5
T_True "high skill blind-EV beats low skill blind-EV", GaugeBlindEV!(hi, 5, 3000) > GaugeBlindEV!(lo, 5, 3000)
' Even at the TOP tier, blind play must not beat the baseline -- otherwise a high-level player
' could opt in mindlessly and never lose anything by ignoring the bar.
T_True "even top-tier BLIND play stays under the baseline", GaugeBlindEV!(hi, 5, 4000) < baseDmg

T_Group "GaugeOutOfSweeps% -- low skill gets a limited read"
FreshK lo, 0, 1
T_EqI "low skill gets 2 sweeps", lo.maxsweeps, 2
FreshK hi, 2, 1
T_EqI "high skill is unbounded (0 = only the fuse)", hi.maxsweeps, 0
GaugeBegin hi
hi.sweeps = 99
T_False "unbounded never runs out of sweeps", GaugeOutOfSweeps%(hi)
GaugeBegin lo
lo.sweeps = 0: T_False "fresh attempt has sweeps left", GaugeOutOfSweeps%(lo)
lo.sweeps = 2: T_True "used its budget", GaugeOutOfSweeps%(lo)

T_Done

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/GAUGE.bas'
