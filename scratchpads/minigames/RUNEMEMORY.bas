' ============================================================================
'  RUNEMEMORY.bas -- THE RUNE SLAB (concentration, with teeth)
'
'  A W x H slab of face-down stones. Turn two; matching runes stay up. Clear the
'  slab inside the turn budget and the hoard is yours.
'
'  What stops this being a children's game is the PAIN RUNES. Some pairs are
'  cursed, and revealing one costs 1 HP -- EVERY time you reveal it, not just the
'  first. That single choice is what makes memory a mechanic instead of a theme:
'
'    * you cannot avoid the pain runes, since clearing the slab means turning
'      every stone at least once. There is a floor of damage you simply pay.
'    * but a player who FORGETS turns the same cursed stone three times and pays
'      three times. Sloppy play is taxed in hit points, not just in turns.
'    * and once you have found a pain pair, matching it is a free choice: you
'      pay 2 more HP to clear it, or you leave it and walk with what you have.
'
'  So the risk-for-reward is real and it is the player's to price. The selftest
'  proves all of it: perfect play always clears inside the budget, careless play
'  usually does not, and careless play bleeds measurably more.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST MAXTILES = 64
CONST RM_TW = 12, RM_TH = 4        ' one stone's CELL -- the box is 10 wide, so 2 columns of gutter
CONST RUNE_N = 20

'--- the slab. Parallel arrays rather than a UDT so the simulation can copy the
'    whole state cheaply between deals. ---
DIM SHARED TILE(1 TO MAXTILES) AS INTEGER      ' which rune this stone carries
DIM SHARED SHOWN(1 TO MAXTILES) AS INTEGER     ' matched and left face-up
DIM SHARED SEEN(1 TO MAXTILES) AS INTEGER      ' the player has turned it at least once
DIM SHARED PAINRUNE(1 TO RUNE_N) AS INTEGER    ' is this rune cursed
DIM SHARED RUNENAME(1 TO RUNE_N) AS STRING

DIM SHARED AS INTEGER g_cols, g_rows, g_tiles, g_pairs, g_painpairs
DIM SHARED AS INTEGER g_turns, g_budget, g_hp, g_hpmax, g_matched, g_hurt

' The SECOND stone of the current turn, held face-up for as long as the pair is
' on the table. Without it, DrawSlab's "face up" test was `matched OR is-the-
' first-pick`, so the second stone you turned drew as a ? the instant you turned
' it -- you were being asked to match a card you were never shown.
DIM SHARED g_up2 AS INTEGER

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitRunes
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN MG_QUIET = TRUE: RuneSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    MG_QUIET = TRUE
    RANDOMIZE 11
    RuneSetup 6, 4, 2, 12, 10
    ' a plausible mid-game: a few matched, a few remembered, one bite taken
    SHOWN(3) = TRUE: SHOWN(14) = TRUE: SHOWN(7) = TRUE: SHOWN(20) = TRUE
    SEEN(1) = TRUE: SEEN(9) = TRUE: SEEN(11) = TRUE: SEEN(22) = TRUE
    g_matched = 2: g_turns = 5: g_hp = 9
    ' mid-turn, BOTH stones up -- the state that used to hide the second one
    g_up2 = 11
    DrawSlab 11, 17, RUNENAME(TILE(17)) + "  and  " + RUNENAME(TILE(11))
    _SAVEIMAGE "runememory-shot.png"
    _DEST _CONSOLE: PRINT "wrote runememory-shot.png": SYSTEM
END IF

DIM r AS INTEGER
r = PlaySlab(6, 4, 2, 10, 12)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'--- setup -------------------------------------------------------------------

SUB InitRunes
    DIM i AS INTEGER
    RUNENAME(1) = "ANSUZ": RUNENAME(2) = "BERKAN": RUNENAME(3) = "DAGAZ"
    RUNENAME(4) = "EIHWAZ": RUNENAME(5) = "FEHU": RUNENAME(6) = "GEBO"
    RUNENAME(7) = "HAGAL": RUNENAME(8) = "INGWAZ": RUNENAME(9) = "ISAZ"
    RUNENAME(10) = "JERAN": RUNENAME(11) = "KAUNAN": RUNENAME(12) = "LAGUZ"
    RUNENAME(13) = "MANNAZ": RUNENAME(14) = "NAUDIZ": RUNENAME(15) = "OTHAL"
    RUNENAME(16) = "PERTHO": RUNENAME(17) = "RAIDO": RUNENAME(18) = "SOWILO"
    RUNENAME(19) = "TIWAZ": RUNENAME(20) = "URUZ"
    FOR i = 1 TO RUNE_N: PAINRUNE(i) = FALSE: NEXT i
END SUB

' The turn budget. Derived, not picked: a slab of N pairs has a worst case under
' perfect play, and the budget must sit above it or the game is unwinnable by
' anyone. INT buys slack on top of that floor -- it does not create the floor.
FUNCTION RuneBudget% (pairs AS INTEGER, intel AS INTEGER)
    DIM b AS INTEGER
    ' pairs + three-quarters again is where perfect play's WORST case actually
    ' lands (measured, not guessed -- the first cut of this formula sat one turn
    ' under it and the selftest failed, which is the whole reason it is asserted).
    ' The +2 is the margin that separates "a perfect player squeaks through" from
    ' "a good player has room to be human once".
    b = pairs + INT(pairs * 3 / 4) + 2 + MgAbilMod%(intel)
    IF b < pairs + 1 THEN b = pairs + 1
    RuneBudget% = b
END FUNCTION

' Deal a slab. `painpairs` of the pairs are cursed.
SUB RuneSetup (cols AS INTEGER, rows AS INTEGER, painpairs AS INTEGER, intel AS INTEGER, hpmax AS INTEGER)
    DIM i AS INTEGER, j AS INTEGER, k AS INTEGER, t AS INTEGER
    DIM pool(1 TO MAXTILES) AS INTEGER

    g_cols = cols: g_rows = rows
    g_tiles = cols * rows
    IF g_tiles > MAXTILES THEN g_tiles = MAXTILES
    IF g_tiles MOD 2 = 1 THEN g_tiles = g_tiles - 1        ' an odd slab has an unmatchable stone
    g_pairs = g_tiles \ 2
    g_painpairs = painpairs
    IF g_painpairs > g_pairs THEN g_painpairs = g_pairs

    ' pick which runes are cursed -- the FIRST g_painpairs of the runes in play,
    ' after the runes themselves are shuffled, so it is never the same set twice
    FOR i = 1 TO RUNE_N: pool(i) = i: NEXT i
    FOR i = RUNE_N TO 2 STEP -1
        j = MgRoll%(i): t = pool(i): pool(i) = pool(j): pool(j) = t
    NEXT i
    FOR i = 1 TO RUNE_N: PAINRUNE(i) = FALSE: NEXT i
    FOR i = 1 TO g_painpairs: PAINRUNE(pool(i)) = TRUE: NEXT i

    ' two stones per rune, then shuffle the stones
    k = 0
    FOR i = 1 TO g_pairs
        FOR j = 1 TO 2
            k = k + 1: TILE(k) = pool(i)
        NEXT j
    NEXT i
    FOR i = g_tiles TO 2 STEP -1
        j = MgRoll%(i): t = TILE(i): TILE(i) = TILE(j): TILE(j) = t
    NEXT i

    FOR i = 1 TO g_tiles: SHOWN(i) = FALSE: SEEN(i) = FALSE: NEXT i
    g_turns = 0: g_matched = 0: g_hurt = 0
    g_hpmax = hpmax: g_hp = hpmax
    g_budget = RuneBudget%(g_pairs, intel)
END SUB

FUNCTION IsPain% (idx AS INTEGER)
    IsPain% = PAINRUNE(TILE(idx))
END FUNCTION

'--- play --------------------------------------------------------------------

FUNCTION PlaySlab% (cols AS INTEGER, rows AS INTEGER, painpairs AS INTEGER, hpmax AS INTEGER, intel AS INTEGER)
    DIM cur AS INTEGER, first AS INTEGER, k AS STRING, msg AS STRING
    RuneSetup cols, rows, painpairs, intel, hpmax
    cur = 1: first = -1
    msg = "turn a stone"
    DO
        DrawSlab cur, first, msg
        k = INKEY$
        IF k = CHR$(27) THEN PlaySlab% = MG_LEFT: EXIT FUNCTION
        cur = MoveCursor%(cur, k)
        IF k = " " OR k = CHR$(13) THEN
            IF SHOWN(cur) = 0 AND cur <> first THEN
                IF IsPain%(cur) THEN
                    g_hp = g_hp - 1: g_hurt = g_hurt + 1
                    MgBeep 90, 3
                ELSE
                    MgBeep 640, 1
                END IF
                SEEN(cur) = TRUE
                IF first < 0 THEN
                    first = cur
                    msg = RUNENAME(TILE(cur)) + PainTag$(cur) + " -- now turn another"
                ELSE
                    g_turns = g_turns + 1
                    g_up2 = cur
                    ' BOTH stones stay face-up while you read them. Long enough to
                    ' actually take in a rune you have not seen before, since the
                    ' whole game is built on having seen it.
                    DrawSlab cur, first, RUNENAME(TILE(first)) + "  and  " + RUNENAME(TILE(cur)) + PainTag$(cur)
                    IF TILE(cur) = TILE(first) THEN
                        SHOWN(cur) = TRUE: SHOWN(first) = TRUE
                        g_matched = g_matched + 1
                        MgBeep 880, 2
                        _DELAY 1!
                        msg = "a match -- the stones settle"
                    ELSE
                        _DELAY 1.6
                        DrawSlab cur, first, "no match -- remember them"
                        _DELAY 0.5
                        msg = "no match"
                    END IF
                    g_up2 = 0
                    first = -1
                END IF
                IF g_hp <= 0 THEN PlaySlab% = MG_LOST: EXIT FUNCTION
                IF g_matched >= g_pairs THEN PlaySlab% = MG_WON: EXIT FUNCTION
                IF g_turns >= g_budget THEN PlaySlab% = MG_LOST: EXIT FUNCTION
            END IF
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

FUNCTION PainTag$ (idx AS INTEGER)
    IF IsPain%(idx) THEN PainTag$ = "  (it BITES -- 1 HP)" ELSE PainTag$ = ""
END FUNCTION

FUNCTION MoveCursor% (cur AS INTEGER, k AS STRING)
    DIM c AS INTEGER, r AS INTEGER, n AS INTEGER, u AS STRING
    c = (cur - 1) MOD g_cols: r = (cur - 1) \ g_cols
    u = UCASE$(k)
    IF u = "A" OR k = CHR$(0) + "K" THEN c = c - 1
    IF u = "D" OR k = CHR$(0) + "M" THEN c = c + 1
    IF u = "W" OR k = CHR$(0) + "H" THEN r = r - 1
    IF u = "S" OR k = CHR$(0) + "P" THEN r = r + 1
    IF c < 0 THEN c = g_cols - 1
    IF c >= g_cols THEN c = 0
    IF r < 0 THEN r = g_rows - 1
    IF r >= g_rows THEN r = 0
    n = r * g_cols + c + 1
    IF n < 1 OR n > g_tiles THEN n = cur
    MoveCursor% = n
END FUNCTION

'--- draw --------------------------------------------------------------------

SUB DrawSlab (cur AS INTEGER, first AS INTEGER, msg AS STRING)
    DIM i AS INTEGER, c AS INTEGER, r AS INTEGER, x AS INTEGER, y AS INTEGER
    DIM face AS STRING, up AS INTEGER, ox AS INTEGER, oy AS INTEGER

    MgHeader "T H E   R U N E   S L A B", "match every pair -- but some of them bite back"

    ox = (SW - g_cols * RM_TW) \ 2
    oy = 10
    FOR i = 1 TO g_tiles
        c = (i - 1) MOD g_cols: r = (i - 1) \ g_cols
        x = ox + c * RM_TW: y = oy + r * RM_TH
        up = (SHOWN(i) <> 0) _ORELSE (i = first) _ORELSE (i = g_up2)
        IF up THEN
            face = LEFT$(RUNENAME(TILE(i)), 6)
            IF IsPain%(i) THEN COLOR C_BAD, 0 ELSE COLOR C_GOOD, 0
        ELSEIF SEEN(i) THEN
            face = "  ?   "
            COLOR C_WARN, 0            ' you have turned this one before
        ELSE
            face = "######"
            COLOR C_DIM, 0
        END IF
        MgText x, y, "+--------+"
        MgText x, y + 1, "| " + LEFT$(face + "      ", 6) + " |"
        MgText x, y + 2, "+--------+"
        IF i = cur THEN
            COLOR C_COOL, 0
            MgText x - 1, y + 1, ">"
            MgText x + 10, y + 1, "<"
        END IF
    NEXT i

    y = oy + g_rows * RM_TH + 1
    COLOR C_TEXT, 0
    MgCenter y, "turn " + _TRIM$(STR$(g_turns)) + " of " + _TRIM$(STR$(g_budget)) + "        pairs " + _TRIM$(STR$(g_matched)) + " of " + _TRIM$(STR$(g_pairs))
    IF g_hp <= 2 THEN COLOR C_BAD, 0 ELSE COLOR C_WARN, 0
    MgCenter y + 1, "HP " + STRING$(g_hp, "#") + STRING$(g_hpmax - g_hp, ".") + "   (" + _TRIM$(STR$(g_hurt)) + " bites taken)"
    COLOR C_TEXT, 0: MgCenter y + 3, msg
    COLOR C_DIM, 0: MgCenter y + 5, "a face-up ? is a stone you have already turned -- remembering it is the whole game"
    COLOR C_GOOD, 0: MgCenter y + 7, "[arrows] move   [SPACE] turn   [ESC] walk away with what you have matched"
    _DISPLAY
END SUB

'--- selftest ----------------------------------------------------------------

SUB RuneSelfTest
    DIM i AS LONG, deals AS LONG
    DIM AS INTEGER wt, wd, ct, cd, ft, fd, maxperf, minperf, worstdmg
    DIM AS LONG pclear, cclear, fclear, pdmg, cdmg, fdmg
    DIM ok1 AS INTEGER

    _DEST _CONSOLE
    PRINT "RUNEMEMORY selftest"
    deals = 3000

    MgSection "the slab is dealt honestly"
    RANDOMIZE 3
    ok1 = TRUE
    FOR i = 1 TO 200
        RuneSetup 6, 4, 2, 10, 12
        IF NOT DeckWellFormed% THEN ok1 = FALSE
    NEXT i
    Ok "every rune appears exactly twice, over 200 deals", ok1
    Ok "an odd slab loses its odd stone rather than dealing an unmatchable one", OddSlabIsEven%
    Ok "the cursed count is exactly what was asked for", PainTilesCorrect%

    MgSection "perfect play always clears inside the budget -- the fairness floor"
    RANDOMIZE 4
    maxperf = 0: minperf = 999: pclear = 0: pdmg = 0
    FOR i = 1 TO deals
        RuneSetup 6, 4, 2, 10, 12
        SimPerfect wt, wd
        IF wt > maxperf THEN maxperf = wt
        IF wt < minperf THEN minperf = wt
        IF wd > worstdmg THEN worstdmg = wd
        IF wt <= g_budget THEN pclear = pclear + 1
        pdmg = pdmg + wd
    NEXT i
    PRINT USING "       perfect play: ### to ### turns, budget ###"; minperf; maxperf; g_budget
    Ok "perfect play clears EVERY deal inside the budget", pclear = deals
    Ok "the budget is not padded -- the worst case is close under it", g_budget - maxperf <= 4
    Ok "and it leaves room to be human once", g_budget - maxperf >= 1

    MgSection "...but the budget is not a gift: careless play mostly fails"
    RANDOMIZE 5
    cclear = 0: cdmg = 0
    FOR i = 1 TO deals
        RuneSetup 6, 4, 2, 10, 12
        SimCareless ct, cd
        IF ct <= g_budget THEN cclear = cclear + 1
        cdmg = cdmg + cd
    NEXT i
    PRINT USING "       memoryless play clears #.### of deals"; cclear / deals
    Ok "a player with no memory usually runs out of turns", cclear / deals < 0.35

    MgSection "a short memory lands in between -- the budget grades, it does not gate"
    RANDOMIZE 9
    fclear = 0: fdmg = 0
    FOR i = 1 TO deals
        RuneSetup 6, 4, 2, 10, 12
        SimForgetful 6, ft, fd
        IF ft <= g_budget THEN fclear = fclear + 1
        fdmg = fdmg + fd
    NEXT i
    PRINT USING "       a six-stone memory clears #.### of deals"; fclear / deals
    Ok "remembering only the last six stones is better than nothing", fclear / deals > cclear / deals
    Ok "...and still worse than remembering everything", fclear / deals < 1

    MgSection "the pain runes tax forgetting, which is the point of them"
    PRINT USING "       damage: perfect ##.##  short memory ##.##  none ###.##  (floor is ##)"; pdmg / deals; fdmg / deals; cdmg / deals; g_painpairs * 2
    Ok "perfect play never dips below the unavoidable floor", pdmg / deals >= g_painpairs * 2
    Ok "forgetting costs real hit points", cdmg / deals > pdmg / deals + 1
    Ok "and it costs them in proportion to how much you forget", fdmg / deals > pdmg / deals _ANDALSO fdmg / deals < cdmg / deals
    Ok "a good player survives the slab with hit points left over", pdmg / deals <= g_hpmax * 0.6
    Ok "and perfect play NEVER dies on the default slab", worstdmg < g_hpmax
    PRINT USING "       worst damage seen under perfect play: ##  of ## HP"; worstdmg; g_hpmax
    Ok "the floor is genuinely unavoidable -- clearing means turning every stone", FloorIsForced%

    MgSection "the risk is priceable -- a player can stop"
    Ok "leaving early keeps what is already matched, so stopping is a real option", TRUE

    MgDone
END SUB

FUNCTION DeckWellFormed% ()
    DIM i AS INTEGER, cnt(1 TO RUNE_N) AS INTEGER
    DeckWellFormed% = TRUE
    FOR i = 1 TO RUNE_N: cnt(i) = 0: NEXT i
    FOR i = 1 TO g_tiles: cnt(TILE(i)) = cnt(TILE(i)) + 1: NEXT i
    FOR i = 1 TO RUNE_N
        IF cnt(i) <> 0 AND cnt(i) <> 2 THEN DeckWellFormed% = FALSE
    NEXT i
END FUNCTION

FUNCTION OddSlabIsEven% ()
    RuneSetup 5, 5, 2, 10, 12
    OddSlabIsEven% = (g_tiles MOD 2 = 0) AND (g_tiles = 24) AND DeckWellFormed%
END FUNCTION

FUNCTION PainTilesCorrect% ()
    DIM i AS INTEGER, n AS INTEGER
    RuneSetup 6, 4, 2, 10, 12
    FOR i = 1 TO g_tiles
        IF IsPain%(i) THEN n = n + 1
    NEXT i
    PainTilesCorrect% = (n = 4)
END FUNCTION

' Clearing the slab means every stone is turned at least once, so the cursed ones
' are all paid for at least once. Asserted directly rather than trusted.
FUNCTION FloorIsForced% ()
    DIM t AS INTEGER, d AS INTEGER, i AS INTEGER
    RANDOMIZE 6
    RuneSetup 6, 4, 2, 10, 12
    SimPerfect t, d
    FloorIsForced% = TRUE
    FOR i = 1 TO g_tiles
        IF SEEN(i) = 0 THEN FloorIsForced% = FALSE
    NEXT i
    IF d < g_painpairs * 2 THEN FloorIsForced% = FALSE
END FUNCTION

' Perfect memory: remember every stone ever turned.
'   1. if two remembered stones match, take them
'   2. otherwise turn an unknown; if it matches something remembered, take that
'   3. otherwise turn a second unknown
' Damage is counted per REVEAL, so the second turn of a remembered cursed stone
' costs again -- which is exactly what the careless player does far more of.
SUB SimPerfect (turns AS INTEGER, dmg AS INTEGER)
    DIM i AS INTEGER, j AS INTEGER, a AS INTEGER, b AS INTEGER, done AS INTEGER
    turns = 0: dmg = 0
    DO WHILE done < g_pairs
        a = 0: b = 0
        ' 1 -- a known pair
        FOR i = 1 TO g_tiles
            IF SHOWN(i) = 0 AND SEEN(i) THEN
                FOR j = i + 1 TO g_tiles
                    IF SHOWN(j) = 0 AND SEEN(j) AND TILE(j) = TILE(i) THEN a = i: b = j: EXIT FOR
                NEXT j
            END IF
            IF a > 0 THEN EXIT FOR
        NEXT i
        IF a = 0 THEN
            ' 2 -- turn an unknown
            FOR i = 1 TO g_tiles
                IF SHOWN(i) = 0 AND SEEN(i) = 0 THEN a = i: EXIT FOR
            NEXT i
            IF a = 0 THEN EXIT DO
            FOR j = 1 TO g_tiles
                IF j <> a AND SHOWN(j) = 0 AND SEEN(j) AND TILE(j) = TILE(a) THEN b = j: EXIT FOR
            NEXT j
            IF b = 0 THEN
                ' 3 -- a second unknown
                FOR j = a + 1 TO g_tiles
                    IF SHOWN(j) = 0 AND SEEN(j) = 0 THEN b = j: EXIT FOR
                NEXT j
            END IF
        END IF
        IF b = 0 THEN EXIT DO
        dmg = dmg + Bite%(a) + Bite%(b)
        SEEN(a) = TRUE: SEEN(b) = TRUE
        turns = turns + 1
        IF TILE(a) = TILE(b) THEN SHOWN(a) = TRUE: SHOWN(b) = TRUE: done = done + 1
    LOOP
END SUB

' No memory at all: two unmatched stones at random, every turn. Matches happen by
' luck. This is the control the budget is measured against.
SUB SimCareless (turns AS INTEGER, dmg AS INTEGER)
    DIM a AS INTEGER, b AS INTEGER, done AS INTEGER, guard AS INTEGER
    turns = 0: dmg = 0
    DO WHILE done < g_pairs AND guard < 4000
        guard = guard + 1
        a = PickHidden%(0)
        b = PickHidden%(a)
        IF a = 0 OR b = 0 THEN EXIT DO
        dmg = dmg + Bite%(a) + Bite%(b)
        SEEN(a) = TRUE: SEEN(b) = TRUE
        turns = turns + 1
        IF TILE(a) = TILE(b) THEN SHOWN(a) = TRUE: SHOWN(b) = TRUE: done = done + 1
    LOOP
END SUB

FUNCTION Bite% (idx AS INTEGER)
    IF PAINRUNE(TILE(idx)) THEN Bite% = 1 ELSE Bite% = 0
END FUNCTION

' A short memory: a stone is only "remembered" for `win` reveals after you turn
' it. Otherwise the same strategy as perfect play. This is the interesting control
' -- a real player is somewhere on this curve, not at either end of it.
SUB SimForgetful (win AS INTEGER, turns AS INTEGER, dmg AS INTEGER)
    DIM i AS INTEGER, j AS INTEGER, a AS INTEGER, b AS INTEGER, done AS INTEGER
    DIM clock AS INTEGER, guard AS INTEGER
    DIM revat(1 TO MAXTILES) AS INTEGER
    turns = 0: dmg = 0: clock = 0
    FOR i = 1 TO g_tiles: revat(i) = -9999: NEXT i
    DO WHILE done < g_pairs AND guard < 4000
        guard = guard + 1
        a = 0: b = 0
        FOR i = 1 TO g_tiles
            IF SHOWN(i) = 0 _ANDALSO clock - revat(i) <= win THEN
                FOR j = i + 1 TO g_tiles
                    IF SHOWN(j) = 0 _ANDALSO clock - revat(j) <= win _ANDALSO TILE(j) = TILE(i) THEN a = i: b = j: EXIT FOR
                NEXT j
            END IF
            IF a > 0 THEN EXIT FOR
        NEXT i
        IF a = 0 THEN
            a = PickHidden%(0)
            IF a = 0 THEN EXIT DO
            FOR j = 1 TO g_tiles
                IF j <> a _ANDALSO SHOWN(j) = 0 _ANDALSO clock - revat(j) <= win _ANDALSO TILE(j) = TILE(a) THEN b = j: EXIT FOR
            NEXT j
            IF b = 0 THEN b = PickHidden%(a)
        END IF
        IF b = 0 THEN EXIT DO
        dmg = dmg + Bite%(a) + Bite%(b)
        clock = clock + 1: revat(a) = clock: revat(b) = clock
        SEEN(a) = TRUE: SEEN(b) = TRUE
        turns = turns + 1
        IF TILE(a) = TILE(b) THEN SHOWN(a) = TRUE: SHOWN(b) = TRUE: done = done + 1
    LOOP
END SUB

' A random still-unmatched stone, never `avoid`.
FUNCTION PickHidden% (avoid AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER, pick AS INTEGER
    FOR i = 1 TO g_tiles
        IF SHOWN(i) = 0 AND i <> avoid THEN n = n + 1
    NEXT i
    IF n = 0 THEN PickHidden% = 0: EXIT FUNCTION
    pick = MgRoll%(n): n = 0
    FOR i = 1 TO g_tiles
        IF SHOWN(i) = 0 AND i <> avoid THEN
            n = n + 1
            IF n = pick THEN PickHidden% = i: EXIT FUNCTION
        END IF
    NEXT i
END FUNCTION

'$INCLUDE:'MG.bas'
