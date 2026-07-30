' ============================================================================
'  TABLE.bas -- ENGINE random-table primitives (game-agnostic).
'
'  Weighted selection is the shape almost every content table in this game wants:
'  pick one curio / chamber event / item / monster, where some entries are rarer than
'  others and some only apply at certain depths. It was written out by hand each time
'  (accumulate the total, roll, walk the list subtracting) -- once in DoCurio, and the
'  item deck faked it with slot positions, which quantised the odds to 0/33/66/100%
'  and silently starved three levels of gold treasure.
'
'  These are the reusable pieces. They take PARALLEL ARRAYS rather than a row TYPE, so
'  any caller's own record layout works -- copy the weight column in and go. That also
'  keeps the door open for the planned scripting layer: a script-defined table only has
'  to produce a weight array to use the same selection logic the built-in tables use.
'
'  All of these are SILENT -- they use RollDie (a bare RND), never GameRoll, so no dice
'  animation or Real-Dice prompt fires for an internal content roll.
' ============================================================================

' TRUE `pct` percent of the time. pct <= 0 never fires, pct >= 100 always does.
' (Replaces the `IF RollDie(100) <= X` idiom repeated across the game.)
FUNCTION PctChance% (pct AS INTEGER)
    IF pct <= 0 THEN PctChance% = 0: EXIT FUNCTION
    IF pct >= 100 THEN PctChance% = -1: EXIT FUNCTION
    IF RollDie(100) <= pct THEN PctChance% = -1 ELSE PctChance% = 0
END FUNCTION

' Pick an index 1..n from w(), proportional to weight. Returns 0 when nothing is
' eligible (n < 1, or every weight <= 0) -- callers MUST handle 0 rather than
' assuming a pick, or they index w(0).
FUNCTION WeightPick% (w() AS INTEGER, n AS INTEGER)
    DIM i AS INTEGER, tot AS INTEGER, r AS INTEGER
    WeightPick% = 0
    IF n < 1 THEN EXIT FUNCTION
    FOR i = 1 TO n
        IF w(i) > 0 THEN tot = tot + w(i)
    NEXT i
    IF tot <= 0 THEN EXIT FUNCTION
    r = RollDie(tot)
    FOR i = 1 TO n
        IF w(i) > 0 THEN
            r = r - w(i)
            IF r <= 0 THEN WeightPick% = i: EXIT FUNCTION
        END IF
    NEXT i
    WeightPick% = n                       ' unreachable unless weights changed mid-loop
END FUNCTION

' As WeightPick%, but an entry only competes when lvl falls inside its [lo,hi] depth
' band. A hi of 0 means "no upper bound", so a table can say "level 3 and deeper"
' without knowing how many levels the game has. Returns 0 if nothing is eligible at
' this depth -- a normal outcome, not an error.
FUNCTION WeightPickLvl% (w() AS INTEGER, lo() AS INTEGER, hi() AS INTEGER, n AS INTEGER, lvl AS INTEGER)
    DIM i AS INTEGER, tot AS INTEGER, r AS INTEGER
    WeightPickLvl% = 0
    IF n < 1 THEN EXIT FUNCTION
    FOR i = 1 TO n
        IF LvlOk%(lo(i), hi(i), lvl) THEN
            IF w(i) > 0 THEN tot = tot + w(i)
        END IF
    NEXT i
    IF tot <= 0 THEN EXIT FUNCTION
    r = RollDie(tot)
    FOR i = 1 TO n
        IF LvlOk%(lo(i), hi(i), lvl) THEN
            IF w(i) > 0 THEN
                r = r - w(i)
                IF r <= 0 THEN WeightPickLvl% = i: EXIT FUNCTION
            END IF
        END IF
    NEXT i
END FUNCTION

' Is `lvl` inside the depth band [lo, hi]? lo <= 0 = no lower bound, hi <= 0 = no upper.
' Split out so the two-pass WeightPickLvl% applies exactly the same test both times --
' the classic way a weighted walk desyncs is the passes disagreeing on eligibility.
FUNCTION LvlOk% (lo AS INTEGER, hi AS INTEGER, lvl AS INTEGER)
    LvlOk% = 0
    IF lo > 0 AND lvl < lo THEN EXIT FUNCTION
    IF hi > 0 AND lvl > hi THEN EXIT FUNCTION
    LvlOk% = -1
END FUNCTION
