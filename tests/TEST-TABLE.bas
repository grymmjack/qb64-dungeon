$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/TABLE.bas -- the weighted random-table primitives.
'
'  These are RANDOM, so the assertions test the two things that must hold on every
'  draw rather than the distribution: (a) the result is always an ELIGIBLE index --
'  never 0 when something is eligible, never an entry whose weight is 0 or whose
'  depth band excludes it; (b) 0 comes back exactly when nothing is eligible.
'  A desynced weighted walk (the two passes disagreeing about eligibility) shows up
'  as an ineligible pick, which many draws will catch.
'
'  Distribution is then sanity-checked loosely -- a 90/10 split must not come out
'  reversed -- with bounds wide enough not to flake.
' ============================================================================

T_Begin "engine/TABLE.bas"
RANDOMIZE 424242                              ' deterministic run

DIM i AS INTEGER, k AS INTEGER, bad AS INTEGER
REDIM w(1 TO 8) AS INTEGER, lo(1 TO 8) AS INTEGER, hi(1 TO 8) AS INTEGER

T_Group "PctChance%"
T_False "0% never fires", PctChance%(0)
T_False "negative never fires", PctChance%(-5)
T_True "100% always fires", PctChance%(100)
T_True "over 100 always fires", PctChance%(150)
bad = 0
FOR i = 1 TO 400
    IF PctChance%(0) THEN bad = -1
    IF NOT PctChance%(100) THEN bad = -1
NEXT i
T_False "the extremes hold over 400 draws", bad
k = 0
FOR i = 1 TO 2000: IF PctChance%(50) THEN k = k + 1
NEXT i
T_True "50% lands between 40% and 60% (got " + _TRIM$(STR$(k * 100 \ 2000)) + "%)", k > 800 AND k < 1200

T_Group "WeightPick% -- degenerate cases return 0, never a bogus index"
w(1) = 5
T_EqI "n = 0 -> 0", WeightPick%(w(), 0), 0
T_EqI "n negative -> 0", WeightPick%(w(), -3), 0
FOR i = 1 TO 4: w(i) = 0: NEXT i
T_EqI "all weights zero -> 0", WeightPick%(w(), 4), 0

T_Group "WeightPick% -- only ever returns an eligible index"
FOR i = 1 TO 5: w(i) = 0: NEXT i
w(2) = 7: w(4) = 3                            ' only 2 and 4 are eligible
bad = 0
FOR i = 1 TO 500
    k = WeightPick%(w(), 5)
    IF k <> 2 AND k <> 4 THEN bad = -1
NEXT i
T_False "500 draws never picked a zero-weight entry", bad

FOR i = 1 TO 3: w(i) = 1: NEXT i
bad = 0
FOR i = 1 TO 300
    k = WeightPick%(w(), 3)
    IF k < 1 OR k > 3 THEN bad = -1
NEXT i
T_False "equal weights stay in range", bad

T_Group "WeightPick% -- a single eligible entry is always the answer"
FOR i = 1 TO 6: w(i) = 0: NEXT i
w(5) = 1
bad = 0
FOR i = 1 TO 200: IF WeightPick%(w(), 6) <> 5 THEN bad = -1
NEXT i
T_False "lone entry always chosen", bad

T_Group "WeightPick% -- heavy weight dominates (not reversed)"
FOR i = 1 TO 2: w(i) = 0: NEXT i
w(1) = 90: w(2) = 10
k = 0
FOR i = 1 TO 1000: IF WeightPick%(w(), 2) = 1 THEN k = k + 1
NEXT i
T_True "90/10 picks #1 most of the time (got " + _TRIM$(STR$(k * 100 \ 1000)) + "%)", k > 800

T_Group "LvlOk% -- depth bands (0 = unbounded)"
T_True "no bounds accepts anything", LvlOk%(0, 0, 5)
T_True "at the lower bound", LvlOk%(3, 0, 3)
T_False "below the lower bound", LvlOk%(3, 0, 2)
T_True "at the upper bound", LvlOk%(0, 6, 6)
T_False "above the upper bound", LvlOk%(0, 6, 7)
T_True "inside a closed band", LvlOk%(3, 6, 4)
T_False "outside a closed band", LvlOk%(3, 6, 9)
T_True "single-level band", LvlOk%(4, 4, 4)
T_False "single-level band excludes others", LvlOk%(4, 4, 5)
T_True "hi 0 means 'and deeper'", LvlOk%(7, 0, 99)

T_Group "WeightPickLvl% -- respects the depth band"
FOR i = 1 TO 4: w(i) = 10: lo(i) = 0: hi(i) = 0: NEXT i
lo(1) = 1: hi(1) = 2                          ' shallow only
lo(2) = 5: hi(2) = 0                          ' deep and below
lo(3) = 3: hi(3) = 3                          ' exactly 3
w(4) = 0                                      ' eligible at any depth but weightless
bad = 0
FOR i = 1 TO 400: IF WeightPickLvl%(w(), lo(), hi(), 4, 1) <> 1 THEN bad = -1
NEXT i
T_False "at level 1 only the shallow entry can win", bad
bad = 0
FOR i = 1 TO 400: IF WeightPickLvl%(w(), lo(), hi(), 4, 3) <> 3 THEN bad = -1
NEXT i
T_False "at level 3 only the exact-3 entry can win", bad
bad = 0
FOR i = 1 TO 400: IF WeightPickLvl%(w(), lo(), hi(), 4, 9) <> 2 THEN bad = -1
NEXT i
T_False "at level 9 only the deep entry can win", bad
T_EqI "a depth with nothing eligible -> 0", WeightPickLvl%(w(), lo(), hi(), 4, 4), 0

T_Group "WeightPickLvl% -- zero-weight entries never win even when in band"
FOR i = 1 TO 3: w(i) = 0: lo(i) = 0: hi(i) = 0: NEXT i
w(2) = 5
bad = 0
FOR i = 1 TO 300: IF WeightPickLvl%(w(), lo(), hi(), 3, 5) <> 2 THEN bad = -1
NEXT i
T_False "only the weighted in-band entry wins", bad

T_Done

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/TABLE.bas'

' RollDie lives in engine/UI.bas, which would drag the whole dice/audio stack into a
' table-selection test. TABLE.bas only needs the silent RND form, so stub it.
FUNCTION RollDie% (sides AS INTEGER)
    RollDie = INT(RND * sides) + 1
END FUNCTION
